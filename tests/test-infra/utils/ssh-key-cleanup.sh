#!/bin/bash

# SSH Host Key Cleanup Utility
# Removes SSH host keys from known_hosts file for specified IP addresses
#
# Usage:
#   ./ssh-key-cleanup.sh IP1 [IP2 IP3 ...]
#   echo "192.168.100.10 192.168.100.11" | ./ssh-key-cleanup.sh
#
# Examples:
#   ./ssh-key-cleanup.sh 192.168.100.10 192.168.100.11 192.168.100.12
#   ./ssh-key-cleanup.sh $(virsh list --name | xargs -I{} virsh domifaddr {} | awk '/ipv4/{print $4}' | cut -d'/' -f1)

set -euo pipefail

# Default configuration
KNOWN_HOSTS="${HOME}/.ssh/known_hosts"
VERBOSE="${VERBOSE:-0}"

# Check for help flag
if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    cat << 'EOF'
SSH Host Key Cleanup Utility

Removes SSH host keys from known_hosts file for specified IP addresses.
This prevents "host key verification failed" errors when VMs are rebuilt
with new host keys.

Usage:
  ./ssh-key-cleanup.sh IP1 [IP2 IP3 ...]
  echo "IP1 IP2 IP3" | ./ssh-key-cleanup.sh

Arguments:
  IP addresses to remove from known_hosts (space-separated)
  Can be provided as command-line arguments or via stdin

Environment Variables:
  VERBOSE=1        Enable verbose output
  KNOWN_HOSTS      Path to known_hosts file (default: ~/.ssh/known_hosts)

Examples:
  # Remove specific IPs
  ./ssh-key-cleanup.sh 192.168.100.10 192.168.100.11

  # Remove IPs from VM discovery
  ./ssh-key-cleanup.sh $(virsh list --name | head -2 | xargs -I{} virsh domifaddr {})

  # Verbose mode
  VERBOSE=1 ./ssh-key-cleanup.sh 192.168.100.10

Exit Codes:
  0 - All keys removed successfully
  1 - Some keys failed to remove or no IPs provided
  2 - known_hosts file not found

EOF
    exit 0
fi

# Logging functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log_verbose() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [VERBOSE] $*"
    fi
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $*"
}

log_warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $*"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ ERROR: $*" >&2
}

# Check if known_hosts file exists
check_known_hosts() {
    if [ ! -f "$KNOWN_HOSTS" ]; then
        log_warning "known_hosts file not found: $KNOWN_HOSTS"
        log "No SSH host keys to clean."
        exit 2
    fi
}

# Remove SSH host key for a single IP
remove_host_key() {
    local ip="$1"

    log_verbose "Removing host key for: $ip"

    # Check if the IP exists in known_hosts
    if ! grep -q "^${ip}" "$KNOWN_HOSTS" 2>/dev/null; then
        log_verbose "  No entry found for $ip"
        return 0
    fi

    # Remove the host key
    if ssh-keygen -f "$KNOWN_HOSTS" -R "$ip" >/dev/null 2>&1; then
        log_success "Removed host key: $ip"
        return 0
    else
        log_error "Failed to remove host key: $ip"
        return 1
    fi
}

# Main execution
main() {
    local ips_to_clean=()

    # Collect IPs from command-line arguments
    if [[ $# -gt 0 ]]; then
        ips_to_clean=("$@")
    else
        # Read from stdin if no arguments provided
        if [[ ! -t 0 ]]; then
            log_verbose "Reading IPs from stdin..."
            while read -r line; do
                # Split line into individual IPs
                for ip in $line; do
                    # Basic IP validation (simple check)
                    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        ips_to_clean+=("$ip")
                    else
                        log_verbose "Skipping invalid IP format: $ip"
                    fi
                done
            done
        else
            log_error "No IP addresses provided"
            echo ""
            echo "Usage:"
            echo "  $0 IP1 [IP2 IP3 ...]"
            echo "  echo 'IP1 IP2 IP3' | $0"
            echo ""
            echo "Use --help for more information"
            exit 1
        fi
    fi

    # Check if we have any IPs to clean
    if [ ${#ips_to_clean[@]} -eq 0 ]; then
        log_error "No valid IP addresses to clean"
        exit 1
    fi

    log "=== SSH Host Key Cleanup ==="
    log "Removing SSH host keys for ${#ips_to_clean[@]} IP(s)..."
    log ""

    check_known_hosts

    # Remove host keys for each IP
    local removed=0
    local failed=0
    local skipped=0

    for ip in "${ips_to_clean[@]}"; do
        # Check if IP entry exists before attempting removal
        if grep -q "^${ip}" "$KNOWN_HOSTS" 2>/dev/null; then
            if remove_host_key "$ip"; then
                removed=$((removed + 1))
            else
                failed=$((failed + 1))
            fi
        else
            log_verbose "No entry for $ip (skipped)"
            skipped=$((skipped + 1))
        fi
    done

    log ""
    log_success "=== Cleanup Complete ==="
    log "  Removed: $removed"
    log "  Skipped: $skipped (no entry found)"
    if [ "$failed" -gt 0 ]; then
        log_error "  Failed:  $failed"
        exit 1
    fi

    log ""
    if [ "$removed" -gt 0 ]; then
        log "SSH host keys cleaned. You can now connect to VMs without host key errors."
    else
        log "No SSH host keys needed cleaning (all IPs were already clean)."
    fi

    # Exit successfully (only fail if $failed > 0, which is handled above)
    exit 0
}

# Run main function with all arguments
main "$@"
