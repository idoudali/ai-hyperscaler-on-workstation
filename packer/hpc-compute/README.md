# HPC Compute Image

**Status:** Production  
**Last Updated:** 2025-10-19

## Overview

The HPC Compute image is a specialized Debian 13-based VM image designed to serve as a SLURM compute node with GPU
support. It provides job execution capabilities, GPU acceleration, container runtime, and monitoring for HPC workloads.

> **Note**: For common build system information, prerequisites, and troubleshooting, see the
> [main Packer README](../README.md).

## Compute-Specific Components

This image includes components specific to GPU-accelerated compute workloads:

### SLURM Compute Services

- **slurmd**: Job execution daemon
- **GRES Support**: GPU resource scheduling and allocation
- **cgroup Configuration**: GPU isolation and resource management

### GPU Support

- **NVIDIA Drivers**: Latest data center drivers (no CUDA in base image)
- **MIG Support**: Multi-Instance GPU for A100/H100
- **GPU Passthrough Ready**: Configured for PCI device passthrough
- **Container GPU Integration**: NVIDIA container toolkit compatibility

### Compute-Optimized Features

- **OpenMPI**: High-performance distributed computing
- **PMI Support**: SLURM process management interface
- **BeeGFS Client**: Parallel file system access
- **Apptainer**: GPU-aware container runtime
- **GPU Metrics**: DCGM exporter for monitoring

## Image Specifications

### Base Configuration

- **Base OS**: Debian 13 (Trixie) Cloud Image
- **Format**: QCOW2 (compressed)
- **Default Disk Size**: 30GB (configurable)
- **Default Memory**: 8192MB (build-time only)
- **Default CPUs**: 8 cores (build-time only)
- **Typical Size**: ~2.2GB compressed

### Installed Components

- **SLURM Version**: 23.11.4 (compute daemon with GRES support)
- **NVIDIA Drivers**: Data center drivers (latest, no CUDA)
- **OpenMPI**: With PMI support for SLURM
- **Apptainer**: Version 1.4.2 with GPU integration
- **BeeGFS**: Client only
- **Monitoring**: Node Exporter + DCGM for GPU metrics

For detailed component information, see the [main Packer README](../README.md#image-specifications).

## Build Process

The compute image follows the [standard Packer build process](../README.md#common-build-process) with
compute-specific Ansible provisioning:

```text
Ansible roles applied:
- hpc-base-packages: Core HPC packages and MPI
- container-runtime: Apptainer with GPU support
- monitoring-stack: Node Exporter + GPU metrics
- nvidia-gpu-drivers: GPU driver installation
- slurm-compute: SLURM compute daemon + GRES
```

**BeeGFS Packages**: Client only  
**GPU Preparation**: NVIDIA driver installation and MIG support

## Build Commands

### Quick Build

```bash
# From project root
make run-docker COMMAND="cmake --build build --target build-hpc-compute-image"
```

### Step-by-Step Build

```bash
# Initialize Packer plugins
make run-docker COMMAND="cmake --build build --target init-hpc-compute-packer"

# Validate template
make run-docker COMMAND="cmake --build build --target validate-hpc-compute-packer"

# Build the image
make run-docker COMMAND="cmake --build build --target build-hpc-compute-image"
```

### Alternative: From Inside Container

```bash
# Enter container shell
make shell-docker

# Inside container, build directly
cmake --build build --target build-hpc-compute-image
```

For general build system information, prerequisites, and advanced options, see the
[main Packer README](../README.md#build-system).

## Build Variables

### Compute-Specific Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `disk_size` | 20G | Virtual disk size for compute |
| `memory` | 2048 | Build VM memory (MB) |
| `cpus` | 2 | Build VM CPU cores |
| `image_name` | hpc-compute | Image identifier |
| `vm_name` | hpc-compute.qcow2 | Output filename |

For common build variables (repository paths, SSH keys, cloud-init), see the
[main Packer README](../README.md#build-variables).

## Build Output

Built image location:

```text
build/packer/hpc-compute/hpc-compute/hpc-compute.qcow2
```

Build artifacts and metadata:

```text
build/packer/hpc-compute/
├── hpc-compute/             # Output directory
│   └── hpc-compute.qcow2    # Main image (~2.2GB compressed)
└── qemu-serial.log          # Build console output
```

For verification commands and full output structure, see the
[main Packer README](../README.md#build-output).

## Usage

### Recommended Runtime Resources

| Resource | Minimum | Recommended | GPU Workloads |
|----------|---------|-------------|---------------|
| Memory | 16GB | 32GB+ | 64GB+ |
| CPUs | 8 | 16+ | 32+ |
| Disk | 50GB | 100GB+ | 200GB+ |

### GPU Passthrough Configuration

```yaml
clusters:
  hpc:
    compute_nodes:
      - name: hpc-compute-01
        base_image_path: "build/packer/hpc-compute/hpc-compute/hpc-compute.qcow2"
        memory: 65536
        cpus: 16
        disk_size: 100G
        gpu:
          passthrough: true
          pci_devices:
            - "0000:01:00.0"  # GPU device
            - "0000:02:00.0"  # Additional GPU
```

**Important**: GPU passthrough requires:

- Host IOMMU enabled (`intel_iommu=on` or `amd_iommu=on`)
- GPU bound to `vfio-pci` driver on host
- Proper PCI device isolation

For deployment commands and manual VM creation, see the
[main Packer README](../README.md#common-usage-patterns).

## Runtime Configuration

After deploying the compute VM, configure SLURM, GPU resources, and storage. See component-specific documentation:

### SLURM Compute Configuration

For SLURM compute daemon setup and GRES configuration:

- [SLURM Compute Role](../../ansible/roles/slurm-compute/README.md)
- **TODO**: Create SLURM GRES Configuration guide - SLURM GRES configuration

### GPU Configuration

For NVIDIA driver configuration, MIG setup, and GPU resource management:

- [NVIDIA GPU Drivers Role](../../ansible/roles/nvidia-gpu-drivers/README.md)
- **TODO**: Create GPU Configuration Guide - GPU setup and configuration
- **TODO**: Create MIG Configuration Guide - Multi-Instance GPU setup

**Quick GPU verification:**

```bash
# Verify GPU is visible
nvidia-smi

# Check MIG status
nvidia-smi -L
```

### BeeGFS Client Configuration

For BeeGFS client setup, see the [main Packer README](../README.md#common-usage-patterns).

### Container GPU Configuration

For Apptainer GPU integration and containerized workloads:

- [Container Runtime Role](../../ansible/roles/container-runtime/README.md)
- **TODO**: Create GPU Containers Guide - GPU container usage

**Quick container test:**

```bash
# Test GPU access in container
apptainer exec --nv docker://nvidia/cuda:12.0-base nvidia-smi
```

## GPU Workloads

For detailed SLURM GPU job submission, GRES usage, and job script examples:

- **TODO**: Create SLURM GPU Jobs Guide - SLURM GPU job submission
- **TODO**: Create GPU Workload Examples - GPU workload examples

### Quick GPU Job Submission

```bash
# Submit GPU job
sbatch --gres=gpu:1 gpu_job.sh

# Submit MIG partition job
sbatch --gres=gpu:a100-1g.5gb:1 mig_job.sh

# Interactive GPU session
srun --gres=gpu:1 --pty bash
```

See the guides above for complete job script examples and best practices.

## Customization

### Compute-Specific Ansible Roles

- `nvidia-gpu-drivers`: Edit GPU driver configuration and version
- `slurm-compute`: Modify SLURM compute daemon and GRES settings

```bash
# Edit compute playbook
vim ansible/playbooks/playbook-hpc-compute.yml

# Edit GPU drivers role
vim ansible/roles/nvidia-gpu-drivers/tasks/main.yml

# Rebuild image
make run-docker COMMAND="cmake --build build --target build-hpc-compute-image"
```

### CUDA Installation

By default, CUDA is **NOT** included (use containerized CUDA instead):

**Rationale**:

- Different workloads need different CUDA versions
- CUDA toolkit adds 3-5GB to image size
- Containerized CUDA is easier to update and more flexible

To enable CUDA in base image (not recommended):

```bash
# Edit playbook
vim ansible/playbooks/playbook-hpc-compute.yml
# Change: nvidia_install_cuda: false → nvidia_install_cuda: true
```

For general customization (packages, cloud-init, disk size), see the
[main Packer README](../README.md#advanced-usage).

## Troubleshooting

For common build issues (SSH timeout, disk space, BeeGFS packages), see the
[main Packer README troubleshooting section](../README.md#common-troubleshooting).

### Compute-Specific Build Issues

#### GPU Driver Installation Fails

For GPU driver build issues and troubleshooting:

- [NVIDIA GPU Drivers Troubleshooting](../../ansible/roles/nvidia-gpu-drivers/README.md#troubleshooting)
- **TODO**: Create GPU Driver Issues Guide - Troubleshooting guide for GPU drivers

**Quick diagnostic:**

```bash
# Check driver role configuration
vim ansible/roles/nvidia-gpu-drivers/tasks/main.yml

# Review Ansible build logs for errors
```

### Runtime GPU Issues

For GPU runtime issues (visibility, drivers, MIG):

- **TODO**: Create GPU Runtime Troubleshooting Guide - Troubleshooting guide for GPU runtime
- **TODO**: Create MIG Troubleshooting Guide - Troubleshooting guide for MIG issues

**Quick diagnostics:**

```bash
# Check GPU visibility
nvidia-smi

# Verify driver module loaded
lsmod | grep nvidia

# Check GPU passthrough (on host)
virsh dumpxml hpc-compute-01 | grep hostdev

# Verify IOMMU enabled (on host)
dmesg | grep -i iommu
```

## Performance Tuning

For general performance optimization (build speed, image size reduction), see the
[main Packer README](../README.md#performance-tuning).

### GPU Performance Optimization

For detailed GPU performance tuning, power management, and MIG optimization:

- **TODO**: Create GPU Performance Guide - GPU performance optimization
- **TODO**: Create MIG Optimization Guide - MIG optimization

**Quick GPU tuning:**

```bash
# Enable persistence mode (recommended)
nvidia-smi -pm 1

# Set performance mode
nvidia-smi -ac <memory_clock>,<graphics_clock>
```

**MIG Profile Selection**: Choose based on workload requirements

- `1g.5gb`: Maximum sharing (7 instances on A100)
- `2g.10gb`: Balanced
- `3g.20gb`: Higher performance
- `7g.40gb`: Full GPU

## Design Decisions

### No CUDA in Base Image

CUDA libraries are intentionally **NOT** included:

1. **Flexibility**: Different workloads need different CUDA versions (9.x through 12.x)
2. **Size**: CUDA toolkit adds 3-5GB per version to image
3. **Updates**: Containerized CUDA updates don't require image rebuilds
4. **Compatibility**: Containers provide better version management

**Recommendation**: Use containerized CUDA with Apptainer (`--nv` flag)

### Data Center GPU Drivers

Latest stable NVIDIA data center drivers are installed:

- **Forward Compatibility**: Supports newer CUDA versions in containers
- **Stability**: Production-grade drivers for reliability
- **MIG Support**: Full Multi-Instance GPU on A100/H100
- **Long-term Support**: Extended maintenance and updates

### BeeGFS Client Only

Compute nodes include BeeGFS client, not management services:

- **Parallel Access**: Distributed file system optimized for HPC
- **Scalability**: Performance scales with compute node count
- **Shared Storage**: All nodes access controller's BeeGFS services

## Related Documentation

### Compute-Specific

- **GPU Drivers**: [ansible/roles/nvidia-gpu-drivers/README.md](../../ansible/roles/nvidia-gpu-drivers/README.md)
- **SLURM Compute**: [ansible/roles/slurm-compute/README.md](../../ansible/roles/slurm-compute/README.md)
- **Container Runtime**: [ansible/roles/container-runtime/README.md](../../ansible/roles/container-runtime/README.md)

### General

- **Build System**: [packer/README.md](../README.md) - Build process, troubleshooting, customization
- **HPC Controller**: [hpc-controller/README.md](../hpc-controller/README.md) - Controller node image
- **HPC Base**: [hpc-base/README.md](../hpc-base/README.md) - Shared architecture
- **ai-how CLI**: [python/ai_how/README.md](../../python/ai_how/README.md) - Deployment tools

## GPU Reference

For comprehensive GPU hardware specifications, MIG profiles, and monitoring:

- **TODO**: Create Supported GPU Hardware Reference - Supported GPU hardware
- **TODO**: Create MIG Profiles Reference - MIG profiles
- **TODO**: Create GPU Monitoring Guide - GPU monitoring

### Quick References

**Supported GPU Types**: A100 (MIG), H100 (MIG), A30 (MIG), T4, V100

**Common MIG Profiles** (A100):

- `1g.5gb`: 7 instances × 5GB
- `2g.10gb`: 3 instances × 10GB
- `3g.20gb`: 2 instances × 20GB
- `7g.40gb`: Full GPU (40GB)

**GPU Monitoring**:

```bash
# Real-time monitoring
watch -n 1 nvidia-smi

# Prometheus metrics (DCGM exporter)
curl http://localhost:9400/metrics | grep dcgm
```
