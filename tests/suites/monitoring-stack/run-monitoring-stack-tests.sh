#!/bin/bash
# Master test runner for monitoring stack validation
# Part of Task 015: Install Prometheus Monitoring Stack

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
TEST_SUITE_NAME="Monitoring Stack Validation"
# Use LOG_DIR from environment if set (for remote execution), otherwise use project structure
LOG_DIR="${LOG_DIR:-${PROJECT_ROOT}/tests/logs/monitoring-stack}"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
MAIN_LOG_FILE="$LOG_DIR/monitoring-stack-tests-$TIMESTAMP.log"
VERBOSE=false
QUICK_MODE=false

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

Master test runner for monitoring stack validation (Task 015)

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -q, --quick         Run only essential tests
    --target-vm PATTERN Only test VMs matching pattern (default: all)
    --log-dir DIR      Override log directory (default: $LOG_DIR)
    --no-cleanup       Skip cleanup on test failure (for debugging)

EXAMPLES:
    $0                  # Run all monitoring stack tests
    $0 --verbose        # Run with verbose output
    $0 --quick          # Run essential tests only
    $0 --target-vm controller  # Test only controller node

TEST COMPONENTS:
    1. Components Installation (Prometheus + Node Exporter)
    2. Monitoring Stack Integration Testing

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
            shift
            ;;
        --target-vm)
            export TARGET_VM_PATTERN="$2" # Used for VM filtering
            shift 2
            ;;
        --log-dir)
            LOG_DIR="$2"
            export LOG_DIR
            shift 2
            ;;
        --no-cleanup)
            export NO_CLEANUP=true # Used for debugging
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Test execution functions
run_test_script() {
    local test_name="$1"
    local test_script="$2"
    local test_description="$3"

    log_header "Running $test_name"
    log_info "Description: $test_description"
    log_info "Script: $test_script"

    if [ ! -f "$test_script" ]; then
        log_error "Test script not found: $test_script"
        return 1
    fi

    # Make script executable
    chmod +x "$test_script"

    # Run the test
    local start_time
    start_time=$(date +%s)
    if [ "$VERBOSE" = true ]; then
        log_info "Executing: $test_script"
    fi

    if bash "$test_script"; then
        local end_time
        end_time=$(date +%s)
        local duration
        duration=$((end_time - start_time))
        log_success "$test_name completed successfully (${duration}s)"
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration
        duration=$((end_time - start_time))
        log_error "$test_name failed (${duration}s)"
        return 1
    fi
}

# Pre-test validation
validate_environment() {
    log_info "Validating test environment..."

    # Check if we're in the right directory structure (only when running locally, not on remote VM)
    if [ -z "${SSH_CLIENT:-}" ] && [ -z "${SSH_CONNECTION:-}" ]; then
        # We're running locally, check project structure
        if [ ! -f "$PROJECT_ROOT/ansible/roles/monitoring-stack/tasks/main.yml" ]; then
            log_warning "Not in project root - monitoring-stack role not found locally"
            log_info "This is expected when running on remote VM"
        fi
    else
        log_info "Running on remote VM - skipping local project structure check"
    fi

    # Check required tools
    local required_tools=("curl" "systemctl" "netstat")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_warning "Required tool not found: $tool"
        fi
    done

    log_success "Environment validation completed"
    return 0
}

# Main test execution
main() {
    local start_time
    start_time=$(date +%s)

    log_info "=== $TEST_SUITE_NAME ==="
    log_info "Timestamp: $TIMESTAMP"
    log_info "Log directory: $LOG_DIR"
    log_info "Main log file: $MAIN_LOG_FILE"
    log_info "Verbose mode: $VERBOSE"
    log_info "Quick mode: $QUICK_MODE"

    # Pre-test validation
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi

    local failed_tests=()
    local total_tests=0

    # Test 1: Components Installation (Prometheus + Node Exporter)
    total_tests=$((total_tests + 1))
    if ! run_test_script \
        "Components Installation" \
        "$SCRIPT_DIR/check-components-installation.sh" \
        "Validates Prometheus and Node Exporter installation and configuration"; then
        failed_tests+=("components_installation")
    fi

    # Test 2: Monitoring Integration (skip in quick mode if basic tests failed)
    if [ "$QUICK_MODE" = false ] || [ ${#failed_tests[@]} -eq 0 ]; then
        total_tests=$((total_tests + 1))
        if ! run_test_script \
            "Monitoring Integration" \
            "$SCRIPT_DIR/check-monitoring-integration.sh" \
            "Validates Prometheus and Node Exporter integration and data quality"; then
            failed_tests+=("monitoring_integration")
        fi
    else
        log_info "Skipping integration tests in quick mode due to basic test failures"
    fi

    # Calculate test results
    local passed_tests
    passed_tests=$((total_tests - ${#failed_tests[@]}))
    local end_time
    end_time=$(date +%s)
    local total_duration
    total_duration=$((end_time - start_time))

    # Final summary
    log_info "=== Test Execution Summary ==="
    log_info "Total tests: $total_tests"
    log_info "Passed tests: $passed_tests"
    log_info "Failed tests: ${#failed_tests[@]}"
    log_info "Total duration: ${total_duration}s"

    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_success "All monitoring stack tests passed! 🎉"
        log_info "Monitoring stack is ready for production use"

        # Display monitoring endpoints
        log_info "=== Monitoring Endpoints ==="
        log_info "Prometheus Web UI: http://localhost:9090"
        log_info "Node Exporter Metrics: http://localhost:9100/metrics"
        log_info "Prometheus Metrics API: http://localhost:9090/api/v1/query"

        exit 0
    else
        log_error "Monitoring stack validation failed!"
        log_error "Failed tests: ${failed_tests[*]}"
        log_error "Check individual test logs in: $LOG_DIR"
        log_error "Main log file: $MAIN_LOG_FILE"

        # Display troubleshooting information
        log_info "=== Troubleshooting Information ==="
        log_info "1. Check service status: systemctl status prometheus prometheus-node-exporter"
        log_info "2. Check service logs: journalctl -u prometheus -u prometheus-node-exporter"
        log_info "3. Verify network connectivity: netstat -tuln | grep -E '9090|9100'"
        log_info "4. Check configuration: prometheus --config.file=/etc/prometheus/prometheus.yml --dry-run"

        exit 1
    fi
}

# Cleanup function for signals
cleanup() {
    log_info "Received interrupt signal, cleaning up..."
    # Add any cleanup logic here if needed
    exit 130
}

# Set up signal handling
trap cleanup SIGINT SIGTERM

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
