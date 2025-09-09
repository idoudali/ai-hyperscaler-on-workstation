#!/bin/bash
#
# VM Management Utilities for Test Framework
# Shared VM operations between test suites
#

# Source logging and cluster utilities if available
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -f "$SCRIPT_DIR/log-utils.sh" ]]; then
    # shellcheck source=./log-utils.sh
    source "$SCRIPT_DIR/log-utils.sh"
else
    # Fallback logging if log-utils not available
    log() { echo "[LOG] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_success() { echo "[SUCCESS] $*"; }
    log_warning() { echo "[WARNING] $*"; }
fi

# Configuration variables (must be set by calling script)
: "${SSH_KEY_PATH:=$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
: "${SSH_USER:=admin}"
: "${SSH_OPTS:=-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR}"

# VM discovery and management
get_vm_ips_for_cluster() {
    local cluster_pattern="$1"
    local target_vm_name="${2:-}"

    [[ -z "$cluster_pattern" ]] && {
        log_error "get_vm_ips_for_cluster: cluster_pattern parameter required"
        return 1
    }

    log "Getting IP addresses for VMs matching pattern: $cluster_pattern"

    # Initialize arrays
    VM_IPS=()
    VM_NAMES=()

    # Get all VM names matching our cluster pattern
    local all_vm_names
    if ! all_vm_names=$(virsh list --name --state-running | grep "$cluster_pattern"); then
        log_error "No running VMs found matching cluster pattern: $cluster_pattern"
        return 1
    fi

    # If target_vm_name is specified, filter to that specific VM
    local target_vms
    if [[ -n "$target_vm_name" ]]; then
        target_vms=$(echo "$all_vm_names" | grep "$target_vm_name" || true)
        if [[ -z "$target_vms" ]]; then
            log_error "Target VM not found: $target_vm_name"
            return 1
        fi
        log "Targeting specific VM: $target_vm_name"
    else
        # Separate controller and compute nodes for prioritization
        local controller_vms compute_vms
        controller_vms=$(echo "$all_vm_names" | grep "controller" || true)
        compute_vms=$(echo "$all_vm_names" | grep -v "controller" || true)

        # Log discovered VMs
        if [[ -n "$controller_vms" ]]; then
            log "Found controller VM(s): $(echo "$controller_vms" | tr '\n' ' ')"
        fi
        if [[ -n "$compute_vms" ]]; then
            log "Found compute node(s): $(echo "$compute_vms" | tr '\n' ' ')"
        fi

        # For testing, prioritize compute nodes as they often have special configurations
        target_vms="$compute_vms"
        if [[ -z "$target_vms" ]]; then
            log_warning "No compute nodes found, falling back to testing all VMs"
            target_vms="$all_vm_names"
        else
            log "Prioritizing compute nodes for testing"
        fi
    fi

    # Get IP addresses for target VMs
    while IFS= read -r vm_name; do
        [[ -z "$vm_name" ]] && continue

        log "Getting IP for VM: $vm_name"

        # Try to get IP using virsh domifaddr
        local vm_ip=""
        local attempts=0
        local max_attempts=10

        while [[ $attempts -lt $max_attempts ]] && [[ -z "$vm_ip" ]]; do
            # Extract IPv4 address from virsh domifaddr output (any valid IPv4, not just 192.168.*)
            local domifaddr_output
            domifaddr_output=$(virsh domifaddr "$vm_name" 2>/dev/null || true)

            if [[ -n "$domifaddr_output" ]]; then
                # Look for IPv4 addresses in the format: 192.168.155.11/24
                # Extract just the IP part (before the /)
                vm_ip=$(echo "$domifaddr_output" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -1)

                if [[ -n "$vm_ip" ]]; then
                    log "Found IP address for $vm_name: $vm_ip"
                    break
                fi
            fi

            attempts=$((attempts + 1))
            log "IP not available yet for $vm_name, attempt $attempts/$max_attempts"
            sleep 5
        done

        if [[ -n "$vm_ip" ]]; then
            log_success "VM $vm_name IP: $vm_ip"
            VM_IPS+=("$vm_ip")
            VM_NAMES+=("$vm_name")
        else
            log_error "Failed to get IP for VM: $vm_name"
            return 1
        fi
    done <<< "$target_vms"

    if [[ ${#VM_IPS[@]} -eq 0 ]]; then
        log_error "No VM IPs obtained"
        return 1
    fi

    log_success "Retrieved ${#VM_IPS[@]} target VM IP address(es) for testing"

    # Save VM connection information for debugging
    save_vm_connection_info "$cluster_pattern"

    return 0
}

wait_for_vm_ssh() {
    local vm_ip="$1"
    local vm_name="$2"
    local timeout="${3:-180}"

    [[ -z "$vm_ip" ]] && {
        log_error "wait_for_vm_ssh: vm_ip parameter required"
        return 1
    }
    [[ -z "$vm_name" ]] && {
        log_error "wait_for_vm_ssh: vm_name parameter required"
        return 1
    }

    log "Waiting for SSH connectivity to $vm_name ($vm_ip)..."

    local elapsed=0
    local check_interval=10

    while [[ $elapsed -lt $timeout ]]; do
        # shellcheck disable=SC2086
        if ssh ${SSH_OPTS} -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "echo 'SSH ready'" >/dev/null 2>&1; then
            log_success "SSH ready for $vm_name ($vm_ip)"
            return 0
        fi

        log "SSH not ready for $vm_name... waiting (${elapsed}s/${timeout}s)"
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    log_error "Timeout waiting for SSH connectivity to $vm_name"
    return 1
}

upload_scripts_to_vm() {
    local vm_ip="$1"
    local vm_name="$2"
    local scripts_dir="$3"
    local remote_dir="${4:-~/test-scripts}"

    [[ -z "$vm_ip" ]] && {
        log_error "upload_scripts_to_vm: vm_ip parameter required"
        return 1
    }
    [[ -z "$vm_name" ]] && {
        log_error "upload_scripts_to_vm: vm_name parameter required"
        return 1
    }
    [[ -z "$scripts_dir" ]] && {
        log_error "upload_scripts_to_vm: scripts_dir parameter required"
        return 1
    }

    log "Uploading test scripts to $vm_name ($vm_ip)..."

    # Create remote test directory using user home directory
    local remote_base_dir="$remote_dir"
    local remote_log_dir
    local test_name="${TEST_NAME:-test}"
    remote_log_dir="$remote_base_dir/logs/${test_name}-run-$(date '+%Y-%m-%d_%H-%M-%S')"
    # shellcheck disable=SC2086
    if ! ssh ${SSH_OPTS} -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "mkdir -p $remote_base_dir $remote_log_dir"; then
        log_error "Failed to create remote test and log directories"
        return 1
    fi

    # Upload all test scripts
    # shellcheck disable=SC2086
    if ! scp ${SSH_OPTS} -i "$SSH_KEY_PATH" "$scripts_dir"/*.sh "$SSH_USER@$vm_ip:$remote_base_dir/"; then
        log_error "Failed to upload test scripts"
        return 1
    fi

    # Make scripts executable
    # shellcheck disable=SC2086
    if ! ssh ${SSH_OPTS} -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "chmod +x $remote_base_dir/*.sh"; then
        log_error "Failed to make test scripts executable"
        return 1
    fi

    log_success "Test scripts uploaded successfully to $remote_base_dir"
    return 0
}

execute_script_on_vm() {
    local vm_ip="$1"
    local vm_name="$2"
    local script_name="$3"
    local remote_dir="${4:-~/test-scripts}"
    local extra_args="${5:-}"

    [[ -z "$vm_ip" ]] && {
        log_error "execute_script_on_vm: vm_ip parameter required"
        return 1
    }
    [[ -z "$vm_name" ]] && {
        log_error "execute_script_on_vm: vm_name parameter required"
        return 1
    }
    [[ -z "$script_name" ]] && {
        log_error "execute_script_on_vm: script_name parameter required"
        return 1
    }

    log "Executing script on $vm_name ($vm_ip): $script_name"

    local test_log="${LOG_DIR:-./logs}/test-results-${vm_name}-${script_name%.sh}.log"
    mkdir -p "$(dirname "$test_log")"

    local remote_script_path="$remote_dir/$script_name"
    local remote_log_dir
    local test_name="${TEST_NAME:-test}"
    remote_log_dir="$remote_dir/logs/${test_name}-run-$(date '+%Y-%m-%d_%H-%M-%S')"

    # Build command with LOG_DIR environment variable
    local cmd="LOG_DIR='$remote_log_dir' $remote_script_path"
    if [[ -n "$extra_args" ]]; then
        cmd+=" $extra_args"
    fi

    # Execute the script on the remote VM
    # shellcheck disable=SC2086
    if ssh ${SSH_OPTS} -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "$cmd" 2>&1 | tee "$test_log"; then
        local test_exit_code=${PIPESTATUS[0]}

        # Copy remote logs back to local system
        log "Copying remote test logs from $vm_name..."
        local local_remote_logs_dir="${LOG_DIR:-./logs}/remote-logs-${vm_name}-${script_name%.sh}/"
        # shellcheck disable=SC2086
        if scp ${SSH_OPTS} -i "$SSH_KEY_PATH" -r "$SSH_USER@$vm_ip:$remote_log_dir/" "$local_remote_logs_dir" 2>/dev/null; then
            log_success "Remote logs copied to $local_remote_logs_dir"
        else
            log_warning "Failed to copy remote logs (script may have failed early)"
        fi

        if [[ "$test_exit_code" -eq 0 ]]; then
            log_success "Script executed successfully on $vm_name: $script_name"
            return 0
        else
            log_warning "Script failed on $vm_name: $script_name (exit code: $test_exit_code)"
            return "$test_exit_code"
        fi
    else
        log_error "Failed to execute script on $vm_name: $script_name"
        return 1
    fi
}

save_vm_connection_info() {
    local cluster_name="${1:-test-cluster}"

    [[ ${#VM_IPS[@]} -eq 0 ]] && {
        log_warning "No VM IPs available to save connection info"
        return 0
    }

    log "Saving VM connection information to LOG_DIR..."

    # Create VM info subdirectory
    local vm_info_dir="${LOG_DIR:-./logs}/vm-connection-info"
    mkdir -p "$vm_info_dir"

    # Save structured VM information (JSON-like format)
    log "Creating VM connection info files..."

    # VM List (human readable)
    {
        echo "# VM Connection Information"
        echo "# Generated at: $(date)"
        echo "# Cluster: $cluster_name"
        echo "# Log Directory: ${LOG_DIR:-./logs}"
        echo ""
        echo "VM Count: ${#VM_IPS[@]}"
        echo ""
        echo "VM Details:"
        for i in "${!VM_IPS[@]}"; do
            echo "  VM $((i+1)):"
            echo "    Name: ${VM_NAMES[$i]}"
            echo "    IP: ${VM_IPS[$i]}"
            echo ""
        done
    } > "$vm_info_dir/vm-list.txt"

    # SSH Connection Commands (ready to use)
    {
        echo "#!/bin/bash"
        echo "# SSH Connection Commands for Test VMs"
        echo "# Generated at: $(date)"
        echo ""
        echo "# SSH Configuration:"
        echo "SSH_KEY_PATH=\"$SSH_KEY_PATH\""
        echo "SSH_USER=\"$SSH_USER\""
        echo "SSH_OPTS=\"$SSH_OPTS\""
        echo ""
        echo "# Individual VM Connection Commands:"
        for i in "${!VM_IPS[@]}"; do
            echo ""
            echo "# Connect to ${VM_NAMES[$i]} (${VM_IPS[$i]})"
            echo "ssh $SSH_OPTS -i \"$SSH_KEY_PATH\" \"$SSH_USER@${VM_IPS[$i]}\""
            echo "# Copy files to ${VM_NAMES[$i]}:"
            echo "# scp $SSH_OPTS -i \"$SSH_KEY_PATH\" <local-file> \"$SSH_USER@${VM_IPS[$i]}:~/\""
            echo "# Copy files from ${VM_NAMES[$i]}:"
            echo "# scp $SSH_OPTS -i \"$SSH_KEY_PATH\" \"$SSH_USER@${VM_IPS[$i]}:~/remote-file\" ."
        done
    } > "$vm_info_dir/ssh-commands.sh"
    chmod +x "$vm_info_dir/ssh-commands.sh"

    # CSV format for easy parsing
    {
        echo "vm_name,vm_ip,ssh_command"
        for i in "${!VM_IPS[@]}"; do
            local vm_name="${VM_NAMES[$i]}"
            local vm_ip="${VM_IPS[$i]}"
            local ssh_cmd="ssh $SSH_OPTS -i \"$SSH_KEY_PATH\" \"$SSH_USER@$vm_ip\""
            echo "$vm_name,$vm_ip,\"$ssh_cmd\""
        done
    } > "$vm_info_dir/vm-info.csv"

    log_success "VM connection info saved to: $vm_info_dir"
    log "  - vm-list.txt: Human-readable VM information"
    log "  - ssh-commands.sh: Ready-to-use SSH commands"
    log "  - vm-info.csv: Machine-readable VM data"
}

# Export functions for use in other scripts
export -f get_vm_ips_for_cluster wait_for_vm_ssh upload_scripts_to_vm
export -f execute_script_on_vm save_vm_connection_info
