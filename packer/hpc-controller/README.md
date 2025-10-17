# HPC Controller Image

**Status:** TODO  
**Last Updated:** 2025-01-27

## Overview

This Packer template creates an HPC controller image with SLURM controller and management services.

## Purpose

The HPC controller image provides:

- SLURM controller daemon
- Job scheduling and management
- User authentication (MUNGE)
- Network file system (NFS) server
- Monitoring and logging services
- Web-based management interfaces

## Build Process

The image is built using Packer with the following steps:

1. Start with HPC base image
2. Install SLURM controller components
3. Configure job scheduling
4. Set up authentication services
5. Configure monitoring
6. Create final image

## Usage

This image is used to deploy:

- SLURM controller nodes
- Cluster management nodes
- Job submission nodes

## Configuration

Key configuration options:

- **SLURM version**: Configurable via variables
- **Database backend**: MySQL/PostgreSQL
- **Authentication**: MUNGE key management
- **Network**: Controller network configuration
- **Storage**: Shared storage setup

## Build Commands

```bash
# Build the controller image
packer build hpc-controller.pkr.hcl

# Build with custom variables
packer build -var="slurm_version=23.02" hpc-controller.pkr.hcl
```

## Dependencies

- HPC base image
- Ansible roles: slurm-controller, monitoring-stack
- Database configuration

## Output

The build process creates a machine image ready for SLURM controller deployment.
