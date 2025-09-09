#!/bin/bash
#
# Test Framework Utilities
# Main integration script that provides a common interface for Task 004-based test framework
# This script orchestrates the complete test workflow using shared utilities
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
    local test_config="$1"
    local test_scripts_dir="$2"
    local target_vm_pattern="${3:-}"
    local master_test_script="${4:-run-all-tests.sh}"

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
    # Extract cluster name from YAML configuration using yq
    if command -v yq >/dev/null 2>&1; then
        cluster_name=""
        yq_output=$(yq '.clusters.hpc.name' "$test_config" 2>&1)
        yq_status=$?
        if [[ $yq_status -ne 0 ]]; then
            log_error "Failed to parse YAML config file '$test_config' with yq: $yq_output"
            return 1
        fi
        cluster_name="$yq_output"
        if [[ -z "$cluster_name" || "$cluster_name" == "null" ]]; then
            log_warning "Could not extract cluster name from config, falling back to filename"
            cluster_name=$(basename "${test_config%.yaml}")
        fi
    else
        log_warning "yq command not found, falling back to filename for cluster name"
        cluster_name=$(basename "${test_config%.yaml}")
    fi

    log "Starting Test Framework"
    log "Configuration: $test_config"
    log "Test Scripts: $test_scripts_dir"
    log "Target VM Pattern: ${target_vm_pattern:-auto-detect}"
    log "Log Directory: $LOG_DIR"
    echo

    # Setup cleanup handler
    trap 'cleanup_test_framework "$test_config"' EXIT INT TERM

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
    local cluster_pattern
    cluster_pattern=$(basename "${cluster_name}" | tr '_' '-')
    if ! wait_for_cluster_vms "$cluster_pattern"; then
        log_error "VMs failed to start properly"
        return 1
    fi

    # Step 5: Get VM IPs
    if ! get_vm_ips_for_cluster "$cluster_pattern" "$target_vm_pattern"; then
        log_error "Failed to get VM IP addresses"
        return 1
    fi

    # Step 6: Test each VM
    local overall_success=true
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
    for cmd in uv virsh ssh scp; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
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
    local exit_code=$?

    log "Cleaning up test framework on exit (code: $exit_code)..."

    if [[ "${CLEANUP_REQUIRED:-false}" == "true" ]]; then
        log "Attempting to tear down test cluster..."
        local cluster_name
        cluster_name=$(basename "${test_config%.yaml}")
        if ! destroy_cluster "$test_config" "$cluster_name" "force"; then
            log_warning "Automated cleanup failed. You may need to manually clean up VMs."
            if [[ "${INTERACTIVE_CLEANUP:-false}" == "true" ]]; then
                ask_manual_cleanup "$test_config"
            fi
        fi
    fi

    # Create comprehensive log summary
    if [[ -n "${LOG_DIR:-}" ]]; then
        create_log_summary
    fi

    exit $exit_code
}

# Configuration parsing utilities
get_cluster_name_from_config() {
    local config_file="$1"

    if [[ -f "$config_file" ]]; then
        # Try to extract cluster name from metadata or use filename
        local name
        name=$(grep -E "^\s*name:" "$config_file" | head -1 | cut -d: -f2 | tr -d ' "' || true)
        if [[ -n "$name" ]]; then
            echo "$name"
        else
            basename "${config_file%.yaml}"
        fi
    else
        basename "${config_file%.yaml}"
    fi
}

get_target_vm_from_config() {
    local config_file="$1"
    local vm_type="${2:-compute}"  # compute, controller, or specific name

    if [[ -f "$config_file" ]]; then
        case "$vm_type" in
            "compute"|"compute_nodes")
                echo "compute"
                ;;
            "controller")
                echo "controller"
                ;;
            *)
                echo "$vm_type"
                ;;
        esac
    else
        echo "$vm_type"
    fi
}

# Utility function for running framework-based tests with common patterns
run_container_runtime_test_framework() {
    local test_config="${1:-suites/container-runtime/test-container-runtime.yaml}"
    local test_suite_dir="${2:-suites/container-runtime}"
    local master_script="${3:-run-container-runtime-tests.sh}"

    # Initialize logging with container runtime specific settings
    local run_timestamp
    run_timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local test_name="container-runtime"
    init_logging "$run_timestamp" "logs" "$test_name"

    log "Container Runtime Test Framework Starting"
    log "Test Configuration: $test_config"
    log "Test Suite Directory: $test_suite_dir"

    # Resolve the test config path (handles both absolute and relative paths)
    local resolved_config
    if ! resolved_config=$(resolve_test_config_path "$test_config"); then
        return 1
    fi

    # Use tests directory as base for test config and scripts
    local full_config_path="$resolved_config"
    local full_scripts_dir="$TESTS_DIR/$test_suite_dir"

    # Run with compute node focus (container runtime typically on compute nodes)
    run_test_framework "$full_config_path" "$full_scripts_dir" "compute" "$master_script"
}

# Export main functions for use in other scripts
export -f run_test_framework check_test_prerequisites cleanup_test_framework
export -f get_cluster_name_from_config get_target_vm_from_config run_container_runtime_test_framework
