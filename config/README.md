# Cluster Configuration

This directory contains the core configuration files for the Hyperscaler on a
Workstation project. The files in this directory define the entire
infrastructure, from network topology to the specific resources allocated to
each virtual machine in the HPC and Cloud clusters.

## `template-cluster.yaml`

This is the **single source of truth** for the entire emulated infrastructure.
All automation, including VM provisioning, GPU allocation, and Ansible playbook
execution, is driven by the contents of this file.

It defines:

- **Global Settings**:
  - GPU allocation strategy with MIG-capable devices
  - MIG slice distribution between HPC and Cloud clusters
  - Whole GPU allocation for non-MIG workloads
- **HPC Cluster**:
  - SLURM controller with dedicated network subnet (192.168.100.0/24)
  - 4 compute nodes with MIG GPU slices (hpc-mig-0 through hpc-mig-3)
  - SLURM partitions: gpu and debug
- **Cloud Cluster**:
  - Kubernetes control plane with dedicated network subnet (192.168.200.0/24)
  - CPU worker nodes for general workloads
  - GPU worker nodes with MIG slices (cloud-mig-0 through cloud-mig-2)
  - Kubernetes configuration: Calico CNI, NGINX ingress, local-path storage

## Configuration Structure

### GPU Allocation Strategy

The configuration implements a hybrid GPU allocation approach:

- **MIG Slices**: 4 for HPC cluster, 3 for Cloud cluster
- **Whole GPUs**: 1 dedicated to Cloud cluster for workloads requiring full GPU access
- **MIG Profiles**: Supports 1g.5gb, 2g.10gb, 3g.20gb, and 7g.80gb configurations

### Network Topology

- **HPC Cluster**: 192.168.100.0/24 (virbr100)
- **Cloud Cluster**: 192.168.200.0/24 (virbr200)
- **Isolation**: Each cluster operates on separate virtual bridges for security

### Resource Specifications

- **HPC Compute Nodes**: 8 CPU cores, 16GB RAM, 200GB disk, dedicated MIG slices
- **Cloud GPU Workers**: 8 CPU cores, 16GB RAM, 200GB disk, MIG GPU slices
- **Cloud CPU Workers**: 4 CPU cores, 8GB RAM, 100GB disk, no GPU

## Usage

To use this configuration:

1. Copy the template to create your working configuration:

   ```bash
   cp config/template-cluster.yaml config/cluster.yaml
   ```

2. Modify the `cluster.yaml` file to adjust resource allocations, network
   configurations, or cluster specifications as needed.

3. The automation tools will read from `cluster.yaml` to provision and
   configure your infrastructure.

## Customization

The configuration is designed to be easily customizable:

- Adjust CPU cores, memory, and disk allocations per node type
- Modify network subnets and bridge names
- Change GPU allocation strategy and MIG slice distribution
- Update SLURM and Kubernetes configuration parameters
