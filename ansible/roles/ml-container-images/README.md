# ML Container Images Role

**Status:** TODO  
**Last Updated:** 2025-10-21

## Overview

This role manages machine learning container images for HPC clusters. It handles image building, registry setup, and
container validation for distributed ML workloads with GPU support.

## Purpose

The ML Container Images role provides:

- Container image configuration for ML workloads
- PyTorch with CUDA support
- MPI integration for distributed training
- Container registry path management
- Build optimization with caching and parallel builds

## Variables

### Container Image Configuration

```yaml
# Base container image (default: NVIDIA CUDA 12.1 on Ubuntu 22.04)
container_image_base: "nvidia/cuda:12.1-devel-ubuntu22.04"

# Python version for ML frameworks
container_image_python_version: "3.10"
```

### PyTorch Configuration

```yaml
# PyTorch version
pytorch_version: "2.0.0"

# CUDA version for PyTorch
pytorch_cuda_version: "cu121"
```

### MPI Configuration

```yaml
# MPI implementation (openmpi or mpich)
mpi_type: "openmpi"

# MPI version
mpi_version: "4.1.4"

# Enable PMIx support for MPI
mpi_pmix_enabled: true
```

### Container Registry Configuration

```yaml
# Path to container storage
container_registry_path: "/opt/containers"

# File permissions for container directory
container_registry_permissions: "755"

# Owner and group for container directory
container_registry_owner: "root"
container_registry_group: "slurm"
```

### Build Configuration

```yaml
# Enable build caching for faster rebuilds
container_build_cache: true

# Enable parallel builds
container_build_parallel: true

# Build timeout in seconds
container_build_timeout: 3600
```

## Dependencies

- Container runtime (Docker or Apptainer)
- NVIDIA GPU drivers (for GPU-enabled containers)
- Container registry role (for image distribution)

## Usage

### Basic Usage

```yaml
- hosts: ml_nodes
  become: true
  roles:
    - ml-container-images
```

### Custom Configuration

```yaml
- hosts: ml_nodes
  become: true
  roles:
    - role: ml-container-images
      vars:
        pytorch_version: "2.1.0"
        pytorch_cuda_version: "cu121"
        mpi_type: "openmpi"
        container_build_parallel: true
```

### With GPU Support

```yaml
- hosts: gpu_nodes
  become: true
  roles:
    - nvidia-gpu-drivers
    - container-runtime
    - ml-container-images
  vars:
    nvidia_install_cuda: true
```

## Implementation Status

This role is currently a placeholder with basic variable definitions. Full implementation will include:

- [ ] Container image building automation
- [ ] PyTorch installation with CUDA support
- [ ] MPI integration for distributed training
- [ ] Container registry setup and configuration
- [ ] Image validation and testing
- [ ] Multi-node container orchestration
- [ ] Integration with SLURM for job submission
- [ ] Container image caching and optimization

## Example Playbook

```yaml
---
- name: Configure ML Container Images
  hosts: ml_cluster
  become: true
  
  roles:
    - hpc-base-packages
    - nvidia-gpu-drivers
    - container-runtime
    - ml-container-images
  
  vars:
    # NVIDIA GPU configuration
    nvidia_install_cuda: true
    
    # ML container configuration
    pytorch_version: "2.0.0"
    pytorch_cuda_version: "cu121"
    mpi_type: "openmpi"
    mpi_pmix_enabled: true
    
    # Build optimization
    container_build_cache: true
    container_build_parallel: true
```

## Integration with Other Roles

### Container Registry

```yaml
- hosts: registry_server
  roles:
    - container-registry
    
- hosts: ml_nodes
  roles:
    - ml-container-images
  vars:
    container_registry_url: "registry.hpc.local:5000"
```

### SLURM Integration

```yaml
- hosts: hpc_compute
  roles:
    - slurm-compute
    - ml-container-images
  vars:
    container_registry_group: "slurm"
```

## Typical ML Workload Stack

1. **Base Infrastructure**: `hpc-base-packages`
2. **GPU Support**: `nvidia-gpu-drivers`
3. **Container Runtime**: `container-runtime`
4. **ML Images**: `ml-container-images`
5. **Job Scheduler**: `slurm-compute`

## Troubleshooting

### Container Build Failures

Check build dependencies and CUDA compatibility:

```bash
# Verify NVIDIA driver and CUDA
nvidia-smi

# Check container runtime
docker --version
# or
apptainer --version
```

### Permission Issues

Ensure proper permissions for container registry:

```bash
# Check permissions
ls -ld /opt/containers

# Fix if needed
chmod 755 /opt/containers
chown root:slurm /opt/containers
```

### MPI Integration Issues

Verify MPI and PMIx installation:

```bash
# Check MPI
mpirun --version

# Check PMIx
pmix_info
```

## Related Documentation

- [Container Runtime Role](../container-runtime/README.md)
- [Container Registry Role](../container-registry/README.md)
- [NVIDIA GPU Drivers Role](../nvidia-gpu-drivers/README.md)
- [SLURM Compute Role](../slurm-compute/README.md)

## References

- [NVIDIA NGC Containers](https://catalog.ngc.nvidia.com)
- [PyTorch Docker Images](https://hub.docker.com/r/pytorch/pytorch)
- [Open MPI Documentation](https://www.open-mpi.org/)
- [Apptainer User Guide](https://apptainer.org/docs/user/latest/)
