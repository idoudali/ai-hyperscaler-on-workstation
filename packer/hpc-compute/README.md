# HPC Compute Image

**Status:** TODO  
**Last Updated:** 2025-01-27

## Overview

This Packer template creates an HPC compute image with SLURM compute node and GPU support.

## Purpose

The HPC compute image provides:

- SLURM compute daemon
- GPU drivers and CUDA support
- Container runtime (Docker/Apptainer)
- Job execution environment
- Monitoring and telemetry
- Shared storage access

## Build Process

The image is built using Packer with the following steps:

1. Start with HPC base image
2. Install SLURM compute components
3. Configure GPU drivers and CUDA
4. Set up container runtime
5. Configure job execution environment
6. Set up monitoring
7. Create final image

## Usage

This image is used to deploy:

- SLURM compute nodes
- GPU-enabled compute nodes
- Container execution nodes

## Configuration

Key configuration options:

- **GPU support**: NVIDIA drivers and CUDA
- **Container runtime**: Docker/Apptainer configuration
- **SLURM version**: Compute node version
- **Network**: Compute network configuration
- **Storage**: Shared storage access

## Build Commands

```bash
# Build the compute image
packer build hpc-compute.pkr.hcl

# Build with GPU support
packer build -var="enable_gpu=true" hpc-compute.pkr.hcl
```

## Dependencies

- HPC base image
- Ansible roles: slurm-compute, nvidia-gpu-drivers, container-runtime
- GPU driver configuration

## Output

The build process creates a machine image ready for SLURM compute node deployment.
