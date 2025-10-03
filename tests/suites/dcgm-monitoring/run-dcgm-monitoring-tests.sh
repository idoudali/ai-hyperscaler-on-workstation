#!/bin/bash
# DCGM Monitoring Test Suite Master Runner
# Orchestrates all DCGM monitoring validation tests

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_SUITE_NAME="DCGM GPU Monitoring Test Suite"
LOG_DIR="${LOG_DIR:-${SCRIPT_DIR}/../../logs}"
VERBOSE=${VERBOSE:-false}

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_section() {
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
}

# Test result tracking
declare -A TEST_RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Function to run a test script
run_test() {
    local test_name="$1"
    local test_script="$2"

    ((TOTAL_TESTS++))

    log_section "Running: $test_name"

    if [[ ! -f "$test_script" ]]; then
        log_error "Test script not found: $test_script"
        TEST_RESULTS["$test_name"]="FAILED"
        ((FAILED_TESTS++))
        return 1
    fi

    # Make script executable
    chmod +x "$test_script"

    # Run test with verbose flag if enabled
    local test_cmd="$test_script"
    if [[ "$VERBOSE" == "true" ]]; then
        test_cmd="VERBOSE=true $test_script"
    fi

    # Capture both stdout and stderr
    local test_output
    local test_exit_code

    if test_output=$(bash -c "$test_cmd" 2>&1); then
        test_exit_code=0
    else
        test_exit_code=$?
    fi

    # Always show the test output
    echo "$test_output"

    if [[ $test_exit_code -eq 0 ]]; then
        log_info "✓ $test_name: PASSED"
        TEST_RESULTS["$test_name"]="PASSED"
        ((PASSED_TESTS++))
        return 0
    else
        log_error "✗ $test_name: FAILED (exit code: $test_exit_code)"
        TEST_RESULTS["$test_name"]="FAILED"
        ((FAILED_TESTS++))
        return 1
    fi
}

# Function to display usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Run comprehensive DCGM GPU monitoring validation tests.

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -t, --test TEST_NAME    Run specific test only
    -l, --list              List available tests
    --log-dir DIR           Specify log directory (default: $LOG_DIR)
    --skip-installation     Skip DCGM installation tests
    --skip-exporter         Skip DCGM exporter tests
    --skip-integration      Skip Prometheus integration tests

AVAILABLE TESTS:
    installation    - DCGM installation and configuration
    exporter        - DCGM exporter functionality
    integration     - Prometheus DCGM integration

EXAMPLES:
    # Run all tests
    $0

    # Run with verbose output
    $0 --verbose

    # Run specific test
    $0 --test installation

    # Skip integration tests
    $0 --skip-integration

EOF
    exit 0
}

# Parse command line arguments
SPECIFIC_TEST=""
SKIP_INSTALLATION=false
SKIP_EXPORTER=false
SKIP_INTEGRATION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -t|--test)
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        -l|--list)
            echo "Available tests:"
            echo "  - installation"
            echo "  - exporter"
            echo "  - integration"
            exit 0
            ;;
        --log-dir)
            LOG_DIR="$2"
            shift 2
            ;;
        --skip-installation)
            SKIP_INSTALLATION=true
            shift
            ;;
        --skip-exporter)
            SKIP_EXPORTER=true
            shift
            ;;
        --skip-integration)
            SKIP_INTEGRATION=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Create log directory
mkdir -p "$LOG_DIR"

# Main test execution
main() {
    local start_time
    start_time=$(date +%s)

    log_section "$TEST_SUITE_NAME"
    log_info "Test suite started at $(date)"
    log_info "Verbose mode: $VERBOSE"
    log_info "Log directory: $LOG_DIR"
    echo

    # Run tests based on configuration
    if [[ -z "$SPECIFIC_TEST" ]]; then
        # Run all tests (unless skipped)
        if [[ "$SKIP_INSTALLATION" == "false" ]]; then
            run_test "DCGM Installation" "${SCRIPT_DIR}/check-dcgm-installation.sh" || true
        fi

        if [[ "$SKIP_EXPORTER" == "false" ]]; then
            run_test "DCGM Exporter" "${SCRIPT_DIR}/check-dcgm-exporter.sh" || true
        fi

        if [[ "$SKIP_INTEGRATION" == "false" ]]; then
            run_test "Prometheus Integration" "${SCRIPT_DIR}/check-prometheus-integration.sh" || true
        fi
    else
        # Run specific test
        case "$SPECIFIC_TEST" in
            installation)
                run_test "DCGM Installation" "${SCRIPT_DIR}/check-dcgm-installation.sh"
                ;;
            exporter)
                run_test "DCGM Exporter" "${SCRIPT_DIR}/check-dcgm-exporter.sh"
                ;;
            integration)
                run_test "Prometheus Integration" "${SCRIPT_DIR}/check-prometheus-integration.sh"
                ;;
            *)
                log_error "Unknown test: $SPECIFIC_TEST"
                log_info "Available tests: installation, exporter, integration"
                exit 1
                ;;
        esac
    fi

    # Display test summary
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_section "Test Summary"

    echo "Test Results:"
    for test_name in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[$test_name]}"
        if [[ "$result" == "PASSED" ]]; then
            echo -e "  ${GREEN}✓${NC} $test_name: $result"
        elif [[ "$result" == "FAILED" ]]; then
            echo -e "  ${RED}✗${NC} $test_name: $result"
        else
            echo -e "  ${YELLOW}○${NC} $test_name: $result"
        fi
    done

    echo
    log_info "Total Tests: $TOTAL_TESTS"
    log_info "Passed: ${GREEN}$PASSED_TESTS${NC}"
    log_info "Failed: ${RED}$FAILED_TESTS${NC}"
    log_info "Skipped: ${YELLOW}$SKIPPED_TESTS${NC}"
    log_info "Duration: ${duration}s"
    log_info "Test suite completed at $(date)"

    # Exit with appropriate code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_section "All Tests Passed! ✓"
        return 0
    else
        log_section "Some Tests Failed! ✗"
        return 1
    fi
}

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
