# Cloud Cluster Implementation Task List

**Status:** In Progress - Phase 3 (MLOps Stack)  
**Created:** 2025-10-27  
**Last Updated:** 2025-11-14  
**Priority:** HIGH - Required for Oumi inference workflow  
**Total Tasks:** 18 tasks across 8 phases  
**Completed:** 12 tasks (Phase 0: 6/6, Phase 1: 2/2, Phase 2: 1/2, Phase 3: 3/4)  
**Estimated Duration:** 11 weeks  
**Deployment Tool:** [Kubespray v2.29.0+](https://github.com/kubernetes-sigs/kubespray)

## Overview

This task list outlines the implementation of a Kubernetes-based cloud cluster for **Oumi model inference** after
training completion in the HPC cluster. This enables the complete ML workflow: **HPC training → Cloud inference**.

**Key Architecture Decision:** We use **Kubespray** (CNCF-approved, 17.8k stars, battle-tested) instead of custom
kubeadm roles. This reduces maintenance burden and leverages community expertise for production-ready Kubernetes
deployment.

**Task Numbering:** Tasks use phase-prefixed IDs (e.g., CLOUD-2.1, CLOUD-3.2) to eliminate cascading renumbering when
adding new tasks. Each phase file manages its own task numbers independently.

---

## Phase Overview

| Phase | Tasks | Duration | Status | Details |
|-------|-------|----------|--------|---------|
| Phase 0: Foundation | CLOUD-0.1 to 0.6 | 2 weeks | ✅ Complete (6/6) | [00-foundation-phase.md](00-foundation-phase.md) |
| Phase 1: Packer Images | CLOUD-1.1 to 1.2 | 1 week | ✅ Complete (2/2) | [01-packer-images-phase.md](01-packer-images-phase.md) |
| Phase 2: Kubernetes | CLOUD-2.1 to 2.2 | 2 weeks | 🟡 In Progress (1/2) | [02-kubernetes-phase.md](02-kubernetes-phase.md) |
| Phase 3: MLOps Stack | CLOUD-3.1 to 3.4 | 2 weeks | 🟡 In Progress (3/4) | [03-mlops-stack-phase.md](03-mlops-stack-phase.md) |
| Phase 4: Monitoring | CLOUD-4.1 to 4.2 | 1 week | Not Started | [04-monitoring-phase.md](04-monitoring-phase.md) |
| Phase 5: Oumi Integration | CLOUD-5.1 to 5.2 | 1 week | Not Started | [05-oumi-integration-phase.md](05-oumi-integration-phase.md) |
| Phase 6: Integration | CLOUD-6.1 to 6.3 | 1 week | Not Started | [06-integration-phase.md](06-integration-phase.md) |
| Phase 7: Testing | CLOUD-7.1 | 1 week | Not Started | [07-testing-phase.md](07-testing-phase.md) |

---

## Quick Task Index

| Task ID | Task Name | Phase | Priority | Status | File |
|---------|-----------|-------|----------|--------|------|
| **CLOUD-0.1** | Extend VM Management for Cloud | 0 | CRITICAL | ✅ | [00-foundation-phase.md](00-foundation-phase.md#cloud-01-extend-vm-management-for-cloud-cluster) |
| **CLOUD-0.2** | Implement Cloud Cluster CLI | 0 | CRITICAL | ✅ | [00-foundation-phase.md](00-foundation-phase.md#cloud-02-implement-cloud-cluster-cli-commands) |
| **CLOUD-0.3** | Shared GPU Resource Management | 0 | CRITICAL | ✅ | [00-foundation-phase.md](00-foundation-phase.md#cloud-03-shared-gpu-resource-management) |
| **CLOUD-0.4** | Enhanced VM Lifecycle Management | 0 | CRITICAL | ✅ | [00-foundation-phase.md](00-foundation-phase.md#cloud-04-enhanced-vm-lifecycle-management) |
| **CLOUD-0.5** | Makefile Cloud Cluster Support | 0 | CRITICAL | ✅ | [00-foundation-phase.md](00-foundation-phase.md#cloud-05-makefile-cloud-cluster-support) |
| **CLOUD-0.6** | System-wide Cluster Management | 0 | CRITICAL | ✅ | [00-foundation-phase.md](00-foundation-phase.md#cloud-06-system-wide-cluster-management) |
| **CLOUD-1.1** | Create Cloud Base Packer Image | 1 | HIGH | ✅ | [01-packer-images-phase.md](01-packer-images-phase.md#cloud-11-create-cloud-base-packer-image) |
| **CLOUD-1.2** | Create Specialized Cloud Images | 1 | MEDIUM | ✅ | [01-packer-images-phase.md](01-packer-images-phase.md#cloud-12-create-specialized-cloud-images) |
| **CLOUD-2.1** | Integrate and Configure Kubespray | 2 | HIGH | ✅ | [02-kubernetes-phase.md](02-kubernetes-phase.md#cloud-21-integrate-and-configure-kubespray) |
| **CLOUD-2.2** | Deploy NVIDIA GPU Operator | 2 | HIGH | ⏳ | [02-kubernetes-phase.md](02-kubernetes-phase.md#cloud-22-deploy-nvidia-gpu-operator) |
| **CLOUD-3.1** | Deploy MinIO Object Storage | 3 | HIGH | ✅ | [03-mlops-stack-phase.md](03-mlops-stack-phase.md#cloud-31-deploy-minio-object-storage) |
| **CLOUD-3.2** | Deploy PostgreSQL Database | 3 | HIGH | ✅ | [03-mlops-stack-phase.md](03-mlops-stack-phase.md#cloud-32-deploy-postgresql-database) |
| **CLOUD-3.3** | Deploy MLflow Tracking Server | 3 | HIGH | ✅ | [03-mlops-stack-phase.md](03-mlops-stack-phase.md#cloud-33-deploy-mlflow-tracking-server) |
| **CLOUD-3.4** | Deploy KServe Model Serving | 3 | HIGH | ⏳ | [03-mlops-stack-phase.md](03-mlops-stack-phase.md#cloud-34-deploy-kserve-model-serving) |
| **CLOUD-4.1** | Deploy Prometheus Stack | 4 | HIGH | ⏳ | [04-monitoring-phase.md](04-monitoring-phase.md#cloud-41-deploy-prometheus-stack) |
| **CLOUD-4.2** | Deploy Grafana Dashboards | 4 | MEDIUM | ⏳ | [04-monitoring-phase.md](04-monitoring-phase.md#cloud-42-deploy-grafana-dashboards) |
| **CLOUD-5.1** | Oumi Configuration and Testing | 5 | CRITICAL | ⏳ | [05-oumi-integration-phase.md](05-oumi-integration-phase.md#cloud-51-oumi-configuration-and-testing) |
| **CLOUD-5.2** | ML Workflow Documentation | 5 | HIGH | ⏳ | [05-oumi-integration-phase.md](05-oumi-integration-phase.md#cloud-52-ml-workflow-documentation) |
| **CLOUD-6.1** | Model Transfer Automation | 6 | MEDIUM | ⏳ | [06-integration-phase.md](06-integration-phase.md#cloud-61-hpc-to-cloud-model-transfer-automation) |
| **CLOUD-6.2** | Unified Monitoring | 6 | MEDIUM | ⏳ | [06-integration-phase.md](06-integration-phase.md#cloud-62-unified-monitoring-across-clusters) |
| **CLOUD-6.3** | Performance Testing | 6 | HIGH | ⏳ | [06-integration-phase.md](06-integration-phase.md#cloud-63-performance-testing-and-optimization) |
| **CLOUD-7.1** | Test Framework | 7 | HIGH | ⏳ | [07-testing-phase.md](07-testing-phase.md#cloud-71-cloud-cluster-test-framework) |

---

## Current State Analysis

### What Exists (HPC Cluster) ✅

From the existing codebase and project plan:

- ✅ **Complete HPC VM management** (4,308+ lines of code)
- ✅ **SLURM cluster** with GPU GRES scheduling
- ✅ **BeeGFS 8.1.0** parallel filesystem
- ✅ **Apptainer** container workflow
- ✅ **PCIe GPU passthrough** for discrete GPUs
- ✅ **Comprehensive monitoring** (Prometheus, Grafana, DCGM)
- ✅ **All infrastructure** for model training operational

### What's Missing (Cloud Cluster) ❌

From `python/ai_how/src/ai_how/cli.py` and project analysis:

- ❌ **Cloud VM Management** - CLI commands are stubs (lines 593-610)
- ❌ **Packer Cloud Images** - No cloud-base.qcow2 image exists
- ❌ **Kubernetes Deployment** - ansible/roles/cloud-cluster-setup/ is placeholder
- ✅ **MLOps Stack (Partial)** - MinIO, PostgreSQL, and MLflow deployed ✅
- ❌ **Model Serving** - KServe not yet implemented
- ❌ **HPC-Cloud Integration** - No model transfer automation

**Gap Impact:** Cannot deploy trained models for inference. This blocks the complete ML workflow.

---

## Implementation Strategy

### Unblocked Tasks (Can Start Immediately)

- **CLOUD-0.1:** VM Management Extension
- **CLOUD-0.2:** CLI Commands (after CLOUD-0.1)

### Critical Path

```text
CLOUD-0.1 → CLOUD-0.2 → CLOUD-1.1 → CLOUD-2.1 → CLOUD-3.3 → CLOUD-3.4 → CLOUD-5.1
```

This critical path represents the minimum tasks needed for basic inference capability.

### Parallel Work Opportunities

Multiple tasks can be executed in parallel:

**Week 5-6 (Phase 3):**

- CLOUD-3.1 (MinIO) + CLOUD-3.2 (PostgreSQL) can run in parallel
- Both feed into CLOUD-3.3 (MLflow)

**Week 10 (Phase 6):**

- CLOUD-6.1 (Transfer) + CLOUD-6.2 (Monitoring) + CLOUD-6.3 (Performance) all independent

**Throughout Project:**

- CLOUD-7.1 (Test Framework) can be developed alongside implementation

---

## Success Criteria

### Minimum Viable Product (MVP)

- [ ] `ai-how cloud start` provisions VMs successfully
- [ ] Kubernetes cluster reaches Ready state (all nodes)
- [ ] GPU resources available for pod scheduling
- [ ] Single model deploys via KServe
- [ ] Inference API responds to test requests

### Production Ready

- [ ] All 18 tasks complete and validated
- [ ] End-to-end Oumi workflow tested (train on HPC → deploy on cloud)
- [ ] Performance targets met:
  - Cold start latency <10s
  - Inference latency (P95) <500ms
  - Throughput >50 req/s per GPU
  - GPU utilization >70%
- [ ] Comprehensive test coverage (>80%)
- [ ] Complete documentation (tutorials, operations, architecture)
- [ ] Monitoring and alerting operational
- [ ] Disaster recovery procedures documented

---

## Additional Resources

### Planning Documents

- **Full Implementation Plan:** [cloud-cluster-oumi-inference.md](../../../design-docs/cloud-cluster-oumi-inference.md)
- **Kubespray Migration Details:** [KUBESPRAY-MIGRATION.md](KUBESPRAY-MIGRATION.md)
- **Resource Requirements:** [resource-requirements.md](resource-requirements.md)
- **Dependencies and Risks:** [dependencies-and-risks.md](dependencies-and-risks.md)

### Reference Documentation

- **Project Plan:** `docs/design-docs/project-plan.md`
- **HPC Task List:** `docs/implementation-plans/task-lists/hpc-slurm/`
- **Active Workstreams:** `docs/implementation-plans/task-lists/active-workstreams.md`
- **Cluster Configuration:** `config/example-multi-gpu-clusters.yaml`
- **CLI Reference:** `python/ai_how/docs/cli-reference.md`

### External Resources

- **Kubespray Documentation:** https://kubespray.io/
- **Kubespray GitHub:** https://github.com/kubernetes-sigs/kubespray
- **KServe Documentation:** https://kserve.github.io/website/
- **MLflow Documentation:** https://mlflow.org/docs/latest/
- **Oumi Documentation:** [Documentation link if available]

---

## Next Steps

1. **Review Implementation Plan:** Review [cloud-cluster-oumi-inference.md](../../../design-docs/cloud-cluster-oumi-inference.md)
2. **Assess Resources:** Verify host meets [resource requirements](resource-requirements.md)
3. **Review Risks:** Understand [dependencies and risks](dependencies-and-risks.md)
4. **Create GitHub Issues:** Create tracking issues for all CLOUD-X.Y tasks
5. **Start Phase 0:** Begin with [CLOUD-0.1](00-foundation-phase.md#cloud-01-extend-vm-management-for-cloud-cluster)

---

**Document Version:** 2.3  
**Status:** In Progress - Phase 3 (MLOps Stack)  
**Last Updated:** 2025-11-14  
**Completed Tasks:** 12/18

- Phase 0: CLOUD-0.1, CLOUD-0.2, CLOUD-0.3, CLOUD-0.4, CLOUD-0.5, CLOUD-0.6 (6/6)
- Phase 1: CLOUD-1.1, CLOUD-1.2 (2/2)
- Phase 2: CLOUD-2.1 (1/2)
- Phase 3: CLOUD-3.1, CLOUD-3.2, CLOUD-3.3 (3/4)
