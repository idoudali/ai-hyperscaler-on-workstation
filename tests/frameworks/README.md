# HPC Test Frameworks

Consolidated test frameworks for validating the HPC cluster deployment, including SLURM
controller, compute nodes, runtime services, and GPU passthrough validation.

## Overview

This directory contains three unified test frameworks:

1. **`test-hpc-packer-slurm-framework.sh`** - Unified SLURM testing across controller and compute
2. **`test-hpc-runtime-framework.sh`** - Runtime validation (GPU, cgroups, containers, DCGM)
3. **`test-pcie-passthrough-framework.sh`** - PCIe GPU passthrough validation

## Framework Descriptions

### 1. SLURM Framework (`test-hpc-packer-slurm-framework.sh`)

Validates:

- **SLURM Controller** - Cluster manager and scheduling components
- **SLURM Compute Nodes** - Job execution and resource allocation
- **BeeGFS Shared Storage** - Cross-node file accessibility
- **SLURM Job Examples** - Real-world parallel job execution (Tutorial 08)

**Cluster Configuration**: Uses `config/example-multi-gpu-clusters.yaml`

- **Controller**: 4 cores, 8GB RAM, IP 192.168.100.10
- **Compute-01**: 8 cores, 16GB RAM, IP 192.168.100.11 (GPU passthrough)
- **Compute-02**: 8 cores, 16GB RAM, IP 192.168.100.12 (GPU passthrough)
- **Network**: 192.168.100.0/24, bridge virbr100
- **BeeGFS**: Shared mount at `/mnt/beegfs` with management on controller, storage on compute nodes
- **SLURM Partitions**: `gpu` (default), `debug`

### 2. Runtime Framework (`test-hpc-runtime-framework.sh`)

Validates compute node services and orchestration:

**Compute Node Services** (executed directly on compute nodes):

- **SLURM Compute Services** - Node registration and job execution
- **Container Runtime** - Singularity/Apptainer installation and execution
- **GPU GRES** - GPU resource scheduling and configuration
- **Cgroup Isolation** - Resource isolation and limits

**Cluster Orchestration via SLURM** (executed from controller via SLURM job submission):

- **Job Scripts** - SLURM batch script execution
- **DCGM Monitoring** - GPU telemetry and health
- **Container Integration** - Containers with GPU and MPI support
- **End-to-End ML Workflows** - PyTorch, TensorFlow deployments

**Cluster Configuration**: Uses `tests/test-infra/configs/test-slurm-compute.yaml`

### 3. PCIe Passthrough Framework (`test-pcie-passthrough-framework.sh`)

Validates:

- **PCIe Device Assignment** - GPU device passthrough to VMs
- **GPU Driver Loading** - NVIDIA driver and kernel module loading
- **Device Accessibility** - /dev/nvidia* device files
- **Basic GPU Validation** - nvidia-smi and GPU queries

**Cluster Configuration**: Uses `tests/test-infra/configs/test-pcie-passthrough.yaml`

---

## 1. SLURM Framework

### File

`test-hpc-packer-slurm-framework.sh`

### Usage

Run with `--help` for detailed usage information.

### Commands

Standard framework commands available:

- `e2e` / `end-to-end` - Complete testing workflow
- `start-cluster` - Start the cluster
- `stop-cluster` - Stop the cluster
- `deploy-ansible` - Deploy configuration
- `run-tests` - Run test suites
- `status` - Check cluster status
- `list-tests` - List available tests
- `help` - Show help message

### Options

- `--mode` - Test mode: `controller`, `compute`, or `full`
- `--skip-examples` - Skip job example tests
- `--help` - Display usage information
- `--verbose` - Enable verbose output
- `--no-cleanup` - Skip cleanup after tests

## Test Suites

### Controller Tests (`tests/suites/slurm-controller/`)

Validates SLURM controller installation and functionality:

- SLURM package installation and dependencies
- Basic SLURM functionality and configuration
- PMIx integration and configuration
- MUNGE authentication system
- Container plugin configuration
- Job accounting and database integration

### Compute Tests (`tests/suites/slurm-compute/`)

Validates SLURM compute node setup:

- Compute node installation
- Compute node registration with controller
- Distributed job execution
- Multi-node communication

### Job Example Tests (`tests/suites/slurm-job-examples/`)

Tests real-world SLURM job execution:

1. **BeeGFS Shared Storage** - Cross-node file accessibility validation
2. **Hello World MPI** - Multi-node MPI job execution
3. **Pi Calculation** - Computational parallel job execution
4. **Matrix Multiply** - Memory-intensive job validation

Job examples use BeeGFS shared storage at `/mnt/beegfs/slurm-jobs/`.

## BeeGFS Integration

The test framework leverages BeeGFS shared storage for:

- Storing compiled job binaries accessible from all nodes
- Writing persistent job output files
- Testing cross-node file I/O and concurrent access

### BeeGFS Configuration

- **Mount Point**: `/mnt/beegfs`
- **Management Node**: Controller
- **Metadata Servers**: Controller
- **Storage Servers**: Compute nodes
- **Accessibility**: All cluster nodes

## Test Execution Flow

Standard workflow for all frameworks:

1. **Start Cluster** - Create and start VMs
2. **Deploy Ansible** - Configure services
3. **Run Tests** - Execute validation suites
4. **Collect Results** - Gather logs and reports
5. **Cleanup** - Destroy cluster

## Test Output

Results saved in `logs/run-YYYY-MM-DD_HH-MM-SS/`:

- Individual test suite logs
- `test_report_summary.txt` - Overall summary
- Ansible deployment logs
- Cluster lifecycle logs

## Troubleshooting

### Common Issues

- **SSH Errors**: Verify SSH key configuration and network connectivity
- **BeeGFS Not Accessible**: Check BeeGFS mount status on all nodes
- **Job Examples Not Building**: Ensure Docker image is built
- **SLURM Not Running**: Use framework `status` command to check cluster state

Use framework's `--help` flag for detailed usage and troubleshooting guidance.

---

## 2. Runtime Framework

### File

`test-hpc-runtime-framework.sh`

### Purpose

Consolidated testing framework for HPC compute node runtime components including container runtime,
GPU GRES scheduling, cgroup isolation, job execution, DCGM monitoring, and container integration.

### Usage

Run with `--help` for detailed usage. Supports standard framework commands including `e2e`, `start-cluster`,
`stop-cluster`, `deploy-ansible`, `run-tests`, `list-tests`, and `status`.

### Test Suites

The runtime framework executes test suites in two execution contexts:

### Compute Node Suites (executed ON compute nodes):

1. **SLURM Compute** (`suites/slurm-compute`) - Node registration and job execution
2. **Cgroup Isolation** (`suites/cgroup-isolation`) - Resource isolation validation
3. **GPU GRES** (`suites/gpu-gres`) - GPU resource scheduling and MIG configuration
4. **Container Runtime** (`suites/container-runtime`) - Singularity/Apptainer installation

### Controller Suites (executed FROM controller via SLURM):

1. **Job Scripts** (`suites/job-scripts`) - Batch script execution and prolog/epilog
2. **DCGM Monitoring** (`suites/dcgm-monitoring`) - GPU telemetry and health monitoring
3. **Container Integration** (`suites/container-integration`) - SLURM + GPU + MPI + containers
4. **Container End-to-End** (`suites/container-e2e`) - ML framework deployments (PyTorch, TensorFlow)

### Configuration

Uses `tests/test-infra/configs/test-slurm-compute.yaml` with 1 controller + 2 GPU-capable compute nodes.

---

## 3. PCIe Passthrough Framework

### File

`test-pcie-passthrough-framework.sh`

### Purpose

Validates PCIe GPU passthrough functionality including device assignment, driver loading,
and basic GPU accessibility in virtualized environments.

### Usage

Run with `--help` for detailed usage. Supports standard framework commands.

### Validation Tests

- **PCIe Device Detection** - Verify GPU devices visible via lspci
- **Driver Loading** - NVIDIA kernel modules loaded correctly
- **Device Files** - /dev/nvidia* devices present and accessible
- **nvidia-smi** - GPU management interface functional

### Configuration

Uses `tests/test-infra/configs/test-pcie-passthrough.yaml`

Uses `suites/gpu-validation` for GPU device validation.

---

## Related Documentation

- **SLURM Tutorials**: See `docs/tutorials/slurm/` for detailed guides
  - Tutorial 08: SLURM Basics (hello-world, pi-calculation, matrix-multiply)
  - Tutorial 09: Job Arrays and Dependencies (placeholder)
  - Tutorial 10: GPU Jobs and Containers (placeholder)
  - Tutorial 11: SLURM Debugging and Troubleshooting

- **Cluster Configuration**: `config/example-multi-gpu-clusters.yaml`
- **Infrastructure Code**: `terraform/`, `ansible/`
- **Project Documentation**: `docs/`

## Development Guide

### Adding New Tests

1. Create test script in `tests/suites/<suite-name>/check-<test-name>.sh`
2. Add test script to runner in `run-<suite-name>-tests.sh`
3. Follow test script conventions from existing tests
4. Test locally before committing

Refer to existing test scripts for template and conventions.

## Maintenance

- Update test suites when SLURM configuration changes
- Keep BeeGFS configuration synchronized across nodes
- Review test logs regularly for patterns or recurring issues
- Document any workarounds or special configurations needed

---

*Last Updated: 2025-11-07*
