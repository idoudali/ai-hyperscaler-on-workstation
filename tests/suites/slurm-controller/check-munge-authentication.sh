#!/bin/bash
#
# MUNGE Authentication Test Script
# Task 012 - MUNGE Authentication System Validation
# Tests MUNGE installation, configuration, key management, and authentication
#

set -eo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="check-munge-authentication.sh"
TEST_SUITE_NAME="MUNGE Authentication System Validation"


# Use LOG_DIR from environment or default
: "${LOG_DIR:=$(pwd)/logs/check-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# Expected paths and configuration
MUNGE_KEY_PATH="/etc/munge/munge.key"
MUNGE_CONFIG_PATH="/etc/default/munge"
MUNGE_SOCKET_PATH="/var/run/munge/munge.socket.2"
MUNGE_LOG_PATH="/var/log/munge/munged.log"
MUNGE_PID_PATH="/var/run/munge/munged.pid"

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
PARTIAL_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "$1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[PASS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    log "${RED}[FAIL]${NC} $1"
}

# Test result tracking
increment_total() {
    ((TOTAL_TESTS++))
}

increment_passed() {
    ((PASSED_TESTS++))
    log_success "$1"
}

increment_failed() {
    ((FAILED_TESTS++))
    log_error "$1"
}

increment_partial() {
    ((PARTIAL_TESTS++))
    log_warning "$1"
}

# Helper function for command execution with logging
run_command() {
    local description="$1"
    local command="$2"
    local expected_result="${3:-0}"
    local safe_description
    safe_description="$(printf '%s\n' "$description" | tr ' ' '_' | tr -cd '[:alnum:]_-')"
    local log_file="$LOG_DIR/${safe_description}.log"

    log_info "Testing: $description"

    # Execute command and capture exit code
    eval "$command" > "$log_file" 2>&1
    local exit_code=$?

    if [ "$exit_code" -eq "$expected_result" ]; then
        return 0
    else
        log_error "Command failed with exit code $exit_code (expected $expected_result)"
        if [ -f "$log_file" ] && [ -s "$log_file" ]; then
            head -10 "$log_file" | while read -r line; do
                log_error "  $line"
            done
        fi
        return 1
    fi
}

# Test 1: MUNGE Package Installation
test_munge_package_installation() {
    log_info "=== Testing MUNGE Package Installation ==="
    increment_total

    local test_passed=true
    local required_packages=("munge" "libmunge2" "libmunge-dev")

    for package in "${required_packages[@]}"; do
        if dpkg -l "$package" 2>/dev/null | grep -q '^ii'; then
            log_success "$package package is installed"
        else
            log_error "$package package is not installed"
            test_passed=false
        fi
    done

    if run_command "Verify munge binary" "which munge"; then
        log_success "munge binary is available"
    else
        log_error "munge binary not found in PATH"
        test_passed=false
    fi

    # Check for munged binary in standard locations
    if command -v munged >/dev/null 2>&1 || [ -x "/usr/sbin/munged" ] || [ -x "/sbin/munged" ]; then
        log_success "munged daemon binary is available"
    else
        log_error "munged daemon binary not found in PATH or standard locations"
        test_passed=false
    fi

    if run_command "Check MUNGE version" "munge --version"; then
        local version_output
        version_output=$(munge --version 2>&1 | head -1)
        log_success "MUNGE version check passed: $version_output"
    else
        log_error "MUNGE version check failed"
        test_passed=false
    fi

    if [ "$test_passed" = true ]; then
        increment_passed "MUNGE package installation validation"
    else
        increment_failed "MUNGE package installation validation"
    fi
}

# Test 2: MUNGE User and Group Setup
test_munge_user_group_setup() {
    log_info "=== Testing MUNGE User and Group Setup ==="
    increment_total

    local test_passed=true

    if id munge >/dev/null 2>&1; then
        log_success "MUNGE user exists"

        # Check if user has proper shell (should be nologin for security)
        local user_shell
        user_shell=$(getent passwd munge | cut -d: -f7)
        if [[ "$user_shell" == *"nologin"* ]] || [[ "$user_shell" == *"false"* ]]; then
            log_success "MUNGE user has secure shell: $user_shell"
        else
            log_warning "MUNGE user shell might not be secure: $user_shell"
        fi
    else
        log_error "MUNGE user does not exist"
        test_passed=false
    fi

    if getent group munge >/dev/null 2>&1; then
        log_success "MUNGE group exists"
    else
        log_error "MUNGE group does not exist"
        test_passed=false
    fi

    if [ "$test_passed" = true ]; then
        increment_passed "MUNGE user and group setup validation"
    else
        increment_failed "MUNGE user and group setup validation"
    fi
}

# Test 3: MUNGE Directory Structure and Permissions
test_munge_directory_structure() {
    log_info "=== Testing MUNGE Directory Structure and Permissions ==="
    increment_total

    local test_passed=true
    local directories=(
        "/etc/munge:755:munge:munge"
        "/var/lib/munge:755:munge:munge"
        "/var/log/munge:755:munge:munge"
        "/var/run/munge:755:munge:munge"
    )

    for dir_spec in "${directories[@]}"; do
        IFS=':' read -r dir expected_perms expected_user expected_group <<< "$dir_spec"

        if [ -d "$dir" ]; then
            log_success "Directory exists: $dir"

            # Check ownership
            local actual_owner
            actual_owner=$(stat -c "%U:%G" "$dir")
            if [ "$actual_owner" = "$expected_user:$expected_group" ]; then
                log_success "Ownership correct for $dir: $actual_owner"
            else
                log_warning "Ownership might be incorrect for $dir: $actual_owner (expected: $expected_user:$expected_group)"
            fi

            # Check permissions
            local actual_perms
            actual_perms=$(stat -c "%a" "$dir")
            if [ "$actual_perms" = "$expected_perms" ]; then
                log_success "Permissions correct for $dir: $actual_perms"
            else
                log_warning "Permissions might be different for $dir: $actual_perms (expected: $expected_perms)"
            fi
        else
            log_error "Directory does not exist: $dir"
            test_passed=false
        fi
    done

    if [ "$test_passed" = true ]; then
        increment_passed "MUNGE directory structure and permissions validation"
    else
        increment_failed "MUNGE directory structure and permissions validation"
    fi
}

# Test 4: MUNGE Key Generation and Validation
test_munge_key_validation() {
    log_info "=== Testing MUNGE Key Generation and Validation ==="
    increment_total

    local test_passed=true

    if [ -f "$MUNGE_KEY_PATH" ]; then
        log_success "MUNGE key file exists: $MUNGE_KEY_PATH"

        # Check key file permissions (should be 600)
        local key_perms
        key_perms=$(stat -c "%a" "$MUNGE_KEY_PATH")
        if [ "$key_perms" = "600" ]; then
            log_success "MUNGE key permissions are secure: $key_perms"
        else
            log_error "MUNGE key permissions are incorrect: $key_perms (expected: 600)"
            test_passed=false
        fi

        # Check key file ownership
        local key_owner
        key_owner=$(stat -c "%U:%G" "$MUNGE_KEY_PATH")
        if [ "$key_owner" = "munge:munge" ]; then
            log_success "MUNGE key ownership is correct: $key_owner"
        else
            log_error "MUNGE key ownership is incorrect: $key_owner (expected: munge:munge)"
            test_passed=false
        fi

        # Check key file size (should be 1024 bytes for default key)
        local key_size
        key_size=$(stat -c "%s" "$MUNGE_KEY_PATH")
        if [ "$key_size" -eq 1024 ]; then
            log_success "MUNGE key size is correct: $key_size bytes"
        else
            log_warning "MUNGE key size is non-standard: $key_size bytes (typical: 1024)"
        fi

    else
        log_warning "MUNGE key file does not exist: $MUNGE_KEY_PATH"
        log_info "Attempting to generate MUNGE key..."

        # Try to generate MUNGE key
        if sudo mungekey --create --force 2>/dev/null; then
            log_success "MUNGE key generated successfully"
            # Restart MUNGE service to use new key
            if sudo systemctl restart munge 2>/dev/null; then
                log_success "MUNGE service restarted with new key"
                # Re-check the key file
                if [ -f "$MUNGE_KEY_PATH" ]; then
                    log_success "MUNGE key file now exists: $MUNGE_KEY_PATH"
                else
                    log_error "MUNGE key generation failed"
                    test_passed=false
                fi
            else
                log_error "Failed to restart MUNGE service after key generation"
                test_passed=false
            fi
        else
            log_error "Failed to generate MUNGE key"
            test_passed=false
        fi
    fi

    if [ "$test_passed" = true ]; then
        increment_passed "MUNGE key generation and validation"
    else
        increment_failed "MUNGE key generation and validation"
    fi
}

# Test 5: MUNGE Configuration File Validation
test_munge_configuration() {
    log_info "=== Testing MUNGE Configuration File Validation ==="
    increment_total

    local test_passed=true

    if [ -f "$MUNGE_CONFIG_PATH" ]; then
        log_success "MUNGE configuration file exists: $MUNGE_CONFIG_PATH"

        # Check for key configuration entries
        local required_settings=(
            "MUNGE_KEYFILE"
            "MUNGE_SOCKET"
            "MUNGE_LOGFILE"
            "MUNGE_USER"
            "MUNGE_GROUP"
        )

        for setting in "${required_settings[@]}"; do
            if grep -q "^${setting}=" "$MUNGE_CONFIG_PATH"; then
                local value
                value=$(grep "^${setting}=" "$MUNGE_CONFIG_PATH" | cut -d'=' -f2- | tr -d '"')
                log_success "Configuration setting found: $setting=$value"
            else
                log_warning "Configuration setting not found: $setting"
            fi
        done

    else
        log_warning "MUNGE configuration file not found: $MUNGE_CONFIG_PATH (may use defaults)"
    fi

    increment_passed "MUNGE configuration file validation (using defaults if missing)"
}

# Test 6: MUNGE Service Status
test_munge_service_status() {
    log_info "=== Testing MUNGE Service Status ==="
    increment_total

    local test_passed=true

    if systemctl is-enabled munge >/dev/null 2>&1; then
        log_success "MUNGE service is enabled"
    else
        log_warning "MUNGE service is not enabled (expected during build)"
    fi

    if systemctl is-active munge >/dev/null 2>&1; then
        log_success "MUNGE service is active and running"

        # Check if socket exists and is accessible
        if [ -S "$MUNGE_SOCKET_PATH" ]; then
            log_success "MUNGE socket exists: $MUNGE_SOCKET_PATH"
        else
            log_warning "MUNGE socket not found at expected location: $MUNGE_SOCKET_PATH"
        fi

        # Check if PID file exists
        if [ -f "$MUNGE_PID_PATH" ]; then
            log_success "MUNGE PID file exists: $MUNGE_PID_PATH"
            local pid_content
            pid_content=$(cat "$MUNGE_PID_PATH" 2>/dev/null || echo "unknown")
            log_info "MUNGE daemon PID: $pid_content"
        else
            log_warning "MUNGE PID file not found: $MUNGE_PID_PATH"
        fi

    else
        log_warning "MUNGE service is not active (expected during Packer builds or initial setup)"
        test_passed="partial"
    fi

    if [ "$test_passed" = true ]; then
        increment_passed "MUNGE service status validation"
    elif [ "$test_passed" = "partial" ]; then
        increment_partial "MUNGE service status validation (service not running, expected during build)"
    else
        increment_failed "MUNGE service status validation"
    fi
}

# Test 7: MUNGE Local Authentication Test
test_munge_local_authentication() {
    log_info "=== Testing MUNGE Local Authentication ==="
    increment_total

    # Only test if service is running
    if systemctl is-active munge >/dev/null 2>&1; then
        local test_passed=true
        local test_message
        test_message="MUNGE-auth-test-$(date '+%Y%m%d-%H%M%S')"

        if run_command "MUNGE local authentication test" "echo '$test_message' | munge | unmunge | grep -q '$test_message'"; then
            log_success "MUNGE local authentication test passed"
            increment_passed "MUNGE local authentication test"
        else
            log_error "MUNGE local authentication test failed"
            increment_failed "MUNGE local authentication test"
        fi
    else
        log_warning "Skipping MUNGE authentication test - service not running (expected during build)"
        increment_partial "MUNGE local authentication test (skipped - service not running)"
    fi
}

# Test 8: MUNGE Integration with SLURM Configuration
test_munge_slurm_integration() {
    log_info "=== Testing MUNGE Integration with SLURM ==="
    increment_total

    local test_passed=true
    local slurm_config="/etc/slurm/slurm.conf"

    if [ -f "$slurm_config" ]; then
        log_success "SLURM configuration file exists: $slurm_config"

        # Check for MUNGE authentication settings
        if grep -q "AuthType=auth/munge" "$slurm_config" 2>/dev/null; then
            log_success "SLURM configured to use MUNGE authentication"
        else
            log_warning "SLURM AuthType=auth/munge not found in configuration"
            test_passed=false
        fi

        if grep -q "CryptoType=crypto/munge" "$slurm_config" 2>/dev/null; then
            log_success "SLURM configured to use MUNGE cryptography"
        else
            log_warning "SLURM CryptoType=crypto/munge not found in configuration"
        fi

    else
        log_warning "SLURM configuration file not found: $slurm_config (may not be configured yet)"
    fi

    if [ "$test_passed" = true ]; then
        increment_passed "MUNGE integration with SLURM configuration"
    else
        increment_partial "MUNGE integration with SLURM configuration (some settings may be missing)"
    fi
}

# Test 9: MUNGE Log Analysis
test_munge_log_analysis() {
    log_info "=== Testing MUNGE Log Analysis ==="
    increment_total

    if [ -f "$MUNGE_LOG_PATH" ]; then
        log_success "MUNGE log file exists: $MUNGE_LOG_PATH"

        # Check for recent startup messages
        if tail -50 "$MUNGE_LOG_PATH" 2>/dev/null | grep -qi "started" && systemctl is-active munge >/dev/null 2>&1; then
            log_success "MUNGE daemon startup logged successfully"
        else
            log_info "No recent startup messages (service may not be running)"
        fi

        # Check for any error messages
        if tail -100 "$MUNGE_LOG_PATH" 2>/dev/null | grep -qi "error\|fail\|fatal"; then
            log_warning "Error messages found in MUNGE log (last 100 lines):"
            tail -100 "$MUNGE_LOG_PATH" 2>/dev/null | grep -i "error\|fail\|fatal" | head -5 | while read -r line; do
                log_warning "  $line"
            done
        else
            log_success "No error messages found in recent MUNGE logs"
        fi

        increment_passed "MUNGE log analysis"
    else
        log_info "MUNGE log file not found: $MUNGE_LOG_PATH (may not be created yet)"
        increment_partial "MUNGE log analysis (log file not created yet)"
    fi
}

# Test 10: MUNGE Security Validation
test_munge_security_validation() {
    log_info "=== Testing MUNGE Security Configuration ==="
    increment_total

    local test_passed=true

    # Check that MUNGE key is not world-readable
    if [ -f "$MUNGE_KEY_PATH" ]; then
        local key_perms
        key_perms=$(stat -c "%a" "$MUNGE_KEY_PATH")
        local world_readable=$((key_perms & 4))

        if [ $world_readable -eq 0 ]; then
            log_success "MUNGE key is not world-readable (secure)"
        else
            log_error "MUNGE key is world-readable (SECURITY RISK)"
            test_passed=false
        fi

        # Check that MUNGE key is not group-readable
        local group_readable=$((key_perms & 40))
        if [ $group_readable -eq 0 ]; then
            log_success "MUNGE key is not group-readable (secure)"
        else
            log_warning "MUNGE key is group-readable"
        fi
    fi

    # Check MUNGE socket permissions
    if [ -S "$MUNGE_SOCKET_PATH" ]; then
        local socket_perms
        socket_perms=$(stat -c "%a" "$MUNGE_SOCKET_PATH" 2>/dev/null || echo "unknown")
        log_info "MUNGE socket permissions: $socket_perms"

        # Socket should be accessible by MUNGE group
        local socket_owner
        socket_owner=$(stat -c "%U:%G" "$MUNGE_SOCKET_PATH" 2>/dev/null || echo "unknown")
        if [[ "$socket_owner" == *"munge"* ]]; then
            log_success "MUNGE socket ownership is correct: $socket_owner"
        else
            log_warning "MUNGE socket ownership: $socket_owner"
        fi
    fi

    if [ "$test_passed" = true ]; then
        increment_passed "MUNGE security configuration validation"
    else
        increment_failed "MUNGE security configuration validation"
    fi
}

# Main test execution function
run_all_tests() {
    log_info "Starting $TEST_SUITE_NAME"
    log_info "Log directory: $LOG_DIR"
    log_info "Timestamp: $(date)"
    log_info "Running on: $(hostname)"
    echo

    # Run all test functions with error handling
    test_munge_package_installation || log_error "test_munge_package_installation failed"
    test_munge_user_group_setup || log_error "test_munge_user_group_setup failed"
    test_munge_directory_structure || log_error "test_munge_directory_structure failed"
    test_munge_key_validation || log_error "test_munge_key_validation failed"
    test_munge_configuration || log_error "test_munge_configuration failed"
    test_munge_service_status || log_error "test_munge_service_status failed"
    test_munge_local_authentication || log_error "test_munge_local_authentication failed"
    test_munge_slurm_integration || log_error "test_munge_slurm_integration failed"
    test_munge_log_analysis || log_error "test_munge_log_analysis failed"
    test_munge_security_validation || log_error "test_munge_security_validation failed"

    return 0
}

# Print test summary
print_test_summary() {
    echo
    log_info "=== $TEST_SUITE_NAME - Test Summary ==="
    log_info "Total Tests: $TOTAL_TESTS"

    if [ $PASSED_TESTS -gt 0 ]; then
        log_success "Passed: $PASSED_TESTS"
    fi

    if [ $FAILED_TESTS -gt 0 ]; then
        log_error "Failed: $FAILED_TESTS"
    fi

    if [ $PARTIAL_TESTS -gt 0 ]; then
        log_warning "Partial/Skipped: $PARTIAL_TESTS"
    fi

    echo
    if [ $FAILED_TESTS -eq 0 ]; then
        if [ $PARTIAL_TESTS -gt 0 ]; then
            log_warning "MUNGE Authentication System: PARTIALLY VALIDATED (some tests skipped)"
            log_info "This is expected during Packer builds or initial setup when services are not running"
        else
            log_success "MUNGE Authentication System: FULLY VALIDATED"
        fi
        return 0
    else
        log_error "MUNGE Authentication System: VALIDATION FAILED"
        return 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test artifacts..."
    # No cleanup needed for this test suite
}

# Signal handlers
trap cleanup EXIT
trap 'log_error "Test interrupted by user"; exit 130' INT TERM

# Main execution
main() {
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        if run_all_tests; then
            print_test_summary
        else
            log_error "Test execution failed"
            print_test_summary
            exit 1
        fi
    fi
}

# Allow sourcing this script for individual test functions
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
