#!/bin/bash
# Shared check script helpers
# Provides standardized logging and test execution functions for individual check scripts
#
# This file should be sourced by all check scripts (check-*.sh files)
# It provides:
# - Logging functions that integrate with suite-logging if available
# - Test execution and tracking functions
# - Color constants
# - Common patterns for check scripts

# Prevent multiple sourcing
[ -n "${SUITE_CHECK_HELPERS_LOADED:-}" ] && return 0
readonly SUITE_CHECK_HELPERS_LOADED=1

# =============================================================================
# Color Constants
# =============================================================================

# Define colors if not already defined
if [ -z "${RED:-}" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

# =============================================================================
# Logging Functions
# =============================================================================

# Logging functions that integrate with suite-logging when available
# Falls back to simple colored echo if suite-logging is not loaded

log_info() {
    if command -v log_with_context >/dev/null 2>&1; then
        log_with_context "INFO" "$1"
    elif command -v log_suite_info >/dev/null 2>&1; then
        log_suite_info "$@"
    else
        echo -e "${GREEN}[INFO]${NC} $1"
    fi
}

log_warn() {
    if command -v log_with_context >/dev/null 2>&1; then
        log_with_context "WARN" "$1"
    elif command -v log_suite_warning >/dev/null 2>&1; then
        log_suite_warning "$@"
    else
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_error() {
    if command -v log_with_context >/dev/null 2>&1; then
        log_with_context "ERROR" "$1"
    elif command -v log_suite_error >/dev/null 2>&1; then
        log_suite_error "$@"
    else
        echo -e "${RED}[ERROR]${NC} $1"
    fi
}

log_debug() {
    if command -v log_with_context >/dev/null 2>&1; then
        log_with_context "DEBUG" "$1"
    elif command -v log_suite_debug >/dev/null 2>&1; then
        log_suite_debug "$@"
    else
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

log_success() {
    if command -v log_with_context >/dev/null 2>&1; then
        log_with_context "SUCCESS" "$1"
    elif command -v log_suite_success >/dev/null 2>&1; then
        log_suite_success "$@"
    else
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

# =============================================================================
# Test Execution Functions
# =============================================================================

# Initialize test tracking variables (if not already set)
init_check_tests() {
    export TESTS_RUN=${TESTS_RUN:-0}
    export TESTS_PASSED=${TESTS_PASSED:-0}
    export FAILED_TESTS=()
}

# Run a single test with standardized tracking
# Usage: run_test "test_name" test_function
run_test() {
    local test_name="$1"
    local test_function="$2"

    # Initialize if needed
    init_check_tests

    TESTS_RUN=$((TESTS_RUN + 1))

    echo -e "\n${BLUE}Running Test ${TESTS_RUN}: ${test_name}${NC}"

    if $test_function; then
        log_info "✓ Test passed: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ Test failed: $test_name"
        FAILED_TESTS+=("$test_name")
        return 1
    fi
}

# Print test summary (standardized format)
print_check_summary() {
    local failed_count=$((TESTS_RUN - TESTS_PASSED))

    echo ""
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}  Test Results Summary${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo "Total tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}${failed_count}${NC}"

    if [ $failed_count -gt 0 ]; then
        echo ""
        echo -e "${RED}Failed tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  - ${RED}$test${NC}"
        done
        return 1
    fi

    return 0
}

# =============================================================================
# SSH and Remote Execution Helpers
# =============================================================================

# Check if running in remote mode (via SSH)
check_remote_mode() {
    if [ "${TEST_MODE:-local}" = "remote" ] && [ -n "${CONTROLLER_IP:-}" ]; then
        return 0
    fi
    return 1
}

# Execute command on controller via SSH
# Usage: run_ssh "command"
run_ssh() {
    local cmd="$1"
    local ssh_key="${SSH_KEY_PATH:-}"
    local ssh_user="${SSH_USER:-admin}"
    local controller_ip="${CONTROLLER_IP:-}"

    if [ -z "$controller_ip" ]; then
        log_error "CONTROLLER_IP not set for remote execution"
        return 1
    fi

    local ssh_opts=(
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o LogLevel=ERROR
    )

    if [ -n "$ssh_key" ]; then
        # shellcheck disable=SC2029
        ssh "${ssh_opts[@]}" -i "$ssh_key" "${ssh_user}@${controller_ip}" "$cmd"
    else
        # shellcheck disable=SC2029
        ssh "${ssh_opts[@]}" "${ssh_user}@${controller_ip}" "$cmd"
    fi
}

# =============================================================================
# Common Validation Helpers
# =============================================================================

# Check if a package is installed (dpkg-based systems)
check_package_installed() {
    local package="$1"
    if dpkg -l | grep -q "^ii.*$package"; then
        return 0
    fi
    return 1
}

# Check if a service is running
check_service_running() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        return 0
    fi
    return 1
}

# Check if a file exists
check_file_exists() {
    local file="$1"
    if [ -f "$file" ]; then
        return 0
    fi
    return 1
}

# Check if a directory exists
check_dir_exists() {
    local dir="$1"
    if [ -d "$dir" ]; then
        return 0
    fi
    return 1
}

# Check if a binary is available in PATH
check_binary_available() {
    local binary="$1"
    if command -v "$binary" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# =============================================================================
# Initialization
# =============================================================================

# Auto-initialize test tracking
init_check_tests
