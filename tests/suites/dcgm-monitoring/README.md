# DCGM GPU Monitoring Test Suite

## Overview

This test suite validates NVIDIA DCGM (Data Center GPU Manager) installation, configuration,
and integration with Prometheus monitoring.

## Test Architecture

The test suite is designed to work with two deployment modes:

### 1. Packer Build Mode

- Services installed and configured
- Services enabled for auto-start
- **Services NOT started during build**
- No verification or testing performed

### 2. Runtime Deployment Mode

- Services started and verified
- GPU discovery tested
- Metrics endpoints validated
- Prometheus integration confirmed

## Test Scripts

### Installation Validation (`check-dcgm-installation.sh`)

Tests DCGM installation and basic configuration:

- GPU detection via lspci
- DCGM package installation
- Binary availability (dcgmi)
- Service status and configuration
- Log directory and permissions
- GPU discovery functionality
- Health monitoring capabilities
- Version information

```bash
# Run installation tests
./check-dcgm-installation.sh

# Run with verbose output
VERBOSE=true ./check-dcgm-installation.sh
```

### Exporter Validation (`check-dcgm-exporter.sh`)

Tests DCGM exporter functionality:

- Binary installation and permissions
- Systemd service configuration
- Service user and group setup
- Port availability (9400)
- Metrics endpoint accessibility
- GPU-specific metrics presence
- Service logs analysis
- Dependency configuration
- Health check validation

```bash
# Run exporter tests
./check-dcgm-exporter.sh

# Run with verbose output
VERBOSE=true ./check-dcgm-exporter.sh
```

### Prometheus Integration (`check-prometheus-integration.sh`)

Tests integration with Prometheus:

- Prometheus service status
- DCGM scrape configuration
- Target discovery and health
- Metrics query functionality
- Scrape interval configuration
- GPU utilization metrics
- Metrics retention settings
- Alert rules (if configured)
- End-to-end data flow

```bash
# Run integration tests
./check-prometheus-integration.sh

# Run with verbose output
VERBOSE=true ./check-prometheus-integration.sh
```

### Master Test Runner (`run-dcgm-monitoring-tests.sh`)

Orchestrates all test scripts:

```bash
# Run all tests
./run-dcgm-monitoring-tests.sh

# Run with options
./run-dcgm-monitoring-tests.sh --verbose
./run-dcgm-monitoring-tests.sh --skip-installation
./run-dcgm-monitoring-tests.sh --skip-integration

# Run specific test
./run-dcgm-monitoring-tests.sh --test installation
./run-dcgm-monitoring-tests.sh --test exporter
./run-dcgm-monitoring-tests.sh --test integration

# List available tests
./run-dcgm-monitoring-tests.sh --list
```

## Test Workflows

### Quick Test (Existing Cluster)

Test DCGM on already-running VMs:

```bash
cd tests
./suites/dcgm-monitoring/run-dcgm-monitoring-tests.sh
```

### Full Workflow Test

Create cluster, apply Ansible config, then test:

```bash
cd tests

# Full workflow
./test-dcgm-with-ansible-config.sh

# With verbose output
./test-dcgm-with-ansible-config.sh --verbose

# Without cleanup (for debugging)
./test-dcgm-with-ansible-config.sh --no-cleanup
```

### Phased Testing

Run workflow steps independently:

```bash
# Step 1: Create cluster
./test-dcgm-with-ansible-config.sh --skip-ansible --skip-tests

# Step 2: Apply Ansible configuration
./test-dcgm-with-ansible-config.sh --ansible-only

# Step 3: Run validation tests
./test-dcgm-with-ansible-config.sh --tests-only
```

### Makefile Targets

```bash
cd tests

# Quick test (assumes cluster exists)
make test-dcgm-monitoring

# Full workflow
make test-dcgm-full-workflow

# Apply Ansible config only
make test-dcgm-ansible-config
```

## Test Configuration

Test configuration file: `tests/test-infra/configs/test-dcgm-monitoring.yaml`

Key features:

- HPC controller node
- 2 GPU compute nodes with simulated PCIe devices
- Isolated test network (192.168.190.0/24)
- Minimal resource allocation for fast testing

## Expected Results

### With GPU Hardware

All tests should pass:

- ✅ GPU detection successful
- ✅ DCGM services running
- ✅ GPU metrics available
- ✅ Prometheus scraping working

### Without GPU Hardware

Tests gracefully handle missing GPUs:

- ⚠️ GPU detection returns 0 devices
- ⚠️ DCGM installation skipped (as expected)
- ✅ Configuration validation still works
- ✅ No errors or failures

## Troubleshooting

### DCGM Service Not Starting

```bash
# Check service status
systemctl status nvidia-dcgm

# View logs
journalctl -u nvidia-dcgm -n 50

# Check for GPU devices
lspci | grep -i nvidia

# Test manual start
sudo systemctl start nvidia-dcgm
```

### DCGM Exporter Issues

```bash
# Check exporter status
systemctl status dcgm-exporter

# Test metrics endpoint
curl http://localhost:9400/metrics

# Check dependencies
systemctl show dcgm-exporter -p Requires -p After

# View logs
journalctl -u dcgm-exporter -n 50
```

### Prometheus Integration Problems

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.job=="dcgm")'

# Query DCGM metrics
curl 'http://localhost:9090/api/v1/query?query=up{job="dcgm"}'

# Check configuration
grep -A 10 "job_name.*dcgm" /etc/prometheus/prometheus.yml
```

### Test Failures

```bash
# Run with verbose output
VERBOSE=true ./run-dcgm-monitoring-tests.sh

# Check test logs
ls -lah tests/logs/

# Run individual test script
./check-dcgm-installation.sh
./check-dcgm-exporter.sh
./check-prometheus-integration.sh
```

## Test Environment Requirements

### Minimum Requirements

- libvirt/KVM for VM creation
- Ansible for configuration management
- Python 3.10+ with ai-how CLI
- 16GB RAM (for test VMs)
- 50GB disk space

### Optional Requirements

- NVIDIA GPU hardware (for full validation)
- Internet access (for package downloads)
- Prometheus (for integration tests)

### Without GPU Hardware

The test suite is designed to work without physical GPUs:

- Installation tests still validate package management
- Configuration tests verify templates and files
- Service tests confirm systemd integration
- Only GPU-specific functionality is skipped with warnings

## Continuous Integration

The test suite is CI/CD ready:

```yaml
# Example GitHub Actions workflow
- name: Test DCGM Monitoring
  run: |
    cd tests
    make test-dcgm-full-workflow
```

## Best Practices

1. **Use verbose mode for debugging**

   ```bash
   VERBOSE=true ./run-dcgm-monitoring-tests.sh
   ```

2. **Test after code changes**

   ```bash
   # Quick test
   make test-dcgm-monitoring
   ```

3. **Full workflow for validation**

   ```bash
   # Complete end-to-end test
   make test-dcgm-full-workflow
   ```

4. **Clean up after tests**

   ```bash
   # Tests clean up automatically unless --no-cleanup used
   ```

5. **Check logs for details**

   ```bash
   tail -f tests/logs/dcgm-monitoring-*.log
   ```

## Test Coverage

The test suite covers:

- ✅ Package installation and management
- ✅ Binary deployment and permissions
- ✅ Configuration file generation
- ✅ Systemd service management
- ✅ Service dependencies
- ✅ Network port availability
- ✅ Metrics endpoint functionality
- ✅ GPU detection and discovery
- ✅ Prometheus integration
- ✅ Data flow validation
- ✅ Security configuration
- ✅ Log file management

## Contributing

When adding new tests:

1. Follow existing script structure
2. Use consistent logging functions
3. Implement graceful GPU hardware handling
4. Add test to master runner
5. Update this README
6. Test with and without GPU hardware

## References

- NVIDIA DCGM Documentation: https://docs.nvidia.com/datacenter/dcgm/
- DCGM Exporter: https://github.com/NVIDIA/dcgm-exporter
- Prometheus Integration: https://prometheus.io/docs/
- Packer vs Runtime Workflow: See `docs/DCGM-PACKER-WORKFLOW.md`
