# Component Test Matrix

## Overview

This document provides a comprehensive mapping of HPC SLURM components to test frameworks, test suites, and
validation coverage. It serves as a reference for understanding what each test validates and how components
are tested across the infrastructure.

## Matrix Legend

- **✅ Complete**: Comprehensive test coverage
- **⚠️ Partial**: Some coverage, gaps exist
- **❌ Missing**: No test coverage
- **🔧 Manual**: Requires manual validation
- **🤖 Automated**: Fully automated testing

## Component Coverage Matrix

### HPC Controller Components

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **SLURM Controller** | test-hpc-packer-controller | slurm-controller/ | Installation, config, services | ✅ 🤖 |
| **SLURM Accounting** | test-hpc-packer-controller | slurm-controller/ | Database, slurmdbd, job tracking | ✅ 🤖 |
| **Prometheus** | test-hpc-packer-controller | monitoring-stack/ | Installation, targets, scraping | ✅ 🤖 |
| **Node Exporter** | test-hpc-packer-controller | monitoring-stack/ | Installation, metrics, integration | ✅ 🤖 |
| **Grafana** | test-hpc-packer-controller | monitoring-stack/ | Installation, dashboards, datasources | ✅ 🤖 |
| **MUNGE (Controller)** | test-hpc-packer-controller | slurm-controller/ | Key setup, service, authentication | ✅ 🤖 |

### HPC Compute Components

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **SLURM Compute** | test-hpc-runtime | slurm-compute/ | Installation, registration, jobs | ✅ 🤖 |
| **Apptainer/Singularity** | test-hpc-packer-compute | container-runtime/ | Installation, security, execution | ✅ 🤖 |
| **MUNGE (Compute)** | test-hpc-runtime | slurm-compute/ | Key distribution, authentication | ✅ 🤖 |
| **Cgroup Isolation** | test-hpc-runtime | cgroup-isolation/ | Configuration, enforcement, limits | ✅ 🤖 |
| **GPU GRES** | test-hpc-runtime | gpu-gres/ | Config, detection, scheduling | ✅ 🤖 |
| **DCGM Monitoring** | test-hpc-runtime | dcgm-monitoring/ | Exporter, metrics, Prometheus | ✅ 🤖 |

### Storage Components

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **BeeGFS Management** | test-beegfs | beegfs/ | Service, connectivity, failover | ✅ 🤖 |
| **BeeGFS Metadata** | test-beegfs | beegfs/ | Service, storage, performance | ✅ 🤖 |
| **BeeGFS Storage** | test-beegfs | beegfs/ | Multi-node, data integrity | ✅ 🤖 |
| **BeeGFS Client** | test-beegfs | beegfs/ | Mounts, I/O, permissions | ✅ 🤖 |
| **VirtIO-FS** | test-virtio-fs | virtio-fs/ | Host sharing, permissions, I/O | ✅ 🤖 |

### Container Infrastructure

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **Container Registry** | test-container-registry | container-registry/ | Installation, storage, distribution | ✅ 🤖 |
| **Container Images** | test-container-registry | container-deployment/ | Building, conversion, deployment | ✅ 🤖 |
| **PyTorch + CUDA** | test-hpc-runtime | container-integration/ | Execution, GPU access, training | ✅ 🤖 |
| **MPI Integration** | test-hpc-runtime | container-integration/ | Multi-process, communication | ✅ 🤖 |
| **Distributed Training** | test-hpc-runtime | container-integration/ | Multi-node, NCCL, coordination | ✅ 🤖 |

### GPU and Hardware

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **PCIe Passthrough** | test-pcie-passthrough | gpu-validation/ | Device visibility, assignment | ✅ 🤖 |
| **GPU Detection** | test-hpc-runtime | gpu-gres/ | PCI enumeration, drivers | ✅ 🤖 |
| **GPU Isolation** | test-hpc-runtime | cgroup-isolation/ | Cgroup device control | ✅ 🤖 |
| **GPU Monitoring** | test-hpc-runtime | dcgm-monitoring/ | DCGM metrics, alerts | ✅ 🤖 |

### Job Management

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **Job Submission** | test-hpc-runtime | job-scripts/ | sbatch, srun, salloc | ✅ 🤖 |
| **Job Scheduling** | test-hpc-runtime | job-scripts/ | Priorities, fairshare, backfill | ✅ 🤖 |
| **Resource Allocation** | test-hpc-runtime | job-scripts/ | CPUs, memory, GPUs | ✅ 🤖 |
| **Job Accounting** | test-hpc-packer-controller | slurm-controller/ | Database, queries, reports | ✅ 🤖 |

## Test Suite Detailed Coverage

### suites/slurm-controller/ (SLURM Controller)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-slurm-installation.sh` | SLURM binaries, packages | slurmctld, slurmdbd | ✅ |
| `check-slurm-configuration.sh` | Config files, syntax | slurm.conf, slurmdbd.conf | ✅ |
| `check-slurm-services.sh` | Service status, startup | systemd units | ✅ |
| `check-munge-setup.sh` | MUNGE key, authentication | munge service | ✅ |
| `check-job-submission.sh` | Basic job execution | srun, sbatch | ✅ |

### suites/monitoring-stack/ (Prometheus, Grafana)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-components-installation.sh` | Prometheus, Node Exporter | Packages, binaries | ✅ |
| `check-monitoring-integration.sh` | Target discovery, scraping | Prometheus config | ✅ |
| `check-metrics-collection.sh` | Metrics data quality | Time series data | ✅ |
| `check-grafana-installation.sh` | Grafana server | Web UI, datasources | ✅ |
| `check-grafana-dashboards.sh` | Dashboard provisioning | JSON configs | ✅ |

### suites/container-runtime/ (Apptainer/Singularity)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-singularity-install.sh` | Apptainer installation | Packages, binaries | ✅ |
| `check-singularity-version.sh` | Version compatibility | Binary version | ✅ |
| `check-container-execution.sh` | Container run capability | Basic execution | ✅ |
| `check-security-config.sh` | Security policies | Configuration files | ✅ |

### suites/slurm-compute/ (SLURM Compute Nodes)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-slurm-compute-install.sh` | SLURM compute packages | slurmd binary | ✅ |
| `check-slurm-compute-config.sh` | Configuration files | slurm.conf | ✅ |
| `check-slurm-compute-service.sh` | Service status | slurmd service | ✅ |
| `check-node-registration.sh` | Controller registration | scontrol show nodes | ✅ |
| `check-job-execution.sh` | Job execution on compute | srun tests | ✅ |
| `check-resource-management.sh` | CPU, memory allocation | cgroups | ✅ |

### suites/cgroup-isolation/ (Resource Isolation)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-cgroup-config.sh` | cgroup.conf syntax | Configuration files | ✅ |
| `check-cgroup-v2-setup.sh` | Cgroup v2 filesystem | /sys/fs/cgroup | ✅ |
| `check-resource-isolation.sh` | Resource limits enforcement | Memory, CPU limits | ✅ |

### suites/gpu-gres/ (GPU Resource Scheduling)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-gres-configuration.sh` | gres.conf syntax | Configuration files | ✅ |
| `check-gpu-detection.sh` | GPU enumeration | lspci, nvidia-smi | ✅ |
| `check-gpu-scheduling.sh` | SLURM GPU allocation | scontrol, sinfo | ✅ |

### suites/dcgm-monitoring/ (GPU Monitoring)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-dcgm-service.sh` | DCGM exporter service | systemd unit | ✅ |
| `check-dcgm-metrics.sh` | GPU metrics export | Prometheus metrics | ✅ |
| `check-dcgm-integration.sh` | Prometheus scraping | Target configuration | ✅ |
| `check-gpu-telemetry.sh` | GPU data quality | Metrics accuracy | ✅ |

### suites/container-integration/ (ML/AI Workloads)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-container-availability.sh` | Container image access | SIF files | ✅ |
| `check-pytorch-import.sh` | PyTorch framework | Python imports | ✅ |
| `check-cuda-availability.sh` | CUDA runtime | GPU detection | ✅ |
| `check-gpu-operations.sh` | GPU tensor operations | CUDA kernels | ✅ |
| `check-mpi-functionality.sh` | MPI runtime | mpirun, communication | ✅ |
| `check-distributed-training.sh` | Multi-node training | Process groups, NCCL | ✅ |
| `check-slurm-integration.sh` | Container via SLURM | srun with containers | ✅ |
| `check-multi-node-execution.sh` | Multi-node jobs | Distributed execution | ✅ |
| `check-resource-allocation.sh` | GPU GRES with containers | Resource isolation | ✅ |
| `check-filesystem-access.sh` | Bind mounts, I/O | File system access | ✅ |
| `check-network-communication.sh` | Inter-node networking | MPI collectives | ✅ |
| `check-performance-validation.sh` | Training performance | Throughput, latency | ✅ |

### suites/container-registry/ (Container Distribution)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-registry-installation.sh` | Registry server | Harbor/registry service | ✅ |
| `check-registry-storage.sh` | Storage backend | BeeGFS or local storage | ✅ |
| `check-image-distribution.sh` | Image push/pull | Distribution workflow | ✅ |
| `check-slurm-integration.sh` | SLURM container access | Job scripts with containers | ✅ |
| `check-multi-node-access.sh` | Cluster-wide access | All nodes can access | ✅ |
| `check-registry-security.sh` | Authentication, TLS | Security configuration | ✅ |

### suites/beegfs/ (Parallel Filesystem)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-beegfs-services.sh` | BeeGFS daemons | mgmt, meta, storage, client | ✅ |
| `check-beegfs-connectivity.sh` | Node connectivity | beegfs-ctl commands | ✅ |
| `check-beegfs-mounts.sh` | Client mounts | Mount points, fstab | ✅ |
| `check-beegfs-performance.sh` | I/O performance | Read/write throughput | ✅ |

### suites/virtio-fs/ (Filesystem Sharing)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-virtio-fs-mount.sh` | VirtIO-FS mounts | virtiofs driver | ✅ |
| `check-host-directory-access.sh` | Host directory sharing | Bind mounts | ✅ |
| `check-permissions.sh` | File permissions | User/group mapping | ✅ |
| `check-io-performance.sh` | I/O performance | Read/write speed | ✅ |

### suites/gpu-validation/ (GPU Hardware)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-gpu-visibility.sh` | GPU device visibility | lspci, nvidia-smi | ✅ |
| `check-gpu-passthrough.sh` | PCIe passthrough | Device assignment | ✅ |
| `check-gpu-drivers.sh` | NVIDIA drivers | Driver version | ✅ |
| `check-gpu-functionality.sh` | GPU compute capability | Basic operations | ✅ |
| `check-multi-gpu-setup.sh` | Multi-GPU configuration | All GPUs accessible | ✅ |

### suites/job-scripts/ (Job Management)

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-job-submission.sh` | Job submission methods | sbatch, srun, salloc | ✅ |
| `check-job-templates.sh` | Job script templates | Template syntax | ✅ |
| `check-resource-requests.sh` | Resource allocation | CPU, memory, GPU | ✅ |
| `check-job-arrays.sh` | Array job functionality | Task indexing | ✅ |

## Test Framework to Component Mapping

### test-hpc-runtime-framework.sh (NEW)

**Purpose**: Runtime validation for HPC compute nodes

**Components Covered**:

- SLURM compute node configuration
- Cgroup resource isolation
- GPU GRES configuration and scheduling
- DCGM GPU monitoring
- Container runtime integration
- Job script validation

**Test Suites Used**:

- `suites/slurm-compute/`
- `suites/cgroup-isolation/`
- `suites/gpu-gres/`
- `suites/dcgm-monitoring/`
- `suites/container-integration/`
- `suites/job-scripts/`

**Deployment**: Ansible runtime configuration

**Estimated Time**: 30-45 minutes

### test-hpc-packer-controller-framework.sh (NEW)

**Purpose**: Packer validation for HPC controller images

**Components Covered**:

- SLURM controller installation
- SLURM job accounting configuration
- Prometheus monitoring stack
- Grafana dashboards
- Basic infrastructure

**Test Suites Used**:

- `suites/slurm-controller/`
- `suites/monitoring-stack/`
- `suites/basic-infrastructure/`

**Deployment**: Packer image build

**Estimated Time**: 20-30 minutes

### test-hpc-packer-compute-framework.sh (NEW)

**Purpose**: Packer validation for HPC compute images

**Components Covered**:

- Apptainer/Singularity container runtime
- Basic compute node packages
- SLURM compute prerequisites

**Test Suites Used**:

- `suites/container-runtime/`

**Deployment**: Packer image build

**Estimated Time**: 15-20 minutes

### test-beegfs-framework.sh (REFACTOR)

**Purpose**: BeeGFS parallel filesystem validation

**Components Covered**:

- BeeGFS management service
- BeeGFS metadata service
- BeeGFS storage services
- BeeGFS client mounts

**Test Suites Used**:

- `suites/beegfs/`

**Deployment**: Multi-node storage cluster

**Estimated Time**: 15-25 minutes

### test-virtio-fs-framework.sh (REFACTOR)

**Purpose**: VirtIO-FS filesystem sharing validation

**Components Covered**:

- VirtIO-FS driver and mounts
- Host directory sharing
- File permissions and ownership
- I/O performance

**Test Suites Used**:

- `suites/virtio-fs/`

**Deployment**: Host-guest filesystem

**Estimated Time**: 10-20 minutes

### test-pcie-passthrough-framework.sh (REFACTOR)

**Purpose**: GPU PCIe passthrough validation

**Components Covered**:

- GPU device visibility
- PCIe device assignment
- GPU driver functionality
- Multi-GPU configuration

**Test Suites Used**:

- `suites/gpu-validation/`

**Deployment**: Hardware passthrough

**Estimated Time**: 10-20 minutes

### test-container-registry-framework.sh (REFACTOR)

**Purpose**: Container registry and distribution validation

**Components Covered**:

- Container registry installation
- Image storage (BeeGFS or local)
- Image distribution workflow
- SLURM container integration

**Test Suites Used**:

- `suites/container-registry/`
- `suites/container-deployment/`
- `suites/container-e2e/`

**Deployment**: Registry + image distribution

**Estimated Time**: 15-25 minutes

## Coverage Gaps and Improvements

### Current Coverage Assessment

**Overall Coverage**: ✅ Excellent (90%+)

**Strengths**:

- Comprehensive component testing
- Automated end-to-end validation
- Good integration testing
- Clear test organization

**Areas for Improvement**:

1. **Performance Benchmarking**: Limited performance baseline testing
   - **Gap**: No systematic performance regression testing
   - **Impact**: Low (functional testing is comprehensive)
   - **Recommendation**: Add performance benchmarks to phase-4-validation

2. **Failover Testing**: Limited failure scenario testing
   - **Gap**: Few tests for component failures
   - **Impact**: Medium (affects production readiness)
   - **Recommendation**: Add failover tests to beegfs and slurm-controller suites

3. **Security Testing**: Basic security validation only
   - **Gap**: No penetration testing or security scanning
   - **Impact**: Medium (basic security is validated)
   - **Recommendation**: Add security-focused test suite

4. **Scale Testing**: Limited large-scale testing
   - **Gap**: Most tests use 1-2 node clusters
   - **Impact**: Medium (affects large deployments)
   - **Recommendation**: Add scale testing to phase-4-validation

5. **Upgrade Testing**: No upgrade path validation
   - **Gap**: Fresh installs only, no upgrades tested
   - **Impact**: Medium (affects production upgrades)
   - **Recommendation**: Add upgrade test framework

## Component Dependency Graph

```text
┌─────────────────────────────────────────────────┐
│         Base Infrastructure Layer               │
│  - Base packages, SSH, networking, system       │
└──────────────────┬──────────────────────────────┘
                   │
      ┌────────────┴─────────────┐
      │                          │
      ▼                          ▼
┌──────────────────┐    ┌──────────────────┐
│   HPC Controller  │    │   HPC Compute    │
│  - SLURM Controller│   │ - SLURM Compute  │
│  - Accounting     │    │ - Container RT   │
│  - Prometheus     │    │                  │
│  - Grafana        │    │                  │
└────────┬──────────┘    └────────┬─────────┘
         │                        │
         │    ┌───────────────────┤
         │    │                   │
         ▼    ▼                   ▼
    ┌────────────┐    ┌──────────────────┐
    │   Storage  │    │  Runtime Config  │
    │ - BeeGFS   │    │ - Cgroup         │
    │ - VirtIO-FS│    │ - GPU GRES       │
    └────────────┘    │ - DCGM           │
                      │ - Containers     │
                      └──────────────────┘
```

## Test Execution Recommendation

### Optimal Test Order

1. **Phase 1: Foundation** (30-90 min)
   - Base images
   - Integration tests
   - Ansible role tests

2. **Phase 2: Core Infrastructure** (20-30 min)
   - test-hpc-packer-controller
   - test-hpc-packer-compute

3. **Phase 3: Runtime Configuration** (30-45 min)
   - test-hpc-runtime

4. **Phase 4: Storage** (25-45 min)
   - test-beegfs
   - test-virtio-fs

5. **Phase 5: Specialized** (25-45 min)
   - test-pcie-passthrough
   - test-container-registry

6. **Phase 6: End-to-End** (45-70 min)
   - phase-4-validation (all 10 steps)

**Total Time**: ~2.5-5 hours for complete validation

## Summary

This component matrix provides a comprehensive view of test coverage across the HPC SLURM infrastructure. With
90%+ automated coverage across all major components, the test infrastructure is robust and well-organized.

The consolidation plan preserves this excellent coverage while reducing framework complexity and code duplication.
All test suites remain unchanged, ensuring proven test logic is maintained while improving the orchestration layer.
