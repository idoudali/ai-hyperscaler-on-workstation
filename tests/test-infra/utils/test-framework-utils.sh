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

    # Setup Ansible command using uv (consistent with ai-how usage)
    # CRITICAL: Must run from PROJECT_ROOT/python/ai_how where pyproject.toml lives
    # IMPORTANT: Use absolute paths for playbooks since ansible_cmd changes directory
    local ansible_cmd
    ansible_cmd="(cd '${PROJECT_ROOT}/python/ai_how' || cd '$(dirname "$0")/../../python/ai_how') && uv run ansible-playbook"
    log "Using Ansible via uv: $ansible_cmd"

    # Run controller playbook (using absolute path to playbook)
    local controller_count
    controller_count=$(grep -c "controller" "$temp_inventory" || echo "0")
    if [[ "$controller_count" -gt 0 ]]; then
        log "Running HPC controller playbook..."
        if ! bash -c "$ansible_cmd -i '$temp_inventory' '${PROJECT_ROOT}/ansible/playbooks/playbook-hpc-controller.yml' --limit hpc_controllers -v"; then
            log_error "Controller playbook failed"
            playbook_result=1
        else
            log_success "Controller playbook completed successfully"
        fi
    fi

    # Run compute playbook (using absolute path to playbook)
    local compute_count
    compute_count=$(grep -c "compute" "$temp_inventory" || echo "0")
    if [[ "$compute_count" -gt 0 ]]; then
        log "Running HPC compute playbook..."
        if ! bash -c "$ansible_cmd -i '$temp_inventory' '${PROJECT_ROOT}/ansible/playbooks/playbook-hpc-compute.yml' --limit hpc_compute_nodes -v"; then
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

# Run Ansible playbooks on cluster (controller and compute nodes)
# This function is called by deploy_ansible_on_cluster in ansible-utils.sh
run_ansible_on_cluster() {
    local config_file="$1"

    [[ -z "$config_file" ]] && {
        log_error "run_ansible_on_cluster: config_file parameter required"
        return 1
    }

    [[ ! -f "$config_file" ]] && {
        log_error "Configuration file not found: $config_file"
        return 1
    }

    log "Running Ansible playbooks on cluster using config: $config_file"

    # Get cluster name from config file
    local cluster_name
    if ! cluster_name=$(parse_cluster_name "$config_file" "${LOG_DIR:-$(pwd)}" "hpc"); then
        log_error "Failed to get cluster name from configuration"
        return 1
    fi

    log "Cluster name: $cluster_name"

    # Get all VMs for the cluster
    local vm_list
    vm_list=$(virsh list --name --state-running | grep "^${cluster_name}" || true)

    if [[ -z "$vm_list" ]]; then
        log_error "No running VMs found for cluster: $cluster_name"
        return 1
    fi

    # Create temporary Ansible inventory file
    local temp_inventory
    temp_inventory=$(mktemp)

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
            controllers+=("${vm_name} ansible_host=${vm_ip} ansible_user=${SSH_USER:-admin}")
        elif [[ "$vm_name" == *"compute"* ]]; then
            compute_nodes+=("${vm_name} ansible_host=${vm_ip} ansible_user=${SSH_USER:-admin}")
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

    # Wait for SSH connectivity on all nodes
    log "Waiting for SSH connectivity on all nodes..."
    for vm_name in $vm_list; do
        local vm_ip
        vm_ip=$(get_vm_ip "$vm_name")
        if ! wait_for_vm_ssh "$vm_ip" "$vm_name"; then
            log_error "SSH connectivity failed for $vm_name"
            rm -f "$temp_inventory"
            return 1
        fi
    done

    # Run Ansible playbooks from ansible directory to use proper ansible.cfg
    local playbook_result=0
    local original_dir
    original_dir=$(pwd)
    local ansible_dir="$PROJECT_ROOT/ansible"
    cd "$ansible_dir" || {
        log_error "Could not change to ansible directory: $ansible_dir"
        rm -f "$temp_inventory"
        return 1
    }

    # Set environment variables for Ansible
    export ANSIBLE_CONFIG="$ansible_dir/ansible.cfg"
    log "Using Ansible config: $ANSIBLE_CONFIG"

    # Setup Ansible command using uv (consistent with ai-how usage)
    local ansible_cmd="uv run ansible-playbook"
    log "Using Ansible via uv: $ansible_cmd"

    # Run controller playbook
    local controller_count
    controller_count=$(grep -c "controller" "$temp_inventory" || echo "0")
    if [[ "$controller_count" -gt 0 ]]; then
        log "Running HPC controller playbook..."
        if ! $ansible_cmd -i "$temp_inventory" \
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
        if ! $ansible_cmd -i "$temp_inventory" \
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
    cd "$original_dir" || true

    # Clean up temp inventory
    rm -f "$temp_inventory"

    if [[ $playbook_result -eq 0 ]]; then
        log_success "Ansible deployment completed successfully"
        return 0
    else
        log_error "Ansible deployment failed"
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

            # Diagnostic: Log test execution details
            log_debug "═══════════════════════════════════════════════════════════"
            log_debug "Test Execution Details for $vm_name"
            log_debug "───────────────────────────────────────────────────────────"
            log_debug "  Host PROJECT_ROOT:      $PROJECT_ROOT"
            log_debug "  Test Scripts Dir:       $test_scripts_dir"
            log_debug "  Master Test Script:     $master_test_script"
            log_debug "  Suite Directory:        $(basename "$test_scripts_dir")"
            log_debug "═══════════════════════════════════════════════════════════"

            # Check if repository is mounted at same path on VM
            if check_repo_mounted "$vm_ip" "$PROJECT_ROOT"; then
                log_success "✓ Repository is mounted on $vm_name at $PROJECT_ROOT"
                log "Using DIRECT EXECUTION from mounted repository (FAST)"

                # Run tests directly from mounted repository (no SCP copying needed)
                local suite_dir
                suite_dir=$(basename "$test_scripts_dir")
                local mounted_script_path="$PROJECT_ROOT/tests/suites/$suite_dir/$master_test_script"

                # Diagnostic: Log exact script path and working directory
                log_debug "Mounted Execution Details:"
                log_debug "  Mounted Script Path:    $mounted_script_path"
                log_debug "  Script Working Dir:     $(dirname "$mounted_script_path")"
                log_debug "  Will execute from:      $(dirname "$mounted_script_path")"
                log_debug "  Execution Method:       Direct (no SCP)"

                if ! execute_script_on_mounted_vm "$vm_ip" "$vm_name" "$mounted_script_path"; then
                    log_error "✗ Tests failed on $vm_name (mounted repo execution)"
                    overall_success=false
                fi
            else
                log_warning "✗ Repository NOT mounted on $vm_name at $PROJECT_ROOT"
                log "Using SCP COPY method (SLOWER - falling back to traditional method)"

                local suite_remote_dir
                # shellcheck disable=SC2088
                suite_remote_dir="~/tests/suites/$(basename "$test_scripts_dir")"

                # Diagnostic: Log SCP execution details
                log_debug "SCP Execution Details:"
                log_debug "  Remote Dir:             $suite_remote_dir"
                log_debug "  Scripts will be copied to VM"
                log_debug "  Execution Method:       SCP Copy + Execute"

                # Upload test scripts (traditional SCP method)
                if ! upload_scripts_to_vm "$vm_ip" "$vm_name" "$test_scripts_dir" "$suite_remote_dir"; then
                    log_error "✗ Failed to upload test scripts to $vm_name"
                    overall_success=false
                    continue
                fi

                # Run tests
                if ! execute_script_on_vm "$vm_ip" "$vm_name" "$master_test_script" "$suite_remote_dir"; then
                    log_error "✗ Tests failed on $vm_name"
                    overall_success=false
                fi
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


# Generate Ansible inventory from cluster state
# Uses utility functions to get VM IPs and state information
generate_ansible_inventory() {
    local inventory_file="$1"
    local cluster_name="$2"

    [[ -z "$inventory_file" ]] && {
        log_error "generate_ansible_inventory: inventory_file parameter required"
        return 1
    }
    [[ -z "$cluster_name" ]] && {
        log_error "generate_ansible_inventory: cluster_name parameter required"
        return 1
    }

    log "Generating Ansible inventory: $inventory_file"

    # Get all running VMs for the cluster using utility function
    local vm_list
    vm_list=$(virsh list --name --state-running | grep "^${cluster_name}-" || true)

    if [[ -z "$vm_list" ]]; then
        log_error "No running VMs found for cluster: $cluster_name"
        return 1
    fi

    # Build inventory with separate arrays for organization
    local controllers=()
    local compute_nodes=()

    while IFS= read -r vm_name; do
        if [[ -z "$vm_name" ]]; then continue; fi

        # Use utility function to get VM IP
        local vm_ip
        if ! vm_ip=$(get_vm_ip "$vm_name"); then
            log_warning "Could not get IP for VM: $vm_name"
            continue
        fi

        log "  Found VM: $vm_name ($vm_ip)"

        # Determine VM role and add to appropriate array
        if [[ "$vm_name" == *"controller"* ]]; then
            controllers+=("${vm_name}:ansible_host=${vm_ip}")
        elif [[ "$vm_name" == *"compute"* ]]; then
            compute_nodes+=("${vm_name}:ansible_host=${vm_ip}")
        fi
    done <<< "$vm_list"

    # Get controller hostname from first controller VM (if exists)
    local controller_hostname="controller"
    if [[ ${#controllers[@]} -gt 0 ]]; then
        local first_controller_ip
        first_controller_ip=$(echo "${controllers[0]}" | cut -d= -f2)

        # Try to get actual hostname from the controller VM
        if controller_hostname=$(timeout 10 ssh "${SSH_OPTS}" -i "${SSH_KEY_PATH}" "${SSH_USER}@${first_controller_ip}" "hostname" 2>/dev/null); then
            log "Detected controller hostname: $controller_hostname"
        else
            # Default to expected hostname from Packer cloud-init
            controller_hostname="hpc-controller"
            log "Using default controller hostname: $controller_hostname"
        fi
    fi

    # Write inventory file in YAML format
    cat > "$inventory_file" << EOF
all:
  children:
    controller:
      hosts:
EOF

    # Add controllers
    for controller in "${controllers[@]}"; do
        local name ip
        name=$(echo "$controller" | cut -d: -f1)
        ip=$(echo "$controller" | cut -d= -f2)
        cat >> "$inventory_file" << EOF
        $name:
          ansible_host: $ip
          ansible_user: ${SSH_USER}
          ansible_ssh_private_key_file: ${SSH_KEY_PATH}
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF
    done

    # Add compute nodes
    cat >> "$inventory_file" << EOF
    compute:
      hosts:
EOF

    for compute in "${compute_nodes[@]}"; do
        local name ip
        name=$(echo "$compute" | cut -d: -f1)
        ip=$(echo "$compute" | cut -d= -f2)
        cat >> "$inventory_file" << EOF
        $name:
          ansible_host: $ip
          ansible_user: ${SSH_USER}
          ansible_ssh_private_key_file: ${SSH_KEY_PATH}
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF
    done

    # Add group variables including controller hostname
    cat >> "$inventory_file" << EOF
  vars:
    slurm_controller_name: "$controller_hostname"
    slurm_cluster_name: "$cluster_name"
    packer_build: false
EOF

    log_success "Ansible inventory generated with ${#controllers[@]} controller(s) and ${#compute_nodes[@]} compute node(s)"
    return 0
}

# Extract IPs from Ansible inventory file for SSH connectivity checks
# Parses YAML inventory to get host IPs
# NOTE: Logging is sent to stderr to avoid polluting stdout data
extract_ips_from_inventory() {
    local inventory_file="$1"
    local group_pattern="${2:-compute}"  # Default to compute group

    [[ -z "$inventory_file" ]] && {
        echo "extract_ips_from_inventory: inventory_file parameter required" >&2
        return 1
    }

    [[ ! -f "$inventory_file" ]] && {
        echo "Inventory file not found: $inventory_file" >&2
        return 1
    }

    # Simple grep/awk parsing for YAML inventory
    # Extract hostname and IP from inventory for specified group
    local in_group=false
    local current_host=""
    declare -A host_ips

    while IFS= read -r line; do
        # Detect when we enter the target group
        if [[ "$line" =~ ^[[:space:]]*${group_pattern}:[[:space:]]*$ ]]; then
            in_group=true
            continue
        fi

        # Detect when we leave the group (another top-level key at same or higher level)
        if [[ "$in_group" == "true" ]] && [[ "$line" =~ ^[[:space:]]*[a-z_]+:[[:space:]]*$ ]] && [[ ! "$line" =~ hosts: ]]; then
            in_group=false
            continue
        fi

        # Extract host names (indented under hosts:)
        if [[ "$in_group" == "true" ]] && [[ "$line" =~ ^[[:space:]]{8,}([a-zA-Z0-9._-]+):[[:space:]]*$ ]]; then
            current_host="${BASH_REMATCH[1]}"
        fi

        # Extract ansible_host IP
        if [[ "$in_group" == "true" ]] && [[ -n "$current_host" ]] && [[ "$line" =~ ansible_host:[[:space:]]*([0-9.]+) ]]; then
            host_ips["$current_host"]="${BASH_REMATCH[1]}"
        fi
    done < "$inventory_file"

    # Output in format: hostname:ip (one per line) to stdout
    for host in "${!host_ips[@]}"; do
        echo "${host}:${host_ips[$host]}"
    done
}

# Wait for SSH connectivity on all nodes from inventory
# Uses the inventory file to determine which nodes to check
wait_for_inventory_nodes_ssh() {
    local inventory_file="$1"
    local group_pattern="${2:-compute}"
    local timeout="${3:-180}"

    [[ -z "$inventory_file" ]] && {
        log_error "wait_for_inventory_nodes_ssh: inventory_file parameter required"
        return 1
    }

    log "Waiting for SSH connectivity on ${group_pattern} nodes from inventory..."

    # Extract host:ip pairs from inventory
    local host_ips
    if ! host_ips=$(extract_ips_from_inventory "$inventory_file" "$group_pattern"); then
        log_error "Failed to extract IPs from inventory"
        return 1
    fi

    if [[ -z "$host_ips" ]]; then
        log_warning "No hosts found in ${group_pattern} group"
        return 0
    fi

    # Check SSH connectivity for each host
    local failed_hosts=()
    while IFS=: read -r hostname ip_address; do
        [[ -z "$hostname" || -z "$ip_address" ]] && continue

        log "Checking SSH connectivity: $hostname ($ip_address)"

        # Use wait_for_vm_ssh utility function
        if ! wait_for_vm_ssh "$ip_address" "$hostname" "$timeout"; then
            log_error "SSH connectivity failed for $hostname ($ip_address)"
            failed_hosts+=("$hostname")
        fi
    done <<< "$host_ips"

    if [[ ${#failed_hosts[@]} -gt 0 ]]; then
        log_error "SSH connectivity failed for ${#failed_hosts[@]} host(s): ${failed_hosts[*]}"
        return 1
    fi

    log_success "SSH connectivity verified for all ${group_pattern} nodes"
    return 0
}

# Deploy Ansible playbook using generated inventory
# Common function for all test frameworks that need to deploy Ansible configuration
deploy_ansible_playbook() {
    local config_file="$1"
    local playbook="$2"
    local target_group="${3:-all}"
    local log_directory="${4:-${LOG_DIR}}"

    [[ -z "$config_file" ]] && {
        log_error "deploy_ansible_playbook: config_file parameter required"
        return 1
    }
    [[ -z "$playbook" ]] && {
        log_error "deploy_ansible_playbook: playbook parameter required"
        return 1
    }

    log "Deploying Ansible playbook: $playbook"
    log "Target group: $target_group"

    # Check if playbook exists
    if [[ ! -f "$playbook" ]]; then
        log_error "Playbook not found: $playbook"
        return 1
    fi

    # Get cluster name from config file using ai-how API
    local cluster_name
    if ! cluster_name=$(parse_cluster_name "$config_file" "$log_directory" "hpc"); then
        log_error "Failed to get cluster name from configuration"
        return 1
    fi

    log "Cluster name (from config): $cluster_name"

    # Generate dynamic inventory in test run folder
    local inventory_file="${log_directory}/ansible-inventory-${cluster_name}.yml"
    log "Inventory will be saved to: $inventory_file"

    # Use utility function to generate inventory
    if ! generate_ansible_inventory "$inventory_file" "$cluster_name"; then
        log_error "Failed to generate Ansible inventory"
        return 1
    fi

    # Display generated inventory for verification
    log "Generated inventory contents:"
    while IFS= read -r line; do
        log "  $line"
    done < "$inventory_file"

    # Wait for SSH connectivity on target nodes using inventory
    if ! wait_for_inventory_nodes_ssh "$inventory_file" "$target_group"; then
        log_error "SSH connectivity check failed for ${target_group} nodes"
        return 1
    fi

    # Run Ansible playbook
    log ""
    log "Running Ansible playbook..."
    log "Playbook: $playbook"
    log "Inventory: $inventory_file"
    log "Target: $target_group"

    # Change to ansible directory to find roles
    local original_dir
    original_dir=$(pwd)
    cd "$PROJECT_ROOT/ansible" || {
        log_error "Failed to change to ansible directory"
        return 1
    }

    local ansible_cmd="uv run ansible-playbook -i $inventory_file"
    [[ "$target_group" != "all" ]] && ansible_cmd+=" -l $target_group"
    ansible_cmd+=" $playbook"

    log "Executing: $ansible_cmd"

    if eval "$ansible_cmd"; then
        log_success "Ansible playbook deployed successfully"
        log "Inventory preserved at: $inventory_file"
        cd "$original_dir" || true
        return 0
    else
        log_error "Failed to deploy Ansible playbook"
        log "Check the Ansible output above for details"
        log "Inventory file preserved for debugging: $inventory_file"
        cd "$original_dir" || true
        return 1
    fi
}

# =============================================================================
# Test Discovery and Execution Functions (Added for refactoring)
# =============================================================================

# List all test scripts in a directory with descriptions
list_tests_in_directory() {
    local test_dir="$1"
    local test_pattern="${2:-*.sh}"

    [[ -z "$test_dir" ]] && {
        log_error "list_tests_in_directory: test_dir parameter required"
        return 1
    }

    if [[ ! -d "$test_dir" ]]; then
        log_error "Test directory not found: $test_dir"
        return 1
    fi

    echo ""
    echo -e "${GREEN}Available Test Scripts:${NC}"
    echo "  Location: $test_dir"
    echo ""

    local tests
    mapfile -t tests < <(find "$test_dir" -name "$test_pattern" -type f 2>/dev/null | sort)

    if [[ ${#tests[@]} -eq 0 ]]; then
        echo "  No test scripts found matching pattern: $test_pattern"
        return 1
    fi

    for test in "${tests[@]}"; do
        local test_name
        test_name=$(basename "$test")

        # Try to extract test description from script comments
        local test_desc
        test_desc=$(grep -m1 "^# Test:" "$test" 2>/dev/null | sed 's/^# Test: //' || \
                   grep -m1 "^#.*Test" "$test" 2>/dev/null | sed 's/^# //' || \
                   grep -m1 "^# Description:" "$test" 2>/dev/null | sed 's/^# Description: //' || \
                   echo "")

        echo "  • $test_name"
        [[ -n "$test_desc" ]] && echo "    $test_desc"
    done
    echo ""

    return 0
}

# Execute a single test script by name
execute_single_test_by_name() {
    local test_dir="$1"
    local test_name="$2"

    [[ -z "$test_dir" ]] && {
        log_error "execute_single_test_by_name: test_dir parameter required"
        return 1
    }

    [[ -z "$test_name" ]] && {
        log_error "execute_single_test_by_name: test_name parameter required"
        log "Use list_tests_in_directory to see available tests"
        return 1
    }

    log "Running individual test: $test_name"

    # Find the test script
    local test_path="$test_dir/$test_name"

    if [[ ! -f "$test_path" ]]; then
        log_error "Test not found: $test_name"
        log "Available tests:"
        list_tests_in_directory "$test_dir"
        return 1
    fi

    # Make executable if not already
    if [[ ! -x "$test_path" ]]; then
        chmod +x "$test_path" || {
            log_error "Failed to make test executable: $test_path"
            return 1
        }
    fi

    log "Found test: $test_path"
    log "Executing test..."
    echo ""

    # Execute the test
    if "$test_path"; then
        echo ""
        log_success "Test passed: $test_name"
        return 0
    else
        echo ""
        log_error "Test failed: $test_name"
        return 1
    fi
}

# Validate test script exists
validate_test_exists() {
    local test_dir="$1"
    local test_name="$2"

    [[ -z "$test_dir" || -z "$test_name" ]] && {
        log_error "validate_test_exists: test_dir and test_name required"
        return 1
    }

    local test_path="$test_dir/$test_name"

    if [[ -f "$test_path" ]]; then
        return 0
    else
        return 1
    fi
}

# Format and display test listing (wrapper for consistent formatting)
format_test_listing() {
    local test_dir="$1"
    local category_name="${2:-Test Scripts}"
    local test_pattern="${3:-*.sh}"

    echo ""
    echo -e "${BLUE}$category_name${NC}"

    list_tests_in_directory "$test_dir" "$test_pattern"
}

# Run master test script wrapper
run_master_tests() {
    local test_dir="$1"
    local master_script="$2"

    [[ -z "$test_dir" ]] && {
        log_error "run_master_tests: test_dir parameter required"
        return 1
    }

    [[ -z "$master_script" ]] && {
        log_error "run_master_tests: master_script parameter required"
        return 1
    }

    local master_path="$test_dir/$master_script"

    if [[ ! -f "$master_path" ]]; then
        log_error "Master test script not found: $master_path"
        return 1
    fi

    if [[ ! -x "$master_path" ]]; then
        chmod +x "$master_path" || {
            log_error "Failed to make master script executable: $master_path"
            return 1
        }
    fi

    log "Executing master test script: $master_script"

    # Execute the master test script
    if "$master_path"; then
        return 0
    else
        return 1
    fi
}

# Test suite execution with error aggregation
run_test_suite() {
    local test_dir="$1"
    local test_pattern="${2:-*.sh}"

    [[ -z "$test_dir" ]] && {
        log_error "run_test_suite: test_dir parameter required"
        return 1
    }

    if [[ ! -d "$test_dir" ]]; then
        log_error "Test directory not found: $test_dir"
        return 1
    fi

    log "Running test suite from: $test_dir"
    log "Test pattern: $test_pattern"

    local tests
    mapfile -t tests < <(find "$test_dir" -name "$test_pattern" -type f 2>/dev/null | sort)

    if [[ ${#tests[@]} -eq 0 ]]; then
        log_warning "No tests found matching pattern: $test_pattern"
        return 0
    fi

    log "Found ${#tests[@]} test(s) to execute"
    echo ""

    local failed_tests=()
    local passed_tests=()

    for test in "${tests[@]}"; do
        local test_name
        test_name=$(basename "$test")

        log "Running test: $test_name"

        if execute_single_test_by_name "$test_dir" "$test_name"; then
            passed_tests+=("$test_name")
        else
            failed_tests+=("$test_name")
        fi
        echo ""
    done

    # Summary
    echo "========================================"
    log "Test Suite Summary:"
    log "  Total: ${#tests[@]}"
    log "  Passed: ${#passed_tests[@]}"
    log "  Failed: ${#failed_tests[@]}"

    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "Failed tests:"
        for failed in "${failed_tests[@]}"; do
            log_error "  - $failed"
        done
        return 1
    fi
}

# Export main functions for use in other scripts
export -f run_test_framework check_test_prerequisites cleanup_test_framework
export -f generate_ansible_inventory extract_ips_from_inventory wait_for_inventory_nodes_ssh deploy_ansible_playbook
export -f list_tests_in_directory execute_single_test_by_name validate_test_exists
export -f format_test_listing run_master_tests run_test_suite
