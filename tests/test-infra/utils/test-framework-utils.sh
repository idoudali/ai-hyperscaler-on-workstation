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

# Provision monitoring stack on deployed VMs using Ansible
provision_monitoring_stack_on_vms() {
    local cluster_pattern="$1"

    [[ -z "$cluster_pattern" ]] && {
        log_error "provision_monitoring_stack_on_vms: cluster_pattern parameter required"
        return 1
    }

    log "Provisioning monitoring stack on VMs..."

    # Get all VMs for the cluster
    local vm_list
    vm_list=$(virsh list --name --state-running | grep "^${cluster_pattern}" || true)

    if [[ -z "$vm_list" ]]; then
        log_error "No running VMs found for cluster: $cluster_pattern"
        return 1
    fi

    # Create temporary Ansible inventory file
    local temp_inventory
    temp_inventory=$(mktemp)
    local temp_inventory_dir
    temp_inventory_dir=$(mktemp -d)

    # Build inventory with separate arrays for organization
    local controllers=()
    local compute_nodes=()

    while IFS= read -r vm_name; do
        if [[ -z "$vm_name" ]]; then continue; fi

        local vm_ip
        vm_ip=$(get_vm_ip "$vm_name")

        if [[ -z "$vm_ip" ]]; then
            log_warning "Could not get IP for VM: $vm_name"
            continue
        fi

        # Determine VM role and add to appropriate array
        if [[ "$vm_name" == *"controller"* ]]; then
            controllers+=("${vm_name} ansible_host=${vm_ip} ansible_user=admin")
        elif [[ "$vm_name" == *"compute"* ]]; then
            compute_nodes+=("${vm_name} ansible_host=${vm_ip} ansible_user=admin")
        fi
    done <<< "$vm_list"

    # Write inventory file
    echo "[hpc_controllers]" > "$temp_inventory"
    for controller in "${controllers[@]}"; do
        echo "$controller" >> "$temp_inventory"
    done

    echo "" >> "$temp_inventory"
    echo "[hpc_compute_nodes]" >> "$temp_inventory"
    for compute in "${compute_nodes[@]}"; do
        echo "$compute" >> "$temp_inventory"
    done

    # Add common variables
    cat >> "$temp_inventory" << EOF

[all:vars]
ansible_ssh_private_key_file=${SSH_KEY_PATH}
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
install_monitoring_stack=true
install_slurm_controller=true
install_slurm_compute=true
install_container_runtime=true
install_gpu_support=true
install_database=true
packer_build=false
EOF

    log "Generated Ansible inventory:"
    while IFS= read -r line; do log "  $line"; done < "$temp_inventory"

    # Run Ansible playbooks from ansible directory to use proper ansible.cfg
    local playbook_result=0
    local original_dir
    original_dir=$(pwd)
    local ansible_dir="$PROJECT_ROOT/ansible"
    cd "$ansible_dir" || {
        log_error "Could not change to ansible directory: $ansible_dir"
        rm -f "$temp_inventory"
        rm -rf "$temp_inventory_dir"
        return 1
    }

    # Set environment variables for Ansible
    export ANSIBLE_CONFIG="$ansible_dir/ansible.cfg"
    log "Using Ansible config: $ANSIBLE_CONFIG"

    # Setup Ansible command with virtual environment if available
    local ansible_cmd="ansible-playbook"
    if [[ -n "${VIRTUAL_ENV_PATH:-}" ]] && [[ -f "$VIRTUAL_ENV_PATH/bin/ansible-playbook" ]]; then
        ansible_cmd="$VIRTUAL_ENV_PATH/bin/ansible-playbook"
        log "Using Ansible from virtual environment: $ansible_cmd"
    fi

    # Run controller playbook
    local controller_count
    controller_count=$(grep -c "controller" "$temp_inventory" || echo "0")
    if [[ "$controller_count" -gt 0 ]]; then
        log "Running HPC controller playbook..."
        if ! "$ansible_cmd" -i "$temp_inventory" \
            playbooks/playbook-hpc-controller.yml \
            --limit hpc_controllers \
            -v; then
            log_error "Controller playbook failed"
            playbook_result=1
        else
            log_success "Controller playbook completed successfully"
        fi
    fi

    # Run compute playbook
    local compute_count
    compute_count=$(grep -c "compute" "$temp_inventory" || echo "0")
    if [[ "$compute_count" -gt 0 ]]; then
        log "Running HPC compute playbook..."
        if ! "$ansible_cmd" -i "$temp_inventory" \
            playbooks/playbook-hpc-compute.yml \
            --limit hpc_compute_nodes \
            -v; then
            log_error "Compute playbook failed"
            playbook_result=1
        else
            log_success "Compute playbook completed successfully"
        fi
    fi

    # Return to original directory
    cd "$original_dir" || log_warning "Could not return to original directory"

    # Cleanup
    rm -f "$temp_inventory"
    rm -rf "$temp_inventory_dir"

    if [[ $playbook_result -eq 0 ]]; then
        log_success "Monitoring stack provisioning completed successfully"
        # Wait a moment for services to stabilize
        log "Waiting for services to stabilize..."
        sleep 15
        return 0
    else
        log_error "Monitoring stack provisioning failed"
        return 1
    fi
}

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
    # Export variables for cleanup handler
    export test_config test_scripts_dir target_vm_pattern master_test_script
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

    # Step 6: Provision VMs with Ansible (if monitoring stack test)
    if [[ "$test_scripts_dir" == *"monitoring-stack"* ]]; then
        if ! provision_monitoring_stack_on_vms "$cluster_name"; then
            log_error "Failed to provision monitoring stack on VMs"
            return 1
        fi
    fi

    # Step 7: Run tests
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
