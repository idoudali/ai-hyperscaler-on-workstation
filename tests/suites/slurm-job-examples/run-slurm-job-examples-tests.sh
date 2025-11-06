#!/bin/bash
#
# SLURM Job Examples Test Suite Master Runner
# Validates SLURM job execution using Tutorial 08 examples (hello-world, pi-calculation, matrix-multiply)
# Tests integration with BeeGFS shared storage across multiple nodes
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Resolve script and common utility directories (preserve this script's path)
SUITE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SUITE_SCRIPT_DIR/../common" && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "${COMMON_DIR}/suite-utils.sh"
# shellcheck source=/dev/null
source "${COMMON_DIR}/suite-logging.sh"
# shellcheck source=/dev/null
source "${COMMON_DIR}/suite-test-runner.sh"

# Script configuration
SCRIPT_NAME="run-slurm-job-examples-tests.sh"
TEST_SUITE_NAME="SLURM Job Examples Test Suite (Tutorial 08)"
SCRIPT_DIR="$SUITE_SCRIPT_DIR"
TEST_SUITE_DIR="$SUITE_SCRIPT_DIR"
export SCRIPT_DIR
export TEST_SUITE_DIR

# Configure logging directories
: "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME%.sh}.log"
touch "$LOG_FILE"

# Initialize suite logging and test runner
init_suite_logging "$TEST_SUITE_NAME"
init_test_runner

# Pre-test health check script (runs before all other tests)
HEALTH_CHECK_SCRIPT="check-cluster-health.sh"

# Test scripts for SLURM job examples
TEST_SCRIPTS=(
    "check-beegfs-shared-storage.sh"    # Verify BeeGFS is accessible from all nodes
    "check-hello-world-job.sh"          # Test basic multi-node MPI job
    "check-pi-calculation-job.sh"       # Test computational parallelism
    "check-matrix-multiply-job.sh"      # Test memory-intensive parallel job
)

# Logging helpers
log_plain() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_info() {
    log_with_context "INFO" "$1"
}

log_warn() {
    log_with_context "WARN" "$1"
}

log_error() {
    log_with_context "ERROR" "$1"
}

log_debug() {
    log_with_context "DEBUG" "$1"
}

# Detect Makefile cluster mode
detect_cluster_mode() {
    if [ "${MAKEFILE_CLUSTER_MODE:-false}" = "true" ]; then
        log_info "Running in Makefile cluster mode"
        log_info "Controller IP: ${CONTROLLER_IP:-not set}"

        # In Makefile mode, tests run via SSH
        if [ -z "${CONTROLLER_IP:-}" ]; then
            log_error "CONTROLLER_IP not set in Makefile cluster mode"
            return 1
        fi

        if [ -z "${SSH_KEY_PATH:-}" ]; then
            log_error "SSH_KEY_PATH not set in Makefile cluster mode"
            return 1
        fi

        if [ -z "${SSH_USER:-}" ]; then
            log_error "SSH_USER not set in Makefile cluster mode"
            return 1
        fi

        # Export for test scripts
        export CONTROLLER_IP SSH_KEY_PATH SSH_USER
        export TEST_MODE="remote"

        log_info "✓ Makefile cluster mode configured"
        return 0
    else
        log_debug "Running in standard test framework mode (local)"
        export TEST_MODE="local"
        return 0
    fi
}

# System check functions
check_system_requirements() {
    log_info "Checking system requirements for SLURM job example tests..."

    # Detect cluster mode first
    if ! detect_cluster_mode; then
        log_error "Cluster mode detection failed"
        return 1
    fi

    # In Makefile cluster mode, skip local system checks
    if [ "${TEST_MODE:-local}" = "remote" ]; then
        log_info "Remote test mode - will execute tests on controller: $CONTROLLER_IP"

        # Test SSH connectivity
        if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "${SSH_USER}@${CONTROLLER_IP}" "echo 'SSH OK'" &>/dev/null; then
            log_error "SSH connectivity test failed to controller: $CONTROLLER_IP"
            return 1
        fi

        log_info "✓ SSH connectivity verified"
        return 0
    fi

    # Check if running as root or with sudo access (local mode only)
    if [ "$EUID" -eq 0 ]; then
        log_debug "Running as root - full system access available"
    elif sudo -n true 2>/dev/null; then
        log_debug "Sudo access available for privileged operations"
    else
        log_warn "Limited permissions - some tests may be skipped"
    fi

    # Check essential commands
    local required_commands=(
        "sinfo"
        "sbatch"
        "squeue"
        "timeout"
    )

    local missing_commands=()
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi

    log_info "✓ System requirements check passed"
    return 0
}

# Run cluster health check before tests
run_cluster_health_check() {
    local health_check_path="$TEST_SUITE_DIR/$HEALTH_CHECK_SCRIPT"

    log_plain ""
    log_plain "${BLUE}=====================================${NC}"
    log_plain "${BLUE}  Running Cluster Health Check${NC}"
    log_plain "${BLUE}=====================================${NC}"

    # Check if health check script exists and is executable
    if ! check_script_executable "$health_check_path"; then
        log_error "Failed to prepare health check script"
        return 1
    fi

    # Set up environment for health check script
    export LOG_DIR="$LOG_DIR"
    export SCRIPT_DIR="$SCRIPT_DIR"
    export TEST_SUITE_DIR="$TEST_SUITE_DIR"

    # Execute health check script
    local start_time
    start_time=$(date +%s)

    if "$health_check_path"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_info "✓ Cluster health check passed (${duration}s)"
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_error "✗ Cluster health check failed (${duration}s)"
        return 1
    fi
}

show_environment_info() {
    log_info "Test environment information:"
    log_info "- Test suite: $TEST_SUITE_NAME"
    log_info "- Log directory: $LOG_DIR"
    log_info "- Test suite directory: $TEST_SUITE_DIR"
    log_info "- Number of test scripts: ${#TEST_SCRIPTS[@]}"

    # Show system info
    if command -v lsb_release >/dev/null 2>&1; then
        local os_info
        os_info=$(lsb_release -d | cut -f2-)
        log_info "- Operating System: $os_info"
    fi

    if [ -f /proc/version ]; then
        local kernel_info
        kernel_info=$(cut -d' ' -f1-3 < /proc/version)
        log_info "- Kernel: $kernel_info"
    fi
}

# Cleanup functions
cleanup_test_environment() {
    log_debug "Cleaning up test environment..."

    # Optional: Clean up temporary job files on BeeGFS if needed
    # (Most cleanup is handled by individual test scripts)

    log_debug "Test environment cleanup completed"
}

# Report generation
# Note: Test reporting now handled by print_test_summary from suite-test-runner.sh

# Main execution function
main() {
    local start_time
    start_time=$(date +%s)

    echo ""
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}  $TEST_SUITE_NAME${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""

    # Show environment info
    show_environment_info

    # Check system requirements
    if ! check_system_requirements; then
        log_error "System requirements check failed"
        exit 1
    fi

    # Run cluster health check before tests
    if ! run_cluster_health_check; then
        log_error "Cluster health check failed - cannot proceed with tests"
        exit 1
    fi

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
            echo "  LOG_DIR         Directory for test logs (default: ./logs/run-YYYY-MM-DD_HH-MM-SS)"
            echo ""
            echo "Pre-Test Health Check:"
            echo "  - $HEALTH_CHECK_SCRIPT (runs automatically before all tests)"
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
