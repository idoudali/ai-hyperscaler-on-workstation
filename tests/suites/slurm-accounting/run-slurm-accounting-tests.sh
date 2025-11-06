#!/bin/bash
# SLURM Accounting database validation test suite
# Part of Task 016: Configure SLURM Accounting and Database

set -euo pipefail

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
SCRIPT_NAME="run-slurm-accounting-tests.sh"
TEST_SUITE_NAME="SLURM Accounting Test Suite"
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

log_success() {
    log_with_context "SUCCESS" "$1"
}

log_debug() {
    log_with_context "DEBUG" "$1"
}

# Test tracking (using shared TEST_SUITE_* variables from suite-test-runner.sh)
TESTS_RUN=0
TESTS_PASSED=0
FAILED_TESTS=0
FAILED_DETAILS=()

run_test_case() {
    local test_name="$1"
    local test_fn="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    log_info "Starting test: $test_name"

    if "$test_fn"; then
        log_success "✓ Test passed: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "✗ Test failed: $test_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_DETAILS+=("$test_name")
    fi
}

# Individual test functions
check_slurmdbd_service() {
    if systemctl is-active --quiet slurmdbd; then
        log_success "slurmdbd service is running"
        return 0
    fi

    log_error "slurmdbd service is not running"
    return 1
}

check_slurmdbd_config() {
    local config_path="/etc/slurm/slurmdbd.conf"

    if [[ -f "$config_path" ]]; then
        log_success "slurmdbd configuration file exists: $config_path"
        return 0
    fi

    log_error "slurmdbd configuration file not found: $config_path"
    return 1
}

check_database_service() {
    if systemctl is-active --quiet mariadb 2>/dev/null || systemctl is-active --quiet mysql 2>/dev/null; then
        log_success "Database service is running (mariadb/mysql)"
        return 0
    fi

    log_error "Database service is not running (expected mariadb or mysql)"
    return 1
}

check_slurm_log_directory() {
    local log_dir="/var/log/slurm"

    if [[ -d "$log_dir" ]]; then
        log_success "SLURM log directory exists: $log_dir"
        return 0
    fi

    log_error "SLURM log directory not found: $log_dir"
    return 1
}

check_controller_accounting_config() {
    local controller_conf="/etc/slurm/slurm.conf"

    if grep -q "AccountingStorageType=accounting_storage/slurmdbd" "$controller_conf" 2>/dev/null; then
        log_success "Controller accounting storage configured in slurm.conf"
        return 0
    fi

    log_warn "AccountingStorageType not configured as slurmdbd in slurm.conf"
    return 0
}

check_cluster_association() {
    if sacctmgr list clusters -p 2>/dev/null | grep -q "hpc"; then
        log_success "Cluster association exists in accounting database"
        return 0
    fi

    log_warn "Cluster association not found in accounting database (may need initialization)"
    return 0
}

# Main execution
main() {
    log_info "Log directory: $LOG_DIR"
    log_info "Test suite directory: $TEST_SUITE_DIR"

    run_test_case "slurmdbd service status" check_slurmdbd_service
    run_test_case "slurmdbd configuration file" check_slurmdbd_config
    run_test_case "database service status" check_database_service
    run_test_case "SLURM log directory" check_slurm_log_directory
    run_test_case "controller accounting configuration" check_controller_accounting_config
    run_test_case "cluster association" check_cluster_association

    # Update shared test suite variables for consistency
    TEST_SUITE_TOTAL=$TESTS_RUN
    log_debug "Total tests executed: $TEST_SUITE_TOTAL"
    TEST_SUITE_PASSED=$TESTS_PASSED
    log_debug "Tests passed: $TEST_SUITE_PASSED"
    TEST_SUITE_FAILED=$FAILED_TESTS
    log_debug "Tests failed: $TEST_SUITE_FAILED"
    TEST_SUITE_FAILED_LIST=("${FAILED_DETAILS[@]}")
    if [ "${#TEST_SUITE_FAILED_LIST[@]}" -gt 0 ]; then
        log_debug "Failed test details: ${TEST_SUITE_FAILED_LIST[*]}"
    fi

    # Use shared summary printing
    print_test_summary
}

main "$@" || exit $?
