#!/bin/bash
# Shared test runner framework for test suite orchestration
# Provides standardized test execution, tracking, and reporting

# Prevent multiple sourcing
[ -n "${SUITE_TEST_RUNNER_LOADED:-}" ] && return 0
readonly SUITE_TEST_RUNNER_LOADED=1

# =============================================================================
# Test Runner State Management
# =============================================================================

# Initialize test runner state
init_test_runner() {
    export TEST_SUITE_TOTAL=0
    export TEST_SUITE_PASSED=0
    export TEST_SUITE_FAILED=0
    export TEST_SUITE_FAILED_LIST=()
    local start_time
    start_time=$(date +%s)
    export TEST_SUITE_START_TIME="$start_time"
}

# =============================================================================
# Test Script Execution
# =============================================================================

# Check if test script exists and is executable
check_script_executable() {
    local script_path="$1"

    if [ ! -f "$script_path" ]; then
        log_suite_error "Test script not found: $script_path"
        return 1
    fi

    if [ ! -x "$script_path" ]; then
        log_suite_warning "Making test script executable: $script_path"
        chmod +x "$script_path"
    fi

    return 0
}

# Run a test script and track results
run_test_script() {
    local script_name="$1"
    local script_path="${2:-${TEST_SUITE_DIR:-$(pwd)}/$script_name}"

    TEST_SUITE_TOTAL=$((TEST_SUITE_TOTAL + 1))

    log_suite_info ""
    log_suite_info "====================================="
    log_suite_info "Running: $script_name"
    log_suite_info "====================================="

    # Check if script exists and is executable
    if ! check_script_executable "$script_path"; then
        log_suite_error "Failed to prepare test script: $script_name"
        TEST_SUITE_FAILED_LIST+=("$script_name")
        TEST_SUITE_FAILED=$((TEST_SUITE_FAILED + 1))
        return 1
    fi

    # Set up environment for test script
    export LOG_DIR="${LOG_DIR:-$(pwd)/logs}"
    export SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$script_path")}"
    export TEST_SUITE_DIR="${TEST_SUITE_DIR:-$SCRIPT_DIR}"

    # Execute test script and capture result
    local start_time
    start_time=$(date +%s)

    if "$script_path"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_suite_info "✓ Test script passed: $script_name (${duration}s)"
        TEST_SUITE_PASSED=$((TEST_SUITE_PASSED + 1))
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_suite_error "✗ Test script failed: $script_name (${duration}s)"
        TEST_SUITE_FAILED_LIST+=("$script_name")
        TEST_SUITE_FAILED=$((TEST_SUITE_FAILED + 1))
        return 1
    fi
}

# =============================================================================
# Test Summary Reporting
# =============================================================================

# Print test execution summary
print_test_summary() {
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - TEST_SUITE_START_TIME))

    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Test Execution Summary${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    echo "Total tests:  $TEST_SUITE_TOTAL"
    echo -e "Passed:       ${GREEN}${TEST_SUITE_PASSED}${NC}"
    echo -e "Failed:       ${RED}${TEST_SUITE_FAILED}${NC}"
    echo "Duration:     ${total_duration}s"

    if [ "$TEST_SUITE_FAILED" -gt 0 ]; then
        echo ""
        echo -e "${RED}Failed tests:${NC}"
        for test in "${TEST_SUITE_FAILED_LIST[@]}"; do
            echo -e "  ${RED}✗${NC} $test"
        done
        echo ""
        log_suite_error "Test suite completed with $TEST_SUITE_FAILED failure(s)"
        return 1
    else
        echo ""
        log_suite_info "✓ All tests passed successfully"
        return 0
    fi
}

# =============================================================================
# Conditional Test Execution
# =============================================================================

# Run test script if condition is met
run_test_if() {
    local condition_fn="$1"
    local script_name="$2"
    local script_path="${3:-${TEST_SUITE_DIR:-$(pwd)}/$script_name}"

    if "$condition_fn"; then
        run_test_script "$script_name" "$script_path"
    else
        log_suite_info "Skipping test (condition not met): $script_name"
    fi
}

# Export functions for subshells
export -f init_test_runner
export -f check_script_executable
export -f run_test_script
export -f print_test_summary
export -f run_test_if
