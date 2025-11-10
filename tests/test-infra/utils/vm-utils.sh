#!/bin/bash
#
# VM Management Utilities for Test Framework
# Shared VM operations between test suites
#

# Source logging and cluster utilities if available
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Define fallback logging functions first (always available)
log() { echo "[LOG] $*"; }
log_debug() { echo "[DEBUG] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_success() { echo "[SUCCESS] $*"; }
log_warning() { echo "[WARNING] $*"; }

# Try to source enhanced logging if available
if [[ -f "$SCRIPT_DIR/log-utils.sh" ]]; then
    # shellcheck source=./log-utils.sh
    source "$SCRIPT_DIR/log-utils.sh" || true
fi

# Configuration variables (must be set by calling script)
: "${SSH_KEY_PATH:=$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
: "${SSH_USER:=admin}"
# WARNING: The following SSH options disable host key checking and ignore the known hosts file.
# This makes the system vulnerable to man-in-the-middle attacks and should NEVER be used in production.
# These options are acceptable ONLY in isolated test environments for automation convenience.
: "${SSH_OPTS:=-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR}"

_build_ssh_opts() {
    local -n _opts_ref=$1
    _opts_ref=()
    if [ -n "${SSH_OPTS:-}" ]; then
        # shellcheck disable=SC2206
        _opts_ref=($SSH_OPTS)
    fi
}

# VM discovery and management using ai-how API

# Get IP address for a single VM
get_vm_ip() {
    local vm_name="$1"

    [[ -z "$vm_name" ]] && {
        log_error "get_vm_ip: vm_name parameter required"
        return 1
    }

    # Try to get IP using virsh domifaddr
    local vm_ip=""
    local attempts=0
    local max_attempts=10

    while [[ $attempts -lt $max_attempts ]] && [[ -z "$vm_ip" ]]; do
        local domifaddr_output
        domifaddr_output=$(virsh domifaddr "$vm_name" 2>/dev/null || true)

        if [[ -n "$domifaddr_output" ]]; then
            # Extract IPv4 address
            vm_ip=$(echo "$domifaddr_output" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -1)

            if [[ -n "$vm_ip" ]]; then
                echo "$vm_ip"
                return 0
            fi
        fi

        attempts=$((attempts + 1))
        [[ $attempts -lt $max_attempts ]] && sleep 5
    done

    # Return empty if no IP found
    return 1
}
get_vm_ips_for_cluster() {
    local config_file="$1"
    local cluster_type="${2:-hpc}"
    local target_vm_name="${3:-}"

    [[ -z "$config_file" ]] && {
        log_error "get_vm_ips_for_cluster: config_file parameter required"
        return 1
    }

    log "Getting IP addresses for VMs using ai-how API: $config_file"

    # Check if jq is available for JSON parsing
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq command not found. Please install jq to parse JSON output from ai-how API."
        return 1
    fi

    # Get cluster plan data using ai-how API
    local log_directory="${LOG_DIR:-./logs}"
    local plan_file
    if ! plan_file=$(get_cluster_plan_data "$config_file" "$log_directory" "$cluster_type"); then
        log_error "Failed to get cluster plan data using ai-how API"
        return 1
    fi

    # Extract cluster name and expected VMs
    local cluster_name
    cluster_name=$(jq -r ".clusters.${cluster_type}.name" "$plan_file" 2>/dev/null)

    # Get VM count to validate we have VMs
    local vm_count
    vm_count=$(jq -r ".clusters.${cluster_type}.vms | length" "$plan_file" 2>/dev/null)

    if [[ "$vm_count" -eq 0 ]]; then
        log_error "No VMs found in cluster plan data"
        return 1
    fi

    log "Cluster: $cluster_name"
    log "Expected VMs from API: $(jq -r ".clusters.${cluster_type}.vms[].name" "$plan_file" | tr '\n' ' ')"

    # Initialize arrays
    VM_IPS=()
    VM_NAMES=()

    # Extract IPs using ai-how API
    # Primary: Extract from cluster plan
    log "Extracting VM IPs from cluster plan..."

    # Get VMs with IP addresses from the plan file and populate arrays
    # Using mapfile to avoid subshell issues with array assignment
    local -a plan_vms_array
    mapfile -t plan_vms_array < <(jq -r ".clusters.${cluster_type}.vms[] | select(.ip_address and .ip_address != \"dhcp\") | \"\(.name):\(.ip_address)\"" "$plan_file" 2>/dev/null || true)

    if [[ ${#plan_vms_array[@]} -gt 0 ]]; then
        log "Found ${#plan_vms_array[@]} VMs with IPs from cluster plan"
        for vm_entry in "${plan_vms_array[@]}"; do
            # Parse name:ip format
            local vm_name="${vm_entry%%:*}"
            local vm_ip="${vm_entry##*:}"

            # Skip empty entries
            [[ -z "$vm_name" || -z "$vm_ip" ]] && continue

            # If target_vm_name is specified, filter to VMs matching that pattern
            # target_vm_name can be a regex pattern like "controller|compute"
            if [[ -n "$target_vm_name" ]] && ! [[ "$vm_name" =~ $target_vm_name ]]; then
                continue
            fi

            log_success "VM $vm_name IP: $vm_ip"
            VM_IPS+=("$vm_ip")
            VM_NAMES+=("$vm_name")
        done
    fi

    # Fallback: Try ai-how system status if cluster plan didn't have IPs
    if [[ ${#VM_IPS[@]} -eq 0 ]]; then
        log "No IPs found in cluster plan, attempting ai-how system status..."
        local status_output
        local ai_how_dir="${PROJECT_ROOT}/python/ai_how"
        if [[ ! -d "$ai_how_dir" ]]; then
            ai_how_dir="$(dirname "$0")/../../python/ai_how"
        fi

        # Execute ai-how system status with JSON output
        if ! status_output=$(cd "$ai_how_dir" && uv run ai-how system status "$config_file" --format json 2>&1); then
            log_error "Failed to get system status from ai-how"
            log_error "Output: $status_output"
            return 1
        fi

        # Parse VM information from JSON status output
        log "Parsing VM IPs from ai-how system status..."

        # Extract VMs for the specific cluster type from the status
        local -a status_vms_array
        mapfile -t status_vms_array < <(echo "$status_output" | jq -r ".${cluster_type}_cluster.vms[]? | select(.ip_address and .ip_address != \"dhcp\") | \"\(.name):\(.ip_address)\"" 2>/dev/null || true)

        if [[ ${#status_vms_array[@]} -eq 0 ]]; then
            log_error "No VMs with valid IPs found in ai-how system status"
            return 1
        fi

        for vm_entry in "${status_vms_array[@]}"; do
            # Parse name:ip format
            local vm_name="${vm_entry%%:*}"
            local vm_ip="${vm_entry##*:}"

            # Skip empty entries
            [[ -z "$vm_name" || -z "$vm_ip" ]] && continue

            # If target_vm_name is specified, filter to VMs matching that pattern
            if [[ -n "$target_vm_name" ]] && ! [[ "$vm_name" =~ $target_vm_name ]]; then
                continue
            fi

            log_success "VM $vm_name IP: $vm_ip (from system status)"
            VM_IPS+=("$vm_ip")
            VM_NAMES+=("$vm_name")
        done
    fi

    # Verify we have VMs to test
    if [[ ${#VM_IPS[@]} -eq 0 ]]; then
        log_error "Failed to extract VM IPs: no VMs with valid IPs found"
        return 1
    fi

    log_success "Retrieved ${#VM_IPS[@]} target VM IP address(es) for testing"

    # Save VM connection information for debugging
    save_vm_connection_info "$cluster_name"

    return 0
}

# Legacy function for backward compatibility - now uses ai-how API
get_vm_ips_for_cluster_legacy() {
    local cluster_pattern="$1"
    local target_vm_name="${2:-}"

    log_warning "Using legacy VM discovery method. Consider updating to use ai-how API."

    [[ -z "$cluster_pattern" ]] && {
        log_error "get_vm_ips_for_cluster_legacy: cluster_pattern parameter required"
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

        # Use the improved get_vm_ip function
        local vm_ip=""
        vm_ip=$(get_vm_ip "$vm_name")

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
    local -a ssh_opts
    _build_ssh_opts ssh_opts

    while [[ $elapsed -lt $timeout ]]; do
        if ssh "${ssh_opts[@]}" -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "echo 'SSH ready'" >/dev/null 2>&1; then
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

# =============================================================================
# Mounted Repository Support (Optimization)
# =============================================================================

#
# Check if repository is mounted at the same path on remote VM
#
# This enables running tests directly from mounted repo without SCP copying
# Supports virtvfio, NFS, and other mount types
#
# Usage: check_repo_mounted <vm_ip> <project_root>
# Returns: 0 if mounted, 1 if not mounted
#
check_repo_mounted() {
    local vm_ip="$1"
    local project_root="$2"

    [[ -z "$vm_ip" ]] && {
        log_error "check_repo_mounted: vm_ip parameter required"
        return 1
    }
    [[ -z "$project_root" ]] && {
        log_error "check_repo_mounted: project_root parameter required"
        return 1
    }

    local -a ssh_opts
    _build_ssh_opts ssh_opts

    # Try to access tests/test-infra directory on remote VM
    if ssh "${ssh_opts[@]}" -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" \
       "[[ -d '$project_root/tests/test-infra/utils' ]]" 2>/dev/null; then
        return 0  # Repository is mounted and accessible
    else
        return 1  # Repository not mounted
    fi
}

#
# Execute script directly from mounted repository (no SCP copying)
#
# Faster execution when repository is mounted at same path on host and VM
#
# Usage: execute_script_on_mounted_vm <vm_ip> <vm_name> <script_abs_path> [extra_args]
# Returns: 0 if success, 1 if failed
#
execute_script_on_mounted_vm() {
    local vm_ip="$1"
    local vm_name="$2"
    local script_abs_path="$3"
    local extra_args="${4:-}"

    [[ -z "$vm_ip" ]] && {
        log_error "execute_script_on_mounted_vm: vm_ip parameter required"
        return 1
    }
    [[ -z "$vm_name" ]] && {
        log_error "execute_script_on_mounted_vm: vm_name parameter required"
        return 1
    }
    [[ -z "$script_abs_path" ]] && {
        log_error "execute_script_on_mounted_vm: script_abs_path parameter required"
        return 1
    }

    log "Executing script on mounted repo at $vm_name ($vm_ip): $script_abs_path"

    # Derive PROJECT_ROOT from script path
    local project_root
    project_root="$(cd "$(dirname "$script_abs_path")/../../.." && pwd)" || return 1

    local test_log
    test_log="${LOG_DIR:-./logs}/test-results-${vm_name}-$(basename "$script_abs_path" .sh).log"
    mkdir -p "$(dirname "$test_log")"

    # Build command with PROJECT_ROOT exported
    # Using mounted repo - PROJECT_ROOT is automatically correct
    local cmd="PROJECT_ROOT='$project_root' MOUNTED_REPO=1 $script_abs_path"
    if [[ -n "$extra_args" ]]; then
        cmd+=" $extra_args"
    fi

    # Diagnostic logging for mounted execution
    log_debug "╔════════════════════════════════════════════════════════════════╗"
    log_debug "║      MOUNTED REPOSITORY SCRIPT EXECUTION DETAILS              ║"
    log_debug "╚════════════════════════════════════════════════════════════════╝"
    log_debug "Mounted repo execution: PROJECT_ROOT=$project_root"

    # CRITICAL: Change to script directory before executing
    local script_exec_dir
    script_exec_dir=$(dirname "$script_abs_path")
    local cmd_with_cd="cd '$script_exec_dir' && $cmd"

    # Diagnostic: Log the exact command that will be executed
    log_debug "  Script Absolute Path:     $script_abs_path"
    log_debug "  Script Working Dir:       $script_exec_dir"
    log_debug "  Will execute command:"
    log_debug "  ┌─ cd '$script_exec_dir' && PROJECT_ROOT='$project_root' \\"
    log_debug "  └─    MOUNTED_REPO=1 $script_abs_path"
    log_debug "  Expected pwd on VM:       $script_exec_dir"
    log_debug "  Expected SCRIPT_DIR:      $(dirname "$script_abs_path")"
    log_debug "════════════════════════════════════════════════════════════════"

    local -a ssh_opts
    _build_ssh_opts ssh_opts

    # Execute the script on the remote VM (no copying)
    if ssh "${ssh_opts[@]}" -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "$cmd_with_cd" 2>&1 | tee "$test_log"; then
        local test_exit_code
        test_exit_code=${PIPESTATUS[0]}

        # Copy remote logs back to local system
        log "Copying remote test logs from $vm_name..."
        local local_remote_logs_dir
        local_remote_logs_dir="${LOG_DIR:-./logs}/remote-logs-${vm_name}-$(basename "$script_abs_path" .sh)/"
        if scp "${ssh_opts[@]}" -i "$SSH_KEY_PATH" -r "$SSH_USER@$vm_ip:${script_abs_path%/*}/logs/" "$local_remote_logs_dir" 2>/dev/null; then
            log_success "Remote logs copied to $local_remote_logs_dir"
        else
            log_warning "Failed to copy remote logs (script may have failed early)"
        fi

        if [[ $test_exit_code -eq 0 ]]; then
            log_success "Script execution successful on $vm_name"
        else
            log_error "Script execution failed on $vm_name (exit code: $test_exit_code)"
        fi

        return "$test_exit_code"
    else
        return 1
    fi
}

upload_scripts_to_vm() {
    local vm_ip="$1"
    local vm_name="$2"
    local scripts_dir="$3"
    local remote_dir_arg="${4:-}"

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

    local -a ssh_opts
    _build_ssh_opts ssh_opts

    local suite_name
    suite_name="$(basename "$scripts_dir")"

    local remote_home
    if ! remote_home=$(ssh "${ssh_opts[@]}" -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" 'printf %s "$HOME"'); then
        log_error "Failed to determine remote HOME directory for $vm_name"
        return 1
    fi

    # Use caller-provided directory or default
    local remote_dir
    if [[ -z "$remote_dir_arg" ]]; then
        remote_dir="$remote_home/tests/suites/$suite_name"
    else
        remote_dir="$remote_dir_arg"
        # shellcheck disable=SC2088
        if [[ ${remote_dir:0:2} == "~/" ]]; then
            remote_dir="$remote_home/${remote_dir:2}"
        elif [[ "$remote_dir" != /* ]]; then
            remote_dir="$remote_home/$remote_dir"
        fi
    fi

    log "Uploading test scripts to $vm_name ($vm_ip)..."

    local remote_base_dir="$remote_dir"
    local remote_suite_parent
    local remote_tests_root
    local remote_common_dir
    local remote_test_infra_dir
    local remote_log_dir
    local test_name="${TEST_NAME:-test}"

    # Calculate directory structure based on the already-calculated remote_dir
    # Don't use host PROJECT_ROOT as remote path - use the remote_dir that was passed in
    remote_suite_parent="$(dirname "$remote_base_dir")"
    remote_tests_root="$(dirname "$remote_suite_parent")"
    if [[ "$remote_base_dir" != */tests/suites/* ]]; then
        remote_tests_root="$remote_suite_parent"
    fi
    if [[ "$remote_tests_root" == "/" || "$remote_tests_root" == "." || "$remote_tests_root" == "$remote_suite_parent" ]]; then
        remote_tests_root="$remote_suite_parent"
    fi
    remote_common_dir="$remote_suite_parent/common"
    remote_test_infra_dir="$remote_tests_root/test-infra"

    remote_dir="$remote_base_dir"
    local remote_log_timestamp
    remote_log_timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    remote_log_dir="$remote_base_dir/logs/${test_name}-run-$remote_log_timestamp"

    # Log detailed path information for debugging
    log "Remote path resolution:"
    log "  - Remote home: $remote_home"
    log "  - Remote base dir: $remote_base_dir"
    log "  - Remote log dir: $remote_log_dir"
    log "  - Remote common dir: $remote_common_dir"
    log "  - Remote test infra dir: $remote_test_infra_dir"

    local mkdir_cmd="mkdir -p \"$remote_base_dir\" \"$remote_log_dir\" \"$remote_common_dir\" \"$remote_test_infra_dir\""
    log "Executing mkdir command on $vm_name:"
    log "  ssh $SSH_USER@$vm_ip '$mkdir_cmd'"

    if ! ssh "${ssh_opts[@]}" -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "$mkdir_cmd" 2>/dev/null; then
        log_warning "Failed to create directories at planned location, falling back to /tmp"
        log "Command that failed: $mkdir_cmd"

        # Fallback: use /tmp with a unique directory structure
        local tmp_test_dir
        tmp_test_dir="/tmp/hpc-tests-$(date +%s)-$$"
        local tmp_suite_name
        tmp_suite_name="$(basename "$scripts_dir")"

        remote_base_dir="$tmp_test_dir/suites/$tmp_suite_name"
        remote_log_dir="$tmp_test_dir/logs/${test_name}-run-$remote_log_timestamp"
        remote_common_dir="$tmp_test_dir/common"
        remote_test_infra_dir="$tmp_test_dir/test-infra"
        remote_dir="$remote_base_dir"
        remote_suite_parent="$tmp_test_dir/suites"

        log "Fallback paths:"
        log "  - Remote base dir: $remote_base_dir"
        log "  - Remote log dir: $remote_log_dir"
        log "  - Remote common dir: $remote_common_dir"
        log "  - Remote test infra dir: $remote_test_infra_dir"

        mkdir_cmd="mkdir -p \"$remote_base_dir\" \"$remote_log_dir\" \"$remote_common_dir\" \"$remote_test_infra_dir\""
        if ! ssh "${ssh_opts[@]}" -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "$mkdir_cmd"; then
            log_error "Failed to create directories even in /tmp fallback location"
            log_error "Command that failed: $mkdir_cmd"
            return 1
        fi
        log_success "Created directories in /tmp fallback location"
    fi

    # Upload all test scripts
    if ! scp "${ssh_opts[@]}" -i "$SSH_KEY_PATH" "$scripts_dir"/*.sh "$SSH_USER@$vm_ip:$remote_base_dir/"; then
        log_error "Failed to upload test scripts"
        return 1
    fi

    # Upload common utilities if they exist in parent directory
    # Tests use ../common relative path, so common needs to be at parent level
    local scripts_parent_dir
    scripts_parent_dir="$(dirname "$scripts_dir")"
    if [[ -d "$scripts_parent_dir/common" ]]; then
        if ! scp "${ssh_opts[@]}" -r -i "$SSH_KEY_PATH" "$scripts_parent_dir/common" "$SSH_USER@$vm_ip:$remote_suite_parent/"; then
            log_error "Failed to upload common utilities"
            return 1
        fi
    fi

    # Check if test-infra utilities exist on remote VM, upload if missing
    # Test scripts source utilities from PROJECT_ROOT/tests/test-infra/utils/
    log "Checking for test infrastructure utilities on $vm_name..."

    # Ensure test-infra utilities mirror host-relative structure on remote VM
    local test_infra_remote_path="$remote_tests_root/test-infra/utils"

    if ! ssh "${ssh_opts[@]}" -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "[[ -d '$test_infra_remote_path' ]]" 2>/dev/null; then
        log "Test infrastructure utilities not found on remote VM, synchronizing..."

        local test_infra_dir
        test_infra_dir="$(cd "$scripts_dir/../.." && pwd)/test-infra"

        if [[ -d "$test_infra_dir" ]]; then
            log "Uploading test-infra directory from: $test_infra_dir"

            if ! scp "${ssh_opts[@]}" -r -i "$SSH_KEY_PATH" "$test_infra_dir" "$SSH_USER@$vm_ip:$remote_tests_root/"; then
                log_error "Failed to upload test-infra utilities"
                return 1
            fi

            log_success "Test infrastructure utilities uploaded successfully to $remote_tests_root/test-infra"
        else
            log_warning "Could not locate test-infra directory locally at: $test_infra_dir"
        fi
    else
        log "Test infrastructure utilities already present on remote VM"
    fi

    # Make scripts executable
    local chmod_cmd="chmod +x $remote_base_dir/*.sh && chmod -R +x $remote_suite_parent/common/*.sh 2>/dev/null && chmod -R +x '$remote_tests_root/test-infra/utils'/*.sh 2>/dev/null || true"
    # shellcheck disable=SC2029
    if ! ssh "${ssh_opts[@]}" -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "$chmod_cmd"; then
        log_error "Failed to make test scripts executable"
        return 1
    fi

    log_success "Test scripts uploaded successfully to $remote_base_dir"

    # Export the actual remote directory used (might be /tmp fallback)
    # Caller can use this to execute scripts in the correct location
    export ACTUAL_REMOTE_DIR="$remote_base_dir"

    return 0
}

execute_script_on_vm() {
    local vm_ip="$1"
    local vm_name="$2"
    local script_name="$3"
    local remote_dir_arg="${4:-}"
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

    # Ensure PROJECT_ROOT, TESTS_DIR are set and exported
    # These are critical for test scripts to source shared utilities
    : "${PROJECT_ROOT:?ERROR: PROJECT_ROOT must be set before calling execute_script_on_vm}"
    : "${TESTS_DIR:?ERROR: TESTS_DIR must be set before calling execute_script_on_vm}"
    : "${SSH_KEY_PATH:?ERROR: SSH_KEY_PATH must be set before calling execute_script_on_vm}"
    : "${SSH_USER:?ERROR: SSH_USER must be set before calling execute_script_on_vm}"

    local test_name="${TEST_NAME:-test}"
    local -a ssh_opts
    _build_ssh_opts ssh_opts
    local remote_home
    if ! remote_home=$(ssh "${ssh_opts[@]}" -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" 'printf %s "$HOME"'); then
        log_error "Failed to determine remote HOME directory for $vm_name"
        return 1
    fi

    local remote_dir="$remote_dir_arg"
    if [[ -z "$remote_dir" ]]; then
        remote_dir="test-scripts"
    fi
    # shellcheck disable=SC2088
    if [[ ${remote_dir:0:2} == "~/" ]]; then
        remote_dir="$remote_home/${remote_dir:2}"
    elif [[ "$remote_dir" != /* ]]; then
        remote_dir="$remote_home/$remote_dir"
    fi

    local remote_log_timestamp
    remote_log_timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local remote_log_dir="$remote_dir/logs/${test_name}-run-$remote_log_timestamp"
    local remote_suite_parent
    local remote_tests_dir
    local remote_project_root

    remote_suite_parent="$(dirname "$remote_dir")"
    remote_tests_dir="$(dirname "$remote_suite_parent")"
    local has_standard_layout=true
    if [[ "$remote_dir" != */tests/suites/* ]]; then
        has_standard_layout=false
        remote_tests_dir="$remote_suite_parent"
    fi

    if [[ -z "$remote_tests_dir" || "$remote_tests_dir" == "." || "$remote_tests_dir" == "/" ]]; then
        remote_tests_dir="$remote_dir"
    fi

    if [[ "$has_standard_layout" == true ]]; then
        remote_project_root="$(dirname "$remote_tests_dir")"
    else
        remote_project_root="$remote_suite_parent"
    fi

    if [[ -z "$remote_project_root" || "$remote_project_root" == "." || "$remote_project_root" == "/" ]]; then
        remote_project_root="$remote_tests_dir"
    fi

    local cmd="cd '$remote_dir' && mkdir -p '$remote_log_dir' && LOG_DIR='$remote_log_dir' PROJECT_ROOT='$remote_project_root' TESTS_DIR='$remote_tests_dir' SSH_KEY_PATH='$SSH_KEY_PATH' SSH_USER='$SSH_USER' CONTROLLER_IP='$vm_ip' bash './$script_name'"
    if [[ -n "$extra_args" ]]; then
        cmd+=" $extra_args"
    fi

    # Diagnostic logging for SCP execution
    log_debug "╔════════════════════════════════════════════════════════════════╗"
    log_debug "║        SCP-COPIED SCRIPT EXECUTION DETAILS                    ║"
    log_debug "╚════════════════════════════════════════════════════════════════╝"
    log_debug "  Script Name:              $script_name"
    log_debug "  Remote Directory Base:    $remote_dir"
    log_debug "  Remote Script Path:       $remote_dir/$script_name"
    log_debug "  Script Working Dir:       $remote_dir"
    log_debug "  Will execute command:"
    log_debug "  ┌─ cd '$remote_dir' && \\"
    log_debug "  │     LOG_DIR='$remote_log_dir' \\"
    log_debug "  │     PROJECT_ROOT='$remote_project_root' TESTS_DIR='$remote_tests_dir' \\"
    log_debug "  │     SSH_KEY_PATH='$SSH_KEY_PATH' SSH_USER='$SSH_USER' \\"
    log_debug "  └─    CONTROLLER_IP='$vm_ip' bash ./$script_name"
    log_debug "  Expected pwd on VM:       $remote_dir"
    log_debug "  Target VM:                $vm_name ($vm_ip)"
    log_debug "  PROJECT_ROOT:             $remote_project_root"
    log_debug "  TESTS_DIR:                $remote_tests_dir"
    log_debug "════════════════════════════════════════════════════════════════"

    # Execute the script on the remote VM
    # Simply pass the command to SSH - no bash -c wrapper needed
    ssh "${ssh_opts[@]}" -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "$cmd" 2>&1 | tee "$test_log"
    local test_exit_code=${PIPESTATUS[0]}

    # Copy remote logs back to local system (always, regardless of success/failure)
    log "Copying remote test logs from $vm_name..."
    local local_remote_logs_dir="${LOG_DIR:-./logs}/remote-logs-${vm_name}-${script_name%.sh}/"
    mkdir -p "$local_remote_logs_dir"
    local remote_log_scp_path="$SSH_USER@$vm_ip:'$remote_log_dir/'"
    if scp "${ssh_opts[@]}" -i "$SSH_KEY_PATH" -r "$remote_log_scp_path" "$local_remote_logs_dir" 2>/dev/null; then
        log_success "Remote logs copied to $local_remote_logs_dir"
    else
        log_warning "Failed to copy remote logs from $vm_name"
    fi

    # Report results based on exit code
    if [[ "$test_exit_code" -eq 0 ]]; then
        log_success "Script executed successfully on $vm_name: $script_name"
        return 0
    else
        log_warning "Script failed on $vm_name: $script_name (exit code: $test_exit_code)"
        log_error "SSH command: ssh ${SSH_OPTS} -i \"$SSH_KEY_PATH\" \"$SSH_USER@$vm_ip\" \"$cmd\" "
        return "$test_exit_code"
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
export -f get_vm_ip get_vm_ips_for_cluster get_vm_ips_for_cluster_legacy wait_for_vm_ssh upload_scripts_to_vm
export -f execute_script_on_vm save_vm_connection_info
