#!/usr/bin/env bash
# Export k3s kubeconfig for multi-cluster management
#
# This script exports the k3s kubeconfig to the project's kubeconfig directory
# and updates it for multi-cluster use.
#
# Usage: ./scripts/k8s/get-k3s-kubeconfig.sh

set -euo pipefail

# Find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
KUBECONFIG_DIR="${PROJECT_ROOT}/output/cluster-state/kubeconfigs"
K3S_KUBECONFIG="${KUBECONFIG_DIR}/k3s-local.kubeconfig"
K3S_SOURCE="/etc/rancher/k3s/k3s.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check if k3s kubeconfig exists
check_source() {
    if [ ! -f "${K3S_SOURCE}" ]; then
        log_error "k3s kubeconfig not found at ${K3S_SOURCE}"
        log_error "Please ensure k3s is installed and running"
        exit 1
    fi
}

# Export kubeconfig
export_kubeconfig() {
    log_info "Exporting k3s kubeconfig..."

    # Create directory if it doesn't exist
    mkdir -p "${KUBECONFIG_DIR}"

    # Copy kubeconfig
    cp "${K3S_SOURCE}" "${K3S_KUBECONFIG}"

    # Get hostname or IP for server URL
    local server_url
    local hostname

    # Try to get hostname first
    hostname=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")

    # Try to get IP address
    local ip_address
    ip_address=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "")

    # Use IP if available, otherwise use hostname
    if [ -n "${ip_address}" ] && [ "${ip_address}" != "127.0.0.1" ]; then
        server_url="https://${ip_address}:6443"
    else
        server_url="https://${hostname}:6443"
    fi

    # Update server URL in kubeconfig
    # Replace 127.0.0.1 with actual hostname/IP
    sed -i "s|server: https://127.0.0.1:6443|server: ${server_url}|g" "${K3S_KUBECONFIG}"

    # Update context name to be more descriptive
    sed -i "s|default|k3s-local|g" "${K3S_KUBECONFIG}"

    # Set proper permissions
    chmod 600 "${K3S_KUBECONFIG}"

    log_info "Kubeconfig exported to: ${K3S_KUBECONFIG}"
    log_info "Server URL: ${server_url}"
}

# Verify kubeconfig
verify_kubeconfig() {
    log_info "Verifying kubeconfig..."

    if [ ! -f "${K3S_KUBECONFIG}" ]; then
        log_error "Kubeconfig file not found"
        return 1
    fi

    # Check if kubectl can use the config
    if command -v kubectl &> /dev/null; then
        if KUBECONFIG="${K3S_KUBECONFIG}" kubectl cluster-info &> /dev/null; then
            log_info "Kubeconfig is valid and accessible"
            KUBECONFIG="${K3S_KUBECONFIG}" kubectl cluster-info | head -1
            return 0
        else
            log_warn "Kubeconfig exists but cluster may not be accessible"
            return 1
        fi
    else
        log_warn "kubectl not found, skipping verification"
        return 0
    fi
}

# Show usage instructions
show_usage() {
    echo ""
    log_info "To use this kubeconfig:"
    echo "  export KUBECONFIG=${K3S_KUBECONFIG}"
    echo ""
    log_info "Or use the kubeconfig management script:"
    echo "  ./scripts/manage-kubeconfig.sh use k3s-local"
    echo ""
    log_info "Or use Makefile target:"
    echo "  make kubeconfig-use CLUSTER=k3s-local"
}

# Main execution
main() {
    check_source
    export_kubeconfig
    verify_kubeconfig
    show_usage
}

main "$@"
