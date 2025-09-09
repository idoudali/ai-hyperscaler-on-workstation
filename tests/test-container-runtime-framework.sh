#!/bin/bash
#
# Container Runtime Test Framework - Task 004 Integration
# Automated testing framework for container runtime using Task 004 framework patterns
# Task 008 compliant test orchestration with ai-how cluster deployment
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/..")"
TESTS_DIR="$PROJECT_ROOT/tests"
TEST_CONFIG="test-infra/configs/test-container-runtime.yaml"
TEST_SCRIPTS_DIR="$PROJECT_ROOT/tests/suites/container-runtime"

# Create unique log directory per run using LOG_DIR pattern
RUN_TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
TEST_NAME="container-runtime"
LOG_DIR="$PROJECT_ROOT/tests/logs/${TEST_NAME}-test-run-$RUN_TIMESTAMP"
mkdir -p "$LOG_DIR"

SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
SSH_USER="admin"  # Adjust based on your base image
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# Target VM configuration - focus on container-enabled compute nodes
TARGET_VM_PATTERN="compute"

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
# Container Runtime Specific Functions
# =============================================================================

show_usage() {
    cat << EOF
Container Runtime Test Framework (Task 008)

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    Automated testing framework for container runtime validation using Task 004
    framework patterns. Tests container runtime installation, execution, and
    security on ai-how deployed clusters.

    This framework validates Task 008 requirements:
    • Apptainer binary installed and functional (>= 4.1.5)
    • All dependencies installed (fuse, squashfs-tools, uidmap, libfuse2, libseccomp2)
    • Container execution capabilities (pull, run, bind mounts)
    • Security configuration properly applied
    • Integration with SLURM scheduling

OPTIONS:
    --help, -h              Show this help message
    --config CONFIG         Use specific test configuration (default: $TEST_CONFIG)
    --ssh-user USER         SSH username (default: $SSH_USER)
    --ssh-key KEY           SSH private key path (default: $SSH_KEY_PATH)
    --target-vm PATTERN     Target VM pattern (default: $TARGET_VM_PATTERN)
    --no-cleanup            Don't cleanup on failure (for debugging)
    --verbose, -v           Enable verbose output
    --quick                 Run only essential tests

EXAMPLES:
    # Run with default configuration (recommended)
    $0

    # Run with custom configuration
    $0 --config test-infra/configs/test-custom.yaml

    # Run with different target VMs
    $0 --target-vm "container-runtime"

    # Debug mode (no auto-cleanup on failure)
    $0 --no-cleanup --verbose

PREREQUISITES:
    - ai-how tool installed and working
    - virsh command available
    - SSH key pair configured
    - Base VM images built (Packer)
    - Container runtime role deployed in Ansible

TEST VALIDATION:
    The framework validates these Task 008 components:
    ✓ Container runtime installation and version
    ✓ Required dependencies installed
    ✓ Container execution capabilities
    ✓ Security policy enforcement
    ✓ SLURM integration (if available)

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
    This test integrates with the Task 004 framework by:
    • Using shared cluster management utilities
    • Following Task 004 logging patterns
    • Providing consistent VM orchestration
    • Supporting ai-how cluster deployment workflow

EOF
}

# Container runtime specific test execution
run_container_runtime_tests() {
    log "Starting Container Runtime Test Framework (Task 008 Validation)"
    log "Configuration: $TEST_CONFIG"
    log "Target VM Pattern: $TARGET_VM_PATTERN"
    log "Test Scripts Directory: $TEST_SCRIPTS_DIR"
    log "Log directory: $LOG_DIR"
    echo

    # Use the shared test framework utilities
    if run_test_framework "$TESTS_DIR/$TEST_CONFIG" "$TEST_SCRIPTS_DIR" "$TARGET_VM_PATTERN" "run-container-runtime-tests.sh"; then
        log_success "Container Runtime Test Framework: ALL TESTS PASSED"
        log_success "Task 008 validation completed successfully"
        return 0
    else
        log_warning "Container Runtime Test Framework: TESTS FAILED"
        log_warning "Task 008 validation failed - check logs for details"
        return 1
    fi
}

# Quick test mode - runs essential tests only
run_quick_tests() {
    log "Running quick container runtime validation..."

    # Run only the installation check
    local quick_script="check-singularity-install.sh"

    if run_test_framework "$TESTS_DIR/$TEST_CONFIG" "$TEST_SCRIPTS_DIR" "$TARGET_VM_PATTERN" "$quick_script"; then
        log_success "Quick container runtime test: PASSED"
        return 0
    else
        log_warning "Quick container runtime test: FAILED"
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

    log "Container Runtime Test Framework Starting"
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
        if run_container_runtime_tests; then
            main_exit_code=0
        else
            main_exit_code=1
        fi
    fi

    # Final completion message
    {
        echo
        echo "=================================================="
        echo "Container Runtime Test Framework completed at: $(date)"
        echo "Exit code: $main_exit_code"
        echo "All logs saved to: $LOG_DIR"
        echo "=================================================="
    } | tee -a "$LOG_DIR/framework-main.log"

    exit $main_exit_code
fi
