#!/bin/bash

# HPC Base Image Build Debug Script
# This script helps debug failed Packer builds by providing analysis tools
# and easy VM booting capabilities

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/../build/packer/hpc-base/hpc-base"
VM_NAME="hpc-base.qcow2"
DEBUG_SCRIPT="${BUILD_DIR}/debug-vm.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if VM image exists
check_vm_image() {
    if [[ -f "${BUILD_DIR}/${VM_NAME}" ]]; then
        print_success "VM image found: ${BUILD_DIR}/${VM_NAME}"
        return 0
    else
        print_error "VM image not found: ${BUILD_DIR}/${VM_NAME}"
        return 1
    fi
}

# Function to analyze build logs
analyze_logs() {
    print_status "Analyzing build logs..."

    # Check for common error patterns
    if [[ -f "${BUILD_DIR}/../qemu-serial.log" ]]; then
        print_status "QEMU serial log found: ${BUILD_DIR}/../qemu-serial.log"

        # Look for common error patterns
        if grep -q "ERROR" "${BUILD_DIR}/../qemu-serial.log" 2>/dev/null; then
            print_warning "Errors found in QEMU serial log:"
            grep -i "error" "${BUILD_DIR}/../qemu-serial.log" | head -10
        fi

        if grep -q "FAILED" "${BUILD_DIR}/../qemu-serial.log" 2>/dev/null; then
            print_warning "Failures found in QEMU serial log:"
            grep -i "failed" "${BUILD_DIR}/../qemu-serial.log" | head -10
        fi
    else
        print_warning "QEMU serial log not found"
    fi

    # Check for Ansible errors
    if [[ -f "${BUILD_DIR}/../ansible.log" ]]; then
        print_status "Ansible log found: ${BUILD_DIR}/../ansible.log"

        if grep -q "ERROR" "${BUILD_DIR}/../ansible.log" 2>/dev/null; then
            print_warning "Ansible errors found:"
            grep -i "error" "${BUILD_DIR}/../ansible.log" | head -10
        fi
    fi
}

# Function to show VM image information
show_vm_info() {
    if check_vm_image; then
        print_status "VM image information:"
        echo "  Size: $(du -h "${BUILD_DIR}/${VM_NAME}" | cut -f1)"
        echo "  Format: $(file "${BUILD_DIR}/${VM_NAME}" | cut -d: -f2-)"

        # Check if image is bootable
        if qemu-img info "${BUILD_DIR}/${VM_NAME}" >/dev/null 2>&1; then
            print_success "VM image is valid and bootable"
        else
            print_error "VM image appears to be corrupted"
        fi
    fi
}

# Function to create debug VM script if it doesn't exist
create_debug_script() {
    if [[ ! -f "${DEBUG_SCRIPT}" ]]; then
        print_status "Creating debug VM script..."
        cat > "${DEBUG_SCRIPT}" << 'EOF'
#!/bin/bash
# Debug VM Script for Failed Packer Build

set -euo pipefail

VM_NAME="hpc-base.qcow2"
VM_MEMORY_GB=4
VM_CPUS=2
SSH_HOST_PORT="2222"
QEMU_SYSTEM="/usr/bin/qemu-system-x86_64"

echo "Debug VM for failed Packer build"
echo "VM: $VM_NAME | Memory: ${VM_MEMORY_GB}G | CPUs: $VM_CPUS"
echo "SSH available on localhost:$SSH_HOST_PORT"
echo "Press Ctrl+A then X to exit QEMU"
echo

# Check if QEMU exists
if [[ ! -x "$QEMU_SYSTEM" ]]; then
    echo "ERROR: QEMU not found at $QEMU_SYSTEM"
    echo "Install with: sudo apt-get install qemu-system-x86"
    exit 1
fi

# Check if VM image exists
if [[ ! -f "$VM_NAME" ]]; then
    echo "ERROR: VM image not found: $VM_NAME"
    exit 1
fi

# Start debug VM
echo "Starting debug VM..."
"$QEMU_SYSTEM" \
    -name "debug-hpc-base" \
    -drive "file=$VM_NAME,format=qcow2,if=virtio,snapshot=off" \
    -machine type=q35,accel=kvm \
    -cpu host \
    -smp "$VM_CPUS" \
    -m "${VM_MEMORY_GB}G" \
    -netdev "user,id=net0,hostfwd=tcp::$SSH_HOST_PORT-:22" \
    -device "virtio-net-pci,netdev=net0" \
    -nographic -serial mon:stdio
EOF
        chmod +x "${DEBUG_SCRIPT}"
        print_success "Debug script created: ${DEBUG_SCRIPT}"
    else
        print_success "Debug script already exists: ${DEBUG_SCRIPT}"
    fi
}

# Function to start debug VM
start_debug_vm() {
    if check_vm_image; then
        print_status "Starting debug VM..."
        cd "${BUILD_DIR}"
        exec ./debug-vm.sh
    else
        print_error "Cannot start debug VM - image not found"
        exit 1
    fi
}

# Function to show debugging tips
show_debugging_tips() {
    print_status "Debugging Tips:"
    echo "1. Boot the VM and check the system state:"
    echo "   cd ${BUILD_DIR} && ./debug-vm.sh"
    echo
    echo "2. Once in the VM, check:"
    echo "   - System logs: journalctl -xe"
    echo "   - Network status: ip addr show"
    echo "   - Service status: systemctl status"
    echo "   - Package installation: dpkg -l | grep -E '(nvidia|singularity|apptainer)'"
    echo
    echo "3. Check Ansible execution:"
    echo "   - Look for /tmp/ansible-* directories"
    echo "   - Check /var/log/ansible.log if it exists"
    echo
    echo "4. Common issues to check:"
    echo "   - Network connectivity during build"
    echo "   - Package repository availability"
    echo "   - Disk space during installation"
    echo "   - Permission issues with sudo"
    echo
    echo "5. To fix and retry:"
    echo "   - Make necessary changes to the build scripts"
    echo "   - Run: make build-hpc-image"
    echo
}

# Main function
main() {
    echo "=========================================="
    echo "HPC Base Image Build Debug Tool"
    echo "=========================================="
    echo

    # Check if build directory exists
    if [[ ! -d "${BUILD_DIR}" ]]; then
        print_error "Build directory not found: ${BUILD_DIR}"
        print_status "Make sure you've run the build at least once"
        exit 1
    fi

    # Analyze the build
    analyze_logs
    echo

    # Show VM information
    show_vm_info
    echo

    # Create debug script if needed
    create_debug_script
    echo

    # Show debugging tips
    show_debugging_tips

    # Ask if user wants to start debug VM
    echo "=========================================="
    read -p "Do you want to start the debug VM now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_debug_vm
    else
        print_status "To start debugging later, run:"
        echo "  cd ${BUILD_DIR} && ./debug-vm.sh"
        echo
        print_status "Or use the CMake target:"
        echo "  make debug-hpc-vm"
    fi
}

# Run main function
main "$@"
