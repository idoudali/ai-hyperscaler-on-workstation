#!/bin/bash

# HPC Cloud Ansible Orchestration Script
# Automated deployment and configuration of HPC cluster infrastructure
# Integrates with ai-how cluster management and project virtual environment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_DIR="$PROJECT_ROOT/logs/ansible-hpc-cloud-$TIMESTAMP"

# Default configuration
DEFAULT_CLUSTER_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/test-monitoring-stack.yaml"
DEFAULT_SSH_KEY="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"

# Operation modes
OPERATION="deploy"
CLUSTER_CONFIG=""
CLUSTER_NAME=""
DRY_RUN=false
VERBOSE=false
FORCE=false

# Feature flags
INSTALL_MONITORING_STACK=true
INSTALL_SLURM_CONTROLLER=true
INSTALL_SLURM_COMPUTE=true
INSTALL_CONTAINER_RUNTIME=true
INSTALL_GPU_SUPPORT=true
INSTALL_DATABASE=true

usage() {
    cat << 'EOF'
Usage: $0 [OPTIONS] [OPERATION]

OPERATIONS:
    deploy      Create cluster and deploy HPC stack (default)
    configure   Configure existing cluster with HPC software
    verify      Verify HPC cluster configuration
    destroy     Destroy HPC cluster

OPTIONS:
    -c, --cluster-config FILE   Cluster configuration file (YAML)
    -n, --cluster-name NAME     Cluster name (overrides config file)
    -d, --dry-run              Show what would be done without executing
    -v, --verbose              Enable verbose output
    -f, --force                Force operations without confirmation
    -h, --help                 Show this help message

FEATURE FLAGS:
    --no-monitoring           Disable monitoring stack installation
    --no-slurm-controller     Disable SLURM controller installation
    --no-slurm-compute        Disable SLURM compute installation
    --no-container-runtime    Disable container runtime installation
    --no-gpu-support          Disable GPU support installation
    --no-database             Disable database installation

EXAMPLES:
    # Deploy full HPC cluster using default config
    ./run-ansible-hpc-cloud.sh deploy

    # Configure existing cluster without monitoring
    ./run-ansible-hpc-cloud.sh --no-monitoring configure

    # Dry-run deployment with custom config
    ./run-ansible-hpc-cloud.sh -d -c /path/to/cluster.yaml deploy

    # Verify cluster with verbose output
    ./run-ansible-hpc-cloud.sh -v verify

    # Force destroy cluster
    ./run-ansible-hpc-cloud.sh -f destroy

ENVIRONMENT:
    AI_HOW_CLUSTER_CONFIG   Default cluster configuration file
    VIRTUAL_ENV_PATH        Path to virtual environment (auto-detected)
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--cluster-config) CLUSTER_CONFIG="$2"; shift 2 ;;
            -n|--cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
            -d|--dry-run) DRY_RUN=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -f|--force) FORCE=true; shift ;;
            --no-monitoring) INSTALL_MONITORING_STACK=false; shift ;;
            --no-slurm-controller) INSTALL_SLURM_CONTROLLER=false; shift ;;
            --no-slurm-compute) INSTALL_SLURM_COMPUTE=false; shift ;;
            --no-container-runtime) INSTALL_CONTAINER_RUNTIME=false; shift ;;
            --no-gpu-support) INSTALL_GPU_SUPPORT=false; shift ;;
            --no-database) INSTALL_DATABASE=false; shift ;;
            -h|--help) usage; exit 0 ;;
            deploy|configure|verify|destroy) OPERATION="$1"; shift ;;
            -*) log_error "Unknown option: $1"; usage; exit 1 ;;
            *) OPERATION="$1"; shift ;;
        esac
    done

    # Set default cluster config if not provided
    if [[ -z "$CLUSTER_CONFIG" ]]; then
        CLUSTER_CONFIG="${AI_HOW_CLUSTER_CONFIG:-$DEFAULT_CLUSTER_CONFIG}"
    fi

    # Validate cluster config file exists
    if [[ ! -f "$CLUSTER_CONFIG" ]]; then
        log_error "Cluster configuration file not found: $CLUSTER_CONFIG"
        exit 1
    fi
}

# Setup virtual environment for Ansible
setup_virtual_environment() {
    log_info "Setting up virtual environment for Ansible dependencies..."

    if [[ -f "$PROJECT_ROOT/.venv/bin/activate" ]]; then
        log_info "Virtual environment exists, checking Ansible availability..."
        if source "$PROJECT_ROOT/.venv/bin/activate" && python3 -c "from ansible.cli.playbook import main" >/dev/null 2>&1; then
            log_success "Virtual environment with Ansible is ready"
            return 0
        else
            log_warning "Virtual environment exists but Ansible is not properly installed"
        fi
    fi

    log_info "Creating virtual environment with all dependencies..."
    if (cd "$PROJECT_ROOT" && make venv-create); then
        log_success "Virtual environment created successfully"
        return 0
    else
        log_error "Failed to create virtual environment"
        return 1
    fi
}

# Extract cluster name from configuration using ai-how plan clusters
get_cluster_name() {
    local config_file="$1"

    if [[ -n "$CLUSTER_NAME" ]]; then
        echo "$CLUSTER_NAME"
        return 0
    fi

    # Get cluster plan as JSON and extract HPC cluster name (silently)
    local cluster_plan_json
    cluster_plan_json=$(timeout 30 uv run ai-how plan clusters "$config_file" -f json 2>/dev/null)

    if [[ $? -ne 0 || -z "$cluster_plan_json" ]]; then
        return 1
    fi

    # Extract HPC cluster name from JSON using jq
    local cluster_name
    cluster_name=$(echo "$cluster_plan_json" | jq -r '.clusters.hpc.name // empty' 2>/dev/null)

    if [[ -z "$cluster_name" ]]; then
        return 1
    fi

    echo "$cluster_name"
}

# Check if cluster exists and get status
get_cluster_status() {
    local cluster_name="$1"

    log_info "Checking cluster status: $cluster_name"

    # Add timeout to prevent hanging
    if timeout 30 uv run ai-how hpc status "$CLUSTER_CONFIG" >/dev/null 2>&1; then
        echo "running"
    else
        echo "not_found"
    fi
}

# Generate Ansible inventory from cluster information using ai-how plan clusters
generate_inventory() {
    local cluster_config="$1"
    local inventory_file="$2"

    log_info "Generating Ansible inventory from cluster configuration..."

    # Create logs directory structure
    mkdir -p "$LOG_DIR"

    # Get cluster plan as JSON and save to file
    local cluster_plan_json_file="$LOG_DIR/cluster-plan.json"
    log_info "Saving cluster plan to: $cluster_plan_json_file"

    if ! timeout 30 uv run ai-how plan clusters "$cluster_config" -f json -o "$cluster_plan_json_file"; then
        log_error "Failed to generate cluster plan"
        return 1
    fi

    if [[ ! -f "$cluster_plan_json_file" ]]; then
        log_error "Cluster plan file not created: $cluster_plan_json_file"
        return 1
    fi

    # Extract cluster name from JSON using jq
    local cluster_name
    cluster_name=$(jq -r '.clusters.hpc.name // empty' "$cluster_plan_json_file" 2>/dev/null)

    if [[ -z "$cluster_name" ]]; then
        log_error "Could not extract cluster name from cluster plan"
        return 1
    fi

    log_info "Generating inventory for cluster: $cluster_name"

    # Create inventory file directory
    mkdir -p "$(dirname "$inventory_file")"

    # Generate inventory from JSON using jq
    {
        echo "# Generated HPC Cloud Inventory - $TIMESTAMP"
        echo "# Cluster: $cluster_name"
        echo ""

        # Controller VMs
        echo "[hpc_controllers]"
        local controllers
        controllers=$(jq -r '.clusters.hpc.vms[] | select(.type == "controller") | "\(.name) ansible_host=\(.ip_address) ansible_user=admin"' "$cluster_plan_json_file" 2>/dev/null)
        if [[ -n "$controllers" ]]; then
            echo "$controllers"
        else
            echo "# No controller VMs found"
        fi

        echo ""

        # Compute VMs
        echo "[hpc_compute_nodes]"
        local compute_nodes
        compute_nodes=$(jq -r '.clusters.hpc.vms[] | select(.type == "compute") | "\(.name) ansible_host=\(.ip_address) ansible_user=admin"' "$cluster_plan_json_file" 2>/dev/null)
        if [[ -n "$compute_nodes" ]]; then
            echo "$compute_nodes"
        else
            echo "# No compute VMs found"
        fi

        echo ""
        echo "[all:vars]"
        echo "ansible_ssh_private_key_file=$DEFAULT_SSH_KEY"
        echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'"
        echo "ansible_python_interpreter=/usr/bin/python3"
        echo ""
        echo "# Feature flags for Ansible playbooks"
        echo "install_monitoring_stack=$INSTALL_MONITORING_STACK"
        echo "install_slurm_controller=$INSTALL_SLURM_CONTROLLER"
        echo "install_slurm_compute=$INSTALL_SLURM_COMPUTE"
        echo "install_container_runtime=$INSTALL_CONTAINER_RUNTIME"
        echo "install_gpu_support=$INSTALL_GPU_SUPPORT"
        echo "install_database=$INSTALL_DATABASE"
        echo "packer_build=false"

    } > "$inventory_file" || {
        log_error "Failed to generate inventory from cluster plan"
        return 1
    }

    # Display generated inventory if verbose
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Generated inventory:"
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ ]] || log_info "  $line"
        done < "$inventory_file"
    fi

    log_success "Ansible inventory generated: $inventory_file"
    log_info "Cluster plan saved to: $cluster_plan_json_file"
    return 0
}

# Run Ansible playbook with proper environment
run_ansible_playbook() {
    local playbook_file="$1"
    local inventory_file="$2"
    local extra_args="${3:-}"

    log_info "Running Ansible playbook: $(basename "$playbook_file")"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN: Would execute playbook $playbook_file"
        return 0
    fi

    # Change to ansible directory for proper configuration
    local original_dir
    original_dir=$(pwd)
    cd "$ANSIBLE_DIR" || {
        log_error "Could not change to ansible directory: $ANSIBLE_DIR"
        return 1
    }

    # Set up environment variables for Ansible
    export ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg"
    export PATH="$PROJECT_ROOT/.venv/bin:$PATH"

    local ansible_cmd="$PROJECT_ROOT/.venv/bin/ansible-playbook"
    if [[ ! -f "$ansible_cmd" ]]; then
        log_error "Ansible not found in virtual environment: $ansible_cmd"
        cd "$original_dir"
        return 1
    fi

    # Build ansibl1e command
    local cmd_args=("-i" "$inventory_file" "$playbook_file")

    if [[ "$VERBOSE" == "true" ]]; then
        cmd_args+=("-v")
    fi

    if [[ -n "$extra_args" ]]; then
        # Split extra_args into array elements
        read -ra extra_args_array <<< "$extra_args"
        cmd_args+=("${extra_args_array[@]}")
    fi

    # Execute playbook
    log_info "Executing: $ansible_cmd ${cmd_args[*]}"

    if "$ansible_cmd" "${cmd_args[@]}"; then
        log_success "Playbook completed successfully: $(basename "$playbook_file")"
        cd "$original_dir"
        return 0
    else
        log_error "Playbook failed: $(basename "$playbook_file")"
        cd "$original_dir"
        return 1
    fi
}

# Deploy operation: create cluster and configure HPC stack
operation_deploy() {
    log_info "Starting HPC cluster deployment..."

    local cluster_name
    cluster_name=$(get_cluster_name "$CLUSTER_CONFIG")

    if [[ -z "$cluster_name" ]]; then
        log_error "Failed to get cluster name from configuration"
        return 1
    fi

    log_info "HPC cluster name: $cluster_name"

    # Check if cluster already exists
    local status
    status=$(get_cluster_status "$cluster_name")

    if [[ "$status" == "running" ]]; then
        if [[ "$FORCE" != "true" ]]; then
            log_warning "Cluster $cluster_name is already running"
            log_info "Use --force to reconfigure or 'configure' operation to update existing cluster"
            return 1
        else
            log_warning "Cluster exists, proceeding with forced reconfiguration"
        fi
    else
        log_info "Creating HPC cluster: $cluster_name"
        if [[ "$DRY_RUN" != "true" ]]; then
            if ! uv run ai-how hpc start "$CLUSTER_CONFIG"; then
                log_error "Failed to create cluster"
                return 1
            fi
            log_success "Cluster created successfully"
        fi
    fi

    # Wait for cluster to be ready
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "Waiting for cluster to be fully operational..."
        sleep 10  # Allow VMs to fully boot
    fi

    # Configure the cluster
    operation_configure
}

# Configure operation: configure existing cluster with HPC software
operation_configure() {
    log_info "Starting HPC cluster configuration..."

    local cluster_name
    cluster_name=$(get_cluster_name "$CLUSTER_CONFIG")

    if [[ -z "$cluster_name" ]]; then
        log_error "Failed to get cluster name from configuration"
        return 1
    fi

    log_info "Configuring HPC cluster: $cluster_name"

    # Check if cluster is running
    local status
    status=$(get_cluster_status "$cluster_name")

    if [[ "$status" != "running" ]]; then
        log_error "Cluster $cluster_name is not running. Use 'deploy' operation to create it first."
        return 1
    fi

    # Generate inventory
    local inventory_file="$LOG_DIR/inventory-$cluster_name.ini"
    mkdir -p "$LOG_DIR"

    if ! generate_inventory "$CLUSTER_CONFIG" "$inventory_file"; then
        log_error "Failed to generate inventory"
        return 1
    fi

    # Run controller playbook first
    log_info "Configuring HPC controller nodes..."
    if ! run_ansible_playbook "playbooks/playbook-hpc-controller.yml" "$inventory_file" "--limit hpc_controllers"; then
        log_error "Failed to configure controller nodes"
        return 1
    fi

    # Run compute playbook
    log_info "Configuring HPC compute nodes..."
    if ! run_ansible_playbook "playbooks/playbook-hpc-compute.yml" "$inventory_file" "--limit hpc_compute_nodes"; then
        log_error "Failed to configure compute nodes"
        return 1
    fi

    log_success "HPC cluster configuration completed successfully"

    # Show cluster status
    operation_verify
}

# Verify operation: verify HPC cluster configuration
operation_verify() {
    log_info "Starting cluster verification..."

    local cluster_name
    cluster_name=$(get_cluster_name "$CLUSTER_CONFIG")

    if [[ -z "$cluster_name" ]]; then
        log_error "Failed to get cluster name from configuration"
        return 1
    fi

    log_info "Verifying HPC cluster: $cluster_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN: Would verify cluster $cluster_name"
        return 0
    fi

    # Show cluster status
    log_info "Cluster Status:"
    if timeout 60 uv run ai-how hpc status "$CLUSTER_CONFIG"; then
        log_success "Cluster is running and accessible"
    else
        log_error "Failed to get cluster status (timeout or cluster not found)"
        return 1
    fi

    return 0
}

# Destroy operation: destroy HPC cluster
operation_destroy() {
    log_info "Starting cluster destruction process..."

    local cluster_name
    cluster_name=$(get_cluster_name "$CLUSTER_CONFIG")

    if [[ -z "$cluster_name" ]]; then
        log_error "Failed to get cluster name from configuration"
        return 1
    fi

    if [[ "$FORCE" != "true" ]]; then
        echo -n "Are you sure you want to destroy cluster '$cluster_name'? [y/N] "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled"
            return 0
        fi
    fi

    log_info "Destroying HPC cluster: $cluster_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN: Would destroy cluster $cluster_name"
        return 0
    fi

    if uv run ai-how hpc destroy "$CLUSTER_CONFIG" --force; then
        log_success "Cluster destroyed successfully"
    else
        log_error "Failed to destroy cluster"
        return 1
    fi
}

# Main execution function
main() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  HPC Cloud Ansible Orchestration${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo

    log_info "Operation: $OPERATION"
    log_info "Cluster Config: $CLUSTER_CONFIG"
    log_info "Log Directory: $LOG_DIR"

    # Create logs directory structure early
    mkdir -p "$LOG_DIR"
    log_info "Created logs directory: $LOG_DIR"

    # Check for required tools
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required but not installed. Please install jq: sudo apt-get install jq"
        exit 1
    fi

    # Setup virtual environment
    if ! setup_virtual_environment; then
        log_error "Failed to setup virtual environment"
        exit 1
    fi

    log_info "Virtual environment setup completed, exporting paths..."

    # Export virtual environment for Ansible execution
    export VIRTUAL_ENV_PATH="$PROJECT_ROOT/.venv"
    export PATH="$VIRTUAL_ENV_PATH/bin:$PATH"

    log_info "About to execute operation: $OPERATION"

    # Execute requested operation
    case "$OPERATION" in
        deploy) operation_deploy ;;
        configure) operation_configure ;;
        verify) operation_verify ;;
        destroy) operation_destroy ;;
        *)
            log_error "Unknown operation: $OPERATION"
            usage
            exit 1
            ;;
    esac

    local exit_code=$?

    echo
    if [[ $exit_code -eq 0 ]]; then
        log_success "HPC Cloud operation '$OPERATION' completed successfully"
    else
        log_error "HPC Cloud operation '$OPERATION' failed"
    fi

    log_info "Logs and artifacts saved to: $LOG_DIR"
    echo -e "${BLUE}============================================${NC}"

    exit $exit_code
}

# Parse arguments and run main function
parse_arguments "$@"
main
