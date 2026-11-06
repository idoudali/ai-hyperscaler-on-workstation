#!/usr/bin/env bash
# Teardown k3s cluster
#
# This script cleanly uninstalls k3s and removes configurations.
#
# Usage: ./scripts/k8s/teardown-k3s-cluster.sh

set -euo pipefail

# Find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
KUBECONFIG_DIR="${PROJECT_ROOT}/output/cluster-state/kubeconfigs"
K3S_KUBECONFIG="${KUBECONFIG_DIR}/k3s-local.kubeconfig"

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

# Check if running as root or with sudo
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check if k3s is installed
check_k3s_installed() {
    if ! command -v k3s &> /dev/null && ! systemctl is-active --quiet k3s 2>/dev/null; then
        log_warn "k3s does not appear to be installed"
        return 1
    fi
    return 0
}

# Uninstall k3s
uninstall_k3s() {
    log_info "Uninstalling k3s..."

    # Stop k3s service
    if systemctl is-active --quiet k3s 2>/dev/null; then
        log_info "Stopping k3s service..."
        systemctl stop k3s || true
    fi

    # Run k3s uninstall script if it exists
    if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
        log_info "Running k3s uninstall script..."
        /usr/local/bin/k3s-uninstall.sh || true
    else
        log_warn "k3s uninstall script not found, attempting manual cleanup..."

        # Manual cleanup
        systemctl disable k3s || true
        rm -f /etc/systemd/system/k3s.service
        systemctl daemon-reload
        rm -rf /var/lib/rancher/k3s
        rm -rf /etc/rancher/k3s
        rm -f /usr/local/bin/k3s
        rm -f /usr/local/bin/k3s-killall.sh
        rm -f /usr/local/bin/k3s-uninstall.sh
    fi

    log_info "k3s uninstalled"
}

# Clean up kubeconfig
cleanup_kubeconfig() {
    log_info "Cleaning up kubeconfig..."

    if [ -f "${K3S_KUBECONFIG}" ]; then
        rm -f "${K3S_KUBECONFIG}"
        log_info "Removed kubeconfig: ${K3S_KUBECONFIG}"
    else
        log_info "Kubeconfig not found, skipping cleanup"
    fi
}

# Clean up storage directories (optional)
cleanup_storage() {
    read -p "Do you want to remove k3s storage directories? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Removing k3s storage directories..."
        rm -rf /var/lib/rancher/k3s || true
        log_info "Storage directories removed"
    else
        log_info "Keeping storage directories"
    fi
}

# Main execution
main() {
    log_info "Starting k3s cluster teardown..."

    check_root

    if ! check_k3s_installed; then
        log_warn "k3s is not installed, nothing to teardown"
        cleanup_kubeconfig
        exit 0
    fi

    uninstall_k3s
    cleanup_kubeconfig
    cleanup_storage

    log_info "k3s cluster teardown complete!"
}

main "$@"
