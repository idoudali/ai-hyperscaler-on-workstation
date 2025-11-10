#!/bin/bash
#
# SLURM Job Scripts Test Suite - Master Test Runner
# Task 025 - Job Scripts Validation
# Orchestrates execution of all job scripts validation tests
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
SCRIPT_NAME="run-job-scripts-tests.sh"
TEST_SUITE_NAME="SLURM Job Scripts Test Suite (Task 025)"
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

# Test scripts for Job Scripts validation
TEST_SCRIPTS=(
    "check-epilog-prolog.sh"             # Task 025: Validate epilog/prolog functionality
    "check-failure-detection.sh"         # Task 025: Validate job failure detection
    "check-debug-collection.sh"          # Task 025: Validate debug log collection
)

# System check functions
check_system_requirements() {
    log_info "Checking system requirements for job scripts tests..."

    # Check if SLURM is installed
    if ! command -v sinfo >/dev/null 2>&1; then
        log_warn "SLURM not found on system"
    else
        log_debug "SLURM is available"
    fi

    # Check essential commands
    local required_commands=(
        "bash"
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

# Setup test environment
setup_test_environment() {
    log_info "Setting up local test environment..."

    local setup_script="$SCRIPT_DIR/setup-local-test-env.sh"

    if [ ! -f "$setup_script" ]; then
        log_error "Setup script not found: $setup_script"
        return 1
    fi

    if [ ! -x "$setup_script" ]; then
        chmod +x "$setup_script" || {
            log_error "Failed to make setup script executable"
            return 1
        }
    fi

    # Run setup script
    if ! "$setup_script"; then
        log_error "Failed to set up test environment"
        return 1
    fi

    # Source the environment file
    local env_file="$SCRIPT_DIR/test-run/test-env.sh"
    if [ -f "$env_file" ]; then
        # shellcheck source=/dev/null
        source "$env_file"
        log_info "Test environment configured:"
        log_info "  Scripts: $TEST_SLURM_SCRIPTS_DIR"
        log_info "  Tools: $TEST_SLURM_TOOLS_DIR"
        log_info "  Logs: $TEST_SLURM_LOG_DIR"

        # Export for child processes
        export TEST_SLURM_SCRIPTS_DIR
        export TEST_SLURM_TOOLS_DIR
        export TEST_SLURM_LOG_DIR
    else
        log_error "Environment file not found: $env_file"
        return 1
    fi

    return 0
}

# Teardown test environment
teardown_test_environment() {
    log_debug "Cleaning up test environment..."

    local teardown_script="$SCRIPT_DIR/teardown-local-test-env.sh"

    if [ ! -f "$teardown_script" ]; then
        log_warn "Teardown script not found: $teardown_script"
        return 0
    fi

    if [ ! -x "$teardown_script" ]; then
        chmod +x "$teardown_script" || {
            log_warn "Failed to make teardown script executable"
            return 0
        }
    fi

    # Run teardown script
    if ! "$teardown_script"; then
        log_warn "Failed to clean up test environment"
        return 0
    fi

    return 0
}

# Cleanup functions
cleanup_test_environment() {
    log_debug "Cleaning up after tests..."
    teardown_test_environment
    log_debug "Cleanup completed"
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

    # Setup test environment
    if ! setup_test_environment; then
        log_error "Failed to set up test environment"
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
