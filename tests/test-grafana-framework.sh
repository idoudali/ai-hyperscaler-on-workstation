#!/bin/bash
# Grafana Test Framework Integration
# Integrates Grafana testing with the established test framework from Task 004
# Part of the Task 016 Grafana implementation

set -euo pipefail

# Source the test framework utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-infra/utils/test-framework-utils.sh"

# Script configuration
TEST_CONFIG="${TEST_CONFIG:-tests/test-infra/configs/test-monitoring-stack.yaml}"
export TEST_LOG_PREFIX="grafana-framework"
TEST_SUITE_NAME="Grafana Framework Integration Test"

# Command line options
export VERBOSE=0
HELP=0
CLEANUP=1
CLUSTER_NAME="test-grafana-$(date '+%Y%m%d-%H%M%S')"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            export VERBOSE=1
            shift
            ;;
        -c|--config)
            TEST_CONFIG="$2"
            shift 2
            ;;
        -n|--name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --no-cleanup)
            CLEANUP=0
            shift
            ;;
        -h|--help)
            HELP=1
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Show help if requested
if [[ $HELP -eq 1 ]]; then
    cat << EOF
Grafana Framework Integration Test

Usage: $0 [OPTIONS]

Options:
    -v, --verbose    Enable verbose output
    -c, --config     Specify test configuration file (default: tests/test-infra/configs/test-monitoring-stack.yaml)
    -n, --name       Cluster name for testing (default: auto-generated)
    -h, --help       Show this help message
    --no-cleanup     Don't cleanup cluster after testing

Description:
    Tests Grafana installation and functionality using real ai-how cluster deployment.
    This test creates a temporary cluster, installs monitoring stack with Grafana,
    validates the installation, then cleans up.

Prerequisites:
    - ai-how CLI installed and configured
    - Base images built (hpc-controller with Grafana)
    - Test configuration file available
    - Sufficient resources for cluster deployment

Examples:
    $0                          # Run with default settings
    $0 -v                       # Run with verbose output
    $0 -c custom-config.yaml    # Use custom test configuration
    $0 --no-cleanup             # Keep cluster for debugging

EOF
    exit 0
fi

# Initialize logging
init_logging "$(date '+%Y-%m-%d_%H-%M-%S')" "tests/logs" "grafana-framework"

log_info "=== $TEST_SUITE_NAME ==="
log_info "Test Configuration: $TEST_CONFIG"
log_info "Cluster Name: $CLUSTER_NAME"

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."

    # Check ai-how CLI
    if ! command -v ai-how >/dev/null 2>&1; then
        log_error "ai-how CLI not found. Please install AI-HOW CLI first."
        exit 1
    fi

    # Check test configuration
    if [[ ! -f "$TEST_CONFIG" ]]; then
        log_error "Test configuration not found: $TEST_CONFIG"
        exit 1
    fi

    # Validate configuration
    if ! uv run ai-how validate "$TEST_CONFIG" >/dev/null 2>&1; then
        log_error "Test configuration validation failed"
        exit 1
    fi

    log_success "Prerequisites validation completed"
}

# Deploy test cluster
deploy_test_cluster() {
    log_info "Deploying test cluster: $CLUSTER_NAME"

    # Create cluster with monitoring stack
    if ! uv run ai-how hpc create "$TEST_CONFIG" --name "$CLUSTER_NAME" --monitoring; then
        log_error "Failed to create test cluster"
        return 1
    fi

    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    sleep 30

    # Get VM IPs
    if ! get_cluster_vm_ips "$CLUSTER_NAME"; then
        log_error "Failed to get cluster VM IPs"
        return 1
    fi

    log_success "Test cluster deployed successfully"
}

# Test Grafana installation on controller
test_grafana_on_controller() {
    log_info "Testing Grafana installation on controller node..."

    local controller_ip="${VM_IPS[0]:-}"

    if [[ -z "$controller_ip" ]]; then
        log_error "No controller IP available"
        return 1
    fi

    # Wait for SSH access
    if ! wait_for_ssh "$controller_ip" "grafana-test"; then
        log_error "SSH not available on controller"
        return 1
    fi

    # Copy Grafana test scripts to controller
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$SCRIPT_DIR/suites/monitoring-stack/check-grafana-installation.sh" \
        "$controller_ip:/tmp/" 2>/dev/null

    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$SCRIPT_DIR/suites/monitoring-stack/check-grafana-functionality.sh" \
        "$controller_ip:/tmp/" 2>/dev/null

    # Run installation tests
    log_info "Running Grafana installation tests on controller..."
    if ssh_execute "$controller_ip" "cd /tmp && chmod +x check-grafana-installation.sh && ./check-grafana-installation.sh"; then
        log_success "Grafana installation tests passed"
    else
        log_error "Grafana installation tests failed"
        return 1
    fi

    # Run functionality tests
    log_info "Running Grafana functionality tests on controller..."
    if ssh_execute "$controller_ip" "cd /tmp && chmod +x check-grafana-functionality.sh && ./check-grafana-functionality.sh"; then
        log_success "Grafana functionality tests passed"
    else
        log_error "Grafana functionality tests failed"
        return 1
    fi
}

# Cleanup function
cleanup() {
    if [[ $CLEANUP -eq 1 ]]; then
        log_info "Cleaning up test cluster: $CLUSTER_NAME"

        if uv run ai-how hpc destroy "$CLUSTER_NAME" >/dev/null 2>&1; then
            log_success "Test cluster destroyed successfully"
        else
            log_warning "Failed to destroy test cluster (manual cleanup may be needed)"
        fi
    else
        log_info "Skipping cluster cleanup as requested"
    fi
}

# Main test execution
main() {
    # Set up cleanup trap
    trap cleanup EXIT

    # Run tests
    run_test "Prerequisites Validation" validate_prerequisites
    run_test "Test Cluster Deployment" deploy_test_cluster
    run_test "Grafana Installation Test" test_grafana_on_controller

    print_test_summary

    log_success "Grafana framework integration test completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
