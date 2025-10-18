# Ansible Playbooks

**Status:** TODO  
**Last Updated:** 2025-01-27

## Overview

This directory contains Ansible playbooks for deploying and configuring HPC infrastructure components.
Playbooks orchestrate multiple roles to achieve complete system configurations.

## Available Playbooks

### HPC Core Playbooks (Consolidated)

- **playbook-hpc-packer-controller.yml**: HPC controller Packer image build
- **playbook-hpc-packer-compute.yml**: HPC compute Packer image build  
- **playbook-hpc-runtime.yml**: Unified HPC cluster runtime configuration

### Storage Infrastructure Playbooks (Optional)

- **playbook-beegfs-packer-install.yml**: BeeGFS Packer installation
- **playbook-beegfs-runtime-config.yml**: BeeGFS runtime configuration
- **playbook-virtio-fs-runtime-config.yml**: Virtio-FS shared storage configuration

### Cloud Infrastructure Playbooks

- **playbook-cloud.yml**: Base cloud infrastructure setup
- **playbook-container-registry.yml**: Container registry deployment

## Prerequisites

### Required: Build SLURM Packages

Before running HPC playbooks, you **MUST** build SLURM packages from source:

```bash
# 1. Configure CMake
make config

# 2. Build SLURM packages (required for Debian Trixie)
make run-docker COMMAND="cmake --build build --target build-slurm-packages"

# 3. Verify packages
ls -lh build/packages/slurm/
```

**Why?** Debian Trixie repositories lack complete SLURM packages. Pre-built packages ensure all components are
available with PMIx integration.

## Usage

Run playbooks using the `ansible-playbook` command:

```bash
# Deploy complete HPC cluster (runtime configuration)
ansible-playbook -i inventory/hosts playbook-hpc-runtime.yml

# Build HPC images with Packer (requires SLURM packages built first)
packer build packer/hpc-controller/hpc-controller.pkr.hcl
packer build packer/hpc-compute/hpc-compute.pkr.hcl

# Configure specific component
ansible-playbook -i inventory/hosts playbook-container-registry.yml
```

## Inventory

Playbooks require a properly configured inventory file with host groups and variables. See the `inventories/`
directory for examples.

## Variables

Each playbook supports various configuration variables. Check individual playbook files for available options and defaults.
