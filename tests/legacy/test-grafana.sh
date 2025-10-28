#!/bin/bash
# Grafana Testing Master Script
# Comprehensive testing for Task 016 Grafana implementation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} $*"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
}

# Show usage
show_usage() {
    cat << EOF
Grafana Testing Master Script

Usage: $0 [TEST_LEVEL] [OPTIONS]

Test Levels:
    static          Run static validation tests (no deployment needed)
    unit            Run unit tests on deployed controller
    integration     Run full integration tests with cluster deployment
    all             Run all test levels (default)

Options:
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message
    --controller-ip IP  Specify controller IP for unit tests
    --no-cleanup        Keep test cluster after integration tests
    --quick             Run only critical tests

Examples:
    $0 static                              # Quick validation without deployment
    $0 unit --controller-ip 192.168.1.100  # Test on existing controller
    $0 integration                         # Full end-to-end test
    $0 all -v                              # Run all tests with verbose output

Description:
    This script provides a unified interface for testing the Grafana implementation
    at different levels. Choose the appropriate test level based on your needs:

    - 'static': Fast checks of file structure and syntax (< 1 minute)
    - 'unit': Tests on a deployed controller node (2-5 minutes)
    - 'integration': Full deployment and testing (10-15 minutes)
    - 'all': Complete test suite at all levels (15-20 minutes)

Prerequisites:
    - For 'static': No special requirements
    - For 'unit': Deployed HPC controller with SSH access
    - For 'integration': ai-how CLI, sufficient resources for cluster

EOF
}

# Test level selection
TEST_LEVEL="${1:-all}"
shift || true

# Parse options
VERBOSE=0
CONTROLLER_IP=""
NO_CLEANUP=""
# QUICK=""  # Not used in current implementation

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        --controller-ip)
            CONTROLLER_IP="$2"
            shift 2
            ;;
        --no-cleanup)
            NO_CLEANUP="--no-cleanup"
            shift
            ;;
        --quick)
            # QUICK="-q"  # Not used in current implementation
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Build verbose flag
VERBOSE_FLAG=""
if [[ $VERBOSE -eq 1 ]]; then
    VERBOSE_FLAG="-v"
fi

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

record_test_result() {
    local test_name="$1"
    local result="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ $result -eq 0 ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ $test_name PASSED"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ $test_name FAILED"
    fi
}

# Static validation tests
run_static_tests() {
    log_header "LEVEL 1: Static Validation Tests"
    log_info "Testing file structure and configuration without deployment"

    # Get script directory for proper path resolution
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ -f "$SCRIPT_DIR/validate-grafana-implementation.sh" ]]; then
        bash "$SCRIPT_DIR/validate-grafana-implementation.sh"
        record_test_result "Static Validation" $?
    else
        log_error "Static validation script not found: $SCRIPT_DIR/validate-grafana-implementation.sh"
        record_test_result "Static Validation" 1
    fi
}

# Unit tests on deployed controller
run_unit_tests() {
    log_header "LEVEL 2: Unit Tests"
    log_info "Testing Grafana components on deployed controller"

    if [[ -z "$CONTROLLER_IP" ]]; then
        log_error "Controller IP not specified. Use --controller-ip <IP>"
        log_info "Example: $0 unit --controller-ip 192.168.1.100"
        record_test_result "Unit Tests" 1
        return 1
    fi

    log_info "Testing controller at: $CONTROLLER_IP"

    # Check SSH connectivity
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes root@"$CONTROLLER_IP" "echo 'SSH OK'" &>/dev/null; then
        log_error "Cannot connect to controller via SSH: $CONTROLLER_IP"
        record_test_result "Unit Tests - SSH Connectivity" 1
        return 1
    fi

    # Copy and run installation tests
    if [[ -f "tests/suites/monitoring-stack/check-grafana-installation.sh" ]]; then
        log_info "Running installation tests..."
        scp -q tests/suites/monitoring-stack/check-grafana-installation.sh root@"$CONTROLLER_IP":/tmp/
        ssh root@"$CONTROLLER_IP" "bash /tmp/check-grafana-installation.sh"
        record_test_result "Installation Tests" $?
    else
        log_warning "Installation test script not found"
    fi

    # Copy and run functionality tests
    if [[ -f "tests/suites/monitoring-stack/check-grafana-functionality.sh" ]]; then
        log_info "Running functionality tests..."
        scp -q tests/suites/monitoring-stack/check-grafana-functionality.sh root@"$CONTROLLER_IP":/tmp/
        ssh root@"$CONTROLLER_IP" "bash /tmp/check-grafana-functionality.sh"
        record_test_result "Functionality Tests" $?
    else
        log_warning "Functionality test script not found"
    fi
}

# Integration tests with cluster deployment
run_integration_tests() {
    log_header "LEVEL 3: Integration Tests"
    log_info "Running full end-to-end tests with cluster deployment"

    if [[ -f "tests/test-grafana-framework.sh" ]]; then
        bash tests/test-grafana-framework.sh $VERBOSE_FLAG $NO_CLEANUP
        record_test_result "Integration Tests" $?
    else
        log_error "Integration test script not found: tests/test-grafana-framework.sh"
        record_test_result "Integration Tests" 1
    fi
}

# Print test summary
print_summary() {
    echo ""
    log_header "Test Summary"
    log_info "Total Tests Run: $TESTS_RUN"
    log_info "Tests Passed: $TESTS_PASSED"
    log_info "Tests Failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo ""
        log_success "═══════════════════════════════════════════════════════"
        log_success "   ALL TESTS PASSED! Grafana implementation is ready   "
        log_success "═══════════════════════════════════════════════════════"
        return 0
    else
        echo ""
        log_error "═══════════════════════════════════════════════════════"
        log_error "   $TESTS_FAILED TEST(S) FAILED - Review output above   "
        log_error "═══════════════════════════════════════════════════════"
        return 1
    fi
}

# Main execution
main() {
    log_header "Grafana Implementation Testing - Task 016"

    case "$TEST_LEVEL" in
        static)
            run_static_tests
            ;;
        unit)
            run_unit_tests
            ;;
        integration)
            run_integration_tests
            ;;
        all)
            run_static_tests
            echo ""
            log_info "Unit tests require --controller-ip, skipping..."
            echo ""
            run_integration_tests
            ;;
        *)
            log_error "Unknown test level: $TEST_LEVEL"
            show_usage
            exit 1
            ;;
    esac

    print_summary
}

# Run main function
main
