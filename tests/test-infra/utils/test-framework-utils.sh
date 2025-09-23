#!/bin/bash
#
# Test Framework Utilities
# Main integration script that provides a common interface for Task 004-based test framework
# This script orchestrates the complete test workflow using shared utilities
#
# Environment Variables:
#   AI_HOW_DESTROY_FORCE: Set to "false" to disable --force flag for interactive destroy operations
#                         Default: "true" (automated testing mode)
#

set -euo pipefail

# Check if required variables are set (this file is sourced by other scripts)
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    echo "Error: SCRIPT_DIR variable not set. This file must be sourced from a script that sets SCRIPT_DIR."
    # shellcheck disable=SC2317
    return 1 2>/dev/null || exit 1
fi

if [[ -z "${PROJECT_ROOT:-}" ]]; then
    echo "Error: PROJECT_ROOT variable not set. This file must be sourced from a script that sets PROJECT_ROOT."
    # shellcheck disable=SC2317
    return 1 2>/dev/null || exit 1
fi

UTILS_DIR="${PROJECT_ROOT}/tests/test-infra/utils"
# Source all utility modules
# shellcheck source=./log-utils.sh
source "$UTILS_DIR/log-utils.sh"
# shellcheck source=./cluster-utils.sh
source "$UTILS_DIR/cluster-utils.sh"
# shellcheck source=./vm-utils.sh
source "$UTILS_DIR/vm-utils.sh"

# Framework configuration
: "${TESTS_DIR:=$PROJECT_ROOT/tests}"
: "${SSH_KEY_PATH:=$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
: "${SSH_USER:=admin}"
: "${CLEANUP_REQUIRED:=false}"
: "${INTERACTIVE_CLEANUP:=false}"

# Test framework main execution function
run_test_framework() {
    test_config="$1"  # Make it global for cleanup trap
    test_scripts_dir="$2"  # Make it global for cleanup trap
    target_vm_pattern="${3:-}"  # Make it global for cleanup trap
    master_test_script="${4:-run-all-tests.sh}"  # Make it global for cleanup trap

    [[ -z "$test_config" ]] && {
        log_error "run_test_framework: test_config parameter required"
        return 1
    }
    [[ -z "$test_scripts_dir" ]] && {
        log_error "run_test_framework: test_scripts_dir parameter required"
        return 1
    }
    [[ ! -d "$test_scripts_dir" ]] && {
        log_error "Test scripts directory not found: $test_scripts_dir"
        return 1
    }

    local cluster_name
    # Extract cluster name using ai-how API
    if ! cluster_name=$(parse_cluster_name "$test_config" "$LOG_DIR" "hpc"); then
        log_warning "Failed to extract cluster name using ai-how API, falling back to filename"
        cluster_name=$(basename "${test_config%.yaml}")
    fi

    log "Starting Test Framework"
    log "Configuration: $test_config"
    log "Test Scripts: $test_scripts_dir"
    log "Target VM Pattern: ${target_vm_pattern:-auto-detect}"
    log "Log Directory: $LOG_DIR"
    echo

    # Setup cleanup handler with structured approach
    # Create a cleanup function that captures the current test_config
    cleanup_handler() {
        # shellcheck disable=SC2317  # This function is called by trap, not directly
        cleanup_test_framework "$test_config" "$test_scripts_dir" "$target_vm_pattern" "$master_test_script"
    }
    trap cleanup_handler EXIT INT TERM

    # Step 1: Prerequisites
    if ! check_test_prerequisites "$test_config" "$test_scripts_dir"; then
        log_error "Prerequisites check failed"
        return 1
    fi

    # Step 2: Check cluster not running
    if [[ -n "$target_vm_pattern" ]]; then
        if ! check_cluster_not_running "$target_vm_pattern"; then
            log_error "Environment check failed - VMs already exist"
            return 1
        fi
    fi

    # Step 3: Start cluster
    if ! start_cluster "$test_config" "$cluster_name"; then
        log_error "Failed to start cluster"
        return 1
    fi

    CLEANUP_REQUIRED=true
    export CLEANUP_REQUIRED

    # Step 4: Wait for VMs
    if ! wait_for_cluster_vms "$test_config" "hpc" "300"; then
        log_error "VMs failed to start properly"
        return 1
    fi

    # Step 5: Get VM IPs using ai-how API
    if ! get_vm_ips_for_cluster "$test_config" "hpc" "$target_vm_pattern"; then
        log_error "Failed to get VM IP addresses using ai-how API"
        return 1
    fi

    # Step 6: Run tests
    local overall_success=true

    # Check if this is a basic infrastructure test (run on host)
    if [[ "$test_scripts_dir" == *"basic-infrastructure"* ]]; then
        log "Running basic infrastructure tests on host system..."

        # Run the master test script on the host
        if [[ -f "$test_scripts_dir/$master_test_script" ]]; then
            log "Executing: $test_scripts_dir/$master_test_script"
            if ! bash "$test_scripts_dir/$master_test_script"; then
                log_warning "Basic infrastructure tests failed"
                overall_success=false
            fi
        else
            log_error "Master test script not found: $test_scripts_dir/$master_test_script"
            overall_success=false
        fi
    else
        # For other test types, run on VMs as before
        for i in "${!VM_IPS[@]}"; do
            local vm_ip="${VM_IPS[$i]}"
            local vm_name="${VM_NAMES[$i]}"

            log "Testing VM: $vm_name ($vm_ip)"

            # Wait for SSH
            if ! wait_for_vm_ssh "$vm_ip" "$vm_name"; then
                log_error "SSH connectivity failed for $vm_name"
                overall_success=false
                continue
            fi

            # Upload test scripts
            if ! upload_scripts_to_vm "$vm_ip" "$vm_name" "$test_scripts_dir"; then
                log_error "Failed to upload test scripts to $vm_name"
                overall_success=false
                continue
            fi

            # Run tests
            if ! execute_script_on_vm "$vm_ip" "$vm_name" "$master_test_script"; then
                log_warning "Tests failed on $vm_name"
                overall_success=false
            fi
        done
    fi

    # Step 7: Cleanup
    if ! destroy_cluster "$test_config" "$cluster_name"; then
        log_error "Failed to tear down cluster cleanly"
        INTERACTIVE_CLEANUP=true
        export INTERACTIVE_CLEANUP
        return 1
    fi

    CLEANUP_REQUIRED=false
    export CLEANUP_REQUIRED

    # Final results
    echo
    log "=================================================="
    if [[ "$overall_success" == "true" ]]; then
        log_success "Test Framework: ALL TESTS PASSED"
        log_success "All tests completed successfully across ${#VM_IPS[@]} VM(s)"
        return 0
    else
        log_warning "Test Framework: SOME TESTS FAILED"
        log_warning "Check individual test logs in $LOG_DIR"
        return 1
    fi
}

check_test_prerequisites() {
    local test_config="$1"
    local test_scripts_dir="$2"

    log "Checking test framework prerequisites..."

    # Resolve the test config path (handles both absolute and relative paths)
    local resolved_config
    if ! resolved_config=$(resolve_test_config_path "$test_config"); then
        return 1
    fi

    # Check if we're in the right directory structure
    if [[ ! -f "$resolved_config" ]]; then
        log_error "Test configuration not found: $resolved_config"
        return 1
    fi

    # Check test scripts directory
    if [[ ! -d "$test_scripts_dir" ]]; then
        log_error "Test scripts directory not found: $test_scripts_dir"
        return 1
    fi

    # Check for required commands
    local missing_commands=()
    for cmd in uv virsh ssh scp jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        log_error "Note: jq is required for parsing JSON output from ai-how API"
        return 1
    fi

    # Check SSH key
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        log_warning "SSH key not found at $SSH_KEY_PATH"
        log_warning "You may need to generate an SSH key pair or adjust SSH_KEY_PATH"
    fi

    log_success "Prerequisites check passed"
    return 0
}

cleanup_test_framework() {
    local test_config="$1"
    local test_scripts_dir="$2"
    local target_vm_pattern="$3"
    local master_test_script="$4"
    local exit_code=$?

    log "Cleaning up test framework on exit (code: $exit_code)..."

    # Only attempt cleanup if we have a valid test_config and cleanup is required
    if [[ "${CLEANUP_REQUIRED:-false}" == "true" ]] && [[ -n "${test_config:-}" ]]; then
        log "Attempting to tear down test cluster..."
        local cluster_name
        cluster_name=$(basename "${test_config%.yaml}")
        if ! destroy_cluster "$test_config" "$cluster_name"; then
            log_warning "Automated cleanup failed. You may need to manually clean up VMs."
            if [[ "${INTERACTIVE_CLEANUP:-false}" == "true" ]]; then
                ask_manual_cleanup "$test_config"
            fi
        fi
    elif [[ "${CLEANUP_REQUIRED:-false}" == "true" ]]; then
        log_warning "Cleanup required but no test config available for cleanup"
    fi

    # Create comprehensive log summary
    if [[ -n "${LOG_DIR:-}" ]]; then
        create_log_summary
    fi

    exit $exit_code
}


# Export main functions for use in other scripts
export -f run_test_framework check_test_prerequisites cleanup_test_framework
