# Ansible Roles Index

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This directory contains 14 Ansible roles for configuring HPC infrastructure components. Each
role is responsible for a specific aspect of the system configuration and can be used
independently or as part of playbooks.

## Role Categories

### 1. Base Infrastructure Roles

These roles provide foundational system configuration for both HPC and cloud deployments.

| Role | Purpose | Use Case |
|------|---------|----------|
| **[base-packages](./base-packages/README.md)** | Consolidated base package installation (HPC and cloud) | All deployment types |
| ~~**[hpc-base-packages](./hpc-base-packages/README.md)**~~ | ~~Installs HPC-specific packages~~ | ~~DEPRECATED - Use base-packages~~ |
| ~~**[cloud-base-packages](./cloud-base-packages/README.md)**~~ | ~~Installs base packages for cloud instances~~ | ~~DEPRECATED - Use base-packages~~ |
| **[container-runtime](./container-runtime/README.md)** | Configures container runtime (Docker/Apptainer) | Nodes requiring container support |

### 2. Storage Roles (BeeGFS)

BeeGFS distributed storage configuration for high-performance parallel file systems.

| Role | Purpose | Use Case |
|------|---------|----------|
| **[beegfs-mgmt](./beegfs-mgmt/README.md)** | BeeGFS management node | Primary storage management |
| **[beegfs-meta](./beegfs-meta/README.md)** | BeeGFS metadata node | Distributed metadata storage |
| **[beegfs-storage](./beegfs-storage/README.md)** | BeeGFS storage node | Data storage targets |
| **[beegfs-client](./beegfs-client/README.md)** | BeeGFS client mounting | Compute nodes accessing shared storage |

**BeeGFS Documentation:**
Each BeeGFS role includes its own `README.md` with detailed configuration options and variables.

### 3. HPC Scheduler Roles (SLURM)

SLURM cluster scheduler configuration for job orchestration and resource management.

| Role | Purpose | Use Case |
|------|---------|----------|
| **[slurm-controller](./slurm-controller/README.md)** | Configures SLURM controller/head node | Job scheduler management |
| **[slurm-compute](./slurm-compute/README.md)** | Configures SLURM compute nodes | Job execution nodes |

**Key Features:**

- Job scheduling and resource management
- User account and group configuration
- Integration with GPU and storage resources
- Monitoring and accounting setup

**Important Note:** SLURM roles install from pre-built packages in `build/packages/slurm/`. Build packages first with:

```bash
make run-docker COMMAND="cmake --build build --target build-slurm-packages"
```

### 4. GPU Support Roles

NVIDIA GPU driver and toolkit installation for GPU-accelerated computing.

| Role | Purpose | Features |
|------|---------|----------|
| **[nvidia-gpu-drivers/README.md](./nvidia-gpu-drivers/README.md)** | NVIDIA GPU driver installation | Auto-detection, CUDA support, multiple Debian versions |

Key capabilities:

- Automatic GPU detection with `nvidia-detect`
- Support for multiple Debian versions (Trixie, Bookworm, Bullseye)
- Tesla datacenter GPU support
- CUDA toolkit installation (optional)
- Proper nouveau driver blacklisting

### 5. Container Management Roles

Container registry and image management for distributed deployment.

| Role | Purpose | Use Case |
|------|---------|----------|
| **[container-registry](./container-registry/README.md)** | Container registry server setup | Image storage and distribution |
| **[ml-container-images](./ml-container-images/README.md)** | ML container image management | ML workload container provisioning |

### 6. Storage Mounting Roles

Specialized storage configuration for shared file systems.

| Role | Purpose | Use Case |
|------|---------|----------|
| **[virtio-fs-mount](./virtio-fs-mount/README.md)** | Virtio-FS configuration | VM-based workload shared storage |

### 7. Monitoring Roles

Comprehensive monitoring infrastructure with metrics collection and visualization.

| Role | Purpose | Components |
|------|---------|------------|
| **[monitoring-stack](./monitoring-stack/README.md)** | Complete monitoring infrastructure | Prometheus, Grafana, node-exporter, DCGM |

**Monitoring Stack Components:**

- **Prometheus**: Metrics collection and storage
- **Grafana**: Metrics visualization and dashboards
- **node-exporter**: Host system metrics
- **DCGM** (NVIDIA DCGM): GPU metrics and health monitoring

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
├── defaults/           # Default variables (role defaults)
├── tasks/              # Main role tasks (main.yml + optional subtasks)
├── templates/          # Jinja2 template files
├── handlers/           # Event handlers (service restarts, etc.)
├── README.md           # Role-specific documentation
└── meta/               # Role metadata and dependencies (if any)
```

### Optional Directories

Roles may include additional directories as needed:

- `vars/`: Static variables (less commonly used than defaults)
- `files/`: Static files to copy to target systems
- `meta/main.yml`: Role dependencies and metadata

## Role Documentation Standards

Each role should include comprehensive `README.md` with:

- **Status**: Implementation status (Complete, In Progress, TODO)
- **Overview**: Role purpose and capabilities
- **Purpose**: What the role does and why
- **Variables**: All configurable variables with defaults
- **Usage**: Basic and advanced usage examples
- **Dependencies**: Other roles or system requirements
- **Tags**: Available Ansible tags for selective execution
- **Example Playbook**: Complete working example
- **Troubleshooting**: Common issues and solutions

## Finding Role Documentation

### Complete Role Listing

- **[container-registry/README.md](./container-registry/README.md)** - Container registry setup
- **[nvidia-gpu-drivers/README.md](./nvidia-gpu-drivers/README.md)** - GPU driver installation

### Documentation in Development

The following roles have base documentation and are being enhanced:

- `beegfs-mgmt/`
- `beegfs-meta/`
- `beegfs-storage/`
- `beegfs-client/`
- `slurm-controller/`
- `slurm-compute/`
- `monitoring-stack/`
- `ml-container-images/`
- `base-packages/`
- `cloud-base-packages/`
- `container-runtime/`
- `virtio-fs-mount/`

## Common Variables Used Across Roles

### Packer Build Mode

When building images with Packer, certain roles accept a `*_packer_build` variable:

```yaml
nvidia_packer_build: true  # Suppresses reboot warnings during image build
```

### CUDA Installation

Roles supporting CUDA toolkit:

```yaml
nvidia_install_cuda: true  # Install CUDA toolkit alongside drivers
```

### Debugging and Logging

Most roles support Ansible's standard verbosity levels:

```bash
# Standard run
ansible-playbook playbook.yml

# Verbose output
ansible-playbook -v playbook.yml

# Extra verbose (variable values shown)
ansible-playbook -vv playbook.yml

# Debug level (all details)
ansible-playbook -vvv playbook.yml
```

## Role Dependencies and Integration

### Typical Deployment Order

For complete cluster deployments, roles should typically execute in this order:

1. **Base Infrastructure**: `base-packages`
2. **Storage Setup**: `beegfs-mgmt`, `beegfs-meta`, `beegfs-storage`
3. **Client Configuration**: `beegfs-client`, `virtio-fs-mount`
4. **GPU Support**: `nvidia-gpu-drivers`
5. **Scheduler**: `slurm-controller`, `slurm-compute`
6. **Container Infrastructure**: `container-registry`, `container-runtime`
7. **Monitoring**: `monitoring-stack`
8. **Applications**: `ml-container-images`

### Usage Examples

See [playbooks/README.md](../playbooks/README.md) for complete playbook examples that orchestrate these roles.

## Best Practices for Using Roles

1. **Always specify become**: Most roles require `become: true` for system-level changes
2. **Check role documentation**: Each role's README contains important configuration details
3. **Test in development**: Run roles in development before production deployment
4. **Use inventory groups**: Organize hosts by function (controllers, compute, storage, etc.)
5. **Monitor role execution**: Use verbose output to verify role execution
6. **Understand variables**: Each role has configurable defaults documented in its README

## Adding New Roles

When adding a new role, follow this checklist:

- [ ] Create role directory and subdirectories
- [ ] Implement `tasks/main.yml`
- [ ] Add `defaults/main.yml` for default variables
- [ ] Create comprehensive `README.md` following the template above
- [ ] Test role execution with sample playbook
- [ ] Update this index with new role information
- [ ] Ensure Ansible linting passes (`ansible-lint`)
- [ ] Document any special requirements or dependencies

## See Also

- **[../README.md](../README.md)** - Main Ansible directory overview
- **[../playbooks/README.md](../playbooks/README.md)** - Playbook usage and examples
- **Individual role READMEs** - Detailed role-specific documentation
