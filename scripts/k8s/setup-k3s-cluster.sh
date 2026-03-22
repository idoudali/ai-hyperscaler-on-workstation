#!/usr/bin/env bash
# Setup k3s cluster with GPU support
#
# This script installs and configures k3s with NVIDIA GPU support.
# It is idempotent and safe to run multiple times.
#
# Prerequisites:
# - NVIDIA driver installed and loaded
# - NVIDIA Container Toolkit installed
# - Root/sudo access
#
# Usage: ./scripts/k8s/setup-k3s-cluster.sh

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

# Check NVIDIA driver
check_nvidia_driver() {
    log_info "Checking NVIDIA driver..."
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "nvidia-smi not found. Please install NVIDIA driver first."
        exit 1
    fi

    if ! nvidia-smi &> /dev/null; then
        log_error "NVIDIA driver is not loaded. Please load the driver first."
        log_warn "Try: sudo modprobe nvidia"
        exit 1
    fi

    local driver_version
    driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
    log_info "NVIDIA driver version: ${driver_version}"

    local gpu_count
    gpu_count=$(nvidia-smi --list-gpus | wc -l)
    log_info "Found ${gpu_count} GPU(s)"
}

# Check NVIDIA Container Toolkit
check_nvidia_container_toolkit() {
    log_info "Checking NVIDIA Container Toolkit..."
    if ! command -v nvidia-container-cli &> /dev/null; then
        log_warn "NVIDIA Container Toolkit not found. Installing..."
        install_nvidia_container_toolkit
    else
        log_info "NVIDIA Container Toolkit is installed"
    fi
}

# Install NVIDIA Container Toolkit
install_nvidia_container_toolkit() {
    log_info "Installing NVIDIA Container Toolkit..."

    # Detect distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        log_error "Cannot detect Linux distribution"
        exit 1
    fi

    case $DISTRO in
        ubuntu|debian)
            # shellcheck disable=SC2034  # Variables used by NVIDIA's setup guide reference
            distribution=$ID
            # shellcheck disable=SC2034
            version=$VERSION_ID
            # Remove any existing broken repository file
            if [ -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]; then
                if grep -q "<!doctype html>" /etc/apt/sources.list.d/nvidia-container-toolkit.list 2>/dev/null; then
                    log_warn "Removing broken repository file from previous failed installation..."
                    rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
                fi
            fi
            # Install prerequisites (following official NVIDIA guide)
            log_info "Installing prerequisites..."
            apt-get update && apt-get install -y --no-install-recommends curl gnupg2
            # Configure the production repository (following official NVIDIA guide)
            log_info "Configuring NVIDIA Container Toolkit repository..."
            curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
            curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
                sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
                tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
            # Update the packages list from the repository
            apt-get update
            # Install the NVIDIA Container Toolkit
            log_info "Installing NVIDIA Container Toolkit..."
            apt-get install -y nvidia-container-toolkit
            ;;
        *)
            log_error "Unsupported distribution: $DISTRO"
            log_warn "Please install NVIDIA Container Toolkit manually"
            exit 1
            ;;
    esac

    # Configure containerd (if it exists)
    if [ -f /etc/containerd/config.toml ]; then
        nvidia-ctk runtime configure --runtime=containerd
        systemctl restart containerd || true
    fi

    log_info "NVIDIA Container Toolkit installed"
}

# CNI configuration paths
CNI_BIN_DIR="/opt/cni/bin"
CNI_CONF_DIR="/etc/cni/net.d"
CNI_VERSION="v1.4.0"
FLANNEL_CNI_VERSION="v1.4.0-flannel1"

# Install CNI plugins
install_cni_plugins() {
    log_info "Checking CNI plugins..."

    # Create CNI directories
    mkdir -p "${CNI_BIN_DIR}"
    mkdir -p "${CNI_CONF_DIR}"

    # Check if CNI plugins are already installed
    if [ -f "${CNI_BIN_DIR}/bridge" ]; then
        log_info "CNI plugins already installed"
    else
        log_info "Installing CNI plugins ${CNI_VERSION}..."

        # Download and install CNI plugins
        local cni_url="https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz"

        log_info "Downloading CNI plugins..."
        if ! curl -L "${cni_url}" | tar -C "${CNI_BIN_DIR}" -xz; then
            log_error "Failed to download CNI plugins"
            exit 1
        fi

        # Verify installation
        if [ ! -f "${CNI_BIN_DIR}/bridge" ]; then
            log_error "Failed to install CNI plugins"
            exit 1
        fi

        log_info "CNI plugins installed: $(find "${CNI_BIN_DIR}" -maxdepth 1 -type f | wc -l) plugins"
    fi

    # Install flannel CNI plugin (not included in standard CNI plugins)
    if [ -f "${CNI_BIN_DIR}/flannel" ]; then
        log_info "Flannel CNI plugin already installed"
    else
        log_info "Installing Flannel CNI plugin ${FLANNEL_CNI_VERSION}..."
        local flannel_url="https://github.com/flannel-io/cni-plugin/releases/download/${FLANNEL_CNI_VERSION}/flannel-amd64"
        if ! curl -L "${flannel_url}" -o "${CNI_BIN_DIR}/flannel"; then
            log_error "Failed to download Flannel CNI plugin"
            exit 1
        fi
        chmod +x "${CNI_BIN_DIR}/flannel"
        log_info "Flannel CNI plugin installed"
    fi
}

# Get kubectl command (k3s provides kubectl at /usr/local/bin/kubectl)
get_kubectl() {
    if command -v kubectl &> /dev/null; then
        echo "kubectl"
    elif [ -f /usr/local/bin/kubectl ]; then
        echo "/usr/local/bin/kubectl"
    elif command -v k3s &> /dev/null; then
        echo "k3s kubectl"
    else
        return 1
    fi
}

# Check if k3s is already installed
# Returns 0 (true) if k3s is installed and we should skip installation
# Returns 1 (false) if k3s is not installed or user wants to reinstall
check_k3s_installed() {
    # Check if k3s binary exists
    if [ -f /usr/local/bin/k3s ] || command -v k3s &> /dev/null; then
        # Check if k3s service exists and is running
        if systemctl list-unit-files | grep -q "^k3s.service" && systemctl is-active --quiet k3s 2>/dev/null; then
            log_warn "k3s appears to be already installed and running"
            read -p "Do you want to reinstall? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Skipping k3s installation"
                return 0  # Return true = skip installation
            fi
            return 1  # Return false = proceed with installation (reinstall)
        elif [ -f /etc/rancher/k3s/k3s.yaml ]; then
            log_warn "k3s appears to be installed but not running"
            read -p "Do you want to reinstall? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Skipping k3s installation"
                return 0  # Return true = skip installation
            fi
            return 1  # Return false = proceed with installation (reinstall)
        fi
    fi
    # k3s is not installed, return false to proceed with installation
    return 1
}

# Install k3s
install_k3s() {
    log_info "Installing k3s..."

    # Download and install k3s (following official k3s installation guide)
    # --disable=traefik: Disable the default ingress controller
    # --container-runtime-endpoint: Use containerd that we've configured for NVIDIA
    # --write-kubeconfig-mode: Make kubeconfig readable by non-root users
    # --flannel-cni-conf: Tell flannel where to write its CNI config
    # Note: CNI paths are configured in containerd config, not kubelet args (deprecated in k8s 1.24+)
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik --container-runtime-endpoint=unix:///run/containerd/containerd.sock --write-kubeconfig-mode=644 --flannel-cni-conf=${CNI_CONF_DIR}/10-flannel.conflist" sh -

    # Ensure /usr/local/bin is in PATH for kubectl
    export PATH="/usr/local/bin:${PATH}"

    # Wait for k3s service to be active
    log_info "Waiting for k3s service to start..."
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if systemctl is-active --quiet k3s 2>/dev/null; then
            log_info "k3s service is active"
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    if [ $attempt -eq $max_attempts ]; then
        log_error "k3s service failed to start"
        systemctl status k3s || true
        exit 1
    fi

    # Wait for k3s API to be ready and kubectl to work
    log_info "Waiting for k3s API to be ready..."
    attempt=0
    local kubectl_cmd
    kubectl_cmd=$(get_kubectl) || {
        log_error "kubectl not found after k3s installation"
        exit 1
    }

    while [ $attempt -lt $max_attempts ]; do
        if KUBECONFIG=/etc/rancher/k3s/k3s.yaml "${kubectl_cmd}" get nodes &> /dev/null; then
            log_info "k3s is ready"
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    if [ $attempt -eq $max_attempts ]; then
        log_error "k3s API failed to become ready"
        KUBECONFIG=/etc/rancher/k3s/k3s.yaml "${kubectl_cmd}" get nodes || true
        exit 1
    fi
}

# Configure containerd for NVIDIA runtime and CNI
configure_containerd() {
    log_info "Configuring containerd for NVIDIA runtime and CNI..."

    local containerd_config="/etc/containerd/config.toml"

    # Create containerd config directory if it doesn't exist
    mkdir -p /etc/containerd

    # Backup existing config if it exists
    if [ -f "${containerd_config}" ]; then
        cp "${containerd_config}" "${containerd_config}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backed up existing containerd config"
    fi

    # Generate fresh default config (ensures all required sections exist)
    log_info "Generating containerd configuration..."
    containerd config default > "${containerd_config}"

    # Ensure CNI paths are set correctly in the config
    # The default config may have different paths, so we explicitly set them
    log_info "Configuring CNI paths in containerd..."
    if grep -q '\[plugins\."io\.containerd\.grpc\.v1\.cri"\.cni\]' "${containerd_config}"; then
        # Update bin_dir
        sed -i "s|bin_dir = \".*\"|bin_dir = \"${CNI_BIN_DIR}\"|g" "${containerd_config}"
        # Update conf_dir
        sed -i "s|conf_dir = \".*\"|conf_dir = \"${CNI_CONF_DIR}\"|g" "${containerd_config}"
        log_info "CNI paths configured: bin_dir=${CNI_BIN_DIR}, conf_dir=${CNI_CONF_DIR}"
    else
        log_warn "CNI section not found in containerd config, paths may use defaults"
    fi

    # Configure NVIDIA runtime and set as default
    log_info "Configuring NVIDIA runtime..."
    nvidia-ctk runtime configure --runtime=containerd --set-as-default

    # Enable and restart containerd
    systemctl enable containerd 2>/dev/null || true
    systemctl restart containerd

    # Wait for containerd to be ready
    log_info "Waiting for containerd to be ready..."
    local max_attempts=15
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if systemctl is-active --quiet containerd; then
            log_info "containerd is running"
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    if [ $attempt -eq $max_attempts ]; then
        log_error "containerd failed to start"
        systemctl status containerd --no-pager || true
        exit 1
    fi

    # Verify containerd CRI is responding
    if command -v crictl &> /dev/null; then
        if crictl --runtime-endpoint unix:///run/containerd/containerd.sock info &>/dev/null; then
            log_info "containerd CRI is responding"
        else
            log_warn "crictl check failed (may be okay if crictl not configured)"
        fi
    fi

    # Restart k3s to pick up containerd changes (if k3s is installed and running)
    if systemctl list-unit-files | grep -q "^k3s.service" && systemctl is-active --quiet k3s 2>/dev/null; then
        log_info "Restarting k3s to pick up containerd changes..."
        systemctl restart k3s || true
        sleep 5
    fi

    log_info "containerd configured for NVIDIA runtime and CNI"
}

# Deploy NVIDIA device plugin
deploy_nvidia_device_plugin() {
    log_info "Deploying NVIDIA device plugin..."

    # Get kubectl command
    local kubectl_cmd
    kubectl_cmd=$(get_kubectl) || {
        log_error "kubectl not found. k3s may not be properly installed."
        exit 1
    }

    # Set KUBECONFIG if k3s.yaml exists
    if [ -f /etc/rancher/k3s/k3s.yaml ]; then
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    fi

    # Wait for k3s to be ready
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if "${kubectl_cmd}" get nodes &> /dev/null; then
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    if [ $attempt -eq $max_attempts ]; then
        log_error "k3s API is not ready"
        exit 1
    fi

    # Apply NVIDIA device plugin manifest
    if [ -f "${PROJECT_ROOT}/k8s-manifests/gpu-support/nvidia-device-plugin.yaml" ]; then
        "${kubectl_cmd}" apply -f "${PROJECT_ROOT}/k8s-manifests/gpu-support/nvidia-device-plugin.yaml"
    else
        log_warn "NVIDIA device plugin manifest not found, deploying from upstream..."
        "${kubectl_cmd}" apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml
    fi

    # Wait for device plugin to be ready
    log_info "Waiting for NVIDIA device plugin to be ready..."
    "${kubectl_cmd}" wait --for=condition=ready pod -l name=nvidia-device-plugin-ds -n kube-system --timeout=120s || {
        log_warn "Device plugin may not be ready yet"
    }

    log_info "NVIDIA device plugin deployed"
}

# Deploy local-path-provisioner
deploy_local_path_provisioner() {
    log_info "Deploying local-path-provisioner..."

    # Get kubectl command
    local kubectl_cmd
    kubectl_cmd=$(get_kubectl) || {
        log_error "kubectl not found. k3s may not be properly installed."
        exit 1
    }

    # Set KUBECONFIG if k3s.yaml exists
    if [ -f /etc/rancher/k3s/k3s.yaml ]; then
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    fi

    if [ -f "${PROJECT_ROOT}/k8s-manifests/storage/local-path-provisioner.yaml" ]; then
        "${kubectl_cmd}" apply -f "${PROJECT_ROOT}/k8s-manifests/storage/local-path-provisioner.yaml"
    else
        log_warn "local-path-provisioner manifest not found, deploying from upstream..."
        "${kubectl_cmd}" apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
    fi

    log_info "local-path-provisioner deployed"
}

# Export kubeconfig
export_kubeconfig() {
    log_info "Exporting kubeconfig..."

    mkdir -p "${KUBECONFIG_DIR}"

    # Copy k3s kubeconfig
    if [ -f /etc/rancher/k3s/k3s.yaml ]; then
        cp /etc/rancher/k3s/k3s.yaml "${K3S_KUBECONFIG}"

        # Update server URL to use hostname instead of 127.0.0.1
        local hostname
        hostname=$(hostname -f 2>/dev/null || hostname)
        sed -i "s|server: https://127.0.0.1:6443|server: https://${hostname}:6443|g" "${K3S_KUBECONFIG}"

        # Set proper permissions and ownership
        chmod 600 "${K3S_KUBECONFIG}"
        # Try to change ownership to the user running the script (if not root)
        if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
            chown "${SUDO_USER}:${SUDO_USER}" "${K3S_KUBECONFIG}" 2>/dev/null || true
        elif [ "$EUID" -ne 0 ]; then
            chown "$(id -u):$(id -g)" "${K3S_KUBECONFIG}" 2>/dev/null || true
        fi

        log_info "Kubeconfig exported to ${K3S_KUBECONFIG}"
    else
        log_error "k3s kubeconfig not found at /etc/rancher/k3s/k3s.yaml"
        exit 1
    fi
}

# Verify GPU availability
verify_gpu() {
    log_info "Verifying GPU availability..."

    # Get kubectl command
    local kubectl_cmd
    kubectl_cmd=$(get_kubectl) || {
        log_warn "kubectl not found, skipping GPU verification"
        return 0
    }

    # Set KUBECONFIG if k3s.yaml exists
    if [ -f /etc/rancher/k3s/k3s.yaml ]; then
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    fi

    # Wait a bit for device plugin to register
    sleep 5

    # Check if GPUs are visible to Kubernetes
    if "${kubectl_cmd}" get nodes -o json 2>/dev/null | jq -e '.items[0].status.capacity."nvidia.com/gpu"' &> /dev/null; then
        local gpu_count
        gpu_count=$("${kubectl_cmd}" get nodes -o json 2>/dev/null | jq -r '.items[0].status.capacity."nvidia.com/gpu"')
        log_info "GPU(s) detected by Kubernetes: ${gpu_count}"
    else
        log_warn "GPUs not yet visible to Kubernetes (may take a moment)"
    fi
}

# Ensure CNI config is visible to containerd
# k3s writes flannel config to its own directory, but external containerd looks in /etc/cni/net.d
setup_cni_config_symlinks() {
    log_info "Setting up CNI configuration symlinks..."

    local k3s_cni_dir="/var/lib/rancher/k3s/agent/etc/cni/net.d"
    local flannel_config="${k3s_cni_dir}/10-flannel.conflist"

    # Wait for k3s to create the flannel config
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if [ -f "${flannel_config}" ]; then
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    if [ ! -f "${flannel_config}" ]; then
        log_warn "Flannel config not found at ${flannel_config}"
        return 1
    fi

    # Create symlink if it doesn't exist
    mkdir -p "${CNI_CONF_DIR}"
    if [ ! -L "${CNI_CONF_DIR}/10-flannel.conflist" ]; then
        ln -sf "${flannel_config}" "${CNI_CONF_DIR}/10-flannel.conflist"
        log_info "Created symlink: ${CNI_CONF_DIR}/10-flannel.conflist -> ${flannel_config}"

        # Restart k3s to pick up the CNI config
        log_info "Restarting k3s to pick up CNI configuration..."
        systemctl restart k3s
        sleep 5
    else
        log_info "CNI config symlink already exists"
    fi

    return 0
}

# Wait for node to become Ready
wait_for_node_ready() {
    log_info "Waiting for node to become Ready..."

    local kubectl_cmd
    kubectl_cmd=$(get_kubectl) || {
        log_warn "kubectl not found, skipping node readiness check"
        return 0
    }

    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

    local max_attempts=60
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        local status
        status=$("${kubectl_cmd}" get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        if [ "$status" = "True" ]; then
            log_info "Node is Ready!"
            return 0
        fi
        echo -n "."
        attempt=$((attempt + 1))
        sleep 2
    done
    echo ""

    # Node not ready - check why
    log_warn "Node is not Ready after ${max_attempts} attempts"
    log_warn "Checking node conditions..."
    "${kubectl_cmd}" describe nodes | grep -A 10 "Conditions:" || true

    return 1
}

# Main execution
main() {
    log_info "Starting k3s cluster setup with GPU support..."

    check_root
    check_nvidia_driver
    check_nvidia_container_toolkit

    # IMPORTANT: Install CNI plugins and configure containerd BEFORE k3s
    # k3s uses external containerd, so containerd must be ready with CNI configured
    install_cni_plugins
    configure_containerd

    if check_k3s_installed; then
        log_info "k3s is already installed, skipping installation"
        # Still restart k3s to pick up any containerd changes
        if systemctl is-active --quiet k3s 2>/dev/null; then
            log_info "Restarting k3s to ensure containerd changes are applied..."
            systemctl restart k3s
            sleep 5
        fi
    else
        install_k3s
    fi

    # Setup CNI config symlinks for external containerd compatibility
    setup_cni_config_symlinks

    # Wait for node to be Ready before deploying workloads
    if ! wait_for_node_ready; then
        log_error "Node failed to become Ready. Check CNI and containerd configuration."
        log_info "Debug commands:"
        log_info "  journalctl -u k3s -f"
        log_info "  journalctl -u containerd -f"
        log_info "  kubectl describe node"
        exit 1
    fi

    deploy_nvidia_device_plugin
    deploy_local_path_provisioner
    export_kubeconfig
    verify_gpu

    log_info "k3s cluster setup complete!"
    log_info "Kubeconfig location: ${K3S_KUBECONFIG}"
    log_info "To use this cluster:"
    log_info "  export KUBECONFIG=${K3S_KUBECONFIG}"
    log_info "Or use: make kubeconfig-use CLUSTER=k3s-local"
}

main "$@"
