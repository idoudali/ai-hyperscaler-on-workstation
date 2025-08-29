#!/bin/bash
#
# Simplified GPU Passthrough VM Script
# Minimal configuration for PCIe GPU passthrough with QEMU snapshot protection
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

VM_NAME="hpc-cluster-compute-01"
VM_MEMORY_GB=16
VM_CPUS=8
BASE_DISK_IMAGE="/home/doudalis/Projects/pharos.ai-hyperscaler-on-workskation/build/packer/hpc-base/hpc-base/hpc-base.qcow2"
GPU_PCI_ADDRESS="0000:01:00.0"
GPU_AUDIO_PCI_ADDRESS="0000:01:00.1"
SSH_HOST_PORT="2222"
QEMU_SYSTEM="/usr/bin/qemu-system-x86_64"

# =============================================================================
# Basic Checks
# =============================================================================

# Check if base disk exists
if [[ ! -f "$BASE_DISK_IMAGE" ]]; then
    echo "ERROR: Base disk image not found: $BASE_DISK_IMAGE"
    exit 1
fi

# Check if QEMU exists
if [[ ! -x "$QEMU_SYSTEM" ]]; then
    echo "ERROR: QEMU not found at $QEMU_SYSTEM"
    echo "Install with: sudo apt-get install qemu-system-x86"
    exit 1
fi

# Check KVM access
if [[ ! -c /dev/kvm ]]; then
    echo "ERROR: /dev/kvm not found"
    exit 1
fi

# Check GPU is bound to vfio-pci
gpu_driver_path="/sys/bus/pci/devices/$GPU_PCI_ADDRESS/driver"
if [[ -L "$gpu_driver_path" ]]; then
    current_driver=$(basename "$(readlink "$gpu_driver_path")")
    if [[ "$current_driver" != "vfio-pci" ]]; then
        echo "WARNING: GPU $GPU_PCI_ADDRESS is bound to '$current_driver' instead of vfio-pci"
        echo "GPU passthrough may not work"
    fi
else
    echo "WARNING: GPU $GPU_PCI_ADDRESS is not bound to any driver"
fi

# =============================================================================
# Start VM
# =============================================================================

echo "Starting GPU Passthrough VM..."
echo "Memory: ${VM_MEMORY_GB}G | CPUs: $VM_CPUS | GPU: $GPU_PCI_ADDRESS"
echo "SSH available on localhost:$SSH_HOST_PORT"
echo "Press Ctrl+A then X to exit QEMU"
echo "Note: QEMU will automatically create a snapshot to protect the base image"
echo

set -x

"$QEMU_SYSTEM" \
    -name "$VM_NAME" \
    -drive "file=$BASE_DISK_IMAGE,format=qcow2,if=virtio,snapshot=on" \
    -machine type=q35,accel=kvm \
    -cpu host,host-phys-bits=on,host-phys-bits-limit=39 \
    -smp "$VM_CPUS" \
    -m "${VM_MEMORY_GB}G" \
    -object memory-backend-memfd,id=ram,size="${VM_MEMORY_GB}G",share=on \
    -machine memory-backend=ram \
    -netdev "user,id=net0,hostfwd=tcp::$SSH_HOST_PORT-:22" \
    -device "virtio-net-pci,netdev=net0" \
    -device "vfio-pci,host=$GPU_PCI_ADDRESS,multifunction=on" \
    -device "vfio-pci,host=$GPU_AUDIO_PCI_ADDRESS" \
    -nographic -serial mon:stdio
