# Phase 0: Cloud Cluster Foundation

**Duration:** 3 weeks (extended to include shared GPU support)
**Tasks:** CLOUD-0.1, CLOUD-0.2, CLOUD-0.3, CLOUD-0.4
**Dependencies:** None (can start immediately)

## Overview

Establish the foundational infrastructure for cloud cluster management by extending the existing HPC VM management
system to support Kubernetes-based cloud clusters. This phase creates the core VM lifecycle management, CLI
integration, and shared GPU resource management needed for all subsequent phases.

## Key Features

- **Shared GPU Support**: Multiple clusters can be configured to use the same physical GPUs with mutual exclusivity
- **Enhanced VM Lifecycle**: Individual VM stop/start/restart with proper GPU resource management
- **Cluster Conflict Detection**: Automatic detection and prevention of resource conflicts between clusters
- **GPU Resource Tracking**: State-based tracking of which cluster owns GPU resources at any given time

---

## CLOUD-0.1: Extend VM Management for Cloud Cluster

**Duration:** 3-4 days
**Priority:** CRITICAL
**Status:** Not Started
**Dependencies:** None

### Objective

Extend existing HPC VM management infrastructure to support cloud cluster provisioning with Kubernetes-specific
requirements.

### Current State

- HPC VM management is complete (4,308+ lines)
- LibVirt client, VM lifecycle, volume, and network management operational
- PCIe passthrough for discrete GPU access implemented
- XML templating system functional

### Key Files to Modify

- `python/ai_how/src/ai_how/vm/vm_manager.py` - Extend with CloudVMManager class
- `python/ai_how/src/ai_how/state/state_manager.py` - Add cloud cluster state tracking
- `python/ai_how/src/ai_how/config/cluster_config.py` - Add cloud cluster validation

### Deliverables

- [ ] Create `CloudVMManager` class extending `VMManager`
- [ ] Add cloud cluster state tracking in `output/state.json`
- [ ] Create cloud-specific libvirt XML templates
- [ ] Implement configuration validation for cloud cluster topology
- [ ] Add cloud cluster lifecycle methods (provision, deprovision, status)
- [ ] Add support for `auto_start: false` VM configuration flag

### Implementation Notes

**State Management:**

```python
# output/state.json structure for cloud cluster
{
  "cloud_cluster": {
    "name": "oumi-inference-cluster",
    "status": "running",
    "nodes": {
      "control-plane": {
        "vm_id": "cloud-control-plane-uuid",
        "ip": "192.168.200.10",
        "role": "kubernetes-control-plane",
        "state": "running"
      },
      "gpu-worker-1": {
        "vm_id": "cloud-gpu-worker-1-uuid",
        "ip": "192.168.200.12",
        "role": "kubernetes-worker",
        "gpu": "NVIDIA RTX A6000",
        "state": "shutoff",
        "auto_start": false
      }
    }
  }
}
```

**Configuration with `auto_start` Flag:**

```yaml
# config/cloud-cluster.yaml
clusters:
  cloud:
    control_plane:
      cpu_cores: 4
      memory_gb: 8
      disk_gb: 100
      ip: "192.168.200.10"
      # auto_start defaults to true if not specified
    
    worker_nodes:
      cpu:
        - worker_type: "cpu"
          cpu_cores: 4
          memory_gb: 8
          disk_gb: 100
          ip: "192.168.200.11"
      
      gpu:
        - worker_type: "gpu"
          cpu_cores: 8
          memory_gb: 16
          disk_gb: 200
          ip: "192.168.200.12"
          auto_start: false  # VM created but not started (avoids GPU conflict)
          pcie_passthrough:
            enabled: true
            devices:
              - pci_address: "0000:01:00.0"  # Shared with HPC cluster
                device_type: "gpu"
                vendor_id: "10de"
                device_id: "2805"
```

**Use Case - GPU Conflict Avoidance:**

This flag is essential when multiple clusters share the same GPU:

1. **HPC Training Cluster**: Uses GPU `0000:01:00.0` for training workloads
2. **Cloud Inference Cluster**: Also configured with GPU `0000:01:00.0` for inference

During cluster provisioning:

- All VMs are created (including GPU inference VM)
- HPC training VMs start automatically
- Cloud GPU inference VM is created but left in `shutoff` state
- User can manually start cloud GPU VM when HPC training is complete

```bash
# Provision both clusters (all VMs created)
ai-how hpc start config/cluster.yaml
ai-how cloud start config/cluster.yaml

# Result:
# - HPC cluster: All VMs running (GPU allocated)
# - Cloud cluster: CPU workers running, GPU worker created but stopped

# Later, switch to inference:
ai-how hpc stop config/cluster.yaml
ai-how vm start cloud-cluster-gpu-worker-01
```

**XML Template Differences from HPC:**

- No SLURM-specific configuration
- Kubernetes networking requirements (bridge mode)
- Different resource allocations (control plane vs workers)
- Optional GPU passthrough (only for GPU workers)

### Validation

```bash
# Test VM provisioning with auto_start flag
ai-how cloud start config/cloud-cluster.yaml

# Verify state tracking (check auto_start flag and VM states)
cat output/state.json | jq '.cloud_cluster'

# Check VM status (should show GPU worker as 'created' but 'shutoff')
ai-how cloud status config/cloud-cluster.yaml

# Verify VMs with auto_start: false are created but not running
virsh list --all | grep cloud-cluster-gpu-worker

# Test manual start of non-auto-start VM
ai-how vm start cloud-cluster-gpu-worker-01
ai-how vm status cloud-cluster-gpu-worker-01

# Test lifecycle
ai-how cloud stop config/cloud-cluster.yaml
ai-how cloud start config/cloud-cluster.yaml
# GPU worker should still be stopped after cluster restart
```

### Success Criteria

- [ ] VMs provision successfully from cloud cluster configuration
- [ ] VMs with `auto_start: false` are created but remain in `shutoff` state
- [ ] VMs with `auto_start: true` (or default) start automatically
- [ ] State is tracked accurately in state.json with `auto_start` flag preserved
- [ ] VMs have correct network configuration for Kubernetes
- [ ] GPU passthrough works for GPU worker nodes
- [ ] Lifecycle operations (start/stop) work reliably
- [ ] Non-auto-start VMs can be manually started with `ai-how vm start`
- [ ] Cluster restart preserves non-auto-start VM stopped state

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-001`

---

## CLOUD-0.2: Implement Cloud Cluster CLI Commands

**Duration:** 2-3 days
**Priority:** CRITICAL
**Status:** Not Started
**Dependencies:** CLOUD-0.1

### Objective

Replace stub implementations in CLI with functional cloud cluster commands, providing complete lifecycle management
through the `ai-how` command-line interface.

### Current State

- CLI stub implementations exist (lines 593-610 in `python/ai_how/src/ai_how/cli.py`)
- Commands defined but not functional:
  - `ai-how cloud start`
  - `ai-how cloud stop`
  - `ai-how cloud status`
  - `ai-how cloud destroy`

### Key Files to Modify

- `python/ai_how/src/ai_how/cli.py` - Implement cloud subcommands
- `python/ai_how/docs/cli-reference.md` - Update documentation

### Deliverables

- [ ] Implement `cloud start` command with Ansible playbook execution
- [ ] Implement `cloud stop` command with graceful shutdown
- [ ] Implement `cloud status` command with detailed cluster information
- [ ] Implement `cloud destroy` command with confirmation prompts
- [ ] Implement `topology` command to display complete infrastructure tree
- [ ] Add comprehensive error handling and rollback mechanisms
- [ ] Update CLI documentation with examples

### Implementation Details

**Command: `cloud start`**

```python
# Workflow:
1. Validate cluster configuration (cluster.yaml)
2. Provision VMs using CloudVMManager (CLOUD-0.1)
3. For each VM, check auto_start flag (default: true):
   - If auto_start: true → Start VM and wait for boot
   - If auto_start: false → Create VM but leave in shutoff state
4. Wait for auto-started VMs to boot and become SSH-accessible
5. Generate Kubespray inventory (only include running VMs)
6. Execute Ansible playbook: deploy-cloud-cluster.yml (on running VMs only)
7. Validate Kubernetes cluster health (excluding non-started VMs)
8. Update state.json with cluster status and VM states
```

**Note on `auto_start: false` VMs:**

- VMs are created but not started (remain in `shutoff` state)
- Not included in Kubernetes cluster initialization
- Can be manually started later with `ai-how vm start <vm-name>`
- Upon manual start, user must run Ansible to join node to Kubernetes cluster

**Command: `cloud stop`**

```python
# Workflow:
1. Drain Kubernetes nodes gracefully
2. Stop Kubernetes services
3. Shutdown VMs using libvirt
4. Update state.json (status: stopped)
```

**Command: `cloud status`**

```python
# Display:
- Cluster name and configuration file
- VM status (running/stopped for each node)
  - Indicate VMs with auto_start: false with special marker
- Kubernetes cluster status (if running)
- Node roles and IPs
- GPU allocation (for GPU workers)
- Resource utilization summary

# Example output:
Cloud Cluster Status: oumi-inference-cluster
├── control-plane (192.168.200.10) [running]
├── cpu-worker-01 (192.168.200.11) [running]
└── gpu-worker-01 (192.168.200.12) [stopped] 🔒 auto_start: false

Kubernetes Status: Healthy (2/3 nodes ready)
Note: gpu-worker-01 was created but not started (auto_start: false)
```

**Command: `cloud destroy`**

```python
# Workflow:
1. Prompt for confirmation (--force to skip)
2. Stop cluster if running
3. Delete VMs and associated volumes
4. Clean up state.json
5. Archive logs to output/logs/cloud-cluster-destroyed-{timestamp}/
```

**Command: `topology`**

```python
# Workflow:
1. Load all cluster states (HPC, Cloud, etc.)
2. Load global GPU allocation state
3. Build tree structure with:
   - Clusters (with status: running/stopped)
   - Networks (with CIDR ranges)
   - VMs (with IPs, roles, resource allocation)
   - GPUs (with PCI addresses and allocation status)
4. Identify GPU conflicts (VMs sharing same GPU)
5. Render tree with color coding:
   - Green: running nodes
   - Yellow: stopped nodes
   - Red: nodes with GPU conflicts (cannot run simultaneously)
   - Cyan: network information
   - Magenta: GPU information

# Display format:
Infrastructure Topology
├── HPC Cluster (running)
│   ├── Network: 192.168.100.0/24
│   ├── controller (192.168.100.10) [running]
│   │   ├── CPU: 4 cores
│   │   ├── RAM: 8 GB
│   │   └── Role: SLURM Controller
│   └── compute-01 (192.168.100.11) [running] ⚠️ GPU CONFLICT
│       ├── CPU: 8 cores
│       ├── RAM: 16 GB
│       ├── Role: SLURM Compute Node
│       └── GPU: 0000:01:00.0 (NVIDIA RTX A6000) [ALLOCATED]
│
└── Cloud Cluster (stopped)
    ├── Network: 192.168.200.0/24
    ├── control-plane (192.168.200.10) [stopped]
    │   ├── CPU: 4 cores
    │   ├── RAM: 8 GB
    │   └── Role: Kubernetes Control Plane
    └── gpu-worker-01 (192.168.200.12) [stopped] ⚠️ GPU CONFLICT
        ├── CPU: 8 cores
        ├── RAM: 16 GB
        ├── Role: Kubernetes Worker
        └── GPU: 0000:01:00.0 (NVIDIA RTX A6000) [SHARED - Cannot run with HPC compute-01]
```

### Error Handling

- Configuration validation errors (clear messages with examples)
- Ansible playbook failures (capture logs, suggest fixes)
- VM provisioning failures (automatic cleanup of partial state)
- Network connectivity issues (retry logic with exponential backoff)

### Validation

```bash
# Full lifecycle test
ai-how cloud start config/cloud-cluster.yaml
# Expected: VMs provision, auto-start VMs running, non-auto-start VMs created but stopped

ai-how cloud status config/cloud-cluster.yaml
# Expected: Detailed status output showing auto_start flags and VM states

ai-how topology
# Expected: Complete infrastructure tree showing all clusters, networks, VMs, and GPUs

# Test auto_start: false functionality
virsh list --all | grep gpu-worker-01
# Expected: VM exists but in 'shut off' state

ai-how vm start cloud-cluster-gpu-worker-01
# Expected: VM starts successfully

ai-how vm status cloud-cluster-gpu-worker-01
# Expected: Shows running state with GPU allocation

# Test cluster restart preserves auto_start state
ai-how cloud stop config/cloud-cluster.yaml
# Expected: Graceful shutdown, all VMs stopped

ai-how cloud start config/cloud-cluster.yaml
# Expected: Auto-start VMs start, non-auto-start VMs remain stopped

ai-how cloud destroy config/cloud-cluster.yaml
# Expected: Confirmation prompt, complete cleanup

# Test GPU conflict avoidance with auto_start
# Configure cloud GPU worker with auto_start: false
ai-how hpc start config/example-multi-gpu-clusters.yaml
ai-how cloud start config/example-multi-gpu-clusters.yaml
# Expected: HPC GPU workers running, Cloud GPU workers created but stopped (no conflict)

ai-how topology
# Expected: Show both clusters, HPC running with GPU allocated, Cloud GPU workers created but not started
```

### Success Criteria

- [ ] All five commands functional and tested (start, stop, status, destroy, topology)
- [ ] `auto_start: false` VMs are created but not started during cluster provisioning
- [ ] `auto_start` flag is preserved in state across cluster restarts
- [ ] Status command clearly indicates VMs with `auto_start: false`
- [ ] Topology command displays complete infrastructure tree with proper formatting
- [ ] GPU conflicts are clearly highlighted in red in topology view
- [ ] Non-started VMs don't allocate GPU resources (no false conflicts)
- [ ] Error messages are clear and actionable
- [ ] Rollback works for failed operations
- [ ] CLI documentation is complete and accurate
- [ ] Integration tests pass for all commands

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-002`

---

## CLOUD-0.3: Shared GPU Resource Management

**Duration:** 4-5 days
**Priority:** HIGH
**Status:** Not Started
**Dependencies:** None (can be developed in parallel with CLOUD-0.1)

### Objective

Implement shared GPU resource management to allow the same physical GPU to be configured for both HPC and Cloud
clusters while enforcing mutual exclusivity at runtime.

### Background: GPU Passthrough Limitations

Based on the current VFIO PCIe passthrough implementation:

- **Exclusive Access**: A physical GPU bound to VFIO can only be assigned to ONE VM at a time
- **No Simultaneous Usage**: Two VMs cannot share the same physical GPU using VFIO passthrough
- **Release on Stop**: When a VM is stopped, the GPU is released and can be assigned to another VM
- **VFIO Binding Required**: GPUs must be unbound from host drivers (nvidia, nouveau) and bound to vfio-pci

**Critical Constraint**: If VM1 (HPC) and VM2 (Cloud) are both configured to use GPU at PCI address `0000:01:00.0`,
only one VM can run at a time. The other VM's cluster must be completely stopped before starting.

### Key Files to Create/Modify

- `python/ai_how/src/ai_how/resource_management/` - New module for shared resource tracking
  - `gpu_allocator.py` - GPU resource allocation and conflict detection
  - `resource_lock.py` - Cluster-level resource locking mechanism
- `python/ai_how/src/ai_how/validation.py` - Extend with shared GPU validation
- `python/ai_how/src/ai_how/state/models.py` - Add GPU resource tracking to ClusterState
- `python/ai_how/src/ai_how/vm_management/hpc_manager.py` - Add GPU conflict checks
- `python/ai_how/src/ai_how/vm_management/cloud_manager.py` - Create with GPU conflict checks

### Deliverables

- [ ] Create `SharedGPUValidator` class to detect GPU sharing in configuration
- [ ] Implement `GPUResourceAllocator` for runtime GPU ownership tracking
- [ ] Add `shared_resources` section to state.json schema
- [ ] Create cluster startup validation that checks GPU availability
- [ ] Implement cluster shutdown GPU resource release
- [ ] Ensure VMs with `auto_start: false` do NOT allocate GPUs during cluster provisioning
- [ ] Add helpful error messages when GPU conflicts are detected
- [ ] Extend `config/example-multi-gpu-clusters.yaml` with shared GPU test configuration

### Test Configuration

For local testing, validation, and integration of the shared GPU resource management feature, we will extend the
existing `config/example-multi-gpu-clusters.yaml` configuration file:

**Purpose**: Create a realistic test scenario where:

- At least one physical GPU is configured in both HPC and Cloud clusters
- This allows testing the mutual exclusivity enforcement
- Validates that error messages are clear when attempting to start conflicting clusters

**Example Extension**:

```yaml
# In config/example-multi-gpu-clusters.yaml

clusters:
  hpc:
    compute_nodes:
      - cpu_cores: 8
        memory_gb: 16
        disk_gb: 200
        ip: "192.168.100.11"
        # auto_start defaults to true
        pcie_passthrough:
          enabled: true
          devices:
            # Shared GPU - will also be used in Cloud cluster
            - pci_address: "0000:01:00.0"
              device_type: "gpu"
              vendor_id: "10de"
              device_id: "2805"

  cloud:
    worker_nodes:
      gpu:
        - worker_type: "gpu"
          cpu_cores: 8
          memory_gb: 16
          disk_gb: 200
          ip: "192.168.200.12"
          auto_start: false  # Prevent GPU conflict - VM created but not started
          pcie_passthrough:
            enabled: true
            devices:
              # Same GPU as HPC compute node - but won't conflict due to auto_start: false
              - pci_address: "0000:01:00.0"
                device_type: "gpu"
                vendor_id: "10de"
                device_id: "2805"
```

**Test Scenarios**:

1. Start HPC cluster → Verify GPU allocated to HPC compute node
2. Start Cloud cluster → Should succeed because GPU worker has `auto_start: false`
3. Verify Cloud GPU worker is created but not started (no GPU allocation)
4. Verify both clusters running simultaneously without GPU conflict
5. Manually start Cloud GPU worker → Should fail due to GPU conflict with HPC
6. Stop HPC cluster → Verify GPU released
7. Manually start Cloud GPU worker → Should succeed now that GPU is available
8. Verify state tracking in `output/global-state.json`

### Implementation Details

**Step 1: Configuration Validation (Detect Shared GPUs)**

```python
# In validation.py or new shared_gpu_validator.py

class SharedGPUValidator:
    """Validates GPU sharing configuration between clusters."""

    def detect_shared_gpus(self, config_data: dict) -> dict[str, list[str]]:
        """Detect GPUs that are shared between clusters.

        Returns:
            Dictionary mapping PCI addresses to list of cluster names using them
            Example: {"0000:01:00.0": ["hpc-cluster", "cloud-cluster"]}
        """
        gpu_usage = {}

        # Scan HPC cluster
        if "hpc" in config_data.get("clusters", {}):
            hpc_config = config_data["clusters"]["hpc"]
            gpus = self._extract_gpu_addresses(hpc_config)
            for gpu_addr in gpus:
                gpu_usage.setdefault(gpu_addr, []).append("hpc")

        # Scan Cloud cluster
        if "cloud" in config_data.get("clusters", {}):
            cloud_config = config_data["clusters"]["cloud"]
            gpus = self._extract_gpu_addresses(cloud_config)
            for gpu_addr in gpus:
                gpu_usage.setdefault(gpu_addr, []).append("cloud")

        # Return only shared GPUs (used by multiple clusters)
        return {addr: clusters for addr, clusters in gpu_usage.items() if len(clusters) > 1}

    def _extract_gpu_addresses(self, cluster_config: dict) -> list[str]:
        """Extract all GPU PCI addresses from cluster configuration."""
        gpu_addresses = []

        # Check controller
        if "controller" in cluster_config:
            pcie = cluster_config["controller"].get("pcie_passthrough", {})
            gpu_addresses.extend(self._get_gpu_devices(pcie))

        # Check compute nodes
        for node in cluster_config.get("compute_nodes", []):
            pcie = node.get("pcie_passthrough", {})
            gpu_addresses.extend(self._get_gpu_devices(pcie))

        # Check worker nodes (for cloud)
        for worker_type, nodes in cluster_config.get("worker_nodes", {}).items():
            for node in nodes:
                pcie = node.get("pcie_passthrough", {})
                gpu_addresses.extend(self._get_gpu_devices(pcie))

        return gpu_addresses

    def _get_gpu_devices(self, pcie_config: dict) -> list[str]:
        """Extract GPU device addresses from PCIe configuration."""
        if not pcie_config.get("enabled", False):
            return []

        return [
            device["pci_address"]
            for device in pcie_config.get("devices", [])
            if device.get("device_type") == "gpu"
        ]
```

**Step 2: State Management (Track GPU Ownership)**

```python
# Extend state/models.py - Add to ClusterState

@dataclass
class SharedResourceState:
    """Tracks shared resource allocation between clusters."""

    gpu_allocations: dict[str, str] = field(default_factory=dict)  # pci_address -> cluster_name
    last_updated: datetime = field(default_factory=datetime.now)

    def to_dict(self) -> dict[str, Any]:
        return {
            "gpu_allocations": self.gpu_allocations,
            "last_updated": self.last_updated.isoformat()
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "SharedResourceState":
        return cls(
            gpu_allocations=data.get("gpu_allocations", {}),
            last_updated=datetime.fromisoformat(data["last_updated"])
        )


# Update ClusterState to include shared resources
@dataclass
class ClusterState:
    # ... existing fields ...
    shared_resources: SharedResourceState | None = None

    # Add method to allocate GPU
    def allocate_gpu(self, pci_address: str, cluster_name: str) -> None:
        """Mark a GPU as allocated to a cluster."""
        if self.shared_resources is None:
            self.shared_resources = SharedResourceState()
        self.shared_resources.gpu_allocations[pci_address] = cluster_name
        self.shared_resources.last_updated = datetime.now()

    # Add method to release GPU
    def release_gpu(self, pci_address: str) -> None:
        """Release GPU allocation."""
        if self.shared_resources and pci_address in self.shared_resources.gpu_allocations:
            del self.shared_resources.gpu_allocations[pci_address]
            self.shared_resources.last_updated = datetime.now()

    # Add method to check GPU availability
    def is_gpu_available(self, pci_address: str, requesting_cluster: str) -> bool:
        """Check if a GPU is available for use by the requesting cluster."""
        if self.shared_resources is None:
            return True

        current_owner = self.shared_resources.gpu_allocations.get(pci_address)
        return current_owner is None or current_owner == requesting_cluster
```

**Step 3: Runtime Validation (Cluster Start)**

```python
# In hpc_manager.py and cloud_manager.py

class HPCClusterManager:
    def _validate_gpu_availability(self) -> None:
        """Validate that required GPUs are available before starting cluster."""

        # Get list of GPUs needed by this cluster
        required_gpus = self._get_required_gpus()

        if not required_gpus:
            return  # No GPUs required

        # Load global state
        global_state_path = self.state_file.parent / "global-state.json"
        global_state = self._load_global_state(global_state_path)

        # Check each GPU
        for pci_address in required_gpus:
            if not global_state.is_gpu_available(pci_address, self.cluster_name):
                current_owner = global_state.shared_resources.gpu_allocations[pci_address]
                raise HPCManagerError(
                    f"GPU {pci_address} is currently allocated to cluster '{current_owner}'. "
                    f"Stop the '{current_owner}' cluster before starting '{self.cluster_name}'. "
                    f"\n\nCommand to stop conflicting cluster:\n"
                    f"  ai-how {current_owner.split('-')[0]} stop config/{current_owner}.yaml"
                )

    def _allocate_cluster_gpus(self) -> None:
        """Allocate GPUs to this cluster in global state.
        
        Only allocates GPUs for VMs that are actually started.
        VMs with auto_start: false do NOT allocate GPUs.
        """
        required_gpus = self._get_required_gpus_for_started_vms()

        if not required_gpus:
            return

        global_state_path = self.state_file.parent / "global-state.json"
        global_state = self._load_global_state(global_state_path)

        for pci_address in required_gpus:
            global_state.allocate_gpu(pci_address, self.cluster_name)

        self._save_global_state(global_state_path, global_state)

    def _get_required_gpus_for_started_vms(self) -> list[str]:
        """Get GPU addresses for VMs that are actually started.
        
        Returns:
            List of PCI addresses for GPUs in running VMs only.
            VMs with auto_start: false are excluded.
        """
        gpu_addresses = []
        
        cluster_state = self.state_manager.get_state()
        if not cluster_state:
            return gpu_addresses
        
        for vm in cluster_state.get_all_vms():
            # Skip VMs that are not started
            if not vm.is_started or (hasattr(vm, 'auto_start') and not vm.auto_start):
                continue
            
            # Extract GPU address if VM has GPU assigned
            if vm.gpu_assigned:
                pci_address = self._extract_pci_address(vm.gpu_assigned)
                if pci_address:
                    gpu_addresses.append(pci_address)
        
        return gpu_addresses

    def _release_cluster_gpus(self) -> None:
        """Release GPUs from this cluster in global state."""
        required_gpus = self._get_required_gpus()

        if not required_gpus:
            return

        global_state_path = self.state_file.parent / "global-state.json"
        global_state = self._load_global_state(global_state_path)

        for pci_address in required_gpus:
            global_state.release_gpu(pci_address)

        self._save_global_state(global_state_path, global_state)
```

**Step 4: Integration with Cluster Lifecycle**

```python
# Modify start_cluster() in hpc_manager.py

def _execute_cluster_start(self) -> bool:
    """Execute cluster start operation."""
    try:
        logger.info("Starting HPC cluster")

        # STEP 1: Validate GPU availability (NEW)
        self._validate_gpu_availability()

        # STEP 2: Validate cluster configuration
        self._validate_cluster_config()

        # STEP 3: Check prerequisites
        self._check_prerequisites()

        # STEP 4: Create cluster infrastructure
        self._create_cluster_infrastructure()

        # STEP 5: Allocate GPUs to this cluster (NEW)
        self._allocate_cluster_gpus()

        logger.info("HPC cluster started successfully")
        return True

    except Exception as e:
        logger.error(f"Failed to start HPC cluster: {e}")
        raise


# Modify stop_cluster() in hpc_manager.py

def _execute_cluster_stop(self) -> bool:
    """Execute cluster stop operation."""
    try:
        logger.info("Stopping HPC cluster")

        cluster_state = self.state_manager.get_state()
        if not cluster_state:
            logger.info("No cluster state found, nothing to stop")
            return True

        # Stop all VMs
        all_vms = cluster_state.get_all_vms()
        for vm in all_vms:
            try:
                if self.vm_lifecycle.get_vm_state(vm.name) == VMState.RUNNING:
                    self.vm_lifecycle.stop_vm(vm.name, force=False)
                    vm.update_state(VMState.SHUTOFF)
            except VMLifecycleError as e:
                logger.warning(f"Failed to stop VM {vm.name}: {e}")

        # Release GPUs from this cluster (NEW)
        self._release_cluster_gpus()

        # Update state
        self.state_manager.save_state(cluster_state)

        logger.info("HPC cluster stopped successfully")
        return True

    except Exception as e:
        logger.error(f"Failed to stop HPC cluster: {e}")
        raise
```

### Validation

```bash
# Test 1: Configure shared GPU with auto_start: false in Cloud cluster
# Use config/example-multi-gpu-clusters.yaml with Cloud GPU worker auto_start: false

# Test 2: Start HPC cluster (should succeed, GPU allocated)
ai-how hpc start config/example-multi-gpu-clusters.yaml

# Test 3: Start Cloud cluster (should succeed, GPU worker created but not started)
ai-how cloud start config/example-multi-gpu-clusters.yaml
# Expected: Success, Cloud GPU worker created but remains in shutoff state

# Test 4: Verify GPU ownership (only HPC should have GPU allocated)
cat output/global-state.json | jq '.shared_resources.gpu_allocations'
# Expected: {"0000:01:00.0": "hpc-cluster-compute-01"}

# Test 5: Verify Cloud GPU worker is created but not running
virsh list --all | grep cloud-cluster-gpu-worker

# Test 6: Try to manually start Cloud GPU worker (should fail - GPU conflict)
ai-how vm start cloud-cluster-gpu-worker-01
# Expected: Error about GPU conflict with HPC cluster

# Test 7: Stop HPC cluster (releases GPU)
ai-how hpc stop config/example-multi-gpu-clusters.yaml

# Test 8: Verify GPU released
cat output/global-state.json | jq '.shared_resources.gpu_allocations'
# Expected: {}

# Test 9: Start Cloud GPU worker (should now succeed)
ai-how vm start cloud-cluster-gpu-worker-01

# Test 10: Verify GPU now allocated to Cloud
cat output/global-state.json | jq '.shared_resources.gpu_allocations'
# Expected: {"0000:01:00.0": "cloud-cluster-gpu-worker-01"}
```

### Success Criteria

- [ ] Configuration with shared GPUs is validated correctly
- [ ] VMs with `auto_start: false` do NOT allocate GPUs during cluster provisioning
- [ ] Multiple clusters can coexist when GPU VMs have `auto_start: false`
- [ ] Manually starting VM with GPU checks availability and enforces exclusivity
- [ ] Starting second cluster with shared GPU fails with clear error message (when auto_start: true)
- [ ] Stopping cluster releases GPU resources for other clusters
- [ ] Global state accurately tracks GPU ownership
- [ ] Error messages clearly explain conflict and how to resolve it
- [ ] Documentation explains GPU sharing limitations and `auto_start` usage

### Important Note: Why Not Simultaneous Usage?

**Question**: Can one VM be stopped while another is running when they share the same GPU?

**Answer**: No, with VFIO GPU passthrough:

1. **GPU is exclusively bound**: The physical GPU is bound to `vfio-pci` driver
2. **Single VM ownership**: Only ONE VM can attach to the VFIO device at a time
3. **Stop-then-start workflow**: VM1 must be completely stopped and its GPU released before VM2 can start
4. **No hot-swap**: Cannot transfer GPU from one running VM to another without stopping the first VM

**Workaround**: To switch GPU usage between clusters:

```bash
# Stop HPC cluster first
ai-how hpc stop config/cluster.yaml

# Wait for GPU release (automatic)

# Start Cloud cluster
ai-how cloud start config/cluster.yaml
```

**Alternative Technology**: NVIDIA vGPU (requires enterprise GPU hardware) would allow multiple VMs to share
a GPU simultaneously, but this is NOT supported by the current VFIO passthrough implementation.

---

## CLOUD-0.4: Enhanced VM Lifecycle Management

**Duration:** 3-4 days
**Priority:** HIGH
**Status:** Not Started
**Dependencies:** CLOUD-0.3

### Objective

Improve VM lifecycle management to support individual VM stop/start/restart operations with proper GPU resource
handling, enabling more granular cluster control.

### Current State Issues

- VM stop/start exists in `VMLifecycleManager` but not exposed at cluster level
- No GPU resource tracking for individual VMs
- No support for restarting individual VMs without affecting entire cluster
- VM state updates don't account for GPU resource changes

### Key Files to Modify

- `python/ai_how/src/ai_how/cli.py` - Add individual VM control commands
- `python/ai_how/src/ai_how/vm_management/vm_lifecycle.py` - Enhance with GPU awareness
- `python/ai_how/src/ai_how/vm_management/hpc_manager.py` - Add individual VM methods
- `python/ai_how/src/ai_how/state/models.py` - Track per-VM GPU allocation

### Deliverables

- [ ] Add CLI commands for individual VM control (`ai-how vm stop/start/restart`)
- [ ] Implement GPU resource release on individual VM stop
- [ ] Implement GPU resource allocation on individual VM start
- [ ] Add VM restart with automatic GPU rebinding
- [ ] Update state tracking for individual VM operations
- [ ] Add validation to prevent starting VMs with conflicted GPUs

### Implementation Details

**Step 1: Enhanced VMLifecycleManager**

```python
# Extend vm_lifecycle.py

class VMLifecycleManager:
    """Manages VM creation, start, stop, destroy operations with GPU awareness."""

    def __init__(self, libvirt_client: LibvirtClient | None = None,
                 state_manager: ClusterStateManager | None = None):
        """Initialize VM lifecycle manager.

        Args:
            libvirt_client: libvirt client instance
            state_manager: State manager for GPU resource tracking
        """
        self.client = libvirt_client or LibvirtClient()
        self.state_manager = state_manager

    def stop_vm_with_gpu_release(self, vm_name: str, force: bool = False) -> bool:
        """Stop VM and release its GPU resources.

        Args:
            vm_name: Name of the VM to stop
            force: Whether to force stop

        Returns:
            True if VM stopped successfully

        Raises:
            VMLifecycleError: If VM stop fails
        """
        try:
            # Get VM info to find GPU assignments
            vm_info = self._get_vm_info(vm_name)

            # Stop the VM using existing method
            success = self.stop_vm(vm_name, force=force)

            if success and vm_info and vm_info.gpu_assigned:
                # Extract PCI address from gpu_assigned string
                pci_address = self._extract_pci_address(vm_info.gpu_assigned)
                if pci_address:
                    # Release GPU in global state
                    self._release_vm_gpu(pci_address)
                    logger.info(f"Released GPU {pci_address} from VM {vm_name}")

            return success

        except Exception as e:
            logger.error(f"Failed to stop VM with GPU release: {e}")
            raise VMLifecycleError(f"Failed to stop VM {vm_name}: {e}") from e

    def start_vm_with_gpu_allocation(self, vm_name: str, wait_for_boot: bool = True) -> bool:
        """Start VM and allocate its GPU resources.

        Args:
            vm_name: Name of the VM to start
            wait_for_boot: Whether to wait for boot completion

        Returns:
            True if VM started successfully

        Raises:
            VMLifecycleError: If VM start fails or GPU unavailable
        """
        try:
            # Get VM info to find GPU assignments
            vm_info = self._get_vm_info(vm_name)

            if vm_info and vm_info.gpu_assigned:
                # Extract PCI address
                pci_address = self._extract_pci_address(vm_info.gpu_assigned)
                if pci_address:
                    # Check GPU availability
                    if not self._is_gpu_available(pci_address):
                        current_owner = self._get_gpu_owner(pci_address)
                        raise VMLifecycleError(
                            f"GPU {pci_address} is currently allocated to {current_owner}. "
                            f"Stop that VM before starting {vm_name}."
                        )

                    # Allocate GPU
                    self._allocate_vm_gpu(vm_name, pci_address)

            # Start the VM using existing method
            success = self.start_vm(vm_name, wait_for_boot=wait_for_boot)

            return success

        except Exception as e:
            logger.error(f"Failed to start VM with GPU allocation: {e}")
            # Cleanup: release GPU if start failed
            if vm_info and vm_info.gpu_assigned:
                pci_address = self._extract_pci_address(vm_info.gpu_assigned)
                if pci_address:
                    self._release_vm_gpu(pci_address)
            raise VMLifecycleError(f"Failed to start VM {vm_name}: {e}") from e

    def restart_vm(self, vm_name: str, wait_for_boot: bool = True) -> bool:
        """Restart VM with GPU resource management.

        Args:
            vm_name: Name of the VM to restart
            wait_for_boot: Whether to wait for boot completion

        Returns:
            True if VM restarted successfully

        Raises:
            VMLifecycleError: If VM restart fails
        """
        try:
            logger.info(f"Restarting VM: {vm_name}")

            # Stop VM with GPU release
            self.stop_vm_with_gpu_release(vm_name, force=False)

            # Wait a moment for clean shutdown
            import time
            time.sleep(2)

            # Start VM with GPU allocation
            self.start_vm_with_gpu_allocation(vm_name, wait_for_boot=wait_for_boot)

            logger.info(f"VM {vm_name} restarted successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to restart VM {vm_name}: {e}")
            raise VMLifecycleError(f"Failed to restart VM {vm_name}: {e}") from e

    def _get_vm_info(self, vm_name: str) -> VMInfo | None:
        """Get VM info from state manager."""
        if self.state_manager:
            return self.state_manager.get_vm(vm_name)
        return None

    def _extract_pci_address(self, gpu_assigned: str) -> str | None:
        """Extract PCI address from gpu_assigned string.

        Args:
            gpu_assigned: String like "0000:01:00.0 (10de:2204)" or "NVIDIA RTX A6000"

        Returns:
            PCI address or None
        """
        import re
        # Match PCI address pattern
        match = re.search(r'([0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7])', gpu_assigned)
        return match.group(1) if match else None

    def _is_gpu_available(self, pci_address: str) -> bool:
        """Check if GPU is available for allocation."""
        # Load global state and check
        global_state_path = Path("output/global-state.json")
        if global_state_path.exists():
            with open(global_state_path) as f:
                data = json.load(f)
                allocations = data.get("shared_resources", {}).get("gpu_allocations", {})
                return pci_address not in allocations
        return True

    def _get_gpu_owner(self, pci_address: str) -> str:
        """Get current owner of a GPU."""
        global_state_path = Path("output/global-state.json")
        if global_state_path.exists():
            with open(global_state_path) as f:
                data = json.load(f)
                allocations = data.get("shared_resources", {}).get("gpu_allocations", {})
                return allocations.get(pci_address, "unknown")
        return "unknown"

    def _allocate_vm_gpu(self, vm_name: str, pci_address: str) -> None:
        """Allocate GPU to a specific VM."""
        global_state_path = Path("output/global-state.json")
        global_state = self._load_global_state(global_state_path)
        global_state.allocate_gpu(pci_address, vm_name)
        self._save_global_state(global_state_path, global_state)

    def _release_vm_gpu(self, pci_address: str) -> None:
        """Release GPU from VM."""
        global_state_path = Path("output/global-state.json")
        global_state = self._load_global_state(global_state_path)
        global_state.release_gpu(pci_address)
        self._save_global_state(global_state_path, global_state)
```

**Step 2: CLI Commands for Individual VM Control**

```python
# Add to cli.py

vm_app = typer.Typer(help="Individual VM lifecycle management")
app.add_typer(vm_app, name="vm")


@vm_app.command("stop")
def vm_stop(
    ctx: typer.Context,
    vm_name: Annotated[str, typer.Argument(help="Name of the VM to stop")],
    force: Annotated[bool, typer.Option("--force", help="Force stop the VM")] = False,
) -> None:
    """Stop an individual VM with GPU resource release."""
    state_path = ctx.obj["state"]

    console.print(f"Stopping VM: {vm_name}")

    try:
        # Load state to determine which cluster the VM belongs to
        state_manager = ClusterStateManager(state_path)
        vm_info = state_manager.get_vm(vm_name)

        if not vm_info:
            console.print(f"[red]Error:[/red] VM '{vm_name}' not found in state")
            raise typer.Exit(code=1)

        # Initialize lifecycle manager with state manager
        libvirt_client = LibvirtClient()
        vm_lifecycle = VMLifecycleManager(libvirt_client, state_manager)

        # Stop VM with GPU release
        success = vm_lifecycle.stop_vm_with_gpu_release(vm_name, force=force)

        if success:
            # Update VM state
            state_manager.update_vm_state(vm_name, VMState.SHUTOFF)
            state_manager.save_state()
            console.print(f"[green]✅ VM '{vm_name}' stopped successfully[/green]")
        else:
            console.print(f"[red]❌ Failed to stop VM '{vm_name}'[/red]")
            raise typer.Exit(code=1)

    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e


@vm_app.command("start")
def vm_start(
    ctx: typer.Context,
    vm_name: Annotated[str, typer.Argument(help="Name of the VM to start")],
    no_wait: Annotated[bool, typer.Option("--no-wait", help="Don't wait for boot")] = False,
) -> None:
    """Start an individual VM with GPU resource allocation."""
    state_path = ctx.obj["state"]

    console.print(f"Starting VM: {vm_name}")

    try:
        # Load state
        state_manager = ClusterStateManager(state_path)
        vm_info = state_manager.get_vm(vm_name)

        if not vm_info:
            console.print(f"[red]Error:[/red] VM '{vm_name}' not found in state")
            raise typer.Exit(code=1)

        # Initialize lifecycle manager
        libvirt_client = LibvirtClient()
        vm_lifecycle = VMLifecycleManager(libvirt_client, state_manager)

        # Start VM with GPU allocation
        success = vm_lifecycle.start_vm_with_gpu_allocation(vm_name, wait_for_boot=not no_wait)

        if success:
            # Update VM state
            state_manager.update_vm_state(vm_name, VMState.RUNNING)
            state_manager.save_state()
            console.print(f"[green]✅ VM '{vm_name}' started successfully[/green]")
        else:
            console.print(f"[red]❌ Failed to start VM '{vm_name}'[/red]")
            raise typer.Exit(code=1)

    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e


@vm_app.command("restart")
def vm_restart(
    ctx: typer.Context,
    vm_name: Annotated[str, typer.Argument(help="Name of the VM to restart")],
    no_wait: Annotated[bool, typer.Option("--no-wait", help="Don't wait for boot")] = False,
) -> None:
    """Restart an individual VM with GPU resource management."""
    state_path = ctx.obj["state"]

    console.print(f"Restarting VM: {vm_name}")

    try:
        # Load state
        state_manager = ClusterStateManager(state_path)
        vm_info = state_manager.get_vm(vm_name)

        if not vm_info:
            console.print(f"[red]Error:[/red] VM '{vm_name}' not found in state")
            raise typer.Exit(code=1)

        # Initialize lifecycle manager
        libvirt_client = LibvirtClient()
        vm_lifecycle = VMLifecycleManager(libvirt_client, state_manager)

        # Restart VM
        success = vm_lifecycle.restart_vm(vm_name, wait_for_boot=not no_wait)

        if success:
            console.print(f"[green]✅ VM '{vm_name}' restarted successfully[/green]")
        else:
            console.print(f"[red]❌ Failed to restart VM '{vm_name}'[/red]")
            raise typer.Exit(code=1)

    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e


@vm_app.command("status")
def vm_status(
    ctx: typer.Context,
    vm_name: Annotated[str, typer.Argument(help="Name of the VM")],
) -> None:
    """Show detailed status of an individual VM."""
    state_path = ctx.obj["state"]

    try:
        # Load state
        state_manager = ClusterStateManager(state_path)
        vm_info = state_manager.get_vm(vm_name)

        if not vm_info:
            console.print(f"[red]Error:[/red] VM '{vm_name}' not found in state")
            raise typer.Exit(code=1)

        # Get current libvirt state
        libvirt_client = LibvirtClient()
        vm_lifecycle = VMLifecycleManager(libvirt_client)
        current_state = vm_lifecycle.get_vm_state(vm_name)

        # Display status
        table = Table(title=f"VM Status: {vm_name}")
        table.add_column("Property", style="cyan")
        table.add_column("Value", style="white")

        table.add_row("Name", vm_name)
        table.add_row("UUID", vm_info.domain_uuid)
        table.add_row("Type", vm_info.vm_type)
        table.add_row("State", f"[{'green' if current_state == VMState.RUNNING else 'yellow'}]"
                              f"{current_state.value}[/]")
        table.add_row("CPU Cores", str(vm_info.cpu_cores))
        table.add_row("Memory (GB)", str(vm_info.memory_gb))
        table.add_row("Volume Path", str(vm_info.volume_path))
        table.add_row("IP Address", vm_info.ip_address or "Not assigned")
        table.add_row("GPU", vm_info.gpu_assigned or "None")

        console.print(table)

    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
```

### Validation

```bash
# Test 1: Stop individual VM from running cluster
ai-how hpc start config/cluster.yaml
ai-how vm stop hpc-cluster-compute-01
ai-how hpc status config/cluster.yaml  # Should show compute-01 as stopped

# Test 2: Start stopped VM
ai-how vm start hpc-cluster-compute-01
ai-how vm status hpc-cluster-compute-01  # Should show running

# Test 3: Restart VM
ai-how vm restart hpc-cluster-compute-01

# Test 4: Stop VM with GPU, start different VM with same GPU
ai-how vm stop hpc-cluster-compute-01  # Has GPU 0000:01:00.0
ai-how vm start cloud-cluster-gpu-worker-01  # Also uses GPU 0000:01:00.0

# Test 5: Try to start both VMs with same GPU (should fail)
ai-how vm start hpc-cluster-compute-01
# Expected: Error about GPU conflict

# Test 6: Check GPU allocation status
cat output/global-state.json | jq '.shared_resources.gpu_allocations'
```

### Success Criteria

- [ ] Individual VMs can be stopped/started/restarted independently
- [ ] GPU resources are correctly released on VM stop
- [ ] GPU resources are correctly allocated on VM start
- [ ] Error messages clearly indicate GPU conflicts
- [ ] State tracking accurately reflects VM and GPU status
- [ ] CLI commands work for both HPC and Cloud cluster VMs

---

## Phase Completion Checklist

- [ ] CLOUD-0.1: VM Management Extension complete
- [ ] CLOUD-0.2: CLI Commands implemented
- [ ] CLOUD-0.3: Shared GPU Resource Management complete
- [ ] CLOUD-0.4: Enhanced VM Lifecycle Management complete
- [ ] All validation tests pass
- [ ] Documentation updated
- [ ] Code reviewed and merged

## Summary of Key Questions Answered

### Q1: Can the same physical GPU be assigned to both HPC and Cloud clusters?

**Answer: Yes**, but with mutual exclusivity:

- The configuration file can specify the same GPU PCI address in both clusters
- Only ONE cluster can have the GPU actively allocated at a time
- Use `auto_start: false` to create VMs without allocating GPUs
- This allows both clusters to exist simultaneously with only one actively using the GPU

### Q2: If both clusters share a GPU, can only one cluster be active at a time?

**Answer: Both clusters can be active, but only one can use the GPU**:

- With `auto_start: false`, VMs can be created without allocating GPUs
- Multiple clusters can run simultaneously if GPU VMs are not started
- Only when a GPU VM is actually started does it allocate the GPU resource
- The GPU resource management system enforces mutual exclusivity at the VM level
- Runtime validation checks GPU availability before starting a GPU-enabled VM
- Global state tracks which VM currently owns each GPU

### Q3: Can one VM be stopped while another is running when they share the same GPU?

**Answer: No, not simultaneously**:

- VFIO GPU passthrough provides exclusive access to ONE VM at a time
- When VM1 is running with a GPU, the GPU is bound to that VM
- VM2 cannot start until VM1 is stopped and releases the GPU
- However, you CAN stop VM1 first, then start VM2 (sequential usage)

**Workflow for switching GPU between VMs**:

```bash
# Stop VM1 (releases GPU automatically)
ai-how vm stop hpc-cluster-compute-01

# Start VM2 (allocates the now-available GPU)
ai-how vm start cloud-cluster-gpu-worker-01
```

### Q4: How do I create VMs but not start them to avoid GPU conflicts?

**Answer: Use `auto_start: false` in VM configuration**:

```yaml
gpu:
  - worker_type: "gpu"
    cpu_cores: 8
    memory_gb: 16
    disk_gb: 200
    ip: "192.168.200.12"
    auto_start: false  # VM created but not started
    pcie_passthrough:
      enabled: true
      devices:
        - pci_address: "0000:01:00.0"
```

**Behavior**:

- VM is created with all resources allocated (disk, network, etc.)
- VM remains in `shutoff` state and does NOT start automatically
- GPU is NOT allocated during cluster provisioning
- Allows multiple clusters to coexist with shared GPU configuration
- VM can be manually started later with `ai-how vm start <vm-name>`
- When manually started, GPU allocation is checked and enforced

**Use Case Example**:

```bash
# Create both clusters (HPC GPU running, Cloud GPU created but stopped)
ai-how hpc start config/cluster.yaml
ai-how cloud start config/cluster.yaml  # Cloud GPU worker has auto_start: false

# Both clusters running, no GPU conflict
# HPC has the GPU, Cloud GPU worker exists but is stopped

# Later, switch to inference:
ai-how hpc stop config/cluster.yaml
ai-how vm start cloud-cluster-gpu-worker-01  # Now GPU is available
```

### Q5: What VM stop/restart capabilities are supported?

**Answer: Full individual VM control**:

- `ai-how vm stop <vm-name>` - Stop individual VM with GPU release
- `ai-how vm start <vm-name>` - Start individual VM with GPU allocation
- `ai-how vm restart <vm-name>` - Restart VM with automatic GPU rebinding
- `ai-how vm status <vm-name>` - Check VM status including GPU assignment
- Works for VMs in both HPC and Cloud clusters
- Proper GPU resource management with conflict detection

## Technical Details

### GPU Passthrough Limitations

The current implementation uses VFIO PCIe passthrough, which has these constraints:

1. **Exclusive Binding**: GPU must be unbound from host drivers (nvidia/nouveau) and bound to vfio-pci
2. **Single VM Access**: Only one VM can attach to a VFIO device at any time
3. **No Hot-Swap**: Cannot transfer GPU from running VM to another without stopping first
4. **Sequential Usage Only**: Must use stop-then-start workflow to switch GPUs between VMs

### Alternative Technology (Not Implemented)

NVIDIA vGPU technology would allow true simultaneous GPU sharing:

- Multiple VMs can run concurrently with vGPU instances from the same physical GPU
- Requires enterprise GPU hardware (e.g., NVIDIA A100, H100 with vGPU license)
- Would require significant re-architecture of the current VFIO-based implementation
- Currently NOT supported by this project

### Resource Tracking Architecture

```text
output/
├── state.json              # Per-cluster state (HPC cluster)
├── cloud-state.json        # Per-cluster state (Cloud cluster)
└── global-state.json       # NEW: Cross-cluster GPU resource tracking
    └── shared_resources:
        └── gpu_allocations:
            "0000:01:00.0": "hpc-cluster-compute-01"  # Which VM owns this GPU
```

## Next Phase

Proceed to [Phase 1: Packer Images](01-packer-images-phase.md)
