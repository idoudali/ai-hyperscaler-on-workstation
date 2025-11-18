# Ansible Roles Index

**Status:** Complete
**Last Updated:** 2025-11-18

## Overview

This directory contains Ansible roles for configuring HPC infrastructure components. Each
role is responsible for a specific aspect of the system configuration and can be used
independently or as part of playbooks. Roles have been consolidated in Phase 4.8 to reduce
duplication and improve maintainability.

## Role Categories

### 1. Base Infrastructure Roles

These roles provide foundational system configuration for both HPC and cloud deployments.

|| Role | Purpose | Status | Documentation |
||------|---------|--------|-----------------|
|| **[hpc-base-packages](./hpc-base-packages/README.md)** | Installs HPC packages | ✅ Complete | Full |
|| **[cloud-base-packages](./cloud-base-packages/README.md)** | Installs cloud packages | ✅ Complete | Full |
|| **[container-runtime](./container-runtime/README.md)** | Container runtime | ✅ Complete | Full |

**Note:** Legacy `hpc-base-packages` and `cloud-base-packages` roles have been consolidated into `base-packages` (Phase 4.8).

### 2. Storage Roles (BeeGFS)

BeeGFS distributed storage configuration for high-performance parallel file systems.

|| Role | Purpose | Status | Documentation |
||------|---------|--------|-----------------|
|| **[beegfs-mgmt](./beegfs-mgmt/README.md)** | BeeGFS management | ✅ Complete | Full |
|| **[beegfs-meta](./beegfs-meta/README.md)** | BeeGFS metadata | ✅ Complete | Full |
|| **[beegfs-storage](./beegfs-storage/README.md)** | BeeGFS storage | ✅ Complete | Full |
|| **[beegfs-client](./beegfs-client/README.md)** | BeeGFS client mount | ✅ Complete | Full |

See each role's README for detailed configuration options.

### 3. HPC Scheduler Roles (SLURM)

SLURM cluster scheduler configuration for job orchestration and resource management.

|| Role | Purpose | Status | Documentation |
||------|---------|--------|-----------------|
|| **[slurm-controller](./slurm-controller/README.md)** | SLURM head node | ✅ Complete | Full |
|| **[slurm-compute](./slurm-compute/README.md)** | SLURM compute nodes | ✅ Complete | Full |

**Important Note:** SLURM roles install from pre-built packages in `build/packages/slurm/`.
Build packages first with:

```bash
make run-docker COMMAND="cmake --build build --target build-slurm-packages"
```

### 4. GPU Support Roles

NVIDIA GPU driver and toolkit installation for GPU-accelerated computing.

|| Role | Purpose | Status | Documentation |
||------|---------|--------|-----------------|
|| **[nvidia-gpu-drivers](./nvidia-gpu-drivers/README.md)** | NVIDIA drivers | ✅ Complete | Full |

Key capabilities:

- Automatic GPU detection with `nvidia-detect`
- Support for Debian Trixie, Bookworm, Bullseye
- Tesla datacenter GPU support
- CUDA toolkit installation (optional)
- Nouveau driver blacklisting

### 5. Container Management Roles

Container registry and image management for distributed deployment.

|| Role | Purpose | Status | Documentation |
||------|---------|--------|-----------------|
|| **[container-registry](./container-registry/README.md)** | Registry server | ✅ Complete | Full |
|| **[ml-container-images](./ml-container-images/README.md)** | ML images | ✅ Complete | Full |

### 6. Storage Mounting Roles

Specialized storage configuration for shared file systems.

|| Role | Purpose | Status | Documentation |
||------|---------|--------|-----------------|
|| **[virtio-fs-mount](./virtio-fs-mount/README.md)** | Virtio-FS mount | ✅ Complete | Full |

### 7. Monitoring Roles

Comprehensive monitoring infrastructure with metrics collection and visualization.

||| Role | Purpose | Status | Documentation |
|||------|---------|--------|-----------------|
||| **[monitoring-stack](./monitoring-stack/README.md)** | Monitoring | ✅ Complete | Full |

**Monitoring Stack Components:**

- **Prometheus**: Metrics collection and storage
- **Grafana**: Metrics visualization and dashboards
- **node-exporter**: Host system metrics
- **DCGM** (NVIDIA DCGM): GPU metrics and health monitoring

## Documentation Status

### ✅ Fully Documented Roles

All 14 roles have complete documentation with:

- Overview and purpose
- Configuration variables
- Usage examples
- Dependencies
- Tags for selective execution
- Example playbooks
- Troubleshooting guides
- See Also section with cross-references

### 📋 Deprecated/Experimental Roles

These roles are no longer recommended:

**Consolidation Note (Phase 4.8):**

Legacy `hpc-base-packages` and `cloud-base-packages` roles have been merged into the unified `base-packages` role.
Migration guide in `base-packages/README.md`.

## Role Usage Patterns

### Basic Pattern: Single Role in Playbook

```yaml
- hosts: gpu_nodes
  become: true
  roles:
    - nvidia-gpu-drivers
  vars:
    nvidia_install_cuda: true
```

### Advanced Pattern: Role Dependencies

```yaml
- hosts: hpc_controllers
  become: true
  roles:
    - base-packages
    - slurm-controller
    - monitoring-stack
```

### Component Combination Pattern

```yaml
- hosts: hpc_compute
  become: true
  roles:
    - base-packages
    - nvidia-gpu-drivers
    - slurm-compute
    - beegfs-client
  vars:
    nvidia_install_cuda: true
```

## Role Structure

Each role follows the standard Ansible role structure:

```text
role-name/
├── defaults/           # Default variables
├── tasks/              # Main role tasks
├── templates/          # Jinja2 template files
├── handlers/           # Event handlers
├── README.md           # Role documentation
└── meta/               # Role metadata (if needed)
```

## Role Documentation Standards

Each role includes comprehensive `README.md` with:

- **Status**: Implementation status (Complete, In Progress, TODO)
- **Overview**: Role purpose and capabilities
- **Purpose**: What the role does and why
- **Variables**: All configurable variables with defaults
- **Usage**: Basic and advanced usage examples
- **Dependencies**: Other roles or system requirements
- **Tags**: Available Ansible tags
- **Example Playbook**: Complete working example
- **Troubleshooting**: Common issues and solutions
- **See Also**: Cross-references to related roles

## Typical Deployment Order

For complete cluster deployments, deploy roles in this order:

1. **Base Infrastructure**: `base-packages` (supports both HPC and cloud profiles)
2. **Storage Setup**: `beegfs-mgmt`, `beegfs-meta`, `beegfs-storage`
3. **Client Configuration**: `beegfs-client`, `virtio-fs-mount`
4. **GPU Support**: `nvidia-gpu-drivers`
5. **Scheduler**: `slurm-controller`, `slurm-compute`
6. **Container Infrastructure**: `container-registry`, `container-runtime`
7. **Monitoring**: `monitoring-stack`
8. **Applications**: `ml-container-images`

## Best Practices

1. **Always specify become**: Most roles require `become: true`
2. **Check role documentation**: Each role's README has important details
3. **Test in development**: Run roles in development before production
4. **Use inventory groups**: Organize hosts by function
5. **Monitor role execution**: Use verbose output to verify execution
6. **Understand variables**: Each role has configurable defaults

## Common Variables

### Packer Build Mode

When building images with Packer, roles accept `*_packer_build` variable:

```yaml
nvidia_packer_build: true  # Suppresses reboot warnings during image build
```

### CUDA Installation

Roles supporting CUDA toolkit:

```yaml
nvidia_install_cuda: true  # Install CUDA alongside drivers
```

### Debugging

Use standard Ansible verbosity levels:

```bash
ansible-playbook playbook.yml       # Standard
ansible-playbook -v playbook.yml    # Verbose
ansible-playbook -vv playbook.yml   # More verbose
ansible-playbook -vvv playbook.yml  # Debug level
```

## See Also

- **[../README.md](../README.md)** - Main Ansible directory overview
- **[../playbooks/README.md](../playbooks/README.md)** - Playbook usage and examples
- Individual role READMEs - Detailed role-specific documentation
