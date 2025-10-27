# Phase 0: Cloud Cluster Foundation

**Duration:** 2 weeks
**Tasks:** CLOUD-0.1, CLOUD-0.2
**Dependencies:** None (can start immediately)

## Overview

Establish the foundational infrastructure for cloud cluster management by extending the existing HPC VM management
system to support Kubernetes-based cloud clusters. This phase creates the core VM lifecycle management and CLI
integration needed for all subsequent phases.

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
        "role": "kubernetes-control-plane"
      },
      "gpu-worker-1": {
        "vm_id": "cloud-gpu-worker-1-uuid",
        "ip": "192.168.200.12",
        "role": "kubernetes-worker",
        "gpu": "NVIDIA RTX A6000"
      }
    }
  }
}
```

**XML Template Differences from HPC:**

- No SLURM-specific configuration
- Kubernetes networking requirements (bridge mode)
- Different resource allocations (control plane vs workers)
- Optional GPU passthrough (only for GPU workers)

### Validation

```bash
# Test VM provisioning
ai-how cloud start config/cloud-cluster.yaml

# Verify state tracking
cat output/state.json | jq '.cloud_cluster'

# Check VM status
ai-how cloud status config/cloud-cluster.yaml

# Test lifecycle
ai-how cloud stop config/cloud-cluster.yaml
ai-how cloud start config/cloud-cluster.yaml
```

### Success Criteria

- [ ] VMs provision successfully from cloud cluster configuration
- [ ] State is tracked accurately in state.json
- [ ] VMs have correct network configuration for Kubernetes
- [ ] GPU passthrough works for GPU worker nodes
- [ ] Lifecycle operations (start/stop) work reliably

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
- [ ] Add comprehensive error handling and rollback mechanisms
- [ ] Update CLI documentation with examples

### Implementation Details

**Command: `cloud start`**

```python
# Workflow:
1. Validate cluster configuration (cluster.yaml)
2. Provision VMs using CloudVMManager (CLOUD-0.1)
3. Wait for VMs to boot and become SSH-accessible
4. Generate Kubespray inventory from cluster.yaml
5. Execute Ansible playbook: deploy-cloud-cluster.yml
6. Validate Kubernetes cluster health
7. Update state.json with cluster status
```

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
- Kubernetes cluster status (if running)
- Node roles and IPs
- GPU allocation (for GPU workers)
- Resource utilization summary
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

### Error Handling

- Configuration validation errors (clear messages with examples)
- Ansible playbook failures (capture logs, suggest fixes)
- VM provisioning failures (automatic cleanup of partial state)
- Network connectivity issues (retry logic with exponential backoff)

### Validation

```bash
# Full lifecycle test
ai-how cloud start config/cloud-cluster.yaml
# Expected: VMs provision, Kubernetes cluster deploys, status shows healthy

ai-how cloud status config/cloud-cluster.yaml
# Expected: Detailed status output

ai-how cloud stop config/cloud-cluster.yaml
# Expected: Graceful shutdown, VMs stopped

ai-how cloud start config/cloud-cluster.yaml
# Expected: Cluster restarts successfully

ai-how cloud destroy config/cloud-cluster.yaml
# Expected: Confirmation prompt, complete cleanup
```

### Success Criteria

- [ ] All four commands functional and tested
- [ ] Error messages are clear and actionable
- [ ] Rollback works for failed operations
- [ ] CLI documentation is complete and accurate
- [ ] Integration tests pass for all commands

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-002`

---

## Phase Completion Checklist

- [ ] CLOUD-0.1: VM Management Extension complete
- [ ] CLOUD-0.2: CLI Commands implemented
- [ ] All validation tests pass
- [ ] Documentation updated
- [ ] Code reviewed and merged

## Next Phase

Proceed to [Phase 1: Packer Images](01-packer-images-phase.md)
