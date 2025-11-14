#!/bin/bash
#
# Cgroup Isolation Test Suite Master Runner
# Task 024 - Master Test Runner for Cgroup Isolation Validation
# Orchestrates all cgroup isolation tests per Task 024 requirements
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
SCRIPT_NAME="run-cgroup-isolation-tests.sh"
TEST_SUITE_NAME="Cgroup Isolation Test Suite (Task 024)"
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

# Test scripts for Cgroup Isolation validation
TEST_SCRIPTS=(
    "check-cgroup-configuration.sh"      # Task 024: Verify cgroup configuration
    "check-device-isolation.sh"          # Task 024: Validate device isolation
    "check-resource-isolation.sh"        # Task 024: Validate resource isolation
)

# System check functions
check_system_requirements() {
    log_info "Checking system requirements for cgroup isolation tests..."

    # Check if running as root or with sudo access
    if [ "$EUID" -eq 0 ]; then
        log_debug "Running as root - full system access available"
    elif sudo -n true 2>/dev/null; then
        log_debug "Sudo access available for privileged operations"
    else
        log_warn "Limited permissions - some tests may be skipped"
    fi

    # Check essential commands
    local required_commands=(
        "cgroup-ls"
        "systemctl"
        "timeout"
    )

    # shellcheck disable=SC2034
    local missing_commands=()
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Optional command not found: $cmd"
        fi
    done

    log_info "✓ System requirements check passed"
    return 0
}

show_environment_info() {
    log_info "Test environment information:"
    log_info "- Test suite: $TEST_SUITE_NAME"
    log_info "- Log directory: $LOG_DIR"
    log_info "- Test suite directory: $TEST_SUITE_DIR"
    log_info "- Number of test scripts: ${#TEST_SCRIPTS[@]}"
    log_info "- Current hostname: $(hostname)"

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
    # No specific cleanup needed for cgroup isolation tests
    log_debug "Test environment cleanup completed"
}

# Main execution function
main() {
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
