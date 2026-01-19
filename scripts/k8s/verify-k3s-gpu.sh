#!/usr/bin/env bash
# Verify k3s cluster health and GPU availability
#
# This script verifies that k3s is running correctly and GPUs are available.
#
# Usage: ./scripts/k8s/verify-k3s-gpu.sh

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

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_fail() {
    echo -e "${RED}✗${NC} $*"
}

# Check if k3s is running
check_k3s_running() {
    log_info "Checking if k3s is running..."
    if systemctl is-active --quiet k3s 2>/dev/null; then
        log_success "k3s service is running"
        return 0
    else
        log_fail "k3s service is not running"
        return 1
    fi
}

# Get kubectl command with proper permissions
get_kubectl_cmd() {
    # Try k3s kubectl first (has built-in permissions)
    if command -v k3s &> /dev/null; then
        echo "k3s kubectl"
        return 0
    fi

    # Setup kubeconfig for regular kubectl
    if [ -f "${K3S_KUBECONFIG}" ] && [ -r "${K3S_KUBECONFIG}" ]; then
        export KUBECONFIG="${K3S_KUBECONFIG}"
    elif [ -f /etc/rancher/k3s/k3s.yaml ] && [ -r /etc/rancher/k3s/k3s.yaml ]; then
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    fi

    # Try regular kubectl
    if command -v kubectl &> /dev/null; then
        echo "kubectl"
        return 0
    elif [ -f /usr/local/bin/kubectl ]; then
        echo "/usr/local/bin/kubectl"
        return 0
    fi

    return 1
}

# Check kubectl access
check_kubectl() {
    log_info "Checking kubectl access..."

    # Get kubectl command
    local kubectl_cmd
    if ! kubectl_cmd=$(get_kubectl_cmd); then
        log_fail "kubectl not found"
        return 1
    fi

    # Export kubeconfig for the command if using regular kubectl
    if [[ ! "$kubectl_cmd" =~ "k3s kubectl" ]]; then
        if [ -f "${K3S_KUBECONFIG}" ] && [ -r "${K3S_KUBECONFIG}" ]; then
            export KUBECONFIG="${K3S_KUBECONFIG}"
        elif [ -f /etc/rancher/k3s/k3s.yaml ] && [ -r /etc/rancher/k3s/k3s.yaml ]; then
            export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        fi
    fi

    if ${kubectl_cmd} cluster-info &> /dev/null; then
        log_success "kubectl can access cluster"
        ${kubectl_cmd} cluster-info | head -1
        return 0
    else
        log_fail "kubectl cannot access cluster"
        # Try to show the error
        ${kubectl_cmd} cluster-info 2>&1 | head -3 || true
        log_warn "Try running: sudo cp /etc/rancher/k3s/k3s.yaml ${K3S_KUBECONFIG} && sudo chown \$(id -u):\$(id -g) ${K3S_KUBECONFIG}"
        return 1
    fi
}

# Check nodes
check_nodes() {
    log_info "Checking cluster nodes..."

    # Get kubectl command
    local kubectl_cmd
    if ! kubectl_cmd=$(get_kubectl_cmd); then
        log_fail "kubectl not found"
        return 1
    fi

    # Export kubeconfig if using regular kubectl
    if [[ ! "$kubectl_cmd" =~ "k3s kubectl" ]]; then
        if [ -f "${K3S_KUBECONFIG}" ] && [ -r "${K3S_KUBECONFIG}" ]; then
            export KUBECONFIG="${K3S_KUBECONFIG}"
        elif [ -f /etc/rancher/k3s/k3s.yaml ] && [ -r /etc/rancher/k3s/k3s.yaml ]; then
            export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        fi
    fi

    local node_count
    node_count=$(${kubectl_cmd} get nodes --no-headers 2>/dev/null | wc -l | tr -d '[:space:]' || echo "0")
    node_count=$((node_count))  # Convert to integer, removing any whitespace

    if [ "$node_count" -eq 0 ]; then
        log_fail "No nodes found in cluster"
        return 1
    fi

    log_success "Found ${node_count} node(s)"

    # Show node status
    echo ""
    ${kubectl_cmd} get nodes

    # Check if nodes are ready
    local ready_count
    ready_count=$(${kubectl_cmd} get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
    ready_count=$(echo "$ready_count" | tr -d '[:space:]')  # Remove all whitespace
    ready_count=${ready_count:-0}  # Default to 0 if empty
    ready_count=$((ready_count))  # Convert to integer

    if [ "$ready_count" -eq "$node_count" ]; then
        log_success "All nodes are Ready"
    else
        log_warn "Only ${ready_count}/${node_count} nodes are Ready"
    fi
}

# Check GPU availability
check_gpu() {
    log_info "Checking GPU availability..."

    # Get kubectl command
    local kubectl_cmd
    if ! kubectl_cmd=$(get_kubectl_cmd); then
        log_fail "kubectl not found"
        return 1
    fi

    # Export kubeconfig if using regular kubectl
    if [[ ! "$kubectl_cmd" =~ "k3s kubectl" ]]; then
        if [ -f "${K3S_KUBECONFIG}" ] && [ -r "${K3S_KUBECONFIG}" ]; then
            export KUBECONFIG="${K3S_KUBECONFIG}"
        elif [ -f /etc/rancher/k3s/k3s.yaml ] && [ -r /etc/rancher/k3s/k3s.yaml ]; then
            export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        fi
    fi

    # Check if NVIDIA device plugin is running
    local plugin_pods
    plugin_pods=$(${kubectl_cmd} get pods -n kube-system -l name=nvidia-device-plugin-ds --no-headers 2>/dev/null | wc -l | tr -d '[:space:]' || echo "0")
    plugin_pods=$((plugin_pods))  # Convert to integer

    if [ "$plugin_pods" -eq 0 ]; then
        log_fail "NVIDIA device plugin not found"
        return 1
    fi

    log_success "NVIDIA device plugin is running (${plugin_pods} pod(s))"

    # Check if GPUs are visible to Kubernetes
    if ${kubectl_cmd} get nodes -o json 2>/dev/null | jq -e '.items[0].status.capacity."nvidia.com/gpu"' &> /dev/null; then
        local gpu_count
        gpu_count=$(${kubectl_cmd} get nodes -o json | jq -r '.items[0].status.capacity."nvidia.com/gpu"')
        log_success "GPU(s) detected by Kubernetes: ${gpu_count}"

        # Show node GPU capacity
        echo ""
        ${kubectl_cmd} get nodes -o custom-columns=NAME:.metadata.name,GPUS:.status.capacity.'nvidia\.com/gpu'
    else
        log_warn "GPUs not yet visible to Kubernetes"
        log_warn "This may take a few moments after device plugin deployment"
    fi
}

# Check storage provisioner
check_storage() {
    log_info "Checking storage provisioner..."

    # Get kubectl command
    local kubectl_cmd
    if ! kubectl_cmd=$(get_kubectl_cmd); then
        log_warn "kubectl not found, skipping storage check"
        return 0
    fi

    # Export kubeconfig if using regular kubectl
    if [[ ! "$kubectl_cmd" =~ "k3s kubectl" ]]; then
        if [ -f "${K3S_KUBECONFIG}" ] && [ -r "${K3S_KUBECONFIG}" ]; then
            export KUBECONFIG="${K3S_KUBECONFIG}"
        elif [ -f /etc/rancher/k3s/k3s.yaml ] && [ -r /etc/rancher/k3s/k3s.yaml ]; then
            export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        fi
    fi

    # Check for local-path-provisioner
    local provisioner_pods
    provisioner_pods=$(${kubectl_cmd} get pods -n local-path-storage --no-headers 2>/dev/null | wc -l | tr -d '[:space:]' || echo "0")
    provisioner_pods=$((provisioner_pods))  # Convert to integer

    if [ "$provisioner_pods" -gt 0 ]; then
        log_success "local-path-provisioner is running (${provisioner_pods} pod(s))"

        # Check storage classes
        local storage_classes
        storage_classes=$(${kubectl_cmd} get storageclass --no-headers 2>/dev/null | wc -l | tr -d '[:space:]' || echo "0")
        storage_classes=$((storage_classes))  # Convert to integer
        if [ "$storage_classes" -gt 0 ]; then
            echo ""
            ${kubectl_cmd} get storageclass
        fi
    else
        log_warn "local-path-provisioner not found"
    fi
}

# Check system pods
check_system_pods() {
    log_info "Checking system pods..."

    # Get kubectl command
    local kubectl_cmd
    if ! kubectl_cmd=$(get_kubectl_cmd); then
        log_warn "kubectl not found, skipping system pods check"
        return 0
    fi

    # Export kubeconfig if using regular kubectl
    if [[ ! "$kubectl_cmd" =~ "k3s kubectl" ]]; then
        if [ -f "${K3S_KUBECONFIG}" ] && [ -r "${K3S_KUBECONFIG}" ]; then
            export KUBECONFIG="${K3S_KUBECONFIG}"
        elif [ -f /etc/rancher/k3s/k3s.yaml ] && [ -r /etc/rancher/k3s/k3s.yaml ]; then
            export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        fi
    fi

    local total_pods
    total_pods=$(${kubectl_cmd} get pods -n kube-system --no-headers 2>/dev/null | wc -l | tr -d '[:space:]' || echo "0")
    total_pods=$((total_pods))  # Convert to integer

    if [ "$total_pods" -eq 0 ]; then
        log_warn "No system pods found"
        return 1
    fi

    local running_pods
    running_pods=$(${kubectl_cmd} get pods -n kube-system --no-headers 2>/dev/null | grep -c " Running " || echo "0")
    running_pods=$(echo "$running_pods" | tr -d '[:space:]')  # Remove all whitespace
    running_pods=${running_pods:-0}  # Default to 0 if empty
    running_pods=$((running_pods))  # Convert to integer

    log_info "System pods: ${running_pods}/${total_pods} running"

    # Show pods with issues
    local pending_pods
    pending_pods=$(${kubectl_cmd} get pods -n kube-system --no-headers 2>/dev/null | grep -c " Pending " || echo "0")
    pending_pods=$(echo "$pending_pods" | tr -d '[:space:]')  # Remove all whitespace
    pending_pods=${pending_pods:-0}  # Default to 0 if empty
    pending_pods=$((pending_pods))  # Convert to integer
    if [ "$pending_pods" -gt 0 ]; then
        log_warn "Found ${pending_pods} pending pod(s)"
        ${kubectl_cmd} get pods -n kube-system | grep -E "Pending|Error|CrashLoop" || true
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "K3s Cluster Verification"
    echo "=========================================="
    echo ""

    local failed=0

    check_k3s_running || failed=$((failed + 1))
    echo ""

    check_kubectl || failed=$((failed + 1))
    echo ""

    check_nodes || failed=$((failed + 1))
    echo ""

    check_gpu || failed=$((failed + 1))
    echo ""

    check_storage || failed=$((failed + 1))
    echo ""

    check_system_pods || failed=$((failed + 1))
    echo ""

    echo "=========================================="
    if [ $failed -eq 0 ]; then
        log_success "All checks passed!"
    else
        log_warn "Some checks failed (${failed} issue(s))"
    fi
    echo "=========================================="
}

main "$@"
