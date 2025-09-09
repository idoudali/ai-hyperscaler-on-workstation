#!/bin/bash
#
# GPU Validation Test Suite Master Script
# Runs all GPU and PCIe passthrough validation tests
#

set -euo pipefail

echo "=================================================="
echo "GPU Validation Test Suite"
echo "=================================================="
echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "Uptime: $(uptime)"
echo "=================================================="

# Test configuration
TEST_DIR="$(dirname "$0")"
# Use provided LOG_DIR or create a default one in user home directory
if [ -z "${LOG_DIR:-}" ]; then
    RUN_TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
    LOG_DIR="$HOME/gpu-tests/logs/run-$RUN_TIMESTAMP"
fi
mkdir -p "$LOG_DIR"

echo "Log Directory: $LOG_DIR"
echo "=================================================="

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
PARTIAL_TESTS=0

# Function to run a test and track results
run_test() {
    local test_script="$1"
    local test_name="$2"
    local log_file="$LOG_DIR/${test_name}.log"

    echo
    echo "=================================================="
    echo "Running: $test_name"
    echo "=================================================="

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ ! -f "$TEST_DIR/$test_script" ]; then
        echo "✗ Test script not found: $TEST_DIR/$test_script"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    # Make script executable
    chmod +x "$TEST_DIR/$test_script"

    # Run the test and capture output
    if "$TEST_DIR/$test_script" 2>&1 | tee "$log_file"; then
        exit_code=${PIPESTATUS[0]}
    else
        exit_code=$?
    fi

    case $exit_code in
        0)
            echo "✓ $test_name: PASSED"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            ;;
        1)
            echo "✗ $test_name: FAILED"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            ;;
        *)
            echo "⚠ $test_name: PARTIAL/UNKNOWN (exit code: $exit_code)"
            PARTIAL_TESTS=$((PARTIAL_TESTS + 1))
            ;;
    esac

    echo "Log saved to: $log_file"
    return "$exit_code"
}

# System Information Collection
echo
echo "=== System Information ==="
echo "OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 2>/dev/null || echo 'Unknown')"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"

if command -v free >/dev/null 2>&1; then
    echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
fi

if command -v nproc >/dev/null 2>&1; then
    echo "CPU cores: $(nproc)"
fi

echo
echo "=== Running GPU Validation Tests ==="

# Run all tests in order
run_test "check-pcie-devices.sh" "PCIe Device Detection"
run_test "check-gpu-drivers.sh" "GPU Driver Test"

# Summary Report
echo
echo "=================================================="
echo "GPU Validation Test Suite - FINAL RESULTS"
echo "=================================================="
echo "Total tests run: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"
echo "Partial/Warning: $PARTIAL_TESTS"
echo
echo "Test logs saved to: $LOG_DIR"
echo "Available log files:"
found_logs=$(find "$LOG_DIR" -maxdepth 1 -type f -name '*.log')
if [ -n "$found_logs" ]; then
    ls -la "$found_logs"
else
    echo "  (No log files found)"
fi

# Generate summary status
if [ $FAILED_TESTS -eq 0 ] && [ $PASSED_TESTS -gt 0 ]; then
    if [ $PARTIAL_TESTS -eq 0 ]; then
        echo
        echo "🎉 OVERALL STATUS: ALL TESTS PASSED"
        echo "   GPU passthrough is working correctly"
        exit_status=0
    else
        echo
        echo "⚠  OVERALL STATUS: MOSTLY WORKING"
        echo "   GPU passthrough is functional with some warnings"
        exit_status=0
    fi
elif [ $PASSED_TESTS -gt 0 ] || [ $PARTIAL_TESTS -gt 0 ]; then
    echo
    echo "⚠  OVERALL STATUS: PARTIAL FUNCTIONALITY"
    echo "   Some components working, others may need configuration"
    exit_status=1
else
    echo
    echo "❌ OVERALL STATUS: TESTS FAILED"
    echo "   GPU passthrough is not working correctly"
    exit_status=1
fi

echo "=================================================="
echo "Test completed at: $(date)"
echo "=================================================="

exit $exit_status
