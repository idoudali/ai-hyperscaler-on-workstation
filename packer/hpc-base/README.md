# HPC Base Image

**Status:** Foundation Image (Not Directly Built)  
**Last Updated:** 2025-10-19

## Overview

The HPC Base image concept represents the foundational layer of software packages and configurations shared across all
HPC images (controller and compute). Rather than being a separate Packer template, the "base" functionality is
implemented through shared Ansible roles and playbooks.

## Architecture

This project uses a **shared role-based approach** instead of a traditional base image hierarchy:

```text
Debian 13 Cloud Image (Base)
         ↓
    [Ansible Roles Apply]
         ↓
    ┌────┴────┐
    ↓         ↓
Controller  Compute
```

## Shared Base Components

All HPC images share these foundational components:

### Operating System

- **Base Image**: Debian 13 (Trixie) Cloud Image
- **Release**: 20250806-2196
- **Format**: QCOW2
- **Source**: <https://cloud.debian.org/images/cloud/trixie/>

### Core Packages (via `hpc-base-packages` role)

The `hpc-base-packages` Ansible role provides:

- **Development Tools**: build-essential, gcc, g++, gfortran, make, cmake
- **System Utilities**: curl, wget, vim, htop, tmux, screen
- **Network Tools**: NetworkManager, iproute2, netcat, tcpdump
- **Storage Tools**: nfs-common, cifs-utils
- **Python Environment**: python3, pip, virtualenv
- **Version Control**: git
- **HPC Libraries**: OpenMPI, PMI libraries, InfiniBand tools (if available)

### Container Runtime

- **Runtime**: Apptainer 1.4.2 (successor to Singularity)
- **Installation**: From GitHub releases
- **Purpose**: Run containerized HPC workloads
- **Configuration**: Rootless and fakeroot support enabled

### Shared Storage Support

- **BeeGFS Client**: Parallel file system client
- **NFS Support**: Network File System utilities
- **Configuration**: Prepared for shared storage setup at runtime

### Monitoring

- **Node Exporter**: Prometheus metrics exporter
- **Configuration**: Exports system metrics to Prometheus
- **Port**: 9100 (default)

## Why No Separate Base Image?

The project deliberately **does not build a separate base image** for these reasons:

1. **Simplicity**: Fewer images to manage and maintain
2. **Consistency**: Same base OS for all images (Debian cloud image)
3. **Flexibility**: Roles can be updated independently without rebuilding base
4. **Speed**: Parallel builds without base image dependency
5. **Storage**: One fewer large image to store

Instead, shared functionality is implemented through:

- **Shared Ansible roles** (e.g., `hpc-base-packages`, `container-runtime`, `monitoring-stack`)
- **Common cloud-init configurations**
- **Shared provisioning scripts**

## Build Integration

The base functionality is applied during each image build:

### HPC Controller Build

```hcl
# In hpc-controller.pkr.hcl
provisioner "ansible" {
  playbook_file = "playbooks/playbook-hpc-controller.yml"
  # Includes: hpc-base-packages, container-runtime, monitoring-stack
}
```

### HPC Compute Build

```hcl
# In hpc-compute.pkr.hcl
provisioner "ansible" {
  playbook_file = "playbooks/playbook-hpc-compute.yml"
  # Includes: hpc-base-packages, container-runtime, monitoring-stack, nvidia-gpu-drivers
}
```

## Customization

To customize the base functionality shared by all images:

### 1. Modify the `hpc-base-packages` Role

```bash
# Edit the role variables
vim ../ansible/roles/hpc-base-packages/defaults/main.yml

# Edit package lists
vim ../ansible/roles/hpc-base-packages/tasks/main.yml
```

### 2. Update Container Runtime Configuration

```bash
# Edit container runtime role
vim ../ansible/roles/container-runtime/defaults/main.yml

# Adjust Apptainer version or configuration
vim ../ansible/roles/container-runtime/tasks/main.yml
```

### 3. Modify Shared Scripts

```bash
# Edit controller setup script
vim ../packer/hpc-controller/setup-hpc-controller.sh

# Edit compute setup script
vim ../packer/hpc-compute/setup-hpc-compute.sh
```

## Testing Base Functionality

To verify base packages are installed correctly on any image:

```bash
# Launch a VM with the image
virsh start <vm-name>

# Connect to the VM
ssh user@<vm-ip>

# Verify core tools
which python3 gcc cmake git

# Verify container runtime
apptainer --version

# Verify monitoring
systemctl status node_exporter

# Verify MPI
mpirun --version
```

## Related Documentation

- **HPC Controller Image**: See [hpc-controller/README.md](../hpc-controller/README.md)
- **HPC Compute Image**: See [hpc-compute/README.md](../hpc-compute/README.md)
- **Ansible Roles**: See [ansible/roles/README.md](../../ansible/roles/README.md)
- **Build System**: See [packer/README.md](../README.md)

## Design Rationale

This architectural decision favors:

- **Simplicity over optimization**: Slightly longer builds but simpler management
- **Flexibility over efficiency**: Easy to update components without cascading rebuilds
- **Maintainability over build time**: Clear separation of concerns in Ansible roles

For projects requiring faster iteration, consider creating a separate base image with the
`hpc-base-packages` role pre-applied.
