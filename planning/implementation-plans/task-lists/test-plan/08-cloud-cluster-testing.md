# Cloud Cluster Testing Requirements

## Overview

This document outlines testing requirements for the new cloud cluster infrastructure being added to support
Kubernetes-based model inference with Oumi. This complements the existing HPC SLURM test infrastructure and adds
validation for the complete ML workflow: **HPC training → Cloud inference**.

**Status**: Planning  
**Created**: 2025-10-28  
**Dependencies**: Cloud cluster implementation (CLOUD-0.1 through CLOUD-7.1)

---

## New Test Frameworks Needed

Based on the cloud cluster implementation plan, we need to add **4 new test frameworks** to validate the cloud
infrastructure.

### Summary Table

| Framework | Purpose | Test Suites | Priority | Status |
|-----------|---------|-------------|----------|--------|
| test-cloud-vm-framework.sh | Cloud VM lifecycle | cloud-vm-lifecycle/ | CRITICAL | Needed |
| test-kubernetes-framework.sh | K8s cluster validation | kubernetes-cluster/ | CRITICAL | Needed |
| test-mlops-stack-framework.sh | MLOps components | mlops-stack/ | HIGH | Needed |
| test-inference-framework.sh | Model serving | inference-validation/ | HIGH | Needed |

---

## Framework 1: test-cloud-vm-framework.sh

**Purpose**: Validate cloud VM provisioning and lifecycle management

**Location**: `tests/frameworks/test-cloud-vm-framework.sh`

**Configuration**: `tests/test-infra/configs/test-cloud-vm.yaml`

### Cluster Configuration

```yaml
cluster:
  name: test-cloud-vm
  type: cloud  # NEW: Distinguishes from HPC clusters
  control_plane_count: 1
  worker_count: 2
  gpu_worker_count: 1

images:
  control_plane: cloud-control-plane-latest.qcow2  # NEW: Cloud images
  worker: cloud-worker-latest.qcow2
  gpu_worker: cloud-gpu-worker-latest.qcow2

resources:
  control_plane_cpus: 4
  control_plane_memory: 8192
  worker_cpus: 4
  worker_memory: 8192
  gpu_worker_cpus: 8
  gpu_worker_memory: 16384

hardware:
  gpu_passthrough: true
  gpu_pci_ids:
    - "0000:01:00.0"

test_options:
  validate_vm_provisioning: true
  test_lifecycle_operations: true
  test_state_management: true
```

### Test Suites

#### suites/basic-infrastructure/

**Topology Visualization Tests** (NEW - CLOUD-0.2):

- `check-topology-command-output.sh` - Verify topology command output format
- `check-topology-cluster-display.sh` - Validate cluster information display
- `check-topology-network-display.sh` - Validate network CIDR display
- `check-topology-vm-display.sh` - Validate VM details (IPs, roles, resources)
- `check-topology-gpu-display.sh` - Validate GPU information display
- `check-topology-gpu-conflict-highlighting.sh` - Verify GPU conflicts highlighted in red
- `check-topology-tree-structure.sh` - Validate hierarchical tree structure
- `check-topology-color-coding.sh` - Verify color coding (green/yellow/red)
- `check-topology-multi-cluster.sh` - Test topology with multiple clusters
- `check-topology-empty-state.sh` - Test topology with no clusters running

#### suites/cloud-vm-lifecycle/

**Cluster-Level Tests**:

- `check-vm-provisioning.sh` - Verify VMs provision correctly
- `check-vm-network.sh` - Validate network configuration
- `check-vm-storage.sh` - Verify storage volumes
- `check-vm-gpu-passthrough.sh` - GPU passthrough validation
- `check-vm-lifecycle.sh` - Start/stop/restart operations
- `check-state-tracking.sh` - State management in state.json
- `check-auto-start-flag.sh` - Verify `auto_start: false` VMs created but not started (NEW)
- `check-auto-start-preservation.sh` - Verify `auto_start` flag preserved across restarts (NEW)
- `check-auto-start-status-display.sh` - Verify status command shows `auto_start` flag (NEW)

**Individual VM Tests** (NEW - CLOUD-0.4):

- `check-individual-vm-stop.sh` - Stop single VM with GPU release
- `check-individual-vm-start.sh` - Start single VM with GPU allocation
- `check-individual-vm-restart.sh` - Restart VM with GPU rebinding
- `check-vm-status-command.sh` - VM status display and accuracy
- `check-vm-gpu-release.sh` - GPU released when VM stops

**Shared GPU Tests** (NEW - CLOUD-0.3):

- `check-shared-gpu-detection.sh` - Detect GPUs shared between clusters
- `check-gpu-conflict-detection.sh` - Prevent simultaneous GPU usage
- `check-gpu-ownership-tracking.sh` - Validate global state GPU allocations
- `check-gpu-switch-between-vms.sh` - Sequential GPU transfer between VMs
- `check-gpu-error-messages.sh` - Clear error messages for GPU conflicts
- `check-auto-start-no-gpu-allocation.sh` - Verify VMs with `auto_start: false` don't allocate GPUs (NEW)
- `check-multi-cluster-coexistence.sh` - Both clusters running with shared GPU using `auto_start` (NEW)
- `check-manual-start-gpu-validation.sh` - GPU conflict checked when manually starting VM (NEW)

**Validation Criteria**:

- VMs provision with correct resources
- Network connectivity between VMs
- GPU passthrough works on GPU workers
- State.json accurately tracks cluster state
- Lifecycle operations (start/stop) work reliably
- VMs with `auto_start: false` are created but not started (NEW)
- `auto_start` flag preserved across cluster restarts (NEW)
- Status command clearly indicates VMs with `auto_start: false` (NEW)
- Individual VMs can be stopped/started independently (NEW)
- GPU resources released on VM stop (NEW)
- GPU conflicts detected and prevented (NEW)
- VMs with `auto_start: false` do NOT allocate GPUs (NEW)
- Multiple clusters can coexist with shared GPU using `auto_start: false` (NEW)
- Manual VM start checks GPU availability before allocation (NEW)
- Global state tracks GPU ownership accurately (NEW)
- Clear error messages for GPU conflicts (NEW)

### CLI Commands to Test

**Topology Command** (implemented in CLOUD-0.2):

```bash
# Display complete infrastructure topology
ai-how topology

# Test scenarios:
# 1. Empty state (no clusters running)
# 2. HPC cluster only
# 3. Cloud cluster only
# 4. Both clusters running
# 5. Shared GPU configuration (conflicts highlighted)
# 6. Individual VMs stopped within running cluster
```

**Cluster-Level Commands** (implemented in CLOUD-0.2):

```bash
# Start cloud cluster
ai-how cloud start config/cloud-cluster.yaml

# Check cluster status
ai-how cloud status config/cloud-cluster.yaml

# Stop cloud cluster
ai-how cloud stop config/cloud-cluster.yaml

# Destroy cloud cluster
ai-how cloud destroy config/cloud-cluster.yaml --force
```

**Individual VM Commands** (implemented in CLOUD-0.4):

```bash
# Stop individual VM with GPU release
ai-how vm stop <vm-name> [--force]

# Start individual VM with GPU allocation
ai-how vm start <vm-name> [--no-wait]

# Restart individual VM
ai-how vm restart <vm-name> [--no-wait]

# Check individual VM status
ai-how vm status <vm-name>
```

**Cluster Test Scenarios**:

1. **Cold Start**: Start cluster from scratch
2. **Warm Restart**: Stop and restart existing cluster
3. **Forced Destroy**: Cleanup with --force flag
4. **Status During Operations**: Check status while starting/stopping
5. **Error Recovery**: Validate rollback on failures

**Individual VM Test Scenarios**:

1. **Stop Individual VM**: Stop single VM in running cluster
2. **Start Individual VM**: Start single stopped VM
3. **Restart Individual VM**: Restart VM with automatic GPU rebinding
4. **VM Status Check**: Display detailed VM information
5. **GPU Conflict Detection**: Attempt to start VM with conflicted GPU

### Makefile Targets

```makefile
# Full cloud VM framework test
test-cloud-vm:
 ./frameworks/test-cloud-vm-framework.sh e2e

# Cluster-level tests
test-cloud-vm-provisioning:
 ./frameworks/test-cloud-vm-framework.sh run-tests cloud-vm-lifecycle

test-cloud-vm-cli:
 ./frameworks/test-cloud-vm-framework.sh test-cli-commands

# Individual VM tests (NEW - CLOUD-0.4)
test-individual-vm-lifecycle:
 ./frameworks/test-cloud-vm-framework.sh run-tests cloud-vm-lifecycle/individual

test-vm-cli-commands:
 ./frameworks/test-cloud-vm-framework.sh test-vm-commands

# Shared GPU tests (NEW - CLOUD-0.3)
test-shared-gpu-management:
 ./frameworks/test-cloud-vm-framework.sh run-tests cloud-vm-lifecycle/shared-gpu

test-gpu-conflict-detection:
 ./frameworks/test-cloud-vm-framework.sh test-gpu-conflicts
```

---

## Framework 2: test-kubernetes-framework.sh

**Purpose**: Validate Kubernetes cluster deployment via Kubespray

**Location**: `tests/frameworks/test-kubernetes-framework.sh`

**Configuration**: `tests/test-infra/configs/test-kubernetes.yaml`

### Cluster Configuration

```yaml
cluster:
  name: test-kubernetes
  type: cloud
  control_plane_count: 1
  worker_count: 2
  gpu_worker_count: 1

kubernetes:
  version: "1.28.0"
  network_plugin: calico
  cni_version: "v3.30.3"
  service_cidr: 10.96.0.0/12
  pod_cidr: 10.244.0.0/16
  dns_mode: coredns
  ingress_controller: nginx
  metrics_server: true

kubespray:
  enabled: true
  install_dir: build/3rd-party/kubespray/kubespray-src/

test_options:
  validate_kubespray_deployment: true
  test_cluster_health: true
  test_networking: true
  test_dns_resolution: true
  test_gpu_scheduling: true
```

### Test Suites

#### suites/kubernetes-cluster/

**Tests**:

- `check-kubespray-installation.sh` - Kubespray installed correctly
- `check-cluster-health.sh` - All nodes Ready, system pods Running
- `check-networking.sh` - Pod-to-pod communication
- `check-dns-resolution.sh` - CoreDNS resolution working
- `check-calico-cni.sh` - Calico network plugin operational
- `check-ingress-controller.sh` - NGINX ingress working
- `check-metrics-server.sh` - Metrics collection functional
- `check-gpu-device-plugin.sh` - GPU operator deployed
- `check-gpu-scheduling.sh` - GPU pods can be scheduled

**Validation Criteria**:

- Kubernetes API server accessible
- All nodes report Ready status
- System pods (kube-system namespace) running
- Pod-to-pod networking functional
- DNS resolution works for cluster services
- Ingress controller serving traffic
- GPU resources exposed via device plugin

### Integration with Kubespray

**Test Scenarios**:

1. **Fresh Deployment**: Deploy K8s cluster from scratch
2. **Cluster Upgrade**: Test version upgrades (future)
3. **Node Addition**: Add worker nodes dynamically (future)
4. **Kubespray Validation**: Verify all Kubespray components

### Makefile Targets

```makefile
test-kubernetes:
 ./frameworks/test-kubernetes-framework.sh e2e

test-kubernetes-deployment:
 ./frameworks/test-kubernetes-framework.sh deploy-and-validate

test-kubernetes-networking:
 ./frameworks/test-kubernetes-framework.sh run-tests kubernetes-cluster
```

---

## Framework 3: test-mlops-stack-framework.sh

**Purpose**: Validate MLOps stack deployment (MinIO, PostgreSQL, MLflow, KServe)

**Location**: `tests/frameworks/test-mlops-stack-framework.sh`

**Configuration**: `tests/test-infra/configs/test-mlops-stack.yaml`

### Cluster Configuration

```yaml
cluster:
  name: test-mlops-stack
  type: cloud
  control_plane_count: 1
  worker_count: 1
  gpu_worker_count: 1

mlops:
  minio:
    enabled: true
    storage_size: 50Gi
    buckets:
      - mlflow-artifacts
      - models
      - datasets

  postgresql:
    enabled: true
    storage_size: 10Gi
    database: mlflow

  mlflow:
    enabled: true
    replicas: 2
    version: "2.9.2"

  kserve:
    enabled: true
    version: "0.11.2"
    knative_version: "1.11.0"

test_options:
  test_minio: true
  test_postgresql: true
  test_mlflow: true
  test_kserve: true
  test_integration: true
```

### Test Suites

#### suites/mlops-stack/

**Tests**:

1. **MinIO Tests** (`minio/`):
   - `check-minio-deployment.sh` - MinIO pods running
   - `check-minio-storage.sh` - Persistent volumes attached
   - `check-minio-buckets.sh` - Buckets created correctly
   - `check-minio-api.sh` - S3 API accessible
   - `check-minio-upload-download.sh` - Upload/download operations

2. **PostgreSQL Tests** (`postgresql/`):
   - `check-postgresql-deployment.sh` - PostgreSQL pod running
   - `check-postgresql-connection.sh` - Database connectivity
   - `check-mlflow-schema.sh` - MLflow tables exist
   - `check-postgresql-persistence.sh` - Data persists across restarts

3. **MLflow Tests** (`mlflow/`):
   - `check-mlflow-deployment.sh` - MLflow pods running
   - `check-mlflow-api.sh` - REST API accessible
   - `check-mlflow-backend-store.sh` - PostgreSQL connection
   - `check-mlflow-artifact-store.sh` - MinIO connection
   - `check-mlflow-experiment.sh` - Create/log experiment
   - `check-mlflow-model-registry.sh` - Register model

4. **KServe Tests** (`kserve/`):
   - `check-kserve-installation.sh` - KServe CRDs installed
   - `check-knative-serving.sh` - Knative Serving operational
   - `check-cert-manager.sh` - Cert-manager deployed
   - `check-inference-service-crd.sh` - InferenceService CRD available
   - `check-mlflow-serving-runtime.sh` - MLflow runtime configured

**Validation Criteria**:

- MinIO accessible and buckets created
- PostgreSQL accepting connections
- MLflow API responding and tracking experiments
- KServe controller running and CRDs registered
- End-to-end: Register model in MLflow → Deploy via KServe

### Makefile Targets

```makefile
test-mlops-stack:
 ./frameworks/test-mlops-stack-framework.sh e2e

test-mlops-minio:
 ./frameworks/test-mlops-stack-framework.sh run-tests mlops-stack/minio

test-mlops-mlflow:
 ./frameworks/test-mlops-stack-framework.sh run-tests mlops-stack/mlflow

test-mlops-kserve:
 ./frameworks/test-mlops-stack-framework.sh run-tests mlops-stack/kserve
```

---

## Framework 4: test-inference-framework.sh

**Purpose**: Validate model serving and inference workflows

**Location**: `tests/frameworks/test-inference-framework.sh`

**Configuration**: `tests/test-infra/configs/test-inference.yaml`

### Cluster Configuration

```yaml
cluster:
  name: test-inference
  type: cloud
  control_plane_count: 1
  worker_count: 1
  gpu_worker_count: 2

inference:
  test_model: "oumi-test-model-v1"
  model_format: "mlflow"
  storage_uri: "s3://models/oumi-test-model-v1"
  
  autoscaling:
    min_replicas: 1
    max_replicas: 3
    target_utilization: 80

  gpu_config:
    resource_limit: "nvidia.com/gpu: 1"
    node_selector:
      workload-type: inference

test_options:
  test_model_deployment: true
  test_inference_api: true
  test_autoscaling: true
  test_gpu_inference: true
  test_multi_replica: true
```

### Test Suites

#### suites/inference-validation/

**Tests**:

- `check-inference-service-deployment.sh` - InferenceService deploys
- `check-model-loading.sh` - Model loads from MLflow
- `check-inference-endpoint.sh` - Inference API accessible
- `check-inference-request-response.sh` - API request/response cycle
- `check-gpu-utilization.sh` - GPU used during inference
- `check-autoscaling-scale-up.sh` - Scales up under load
- `check-autoscaling-scale-down.sh` - Scales down when idle
- `check-multi-replica-load-balancing.sh` - Load balancing works
- `check-inference-latency.sh` - Latency within acceptable range
- `check-inference-throughput.sh` - Throughput meets targets

**Validation Criteria**:

- InferenceService reaches Ready state
- Inference requests return valid responses
- GPU is utilized during inference (>70%)
- Autoscaling works based on load
- Latency P95 < 500ms
- Throughput > 50 req/s per GPU

### Performance Targets

| Metric | Target | Test |
|--------|--------|------|
| Cold start | <10s | check-model-loading.sh |
| Inference latency (P95) | <500ms | check-inference-latency.sh |
| Throughput per GPU | >50 req/s | check-inference-throughput.sh |
| GPU utilization | >70% | check-gpu-utilization.sh |
| Scale-up time | <60s | check-autoscaling-scale-up.sh |
| Scale-down time | <120s | check-autoscaling-scale-down.sh |

### Makefile Targets

```makefile
test-inference:
 ./frameworks/test-inference-framework.sh e2e

test-inference-deployment:
 ./frameworks/test-inference-framework.sh run-tests inference-validation

test-inference-performance:
 ./frameworks/test-inference-framework.sh run-performance-tests
```

---

## Cluster Start/Stop Scenarios

### Scenario Matrix

| Scenario | HPC Cluster | Cloud Cluster | Use Case | Test |
|----------|-------------|---------------|----------|------|
| **Scenario 1** | Running | Running | Full stack development | test-multi-cluster.sh |
| **Scenario 2** | Running | Stopped | HPC training only | test-hpc-only.sh |
| **Scenario 3** | Stopped | Running | Cloud inference only | test-cloud-only.sh |
| **Scenario 4** | Stopped | Stopped | Clean environment | test-cold-start.sh |
| **Scenario 5** | Running | Starting | HPC→Cloud workflow | test-workflow-transition.sh |
| **Scenario 6** | Running→Stopped→Running | Stopped→Running | Shared GPU conflict (NEW) | test-shared-gpu-conflict.sh |
| **Scenario 7** | VM Stopped→Started | VM Started→Stopped | VM GPU transfer (NEW) | test-vm-gpu-transfer.sh |
| **Scenario 8** | Multiple states | Multiple states | Topology visualization (NEW) | test-topology-visualization.sh |
| **Scenario 9** | Running | Running | Multi-cluster coexistence with `auto_start` (NEW) | test-multi-cluster-auto-start.sh |

### Detailed Scenario Tests

#### Scenario 1: Both Clusters Running

**Test**: `tests/suites/multi-cluster/test-both-clusters-running.sh`

```bash
# Validate both clusters operational
test_both_clusters_running() {
    # Start HPC cluster
    ai-how hpc start config/hpc-cluster.yaml
    assert_cluster_ready "hpc"
    
    # Start Cloud cluster
    ai-how cloud start config/cloud-cluster.yaml
    assert_cluster_ready "cloud"
    
    # Verify network isolation
    assert_network_isolated "hpc" "cloud"
    
    # Verify resource allocation
    assert_resources_available "hpc" "minimum"
    assert_resources_available "cloud" "minimum"
}
```

#### Scenario 2: HPC Only

**Test**: `tests/suites/multi-cluster/test-hpc-only.sh`

```bash
test_hpc_only() {
    # Start HPC cluster
    ai-how hpc start config/hpc-cluster.yaml
    
    # Verify cloud cluster not running
    ai-how cloud status config/cloud-cluster.yaml | grep "stopped"
    
    # Run HPC workload
    run_slurm_job "test-job.sh"
}
```

#### Scenario 3: Cloud Only

**Test**: `tests/suites/multi-cluster/test-cloud-only.sh`

```bash
test_cloud_only() {
    # Start Cloud cluster
    ai-how cloud start config/cloud-cluster.yaml
    
    # Verify HPC cluster not running
    ai-how hpc status config/hpc-cluster.yaml | grep "stopped"
    
    # Deploy inference service
    kubectl apply -f test-inference-service.yaml
    kubectl wait --for=condition=Ready inferenceservice/test-model
}
```

#### Scenario 4: Cold Start

**Test**: `tests/suites/multi-cluster/test-cold-start.sh`

```bash
test_cold_start() {
    # Ensure both clusters stopped
    ai-how hpc destroy config/hpc-cluster.yaml --force
    ai-how cloud destroy config/cloud-cluster.yaml --force
    
    # Verify clean state
    assert_no_running_vms
    assert_state_file_clean
}
```

#### Scenario 5: Workflow Transition

**Test**: `tests/suites/multi-cluster/test-workflow-transition.sh`

```bash
test_workflow_transition() {
    # Start HPC cluster and train model
    ai-how hpc start config/hpc-cluster.yaml
    run_training_job "train-oumi-model.sh"
    export_model_artifacts
    
    # Start Cloud cluster
    ai-how cloud start config/cloud-cluster.yaml
    
    # Transfer model to Cloud
    transfer_model_to_cloud "oumi-model-v1"
    
    # Deploy for inference
    deploy_inference_service "oumi-model-v1"
    
    # Validate inference
    test_inference_endpoint
}
```

#### Scenario 6: Shared GPU Between Clusters (NEW - CLOUD-0.3)

**Test**: `tests/suites/multi-cluster/test-shared-gpu-conflict.sh`

```bash
test_shared_gpu_conflict() {
    # Configure both clusters to use same GPU (0000:01:00.0)
    # config/test-shared-gpu.yaml has shared GPU in both clusters
    
    # Start HPC cluster (should succeed)
    ai-how hpc start config/test-shared-gpu.yaml
    assert_cluster_ready "hpc"
    
    # Verify GPU allocated to HPC
    cat output/global-state.json | jq '.shared_resources.gpu_allocations["0000:01:00.0"]' | grep "hpc"
    
    # Try to start Cloud cluster (should fail)
    if ai-how cloud start config/test-shared-gpu.yaml 2>&1 | grep "GPU.*currently allocated"; then
        echo "✅ GPU conflict detected correctly"
    else
        echo "❌ GPU conflict NOT detected - FAIL"
        exit 1
    fi
    
    # Stop HPC cluster
    ai-how hpc stop config/test-shared-gpu.yaml
    
    # Verify GPU released
    cat output/global-state.json | jq '.shared_resources.gpu_allocations' | grep -v "0000:01:00.0"
    
    # Start Cloud cluster (should now succeed)
    ai-how cloud start config/test-shared-gpu.yaml
    assert_cluster_ready "cloud"
    
    # Verify GPU allocated to Cloud
    cat output/global-state.json | jq '.shared_resources.gpu_allocations["0000:01:00.0"]' | grep "cloud"
}
```

#### Scenario 7: Individual VM GPU Transfer (NEW - CLOUD-0.4)

**Test**: `tests/suites/multi-cluster/test-vm-gpu-transfer.sh`

```bash
test_vm_gpu_transfer() {
    # Start HPC cluster with GPU on compute node
    ai-how hpc start config/test-shared-gpu.yaml
    
    # Verify HPC compute node has GPU
    ai-how vm status hpc-cluster-compute-01 | grep "GPU: 0000:01:00.0"
    
    # Stop HPC compute node (releases GPU)
    ai-how vm stop hpc-cluster-compute-01
    
    # Verify GPU released in global state
    cat output/global-state.json | jq '.shared_resources.gpu_allocations' | grep -v "0000:01:00.0"
    
    # Start Cloud GPU worker (same GPU)
    ai-how vm start cloud-cluster-gpu-worker-01
    
    # Verify Cloud worker has GPU
    ai-how vm status cloud-cluster-gpu-worker-01 | grep "GPU: 0000:01:00.0"
    
    # Try to start HPC compute node again (should fail - GPU in use)
    if ai-how vm start hpc-cluster-compute-01 2>&1 | grep "GPU.*currently allocated"; then
        echo "✅ VM GPU conflict detected correctly"
    else
        echo "❌ VM GPU conflict NOT detected - FAIL"
        exit 1
    fi
    
    # Stop Cloud worker
    ai-how vm stop cloud-cluster-gpu-worker-01
    
    # Start HPC compute node (should succeed now)
    ai-how vm start hpc-cluster-compute-01
    assert_vm_running "hpc-cluster-compute-01"
}
```

#### Scenario 8: Topology Visualization Testing (NEW - CLOUD-0.2)

**Test**: `tests/suites/basic-infrastructure/test-topology-visualization.sh`

```bash
test_topology_visualization() {
    log_info "Testing ai-how topology command..."
    
    # Test 1: Empty state (no clusters running)
    log_info "Test 1: Empty topology"
    ai-how hpc destroy config/test-shared-gpu.yaml --force 2>/dev/null || true
    ai-how cloud destroy config/test-shared-gpu.yaml --force 2>/dev/null || true
    
    topology_output=$(ai-how topology)
    if echo "$topology_output" | grep -q "No clusters running" || \
       echo "$topology_output" | grep -q "Infrastructure Topology"; then
        log_info "✅ Empty topology displayed correctly"
    else
        log_error "❌ Empty topology output incorrect"
        return 1
    fi
    
    # Test 2: HPC cluster only
    log_info "Test 2: HPC cluster topology"
    ai-how hpc start config/test-shared-gpu.yaml
    
    topology_output=$(ai-how topology)
    
    # Verify HPC cluster present
    echo "$topology_output" | grep -q "HPC Cluster" || {
        log_error "❌ HPC Cluster not shown in topology"
        return 1
    }
    
    # Verify network information
    echo "$topology_output" | grep -q "Network:.*192.168.100" || {
        log_error "❌ Network CIDR not shown"
        return 1
    }
    
    # Verify VM information (controller)
    echo "$topology_output" | grep -q "controller.*192.168.100.10" || {
        log_error "❌ Controller VM not shown"
        return 1
    }
    
    # Verify resource information
    echo "$topology_output" | grep -q "CPU:" && \
    echo "$topology_output" | grep -q "RAM:" || {
        log_error "❌ VM resources not shown"
        return 1
    }
    
    # Verify GPU information
    echo "$topology_output" | grep -q "GPU:.*0000:01:00.0" || {
        log_error "❌ GPU information not shown"
        return 1
    }
    
    log_info "✅ HPC cluster topology correct"
    
    # Test 3: Both clusters with GPU conflict
    log_info "Test 3: Multi-cluster topology with GPU conflict"
    
    # Try to start Cloud cluster (should fail due to GPU conflict)
    ai-how cloud start config/test-shared-gpu.yaml 2>&1 | grep -q "GPU.*currently allocated" || {
        log_error "❌ GPU conflict not detected during start"
        return 1
    }
    
    # Check topology shows conflict warning
    topology_output=$(ai-how topology)
    
    # Verify GPU conflict highlighted
    if echo "$topology_output" | grep -q "⚠️ GPU CONFLICT" || \
       echo "$topology_output" | grep -q "SHARED.*Cannot run"; then
        log_info "✅ GPU conflict highlighted in topology"
    else
        log_error "❌ GPU conflict NOT highlighted in topology"
        return 1
    fi
    
    # Test 4: Cloud cluster only
    log_info "Test 4: Cloud cluster topology after HPC stop"
    ai-how hpc stop config/test-shared-gpu.yaml
    ai-how cloud start config/test-shared-gpu.yaml
    
    topology_output=$(ai-how topology)
    
    # Verify HPC shown as stopped
    echo "$topology_output" | grep -q "HPC Cluster.*stopped" || {
        log_error "❌ HPC cluster not shown as stopped"
        return 1
    }
    
    # Verify Cloud shown as running
    echo "$topology_output" | grep -q "Cloud Cluster.*running" || {
        log_error "❌ Cloud cluster not shown as running"
        return 1
    }
    
    # Verify Cloud network
    echo "$topology_output" | grep -q "Network:.*192.168.200" || {
        log_error "❌ Cloud network not shown"
        return 1
    }
    
    # Verify Kubernetes roles
    echo "$topology_output" | grep -q "Kubernetes Control Plane" && \
    echo "$topology_output" | grep -q "Kubernetes Worker" || {
        log_error "❌ Kubernetes roles not shown"
        return 1
    }
    
    log_info "✅ Cloud cluster topology correct"
    
    # Test 5: Individual VM stopped
    log_info "Test 5: Topology with individual VM stopped"
    ai-how vm stop cloud-cluster-gpu-worker-01
    
    topology_output=$(ai-how topology)
    
    # Verify GPU worker shown as stopped
    echo "$topology_output" | grep "gpu-worker-01.*stopped" || {
        log_error "❌ Stopped VM not shown correctly"
        return 1
    }
    
    # Verify GPU shown as released
    if echo "$topology_output" | grep -q "\[ALLOCATED\]"; then
        log_error "❌ GPU still shown as allocated after VM stop"
        return 1
    fi
    
    log_info "✅ Individual VM stop reflected in topology"
    
    # Test 6: Both clusters running (no shared GPU)
    log_info "Test 6: Both clusters running without conflicts"
    ai-how cloud destroy config/test-shared-gpu.yaml --force
    ai-how cloud start config/cloud-cluster.yaml  # Different config without shared GPU
    ai-how hpc start config/hpc-cluster.yaml
    
    topology_output=$(ai-how topology)
    
    # Verify both clusters shown as running
    echo "$topology_output" | grep -q "HPC Cluster.*running" && \
    echo "$topology_output" | grep -q "Cloud Cluster.*running" || {
        log_error "❌ Both clusters not shown as running"
        return 1
    }
    
    # Verify no GPU conflict warnings
    if echo "$topology_output" | grep -q "⚠️ GPU CONFLICT"; then
        log_error "❌ False GPU conflict warning shown"
        return 1
    fi
    
    log_info "✅ Both clusters topology correct"
    log_info "✅ All topology visualization tests passed"
}
```

#### Scenario 9: Multi-Cluster Coexistence with `auto_start` (NEW - CLOUD-0.3)

**Test**: `tests/suites/multi-cluster/test-multi-cluster-auto-start.sh`

```bash
test_multi_cluster_auto_start() {
    log_info "Testing multi-cluster coexistence with auto_start: false..."
    
    # Use config with shared GPU where Cloud GPU worker has auto_start: false
    # config/example-multi-gpu-clusters.yaml
    
    # Test 1: Start HPC cluster (GPU allocated)
    log_info "Test 1: Start HPC cluster with GPU"
    ai-how hpc start config/example-multi-gpu-clusters.yaml
    assert_cluster_ready "hpc"
    
    # Verify GPU allocated to HPC compute node
    cat output/global-state.json | jq '.shared_resources.gpu_allocations["0000:01:00.0"]' | grep -q "hpc" || {
        log_error "❌ GPU not allocated to HPC cluster"
        return 1
    }
    log_info "✅ GPU allocated to HPC cluster"
    
    # Test 2: Start Cloud cluster (GPU worker has auto_start: false)
    log_info "Test 2: Start Cloud cluster with auto_start: false GPU worker"
    ai-how cloud start config/example-multi-gpu-clusters.yaml
    
    # Should succeed because Cloud GPU worker won't start
    if ! is_cloud_cluster_running "config/example-multi-gpu-clusters.yaml"; then
        log_error "❌ Cloud cluster failed to start"
        return 1
    fi
    log_info "✅ Cloud cluster started successfully"
    
    # Test 3: Verify Cloud GPU worker created but not running
    log_info "Test 3: Verify Cloud GPU worker state"
    
    # Check VM exists
    if ! virsh list --all | grep -q "cloud-cluster-gpu-worker"; then
        log_error "❌ Cloud GPU worker VM not created"
        return 1
    fi
    
    # Check VM is in shutoff state
    if virsh list --all | grep "cloud-cluster-gpu-worker" | grep -q "shut off"; then
        log_info "✅ Cloud GPU worker created but not running"
    else
        log_error "❌ Cloud GPU worker should be in shutoff state"
        return 1
    fi
    
    # Test 4: Verify GPU still allocated only to HPC
    log_info "Test 4: Verify GPU allocation state"
    
    gpu_owner=$(jq -r '.shared_resources.gpu_allocations["0000:01:00.0"]' output/global-state.json)
    if [ "$gpu_owner" = "hpc-cluster-compute-01" ]; then
        log_info "✅ GPU still allocated only to HPC cluster"
    else
        log_error "❌ GPU allocation incorrect: $gpu_owner"
        return 1
    fi
    
    # Test 5: Verify both clusters operational
    log_info "Test 5: Verify both clusters running simultaneously"
    
    if ! is_hpc_cluster_running "config/example-multi-gpu-clusters.yaml"; then
        log_error "❌ HPC cluster not running"
        return 1
    fi
    
    if ! is_cloud_cluster_running "config/example-multi-gpu-clusters.yaml"; then
        log_error "❌ Cloud cluster not running"
        return 1
    fi
    
    log_info "✅ Both clusters running simultaneously without GPU conflict"
    
    # Test 6: Verify status command shows auto_start flag
    log_info "Test 6: Verify status display"
    
    cloud_status=$(ai-how cloud status config/example-multi-gpu-clusters.yaml)
    if echo "$cloud_status" | grep -q "auto_start: false"; then
        log_info "✅ Status command shows auto_start flag"
    else
        log_warning "⚠️  Status command doesn't clearly show auto_start flag"
    fi
    
    # Test 7: Try to manually start Cloud GPU worker (should fail - GPU conflict)
    log_info "Test 7: Test manual start with GPU conflict"
    
    if ai-how vm start cloud-cluster-gpu-worker-01 2>&1 | grep -q "GPU.*currently allocated"; then
        log_info "✅ Manual start correctly detects GPU conflict"
    else
        log_error "❌ Manual start did not detect GPU conflict"
        return 1
    fi
    
    # Test 8: Stop HPC cluster, then start Cloud GPU worker
    log_info "Test 8: Switch GPU from HPC to Cloud"
    
    ai-how hpc stop config/example-multi-gpu-clusters.yaml
    
    # Verify GPU released
    if jq -e '.shared_resources.gpu_allocations["0000:01:00.0"]' output/global-state.json >/dev/null 2>&1; then
        log_error "❌ GPU not released after HPC stop"
        return 1
    fi
    log_info "✅ GPU released after HPC stop"
    
    # Start Cloud GPU worker
    ai-how vm start cloud-cluster-gpu-worker-01
    wait_for_vm_ready "cloud-cluster-gpu-worker-01"
    
    # Verify GPU now allocated to Cloud
    gpu_owner=$(jq -r '.shared_resources.gpu_allocations["0000:01:00.0"]' output/global-state.json)
    if [ "$gpu_owner" = "cloud-cluster-gpu-worker-01" ]; then
        log_info "✅ GPU successfully switched to Cloud cluster"
    else
        log_error "❌ GPU not allocated to Cloud: $gpu_owner"
        return 1
    fi
    
    # Test 9: Restart Cloud cluster, verify auto_start preserved
    log_info "Test 9: Verify auto_start flag preserved across restart"
    
    ai-how cloud stop config/example-multi-gpu-clusters.yaml
    ai-how cloud start config/example-multi-gpu-clusters.yaml
    
    # Cloud GPU worker should still be stopped
    if virsh list --all | grep "cloud-cluster-gpu-worker" | grep -q "shut off"; then
        log_info "✅ auto_start: false preserved across cluster restart"
    else
        log_error "❌ auto_start flag not preserved"
        return 1
    fi
    
    log_info "✅ All multi-cluster auto_start tests passed"
}
```

---

## New Test Infrastructure Features

### 1. Multi-Cluster State Management

**Location**: `tests/test-infra/utils/multi-cluster-utils.sh`

**Functions**:

```bash
# Check if HPC cluster is running
is_hpc_cluster_running() {
    ai-how hpc status "$HPC_CONFIG" 2>/dev/null | grep -q "running"
}

# Check if Cloud cluster is running
is_cloud_cluster_running() {
    ai-how cloud status "$CLOUD_CONFIG" 2>/dev/null | grep -q "running"
}

# Get combined cluster status
get_multi_cluster_status() {
    local hpc_status=$(get_cluster_status "hpc" "$HPC_CONFIG")
    local cloud_status=$(get_cluster_status "cloud" "$CLOUD_CONFIG")
    echo "HPC: $hpc_status | Cloud: $cloud_status"
}

# Validate resource availability for both clusters
validate_multi_cluster_resources() {
    local total_cpus=$(get_available_cpus)
    local total_memory=$(get_available_memory)
    local total_gpus=$(get_available_gpus)
    
    local required_cpus=$((HPC_CPU_REQ + CLOUD_CPU_REQ))
    local required_memory=$((HPC_MEM_REQ + CLOUD_MEM_REQ))
    local required_gpus=$((HPC_GPU_REQ + CLOUD_GPU_REQ))
    
    assert_gte "$total_cpus" "$required_cpus" "Insufficient CPUs"
    assert_gte "$total_memory" "$required_memory" "Insufficient memory"
    assert_gte "$total_gpus" "$required_gpus" "Insufficient GPUs"
}
```

### 2. Cloud CLI Test Utilities

**Location**: `tests/test-infra/utils/cloud-cli-utils.sh`

**Functions**:

```bash
# Test cloud CLI command
test_cloud_cli_command() {
    local command="$1"
    local config="$2"
    local expected_exit_code="${3:-0}"
    
    ai-how cloud "$command" "$config"
    assert_exit_code "$expected_exit_code" "Cloud CLI command failed: $command"
}

# Test individual VM CLI command (NEW - CLOUD-0.4)
test_vm_cli_command() {
    local command="$1"
    local vm_name="$2"
    local expected_exit_code="${3:-0}"
    
    ai-how vm "$command" "$vm_name"
    assert_exit_code "$expected_exit_code" "VM CLI command failed: $command $vm_name"
}

# Wait for cloud cluster to be ready
wait_for_cloud_cluster_ready() {
    local config="$1"
    local timeout="${2:-300}"
    local elapsed=0
    
    while ! is_cloud_cluster_running "$config"; do
        sleep 10
        elapsed=$((elapsed + 10))
        if [ $elapsed -ge $timeout ]; then
            log_error "Cloud cluster did not become ready within ${timeout}s"
            return 1
        fi
    done
}

# Wait for individual VM to be ready (NEW - CLOUD-0.4)
wait_for_vm_ready() {
    local vm_name="$1"
    local timeout="${2:-120}"
    local elapsed=0
    
    while ! is_vm_running "$vm_name"; do
        sleep 5
        elapsed=$((elapsed + 5))
        if [ $elapsed -ge $timeout ]; then
            log_error "VM ${vm_name} did not become ready within ${timeout}s"
            return 1
        fi
    done
}

# Validate Kubernetes cluster
validate_kubernetes_cluster() {
    kubectl cluster-info
    assert_exit_code 0 "Kubernetes cluster not accessible"
    
    kubectl get nodes | grep -q "Ready"
    assert_exit_code 0 "No Ready nodes in cluster"
}
```

### 3. GPU Management Testing Utilities (NEW - CLOUD-0.3, CLOUD-0.4)

**Location**: `tests/test-infra/utils/gpu-test-utils.sh`

**Functions**:

```bash
# Check GPU allocation in global state
check_gpu_allocation() {
    local pci_address="$1"
    local expected_owner="$2"
    
    local actual_owner=$(jq -r ".shared_resources.gpu_allocations[\"$pci_address\"]" output/global-state.json)
    
    if [ "$actual_owner" = "$expected_owner" ]; then
        log_info "✅ GPU $pci_address correctly allocated to $expected_owner"
        return 0
    else
        log_error "❌ GPU $pci_address allocated to '$actual_owner', expected '$expected_owner'"
        return 1
    fi
}

# Check GPU is not allocated
check_gpu_released() {
    local pci_address="$1"
    
    if jq -e ".shared_resources.gpu_allocations[\"$pci_address\"]" output/global-state.json >/dev/null 2>&1; then
        local owner=$(jq -r ".shared_resources.gpu_allocations[\"$pci_address\"]" output/global-state.json)
        log_error "❌ GPU $pci_address still allocated to $owner, expected released"
        return 1
    else
        log_info "✅ GPU $pci_address correctly released"
        return 0
    fi
}

# Test GPU conflict detection
test_gpu_conflict() {
    local command="$1"
    local config_or_vm="$2"
    
    # Run command and capture output
    local output
    if ! output=$(eval "$command" "$config_or_vm" 2>&1); then
        # Command failed - check if it's a GPU conflict error
        if echo "$output" | grep -q "GPU.*currently allocated"; then
            log_info "✅ GPU conflict correctly detected"
            return 0
        else
            log_error "❌ Command failed but not due to GPU conflict: $output"
            return 1
        fi
    else
        log_error "❌ Command succeeded when GPU conflict expected"
        return 1
    fi
}

# Get GPU owner from global state
get_gpu_owner() {
    local pci_address="$1"
    
    jq -r ".shared_resources.gpu_allocations[\"$pci_address\"] // \"none\"" output/global-state.json
}

# Verify VM has GPU assigned
verify_vm_gpu() {
    local vm_name="$1"
    local expected_pci="$2"
    
    local vm_status=$(ai-how vm status "$vm_name")
    
    if echo "$vm_status" | grep -q "$expected_pci"; then
        log_info "✅ VM $vm_name has GPU $expected_pci"
        return 0
    else
        log_error "❌ VM $vm_name does not have GPU $expected_pci"
        return 1
    fi
}

# Test GPU sequential transfer between VMs
test_gpu_transfer() {
    local vm1="$1"
    local vm2="$2"
    local gpu_pci="$3"
    
    log_info "Testing GPU transfer from $vm1 to $vm2"
    
    # Stop first VM
    ai-how vm stop "$vm1"
    check_gpu_released "$gpu_pci" || return 1
    
    # Start second VM
    ai-how vm start "$vm2"
    wait_for_vm_ready "$vm2"
    verify_vm_gpu "$vm2" "$gpu_pci" || return 1
    check_gpu_allocation "$gpu_pci" "$vm2" || return 1
    
    log_info "✅ GPU successfully transferred from $vm1 to $vm2"
    return 0
}
```

### 4. MLOps Testing Utilities

**Location**: `tests/test-infra/utils/mlops-test-utils.sh`

**Functions**:

```bash
# Test MinIO bucket access
test_minio_bucket() {
    local bucket="$1"
    kubectl exec -n mlops deployment/minio -- mc ls "local/$bucket"
    assert_exit_code 0 "MinIO bucket not accessible: $bucket"
}

# Test MLflow API
test_mlflow_api() {
    local endpoint="${1:-/api/2.0/mlflow/experiments/list}"
    kubectl port-forward -n mlops svc/mlflow 5000:5000 &
    local pf_pid=$!
    sleep 5
    
    curl -f "http://localhost:5000$endpoint"
    local result=$?
    
    kill $pf_pid
    assert_exit_code $result "MLflow API not responding: $endpoint"
}

# Deploy test InferenceService
deploy_test_inference_service() {
    local model_name="$1"
    local manifest="$2"
    
    kubectl apply -f "$manifest"
    kubectl wait --for=condition=Ready "inferenceservice/$model_name" --timeout=300s
}
```

---

## Integration with Existing Test Plan

### Updated Test Framework Count

**Before** (HPC only):

- 7 test frameworks (3 unified + 4 standalone)

**After** (HPC + Cloud):

- 11 test frameworks total
  - 7 HPC frameworks (existing)
  - 4 Cloud frameworks (new)

### Updated Component Matrix

Add new section to `02-component-matrix.md`:

```markdown
### Cloud Cluster Components

| Component | Test Framework | Test Suite | Coverage | Status |
|-----------|---------------|------------|----------|--------|
| **Cloud VM Management** | test-cloud-vm | cloud-vm-lifecycle/ | Provisioning, lifecycle | ✅ Planned |
| **Kubernetes (Kubespray)** | test-kubernetes | kubernetes-cluster/ | K8s deployment | ✅ Planned |
| **MinIO** | test-mlops-stack | mlops-stack/minio/ | Object storage | ✅ Planned |
| **PostgreSQL** | test-mlops-stack | mlops-stack/postgresql/ | Database | ✅ Planned |
| **MLflow** | test-mlops-stack | mlops-stack/mlflow/ | Experiment tracking | ✅ Planned |
| **KServe** | test-mlops-stack | mlops-stack/kserve/ | Model serving | ✅ Planned |
| **Inference API** | test-inference | inference-validation/ | Model inference | ✅ Planned |
```

### Updated Makefile Targets

Add to `tests/Makefile`:

```makefile
#
# Cloud Cluster Tests
#

test-cloud-vm:
 ./frameworks/test-cloud-vm-framework.sh e2e

test-kubernetes:
 ./frameworks/test-kubernetes-framework.sh e2e

test-mlops-stack:
 ./frameworks/test-mlops-stack-framework.sh e2e

test-inference:
 ./frameworks/test-inference-framework.sh e2e

test-cloud-all: test-cloud-vm test-kubernetes test-mlops-stack test-inference
 @echo "✓ All cloud cluster tests passed"

#
# Multi-Cluster Tests
#

test-multi-cluster-scenarios:
 ./frameworks/test-multi-cluster-framework.sh all-scenarios

test-workflow-transition:
 ./frameworks/test-multi-cluster-framework.sh workflow-transition

#
# Complete Test Suite (HPC + Cloud)
#

test-all-clusters: test-all test-cloud-all test-multi-cluster-scenarios
 @echo "✓ All HPC and Cloud tests passed"
```

---

## Implementation Tasks

### Task 1: Create Cloud VM Test Framework

**Priority**: CRITICAL  
**Duration**: 2-3 days  
**Dependencies**: CLOUD-0.2 (CLI implementation)

**Deliverables**:

- [ ] `test-cloud-vm-framework.sh` created
- [ ] `test-infra/configs/test-cloud-vm.yaml` created
- [ ] `suites/cloud-vm-lifecycle/` test suite created
- [ ] CLI command tests implemented
- [ ] Integration with existing test infrastructure

### Task 2: Create Kubernetes Test Framework

**Priority**: CRITICAL  
**Duration**: 3-4 days  
**Dependencies**: CLOUD-2.1 (Kubespray integration)

**Deliverables**:

- [ ] `test-kubernetes-framework.sh` created
- [ ] `test-infra/configs/test-kubernetes.yaml` created
- [ ] `suites/kubernetes-cluster/` test suite created
- [ ] Kubespray deployment validation
- [ ] GPU scheduling tests

### Task 3: Create MLOps Stack Test Framework

**Priority**: HIGH  
**Duration**: 4-5 days  
**Dependencies**: CLOUD-3.1-3.4 (MLOps stack deployment)

**Deliverables**:

- [ ] `test-mlops-stack-framework.sh` created
- [ ] `test-infra/configs/test-mlops-stack.yaml` created
- [ ] `suites/mlops-stack/` test suite created
  - [ ] `minio/` sub-suite
  - [ ] `postgresql/` sub-suite
  - [ ] `mlflow/` sub-suite
  - [ ] `kserve/` sub-suite
- [ ] End-to-end MLOps workflow test

### Task 4: Create Inference Test Framework

**Priority**: HIGH  
**Duration**: 4-5 days  
**Dependencies**: CLOUD-3.4 (KServe deployment), CLOUD-5.1 (Oumi integration)

**Deliverables**:

- [ ] `test-inference-framework.sh` created
- [ ] `test-infra/configs/test-inference.yaml` created
- [ ] `suites/inference-validation/` test suite created
- [ ] Performance benchmark tests
- [ ] Autoscaling validation tests

### Task 5: Create Multi-Cluster Test Utilities

**Priority**: MEDIUM  
**Duration**: 2-3 days  
**Dependencies**: Tasks 1-4

**Deliverables**:

- [ ] `test-infra/utils/multi-cluster-utils.sh` created
- [ ] `test-infra/utils/cloud-cli-utils.sh` created
- [ ] `test-infra/utils/mlops-test-utils.sh` created
- [ ] `suites/multi-cluster/` test suite created
- [ ] All 5 cluster scenarios tested

### Task 6: Update Existing Documentation

**Priority**: MEDIUM  
**Duration**: 1-2 days  
**Dependencies**: Tasks 1-5

**Deliverables**:

- [ ] `00-test-inventory.md` updated with cloud frameworks
- [ ] `02-component-matrix.md` updated with cloud components
- [ ] `03-framework-specifications.md` updated with cloud specs
- [ ] `06-test-dependencies-matrix.md` updated with cloud dependencies
- [ ] `tests/README.md` updated with cloud testing guide

### Task 7: Add Makefile Targets

**Priority**: MEDIUM  
**Duration**: 1 day  
**Dependencies**: Tasks 1-5

**Deliverables**:

- [ ] `tests/Makefile` updated with cloud test targets
- [ ] Multi-cluster test targets added
- [ ] Test execution documented

---

## Success Criteria

### Must-Have Criteria

- [ ] All 4 cloud test frameworks created and functional
- [ ] Cloud VM provisioning and CLI validated
- [ ] Kubernetes cluster deployment validated
- [ ] MLOps stack components validated
- [ ] Inference workflows validated
- [ ] Multi-cluster scenarios tested
- [ ] Documentation complete

### Performance Criteria

- [ ] Inference latency P95 < 500ms
- [ ] GPU utilization > 70% during inference
- [ ] Throughput > 50 req/s per GPU
- [ ] Cold start < 10s
- [ ] Autoscaling responds within 60s

### Quality Criteria

- [ ] Test coverage >80% for cloud components
- [ ] All tests pass consistently
- [ ] Clear error messages and logging
- [ ] Integration with CI/CD (future)

---

## Timeline

| Week | Tasks | Deliverables |
|------|-------|--------------|
| **Week 1** | Task 1, Task 2 (partial) | Cloud VM framework, K8s framework started |
| **Week 2** | Task 2 (complete), Task 3 (partial) | K8s framework complete, MLOps started |
| **Week 3** | Task 3 (complete), Task 4 (partial) | MLOps complete, Inference started |
| **Week 4** | Task 4 (complete), Task 5 | Inference complete, Multi-cluster utils |
| **Week 5** | Task 6, Task 7 | Documentation and Makefile updates |

**Total Duration**: 5 weeks (aligns with cloud cluster implementation timeline)

---

## Dependencies and Risks

### Dependencies

1. **Cloud cluster implementation** (CLOUD-0.1 through CLOUD-6.3)
   - Cannot test infrastructure that doesn't exist
   - Mitigation: Implement tests in parallel with features

2. **Existing test infrastructure**
   - Must integrate with existing HPC test frameworks
   - Mitigation: Follow established patterns from `framework-cli.sh` and `framework-orchestration.sh`

3. **Hardware requirements**
   - Need GPUs for inference testing
   - Mitigation: Tests should skip gracefully if GPU unavailable

### Risks

1. **Resource contention** between HPC and Cloud clusters
   - Risk: Running both clusters simultaneously may exceed host resources
   - Mitigation: Resource validation checks in multi-cluster utilities

2. **Test execution time**
   - Risk: Full test suite (HPC + Cloud) may take 4-6 hours
   - Mitigation: Modular test execution, parallel testing where possible

3. **Kubernetes complexity**
   - Risk: K8s validation more complex than SLURM
   - Mitigation: Leverage existing Kubernetes testing tools (kubectl, k8s Python client)

4. **External dependencies**
   - Risk: Tests depend on external images (Kubespray, KServe, MLflow)
   - Mitigation: Pin specific versions, cache images locally

---

## Conclusion

This document outlines comprehensive testing requirements for the new cloud cluster infrastructure. Implementation of
these 4 new test frameworks will provide complete validation coverage for the entire ML workflow from HPC training to
cloud inference.

**Next Steps**:

1. Review and approve this testing plan
2. Create GitHub issues for Tasks 1-7
3. Begin Task 1 implementation once CLOUD-0.2 is complete
4. Track progress and update this document as implementation proceeds

---

**Document Version**: 1.0  
**Status**: Planning  
**Last Updated**: 2025-10-28
