# Test Framework Specifications

## Overview

This document provides detailed specifications for each of the 7 test frameworks in the consolidated test infrastructure.
Each specification includes purpose, configuration, test suites, CLI interface, and implementation details.

## Framework Architecture

All frameworks follow a consistent three-layer architecture:

1. **CLI Layer**: Standardized command parsing and help (`framework-cli.sh`)
2. **Orchestration Layer**: Cluster lifecycle and workflow management (`framework-orchestration.sh`)
3. **Execution Layer**: Test suite execution and validation (`test-framework-utils.sh`)

## Unified Frameworks (3 Total)

### 1. test-hpc-runtime-framework.sh

#### Purpose

Unified runtime validation framework for HPC compute nodes. Validates all runtime configuration deployed via
Ansible after Packer images are built.

#### Replaces

- `test-cgroup-isolation-framework.sh`
- `test-gpu-gres-framework.sh`
- `test-job-scripts-framework.sh`
- `test-dcgm-monitoring-framework.sh`
- `test-container-integration-framework.sh`
- `test-slurm-compute-framework.sh`

#### Configuration

**File**: `tests/test-infra/configs/test-hpc-runtime.yaml`

**Key Settings**:

```yaml
cluster:
  name: test-hpc-runtime
  controller_count: 1
  compute_count: 2
  
images:
  controller: hpc-controller-latest.qcow2
  compute: hpc-compute-latest.qcow2
  
resources:
  controller_cpus: 4
  controller_memory: 8192
  compute_cpus: 8
  compute_memory: 16384
  
test_options:
  enable_gpu_tests: true
  enable_container_tests: true
  skip_slow_tests: false
```

#### Test Suites

1. **suites/slurm-compute/** - SLURM compute node validation
   - Installation and configuration
   - Service status and health
   - Node registration with controller
   - Job execution capability

2. **suites/cgroup-isolation/** - Resource isolation validation
   - Cgroup v2 configuration
   - CPU and memory limits
   - Resource enforcement

3. **suites/gpu-gres/** - GPU resource scheduling
   - GRES configuration
   - GPU detection and enumeration
   - SLURM GPU scheduling

4. **suites/dcgm-monitoring/** - GPU monitoring
   - DCGM exporter installation
   - GPU metrics collection
   - Prometheus integration

5. **suites/container-integration/** - ML/AI workload validation
   - PyTorch + CUDA integration
   - MPI communication
   - Distributed training
   - SLURM container integration

6. **suites/job-scripts/** - Job management validation
   - Job submission methods
   - Resource allocation
   - Job templates

#### CLI Interface

```bash
# Complete end-to-end test
./frameworks/test-hpc-runtime-framework.sh e2e

# Modular workflow
./frameworks/test-hpc-runtime-framework.sh start-cluster
./frameworks/test-hpc-runtime-framework.sh deploy-ansible
./frameworks/test-hpc-runtime-framework.sh run-tests
./frameworks/test-hpc-runtime-framework.sh stop-cluster

# Run specific test suite
./frameworks/test-hpc-runtime-framework.sh run-test-suite cgroup-isolation

# List all tests
./frameworks/test-hpc-runtime-framework.sh list-tests

# Run specific test
./frameworks/test-hpc-runtime-framework.sh run-test check-cgroup-config.sh
```

#### Implementation Details

**File Size**: ~40K (vs 109K for 6 separate frameworks)

**Key Functions**:

- `run_cgroup_tests()` - Execute cgroup validation
- `run_gpu_gres_tests()` - Execute GPU GRES validation
- `run_job_script_tests()` - Execute job script validation
- `run_dcgm_tests()` - Execute DCGM monitoring validation
- `run_container_tests()` - Execute container integration validation
- `run_compute_tests()` - Execute SLURM compute validation
- `run_all_runtime_tests()` - Execute all test suites in sequence

**Ansible Playbook**: `ansible/playbooks/playbook-hpc-runtime.yml`

**Estimated Duration**: 30-45 minutes

---

### 2. test-hpc-packer-controller-framework.sh

#### Purpose

Unified Packer validation framework for HPC controller images. Validates all controller components installed
during Packer image build.

#### Replaces

- `test-slurm-controller-framework.sh`
- `test-slurm-accounting-framework.sh`
- `test-monitoring-stack-framework.sh`
- `test-grafana-framework.sh`

#### Configuration

**File**: `tests/test-infra/configs/test-hpc-packer-controller.yaml`

**Key Settings**:

```yaml
cluster:
  name: test-hpc-packer-controller
  controller_count: 1
  compute_count: 1
  
images:
  controller: hpc-controller-latest.qcow2
  compute: hpc-compute-latest.qcow2
  
resources:
  controller_cpus: 4
  controller_memory: 8192
  compute_cpus: 4
  compute_memory: 8192
  
test_options:
  validate_packer_build: true
  skip_runtime_config: false
```

#### Test Suites

1. **suites/slurm-controller/** - SLURM controller validation
   - SLURM controller installation
   - Configuration files
   - Service status
   - Basic job submission

2. **suites/monitoring-stack/** - Monitoring infrastructure
   - Prometheus installation
   - Node Exporter installation
   - Grafana installation
   - Metrics collection
   - Dashboard provisioning

3. **suites/basic-infrastructure/** - Basic system validation
   - Package installation
   - System configuration
   - Network connectivity

#### CLI Interface

```bash
# Complete end-to-end test
./frameworks/test-hpc-packer-controller-framework.sh e2e

# Modular workflow
./frameworks/test-hpc-packer-controller-framework.sh start-cluster
./frameworks/test-hpc-packer-controller-framework.sh deploy-ansible
./frameworks/test-hpc-packer-controller-framework.sh run-tests
./frameworks/test-hpc-packer-controller-framework.sh stop-cluster

# Run specific component tests
./frameworks/test-hpc-packer-controller-framework.sh run-test-suite slurm-controller
./frameworks/test-hpc-packer-controller-framework.sh run-test-suite monitoring-stack
```

#### Implementation Details

**File Size**: ~35K (vs 58K for 4 separate frameworks)

**Key Functions**:

- `run_slurm_controller_tests()` - Execute SLURM controller validation
- `run_slurm_accounting_tests()` - Execute accounting validation
- `run_monitoring_tests()` - Execute Prometheus validation
- `run_grafana_tests()` - Execute Grafana validation
- `run_all_controller_tests()` - Execute all test suites in sequence

**Ansible Playbook**: `ansible/playbooks/playbook-hpc-packer-controller.yml`

**Estimated Duration**: 20-30 minutes

---

### 3. test-hpc-packer-compute-framework.sh

#### Purpose

Unified Packer validation framework for HPC compute images. Validates all compute components installed during
Packer image build.

#### Replaces

- `test-container-runtime-framework.sh`

#### Configuration

**File**: `tests/test-infra/configs/test-hpc-packer-compute.yaml`

**Key Settings**:

```yaml
cluster:
  name: test-hpc-packer-compute
  controller_count: 1
  compute_count: 1
  
images:
  controller: hpc-controller-latest.qcow2
  compute: hpc-compute-latest.qcow2
  
resources:
  controller_cpus: 2
  controller_memory: 4096
  compute_cpus: 4
  compute_memory: 8192
  
test_options:
  validate_packer_build: true
  validate_container_runtime: true
```

#### Test Suites

1. **suites/container-runtime/** - Container runtime validation
   - Apptainer/Singularity installation
   - Version compatibility
   - Security configuration
   - Container execution capability

#### CLI Interface

```bash
# Complete end-to-end test
./frameworks/test-hpc-packer-compute-framework.sh e2e

# Modular workflow
./frameworks/test-hpc-packer-compute-framework.sh start-cluster
./frameworks/test-hpc-packer-compute-framework.sh deploy-ansible
./frameworks/test-hpc-packer-compute-framework.sh run-tests
./frameworks/test-hpc-packer-compute-framework.sh stop-cluster
```

#### Implementation Details

**File Size**: ~15K (provides consistency with other Packer frameworks)

**Key Functions**:

- `run_container_runtime_tests()` - Execute container runtime validation
- `validate_security_config()` - Validate security policies
- `test_container_execution()` - Test basic container execution

**Ansible Playbook**: `ansible/playbooks/playbook-hpc-packer-compute.yml`

**Estimated Duration**: 15-20 minutes

---

## Standalone Frameworks (4 Total)

### 4. test-beegfs-framework.sh

#### Purpose

Validates BeeGFS parallel filesystem deployment and functionality.

#### Current Status

Refactored to use shared utilities

#### Configuration

**File**: `tests/test-infra/configs/test-beegfs.yaml`

**Key Settings**:

```yaml
cluster:
  name: test-beegfs
  controller_count: 1
  compute_count: 2
  
storage:
  beegfs:
    enabled: true
    mgmt_path: /data/beegfs/mgmt
    meta_path: /data/beegfs/meta
    storage_path: /data/beegfs/storage
    mount_point: /mnt/beegfs
```

#### Test Suites

1. **suites/beegfs/** - BeeGFS validation
   - Management service
   - Metadata service
   - Storage services
   - Client mounts
   - Multi-node connectivity
   - I/O performance

#### CLI Interface

```bash
./advanced/test-beegfs-framework.sh e2e
./advanced/test-beegfs-framework.sh start-cluster
./advanced/test-beegfs-framework.sh deploy-ansible
./advanced/test-beegfs-framework.sh run-tests
./advanced/test-beegfs-framework.sh stop-cluster
```

#### Implementation Details

**File Size**: ~8K (reduced from 15K via shared utilities)

**Ansible Playbook**: `ansible/playbooks/playbook-hpc-runtime.yml` (with BeeGFS enabled)

**Estimated Duration**: 15-25 minutes

---

### 5. test-virtio-fs-framework.sh

#### Purpose

Validates VirtIO-FS filesystem sharing between host and guest VMs.

#### Current Status

Refactored to use shared utilities

#### Configuration

**File**: `tests/test-infra/configs/test-virtio-fs.yaml`

**Key Settings**:

```yaml
cluster:
  name: test-virtio-fs
  controller_count: 1
  compute_count: 1
  
storage:
  virtio_fs_mounts:
    - host_path: /opt/shared
      guest_mount: /mnt/host-shared
      tag: shared
```

#### Test Suites

1. **suites/virtio-fs/** - VirtIO-FS validation
   - Mount point configuration
   - Host directory access
   - File permissions
   - I/O performance

#### CLI Interface

```bash
./advanced/test-virtio-fs-framework.sh e2e
./advanced/test-virtio-fs-framework.sh start-cluster
./advanced/test-virtio-fs-framework.sh deploy-ansible
./advanced/test-virtio-fs-framework.sh run-tests
./advanced/test-virtio-fs-framework.sh stop-cluster
```

#### Implementation Details

**File Size**: ~12K (reduced from 24K via shared utilities)

**Ansible Playbook**: `ansible/playbooks/playbook-hpc-runtime.yml` (with VirtIO-FS enabled)

**Estimated Duration**: 10-20 minutes

---

### 6. test-pcie-passthrough-framework.sh

#### Purpose

Validates GPU PCIe passthrough configuration and functionality.

#### Current Status

Refactored to use shared utilities

#### Configuration

**File**: `tests/test-infra/configs/test-pcie-passthrough.yaml`

**Key Settings**:

```yaml
cluster:
  name: test-pcie-passthrough
  controller_count: 1
  compute_count: 1
  
hardware:
  gpu_passthrough: true
  gpu_pci_ids:
    - "0000:01:00.0"
    - "0000:02:00.0"
```

#### Test Suites

1. **suites/gpu-validation/** - GPU passthrough validation
   - GPU device visibility
   - PCIe device assignment
   - GPU driver functionality
   - Multi-GPU configuration

#### CLI Interface

```bash
./frameworks/test-pcie-passthrough-framework.sh e2e
./frameworks/test-pcie-passthrough-framework.sh start-cluster
./frameworks/test-pcie-passthrough-framework.sh run-tests
./frameworks/test-pcie-passthrough-framework.sh stop-cluster
```

#### Implementation Details

**File Size**: ~7K (reduced from 13K via shared utilities)

**Ansible Playbook**: Not applicable (hardware passthrough)

**Estimated Duration**: 10-20 minutes

**Note**: Requires GPU hardware; tests skip gracefully if not available

---

### 7. test-container-registry-framework.sh

#### Purpose

Validates container registry deployment, image distribution, and SLURM integration.

#### Current Status

Refactored to use shared utilities

#### Configuration

**File**: `tests/test-infra/configs/test-container-registry.yaml`

**Key Settings**:

```yaml
cluster:
  name: test-container-registry
  controller_count: 1
  compute_count: 2
  
containers:
  registry:
    enabled: true
    storage_path: /opt/containers
    images:
      - pytorch-cuda12.1-mpi4.1
```

#### Test Suites

1. **suites/container-registry/** - Registry validation
   - Registry installation
   - Storage backend
   - Image distribution
   - SLURM integration
   - Multi-node access

2. **suites/container-deployment/** - Image deployment
   - Image building
   - Format conversion
   - Distribution workflow

3. **suites/container-e2e/** - End-to-end container validation
   - Complete workflow validation
   - Integration testing

#### CLI Interface

```bash
./advanced/test-container-registry-framework.sh e2e
./advanced/test-container-registry-framework.sh start-cluster
./advanced/test-container-registry-framework.sh deploy-ansible
./advanced/test-container-registry-framework.sh deploy-images
./advanced/test-container-registry-framework.sh run-tests
./advanced/test-container-registry-framework.sh stop-cluster
```

#### Implementation Details

**File Size**: ~35K (reduced from 50K via shared utilities)

**Ansible Playbook**: Multiple playbooks for registry and image deployment

**Estimated Duration**: 15-25 minutes

**Note**: Requires pre-built container images

---

## Shared Utilities Specifications

### framework-cli.sh

**Purpose**: Standardized CLI parsing and command dispatch

**Size**: ~400 lines

**Key Functions**:

```bash
parse_framework_cli()          # Main CLI parser
show_framework_help()          # Generate help output
parse_framework_options()      # Parse options (-v, --help, etc)
list_test_suites_help()        # List test suites for help
```

**Usage Pattern**:

```bash
source "$PROJECT_ROOT/tests/test-infra/utils/framework-cli.sh"
parse_framework_cli "$@"
```

---

### framework-orchestration.sh

**Purpose**: Cluster lifecycle and workflow orchestration

**Size**: ~300 lines

**Key Functions**:

```bash
start_test_cluster()           # Start cluster with config
stop_test_cluster()            # Stop and cleanup cluster
run_e2e_workflow()             # Full e2e workflow
deploy_ansible_config()        # Deploy Ansible playbook
run_test_suite_wrapper()       # Run tests with error handling
validate_test_environment()    # Pre-flight checks
```

**Usage Pattern**:

```bash
source "$PROJECT_ROOT/tests/test-infra/utils/framework-orchestration.sh"
run_e2e_workflow
```

---

### test-framework-utils.sh (Enhanced)

**Purpose**: Common test utilities and helper functions

**Current Size**: ~500 lines

**Target Size**: ~700 lines

**Key Functions**:

```bash
# Existing functions
source_common_test_config()
ensure_project_root()
deploy_ansible_playbook()
run_test_suite()
list_test_scripts()
run_individual_test()
stop_test_cluster()
show_cluster_status()

# New/enhanced functions
validate_test_config()         # Validate test configuration
setup_test_environment()       # Prepare test environment
run_test_with_timeout()        # Execute test with timeout
collect_test_artifacts()       # Gather logs and outputs
generate_test_report()         # Create test summary report
```

---

## Standard CLI Pattern

All frameworks implement the same CLI interface:

### Commands

| Command | Description | Usage |
|---------|-------------|-------|
| `e2e` | Complete end-to-end test | Default if no command specified |
| `start-cluster` | Start test cluster | Keeps cluster running |
| `stop-cluster` | Stop test cluster | Cleanup resources |
| `deploy-ansible` | Deploy Ansible config | Requires running cluster |
| `run-tests` | Run test suite | Requires deployed config |
| `list-tests` | List available tests | Show all test scripts |
| `run-test NAME` | Run specific test | Execute single test |
| `status` | Show cluster status | Display current state |
| `help` | Show help message | Display usage info |

### Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-v, --verbose` | Enable verbose output |
| `--no-cleanup` | Skip cleanup after tests |
| `--interactive` | Enable interactive prompts |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Configuration error |
| 3 | Cluster startup failed |
| 4 | Ansible deployment failed |
| 5 | Test execution failed |

---

## Configuration File Structure

All test configurations follow a standard YAML structure:

```yaml
# Cluster configuration
cluster:
  name: test-framework-name
  controller_count: 1
  compute_count: 2

# VM images
images:
  controller: hpc-controller-latest.qcow2
  compute: hpc-compute-latest.qcow2

# Resource allocation
resources:
  controller_cpus: 4
  controller_memory: 8192
  compute_cpus: 8
  compute_memory: 16384

# Test-specific options
test_options:
  enable_gpu_tests: true
  skip_slow_tests: false
  timeout_minutes: 60

# Component-specific configuration
# (varies by framework)
```

---

## Implementation Checklist

For each new or refactored framework:

- [ ] Framework script created/updated
- [ ] Configuration file created/updated
- [ ] Test suites identified and mapped
- [ ] CLI interface implemented
- [ ] Shared utilities integrated
- [ ] Help documentation complete
- [ ] Error handling implemented
- [ ] Logging and output consistent
- [ ] End-to-end test successful
- [ ] Individual commands tested
- [ ] Documentation updated
- [ ] Makefile target created

---

## System Management Framework (1 Total)

### test-system-management-framework.sh (NEW)

**Purpose**: Unified system-wide cluster management and coordinated operations

**File Location**: `tests/frameworks/test-system-management-framework.sh`

**Current Status**: To be implemented in CLOUD-0.6

**Configuration**

**File**: `tests/test-infra/configs/test-system-management.yaml`

**Key Settings**:

```yaml
cluster:
  name: test-system-management
  hpc_config: config/hpc-cluster.yaml
  cloud_config: config/cloud-cluster.yaml

system_options:
  test_startup_ordering: true
  test_shutdown_ordering: true
  test_failure_scenarios: true
  test_shared_resources: true
```

**Test Suites**

1. **suites/system-management/** - System-wide operations
   - System start command
   - System stop command
   - System destroy command
   - System status command
   - Startup ordering (HPC → Cloud)
   - Shutdown ordering (Cloud → HPC)
   - Failure rollback
   - Config validation
   - Error handling
   - Shared resources display

**CLI Interface**

```bash
# Complete system end-to-end test
./frameworks/test-system-management-framework.sh e2e

# Modular workflow
./frameworks/test-system-management-framework.sh start-system
./frameworks/test-system-management-framework.sh system-status
./frameworks/test-system-management-framework.sh run-tests
./frameworks/test-system-management-framework.sh stop-system
./frameworks/test-system-management-framework.sh destroy-system

# Run specific test suite
./frameworks/test-system-management-framework.sh run-test-suite system-start-ordering

# List all tests
./frameworks/test-system-management-framework.sh list-tests

# Run specific test
./frameworks/test-system-management-framework.sh run-test check-system-start-ordering.sh
```

**Implementation Details**

**File Size**: ~20K

**Key Functions**:

- `run_system_startup_tests()` - Validate startup ordering and sequence
- `run_system_shutdown_tests()` - Validate shutdown ordering
- `run_system_status_tests()` - Validate status display
- `run_system_destroy_tests()` - Validate destroy operations
- `run_failure_scenario_tests()` - Validate rollback and error handling
- `run_all_system_tests()` - Execute all test suites in sequence

**Dependencies**: Both test-hpc-runtime and test-cloud-vm frameworks

**Estimated Duration**: 30-40 minutes

---

## Summary

These specifications provide a complete blueprint for the 7 consolidated test frameworks. All frameworks share
a consistent architecture, CLI interface, and implementation pattern while maintaining flexibility for
component-specific requirements.

The consolidation reduces code duplication significantly while preserving 100% test coverage and improving
developer experience through standardized interfaces.
