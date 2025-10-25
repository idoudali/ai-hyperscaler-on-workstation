# Test Dependencies and Cluster Configuration Matrix

## Overview

This document provides detailed dependency and cluster configuration requirements for each test suite in the HPC SLURM
infrastructure. Use this matrix to understand what prerequisites, hardware, and cluster topology are needed for each test.

## Document Purpose

- **Per-Test Dependencies**: What each test suite requires to execute
- **Cluster Configuration**: Minimum cluster topology and resource allocations
- **Hardware Requirements**: GPU, storage, network requirements
- **Execution Prerequisites**: Pre-built images, packages, services needed
- **Configuration Flags**: Test-specific configuration options

## Matrix Legend

- **Required**: Must be present for test to execute
- **Optional**: Enhances test coverage but not mandatory
- **Conditional**: Required only for specific test scenarios
- **N/A**: Not applicable to this test suite

---

## Test Configuration Mapping

Each test suite uses a specific cluster configuration file from `tests/test-infra/configs/` or the default
`config/example-multi-gpu-clusters.yaml`. This section maps tests to their configurations.

### Configuration Selection Guide

| Test Suite | Configuration File | Use Default? | Notes |
|------------|-------------------|--------------|-------|
| **cgroup-isolation** | `test-cgroup-isolation.yaml` | No | Specialized cgroup testing |
| **gpu-gres** | `test-gpu-gres.yaml` | No | GPU GRES specific config |
| **job-scripts** | `test-job-scripts.yaml` | No | Job script testing config |
| **dcgm-monitoring** | `test-dcgm-monitoring.yaml` | No | GPU monitoring specific |
| **container-integration** | `test-container-integration.yaml` | No | Container + GPU testing |
| **slurm-compute** | `test-slurm-compute.yaml` | No | Multi-node compute config |
| **slurm-controller** | `test-slurm-controller.yaml` | No | Controller-only testing |
| **monitoring-stack** | `test-monitoring-stack.yaml` | No | Monitoring validation |
| **container-runtime** | `test-container-runtime.yaml` | No | Container runtime specific |
| **beegfs** | `test-beegfs.yaml` | No | BeeGFS multi-node config |
| **virtio-fs** | `test-virtio-fs.yaml` | No | VirtIO-FS host sharing |
| **gpu-validation** | `test-pcie-passthrough-minimal.yaml` | No | PCIe passthrough testing |
| **container-registry** | `test-container-registry.yaml` | No | Registry infrastructure |
| **full-stack** | `test-full-stack.yaml` | No | Complete integration test |
| **minimal** | `test-minimal.yaml` | No | Smoke test configuration |

**Default Configuration**: `config/example-multi-gpu-clusters.yaml` is suitable for:

- Manual testing with full GPU hardware
- Development environment validation
- Integration testing across all components

---

## Makefile Cluster Operations

Use these Makefile targets for cluster lifecycle management during testing:

### Basic Cluster Operations

```bash
# Start cluster (auto-cleans SSH keys)
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml

# Check cluster status
make cluster-status CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml

# Stop cluster (graceful shutdown)
make cluster-stop CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml

# Destroy cluster (full cleanup)
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml
```

### Ansible Deployment Operations

```bash
# Generate Ansible inventory from cluster config
make cluster-inventory CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml

# Deploy runtime configuration via Ansible
make cluster-deploy CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml

# Full validation workflow (inventory → start → deploy → test)
make validate-cluster-full CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml

# Runtime validation only (assumes cluster running)
make validate-cluster-runtime CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml
```

### SSH Key Management

```bash
# Clean SSH keys for cluster IPs (run before cluster-start)
make clean-ssh-keys CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml
```

### Configuration Rendering

```bash
# Render configuration with variable expansion
make config-render CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml

# Validate configuration without rendering
make config-validate CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml
```

---

## Ansible Deployment Strategy

### Two Testing Approaches

#### Approach 1: Fresh Deployment Per Test (Recommended for CI/CD)

**Use Case**: Isolated test execution, clean slate for each test suite

```bash
# For each test:
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml
make cluster-deploy CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml
# Run test framework
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml
```

**Advantages**:

- ✅ Complete isolation between tests
- ✅ Catches configuration drift issues
- ✅ Tests Ansible deployment itself
- ✅ Reproducible from clean state

**Disadvantages**:

- ⏱️ Slower (full deployment per test)
- 💾 More resource intensive
- 🔄 Longer feedback loop

**Best For**:

- CI/CD pipelines
- Release validation
- Ansible playbook testing
- Full integration testing

---

#### Approach 2: Shared Pre-Configured Cluster (Recommended for Development)

**Use Case**: Rapid test iteration, development workflow

```bash
# One-time setup:
make cluster-start CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml
make cluster-deploy CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml

# Run tests repeatedly against same cluster:
./tests/test-hpc-runtime-framework.sh --suite cgroup-isolation
./tests/test-hpc-runtime-framework.sh --suite gpu-gres
./tests/test-hpc-runtime-framework.sh --suite container-integration

# Cleanup when done:
make cluster-destroy CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml
```

**Advantages**:

- ⚡ Fast test execution
- 🔄 Quick iteration cycle
- 💾 Resource efficient
- 🎯 Focus on test logic

**Disadvantages**:

- ⚠️ Test pollution possible
- ⚠️ State accumulation between runs
- ⚠️ Doesn't validate deployment
- ⚠️ May miss configuration issues

**Best For**:

- Local development
- Test debugging
- Rapid prototyping
- Feature development

---

### Hybrid Approach (Recommended)

Use both strategies based on context:

```bash
# Development: Shared cluster for quick iteration
make cluster-start CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml
make cluster-deploy CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml
# Run tests multiple times
make cluster-stop

# Pre-commit: Fresh deployment for critical tests
make validate-cluster-full CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml

# CI/CD: Fresh deployment for each test suite
for config in tests/test-infra/configs/test-*.yaml; do
  make validate-cluster-full CLUSTER_CONFIG=$config
done
```

---

## Per-Test Deployment Requirements

### Tests Requiring Fresh Ansible Deployment

These tests **MUST** start with Ansible deployment as they validate the deployment itself:

1. **test-hpc-packer-controller** (slurm-controller, monitoring-stack)
   - Validates Packer image contents
   - Tests service installation
   - **Requires**: Fresh deployment from Packer images

2. **test-hpc-packer-compute** (container-runtime)
   - Validates compute image contents
   - Tests Apptainer installation
   - **Requires**: Fresh deployment from Packer images

3. **test-beegfs** (beegfs)
   - Validates BeeGFS service deployment
   - Tests multi-node storage configuration
   - **Requires**: Fresh Ansible deployment of BeeGFS roles

4. **test-container-registry** (container-registry)
   - Validates registry infrastructure deployment
   - Tests image distribution
   - **Requires**: Fresh Ansible deployment of registry role

### Tests That Can Use Pre-Configured Cluster

These tests validate **runtime behavior** and can run against an already-deployed cluster:

1. **test-hpc-runtime** (cgroup-isolation, gpu-gres, job-scripts, slurm-compute)
   - Validates SLURM job execution
   - Tests resource isolation
   - **Can use**: Pre-deployed cluster (if Ansible already ran)

2. **test-hpc-runtime** (dcgm-monitoring, container-integration)
   - Validates monitoring metrics
   - Tests containerized workloads
   - **Can use**: Pre-deployed cluster with GPU

3. **test-virtio-fs** (virtio-fs)
   - Validates host directory sharing
   - Tests mount points
   - **Can use**: Pre-deployed cluster with VirtIO-FS

4. **test-pcie-passthrough** (gpu-validation)
   - Validates GPU passthrough
   - Tests device visibility
   - **Can use**: Pre-deployed cluster with GPU

---

## Example Test Execution Workflows

### Workflow 1: Full Isolation (CI/CD)

```bash
#!/bin/bash
# Test cgroup isolation with fresh deployment

CONFIG="tests/test-infra/configs/test-cgroup-isolation.yaml"

# Step 1: Start cluster
make cluster-start CLUSTER_CONFIG=$CONFIG

# Step 2: Deploy Ansible configuration
make cluster-deploy CLUSTER_CONFIG=$CONFIG

# Step 3: Run test suite
./tests/test-hpc-runtime-framework.sh --suite cgroup-isolation --config $CONFIG

# Step 4: Cleanup
make cluster-destroy CLUSTER_CONFIG=$CONFIG
```

### Workflow 2: Shared Cluster (Development)

```bash
#!/bin/bash
# Multiple tests against pre-configured cluster

CONFIG="config/example-multi-gpu-clusters.yaml"

# One-time setup
make cluster-start CLUSTER_CONFIG=$CONFIG
make cluster-deploy CLUSTER_CONFIG=$CONFIG

# Run multiple tests
./tests/test-hpc-runtime-framework.sh --suite cgroup-isolation
./tests/test-hpc-runtime-framework.sh --suite slurm-compute
./tests/test-hpc-runtime-framework.sh --suite job-scripts

# Cleanup when done
make cluster-stop CLUSTER_CONFIG=$CONFIG
```

### Workflow 3: Hybrid (Recommended)

```bash
#!/bin/bash
# Fast iteration with periodic reset

CONFIG="config/example-multi-gpu-clusters.yaml"

# Initial deployment
make cluster-start CLUSTER_CONFIG=$CONFIG
make cluster-deploy CLUSTER_CONFIG=$CONFIG

# Development iteration loop
for i in {1..5}; do
  echo "Test iteration $i"
  ./tests/test-hpc-runtime-framework.sh --suite cgroup-isolation
  
  # Reset cluster state every 3 runs
  if [ $((i % 3)) -eq 0 ]; then
    echo "Resetting cluster..."
    make cluster-stop CLUSTER_CONFIG=$CONFIG
    make cluster-start CLUSTER_CONFIG=$CONFIG
    make cluster-deploy CLUSTER_CONFIG=$CONFIG
  fi
done

# Final cleanup
make cluster-destroy CLUSTER_CONFIG=$CONFIG
```

---

## Test Framework Dependency Matrix

### Framework 1: test-hpc-runtime-framework.sh

**Purpose**: Runtime validation for HPC compute nodes via Ansible

**Deployment Strategy**: Can use pre-configured cluster OR fresh deployment

#### Cluster Configuration

| Setting | Requirement | Rationale |
|---------|-------------|-----------|
| **Controller Nodes** | 1 (minimum) | SLURM controller, job scheduling |
| **Compute Nodes** | 2 (minimum) | Multi-node job testing, MPI validation |
| **Controller CPU** | 4 cores | Prometheus, SLURM controller, monitoring |
| **Controller Memory** | 8 GB | Prometheus time series storage |
| **Compute CPU** | 8 cores | GPU workloads, container execution |
| **Compute Memory** | 16 GB | ML/AI container workloads |
| **Storage** | 50 GB per node | Container images, test artifacts |
| **Network** | Private bridge | Multi-node communication, MPI |

#### Hardware Dependencies

| Requirement | Status | Used By Test Suite | Notes |
|-------------|--------|-------------------|-------|
| **GPUs** | Optional | gpu-gres, dcgm-monitoring, container-integration | Tests skip if no GPU |
| **MIG GPUs** | Optional | gpu-gres | Advanced GPU partitioning tests |
| **NVMe Storage** | Optional | Performance tests | Enhances I/O performance |
| **10Gb+ Network** | Optional | container-integration | Multi-node training tests |

#### Test Suite Dependencies

##### suites/cgroup-isolation/

**Configuration File**: `tests/test-infra/configs/test-cgroup-isolation.yaml`

**Makefile Usage**:

```bash
# Start cluster with cgroup test config
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml

# Deploy Ansible configuration
make cluster-deploy CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml

# Run test
./tests/test-hpc-runtime-framework.sh --suite cgroup-isolation

# Cleanup
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-cgroup-isolation.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1
  compute_count: 1  # Single node sufficient

resources:
  compute_cpus: 4
  compute_memory: 8192
```

**Prerequisites**:

- ✅ Cgroup v2 filesystem mounted
- ✅ SLURM with cgroup plugin
- ✅ Test user with resource limits

**Test-Specific Requirements**:

- `/sys/fs/cgroup` writable
- `systemd-cgtop` available
- Cgroup controllers enabled: `cpu`, `memory`, `cpuset`

**Configuration Flags**:

```yaml
test_options:
  enable_cgroup_tests: true
  cgroup_version: 2
  test_memory_limits: true
  test_cpu_limits: true
```

**Dependencies**:

- **Required**: SLURM compute node deployed
- **Required**: Ansible cgroup configuration applied
- **Optional**: Stress testing tools (`stress-ng`)

**Deployment Strategy**: Can use pre-configured cluster with Ansible cgroup role applied

---

##### suites/gpu-gres/

**Configuration File**: `tests/test-infra/configs/test-gpu-gres.yaml`

**Makefile Usage**:

```bash
# Start cluster with GPU GRES config
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-gpu-gres.yaml

# Deploy Ansible GPU configuration
make cluster-deploy CLUSTER_CONFIG=tests/test-infra/configs/test-gpu-gres.yaml

# Run test
./tests/test-hpc-runtime-framework.sh --suite gpu-gres

# Cleanup
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-gpu-gres.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1
  compute_count: 1

hardware:
  gpu_passthrough: true
  gpu_count: 1  # Minimum
```

**Prerequisites**:

- ✅ NVIDIA drivers installed
- ✅ CUDA runtime available
- ✅ `gres.conf` configured
- ✅ GPU visible in compute node

**Hardware Requirements**:

- **Required**: At least 1 GPU (NVIDIA)
- **Optional**: MIG-capable GPU for advanced tests
- **Required**: PCIe passthrough configured

**Test-Specific Requirements**:

- `nvidia-smi` available
- GPU driver version compatible with SLURM
- GRES plugin enabled in SLURM

**Configuration Flags**:

```yaml
test_options:
  enable_gpu_tests: true
  gpu_type: nvidia  # or mig
  skip_if_no_gpu: true
```

**Dependencies**:

- **Required**: GPU hardware present
- **Required**: SLURM GRES plugin configured
- **Conditional**: MIG configuration (if testing MIG)

**Deployment Strategy**: Requires fresh Ansible deployment to configure GPU GRES

---

##### suites/job-scripts/

**Configuration File**: `tests/test-infra/configs/test-job-scripts.yaml`

**Makefile Usage**:

```bash
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-job-scripts.yaml
make cluster-deploy CLUSTER_CONFIG=tests/test-infra/configs/test-job-scripts.yaml
./tests/test-hpc-runtime-framework.sh --suite job-scripts
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-job-scripts.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1
  compute_count: 2  # Multi-node jobs

resources:
  compute_cpus: 4
  compute_memory: 8192
```

**Prerequisites**:

- ✅ SLURM controller operational
- ✅ Compute nodes registered
- ✅ MUNGE authentication working
- ✅ Job submission tools available

**Test-Specific Requirements**:

- `sbatch`, `srun`, `salloc` binaries
- Job accounting database (optional)
- Shared filesystem or NFS

**Configuration Flags**:

```yaml
test_options:
  test_array_jobs: true
  test_multi_node_jobs: true
  max_job_wait_time: 300  # seconds
```

**Dependencies**:

- **Required**: SLURM fully operational
- **Required**: At least 2 compute nodes for multi-node tests
- **Optional**: Job accounting enabled

**Deployment Strategy**: Can use pre-configured cluster

---

##### suites/dcgm-monitoring/

**Configuration File**: `tests/test-infra/configs/test-dcgm-monitoring.yaml`

**Makefile Usage**:

```bash
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-dcgm-monitoring.yaml
make cluster-deploy CLUSTER_CONFIG=tests/test-infra/configs/test-dcgm-monitoring.yaml
./tests/test-hpc-runtime-framework.sh --suite dcgm-monitoring
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-dcgm-monitoring.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1
  compute_count: 1

hardware:
  gpu_passthrough: true
  gpu_count: 1
```

**Prerequisites**:

- ✅ DCGM exporter installed
- ✅ Prometheus available
- ✅ GPU accessible
- ✅ DCGM service running

**Hardware Requirements**:

- **Required**: NVIDIA GPU with DCGM support
- **Required**: GPU driver version >= 450.80

**Test-Specific Requirements**:

- DCGM exporter port accessible (default: 9400)
- Prometheus configured to scrape DCGM metrics
- GPU metrics endpoint: `http://compute-node:9400/metrics`

**Configuration Flags**:

```yaml
test_options:
  enable_dcgm_tests: true
  dcgm_exporter_port: 9400
  prometheus_endpoint: "http://controller:9090"
```

**Dependencies**:

- **Required**: GPU hardware
- **Required**: DCGM exporter installed
- **Required**: Prometheus monitoring stack
- **Conditional**: Grafana (if testing dashboards)

**Deployment Strategy**: Requires fresh Ansible deployment for DCGM configuration

---

##### suites/container-integration/

**Configuration File**: `tests/test-infra/configs/test-container-integration.yaml`

**Makefile Usage**:

```bash
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-container-integration.yaml
make cluster-deploy CLUSTER_CONFIG=tests/test-infra/configs/test-container-integration.yaml
./tests/test-hpc-runtime-framework.sh --suite container-integration
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-container-integration.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1
  compute_count: 2  # Distributed training

resources:
  compute_cpus: 8
  compute_memory: 16384  # ML workloads

hardware:
  gpu_passthrough: true
  gpu_count: 1  # Per compute node
```

**Prerequisites**:

- ✅ Apptainer/Singularity installed
- ✅ Container images available
- ✅ GPU accessible in containers
- ✅ MPI runtime installed
- ✅ SLURM configured for containers

**Container Images Required**:

- `pytorch-cuda12.1-mpi4.1.sif` (PyTorch + CUDA)
- `mpi-test.sif` (MPI validation)

**Test-Specific Requirements**:

- Container images at `/opt/containers/`
- GPU device files accessible in containers
- Shared filesystem for multi-node training
- NCCL library for GPU communication

**Configuration Flags**:

```yaml
test_options:
  enable_container_tests: true
  container_runtime: apptainer
  test_pytorch: true
  test_mpi: true
  test_distributed_training: true
  container_image_path: /opt/containers
```

**Dependencies**:

- **Required**: GPU hardware
- **Required**: Container runtime installed
- **Required**: Container images pre-built
- **Required**: MPI library compatible with SLURM
- **Conditional**: Multiple GPUs for multi-GPU tests
- **Conditional**: 10Gb+ network for distributed training

**Deployment Strategy**: Requires fresh Ansible deployment for container registry and image distribution

---

##### suites/slurm-compute/

**Configuration File**: `tests/test-infra/configs/test-slurm-compute.yaml`

**Makefile Usage**:

```bash
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-slurm-compute.yaml
make cluster-deploy CLUSTER_CONFIG=tests/test-infra/configs/test-slurm-compute.yaml
./tests/test-hpc-runtime-framework.sh --suite slurm-compute
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-slurm-compute.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1
  compute_count: 1  # Basic validation

resources:
  compute_cpus: 4
  compute_memory: 8192
```

**Prerequisites**:

- ✅ SLURM controller operational
- ✅ MUNGE key distributed
- ✅ Compute packages installed
- ✅ Network connectivity

**Test-Specific Requirements**:

- `slurmd` daemon installed
- SLURM configuration synchronized
- Node can communicate with controller
- MUNGE authentication working

**Configuration Flags**:

```yaml
test_options:
  test_node_registration: true
  test_job_execution: true
  validate_slurm_conf: true
```

**Dependencies**:

- **Required**: SLURM controller running
- **Required**: MUNGE authentication configured
- **Required**: Network connectivity between nodes

**Deployment Strategy**: Can use pre-configured cluster OR requires Packer image validation

---

### Framework 2: test-hpc-packer-controller-framework.sh

**Purpose**: Validate HPC controller Packer image builds

**Deployment Strategy**: MUST use fresh deployment from Packer images - validates image contents

#### Cluster Configuration

| Setting | Requirement | Rationale |
|---------|-------------|-----------|
| **Controller Nodes** | 1 | Single controller validation |
| **Compute Nodes** | 1 (minimal) | Basic job submission testing |
| **Controller CPU** | 4 cores | SLURM + Prometheus + Grafana |
| **Controller Memory** | 8 GB | Monitoring stack storage |
| **Compute CPU** | 2 cores | Minimal for job execution |
| **Compute Memory** | 4 GB | Basic job workloads |
| **Storage** | 30 GB controller | Prometheus time series, logs |

#### Hardware Dependencies

| Requirement | Status | Notes |
|-------------|--------|-------|
| **GPUs** | N/A | Controller doesn't need GPU |
| **Fast Disk** | Optional | Improves Prometheus performance |

#### Test Suite Dependencies

##### suites/slurm-controller/

**Configuration File**: `tests/test-infra/configs/test-slurm-controller.yaml`

**Makefile Usage**:

```bash
# Build Packer image first
make run-docker COMMAND="cmake --build build --target hpc-controller"

# Start and test
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-slurm-controller.yaml
./tests/test-hpc-packer-controller-framework.sh --suite slurm-controller
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-slurm-controller.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1
  compute_count: 1  # For job submission tests

resources:
  controller_cpus: 4
  controller_memory: 8192
```

**Prerequisites**:

- ✅ SLURM packages installed via Packer
- ✅ slurmdbd database accessible
- ✅ MUNGE key generated
- ✅ SLURM configuration files present

**Test-Specific Requirements**:

- `slurmctld` daemon installed
- `slurmdbd` daemon installed
- MariaDB/MySQL for accounting
- SLURM configuration valid (`slurm.conf`, `slurmdbd.conf`)

**Configuration Flags**:

```yaml
test_options:
  validate_packer_build: true
  test_accounting_database: true
  test_job_submission: true
```

**Dependencies**:

- **Required**: Packer image built successfully
- **Required**: Database for accounting (MariaDB/MySQL)
- **Required**: Compute node for job testing
- **Optional**: Multiple compute nodes for scheduling tests

**Deployment Strategy**: MUST start from fresh Packer-built image - validates Packer build process

---

##### suites/monitoring-stack/

**Configuration File**: `tests/test-infra/configs/test-monitoring-stack.yaml`

**Makefile Usage**:

```bash
# Build Packer image first
make run-docker COMMAND="cmake --build build --target hpc-controller"

# Start and test
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-monitoring-stack.yaml
./tests/test-hpc-packer-controller-framework.sh --suite monitoring-stack
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-monitoring-stack.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1
  compute_count: 1  # For metrics collection

resources:
  controller_cpus: 4
  controller_memory: 8192  # Prometheus storage
```

**Prerequisites**:

- ✅ Prometheus installed via Packer
- ✅ Node Exporter installed
- ✅ Grafana installed via Packer
- ✅ Systemd services configured

**Test-Specific Requirements**:

- Prometheus service running on port 9090
- Node Exporter on port 9100
- Grafana on port 3000
- Prometheus configuration includes targets
- Grafana datasources configured

**Configuration Flags**:

```yaml
test_options:
  test_prometheus: true
  test_node_exporter: true
  test_grafana: true
  test_dashboards: true
  prometheus_port: 9090
  grafana_port: 3000
```

**Dependencies**:

- **Required**: Packer image built with monitoring stack
- **Required**: Compute nodes for metric scraping
- **Optional**: TLS certificates for secure access
- **Optional**: Grafana dashboards provisioned

**Deployment Strategy**: MUST start from fresh Packer-built image - validates monitoring stack installation

---

### Framework 3: test-hpc-packer-compute-framework.sh

**Purpose**: Validate HPC compute Packer image builds

**Deployment Strategy**: MUST use fresh deployment from Packer images - validates image contents

#### Cluster Configuration

| Setting | Requirement | Rationale |
|---------|-------------|-----------|
| **Controller Nodes** | 1 | Basic SLURM coordination |
| **Compute Nodes** | 1 | Single node validation |
| **Compute CPU** | 4 cores | Container execution |
| **Compute Memory** | 8 GB | Container workloads |
| **Storage** | 30 GB | Container images |

#### Test Suite Dependencies

##### suites/container-runtime/

**Configuration File**: `tests/test-infra/configs/test-container-runtime.yaml`

**Makefile Usage**:

```bash
# Build Packer image first
make run-docker COMMAND="cmake --build build --target hpc-compute"

# Start and test
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-container-runtime.yaml
./tests/test-hpc-packer-compute-framework.sh --suite container-runtime
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-container-runtime.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1
  compute_count: 1

resources:
  compute_cpus: 4
  compute_memory: 8192
```

**Prerequisites**:

- ✅ Apptainer/Singularity installed via Packer
- ✅ Security policies configured
- ✅ Container execution allowed

**Test-Specific Requirements**:

- `apptainer` binary available
- Version >= 1.1.0
- Security configuration: `/etc/apptainer/apptainer.conf`
- Test container image available

**Configuration Flags**:

```yaml
test_options:
  validate_container_runtime: true
  test_security_config: true
  container_version_min: "1.1.0"
```

**Dependencies**:

- **Required**: Packer image built with Apptainer
- **Required**: Test container image (busybox or alpine)
- **Optional**: GPU for GPU container tests

**Deployment Strategy**: MUST start from fresh Packer-built image - validates Apptainer installation

---

### Framework 4: test-beegfs-framework.sh

**Purpose**: BeeGFS parallel filesystem validation

**Deployment Strategy**: MUST use fresh Ansible deployment - validates BeeGFS service deployment

#### Cluster Configuration

| Setting | Requirement | Rationale |
|---------|-------------|-----------|
| **Controller Nodes** | 1 | BeeGFS management service |
| **Compute Nodes** | 2 (minimum) | Multi-node filesystem access |
| **Storage** | 100 GB | BeeGFS storage targets |
| **Network** | 10Gb+ recommended | Parallel filesystem performance |

#### Test Suite Dependencies

##### suites/beegfs/

**Configuration File**: `tests/test-infra/configs/test-beegfs.yaml`

**Makefile Usage**:

```bash
# Start cluster
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-beegfs.yaml

# Deploy BeeGFS via Ansible
make cluster-deploy CLUSTER_CONFIG=tests/test-infra/configs/test-beegfs.yaml

# Run test
./tests/test-beegfs-framework.sh --suite beegfs

# Cleanup
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-beegfs.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1  # Management + Metadata
  compute_count: 2     # Storage + Clients

storage:
  beegfs:
    mgmt_path: /data/beegfs/mgmt
    meta_path: /data/beegfs/meta
    storage_path: /data/beegfs/storage
    mount_point: /mnt/beegfs
```

**Prerequisites**:

- ✅ BeeGFS packages installed
- ✅ BeeGFS services configured
- ✅ Storage directories created
- ✅ Network connectivity between nodes

**Test-Specific Requirements**:

- BeeGFS management service (controller)
- BeeGFS metadata service (controller)
- BeeGFS storage services (compute nodes)
- BeeGFS clients (all nodes)
- Mount point accessible

**Configuration Flags**:

```yaml
test_options:
  test_beegfs_services: true
  test_multi_node_access: true
  test_io_performance: true
  mount_point: /mnt/beegfs
```

**Dependencies**:

- **Required**: At least 3 nodes (mgmt+meta, storage1, storage2)
- **Required**: Storage volumes for BeeGFS data
- **Required**: Network connectivity
- **Optional**: High-speed network for performance tests

**Deployment Strategy**: MUST use fresh Ansible deployment - validates BeeGFS installation and configuration

---

### Framework 5: test-virtio-fs-framework.sh

**Purpose**: VirtIO-FS filesystem sharing validation

**Deployment Strategy**: Can use pre-configured cluster with VirtIO-FS mounts configured

#### Cluster Configuration

| Setting | Requirement | Rationale |
|---------|-------------|-----------|
| **Controller Nodes** | 1 | Single node sufficient |
| **Compute Nodes** | 1 | Host-guest sharing |
| **Host Storage** | 50 GB | Shared directories |

#### Test Suite Dependencies

##### suites/virtio-fs/

**Configuration File**: `tests/test-infra/configs/test-virtio-fs.yaml`

**Makefile Usage**:

```bash
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-virtio-fs.yaml
./tests/test-virtio-fs-framework.sh --suite virtio-fs
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-virtio-fs.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1
  compute_count: 1

storage:
  virtio_fs_mounts:
    - host_path: /opt/shared
      guest_mount: /mnt/host-shared
      tag: shared
```

**Prerequisites**:

- ✅ VirtIO-FS driver loaded
- ✅ Host directory configured
- ✅ QEMU virtiofsd configured
- ✅ Mount point created

**Test-Specific Requirements**:

- Host directory accessible
- virtiofsd daemon running
- VirtIO-FS kernel module loaded
- Mount configured in VM definition

**Configuration Flags**:

```yaml
test_options:
  test_host_sharing: true
  test_permissions: true
  test_io_performance: true
  host_path: /opt/shared
  guest_mount: /mnt/host-shared
```

**Dependencies**:

- **Required**: QEMU with virtiofsd support
- **Required**: Host directory exists
- **Required**: VirtIO-FS driver in guest

**Deployment Strategy**: No Ansible needed - tests VM configuration only

---

### Framework 6: test-pcie-passthrough-framework.sh

**Purpose**: GPU PCIe passthrough validation

**Deployment Strategy**: Can use pre-configured cluster - tests hardware passthrough only

#### Cluster Configuration

| Setting | Requirement | Rationale |
|---------|-------------|-----------|
| **Controller Nodes** | 1 | Minimal |
| **Compute Nodes** | 1 | GPU validation |
| **GPU Hardware** | 1+ GPUs | PCIe passthrough target |

#### Hardware Dependencies

| Requirement | Status | Notes |
|-------------|--------|-------|
| **Physical GPU** | **Required** | Cannot be virtualized |
| **IOMMU Support** | **Required** | Intel VT-d or AMD-Vi |
| **GPU Not in Use** | **Required** | Unbound from host drivers |

#### Test Suite Dependencies

##### suites/gpu-validation/

**Configuration File**: `tests/test-infra/configs/test-pcie-passthrough-minimal.yaml` OR `config/example-multi-gpu-clusters.yaml`

**Makefile Usage**:

```bash
# For real GPU hardware testing
make cluster-start CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml
./tests/test-pcie-passthrough-framework.sh --suite gpu-validation
make cluster-destroy CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1
  compute_count: 1

hardware:
  gpu_passthrough: true
  gpu_pci_ids:
    - "0000:01:00.0"
```

**Prerequisites**:

- ✅ IOMMU enabled in BIOS
- ✅ VFIO drivers loaded
- ✅ GPU unbound from host
- ✅ GPU passed through to VM

**Test-Specific Requirements**:

- GPU visible via `lspci`
- NVIDIA drivers installed in guest
- `nvidia-smi` functional
- GPU compute capability accessible

**Configuration Flags**:

```yaml
test_options:
  skip_if_no_gpu: true
  verify_compute_capability: true
  test_multiple_gpus: true
```

**Dependencies**:

- **Required**: Physical GPU hardware
- **Required**: IOMMU support and enabled
- **Required**: VFIO kernel modules
- **Conditional**: Multiple GPUs for multi-GPU tests

**Deployment Strategy**: No Ansible needed - tests PCIe passthrough configuration only

---

### Framework 7: test-container-registry-framework.sh

**Purpose**: Container registry and distribution validation

**Deployment Strategy**: MUST use fresh Ansible deployment - validates registry infrastructure deployment

#### Cluster Configuration

| Setting | Requirement | Rationale |
|---------|-------------|-----------|
| **Controller Nodes** | 1 | Registry server |
| **Compute Nodes** | 2 | Multi-node image distribution |
| **Storage** | 100 GB | Container images |
| **Network** | Private bridge | Image distribution |

#### Test Suite Dependencies

##### suites/container-registry/

**Configuration File**: `tests/test-infra/configs/test-container-registry.yaml`

**Makefile Usage**:

```bash
# Start cluster
make cluster-start CLUSTER_CONFIG=tests/test-infra/configs/test-container-registry.yaml

# Deploy registry via Ansible
make cluster-deploy CLUSTER_CONFIG=tests/test-infra/configs/test-container-registry.yaml

# Run test
./tests/test-container-registry-framework.sh --suite container-registry

# Cleanup
make cluster-destroy CLUSTER_CONFIG=tests/test-infra/configs/test-container-registry.yaml
```

**Cluster Config**:

```yaml
cluster:
  controller_count: 1
  compute_count: 2

containers:
  registry:
    storage_path: /opt/containers
    images:
      - pytorch-cuda12.1-mpi4.1
```

**Prerequisites**:

- ✅ Container registry installed
- ✅ Storage backend configured
- ✅ Registry service running
- ✅ Container images available

**Test-Specific Requirements**:

- Registry accessible on network
- Storage path writable
- Container images pre-built
- Apptainer/Singularity on compute nodes

**Configuration Flags**:

```yaml
test_options:
  test_registry_installation: true
  test_image_distribution: true
  test_slurm_integration: true
  registry_port: 5000
  storage_backend: local  # or beegfs
```

**Dependencies**:

- **Required**: Container registry software (Harbor or Docker Registry)
- **Required**: Storage backend (local or BeeGFS)
- **Required**: Pre-built container images
- **Required**: Apptainer on compute nodes
- **Optional**: TLS certificates for secure registry

**Deployment Strategy**: MUST use fresh Ansible deployment - validates registry role deployment

---

## Test Execution Dependency Graph

```text
┌─────────────────────────────────────────────────────────────────┐
│                     Test Execution Order                         │
└─────────────────────────────────────────────────────────────────┘

Phase 1: Base Infrastructure
├── Prerequisites Check
├── Base Images Built (Packer)
└── Network Configured

Phase 2: Controller Validation (Packer)
├── test-hpc-packer-controller
│   ├── SLURM controller installed
│   ├── Monitoring stack installed
│   └── Grafana installed
└── DEPENDENCIES: Base images

Phase 3: Compute Validation (Packer)
├── test-hpc-packer-compute
│   └── Container runtime installed
└── DEPENDENCIES: Base images

Phase 4: Runtime Configuration (Ansible)
├── test-hpc-runtime
│   ├── Cgroup isolation configured
│   ├── GPU GRES configured (if GPU available)
│   ├── DCGM monitoring configured (if GPU available)
│   ├── Container integration validated
│   ├── Job scripts tested
│   └── SLURM compute validated
└── DEPENDENCIES: Packer images, Ansible deployment

Phase 5: Storage Validation
├── test-beegfs (if enabled)
│   └── Parallel filesystem validated
├── test-virtio-fs (if enabled)
│   └── Host-guest sharing validated
└── DEPENDENCIES: Runtime configuration

Phase 6: Hardware Validation
├── test-pcie-passthrough (if GPU hardware)
│   └── GPU passthrough validated
└── DEPENDENCIES: Hardware available, runtime config

Phase 7: Distribution Validation
└── test-container-registry
    └── Registry and distribution validated
    DEPENDENCIES: Container runtime, storage backend
```

---

## Hardware Requirement Summary

| Test Framework | CPU (min) | Memory (min) | GPU | Storage | Network |
|----------------|-----------|--------------|-----|---------|---------|
| test-hpc-runtime | 12 cores | 40 GB | Optional | 100 GB | 1Gb+ |
| test-hpc-packer-controller | 6 cores | 12 GB | No | 60 GB | 1Gb+ |
| test-hpc-packer-compute | 6 cores | 12 GB | No | 60 GB | 1Gb+ |
| test-beegfs | 6 cores | 16 GB | No | 200 GB | 10Gb+ recommended |
| test-virtio-fs | 4 cores | 8 GB | No | 80 GB | 1Gb+ |
| test-pcie-passthrough | 4 cores | 8 GB | **Required** | 60 GB | 1Gb+ |
| test-container-registry | 12 cores | 32 GB | Optional | 200 GB | 1Gb+ |

---

## Configuration File Templates

### Minimal Test Configuration

```yaml
# Minimal configuration for basic testing
cluster:
  name: test-minimal
  controller_count: 1
  compute_count: 1

images:
  controller: hpc-controller-latest.qcow2
  compute: hpc-compute-latest.qcow2

resources:
  controller_cpus: 2
  controller_memory: 4096
  compute_cpus: 2
  compute_memory: 4096

test_options:
  skip_slow_tests: true
  skip_gpu_tests: true
  timeout_minutes: 30
```

### Full Test Configuration

```yaml
# Full configuration with all features
cluster:
  name: test-full
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

hardware:
  gpu_passthrough: true
  gpu_count: 1
  gpu_pci_ids:
    - "0000:01:00.0"

storage:
  beegfs:
    enabled: false
  virtio_fs_mounts:
    - host_path: /opt/shared
      guest_mount: /mnt/host-shared
      tag: shared

containers:
  registry:
    enabled: false
    storage_path: /opt/containers

test_options:
  enable_gpu_tests: true
  enable_container_tests: true
  enable_distributed_tests: true
  skip_slow_tests: false
  timeout_minutes: 60
```

### GPU-Focused Configuration

```yaml
# Configuration optimized for GPU testing
cluster:
  name: test-gpu
  controller_count: 1
  compute_count: 1

images:
  controller: hpc-controller-latest.qcow2
  compute: hpc-compute-latest.qcow2

resources:
  controller_cpus: 4
  controller_memory: 8192
  compute_cpus: 8
  compute_memory: 16384

hardware:
  gpu_passthrough: true
  gpu_count: 1
  gpu_pci_ids:
    - "0000:01:00.0"

test_options:
  enable_gpu_tests: true
  enable_dcgm_tests: true
  enable_container_tests: true
  skip_non_gpu_tests: false
  gpu_type: nvidia
  verify_cuda: true
```

---

## Test Execution Prerequisites Checklist

### Before Running Any Tests

- [ ] Base images built via Packer
- [ ] Test configuration file created
- [ ] Required hardware available
- [ ] Network connectivity verified
- [ ] Storage requirements met
- [ ] ai-how CLI available

### Before test-hpc-runtime

- [ ] Controller and compute images built
- [ ] Ansible playbooks ready
- [ ] GPU available (if testing GPU features)
- [ ] Container images available (if testing containers)

### Before test-beegfs

- [ ] Multiple nodes available (3+)
- [ ] Storage volumes created
- [ ] High-speed network configured
- [ ] BeeGFS packages available

### Before test-pcie-passthrough

- [ ] Physical GPU available
- [ ] IOMMU enabled in BIOS
- [ ] VFIO drivers available
- [ ] GPU not bound to host

### Before test-container-registry

- [ ] Container registry software available
- [ ] Storage backend configured (local or BeeGFS)
- [ ] Container images pre-built
- [ ] Apptainer installed on compute nodes

---

## Summary

This dependency matrix provides comprehensive information about:

1. **Cluster topology requirements** for each test framework
2. **Hardware dependencies** (GPU, storage, network)
3. **Per-test-suite prerequisites** and configuration
4. **Test-specific flags** for customization
5. **Execution order** and inter-test dependencies

Use this document in conjunction with:

- `03-framework-specifications.md` for framework details
- `02-component-matrix.md` for test coverage
- `04-implementation-phases.md` for execution guidance

---

## Future Enhancements

Potential improvements to this matrix:

1. **Performance Benchmarks**: Add expected execution times per test suite
2. **Resource Utilization**: Document CPU/memory usage during tests
3. **Failure Scenarios**: Document common failure modes and their causes
4. **Compatibility Matrix**: Track supported OS versions and package versions
5. **Cost Estimation**: Cloud resource costs for test execution
