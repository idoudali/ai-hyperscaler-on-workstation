#!/bin/bash
#
# SLURM Controller Test Suite Master Runner
# Task 010 - Master Test Runner for SLURM Controller Validation
# Orchestrates all SLURM controller tests per Task 010 requirements
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="run-slurm-controller-tests.sh"
TEST_SUITE_NAME="SLURM Controller Test Suite (Tasks 010-013)"

# Get script directory and test suite directory
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
TEST_SUITE_DIR="$(cd "$SCRIPT_DIR" && pwd)"

# Use LOG_DIR from environment or default
: "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# Test scripts for SLURM Controller validation
TEST_SCRIPTS=(
    "check-slurm-installation.sh"      # Task 010: Verify package installation and dependencies
    "check-slurm-functionality.sh"     # Task 010: Test basic SLURM functionality and configuration
    "check-pmix-integration.sh"        # Task 011: Validate PMIx integration and configuration
    "check-munge-authentication.sh"    # Task 012: Validate MUNGE authentication system
    "check-container-plugin.sh"        # Task 013: Validate container plugin configuration and integration
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
# TODO: Add support for tracking partial test results if/when partial test states are implemented
FAILED_SCRIPTS=()

# Logging functions with LOG_DIR compliance
log() {
    echo -e "$1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_info() {
    log "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    log "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

log_debug() {
    log "${BLUE}[DEBUG]${NC} $1"
}

# Utility functions
check_script_executable() {
    local script_path="$1"

    if [ ! -f "$script_path" ]; then
        log_error "Test script not found: $script_path"
        return 1
    fi

    if [ ! -x "$script_path" ]; then
        log_warn "Making test script executable: $script_path"
        chmod +x "$script_path"
    fi

    return 0
}

# Test execution functions
run_test_script() {
    local script_name="$1"
    local script_path="$TEST_SUITE_DIR/$script_name"

    log ""
    log "${BLUE}=====================================${NC}"
    log "${BLUE}  Running: $script_name${NC}"
    log "${BLUE}=====================================${NC}"

    # Check if script exists and is executable
    if ! check_script_executable "$script_path"; then
        log_error "Failed to prepare test script: $script_name"
        FAILED_SCRIPTS+=("$script_name")
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    # Set up environment for test script
    export LOG_DIR="$LOG_DIR"
    export SCRIPT_DIR="$SCRIPT_DIR"
    export TEST_SUITE_DIR="$TEST_SUITE_DIR"

    # Execute test script and capture result
    local start_time
    start_time=$(date +%s)

    if "$script_path"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_info "✓ Test script passed: $script_name (${duration}s)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_error "✗ Test script failed: $script_name (${duration}s)"
        FAILED_SCRIPTS+=("$script_name")
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# System check functions
check_system_requirements() {
    log_info "Checking system requirements for SLURM controller tests..."

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
        "dpkg"
        "systemctl"
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

    # No specific cleanup needed for SLURM controller tests
    # (Unlike container tests, we don't create temporary containers)

    log_debug "Test environment cleanup completed"
}

# Report generation
generate_test_report() {
    local report_file="$LOG_DIR/test_report_summary.txt"

    log ""
    log "${BLUE}=====================================${NC}"
    log "${BLUE}  FINAL TEST RESULTS${NC}"
    log "${BLUE}=====================================${NC}"

    {
        echo "SLURM Controller Test Suite Results"
        echo "Generated: $(date)"
        echo ""
        echo "Test Suite: $TEST_SUITE_NAME"
        echo "Total Scripts: $TOTAL_TESTS"
        echo "Passed: $PASSED_TESTS"
        echo "Failed: $FAILED_TESTS"
        echo ""

        if [ ${#FAILED_SCRIPTS[@]} -gt 0 ]; then
            echo "Failed Scripts:"
            for script in "${FAILED_SCRIPTS[@]}"; do
                echo "  - $script"
            done
            echo ""
        fi

        echo "Detailed logs available in: $LOG_DIR"
    } | tee "$report_file"

    # Display summary with colors
    log "Test Suite: ${BLUE}$TEST_SUITE_NAME${NC}"
    log "Total Scripts: $TOTAL_TESTS"
    log "Passed: ${GREEN}$PASSED_TESTS${NC}"
    log "Failed: ${RED}$FAILED_TESTS${NC}"

    if [ ${#FAILED_SCRIPTS[@]} -gt 0 ]; then
        log ""
        log "${RED}Failed Scripts:${NC}"
        for script in "${FAILED_SCRIPTS[@]}"; do
            log "  - ${RED}$script${NC}"
        done
    fi

    log ""
    log "Detailed logs: ${BLUE}$LOG_DIR${NC}"
    log "Test report: ${BLUE}$report_file${NC}"
}

# Main execution function
main() {
    local start_time
    start_time=$(date +%s)

    echo ""
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}  $TEST_SUITE_NAME${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""

    # Initialize test tracking
    TOTAL_TESTS=${#TEST_SCRIPTS[@]}

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

    # Generate final report
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    generate_test_report

    log ""
    log "Total execution time: ${total_duration}s"

    # Determine exit code based on results
    if [ $FAILED_TESTS -eq 0 ]; then
        log_info "🎉 All SLURM controller tests passed!"
        exit 0
    else
        log_error "❌ Some SLURM controller tests failed"
        exit 1
    fi
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
