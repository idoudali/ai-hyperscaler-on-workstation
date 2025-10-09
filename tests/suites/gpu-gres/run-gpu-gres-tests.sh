#!/bin/bash
#
# GPU GRES Test Suite Master Runner
# Task 023 - Master Test Runner for GPU GRES Validation
# Orchestrates all GPU GRES tests per Task 023 requirements
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="run-gpu-gres-tests.sh"
TEST_SUITE_NAME="GPU GRES Test Suite (Task 023)"

# Get script directory and test suite directory
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
TEST_SUITE_DIR="$(cd "$SCRIPT_DIR" && pwd)"

# Use LOG_DIR from environment or default
: "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# Test scripts for GPU GRES validation
TEST_SCRIPTS=(
    "check-gres-configuration.sh"    # Task 023: Verify GRES configuration
    "check-gpu-detection.sh"         # Task 023: Validate GPU detection
    "check-gpu-scheduling.sh"        # Task 023: Validate GPU scheduling
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

    # Execute test script
    local test_log="$LOG_DIR/${script_name%.sh}.log"

    if LOG_DIR="$LOG_DIR" "$script_path" 2>&1 | tee -a "$test_log"; then
        log_info "✓ Test script passed: $script_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        log_error "✗ Test script failed: $script_name"
        FAILED_SCRIPTS+=("$script_name")
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Main test execution
main() {
    log "========================================="
    log "  $TEST_SUITE_NAME"
    log "========================================="
    log ""
    log "Test Suite Directory: $TEST_SUITE_DIR"
    log "Log Directory: $LOG_DIR"
    log "Test Scripts: ${#TEST_SCRIPTS[@]}"
    log ""

    # Display test scripts
    log "Test scripts to run:"
    for script in "${TEST_SCRIPTS[@]}"; do
        log "  - $script"
    done
    log ""

    # Run all test scripts
    TOTAL_TESTS=${#TEST_SCRIPTS[@]}

    for script in "${TEST_SCRIPTS[@]}"; do
        run_test_script "$script" || true  # Continue even if test fails
    done

    # Print final summary
    log ""
    log "========================================="
    log "  Final Test Summary"
    log "========================================="
    log "Total test scripts: $TOTAL_TESTS"
    log "Passed: $PASSED_TESTS"
    log "Failed: $FAILED_TESTS"

    if [[ ${#FAILED_SCRIPTS[@]} -gt 0 ]]; then
        log ""
        log "${RED}Failed test scripts:${NC}"
        for script in "${FAILED_SCRIPTS[@]}"; do
            log "  - $script"
        done
    fi

    log ""
    log "All logs saved to: $LOG_DIR"
    log "========================================="

    # Return appropriate exit code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log ""
        log_info "${GREEN}✓ All GPU GRES tests passed!${NC}"
        exit 0
    else
        log ""
        log_error "${RED}✗ Some GPU GRES tests failed${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
