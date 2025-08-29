# GPU Passthrough VM Experiments

This directory contains experimental scripts for GPU passthrough and
virtualization testing in the Pharos.AI hyperscaler project.

## start-gpu-passthrough-vm.sh

A simplified GPU passthrough VM script that provides minimal configuration for
PCIe GPU passthrough with QEMU snapshot protection.

### Overview

This script creates a QEMU virtual machine with direct GPU passthrough
capabilities, allowing the VM to access physical GPU hardware directly. It's
designed for HPC cluster compute node testing and development.

### Features

- **GPU Passthrough**: Direct access to physical GPU hardware
- **Snapshot Protection**: Automatically creates QEMU snapshots to protect base
  disk images
- **Configurable Resources**: Easily adjustable CPU, memory, and network
  settings
- **Safety Checks**: Validates prerequisites and GPU driver binding before VM
  startup
- **SSH Access**: Forwarded SSH port for remote VM management

### Prerequisites

#### System Requirements

- Linux host with KVM support
- QEMU system emulator (`qemu-system-x86`)
- GPU bound to `vfio-pci` driver
- Base disk image in QCOW2 format

#### Software Installation

```bash
# Install QEMU on Ubuntu/Debian
sudo apt-get install qemu-system-x86

# Install QEMU on CentOS/RHEL
sudo yum install qemu-kvm
```

#### GPU Driver Setup

The GPU must be bound to the `vfio-pci` driver for passthrough to work:

```bash
# Check current GPU driver
lspci -nnk -d 10de:  # For NVIDIA GPUs
lspci -nnk -d 1002:  # For AMD GPUs

# Bind GPU to vfio-pci (requires root)
echo "0000:01:00.0" > /sys/bus/pci/drivers/vfio-pci/bind
```

### Configuration

Edit the configuration section at the top of the script to customize VM
settings:

```bash
VM_NAME="hpc-cluster-compute-01"           # VM display name
VM_MEMORY_GB=16                            # VM memory in GB
VM_CPUS=8                                  # Number of CPU cores
BASE_DISK_IMAGE="/path/to/base.qcow2"      # Base disk image path
GPU_PCI_ADDRESS="0000:01:00.0"             # Primary GPU PCI address
GPU_AUDIO_PCI_ADDRESS="0000:01:00.1"       # GPU audio device PCI address
SSH_HOST_PORT="2222"                       # Host port for SSH forwarding
QEMU_SYSTEM="/usr/bin/qemu-system-x86_64"  # QEMU binary path
```

### Usage

#### Basic Usage

```bash
# Make script executable
chmod +x start-gpu-passthrough-vm.sh

# Run the script
./start-gpu-passthrough-vm.sh
```

#### Custom Configuration

```bash
# Edit configuration variables
vim start-gpu-passthrough-vm.sh

# Or override variables at runtime
VM_MEMORY_GB=32 VM_CPUS=16 ./start-gpu-passthrough-vm.sh
```

### VM Access

#### SSH Connection

The script forwards SSH port 22 from the VM to the host:

```bash
ssh -p 2222 user@localhost
```

#### QEMU Console

- **Exit VM**: Press `Ctrl+A` then `X`
- **Monitor Mode**: The script uses `-serial mon:stdio` for console access

### QEMU Configuration Details

The script uses the following QEMU configuration:

- **Machine Type**: `q35` with KVM acceleration
- **CPU**: Host CPU with 39-bit physical addressing
- **Memory**: Memory backend with memfd for efficient sharing
- **Storage**: QCOW2 disk with snapshot protection
- **Network**: User networking with SSH port forwarding
- **GPU**: VFIO PCI devices for direct GPU access
- **Display**: No graphics (nographic mode)

### Safety Features

#### Snapshot Protection

The `snapshot=on` option ensures the base disk image is never modified:

- VM changes are stored in temporary snapshots
- Base image remains pristine for future use
- Automatic cleanup when VM exits

#### Pre-flight Checks

The script validates:

- Base disk image existence
- QEMU binary availability
- KVM device access
- GPU driver binding status

### Troubleshooting

#### Common Issues

**GPU Not Bound to vfio-pci**

```bash
# Check current driver
lspci -nnk -d 10de: | grep -A 2 "01:00.0"

# Bind to vfio-pci
echo "0000:01:00.0" > /sys/bus/pci/drivers/vfio-pci/bind
```

**KVM Access Denied**

```bash
# Check KVM group membership
groups $USER

# Add user to kvm group
sudo usermod -a -G kvm $USER
# Log out and back in
```

**Base Disk Not Found**

```bash
# Verify image path
ls -la /path/to/base.qcow2

# Update BASE_DISK_IMAGE variable in script
```

#### Performance Optimization

- **Memory Backend**: Uses `memfd` for efficient memory sharing
- **CPU Pinning**: Consider using `-cpu host` for best performance
- **I/O Optimization**: Virtio drivers for network and storage

### Development Notes

This script is designed for experimental use and development testing. For
production deployment:

- Remove hardcoded paths and make them configurable
- Add logging and monitoring capabilities
- Implement proper error handling and recovery
- Consider using libvirt for VM management
- Add security hardening measures

### Related Documentation

- [QEMU GPU Passthrough
  Guide](https://wiki.qemu.org/Documentation/GPU_Passthrough)
- [VFIO Driver
  Documentation](https://www.kernel.org/doc/html/latest/driver-api/vfio.html)
- [KVM Virtualization](https://www.linux-kvm.org/page/Main_Page)

### Contributing

When modifying this script:

- Maintain the safety checks and validation
- Test GPU passthrough functionality thoroughly
- Update this documentation for any new features
- Follow shell script best practices
- Consider backward compatibility
