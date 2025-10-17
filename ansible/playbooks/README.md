# Ansible Playbooks

**Status:** TODO  
**Last Updated:** 2025-01-27

## Overview

This directory contains Ansible playbooks for deploying and configuring HPC infrastructure components.
Playbooks orchestrate multiple roles to achieve complete system configurations.

## Available Playbooks

### Infrastructure Playbooks

- **playbook-cloud.yml**: Base cloud infrastructure setup
- **playbook-hpc.yml**: Complete HPC cluster deployment
- **playbook-hpc-controller.yml**: SLURM controller node configuration
- **playbook-hpc-compute.yml**: SLURM compute node configuration

### Component-Specific Playbooks

- **playbook-container-registry.yml**: Container registry deployment
- **playbook-monitoring-stack.yml**: Monitoring infrastructure setup

### Runtime Configuration Playbooks

- **playbook-cgroup-runtime-config.yml**: Cgroup configuration
- **playbook-container-validation-runtime-config.yml**: Container validation setup
- **playbook-dcgm-runtime-config.yml**: DCGM GPU monitoring configuration
- **playbook-gres-runtime-config.yml**: GPU resource configuration
- **playbook-job-scripts-runtime-config.yml**: Job script templates
- **playbook-slurm-compute-runtime-config.yml**: SLURM compute node runtime config
- **playbook-virtio-fs-runtime-config.yml**: Virtio-FS shared storage configuration

## Usage

Run playbooks using the `ansible-playbook` command:

```bash
# Deploy complete HPC cluster
ansible-playbook -i inventory/hosts playbook-hpc.yml

# Configure specific component
ansible-playbook -i inventory/hosts playbook-container-registry.yml
```

## Inventory

Playbooks require a properly configured inventory file with host groups and variables. See the `inventories/`
directory for examples.

## Variables

Each playbook supports various configuration variables. Check individual playbook files for available options and defaults.
