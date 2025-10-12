#!/bin/bash
#
# SLURM Job Scripts Test Suite - Master Test Runner
# Task 025 - Job Scripts Validation
# Orchestrates execution of all job scripts validation tests
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="run-job-scripts-tests.sh"
SUITE_NAME="SLURM Job Scripts Test Suite"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use LOG_DIR from environment or default
: "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Suite tracking
SUITES_RUN=0
SUITES_PASSED=0
FAILED_SUITES=()

# Test scripts to run (in order)
TEST_SCRIPTS=(
    "check-epilog-prolog.sh"
    "check-failure-detection.sh"
    "check-debug-collection.sh"
)

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

# Function to run a test script
run_test_script() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"

    SUITES_RUN=$((SUITES_RUN + 1))

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Running Test Suite ${SUITES_RUN}: ${script_name}${NC}"
    echo -e "${BLUE}========================================${NC}"

    if [ ! -f "$script_path" ]; then
        log_error "Test script not found: $script_path"
        FAILED_SUITES+=("$script_name (not found)")
        return 1
    fi

    if [ ! -x "$script_path" ]; then
        log_error "Test script not executable: $script_path"
        chmod +x "$script_path" || {
            log_error "Failed to make script executable"
            FAILED_SUITES+=("$script_name (not executable)")
            return 1
        }
    fi

    # Export LOG_DIR for test script
    export LOG_DIR

    # Run the test script
    if "$script_path"; then
        log_info "✓ Test suite passed: $script_name"
        SUITES_PASSED=$((SUITES_PASSED + 1))
        return 0
    else
        log_error "✗ Test suite failed: $script_name"
        FAILED_SUITES+=("$script_name")
        return 1
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
    log_info "Cleaning up local test environment..."

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

# Main execution
main() {
    local start_time
    start_time=$(date +%s)

    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  $SUITE_NAME${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""

    log_info "Starting job scripts test suite"
    log_info "Test directory: $SCRIPT_DIR"
    log_info "Log directory: $LOG_DIR"
    log_info "Test scripts: ${#TEST_SCRIPTS[@]}"
    echo ""

    # Setup local test environment
    if ! setup_test_environment; then
        log_error "Failed to set up test environment"
        exit 1
    fi
    echo ""

    # Verify all test scripts exist
    local missing_scripts=()
    for script in "${TEST_SCRIPTS[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$script" ]; then
            missing_scripts+=("$script")
        fi
    done

    if [ ${#missing_scripts[@]} -gt 0 ]; then
        log_error "Missing test scripts:"
        for script in "${missing_scripts[@]}"; do
            log_error "  - $script"
        done
        echo ""
        echo -e "${RED}Cannot proceed with missing test scripts${NC}"
        exit 1
    fi

    # Run all test scripts
    for script in "${TEST_SCRIPTS[@]}"; do
        run_test_script "$script" || true  # Continue even if a suite fails
    done

    # Calculate execution time
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Final results
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  Test Suite Results Summary${NC}"
    echo -e "${BLUE}==========================================${NC}"

    echo -e "Total test suites run: ${SUITES_RUN}"
    echo -e "Test suites passed: ${GREEN}${SUITES_PASSED}${NC}"
    echo -e "Test suites failed: ${RED}$((SUITES_RUN - SUITES_PASSED))${NC}"
    echo -e "Total execution time: ${duration}s"
    echo ""

    if [ ${#FAILED_SUITES[@]} -gt 0 ]; then
        echo -e "${RED}Failed test suites:${NC}"
        for suite in "${FAILED_SUITES[@]}"; do
            echo -e "  - $suite"
        done
        echo ""
    fi

    # Teardown test environment
    echo ""
    teardown_test_environment

    if [ $SUITES_PASSED -eq $SUITES_RUN ]; then
        echo ""
        echo -e "${GREEN}==========================================${NC}"
        echo -e "${GREEN}  ALL JOB SCRIPTS TESTS PASSED${NC}"
        echo -e "${GREEN}==========================================${NC}"
        echo ""
        log_info "Job scripts test suite completed successfully (${SUITES_PASSED}/${SUITES_RUN} suites, ${duration}s)"
        exit 0
    else
        echo ""
        echo -e "${RED}==========================================${NC}"
        echo -e "${RED}  SOME JOB SCRIPTS TESTS FAILED${NC}"
        echo -e "${RED}==========================================${NC}"
        echo ""
        log_error "Job scripts test suite failed (${SUITES_PASSED}/${SUITES_RUN} suites passed, ${duration}s)"
        exit 1
    fi
}

# Execute main function
main "$@"
