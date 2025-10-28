# Base Packages Role

Consolidated base package installation role for HPC and cloud workloads. Replaces separate `hpc-base-packages`
and `cloud-base-packages` roles.

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

### HPC-Specific Packages

Currently empty. Reserved for future HPC-specific package additions.

### Cloud-Specific Packages

Currently empty. Reserved for future cloud-specific package additions (e.g., `cloud-init`, `qemu-guest-agent`).

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

- `hpc-base-packages` (merged)
- `cloud-base-packages` (placeholder, now consolidated)

**Migration Steps:**

1. Replace `hpc-base-packages` with `base-packages` in playbooks
2. Remove `cloud-base-packages` references (if any)
3. Keep default `package_profile: "hpc"` for HPC deployments
4. Set `package_profile: "cloud"` for cloud deployments (when implemented)

## Related Roles

- `package-manager` - Pre-built package installation logic
- `slurm-common` - SLURM common functionality
- `beegfs-common` - BeeGFS common functionality
