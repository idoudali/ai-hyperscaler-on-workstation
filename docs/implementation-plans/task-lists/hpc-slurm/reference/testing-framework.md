# HPC SLURM Testing Framework Patterns

**Last Updated**: 2025-10-17

## Overview

This document describes the standard testing framework patterns established in Task 004 and used throughout the HPC
SLURM deployment project. All testing follows these proven patterns for consistency and reliability.

## Standard Test Framework Pattern

Established in **TASK-018** (DCGM GPU Monitoring), this pattern is used for all subsequent tasks.

### Framework Components

#### 1. Ansible Role Structure

- Separate Packer build tasks (`packer_build=true`) from runtime tasks (`packer_build=false`)
- Service management: Enable in Packer, start+verify in runtime
- Clear logging distinguishing build vs runtime modes

#### 2. Runtime Configuration Playbook

- Dedicated playbook for applying config to running VMs
- Forces `packer_build=false` mode
- Includes pre/post validation tasks

#### 3. Unified Test Framework

- Single script following established pattern
- Commands: `start-cluster`, `stop-cluster`, `deploy-ansible`, `run-tests`, `full-test`, `status`
- Phased workflow support for debugging
- Integrated with shared test framework utilities

#### 4. Makefile Integration

```makefile
test-<name>          # Full workflow
test-<name>-start    # Start cluster
test-<name>-deploy   # Deploy Ansible
test-<name>-tests    # Run tests only
test-<name>-stop     # Stop cluster
test-<name>-status   # Show status
```

#### 5. Documentation

- Pattern documented in task-specific workflow guide
- All remaining tasks follow this pattern

## Test Suite Structure

### Directory Organization

```text
tests/
├── suites/                                # Test suites by component
│   ├── <component-name>/
│   │   ├── check-<aspect-1>.sh          # Specialized validation scripts
│   │   ├── check-<aspect-2>.sh
│   │   ├── check-<aspect-3>.sh
│   │   └── run-<component>-tests.sh     # Master test runner
├── test-infra/
│   ├── configs/                          # Test configurations
│   │   └── test-<component>.yaml
│   └── utils/
│       └── test-framework-utils.sh       # Shared utilities
└── test-<component>-framework.sh         # Unified test framework
```

### Test Script Naming Conventions

- `check-*.sh` - Specialized validation scripts for specific aspects
- `run-*-tests.sh` - Master test runner that orchestrates all checks
- `test-*-framework.sh` - Unified framework with CLI API

## Standard CLI API

All test frameworks implement this standard CLI:

```bash
./test-<component>-framework.sh <command>

Commands:
  e2e                 # Full end-to-end workflow (default)
  start-cluster       # Start test cluster
  stop-cluster        # Stop and clean up cluster
  deploy-ansible      # Deploy Ansible configuration
  run-tests           # Run test suite
  list-tests          # List available tests
  run-test <name>     # Run specific test
  status              # Show cluster status
  help                # Show usage information
```

## Packer Build vs Runtime Deployment

### Packer Build Mode (`packer_build=true`)

**DO:**

- ✅ Install packages and binaries
- ✅ Deploy configuration templates
- ✅ Enable services for auto-start on boot
- ✅ Create directory structures

**DO NOT:**

- ❌ Start services during build
- ❌ Verify service status
- ❌ Test functionality requiring running services
- ❌ Perform cross-node operations

### Runtime Deployment Mode (`packer_build=false`)

**DO:**

- ✅ Start and enable services
- ✅ Verify service status and health
- ✅ Test functionality
- ✅ Validate configuration
- ✅ Confirm integration with other services
- ✅ Perform cross-node operations

## Test Framework Examples

### TASK-018: DCGM GPU Monitoring (Reference Implementation)

```bash
# Phase 1: Build containers and images (local)
cmake --build build --target build-docker-pytorch-cuda12.1-mpi4.1
cmake --build build --target convert-to-apptainer-pytorch-cuda12.1-mpi4.1

# Phase 2: Deploy infrastructure (cluster)
cd tests
make test-dcgm-start        # Start cluster
make test-dcgm-deploy       # Deploy Ansible config

# Phase 3: Run validation tests
make test-dcgm-tests        # Run tests

# Phase 4: Cleanup
make test-dcgm-stop         # Stop cluster

# Or run full workflow
make test-dcgm              # Full e2e workflow
```

### Test Suite Structure Example

```bash
tests/suites/dcgm-monitoring/
├── check-dcgm-installation.sh          # DCGM package and service validation
├── check-dcgm-exporter.sh              # DCGM exporter validation
├── check-prometheus-integration.sh     # Prometheus integration tests
└── run-dcgm-monitoring-tests.sh        # Master test runner
```

## Test Configuration Format

```yaml
version: "1.0"
clusters:
  hpc:
    name: "test-<component>-hpc"
    base_image_path: "build/packer/hpc-controller/hpc-controller.qcow2"
    controller:
      hostname: "test-<component>-controller"
      ip_address: "192.168.XXX.10"
      memory_gb: 4
      cpu_cores: 4
    compute_nodes:
      - hostname: "test-<component>-compute01"
        ip_address: "192.168.XXX.20"
        memory_gb: 8
        cpu_cores: 8
```

## Logging and Output

### Log Directory Structure

```text
tests/logs/
└── <timestamp>/
    ├── <component>-framework.log        # Framework execution log
    ├── <component>-deploy.log           # Ansible deployment log
    ├── <component>-tests.log            # Test execution log
    └── suites/
        └── <component>/
            ├── check-<aspect-1>.log
            ├── check-<aspect-2>.log
            └── summary.log
```

### Logging Best Practices

- Use color-coded output: `log_info`, `log_success`, `log_error`, `log_warning`
- Include timestamps in log files
- Separate framework logs from test logs
- Preserve logs for debugging failed runs
- Clean logs for successful runs (optional)

## Task Compliance Checklist

When implementing a new task with testing:

- [ ] Ansible role separates Packer build and runtime tasks
- [ ] Runtime configuration playbook created
- [ ] Test suites directory created with specialized validation scripts
- [ ] Master test runner orchestrates all checks
- [ ] Unified test framework implements standard CLI API
- [ ] Test configuration created
- [ ] Makefile targets added (6 targets: test, start, deploy, tests, stop, status)
- [ ] Documentation includes workflow guide
- [ ] Follows established pattern from TASK-018

## Related Documentation

- [TASK-018: DCGM GPU Monitoring](../completed/phase-1-core-infrastructure.md#task-018-deploy-dcgm-gpu-monitoring)
- [Standard Test Framework Pattern Documentation](../../../STANDARD-TEST-FRAMEWORK-PATTERN.md)
- [Infrastructure Summary](infrastructure-summary.md)
