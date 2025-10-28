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

---

## Cloud Cluster Components (NEW)

### AI-HOW CLI & Topology

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **Topology Visualization** | test-cloud-vm | basic-infrastructure/ | Complete topology tree display | ✅ 🤖 |
| **Cluster Display** | test-cloud-vm | basic-infrastructure/ | Cluster status and information | ✅ 🤖 |
| **Network Display** | test-cloud-vm | basic-infrastructure/ | Network CIDR and configuration | ✅ 🤖 |
| **VM Display** | test-cloud-vm | basic-infrastructure/ | VM IPs, roles, resources | ✅ 🤖 |
| **GPU Display** | test-cloud-vm | basic-infrastructure/ | GPU assignments and PCI addresses | ✅ 🤖 |
| **GPU Conflict Highlighting** | test-cloud-vm | basic-infrastructure/ | Red highlighting for conflicts | ✅ 🤖 |
| **Tree Structure** | test-cloud-vm | basic-infrastructure/ | Hierarchical tree rendering | ✅ 🤖 |
| **Color Coding** | test-cloud-vm | basic-infrastructure/ | Status-based colors (green/yellow/red) | ✅ 🤖 |
| **Multi-Cluster Topology** | test-multi-cluster | multi-cluster/ | Both HPC and Cloud in topology | ✅ 🤖 |

### Cloud VM Management

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **Cloud VM Provisioning** | test-cloud-vm | cloud-vm-lifecycle/ | VM creation, resources, network | ✅ 🤖 |
| **VM Lifecycle (Cluster)** | test-cloud-vm | cloud-vm-lifecycle/ | Start, stop, restart operations | ✅ 🤖 |
| **VM Lifecycle (Individual)** | test-cloud-vm | cloud-vm-lifecycle/ | Individual VM stop/start/restart | ✅ 🤖 |
| **State Management** | test-cloud-vm | cloud-vm-lifecycle/ | state.json, global state tracking | ✅ 🤖 |
| **Auto-Start Flag** | test-cloud-vm | cloud-vm-lifecycle/ | `auto_start: false` VM creation | ✅ 🤖 |
| **Auto-Start Preservation** | test-cloud-vm | cloud-vm-lifecycle/ | Flag persists across restarts | ✅ 🤖 |
| **Auto-Start Status Display** | test-cloud-vm | cloud-vm-lifecycle/ | Status shows `auto_start` flag | ✅ 🤖 |
| **GPU Passthrough (Cloud)** | test-cloud-vm | cloud-vm-lifecycle/ | GPU passthrough for workers | ✅ 🤖 |
| **Shared GPU Management** | test-cloud-vm | cloud-vm-lifecycle/ | GPU conflict detection, ownership | ✅ 🤖 |
| **Auto-Start GPU Isolation** | test-cloud-vm | cloud-vm-lifecycle/ | No GPU alloc for `auto_start: false` | ✅ 🤖 |
| **Multi-Cluster Coexistence** | test-multi-cluster | multi-cluster/ | Both clusters with shared GPU | ✅ 🤖 |

### Kubernetes Cluster

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **Kubespray Deployment** | test-kubernetes | kubernetes-cluster/ | Installation, configuration | ✅ 🤖 |
| **Cluster Health** | test-kubernetes | kubernetes-cluster/ | API server, nodes, system pods | ✅ 🤖 |
| **Networking (Calico)** | test-kubernetes | kubernetes-cluster/ | Pod-to-pod, CNI validation | ✅ 🤖 |
| **DNS Resolution** | test-kubernetes | kubernetes-cluster/ | CoreDNS, service discovery | ✅ 🤖 |
| **Ingress Controller** | test-kubernetes | kubernetes-cluster/ | NGINX ingress, routing | ✅ 🤖 |
| **Metrics Server** | test-kubernetes | kubernetes-cluster/ | Resource metrics collection | ✅ 🤖 |
| **GPU Device Plugin** | test-kubernetes | kubernetes-cluster/ | GPU operator, device plugin | ✅ 🤖 |
| **GPU Scheduling (K8s)** | test-kubernetes | kubernetes-cluster/ | GPU resource requests, limits | ✅ 🤖 |

### MLOps Stack

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **MinIO Object Storage** | test-mlops-stack | mlops-stack/minio/ | S3 API, buckets, upload/download | ✅ 🤖 |
| **PostgreSQL Database** | test-mlops-stack | mlops-stack/postgresql/ | Connection, MLflow schema, persistence | ✅ 🤖 |
| **MLflow Tracking Server** | test-mlops-stack | mlops-stack/mlflow/ | API, experiments, model registry | ✅ 🤖 |
| **KServe Model Serving** | test-mlops-stack | mlops-stack/kserve/ | CRDs, Knative, inference service | ✅ 🤖 |
| **MLflow-MinIO Integration** | test-mlops-stack | mlops-stack/mlflow/ | Artifact store connection | ✅ 🤖 |
| **MLflow-PostgreSQL Integration** | test-mlops-stack | mlops-stack/mlflow/ | Backend store connection | ✅ 🤖 |

### Model Inference

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **InferenceService Deployment** | test-inference | inference-validation/ | Model loading, deployment | ✅ 🤖 |
| **Inference API** | test-inference | inference-validation/ | Request/response, endpoint | ✅ 🤖 |
| **GPU Inference** | test-inference | inference-validation/ | GPU utilization, performance | ✅ 🤖 |
| **Autoscaling** | test-inference | inference-validation/ | Scale up/down, load balancing | ✅ 🤖 |
| **Performance Metrics** | test-inference | inference-validation/ | Latency, throughput | ✅ 🤖 |

### Multi-Cluster Integration

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **HPC-Cloud Coordination** | test-multi-cluster | multi-cluster/ | Both clusters running | ✅ 🤖 |
| **Shared GPU Conflicts** | test-multi-cluster | multi-cluster/ | GPU conflict detection | ✅ 🤖 |
| **Workflow Transition** | test-multi-cluster | multi-cluster/ | HPC training → Cloud inference | ✅ 🤖 |
| **Model Transfer** | test-multi-cluster | multi-cluster/ | BeeGFS → MinIO transfer | ✅ 🤖 |
| **Unified Monitoring** | test-multi-cluster | multi-cluster/ | Cross-cluster metrics | ✅ 🤖 |

### System-wide Management (CLOUD-0.6)

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **System Start Command** | test-system-management | system-management/ | Start both clusters | ✅ 🤖 |
| **System Stop Command** | test-system-management | system-management/ | Stop both clusters | ✅ 🤖 |
| **System Destroy Command** | test-system-management | system-management/ | Destroy both clusters | ✅ 🤖 |
| **System Status Command** | test-system-management | system-management/ | Show combined status | ✅ 🤖 |
| **Startup Ordering** | test-system-management | system-management/ | HPC first, then Cloud | ✅ 🤖 |
| **Shutdown Ordering** | test-system-management | system-management/ | Cloud first, then HPC | ✅ 🤖 |
| **Failure Rollback** | test-system-management | system-management/ | Rollback on partial failure | ✅ 🤖 |
| **Config Validation** | test-system-management | system-management/ | Validate config files | ✅ 🤖 |
| **Error Handling** | test-system-management | system-management/ | Clear error messages | ✅ 🤖 |
| **Shared Resources Display** | test-system-management | system-management/ | GPU allocations shown | ✅ 🤖 |

---

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

---

### suites/basic-infrastructure/ (Topology & CLI) - NEW

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-topology-command-output.sh` | Topology command execution | ai-how topology CLI | ✅ |
| `check-topology-cluster-display.sh` | Cluster information rendering | Cluster name, status | ✅ |
| `check-topology-network-display.sh` | Network CIDR display | Network configuration | ✅ |
| `check-topology-vm-display.sh` | VM details (IP, role, resources) | VM information | ✅ |
| `check-topology-gpu-display.sh` | GPU PCI and allocation info | GPU display | ✅ |
| `check-topology-gpu-conflict-highlighting.sh` | Red highlight for GPU conflicts | Conflict visualization | ✅ |
| `check-topology-tree-structure.sh` | Hierarchical tree format | Tree rendering | ✅ |
| `check-topology-color-coding.sh` | Status colors (green/yellow/red) | Color-coded output | ✅ |
| `check-topology-multi-cluster.sh` | Both HPC and Cloud clusters | Multi-cluster display | ✅ |
| `check-topology-empty-state.sh` | No clusters running scenario | Empty state handling | ✅ |
| `test-topology-visualization.sh` | Complete topology test suite | End-to-end topology | ✅ |

### suites/cloud-vm-lifecycle/ (Cloud VM Management) - NEW

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-vm-provisioning.sh` | VM creation with resources | Cloud VMs, network | ✅ |
| `check-vm-network.sh` | Network connectivity | Bridge network, IPs | ✅ |
| `check-vm-storage.sh` | Storage volumes | qcow2 images, disks | ✅ |
| `check-vm-gpu-passthrough.sh` | GPU passthrough | GPU workers | ✅ |
| `check-vm-lifecycle.sh` | Cluster start/stop/restart | VM lifecycle | ✅ |
| `check-state-tracking.sh` | State management | state.json, global state | ✅ |
| `check-auto-start-flag.sh` | `auto_start: false` VM creation | Auto-start control | ✅ |
| `check-auto-start-preservation.sh` | `auto_start` flag across restarts | State persistence | ✅ |
| `check-auto-start-status-display.sh` | Status shows `auto_start` flag | CLI status display | ✅ |
| `check-individual-vm-stop.sh` | Stop single VM, GPU release | Individual VM control | ✅ |
| `check-individual-vm-start.sh` | Start single VM, GPU allocation | Individual VM control | ✅ |
| `check-individual-vm-restart.sh` | Restart VM, GPU rebinding | Individual VM control | ✅ |
| `check-vm-status-command.sh` | VM status display | CLI status command | ✅ |
| `check-vm-gpu-release.sh` | GPU released on stop | GPU resource management | ✅ |
| `check-shared-gpu-detection.sh` | Detect shared GPUs | Multi-cluster GPU sharing | ✅ |
| `check-gpu-conflict-detection.sh` | Prevent simultaneous GPU use | GPU conflict prevention | ✅ |
| `check-gpu-ownership-tracking.sh` | Global state GPU allocations | GPU ownership tracking | ✅ |
| `check-gpu-switch-between-vms.sh` | Sequential GPU transfer | GPU resource switching | ✅ |
| `check-gpu-error-messages.sh` | Clear GPU error messages | Error handling | ✅ |
| `check-auto-start-no-gpu-allocation.sh` | `auto_start: false` no GPU alloc | Auto-start GPU isolation | ✅ |
| `check-multi-cluster-coexistence.sh` | Both clusters with shared GPU | Multi-cluster coexistence | ✅ |
| `check-manual-start-gpu-validation.sh` | GPU check on manual VM start | Manual start validation | ✅ |

### suites/kubernetes-cluster/ (Kubernetes Cluster) - NEW

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-kubespray-installation.sh` | Kubespray deployment | Ansible playbooks, inventory | ✅ |
| `check-cluster-health.sh` | Cluster operational status | API server, nodes, pods | ✅ |
| `check-networking.sh` | Pod-to-pod communication | Calico CNI, routing | ✅ |
| `check-dns-resolution.sh` | Service discovery | CoreDNS, cluster DNS | ✅ |
| `check-calico-cni.sh` | Network plugin | Calico pods, configuration | ✅ |
| `check-ingress-controller.sh` | External access | NGINX ingress | ✅ |
| `check-metrics-server.sh` | Resource metrics | Metrics server deployment | ✅ |
| `check-gpu-device-plugin.sh` | GPU operator | NVIDIA device plugin | ✅ |
| `check-gpu-scheduling.sh` | GPU resource allocation | K8s GPU scheduling | ✅ |

### suites/mlops-stack/minio/ (MinIO Object Storage) - NEW

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-minio-deployment.sh` | MinIO pods running | StatefulSet, pods | ✅ |
| `check-minio-storage.sh` | Persistent volumes | PV, PVC, storage class | ✅ |
| `check-minio-buckets.sh` | Bucket creation | S3 buckets | ✅ |
| `check-minio-api.sh` | S3 API accessibility | S3 endpoint | ✅ |
| `check-minio-upload-download.sh` | Object operations | Upload, download, delete | ✅ |

### suites/mlops-stack/postgresql/ (PostgreSQL Database) - NEW

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-postgresql-deployment.sh` | PostgreSQL pod running | StatefulSet, pod | ✅ |
| `check-postgresql-connection.sh` | Database connectivity | psql connection | ✅ |
| `check-mlflow-schema.sh` | MLflow tables exist | Database schema | ✅ |
| `check-postgresql-persistence.sh` | Data persists on restart | Persistent volumes | ✅ |

### suites/mlops-stack/mlflow/ (MLflow Tracking Server) - NEW

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-mlflow-deployment.sh` | MLflow pods running | Deployment, replicas | ✅ |
| `check-mlflow-api.sh` | REST API accessible | HTTP endpoint | ✅ |
| `check-mlflow-backend-store.sh` | PostgreSQL connection | Backend store config | ✅ |
| `check-mlflow-artifact-store.sh` | MinIO connection | Artifact store S3 | ✅ |
| `check-mlflow-experiment.sh` | Create/log experiment | Experiment tracking | ✅ |
| `check-mlflow-model-registry.sh` | Register model | Model registry | ✅ |

### suites/mlops-stack/kserve/ (KServe Model Serving) - NEW

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-kserve-installation.sh` | KServe CRDs installed | Custom resource definitions | ✅ |
| `check-knative-serving.sh` | Knative Serving operational | Knative components | ✅ |
| `check-cert-manager.sh` | Cert-manager deployed | Certificate management | ✅ |
| `check-inference-service-crd.sh` | InferenceService CRD | CRD availability | ✅ |
| `check-mlflow-serving-runtime.sh` | MLflow runtime configured | Serving runtime | ✅ |

### suites/inference-validation/ (Model Inference) - NEW

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-inference-service-deployment.sh` | InferenceService deploys | KServe deployment | ✅ |
| `check-model-loading.sh` | Model loads from MLflow | Model loading | ✅ |
| `check-inference-endpoint.sh` | Inference API accessible | HTTP endpoint | ✅ |
| `check-inference-request-response.sh` | API request/response cycle | Inference logic | ✅ |
| `check-gpu-utilization.sh` | GPU used during inference | GPU metrics | ✅ |
| `check-autoscaling-scale-up.sh` | Scales up under load | HPA, autoscaling | ✅ |
| `check-autoscaling-scale-down.sh` | Scales down when idle | Scale-down logic | ✅ |
| `check-multi-replica-load-balancing.sh` | Load balancing works | Service routing | ✅ |
| `check-inference-latency.sh` | Latency within acceptable range | Performance metrics | ✅ |
| `check-inference-throughput.sh` | Throughput meets targets | Throughput metrics | ✅ |

### suites/multi-cluster/ (Multi-Cluster Integration) - NEW

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `test-both-clusters-running.sh` | HPC and Cloud operational | Multi-cluster coordination | ✅ |
| `test-hpc-only.sh` | HPC running, Cloud stopped | HPC-only workflow | ✅ |
| `test-cloud-only.sh` | Cloud running, HPC stopped | Cloud-only workflow | ✅ |
| `test-cold-start.sh` | Both clusters from scratch | Cold start scenario | ✅ |
| `test-workflow-transition.sh` | HPC training → Cloud inference | End-to-end ML workflow | ✅ |
| `test-shared-gpu-conflict.sh` | GPU conflict at cluster level | Shared GPU management | ✅ |
| `test-vm-gpu-transfer.sh` | GPU transfer between VMs | Individual VM GPU switching | ✅ |
| `test-topology-visualization.sh` | Topology in all scenarios | Topology command validation | ✅ |
| `test-multi-cluster-auto-start.sh` | Cluster coexistence with `auto_start` | Multi-cluster with shared GPU | ✅ |

### suites/system-management/ (System-wide Management) - NEW

| Test Script | Validates | Components | Auto |
|-------------|-----------|------------|------|
| `check-system-start-ordering.sh` | HPC starts before Cloud | Startup sequence | ✅ |
| `check-system-stop-ordering.sh` | Cloud stops before HPC | Shutdown sequence | ✅ |
| `check-system-status-display.sh` | Status shows both clusters | Combined status display | ✅ |
| `check-system-status-shared-resources.sh` | Status shows GPU allocations | Shared resource display | ✅ |
| `check-system-destroy-confirmation.sh` | Confirmation prompt works | User confirmation | ✅ |
| `check-system-destroy-force.sh` | Force flag skips prompt | Force destroy | ✅ |
| `check-system-rollback-on-failure.sh` | Rollback HPC if Cloud fails | Failure handling | ✅ |
| `check-system-mixed-state.sh` | Handles one cluster running | Mixed state handling | ✅ |
| `check-system-config-validation.sh` | Missing/invalid config errors | Config validation | ✅ |
| `check-system-error-messages.sh` | Clear error messages | Error communication | ✅ |

---

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

---

### test-cloud-vm-framework.sh (NEW)

**Purpose**: Cloud VM lifecycle and management validation

**Components Covered**:

- Cloud VM provisioning (control plane, worker, GPU worker)
- VM network configuration and connectivity
- VM storage and volumes
- GPU passthrough for cloud workers
- Cluster lifecycle operations (start/stop/destroy)
- Individual VM lifecycle management (CLOUD-0.4)
- Shared GPU resource management (CLOUD-0.3)
- State tracking in global state
- CLI command validation

**Test Suites Used**:

- `suites/cloud-vm-lifecycle/`

**Deployment**: Cloud cluster VM management via ai-how CLI

**Estimated Time**: 20-30 minutes

---

### test-kubernetes-framework.sh (NEW)

**Purpose**: Kubernetes cluster deployment and validation

**Components Covered**:

- Kubespray deployment (CNCF-approved)
- Kubernetes API server and control plane
- Worker node registration and health
- Networking (Calico CNI, pod-to-pod)
- DNS resolution (CoreDNS)
- Ingress controller (NGINX)
- Metrics server
- GPU device plugin (NVIDIA GPU Operator)
- GPU scheduling in Kubernetes

**Test Suites Used**:

- `suites/kubernetes-cluster/`

**Deployment**: Kubespray Ansible playbooks

**Estimated Time**: 30-45 minutes

---

### test-mlops-stack-framework.sh (NEW)

**Purpose**: MLOps infrastructure and service validation

**Components Covered**:

- MinIO object storage (S3-compatible)
- PostgreSQL database (MLflow backend)
- MLflow tracking server and model registry
- KServe model serving platform
- Knative Serving
- Cert-manager
- Component integration (MLflow-MinIO, MLflow-PostgreSQL)

**Test Suites Used**:

- `suites/mlops-stack/minio/`
- `suites/mlops-stack/postgresql/`
- `suites/mlops-stack/mlflow/`
- `suites/mlops-stack/kserve/`

**Deployment**: Kubernetes manifests and Helm charts

**Estimated Time**: 35-50 minutes

---

### test-inference-framework.sh (NEW)

**Purpose**: Model inference and serving validation

**Components Covered**:

- InferenceService deployment (KServe)
- Model loading from MLflow
- Inference API endpoints
- GPU utilization during inference
- Horizontal pod autoscaling (HPA)
- Multi-replica load balancing
- Performance metrics (latency, throughput)

**Test Suites Used**:

- `suites/inference-validation/`

**Deployment**: KServe InferenceService CRDs

**Estimated Time**: 25-40 minutes

**Performance Targets**:

- Cold start: <10s
- Inference latency (P95): <500ms
- Throughput per GPU: >50 req/s
- GPU utilization: >70%
- Scale-up time: <60s
- Scale-down time: <120s

---

### test-multi-cluster-framework.sh (NEW)

**Purpose**: Multi-cluster coordination and workflow validation

**Components Covered**:

- HPC and Cloud cluster coordination
- Shared GPU resource management across clusters
- HPC training to Cloud inference workflow
- Model transfer (BeeGFS → MinIO)
- Unified monitoring across clusters
- Multi-cluster scenario testing

**Test Suites Used**:

- `suites/multi-cluster/`

**Deployment**: Both HPC and Cloud clusters running

**Estimated Time**: 45-60 minutes

**Scenarios Tested**:

- Scenario 1: Both clusters running (full stack)
- Scenario 2: HPC only (training workflow)
- Scenario 3: Cloud only (inference workflow)
- Scenario 4: Cold start (both clusters from scratch)
- Scenario 5: Workflow transition (HPC → Cloud)
- Scenario 6: Shared GPU conflicts (CLOUD-0.3)
- Scenario 7: Individual VM GPU transfer (CLOUD-0.4)

---

### test-system-management-framework.sh (NEW)

**Purpose**: System-wide cluster management and unified operations (CLOUD-0.6)

**Components Covered**:

- `ai-how system start` - Start both clusters
- `ai-how system stop` - Stop both clusters
- `ai-how system destroy` - Destroy both clusters
- `ai-how system status` - Show system status
- Intelligent startup ordering (HPC first, then Cloud)
- Intelligent shutdown ordering (Cloud first, then HPC)
- Rollback on partial failure
- Shared resource coordination

**Test Suites Used**:

- `suites/system-management/` (new)

**Deployment**: System-level cluster coordination

**Estimated Time**: 30-40 minutes

**Scenarios Tested**:

- Scenario 1: System startup (ordered correctly)
- Scenario 2: System shutdown (correct sequence)
- Scenario 3: System destroy with confirmation
- Scenario 4: System destroy with --force flag
- Scenario 5: System status shows both clusters
- Scenario 6: Rollback on Cloud startup failure
- Scenario 7: Mixed state (one cluster running)
- Scenario 8: Error handling for missing configs
- Scenario 9: Error handling for invalid configs
- Scenario 10: Shared resources properly displayed

---

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
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Base Infrastructure Layer                               │
│             - Base packages, SSH, networking, system                         │
└────────────────────────┬────────────────────────────────────────────────────┘
                         │
       ┌─────────────────┴──────────────────┐
       │                                    │
       ▼                                    ▼
┌─────────────────────┐         ┌─────────────────────┐
│   HPC SLURM Cluster  │         │   Cloud K8s Cluster  │
│                     │         │                     │
│ Controller:         │         │ Control Plane:      │
│  - SLURM Controller│         │  - Kubernetes       │
│  - Accounting      │         │  - Kubespray        │
│  - Prometheus      │         │                     │
│  - Grafana         │         │ Workers:            │
│                    │         │  - K8s Workers      │
│ Compute:           │         │  - GPU Workers      │
│  - SLURM Compute   │         │                     │
│  - Container RT    │         │ MLOps Stack:        │
│                    │         │  - MinIO            │
│ Storage:           │         │  - PostgreSQL       │
│  - BeeGFS          │         │  - MLflow           │
│  - VirtIO-FS       │         │  - KServe           │
│                    │         │                     │
│ GPU Config:        │         │ Inference:          │
│  - Cgroup          │         │  - Model Serving    │
│  - GPU GRES        │         │  - Autoscaling      │
│  - DCGM            │         │  - GPU Inference    │
└─────────┬───────────┘         └──────────┬──────────┘
          │                                │
          │      ┌─────────────────────────┤
          │      │                         │
          ▼      ▼                         ▼
     ┌─────────────────┐          ┌──────────────────┐
     │  Shared GPU     │          │  Model Transfer  │
     │  Management     │          │  BeeGFS → MinIO  │
     │  (CLOUD-0.3)    │          │                  │
     └─────────────────┘          └──────────────────┘
              │
              ▼
     ┌─────────────────┐
     │ Individual VM   │
     │ Lifecycle       │
     │ (CLOUD-0.4)     │
     └─────────────────┘
```

## Test Execution Recommendation

### HPC SLURM Cluster Test Order

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

**HPC Total Time**: ~2.5-5 hours for complete validation

---

### Cloud Cluster Test Order (NEW)

1. **Phase 1: Cloud VM Infrastructure** (20-30 min)
   - test-cloud-vm-framework
     - VM provisioning
     - Cluster lifecycle
     - Individual VM control
     - Shared GPU management

2. **Phase 2: Kubernetes Deployment** (30-45 min)
   - test-kubernetes-framework
     - Kubespray deployment
     - Cluster health
     - Networking and DNS
     - GPU scheduling

3. **Phase 3: MLOps Stack** (35-50 min)
   - test-mlops-stack-framework
     - MinIO object storage
     - PostgreSQL database
     - MLflow tracking server
     - KServe model serving

4. **Phase 4: Model Inference** (25-40 min)
   - test-inference-framework
     - InferenceService deployment
     - Model loading
     - Inference API
     - Autoscaling
     - Performance metrics

5. **Phase 5: Multi-Cluster Integration** (45-60 min)
   - test-multi-cluster-framework
     - HPC-Cloud coordination
     - Shared GPU conflicts
     - Workflow transition
     - Model transfer

**Cloud Total Time**: ~2.5-3.5 hours for complete validation

---

### Combined HPC + Cloud Test Execution

**Sequential Execution**: 5-8.5 hours (run HPC tests, then Cloud tests)

**Parallel Execution**: 3-5 hours (if sufficient hardware resources)

**Recommended Approach**: Sequential execution to avoid resource contention

---

### Quick Test Subsets

**HPC Quick Validation** (30-45 min):

- test-hpc-runtime (essential components)
- phase-4-validation (step 1-3 only)

**Cloud Quick Validation** (45-60 min):

- test-cloud-vm-framework (essential)
- test-kubernetes-framework (essential)

**Multi-Cluster Smoke Test** (20-30 min):

- test-multi-cluster-framework (Scenario 1 only)

## Summary

This component matrix provides a comprehensive view of test coverage across both **HPC SLURM** and **Cloud Kubernetes**
infrastructures. With 90%+ automated coverage across all major components, the test infrastructure is robust and
well-organized.

### HPC SLURM Coverage

- **7 test frameworks** covering controller, compute, storage, GPU, and container components
- **16 test suites** with 150+ individual test scripts
- **Complete workflow validation** from Packer images to production workloads

### Cloud Cluster Coverage (NEW)

- **5 test frameworks** covering VM management, Kubernetes, MLOps, inference, and multi-cluster
- **10 test suites** with 71+ individual test scripts
  - basic-infrastructure/ (11 tests for topology visualization)
  - cloud-vm-lifecycle/ (25 tests including `auto_start` functionality)
    - Cluster-level: 9 tests
    - Individual VM: 5 tests
    - Shared GPU: 11 tests (including 3 new `auto_start` tests)
  - kubernetes-cluster/ (9 tests)
  - mlops-stack/ (4 sub-suites: minio, postgresql, mlflow, kserve)
  - inference-validation/ (10 tests)
  - multi-cluster/ (9 tests including `auto_start` coexistence)
  - system-management/ (10 tests for system-wide management)
- **End-to-end ML workflow** from HPC training to Cloud inference
- **Shared GPU management** across clusters (CLOUD-0.3)
- **Auto-start control** for VM creation without GPU allocation (CLOUD-0.1, CLOUD-0.3)
- **Multi-cluster coexistence** with shared GPUs using `auto_start: false`
- **Individual VM lifecycle control** (CLOUD-0.4)
- **Topology visualization** with GPU conflict highlighting (CLOUD-0.2)

### Total Test Infrastructure

- **13 test frameworks** (7 HPC + 5 Cloud + 1 System Management)
  - 7 HPC frameworks (3 unified + 4 standalone)
  - 5 Cloud frameworks (cloud-vm, kubernetes, mlops, inference, multi-cluster)
  - 1 System management framework (unified system start/stop/destroy)
- **27 test suites** (16 HPC + 10 Cloud + 1 System Management)
  - 16 HPC test suites covering SLURM, storage, containers, GPU, monitoring
  - 10 Cloud test suites covering VMs, Kubernetes, MLOps, inference, multi-cluster
  - 1 System management test suite (10 tests for unified operations)
- **230+ test scripts** across all components (150+ HPC + 71+ Cloud + 10 System)
- **Complete ML platform** validation (training + inference)
- **AI-HOW CLI** comprehensive validation (topology, clusters, VMs, system)
- **Advanced GPU management** with `auto_start` control and multi-cluster coexistence
- **System-wide operations** for unified cluster management

The consolidation plan preserves this excellent coverage while reducing framework complexity and code duplication.
All test suites remain unchanged, ensuring proven test logic is maintained while improving the orchestration layer.

---

**Document Version**: 2.1  
**Last Updated**: 2025-10-28  
**Changes**: Added Cloud Cluster Components (CLOUD-0.3, CLOUD-0.4), System-wide Management (CLOUD-0.6)
