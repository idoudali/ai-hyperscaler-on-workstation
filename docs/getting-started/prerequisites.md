# Prerequisites

**Status:** Complete  
**Last Updated:** 2025-01-21

## Overview

This document outlines the hardware, software, and system requirements needed to run the Hyperscaler on
Workstation project. Review these prerequisites before proceeding with installation.

### Quick Verification

Before reading through all requirements, you can quickly verify your system using the automated validation scripts:

**System Prerequisites Checker:**

```bash
# Run comprehensive system checks
./scripts/system-checks/check_prereqs.sh all

# Or check specific components
./scripts/system-checks/check_prereqs.sh cpu          # CPU virtualization
./scripts/system-checks/check_prereqs.sh iommu       # IOMMU support
./scripts/system-checks/check_prereqs.sh kvm         # KVM acceleration
./scripts/system-checks/check_prereqs.sh gpu         # GPU drivers
./scripts/system-checks/check_prereqs.sh packages    # Required packages
./scripts/system-checks/check_prereqs.sh resources  # System resources
```

**GPU Inventory Script:**

```bash
# Generate GPU inventory and PCIe passthrough configuration
./scripts/system-checks/gpu_inventory.sh

# Output written to: output/gpu_inventory.yaml
```

The prerequisite checker validates:

- CPU virtualization support (VT-x/AMD-V)
- IOMMU support (VT-d/AMD-Vi) for GPU passthrough
- KVM acceleration and kernel modules
- NVIDIA GPU detection and driver status
- Required software packages
- System resources (RAM, disk, CPU)
- User group memberships (docker, kvm, libvirt)

For detailed information about these scripts, see [`scripts/system-checks/README.md`](../../scripts/system-checks/README.md).

---

## Hardware Requirements

### Minimum Configuration

**Host Machine:**

| Resource | Minimum | Purpose |
|----------|---------|---------|
| **CPU** | 8 cores (Intel/AMD x86_64) | Basic VM operation and host OS |
| **RAM** | 32 GB | Host OS + basic cluster operation |
| **Storage** | 500 GB available disk space | VM images, build artifacts, logs |
| **GPU** | Optional (1+ NVIDIA GPU recommended) | GPU-accelerated workloads |
| **Network** | Gigabit Ethernet (1 Gbps) | VM-to-VM and external connectivity |

**Notes:**

- Suitable for development and testing
- May require running HPC and cloud clusters sequentially
- Limited to smaller workloads

### Recommended Configuration

**Host Machine:**

| Resource | Recommended | Purpose |
|----------|-------------|---------|
| **CPU** | 16-24 cores (Intel Xeon or AMD EPYC) | Concurrent cluster operation |
| **RAM** | 64-128 GB | Run both HPC and cloud clusters simultaneously |
| **Storage** | 1-1.5 TB NVMe SSD | Faster builds and VM operations |
| **GPU** | 2-4x NVIDIA GPUs (RTX A6000, Tesla T4, or better) | Production ML workloads |
| **Network** | 10 Gigabit Ethernet | High-throughput workloads |

**Benefits:**

- Sufficient resources for both HPC and cloud clusters simultaneously
- Better performance for training and inference workloads
- Improved I/O for model storage and transfer

The recommended system can work either

1. Have multiple GPUs (e.g. gaming ones), where each one is passed through to individual VMs
2. Even with a single GPU with [MIG](https://www.nvidia.com/en-eu/technologies/multi-instance-gpu/) support could
suffice and give the "illusion" of multiple ones.

## CPU Requirements

### Virtualization Support

**Required Features:**

- **Intel:** VT-x (Intel Virtualization Technology)
- **AMD:** AMD-V (SVM - Secure Virtual Machine)

**Verification:**

```bash
# Check CPU virtualization support
grep -E 'vmx|svm' /proc/cpuinfo

# Intel systems should show 'vmx'
# AMD systems should show 'svm'
```

**BIOS Configuration:**

- Enable virtualization in BIOS/UEFI settings
- Common setting names: "Intel Virtualization Technology", "AMD-V", "SVM Mode"
- May require disabling secure boot on some systems

### IOMMU Support (for GPU Passthrough)

**Required Features:**

- **Intel:** VT-d (Intel Virtualization Technology for Directed I/O)
- **AMD:** AMD-Vi (IOMMU)

**Kernel Requirements:**

- Kernel 6.12+ recommended
- IOMMU enabled in kernel: `intel_iommu=on` (Intel) or `amd_iommu=on` (AMD)

**Verification:**

```bash
# Check IOMMU status
dmesg | grep -i iommu

# Should show IOMMU groups if enabled
find /sys/kernel/iommu_groups/ -type l | head
```

---

## Memory Requirements

### Host System Memory

**Minimum:** 32 GB RAM

- 4-8 GB for host OS and services
- 24+ GB for VM allocation

**Recommended:** 64-128 GB RAM

- 8-16 GB for host OS
- 40-56 GB for HPC cluster VMs
- 40-56 GB for cloud cluster VMs
- Allows concurrent operation of both clusters

**Memory Calculation:**

For concurrent HPC + Cloud clusters:

```text
Total RAM = Host OS (8 GB) + HPC Cluster (56 GB) + Cloud Cluster (56 GB) + Overhead (8 GB)
Total RAM ≈ 128 GB minimum
```

---

## Storage Requirements

### Disk Space

**Minimum:** 500 GB available disk space

**Breakdown:**

- VM images (Packer builds): ~50-100 GB
- Build artifacts: ~50 GB
- Container images: ~50 GB
- VM runtime storage: ~200 GB
- Logs and temporary files: ~50 GB
- Operating system: ~50 GB

**Recommended:** 1-1.5 TB available disk space

- Faster builds with SSD
- More VM images and snapshots
- Better performance for concurrent operations

**Storage Type:**

- **NVMe SSD (Recommended):** Fastest build and VM operations
- **SATA SSD:** Good performance, lower cost
- **HDD:** Functional but slower builds and VM operations

### Filesystem

- **ext4** or **xfs** recommended
- Support for large files (>10 GB VM images)
- Sufficient inode count for many small files

**Verification:**

```bash
# Check available disk space
df -h /

# Check filesystem type
df -T /
```

---

## GPU Requirements

### NVIDIA GPU Support

**Minimum Requirements:**

- NVIDIA GPU with compute capability 7.0+
- NVIDIA Driver 535+ installed
- CUDA Toolkit 12.0+ (can be containerized)

**GPU Passthrough Requirements:**

- IOMMU enabled (see CPU Requirements)
- GPU in its own IOMMU group
- PCIe passthrough configured

**Verification:**

```bash
# Check NVIDIA GPU detection
lspci | grep -i nvidia

# Check NVIDIA driver installation
nvidia-smi

# Check CUDA availability (if installed)
nvcc --version
```

**Note:** GPU passthrough is optional. The system can run without GPUs for CPU-only workloads.

---

## Operating System Requirements

### Supported Operating Systems

**Primary Platform:**

- **Ubuntu:** 22.04 LTS or later (recommended)
- **Debian:** 13 (Trixie) or later

**Other Linux Distributions:**

Has not been tested

### Kernel Requirements

**Minimum:** Kernel 5.15+ (Ubuntu 22.04 default)

**Recommended:** Kernel 6.12+ (Debian 13 Trixie default)

**Required Kernel Features:**

- KVM support (built-in)
- IOMMU support (for GPU passthrough)
- Cgroup v2 support
- Namespace support

**Verification:**

```bash
# Check kernel version
uname -r

# Check KVM support
lsmod | grep kvm

# Check cgroup support
stat -fc %T /sys/fs/cgroup/
```

---

## Software Dependencies

### Required System Packages

**Build Tools:**

- `build-essential` - C/C++ compiler and build tools
- `cmake` (>= 3.18) - Build system configuration
- `ninja-build` - Build system executor
- `make` - Build automation
- `git` - Version control

**Python Environment:**

- `python3` (>= 3.11) - Python interpreter
- `python3-dev` - Python development headers
- `python3-pip` - Python package manager
- `python3-venv` - Python virtual environments

**Virtualization Tools:**

- `libvirt-dev` - LibVirt development libraries
- `qemu-system-x86` - QEMU x86 system emulator
- `qemu-utils` - QEMU utilities (qemu-img, etc.)
- `virtiofsd` - Virtio filesystem daemon

**Network Tools:**

- `curl` - HTTP client
- `wget` - File download utility
- `ca-certificates` - SSL certificate bundle

**System Utilities:**

- `lsb-release` - Linux Standard Base release information
- `gnupg` - GNU Privacy Guard (for package verification)
- `apt-transport-https` - HTTPS transport for APT

### Docker CE

**Required:** Docker Community Edition (latest stable)

**Components:**

- Docker Engine
- Docker Compose plugin
- Docker Buildx plugin

**User Permissions:**

- User must be in `docker` group
- Automatic user addition via setup script

**Verification:**

```bash
# Check Docker installation
docker --version

# Check Docker daemon status
systemctl status docker

# Verify user is in docker group
groups | grep docker
```

### Python Package Manager

**Required:** `uv` (modern Python package manager)

**Purpose:**

- Fast Python dependency resolution
- Virtual environment management
- Project dependency management

**Installation:**

Automatically installed by `scripts/setup-host-dependencies.sh` or manually:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Development Tools (Optional but Recommended)

**Pre-commit:**

- Git hooks for code quality
- Installed via `make pre-commit-install`

**Commitizen:**

- Conventional commit message formatting
- Installed via `./scripts/setup-commitizen.sh`

**Shellcheck:**

- Shell script linting
- Installed via setup script

**Hadolint:**

- Dockerfile linting
- Installed via setup script

---

## Network Requirements

### Host Network Configuration

**Minimum:** Gigabit Ethernet (1 Gbps)

**Recommended:** 10 Gigabit Ethernet

**Required Capabilities:**

- Internet connectivity (for package downloads, container pulls)
- Local network access (for VM-to-VM communication)
- DNS resolution (for container registries, package repositories)

---

## Virtualization Prerequisites

### KVM/QEMU

**Required:** KVM acceleration enabled

**Verification:**

```bash
# Check KVM module loaded
lsmod | grep kvm

# Check /dev/kvm exists
ls -l /dev/kvm

# Check user permissions
ls -l /dev/kvm | grep $USER
```

**User Groups:**

User must be in `kvm` and `libvirt` groups:

```bash
# Add user to groups (handled by setup script)
sudo usermod -aG kvm $USER
sudo usermod -aG libvirt $USER

# Log out and back in for changes to take effect
```

### LibVirt

**Required:** LibVirt daemon running

**Verification:**

```bash
# Check libvirt status
systemctl status libvirtd

# Check libvirt version
virsh version
```

---

## Verification Checklist

Before proceeding with installation, verify all prerequisites:

- [ ] CPU has virtualization support (VT-x/AMD-V)
- [ ] IOMMU enabled (if using GPU passthrough)
- [ ] Minimum 32 GB RAM available
- [ ] Minimum 500 GB disk space available
- [ ] Supported operating system (Ubuntu 22.04+ or Debian 13+)
- [ ] Kernel 5.15+ (6.12+ recommended)
- [ ] Internet connectivity
- [ ] sudo privileges
- [ ] NVIDIA GPU detected (if using GPU features)
- [ ] NVIDIA drivers installed (if using GPU features)

### Automated Verification

**Recommended:** Use the automated prerequisite checker to validate all requirements:

```bash
# Run comprehensive system checks (recommended)
./scripts/system-checks/check_prereqs.sh all

# The script checks:
# - CPU virtualization (VT-x/AMD-V)
# - IOMMU support (VT-d/AMD-Vi)
# - KVM acceleration
# - GPU drivers and hardware
# - Required packages
# - System resources (RAM, disk, CPU)
# - User group memberships
```

**For GPU Configuration:**

If you're using GPUs, generate an inventory report:

```bash
# Generate GPU inventory and PCIe passthrough configuration
./scripts/system-checks/gpu_inventory.sh

# This creates: output/gpu_inventory.yaml
# With YAML snippets ready for cluster configuration
```

**Manual Verification:**

If you prefer manual verification, see the individual sections above for verification commands for each component.

---

## Next Steps

Once all prerequisites are met, proceed to the [Installation Guide](installation.md) for step-by-step installation instructions.

---

## Troubleshooting

### Common Issues

**Virtualization Not Enabled:**

- Check BIOS/UEFI settings
- Ensure "Virtualization Technology" is enabled
- Reboot after BIOS changes

**Insufficient Memory:**

- Close unnecessary applications
- Consider running clusters sequentially
- Upgrade RAM if possible

**Docker Permission Denied:**

- Ensure user is in `docker` group
- Log out and back in after group changes
- Restart Docker daemon: `sudo systemctl restart docker`

**GPU Not Detected:**

- Verify GPU is physically installed
- Check PCIe slot connection
- Verify NVIDIA drivers: `nvidia-smi`
- Check IOMMU groups for passthrough

For more troubleshooting help, see the [Troubleshooting Guide](../troubleshooting/common-issues.md).
