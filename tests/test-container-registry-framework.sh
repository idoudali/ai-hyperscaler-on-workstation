#!/bin/bash
# Container Registry Test Framework (Unified)
# Task 021 - Container Registry Infrastructure & Cluster Deployment
# Test framework for validating container registry infrastructure and image deployment
#
# This framework uses shared utility functions from tests/test-infra/utils/:
#
# test-framework-utils.sh: Main test framework utilities
#   - deploy_ansible_playbook(): Deploys Ansible playbooks with automatic inventory generation
#   - generate_ansible_inventory(): Generates dynamic inventory from cluster state
#   - wait_for_inventory_nodes_ssh(): Waits for SSH connectivity on all nodes
#
# cluster-utils.sh: Cluster management utilities
#   - start_cluster(): Starts HPC cluster using ai-how
#   - destroy_cluster(): Destroys cluster with cleanup verification
#   - check_cluster_not_running(): Validates cluster state before starting
#   - wait_for_cluster_vms(): Waits for VMs to be ready
#   - parse_cluster_name(): Extracts cluster name from config using ai-how API
#
# vm-utils.sh: VM management utilities
#   - get_vm_ips_for_cluster(): Gets VM IPs using ai-how API
#   - get_vm_ip(): Gets IP address for a specific VM
#   - wait_for_vm_ssh(): Waits for SSH connectivity on individual VMs
#
# log-utils.sh: Logging utilities
#   - log(), log_success(), log_error(), log_warning(): Consistent logging
#   - log_info(), log_verbose(): Informational and verbose logging
#   - init_logging(): Initializes logging for test runs
#   - configure_logging_level(): Sets logging verbosity (quiet|normal|verbose|debug)
#
# REFACTORING NOTES:
#   - Replaced manual inventory generation with deploy_ansible_playbook()
#   - Replaced manual cluster start/stop with start_cluster()/destroy_cluster()
#   - Replaced manual SSH checks with wait_for_vm_ssh()
#   - Replaced manual VM IP discovery with get_vm_ip()
#   - Simplified discover_and_validate_controller() using yq to extract config and generate inventory

set -euo pipefail

# Help message
show_help() {
    cat << EOF
Container Registry Test Framework - Task 021 Validation

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    e2e, end-to-end   Run complete end-to-end test with cleanup (default behavior)
    start-cluster     Start the HPC cluster independently
    stop-cluster      Stop and destroy the HPC cluster
    deploy-ansible    Deploy container registry via Ansible (assumes cluster is running)
    deploy-images     Build, convert, and deploy container images to cluster
    run-tests         Run container registry tests on deployed cluster
    list-tests        List all available individual test scripts
    run-test NAME     Run a specific individual test by name
    status            Show cluster status
    help              Show this help message

OPTIONS:
    -h, --help        Show this help message
    -v, --verbose     Enable verbose output (equivalent to --log-level verbose)
    -q, --quiet       Minimal output (equivalent to --log-level quiet)
    --log-level LVL   Set logging level: quiet, normal, verbose, debug (default: normal)
    --no-cleanup      Skip cleanup after test completion
    --interactive     Enable interactive cleanup prompts
    --phase PHASE     Specific test phase (infrastructure|deployment|e2e)
    --controller HOST Test controller hostname (default: hpc-controller)
    --test-image IMG  Test image name (default: pytorch-cuda12.1-mpi4.1.sif)

LOGGING LEVELS:
    quiet             Only show errors and critical messages
    normal            Standard output with key steps and results (default)
    verbose           Detailed output including all operations
    debug             Maximum verbosity for troubleshooting

TEST PHASES (for run-tests command):
    infrastructure    Run Ansible infrastructure tests (Test Suite 1)
    deployment        Run image deployment tests (Test Suite 2)
    e2e               Run end-to-end integration tests (Test Suite 3)
    all               Run all three test suites (default for run-tests)

EXAMPLES:
    # Run complete end-to-end test with cleanup (default, recommended for CI/CD)
    $0
    $0 e2e
    $0 end-to-end

    # Modular workflow for debugging (keeps cluster running)
    $0 start-cluster          # Start cluster once
    $0 deploy-ansible         # Deploy registry infrastructure
    $0 deploy-images          # Build and deploy container images
    $0 run-tests              # Run all tests (can repeat)
    $0 run-tests --phase infrastructure  # Run specific phase
    $0 stop-cluster           # Clean up when done

    # List and run individual tests
    $0 list-tests             # Show all available test scripts
    $0 run-test check-registry-structure.sh    # Run specific test
    $0 run-test check-slurm-container-exec.sh  # Run another specific test

    # Check status
    $0 status

    # Logging level examples
    $0 --verbose e2e                           # End-to-end with verbose output
    $0 -v run-tests                            # Verbose (short form)
    $0 --quiet run-tests                       # Minimal output
    $0 -q start-cluster                        # Quiet mode (short form)
    $0 --log-level debug e2e                   # Maximum verbosity with trace
    $0 --log-level verbose deploy-ansible      # Detailed Ansible output

WORKFLOWS:
    End-to-End (Default):
        $0                    # Complete test with cleanup
        $0 e2e                # Explicit

    Manual/Debugging:
        1. Start cluster:     $0 start-cluster
        2. Deploy Ansible:    $0 deploy-ansible
        3. Deploy images:     $0 deploy-images
        4. Run tests:         $0 run-tests [--phase PHASE]
        5. Stop cluster:      $0 stop-cluster

CONFIGURATION:
    Test Controller: $TEST_CONTROLLER
    Registry Base: $REGISTRY_BASE_PATH
    Registry Path: $REGISTRY_PATH
    Test Image: $TEST_IMAGE

NOTES:
    - Container registry setup MUST NOT run during Packer builds (packer_build=true)
    - Registry infrastructure deployed ONLY on live VMs (packer_build=false)
    - See docs/CLUSTER-DEPLOYMENT-WORKFLOW.md for detailed workflow
    - See docs/TESTING-TASK-021.md for comprehensive testing guide

EOF
}

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Framework configuration
FRAMEWORK_NAME="Container Registry Test Framework"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Validate PROJECT_ROOT
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "Error: Invalid PROJECT_ROOT directory: $PROJECT_ROOT"
    exit 1
fi

# Source shared utilities
UTILS_DIR="$PROJECT_ROOT/tests/test-infra/utils"
if [[ ! -f "$UTILS_DIR/test-framework-utils.sh" ]]; then
    echo "Error: Shared utilities not found at $UTILS_DIR/test-framework-utils.sh"
    exit 1
fi

# Set up environment variables for shared utilities
export PROJECT_ROOT
export TESTS_DIR="$PROJECT_ROOT/tests"
export SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
export SSH_USER="admin"
export CLEANUP_REQUIRED=false
export INTERACTIVE_CLEANUP=false
export TEST_NAME="container-registry"

# shellcheck source=./test-infra/utils/test-framework-utils.sh
source "$UTILS_DIR/test-framework-utils.sh"

# Test configuration
TEST_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/test-container-registry.yaml"
TARGET_VM_PATTERN="test-container-registry"

# Test suite paths
SUITE_1_RUNNER="$TESTS_DIR/suites/container-registry/run-ansible-infrastructure-tests.sh"
SUITE_2_RUNNER="$TESTS_DIR/suites/container-deployment/run-image-deployment-tests.sh"
SUITE_3_RUNNER="$TESTS_DIR/suites/container-e2e/run-container-e2e-tests.sh"

# Registry Infrastructure Playbook
REGISTRY_PLAYBOOK="$PROJECT_ROOT/ansible/playbooks/playbook-container-registry.yml"

# Ansible inventory file (generated dynamically from test config)
ANSIBLE_INVENTORY="$PROJECT_ROOT/tests/test-infra/inventory/container-registry-inventory.ini"

# Test environment
export TEST_CONTROLLER="${TEST_CONTROLLER:-hpc-controller}"
export REGISTRY_BASE_PATH="${REGISTRY_BASE_PATH:-/opt/containers}"
export REGISTRY_PATH="${REGISTRY_PATH:-/opt/containers/ml-frameworks}"
export TEST_IMAGE="${TEST_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"

# Global variables for command line options
export NO_CLEANUP=false
INTERACTIVE=false
COMMAND="e2e"
TEST_PHASE="all"
TEST_NAME=""
LOG_LEVEL="normal"  # quiet, normal, verbose, debug

# Logging level configuration
# Exported for use by log-utils.sh functions
export VERBOSE_MODE=false

# Colors (already defined in utils, but kept for standalone usage)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                LOG_LEVEL="verbose"
                shift
                ;;
            -q|--quiet)
                LOG_LEVEL="quiet"
                shift
                ;;
            --log-level)
                LOG_LEVEL="$2"
                shift 2
                ;;
            --no-cleanup)
                NO_CLEANUP=true
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --phase)
                TEST_PHASE="$2"
                shift 2
                ;;
            --controller)
                TEST_CONTROLLER="$2"
                export TEST_CONTROLLER
                shift 2
                ;;
            --test-image)
                TEST_IMAGE="$2"
                export TEST_IMAGE
                shift 2
                ;;
            e2e|end-to-end|start-cluster|stop-cluster|deploy-ansible|deploy-images|run-tests|list-tests|status|help)
                COMMAND="$1"
                shift
                ;;
            run-test)
                COMMAND="run-test"
                TEST_NAME="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Use '$0 --help' for usage information"
                exit 1
                ;;
        esac
    done
}

# Initialize logging
# Note: configure_logging_level() is now provided by log-utils.sh
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "container-registry"

# Setup virtual environment for Ansible
setup_virtual_environment() {
    log_verbose "Setting up virtual environment for Ansible dependencies..."

    # Check if virtual environment exists and has Ansible
    if [[ -f "$PROJECT_ROOT/.venv/bin/activate" ]]; then
        log_verbose "Virtual environment exists, checking Ansible availability..."
        if source "$PROJECT_ROOT/.venv/bin/activate" && python3 -c "from ansible.cli.playbook import main" >/dev/null 2>&1; then
            log_verbose "Virtual environment with Ansible is ready"
            return 0
        else
            log_warning "Virtual environment exists but Ansible is not properly installed"
        fi
    fi

    log "Creating virtual environment with all dependencies..."
    if (cd "$PROJECT_ROOT" && make venv-create); then
        log_success "Virtual environment created successfully"
        return 0
    else
        log_error "Failed to create virtual environment"
        return 1
    fi
}

# Start cluster independently
start_cluster_wrapper() {
    log "Starting HPC cluster for container registry tests..."

    # Check if cluster is already running
    if ! check_cluster_not_running "$TARGET_VM_PATTERN" 2>/dev/null; then
        log_warning "Cluster appears to be already running"
        if [[ "$INTERACTIVE" == "true" ]]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "Aborted by user"
                return 0
            fi
        fi
    fi

    # Check if test config exists
    if [[ ! -f "$TEST_CONFIG" ]]; then
        log_error "Test configuration not found: $TEST_CONFIG"
        log ""
        log "The test configuration file is required for cluster management."
        log "It should have been created during Task 021 implementation."
        log ""
        log "If you're testing manually with an existing cluster:"
        log "  1. Ensure your cluster is running"
        log "  2. Set TEST_CONTROLLER to your controller hostname:"
        log "     export TEST_CONTROLLER=your-controller-hostname"
        log "  3. Skip start-cluster and go directly to deploy-ansible:"
        log "     $0 deploy-ansible"
        log ""
        return 1
    fi

    # Use helper function to start cluster
    # This handles:
    # - Configuration validation
    # - Image existence checks
    # - ai-how command execution
    # - Logging and error handling
    local cluster_name
    cluster_name=$(basename "${TEST_CONFIG%.yaml}")

    if start_cluster "$TEST_CONFIG" "$cluster_name"; then
        log_success "Cluster started successfully"
        log ""
        log "Cluster Details:"
        log "  Configuration: $TEST_CONFIG"
        log "  VM Pattern:    $TARGET_VM_PATTERN"
        log "  Cluster Name:  $cluster_name"
        log ""
        log "Next steps:"
        log "  1. Deploy registry: $0 deploy-ansible"
        log "  2. Run tests:       $0 run-tests"
        log ""

        # Wait for VMs to be ready
        if ! wait_for_cluster_vms "$TEST_CONFIG" "hpc" "300"; then
            log_warning "VMs may not be fully ready, but continuing..."
        fi

        return 0
    else
        log_error "Failed to start cluster"
        log ""
        log "For manual testing with existing cluster:"
        log "  export TEST_CONTROLLER=your-controller-hostname"
        log "  $0 deploy-ansible"
        log ""
        return 1
    fi
}

# Stop cluster independently
stop_cluster_wrapper() {
    log "Stopping HPC cluster..."

    # Check if cluster is running
    if ! check_cluster_status >/dev/null 2>&1; then
        log_warning "No running cluster found"
        return 0
    fi

    # Use helper function to destroy cluster
    # This handles:
    # - Configuration validation
    # - ai-how command execution with --force flag
    # - Cleanup verification
    # - Logging and error handling
    local cluster_name
    cluster_name=$(basename "${TEST_CONFIG%.yaml}")

    if destroy_cluster "$TEST_CONFIG" "$cluster_name"; then
        log_success "Cluster stopped successfully"
        return 0
    else
        log_error "Failed to stop cluster"
        return 1
    fi
}

# Deploy container registry infrastructure via Ansible
deploy_container_registry() {
    local test_config="$1"

    [[ -z "$test_config" ]] && test_config="$TEST_CONFIG"

    log "Deploying container registry infrastructure (LIVE VM MODE)..."
    log_verbose "Using registry playbook: $REGISTRY_PLAYBOOK"
    log_verbose ""
    log_verbose "Live VM Deployment Behavior:"
    log_verbose "  - packer_build=false (forced)"
    log_verbose "  - Registry directory structure will be CREATED"
    log_verbose "  - Permissions and ownership will be SET"
    log_verbose "  - Cross-node sync will be CONFIGURED"
    log_verbose ""

    # Check if playbook exists
    if [[ ! -f "$REGISTRY_PLAYBOOK" ]]; then
        log_error "Registry playbook not found: $REGISTRY_PLAYBOOK"
        return 1
    fi

    # Use helper function to deploy Ansible playbook
    # This handles:
    # - Dynamic inventory generation from cluster state
    # - SSH connectivity checks
    # - Ansible execution with proper environment
    log_verbose "Calling deploy_ansible_playbook helper function..."
    if deploy_ansible_playbook "$test_config" "$REGISTRY_PLAYBOOK" "all" "$LOG_DIR"; then
        log_success "Container registry infrastructure deployed successfully"
        return 0
    else
        log_error "Failed to deploy container registry infrastructure"
        return 1
    fi
}

# Discover and validate controller VM using yq and generate Ansible inventory
# Parameters:
#   $1: test_config - Path to test configuration YAML file
#   $2: inventory_file - Path where Ansible inventory should be created
discover_and_validate_controller() {
    local test_config="$1"
    local inventory_file="$2"

    [[ -z "$test_config" ]] && {
        log_error "discover_and_validate_controller: test_config parameter required"
        return 1
    }
    [[ -z "$inventory_file" ]] && {
        log_error "discover_and_validate_controller: inventory_file parameter required"
        return 1
    }

    log_verbose "Extracting controller information from: $test_config"

    # Extract controller IP from YAML config using yq
    local controller_ip
    if ! controller_ip=$(yq eval '.clusters.hpc.controller.ip_address' "$test_config" 2>/dev/null); then
        log_error "Failed to extract controller IP from config"
        return 1
    fi

    if [[ -z "$controller_ip" || "$controller_ip" == "null" ]]; then
        log_error "Controller IP not found in config"
        return 1
    fi

    log_verbose "Controller IP from config: $controller_ip"

    # Validate SSH connectivity
    if ! wait_for_vm_ssh "$controller_ip" "controller" "30"; then
        log_error "SSH connectivity failed to controller: $controller_ip"
        return 1
    fi

    # Set environment variables
    TEST_CONTROLLER="${SSH_USER}@${controller_ip}"
    export TEST_CONTROLLER
    export SSH_KEY_PATH

    log_success "Controller validated: $controller_ip"

    # Generate Ansible inventory file
    log_verbose "Generating Ansible inventory: $inventory_file"

    cat > "$inventory_file" << EOF
[hpc_controllers]
controller ansible_host=${controller_ip} ansible_user=${SSH_USER}

[all:vars]
ansible_ssh_private_key_file=${SSH_KEY_PATH}
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

    log_success "Ansible inventory created: $inventory_file"
    return 0
}

# Deploy Ansible independently
deploy_ansible() {
    log "Deploying container registry via Ansible..."

    # Check if cluster is running
    if ! check_cluster_status >/dev/null 2>&1; then
        log_error "No running cluster found. Please start cluster first with: $0 start-cluster"
        log_warning "Or ensure HPC cluster is running and accessible at: $TEST_CONTROLLER"
        return 1
    fi

    # Setup virtual environment
    if ! setup_virtual_environment; then
        log_error "Failed to setup virtual environment"
        return 1
    fi

    # Export virtual environment
    export VIRTUAL_ENV_PATH="$PROJECT_ROOT/.venv"
    export PATH="$VIRTUAL_ENV_PATH/bin:$PATH"
    log "Virtual environment activated for Ansible operations"

    # Deploy container registry
    if deploy_container_registry "$TEST_CONFIG"; then
        log_success "Container registry infrastructure deployed successfully"
        return 0
    else
        log_error "Failed to deploy container registry infrastructure"
        return 1
    fi
}

# Deploy container images to cluster
deploy_images() {
    log "Deploying container images to cluster..."
    log ""

    # Check if cluster is running
    if ! check_cluster_status >/dev/null 2>&1; then
        log_error "No running cluster found or controller not accessible"
        log "Please ensure:"
        log "  1. Cluster is started: $0 start-cluster"
        log "  2. Or TEST_CONTROLLER is set to accessible controller"
        return 1
    fi

    # Auto-discover controller IP if using default hostname
    local controller_target="$TEST_CONTROLLER"
    if [[ "$TEST_CONTROLLER" == "hpc-controller" ]] || [[ "${TEST_CONTROLLER#*@}" == "hpc-controller" ]]; then
        log_verbose "Auto-discovering controller IP from cluster..."

        # Get cluster name from test config
        local cluster_name
        cluster_name=$(basename "${TEST_CONFIG%.yaml}")

        # Try to get controller VM name and IP
        local controller_vm_name="${cluster_name}-controller"
        local controller_ip

        if controller_ip=$(get_vm_ip "$controller_vm_name" 2>/dev/null); then
            log_verbose "Discovered controller IP: $controller_ip"
            controller_target="${SSH_USER}@${controller_ip}"
            log "Using discovered controller: $controller_target"
        else
            log_warning "Could not auto-discover controller IP, using TEST_CONTROLLER: $TEST_CONTROLLER"
            controller_target="$TEST_CONTROLLER"
        fi
    fi

    # Validate controller is set
    if [[ -z "$controller_target" ]]; then
        log_error "TEST_CONTROLLER not set and auto-discovery failed"
        log "Set it with: export TEST_CONTROLLER=admin@<controller-ip>"
        return 1
    fi

    log "Container Image Deployment Workflow:"
    log "  1. Build Docker images"
    log "  2. Convert to Apptainer SIF format"
    log "  3. Deploy to cluster registry"
    log ""

    # Save current directory
    local original_dir
    original_dir=$(pwd)

    # Ensure we're in project root
    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project root: $PROJECT_ROOT"
        return 1
    }

    # Step 1: Configure build system
    log "=========================================="
    log "STEP 1: Configuring Build System"
    log "=========================================="
    local config_cmd="make config"
    log_verbose "Running from $(pwd): $config_cmd"

    if ! $config_cmd 2>&1; then
        local exit_code=$?
        log_error "Failed to configure build system (exit code: $exit_code)"
        log_error "Failed command: $config_cmd"
        log "This may be due to:"
        log "  - CMake not installed in dev container"
        log "  - Missing build dependencies"
        log "  - Configuration errors in CMakeLists.txt"
        log "  - Docker not running or dev container not built"
        log ""
        log "Try:"
        log "  1. Build dev container: make build-docker"
        log "  2. Verify Docker is running: docker ps"
        cd "$original_dir" || true
        return 1
    fi
    log_success "Build system configured"
    echo ""

    # Step 2: Build container images (Docker images)
    log "=========================================="
    log "STEP 2: Building Docker Container Images"
    log "=========================================="
    log "This will build all container images defined in containers/CMakeLists.txt"
    local build_cmd="make run-docker COMMAND='cmake --build build --target build-all-docker-images'"
    log_verbose "Running from $(pwd): $build_cmd"

    if ! eval "$build_cmd" 2>&1; then
        local exit_code=$?
        log_error "Failed to build container images (exit code: $exit_code)"
        log_error "Failed command: $build_cmd"
        log "This may be due to:"
        log "  - Docker not running"
        log "  - Build errors in Dockerfiles"
        log "  - Network issues downloading base images"
        log "  - Insufficient disk space"
        log ""
        log "Check build logs above for details"
        cd "$original_dir" || true
        return 1
    fi
    log_success "Docker container images built successfully"
    echo ""

    # Step 3: Convert to Apptainer SIF format
    log "=========================================="
    log "STEP 3: Converting to Apptainer SIF Format"
    log "=========================================="
    log "Building Apptainer SIF images from Docker images..."
    local convert_cmd="make run-docker COMMAND='cmake --build build --target convert-all-to-apptainer'"
    log_verbose "Running from $(pwd): $convert_cmd"

    if ! eval "$convert_cmd" 2>&1; then
        local exit_code=$?
        log_error "Failed to convert images to SIF format (exit code: $exit_code)"
        log_error "Failed command: $convert_cmd"
        log "This may be due to:"
        log "  - Apptainer not installed in dev container"
        log "  - Insufficient disk space"
        log "  - Docker images not found"
        log "  - Conversion errors (check build logs)"
        log ""
        log "Note: Ensure the dev container has Apptainer installed"
        cd "$original_dir" || true
        return 1
    fi
    log_success "Images converted to SIF format"
    echo ""

    # Verify SIF files exist
    local sif_dir="$PROJECT_ROOT/build/containers/apptainer"
    if [[ ! -d "$sif_dir" ]]; then
        log_warning "Apptainer output directory not found: $sif_dir"
    else
        local sif_count
        sif_count=$(find "$sif_dir" -name "*.sif" -type f 2>/dev/null | wc -l)
        if [[ $sif_count -eq 0 ]]; then
            log_warning "No .sif files found in $sif_dir"
        else
            log "Found $sif_count SIF image(s) ready for deployment"
        fi
    fi
    echo ""

    # Step 4: Deploy to cluster
    log "=========================================="
    log "STEP 4: Deploying Images to Cluster"
    log "=========================================="
    log "Deploying SIF images to cluster registry..."
    log "Target: $controller_target:$REGISTRY_PATH"

    # Use the deploy-all.sh script with proper parameters
    local deploy_script="$PROJECT_ROOT/containers/scripts/deploy-all.sh"
    if [[ ! -x "$deploy_script" ]]; then
        log_error "Deployment script not found or not executable: $deploy_script"
        cd "$original_dir" || true
        return 1
    fi

    # For now, we'll use manual deployment since deploy-all.sh expects a config file
    # and we have controller_target in user@host format
    # Note: Using -rltvz instead of -a to avoid permission/ownership issues with non-root users
    # -r: recursive, -l: copy symlinks as symlinks, -t: preserve timestamps, -v: verbose, -z: compress
    local deploy_cmd="rsync -rltvz --progress -e 'ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no' $sif_dir/*.sif $controller_target:$REGISTRY_PATH/"
    log_verbose "Running: $deploy_cmd"

    if ! eval "$deploy_cmd" 2>&1; then
        local exit_code=$?
        log_error "Failed to deploy images to cluster (exit code: $exit_code)"
        log_error "Failed command: $deploy_cmd"
        log "This may be due to:"
        log "  - SSH connectivity issues"
        log "  - Insufficient permissions on target directory"
        log "  - No SIF images found to deploy"
        log "  - Network issues"
        log ""
        log "Verify:"
        log "  - SSH access: ssh -i $SSH_KEY_PATH $controller_target 'echo OK'"
        log "  - Target directory exists: ssh -i $SSH_KEY_PATH $controller_target 'ls -ld $REGISTRY_PATH'"
        cd "$original_dir" || true
        return 1
    fi
    log_success "Images deployed to cluster successfully"
    echo ""

    # Verify deployment
    log "=========================================="
    log "Verifying Deployment"
    log "=========================================="
    log "Checking deployed images on cluster..."

    local ssh_opts="-i $SSH_KEY_PATH -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

    local deployed_images
    if ! deployed_images=$(ssh "$ssh_opts" "$controller_target" "ls -lh \$REGISTRY_PATH/*.sif 2>/dev/null"); then
        log_warning "Could not list deployed images"
        log_warning "Command failed: ssh $ssh_opts $controller_target 'ls -lh $REGISTRY_PATH/*.sif'"
    elif [[ -z "$deployed_images" ]]; then
        log_warning "No SIF images found in $REGISTRY_PATH"
        log "This might indicate a deployment issue"
        cd "$original_dir" || true
        return 1
    else
        log_success "Deployed images found:"
        # Add leading spaces to each line
        while IFS= read -r line; do echo "  $line"; done <<< "$deployed_images"
        echo ""

        local image_count
        image_count=$(echo "$deployed_images" | wc -l)
        log_success "Total images deployed: $image_count"
    fi

    echo ""
    log_success "Container image deployment completed successfully"
    log ""
    log "Next steps:"
    log "  1. Run tests: $0 run-tests"
    log "  2. Or run specific test phase: $0 run-tests --phase deployment"
    log ""

    # Return to original directory
    cd "$original_dir" || true

    return 0
}

# Run container registry tests on running cluster
run_container_registry_tests() {
    local phase="${1:-all}"

    log "Running container registry tests (Phase: $phase)..."

    # Create inventory directory if it doesn't exist
    mkdir -p "$(dirname "$ANSIBLE_INVENTORY")"

    # Discover and validate controller, generating Ansible inventory
    if ! discover_and_validate_controller "$TEST_CONFIG" "$ANSIBLE_INVENTORY"; then
        log_error "Failed to discover or validate controller"
        log ""
        log "Please ensure:"
        log "  1. Test config exists: $TEST_CONFIG"
        log "  2. Cluster VMs are running and accessible"
        log "  3. Controller IP is correctly configured in: $TEST_CONFIG"
        log ""
        return 1
    fi

    # Export environment variables for test scripts
    export TEST_CONTROLLER
    export SSH_KEY_PATH

    # Run tests based on phase
    local overall_success=true
    local suite1_result="not_run"
    local suite2_result="not_run"
    local suite3_result="not_run"

    case "$phase" in
        infrastructure)
            log "Running Test Suite 1: Ansible Infrastructure Tests..."
            if "$SUITE_1_RUNNER"; then
                log_success "Infrastructure tests passed"
                suite1_result="passed"
            else
                log_error "Infrastructure tests failed"
                suite1_result="failed"
                overall_success=false
            fi
            ;;
        deployment)
            log "Running Test Suite 2: Image Deployment Tests..."
            if "$SUITE_2_RUNNER"; then
                log_success "Deployment tests passed"
                suite2_result="passed"
            else
                log_error "Deployment tests failed"
                suite2_result="failed"
                overall_success=false
            fi
            ;;
        e2e)
            log "Running Test Suite 3: End-to-End Integration Tests..."
            if "$SUITE_3_RUNNER"; then
                log_success "E2E tests passed"
                suite3_result="passed"
            else
                log_error "E2E tests failed"
                suite3_result="failed"
                overall_success=false
            fi
            ;;
        all)
            log "Running all test suites..."

            if "$SUITE_1_RUNNER"; then
                log_success "Test Suite 1 (Infrastructure) passed"
                suite1_result="passed"
            else
                log_error "Test Suite 1 (Infrastructure) failed"
                suite1_result="failed"
                overall_success=false
            fi

            if "$SUITE_2_RUNNER"; then
                log_success "Test Suite 2 (Deployment) passed"
                suite2_result="passed"
            else
                log_error "Test Suite 2 (Deployment) failed"
                suite2_result="failed"
                overall_success=false
            fi

            if "$SUITE_3_RUNNER"; then
                log_success "Test Suite 3 (E2E) passed"
                suite3_result="passed"
            else
                log_error "Test Suite 3 (E2E) failed"
                suite3_result="failed"
                overall_success=false
            fi
            ;;
        *)
            log_error "Invalid test phase: $phase"
            return 1
            ;;
    esac

    # Generate actionable recommendations based on results
    if [[ "$overall_success" == "false" ]]; then
        echo ""
        log "=========================================="
        log "FAILURE ANALYSIS & NEXT STEPS"
        log "=========================================="
        echo ""

        if [[ "$suite1_result" == "failed" ]]; then
            log_error "Test Suite 1 (Infrastructure) Failed"
            echo ""
            echo "This indicates the container registry infrastructure is not properly deployed."
            echo ""
            echo "Next steps:"
            echo "  1. Ensure the cluster is running:"
            echo "     $0 status"
            echo ""
            echo "  2. Deploy the container registry infrastructure:"
            echo "     $0 deploy-ansible"
            echo ""
            echo "  3. Re-run infrastructure tests:"
            echo "     $0 run-tests --phase infrastructure"
            echo ""
        fi

        if [[ "$suite2_result" == "failed" ]]; then
            log_error "Test Suite 2 (Deployment) Failed"
            echo ""
            echo "This indicates container images are not built or deployed to the cluster."
            echo ""
            echo "Next steps:"
            echo "  1. Build container images:"
            echo "     cd containers/"
            echo "     make config"
            echo "     make run-docker COMMAND='cmake --build build --target all'"
            echo ""
            echo "  2. Convert images to Apptainer SIF format:"
            echo "     cd containers/"
            echo "     ./scripts/convert-all.sh"
            echo ""
            echo "  3. Deploy images to cluster:"
            echo "     cd containers/"
            echo "     ./scripts/deploy-to-cluster.sh --controller $TEST_CONTROLLER --registry-path $REGISTRY_PATH"
            echo ""
            echo "  4. Re-run deployment tests:"
            echo "     $0 run-tests --phase deployment"
            echo ""
        fi

        if [[ "$suite3_result" == "failed" ]]; then
            log_error "Test Suite 3 (E2E Integration) Failed"
            echo ""
            echo "This indicates issues with end-to-end container execution."
            echo ""
            echo "Common causes:"
            echo "  - SLURM not running or misconfigured"
            echo "  - Apptainer runtime issues"
            echo "  - Container image compatibility problems"
            echo "  - Resource constraints (GPU, memory, etc.)"
            echo ""
            echo "Next steps:"
            echo "  1. Verify SLURM is running:"
            echo "     ssh $TEST_CONTROLLER 'sinfo -a'"
            echo ""
            echo "  2. Check Apptainer availability:"
            echo "     ssh $TEST_CONTROLLER 'apptainer --version'"
            echo ""
            echo "  3. Review detailed test logs in:"
            echo "     $LOG_DIR"
            echo ""
            echo "  4. Re-run E2E tests with verbose output:"
            echo "     $0 --verbose run-tests --phase e2e"
            echo ""
        fi
    fi

    if [[ "$overall_success" == "true" ]]; then
        log_success "All container registry tests passed successfully"
        return 0
    else
        log_error "Some container registry tests failed"
        echo ""
        log "For more details, review test logs in: $LOG_DIR"
        return 1
    fi
}

# Run tests independently
run_tests() {
    log "Running container registry tests (Phase: $TEST_PHASE)..."

    # Check if registry is deployed (basic check)
    log "Verifying container registry infrastructure..."
    if ssh "$TEST_CONTROLLER" "[ -d /opt/containers ]" 2>/dev/null; then
        log_success "Container registry directory exists"
    else
        log_warning "Container registry may not be deployed"
        log_warning "Deploy first with: $0 deploy-ansible"
    fi

    # Run tests
    if run_container_registry_tests "$TEST_PHASE"; then
        log_success "All tests passed successfully"
        return 0
    else
        log_error "Some tests failed"
        return 1
    fi
}

# List all available test scripts
list_tests() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  Available Test Scripts${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""

    # Test Suite 1: Infrastructure Tests
    echo -e "${GREEN}Test Suite 1: Infrastructure Tests${NC}"
    echo "  Location: tests/suites/container-registry/"
    echo ""
    local suite1_tests
    mapfile -t suite1_tests < <(find "$TESTS_DIR/suites/container-registry" -name "check-*.sh" -type f -executable | sort)
    for test in "${suite1_tests[@]}"; do
        local test_name
        test_name=$(basename "$test")
        local test_desc
        test_desc=$(grep -m1 "^# Test:" "$test" 2>/dev/null | sed 's/^# Test: //' || echo "")
        echo "  • $test_name"
        [[ -n "$test_desc" ]] && echo "    $test_desc"
    done
    echo ""

    # Test Suite 2: Deployment Tests
    echo -e "${GREEN}Test Suite 2: Deployment Tests${NC}"
    echo "  Location: tests/suites/container-deployment/"
    echo ""
    local suite2_tests
    mapfile -t suite2_tests < <(find "$TESTS_DIR/suites/container-deployment" -name "check-*.sh" -type f -executable | sort)
    for test in "${suite2_tests[@]}"; do
        local test_name
        test_name=$(basename "$test")
        local test_desc
        test_desc=$(grep -m1 "^# Test:" "$test" 2>/dev/null | sed 's/^# Test: //' || echo "")
        echo "  • $test_name"
        [[ -n "$test_desc" ]] && echo "    $test_desc"
    done
    echo ""

    # Test Suite 3: E2E Tests
    echo -e "${GREEN}Test Suite 3: End-to-End Integration Tests${NC}"
    echo "  Location: tests/suites/container-e2e/"
    echo ""
    local suite3_tests
    mapfile -t suite3_tests < <(find "$TESTS_DIR/suites/container-e2e" -name "test-*.sh" -type f -executable | sort)
    for test in "${suite3_tests[@]}"; do
        local test_name
        test_name=$(basename "$test")
        local test_desc
        test_desc=$(grep -m1 "^# Test:" "$test" 2>/dev/null | sed 's/^# Test: //' || echo "")
        echo "  • $test_name"
        [[ -n "$test_desc" ]] && echo "    $test_desc"
    done
    echo ""

    echo "Usage:"
    echo "  $0 run-test <test-name>"
    echo ""
    echo "Examples:"
    echo "  $0 run-test check-registry-structure.sh"
    echo "  $0 run-test check-slurm-container-exec.sh"
    echo "  $0 run-test test-pytorch-deployment.sh"
    echo ""
}

# Run a single individual test
run_single_test() {
    local test_name="$1"

    [[ -z "$test_name" ]] && {
        log_error "run_single_test: test_name parameter required"
        log "Use: $0 list-tests to see available tests"
        return 1
    }

    log "Running individual test: $test_name"

    # Validate TEST_CONTROLLER is set
    if [[ -z "$TEST_CONTROLLER" ]]; then
        log_error "TEST_CONTROLLER environment variable not set"
        log "Set it to your cluster controller hostname:"
        log "  export TEST_CONTROLLER=hpc-controller"
        return 1
    fi

    # Find the test script in all test suites
    local test_path=""
    local search_dirs=(
        "$TESTS_DIR/suites/container-registry"
        "$TESTS_DIR/suites/container-deployment"
        "$TESTS_DIR/suites/container-e2e"
    )

    for dir in "${search_dirs[@]}"; do
        if [[ -f "$dir/$test_name" && -x "$dir/$test_name" ]]; then
            test_path="$dir/$test_name"
            break
        fi
    done

    if [[ -z "$test_path" ]]; then
        log_error "Test not found: $test_name"
        log "Available tests:"
        list_tests
        return 1
    fi

    log "Found test: $test_path"
    log "Executing test..."
    echo ""

    # Execute the test
    if "$test_path"; then
        echo ""
        log_success "Test passed: $test_name"
        return 0
    else
        echo ""
        log_error "Test failed: $test_name"
        return 1
    fi
}

# Check cluster status
check_cluster_status() {
    log "Checking cluster status..."

    # Check if VMs are running
    local vms_running
    vms_running=$(virsh list --name 2>/dev/null | grep -c -E "$TARGET_VM_PATTERN" || true)

    if [[ $vms_running -gt 0 ]]; then
        log "Found $vms_running running VMs:"
        virsh list --name 2>/dev/null | grep -E "$TARGET_VM_PATTERN" | while read -r vm; do
            log "  - $vm"
        done
        return 0
    else
        log "No container registry cluster VMs found running"

        # Alternative: check if TEST_CONTROLLER is accessible
        if [[ -n "$TEST_CONTROLLER" ]]; then
            if ssh -o ConnectTimeout=5 -o BatchMode=yes "$TEST_CONTROLLER" "echo 'OK'" >/dev/null 2>&1; then
                log "Controller accessible at: $TEST_CONTROLLER"
                return 0
            fi
        fi

        return 1
    fi
}

# Show cluster status
show_status() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  Cluster Status${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""

    if check_cluster_status; then
        log_success "Cluster is running or controller is accessible"
    else
        log "Cluster is not running or controller not accessible"
    fi

    echo ""
    log "Configuration:"
    log "  Test Controller:  $TEST_CONTROLLER"
    log "  Registry Base:    $REGISTRY_BASE_PATH"
    log "  Registry Path:    $REGISTRY_PATH"
    log "  Test Image:       $TEST_IMAGE"
    echo ""
    log "Test Suites:"
    log "  Infrastructure:   $SUITE_1_RUNNER"
    log "  Deployment:       $SUITE_2_RUNNER"
    log "  End-to-End:       $SUITE_3_RUNNER"
    echo ""
    log "Deployment Mode:"
    log "  - Packer Build: Registry setup SKIPPED (packer_build=true)"
    log "  - Live VM Deploy: Registry setup EXECUTED (packer_build=false)"
    log ""
}

# Main execution function
main() {
    local start_time
    start_time=$(date +%s)

    # Parse command line arguments
    parse_arguments "$@"

    # Configure logging level based on command-line options
    configure_logging_level "$LOG_LEVEL"

    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  $FRAMEWORK_NAME${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""

    log "Logging initialized: $LOG_DIR"
    log_verbose "Log level: $LOG_LEVEL"
    log "$FRAMEWORK_NAME Starting"
    log "Working directory: $PROJECT_ROOT"
    log "Command: $COMMAND"
    [[ "$TEST_PHASE" != "all" ]] && log "Test Phase: $TEST_PHASE"
    echo ""

    # Handle different commands
    case "$COMMAND" in
        "help")
            show_help
            exit 0
            ;;
        "status")
            show_status
            exit 0
            ;;
        "e2e"|"end-to-end")
            # End-to-end test with cleanup
            log "Starting End-to-End Test (with automatic cleanup)"
            log "Configuration:"
            log "  Test Controller: $TEST_CONTROLLER"
            log "  Registry Base: $REGISTRY_BASE_PATH"
            log "  Test Config: $TEST_CONFIG"
            log "  Log directory: $LOG_DIR"
            echo ""

            # Setup virtual environment
            if ! setup_virtual_environment; then
                log_error "Failed to setup virtual environment"
                exit 1
            fi

            export VIRTUAL_ENV_PATH="$PROJECT_ROOT/.venv"
            export PATH="$VIRTUAL_ENV_PATH/bin:$PATH"
            log "Virtual environment activated"
            echo ""

            # Validate files exist
            if [[ ! -f "$TEST_CONFIG" ]]; then
                log_error "Test configuration file not found: $TEST_CONFIG"
                exit 1
            fi

            # Step 1: Start cluster
            log "=========================================="
            log "STEP 1: Starting HPC Cluster"
            log "=========================================="
            if ! start_cluster_wrapper; then
                log_error "Failed to start cluster"
                exit 1
            fi
            echo ""

            # Step 2: Deploy container registry
            log "=========================================="
            log "STEP 2: Deploying Container Registry"
            log "=========================================="
            if ! deploy_ansible; then
                log_error "Failed to deploy container registry"
                # Don't exit - try to continue with tests and cleanup
            fi
            echo ""

            # Step 3: Deploy container images
            log "=========================================="
            log "STEP 3: Deploying Container Images"
            log "=========================================="
            if ! deploy_images; then
                log_error "Failed to deploy container images"
                # Don't exit - try to continue with tests and cleanup
            fi
            echo ""

            # Step 4: Run tests
            log "=========================================="
            log "STEP 4: Running Container Registry Tests"
            log "=========================================="
            local test_result=0
            if ! run_tests; then
                test_result=1
            fi
            echo ""

            # Step 5: Stop cluster (cleanup)
            log "=========================================="
            log "STEP 5: Stopping and Cleaning Up Cluster"
            log "=========================================="
            if ! stop_cluster_wrapper; then
                log_error "Failed to stop cluster cleanly"
                # Continue to report test results even if cleanup failed
            fi
            echo ""

            # Final results
            local end_time
            end_time=$(date +%s)
            local duration=$((end_time - start_time))

            echo ""
            log "=========================================="
            if [[ $test_result -eq 0 ]]; then
                log_success "End-to-End Test: ALL TESTS PASSED"
                log_success "Container Registry Test Framework: ALL TESTS PASSED"
                log_success "Task 021 validation completed successfully"
            else
                log_error "End-to-End Test: SOME TESTS FAILED"
                log_error "Check individual test logs in $LOG_DIR"
            fi
            echo ""
            echo "=========================================="
            echo "$FRAMEWORK_NAME completed at: $(date)"
            echo "Exit code: $test_result"
            echo "Total duration: ${duration}s"
            echo "All logs saved to: $LOG_DIR"
            echo "=========================================="

            exit $test_result
            ;;
        "start-cluster")
            if start_cluster_wrapper; then
                log_success "Cluster started successfully"
                exit 0
            else
                log_error "Failed to start cluster"
                exit 1
            fi
            ;;
        "stop-cluster")
            if stop_cluster_wrapper; then
                log_success "Cluster stopped successfully"
                exit 0
            else
                log_error "Failed to stop cluster"
                exit 1
            fi
            ;;
        "deploy-ansible")
            if deploy_ansible; then
                log_success "Ansible deployment completed successfully"
                log ""
                log "Next step: Deploy container images with: $0 deploy-images"
                exit 0
            else
                log_error "Ansible deployment failed"
                exit 1
            fi
            ;;
        "deploy-images")
            if deploy_images; then
                log_success "Container images deployed successfully"
                exit 0
            else
                log_error "Container image deployment failed"
                exit 1
            fi
            ;;
        "run-tests")
            if run_tests; then
                log_success "Tests completed successfully"
                exit 0
            else
                log_error "Tests failed"
                exit 1
            fi
            ;;
        "list-tests")
            list_tests
            exit 0
            ;;
        "run-test")
            if [[ -z "$TEST_NAME" ]]; then
                log_error "Test name required for run-test command"
                log "Usage: $0 run-test <test-name>"
                log "Use: $0 list-tests to see available tests"
                exit 1
            fi
            if run_single_test "$TEST_NAME"; then
                log_success "Test completed successfully"
                exit 0
            else
                log_error "Test failed"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
