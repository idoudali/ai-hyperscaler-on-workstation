#!/bin/bash
#
# Basic Infrastructure Test Framework - Task 005 Integration
# Automated testing framework for basic infrastructure using Task 005 framework patterns
# Task 005 compliant test orchestration with ai-how cluster deployment
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/..")"
TESTS_DIR="$PROJECT_ROOT/tests"
TEST_CONFIG="test-infra/configs/test-minimal.yaml"
TEST_SCRIPTS_DIR="$PROJECT_ROOT/tests/suites/basic-infrastructure"

# Create unique log directory per run using LOG_DIR pattern
RUN_TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
TEST_NAME="basic-infrastructure"
LOG_DIR="$PROJECT_ROOT/tests/logs/${TEST_NAME}-test-run-$RUN_TIMESTAMP"
mkdir -p "$LOG_DIR"

SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
SSH_USER="admin"  # Adjust based on your base image
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# Target VM configuration - focus on all nodes for basic infrastructure testing
TARGET_VM_PATTERN="test-hpc-minimal"

# Timeouts (in seconds) - handled by framework utilities

# Source shared utilities
if [[ -f "$TESTS_DIR/test-infra/utils/test-framework-utils.sh" ]]; then
    # shellcheck source=test-infra/utils/test-framework-utils.sh
    source "$TESTS_DIR/test-infra/utils/test-framework-utils.sh"
else
    echo "Error: Shared test framework utilities not found"
    echo "Expected: $TESTS_DIR/test-infra/utils/test-framework-utils.sh"
    exit 1
fi

# Export configuration for shared utilities
export PROJECT_ROOT TESTS_DIR LOG_DIR SSH_KEY_PATH SSH_USER SSH_OPTS TEST_NAME
export CLEANUP_REQUIRED=false INTERACTIVE_CLEANUP=false

# =============================================================================
# Basic Infrastructure Specific Functions
# =============================================================================

show_usage() {
    cat << EOF
Basic Infrastructure Test Framework (Task 005)

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    Automated testing framework for basic infrastructure validation using Task 005
    framework patterns. Tests VM lifecycle, networking, SSH connectivity, and
    configuration validation on ai-how deployed clusters.

    This framework validates Task 005 requirements:
    • VM lifecycle management (start, stop, cleanup)
    • SSH connectivity and authentication
    • Basic networking functionality
    • Configuration validation across all test configs
    • Integration with existing comprehensive test infrastructure

OPTIONS:
    --help, -h              Show this help message
    --config CONFIG         Use specific test configuration (default: $TEST_CONFIG)
    --ssh-user USER         SSH username (default: $SSH_USER)
    --ssh-key KEY           SSH private key path (default: $SSH_KEY_PATH)
    --target-vm PATTERN     Target VM pattern (default: all VMs)
    --no-cleanup            Don't cleanup on failure (for debugging)
    --verbose, -v           Enable verbose output
    --quick                 Run only essential tests

EXAMPLES:
    # Run with default configuration (recommended)
    $0

    # Run with custom configuration
    $0 --config test-infra/configs/test-custom.yaml

    # Run with different target VMs
    $0 --target-vm "controller"

    # Debug mode (no auto-cleanup on failure)
    $0 --no-cleanup --verbose

PREREQUISITES:
    - ai-how tool installed and working
    - virsh command available
    - SSH key pair configured
    - Base VM images built (Packer)
    - Basic infrastructure test suite deployed

TEST VALIDATION:
    The framework validates these Task 005 components:
    ✓ VM lifecycle management (start, stop, cleanup)
    ✓ SSH connectivity and authentication
    ✓ Basic networking functionality
    ✓ Configuration validation across all test configs
    ✓ Integration with existing test infrastructure

LOG FILES:
    Test logs are saved to: $LOG_DIR
    - framework-main.log: Main framework execution
    - cluster-start.log, cluster-destroy.log: Cluster operations
    - test-results-<vm-name>.log: Individual VM test results
    - remote-logs-<vm-name>/: Remote VM test execution logs
    - vm-connection-info/: VM connection commands and debugging info

EXIT CODES:
    0: All tests passed successfully
    1: Some tests failed or framework error

FRAMEWORK INTEGRATION:
    This test integrates with the Task 005 framework by:
    • Using shared cluster management utilities
    • Following Task 005 logging patterns
    • Providing consistent VM orchestration
    • Supporting ai-how cluster deployment workflow
    • Leveraging existing comprehensive test infrastructure

EOF
}

# Basic infrastructure specific test execution
run_basic_infrastructure_tests() {
    log "Starting Basic Infrastructure Test Framework (Task 005 Validation)"
    log "Configuration: $TEST_CONFIG"
    log "Target VM Pattern: $TARGET_VM_PATTERN"
    log "Test Scripts Directory: $TEST_SCRIPTS_DIR"
    log "Log directory: $LOG_DIR"
    echo

    # Use the shared test framework utilities
    if run_test_framework "$TESTS_DIR/$TEST_CONFIG" "$TEST_SCRIPTS_DIR" "$TARGET_VM_PATTERN" "run-basic-infrastructure-tests.sh"; then
        log_success "Basic Infrastructure Test Framework: ALL TESTS PASSED"
        log_success "Task 005 validation completed successfully"
        return 0
    else
        log_warning "Basic Infrastructure Test Framework: TESTS FAILED"
        log_warning "Task 005 validation failed - check logs for details"
        return 1
    fi
}

# Quick test mode - runs essential tests only
run_quick_tests() {
    log "Running quick basic infrastructure validation..."

    # Run only the VM lifecycle check
    local quick_script="check-vm-lifecycle.sh"

    if run_test_framework "$TESTS_DIR/$TEST_CONFIG" "$TEST_SCRIPTS_DIR" "$TARGET_VM_PATTERN" "$quick_script"; then
        log_success "Quick basic infrastructure test: PASSED"
        return 0
    else
        log_warning "Quick basic infrastructure test: FAILED"
        return 1
    fi
}

# =============================================================================
# CLI Interface and Main Execution
# =============================================================================

# Parse command line arguments
QUICK_MODE=false

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
            export SSH_USER
            shift 2
            ;;
        --ssh-key)
            SSH_KEY_PATH="$2"
            export SSH_KEY_PATH
            shift 2
            ;;
        --target-vm)
            TARGET_VM_PATTERN="$2"
            shift 2
            ;;
        --no-cleanup)
            trap - EXIT INT TERM
            shift
            ;;
        --verbose|-v)
            set -x
            export VERBOSE_MODE=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
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
    # Change to project root directory for consistent relative path handling
    cd "$PROJECT_ROOT" || {
        echo "Error: Failed to change to project root: $PROJECT_ROOT"
        exit 1
    }

    # Initialize logging
    init_logging "$RUN_TIMESTAMP" "tests/logs" "$TEST_NAME"

    log "Basic Infrastructure Test Framework Starting"
    log "Working directory: $(pwd)"
    echo

    # Execute appropriate test mode
    if [[ "$QUICK_MODE" == "true" ]]; then
        if run_quick_tests; then
            main_exit_code=0
        else
            main_exit_code=1
        fi
    else
        if run_basic_infrastructure_tests; then
            main_exit_code=0
        else
            main_exit_code=1
        fi
    fi

    # Final completion message
    {
        echo
        echo "=================================================="
        echo "Basic Infrastructure Test Framework completed at: $(date)"
        echo "Exit code: $main_exit_code"
        echo "All logs saved to: $LOG_DIR"
        echo "=================================================="
    } | tee -a "$LOG_DIR/framework-main.log"

    exit $main_exit_code
fi
