# Test Infrastructure

This directory contains shared testing infrastructure and configuration files used by all test frameworks
in the HPC cluster validation suite.

## Overview

The test infrastructure provides:

- **Configuration Files** - YAML configurations for various test scenarios
- **Shared Utilities** - Common functions for cluster management, logging, and test orchestration
- **Inventory Templates** - Ansible inventory generation for test clusters

## Directory Structure

```text
test-infra/
├── configs/                # Test cluster configurations
│   ├── test-minimal.yaml
│   ├── test-slurm-controller.yaml
│   ├── test-slurm-compute.yaml
│   ├── test-container-runtime.yaml
│   ├── test-pcie-passthrough-minimal.yaml
│   ├── test-beegfs.yaml
│   ├── test-virtio-fs.yaml
│   └── ... (more test configs)
├── utils/                  # Shared utility scripts
│   ├── log-utils.sh
│   ├── cluster-utils.sh
│   ├── ansible-utils.sh
│   ├── test-framework-utils.sh
│   ├── framework-cli.sh
│   └── framework-orchestration.sh
├── inventory/             # Ansible inventory templates
└── README.md             # This file
```

## Components

### Test Configurations (`configs/`)

Test configurations define cluster topologies and parameters for various test scenarios:

**Core Infrastructure Tests:**

- **`test-minimal.yaml`**: Basic 1 controller + 1 compute node
- **`test-slurm-controller.yaml`**: SLURM controller validation
- **`test-slurm-compute.yaml`**: SLURM compute node validation (1 controller + 2 compute)
- **`test-slurm-accounting.yaml`**: SLURM job accounting
- **`test-monitoring-stack.yaml`**: Prometheus/Grafana monitoring

**Runtime Tests:**

- **`test-container-runtime.yaml`**: Container runtime (Docker/Podman)
- **`test-cgroup-isolation.yaml`**: Cgroup resource isolation
- **`test-gpu-gres.yaml`**: GPU GRES scheduling
- **`test-job-scripts.yaml`**: SLURM batch scripts
- **`test-dcgm-monitoring.yaml`**: DCGM GPU monitoring
- **`test-container-integration.yaml`**: Container workload integration

**Advanced Tests:**

- **`test-pcie-passthrough-minimal.yaml`**: PCIe GPU passthrough (1 controller + 1 GPU compute)
- **`test-beegfs.yaml`**: BeeGFS distributed filesystem (1 controller + 3 storage nodes)
- **`test-virtio-fs.yaml`**: VirtIO-FS host directory sharing
- **`test-container-registry.yaml`**: Container registry deployment
- **`test-full-stack.yaml`**: Complete HPC + Cloud setup
- **`test-gpu-simulation.yaml`**: Full GPU simulation

### Shared Utilities (`utils/`)

Reusable functions used by all test frameworks:

- **`log-utils.sh`**: Logging, colors, timestamps
- **`cluster-utils.sh`**: VM management, SSH connectivity, IP discovery
- **`ansible-utils.sh`**: Ansible inventory generation, playbook execution
- **`test-framework-utils.sh`**: Test execution, result collection
- **`framework-cli.sh`**: Standard CLI interface (e2e, start-cluster, stop-cluster, etc.)
- **`framework-orchestration.sh`**: Workflow orchestration for frameworks

## Prerequisites

Before running the tests, ensure you have:

1. **AI-HOW Tool**: Installed and functional

   ```bash
   uv run ai-how --help
   ```

2. **Base Images**: HPC base image built with Packer

   ```bash
   ls -la build/packer/hpc-base/hpc-base/hpc-base.qcow2
   ```

3. **Virtualization**: KVM and libvirt installed

   ```bash
   virsh version
   sudo systemctl status libvirtd
   ```

4. **SSH Keys**: Project SSH key pair configured

   ```bash
   ls -la build/shared/ssh-keys/id_rsa*
   ```

## Usage

### Using Test Configurations

Test configurations are consumed by test frameworks in `tests/frameworks/` and `tests/advanced/`.
Each framework references specific configuration files for its test scenarios.

### Creating Custom Test Configurations

1. Copy an existing configuration as a template
2. Modify cluster topology, resources, and features
3. Reference in a framework script

### Manual Testing

For debugging or custom workflows, configurations can be used directly with the `ai-how` CLI
and standard libvirt/virsh commands. Refer to framework scripts for usage patterns.

## Standard Test Framework Workflow

All test frameworks follow a standardized workflow:

1. **Prerequisites Check**: Validates required tools and configurations
2. **Cluster Deployment**: Uses `ai-how create` to deploy test cluster from config
3. **VM Discovery**: Uses `virsh` to detect and get IP addresses of VMs
4. **SSH Connectivity**: Waits for SSH access to become available on all nodes
5. **Ansible Deployment**: Deploys cluster configuration via Ansible playbooks
6. **Test Execution**: Runs validation test suites on the deployed cluster
7. **Result Collection**: Gathers test results and logs
8. **Cleanup**: Uses `ai-how destroy` to tear down cluster
9. **Verification**: Ensures no VMs remain after testing

## Test Results and Logging

### Log Directory Structure

All test results are saved to `tests/logs/run-YYYY-MM-DD_HH-MM-SS/`:

```text
logs/run-2025-11-07_14-30-00/
├── cluster-start.log              # ai-how cluster creation output
├── cluster-destroy.log            # ai-how cluster teardown output
├── ansible-deployment.log         # Ansible playbook execution
├── test-results-<suite-name>.log  # Individual test suite results
└── test_report_summary.txt        # Summary of all test results
```

### Exit Codes

- **0**: All tests passed successfully
- **1**: Some tests failed or framework error occurred

### Interpreting Results

Each test framework validates specific components:

- **SLURM Framework**: Controller services, compute nodes, job execution, BeeGFS
- **Runtime Framework**: Containers, GPU GRES, cgroups, DCGM, job scripts
- **PCIe Framework**: GPU passthrough, driver loading, device accessibility
- **Storage Frameworks**: BeeGFS/VirtIO-FS mount, I/O performance, multi-node access
- **Registry Framework**: Image push/pull, SLURM container integration

## Troubleshooting

### Common Issues

1. **VM Startup Timeout**
   - Increase timeout values in framework script
   - Check system resources (CPU, memory, disk space)
   - Verify libvirt/KVM is running: `sudo systemctl status libvirtd`

2. **SSH Connection Failed**
   - Verify SSH key permissions: `ls -la build/shared/ssh-keys/`
   - Check VM network configuration: `virsh net-list --all`
   - Test connectivity: `ssh -i build/shared/ssh-keys/id_rsa admin@<vm-ip>`

3. **Ansible Deployment Fails**
   - Check inventory generation succeeded
   - Verify SSH access to all nodes
   - Review Ansible logs in `tests/logs/`

4. **Test Suite Failures**
   - Review individual test logs in `tests/logs/run-*/`
   - Use framework's `list-tests` command to identify failing test
   - Run specific test individually for debugging

5. **Cleanup Failed**
   - Use manual cleanup commands (see below)
   - Check for stale libvirt resources
   - Use framework's `--no-cleanup` flag for debugging

### Debugging Techniques

- Enable verbose output: Use framework's `--verbose` flag
- Keep cluster running: Use framework's `--no-cleanup` flag
- Step-by-step execution: Use modular framework commands
- Check VM status: Use `virsh list --all`
- Review logs: Check `tests/logs/` directory

### Manual Cleanup

If automated cleanup fails:

- List VMs: `virsh list --all`
- Stop/remove VMs: `virsh destroy` and `virsh undefine`
- Force cleanup: Use `ai-how destroy --force`
- Clean logs: Remove `tests/logs/run-*` directories

## Development

### Adding New Test Configurations

1. Copy an existing configuration as a template
2. Modify cluster topology, node resources, and feature flags
3. Reference in a framework script

### Creating New Test Frameworks

When creating a new test framework:

1. Follow the standardized CLI pattern (see `tests/README.md`)
2. Source shared utilities from `utils/`
3. Use configuration files from `configs/`
4. Implement standard commands: `e2e`, `start-cluster`, `stop-cluster`, `deploy-ansible`, `run-tests`, `status`

### Adding Test Suites

1. Create suite directory in `tests/suites/<suite-name>/`
2. Add individual test scripts: `check-<feature>.sh`
3. Create runner script: `run-<suite-name>-tests.sh`
4. Reference suite in appropriate framework

## Related Documentation

- **Main Test Documentation**: `tests/README.md`
- **Framework Documentation**: `tests/frameworks/README.md`
- **AI-HOW CLI**: `python/ai_how/README.md`
- **Cluster Configuration**: `config/example-multi-gpu-clusters.yaml`
- **Ansible Playbooks**: `ansible/README.md`

## Design Principles

The test infrastructure is designed with these principles:

- **No Host Modification**: Works on any development system without requiring sudo
- **Real Testing**: Uses actual ai-how deployments for authentic validation
- **Automated Cleanup**: Ensures no test artifacts remain after execution
- **Comprehensive Logging**: Provides detailed output for debugging
- **Modular Design**: Individual test components can be run independently
- **Standardized CLI**: All frameworks follow the same command interface
- **Shared Utilities**: Common functions reduce code duplication
