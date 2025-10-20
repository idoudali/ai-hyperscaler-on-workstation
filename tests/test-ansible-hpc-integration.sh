#!/bin/bash

# HPC Cloud Ansible Integration Test
# ==================================
#
# This script tests the run-ansible-hpc-cloud.sh orchestration script, which automates
# HPC cluster deployment and configuration using Ansible and the ai-how cluster management tool.
#
# OVERVIEW:
# ---------
# Tests the complete HPC cluster lifecycle:
# - Cluster deployment (creating VMs with ai-how)
# - Ansible-based configuration (HPC software stack installation)
# - Cluster verification (status and connectivity checks)
# - Feature flag testing (selective component installation)
# - Cluster destruction (cleanup)
#
# PREREQUISITES:
# --------------
# 1. Complete project setup (see README.md for details):
#    ./scripts/setup-host-dependencies.sh  # Install system dependencies
#    make build-docker                     # Build development container
#    make venv-create                      # Create Python virtual environment
#    make ssh-keys                         # Generate SSH keys
#
# 2. Verify setup:
#    uv run ai-how --version              # Confirm ai-how works
#    virsh list --all                     # Confirm libvirt works
#    jq --version                         # Confirm JSON parsing works
#
# 3. Resources: 8GB+ RAM, 50GB+ disk space, network connectivity
#
# For detailed system setup instructions, see:
# - README.md (main setup guide)
# - tests/README.md (test-specific requirements and architecture)
#
# 4. Cluster Configuration:
#    - Uses test-infra/configs/test-monitoring-stack.yaml by default
#    - This creates a minimal HPC cluster with:
#      * 1 controller node (test-hpc-monitoring-controller)
#      * 1 compute node (test-hpc-monitoring-compute-01)
#      * Basic networking (192.168.200.x subnet)
#
# CLUSTER STATE REQUIREMENTS:
# ---------------------------
# For NON-DRY-RUN operations:
# - No existing VMs with names matching "test-hpc-monitoring*"
# - Clean libvirt environment (check with: virsh list --all)
# - If VMs exist, destroy them first using ai-how Python library:
#   cd /path/to/ai-hyperscaler-on-workskation
#   uv run ai-how hpc destroy tests/test-infra/configs/test-monitoring-stack.yaml --force
#
# For DRY-RUN operations:
# - No cluster needs to be running
# - Script will simulate operations without creating actual resources
#
# AI-HOW CLUSTER MANAGEMENT:
# -------------------------
# The test uses the ai-how Python library for HPC cluster lifecycle management:
#
# 1. Start HPC cluster:
#    uv run ai-how hpc start tests/test-infra/configs/test-monitoring-stack.yaml
#
# 2. Check cluster status:
#    uv run ai-how hpc status tests/test-infra/configs/test-monitoring-stack.yaml
#
# 3. Get cluster plan (JSON format):
#    uv run ai-how plan clusters tests/test-infra/configs/test-monitoring-stack.yaml -f json
#
# 4. Destroy cluster:
#    uv run ai-how hpc destroy tests/test-infra/configs/test-monitoring-stack.yaml --force
#
# SUPPORTED TEST OPERATIONS:
# --------------------------
# 1. deploy      - Create cluster and deploy HPC stack
# 2. configure   - Configure existing cluster with HPC software
# 3. verify      - Verify cluster configuration and connectivity
# 4. destroy     - Destroy cluster and cleanup resources
# 5. full-cycle  - Complete lifecycle test (deploy->configure->verify->destroy)
#
# USAGE EXAMPLES:
# ---------------
# # Quick verification test (dry-run, no actual cluster needed)
# ./test-ansible-hpc-integration.sh verify --dry-run --verbose
#
# # Test full deployment cycle with actual cluster creation
# ./test-ansible-hpc-integration.sh full-cycle --verbose
#
# # Test just the configuration step (requires existing cluster)
# ./test-ansible-hpc-integration.sh configure
#
# # Test with feature flags disabled
# ./test-ansible-hpc-integration.sh configure --no-monitoring --dry-run
#
# MAKEFILE INTEGRATION:
# --------------------
# make test-hpc-ansible-dry     # Full cycle dry-run test
# make test-hpc-ansible         # Full cycle with actual cluster
# make test-hpc-ansible-verify  # Verification test only
#
# TROUBLESHOOTING:
# ---------------
# For system setup issues, see README.md and tests/README.md
#
# Common test-specific issues:
# 1. Prerequisites validation failed → Run setup verification commands above
# 2. Cluster already running → uv run ai-how hpc destroy <config> --force
# 3. SSH connectivity failed → Check: ls -la build/shared/ssh-keys/ && virsh net-list
# 4. Ansible playbook failed → Check logs in logs/ansible-hpc-integration-*/
# 5. AI-How command failed → Verify: docker ps && uv run ai-how --version
#
# LOGGING AND ARTIFACTS:
# ----------------------
# All test runs create comprehensive logs in:
# logs/ansible-hpc-integration-test-run-TIMESTAMP/
# ├── framework.log              # Main test execution log
# ├── ansible-script-*.log       # Command execution details
# ├── cluster-plan-*.json        # Generated cluster specifications
# ├── test-results.log           # Structured test results
# └── summary.txt                # Comprehensive test summary
#
# INTERNAL AI-HOW INTEGRATION:
# ----------------------------
# The test script internally leverages ai-how Python library through the shared utilities:
# - cluster-utils.sh: Uses get_cluster_plan_data() which calls 'uv run ai-how plan clusters'
# - test-framework-utils.sh: Calls start_cluster() and destroy_cluster() functions
# - vm-utils.sh: Uses get_vm_ips_for_cluster() for VM discovery via ai-how API
#
# Key ai-how commands used internally by the test framework:
# 1. Prerequisites validation: uv run ai-how plan clusters <config> -f json
# 2. Cluster operations: uv run ai-how hpc start/destroy/status <config>
# 3. VM discovery: Parse JSON output from cluster plans for IP addresses
# 4. Status checks: Verify cluster state before/after operations
#
# ==================================

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_SCRIPT="$PROJECT_ROOT/ansible/run-ansible-hpc-cloud.sh"
TEST_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/test-monitoring-stack.yaml"

# Source test framework utilities
UTILS_DIR="$PROJECT_ROOT/tests/test-infra/utils"
# shellcheck source=test-infra/utils/log-utils.sh
source "$UTILS_DIR/log-utils.sh"
# shellcheck source=test-infra/utils/cluster-utils.sh
source "$UTILS_DIR/cluster-utils.sh"

# Initialize logging with proper test name and timestamp
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
TEST_NAME="ansible-hpc-integration"
init_logging "$TIMESTAMP" "logs" "$TEST_NAME"

# Test options
OPERATION="${1:-}"
DRY_RUN=false
VERBOSE=false
QUICK_TEST=false

# Set verbose mode for utilities if requested
export VERBOSE_MODE=false

usage() {
    cat << 'EOF'
HPC Cloud Ansible Integration Test

Usage: $0 [OPERATION] [OPTIONS]

OPERATIONS:
    deploy      Test cluster deployment (creates VMs and deploys HPC stack)
    configure   Test cluster configuration (requires existing cluster)
    verify      Test cluster verification (status and connectivity checks)
    destroy     Test cluster destruction (cleanup all resources)
    full-cycle  Test complete lifecycle (deploy->configure->verify->destroy)

OPTIONS:
    --dry-run   Run in dry-run mode (no actual cluster operations)
    --verbose   Enable verbose output and debugging
    --quick     Skip some verification steps for faster testing
    --help      Show this help message

CLUSTER REQUIREMENTS:
    For non-dry-run: Clean environment (no existing "test-hpc-monitoring*" VMs)
    For dry-run: No cluster requirements

SETUP:
    Complete project setup first - see documentation header in this script

EXAMPLES:
    # Quick verification test (recommended first run)
    ./test-ansible-hpc-integration.sh verify --dry-run --verbose

    # Test full deployment cycle with actual cluster
    ./test-ansible-hpc-integration.sh full-cycle --verbose

    # Test configuration only (cluster must exist)
    ./test-ansible-hpc-integration.sh configure

    # Clean up existing cluster
    uv run ai-how hpc destroy tests/test-infra/configs/test-monitoring-stack.yaml --force

    # Manually start cluster (for configure-only tests)
    uv run ai-how hpc start tests/test-infra/configs/test-monitoring-stack.yaml

MAKEFILE SHORTCUTS:
    make test-hpc-ansible-dry     # Safe dry-run test
    make test-hpc-ansible         # Full cycle with real cluster
    make test-hpc-ansible-verify  # Verification test only

LOGS: All test runs create detailed logs in logs/ansible-hpc-integration-test-run-*/
EOF
}

# Parse additional arguments
parse_arguments() {
    # Handle help first
    for arg in "$@"; do
        if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
            usage
            exit 0
        fi
    done

    while [[ $# -gt 1 ]]; do
        case $2 in
            --dry-run) DRY_RUN=true ;;
            --verbose)
                VERBOSE=true
                export VERBOSE_MODE=true
                ;;
            --quick) QUICK_TEST=true ;;
            *) log_warning "Unknown option: $2" ;;
        esac
        shift
    done
}

# Run ansible script with error handling and structured logging
run_ansible_script() {
    local operation="$1"
    local extra_args="${2:-}"

    log_info "Testing ansible script: $operation"
    log_verbose "Extra args: $extra_args"

    local cmd_args=("$operation")

    if [[ "$DRY_RUN" == "true" ]]; then
        cmd_args+=("--dry-run")
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        cmd_args+=("--verbose")
    fi

    # Add cluster config
    cmd_args+=("--cluster-config" "$TEST_CONFIG")

    if [[ -n "$extra_args" ]]; then
        # Split extra_args into array elements
        read -ra extra_args_array <<< "$extra_args"
        cmd_args+=("${extra_args_array[@]}")
    fi

    local test_log="ansible-script-${operation}.log"
    log_verbose "Executing: $ANSIBLE_SCRIPT ${cmd_args[*]}"

    # Use log_command from utilities for structured command logging
    if log_command "$test_log" "$ANSIBLE_SCRIPT" "${cmd_args[@]}"; then
        log_success "Ansible script $operation completed successfully"
        log_test_result "ansible-script-$operation" "PASSED" "Operation $operation executed successfully"
        return 0
    else
        local exit_code=$?
        log_error "Ansible script $operation failed (exit code: $exit_code)"
        log_test_result "ansible-script-$operation" "FAILED" "Operation $operation failed with exit code $exit_code"
        return $exit_code
    fi
}

# Test deployment operation
test_deploy() {
    echo
    log_info "=== Testing HPC Cluster Deployment ==="

    local test_name="hpc-cluster-deployment"
    log_verbose "Starting deployment test"

    if ! run_ansible_script "deploy"; then
        log_error "Deploy test failed"
        log_test_result "$test_name" "FAILED" "HPC cluster deployment test failed"
        return 1
    fi

    log_success "Deploy test completed successfully"
    log_test_result "$test_name" "PASSED" "HPC cluster deployment test completed successfully"
}

# Test configuration operation
test_configure() {
    echo
    log_info "=== Testing HPC Cluster Configuration ==="

    local test_name="hpc-cluster-configuration"
    log_verbose "Starting configuration test"

    if ! run_ansible_script "configure"; then
        log_error "Configure test failed"
        log_test_result "$test_name" "FAILED" "HPC cluster configuration test failed"
        return 1
    fi

    log_success "Configure test completed successfully"
    log_test_result "$test_name" "PASSED" "HPC cluster configuration test completed successfully"
}

# Test verification operation
test_verify() {
    echo
    log_info "=== Testing HPC Cluster Verification ==="

    local test_name="hpc-cluster-verification"
    log_verbose "Starting verification test"

    if ! run_ansible_script "verify"; then
        log_error "Verify test failed"
        log_test_result "$test_name" "FAILED" "HPC cluster verification test failed"
        return 1
    fi

    log_success "Verify test completed successfully"
    log_test_result "$test_name" "PASSED" "HPC cluster verification test completed successfully"
}

# Test destruction operation
test_destroy() {
    echo
    log_info "=== Testing HPC Cluster Destruction ==="

    local test_name="hpc-cluster-destruction"
    log_verbose "Starting destruction test"

    if ! run_ansible_script "destroy" "--force"; then
        log_error "Destroy test failed"
        log_test_result "$test_name" "FAILED" "HPC cluster destruction test failed"
        return 1
    fi

    log_success "Destroy test completed successfully"
    log_test_result "$test_name" "PASSED" "HPC cluster destruction test completed successfully"
}

# Test feature flags
test_feature_flags() {
    echo
    log_info "=== Testing Feature Flag Combinations ==="

    local overall_success=true

    # Test with monitoring disabled
    local test_name="feature-flags-no-monitoring"
    log_info "Testing configuration without monitoring stack..."
    log_verbose "Running configure with --no-monitoring flag"

    if ! run_ansible_script "configure" "--no-monitoring"; then
        log_error "Feature flag test (no-monitoring) failed"
        log_test_result "$test_name" "FAILED" "Configuration without monitoring stack failed"
        overall_success=false
    else
        log_test_result "$test_name" "PASSED" "Configuration without monitoring stack successful"
    fi

    # Test with minimal features (if not quick test)
    if [[ "$QUICK_TEST" != "true" ]]; then
        local test_name_minimal="feature-flags-minimal-config"
        log_info "Testing minimal configuration..."
        log_verbose "Running configure with minimal feature flags"

        if ! run_ansible_script "configure" "--no-monitoring --no-gpu-support --no-database"; then
            log_error "Minimal configuration test failed"
            log_test_result "$test_name_minimal" "FAILED" "Minimal configuration test failed"
            overall_success=false
        else
            log_test_result "$test_name_minimal" "PASSED" "Minimal configuration test successful"
        fi
    else
        log_verbose "Skipping minimal configuration test (quick mode)"
    fi

    if [[ "$overall_success" == "true" ]]; then
        log_success "Feature flag tests completed successfully"
        log_test_result "feature-flags-overall" "PASSED" "All feature flag tests completed successfully"
        return 0
    else
        log_error "Some feature flag tests failed"
        log_test_result "feature-flags-overall" "FAILED" "Some feature flag tests failed"
        return 1
    fi
}

# Test full deployment cycle
test_full_cycle() {
    echo
    log_info "=== Testing Full HPC Deployment Cycle ==="

    local test_name="full-deployment-cycle"
    local failed=false
    local failed_tests=()

    log_verbose "Starting full deployment cycle test"

    # Deploy
    log_verbose "Step 1: Testing deployment"
    if ! test_deploy; then
        failed=true
        failed_tests+=("deployment")
    fi

    # Configure (if deploy succeeded or if we're in dry-run mode)
    if [[ "$failed" != "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        log_verbose "Step 2: Testing configuration"
        if ! test_configure; then
            failed=true
            failed_tests+=("configuration")
        fi
    else
        log_verbose "Skipping configuration due to deployment failure"
    fi

    # Test feature flags (if previous steps succeeded)
    if [[ "$failed" != "true" ]] && [[ "$QUICK_TEST" != "true" ]]; then
        log_verbose "Step 3: Testing feature flags"
        if ! test_feature_flags; then
            failed=true
            failed_tests+=("feature-flags")
        fi
    elif [[ "$QUICK_TEST" == "true" ]]; then
        log_verbose "Skipping feature flags test (quick mode)"
    else
        log_verbose "Skipping feature flags due to previous failures"
    fi

    # Verify
    if [[ "$failed" != "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        log_verbose "Step 4: Testing verification"
        if ! test_verify; then
            failed=true
            failed_tests+=("verification")
        fi
    else
        log_verbose "Skipping verification due to previous failures"
    fi

    # Destroy (always attempt cleanup unless dry-run)
    if [[ "$DRY_RUN" != "true" ]]; then
        log_verbose "Step 5: Testing destruction"
        if ! test_destroy; then
            failed=true
            failed_tests+=("destruction")
        fi
    else
        log_verbose "Skipping destruction (dry-run mode)"
    fi

    if [[ "$failed" == "true" ]]; then
        local failure_details
        failure_details="Failed tests: $(IFS=,; echo "${failed_tests[*]}")"
        log_error "Full cycle test had failures: $failure_details"
        log_test_result "$test_name" "FAILED" "$failure_details"
        return 1
    else
        log_success "Full cycle test completed successfully"
        log_test_result "$test_name" "PASSED" "All deployment cycle tests completed successfully"
        return 0
    fi
}

# Validate prerequisites using shared utilities
validate_prerequisites() {
    log_info "Validating test prerequisites..."

    local test_name="prerequisites-validation"
    log_verbose "Checking required files and commands"

    # Check if ansible script exists
    if [[ ! -f "$ANSIBLE_SCRIPT" ]]; then
        log_error "Ansible script not found: $ANSIBLE_SCRIPT"
        log_test_result "$test_name" "FAILED" "Ansible script not found: $ANSIBLE_SCRIPT"
        return 1
    fi

    # Check if test config exists
    if [[ ! -f "$TEST_CONFIG" ]]; then
        log_error "Test configuration not found: $TEST_CONFIG"
        log_test_result "$test_name" "FAILED" "Test configuration not found: $TEST_CONFIG"
        return 1
    fi

    # Check if script is executable
    if [[ ! -x "$ANSIBLE_SCRIPT" ]]; then
        log_error "Ansible script is not executable: $ANSIBLE_SCRIPT"
        log_test_result "$test_name" "FAILED" "Ansible script is not executable: $ANSIBLE_SCRIPT"
        return 1
    fi

    # Check for required commands using shared utility logic
    local missing_commands=()
    for cmd in uv jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        log_test_result "$test_name" "FAILED" "Missing required commands: ${missing_commands[*]}"
        return 1
    fi

    # Validate cluster configuration using ai-how API
    log_verbose "Validating cluster configuration with ai-how API"
    local cluster_plan_file
    if cluster_plan_file=$(get_cluster_plan_data "$TEST_CONFIG" "$LOG_DIR" "hpc" 2>/dev/null); then
        log_verbose "Cluster configuration validated successfully"

        # Show cluster details for user information
        local cluster_name
        cluster_name=$(jq -r '.clusters.hpc.name // "unknown"' "$cluster_plan_file" 2>/dev/null)
        local vm_count
        vm_count=$(jq -r '.clusters.hpc.vms | length // 0' "$cluster_plan_file" 2>/dev/null)

        log_info "Test Cluster Configuration:"
        log_info "  Name: $cluster_name"
        log_info "  VMs: $vm_count nodes"

        if [[ "$VERBOSE_MODE" == "true" ]]; then
            log_verbose "Expected VM names:"
            jq -r '.clusters.hpc.vms[].name' "$cluster_plan_file" 2>/dev/null | while read -r vm_name; do
                log_verbose "  - $vm_name"
            done
        fi

        # Check if cluster already exists (for non-dry-run operations)
        if [[ "$DRY_RUN" != "true" ]] && [[ -n "$cluster_name" ]] && [[ "$cluster_name" != "unknown" ]]; then
            log_verbose "Checking for existing cluster VMs using ai-how Python library..."
            if virsh list --all 2>/dev/null | grep -q "$cluster_name"; then
                log_warning "Found existing VMs with cluster name pattern '$cluster_name'"
                log_warning "Clean up existing cluster:"
                log_warning "  uv run ai-how hpc destroy $TEST_CONFIG --force"
                log_info "Or use 'deploy --force' to reconfigure existing cluster"
            else
                log_verbose "No existing VMs found - ready for clean deployment"
            fi
        fi
    else
        log_warning "Could not validate cluster configuration with ai-how API (may be OK for dry-run tests)"
        log_test_result "$test_name" "WARNING" "Cluster configuration validation failed (acceptable for dry-run)"
    fi

    log_success "Prerequisites validation passed"
    log_test_result "$test_name" "PASSED" "All prerequisites validation checks passed"
}

# Main execution
main() {
    # Use shared utilities for consistent output formatting
    log_info "================================================"
    log_info "  HPC Cloud Ansible Integration Test"
    log_info "================================================"
    echo

    log_info "Test Operation: $OPERATION"
    log_info "Ansible Script: $ANSIBLE_SCRIPT"
    log_info "Test Config: $TEST_CONFIG"
    log_info "Log Directory: $LOG_DIR"
    log_verbose "Test Name: $TEST_NAME"
    log_verbose "Timestamp: $TIMESTAMP"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Running in DRY-RUN mode"
    fi

    if [[ "$VERBOSE_MODE" == "true" ]]; then
        log_info "Verbose mode enabled"
    fi

    if [[ "$QUICK_TEST" == "true" ]]; then
        log_info "Quick test mode enabled (skipping some tests)"
    fi

    # Show usage if no operation provided
    if [[ -z "$OPERATION" ]]; then
        echo
        log_warning "No test operation specified"
        usage
        create_log_summary
        exit 1
    fi

    # Validate prerequisites using enhanced validation
    log_verbose "Starting prerequisites validation"
    if ! validate_prerequisites; then
        log_error "Prerequisites validation failed"
        create_log_summary
        exit 1
    fi

    # Execute requested test operation with timing
    local start_time
    start_time=$(date +%s)
    log_verbose "Starting test execution at $(date)"

    local test_result=0
    case "$OPERATION" in
        deploy)
            test_deploy
            test_result=$?
            ;;
        configure)
            test_configure
            test_result=$?
            ;;
        verify)
            test_verify
            test_result=$?
            ;;
        destroy)
            test_destroy
            test_result=$?
            ;;
        full-cycle)
            test_full_cycle
            test_result=$?
            ;;
        *)
            log_error "Unknown test operation: $OPERATION"
            log_test_result "main-execution" "FAILED" "Unknown test operation: $OPERATION"
            usage
            create_log_summary
            exit 1
            ;;
    esac

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_verbose "Test execution completed at $(date)"

    # Create comprehensive log summary
    create_log_summary

    echo
    log_info "================================================"
    if [[ $test_result -eq 0 ]]; then
        log_success "HPC Cloud Ansible integration test '$OPERATION' PASSED"
        log_test_result "main-test-$OPERATION" "PASSED" "Integration test '$OPERATION' completed successfully in ${duration}s"
    else
        log_error "HPC Cloud Ansible integration test '$OPERATION' FAILED"
        log_test_result "main-test-$OPERATION" "FAILED" "Integration test '$OPERATION' failed after ${duration}s"
    fi

    log_info "Test Duration: ${duration}s"
    log_info "Logs and summary saved to: $LOG_DIR"
    log_info "================================================"

    exit $test_result
}

# Parse arguments and run main
parse_arguments "$@"
main
