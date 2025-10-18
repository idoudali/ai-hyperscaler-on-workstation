# Ansible Roles

**Status:** TODO  
**Last Updated:** 2025-01-27

## Overview

This directory contains Ansible roles for configuring HPC infrastructure components. Each role is responsible
for a specific aspect of the system configuration.

## Available Roles

### Core Infrastructure Roles

- **cloud-base-packages**: Installs base packages for cloud instances
- **hpc-base-packages**: Installs HPC-specific packages and dependencies
- **container-runtime**: Configures container runtime (Docker/Apptainer)
- **container-registry**: Sets up container registry for image distribution

### HPC Components

- **slurm-controller**: Configures SLURM controller node (uses pre-built packages)
- **slurm-compute**: Configures SLURM compute nodes (uses pre-built packages)
- **nvidia-gpu-drivers**: Installs and configures NVIDIA GPU drivers
- **virtio-fs-mount**: Configures Virtio-FS for shared storage

**Note**: SLURM roles install from pre-built packages in `build/packages/slurm/`. Build packages first with:
`make run-docker COMMAND="cmake --build build --target build-slurm-packages"`

### Monitoring and ML

- **monitoring-stack**: Deploys Prometheus, Grafana, and related monitoring tools
- **ml-container-images**: Manages machine learning container images

## Usage

Each role can be used independently or as part of a playbook. See individual role directories for specific
configuration options and examples.

## Role Structure

Each role follows the standard Ansible role structure:

- `defaults/`: Default variables
- `tasks/`: Main tasks
- `templates/`: Jinja2 templates
- `handlers/`: Event handlers
- `README.md`: Role-specific documentation

## Dependencies

Roles may depend on other roles. Check individual role documentation for specific requirements.
