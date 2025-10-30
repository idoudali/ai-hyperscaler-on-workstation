#!/bin/bash
# Run Cgroup Isolation Tests
# Task 024: Set Up Cgroup Resource Isolation
# Master Test Runner for Cgroup Isolation Test Suite
#
# This script orchestrates all cgroup isolation tests

source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
set -euo pipefail

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="run-cgroup-isolation-tests.sh"
# shellcheck disable=SC2034
TEST_NAME="Cgroup Isolation Test Suite Runner"
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Test suite results
declare -a SUITE_RESULTS
declare -a FAILED_SUITES_LIST=()

#=============================================================================
# Helper Functions
#=============================================================================

run_test_suite() {
    local suite_name="$1"
    local suite_script="$2"

    TOTAL_SUITES=$((TOTAL_SUITES + 1))

    log_info "======================================================================"
    log_info "Running test suite: $suite_name"
    log_info "======================================================================"

    if [ ! -f "$suite_script" ]; then
        log_error "Test suite script not found: $suite_script"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        SUITE_RESULTS+=("✗ $suite_name (script not found)")
        FAILED_SUITES_LIST+=("$suite_name")
        return 1
    fi

    if [ ! -x "$suite_script" ]; then
        log_error "Test suite script not executable: $suite_script"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        SUITE_RESULTS+=("✗ $suite_name (not executable)")
        FAILED_SUITES_LIST+=("$suite_name")
        return 1
    fi

    if "$suite_script"; then
        PASSED_SUITES=$((PASSED_SUITES + 1))
        SUITE_RESULTS+=("✓ $suite_name")
        log_success "Test suite passed: $suite_name"
        return 0
    else
        FAILED_SUITES=$((FAILED_SUITES + 1))
        SUITE_RESULTS+=("✗ $suite_name")
        FAILED_SUITES_LIST+=("$suite_name")
        log_error "Test suite failed: $suite_name"
        return 1
    fi
}

#=============================================================================
# Main Test Execution
#=============================================================================

main() {
    log_info "======================================================================"
    log_info "Cgroup Isolation Test Suite Runner"
    log_info "======================================================================"
    log_info "Test suite directory: $SCRIPT_DIR"
    log_info "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "======================================================================"

    # Run all test suites
    run_test_suite "Cgroup Configuration" "$SCRIPT_DIR/check-cgroup-configuration.sh" || true
    run_test_suite "Resource Isolation" "$SCRIPT_DIR/check-resource-isolation.sh" || true
    run_test_suite "Device Isolation" "$SCRIPT_DIR/check-device-isolation.sh" || true

    # Print overall summary
    log_info "======================================================================"
    log_info "Test Suite Summary"
    log_info "======================================================================"
    log_info "Total test suites: $TOTAL_SUITES"
    log_info "Passed test suites: $PASSED_SUITES"
    log_info "Failed test suites: $FAILED_SUITES"
    log_info "======================================================================"

    # Print individual suite results
    for result in "${SUITE_RESULTS[@]}"; do
        echo "$result"
    done

    # Print failed suites if any
    if [ ${#FAILED_SUITES_LIST[@]} -gt 0 ]; then
        log_error "======================================================================"
        log_error "Failed Test Suites:"
        for suite in "${FAILED_SUITES_LIST[@]}"; do
            log_error "  - $suite"
        done
        log_error "======================================================================"
    fi

    log_info "End time: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "======================================================================"

    # Return exit code based on results
    if [ $FAILED_SUITES -eq 0 ]; then
        log_success "All cgroup isolation test suites passed!"
        return 0
    else
        log_error "Some cgroup isolation test suites failed!"
        return 1
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
