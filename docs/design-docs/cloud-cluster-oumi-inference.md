# Cloud Cluster for Oumi Inference - Implementation Plan

**Status:** Planning
**Created:** 2025-10-27
**Last Updated:** 2025-10-27
**Priority:** HIGH - Critical for ML workflow completion

## Executive Summary

This document outlines the implementation plan for deploying a Kubernetes-based cloud cluster that supports
**Oumi** model inference after training completion in the HPC cluster. The goal is to create a complete
ML workflow: train on HPC (SLURM + GPU) → deploy to cloud (Kubernetes + GPU) → serve models via inference API.

**Key Gap:** Current implementation has complete HPC cluster management but cloud cluster commands are stub
implementations. This plan identifies all missing components needed for production Oumi inference deployment.

---

## Current State Analysis

### ✅ What We Have (HPC Cluster - Complete)

From the project plan and codebase analysis:

- **HPC VM Management:** Complete (4,308+ lines)
  - LibVirt client, VM lifecycle manager, volume manager, network manager
  - PCIe passthrough for discrete GPU access
  - XML templating system for dynamic VM configuration
  - State management and persistence
  - Full CLI integration (start/stop/status/destroy)

- **SLURM Cluster:** Complete
  - Controller with database and accounting
  - Compute nodes with GPU GRES (Generic Resource Scheduling)
  - Cgroup isolation for job resource management
  - Container integration via Apptainer

- **Storage Infrastructure:** Complete
  - BeeGFS 8.1.0 parallel filesystem
  - VirtIO-FS host directory sharing
  - Container registry on BeeGFS storage

- **Container Workflow:** Complete
  - Docker image building
  - Apptainer SIF conversion
  - Registry deployment to BeeGFS
  - SLURM job submission with containers

- **GPU Support:** Complete
  - PCIe passthrough for discrete GPUs
  - NVIDIA driver installation
  - GPU monitoring (DCGM)
  - SLURM GRES configuration

### ❌ What's Missing (Cloud Cluster - Not Implemented)

From project-plan.md Phase 0.7.4 and code analysis:

1. **Cloud Cluster VM Management:** Not implemented
   - Cloud VM provisioning using existing VM management infrastructure
   - Cloud cluster start/stop/status/destroy operations (stubs in CLI)
   - Kubernetes-specific configuration and networking support

2. **Ansible Infrastructure for Kubernetes:** Minimal/skeleton
   - `ansible/roles/cloud-cluster-setup/` is placeholder
   - No Kubernetes cluster bootstrapping playbooks
   - No CNI (Calico/Flannel/Cilium) deployment automation
   - No GPU operator deployment for Kubernetes

3. **MLOps Stack (Phase 6):** Not implemented
   - MLflow for model registry and experiment tracking
   - MinIO for object storage
   - PostgreSQL for MLflow backend
   - KServe/Seldon for model serving

4. **Model Serving Infrastructure:** Not implemented
   - Inference API endpoints
   - Model versioning and deployment automation
   - Autoscaling for inference workloads
   - Monitoring and metrics collection

5. **HPC-to-Cloud Integration:** Not implemented
   - Model artifact transfer from HPC to cloud
   - Metadata synchronization between clusters
   - Unified monitoring across both clusters

---

## Proposed Cloud Cluster Configuration

Based on the existing cluster.yaml structure and Oumi requirements:

```yaml
version: "1.0"
metadata:
  name: "oumi-inference-cluster"
  description: "Kubernetes cluster optimized for Oumi model inference"

clusters:
  # HPC cluster for training (existing - complete)
  hpc:
    name: "training-cluster"
    # ... existing HPC configuration ...
    
  # Cloud cluster for inference (proposed - to be implemented)
  cloud:
    name: "inference-cluster"
    base_image_path: "build/packer/cloud-base/cloud-base/cloud-base.qcow2"
    
    network:
      subnet: "192.168.200.0/24"
      bridge: "virbr200"
      # DNS configuration for service discovery
      dns:
        enabled: true
        nameservers:
          - "8.8.8.8"
          - "8.8.4.4"
    
    # Kubernetes control plane node
    control_plane:
      cpu_cores: 6           # Increased for control plane workload
      memory_gb: 12          # Increased for etcd + API server
      disk_gb: 150           # Increased for container images
      ip_address: "192.168.200.10"
      
      # Control plane specific configuration
      kubernetes_role: "control-plane"
      high_availability: false  # Single control plane for development
      
      # Monitoring and observability
      monitoring:
        prometheus: true
        grafana: true
        node_exporter: true
    
    # Worker nodes configuration
    worker_nodes:
      # CPU workers for general workloads (MLOps services)
      cpu:
        - worker_type: "cpu"
          cpu_cores: 6
          memory_gb: 16
          disk_gb: 150
          ip: "192.168.200.11"
          
          kubernetes_role: "worker"
          node_labels:
            workload-type: "general"
            mlops-services: "true"
          node_taints: []
          
          # MLOps services will be scheduled here
          services:
            - mlflow
            - minio
            - postgresql
            - prometheus
            - grafana
      
      # GPU workers for inference workloads
      gpu:
        # Primary inference node (NVIDIA RTX A6000)
        - worker_type: "gpu"
          cpu_cores: 12
          memory_gb: 32
          disk_gb: 300
          ip: "192.168.200.12"
          
          kubernetes_role: "worker"
          node_labels:
            workload-type: "inference"
            gpu-type: "rtx-a6000"
            inference-ready: "true"
          node_taints:
            - key: "nvidia.com/gpu"
              value: "present"
              effect: "NoSchedule"
          
          # PCIe passthrough for discrete GPU access
          pcie_passthrough:
            enabled: true
            devices:
              # GPU device (primary function)
              - pci_address: "0000:65:00.0"
                device_type: "gpu"
                vendor_id: "10de"
                device_id: "2684"
                iommu_group: 3
              # Audio device (secondary function)
              - pci_address: "0000:65:00.1"
                device_type: "audio"
                vendor_id: "10de"
                device_id: "22bd"
                iommu_group: 3
        
        # Secondary inference node (NVIDIA Tesla T4)
        - worker_type: "gpu"
          cpu_cores: 12
          memory_gb: 32
          disk_gb: 300
          ip: "192.168.200.13"
          
          kubernetes_role: "worker"
          node_labels:
            workload-type: "inference"
            gpu-type: "tesla-t4"
            inference-ready: "true"
          node_taints:
            - key: "nvidia.com/gpu"
              value: "present"
              effect: "NoSchedule"
          
          pcie_passthrough:
            enabled: true
            devices:
              - pci_address: "0000:ca:00.0"
                device_type: "gpu"
                vendor_id: "10de"
                device_id: "1e36"
                iommu_group: 4
              - pci_address: "0000:ca:00.1"
                device_type: "audio"
                vendor_id: "10de"
                device_id: "22bd"
                iommu_group: 4
    
    # Kubernetes cluster configuration
    kubernetes_config:
      version: "1.28"          # Kubernetes version
      
      # Container runtime
      runtime: "containerd"
      runtime_version: "1.7"
      
      # Networking
      networking:
        cni: "calico"          # Calico for network policies
        cni_version: "3.27"
        pod_cidr: "10.244.0.0/16"
        service_cidr: "10.96.0.0/12"
        dns_domain: "cluster.local"
      
      # Ingress controller
      ingress:
        provider: "nginx"      # NGINX ingress controller
        enabled: true
        replicas: 2
        load_balancer_ip: "192.168.200.100"  # Virtual IP for ingress
      
      # Storage
      storage:
        default_class: "local-path"
        classes:
          - name: "local-path"
            provisioner: "rancher.io/local-path"
            reclaim_policy: "Delete"
          - name: "nfs"
            provisioner: "nfs.csi.k8s.io"
            reclaim_policy: "Retain"
            parameters:
              server: "192.168.100.10"  # HPC controller with BeeGFS
              share: "/mnt/beegfs/k8s-pv"
      
      # GPU operator
      gpu_operator:
        enabled: true
        version: "v23.9.0"
        driver_version: "535.129.03"
        
        # Device plugin configuration
        device_plugin:
          enabled: true
          mig_strategy: "none"    # Use full GPUs for inference
          time_slicing: false     # No time-slicing for inference
        
        # GPU Feature Discovery
        gfd:
          enabled: true
        
        # DCGM for monitoring
        dcgm:
          enabled: true
          port: 5555
    
    # MLOps stack configuration
    mlops:
      # MLflow for experiment tracking and model registry
      mlflow:
        enabled: true
        version: "2.9.0"
        
        # Backend database
        database:
          type: "postgresql"
          host: "postgresql-service"
          port: 5432
          database: "mlflow"
          username: "mlflow"
          password: "mlflow"  # Should be in secrets
        
        # Artifact storage
        artifact_store:
          type: "minio"
          bucket: "mlflow-artifacts"
          endpoint: "minio-service:9000"
        
        # Service configuration
        service:
          type: "ClusterIP"
          port: 5000
        
        # Ingress for external access
        ingress:
          enabled: true
          host: "mlflow.local"
          path: "/"
      
      # MinIO for object storage
      minio:
        enabled: true
        version: "RELEASE.2023-12-02T10-51-33Z"
        
        # Storage configuration
        storage:
          size: "100Gi"
          class: "local-path"
        
        # Service configuration
        service:
          api_port: 9000
          console_port: 9001
        
        # Access credentials
        credentials:
          root_user: "admin"
          root_password: "minio123"  # Should be in secrets
        
        # Buckets to create
        buckets:
          - name: "mlflow-artifacts"
          - name: "models"
          - name: "datasets"
      
      # PostgreSQL for MLflow backend
      postgresql:
        enabled: true
        version: "15.5"
        
        # Database configuration
        database:
          name: "mlflow"
          username: "mlflow"
          password: "mlflow"  # Should be in secrets
        
        # Storage
        storage:
          size: "20Gi"
          class: "local-path"
        
        # High availability (disabled for single-node)
        ha:
          enabled: false
      
      # Model serving infrastructure
      serving:
        # KServe for model serving
        kserve:
          enabled: true
          version: "0.11.0"
          
          # Inference services configuration
          inference_services:
            default_resources:
              requests:
                cpu: "1"
                memory: "4Gi"
                nvidia.com/gpu: "1"
              limits:
                cpu: "4"
                memory: "16Gi"
                nvidia.com/gpu: "1"
          
          # Autoscaling
          autoscaling:
            enabled: true
            min_replicas: 1
            max_replicas: 5
            target_concurrency: 10
        
        # Alternative: Seldon Core (if preferred)
        seldon:
          enabled: false
          version: "1.17.0"
    
    # Monitoring and observability
    monitoring:
      # Prometheus for metrics
      prometheus:
        enabled: true
        version: "2.48.0"
        
        # Storage
        storage:
          size: "50Gi"
          class: "local-path"
          retention: "30d"
        
        # Service monitors
        service_monitors:
          - kubernetes_api
          - kubernetes_nodes
          - nvidia_dcgm
          - mlflow
          - inference_services
      
      # Grafana for visualization
      grafana:
        enabled: true
        version: "10.2.0"
        
        # Dashboards
        dashboards:
          - kubernetes-cluster
          - gpu-monitoring
          - inference-metrics
          - mlflow-experiments
        
        # Data sources
        datasources:
          - name: "Prometheus"
            type: "prometheus"
            url: "http://prometheus-service:9090"
      
      # Logging (ELK stack or Loki)
      logging:
        enabled: true
        provider: "loki"       # Loki for lighter weight
        version: "2.9.0"
        
        # Storage
        storage:
          size: "30Gi"
          class: "local-path"
          retention: "7d"
```

---

## Missing Tasks - Implementation Breakdown

### Phase 0: Cloud Cluster Foundation (Weeks 1-2)

#### CLOUD-0.1: Extend VM Management for Cloud Cluster

**Duration:** 3-4 days
**Priority:** CRITICAL
**Dependencies:** None (reuse existing HPC VM management)

**Objective:** Extend the existing VM management infrastructure to support cloud cluster provisioning.

**Deliverables:**

- [ ] Extend `python/ai_how/src/ai_how/vm/` to support cloud cluster VMs
- [ ] Update `ClusterStateManager` to track both HPC and cloud cluster state
- [ ] Add cloud cluster validation logic to configuration validator
- [ ] Create cloud-specific libvirt XML templates for Kubernetes nodes

**Implementation Steps:**

1. Create `cloud_vm_manager.py` extending existing `VMManager` class
2. Add cloud cluster state tracking in `output/state.json`
3. Update XML templates for cloud VMs (control-plane, workers)
4. Add cloud cluster network configuration

**Validation:**

```bash
# Should provision cloud cluster VMs
ai-how cloud start config/cloud-cluster.yaml

# Should show cloud cluster status
ai-how cloud status config/cloud-cluster.yaml

# Should gracefully stop cloud cluster
ai-how cloud stop config/cloud-cluster.yaml

# Should destroy cloud cluster VMs
ai-how cloud destroy config/cloud-cluster.yaml
```

---

#### CLOUD-0.2: Implement Cloud Cluster CLI Commands

**Duration:** 2-3 days
**Priority:** CRITICAL
**Dependencies:** CLOUD-0.1

**Objective:** Replace stub implementations in `python/ai_how/src/ai_how/cli.py` with functional cloud cluster commands.

**Deliverables:**

- [ ] Implement `cloud start` command
- [ ] Implement `cloud stop` command
- [ ] Implement `cloud status` command
- [ ] Implement `cloud destroy` command
- [ ] Add comprehensive error handling and rollback

**Files to Modify:**

- `python/ai_how/src/ai_how/cli.py` (lines 593-610)
- `python/ai_how/docs/cli-reference.md` (update documentation)

**Implementation Pattern:**

```python
@cloud.command()
def start(
    ctx: typer.Context,
    config: Annotated[Path, typer.Argument(...)],
) -> None:
    """Start the cloud cluster with full Kubernetes deployment."""
    state_path = ctx.obj["state"]
    logger = logging.getLogger(__name__)
    
    console.print("Starting cloud cluster...")
    
    try:
        # Load and render configuration
        config_data = load_and_render_config(config)
        
        # Validate cloud cluster configuration
        validator = CloudClusterValidator(config_data)
        validator.validate()
        
        # Provision VMs using cloud VM manager
        cloud_manager = CloudVMManager(config_data, state_path)
        cloud_manager.start_cluster()
        
        # Deploy Kubernetes via Ansible
        ansible_runner = AnsibleRunner(config_data, state_path)
        ansible_runner.deploy_kubernetes_cluster()
        
        console.print("[green]Cloud cluster started successfully[/green]")
        
    except Exception as e:
        logger.error(f"Failed to start cloud cluster: {e}")
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(code=1) from e
```

---

### Phase 1: Packer Images for Cloud Cluster (Weeks 2-3)

#### CLOUD-1.1: Create Cloud Base Packer Image

**Duration:** 2-3 days
**Priority:** HIGH
**Dependencies:** None

**Objective:** Build a Debian-based cloud base image optimized for Kubernetes workloads.

**Deliverables:**

- [ ] Create `packer/cloud-base/` directory structure
- [ ] Create `cloud-base.pkr.hcl` Packer template
- [ ] Create `setup-cloud-base.sh` provisioning script
- [ ] Create `cloud-base-user-data.yml` cloud-init configuration
- [ ] Integrate with CMake build system

**Directory Structure:**

```text
packer/cloud-base/
├── README.md
├── cloud-base.pkr.hcl
├── setup-cloud-base.sh
├── cloud-base-user-data.yml
└── ansible/
    └── cloud-base-packages.yml
```

**Base Image Requirements:**

- Debian 13 (Trixie) with kernel 6.12+
- Containerd runtime (1.7+)
- Kubernetes packages (kubeadm, kubelet, kubectl - uninitialized)
- CNI plugins
- NVIDIA container toolkit (for GPU workers)
- Cloud-init for VM initialization
- Basic monitoring tools (node-exporter)

**CMake Integration:**

```cmake
# Add to CMakeLists.txt
add_custom_target(build-cloud-base-image
    COMMAND ${PACKER_EXECUTABLE} build -force cloud-base.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/packer/cloud-base
    COMMENT "Building cloud base image with Packer"
)
```

---

#### CLOUD-1.2: Create Specialized Cloud Images

**Duration:** 2 days
**Priority:** MEDIUM
**Dependencies:** CLOUD-1.1

**Objective:** Create specialized images for control plane and worker nodes (optional - can use base image).

**Deliverables:**

- [ ] `cloud-control-plane` image (optional - additional control plane tools)
- [ ] `cloud-gpu-worker` image (with NVIDIA drivers pre-installed)

**Note:** This task is optional. We can use the base image for all nodes and configure via Ansible.

---

### Phase 2: Kubernetes Deployment with Kubespray (Weeks 3-5)

**Deployment Tool:** [Kubespray v2.29.0+](https://github.com/kubernetes-sigs/kubespray)

Kubespray is a production-ready Kubernetes deployment tool maintained by Kubernetes SIG Cluster Lifecycle. It
provides battle-tested Ansible playbooks for deploying highly available Kubernetes clusters. Key benefits:

- **Production-Ready:** CNCF approved, 17.8k GitHub stars, 1,170 contributors
- **Ansible-Native:** Seamlessly integrates with our existing infrastructure
- **Comprehensive:** Handles OS prep, container runtime, K8s cluster, and add-ons
- **Well-Tested:** Continuous integration tests on multiple platforms
- **Supports Our Stack:** Debian Trixie, Containerd, Calico CNI, GPU nodes

#### CLOUD-2.1: Integrate and Configure Kubespray

**Duration:** 3-4 days
**Priority:** HIGH
**Dependencies:** CLOUD-0.2, CLOUD-1.1

**Objective:** Integrate Kubespray into the project and configure it for our cloud cluster topology.

**Deliverables:**

- [ ] Install Kubespray via CMake third-party dependency system
- [ ] Create cloud cluster inventory for Kubespray
- [ ] Configure Kubespray variables for our requirements
- [ ] Create wrapper playbook for cloud cluster deployment
- [ ] Integration with `ai-how cloud start` command

**Directory Structure:**

```text
3rd-party/
└── kubespray/                              # Kubespray CMake integration
    ├── CMakeLists.txt                      # CMake configuration
    └── README.md                           # Documentation

build/3rd-party/kubespray/
└── kubespray-src/                          # Cloned Kubespray (via CMake)
    ├── inventory/
    ├── roles/
    └── cluster.yml

ansible/
├── inventories/
│   └── cloud-cluster/                      # Our cloud cluster inventory
│       ├── inventory.ini                   # Generated from cluster.yaml
│       └── group_vars/
│           ├── all/
│           │   ├── all.yml                # Global Kubespray settings
│           │   └── cloud-cluster.yml       # Our custom settings
│           └── k8s_cluster/
│               ├── k8s-cluster.yml        # Kubernetes settings
│               ├── k8s-net-calico.yml     # Calico CNI settings
│               └── addons.yml             # Enable ingress, metrics-server
└── playbooks/
    └── deploy-cloud-cluster.yml            # Wrapper playbook
```

**Kubespray Installation:**

```bash
# Install Kubespray as a third-party dependency
cmake --build build --target install-kubespray

# Kubespray is cloned to: build/3rd-party/kubespray/kubespray-src/
# This follows the same pattern as BeeGFS and SLURM packages
```

**Kubespray Configuration (`group_vars/all/cloud-cluster.yml`):**

```yaml
# Container Runtime
container_manager: containerd
containerd_version: "1.7.23"

# Kubernetes Version
kube_version: v1.28.0

# Network Plugin
kube_network_plugin: calico
calico_version: "v3.30.3"

# Service/Pod Network
kube_service_addresses: 10.96.0.0/12
kube_pods_subnet: 10.244.0.0/16

# DNS
dns_mode: coredns
enable_nodelocaldns: true

# Ingress
ingress_nginx_enabled: true
ingress_nginx_host_network: false

# Metrics Server
metrics_server_enabled: true

# Node Features
node_labels:
  gpu-worker-1:
    workload-type: "inference"
    gpu-type: "rtx-a6000"
    inference-ready: "true"
  gpu-worker-2:
    workload-type: "inference"
    gpu-type: "tesla-t4"
    inference-ready: "true"

node_taints:
  gpu-worker-1: ['nvidia.com/gpu=present:NoSchedule']
  gpu-worker-2: ['nvidia.com/gpu=present:NoSchedule']
```

**Inventory Generation:**
The `ai-how cloud start` command will generate the Kubespray inventory from `cluster.yaml`:

```ini
# Generated: ansible/inventories/cloud-cluster/inventory.ini
[all]
control-plane ansible_host=192.168.200.10 ip=192.168.200.10
cpu-worker    ansible_host=192.168.200.11 ip=192.168.200.11
gpu-worker-1  ansible_host=192.168.200.12 ip=192.168.200.12
gpu-worker-2  ansible_host=192.168.200.13 ip=192.168.200.13

[kube_control_plane]
control-plane

[etcd]
control-plane

[kube_node]
cpu-worker
gpu-worker-1
gpu-worker-2

[calico_rr]

[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr
```

**Wrapper Playbook (`ansible/playbooks/deploy-cloud-cluster.yml`):**

```yaml
---
- name: Deploy Cloud Cluster with Kubespray
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Run Kubespray cluster deployment
      ansible.builtin.import_playbook: ../../build/3rd-party/kubespray/kubespray-src/cluster.yml
      vars:
        ansible_python_interpreter: /usr/bin/python3

- name: Post-deployment configuration
  hosts: kube_node
  tasks:
    - name: Apply GPU node labels
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: v1
          kind: Node
          metadata:
            name: "{{ inventory_hostname }}"
            labels: "{{ node_labels[inventory_hostname] | default({}) }}"
      when: "'gpu-worker' in inventory_hostname"
      delegate_to: control-plane
```

**Note:** Kubespray is installed via `cmake --build build --target install-kubespray` and is available at
`build/3rd-party/kubespray/kubespray-src/`. This follows the same third-party dependency pattern as BeeGFS and
SLURM.

**Execution Flow:**

```bash
# From ai-how CLI:
ai-how cloud start config/cloud-cluster.yaml

# Internally executes:
1. Generate Kubespray inventory from cluster.yaml
2. Validate inventory and SSH connectivity
3. Run Kubespray deployment:
   ansible-playbook -i ansible/inventories/cloud-cluster/inventory.ini \
     ansible/playbooks/deploy-cloud-cluster.yml
4. Wait for cluster ready state
5. Fetch kubeconfig from control plane
6. Validate cluster health (kubectl get nodes)
```

**Validation:**

```bash
# After deployment completes
kubectl get nodes
# NAME              STATUS   ROLES           AGE   VERSION
# control-plane     Ready    control-plane   5m    v1.28.0
# cpu-worker        Ready    <none>          4m    v1.28.0
# gpu-worker-1      Ready    <none>          4m    v1.28.0
# gpu-worker-2      Ready    <none>          4m    v1.28.0

kubectl get pods -n kube-system
# Should show: calico, coredns, metrics-server, ingress-nginx
```

---

#### CLOUD-2.2: Deploy NVIDIA GPU Operator

**Duration:** 2-3 days
**Priority:** HIGH
**Dependencies:** CLOUD-2.1

**Objective:** Deploy NVIDIA GPU Operator on GPU worker nodes after Kubespray completes.

**Note:** Kubespray deploys the base Kubernetes cluster with NGINX Ingress and metrics-server. The GPU Operator is
deployed separately as a post-installation step.

**Deliverables:**

- [ ] `ansible/roles/nvidia-gpu-operator/` Ansible role
- [ ] Helm-based GPU operator installation
- [ ] Device plugin configuration for full GPU access
- [ ] GPU feature discovery verification
- [ ] DCGM exporter deployment for monitoring
- [ ] Validation tests for GPU scheduling

**Role Structure:**

```text
ansible/roles/nvidia-gpu-operator/
├── README.md
├── defaults/main.yml
├── tasks/
│   ├── main.yml
│   ├── install-helm.yml                    # Ensure Helm is available
│   ├── add-nvidia-helm-repo.yml            # Add NVIDIA Helm repo
│   ├── install-gpu-operator.yml            # Deploy GPU Operator
│   ├── wait-for-ready.yml                  # Wait for operator to be ready
│   └── validation.yml                      # Validate GPU resources
└── templates/
    └── gpu-operator-values.yaml.j2         # Helm values template
```

**GPU Operator Helm Values (`gpu-operator-values.yaml.j2`):**

```yaml
# NVIDIA GPU Operator Helm Values
operator:
  defaultRuntime: containerd

driver:
  enabled: true
  version: "535.129.03"
  repository: nvcr.io/nvidia

toolkit:
  enabled: true
  version: v1.14.3

devicePlugin:
  enabled: true
  version: v0.14.3
  config:
    name: time-slicing-config-all
    default: "any"
  
dcgm:
  enabled: true
  version: 3.1.8-3.1.5-ubuntu22.04

dcgmExporter:
  enabled: true
  version: 3.1.8-3.1.5-ubuntu22.04
  serviceMonitor:
    enabled: true

gfd:
  enabled: true
  version: v0.8.2

migManager:
  enabled: false  # Not using MIG for inference

node-feature-discovery:
  enableNodeFeatureApi: true
```

**Deployment Tasks:**

```yaml
# ansible/roles/nvidia-gpu-operator/tasks/install-gpu-operator.yml
---
- name: Add NVIDIA Helm repository
  kubernetes.core.helm_repository:
    name: nvidia
    repo_url: https://helm.ngc.nvidia.com/nvidia

- name: Deploy NVIDIA GPU Operator
  kubernetes.core.helm:
    name: gpu-operator
    chart_ref: nvidia/gpu-operator
    release_namespace: gpu-operator-resources
    create_namespace: true
    values: "{{ lookup('template', 'gpu-operator-values.yaml.j2') | from_yaml }}"
    wait: true
    wait_timeout: 10m

- name: Wait for GPU Operator to be ready
  kubernetes.core.k8s_info:
    kind: Pod
    namespace: gpu-operator-resources
    label_selectors:
      - app=nvidia-device-plugin-daemonset
  register: gpu_pods
  until: gpu_pods.resources | selectattr('status.phase', 'equalto', 'Running') | list | length > 0
  retries: 30
  delay: 10
```

**Validation:**

```bash
# Check GPU operator deployment
kubectl get pods -n gpu-operator-resources

# Verify GPU resources are advertised
kubectl describe node gpu-worker-1 | grep nvidia.com/gpu
# Should show: nvidia.com/gpu: 1

# Test GPU scheduling
kubectl run gpu-test --rm -it --restart=Never \
  --image=nvidia/cuda:12.2.0-base-ubuntu22.04 \
  --limits=nvidia.com/gpu=1 \
  -- nvidia-smi

# Should display GPU information
```

---

### Phase 3: MLOps Stack Deployment (Weeks 5-7)

**Note:** All MLOps components are deployed as Kubernetes resources on the cluster established by Kubespray.
These can be deployed via Ansible playbooks that use `kubernetes.core` modules or Helm charts.

#### CLOUD-3.1: Deploy MinIO Object Storage

**Duration:** 2-3 days
**Priority:** HIGH
**Dependencies:** CLOUD-2.1 (Kubernetes cluster must be running)

**Objective:** Deploy MinIO for model artifact and dataset storage.

**Deliverables:**

- [ ] `ansible/roles/minio/` directory structure
- [ ] MinIO deployment with persistent storage
- [ ] Bucket creation automation
- [ ] Access policy configuration
- [ ] Integration with MLflow

**Role Structure:**

```text
ansible/roles/minio/
├── README.md
├── defaults/main.yml
├── vars/main.yml
├── tasks/
│   ├── main.yml
│   ├── deploy-minio.yml
│   ├── create-buckets.yml
│   ├── configure-policies.yml
│   └── validation.yml
└── templates/
    ├── minio-deployment.yaml.j2
    ├── minio-service.yaml.j2
    └── minio-ingress.yaml.j2
```

---

#### CLOUD-3.2: Deploy PostgreSQL Database

**Duration:** 2 days
**Priority:** HIGH
**Dependencies:** CLOUD-2.1 (Kubernetes cluster must be running)

**Objective:** Deploy PostgreSQL for MLflow metadata storage.

**Deliverables:**

- [ ] `ansible/roles/postgresql/` directory structure
- [ ] PostgreSQL StatefulSet deployment
- [ ] Database initialization for MLflow
- [ ] Backup configuration

---

#### CLOUD-3.3: Deploy MLflow Tracking Server

**Duration:** 3-4 days
**Priority:** HIGH
**Dependencies:** CLOUD-3.1, CLOUD-3.2 (MinIO and PostgreSQL)

**Objective:** Deploy MLflow for experiment tracking and model registry.

**Deliverables:**

- [ ] `ansible/roles/mlflow/` directory structure
- [ ] MLflow server deployment
- [ ] Backend database configuration (PostgreSQL)
- [ ] Artifact store configuration (MinIO)
- [ ] Ingress for external access
- [ ] Integration validation

**Key Features:**

- Model registry for versioned models
- Experiment tracking from HPC cluster
- Model promotion workflow (staging → production)
- REST API for model serving integration

---

#### CLOUD-3.4: Deploy KServe Model Serving

**Duration:** 4-5 days
**Priority:** HIGH
**Dependencies:** CLOUD-2.2, CLOUD-3.3 (GPU Operator and MLflow)

**Objective:** Deploy KServe for scalable model inference.

**Deliverables:**

- [ ] `ansible/roles/kserve/` directory structure
- [ ] KServe installation (with Knative Serving)
- [ ] InferenceService CRD configuration
- [ ] Autoscaling policies
- [ ] GPU resource allocation
- [ ] Model deployment automation from MLflow

**Role Structure:**

```text
ansible/roles/kserve/
├── README.md
├── defaults/main.yml
├── vars/main.yml
├── tasks/
│   ├── main.yml
│   ├── install-knative.yml
│   ├── install-kserve.yml
│   ├── configure-autoscaling.yml
│   ├── setup-gpu-serving.yml
│   └── validation.yml
└── templates/
    ├── kserve-values.yaml.j2
    ├── inference-service-example.yaml.j2
    └── autoscaling-policy.yaml.j2
```

---

### Phase 4: Monitoring and Observability (Weeks 7-8)

#### CLOUD-4.1: Deploy Prometheus Stack

**Duration:** 3 days
**Priority:** HIGH
**Dependencies:** CLOUD-2.1 (Kubernetes cluster must be running)

**Objective:** Deploy Prometheus for metrics collection across cloud cluster.

**Deliverables:**

- [ ] `ansible/roles/prometheus-stack/` directory structure
- [ ] Prometheus operator deployment
- [ ] ServiceMonitor CRDs for automatic discovery
- [ ] GPU metrics collection (DCGM from GPU Operator)
- [ ] Inference metrics collection (KServe)
- [ ] Alert rules configuration

---

#### CLOUD-4.2: Deploy Grafana Dashboards

**Duration:** 2 days
**Priority:** MEDIUM
**Dependencies:** CLOUD-4.1

**Objective:** Deploy Grafana with pre-configured dashboards for cloud cluster.

**Deliverables:**

- [ ] Grafana deployment with Prometheus data source
- [ ] Kubernetes cluster dashboard
- [ ] GPU monitoring dashboard
- [ ] Inference metrics dashboard
- [ ] MLflow experiments dashboard

---

### Phase 5: Oumi Integration (Weeks 8-9)

#### CLOUD-5.1: Oumi Configuration and Testing

**Duration:** 3-4 days
**Priority:** CRITICAL
**Dependencies:** CLOUD-3.4 (KServe must be deployed)

**Objective:** Configure Oumi to use the cloud cluster for inference and validate end-to-end workflow.

**Deliverables:**

- [ ] Oumi configuration for custom cluster
- [ ] Job launcher configuration
- [ ] Integration with MLflow model registry
- [ ] End-to-end training → inference workflow validation

**Oumi Configuration:**

Create `oumi_config.yaml`:

```yaml
# Oumi configuration for custom Kubernetes cluster
clusters:
  - name: "local-k8s-inference"
    type: "kubernetes"
    
    # Kubernetes API endpoint
    api_server: "https://192.168.200.10:6443"
    kubeconfig: "/path/to/kubeconfig"
    
    # GPU configuration
    gpu:
      enabled: true
      resource_key: "nvidia.com/gpu"
      
      # GPU types available
      gpu_types:
        - name: "rtx-a6000"
          memory_gb: 48
          node_selector:
            gpu-type: "rtx-a6000"
        - name: "tesla-t4"
          memory_gb: 16
          node_selector:
            gpu-type: "tesla-t4"
    
    # Model serving configuration
    serving:
      backend: "kserve"
      endpoint: "http://192.168.200.100"  # Ingress endpoint
      
      # Default resources for inference
      resources:
        requests:
          cpu: "2"
          memory: "8Gi"
          nvidia.com/gpu: "1"
        limits:
          cpu: "4"
          memory: "16Gi"
          nvidia.com/gpu: "1"
    
    # MLflow integration
    mlflow:
      tracking_uri: "http://mlflow.local"
      registry_uri: "http://mlflow.local"
      artifact_uri: "s3://mlflow-artifacts"
```

**Validation Workflow:**

**Step 1: Train model on HPC cluster**

```bash
# SSH to HPC controller
ssh admin@192.168.100.10

# Submit training job via SLURM
sbatch --gres=gpu:1 train_model.sh

# Track experiment in MLflow
mlflow experiments list
mlflow runs list --experiment-id 1
```

**Step 2: Register model in MLflow**

```bash
# From training script or manually
mlflow.register_model(
    model_uri="runs:/<run_id>/model",
    name="oumi-llama-7b"
)

# Promote to staging
mlflow.set_registered_model_alias(
    name="oumi-llama-7b",
    alias="staging",
    version="1"
)
```

**Step 3: Deploy model to cloud cluster for inference**

```bash
# Create InferenceService CRD
kubectl apply -f - <<EOF
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: oumi-llama-7b
  namespace: default
spec:
  predictor:
    model:
      modelFormat:
        name: mlflow
      storageUri: "s3://mlflow-artifacts/models/oumi-llama-7b/1"
      resources:
        requests:
          nvidia.com/gpu: "1"
          memory: "16Gi"
        limits:
          nvidia.com/gpu: "1"
          memory: "32Gi"
      env:
        - name: MLFLOW_TRACKING_URI
          value: "http://mlflow-service:5000"
EOF

# Wait for inference service to be ready
kubectl wait --for=condition=Ready inferenceservice/oumi-llama-7b --timeout=300s

# Get inference endpoint
kubectl get inferenceservice oumi-llama-7b -o jsonpath='{.status.url}'
```

**Step 4: Test inference API**

```bash
# Send inference request
curl -X POST http://oumi-llama-7b.default.192.168.200.100.nip.io/v1/models/oumi-llama-7b:predict \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": {
      "prompt": "Explain quantum computing in simple terms:",
      "max_tokens": 100,
      "temperature": 0.7
    }
  }'
```

**Step 5: Monitor inference metrics**

```bash
# Check GPU utilization on inference nodes
kubectl exec -it <gpu-worker-pod> -- nvidia-smi

# Check inference latency in Grafana
# Navigate to http://grafana.local/d/inference-metrics

# Check MLflow for logged predictions (if enabled)
mlflow experiments list
```

---

#### CLOUD-5.2: Create End-to-End ML Workflow Documentation

**Duration:** 2 days
**Priority:** HIGH
**Dependencies:** CLOUD-5.1

**Objective:** Document complete ML workflow from training to inference.

**Deliverables:**

- [ ] `docs/tutorials/08-oumi-training-to-inference.md`
- [ ] `docs/architecture/ml-workflow.md`
- [ ] `docs/operations/model-deployment.md`
- [ ] Example Oumi training scripts
- [ ] Example inference deployment manifests

---

### Phase 6: Integration and Optimization (Week 10)

#### CLOUD-6.1: HPC-to-Cloud Model Transfer Automation

**Duration:** 3 days
**Priority:** MEDIUM
**Dependencies:** CLOUD-5.1

**Objective:** Automate model artifact transfer from HPC to cloud cluster.

**Deliverables:**

- [ ] Script to sync models from BeeGFS to MinIO
- [ ] Automated MLflow model registration from HPC
- [ ] Metadata synchronization
- [ ] Transfer validation and checksums

**Implementation:**

Create `scripts/sync-models-to-cloud.sh`:

```bash
#!/bin/bash
# Sync trained models from HPC BeeGFS to Cloud MinIO

HPC_BEEGFS="/mnt/beegfs/models"
CLOUD_MINIO="s3://models"
MLFLOW_TRACKING_URI="http://mlflow.local"

# Sync model artifacts
mc mirror --overwrite \
    "${HPC_BEEGFS}/trained/" \
    "${CLOUD_MINIO}/trained/"

# Register models in MLflow
for model_dir in "${HPC_BEEGFS}/trained/"*; do
    model_name=$(basename "$model_dir")
    mlflow models create-model-version \
        --name "$model_name" \
        --source "s3://models/trained/$model_name"
done
```

---

#### CLOUD-6.2: Unified Monitoring Across Clusters

**Duration:** 2-3 days
**Priority:** MEDIUM
**Dependencies:** CLOUD-4.1, CLOUD-4.2

**Objective:** Create unified monitoring view for both HPC and cloud clusters.

**Deliverables:**

- [ ] Federated Prometheus configuration
- [ ] Cross-cluster Grafana dashboards
- [ ] Unified alerting rules
- [ ] Cluster comparison metrics

---

#### CLOUD-6.3: Performance Testing and Optimization

**Duration:** 3-4 days
**Priority:** HIGH
**Dependencies:** CLOUD-5.1

**Objective:** Benchmark inference performance and optimize for production.

**Deliverables:**

- [ ] Inference latency benchmarks (P50, P95, P99)
- [ ] Throughput testing (requests per second)
- [ ] GPU utilization optimization
- [ ] Autoscaling validation
- [ ] Cost-performance analysis

**Benchmark Metrics:**

- **Cold start latency:** Time to start first inference after deployment
- **Warm inference latency:** Time for subsequent inferences
- **Throughput:** Concurrent requests supported
- **GPU utilization:** % GPU memory and compute used
- **Autoscaling behavior:** Time to scale up/down

---

### Phase 7: Testing and Validation (Week 11)

#### CLOUD-7.1: Create Cloud Cluster Test Framework

**Duration:** 4-5 days
**Priority:** HIGH
**Dependencies:** CLOUD-0.2

**Objective:** Create comprehensive test framework for cloud cluster validation.

**Deliverables:**

- [ ] `tests/test-cloud-framework.sh` (unified test framework)
- [ ] `tests/suites/cloud-cluster-deployment/` test suite
- [ ] `tests/suites/kubernetes-cluster/` test suite
- [ ] `tests/suites/mlops-stack/` test suite
- [ ] `tests/suites/inference-validation/` test suite

**Test Framework Structure:**

```text
tests/
├── test-cloud-framework.sh                     # Unified test framework
├── test-configs/
│   ├── cloud-cluster-test-config.yaml
│   ├── kubernetes-test-config.yaml
│   └── inference-test-config.yaml
└── suites/
    ├── cloud-cluster-deployment/
    │   ├── test-vm-provisioning.sh
    │   ├── test-network-configuration.sh
    │   └── test-cluster-lifecycle.sh
    ├── kubernetes-cluster/
    │   ├── test-control-plane.sh
    │   ├── test-worker-nodes.sh
    │   ├── test-cni-networking.sh
    │   └── test-gpu-operator.sh
    ├── mlops-stack/
    │   ├── test-minio.sh
    │   ├── test-postgresql.sh
    │   ├── test-mlflow.sh
    │   └── test-kserve.sh
    └── inference-validation/
        ├── test-model-deployment.sh
        ├── test-inference-api.sh
        ├── test-autoscaling.sh
        └── test-monitoring.sh
```

**Test Execution:**

```bash
# Run all cloud cluster tests
cd tests
./test-cloud-framework.sh e2e

# Run specific test suites
./test-cloud-framework.sh test-suite cloud-cluster-deployment
./test-cloud-framework.sh test-suite kubernetes-cluster
./test-cloud-framework.sh test-suite mlops-stack
./test-cloud-framework.sh test-suite inference-validation

# Makefile targets
make test-cloud-all
make test-cloud-deployment
make test-cloud-kubernetes
make test-cloud-mlops
make test-cloud-inference
```

---

## Resource Allocation Summary

### Development Hardware Requirements

**Minimum:**

- **CPU:** 16 cores (host passthrough to VMs)
- **RAM:** 64 GB (allocated across control plane + 3 workers)
- **Disk:** 800 GB (VMs + container images + models)
- **GPUs:** 2x NVIDIA GPUs for inference workloads

**Optimal:**

- **CPU:** 24+ cores
- **RAM:** 128 GB
- **Disk:** 1.5 TB (NVMe SSD preferred)
- **GPUs:** 2-4x NVIDIA GPUs (RTX A6000, Tesla T4, or similar)

### Cloud Cluster Resource Allocation

**Total VM Resources:**

- **Control Plane:** 6 CPU cores, 12 GB RAM, 150 GB disk
- **CPU Worker:** 6 CPU cores, 16 GB RAM, 150 GB disk
- **GPU Worker 1:** 12 CPU cores, 32 GB RAM, 300 GB disk + 1x GPU
- **GPU Worker 2:** 12 CPU cores, 32 GB RAM, 300 GB disk + 1x GPU

**Total:** 36 CPU cores, 92 GB RAM, 900 GB disk, 2x GPUs

**Note:** This assumes HPC and Cloud clusters run on separate hardware or at different times due to resource constraints.

---

## Implementation Timeline

### Week 1-2: Foundation

- CLOUD-0.1: VM Management Extension
- CLOUD-0.2: CLI Commands Implementation

### Week 2-3: Packer Images

- CLOUD-1.1: Cloud Base Image
- CLOUD-1.2: Specialized Images (optional)

### Week 3-5: Kubernetes Deployment

- CLOUD-2.1: Kubespray Integration and Configuration
- CLOUD-2.2: GPU Operator Deployment

### Week 5-7: MLOps Stack

- CLOUD-3.1: MinIO Deployment
- CLOUD-3.2: PostgreSQL Deployment
- CLOUD-3.3: MLflow Deployment
- CLOUD-3.4: KServe Deployment

### Week 7-8: Monitoring

- CLOUD-4.1: Prometheus Stack
- CLOUD-4.2: Grafana Dashboards

### Week 8-9: Oumi Integration

- CLOUD-5.1: Oumi Configuration
- CLOUD-5.2: Documentation

### Week 10: Integration

- CLOUD-6.1: Model Transfer Automation
- CLOUD-6.2: Unified Monitoring
- CLOUD-6.3: Performance Testing

### Week 11: Testing

- CLOUD-7.1: Test Framework

**Total Duration:** 11 weeks for complete implementation
**Total Tasks:** 18 tasks (CLOUD-0.1 to CLOUD-7.1)

---

## Success Criteria

### Technical Milestones

- [ ] Cloud cluster VMs provision successfully via `ai-how cloud start`
- [ ] Kubernetes control plane boots and is accessible
- [ ] GPU workers join cluster with GPU resources visible
- [ ] MLflow server accessible and can register models
- [ ] MinIO stores model artifacts from HPC cluster
- [ ] KServe deploys inference services with GPU allocation
- [ ] Inference API responds to test requests with <500ms latency
- [ ] Autoscaling increases replicas under load
- [ ] Monitoring dashboards show GPU utilization and inference metrics
- [ ] End-to-end workflow: HPC training → MLflow registry → Cloud inference

### Operational Milestones

- [ ] Complete documentation for all components
- [ ] Automated testing with >80% coverage
- [ ] Disaster recovery procedures tested
- [ ] Performance benchmarks meet targets
- [ ] Security policies enforced (RBAC, network policies)

---

## Risk Mitigation

### High Risk: Resource Constraints

**Risk:** Insufficient hardware resources to run both HPC and cloud clusters simultaneously.

**Mitigation:**

- Implement resource capacity checks in CLI
- Add `--force` override with warnings
- Document alternative: run clusters sequentially (train on HPC, shutdown, deploy to cloud)
- Create resource allocation planning tool

### High Risk: GPU Passthrough Conflicts

**Risk:** Same GPUs cannot be passed through to both HPC and cloud VMs simultaneously.

**Mitigation:**

- Add PCIe device conflict detection in configuration validator
- Implement GPU inventory tracking in state.json
- Provide clear error messages about GPU allocation conflicts
- Document GPU allocation strategy

### Medium Risk: Kubernetes Complexity

**Risk:** Kubernetes cluster setup is complex and error-prone.

**Mitigation:**

- Use well-tested Ansible roles (kubeadm, GPU operator)
- Implement comprehensive validation at each step
- Create rollback procedures for failed deployments
- Provide detailed troubleshooting documentation

### Medium Risk: MLOps Stack Stability

**Risk:** MLflow, MinIO, PostgreSQL may be unstable in development environment.

**Mitigation:**

- Use stable versions of all components
- Implement health checks and automatic restarts
- Add backup and restore procedures
- Document common failure modes and fixes

---

## Next Steps

1. **Review and Approve:** Get stakeholder approval for this implementation plan
2. **Create Task Tracking:** Create GitHub issues/project board for all tasks
3. **Start Foundation:** Begin with CLOUD-0.1 and CLOUD-0.2
4. **Parallel Development:** Once VM management is working, split into:
   - Team A: Packer images and Ansible roles
   - Team B: Test framework development
5. **Incremental Testing:** Test each component as it's built
6. **Documentation:** Update docs alongside implementation

---

## References

- **Project Plan:** `docs/design-docs/project-plan.md`
- **HPC Task List:** `docs/implementation-plans/task-lists/hpc-slurm/`
- **Active Workstreams:** `docs/implementation-plans/task-lists/active-workstreams.md`
- **Cluster Configuration:** `config/example-multi-gpu-clusters.yaml`
- **Oumi Documentation:** https://github.com/oumi-ai/oumi
- **KServe Documentation:** https://kserve.github.io/website/
- **MLflow Documentation:** https://mlflow.org/docs/latest/index.html

---

**Document Version:** 1.0
**Status:** Planning - Pending Review
**Last Updated:** 2025-10-27
**Author:** AI Assistant
