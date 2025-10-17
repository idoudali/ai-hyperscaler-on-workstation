# HPC Base Image

**Status:** TODO  
**Last Updated:** 2025-01-27

## Overview

This Packer template creates a base HPC image with essential packages and configurations for HPC workloads.

## Purpose

The HPC base image provides:

- Base operating system (Ubuntu)
- Essential HPC packages and libraries
- Common development tools
- Network and storage configurations
- Security hardening

## Build Process

The image is built using Packer with the following steps:

1. Launch base cloud instance
2. Install HPC packages via Ansible
3. Configure system settings
4. Create final image

## Usage

This base image is used as the foundation for:

- HPC Controller images
- HPC Compute images
- Custom workload images

## Configuration

Key configuration options:

- **Instance type**: Configurable via variables
- **Region**: Set in Packer variables
- **Base image**: Ubuntu LTS
- **Ansible roles**: hpc-base-packages, cloud-base-packages

## Build Commands

```bash
# Build the base image
packer build hpc-base.pkr.hcl

# Build with custom variables
packer build -var="instance_type=t3.large" hpc-base.pkr.hcl
```

## Output

The build process creates a machine image that can be used to launch HPC instances.
