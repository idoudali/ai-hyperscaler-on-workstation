#!/bin/bash
# Container Integration Test Framework (Unified)
# Task 026 - Container Validation Tests
# Test framework for validating PyTorch CUDA, MPI functionality, and GPU access within containers
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

set -euo pipefail

# Help message
show_help() {
    cat << EOF
Container Integration Test Framework - Task 026 Validation

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    e2e, end-to-end   Run complete end-to-end test with cleanup (default behavior)
    start-cluster     Start the HPC cluster independently
    stop-cluster      Stop and destroy the HPC cluster
    deploy-ansible    Deploy container integration validation via Ansible
    run-tests         Run container integration tests on deployed cluster
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
    --controller HOST Test controller hostname (default: hpc-controller)
    --container-image Path to container image (default: pytorch-cuda12.1-mpi4.1.sif)

LOGGING LEVELS:
    quiet             Only show errors and critical messages
    normal            Standard output with key steps and results (default)
    verbose           Detailed output including all operations
    debug             Maximum verbosity for troubleshooting

TEST CATEGORIES:
    - Container Functionality: Basic container execution and environment
    - PyTorch CUDA: PyTorch with CUDA integration and GPU access
    - MPI Communication: MPI multi-process communication
    - Distributed Training: Distributed training environment setup
    - SLURM Integration: SLURM + container + GPU integration

EXAMPLES:
    # Run complete end-to-end test with cleanup (default, recommended for CI/CD)
    $0
    $0 e2e
    $0 end-to-end

    # Modular workflow for debugging (keeps cluster running)
    $0 start-cluster          # Start cluster once
    $0 deploy-ansible         # Deploy validation runtime config
    $0 run-tests              # Run all tests (can repeat)
    $0 stop-cluster           # Clean up when done

    # List and run individual tests
    $0 list-tests             # Show all available test scripts
    $0 run-test check-container-functionality.sh    # Run specific test
    $0 run-test check-pytorch-cuda-integration.sh   # Run another specific test

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
        3. Run tests:         $0 run-tests
        4. Stop cluster:      $0 stop-cluster

CONFIGURATION:
    Test Controller: $TEST_CONTROLLER
    Container Image: $CONTAINER_IMAGE
    Container Runtime: $CONTAINER_RUNTIME

DEPENDENCIES (must be deployed before running):
    - TASK-019: PyTorch Container with CUDA 12.1 + MPI 4.1
    - TASK-020: Docker to Apptainer Conversion
    - TASK-021: Container Registry Infrastructure
    - TASK-022: SLURM Compute Node Installation
    - TASK-023: GPU Resources (GRES) Configuration
    - TASK-024: Cgroup Resource Isolation

NOTES:
    - All prerequisite tasks must be completed before running these tests
    - Container images must be built, converted, and deployed to cluster
    - SLURM must be running with compute nodes registered
    - GPU GRES must be configured (tests will skip GPU tests if unavailable)
    - See docs/CONTAINER-INTEGRATION-TESTING.md for detailed testing guide

EOF
}

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Framework configuration
FRAMEWORK_NAME="Container Integration Test Framework"

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
export TEST_NAME="container-integration"

# shellcheck source=./test-infra/utils/test-framework-utils.sh
source "$UTILS_DIR/test-framework-utils.sh"

# Test configuration
TEST_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/test-container-integration.yaml"
TARGET_VM_PATTERN="test-container-integration"

# Test suite path
TEST_SUITE_RUNNER="$TESTS_DIR/suites/container-integration/run-container-integration-tests.sh"

# Runtime validation playbook
VALIDATION_PLAYBOOK="$PROJECT_ROOT/ansible/playbooks/playbook-container-validation-runtime-config.yml"

# Ansible inventory file (generated dynamically from test config)
ANSIBLE_INVENTORY="$PROJECT_ROOT/tests/test-infra/inventory/container-integration-inventory.ini"

# Test environment
export TEST_CONTROLLER="${TEST_CONTROLLER:-hpc-controller}"
export CONTAINER_IMAGE="${CONTAINER_IMAGE:-/opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif}"
export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-apptainer}"

# Global variables for command line options
export NO_CLEANUP=false
INTERACTIVE=false
COMMAND="e2e"
TEST_NAME=""
LOG_LEVEL="normal"  # quiet, normal, verbose, debug

# Logging level configuration
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
            --controller)
                TEST_CONTROLLER="$2"
                export TEST_CONTROLLER
                shift 2
                ;;
            --container-image)
                CONTAINER_IMAGE="$2"
                export CONTAINER_IMAGE
                shift 2
                ;;
            e2e|end-to-end|start-cluster|stop-cluster|deploy-ansible|run-tests|list-tests|status|help)
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
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "container-integration"

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
    log "Starting HPC cluster for container integration tests..."

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
        log "  1. Deploy validation: $0 deploy-ansible"
        log "  2. Run tests:         $0 run-tests"
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

# Deploy container integration validation via Ansible
deploy_container_validation() {
    local test_config="$1"

    [[ -z "$test_config" ]] && test_config="$TEST_CONFIG"

    log "Deploying container integration validation runtime configuration..."
    log_verbose "Using validation playbook: $VALIDATION_PLAYBOOK"
    log_verbose ""
    log_verbose "Runtime Deployment Behavior:"
    log_verbose "  - packer_build=false (forced)"
    log_verbose "  - Runtime validation tests will be EXECUTED"
    log_verbose "  - Container functionality will be VALIDATED"
    log_verbose "  - PyTorch + CUDA integration will be TESTED"
    log_verbose "  - MPI communication will be VERIFIED"
    log_verbose ""

    # Check if playbook exists
    if [[ ! -f "$VALIDATION_PLAYBOOK" ]]; then
        log_error "Validation playbook not found: $VALIDATION_PLAYBOOK"
        return 1
    fi

    # Use helper function to deploy Ansible playbook
    log_verbose "Calling deploy_ansible_playbook helper function..."
    if deploy_ansible_playbook "$test_config" "$VALIDATION_PLAYBOOK" "all" "$LOG_DIR"; then
        log_success "Container integration validation deployed successfully"
        return 0
    else
        log_error "Failed to deploy container integration validation"
        return 1
    fi
}

# Deploy Ansible independently
deploy_ansible() {
    log "Deploying container integration validation via Ansible..."

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

    # Deploy container validation
    if deploy_container_validation "$TEST_CONFIG"; then
        log_success "Container integration validation deployed successfully"
        return 0
    else
        log_error "Failed to deploy container integration validation"
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

# Run container integration tests on running cluster
run_container_integration_tests() {
    log "Running container integration tests..."

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
        log "Or if using existing cluster:"
        log "  export TEST_CONTROLLER=admin@<controller-ip>"
        log ""
        return 1
    fi

    # Export environment variables for test scripts
    export TEST_CONTROLLER
    export SSH_KEY_PATH
    export CONTAINER_IMAGE
    export CONTAINER_RUNTIME

    # Check if test suite exists
    if [[ ! -f "$TEST_SUITE_RUNNER" ]]; then
        log_error "Test suite runner not found: $TEST_SUITE_RUNNER"
        return 1
    fi

    if [[ ! -x "$TEST_SUITE_RUNNER" ]]; then
        chmod +x "$TEST_SUITE_RUNNER"
    fi

    # Run test suite
    if "$TEST_SUITE_RUNNER"; then
        log_success "All container integration tests passed"
        return 0
    else
        log_error "Some container integration tests failed"
        echo ""
        log "For more details, review test logs in: $LOG_DIR"
        return 1
    fi
}

# Run tests independently
run_tests() {
    log "Running container integration tests..."
    log ""
    log "Pre-flight Checks:"
    log "=================="

    # Check if cluster is running
    if ! check_cluster_status >/dev/null 2>&1; then
        log_warning "No running cluster found via virsh"
        log "Will attempt to use TEST_CONTROLLER if set: ${TEST_CONTROLLER:-not set}"

        # If TEST_CONTROLLER not set, we need the cluster
        if [[ -z "${TEST_CONTROLLER:-}" ]] || [[ "$TEST_CONTROLLER" == "hpc-controller" ]]; then
            log_error "No running cluster found and TEST_CONTROLLER not properly configured"
            log ""
            log "Please either:"
            log "  1. Start cluster first: $0 start-cluster"
            log "  2. Set TEST_CONTROLLER to existing cluster: export TEST_CONTROLLER=admin@<controller-ip>"
            log ""
            return 1
        fi
    fi

    # Run comprehensive tests with controller discovery and validation
    # This will discover controller from config or use TEST_CONTROLLER if set
    if run_container_integration_tests; then
        log ""
        log "=========================================="
        log_success "All container integration tests passed"
        log "=========================================="
        return 0
    else
        log ""
        log "=========================================="
        log_error "Some container integration tests failed"
        log "=========================================="
        log ""
        log "Common issues:"
        log "  - Container image not deployed (run: make test-container-registry-deploy)"
        log "  - SLURM not running (run: make test-slurm-controller-deploy && make test-slurm-compute-deploy)"
        log "  - GPU GRES not configured (run: make test-gpu-gres-deploy)"
        log "  - Network connectivity issues"
        log ""
        log "For detailed logs, check: $LOG_DIR"
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

    echo -e "${GREEN}Container Integration Tests${NC}"
    echo "  Location: tests/suites/container-integration/"
    echo ""

    local suite_dir="$TESTS_DIR/suites/container-integration"
    if [[ -d "$suite_dir" ]]; then
        local test_scripts
        mapfile -t test_scripts < <(find "$suite_dir" -name "check-*.sh" -type f | sort)

        for test in "${test_scripts[@]}"; do
            local test_name
            test_name=$(basename "$test")
            local test_desc
            test_desc=$(grep -m1 "^# Test:" "$test" 2>/dev/null | sed 's/^# Test: //' || echo "")
            echo "  • $test_name"
            [[ -n "$test_desc" ]] && echo "    $test_desc"
        done
    else
        echo "  No test scripts found"
    fi
    echo ""

    echo "Usage:"
    echo "  $0 run-test <test-name>"
    echo ""
    echo "Examples:"
    echo "  $0 run-test check-container-functionality.sh"
    echo "  $0 run-test check-pytorch-cuda-integration.sh"
    echo "  $0 run-test check-mpi-communication.sh"
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

    # Find the test script
    local test_path=""
    local suite_dir="$TESTS_DIR/suites/container-integration"

    if [[ -f "$suite_dir/$test_name" && -x "$suite_dir/$test_name" ]]; then
        test_path="$suite_dir/$test_name"
    fi

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
        log "No container integration cluster VMs found running"

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
    log "  Test Controller:   $TEST_CONTROLLER"
    log "  Container Image:   $CONTAINER_IMAGE"
    log "  Container Runtime: $CONTAINER_RUNTIME"
    echo ""
    log "Test Suite:"
    log "  Runner: $TEST_SUITE_RUNNER"
    echo ""
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
            log "  Container Image: $CONTAINER_IMAGE"
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

            # Step 2: Deploy container validation
            log "=========================================="
            log "STEP 2: Deploying Container Validation"
            log "=========================================="
            if ! deploy_ansible; then
                log_error "Failed to deploy container validation"
                # Don't exit - try to continue with tests and cleanup
            fi
            echo ""

            # Step 3: Run tests
            log "=========================================="
            log "STEP 3: Running Container Integration Tests"
            log "=========================================="
            local test_result=0
            if ! run_tests; then
                test_result=1
            fi
            echo ""

            # Step 4: Stop cluster (cleanup)
            log "=========================================="
            log "STEP 4: Stopping and Cleaning Up Cluster"
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
                log_success "Container Integration Test Framework: ALL TESTS PASSED"
                log_success "Task 026 validation completed successfully"
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
                log "Next step: Run tests with: $0 run-tests"
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
