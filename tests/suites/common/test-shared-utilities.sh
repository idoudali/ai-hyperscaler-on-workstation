#!/bin/bash
#
# Test Script for Shared Utilities
# Validates that all shared utilities load and function correctly
#

set -euo pipefail

# Script configuration
SCRIPT_NAME="test-shared-utilities.sh"
export SCRIPT_NAME
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set up environment
LOG_DIR="$(pwd)/logs/test-$(date '+%Y-%m-%d_%H-%M-%S')"
mkdir -p "$LOG_DIR"

# Source shared utilities
source "$SCRIPT_DIR/suite-config.sh"
source "$SCRIPT_DIR/suite-logging.sh"
source "$SCRIPT_DIR/suite-utils.sh"

# Initialize suite
init_suite_logging "Shared Utilities Test"
setup_suite_environment "test-shared-utilities"

# Test functions
test_config_loading() {
    log_test_start "Configuration Loading Test"

    # Test configuration getters
    local ssh_config
    ssh_config=$(get_ssh_config)
    local ssh_user
    ssh_user=$(get_ssh_user)
    local timeouts
    timeouts=$(get_test_timeouts)

    if [[ -n "$ssh_config" && -n "$ssh_user" && -n "$timeouts" ]]; then
        log_test_success "Configuration loading test"
        return 0
    else
        log_test_failure "Configuration loading test"
        return 1
    fi
}

test_logging_functions() {
    log_test_start "Logging Functions Test"

    # Test various logging functions
    log_suite_info "Testing suite info logging"
    log_suite_success "Testing suite success logging"
    log_suite_warning "Testing suite warning logging"
    log_suite_error "Testing suite error logging"

    log_test_success "Logging functions test"
    return 0
}

test_test_execution() {
    log_test_start "Test Execution Framework Test"

    # Test test execution
    local test_passed=false

    if run_test "Sample Test" "echo 'Sample test execution'"; then
        test_passed=true
    fi

    if $test_passed; then
        log_test_success "Test execution framework test"
        return 0
    else
        log_test_failure "Test execution framework test"
        return 1
    fi
}

test_validation_functions() {
    log_test_start "Validation Functions Test"

    # Test file existence check with proper path
    if check_file_exists "./suite-utils.sh" "localhost" "Utility file"; then
        log_test_success "Validation functions test"
        return 0
    else
        log_test_failure "Validation functions test"
        return 1
    fi
}

# Export test functions
export -f test_config_loading
export -f test_logging_functions
export -f test_test_execution
export -f test_validation_functions

# Main test execution
main() {
    log_suite_info "Starting shared utilities validation"

    # Run tests
    run_test "Configuration Loading" test_config_loading
    run_test "Logging Functions" test_logging_functions
    run_test "Test Execution Framework" test_test_execution
    run_test "Validation Functions" test_validation_functions

    # Collect results
    collect_test_results

    # Generate report
    generate_test_report

    # Create log summary
    create_log_summary

    # Display configuration summary
    echo
    get_config_summary "Shared Utilities Test"

    format_suite_summary "Shared Utilities Test"
}

# Run main function
main "$@"
