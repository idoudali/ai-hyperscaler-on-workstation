#!/bin/bash
#
# Container Integration Test Suite Master Runner
# Orchestrates all container integration validation tests
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Resolve script and common utility directories (preserve this script's path)
SUITE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SUITE_SCRIPT_DIR/../common" && pwd)"
PROJECT_ROOT="$(cd "$SUITE_SCRIPT_DIR/../../.." && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "${COMMON_DIR}/suite-utils.sh"
# shellcheck source=/dev/null
source "${COMMON_DIR}/suite-logging.sh"
# shellcheck source=/dev/null
source "${COMMON_DIR}/suite-test-runner.sh"

# Also source test-infra utilities for VM discovery
UTILS_DIR="$PROJECT_ROOT/tests/test-infra/utils"
if [ -f "$UTILS_DIR/log-utils.sh" ]; then
    # shellcheck source=/dev/null
    source "$UTILS_DIR/log-utils.sh"
fi
if [ -f "$UTILS_DIR/vm-utils.sh" ]; then
    # shellcheck source=/dev/null
    source "$UTILS_DIR/vm-utils.sh"
fi

# Script configuration
SCRIPT_NAME="run-container-integration-tests.sh"
TEST_SUITE_NAME="Container Integration Test Suite"
SCRIPT_DIR="$SUITE_SCRIPT_DIR"
TEST_SUITE_DIR="$SUITE_SCRIPT_DIR"
export SCRIPT_DIR
export TEST_SUITE_DIR
export PROJECT_ROOT

# Configure logging directories
: "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME%.sh}.log"
touch "$LOG_FILE"

# Initialize suite logging and test runner
init_suite_logging "$TEST_SUITE_NAME"
init_test_runner

# Test configuration
TEST_CONFIG="${TEST_CONFIG:-$PROJECT_ROOT/tests/test-infra/configs/test-container-integration.yaml}"
ANSIBLE_INVENTORY="$PROJECT_ROOT/tests/test-infra/inventory/container-integration-inventory.ini"
SSH_KEY_PATH="${SSH_KEY_PATH:-$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
SSH_USER="${SSH_USER:-admin}"

# Container configuration
export CONTAINER_IMAGE="${CONTAINER_IMAGE:-/opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif}"
export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-apptainer}"

# Test scripts for Container Integration validation
TEST_SCRIPTS=(
    "check-container-functionality.sh"
    "check-pytorch-cuda-integration.sh"
    "check-mpi-communication.sh"
    "check-distributed-training.sh"
    "check-container-slurm-integration.sh"
)

# Discover and validate controller
discover_and_validate_controller() {
    local test_config="$1"
    local inventory_file="$2"

    [[ -z "$test_config" ]] && log_error "test_config parameter required" && return 1
    [[ -z "$inventory_file" ]] && log_error "inventory_file parameter required" && return 1

    log_info "Extracting controller information from: $test_config"

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

    log_info "Controller IP from config: $controller_ip"

    # Validate SSH connectivity
    if ! wait_for_node_ssh "$controller_ip"; then
        log_error "SSH connectivity failed to controller: $controller_ip"
        return 1
    fi

    # Set environment variables
    TEST_CONTROLLER="${SSH_USER}@${controller_ip}"
    export TEST_CONTROLLER
    export SSH_KEY_PATH

    log_success "✓ Controller validated: $controller_ip"

    # Generate Ansible inventory file
    mkdir -p "$(dirname "$inventory_file")"

    cat > "$inventory_file" << EOF
[hpc_controllers]
controller ansible_host=${controller_ip} ansible_user=${SSH_USER}

[all:vars]
ansible_ssh_private_key_file=${SSH_KEY_PATH}
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

    log_success "✓ Ansible inventory created: $inventory_file"
    return 0
}

# Check container image availability
check_container_availability() {
    log_info "Checking container image availability..."
    local ssh_opts=(-o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes)

    if [[ -f "$SSH_KEY_PATH" ]]; then
        if ssh -i "$SSH_KEY_PATH" "${ssh_opts[@]}" "$TEST_CONTROLLER" "[ -f '$CONTAINER_IMAGE' ]" 2>/dev/null; then
            log_success "✓ Container image exists: $CONTAINER_IMAGE"
            return 0
        else
            log_error "✗ Container image not found: $CONTAINER_IMAGE"
            log_error ""
            log_error "Container image must be deployed before running integration tests"
            log_error ""
            log_info "Quick deployment (recommended):"
            log_info "  cd tests && make test-container-registry-deploy"
            return 1
        fi
    else
        log_error "✗ SSH key not found: $SSH_KEY_PATH"
        return 1
    fi
}

# Check SLURM availability
check_slurm_availability() {
    log_info "Checking SLURM availability..."
    local ssh_opts=(-o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes)

    if ssh -i "$SSH_KEY_PATH" "${ssh_opts[@]}" "$TEST_CONTROLLER" "sinfo --version >/dev/null 2>&1" 2>/dev/null; then
        log_success "✓ SLURM is running"
        return 0
    else
        log_warn "✗ SLURM is not running or not accessible"
        log_info ""
        log_warn "WARNING: Some integration tests may fail without SLURM"
        log_info "SLURM deployment:"
        log_info "  1. Deploy controller: cd tests && make test-slurm-controller-deploy"
        log_info "  2. Deploy compute nodes: cd tests && make test-slurm-compute-deploy"
        log_info ""
        log_info "Continuing with tests (some may be skipped)..."
        return 0  # Don't fail - continue with tests
    fi
}

# Cleanup functions
cleanup_test_environment() {
    log_debug "Cleaning up test environment..."
    # No specific cleanup needed for container integration tests
    log_debug "Test environment cleanup completed"
}

# Main execution function
main() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $TEST_SUITE_NAME${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    log_info "Pre-flight Checks:"
    echo ""

    # Discover and validate controller (generates inventory file)
    log_info "• Discovering controller and generating Ansible inventory..."
    if ! discover_and_validate_controller "$TEST_CONFIG" "$ANSIBLE_INVENTORY"; then
        log_error "ERROR: Failed to discover or validate controller"
        echo ""
        log_info "Please ensure:"
        log_info "  1. Test config exists: $TEST_CONFIG"
        log_info "  2. Cluster VMs are running and accessible"
        log_info "  3. Controller IP is correctly configured in: $TEST_CONFIG"
        echo ""
        log_info "Required infrastructure must be deployed:"
        log_info "  - TASK-019: PyTorch Container built"
        log_info "  - TASK-020: Container converted to Apptainer"
        log_info "  - TASK-021: Container Registry deployed"
        log_info "  - TASK-022: SLURM Compute Nodes installed"
        log_info "  - TASK-023: GPU GRES configured"
        log_info "  - TASK-024: Cgroup isolation active"
        exit 1
    fi
    echo ""

    log_info "Test Controller: $TEST_CONTROLLER"
    log_info "Container Image: $CONTAINER_IMAGE"
    log_info "Container Runtime: $CONTAINER_RUNTIME"
    log_info "Ansible Inventory: $ANSIBLE_INVENTORY"
    log_info "Test Scripts: ${#TEST_SCRIPTS[@]}"
    echo ""

    # Check if container image exists
    if ! check_container_availability; then
        exit 1
    fi
    echo ""

    # Check if SLURM is running
    check_slurm_availability
    echo ""

    log_success "Pre-flight checks complete. Starting tests..."
    echo ""

    # Run each test script
    for script in "${TEST_SCRIPTS[@]}"; do
        run_test_script "$script"
    done

    # Cleanup
    cleanup_test_environment

    # Print test summary
    print_test_summary
    local test_result=$?

    # Exit with result from summary
    exit $test_result
}

# Handle script interruption
trap cleanup_test_environment EXIT

# Parse command line arguments
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Enable verbose output"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  LOG_DIR                    Directory for test logs (default: ./logs/run-YYYY-MM-DD_HH-MM-SS)"
            echo "  TEST_CONFIG                Path to test configuration file"
            echo "  SSH_KEY_PATH               Path to SSH key (default: build/shared/ssh-keys/id_rsa)"
            echo "  SSH_USER                   SSH user (default: admin)"
            echo "  CONTAINER_IMAGE            Path to container image"
            echo "  CONTAINER_RUNTIME          Container runtime (default: apptainer)"
            echo ""
            echo "Test Scripts:"
            for script in "${TEST_SCRIPTS[@]}"; do
                echo "  - $script"
            done
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Enable verbose mode if requested
if [ "$VERBOSE" = true ]; then
    set -x
    log_debug "Verbose mode enabled"
fi

# Execute main function
main "$@"
