#!/bin/bash

# Clean SSH Keys for Running Cluster VMs
# Wrapper script that discovers cluster VMs and cleans their SSH host keys
#
# Usage:
#   ./clean-cluster-ssh-keys.sh [OPTIONS]
#
# Options:
#   --cluster-pattern PATTERN  Filter VMs by name pattern (default: all running VMs)
#   --verbose, -v             Enable verbose output
#   --help, -h                Show this help message
#
# Examples:
#   ./clean-cluster-ssh-keys.sh                              # Clean all running VMs
#   ./clean-cluster-ssh-keys.sh --cluster-pattern "test-hpc" # Clean specific cluster
#   ./clean-cluster-ssh-keys.sh --verbose                    # Verbose output

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
UTILS_DIR="${SCRIPT_DIR}/test-infra/utils"
if [[ ! -f "${UTILS_DIR}/vm-utils.sh" ]]; then
    echo "ERROR: Required utilities not found: ${UTILS_DIR}/vm-utils.sh"
    exit 1
fi

# Source utility functions
# shellcheck source=./test-infra/utils/log-utils.sh
source "${UTILS_DIR}/log-utils.sh" 2>/dev/null || {
    # Fallback logging if log-utils not available
    log() { echo "[LOG] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_success() { echo "[SUCCESS] $*"; }
    log_warning() { echo "[WARNING] $*"; }
    log_verbose() { [[ "${VERBOSE:-0}" -eq 1 ]] && echo "[VERBOSE] $*"; }
}

# shellcheck source=./test-infra/utils/vm-utils.sh
source "${UTILS_DIR}/vm-utils.sh"

# Default configuration
CLUSTER_PATTERN=""
VERBOSE=0
export VERBOSE

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cluster-pattern)
            CLUSTER_PATTERN="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=1
            export VERBOSE
            shift
            ;;
        --help|-h)
            head -n 20 "$0" | tail -n +2 | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log "=== SSH Host Key Cleanup for Cluster VMs ==="
    log ""

    # Discover running VMs
    local vms
    if [[ -n "$CLUSTER_PATTERN" ]]; then
        log "Discovering VMs matching pattern: $CLUSTER_PATTERN"
        vms=$(virsh list --name --state-running | grep "$CLUSTER_PATTERN" || true)
    else
        log "Discovering all running HPC/test cluster VMs..."
        vms=$(virsh list --name --state-running | grep -E "(hpc|test|cluster)" || true)
    fi

    if [[ -z "$vms" ]]; then
        log_warning "No running cluster VMs found"
        if [[ -n "$CLUSTER_PATTERN" ]]; then
            log "Pattern used: $CLUSTER_PATTERN"
        fi
        log ""
        log "Available VMs:"
        virsh list --name --state-running | sed 's/^/  /'
        exit 0
    fi

    log "Found VMs:"
    while IFS= read -r line; do echo "  $line"; done <<< "$vms"
    log ""

    # Collect IPs from discovered VMs
    local ips=()
    while IFS= read -r vm_name; do
        [[ -z "$vm_name" ]] && continue

        log_verbose "Getting IP for: $vm_name"

        # Use get_vm_ip function from vm-utils.sh
        local vm_ip
        if vm_ip=$(get_vm_ip "$vm_name" 2>/dev/null); then
            ips+=("$vm_ip")
            log_verbose "  Found IP: $vm_ip"
        else
            log_verbose "  No IP found (VM may not have network ready)"
        fi
    done <<< "$vms"

    if [[ ${#ips[@]} -eq 0 ]]; then
        log_warning "No IP addresses found for running VMs"
        log "VMs may not have network connectivity established yet"
        exit 0
    fi

    log "Collected ${#ips[@]} IP address(es) to clean"
    log ""

    # Call the simplified ssh-key-cleanup utility
    local cleanup_script="${UTILS_DIR}/ssh-key-cleanup.sh"

    if [[ ! -f "$cleanup_script" ]]; then
        log_error "Cleanup utility not found: $cleanup_script"
        exit 1
    fi

    # Pass IPs to cleanup utility
    log "Cleaning SSH host keys..."
    if [[ "$VERBOSE" -eq 1 ]]; then
        export VERBOSE=1
        "$cleanup_script" "${ips[@]}"
    else
        "$cleanup_script" "${ips[@]}"
    fi

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log ""
        log_success "All SSH host keys cleaned successfully"
        log "You can now connect to cluster VMs without host key verification errors"
        return 0
    else
        log ""
        log_error "SSH key cleanup completed with errors"
        return 1
    fi
}

# Run main function
main
