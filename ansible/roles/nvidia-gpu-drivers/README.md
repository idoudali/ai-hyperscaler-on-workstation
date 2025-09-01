# NVIDIA GPU Drivers Role

This Ansible role installs NVIDIA proprietary GPU drivers on Debian systems
following the official [Debian wiki
guidelines](https://wiki.debian.org/NvidiaGraphicsDrivers).

## Features

- **Automatic GPU detection** using `nvidia-detect`
- **Intelligent driver selection** based on detected hardware
- **Support for multiple Debian versions** (Trixie, Bookworm, Bullseye)
- **Tesla driver support** for datacenter GPUs
- **CUDA toolkit installation** (optional)
- **Proper nouveau driver blacklisting** to prevent conflicts

## Requirements

- Debian-based system (Debian 11+, Ubuntu)
- Root privileges (role uses `become: true`)
- Internet connection for package downloads

## Role Variables

Available variables with their default values:

```yaml
# Whether to install NVIDIA CUDA toolkit and development tools
nvidia_install_cuda: false

# Whether this is running during a Packer build (suppresses reboot warnings)
nvidia_packer_build: false

# Whether to show reboot warning even if /var/run/reboot-required doesn't exist
# Automatically disabled during Packer builds
nvidia_force_reboot_warning: true

# NVIDIA driver version preference (auto-detected by default)
nvidia_driver_version: "auto"
```

## Usage

### Basic Usage

Include the role in your playbook:

```yaml
- hosts: gpu_nodes
  become: true
  roles:
    - nvidia-gpu-drivers
```

### With CUDA Support

```yaml
- hosts: gpu_nodes
  become: true
  vars:
    nvidia_install_cuda: true
  roles:
    - nvidia-gpu-drivers
```

### For Packer Builds

When running during Packer image creation, enable Packer mode to suppress reboot warnings:

```yaml
- hosts: all
  become: true
  vars:
    nvidia_install_cuda: true
    nvidia_packer_build: true
  roles:
    - nvidia-gpu-drivers
```

## What This Role Does

1. **Detects NVIDIA GPUs** using `lspci` command
2. **Enables non-free repositories** required for NVIDIA drivers
3. **Installs kernel headers** (prerequisite for driver compilation)
4. **Installs nvidia-detect** utility for automatic driver detection
5. **Installs appropriate NVIDIA driver** based on detected hardware
6. **Blacklists nouveau driver** to prevent conflicts
7. **Optionally installs CUDA toolkit** and development tools
8. **Configures system** for optimal NVIDIA driver operation

## Post-Installation

### Runtime Deployments

**Important**: A system reboot is required after installation for the NVIDIA driver to become active. The role will
notify you about this requirement.

### Packer Builds

When `nvidia_packer_build: true` is set, reboot warnings are suppressed since the drivers will be available
when the built image is deployed and rebooted.

After deployment of a Packer-built image, verify the installation:

```bash
# Check driver status
nvidia-smi

# Test OpenGL support
glxinfo | grep -i nvidia
```

## Supported Debian Versions

- **Debian 13 "Trixie"**: NVIDIA driver 550.163.01, 535.216.03
- **Debian 12 "Bookworm"**: NVIDIA driver 535.183.01
- **Debian 11 "Bullseye"**: NVIDIA driver 470.129.06, 390.144

## Tesla GPUs

The role automatically detects and installs Tesla drivers for datacenter GPUs
when recommended by `nvidia-detect`.

## Troubleshooting

### No NVIDIA GPU Detected

If no NVIDIA GPU is detected, the role will skip installation gracefully.

### Driver Installation Fails

1. Ensure non-free repositories are properly configured
2. Check that kernel headers match your running kernel
3. Verify the GPU is supported by current driver versions

### System Won't Boot After Installation

Boot into recovery mode and run:

```bash
# Remove NVIDIA packages
apt purge "*nvidia*"

# Reinstall nouveau driver
apt install --reinstall xserver-xorg-video-nouveau

# Reboot
reboot
```

## Dependencies

This role has no external role dependencies but requires:

- Debian package manager (`apt`)
- Internet connectivity
- Non-free repository access

## License

This role follows the same license as the parent project.

## References

- [Debian NVIDIA Graphics Drivers
  Wiki](https://wiki.debian.org/NvidiaGraphicsDrivers)
- [NVIDIA Official
  Documentation](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)
