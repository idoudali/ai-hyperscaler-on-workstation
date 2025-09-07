#!/bin/bash
#
# GPU Passthrough VM Script with Comprehensive Documentation
#
# This script demonstrates PCIe GPU passthrough to a QEMU VM with detailed
# explanations of all QEMU arguments and modern GPU considerations.
#
# =============================================================================
# QEMU ARGUMENT REFERENCE
# =============================================================================
#
# CORE QEMU ARGUMENTS USED IN THIS SCRIPT:
#
# -name <name>                    : Sets the VM name (appears in QEMU monitor)
# -drive <options>                : Configures storage devices
#   file=<path>                   : Path to disk image file
#   format=<type>                 : Disk image format (qcow2, raw, etc.)
#   if=<interface>                : Interface type (virtio, ide, scsi, etc.)
#   snapshot=on                   : Creates temporary overlay, protects base image
#
# -machine <type>,<options>       : Specifies machine type and acceleration
#   type=q35                      : Modern PCIe-based machine (replaces i440fx)
#   accel=kvm                     : Enables KVM hardware acceleration
#
# -cpu <options>                  : CPU configuration
#   host                         : Use host CPU features
#   host-phys-bits=on            : Enable host physical address bits
#   host-phys-bits-limit=39      : Limit to 39-bit physical addresses (512GB)
#
# -smp <count>                    : Number of virtual CPUs
# -m <size>                       : Memory size (G for gigabytes)
#
# -object <type>,<options>        : Creates QEMU objects
#   memory-backend-memfd          : Memory backend using memfd
#   id=ram                        : Unique identifier for this object
#   size=<size>                   : Memory size
#   share=on                      : Enable memory sharing with host
#
# -machine memory-backend=<id>    : Associates memory backend with machine
#
# -netdev <type>,<options>        : Network backend configuration
#   user                         : User-mode networking (NAT)
#   id=<name>                    : Unique identifier for this network
#   hostfwd=<host_port>-:<guest_port> : Port forwarding
#
# -device <type>,<options>        : Adds hardware devices to VM
#   virtio-net-pci               : VirtIO network adapter
#   vfio-pci                     : VFIO PCI device for passthrough
#     host=<pci_address>         : Host PCI device to pass through
#     multifunction=on            : Enable multifunction device support
#
# -nographic                      : Disable graphical output, use console
# -serial <backend>               : Serial port configuration
#   mon:stdio                    : Connect serial to QEMU monitor on stdio
#
# =============================================================================
# MODERN GPU CONSIDERATIONS
# =============================================================================
#
# RESIZABLE BAR (ReBAR) SUPPORT:
# Modern GPUs like RTX 4060 support Resizable BAR, which allows the GPU to
# access more system memory directly. This can improve performance but requires
# proper configuration in both host and VM.
#
# GPU MEMORY REQUIREMENTS:
# - RTX 4060: 8GB VRAM + potential ReBAR access to system memory
# - VM Memory: 16GB minimum recommended for GPU workloads
# - Host Memory: Should have sufficient free memory for VM + GPU requirements
#
# REBAR CONFIGURATION:
# - Host BIOS: Enable "Above 4G Decoding" and "Re-Size BAR Support"
# - Kernel: May need iommu=pt or iommu=on parameters
# - VM: Use host-phys-bits-limit=39 for 512GB address space support
#
# =============================================================================
# GPU PASSTHROUGH CONFIGURATION
# =============================================================================
#
# GPU passthrough can be enabled or disabled using the ENABLE_GPU_PASSTHROUGH
# environment variable:
#
# ENABLE_GPU_PASSTHROUGH=true   : Enable GPU passthrough (default)
# ENABLE_GPU_PASSTHROUGH=false  : Disable GPU passthrough
#
# When disabled, the VM will start without GPU devices, useful for:
# - Testing without GPU hardware
# - Development environments
# - Systems without proper VFIO setup
#
# =============================================================================
# VFIO AND IOMMU REQUIREMENTS (GPU Passthrough Only)
# =============================================================================
#
# HOST SYSTEM REQUIREMENTS (when ENABLE_GPU_PASSTHROUGH=true):
# 1. IOMMU enabled in BIOS/UEFI (Intel VT-d or AMD IOMMU)
# 2. Kernel parameters: intel_iommu=on iommu=pt (Intel) or amd_iommu=on (AMD)
# 3. VFIO modules loaded: vfio, vfio_iommu_type1, vfio_pci
# 4. GPU bound to vfio-pci driver
# 5. User in vfio and kvm groups
#
# COMMON ISSUES AND SOLUTIONS:
# - VFIO DMA mapping errors: Usually indicate insufficient hugepages or IOMMU issues
# - GPU not detected: Check IOMMU groups and device binding
# - Performance issues: Verify ReBAR settings and memory allocation
#
# =============================================================================
# PERFORMANCE OPTIMIZATION
# =============================================================================
#
# MEMORY CONFIGURATION:
# - Use memory-backend-memfd for better performance
# - Enable memory sharing with share=on
# - Consider hugepages for large memory VMs
#
# CPU OPTIMIZATION:
# - host-phys-bits=on for better memory addressing
# - host-phys-bits-limit=39 for modern systems
# - Use host CPU features for maximum performance
#
# STORAGE OPTIMIZATION:
# - VirtIO interface for best performance
# - snapshot=on for protection without performance loss
#
# =============================================================================
# USAGE EXAMPLES
# =============================================================================
#
# BASIC USAGE (with GPU passthrough enabled by default):
#   ./start-test-vm.sh
#
# DISABLE GPU PASSTHROUGH:
#   ENABLE_GPU_PASSTHROUGH=false ./start-test-vm.sh
#
# WITH CUSTOM CONFIGURATION:
#   VM_MEMORY_GB=32 VM_CPUS=16 ./start-test-vm.sh
#
# CUSTOM CONFIGURATION WITHOUT GPU:
#   ENABLE_GPU_PASSTHROUGH=false VM_MEMORY_GB=32 VM_CPUS=16 ./start-test-vm.sh
#
# DEBUG MODE (with set -x):
#   The script includes set -x for debugging QEMU command execution
#
# =============================================================================
# TROUBLESHOOTING
# =============================================================================
#
# COMMON ERROR MESSAGES:
# - "VFIO_MAP_DMA failed": Check IOMMU, hugepages, and VFIO setup
# - "Cannot access /dev/vfio": Verify user group membership
# - "GPU not bound to vfio-pci": Run GPU passthrough setup script
#
# DEBUGGING STEPS:
# 1. Check IOMMU status: dmesg | grep -i iommu
# 2. Verify VFIO modules: lsmod | grep vfio
# 3. Check GPU binding: lspci -nnk | grep -A 2 "01:00"
# 4. Monitor QEMU output for detailed error messages
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

VM_NAME="hpc-cluster-compute-01"
VM_MEMORY_GB=16
VM_CPUS=8
REPO_DIR="$HOME/Projects/pharos.ai-hyperscaler-on-workskation"
BASE_DISK_IMAGE="$REPO_DIR/build/packer/hpc-base/hpc-base/hpc-base.qcow2"
GPU_PCI_ADDRESS="0000:01:00.0"
GPU_AUDIO_PCI_ADDRESS="0000:01:00.1"
SSH_HOST_PORT="2222"
QEMU_SYSTEM="/usr/bin/qemu-system-x86_64"

# GPU Passthrough Configuration
# Set to "true" to enable GPU passthrough, "false" to disable
ENABLE_GPU_PASSTHROUGH="${ENABLE_GPU_PASSTHROUGH:-false}"

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

# Check GPU is bound to vfio-pci (only if GPU passthrough is enabled)
if [[ "$ENABLE_GPU_PASSTHROUGH" == "true" ]]; then
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
fi

# =============================================================================
# Start VM
# =============================================================================

echo "Starting VM..."
echo "Memory: ${VM_MEMORY_GB}G | CPUs: $VM_CPUS"
if [[ "$ENABLE_GPU_PASSTHROUGH" == "true" ]]; then
    echo "GPU Passthrough: ENABLED | GPU: $GPU_PCI_ADDRESS"
else
    echo "GPU Passthrough: DISABLED"
fi
echo "SSH available on localhost:$SSH_HOST_PORT"
echo "Press Ctrl+A then X to exit QEMU"
echo "Note: QEMU will automatically create a snapshot to protect the base image"
echo

# Enable debug mode to show QEMU command execution
set -x

# Build QEMU command with conditional GPU passthrough
QEMU_CMD=(
    "$QEMU_SYSTEM"
    -name "$VM_NAME"
    -drive "file=$BASE_DISK_IMAGE,format=qcow2,if=virtio,snapshot=on"
    -machine "type=q35,accel=kvm"
    -cpu "host,host-phys-bits=on,host-phys-bits-limit=39"
    -smp "$VM_CPUS"
    -m "${VM_MEMORY_GB}G"
    -object "memory-backend-memfd,id=ram,size=${VM_MEMORY_GB}G,share=on"
    -machine "memory-backend=ram"
    -netdev "user,id=net0,hostfwd=tcp::$SSH_HOST_PORT-:22"
    -device "virtio-net-pci,netdev=net0"
)

# Add GPU passthrough devices only if enabled
if [[ "$ENABLE_GPU_PASSTHROUGH" == "true" ]]; then
    QEMU_CMD+=(
        -device "vfio-pci,host=$GPU_PCI_ADDRESS,multifunction=on"
        -device "vfio-pci,host=$GPU_AUDIO_PCI_ADDRESS"
    )
fi

# Add common options
QEMU_CMD+=(
    -nographic
    -serial mon:stdio
)

# Execute QEMU command
"${QEMU_CMD[@]}"
