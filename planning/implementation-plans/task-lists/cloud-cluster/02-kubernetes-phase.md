# Phase 2: Kubernetes Deployment with Kubespray

**Duration:** 2 weeks
**Tasks:** CLOUD-2.1, CLOUD-2.2
**Dependencies:** Phase 0 (Foundation), Phase 1 (Packer Images)
**Deployment Tool:** [Kubespray v2.29.0+](https://github.com/kubernetes-sigs/kubespray)

## Overview

Deploy production-ready Kubernetes cluster using Kubespray, a CNCF-approved tool with battle-tested Ansible
automation. This eliminates the need for custom kubeadm roles and provides comprehensive cluster management out of
the box.

**Why Kubespray:**

- ✅ CNCF-approved, 17.8k GitHub stars, 1,170+ contributors
- ✅ Production-tested across multiple environments
- ✅ Supports our stack: Debian Trixie, Containerd, Calico CNI
- ✅ Built-in validation and health checks
- ✅ Active community and regular updates

---

## CLOUD-2.1: Integrate and Configure Kubespray

**Duration:** 3-4 days
**Priority:** HIGH
**Status:** ✅ **Completed**
**Dependencies:** CLOUD-0.2, CLOUD-1.1

### Objective

Integrate Kubespray into the project as a third-party dependency and configure it for our cloud cluster topology.

### Kubespray Integration

**Installation:**

```bash
# Install Kubespray via CMake (one-time setup)
cmake --build build --target install-kubespray

# Kubespray cloned to: build/3rd-party/kubespray/kubespray-src/
```

**Directory Structure:**

```text
3rd-party/
└── kubespray/
    ├── CMakeLists.txt                  # CMake configuration
    └── README.md                       # Integration documentation

build/3rd-party/kubespray/
└── kubespray-src/                      # Cloned Kubespray repository
    ├── cluster.yml                     # Main deployment playbook
    ├── reset.yml                       # Cluster teardown playbook
    ├── roles/                          # Ansible roles
    └── inventory/                      # Sample inventories

ansible/
├── inventories/
│   └── cloud-cluster/                  # Our cloud cluster inventory
│       ├── inventory.ini               # Generated from cluster.yaml
│       └── group_vars/
│           ├── all/
│           │   └── cloud-cluster.yml   # Our Kubespray configuration
│           └── k8s_cluster/
│               ├── k8s-cluster.yml     # Kubernetes settings
│               ├── k8s-net-calico.yml  # Calico CNI configuration
│               └── addons.yml          # Enable add-ons
└── playbooks/
    └── deploy-cloud-cluster.yml        # Wrapper playbook
```

### Inventory Generation

The `ai-how cloud start` command generates Kubespray inventory from `cluster.yaml`:

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
# Empty - not using route reflectors

[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr
```

### Kubespray Configuration

**group_vars/all/cloud-cluster.yml:**

```yaml
---
# AI-HOW Cloud Cluster Configuration for Kubespray

## Container Runtime
container_manager: containerd
containerd_version: "1.7.23"
containerd_storage_dir: "/var/lib/containerd"
containerd_state_dir: "/run/containerd"

## Kubernetes Version
kube_version: v1.28.0

## Network Plugin
kube_network_plugin: calico
calico_version: "v3.30.3"
calico_cni_version: "v3.30.3"
calico_policy_enabled: true
calico_mtu: 1440

## Service and Pod Networks
kube_service_addresses: 10.96.0.0/12
kube_pods_subnet: 10.244.0.0/16
kube_network_node_prefix: 24

## DNS Configuration
dns_mode: coredns
enable_nodelocaldns: true
nodelocaldns_ip: 169.254.25.10

## Ingress Controller
ingress_nginx_enabled: true
ingress_nginx_host_network: false
ingress_nginx_namespace: ingress-nginx

## Metrics Server
metrics_server_enabled: true
metrics_server_kubelet_insecure_tls: true
metrics_server_kubelet_preferred_address_types: "InternalIP"

## Node Configuration
kubelet_max_pods: 110
kube_read_only_port: 10255

## Node Labels and Taints
node_labels:
  control-plane:
    node-role.kubernetes.io/control-plane: ""
  cpu-worker:
    workload-type: "general"
  gpu-worker-1:
    workload-type: "inference"
    gpu-type: "rtx-a6000"
    inference-ready: "true"
  gpu-worker-2:
    workload-type: "inference"
    gpu-type: "tesla-t4"
    inference-ready: "true"

node_taints:
  control-plane:
    - key: node-role.kubernetes.io/control-plane
      effect: NoSchedule
  gpu-worker-1:
    - key: nvidia.com/gpu
      value: present
      effect: NoSchedule
  gpu-worker-2:
    - key: nvidia.com/gpu
      value: present
      effect: NoSchedule

## Kubeconfig
kubeconfig_localhost: true
kubectl_localhost: true

## Feature Gates
kube_feature_gates:
  - "CSIMigration=true"
  - "CSIMigrationAWS=true"

## System Configuration
system_reserved: true
system_memory_reserved: 512Mi
system_cpu_reserved: 500m
```

### Wrapper Playbook

**ansible/playbooks/deploy-cloud-cluster.yml:**

```yaml
---
- name: Deploy Cloud Cluster with Kubespray
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Display deployment information
      ansible.builtin.debug:
        msg: |
          Deploying Kubernetes cluster via Kubespray
          Inventory: {{ inventory_file }}
          Kubernetes Version: v1.28.0
          CNI: Calico

    - name: Run Kubespray cluster deployment
      ansible.builtin.import_playbook: ../../build/3rd-party/kubespray/kubespray-src/cluster.yml
      vars:
        ansible_python_interpreter: /usr/bin/python3

- name: Post-Kubespray Configuration
  hosts: kube_node
  gather_facts: false
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

    - name: Wait for all nodes to be ready
      kubernetes.core.k8s_info:
        kind: Node
        name: "{{ inventory_hostname }}"
      register: node_info
      until: >
        node_info.resources[0].status.conditions | selectattr('type', 'equalto', 'Ready') |
        map(attribute='status') | first == 'True'
      retries: 30
      delay: 10
      delegate_to: control-plane

- name: Validate Cluster Health
  hosts: kube_control_plane[0]
  gather_facts: false
  tasks:
    - name: Check cluster info
      kubernetes.core.k8s_cluster_info:
      register: cluster_info

    - name: Display cluster info
      ansible.builtin.debug:
        var: cluster_info
```

### CLI Integration

**Workflow in `ai-how cloud start`:**

```python
1. Validate cluster configuration
2. Provision VMs (CLOUD-0.1)
3. Wait for VMs to be SSH-accessible
4. Generate Kubespray inventory from cluster.yaml
5. Execute: ansible-playbook -i inventories/cloud-cluster/inventory.ini \
              ../../build/3rd-party/kubespray/kubespray-src/cluster.yml
6. Validate Kubernetes cluster health
7. Copy kubeconfig to ~/.kube/config
8. Display cluster status
```

### What Kubespray Deploys

Kubespray automatically handles:

1. **OS Bootstrap:**
   - Package installation (containerd, kubeadm, kubectl, kubelet)
   - Kernel module loading
   - sysctl configuration
   - Swap management

2. **Container Runtime:**
   - Containerd installation and configuration
   - Runtime systemd service

3. **Kubernetes Cluster:**
   - etcd cluster (on control plane)
   - Kubernetes control plane (API server, controller-manager, scheduler)
   - Kubelet on all nodes
   - Certificate generation and distribution
   - RBAC configuration

4. **Networking:**
   - Calico CNI deployment
   - Network policy support
   - Pod-to-pod connectivity

5. **Add-ons:**
   - CoreDNS for cluster DNS
   - Metrics-server for resource metrics
   - NGINX Ingress Controller
   - Node-local DNS cache (optional)

### Deliverables

- [x] Install Kubespray via CMake (`3rd-party/kubespray/CMakeLists.txt`)
- [x] Create Kubespray inventory generation script (`scripts/generate-kubespray-inventory.py`)
- [x] Create cloud cluster inventory template (`ansible/inventories/cloud-cluster/inventory.ini`)
- [x] Configure Kubespray variables in group_vars (`ansible/inventories/cloud-cluster/group_vars/`)
- [x] Create Ansible role for Kubespray integration (`ansible/roles/kubespray-integration/`)
- [x] Create wrapper playbook for deployment (`ansible/playbooks/deploy-cloud-cluster.yml`)
- [x] Add Kubernetes deployment methods to CloudClusterManager (`deploy_kubernetes()`, `generate_kubespray_inventory()`)
- [x] Update Makefile target (`cloud-cluster-deploy`)
- [x] Document Kubespray configuration options

### Validation

```bash
# Deploy cluster
ai-how cloud start config/cloud-cluster.yaml

# Verify Kubernetes cluster
kubectl get nodes
# Expected: All nodes in Ready state

kubectl get pods -A
# Expected: All system pods running

# Verify networking
kubectl run test-pod --image=nginx --rm -it -- /bin/sh
# Expected: Pod can resolve DNS, reach other pods

# Check Calico
kubectl get pods -n kube-system -l k8s-app=calico-node
# Expected: Calico pods running on all nodes

# Verify ingress
kubectl get pods -n ingress-nginx
# Expected: Ingress controller running

# Test metrics
kubectl top nodes
kubectl top pods -A
# Expected: Resource metrics available
```

### Success Criteria

- [x] Kubespray installs successfully via CMake (`make run-docker COMMAND="cmake --build build --target install-kubespray"`)
- [x] Inventory generation script works correctly (`scripts/generate-kubespray-inventory.py`)
- [x] Ansible role properly integrates with Kubespray (`ansible/roles/kubespray-integration/`)
- [x] Wrapper playbook provides deployment workflow (`ansible/playbooks/deploy-cloud-cluster.yml`)
- [x] Cloud manager can generate inventory and deploy Kubernetes (methods implemented)
- [x] Kubespray configuration files created (group_vars)
- [ ] Kubernetes cluster deploys without errors (pending deployment testing)
- [ ] All nodes reach Ready state (pending deployment testing)
- [ ] CoreDNS resolves cluster services (pending deployment testing)
- [ ] Calico CNI provides pod networking (pending deployment testing)
- [ ] Ingress controller is operational (pending deployment testing)
- [ ] Metrics-server provides resource data (pending deployment testing)
- [ ] Kubeconfig is accessible on workstation (pending deployment testing)

### Troubleshooting

**Common Issues:**

1. **Kubespray playbook fails:**
   - Check Ansible version (2.14+ required)
   - Verify Python 3.9+ on all nodes
   - Review logs: `output/logs/cloud-cluster-deploy-{timestamp}.log`

2. **Nodes not joining cluster:**
   - Verify network connectivity between nodes
   - Check firewall rules (Kubernetes ports)
   - Review kubelet logs: `journalctl -u kubelet`

3. **DNS not working:**
   - Verify CoreDNS pods are running
   - Check DNS service: `kubectl get svc -n kube-system kube-dns`
   - Test with: `kubectl run busybox --image=busybox --rm -it -- nslookup kubernetes`

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-005`

---

## CLOUD-2.2: Deploy NVIDIA GPU Operator

**Duration:** 2-3 days
**Priority:** HIGH
**Status:** Not Started
**Dependencies:** CLOUD-2.1

### Objective

Deploy NVIDIA GPU Operator on GPU worker nodes to enable GPU scheduling and monitoring in Kubernetes.

### GPU Operator Overview

The NVIDIA GPU Operator automates:

- GPU driver installation (if not pre-installed)
- NVIDIA Container Toolkit
- Device plugin for GPU scheduling
- DCGM for GPU monitoring
- GPU Feature Discovery

**Why GPU Operator:**

- Standardizes GPU configuration across nodes
- Handles driver lifecycle management
- Provides monitoring integration
- Supports time-slicing for GPU sharing

### Ansible Role Structure

```text
ansible/roles/nvidia-gpu-operator/
├── README.md
├── defaults/
│   └── main.yml                        # Default variables
├── tasks/
│   ├── main.yml                        # Main task orchestration
│   ├── install-helm.yml                # Ensure Helm is installed
│   ├── add-nvidia-repo.yml             # Add NVIDIA Helm repository
│   ├── install-gpu-operator.yml        # Deploy GPU operator
│   ├── configure-time-slicing.yml      # Optional time-slicing config
│   └── validate.yml                    # Validation checks
├── templates/
│   ├── gpu-operator-values.yaml.j2     # Helm values template
│   └── time-slicing-config.yaml.j2     # Time-slicing configuration
└── files/
    └── gpu-test-pod.yaml               # Test pod manifest
```

### Helm Values Configuration

**templates/gpu-operator-values.yaml.j2:**

```yaml
# NVIDIA GPU Operator Helm Values
operator:
  defaultRuntime: containerd
  runtimeClass: nvidia

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
    enabled: true  # For Prometheus integration

gfd:
  enabled: true
  version: v0.8.2

migManager:
  enabled: false  # Not using MIG for inference workloads

node-feature-discovery:
  enableNodeFeatureApi: true
```

### Installation Tasks

**tasks/install-gpu-operator.yml:**

```yaml
---
- name: Add NVIDIA Helm repository
  kubernetes.core.helm_repository:
    name: nvidia
    repo_url: https://helm.ngc.nvidia.com/nvidia

- name: Update Helm repositories
  kubernetes.core.helm:
    name: dummy
    state: absent
  changed_when: false

- name: Create gpu-operator-system namespace
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: Namespace
      metadata:
        name: gpu-operator-system

- name: Install NVIDIA GPU Operator
  kubernetes.core.helm:
    name: gpu-operator
    chart_ref: nvidia/gpu-operator
    release_namespace: gpu-operator-system
    values: "{{ lookup('template', 'gpu-operator-values.yaml.j2') | from_yaml }}"
    wait: true
    wait_timeout: 10m

- name: Wait for GPU operator pods to be ready
  kubernetes.core.k8s_info:
    kind: Pod
    namespace: gpu-operator-system
    label_selectors:
      - "app.kubernetes.io/component=gpu-operator"
  register: gpu_operator_pods
  until: >
    gpu_operator_pods.resources | length > 0 and
    (gpu_operator_pods.resources | selectattr('status.phase', 'equalto', 'Running') | list | length) ==
    (gpu_operator_pods.resources | length)
  retries: 60
  delay: 10
```

### Validation Tasks

**tasks/validate.yml:**

```yaml
---
- name: Check GPU availability on nodes
  kubernetes.core.k8s_info:
    kind: Node
    label_selectors:
      - "nvidia.com/gpu.present=true"
  register: gpu_nodes

- name: Display GPU node information
  ansible.builtin.debug:
    msg: "Found {{ gpu_nodes.resources | length }} GPU nodes"

- name: Get GPU resource capacity
  ansible.builtin.set_fact:
    gpu_capacity: "{{ item.status.capacity['nvidia.com/gpu'] | default('0') }}"
  loop: "{{ gpu_nodes.resources }}"
  register: gpu_capacities

- name: Deploy test GPU pod
  kubernetes.core.k8s:
    state: present
    definition: "{{ lookup('file', 'gpu-test-pod.yaml') }}"

- name: Wait for test pod to complete
  kubernetes.core.k8s_info:
    kind: Pod
    name: gpu-test-pod
    namespace: default
  register: test_pod
  until: test_pod.resources[0].status.phase == 'Succeeded'
  retries: 30
  delay: 10

- name: Get test pod logs
  kubernetes.core.k8s_log:
    name: gpu-test-pod
    namespace: default
  register: gpu_test_logs

- name: Display GPU test results
  ansible.builtin.debug:
    var: gpu_test_logs.log

- name: Cleanup test pod
  kubernetes.core.k8s:
    state: absent
    kind: Pod
    name: gpu-test-pod
    namespace: default
```

### GPU Test Pod

**files/gpu-test-pod.yaml:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test-pod
  namespace: default
spec:
  restartPolicy: Never
  containers:
  - name: cuda-test
    image: nvidia/cuda:12.0.0-base-ubuntu22.04
    command:
      - nvidia-smi
    resources:
      limits:
        nvidia.com/gpu: 1
  nodeSelector:
    workload-type: inference
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
```

### Integration with deploy-cloud-cluster.yml

```yaml
# Add to ansible/playbooks/deploy-cloud-cluster.yml

- name: Deploy NVIDIA GPU Operator
  hosts: localhost
  gather_facts: false
  roles:
    - nvidia-gpu-operator
  vars:
    kubeconfig_path: "{{ lookup('env', 'HOME') }}/.kube/config"
```

### Deliverables

- [ ] Create `ansible/roles/nvidia-gpu-operator/` role
- [ ] Helm-based GPU operator installation
- [ ] Device plugin configuration
- [ ] DCGM exporter for monitoring
- [ ] Time-slicing configuration (optional)
- [ ] GPU scheduling validation
- [ ] Integration with deployment playbook

### Validation

```bash
# After GPU operator deployment

# Check GPU operator pods
kubectl get pods -n gpu-operator-system
# Expected: All pods in Running state

# Verify GPU resources on nodes
kubectl describe node gpu-worker-1 | grep nvidia.com/gpu
# Expected: Allocatable: nvidia.com/gpu: 1

# Run GPU test pod
kubectl apply -f ansible/roles/nvidia-gpu-operator/files/gpu-test-pod.yaml
kubectl logs gpu-test-pod
# Expected: nvidia-smi output showing GPU information

# Check DCGM metrics
kubectl get servicemonitor -n gpu-operator-system
# Expected: dcgm-exporter ServiceMonitor present
```

### Success Criteria

- [ ] GPU operator installs successfully via Helm
- [ ] GPU devices are recognized on worker nodes
- [ ] Device plugin exposes `nvidia.com/gpu` resource
- [ ] DCGM exporter provides GPU metrics
- [ ] Test pod can access GPU and run nvidia-smi
- [ ] GPU scheduling works with node selectors and tolerations

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-006`

---

## Phase Completion Checklist

- [x] CLOUD-2.1: Kubespray integration complete (CMake, inventory, role, playbook, manager methods)
- [ ] CLOUD-2.2: GPU operator installed and validated (Next task)
- [ ] Kubernetes cluster deployment tested end-to-end
- [ ] GPU scheduling tested and validated
- [ ] All validation tests pass
- [ ] Documentation updated

## Next Phase

Proceed to [Phase 3: MLOps Stack Deployment](03-mlops-stack-phase.md)
