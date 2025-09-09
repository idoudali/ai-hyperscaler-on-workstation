# PCIe Passthrough Test Infrastructure

This directory contains automated testing infrastructure for validating PCIe passthrough functionality in HPC clusters
deployed with the ai-how tool.

## Overview

The test framework provides a clean, automated way to test GPU passthrough without modifying the host system. It uses
real ai-how cluster deployments to validate end-to-end functionality.

## Quick Start

```bash
# Run complete PCIe passthrough test
./test-pcie-passthrough-framework.sh

# View help and options
./test-pcie-passthrough-framework.sh --help
```

## Components

### Test Configurations

- **`configs/test-pcie-passthrough-minimal.yaml`**: Minimal single-node HPC cluster with GPU passthrough
- **`configs/test-gpu-simulation.yaml`**: Full GPU simulation test setup  
- **`configs/test-full-stack.yaml`**: Complete HPC + Cloud setup with GPU nodes
- **`configs/test-minimal.yaml`**: Basic functionality test without GPU passthrough

### Test Framework

- **`test-pcie-passthrough-framework.sh`**: Main orchestration script that manages the complete test workflow
- **`scripts/gpu-validation/`**: GPU validation test suite executed on remote VMs

### GPU Validation Suite

The validation suite runs on deployed VMs to verify GPU passthrough functionality:

- **`check-pcie-devices.sh`**: Validates PCIe device visibility with lspci
- **`check-gpu-drivers.sh`**: Tests NVIDIA driver loading and nvidia-smi
- **`run-all-tests.sh`**: Master test runner combining all validation tests

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

## Usage Examples

### Basic Testing

```bash
# Run minimal PCIe passthrough test
./test-pcie-passthrough-framework.sh

# Run with verbose output
./test-pcie-passthrough-framework.sh --verbose
```

### Advanced Options

```bash
# Use custom configuration
./test-pcie-passthrough-framework.sh \
  --config configs/test-full-stack.yaml

# Use custom SSH settings
./test-pcie-passthrough-framework.sh \
  --ssh-user root --ssh-key ~/.ssh/test_key

# Debug mode (no auto-cleanup on failure)
./test-pcie-passthrough-framework.sh --no-cleanup
```

### Manual Testing

You can also run individual components manually:

```bash
# Start cluster manually
cd ../../..  # Go to project root
uv run ai-how create tests/test-infra/configs/test-pcie-passthrough-minimal.yaml

# Get VM IP
virsh list
virsh domifaddr test-hpc-pcie-minimal-compute-0

# Test SSH connectivity
ssh -i build/shared/ssh-keys/id_rsa admin@<vm-ip> "echo 'SSH working'"

# Upload and run tests manually
scp -i build/shared/ssh-keys/id_rsa tests/scripts/gpu-validation/*.sh admin@<vm-ip>:~/gpu-tests/
ssh -i build/shared/ssh-keys/id_rsa admin@<vm-ip> "chmod +x ~/gpu-tests/*.sh && ~/gpu-tests/run-all-tests.sh"

# Cleanup
uv run ai-how destroy tests/test-infra/configs/test-pcie-passthrough-minimal.yaml
```

## Test Workflow

The automated framework follows this workflow:

1. **Prerequisites Check**: Validates required tools and configurations
2. **Cluster Deployment**: Uses `ai-how create` to deploy test cluster
3. **VM Discovery**: Uses `virsh` to detect and get IP addresses of VMs
4. **SSH Connectivity**: Waits for SSH access to become available
5. **Script Deployment**: Uploads validation scripts to VMs
6. **Test Execution**: Runs GPU validation suite on each VM
7. **Result Collection**: Gathers test results and logs
8. **Cleanup**: Uses `ai-how destroy` to tear down cluster
9. **Verification**: Ensures no VMs remain after testing

## Test Results

### Log Files

All test results are saved to `tests/logs/run-YYYY-MM-DD_HH-MM-SS/`:

- `cluster-start.log`: ai-how cluster creation output
- `cluster-destroy.log`: ai-how cluster teardown output  
- `test-results-<vm-name>.log`: Individual VM test results

### Exit Codes

- **0**: All tests passed successfully
- **1**: Some tests failed or framework error occurred

### Test Validation

The framework validates these components:

- ✅ **PCIe Device Detection**: GPU devices visible via lspci
- ✅ **Driver Loading**: NVIDIA kernel modules loaded
- ✅ **nvidia-smi**: GPU management interface functional
- ✅ **Device Files**: /dev/nvidia* devices present

## Troubleshooting

### Common Issues

1. **VM Startup Timeout**: Increase timeout or check system resources
2. **SSH Connection Failed**: Verify SSH key permissions and VM network
3. **GPU Tests Fail**: Expected for simulated GPU devices (tests hardware detection)
4. **Cleanup Failed**: Use manual cleanup commands or `--no-cleanup` flag

### Debugging

```bash
# Enable verbose output
./test-pcie-passthrough-framework.sh --verbose

# Skip cleanup for debugging
./test-pcie-passthrough-framework.sh --no-cleanup

# Check remaining VMs manually
virsh list --all
```

### Manual Cleanup

If automated cleanup fails:

```bash
# List all VMs
virsh list --all

# Stop and remove test VMs
virsh destroy test-hpc-pcie-minimal-controller
virsh undefine test-hpc-pcie-minimal-controller
virsh destroy test-hpc-pcie-minimal-compute-0  
virsh undefine test-hpc-pcie-minimal-compute-0

# Or use ai-how
cd ../../..  # Go to project root
uv run ai-how destroy tests/test-infra/configs/test-pcie-passthrough-minimal.yaml --force
```

## Development

### Adding New Tests

To add new validation tests:

1. Create test script in `scripts/gpu-validation/`
2. Make it executable: `chmod +x script.sh`
3. Add call to `scripts/gpu-validation/run-all-tests.sh`
4. Test the individual script manually first

### Modifying Configurations

Test configurations follow the ai-how schema. Key sections for GPU testing:

```yaml
compute_nodes:
  - pcie_passthrough:
      enabled: true
      devices:
        - pci_address: "0000:01:00.0"
          device_type: "gpu"
          vendor_id: "10de"
          device_id: "2684"
```

### Framework Options

The test framework supports these configuration options:

- `--config`: Custom test configuration file
- `--ssh-user`: SSH username (default: admin)
- `--ssh-key`: SSH private key path (default: build/shared/ssh-keys/id_rsa)
- `--no-cleanup`: Skip cleanup on failure
- `--verbose`: Enable verbose output

## Integration

### CI/CD Integration

The framework is designed for CI/CD integration:

```yaml
# Example GitHub Actions step
- name: Run PCIe Passthrough Tests
  run: |
    cd tests/test-infra
    ./test-pcie-passthrough-framework.sh
  timeout-minutes: 30
```

### Automated Testing

The framework can be included in automated test suites:

```bash
#!/bin/bash
# Run all test configurations
cd tests/test-infra
for config in configs/test-*.yaml; do
  echo "Testing configuration: $config"
  ./test-pcie-passthrough-framework.sh --config "$config"
done
```

## Architecture

The test framework is designed with these principles:

- **No Host Modification**: Works on any development system without requiring sudo
- **Real Testing**: Uses actual ai-how deployments for authentic validation
- **Automated Cleanup**: Ensures no test artifacts remain after execution
- **Comprehensive Logging**: Provides detailed output for debugging
- **Modular Design**: Individual test components can be run independently
