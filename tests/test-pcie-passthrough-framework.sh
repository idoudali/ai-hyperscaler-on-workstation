#!/bin/bash
#
# PCIe Passthrough Test Framework
# Automated testing framework for GPU passthrough using ai-how tooling
#

set -euo pipefail

# PS4 customizes the debug output format for Bash's 'set -x' (execution tracing).
# To use this format, enable debug mode by running: 'set -x' before executing the script,
# or set the environment variable 'BASH_ENV' to source this script with 'set -x'.
PS4='+ [${BASH_SOURCE[0]}:L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/..")"
TESTS_DIR="$PROJECT_ROOT/tests"
TEST_CONFIG="test-infra/configs/test-pcie-passthrough-minimal.yaml"
TEST_SCRIPTS_DIR="$(realpath "$SCRIPT_DIR/suites/gpu-validation")"
# Create unique log directory per run
RUN_TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_DIR="$(realpath "$SCRIPT_DIR")/logs/test-pcie-passthrough-run-$RUN_TIMESTAMP"
SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
SSH_USER="admin"  # Adjust based on your base image
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# Target VM configuration - only test the GPU-enabled compute node
TARGET_VM_NAME="test-hpc-pcie-minimal-compute-01"

# Timeouts (in seconds) - handled by framework utilities

# Source shared utilities
UTILS_DIR="$PROJECT_ROOT/tests/test-infra/utils"
if [[ -f "$UTILS_DIR/test-framework-utils.sh" ]]; then
    # shellcheck source=test-infra/utils/test-framework-utils.sh
    source "$UTILS_DIR/test-framework-utils.sh"
else
    echo "Error: Shared test framework utilities not found"
    echo "Expected: $UTILS_DIR/test-framework-utils.sh"
    exit 1
fi

# Export configuration for shared utilities
export PROJECT_ROOT TESTS_DIR LOG_DIR SSH_KEY_PATH SSH_USER SSH_OPTS
export CLEANUP_REQUIRED=false INTERACTIVE_CLEANUP=false

# =============================================================================
# PCIe Passthrough Specific Functions (using shared utilities)
# =============================================================================

# Logging functions are now provided by shared utilities (log-utils.sh)
# Available functions: log(), log_success(), log_warning(), log_error(), log_info(), log_verbose()

# Cleanup functions are now provided by shared utilities (cluster-utils.sh, test-framework-utils.sh)
# Available functions: cleanup_cluster_on_exit(), cleanup_test_framework(), ask_manual_cleanup(), manual_cluster_cleanup()

# =============================================================================
# Core Functions
# =============================================================================

# Prerequisites check function is now provided by shared utilities (test-framework-utils.sh)
# Use: check_test_prerequisites "$TESTS_DIR/$TEST_CONFIG" "$TEST_SCRIPTS_DIR"

# VM running check function is now provided by shared utilities (cluster-utils.sh)
# Use: check_cluster_not_running "$TARGET_VM_NAME"

# Cluster management functions are now provided by shared utilities (cluster-utils.sh)
# Use: start_cluster "$TEST_CONFIG" "$cluster_name"

# VM waiting functions are now provided by shared utilities (cluster-utils.sh)
# Use: wait_for_cluster_vms "$TARGET_VM_NAME"

# VM connection info functions are now provided by shared utilities (vm-utils.sh)
# Use: save_vm_connection_info "$cluster_name" (automatically called by get_vm_ips_for_cluster)

# VM IP discovery functions are now provided by shared utilities (vm-utils.sh)
# Use: get_vm_ips_for_cluster "$cluster_pattern" "$target_vm_name"

# SSH waiting functions are now provided by shared utilities (vm-utils.sh)
# Use: wait_for_vm_ssh "$vm_ip" "$vm_name" "$timeout"

# Script upload functions are now provided by shared utilities (vm-utils.sh)
# Use: upload_scripts_to_vm "$vm_ip" "$vm_name" "$scripts_dir" "$remote_dir"

# Script execution functions are now provided by shared utilities (vm-utils.sh)
# Use: execute_script_on_vm "$vm_ip" "$vm_name" "$script_name" "$remote_dir" "$extra_args"

# Cluster teardown functions are now provided by shared utilities (cluster-utils.sh)
# Use: destroy_cluster "$TEST_CONFIG" "$cluster_name" "$force_flag"

# Cleanup verification functions are now provided by shared utilities (cluster-utils.sh)
# Use: verify_cluster_cleanup "$cluster_pattern"

# =============================================================================
# Main Test Execution
# =============================================================================

# Simplified GPU passthrough test execution using shared framework
run_gpu_passthrough_tests() {
    log "Starting PCIe Passthrough Test Framework"
    log "Configuration: $TEST_CONFIG"
    log "Target VM: $TARGET_VM_NAME"
    log "Test Scripts Directory: $TEST_SCRIPTS_DIR"
    log "Log directory: $LOG_DIR"
    echo

    # Initialize the shared framework
    init_logging "$RUN_TIMESTAMP" "tests/logs"

    # Use the shared test framework with specific target VM
    if run_test_framework "$TESTS_DIR/$TEST_CONFIG" "$TEST_SCRIPTS_DIR" "$TARGET_VM_NAME" "run-all-tests.sh"; then
        log_success "PCIe Passthrough Test Framework: ALL TESTS PASSED"
        log_success "GPU passthrough is working correctly on target VM ($TARGET_VM_NAME)"
        return 0
    else
        log_warning "PCIe Passthrough Test Framework: TESTS FAILED"
        log_warning "GPU passthrough failed on target VM ($TARGET_VM_NAME)"
        log_warning "Check test logs in $LOG_DIR"
        return 1
    fi
}

# Legacy function name for backwards compatibility
run_full_test() {
    run_gpu_passthrough_tests
}

# =============================================================================
# CLI Interface
# =============================================================================

show_usage() {
    cat << EOF
PCIe Passthrough Test Framework

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --help, -h          Show this help message
    --config CONFIG     Use specific test configuration (default: $TEST_CONFIG)
    --ssh-user USER     SSH username (default: $SSH_USER)
    --ssh-key KEY       SSH key path (default: $SSH_KEY_PATH)
    --target-vm NAME    Target VM name to test (default: $TARGET_VM_NAME)
    --no-cleanup        Don't cleanup on failure (for debugging)
    --verbose, -v       Enable verbose output

EXAMPLES:
    # Run with default configuration
    $0

    # Run with custom configuration
    $0 --config test-infra/configs/test-full-stack.yaml

    # Run with custom SSH settings
    $0 --ssh-user root --ssh-key ~/.ssh/test_key

    # Run with different target VM
    $0 --target-vm my-custom-compute-node

    # Run without cleanup on failure (for debugging)
    $0 --no-cleanup

PREREQUISITES:
    - ai-how tool installed and working
    - virsh command available
    - SSH key pair configured
    - Base VM images built (Packer)

IMPORTANT:
    The framework requires a clean environment and will check that the target VM
    is not already running before starting tests. If a VM exists, you will get
    detailed cleanup instructions including:

    - Using ai-how to destroy the cluster: 'uv run ai-how destroy <config>'
    - Manual VM cleanup using virsh commands
    - Verification commands to ensure clean environment

    Always ensure previous test runs are properly cleaned up before starting.

LOG FILES:
    Test logs are saved to: tests/logs/run-YYYY-MM-DD_HH-MM-SS/
    Each test run creates a unique timestamped directory with:
    - cluster-start.log, cluster-destroy.log: Framework operation logs
    - test-results-<vm-name>.log: Individual VM test results
    - remote-logs-<vm-name>/: Remote VM test execution logs
    - vm-connection-info/: VM IP addresses and SSH connection commands
      * vm-list.txt: Human-readable VM information
      * ssh-commands.sh: Ready-to-use SSH connection commands
      * debug-helper.sh: Interactive debugging helper script

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_usage
            exit 0
            ;;
        --config)
            TEST_CONFIG="$2"
            shift 2
            ;;
        --ssh-user)
            SSH_USER="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        --target-vm)
            TARGET_VM_NAME="$2"
            shift 2
            ;;
        --no-cleanup)
            trap - EXIT INT TERM
            shift
            ;;
        --verbose|-v)
            set -x
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# =============================================================================
# Main Execution
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_full_test
fi
