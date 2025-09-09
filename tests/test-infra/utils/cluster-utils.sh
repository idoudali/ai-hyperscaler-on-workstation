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
: "${PROJECT_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
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

    # Execute command with proper exit code capture using PIPEFAIL
    set -o pipefail  # Pipeline returns exit code of first failing command
    uv run ai-how hpc start "$resolved_config" 2>&1 | tee "$start_log"
    local exit_code=$?
    set +o pipefail  # Reset pipefail behavior

    if [[ $exit_code -eq 0 ]]; then
        log_success "Cluster '$cluster_name' started successfully"
        return 0
    else
        log_error "Failed to start cluster '$cluster_name' (exit code: $exit_code)"
        log "Check the log file: $start_log"
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

    # Execute command with proper exit code capture using PIPEFAIL
    set -o pipefail  # Pipeline returns exit code of first failing command
    bash -c "$cmd" 2>&1 | tee "$destroy_log"
    local exit_code=$?
    set +o pipefail  # Reset pipefail behavior

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
    local cluster_name="$1"
    local timeout="${2:-300}"

    [[ -z "$cluster_name" ]] && {
        log_error "wait_for_cluster_vms: cluster_name parameter required"
        return 1
    }

    log "Waiting for compute VMs for cluster ($cluster_name) to be created and running..."

    local elapsed=0
    local check_interval=10

    while [[ $elapsed -lt $timeout ]]; do
        # Check for compute VMs matching the cluster name pattern
        local running_compute_vms
        running_compute_vms=$(virsh list --name --state-running 2>/dev/null | grep "^${cluster_name}-compute" || true)

        if [[ -n "$running_compute_vms" ]]; then
            local compute_count
            compute_count=$(echo "$running_compute_vms" | wc -l)
            log_success "Found $compute_count compute VM(s) running for cluster ($cluster_name):"
            echo "$running_compute_vms" | while read -r vm; do
                log "  - $vm"
            done
            return 0
        fi

        log "Compute VMs not ready yet... waiting (${elapsed}s/${timeout}s)"
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    log_error "Timeout waiting for compute VMs for cluster ($cluster_name) to start"
    return 1
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
