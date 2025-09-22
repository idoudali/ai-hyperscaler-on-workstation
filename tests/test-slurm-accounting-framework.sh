#!/bin/bash
# SLURM Job Accounting Test Framework
# Task 017: Configure SLURM Job Accounting
# This script provides a comprehensive test framework for SLURM job accounting functionality

set -euo pipefail

# Script configuration
SCRIPT_NAME="test-slurm-accounting-framework.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-${SCRIPT_DIR}/logs}"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

# Default configuration
DEFAULT_CONFIG="tests/test-infra/configs/test-slurm-accounting.yaml"
DEFAULT_CLUSTER_NAME="test-slurm-accounting"
DEFAULT_TIMEOUT=600
DEFAULT_CLEANUP=true

# Test configuration
TEST_CONFIG="${TEST_CONFIG:-$DEFAULT_CONFIG}"
CLUSTER_NAME="${CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}"
TEST_TIMEOUT="${TEST_TIMEOUT:-$DEFAULT_TIMEOUT}"
CLEANUP_ON_EXIT="${CLEANUP_ON_EXIT:-$DEFAULT_CLEANUP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Test result functions
test_passed() {
    ((TESTS_PASSED++))
    log_success "✓ $1"
}

test_failed() {
    ((TESTS_FAILED++))
    log_error "✗ $1"
}

test_skipped() {
    ((TESTS_SKIPPED++))
    log_warning "⚠ $1"
}

# Cleanup function
cleanup() {
    if [[ "$CLEANUP_ON_EXIT" == "true" ]]; then
        log_info "Cleaning up test environment..."

        # Stop cluster if running
        if command -v ai-how >/dev/null 2>&1; then
            if ai-how hpc status "$CLUSTER_NAME" >/dev/null 2>&1; then
                log_info "Stopping test cluster: $CLUSTER_NAME"
                ai-how hpc stop "$CLUSTER_NAME" || true
                ai-how hpc destroy "$CLUSTER_NAME" || true
            fi
        fi

        # Kill any running test jobs
        if command -v squeue >/dev/null 2>&1; then
            squeue -u "$(whoami)" --format="%i" --noheader | xargs -r scancel 2>/dev/null || true
        fi
    fi
}

# Set up logging
setup_logging() {
    mkdir -p "$LOG_DIR"
    LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}_${TIMESTAMP}.log"
    log_info "Starting SLURM Job Accounting test framework"
    log_info "Log file: $LOG_FILE"
    log_info "Test timeout: ${TEST_TIMEOUT}s"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

SLURM Job Accounting Test Framework
Task 017: Configure SLURM Job Accounting

OPTIONS:
    -c, --config FILE        Test configuration file (default: $DEFAULT_CONFIG)
    -n, --cluster-name NAME  Cluster name (default: $DEFAULT_CLUSTER_NAME)
    -t, --timeout SECONDS    Test timeout in seconds (default: $DEFAULT_TIMEOUT)
    --no-cleanup            Don't cleanup cluster after tests
    --quick                 Run quick tests only (reduced timeout)
    --verbose               Enable verbose output
    -h, --help              Show this help message

EXAMPLES:
    $0                                    # Run with default configuration
    $0 --config custom-config.yaml       # Use custom configuration
    $0 --quick --no-cleanup              # Quick test without cleanup
    $0 --timeout 1200 --verbose          # Extended timeout with verbose output

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                TEST_CONFIG="$2"
                shift 2
                ;;
            -n|--cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            -t|--timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            --no-cleanup)
                CLEANUP_ON_EXIT="false"
                shift
                ;;
            --quick)
                TEST_TIMEOUT=300
                shift
                ;;
            --verbose)
                set -x
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
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."

    # Check if ai-how is available
    if ! command -v ai-how >/dev/null 2>&1; then
        test_failed "ai-how command not found. Please install AI-HOW CLI first."
        return 1
    fi
    test_passed "ai-how CLI available"

    # Check if configuration file exists
    if [[ ! -f "$TEST_CONFIG" ]]; then
        test_failed "Test configuration file not found: $TEST_CONFIG"
        return 1
    fi
    test_passed "Test configuration file exists"

    # Validate configuration file
    if ! ai-how validate "$TEST_CONFIG" >/dev/null 2>&1; then
        test_failed "Test configuration file validation failed"
        return 1
    fi
    test_passed "Test configuration file is valid"

    # Check if base images exist
    local hpc_image="build/packer/hpc-controller/hpc-controller/hpc-controller.qcow2"
    local cloud_image="build/packer/cloud-base/cloud-base/cloud-base.qcow2"

    if [[ -f "$hpc_image" ]]; then
        test_passed "HPC controller image exists"
    else
        test_failed "HPC controller image not found: $hpc_image"
        return 1
    fi

    if [[ -f "$cloud_image" ]]; then
        test_passed "Cloud base image exists"
    else
        test_failed "Cloud base image not found: $cloud_image"
        return 1
    fi
}

# Deploy test cluster
deploy_cluster() {
    log_info "Deploying test cluster: $CLUSTER_NAME"

    # Create cluster
    if ai-how hpc create "$CLUSTER_NAME" --config "$TEST_CONFIG" >/dev/null 2>&1; then
        test_passed "Cluster created successfully"
    else
        test_failed "Failed to create cluster"
        return 1
    fi

    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    local wait_time=0
    while [[ $wait_time -lt $TEST_TIMEOUT ]]; do
        if ai-how hpc status "$CLUSTER_NAME" | grep -q "running"; then
            test_passed "Cluster is running"
            break
        fi

        sleep 10
        ((wait_time += 10))

        if [[ $wait_time -ge $TEST_TIMEOUT ]]; then
            test_failed "Cluster failed to start within timeout"
            return 1
        fi
    done

    # Get cluster information
    log_info "Cluster information:"
    ai-how hpc status "$CLUSTER_NAME" | tee -a "$LOG_FILE"
}

# Get cluster VM information
get_cluster_info() {
    log_info "Getting cluster VM information..."

    # Get VM IPs using virsh
    local vms
    vms=$(virsh list --name | grep "$CLUSTER_NAME" || true)

    if [[ -z "$vms" ]]; then
        test_failed "No VMs found for cluster: $CLUSTER_NAME"
        return 1
    fi

    # Get VM IPs
    local vm_ips=()
    while IFS= read -r vm; do
        if [[ -n "$vm" ]]; then
            local vm_ip
            vm_ip=$(virsh domifaddr "$vm" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)
            if [[ -n "$vm_ip" ]]; then
                vm_ips+=("$vm_ip")
                log_info "Found VM: $vm at $vm_ip"
            fi
        fi
    done <<< "$vms"

    if [[ ${#vm_ips[@]} -eq 0 ]]; then
        test_failed "No VM IPs found"
        return 1
    fi

    # Test SSH connectivity
    for vm_ip in "${vm_ips[@]}"; do
        log_info "Testing SSH connectivity to $vm_ip..."
        local ssh_timeout=60
        local ssh_wait=0

        while [[ $ssh_wait -lt $ssh_timeout ]]; do
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$vm_ip" "echo 'SSH working'" >/dev/null 2>&1; then
                test_passed "SSH connectivity to $vm_ip"
                break
            fi

            sleep 5
            ((ssh_wait += 5))

            if [[ $ssh_wait -ge $ssh_timeout ]]; then
                test_failed "SSH connectivity to $vm_ip failed"
            fi
        done
    done
}

# Run job accounting tests
run_accounting_tests() {
    log_info "Running job accounting tests..."

    # Find controller VM
    local controller_ip
    controller_ip=$(virsh list --name | grep "$CLUSTER_NAME" | grep -i controller | head -1 | xargs -I {} virsh domifaddr {} | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)

    if [[ -z "$controller_ip" ]]; then
        test_failed "Controller VM IP not found"
        return 1
    fi

    log_info "Controller IP: $controller_ip"

    # Copy test script to controller
    local test_script="tests/suites/slurm-controller/check-job-accounting.sh"
    if [[ -f "$test_script" ]]; then
        scp -o StrictHostKeyChecking=no "$test_script" "$controller_ip:/tmp/" >/dev/null 2>&1
        test_passed "Test script copied to controller"
    else
        test_failed "Test script not found: $test_script"
        return 1
    fi

    # Run job accounting tests on controller
    log_info "Running job accounting validation tests on controller..."
    if ssh -o StrictHostKeyChecking=no "$controller_ip" "chmod +x /tmp/check-job-accounting.sh && /tmp/check-job-accounting.sh" | tee -a "$LOG_FILE"; then
        test_passed "Job accounting tests completed"
    else
        test_failed "Job accounting tests failed"
        return 1
    fi
}

# Run comprehensive validation
run_comprehensive_validation() {
    log_info "Running comprehensive validation..."

    # Find controller VM
    local controller_ip
    controller_ip=$(virsh list --name | grep "$CLUSTER_NAME" | grep -i controller | head -1 | xargs -I {} virsh domifaddr {} | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)

    if [[ -z "$controller_ip" ]]; then
        test_failed "Controller VM IP not found"
        return 1
    fi

    # Test SLURM services
    log_info "Testing SLURM services..."
    if ssh -o StrictHostKeyChecking=no "$controller_ip" "systemctl is-active slurmctld slurmdbd mariadb" >/dev/null 2>&1; then
        test_passed "All SLURM services are active"
    else
        test_failed "Some SLURM services are not active"
    fi

    # Test database connectivity
    log_info "Testing database connectivity..."
    if ssh -o StrictHostKeyChecking=no "$controller_ip" "mysql -u slurm -pslurm -e 'SELECT 1;' slurm_acct_db" >/dev/null 2>&1; then
        test_passed "Database connectivity working"
    else
        test_failed "Database connectivity failed"
    fi

    # Test accounting commands
    log_info "Testing accounting commands..."
    if ssh -o StrictHostKeyChecking=no "$controller_ip" "sacctmgr show cluster" >/dev/null 2>&1; then
        test_passed "sacctmgr command working"
    else
        test_failed "sacctmgr command failed"
    fi

    if ssh -o StrictHostKeyChecking=no "$controller_ip" "sacct --format=JobID,JobName,State" >/dev/null 2>&1; then
        test_passed "sacct command working"
    else
        test_failed "sacct command failed"
    fi

    # Test job submission and accounting
    log_info "Testing job submission and accounting..."
    local job_id
    job_id=$(ssh -o StrictHostKeyChecking=no "$controller_ip" "srun --job-name=test-accounting --time=1:00 echo 'test job' 2>/dev/null | grep -o '[0-9]\+' | head -1" || true)

    if [[ -n "$job_id" ]]; then
        test_passed "Test job submitted (JobID: $job_id)"

        # Wait for job to complete
        sleep 10

        # Check if job appears in accounting
        if ssh -o StrictHostKeyChecking=no "$controller_ip" "sacct --job=$job_id --format=JobID,JobName,State" >/dev/null 2>&1; then
            test_passed "Job appears in accounting records"
        else
            test_failed "Job not found in accounting records"
        fi
    else
        test_failed "Failed to submit test job"
    fi
}

# Print test summary
print_summary() {
    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

    echo
    log_info "=== Test Summary ==="
    log_info "Total tests: $total_tests"
    log_success "Passed: $TESTS_PASSED"
    log_error "Failed: $TESTS_FAILED"
    log_warning "Skipped: $TESTS_SKIPPED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! SLURM job accounting is working correctly."
        return 0
    else
        log_error "Some tests failed. Please check the configuration and logs."
        return 1
    fi
}

# Main execution
main() {
    # Set up signal handling
    trap cleanup EXIT INT TERM

    # Parse arguments
    parse_arguments "$@"

    # Set up logging
    setup_logging

    # Run tests
    validate_prerequisites
    deploy_cluster
    get_cluster_info
    run_accounting_tests
    run_comprehensive_validation

    # Print summary
    print_summary
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
