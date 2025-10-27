# Kubespray Migration Summary

**Date:** 2025-10-27  
**Status:** Plan Updated - Ready for Implementation

## Overview

Updated the cloud cluster implementation plan to use **[Kubespray](https://github.com/kubernetes-sigs/kubespray)**
instead of custom kubeadm-based Ansible roles.

## Why Kubespray?

1. **Production-Ready:** CNCF-approved, 17.8k GitHub stars, 1,170 contributors
2. **Battle-Tested:** Used by CNCF and enterprises worldwide
3. **Comprehensive:** Handles everything from OS prep to cluster validation
4. **Ansible-Native:** Seamlessly integrates with our existing infrastructure
5. **Well-Maintained:** Active community, continuous testing
6. **Supports Our Stack:**
   - Debian Trixie (our OS)
   - Containerd runtime
   - Calico CNI
   - NGINX Ingress Controller
   - GPU worker nodes

## Key Changes

### Task Consolidation

**Before (20 tasks with sequential numbering):**

- TASK-CLOUD-005: Create Kubernetes Control Plane Role (custom)
- TASK-CLOUD-006: Create Kubernetes Worker Role (custom)
- TASK-CLOUD-007: Create GPU Operator Role
- TASK-CLOUD-008: Create Ingress Controller Role

**After (18 tasks with phase-prefixed numbering):**

- **CLOUD-2.1**: Integrate and Configure Kubespray (replaces 005, 006, 008)
- **CLOUD-2.2**: Deploy NVIDIA GPU Operator (keeps GPU operator, removes ingress as separate task)

**Reduction:** Eliminated 2 tasks by leveraging Kubespray's built-in automation (CNI, Ingress built into Kubespray).

### Phase 2 Changes

**Old Approach:**

- Write custom Ansible roles for:
  - Kubernetes control plane (kubeadm init)
  - Worker node joining (kubeadm join)
  - CNI deployment (Calico)
  - Ingress controller (NGINX)
- Total: ~2 weeks of custom development

**New Approach:**

- Integrate Kubespray (battle-tested)
- Configure via inventory and group_vars
- Deploy GPU Operator separately
- Total: ~1.5 weeks (faster + more reliable)

### What Kubespray Provides Out-of-the-Box

1. **OS Bootstrap:**
   - Package installation
   - Kernel module loading
   - sysctl configuration
   - Swap management

2. **Container Runtime:**
   - Containerd installation
   - Runtime configuration
   - Registry mirrors

3. **Kubernetes Cluster:**
   - etcd cluster deployment
   - Control plane initialization
   - Worker node joining
   - RBAC configuration
   - Certificate management

4. **Networking:**
   - Calico CNI deployment
   - Network policies
   - Service mesh readiness

5. **Add-ons:**
   - CoreDNS for DNS
   - Metrics-server for resource metrics
   - NGINX Ingress Controller
   - Node-local DNS cache (optional)

## Task Numbering Update

**New Scheme:** Phase-prefixed task IDs (CLOUD-{Phase}.{Task}) eliminate cascading renumbering.

| Old Sequential ID | New Phase-Prefixed ID | Task Name | Phase |
|-------------------|------------------------|-----------|-------|
| CLOUD-001 | **CLOUD-0.1** | Extend VM Management | 0: Foundation |
| CLOUD-002 | **CLOUD-0.2** | Implement CLI Commands | 0: Foundation |
| CLOUD-003 | **CLOUD-1.1** | Create Cloud Base Image | 1: Packer Images |
| CLOUD-004 | **CLOUD-1.2** | Create Specialized Images | 1: Packer Images |
| CLOUD-005 | **CLOUD-2.1** | Integrate Kubespray | 2: Kubernetes |
| CLOUD-006 | **CLOUD-2.2** | Deploy GPU Operator | 2: Kubernetes |
| CLOUD-007 | **CLOUD-3.1** | Deploy MinIO | 3: MLOps Stack |
| CLOUD-008 | **CLOUD-3.2** | Deploy PostgreSQL | 3: MLOps Stack |
| CLOUD-009 | **CLOUD-3.3** | Deploy MLflow | 3: MLOps Stack |
| CLOUD-010 | **CLOUD-3.4** | Deploy KServe | 3: MLOps Stack |
| CLOUD-011 | **CLOUD-4.1** | Deploy Prometheus | 4: Monitoring |
| CLOUD-012 | **CLOUD-4.2** | Deploy Grafana | 4: Monitoring |
| CLOUD-013 | **CLOUD-5.1** | Oumi Configuration | 5: Oumi Integration |
| CLOUD-014 | **CLOUD-5.2** | ML Workflow Documentation | 5: Oumi Integration |
| CLOUD-015 | **CLOUD-6.1** | Model Transfer Automation | 6: Integration |
| CLOUD-016 | **CLOUD-6.2** | Unified Monitoring | 6: Integration |
| CLOUD-017 | **CLOUD-6.3** | Performance Testing | 6: Integration |
| CLOUD-018 | **CLOUD-7.1** | Test Framework | 7: Testing |

**Benefits:**

- Adding CLOUD-2.3 doesn't affect Phase 3+ tasks
- Each phase file manages its own numbering
- Clear phase association from task ID

## Implementation Details

### Kubespray Integration

Kubespray is managed as a third-party dependency via CMake, following the same pattern as BeeGFS and SLURM.

```bash
# Directory structure
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
│   └── cloud-cluster/                      # Our inventory
│       ├── inventory.ini                   # Generated from cluster.yaml
│       └── group_vars/
│           ├── all/cloud-cluster.yml       # Our Kubespray config
│           └── k8s_cluster/k8s-cluster.yml
└── playbooks/
    └── deploy-cloud-cluster.yml            # Wrapper playbook
```

**Installation:**

```bash
# Install Kubespray as a third-party dependency
cmake --build build --target install-kubespray

# Or using Docker container (recommended)
make run-docker COMMAND="cmake --build build --target install-kubespray"
```

### Deployment Flow

```bash
# When running: ai-how cloud start config/cloud-cluster.yaml

0. Install Kubespray (one-time setup)
   └─> cmake --build build --target install-kubespray
   └─> Kubespray cloned to: build/3rd-party/kubespray/kubespray-src/

1. VM Provisioning (CLOUD-0.1)
   └─> Create VMs from cloud-base.qcow2

2. Kubespray Deployment (CLOUD-2.1)
   └─> Generate inventory from cluster.yaml
   └─> Run Kubespray playbook:
       ansible-playbook -i inventories/cloud-cluster/inventory.ini \
         ../../build/3rd-party/kubespray/kubespray-src/cluster.yml
   └─> Result: Fully operational Kubernetes cluster with:
       - Containerd runtime
       - Calico CNI
       - CoreDNS
       - Metrics-server
       - NGINX Ingress

3. GPU Operator (CLOUD-2.2)
   └─> Deploy NVIDIA GPU Operator via Helm
   └─> Enable GPU scheduling on worker nodes

4. MLOps Stack (CLOUD-3.1 to 3.4)
   └─> Deploy on Kubernetes cluster
```

### Configuration Example

```yaml
# ansible/inventories/cloud-cluster/group_vars/all/cloud-cluster.yml

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

# Add-ons
ingress_nginx_enabled: true
metrics_server_enabled: true
enable_nodelocaldns: true

# Node Features (GPU workers)
node_labels:
  gpu-worker-1:
    workload-type: "inference"
    gpu-type: "rtx-a6000"

node_taints:
  gpu-worker-1: ['nvidia.com/gpu=present:NoSchedule']
```

## Benefits of This Approach

### 1. **Less Custom Code**

- **Before:** ~500 lines of custom Ansible roles
- **After:** ~100 lines of configuration + Kubespray integration
- **Reduction:** 80% less custom code to maintain

### 2. **Better Quality**

- Kubespray is tested across:
  - Multiple Linux distributions
  - Various cloud providers
  - Different Kubernetes versions
  - Extensive CI/CD pipeline

### 3. **Easier Maintenance**

- Community maintains Kubespray
- Regular updates for new Kubernetes versions
- Security patches applied upstream
- Bug fixes from 1,170+ contributors

### 4. **Proven Track Record**

- Used by CNCF
- Deployed in production environments globally
- Handles edge cases we haven't encountered
- Comprehensive troubleshooting documentation

### 5. **Faster Implementation**

- No need to write control plane role
- No need to write worker node role
- No need to write ingress role
- Just configure and deploy

## Updated Timeline

| Phase | Duration | Change |
|-------|----------|--------|
| Phase 0: Foundation | 2 weeks | No change |
| Phase 1: Packer Images | 1 week | No change |
| Phase 2: Kubernetes | 2 weeks | **Reduced from 2.5 weeks** |
| Phase 3: MLOps Stack | 2 weeks | No change |
| Phase 4: Monitoring | 1 week | No change |
| Phase 5: Oumi Integration | 1 week | No change |
| Phase 6: Integration | 1 week | No change |
| Phase 7: Testing | 1 week | No change |

**Total: 11 weeks** (reduced from 11.5 weeks due to Phase 2 simplification)

## Risk Mitigation

### Potential Concerns

1. **Learning Curve:**
   - **Mitigation:** Kubespray uses standard Ansible patterns we already know
   - **Documentation:** Comprehensive docs at https://kubespray.io/

2. **Customization Limitations:**
   - **Mitigation:** Kubespray is highly configurable via variables
   - **Escape Hatch:** Can still add custom Ansible tasks if needed

3. **Version Lock-in:**
   - **Mitigation:** Kubespray supports multiple K8s versions
   - **Upgrade Path:** Well-documented upgrade procedures

## Next Steps

1. **Add Kubespray Submodule:**

   ```bash
   cd ansible
   git submodule add https://github.com/kubernetes-sigs/kubespray.git
   git submodule update --init --recursive
   ```

2. **Create Inventory Structure:**

   ```bash
   mkdir -p ansible/inventories/cloud-cluster/group_vars/{all,k8s_cluster}
   ```

3. **Implement Inventory Generator:**
   - Update `ai-how cloud start` to generate Kubespray inventory from `cluster.yaml`

4. **Test Deployment:**
   - Deploy test cluster
   - Validate all components
   - Document any issues

## References

- **Kubespray Repository:** https://github.com/kubernetes-sigs/kubespray
- **Kubespray Documentation:** https://kubespray.io/
- **Getting Started Guide:** https://github.com/kubernetes-sigs/kubespray/blob/master/docs/getting-started.md
- **Supported OS:** https://github.com/kubernetes-sigs/kubespray#supported-linux-distributions
- **Updated Plan:** `docs/design-docs/cloud-cluster-oumi-inference.md`
- **Task List:** `docs/implementation-plans/task-lists/cloud-cluster/README.md`

---

**Status:** Ready for implementation  
**Next Task:** TASK-CLOUD-001 (Extend VM Management for Cloud Cluster)
