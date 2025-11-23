# Base Packages Role

**Status:** ✅ Complete (Phase 4.8 Consolidation)
**Last Updated:** 2025-11-18

This role provides consolidated base package installation for both HPC and cloud workloads, replacing the
separate `hpc-base-packages` and `cloud-base-packages` roles with a unified, profile-based approach.

## Purpose

This role installs essential base packages required for all deployment types, with optional profile-specific additions.

## Variables

### Required Variables

None - all variables have defaults.

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `package_profile` | `hpc` | Package profile: `hpc`, `cloud`, or `minimal` |
| `base_packages_common` | See defaults | Common packages installed for all profiles |
| `base_packages_hpc` | `[]` | HPC-specific packages (when `profile=hpc`) |
| `base_packages_cloud` | `[]` | Cloud-specific packages (when `profile=cloud`) |

## Usage

### Basic Usage (HPC Profile)

```yaml
roles:
  - role: base-packages
```

### Cloud Profile

```yaml
roles:
  - role: base-packages
    vars:
      package_profile: "cloud"
```

### Minimal Profile

```yaml
roles:
  - role: base-packages
    vars:
      package_profile: "minimal"
```

## Package Lists

### Common Packages (All Profiles)

These packages are installed for all profiles (hpc, cloud, minimal):

- `tmux` - Terminal multiplexer
- `htop` - Interactive process viewer
- `vim` - Text editor
- `curl` - HTTP client
- `wget` - File downloader
- `net-tools` - Network utilities
- `iproute2` - Modern IP route utilities
- `iputils-ping` - ping command
- `dnsutils` - DNS utilities
- `netcat-openbsd` - Network connectivity testing
- `bc` - Calculator for performance tests
- `coreutils` - Enhanced GNU core utilities
- `util-linux` - Additional utilities (mount, lsblk, etc.)
- `procps` - Process utilities (ps, top, etc.)
- `gawk` - GNU awk for text processing
- `sed` - Stream editor
- `grep` - Pattern matching
- `findutils` - find, locate, xargs
- `less` - Pager for viewing files
- `sudo` - Privilege escalation
- `ca-certificates` - SSL certificate authorities
- `openssh-client` - SSH client utilities
- `build-essential` - GCC, g++, make, and other build tools for kernel modules
- `dkms` - Dynamic Kernel Module Support for automatic module rebuilds

### Kernel and Headers

- Default kernel: `linux-image-amd64`
- Default headers: `linux-headers-amd64`
- Additional headers: `linux-headers-cloud-amd64` (ensures cloud kernels gain headers after reboot)

Why amd64 meta-packages?

- Works consistently across cloud VMs, bare-metal controllers, and GPU/HPC nodes
- Ensures compatibility with BeeGFS, NVIDIA, and other DKMS modules
- Avoids divergent behavior between cloud and HPC profiles

Override the kernel flavor if needed:

```yaml
roles:
  - role: base-packages
    vars:
      kernel_image_package: linux-image-cloud-amd64
      kernel_headers_package: linux-headers-cloud-amd64
      kernel_additional_packages:
        - linux-headers-rt-amd64
```

Kernel packages are installed via meta-packages, so updates automatically track the latest available kernel.

### HPC-Specific Packages

Currently empty. Most HPC-specific packages (MPI, scientific libraries, compilers) are installed
by other roles (slurm-controller, slurm-compute) or via the package-manager role. Additional
HPC base utilities can be added here if needed.

### Cloud-Specific Packages

- `cloud-init` - Cloud instance initialization
- `qemu-guest-agent` - QEMU guest agent for VM management

Additional cloud packages can be added here as needed for cloud deployments.

## Dependencies

None.

## Example Playbooks

### HPC Packer Build

```yaml
roles:
  - role: base-packages
    vars:
      package_profile: "hpc"
```

### Cloud Deployment

```yaml
roles:
  - role: base-packages
    vars:
      package_profile: "cloud"
```

## Notes

- Supports Packer build mode via `packer_build` variable
- Automatically detects Packer vs runtime execution
- All packages are installed with `apt`
- Package cache is updated before installation
- Uses tags for selective execution: `base-packages`

## Migration from Old Roles

This role replaces:

- ✅ `hpc-base-packages` (fully merged - packages consolidated)
- ✅ `cloud-base-packages` (merged - cloud packages added)

**Migration Status:**

- ✅ All playbooks updated to use `base-packages`
- ✅ Legacy roles consolidated and removed
- ✅ Default profile is `hpc` for backward compatibility
- ✅ Cloud profile available with `package_profile: "cloud"`

**Usage:**

```yaml
# HPC deployments (default)
roles:
  - base-packages  # Uses hpc profile by default

# Cloud deployments
roles:
  - base-packages
    vars:
      package_profile: "cloud"
```

## Related Roles

- `package-manager` - Pre-built package installation logic
- `slurm-common` - SLURM common functionality
- `beegfs-common` - BeeGFS common functionality
