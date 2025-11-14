#!/bin/bash
# GPU Validation Test Suite Master Script
# Runs all GPU and PCIe passthrough validation tests

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"

TEST_NAME="GPU Validation Test Suite"

# Test configuration
if [ -z "${LOG_DIR:-}" ]; then
    RUN_TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
    LOG_DIR="$HOME/gpu-tests/logs/run-$RUN_TIMESTAMP"
fi
mkdir -p "$LOG_DIR"

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
PARTIAL_TESTS=0

# Function to run a test and track results
run_suite_test() {
    local test_script="$1"
    local test_name="$2"
    local log_file="$LOG_DIR/${test_name//[: ]/-}.log"

    log_info ""
    log_info "=================================================="
    log_info "Running: $test_name"
    log_info "=================================================="

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ ! -f "$SCRIPT_DIR/$test_script" ]; then
        log_error "Test script not found: $SCRIPT_DIR/$test_script"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    # Make script executable
    chmod +x "$SCRIPT_DIR/$test_script"

    # Run the test and capture output
    set +e
    if "$SCRIPT_DIR/$test_script" 2>&1 | tee "$log_file"; then
        exit_code=${PIPESTATUS[0]}
    else
        exit_code=$?
    fi
    set -e

    case $exit_code in
        0)
            log_pass "$test_name: PASSED"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            ;;
        1)
            log_fail "$test_name: FAILED"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            ;;
        *)
            log_warn "$test_name: PARTIAL/UNKNOWN (exit code: $exit_code)"
            PARTIAL_TESTS=$((PARTIAL_TESTS + 1))
            ;;
    esac

    log_info "Log saved to: $log_file"
    return "$exit_code"
}

# System Information Collection
log_system_info() {
    log_info "=== System Information ==="
    log_info "Hostname: $(hostname)"
    log_info "User: $(whoami)"
    log_info "OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 2>/dev/null || echo 'Unknown')"
    log_info "Kernel: $(uname -r)"
    log_info "Architecture: $(uname -m)"

    if command -v free >/dev/null 2>&1; then
        log_info "Memory: $(free -h | grep Mem | awk '{print $2}')"
    fi

    if command -v nproc >/dev/null 2>&1; then
        log_info "CPU cores: $(nproc)"
    fi
}

main() {
    init_suite_logging "$TEST_NAME"

    log_info "Log Directory: $LOG_DIR"
    log_system_info

    log_info ""
    log_info "=== Running GPU Validation Tests ==="

    # Run all tests in order
    run_suite_test "check-pcie-devices.sh" "PCIe Device Detection"
    run_suite_test "check-gpu-drivers.sh" "GPU Driver Test"

    # Summary Report
    log_info ""
    log_info "=================================================="
    log_info "GPU Validation Test Suite - FINAL RESULTS"
    log_info "=================================================="
    log_info "Total tests run: $TOTAL_TESTS"
    log_info "Passed: $PASSED_TESTS"
    log_info "Failed: $FAILED_TESTS"
    log_info "Partial/Warning: $PARTIAL_TESTS"
    log_info ""
    log_info "Test logs saved to: $LOG_DIR"

    local found_logs
    found_logs=$(find "$LOG_DIR" -maxdepth 1 -type f -name '*.log' 2>/dev/null || true)
    if [ -n "$found_logs" ]; then
        log_info "Available log files:"
        ls -la "$found_logs"
    fi

    # Generate summary status
    if [ $FAILED_TESTS -eq 0 ] && [ $PASSED_TESTS -gt 0 ]; then
        if [ $PARTIAL_TESTS -eq 0 ]; then
            log_pass "🎉 OVERALL STATUS: ALL TESTS PASSED"
            log_pass "GPU passthrough is working correctly"
            exit_status=0
        else
            log_warn "⚠  OVERALL STATUS: MOSTLY WORKING"
            log_warn "GPU passthrough is functional with some warnings"
            exit_status=0
        fi
    elif [ $PASSED_TESTS -gt 0 ] || [ $PARTIAL_TESTS -gt 0 ]; then
        log_warn "⚠  OVERALL STATUS: PARTIAL FUNCTIONALITY"
        log_warn "Some components working, others may need configuration"
        exit_status=1
    else
        log_fail "❌ OVERALL STATUS: TESTS FAILED"
        log_fail "GPU passthrough is not working correctly"
        exit_status=1
    fi

    log_info "=================================================="
    log_info "Test completed at: $(date)"
    log_info "=================================================="

    exit $exit_status
}

main "$@"
