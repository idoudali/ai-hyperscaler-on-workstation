#!/bin/bash

# Basic Infrastructure Test Suite Master Script
# This script orchestrates all basic infrastructure tests for Task 005 validation

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set PROJECT_ROOT if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi

# Logging configuration
if [[ -z "${LOG_DIR:-}" ]]; then
    LOG_DIR="${SCRIPT_DIR}/logs/$(date +%Y-%m-%d_%H-%M-%S)"
fi

mkdir -p "${LOG_DIR}"

# Set environment variables for test scripts
export PROJECT_ROOT
export SSH_KEY_PATH="${SSH_KEY_PATH:-$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
export SSH_USER="${SSH_USER:-admin}"
export SSH_OPTS="${SSH_OPTS:--o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR}"

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_DIR}/master-test.log"
}

log_success() {
    echo -e "\033[0;32m[$(date '+%Y-%m-%d %H:%M:%S')] ✓\033[0m $*" | tee -a "${LOG_DIR}/master-test.log"
}

log_error() {
    echo -e "\033[0;31m[$(date '+%Y-%m-%d %H:%M:%S')] ✗\033[0m $*" | tee -a "${LOG_DIR}/master-test.log"
}

# Test configuration
TESTS_DIR="${SCRIPT_DIR}"
TEST_SCRIPTS=(
    "check-basic-networking.sh"
    "check-configuration.sh"
    "check-ssh-connectivity.sh"
    "check-vm-lifecycle.sh"
)

# Test results tracking
declare -A TEST_RESULTS
OVERALL_SUCCESS=true

# Function to run individual test
run_test() {
    local test_script="$1"
    local test_name="${test_script%.sh}"
    local test_log="${LOG_DIR}/${test_name}.log"

    log "Starting test: ${test_name}"

    if [[ ! -f "${TESTS_DIR}/${test_script}" ]]; then
        log_error "Test script not found: ${test_script}"
        TEST_RESULTS["${test_name}"]="FAILED"
        return 1
    fi

    # Make script executable
    chmod +x "${TESTS_DIR}/${test_script}"

    # Run the test and capture output with tee for real-time visibility

    if "${TESTS_DIR}/${test_script}" 2>&1 | tee "${test_log}"; then
        log_success "Test passed: ${test_name}"
        TEST_RESULTS["${test_name}"]="PASSED"
        return 0
    else
        local exit_code=$?
        log_error "Test failed: ${test_name} (exit code: ${exit_code})"
        TEST_RESULTS["${test_name}"]="FAILED"
        return 1
    fi
}

# Function to generate test summary
generate_summary() {
    local summary_file="${LOG_DIR}/test-summary.txt"

    log "Generating test summary..."

    {
        echo "Basic Infrastructure Test Suite Summary"
        echo "======================================"
        echo "Test Run: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Log Directory: ${LOG_DIR}"
        echo ""
        echo "Test Results:"
        echo "-------------"

        local passed_count=0
        local failed_count=0

        for test_name in "${!TEST_RESULTS[@]}"; do
            local status="${TEST_RESULTS[${test_name}]}"
            echo "  ${test_name}: ${status}"

            if [[ "${status}" == "PASSED" ]]; then
                ((passed_count++))
            else
                ((failed_count++))
            fi
        done

        echo ""
        echo "Summary:"
        echo "  Total Tests: $((passed_count + failed_count))"
        echo "  Passed: ${passed_count}"
        echo "  Failed: ${failed_count}"
        echo ""

        if [[ "${failed_count}" -eq 0 ]]; then
            echo "Overall Result: ALL TESTS PASSED"
        else
            echo "Overall Result: SOME TESTS FAILED"
        fi

        echo ""
        echo "Individual Test Logs:"
        echo "--------------------"
        for test_name in "${!TEST_RESULTS[@]}"; do
            echo "  ${test_name}: ${LOG_DIR}/${test_name}.log"
        done

    } > "${summary_file}"

    log "Test summary saved to: ${summary_file}"
}

# Main execution
main() {
    log "Starting Basic Infrastructure Test Suite"
    log "Test directory: ${TESTS_DIR}"
    log "Log directory: ${LOG_DIR}"
    log "Number of tests: ${#TEST_SCRIPTS[@]}"
    echo ""

    # Run all tests
    for test_script in "${TEST_SCRIPTS[@]}"; do
        if ! run_test "${test_script}"; then
            OVERALL_SUCCESS=false
        fi
        echo ""
    done

    # Generate summary
    generate_summary

    # Final result
    echo "=================================================="
    if [[ "${OVERALL_SUCCESS}" == "true" ]]; then
        log_success "All basic infrastructure tests passed!"
        exit 0
    else
        log_error "Some basic infrastructure tests failed!"
        log "Check individual test logs in: ${LOG_DIR}"
        exit 1
    fi
}

# Run main function
main "$@"
