# Active Workstreams - Unified Task Tracking

**Last Updated:** 2025-10-30  
**Active Tasks:** 31 tasks across 2 workstreams  
**Estimated Completion:** 37.5 hours + 18 days

## Overview

This document tracks **only active (incomplete) tasks** across all AI-HOW project workstreams. Completed tasks are archived in [`archive/active-workstreams.md`](./archive/active-workstreams.md).

---

## 🎯 Current Sprint Focus

### Critical Path (This Week)

1. **TASK-028.1** - Fix BeeGFS Kernel Module ⚠️ **BLOCKING** (4 hrs)
2. **Remove Pharos References** - All 12 tasks (8 hrs, can run in parallel)

### Next Sprint (Week of 2025-11-04)

3. **HPC Phase 4** - Complete role consolidation (3 tasks, 6.5 hrs)
4. **HPC Phase 6** - Infrastructure validation (4 tasks, 9 hrs)

---

## Workstream 1: HPC Infrastructure Completion

**Status:** 60% Complete (29/48 tasks)  
**Remaining:** 19 tasks  
**Estimated Time:** 31.5 hours  
**Reference:** [`hpc-slurm-task-list.md`](./hpc-slurm-task-list.md)

### Phase 3: Infrastructure Enhancements (1 task)

| Task ID | Description | Priority | Duration | Status | Blockers |
|---------|-------------|----------|----------|--------|----------|
| TASK-028.1 | Fix BeeGFS Client Kernel Module | CRITICAL | 4 hrs | ⚠️ IN PROGRESS | Kernel headers mismatch |

**Validation:**

```bash
cd ansible
make validate-hpc-cluster
# Check: BeeGFS client mounts successfully
```

---

### Phase 4: Infrastructure Consolidation (6 tasks)

**Objective:** Complete Ansible role consolidation

| Task ID | Description | Priority | Duration | Dependencies |
|---------|-------------|----------|----------|--------------|
| TASK-046 | Create Shared Package Management Role | MEDIUM | 2 hrs | TASK-045 ✅ |
| TASK-046.1 | Integrate Package Manager into Existing Roles | MEDIUM | 3 hrs | TASK-046 |
| TASK-047 | Consolidate Base Package Roles | MEDIUM | 1.5 hrs | TASK-046.1 |
| TASK-048 | Create Shared Utilities Role | MEDIUM | 2 hrs | TASK-047 |

**Expected Outcome:**

- Eliminate 500-800 additional lines of duplicate Ansible code
- 4 new common roles created
- All roles use shared package management

**Validation Pattern:**

```bash
cd ansible
make validate-role ROLE=package-manager
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

**Status:** 0% Complete (0/12 tasks)  
**Estimated Time:** 8 hours (1 day)  
**Reference:** [`remove-pharos-references-task-list.md`](./remove-pharos-references-task-list.md)

### Phase 1: Configuration Files (3 tasks - 1.5 hrs)

| Task ID | Description | Duration | Risk |
|---------|-------------|----------|------|
| TASK-001 | Update MkDocs Configuration | 30 min | Low |
| TASK-002 | Update Python Package Configuration | 20 min | Low |
| TASK-003 | Update Docker Configuration | 30 min | Low |

**Changes:**

- Project name: `pharos.ai-hyperscaler-on-workskation` → `ai-hyperscaler-on-workskation`
- Short name: New → `ai-how`
- Docker image: `pharos-dev` → `ai-how-dev`
- Team: `Pharos.ai Team` → `AI-HOW Team`
- Site URL: `pharos-ai/...` → `idoudali/...`

**Validation:**

```bash
yamllint mkdocs.yml
mkdocs build --strict
make build-docker
docker images | grep ai-how-dev
```

---

### Phase 2: Documentation Files (4 tasks - 3.5 hrs)

| Task ID | Description | Duration | Files Affected |
|---------|-------------|----------|----------------|
| TASK-004 | Update Root Documentation | 45 min | README.md, docker/README.md |
| TASK-005 | Update Design Documentation | 1 hr | docs/design-docs/*.md |
| TASK-006 | Update Task Lists and Implementation Plans | 1 hr | planning/**/*.md |
| TASK-007 | Update Test Documentation | 30 min | tests/README.md |

**Strategy:**

- Use `${PROJECT_ROOT}` placeholder for paths
- Make examples generic and portable
- Update file paths in all examples
- Maintain technical accuracy

**Validation:**

```bash
markdownlint docs/**/*.md README.md
grep -ri "pharos" docs/ README.md planning/ tests/README.md
```

---

### Phase 3: Source Code Files (2 tasks - 1 hr)

| Task ID | Description | Duration | Files Affected |
|---------|-------------|----------|----------------|
| TASK-008 | Update Python Source Code | 20 min | containers/tools/hpc_extensions/**init**.py |
| TASK-009 | Update Shell Scripts | 30 min | scripts/*.sh, tests/*.sh |

**Changes:**

- Update `__author__` fields
- Update comments and docstrings
- Update error messages and log output
- No API breaking changes

**Validation:**

```bash
python -m py_compile containers/tools/hpc_extensions/__init__.py
shellcheck scripts/**/*.sh tests/*.sh
grep -ri "pharos" containers/tools/ scripts/ tests/*.sh
```

---

### Phase 4: Cleanup and Validation (3 tasks - 2 hrs)

| Task ID | Description | Duration | Critical |
|---------|-------------|----------|----------|
| TASK-010 | Clean Generated Files | 15 min | No |
| TASK-011 | Global Verification and Testing | 1 hr | Yes |
| TASK-012 | Update Version Control and Documentation | 30 min | Yes |

**Deliverables:**

- Migration guide: `docs/MIGRATION-FROM-PHAROS.md`
- Updated CHANGELOG
- Version bump
- Complete verification

**Final Verification:**

```bash
# Search for remaining references
git ls-files | xargs grep -li "pharos"

# Build and test everything
make clean-docker
make build-docker
make config
mkdocs build --strict

# Run linters
make validate-all
```

---

## Workstream 3: MLOps Validation (Future)

**Status:** 0% Complete (0/10 tasks)  
**Estimated Time:** 18 days (~3-4 weeks)  
**Prerequisites:**

- ✅ TASK-028.1 complete (BeeGFS working)
- ✅ Phase 6 validation complete
- ⏳ Cloud cluster deployed

**Reference:** [`individual-tasks/mlops-validation/README.md`](./individual-tasks/mlops-validation/README.md)

### Execution Order

**Week 1:**

- MLOPS-1.1: Single GPU MNIST Training (1 day)
- MLOPS-1.2: Single GPU LLM Fine-tuning (2 days)

**Week 2:**

- MLOPS-2.1: Multi-GPU Data Parallel Training (2 days)
- MLOPS-2.2: Multi-GPU LLM Training (2 days)

**Week 3:**

- MLOPS-3.1: Oumi Custom Cluster Config (2 days)
- MLOPS-3.2: Oumi Evaluation Framework (1 day)

**Week 4:**

- MLOPS-4.1: CPU Model Inference (1 day)
- MLOPS-4.2: GPU Model Inference (2 days)

**Week 5:**

- MLOPS-5.1: Complete MLOps Pipeline (3 days)
- MLOPS-5.2: Pipeline Automation (2 days)

**Start Date:** TBD (after HPC infrastructure 100% complete)

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
TASK-001 → TASK-002 → TASK-003 → TASK-004 → TASK-005 → TASK-006 → TASK-007 → TASK-008 → TASK-009 → TASK-010 → TASK-011 → TASK-012
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

- TASK-001 through TASK-012 - Remove Pharos references (8 hrs total)
  - Can be done while waiting on BeeGFS fix
  - Low risk, no infrastructure dependencies

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

- [ ] Zero pharos references in tracked source files
- [ ] Docker image rebuilt as `ai-how-dev`
- [ ] Documentation builds without errors
- [ ] All linters pass
- [ ] Migration guide created
- [ ] Version bumped appropriately

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
