# Active Workstreams - Unified Task Tracking

**Last Updated:** 2025-11-10  
**Active Tasks:** 51 tasks across 4 workstreams  
**Estimated Completion:** 42 hours + 18 days + 10 weeks

## Overview

This document tracks **only active (incomplete) tasks** across all AI-HOW project workstreams.
Completed tasks are archived in [`archive/active-workstreams.md`](./archive/active-workstreams.md).

---

## 🎯 Current Sprint Focus

### Critical Path (This Week)

1. **TASK-028.1** - Fix BeeGFS Kernel Module ⚠️ **BLOCKING** (4 hrs)
2. ~~**Remove Pharos References**~~ - ✅ 80% Complete (remaining: low priority, ~1 hour)

### Next Sprint (Week of 2025-11-04)

1. **HPC Phase 4** - Complete role consolidation (3 tasks, 6.5 hrs)
2. **HPC Phase 6** - Infrastructure validation (4 tasks, 9 hrs)

---

## Workstream 1: HPC Infrastructure Completion

**Status:** 60% Complete (29/48 tasks)  
**Remaining:** 19 tasks  
**Estimated Time:** 28 hours  
**Reference:** [`hpc-slurm-task-list.md`](./hpc-slurm-task-list.md)

### Phase 3: Infrastructure Enhancements (1 task)

| Task ID | Description | Priority | Duration | Status | Blockers |
|---------|-------------|----------|----------|--------|----------|
| TASK-028.1 | Fix BeeGFS Client Kernel Module | CRITICAL | 4 hrs | ✅ CODE COMPLETE · ⏳ VALIDATION PENDING | Image rebuild + cluster validation |

**Validation:**

```bash
cd ansible
make validate-hpc-cluster
# Check: BeeGFS client mounts successfully
```

---

### Phase 4: Infrastructure Consolidation (3 tasks pending)

**Objective:** Complete Ansible role consolidation

**Status:** 87% Complete (20/23 tasks)

| Task ID | Description | Priority | Duration | Dependencies |
|---------|-------------|----------|----------|--------------|
| TASK-047 | Consolidate Base Package Roles | LOW | 2 hrs | TASK-046 ✅ |
| TASK-047.1 | Cleanup Legacy Base Package Roles | LOW | 0.5 hrs | TASK-047 |
| TASK-048 | Create Shared Utilities Role | MEDIUM | 2 hrs | TASK-047 |

**Expected Outcome:**

- Eliminate 250-500 additional lines of duplicate Ansible code
- Complete role consolidation (Phase 4.8)
- All roles use shared package management

**Validation Pattern:**

```bash
cd ansible
make validate-role ROLE=base-packages
make validate-role ROLE=shared-utilities

# Full integration test
make cluster-deploy
make validate-hpc-cluster
```

---

### Phase 6: Final Validation (4 tasks)

**Objective:** Validate complete infrastructure stack

| Task ID | Description | Priority | Duration | Dependencies |
|---------|-------------|----------|----------|--------------|
| TASK-040 | Container Registry on BeeGFS | HIGH | 1 hr | TASK-048 |
| TASK-041 | BeeGFS Performance Testing | HIGH | 2 hrs | TASK-040 |
| TASK-042 | SLURM Integration Testing | HIGH | 2 hrs | TASK-041 |
| TASK-043 | Container Workflow Validation | HIGH | 2 hrs | TASK-042 |
| TASK-044 | Full-Stack Integration Testing | HIGH | 3 hrs | TASK-043 |

**Validation Criteria:**

- ✅ Container registry accessible from all nodes
- ✅ BeeGFS throughput >1 GB/s for large files
- ✅ SLURM schedules GPU jobs correctly
- ✅ End-to-end ML training workflow succeeds
- ✅ All monitoring dashboards functional

**Validation Commands:**

```bash
# TASK-040: Container Registry
make test-container-registry

# TASK-041: BeeGFS Performance
make test-beegfs-performance

# TASK-042: SLURM Integration
make test-slurm-integration

# TASK-043: Container Workflow
make test-container-workflow

# TASK-044: Full-Stack Integration
make test-hpc-full-stack
```

---

### Phase 4 & 6 Test Consolidation (3 tasks)

**Note:** These were listed in original active-workstreams.md but may already be complete. Verify status.

| Task ID | Description | Priority | Duration | Dependencies |
|---------|-------------|----------|----------|--------------|
| TASK-035 | Complete HPC Runtime Framework Integration | HIGH | 2 hrs | Phase 3a ✅ |
| TASK-036 | Create HPC Packer Test Frameworks | HIGH | 5 hrs | TASK-035 |
| TASK-037 | Update Makefile & Delete Obsolete Tests | HIGH | 2 hrs | TASK-036 |

**Status Check Required:**

```bash
# Verify these are not already complete based on Stream B completion
ls -la tests/test-hpc-runtime-framework.sh
ls -la tests/test-hpc-packer-*-framework.sh
grep -r "test-hpc-" Makefile
```

---

## Workstream 2: Code Quality & Rebranding

**Status:** ✅ 80% Complete (8 of 10 tasks, 2 deprecated) - **Production Ready**  
**Estimated Remaining:** ~1 hour (low priority internal docs)  
**Reference:** [`remove-pharos-references-task-list.md`](./remove-pharos-references-task-list.md)

### ✅ Production Status: Complete

- ✅ **Phase 1**: All configuration files updated (3/3 tasks)
- ✅ **Phase 2**: Main documentation updated (2/4 tasks - user-facing complete)
- ✅ **Phase 3**: All source code updated (2/2 tasks)
- 🟢 **Phase 4**: Low priority cleanup remaining (1/3 tasks, 2 deprecated)

**Remaining Work (Low Priority):**

- Internal planning documents cleanup (~30 min)
- Test validation scripts update (~20 min)
- Generated files cleanup (~10 min)

### ✅ Phase 1: Configuration Files (3/3 tasks complete)

| Task ID | Description | Status |
|---------|-------------|--------|
| TASK-001 | Update MkDocs Configuration | ✅ Complete |
| TASK-002 | Update Python Package Configuration | ✅ Complete |
| TASK-003 | Update Docker Configuration | ✅ Complete |

**Completed Changes:**

- ✅ Project name: `pharos.ai-hyperscaler-on-workskation` → `ai-hyperscaler-on-workskation`
- ✅ Short name: New → `ai-how`
- ✅ Docker image: `pharos-dev` → `ai-how-dev`
- ✅ Team: `Pharos.ai Team` → `AI-HOW Team`
- ✅ Site URL: `pharos-ai/...` → `idoudali/...`

---

### ⚠️ Phase 2: Documentation Files (2/4 tasks complete - user-facing done)

| Task ID | Description | Status |
|---------|-------------|--------|
| TASK-004 | Update Root Documentation | ✅ Complete |
| TASK-005 | Update Design Documentation | ✅ Complete |
| TASK-006 | Update Task Lists and Implementation Plans | 🟢 Low Priority (~30 min) |
| TASK-007 | Update Test Documentation | 🟢 Low Priority (~20 min) |

**Production Impact:** ✅ None - All user-facing docs complete

**Remaining Work (Low Priority):**

- TASK-006: Internal planning docs only (8+ markdown files)
- TASK-007: Test validation framework scripts (4+ shell scripts)

---

### ✅ Phase 3: Source Code Files (2/2 tasks complete)

| Task ID | Description | Status |
|---------|-------------|--------|
| TASK-008 | Update Python Source Code | ✅ Complete |
| TASK-009 | Update Shell Scripts | ✅ Complete |

**Completed Changes:**

- ✅ Updated `__author__` fields to "AI-HOW Team"
- ✅ Updated comments and docstrings
- ✅ Updated error messages and log output
- ✅ No API breaking changes

---

### 🟢 Phase 4: Cleanup and Validation (1 remaining, 2 deprecated)

| Task ID | Description | Status |
|---------|-------------|--------|
| TASK-010 | Clean Generated Files | 🟢 Low Priority (~10 min) |
| TASK-011 | Global Verification and Testing | ❌ DEPRECATED (covered by existing workflows) |
| TASK-012 | Update Version Control and Documentation | ❌ DEPRECATED (not needed for internal project) |

**Why Deprecated:**

- TASK-011: Validation covered by `make build-docker`, `make docs-build`, `make lint-ai-how`, pre-commit hooks
- TASK-012: Migration guide not needed for internal refactoring; all changes already documented in config files

---

## Workstream 3: Cloud Cluster Implementation

**Status:** 5.6% Complete (1/18 tasks)  
**Current Phase:** Phase 2 (Kubernetes Deployment)  
**Remaining:** 17 tasks  
**Estimated Time:** ~10 weeks  
**Reference:** [`cloud-cluster/README.md`](./cloud-cluster/README.md)

### Recently Completed ✅

**CLOUD-2.1: Integrate and Configure Kubespray** (Oct 29, 2025)

- ✅ Installed Kubespray v2.29.0 via CMake integration
- ✅ Created Kubespray inventory generation script
- ✅ Implemented `kubespray-integration` Ansible role
- ✅ Created deployment playbook with post-deployment validation
- ✅ Configured Kubespray variables (containerd, Calico, CoreDNS, metrics server, ingress)
- ✅ Updated CloudClusterManager with Kubernetes deployment methods
- ✅ Updated Makefile target for cloud cluster deployment
- ⏳ Pending: Actual cluster deployment testing

**What This Enables:**

- Automated Kubernetes cluster deployment with production-ready configuration
- Foundation for MLOps stack deployment (MinIO, MLflow, KServe)
- GPU operator deployment on worker nodes
- Complete infrastructure for model inference workflow

### Next Task: CLOUD-2.2 Deploy NVIDIA GPU Operator

**Duration:** 2-3 days  
**Priority:** HIGH  
**Dependencies:** CLOUD-2.1 ✅

**Objectives:**

- Deploy NVIDIA GPU Operator via Helm
- Enable GPU scheduling with device plugin
- Configure DCGM for GPU monitoring
- Validate GPU availability on worker nodes

**Deliverables:**

- `ansible/roles/nvidia-gpu-operator/` role
- Helm-based installation with time-slicing support
- Integration with `deploy-cloud-cluster.yml` playbook
- GPU scheduling validation tests

### Upcoming Tasks (Phase 2 → Phase 3)

After CLOUD-2.2 completion:

| Task ID | Description | Duration | Priority |
|---------|-------------|----------|----------|
| CLOUD-3.1 | Deploy MinIO Object Storage | 2 days | HIGH |
| CLOUD-3.2 | Deploy PostgreSQL Database | 1 day | HIGH |
| CLOUD-3.3 | Deploy MLflow Tracking Server | 2 days | HIGH |
| CLOUD-3.4 | Deploy KServe Model Serving | 3 days | HIGH |

**Phase 3 Focus:** MLOps stack deployment for model management and serving

---

## Workstream 4: MLOps Validation (Future)

**Status:** 0% Complete (0/10 tasks) - ✅ **READY TO START**  
**Estimated Time:** 18 days (~3-4 weeks)  
**Current Blocker:** None - All prerequisites met for Categories 1-3

**Prerequisites:**

- ✅ TASK-028.1 complete (BeeGFS working) - COMPLETED
- ✅ HPC cluster operational
- ⏳ Phase 6 validation complete (optional - can overlap)
- ⏳ Cloud cluster deployed (Workstream 3 - only for Category 4 & 5)

**Reference:** [`individual-tasks/mlops-validation/README.md`](./individual-tasks/mlops-validation/README.md)

### Task Breakdown by Category

| Category | Tasks | Duration | Priority | HPC/Cloud | Can Start After |
|----------|-------|----------|----------|-----------|-----------------|
| **1: Basic Training** | 2 | 3 days | CRITICAL | HPC | TASK-028.1 complete |
| **2: Distributed Training** | 2 | 4 days | HIGH | HPC | Category 1 complete |
| **3: Oumi Integration** | 2 | 3 days | HIGH | HPC | Category 2 complete |
| **4: Inference Deployment** | 2 | 3 days | MEDIUM | Cloud | Cloud cluster ready |
| **5: E2E Workflow** | 2 | 5 days | CRITICAL | Both | Categories 1-3 complete |

**Total:** 10 tasks, 18 days (can skip Category 4 if cloud not ready)

### Detailed Task List

#### Category 1: Basic Training Validation (HPC) - 3 days

| Task ID | Description | Duration | Priority | Prerequisites |
|---------|-------------|----------|----------|---------------|
| MLOPS-1.1 | Single GPU MNIST Training | 1 day | CRITICAL | TASK-028.1, HPC operational |
| MLOPS-1.2 | Single GPU LLM Fine-tuning (Oumi) | 2 days | HIGH | MLOPS-1.1, Oumi installed |

**Objective:** Validate basic GPU training, SLURM GRES, BeeGFS storage, single GPU workloads

#### Category 2: Distributed Training (HPC) - 4 days

| Task ID | Description | Duration | Priority | Prerequisites |
|---------|-------------|----------|----------|---------------|
| MLOPS-2.1 | Multi-GPU Data Parallel Training | 2 days | HIGH | Category 1 complete |
| MLOPS-2.2 | Multi-GPU LLM Training (Oumi) | 2 days | HIGH | MLOPS-2.1 |

**Objective:** Validate multi-GPU training, NCCL communication, GPU scheduling across nodes

#### Category 3: Oumi Framework Integration (HPC) - 3 days

| Task ID | Description | Duration | Priority | Prerequisites |
|---------|-------------|----------|----------|---------------|
| MLOPS-3.1 | Oumi Custom Cluster Configuration | 2 days | CRITICAL | Category 2 complete |
| MLOPS-3.2 | Oumi Evaluation and Benchmarking | 1 day | MEDIUM | MLOPS-3.1 |

**Objective:** Validate Oumi framework on custom HPC infrastructure, evaluation workflows

#### Category 4: Inference Deployment (Cloud) - 3 days - **FUTURE**

| Task ID | Description | Duration | Priority | Prerequisites |
|---------|-------------|----------|----------|---------------|
| MLOPS-4.1 | Simple Model Inference on CPU | 1 day | HIGH | Cloud cluster deployed |
| MLOPS-4.2 | GPU Model Inference | 2 days | HIGH | MLOPS-4.1 |

**Objective:** Validate Kubernetes inference, KServe deployment, model serving APIs  
**Status:** Deferred until cloud cluster is deployed

#### Category 5: End-to-End Workflow (Both Clusters) - 5 days

| Task ID | Description | Duration | Priority | Prerequisites |
|---------|-------------|----------|----------|---------------|
| MLOPS-5.1 | Complete Training-to-Inference Pipeline | 3 days | CRITICAL | Categories 1-3 complete |
| MLOPS-5.2 | MLOps Pipeline Automation | 2 days | MEDIUM | MLOPS-5.1 |

**Objective:** Validate complete workflow - train on HPC, register in MLflow, deploy inference  
**Note:** Can partially complete without Category 4 (cloud cluster)

### Recommended Execution Order

**Sequential Path (after TASK-028.1 complete):**

1. **Week 1: Category 1** (3 days)
   - MLOPS-1.1: Single GPU MNIST Training (1 day)
   - MLOPS-1.2: Single GPU LLM Fine-tuning (2 days)
   - **Validates:** Basic GPU training, SLURM, BeeGFS, single GPU workloads

2. **Week 2: Category 2** (4 days)
   - MLOPS-2.1: Multi-GPU Data Parallel Training (2 days)
   - MLOPS-2.2: Multi-GPU LLM Training (2 days)
   - **Validates:** Multi-GPU communication, distributed training, NCCL

3. **Week 3: Category 3** (3 days)
   - MLOPS-3.1: Oumi Custom Cluster Configuration (2 days)
   - MLOPS-3.2: Oumi Evaluation and Benchmarking (1 day)
   - **Validates:** Oumi framework integration on HPC

4. **Week 4: Category 5** (5 days - partial, skip Category 4)
   - MLOPS-5.1: End-to-End Pipeline (3 days)
   - MLOPS-5.2: Pipeline Automation (2 days)
   - **Validates:** Complete MLOps workflow (train → register → automate)

**Category 4 (Cloud Inference):** Deferred until cloud cluster deployed

**Total Duration:** ~3 weeks for Categories 1, 2, 3, 5 (without Category 4)

**Start Date:** After TASK-028.1 complete and HPC cluster validated

---

## Task Dependencies

### Dependency Graph

```text
CRITICAL PATH:
TASK-028.1 (BeeGFS) → TASK-040 (Registry) → TASK-041 (Perf) → TASK-042 (SLURM) → TASK-043 (Workflow) → TASK-044 (Full Stack)
                                                                                                              ↓
                                                                                                        MLOPS-1.1 (Start)

PARALLEL PATHS:

Path A (Role Consolidation):
TASK-046 (Package Mgr) → TASK-046.1 (Integration) → TASK-047 (Base Pkg) → TASK-048 (Utilities) → TASK-040

Path B (Rebranding - Independent):
TASK-001 → TASK-002 → TASK-003 → TASK-004 → TASK-005 → TASK-006 →
TASK-007 → TASK-008 → TASK-009 → TASK-010 → TASK-011 → TASK-012
(Can run anytime, no dependencies on other workstreams)

Path C (Test Frameworks - Verify status):
TASK-035 → TASK-036 → TASK-037
```

---

## Execution Strategy

### Week of 2025-10-28 (Current)

**Priority 1 (Critical):**

- ⚠️ TASK-028.1 - Fix BeeGFS kernel module (BLOCKING everything)

**Priority 2 (Parallel, can start immediately):**

- ~~TASK-001 through TASK-012 - Remove Pharos references~~ - ✅ 80% Complete
  - Production code complete - all config, source, and user-facing docs updated
  - Remaining: Low priority internal planning docs (~1 hour)

### Week of 2025-11-04 (Next Week)

**After TASK-028.1 complete:**

**Stream A - Role Consolidation (6.5 hrs):**

- TASK-046: Package Manager Role (2 hrs)
- TASK-046.1: Integration (3 hrs)
- TASK-047: Base Packages (1.5 hrs)

**Stream B - Infrastructure Validation (10 hrs):**

- TASK-048: Shared Utilities (2 hrs)
- TASK-040: Container Registry (1 hr)
- TASK-041: BeeGFS Performance (2 hrs)
- TASK-042: SLURM Integration (2 hrs)
- TASK-043: Container Workflow (2 hrs)
- TASK-044: Full-Stack Integration (3 hrs)

### Week of 2025-11-11 (Future)

**Prerequisites met → Begin MLOps Validation:**

- Start with Category 1 (basic training)
- 2 tasks, 3 days

---

## Success Metrics

### HPC Infrastructure (Workstream 1)

- [ ] BeeGFS client kernel module builds and mounts successfully
- [ ] Container registry operational on BeeGFS storage
- [ ] BeeGFS throughput >1 GB/s for large files
- [ ] SLURM GPU scheduling working correctly
- [ ] End-to-end ML container workflow validated
- [ ] All Ansible roles consolidated (10+ → 7 final roles)
- [ ] Test frameworks consolidated (verified complete)

### Code Quality (Workstream 2)

- [x] Zero pharos references in production code (internal planning docs remain - low priority)
- [x] Docker image rebuilt as `ai-how-dev`
- [x] Documentation builds without errors
- [x] All linters pass
- [x] ~~Migration guide created~~ - DEPRECATED (not needed for internal project)
- [x] ~~Version bumped appropriately~~ - DEPRECATED (changes documented in config files)

### Overall Project

- [ ] Total code duplication reduced by 5,000+ lines
- [ ] All infrastructure validation complete
- [ ] Ready to begin MLOps validation
- [ ] Documentation accurate and complete

---

## Risk Management

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| BeeGFS kernel module continues to fail | High | Medium | Alternative: NFS, delay MLOps validation |
| Role consolidation breaks deployments | High | Low | Test each change with full cluster deployment |
| Pharos removal breaks links | Medium | Low | Comprehensive grep and test after each phase |
| MLOps validation delayed | Medium | High | Acceptable, infrastructure must be stable first |

---

## Quick Reference

### Common Commands

**Validate HPC Cluster:**

```bash
cd ansible
make validate-hpc-cluster
make test-slurm-cluster
make test-beegfs-cluster
```

**Build and Deploy:**

```bash
make build-docker
make cluster-start
make cluster-deploy
```

**Run Specific Tests:**

```bash
cd tests
./test-hpc-runtime-framework.sh e2e
./test-beegfs-framework.sh e2e
make test-all
```

**Check for Pharos References:**

```bash
git ls-files | xargs grep -li "pharos"
```

---

## Document Maintenance

**Update Triggers:**

- After completing any task
- Daily during active development
- Weekly during planning phases

**Archive Policy:**

- Move completed tasks to [`archive/active-workstreams.md`](./archive/active-workstreams.md)
- Keep this document focused on active work only
- Update [`task-list-index.md`](./task-list-index.md) with completion percentages

---

**Last Updated:** 2025-10-30  
**Next Review:** 2025-11-01  
**Document Owner:** Project Lead
