# HPC Controller Image

**Status:** Production  
**Last Updated:** 2025-10-19

## Overview

The HPC Controller image is a specialized Debian 13-based VM image designed to serve as the SLURM cluster controller
and management node. It provides job scheduling, cluster management, shared storage services, and monitoring
capabilities for HPC workloads.

> **Note**: For common build system information, prerequisites, and troubleshooting, see the
> [main Packer README](../README.md).

## Controller-Specific Components

This image includes components specific to the cluster controller role:

### SLURM Controller Services

- **slurmctld**: Job scheduling and resource management daemon
- **slurmdbd**: Database backend for accounting and job history
- **Configuration**: Prepared for cluster-wide job scheduling

### BeeGFS Management Services

- **Management Server**: Distributed file system orchestration
- **Metadata Server**: File metadata management and namespace
- **Storage Server**: Data storage services
- **Client**: Local file system access on controller

### Monitoring Stack

- **Prometheus Server**: Cluster-wide metrics collection and storage
- **Node Exporter**: System metrics export
- **Grafana Ready**: Visualization dashboards (optional)

### Additional Services

- **Container Runtime**: Apptainer 1.4.2 for containerized jobs
- **User Authentication**: MUNGE for secure inter-node communication
- **HPC Development Tools**: Compilers, libraries, and build tools

## Image Specifications

### Base Configuration

- **Base OS**: Debian 13 (Trixie) Cloud Image
- **Format**: QCOW2 (compressed)
- **Default Disk Size**: 20GB (configurable)
- **Default Memory**: 4096MB (build-time only)
- **Default CPUs**: 4 cores (build-time only)
- **Typical Size**: ~1.8GB compressed

### Installed Components

- **SLURM Version**: 23.11.4 (controller + database daemons)
- **BeeGFS**: Management, Metadata, Storage servers + Client
- **Apptainer**: Version 1.4.2 with rootless support
- **Prometheus**: Server + Node Exporter
- **Base System**: Debian 13 + HPC development tools

For detailed component information, see the [main Packer README](../README.md#image-specifications).

## Build Process

The controller image follows the [standard Packer build process](../README.md#common-build-process) with
controller-specific Ansible provisioning:

```text
Ansible roles applied:
- hpc-base-packages: Core HPC packages
- container-runtime: Apptainer installation
- monitoring-stack: Prometheus + Node Exporter  
- slurm-controller: SLURM controller + database setup
```

**BeeGFS Packages**: Management, Metadata, Storage, Client

## Build Commands

### Quick Build

```bash
# From project root
make run-docker COMMAND="cmake --build build --target build-hpc-controller-image"
```

### Step-by-Step Build

```bash
# Initialize Packer plugins
make run-docker COMMAND="cmake --build build --target init-hpc-controller-packer"

# Validate template
make run-docker COMMAND="cmake --build build --target validate-hpc-controller-packer"

# Build the image
make run-docker COMMAND="cmake --build build --target build-hpc-controller-image"
```

### Alternative: From Inside Container

```bash
# Enter container shell
make shell-docker

# Inside container, build directly
cmake --build build --target build-hpc-controller-image
```

For general build system information, prerequisites, and advanced options, see the
[main Packer README](../README.md#build-system).

## Build Variables

### Controller-Specific Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `disk_size` | 20G | Virtual disk size for controller |
| `memory` | 2048 | Build VM memory (MB) |
| `cpus` | 2 | Build VM CPU cores |
| `image_name` | hpc-controller | Image identifier |
| `vm_name` | hpc-controller.qcow2 | Output filename |

For common build variables (repository paths, SSH keys, cloud-init), see the
[main Packer README](../README.md#build-variables).

## Build Output

Built image location:

```text
build/packer/hpc-controller/hpc-controller/hpc-controller.qcow2
```

Build artifacts and metadata:

```text
build/packer/hpc-controller/
├── hpc-controller/          # Output directory
│   └── hpc-controller.qcow2 # Main image (~1.8GB compressed)
└── qemu-serial.log          # Build console output
```

For verification commands and full output structure, see the
[main Packer README](../README.md#build-output).

## Usage

### Recommended Runtime Resources

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| Memory | 4GB | 8GB+ |
| CPUs | 2 | 4+ |
| Disk | 20GB | 40GB+ |

### Configuration in cluster.yml

```yaml
clusters:
  hpc:
    controller:
      base_image_path: "build/packer/hpc-controller/hpc-controller/hpc-controller.qcow2"
      memory: 8192
      cpus: 4
      disk_size: 40G
```

For deployment commands and manual VM creation, see the
[main Packer README](../README.md#common-usage-patterns).

## Runtime Configuration

After deploying the controller VM, configure cluster services. See component-specific documentation:

### SLURM Controller Configuration

For SLURM controller setup, configuration files, and cluster registration:

- [SLURM Controller Role](../../ansible/roles/slurm-controller/README.md)
- [SLURM Configuration Guide](../../docs/slurm-configuration.md) <!-- TODO: Create this guide -->

### BeeGFS Management Services Configuration

For BeeGFS management, metadata, and storage service setup:

- [BeeGFS Ansible Role](../../ansible/roles/beegfs/README.md) <!-- TODO: Verify path -->
- [BeeGFS Configuration Guide](../../docs/beegfs-setup.md) <!-- TODO: Create this guide -->

### Monitoring Stack Configuration

For Prometheus server configuration and target setup:

- [Monitoring Stack Role](../../ansible/roles/monitoring-stack/README.md)
- [Prometheus Configuration Guide](../../docs/prometheus-setup.md) <!-- TODO: Create this guide -->

## Customization

### Controller-Specific Ansible Roles

- `slurm-controller`: Edit SLURM controller configuration
- `monitoring-stack`: Modify Prometheus server settings

```bash
# Edit controller playbook
vim ansible/playbooks/playbook-hpc-controller.yml

# Rebuild image
make run-docker COMMAND="cmake --build build --target build-hpc-controller-image"
```

For general customization (packages, cloud-init, disk size), see the
[main Packer README](../README.md#advanced-usage).

## Troubleshooting

For common build issues (SSH timeout, disk space, BeeGFS packages), see the
[main Packer README troubleshooting section](../README.md#common-troubleshooting).

### Controller-Specific Issues

For component-specific troubleshooting, see:

#### SLURM Controller Issues

- [SLURM Controller Troubleshooting](../../ansible/roles/slurm-controller/README.md#troubleshooting)
- [SLURM Troubleshooting Guide](../../docs/troubleshooting/slurm.md) <!-- TODO: Create this guide -->

**Quick diagnostic commands:**

```bash
# Check SLURM configuration syntax
sudo slurmctld -C

# View service logs
sudo journalctl -u slurmctld -u slurmdbd
```

#### BeeGFS Services Issues

- [BeeGFS Troubleshooting](../../docs/troubleshooting/beegfs.md) <!-- TODO: Create this guide -->

**Quick diagnostic commands:**

```bash
# Check service status
sudo systemctl status beegfs-mgmtd beegfs-meta beegfs-storage

# Check BeeGFS logs
sudo journalctl -u beegfs-mgmtd
```

#### Prometheus Server Issues

- [Monitoring Stack Troubleshooting](../../ansible/roles/monitoring-stack/README.md#troubleshooting)
- [Prometheus Troubleshooting Guide](../../docs/troubleshooting/prometheus.md) <!-- TODO: Create this guide -->

**Quick diagnostic commands:**

```bash
# Check Prometheus logs
sudo journalctl -u prometheus

# Test target connectivity
curl http://<compute-node>:9100/metrics
```

## Performance Tuning

For general performance optimization (build speed, image size reduction), see the
[main Packer README](../README.md#performance-tuning).

### Controller-Specific Tuning

- **SLURM**: Adjust `MaxJobCount` and `MaxArraySize` in `slurm.conf`
- **Prometheus**: Configure retention period and storage limits
- **BeeGFS**: Tune metadata and storage service parameters

## Related Documentation

### Controller-Specific

- **SLURM Controller**: [ansible/roles/slurm-controller/README.md](../../ansible/roles/slurm-controller/README.md)
- **Monitoring Stack**: [ansible/roles/monitoring-stack/README.md](../../ansible/roles/monitoring-stack/README.md)

### General

- **Build System**: [packer/README.md](../README.md) - Build process, troubleshooting, customization
- **HPC Compute**: [hpc-compute/README.md](../hpc-compute/README.md) - Compute node image
- **HPC Base**: [hpc-base/README.md](../hpc-base/README.md) - Shared architecture
- **ai-how CLI**: [python/ai_how/README.md](../../python/ai_how/README.md) - Deployment tools

## Design Decisions

### No GPU Drivers

Controller nodes don't include GPU drivers because they:

- Don't execute computational workloads (scheduling only)
- Don't need direct GPU access
- Keep image size smaller (~1.8GB vs ~2.2GB)

GPU monitoring can be added via runtime configuration if needed.

### Runtime Database Configuration

SLURM database backend (`slurmdbd`) requires runtime setup to:

- Avoid embedding database credentials in the image
- Allow different database configurations per deployment
- Enable secure credential management

The image is prepared with `slurmdbd` but requires:

- Database installation (MariaDB/MySQL)
- User and schema setup
- Configuration with proper credentials
