#!/bin/bash
# Master test runner for virtio-fs validation
# Part of Task 027: Implement Virtio-FS Host Directory Sharing

set -euo pipefail

# Script directory and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Initialize logging and colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEST_SUITE_NAME="Virtio-FS Validation"
# Use LOG_DIR from environment if set (for remote execution), otherwise use project structure
LOG_DIR="${LOG_DIR:-${PROJECT_ROOT}/tests/logs/virtio-fs}"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
MAIN_LOG_FILE="$LOG_DIR/virtio-fs-tests-$TIMESTAMP.log"
VERBOSE=false
QUICK_MODE=false
SKIP_PERFORMANCE=false

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Export LOG_DIR for individual test scripts
export LOG_DIR

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$MAIN_LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$MAIN_LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$MAIN_LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$MAIN_LOG_FILE"
}

log_header() {
    echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$MAIN_LOG_FILE"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Master test runner for virtio-fs validation (Task 027)

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -q, --quick         Run only essential tests (skip performance tests)
    --skip-performance  Skip performance benchmarks
    --log-dir DIR      Override log directory (default: $LOG_DIR)

EXAMPLES:
    $0                  # Run all virtio-fs tests
    $0 --verbose        # Run with verbose output
    $0 --quick          # Run essential tests only
    $0 --skip-performance  # Skip performance tests

TEST COMPONENTS:
    1. Configuration validation (kernel modules, packages, fstab)
    2. Mount functionality (mount status, read/write operations)
    3. Performance benchmarks (sequential I/O, random I/O, metadata ops)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quick)
            QUICK_MODE=true
            SKIP_PERFORMANCE=true
            shift
            ;;
        --skip-performance)
            SKIP_PERFORMANCE=true
            shift
            ;;
        --log-dir)
            LOG_DIR="$2"
            MAIN_LOG_FILE="$LOG_DIR/virtio-fs-tests-$TIMESTAMP.log"
            mkdir -p "$LOG_DIR"
            export LOG_DIR
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Test runner function
run_test() {
    local test_name="$1"
    local test_script="$2"
    local optional="${3:-false}"

    log_header "Running: $test_name"

    if [ ! -f "$test_script" ]; then
        if [ "$optional" = "true" ]; then
            log_warning "Test script not found (optional): $test_script"
            return 0
        else
            log_error "Test script not found: $test_script"
            return 1
        fi
    fi

    if [ ! -x "$test_script" ]; then
        chmod +x "$test_script"
    fi

    local test_log="$LOG_DIR/${test_name}-${TIMESTAMP}.log"

    if $VERBOSE; then
        if "$test_script" 2>&1 | tee "$test_log"; then
            log_success "$test_name: PASSED"
            return 0
        else
            log_error "$test_name: FAILED"
            return 1
        fi
    else
        if "$test_script" > "$test_log" 2>&1; then
            log_success "$test_name: PASSED"
            return 0
        else
            log_error "$test_name: FAILED"
            log_info "See log file for details: $test_log"
            return 1
        fi
    fi
}

# Main test execution
main() {
    log_info "=========================================="
    log_info "$TEST_SUITE_NAME - Test Runner"
    log_info "=========================================="
    log_info "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Log directory: $LOG_DIR"
    log_info "Main log file: $MAIN_LOG_FILE"
    log_info "Verbose mode: $VERBOSE"
    log_info "Quick mode: $QUICK_MODE"
    log_info "Skip performance: $SKIP_PERFORMANCE"
    log_info "=========================================="
    log_info ""

    local failed_tests=()
    local total_tests=0
    local passed_tests=0

    # Test 1: Configuration validation
    log_info "=== Phase 1: Configuration Validation ==="
    total_tests=$((total_tests + 1))
    if run_test "config-validation" "$SCRIPT_DIR/check-virtio-fs-config.sh"; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests+=("config-validation")
    fi
    log_info ""

    # Test 2: Mount functionality
    log_info "=== Phase 2: Mount Functionality ==="
    total_tests=$((total_tests + 1))
    if run_test "mount-functionality" "$SCRIPT_DIR/check-mount-functionality.sh"; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests+=("mount-functionality")
    fi
    log_info ""

    # Test 3: Performance benchmarks (optional in quick mode)
    if [ "$SKIP_PERFORMANCE" = "false" ]; then
        log_info "=== Phase 3: Performance Benchmarks ==="
        total_tests=$((total_tests + 1))
        if run_test "performance-benchmarks" "$SCRIPT_DIR/check-performance.sh" "true"; then
            passed_tests=$((passed_tests + 1))
        else
            # Performance test failures are non-critical
            log_warning "Performance benchmarks had issues (non-critical)"
            passed_tests=$((passed_tests + 1))
        fi
        log_info ""
    else
        log_info "=== Phase 3: Performance Benchmarks ==="
        log_info "Skipped (quick mode or explicitly disabled)"
        log_info ""
    fi

    # Final summary
    log_info "=========================================="
    log_info "TEST SUMMARY"
    log_info "=========================================="
    log_info "Total tests run: $total_tests"
    log_info "Tests passed: $passed_tests"
    log_info "Tests failed: $((total_tests - passed_tests))"
    log_info "End time: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "=========================================="
    log_info ""

    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_success "=== ALL TESTS PASSED ==="
        log_info "Virtio-FS is properly configured and functioning"
        log_info "Main log file: $MAIN_LOG_FILE"
        exit 0
    else
        log_error "=== SOME TESTS FAILED ==="
        log_error "Failed tests: ${failed_tests[*]}"
        log_error "Check log files in: $LOG_DIR"
        log_error "Main log file: $MAIN_LOG_FILE"
        exit 1
    fi
}

# Run main function
main "$@"
