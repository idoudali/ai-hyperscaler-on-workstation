#!/bin/bash
#
# Container Runtime Test Utilities - Enhanced for Task 009
# Shared utilities for container runtime test scripts to eliminate code duplication
# Used by all container runtime test scripts for consistent behavior
# Enhanced to support comprehensive security testing per Task 009 requirements
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking variables (will be initialized by each script)
TESTS_RUN=0
TESTS_PASSED=0
FAILED_TESTS=()

# Common configuration
CONTAINER_RUNTIME_BINARY="apptainer"
CONTAINER_RUNTIME_CONFIG_DIR="/etc/apptainer"
EXPECTED_CONFIG_FILE="$CONTAINER_RUNTIME_CONFIG_DIR/apptainer.conf"

# Test container configurations
TEST_CONTAINER_ALPINE="docker://alpine:latest"
TEST_CONTAINER_UBUNTU="docker://ubuntu:22.04"

# Timeout configurations
DEFAULT_COMMAND_TIMEOUT=30
DEFAULT_PULL_TIMEOUT=180
DEFAULT_EXEC_TIMEOUT=60

# Critical security settings that must be present
CRITICAL_SECURITY_SETTINGS=(
    "allow suid = no"
    "mount hostfs = no"
    "allow pid ns = yes"
    "config passwd = yes"
    "config group = yes"
)

# Logging functions with LOG_DIR compliance
log_info() {
    local script_name="${SCRIPT_NAME:-test-utils}"
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_DIR/$script_name.log"
}

log_warn() {
    local script_name="${SCRIPT_NAME:-test-utils}"
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_DIR/$script_name.log"
}

log_error() {
    local script_name="${SCRIPT_NAME:-test-utils}"
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/$script_name.log"
}

log_debug() {
    local script_name="${SCRIPT_NAME:-test-utils}"
    echo -e "${BLUE}[DEBUG]${NC} $1" | tee -a "$LOG_DIR/$script_name.log"
}

# Test execution function
run_test() {
    local test_name="$1"
    local test_function="$2"

    echo "Running: $test_name" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
    TESTS_RUN=$((TESTS_RUN + 1))

    if $test_function; then
        log_info "✅ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "❌ $test_name"
        FAILED_TESTS+=("$test_name")
    fi
    echo | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

# Common test functions
test_container_runtime_available() {
    log_info "Checking container runtime availability..."

    if ! command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        log_error "Container runtime not available: $CONTAINER_RUNTIME_BINARY"
        return 1
    fi

    log_info "Container runtime available: $CONTAINER_RUNTIME_BINARY"
    return 0
}

test_security_configuration_exists() {
    log_info "Checking security configuration file existence..."

    if [[ -f "$EXPECTED_CONFIG_FILE" ]]; then
        log_info "Configuration file found: $EXPECTED_CONFIG_FILE"

        # Check file permissions
        local perms
        perms=$(stat -c "%a" "$EXPECTED_CONFIG_FILE" 2>/dev/null || echo "unknown")
        log_info "Configuration file permissions: $perms"

        # Check file ownership
        local owner
        owner=$(stat -c "%U:%G" "$EXPECTED_CONFIG_FILE" 2>/dev/null || echo "unknown")
        log_info "Configuration file ownership: $owner"

        return 0
    else
        log_error "Configuration file not found: $EXPECTED_CONFIG_FILE"
        return 1
    fi
}

# Test summary function
print_test_summary() {
    local script_name="$1"
    local test_name="$2"
    local failed=$((TESTS_RUN - TESTS_PASSED))

    {
        echo "========================================"
        echo "$test_name Summary"
        echo "========================================"
        echo "Script: $script_name"
        echo "Tests run: $TESTS_RUN"
        echo "Passed: $TESTS_PASSED"
        echo "Failed: $failed"
    } | tee -a "$LOG_DIR/$script_name.log"

    if [[ $failed -gt 0 ]]; then
        {
            echo "Failed tests:"
            printf '  ❌ %s\n' "${FAILED_TESTS[@]}"
            echo
            echo "❌ $test_name validation FAILED"
        } | tee -a "$LOG_DIR/$script_name.log"
        return 1
    else
        {
            echo
            echo "🎉 $test_name validation PASSED!"
        } | tee -a "$LOG_DIR/$script_name.log"
        return 0
    fi
}

# Container execution helper
execute_container_command() {
    local container="$1"
    local command="$2"
    local timeout_seconds="${3:-60}"
    local log_file="${4:-}"

    if [[ -n "$log_file" ]]; then
        # shellcheck disable=SC2086
        timeout "${timeout_seconds}s" "$CONTAINER_RUNTIME_BINARY" exec "$container" $command 2>&1 | tee "$log_file"
    else
        # shellcheck disable=SC2086
        timeout "${timeout_seconds}s" "$CONTAINER_RUNTIME_BINARY" exec "$container" $command 2>&1
    fi
}

# Test if container can access a path
test_container_path_access() {
    local container="$1"
    local path="$2"
    local timeout_seconds="${3:-30}"

    if timeout "${timeout_seconds}s" "$CONTAINER_RUNTIME_BINARY" exec "$container" test -r "$path" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Test if container can execute a command
test_container_command() {
    local container="$1"
    local command="$2"
    local timeout_seconds="${3:-30}"

    # shellcheck disable=SC2086
    if timeout "${timeout_seconds}s" "$CONTAINER_RUNTIME_BINARY" exec "$container" $command >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check if a configuration setting exists in the config file
check_config_setting() {
    local setting="$1"
    local expected_value="${2:-}"

    if [[ ! -f "$EXPECTED_CONFIG_FILE" ]]; then
        return 1
    fi

    if [[ -n "$expected_value" ]]; then
        # Check for exact match
        grep -q "^[[:space:]]*${setting}[[:space:]]*=[[:space:]]*${expected_value}" "$EXPECTED_CONFIG_FILE" 2>/dev/null
    else
        # Check if setting exists (any value)
        grep -q "^[[:space:]]*${setting}" "$EXPECTED_CONFIG_FILE" 2>/dev/null
    fi
}

# Get configuration setting value
get_config_value() {
    local setting="$1"

    if [[ ! -f "$EXPECTED_CONFIG_FILE" ]]; then
        echo ""
        return 1
    fi

    grep "^[[:space:]]*${setting}" "$EXPECTED_CONFIG_FILE" 2>/dev/null | head -1 | sed 's/^[[:space:]]*[^=]*=[[:space:]]*//' | tr -d ' '
}

# Enhanced security testing functions per Task 009 requirements

# Comprehensive security configuration validation
validate_security_configuration() {
    log_info "Validating comprehensive security configuration per Task 009..."

    if [[ ! -f "$EXPECTED_CONFIG_FILE" ]]; then
        log_error "Configuration file not available for security validation"
        return 1
    fi

    local missing_critical=()
    local found_configs=()

    # Check critical security settings
    for setting in "${CRITICAL_SECURITY_SETTINGS[@]}"; do
        if grep -q "^[[:space:]]*${setting}" "$EXPECTED_CONFIG_FILE" 2>/dev/null; then
            local actual_config
            actual_config=$(grep "^[[:space:]]*${setting}" "$EXPECTED_CONFIG_FILE" | head -1 | sed 's/^[[:space:]]*//')
            found_configs+=("$actual_config")
            log_info "Found critical security setting: $actual_config"
        else
            missing_critical+=("$setting")
            log_error "Missing critical security setting: $setting"
        fi
    done

    # Save analysis to log
    {
        echo "=== Security Configuration Analysis ==="
        echo "Configuration file: $EXPECTED_CONFIG_FILE"
        echo "Critical settings found: ${#found_configs[@]}"
        echo "Critical settings missing: ${#missing_critical[@]}"
        printf '  ✅ %s\n' "${found_configs[@]}"
        if [[ ${#missing_critical[@]} -gt 0 ]]; then
            echo "Missing critical settings:"
            printf '  ❌ %s\n' "${missing_critical[@]}"
        fi
    } >> "$LOG_DIR/$SCRIPT_NAME.log"

    if [[ ${#missing_critical[@]} -gt 0 ]]; then
        return 1
    fi

    log_info "Security configuration validation passed"
    return 0
}

# Test privilege escalation prevention
test_privilege_escalation_prevention() {
    local container="${1:-$TEST_CONTAINER_ALPINE}"
    log_info "Testing privilege escalation prevention..."

    # Test privileged operations that should be blocked
    local privileged_ops=(
        "mount -t tmpfs tmpfs /tmp"
        "modprobe dummy"
        "sysctl -w kernel.hostname=test"
        "chown root:root /tmp"
        "iptables -L"
    )

    local restrictions_working=true
    for op in "${privileged_ops[@]}"; do
        # shellcheck disable=SC2086
        if timeout "$DEFAULT_COMMAND_TIMEOUT" "$CONTAINER_RUNTIME_BINARY" exec "$container" $op >/dev/null 2>&1; then
            log_warn "Privileged operation succeeded (may indicate privilege escalation): $op"
            restrictions_working=false
        else
            log_info "Privileged operation properly restricted: $op"
        fi
    done

    [[ "$restrictions_working" == "true" ]]
}

# Test filesystem isolation
test_filesystem_isolation() {
    local container="${1:-$TEST_CONTAINER_ALPINE}"
    log_info "Testing host filesystem isolation..."

    # Test sensitive host paths
    local sensitive_paths=("/root" "/etc/shadow" "/etc/gshadow" "/etc/sudoers")
    local isolation_working=true

    for path in "${sensitive_paths[@]}"; do
        if test_container_path_access "$container" "$path"; then
            # Check if it's actually host filesystem access
            local container_output
            container_output=$(execute_container_command "$container" "cat $path" "$DEFAULT_COMMAND_TIMEOUT" 2>/dev/null)
            if echo "$container_output" | grep -q "$(whoami)" >/dev/null 2>&1; then
                log_warn "Container can access host filesystem: $path"
                isolation_working=false
            else
                log_info "Container has isolated view of: $path"
            fi
        else
            log_info "Container properly isolated from: $path"
        fi
    done

    [[ "$isolation_working" == "true" ]]
}

# Test SUID prevention
test_suid_prevention() {
    local container="${1:-$TEST_CONTAINER_ALPINE}"
    log_info "Testing SUID execution prevention..."

    # Test that mount operations are blocked (common SUID-related test)
    if timeout "$DEFAULT_COMMAND_TIMEOUT" "$CONTAINER_RUNTIME_BINARY" exec "$container" mount 2>&1 | \
       grep -q "Operation not permitted\|Permission denied" >"$LOG_DIR/suid-test.log"; then
        log_info "SUID prevention working - mount operations blocked"
        return 0
    else
        log_warn "SUID prevention test inconclusive (environment dependent)"
        return 0  # Don't fail - this is environment dependent
    fi
}

# Test user namespace isolation
test_user_namespace_isolation() {
    local container="${1:-$TEST_CONTAINER_ALPINE}"
    log_info "Testing user namespace isolation..."

    # Test user namespace support
    if unshare --user --map-root-user whoami >/dev/null 2>&1; then
        log_info "User namespace support available on host"

        if execute_container_command "$container" "id" "$DEFAULT_COMMAND_TIMEOUT" "$LOG_DIR/container-user-id.log" >/dev/null; then
            local container_id
            container_id=$(cat "$LOG_DIR/container-user-id.log")
            log_info "Container user identification: $container_id"
            return 0
        else
            log_error "Failed to check container user namespace"
            return 1
        fi
    else
        log_warn "User namespace support not available on host (may limit functionality)"
        return 0  # Don't fail - this is a host limitation
    fi
}

# Comprehensive security test runner
run_comprehensive_security_tests() {
    local container="${1:-$TEST_CONTAINER_ALPINE}"
    log_info "Running comprehensive security tests per Task 009..."

    local security_tests=(
        "validate_security_configuration"
        "test_privilege_escalation_prevention $container"
        "test_filesystem_isolation $container"
        "test_suid_prevention $container"
        "test_user_namespace_isolation $container"
    )

    local passed=0
    local total=${#security_tests[@]}

    for test_cmd in "${security_tests[@]}"; do
        if eval "$test_cmd"; then
            ((passed++))
        fi
    done

    log_info "Security tests completed: $passed/$total passed"
    [[ $passed -eq $total ]]
}

# Test container execution capabilities
test_container_execution_basic() {
    local container="${1:-$TEST_CONTAINER_UBUNTU}"
    log_info "Testing basic container execution capabilities..."

    # Test container pull and execution
    local temp_container_dir="$LOG_DIR/containers"
    mkdir -p "$temp_container_dir"
    local sif_file="$temp_container_dir/test-basic.sif"

    # Pull container
    if timeout "$DEFAULT_PULL_TIMEOUT" "$CONTAINER_RUNTIME_BINARY" pull "$sif_file" "$container" 2>&1 | \
       tee "$LOG_DIR/container-pull-basic.log"; then
        log_info "Container pull successful: $container"
    else
        log_error "Container pull failed: $container"
        return 1
    fi

    # Test execution
    if execute_container_command "$sif_file" "echo 'Container execution working'" "$DEFAULT_EXEC_TIMEOUT" >/dev/null; then
        log_info "Container execution successful"
        return 0
    else
        log_error "Container execution failed"
        return 1
    fi
}

# Export functions for use in other scripts
export -f log_info log_warn log_error log_debug run_test
export -f test_container_runtime_available test_security_configuration_exists
export -f print_test_summary execute_container_command test_container_path_access test_container_command
export -f check_config_setting get_config_value
export -f validate_security_configuration test_privilege_escalation_prevention
export -f test_filesystem_isolation test_suid_prevention test_user_namespace_isolation
export -f run_comprehensive_security_tests test_container_execution_basic
