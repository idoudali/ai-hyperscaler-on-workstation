#!/bin/bash
#
# GPU GRES Test Framework
# Task 023 - GPU Resources (GRES) Configuration Validation
# Test framework for validating GPU GRES configuration in HPC compute images
#
# This script uses shared utilities from test-infra/utils/:
#   - cluster-utils.sh: start_cluster, destroy_cluster, resolve_test_config_path
#   - vm-utils.sh: wait_for_vm_ssh, get_vm_ip, get_vm_ips_for_cluster
#   - log-utils.sh: log, log_success, log_error, log_warning, init_logging
#   - test-framework-utils.sh: Orchestration functions (if using run_test_framework)
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Framework configuration
FRAMEWORK_NAME="GPU GRES Test Framework"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Validate PROJECT_ROOT before setting up environment variables
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "Error: Invalid PROJECT_ROOT directory: $PROJECT_ROOT"
    exit 1
fi

# Source shared utilities
UTILS_DIR="$PROJECT_ROOT/tests/test-infra/utils"
if [[ ! -f "$UTILS_DIR/test-framework-utils.sh" ]]; then
    echo "Error: Shared utilities not found at $UTILS_DIR/test-framework-utils.sh"
    exit 1
fi

# Default CLI options (can be overridden by command-line arguments)
VERBOSE=${VERBOSE:-false}
NO_CLEANUP=${NO_CLEANUP:-false}
INTERACTIVE=${INTERACTIVE:-false}

# Set up environment variables for shared utilities AFTER validation
export PROJECT_ROOT
export TESTS_DIR="$PROJECT_ROOT/tests"
export SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
export SSH_USER="admin"
export CLEANUP_REQUIRED=false
export INTERACTIVE_CLEANUP=false
export TEST_NAME="gpu-gres"

# shellcheck source=./test-infra/utils/test-framework-utils.sh
source "$UTILS_DIR/test-framework-utils.sh"

# Test configuration
TEST_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/test-gpu-gres.yaml"
TEST_SCRIPTS_DIR="$PROJECT_ROOT/tests/suites/gpu-gres"
TARGET_VM_PATTERN="compute"
MASTER_TEST_SCRIPT="run-gpu-gres-tests.sh"

# Initialize logging
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "gpu-gres"

# Individual command functions
# Note: start_cluster, generate_ansible_inventory, deploy_ansible_playbook are provided by utilities

deploy_ansible() {
    log "Deploying GPU GRES configuration to cluster: $TEST_NAME"

    local playbook="$PROJECT_ROOT/ansible/playbooks/playbook-gres-runtime-config.yml"

    log "Using runtime playbook: $playbook"
    log ""
    log "Runtime Mode Behavior:"
    log "  - packer_build=false (forced)"
    log "  - GRES configuration will be DEPLOYED"
    log "  - GPU detection will be ENABLED"
    log "  - slurmd service will be RESTARTED"
    log ""

    # Use common utility function to deploy Ansible playbook
    # This function:
    # - Gets cluster name from YAML config (not state.json)
    # - Generates inventory using generate_ansible_inventory()
    # - Extracts IPs from inventory (not state.json) for SSH checks
    # - Runs the playbook
    if ! deploy_ansible_playbook "$TEST_CONFIG" "$playbook" "compute" "$LOG_DIR"; then
        log_error "Failed to deploy GPU GRES configuration"
        return 1
    fi

    log_success "GPU GRES configuration deployed successfully"
    return 0
}

run_tests() {
    local test_scripts_dir="$1"
    local target_pattern="$2"
    local master_script="$3"

    log "Running tests from: $test_scripts_dir"
    log "Target pattern: $target_pattern"
    log "Master script: $master_script"

    # Change to test scripts directory
    cd "$test_scripts_dir" || {
        log_error "Failed to change to test scripts directory: $test_scripts_dir"
        return 1
    }

    # Run master test script
    if [[ -f "$master_script" ]]; then
        log "Executing master test script: $master_script"
        if ./"$master_script"; then
            log_success "Tests completed successfully"
            return 0
        else
            log_error "Tests failed"
            return 1
        fi
    else
        log_error "Master test script not found: $master_script"
        return 1
    fi
}

list_tests() {
    log "Available test scripts in $TEST_SCRIPTS_DIR:"
    echo ""

    if [[ ! -d "$TEST_SCRIPTS_DIR" ]]; then
        log_error "Test scripts directory not found: $TEST_SCRIPTS_DIR"
        return 1
    fi

    # List all executable test scripts (excluding the master script)
    local count=0
    while IFS= read -r test_file; do
        local basename_file
        basename_file=$(basename "$test_file")
        if [[ "$basename_file" != "$MASTER_TEST_SCRIPT" ]]; then
            echo "  - $basename_file"
            ((count++))
        fi
    done < <(find "$TEST_SCRIPTS_DIR" -maxdepth 1 -type f -name "*.sh" -executable | sort)

    # Also show the master script
    if [[ -f "$TEST_SCRIPTS_DIR/$MASTER_TEST_SCRIPT" ]]; then
        echo ""
        echo "Master test runner:"
        echo "  - $MASTER_TEST_SCRIPT (runs all tests)"
    fi

    echo ""
    echo "Total individual tests: $count"
    return 0
}

run_single_test() {
    local test_name="$1"
    local test_path="$TEST_SCRIPTS_DIR/$test_name"

    log "Running single test: $test_name"

    if [[ ! -f "$test_path" ]]; then
        log_error "Test script not found: $test_path"
        return 1
    fi

    if [[ ! -x "$test_path" ]]; then
        log "Making test script executable: $test_name"
        chmod +x "$test_path"
    fi

    # Run the test
    cd "$TEST_SCRIPTS_DIR" || return 1
    if LOG_DIR="$LOG_DIR" ./"$test_name"; then
        log_success "Test passed: $test_name"
        return 0
    else
        log_error "Test failed: $test_name"
        return 1
    fi
}

# Note: destroy_cluster is provided by cluster-utils.sh
# We create a wrapper for backward compatibility
stop_cluster() {
    destroy_cluster "$TEST_CONFIG" "$TEST_NAME"
}

status() {
    log "Checking cluster status for: $TEST_NAME"

    if ! command -v ai-how >/dev/null 2>&1; then
        log_error "ai-how command not found"
        return 1
    fi

    # Get cluster name from config
    local cluster_name
    cluster_name=$(get_cluster_name_from_config "$TEST_CONFIG" "hpc")

    if [[ -z "$cluster_name" ]]; then
        log_error "Failed to get cluster name from config"
        return 1
    fi

    log "Cluster name: $cluster_name"

    # Check if cluster exists
    if ai-how cluster status "$cluster_name" 2>/dev/null; then
        log_success "Cluster is running"

        # Show VM IPs
        log ""
        log "VM IP addresses:"
        get_vm_ips_for_cluster "$TEST_CONFIG" "hpc" || true

        return 0
    else
        log_warning "Cluster is not running or not found"
        return 1
    fi
}

# Help function
show_help() {
    cat << EOF
$FRAMEWORK_NAME - Task 023

Usage: $(basename "$0") [COMMAND] [OPTIONS]

COMMANDS:
  e2e, end-to-end       Run complete end-to-end test (default)
                        Creates cluster → deploys Ansible → runs tests → destroys cluster

  start-cluster         Start the test cluster and keep it running
  stop-cluster          Stop and destroy the test cluster
  deploy-ansible        Deploy GPU GRES configuration via Ansible (requires running cluster)
  run-tests             Run test suite on deployed cluster
  list-tests            List all available individual test scripts
  run-test NAME         Run a specific test script by name
  status                Show current cluster status
  help                  Show this help message

OPTIONS:
  -h, --help            Show this help message
  -v, --verbose         Enable verbose output
  --no-cleanup          Skip cleanup after test completion
  --interactive         Enable interactive prompts for cleanup/confirmation

EXAMPLES:
  # Complete end-to-end test with automatic cleanup (recommended for CI/CD)
  $(basename "$0")
  $(basename "$0") e2e

  # Modular workflow for debugging (keeps cluster running between steps):
  $(basename "$0") start-cluster      # Start cluster once
  $(basename "$0") deploy-ansible     # Deploy GRES configuration
  $(basename "$0") run-tests          # Run tests (can repeat)
  $(basename "$0") list-tests         # Show available tests
  $(basename "$0") run-test check-gres-configuration.sh  # Run specific test
  $(basename "$0") status             # Check cluster status
  $(basename "$0") stop-cluster       # Clean up when done

  # Run with verbose output
  $(basename "$0") --verbose e2e

  # Keep cluster running after test failure for debugging
  $(basename "$0") --no-cleanup e2e

DESCRIPTION:
  This framework validates GPU GRES (Generic Resource Scheduling) configuration
  in HPC compute nodes. It tests GRES configuration deployment, GPU detection,
  and GPU scheduling capabilities.

  Test Categories:
  - GRES Configuration: Validates configuration files and deployment
  - GPU Detection: Tests GPU device detection and visibility
  - GPU Scheduling: Validates SLURM GPU resource scheduling

EOF
}

# Command routing
case "${1:-e2e}" in
    e2e|end-to-end)
        shift || true
        # Parse remaining options
        while [[ $# -gt 0 ]]; do
            case $1 in
                -v|--verbose) VERBOSE=true; shift ;;
                --no-cleanup) NO_CLEANUP=true; shift ;;
                --interactive) INTERACTIVE=true; shift ;;
                -h|--help) show_help; exit 0 ;;
                *) log_error "Unknown option: $1"; show_help; exit 1 ;;
            esac
        done

        log "========================================="
        log "  $FRAMEWORK_NAME - End-to-End Test"
        log "========================================="

        # Run complete workflow
        EXIT_CODE=0

        start_cluster "$TEST_CONFIG" "$TEST_NAME" || EXIT_CODE=$?

        if [[ $EXIT_CODE -eq 0 ]]; then
            deploy_ansible || EXIT_CODE=$?
        fi

        if [[ $EXIT_CODE -eq 0 ]]; then
            run_tests "$TEST_SCRIPTS_DIR" "$TARGET_VM_PATTERN" "$MASTER_TEST_SCRIPT" || EXIT_CODE=$?
        fi

        # Cleanup unless --no-cleanup specified
        if [[ "$NO_CLEANUP" != "true" ]]; then
            stop_cluster || true
        else
            log_warning "Skipping cleanup (--no-cleanup specified)"
        fi

        exit $EXIT_CODE
        ;;

    start-cluster)
        start_cluster "$TEST_CONFIG" "$TEST_NAME"
        ;;

    stop-cluster)
        stop_cluster
        ;;

    deploy-ansible)
        deploy_ansible
        ;;

    run-tests)
        run_tests "$TEST_SCRIPTS_DIR" "$TARGET_VM_PATTERN" "$MASTER_TEST_SCRIPT"
        ;;

    list-tests)
        list_tests
        ;;

    run-test)
        if [[ -z "${2:-}" ]]; then
            log_error "Test name required"
            echo "Usage: $(basename "$0") run-test TEST_NAME"
            echo "Run '$(basename "$0") list-tests' to see available tests"
            exit 1
        fi
        run_single_test "$2"
        ;;

    status)
        status
        ;;

    -h|--help|help)
        show_help
        exit 0
        ;;

    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
