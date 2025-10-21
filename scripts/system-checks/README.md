# System Checks

**Status:** In Development
**Last Updated:** 2025-10-21

System validation scripts for verifying host system configuration, GPU hardware, and infrastructure readiness
for the Hyperscaler on a Workstation project.

## Overview

This directory contains scripts for validating system prerequisites and generating GPU inventory reports:

- **Prerequisites Validation**: Comprehensive checks for virtualization, GPU drivers, and system requirements
- **GPU Inventory**: Detailed GPU detection and PCIe passthrough configuration generation

## Available Scripts

### check_prereqs.sh

Comprehensive system prerequisite checker for validating host system readiness. Verifies all necessary requirements
for running virtualized HPC and Cloud environments.

**Capabilities:**

- CPU virtualization support (VT-x/AMD-V)
- IOMMU support (VT-d/AMD-Vi)
- KVM acceleration and kernel modules
- NVIDIA GPU and driver status
- Required software packages
- Python library dependencies
- System resources (RAM, disk, CPU)
- Conflicting services detection
- User group memberships (libvirt, kvm)

**Usage:**

```bash
# Run all checks
./scripts/system-checks/check_prereqs.sh all

# Run specific check
./scripts/system-checks/check_prereqs.sh cpu          # CPU virtualization
./scripts/system-checks/check_prereqs.sh iommu       # IOMMU support
./scripts/system-checks/check_prereqs.sh kvm         # KVM acceleration
./scripts/system-checks/check_prereqs.sh gpu         # GPU drivers
./scripts/system-checks/check_prereqs.sh packages    # Required packages
./scripts/system-checks/check_prereqs.sh python-deps # Python dependencies
./scripts/system-checks/check_prereqs.sh resources   # System resources
./scripts/system-checks/check_prereqs.sh conflicts   # Conflicting services
./scripts/system-checks/check_prereqs.sh groups      # User groups
```

**Output Format:**

```text
[SUCCESS] Check passed
[WARNING] Warning condition detected
[FAILURE] Failed requirement
[INFO] Informational message
```

**Exit Codes:**

- `0`: All checks passed
- `1`: Critical failures detected
- `2`: Warnings detected (system may work with reduced reliability)

### gpu_inventory.sh

Reports current GPU configuration and generates YAML snippets for cluster configuration. Detects both GPUs
attached to NVIDIA driver and those bound to vfio-pci for PCIe passthrough.

**Capabilities:**

- GPU detection via nvidia-smi and lspci
- MIG capability detection
- IOMMU group identification
- Associated sound device detection
- PCIe passthrough configuration generation
- YAML output for cluster configuration

**Usage:**

```bash
./scripts/system-checks/gpu_inventory.sh
```

**Output:**

- Human-readable summary to stdout
- YAML configuration written to `output/gpu_inventory.yaml`
- Global GPU inventory for `config/cluster.yaml`
- Per-GPU PCIe passthrough configurations for VM definitions

**Requirements:**

- `lspci` (from pciutils package) - required
- `nvidia-smi` (from NVIDIA driver) - optional but recommended for detailed GPU info

## Integration Examples

### Pre-deployment Validation

```bash
# Validate host system before deployment
./scripts/system-checks/check_prereqs.sh all

# Generate GPU inventory
./scripts/system-checks/gpu_inventory.sh
```

### Ansible Playbook

```yaml
- name: Validate system prerequisites
  shell: ./scripts/system-checks/check_prereqs.sh all
  register: prereqs_result
  failed_when: prereqs_result.rc == 1  # Fail on critical errors, allow warnings

- name: Generate GPU inventory
  shell: ./scripts/system-checks/gpu_inventory.sh
  register: gpu_inventory
```

### CI/CD Pipeline

```yaml
- name: System Validation
  run: |
    ./scripts/system-checks/check_prereqs.sh all
    ./scripts/system-checks/gpu_inventory.sh
```

## Troubleshooting

### Permission Denied

Some checks require elevated privileges:

```bash
# Check if sudo is needed
./scripts/system-checks/check_prereqs.sh all

# Run with sudo if required
sudo ./scripts/system-checks/check_prereqs.sh all
```

### Missing Dependencies

Install required system packages:

```bash
# For check_prereqs.sh
sudo apt-get install pciutils

# For gpu_inventory.sh
sudo apt-get install pciutils
# Optional: Install NVIDIA drivers for nvidia-smi
```

## See Also

- **[../README.md](../README.md)** - Scripts overview
- **[../../README.md](../../README.md)** - Project overview
