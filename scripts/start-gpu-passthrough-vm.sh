#!/bin/bash
#
# GPU Passthrough VM Startup Script
# Starts a QEMU VM with the same configuration as hpc-cluster-compute-01
# including GPU PCIe passthrough via VFIO
#
# This script replicates the libvirt XML configuration in direct QEMU commands
# Run with: ./scripts/start-gpu-passthrough-vm.sh
# Serial console will be available in stdout - you can login directly

set -euo pipefail

# =============================================================================
# Configuration Variables
# =============================================================================

# VM Configuration
VM_NAME="hpc-cluster-compute-01"
VM_MEMORY_GB=16
VM_CPUS=8

# Storage Configuration
BASE_DISK_IMAGE="/home/doudalis/Projects/pharos.ai-hyperscaler-on-workskation/build/packer/hpc-base/hpc-base/hpc-base.qcow2"
DISK_FORMAT="qcow2"
# Temporary snapshot file for ephemeral changes
SNAPSHOT_DIR="/tmp/qemu-snapshots"
SNAPSHOT_IMAGE="$SNAPSHOT_DIR/${VM_NAME}-snapshot-$(date +%Y%m%d_%H%M%S).qcow2"

# Network Configuration
SSH_HOST_PORT="2222"  # SSH will be accessible on localhost:2222

# GPU Configuration (from XML: 0000:01:00.0)
GPU_PCI_ADDRESS="0000:01:00.0"
GPU_AUDIO_PCI_ADDRESS="" # "0000:01:00.1"  # Usually audio controller is function 1

# QEMU Paths
QEMU_SYSTEM="/usr/bin/qemu-system-x86_64"

# =============================================================================
# Color Output Functions
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

# =============================================================================
# Basic Checks
# =============================================================================

check_requirements() {
    log_info "Checking basic requirements..."

    # Check for VFIO permissions
    if [[ ! -w "/dev/vfio/vfio" ]]; then
        log_error "Cannot write to /dev/vfio/vfio. VFIO permissions issue."
        log_error "Try running with sudo, or add user to vfio group"
        exit 1
    fi

    # Check for VFIO group permissions (group 18 from the error)
    local gpu_iommu_group
    if [[ -L "/sys/bus/pci/devices/$GPU_PCI_ADDRESS/iommu_group" ]]; then
        gpu_iommu_group=$(basename "$(readlink "/sys/bus/pci/devices/$GPU_PCI_ADDRESS/iommu_group")")
        if [[ ! -w "/dev/vfio/$gpu_iommu_group" ]]; then
            log_error "Cannot write to /dev/vfio/$gpu_iommu_group. VFIO group permissions issue."
            log_error "Try running with sudo: sudo ./scripts/start-gpu-passthrough-vm.sh"
            exit 1
        fi
        log_info "VFIO group $gpu_iommu_group permissions OK"
    fi

    # Check if QEMU is available
    if [[ ! -x "$QEMU_SYSTEM" ]]; then
        log_error "QEMU system emulator not found at $QEMU_SYSTEM"
        log_error "Install with: sudo apt-get install qemu-system-x86"
        exit 1
    fi

    # Check if qemu-img is available for snapshot creation
    if ! command -v qemu-img >/dev/null 2>&1; then
        log_error "qemu-img not found. Required for creating snapshot overlays"
        log_error "Install with: sudo apt-get install qemu-utils"
        exit 1
    fi

    # Check if base disk image exists
    if [[ ! -f "$BASE_DISK_IMAGE" ]]; then
        log_error "Base disk image not found: $BASE_DISK_IMAGE"
        log_error "Please create the disk image first or update BASE_DISK_IMAGE variable"
        exit 1
    fi

    # Check if KVM is available
    if [[ ! -c /dev/kvm ]]; then
        log_error "/dev/kvm device not found. KVM acceleration not available"
        exit 1
    fi

    # Check if user can access KVM
    if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
        log_error "Cannot access /dev/kvm. Make sure you're in the 'kvm' group"
        log_error "Add yourself to kvm group: sudo usermod -aG kvm \$USER"
        exit 1
    fi

    # Check if GPU is bound to vfio-pci (informational only)
    local gpu_driver_path="/sys/bus/pci/devices/$GPU_PCI_ADDRESS/driver"
    if [[ -L "$gpu_driver_path" ]]; then
        local current_driver
        current_driver=$(basename "$(readlink "$gpu_driver_path")")
        if [[ "$current_driver" == "vfio-pci" ]]; then
            log_info "GPU $GPU_PCI_ADDRESS is bound to vfio-pci driver ✓"
        else
            log_warn "GPU $GPU_PCI_ADDRESS is bound to '$current_driver' instead of vfio-pci"
            log_warn "GPU passthrough may not work. Run: sudo ./scripts/gpu-passthrough-setup.sh"
        fi
    else
        log_warn "GPU $GPU_PCI_ADDRESS is not bound to any driver"
        log_warn "GPU passthrough may not work. Run: sudo ./scripts/gpu-passthrough-setup.sh"
    fi

    log_info "Basic requirements check completed"
}

# =============================================================================
# Snapshot Management
# =============================================================================

create_snapshot() {
    log_info "Creating ephemeral snapshot overlay..."

    # Create snapshot directory if it doesn't exist
    mkdir -p "$SNAPSHOT_DIR"

    # Create qcow2 overlay file using the base image as backing file
    if ! qemu-img create -f qcow2 -b "$BASE_DISK_IMAGE" -F qcow2 "$SNAPSHOT_IMAGE"; then
        log_error "Failed to create snapshot overlay: $SNAPSHOT_IMAGE"
        exit 1
    fi

    log_info "Created snapshot: $SNAPSHOT_IMAGE"
    log_info "Original image will remain unmodified: $BASE_DISK_IMAGE"
}

cleanup_snapshot() {
    if [[ -f "$SNAPSHOT_IMAGE" ]]; then
        log_info "Cleaning up snapshot: $SNAPSHOT_IMAGE"
        rm -f "$SNAPSHOT_IMAGE"
    fi
}

# =============================================================================
# QEMU Command Construction
# =============================================================================

build_qemu_command() {
    log_info "Building minimal QEMU command line..." >&2

    local qemu_args=()

    # Basic QEMU setup
    qemu_args+=("$QEMU_SYSTEM")
    qemu_args+=("-name" "$VM_NAME")

    # Minimal machine configuration - no IOMMU device, let host handle it
    qemu_args+=("-machine" "type=q35,accel=kvm")
    qemu_args+=("-cpu" "host")
    qemu_args+=("-smp" "$VM_CPUS")

    # Memory configuration - simple
    qemu_args+=("-m" "${VM_MEMORY_GB}G")

    # Storage configuration - basic
    qemu_args+=("-drive" "file=$SNAPSHOT_IMAGE,format=$DISK_FORMAT,if=virtio")

    # Network configuration - minimal
    qemu_args+=("-netdev" "user,id=net0,hostfwd=tcp::$SSH_HOST_PORT-:22")
    qemu_args+=("-device" "e1000,netdev=net0")
    log_info "Using host networking. SSH available on localhost:$SSH_HOST_PORT" >&2

    # GPU PCIe passthrough - essential only
    qemu_args+=("-device" "vfio-pci,host=$GPU_PCI_ADDRESS")

    # GPU audio passthrough (if available) - minimal
    if [[ -n "$GPU_AUDIO_PCI_ADDRESS" && -d "/sys/bus/pci/devices/$GPU_AUDIO_PCI_ADDRESS" ]]; then
        qemu_args+=("-device" "vfio-pci,host=$GPU_AUDIO_PCI_ADDRESS")
        log_info "GPU audio controller will be passed through" >&2
    fi

    # Console configuration - minimal
    qemu_args+=("-serial" "stdio")
    qemu_args+=("-monitor" "none")
    qemu_args+=("-nographic")

    printf "%s\n" "${qemu_args[@]}"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    # Handle help requests
    if [[ "${1:-}" == "help" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat << EOF
GPU Passthrough VM Startup Script

This script starts a QEMU VM with GPU passthrough using the same configuration
as the libvirt XML for hpc-cluster-compute-01.

Usage: $0

Configuration:
  VM Name:        $VM_NAME
  Memory:         ${VM_MEMORY_GB}G
  CPUs:           $VM_CPUS
  Base Disk:      $BASE_DISK_IMAGE
  GPU PCI:        $GPU_PCI_ADDRESS
  SSH Port:       localhost:$SSH_HOST_PORT

Features:
  - Serial console output to stdout (you can login directly)
  - GPU PCIe passthrough via VFIO
  - KVM acceleration (requires kvm group membership)
  - Host networking with SSH forwarding (no bridge required)
  - Ephemeral changes via snapshot overlay (base image preserved)
  - VFIO permission checking (may require sudo for VFIO access)

Exit: Press Ctrl+A then X to exit QEMU, or Ctrl+C to terminate
Note: Snapshot overlay is automatically cleaned up on exit

Requirements:
  - GPU must be bound to vfio-pci driver (use gpu-passthrough-setup.sh)
  - User must be in 'kvm' group for KVM access
  - Base disk image must exist at specified path
  - qemu-utils package for snapshot creation

EOF
        exit 0
    fi

    echo
    log_info "GPU Passthrough VM: $VM_NAME"
    log_info "Memory: ${VM_MEMORY_GB}G | CPUs: $VM_CPUS | GPU: $GPU_PCI_ADDRESS"
    log_info "Host SSH: localhost:$SSH_HOST_PORT"
    echo

    # Setup cleanup trap for snapshot
    trap cleanup_snapshot EXIT INT TERM

    # Run basic checks
    check_requirements

    # Create ephemeral snapshot for the VM
    create_snapshot

    # Build QEMU command
    local qemu_cmd
    mapfile -t qemu_cmd < <(build_qemu_command)

    # Show command being executed
    log_info "Starting VM with command:"
    printf "  %s \\\\\n" "${qemu_cmd[@]}"
    echo

    log_info "Serial console will appear below. You can login directly."
    log_info "Press Ctrl+A then X to exit QEMU, or Ctrl+C to terminate."
    echo "========================================================================"
    echo

    # Execute QEMU in foreground with serial console
    exec "${qemu_cmd[@]}"
}

# Run main function
main "$@"
