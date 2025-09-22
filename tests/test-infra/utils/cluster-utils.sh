#!/bin/bash
#
# Cluster Management Utilities for Test Framework
# Shared cluster operations between test suites
#

# Source logging utilities if available
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
: "${PROJECT_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
: "${TESTS_DIR:=$PROJECT_ROOT/tests}"

# Helper function to resolve test config path
resolve_test_config_path() {
    local test_config="$1"

    [[ -z "$test_config" ]] && {
        log_error "resolve_test_config_path: test_config parameter required"
        return 1
    }

    # If it's already an absolute path, use it as-is
    if [[ "$test_config" == /* ]]; then
        echo "$test_config"
        return 0
    fi

    # If it already starts with tests/, use PROJECT_ROOT directly
    if [[ "$test_config" == tests/* ]]; then
        echo "$PROJECT_ROOT/$test_config"
        return 0
    fi

    # Otherwise, prefix with TESTS_DIR
    echo "$TESTS_DIR/$test_config"
}

# Cluster management functions
start_cluster() {
    local test_config="$1"
    local cluster_name="${2:-$(basename "${test_config%.yaml}")}"

    [[ -z "$test_config" ]] && {
        log_error "start_cluster: test_config parameter required"
        return 1
    }

    # Resolve the test config path (handles both absolute and relative paths)
    local resolved_config
    if ! resolved_config=$(resolve_test_config_path "$test_config"); then
        return 1
    fi

    [[ ! -f "$resolved_config" ]] && {
        log_error "Test configuration not found: $resolved_config"
        return 1
    }

    log "Starting cluster: $cluster_name"
    log "Configuration: $resolved_config"

    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project root: $PROJECT_ROOT"
        return 1
    }

    local start_log="${LOG_DIR:-./logs}/cluster-start-${cluster_name}.log"
    mkdir -p "$(dirname "$start_log")"

    # Start the cluster
    log "Executing: uv run ai-how hpc start $resolved_config"

    # Execute command and capture exit code using PIPESTATUS
    uv run ai-how hpc start "$resolved_config" 2>&1 | tee "$start_log"
    local exit_code=${PIPESTATUS[0]}

    if [[ $exit_code -eq 0 ]]; then
        log_success "Cluster '$cluster_name' started successfully"
        return 0
    else
        log_error "Failed to start cluster '$cluster_name' (exit code: $exit_code)"
        log "Check the log file: $start_log"
        # shellcheck disable=SC2086
        return $exit_code
    fi
}

destroy_cluster() {
    local test_config="$1"
    local cluster_name="${2:-$(basename "${test_config%.yaml}")}"
    local force_flag="${3:-}"

    [[ -z "$test_config" ]] && {
        log_error "destroy_cluster: test_config parameter required"
        return 1
    }

    # Resolve the test config path (handles both absolute and relative paths)
    local resolved_config
    if ! resolved_config=$(resolve_test_config_path "$test_config"); then
        return 1
    fi

    log "Destroying cluster: $cluster_name"
    log "Configuration: $resolved_config"

    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project root: $PROJECT_ROOT"
        return 1
    }

    local destroy_log="${LOG_DIR:-./logs}/cluster-destroy-${cluster_name}.log"
    mkdir -p "$(dirname "$destroy_log")"

    # Build destroy command
    local cmd="uv run ai-how hpc destroy $resolved_config"
    if [[ -n "$force_flag" ]]; then
        cmd+=" --force"
    fi

    # Destroy the cluster
    log "Executing: $cmd"

    # Execute command and capture exit code using PIPESTATUS
    bash -c "$cmd" 2>&1 | tee "$destroy_log"
    local exit_code=${PIPESTATUS[0]}

    if [[ $exit_code -eq 0 ]]; then
        log_success "Cluster '$cluster_name' destroyed successfully"

        # Wait a moment and verify cleanup
        sleep 5
        if verify_cluster_cleanup "$cluster_name"; then
            log_success "Cluster cleanup verification passed"
            return 0
        else
            log_warning "Cluster cleanup verification found remaining VMs"
            return 1
        fi
    else
        log_error "Failed to destroy cluster '$cluster_name' (exit code: $exit_code)"
        log "Check the log file: $destroy_log"
        # shellcheck disable=SC2086
        return $exit_code
    fi
}

verify_cluster_cleanup() {
    local cluster_pattern="${1:-test}"

    log "Verifying cluster cleanup (pattern: $cluster_pattern)..."

    local remaining_vms
    if remaining_vms=$(virsh list --all 2>/dev/null | grep -i "$cluster_pattern" || true); then
        if [[ -n "$remaining_vms" ]]; then
            log_warning "Found remaining VMs matching pattern '$cluster_pattern':"
            echo "$remaining_vms"
            return 1
        fi
    fi

    log_success "No remaining VMs found for pattern '$cluster_pattern'"
    return 0
}

check_cluster_not_running() {
    local target_vm_name="$1"

    [[ -z "$target_vm_name" ]] && {
        log_error "check_cluster_not_running: target_vm_name parameter required"
        return 1
    }

    log "Checking if target VM ($target_vm_name) is already running..."

    # Check if the target VM exists and is running
    if virsh list --name --state-running 2>/dev/null | grep -q "^${target_vm_name}$"; then
        log_error "Target VM ($target_vm_name) is already running!"
        log_error "The test framework requires a clean environment to start."
        echo ""
        log_error "CLUSTER CLEANUP REQUIRED:"
        echo ""
        show_cleanup_instructions "$target_vm_name"
        return 1
    fi

    # Also check if VM exists but is not running (might be in failed state)
    if virsh list --all 2>/dev/null | grep -q "^.*${target_vm_name}"; then
        local vm_state
        vm_state=$(virsh list --all | grep "${target_vm_name}" | awk '{print $3}')
        log_warning "Target VM ($target_vm_name) exists in state: $vm_state"
        log_warning "This may indicate a previous test run didn't clean up properly."
        echo ""
        show_cleanup_instructions "$target_vm_name"
        return 1
    fi

    log_success "Target VM ($target_vm_name) is not running - ready to start"
    return 0
}

show_cleanup_instructions() {
    local vm_name="$1"
    local test_config="${2:-test-config.yaml}"

    # Resolve the test config path (handles both absolute and relative paths)
    local resolved_config
    if ! resolved_config=$(resolve_test_config_path "$test_config"); then
        resolved_config="$test_config"  # Fallback to original if resolution fails
    fi

    echo "To properly clean up the existing cluster, use the ai-how tool:"
    echo ""
    echo "  cd $PROJECT_ROOT"
    echo "  uv run ai-how destroy $resolved_config"
    echo ""
    echo "Alternative cleanup methods:"
    echo ""
    echo "1. Force destroy with ai-how:"
    echo "   uv run ai-how destroy $resolved_config --force"
    echo ""
    echo "2. Manual VM cleanup using virsh:"
    echo "   # Stop the VM"
    echo "   virsh destroy $vm_name"
    echo "   # Remove VM definition"
    echo "   virsh undefine $vm_name"
    echo "   # Check for any remaining VMs"
    echo "   virsh list --all"
    echo ""
    echo "3. Check for related VMs that might need cleanup:"
    echo "   virsh list --all | grep -E '(hpc|cluster|test)'"
    echo ""
    echo "After cleanup, verify no VMs are running:"
    echo "   virsh list --state-running"
    echo ""
    echo "Then re-run this test framework."
    echo ""
}

wait_for_cluster_vms() {
    local config_file="$1"
    local cluster_type="${2:-hpc}"  # "hpc" or "cloud"
    local timeout="${3:-300}"

    [[ -z "$config_file" ]] && {
        log_error "wait_for_cluster_vms: config_file parameter required"
        return 1
    }

    # Check if jq is available for JSON parsing
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq command not found. Please install jq to parse JSON output from ai-how API."
        log_error "Install with: 'apt install jq', 'brew install jq', 'snap install jq', or download from https://stedolan.github.io/jq/"
        return 1
    fi

    # Parse the configuration using ai-how API to get cluster name and expected VMs
    local cluster_name expected_vms
    if ! cluster_name=$(parse_cluster_name "$config_file" "$cluster_type"); then
        log_error "Failed to parse cluster name from configuration using ai-how API"
        return 1
    fi

    if ! expected_vms=$(parse_expected_vms "$config_file" "$cluster_type"); then
        log_error "Failed to parse expected VMs from configuration using ai-how API"
        return 1
    fi

    [[ -z "$cluster_name" ]] && {
        log_error "Cluster name not found in configuration for cluster type: $cluster_type"
        return 1
    }

    [[ -z "$expected_vms" ]] && {
        log_warning "No VMs expected for cluster ($cluster_name) - configuration may be empty"
        return 0
    }

    log "Waiting for VMs for cluster ($cluster_name) to be created and running..."
    log "Expected VMs: $(echo "$expected_vms" | tr '\n' ' ')"

    local elapsed=0
    local check_interval=10
    local expected_vm_count
    expected_vm_count=$(echo "$expected_vms" | wc -w)

    while [[ $elapsed -lt $timeout ]]; do
        # Get all running VMs matching the cluster name pattern
        local all_running_vms
        all_running_vms=$(virsh list --name --state-running 2>/dev/null | grep "^${cluster_name}-" || true)

        if [[ -n "$all_running_vms" ]]; then
            # Check if all expected VMs are running
            local found_vms=()
            local missing_vms=()

            for expected_vm in $expected_vms; do
                if echo "$all_running_vms" | grep -q "^${expected_vm}$"; then
                    found_vms+=("$expected_vm")
                else
                    missing_vms+=("$expected_vm")
                fi
            done

            if [[ ${#missing_vms[@]} -eq 0 ]]; then
                log_success "All ${#found_vms[@]} expected VM(s) are running for cluster ($cluster_name):"
                for vm in "${found_vms[@]}"; do
                    log "  ✓ $vm"
                done
                return 0
            else
                log "Found ${#found_vms[@]}/${expected_vm_count} expected VMs. Missing: $(echo "${missing_vms[@]}" | tr ' ' ',')"
            fi
        else
            log "No VMs found yet for cluster ($cluster_name)"
        fi

        log "VMs not ready yet... waiting (${elapsed}s/${timeout}s)"
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    log_error "Timeout waiting for VMs for cluster ($cluster_name) to start"
    log_error "Expected VMs: $(echo "$expected_vms" | tr '\n' ' ')"
    return 1
}

# Helper function to get cluster planning data using ai-how API
get_cluster_plan_data() {
    local config_file="$1"
    local cluster_type="${2:-hpc}"

    [[ -z "$config_file" ]] && {
        log_error "get_cluster_plan_data: config_file parameter required"
        return 1
    }

    # Resolve the config file path
    local resolved_config
    if ! resolved_config=$(resolve_test_config_path "$config_file"); then
        return 1
    fi

    [[ ! -f "$resolved_config" ]] && {
        log_error "Configuration file not found: $resolved_config"
        return 1
    }

    # Log to stderr to avoid contaminating stdout (needed for JSON parsing)
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Getting cluster plan data using ai-how API: $resolved_config" >&2

    # Use ai-how plan clusters command with JSON output
    # Extract only the JSON part (from first { to last })
    local plan_output
    local raw_output
    if ! raw_output=$(uv run ai-how plan clusters "$resolved_config" --format json 2>&1); then
        echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} Failed to get cluster plan data using ai-how API" >&2
        return 1
    fi

    # Extract JSON by finding the first { and last }
    plan_output=$(echo "$raw_output" | sed -n '/^{/,/^}/p')

    # Parse JSON and extract cluster data
    local cluster_data
    if ! cluster_data=$(echo "$plan_output" | jq -r ".clusters.${cluster_type}" 2>/dev/null); then
        echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} Failed to parse cluster data from ai-how API output" >&2
        return 1
    fi

    if [[ "$cluster_data" == "null" ]]; then
        echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} No ${cluster_type} cluster found in configuration" >&2
        return 1
    fi

    echo "$cluster_data"
}

# Helper function to parse cluster name from ai-how API
parse_cluster_name() {
    local config_file="$1"
    local cluster_type="$2"

    local cluster_data
    if ! cluster_data=$(get_cluster_plan_data "$config_file" "$cluster_type"); then
        return 1
    fi

    echo "$cluster_data" | jq -r '.name' 2>/dev/null
}

# Helper function to parse expected VMs from ai-how API
parse_expected_vms() {
    local config_file="$1"
    local cluster_type="$2"

    local cluster_data
    if ! cluster_data=$(get_cluster_plan_data "$config_file" "$cluster_type"); then
        return 1
    fi

    # Extract VM names from the cluster data
    local expected_vms
    expected_vms=$(echo "$cluster_data" | jq -r '.vms[].name' 2>/dev/null | tr '\n' ' ')

    echo "$expected_vms" | xargs  # Trim whitespace
}

# Helper function to get VM specifications from ai-how API
get_vm_specifications() {
    local config_file="$1"
    local cluster_type="$2"
    local vm_name="${3:-}"

    local cluster_data
    if ! cluster_data=$(get_cluster_plan_data "$config_file" "$cluster_type"); then
        return 1
    fi

    if [[ -n "$vm_name" ]]; then
        # Get specific VM data
        echo "$cluster_data" | jq -r ".vms[] | select(.name == \"$vm_name\")" 2>/dev/null
    else
        # Get all VM data
        echo "$cluster_data" | jq -r '.vms[]' 2>/dev/null
    fi
}

# Cleanup handler for use with trap
cleanup_cluster_on_exit() {
    local test_config="$1"
    local exit_code=$?

    log "Cleaning up cluster on exit (code: $exit_code)..."

    if [[ "${CLEANUP_REQUIRED:-false}" == "true" ]]; then
        log "Attempting to tear down test cluster..."
        if ! destroy_cluster "$test_config" "" "force"; then
            log_warning "Automated cleanup failed. You may need to manually clean up VMs."
            if [[ "${INTERACTIVE_CLEANUP:-false}" == "true" ]]; then
                ask_manual_cleanup "$test_config"
            fi
        fi
    fi

    exit $exit_code
}

ask_manual_cleanup() {
    local test_config="$1"

    echo
    log_warning "Test cluster may still be running. Manual cleanup options:"
    echo "  1. List running VMs: virsh list --all"
    echo "  2. Stop specific VM: virsh destroy <vm-name>"
    echo "  3. Remove VM: virsh undefine <vm-name>"
    echo "  4. Clean up using ai-how: cd $PROJECT_ROOT && uv run ai-how destroy $test_config"
    echo

    if [[ -t 0 ]]; then  # Check if running interactively
        read -p "Would you like to attempt manual cleanup now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            manual_cluster_cleanup "$test_config"
        fi
    fi
}

manual_cluster_cleanup() {
    local test_config="$1"

    log "Attempting manual cleanup..."

    # Resolve the test config path (handles both absolute and relative paths)
    local resolved_config
    if ! resolved_config=$(resolve_test_config_path "$test_config"); then
        resolved_config="$test_config"  # Fallback to original if resolution fails
    fi

    # Try to destroy cluster using ai-how
    cd "$PROJECT_ROOT" || return 1
    if uv run ai-how destroy "$resolved_config" --force 2>/dev/null; then
        log_success "Manual cleanup completed"
    else
        log_warning "Manual cleanup with ai-how failed"

        # List VMs for manual intervention
        log "Current VM status:"
        virsh list --all || true
    fi
}

# Export functions for use in other scripts
export -f resolve_test_config_path start_cluster destroy_cluster verify_cluster_cleanup check_cluster_not_running
export -f show_cleanup_instructions wait_for_cluster_vms cleanup_cluster_on_exit
export -f ask_manual_cleanup manual_cluster_cleanup
export -f get_cluster_plan_data parse_cluster_name parse_expected_vms get_vm_specifications
