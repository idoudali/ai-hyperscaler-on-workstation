#!/bin/bash
#
# Test Suite Common Utilities
# Shared utilities for all test suite scripts to eliminate code duplication
# Provides standardized test execution, tracking, and common validation functions
#

set -euo pipefail

# Source existing utilities from test-infra
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source existing utilities
if [[ -f "$PROJECT_ROOT/tests/test-infra/utils/log-utils.sh" ]]; then
    source "$PROJECT_ROOT/tests/test-infra/utils/log-utils.sh"
fi

if [[ -f "$PROJECT_ROOT/tests/test-infra/utils/vm-utils.sh" ]]; then
    source "$PROJECT_ROOT/tests/test-infra/utils/vm-utils.sh"
fi

# Test tracking variables
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()
START_TIME=""
END_TIME=""

# Default configurations
DEFAULT_TEST_TIMEOUT=300
DEFAULT_SSH_TIMEOUT=30
DEFAULT_SSH_RETRIES=3

# Initialize test tracking
init_test_tracking() {
    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    FAILED_TESTS=()
    START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

    log_info "Test tracking initialized at $START_TIME"
}

# Update test results
update_test_results() {
    local result="$1"
    local test_name="$2"

    case "$result" in
        "PASS")
            TESTS_PASSED=$((TESTS_PASSED + 1))
            ;;
        "FAIL")
            TESTS_FAILED=$((TESTS_FAILED + 1))
            FAILED_TESTS+=("$test_name")
            ;;
        *)
            log_warn "Unknown test result: $result"
            ;;
    esac
}

# Get test summary statistics
get_test_summary() {
    local total=$((TESTS_PASSED + TESTS_FAILED))
    local pass_rate=0

    if [[ $total -gt 0 ]]; then
        pass_rate=$((TESTS_PASSED * 100 / total))
    fi

    echo "Tests Run: $total | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED | Pass Rate: ${pass_rate}%"
}

# Standardized test execution
run_test() {
    local test_name="$1"
    local test_function="$2"
    local timeout="${3:-$DEFAULT_TEST_TIMEOUT}"

    # Initialize tracking if not done
    if [[ -z "$START_TIME" ]]; then
        init_test_tracking
    fi

    TESTS_RUN=$((TESTS_RUN + 1))

    log_info "Running Test $TESTS_RUN: $test_name"

    # Run test with timeout
    if timeout "$timeout" bash -c "$test_function"; then
        log_success "✅ Test passed: $test_name"
        update_test_results "PASS" "$test_name"
        return 0
    else
        log_error "❌ Test failed: $test_name"
        update_test_results "FAIL" "$test_name"
        return 1
    fi
}

# Execute multiple tests in sequence
run_test_suite() {
    local suite_name="$1"
    shift
    local tests=("$@")

    log_info "Starting test suite: $suite_name"
    init_test_tracking

    local suite_passed=0
    local suite_failed=0

    for test in "${tests[@]}"; do
        if run_test "$test" "${test}_test"; then
            suite_passed=$((suite_passed + 1))
        else
            suite_failed=$((suite_failed + 1))
        fi
    done

    log_info "Suite '$suite_name' completed: $suite_passed passed, $suite_failed failed"
    return $suite_failed
}

# Collect and display test results
collect_test_results() {
    END_TIME=$(date '+%Y-%m-%d %H:%M:%S')

    echo
    log_info "=== Test Results Summary ==="
    log_info "Start Time: $START_TIME"
    log_info "End Time: $END_TIME"
    log_info "Duration: $(calculate_duration "$START_TIME" "$END_TIME")"
    log_info "$(get_test_summary)"

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        log_error "Failed Tests:"
        for test in "${FAILED_TESTS[@]}"; do
            log_error "  - $test"
        done
        return 1
    else
        log_success "All tests passed!"
        return 0
    fi
}

# Generate comprehensive test report
generate_test_report() {
    local script_name="${SCRIPT_NAME:-test-suite}"
    local report_file="$LOG_DIR/${script_name}-report.txt"

    {
        echo "Test Suite Report"
        echo "================="
        echo "Script: $script_name"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Duration: $(calculate_duration "$START_TIME" "$END_TIME")"
        echo
        get_test_summary
        echo

        if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
            echo "Failed Tests:"
            for test in "${FAILED_TESTS[@]}"; do
                echo "  - $test"
            done
        else
            echo "All tests passed successfully!"
        fi
    } > "$report_file"

    log_info "Test report saved to: $report_file"
}

# Calculate duration between timestamps
calculate_duration() {
    local start="$1"
    local end="$2"

    local start_epoch
    start_epoch=$(date -d "$start" +%s 2>/dev/null || echo "0")
    local end_epoch
    end_epoch=$(date -d "$end" +%s 2>/dev/null || echo "0")

    if [[ $start_epoch -gt 0 && $end_epoch -gt 0 ]]; then
        local duration=$((end_epoch - start_epoch))
        printf "%02d:%02d:%02d" $((duration/3600)) $((duration%3600/60)) $((duration%60))
    else
        echo "Unknown"
    fi
}

# Common validation functions

# Check if a service is running
check_service_running() {
    local service_name="$1"
    local node_ip="${2:-localhost}"
    local expected_status="${3:-active}"

    log_info "Checking service '$service_name' on $node_ip"

    local status
    if [[ "$node_ip" == "localhost" ]]; then
        status=$(systemctl is-active "$service_name" 2>/dev/null || echo "inactive")
    else
        status=$(exec_on_node "$node_ip" "systemctl is-active $service_name" 2>/dev/null || echo "inactive")
    fi

    if [[ "$status" == "$expected_status" ]]; then
        log_success "Service '$service_name' is $expected_status"
        return 0
    else
        log_error "Service '$service_name' is $status (expected $expected_status)"
        return 1
    fi
}

# Check if a file exists
check_file_exists() {
    local file_path="$1"
    local node_ip="${2:-localhost}"
    local description="${3:-File}"

    # Use simple echo if log functions not available
    if command -v log_info >/dev/null 2>&1; then
        log_info "Checking if $description exists: $file_path"
    else
        echo "Checking if $description exists: $file_path"
    fi

    local exists=false
    if [[ "$node_ip" == "localhost" ]]; then
        if [[ -f "$file_path" ]]; then
            exists=true
        fi
    else
        if exec_on_node "$node_ip" "test -f '$file_path'"; then
            exists=true
        fi
    fi

    if $exists; then
        if command -v log_success >/dev/null 2>&1; then
            log_success "$description exists: $file_path"
        else
            echo "SUCCESS: $description exists: $file_path"
        fi
        return 0
    else
        if command -v log_error >/dev/null 2>&1; then
            log_error "$description does not exist: $file_path"
        else
            echo "ERROR: $description does not exist: $file_path"
        fi
        return 1
    fi
}

# Check if a command executes successfully
check_command_success() {
    local command="$1"
    local node_ip="${2:-localhost}"
    local timeout="${3:-30}"
    local description="${4:-Command}"

    log_info "Executing $description: $command"

    local success=false
    if [[ "$node_ip" == "localhost" ]]; then
        if timeout "$timeout" bash -c "$command"; then
            success=true
        fi
    else
        if exec_on_node "$node_ip" "$command" "$timeout"; then
            success=true
        fi
    fi

    if $success; then
        log_success "$description executed successfully"
        return 0
    else
        log_error "$description failed to execute"
        return 1
    fi
}

# Check if a port is listening
check_port_listening() {
    local port="$1"
    local node_ip="${2:-localhost}"
    local protocol="${3:-tcp}"

    log_info "Checking if port $port/$protocol is listening on $node_ip"

    local listening=false
    if [[ "$node_ip" == "localhost" ]]; then
        if netstat -ln | grep -q ":$port "; then
            listening=true
        fi
    else
        if exec_on_node "$node_ip" "netstat -ln | grep -q ':$port '"; then
            listening=true
        fi
    fi

    if $listening; then
        log_success "Port $port/$protocol is listening"
        return 0
    else
        log_error "Port $port/$protocol is not listening"
        return 1
    fi
}

# SSH operations with retry logic

# Execute command on remote node
exec_on_node() {
    local node_ip="$1"
    local command="$2"
    local timeout="${3:-$DEFAULT_SSH_TIMEOUT}"
    local retries="${4:-$DEFAULT_SSH_RETRIES}"

    # Get SSH configuration
    local ssh_key_path="${SSH_KEY_PATH:-$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
    local ssh_user="${SSH_USER:-admin}"
    local ssh_opts="${SSH_OPTS:--o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR}"

    for ((i=1; i<=retries; i++)); do
        # shellcheck disable=SC2086
        if timeout "$timeout" ssh $ssh_opts -i "$ssh_key_path" "$ssh_user@$node_ip" "$command"; then
            return 0
        else
            if [[ $i -lt $retries ]]; then
                log_warn "SSH attempt $i failed, retrying in 2 seconds..."
                sleep 2
            fi
        fi
    done

    log_error "SSH execution failed after $retries attempts"
    return 1
}

# Upload file to remote node
upload_file_to_node() {
    local local_file="$1"
    local remote_path="$2"
    local node_ip="$3"

    log_info "Uploading file to $node_ip: $local_file -> $remote_path"

    local ssh_key_path="${SSH_KEY_PATH:-$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
    local ssh_user="${SSH_USER:-admin}"
    local ssh_opts="${SSH_OPTS:--o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR}"

    # shellcheck disable=SC2086
    if scp $ssh_opts -i "$ssh_key_path" "$local_file" "$ssh_user@$node_ip:$remote_path"; then
        log_success "File uploaded successfully"
        return 0
    else
        log_error "File upload failed"
        return 1
    fi
}

# Download file from remote node
download_file_from_node() {
    local remote_path="$1"
    local local_file="$2"
    local node_ip="$3"

    log_info "Downloading file from $node_ip: $remote_path -> $local_file"

    local ssh_key_path="${SSH_KEY_PATH:-$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
    local ssh_user="${SSH_USER:-admin}"
    local ssh_opts="${SSH_OPTS:--o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR}"

    # shellcheck disable=SC2086
    if scp $ssh_opts -i "$ssh_key_path" "$ssh_user@$node_ip:$remote_path" "$local_file"; then
        log_success "File downloaded successfully"
        return 0
    else
        log_error "File download failed"
        return 1
    fi
}

# Wait for node to be accessible via SSH
wait_for_node_ssh() {
    local node_ip="$1"
    local max_wait="${2:-300}"
    local check_interval="${3:-10}"

    log_info "Waiting for SSH access to $node_ip (max ${max_wait}s)"

    local waited=0
    while [[ $waited -lt $max_wait ]]; do
        if exec_on_node "$node_ip" "echo 'SSH test'" 5 1; then
            log_success "SSH access confirmed for $node_ip"
            return 0
        fi

        log_info "SSH not ready, waiting ${check_interval}s... (${waited}/${max_wait}s)"
        sleep "$check_interval"
        waited=$((waited + check_interval))
    done

    log_error "SSH access timeout for $node_ip after ${max_wait}s"
    return 1
}

# Export functions for use by other scripts
export -f init_test_tracking
export -f update_test_results
export -f get_test_summary
export -f run_test
export -f run_test_suite
export -f collect_test_results
export -f generate_test_report
export -f calculate_duration
export -f check_service_running
export -f check_file_exists
export -f check_command_success
export -f check_port_listening
export -f exec_on_node
export -f upload_file_to_node
export -f download_file_from_node
export -f wait_for_node_ssh

# Only log if log_info function is available (from log-utils.sh)
if command -v log_info >/dev/null 2>&1; then
    log_info "Test suite utilities loaded successfully"
fi
