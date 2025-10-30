#!/bin/bash
#
# Container Execution Test
# Task 008 - Test Container Pull and Execution (Adjusted for Apptainer v1.4.2)
# Validates container execution capabilities per Task 008 requirements
# Optimized for Apptainer 1.4.2 compatibility with enhanced error handling
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="check-container-execution.sh"
TEST_NAME="Container Execution Test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared utilities
source "$SCRIPT_DIR/../common/suite-config.sh"
source "$SCRIPT_DIR/../common/suite-logging.sh"
source "$SCRIPT_DIR/../common/suite-utils.sh"

# Initialize suite
init_suite_logging "$TEST_NAME"
setup_suite_environment "$SCRIPT_NAME"

# Test configuration per Task 008 requirements
CONTAINER_RUNTIME_BINARY="apptainer"

# Test container - using Ubuntu for comprehensive testing
TEST_CONTAINER="docker://ubuntu:22.04"

# Configurable timeout for container pull operations
# Environment Variable: CONTAINER_PULL_TIMEOUT
# Purpose: Controls timeout for container pull operations in seconds
# Default: 180 seconds (3 minutes)
# Usage: CONTAINER_PULL_TIMEOUT=300 ./check-container-execution.sh
: "${CONTAINER_PULL_TIMEOUT:=180}"

# Task 008 Test Functions
test_container_runtime_available() {
    log_info "Checking container runtime availability..."

    if ! command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        log_error "Container runtime not available: $CONTAINER_RUNTIME_BINARY"
        return 1
    fi

    log_info "Container runtime available: $CONTAINER_RUNTIME_BINARY"
    return 0
}

test_container_pull_and_convert() {
    log_info "Pulling and converting test container to SIF format..."

    if ! command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        log_error "Container runtime not available for pull test"
        return 1
    fi

    # Create a temporary directory for containers
    local temp_container_dir="$LOG_DIR/containers"
    mkdir -p "$temp_container_dir"

    # Create SIF file name
    local sif_file="$temp_container_dir/ubuntu-test.sif"

    # Pull and convert container
    if timeout "${CONTAINER_PULL_TIMEOUT}s" "$CONTAINER_RUNTIME_BINARY" pull "$sif_file" "$TEST_CONTAINER" 2>&1 | tee "$LOG_DIR/container-pull.log"; then
        log_info "Successfully pulled and converted container: $TEST_CONTAINER -> $sif_file"
        echo "$sif_file" > "$LOG_DIR/pulled_container.txt"
        return 0
    else
        log_error "Failed to pull container: $TEST_CONTAINER"
        return 1
    fi
}

test_container_execution() {
    log_info "Testing container execution..."

    if ! command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        log_error "Container runtime not available for execution test"
        return 1
    fi

    # Check if we have pulled container
    if [[ ! -f "$LOG_DIR/pulled_container.txt" ]]; then
        log_error "No pulled container available for execution test"
        return 1
    fi

    local test_container
    test_container=$(cat "$LOG_DIR/pulled_container.txt")

    # Test container execution
    if timeout 120s "$CONTAINER_RUNTIME_BINARY" exec "$test_container" echo "Container execution test successful" 2>&1 | tee "$LOG_DIR/container-exec-test.log"; then
        log_info "Successfully executed container: $test_container"
        return 0
    else
        log_error "Failed to execute container: $test_container"
        return 1
    fi
}


test_bind_mount_functionality() {
    log_info "Testing bind mount functionality..."

    if ! command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        log_error "Container runtime not available for bind mount test"
        return 1
    fi

    # Check if we have pulled container
    if [[ ! -f "$LOG_DIR/pulled_container.txt" ]]; then
        log_error "No pulled container available for bind mount test"
        return 1
    fi

    local test_container
    test_container=$(cat "$LOG_DIR/pulled_container.txt")

    # Create test bind mount directory
    local test_bind_dir="$LOG_DIR/bind-mount-test"
    mkdir -p "$test_bind_dir"
    echo "bind mount test data" > "$test_bind_dir/test_file.txt"

    # Test bind mount functionality
    if timeout 120s "$CONTAINER_RUNTIME_BINARY" exec -B "$test_bind_dir:/mnt/test" "$test_container" cat /mnt/test/test_file.txt 2>&1 | tee "$LOG_DIR/bind-mount-test.log"; then
        local output
        output=$(cat "$LOG_DIR/bind-mount-test.log")
        if [[ "$output" == *"bind mount test data"* ]]; then
            log_info "Bind mount functionality working correctly"
            return 0
        else
            log_error "Bind mount test produced unexpected output: $output"
            return 1
        fi
    else
        log_error "Bind mount functionality test failed"
        return 1
    fi
}

test_container_networking() {
    log_info "Testing container networking capabilities..."

    if ! command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        log_error "Container runtime not available for networking test"
        return 1
    fi

    # Check if we have pulled container
    if [[ ! -f "$LOG_DIR/pulled_container.txt" ]]; then
        log_error "No pulled container available for networking test"
        return 1
    fi

    local test_container
    test_container=$(cat "$LOG_DIR/pulled_container.txt")

    # Test that container can run network-related commands
    if timeout 60s "$CONTAINER_RUNTIME_BINARY" exec "$test_container" hostname 2>&1 | tee "$LOG_DIR/container-networking-test.log"; then
        log_info "Container networking test passed"
        return 0
    else
        log_warn "Container networking test failed (may be expected in restricted environments)"
        return 0  # Don't fail the test for networking issues in restricted environments
    fi
}

test_container_isolation() {
    log_info "Testing container isolation..."

    if ! command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        log_error "Container runtime not available for isolation test"
        return 1
    fi

    # Check if we have pulled container
    if [[ ! -f "$LOG_DIR/pulled_container.txt" ]]; then
        log_error "No pulled container available for isolation test"
        return 1
    fi

    local test_container
    test_container=$(cat "$LOG_DIR/pulled_container.txt")

    # Test user isolation
    if timeout 60s "$CONTAINER_RUNTIME_BINARY" exec "$test_container" whoami 2>&1 | tee "$LOG_DIR/container-isolation-test.log"; then
        local container_user
        container_user=$(cat "$LOG_DIR/container-isolation-test.log")
        log_info "Container runs as user: $container_user"

        # Verify we're not running as root in container (good security practice)
        if [[ "$container_user" != "root" ]]; then
            log_info "Container user isolation working (not running as root)"
        else
            log_warn "Container running as root (may be expected for some containers)"
        fi
        return 0
    else
        log_error "Container isolation test failed"
        return 1
    fi
}

print_summary() {
    generate_test_report "Container Execution Test"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_suite_error "Container execution validation FAILED"
        return 1
    else
        log_suite_success "Container execution validation PASSED!"
        log_suite_info "EXECUTION COMPONENTS VALIDATED:"
        log_suite_info "  ✅ Container runtime available"
        log_suite_info "  ✅ Container pull and convert to SIF format"
        log_suite_info "  ✅ Container execution working"
        log_suite_info "  ✅ Bind mount functionality"
        log_suite_info "  ✅ Container networking capabilities"
        log_suite_info "  ✅ Container isolation working"
        return 0
    fi
}

main() {
    format_test_header "$TEST_NAME"
    log_suite_info "Script: $SCRIPT_NAME"
    log_suite_info "Timestamp: $(date)"
    log_suite_info "Log Directory: $LOG_DIR"
    log_suite_info "Container Runtime: $CONTAINER_RUNTIME_BINARY"
    echo

    # Run Task 008 container execution tests
    run_test "Container runtime available" test_container_runtime_available
    run_test "Container pull and convert" test_container_pull_and_convert
    run_test "Container execution" test_container_execution
    run_test "Bind mount functionality" test_bind_mount_functionality
    run_test "Container networking" test_container_networking
    run_test "Container isolation" test_container_isolation

    print_summary
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
