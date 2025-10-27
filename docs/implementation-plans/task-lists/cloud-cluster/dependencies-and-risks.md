# Cloud Cluster Dependencies and Risks

**Last Updated:** 2025-10-27

## Overview

This document outlines task dependencies, external dependencies, potential risks, and mitigation strategies for the
cloud cluster implementation.

---

## Task Dependencies

### Phase Dependencies

```text
Phase 0 (Foundation)
  └─> Phase 1 (Packer Images)
      └─> Phase 2 (Kubernetes)
          ├─> Phase 3 (MLOps Stack)
          │   └─> Phase 5 (Oumi Integration)
          │       └─> Phase 6 (Integration)
          └─> Phase 4 (Monitoring)
              └─> Phase 6 (Integration)

Phase 7 (Testing) can proceed in parallel after Phase 0
```

### Detailed Task Dependencies

| Task | Depends On | Blocks | Can Start After |
|------|------------|--------|-----------------|
| **CLOUD-0.1** | None | CLOUD-0.2, CLOUD-1.1 | Immediately |
| **CLOUD-0.2** | CLOUD-0.1 | CLOUD-2.1, CLOUD-7.1 | Phase 0 (Week 1) |
| **CLOUD-1.1** | CLOUD-0.1 | CLOUD-1.2, CLOUD-2.1 | Phase 0 (Week 1) |
| **CLOUD-1.2** | CLOUD-1.1 | None (optional) | Phase 1 (Week 2) |
| **CLOUD-2.1** | CLOUD-0.2, CLOUD-1.1 | CLOUD-2.2, CLOUD-3.x | Phase 2 (Week 3) |
| **CLOUD-2.2** | CLOUD-2.1 | CLOUD-4.1 | Phase 2 (Week 4) |
| **CLOUD-3.1** | CLOUD-2.1 | CLOUD-3.3 | Phase 3 (Week 5) |
| **CLOUD-3.2** | CLOUD-2.1 | CLOUD-3.3 | Phase 3 (Week 5) |
| **CLOUD-3.3** | CLOUD-3.1, CLOUD-3.2 | CLOUD-3.4, CLOUD-5.1 | Phase 3 (Week 6) |
| **CLOUD-3.4** | CLOUD-2.2, CLOUD-3.3 | CLOUD-5.1 | Phase 3 (Week 6) |
| **CLOUD-4.1** | CLOUD-2.2 | CLOUD-4.2, CLOUD-6.2 | Phase 4 (Week 7) |
| **CLOUD-4.2** | CLOUD-4.1 | CLOUD-6.2 | Phase 4 (Week 7) |
| **CLOUD-5.1** | CLOUD-3.4 | CLOUD-5.2, CLOUD-6.x | Phase 5 (Week 8) |
| **CLOUD-5.2** | CLOUD-5.1 | None | Phase 5 (Week 9) |
| **CLOUD-6.1** | CLOUD-5.1 | None | Phase 6 (Week 10) |
| **CLOUD-6.2** | CLOUD-4.1, CLOUD-4.2 | None | Phase 6 (Week 10) |
| **CLOUD-6.3** | CLOUD-5.1 | None | Phase 6 (Week 10) |
| **CLOUD-7.1** | CLOUD-0.2 | None | Phase 7 (Week 11) |

### Parallel Execution Opportunities

**Can run in parallel:**

- CLOUD-3.1 (MinIO) + CLOUD-3.2 (PostgreSQL)
- CLOUD-6.1 (Transfer) + CLOUD-6.2 (Monitoring) + CLOUD-6.3 (Performance)
- CLOUD-7.1 (Testing) development can happen alongside implementation

---

## External Dependencies

### Software Dependencies

| Dependency | Version | Source | Risk Level | Mitigation |
|------------|---------|--------|------------|------------|
| Kubespray | v2.29.0+ | github.com/kubernetes-sigs/kubespray | LOW | Pinned version, stable project |
| Kubernetes | 1.28.0 | upstream | LOW | LTS version, well-tested |
| Containerd | 1.7.23+ | containerd.io | LOW | Stable release |
| NVIDIA Driver | 535+ | nvidia.com | MEDIUM | Test with multiple versions |
| Calico CNI | 3.30.3+ | projectcalico.org | LOW | Production-ready |
| MLflow | 2.9.2+ | mlflow.org | LOW | Stable API |
| KServe | 0.11.2+ | kserve.github.io | MEDIUM | Rapid development, test thoroughly |

### Hardware Dependencies

| Dependency | Requirement | Risk Level | Mitigation |
|------------|-------------|------------|------------|
| CPU Virtualization | VT-x/AMD-V enabled | LOW | Check BIOS settings |
| IOMMU | Enabled for GPU passthrough | MEDIUM | Verify kernel support, BIOS config |
| GPU | NVIDIA compute 7.0+ | MEDIUM | Compatibility testing before deployment |
| Network | 1+ Gbps NIC | LOW | Standard requirement |
| Storage | NVMe SSD preferred | LOW | Use HDD if necessary (performance impact) |

### Blocked By HPC Cluster

**Status:** ✅ **UNBLOCKED**

The HPC cluster implementation is complete. All required infrastructure for model training is operational.

**Available from HPC cluster:**

- BeeGFS parallel filesystem for model storage
- SLURM for GPU-accelerated training
- Container workflow (Apptainer)
- Trained model artifacts

---

## Risk Assessment

### Critical Risks (High Impact, High Probability)

#### Risk 1: Resource Constraints on Host Machine

**Impact:** HIGH  
**Probability:** MEDIUM to HIGH  
**Description:** Insufficient host resources to run cloud cluster VMs, especially if HPC cluster is also running.

**Indicators:**

- Host has <64 GB RAM
- Host has <16 CPU cores
- Host has <2 GPUs
- Storage <1 TB

**Mitigation:**

1. **Capacity Planning:**
   - Pre-deployment resource assessment
   - Document minimum vs recommended requirements
   - Add resource checks to `ai-how cloud start`

2. **Sequential Operation:**
   - Run HPC and cloud clusters sequentially if resources are constrained
   - Implement cluster shutdown/startup automation

3. **Resource Monitoring:**
   - Monitor host resource utilization
   - Alert on resource exhaustion
   - Graceful degradation if resources limited

**Code Example:**

```python
# In CloudVMManager

def check_host_resources(self):
    required = {
        'cpu_cores': 40,
        'ram_gb': 96,
        'disk_gb': 1000,
        'gpus': 2
    }
    
    available = self.get_host_resources()
    
    for resource, needed in required.items():
        if available[resource] < needed:
            raise InsufficientResourcesError(
                f"Insufficient {resource}: need {needed}, have {available[resource]}"
            )
```

#### Risk 2: GPU PCIe Passthrough Conflicts

**Impact:** HIGH  
**Probability:** MEDIUM  
**Description:** GPU already assigned to HPC cluster or other VM, causing passthrough failure.

**Indicators:**

- GPU already passed through to another VM
- IOMMU groups not properly configured
- Driver conflicts between host and VM

**Mitigation:**

1. **GPU Allocation Tracking:**
   - Maintain GPU assignment state in state.json
   - Verify GPU availability before VM creation
   - Clear error messages if GPU unavailable

2. **Configuration Validation:**
   - Check IOMMU configuration before deployment
   - Validate GPU IOMMU groups
   - Test passthrough before production use

3. **Conflict Resolution:**
   - Stop conflicting VMs if requested
   - Suggest alternative GPUs if available
   - Provide clear instructions for manual resolution

**Code Example:**

```python
# In CloudVMManager

def allocate_gpu(self, gpu_id):
    state = self.state_manager.get_state()
    
    # Check if GPU already allocated
    for cluster in ['hpc_cluster', 'cloud_cluster']:
        if state[cluster].get('gpu_allocations', {}).get(gpu_id):
            raise GPUAlreadyAllocatedError(
                f"GPU {gpu_id} already allocated to {cluster}"
            )
    
    # Verify IOMMU group
    if not self.verify_iommu_group(gpu_id):
        raise IOMUUConfigurationError(
            f"GPU {gpu_id} not in valid IOMMU group"
        )
```

### High Risks (High Impact, Medium Probability)

#### Risk 3: Kubernetes Cluster Deployment Failures

**Impact:** HIGH  
**Probability:** MEDIUM  
**Description:** Kubespray deployment fails due to networking, SSH, or configuration issues.

**Mitigation:**

1. **Pre-flight Checks:**
   - Verify SSH connectivity before Kubespray
   - Check network configuration
   - Validate Ansible inventory

2. **Incremental Deployment:**
   - Deploy control plane first
   - Verify control plane before adding workers
   - Validate each component

3. **Comprehensive Logging:**
   - Capture Ansible output
   - Store logs for debugging
   - Provide clear error messages

#### Risk 4: MLOps Stack Integration Issues

**Impact:** HIGH  
**Probability:** MEDIUM  
**Description:** MinIO, PostgreSQL, MLflow, or KServe integration failures.

**Mitigation:**

1. **Component Testing:**
   - Test each component individually before integration
   - Use Docker Compose for local testing
   - Validate APIs before deployment

2. **Health Checks:**
   - Implement readiness probes
   - Add liveness probes
   - Monitor component health

3. **Rollback Capability:**
   - Version control for configurations
   - Document rollback procedures
   - Test rollback before production

### Medium Risks (Medium Impact, Medium Probability)

#### Risk 5: Network Configuration Issues

**Impact:** MEDIUM  
**Probability:** MEDIUM  
**Description:** VM networking problems causing cluster communication failures.

**Mitigation:**

- Test network configuration before deployment
- Use standard network ranges
- Provide network debugging tools

#### Risk 6: Storage Performance Bottlenecks

**Impact:** MEDIUM  
**Probability:** MEDIUM  
**Description:** Slow disk I/O affecting inference performance.

**Mitigation:**

- Use NVMe SSDs for production
- Monitor disk I/O metrics
- Optimize container image layers
- Use image caching

#### Risk 7: GPU Driver Compatibility Issues

**Impact:** MEDIUM  
**Probability:** LOW to MEDIUM  
**Description:** NVIDIA driver version incompatible with CUDA toolkit or framework.

**Mitigation:**

- Test driver compatibility before deployment
- Use containerized CUDA toolkit
- Document tested driver versions
- Provide rollback for driver updates

### Low Risks (Low Impact or Low Probability)

#### Risk 8: Kubespray Version Changes

**Impact:** LOW  
**Probability:** LOW  
**Description:** Breaking changes in Kubespray updates.

**Mitigation:**

- Pin Kubespray version (v2.29.0)
- Test updates in non-production
- Review Kubespray changelog before updates

#### Risk 9: Certificate Expiration

**Impact:** LOW  
**Probability:** LOW  
**Description:** Kubernetes certificates expire, causing cluster failure.

**Mitigation:**

- Kubespray handles cert rotation automatically
- Monitor cert expiration dates
- Document manual renewal process

---

## Mitigation Strategies

### Strategy 1: Comprehensive Testing

**Approach:**

- Unit tests for VM management code
- Integration tests for each phase
- End-to-end workflow tests
- Performance benchmarking

**Investment:** 1 week (Phase 7)  
**Benefit:** Catch issues before production

### Strategy 2: Incremental Deployment

**Approach:**

- Deploy and validate each phase before proceeding
- Test rollback procedures
- Document known issues and workarounds

**Investment:** Integrated into each phase  
**Benefit:** Reduce blast radius of failures

### Strategy 3: Monitoring and Alerting

**Approach:**

- Deploy monitoring early (Phase 4)
- Create alerts for critical metrics
- Monitor resource utilization

**Investment:** Phase 4 (1 week)  
**Benefit:** Early detection of issues

### Strategy 4: Documentation

**Approach:**

- Document architecture decisions
- Create troubleshooting guides
- Maintain runbooks for common issues

**Investment:** Ongoing throughout implementation  
**Benefit:** Faster issue resolution

---

## Contingency Plans

### Plan A: Resource Constraints

**Trigger:** Host resources insufficient for cloud cluster

**Actions:**

1. Stop HPC cluster (if running)
2. Reduce cloud cluster VM allocations
3. Deploy minimal cloud cluster (1 control plane, 1 GPU worker)
4. Use CPU-only inference if no GPUs available

### Plan B: Kubespray Deployment Failure

**Trigger:** Kubespray fails to deploy Kubernetes

**Actions:**

1. Capture Ansible logs
2. Identify failing component
3. Attempt component-specific fixes
4. Fallback: Deploy Kubernetes manually with kubeadm
5. Last resort: Use Minikube or K3s for development

### Plan C: GPU Passthrough Failure

**Trigger:** GPU passthrough not working

**Actions:**

1. Verify IOMMU configuration
2. Test with different GPU
3. Use CPU-only inference temporarily
4. Deploy GPU operator to handle drivers in VM

### Plan D: Performance Issues

**Trigger:** Inference latency exceeds targets

**Actions:**

1. Profile inference pipeline
2. Optimize model loading
3. Increase GPU worker resources
4. Add caching layer
5. Consider model quantization

---

## Success Criteria

### Phase-Level Success Criteria

| Phase | Success Criteria | Validation Method |
|-------|------------------|-------------------|
| Phase 0 | VMs provision and CLI works | `ai-how cloud status` returns cluster info |
| Phase 1 | Packer images build successfully | VM boots from image in <2 min |
| Phase 2 | Kubernetes cluster operational | All nodes Ready, all pods Running |
| Phase 3 | MLOps stack deployed | All services accessible via API |
| Phase 4 | Monitoring operational | Metrics visible in Grafana |
| Phase 5 | Oumi workflow complete | Model deploys and serves requests |
| Phase 6 | Integration complete | Automated model transfer works |
| Phase 7 | All tests pass | `make test-cloud-all` succeeds |

### Project-Level Success Criteria

**MVP (Minimum Viable Product):**

- [ ] Cloud cluster provisions via `ai-how cloud start`
- [ ] Kubernetes cluster reaches Ready state
- [ ] GPU resources available for scheduling
- [ ] Model deploys via KServe
- [ ] Inference API responds to requests

**Production Ready:**

- [ ] All 18 tasks complete
- [ ] End-to-end Oumi workflow validated
- [ ] Performance targets met (see resource-requirements.md)
- [ ] Comprehensive test coverage (>80%)
- [ ] Complete documentation
- [ ] Monitoring and alerting operational
- [ ] Disaster recovery procedures documented

---

## References

- **Main Implementation Plan:** [cloud-cluster-oumi-inference.md](../../../design-docs/cloud-cluster-oumi-inference.md)
- **Resource Requirements:** [resource-requirements.md](resource-requirements.md)
- **Task Lists:** Phase files ([00-foundation-phase.md](00-foundation-phase.md) through [07-testing-phase.md](07-testing-phase.md))
