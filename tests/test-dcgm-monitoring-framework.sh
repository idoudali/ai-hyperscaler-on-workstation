#!/bin/bash
#
# DCGM Monitoring Test Framework (Unified)
# Task 018 - Deploy DCGM GPU Monitoring
# Test framework for validating DCGM GPU monitoring in HPC images
#

set -euo pipefail

# Help message
show_help() {
    cat << EOF
DCGM Monitoring Test Framework - Task 018 Validation

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    start-cluster     Start the HPC cluster independently
    stop-cluster      Stop and destroy the HPC cluster
    deploy-ansible    Deploy DCGM monitoring via Ansible (assumes cluster is running)
    run-tests         Run DCGM monitoring tests on deployed cluster
    full-test         Run complete test suite (default behavior)
    status            Show cluster status
    help              Show this help message

OPTIONS:
    -h, --help        Show this help message
    -v, --verbose     Enable verbose output
    --no-cleanup      Skip cleanup after test completion
    --interactive     Enable interactive cleanup prompts

EXAMPLES:
    # Run complete test suite (default)
    $0

    # Start cluster independently
    $0 start-cluster

    # Deploy Ansible on running cluster
    $0 deploy-ansible

    # Run tests on deployed cluster
    $0 run-tests

    # Stop cluster
    $0 stop-cluster

    # Check cluster status
    $0 status

WORKFLOW:
    1. Start cluster:     $0 start-cluster
    2. Deploy Ansible:    $0 deploy-ansible
    3. Run tests:         $0 run-tests
    4. Stop cluster:      $0 stop-cluster

CONFIGURATION:
    Test Config: $TEST_CONFIG
    Log Directory: logs/dcgm-monitoring-test-run-*
    VM Pattern: $TARGET_VM_PATTERN

NOTES:
    - During Packer builds: Services installed but NOT started (packer_build=true)
    - During runtime (this script): Services started and verified (packer_build=false)
    - See docs/DCGM-PACKER-WORKFLOW.md for detailed workflow documentation

EOF
}

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Framework configuration
FRAMEWORK_NAME="DCGM Monitoring Test Framework"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Validate PROJECT_ROOT before setting up environment variables
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

# Set up environment variables for shared utilities AFTER validation
export PROJECT_ROOT
export TESTS_DIR="$PROJECT_ROOT/tests"
export SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
export SSH_USER="admin"
export CLEANUP_REQUIRED=false
export INTERACTIVE_CLEANUP=false
export TEST_NAME="dcgm-monitoring"

# shellcheck source=./test-infra/utils/test-framework-utils.sh
source "$UTILS_DIR/test-framework-utils.sh"

# Test configuration
TEST_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/test-dcgm-monitoring.yaml"
TEST_SCRIPTS_DIR="$PROJECT_ROOT/tests/suites/dcgm-monitoring"
TARGET_VM_PATTERN="test-dcgm-monitoring-compute"
MASTER_TEST_SCRIPT="run-dcgm-monitoring-tests.sh"

# Runtime Ansible playbook (forces packer_build=false mode)
RUNTIME_PLAYBOOK="$PROJECT_ROOT/ansible/playbooks/playbook-dcgm-runtime-config.yml"

# Global variables for command line options
INTERACTIVE=false
COMMAND="full-test"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                # VERBOSE flag is handled by the calling script
                shift
                ;;
            --no-cleanup)
                # NO_CLEANUP flag is handled by the calling script
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            start-cluster|stop-cluster|deploy-ansible|run-tests|full-test|status|help)
                COMMAND="$1"
                shift
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
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "dcgm-monitoring"

# Setup virtual environment for Ansible
setup_virtual_environment() {
    log "Setting up virtual environment for Ansible dependencies..."

    # Check if virtual environment exists and has Ansible
    if [[ -f "$PROJECT_ROOT/.venv/bin/activate" ]]; then
        log "Virtual environment exists, checking Ansible availability..."
        if source "$PROJECT_ROOT/.venv/bin/activate" && python3 -c "from ansible.cli.playbook import main" >/dev/null 2>&1; then
            log_success "Virtual environment with Ansible is ready"
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
start_cluster() {
    log "Starting HPC cluster for DCGM monitoring tests..."

    # Check if cluster is already running
    if check_cluster_status >/dev/null 2>&1; then
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

    # Change to project root before running ai-how
    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project root: $PROJECT_ROOT"
        return 1
    }

    # Start cluster using ai-how
    log "Executing: uv run ai-how hpc start $TEST_CONFIG"
    if uv run ai-how hpc start "$TEST_CONFIG"; then
        log_success "Cluster started successfully"
        log "Cluster configuration: $TEST_CONFIG"
        log "VM Pattern: $TARGET_VM_PATTERN"
        log ""
        log "Note: Cluster created from Packer images with services enabled but not started"
        log "      Use 'deploy-ansible' command to apply runtime configuration"
        return 0
    else
        log_error "Failed to start cluster"
        return 1
    fi
}

# Stop cluster independently
stop_cluster() {
    log "Stopping HPC cluster..."

    # Check if cluster is running
    if ! check_cluster_status >/dev/null 2>&1; then
        log_warning "No running cluster found"
        return 0
    fi

    # Change to project root before running ai-how
    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project root: $PROJECT_ROOT"
        return 1
    }

    # Stop cluster using ai-how
    log "Executing: uv run ai-how hpc destroy $TEST_CONFIG --force"
    if uv run ai-how hpc destroy "$TEST_CONFIG" --force; then
        log_success "Cluster stopped successfully"
        return 0
    else
        log_error "Failed to stop cluster"
        return 1
    fi
}

# Deploy DCGM monitoring on running cluster (runtime configuration)
deploy_dcgm_monitoring() {
    local test_config="$1"

    [[ -z "$test_config" ]] && {
        log_error "deploy_dcgm_monitoring: test_config parameter required"
        return 1
    }

    log "Deploying DCGM monitoring on running cluster (RUNTIME MODE)..."
    log "Using runtime playbook: $RUNTIME_PLAYBOOK"
    log ""
    log "Runtime Mode Behavior:"
    log "  - packer_build=false (forced)"
    log "  - Services will be STARTED"
    log "  - Service status will be VERIFIED"
    log "  - GPU functionality will be TESTED"
    log ""

    # Check if runtime playbook exists
    if [[ ! -f "$RUNTIME_PLAYBOOK" ]]; then
        log_error "Runtime playbook not found: $RUNTIME_PLAYBOOK"
        return 1
    fi

    # Extract cluster name (for logging purposes)
    if ! parse_cluster_name "$test_config" "$LOG_DIR" "hpc" >/dev/null; then
        log_warning "Failed to extract cluster name using ai-how API, falling back to filename"
        # cluster_name=$(basename "${test_config%.yaml}")  # Not used, but kept for reference
    fi

    # Get VMs for dynamic inventory (using legacy method due to ai-how API bug)
    if ! get_vm_ips_for_cluster_legacy "test-dcgm-monitoring" "$TARGET_VM_PATTERN"; then
        log_error "Failed to get VM IP addresses for cluster"
        return 1
    fi

    # Generate dynamic inventory for Ansible
    local inventory_file="/tmp/dcgm-monitoring-inventory-$$.yml"
    log "Generating dynamic inventory: $inventory_file"

    cat > "$inventory_file" << 'EOF'
all:
  hosts:
EOF

    for i in "${!VM_IPS[@]}"; do
        local vm_ip="${VM_IPS[$i]}"
        local vm_name="${VM_NAMES[$i]}"
        log "  Adding host: $vm_name ($vm_ip)"

        cat >> "$inventory_file" << EOF
    $vm_name:
      ansible_host: $vm_ip
      ansible_user: $SSH_USER
      ansible_ssh_private_key_file: $SSH_KEY_PATH
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF
    done

    # Wait for SSH on all VMs
    log "Waiting for SSH connectivity..."
    for i in "${!VM_IPS[@]}"; do
        local vm_ip="${VM_IPS[$i]}"
        local vm_name="${VM_NAMES[$i]}"
        if ! wait_for_vm_ssh "$vm_ip" "$vm_name"; then
            log_error "SSH connectivity failed for $vm_name"
            rm -f "$inventory_file"
            return 1
        fi
    done

    # Run Ansible playbook
    log "Running Ansible playbook with runtime configuration..."
    local ansible_cmd="ansible-playbook -i $inventory_file playbooks/playbook-dcgm-runtime-config.yml"
    [[ "${VERBOSE:-false}" == "true" ]] && ansible_cmd="$ansible_cmd -vv"

    # Change to ansible directory to find roles
    cd "$PROJECT_ROOT/ansible" || {
        log_error "Failed to change to ansible directory"
        rm -f "$inventory_file"
        return 1
    }

    if eval "$ansible_cmd"; then
        log_success "DCGM monitoring deployed successfully in runtime mode"
        rm -f "$inventory_file"
        return 0
    else
        log_error "Failed to deploy DCGM monitoring"
        rm -f "$inventory_file"
        return 1
    fi
}

# Deploy Ansible independently
deploy_ansible() {
    log "Deploying DCGM monitoring via Ansible (Runtime Configuration)..."

    # Check if cluster is running
    if ! check_cluster_status >/dev/null 2>&1; then
        log_error "No running cluster found. Please start cluster first with: $0 start-cluster"
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

    # Deploy DCGM monitoring using local function
    log "Deploying DCGM monitoring on running cluster..."
    if deploy_dcgm_monitoring "$TEST_CONFIG"; then
        log_success "DCGM monitoring deployed successfully"
        return 0
    else
        log_error "Failed to deploy DCGM monitoring"
        return 1
    fi
}

# Run DCGM tests on running cluster
run_dcgm_tests() {
    local test_config="$1"
    local test_scripts_dir="$2"
    local target_vm_pattern="$3"
    local master_test_script="$4"

    [[ -z "$test_config" ]] && {
        log_error "run_dcgm_tests: test_config parameter required"
        return 1
    }
    [[ -z "$test_scripts_dir" ]] && {
        log_error "run_dcgm_tests: test_scripts_dir parameter required"
        return 1
    }
    [[ ! -d "$test_scripts_dir" ]] && {
        log_error "Test scripts directory not found: $test_scripts_dir"
        return 1
    }

    log "Running DCGM monitoring tests on running cluster..."

    # Extract cluster name (for logging purposes)
    if ! parse_cluster_name "$test_config" "$LOG_DIR" "hpc" >/dev/null; then
        log_warning "Failed to extract cluster name using ai-how API, falling back to filename"
        # cluster_name=$(basename "${test_config%.yaml}")  # Not used, but kept for reference
    fi

    # Get VM IPs for the cluster (using legacy method due to ai-how API bug)
    if ! get_vm_ips_for_cluster_legacy "test-dcgm-monitoring" "$target_vm_pattern"; then
        log_error "Failed to get VM IP addresses for cluster"
        return 1
    fi

    # Run tests on each VM
    local overall_success=true

    for i in "${!VM_IPS[@]}"; do
        local vm_ip="${VM_IPS[$i]}"
        local vm_name="${VM_NAMES[$i]}"

        log "Testing VM: $vm_name ($vm_ip)"

        # Wait for SSH
        if ! wait_for_vm_ssh "$vm_ip" "$vm_name"; then
            log_error "SSH connectivity failed for $vm_name"
            overall_success=false
            continue
        fi

        # Upload test scripts
        if ! upload_scripts_to_vm "$vm_ip" "$vm_name" "$test_scripts_dir"; then
            log_error "Failed to upload test scripts to $vm_name"
            overall_success=false
            continue
        fi

        # Run tests
        if ! execute_script_on_vm "$vm_ip" "$vm_name" "$master_test_script"; then
            log_warning "Tests failed on $vm_name"
            overall_success=false
        fi
    done

    if [[ "$overall_success" == "true" ]]; then
        log_success "All DCGM monitoring tests passed successfully"
        return 0
    else
        log_error "Some DCGM monitoring tests failed"
        return 1
    fi
}

# Run tests independently
run_tests() {
    log "Running DCGM monitoring tests..."

    # Check if cluster is running
    if ! check_cluster_status >/dev/null 2>&1; then
        log_error "No running cluster found. Please start cluster first with: $0 start-cluster"
        return 1
    fi

    # Run tests using local function
    log "Executing DCGM monitoring tests on running cluster..."
    if run_dcgm_tests "$TEST_CONFIG" "$TEST_SCRIPTS_DIR" "$TARGET_VM_PATTERN" "$MASTER_TEST_SCRIPT"; then
        log_success "All tests passed successfully"
        return 0
    else
        log_error "Some tests failed"
        return 1
    fi
}

# Check cluster status
check_cluster_status() {
    log "Checking cluster status..."

    # Check if VMs are running
    local vms_running
    vms_running=$(virsh list --name | grep -c -E "test-dcgm-monitoring-(controller|compute)" || true)

    if [[ $vms_running -gt 0 ]]; then
        log "Found $vms_running running VMs:"
        virsh list --name | grep -E "test-dcgm-monitoring-(controller|compute)" | while read -r vm; do
            log "  - $vm"
        done
        return 0
    else
        log "No DCGM monitoring cluster VMs found running"
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
        log_success "Cluster is running"
    else
        log "Cluster is not running"
    fi

    echo ""
    log "Configuration: $TEST_CONFIG"
    log "VM Pattern: $TARGET_VM_PATTERN"
    log "Test Scripts: $TEST_SCRIPTS_DIR"
    log "Runtime Playbook: $RUNTIME_PLAYBOOK"
    echo ""
    log "Deployment Mode Information:"
    log "  - Packer Build: Services enabled, NOT started (packer_build=true)"
    log "  - Runtime Deploy: Services started and verified (packer_build=false)"
    log ""
}

# Main execution function
main() {
    local start_time
    start_time=$(date +%s)

    # Parse command line arguments
    parse_arguments "$@"

    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  $FRAMEWORK_NAME${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""

    log "Logging initialized: $LOG_DIR"
    log "$FRAMEWORK_NAME Starting"
    log "Working directory: $PROJECT_ROOT"
    log "Command: $COMMAND"
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
        "start-cluster")
            if start_cluster; then
                log_success "Cluster started successfully"
                exit 0
            else
                log_error "Failed to start cluster"
                exit 1
            fi
            ;;
        "stop-cluster")
            if stop_cluster; then
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
                exit 0
            else
                log_error "Ansible deployment failed"
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
        "full-test")
            # Original full test behavior
            log "Starting DCGM Monitoring Test Framework (Task 018 Validation)"
            log "Configuration: $TEST_CONFIG"
            log "Target VM Pattern: $TARGET_VM_PATTERN"
            log "Test Scripts Directory: $TEST_SCRIPTS_DIR"
            log "Runtime Playbook: $RUNTIME_PLAYBOOK"
            log "Log directory: $LOG_DIR"
            echo ""

            # Setup virtual environment for Ansible
            if ! setup_virtual_environment; then
                log_error "Failed to setup virtual environment"
                exit 1
            fi

            # Export virtual environment for use in shared utilities
            export VIRTUAL_ENV_PATH="$PROJECT_ROOT/.venv"
            export PATH="$VIRTUAL_ENV_PATH/bin:$PATH"
            log "Virtual environment activated for Ansible operations"
            echo ""

            # Validate configuration files exist
            if [[ ! -f "$TEST_CONFIG" ]]; then
                log_error "Test configuration file not found: $TEST_CONFIG"
                exit 1
            fi

            if [[ ! -d "$TEST_SCRIPTS_DIR" ]]; then
                log_error "Test scripts directory not found: $TEST_SCRIPTS_DIR"
                exit 1
            fi

            if [[ ! -f "$RUNTIME_PLAYBOOK" ]]; then
                log_error "Runtime playbook not found: $RUNTIME_PLAYBOOK"
                exit 1
            fi

            # Check if controller and compute images exist (optional warning)
            local controller_image_path="$PROJECT_ROOT/build/packer/hpc-controller/hpc-controller/hpc-controller.qcow2"
            if [[ ! -f "$controller_image_path" ]]; then
                log_warning "HPC controller image not found at: $controller_image_path"
                log_warning "You may need to build the controller image first: make build-hpc-controller-image"
            fi

            local compute_image_path="$PROJECT_ROOT/build/packer/hpc-compute/hpc-compute/hpc-compute.qcow2"
            if [[ ! -f "$compute_image_path" ]]; then
                log_warning "HPC compute image not found at: $compute_image_path"
                log_warning "You may need to build the compute image first: make build-hpc-compute-image"
            fi

            # Step 1: Start cluster
            log "=========================================="
            log "STEP 1: Starting HPC Cluster"
            log "=========================================="
            if ! start_cluster; then
                log_error "Failed to start cluster"
                exit 1
            fi
            echo ""

            # Step 2: Deploy DCGM monitoring (runtime configuration)
            log "=========================================="
            log "STEP 2: Deploying DCGM Monitoring (Runtime Mode)"
            log "=========================================="
            if ! deploy_dcgm_monitoring "$TEST_CONFIG"; then
                log_error "Failed to deploy DCGM monitoring"
                # Don't exit - try to run tests anyway
            fi
            echo ""

            # Step 3: Run tests
            log "=========================================="
            log "STEP 3: Running DCGM Monitoring Tests"
            log "=========================================="
            local test_result=0
            if ! run_dcgm_tests "$TEST_CONFIG" "$TEST_SCRIPTS_DIR" "$TARGET_VM_PATTERN" "$MASTER_TEST_SCRIPT"; then
                test_result=1
            fi
            echo ""

            # Final results
            local end_time
            end_time=$(date +%s)
            local duration=$((end_time - start_time))

            echo ""
            log "=========================================="
            if [[ $test_result -eq 0 ]]; then
                log_success "Test Framework: ALL TESTS PASSED"
                log_success "DCGM Monitoring Test Framework: ALL TESTS PASSED"
                log_success "Task 018 validation completed successfully"
            else
                log_error "Test Framework: SOME TESTS FAILED"
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
        *)
            log_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
