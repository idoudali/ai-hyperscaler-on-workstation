# Active Workstreams - 2-Stream Parallel Execution

**Created**: 2025-10-25
**Last Updated**: 2025-10-25
**Status**: Planning
**Total Estimated Time**: ~29 hours across 5 days (Stream A: 15.5 hrs, Stream B: 19.5 hrs)

## Overview

This document tracks active workstreams for Phase 4 consolidation and Phase 6 validation organized into 2 parallel
execution streams to maximize development velocity while respecting dependencies.

---

## Stream A: Role Consolidation & Infrastructure

Ansible role consolidation, shared utilities, and infrastructure improvements.

| Day | Task | Description | Duration | Status | Started | Completed | Task Definition |
|-----|------|-------------|----------|--------|---------|-----------|-----------------|
| 1 | TASK-044 | Create BeeGFS Common Role | 4 hrs | Pending | - | - | [Phase 4](hpc-slurm/pending/phase-4-consolidation.md#task-044) |
| 2 | TASK-045 | Create SLURM Common Role | 3 hrs | Pending | - | - | [Phase 4](hpc-slurm/pending/phase-4-consolidation.md#task-045) |
| 3 | TASK-046 | Create Package Manager Common Role | 2 hrs | Pending | - | - | [Phase 4](hpc-slurm/pending/phase-4-consolidation.md#task-046) |
| 4 | TASK-047 | Consolidate Base Package Roles | 1.5 hrs | Pending | - | - | [Phase 4](hpc-slurm/pending/phase-4-consolidation.md#task-047) |
| 4 | TASK-040 | Container Registry on BeeGFS | 1 hr | Pending | - | - | [Phase 6](hpc-slurm/pending/phase-6-validation.md#task-040) |
| 5 | TASK-041 | BeeGFS Performance Testing | 2 hrs | Pending | - | - | [Phase 6](hpc-slurm/pending/phase-6-validation.md#task-041) |
| 5 | TASK-042 | SLURM Integration Testing | 2 hrs | Pending | - | - | [Phase 6](hpc-slurm/pending/phase-6-validation.md#task-042) |
| 5 | TASK-043 | Container Workflow Validation | 2 hrs | Pending | - | - | [Phase 6](hpc-slurm/pending/phase-6-validation.md#task-043) |

**Key Deliverables**:

- Eliminate 1,200-2,000 lines of duplicate Ansible code
- Create 4 new common roles (BeeGFS, SLURM, Package Manager, Base Packages)
- Configure container registry on BeeGFS storage
- Validate BeeGFS performance and SLURM integration

**Validation Pattern**:

```bash
# After each role consolidation
make run-docker COMMAND="cmake --build build --target build-hpc-controller-image"
make cluster-start
make cluster-deploy
```

---

## Stream B: Test Infrastructure Consolidation

**Exclusively focused on test framework consolidation and validation infrastructure.**

| Day | Task/Phase | Description | Duration | Status | Started | Completed | Reference |
|-----|------------|-------------|----------|--------|---------|-----------|-----------|
| 1 | Phase 2 | Extract Common Test Patterns & Utilities | 2.5 hrs | Pending | - | - | [Test Plan](test-plan/04-implementation-phases.md#phase-2) |
| 2 | TASK-036 | Create HPC Packer Test Frameworks | 5 hrs | Pending | - | - | [Phase 4](hpc-slurm/pending/phase-4-consolidation.md#task-036) |
| 3 | Phase 3a | Create Unified HPC Runtime Framework | 3 hrs | Pending | - | - | [Test Plan](test-plan/04-implementation-phases.md#phase-3) |
| 3 | TASK-035 | Complete HPC Runtime Framework Integration | 2 hrs | Pending | - | - | [Phase 4](hpc-slurm/pending/phase-4-consolidation.md#task-035) |
| 4 | Phase 4 | Refactor Standalone Test Frameworks | 2.5 hrs | Pending | - | - | [Test Plan](test-plan/04-implementation-phases.md#phase-4) |
| 4 | TASK-037 | Update Makefile & Delete Obsolete Tests | 2 hrs | Pending | - | - | [Phase 4](hpc-slurm/pending/phase-4-consolidation.md#task-037) |
| 5 | Phase 5 | Final Validation & Testing | 2.5 hrs | Pending | - | - | [Test Plan](test-plan/04-implementation-phases.md#phase-5) |
| 5 | TASK-044 | Test Documentation Updates | 1 hr | Pending | - | - | [Phase 6](hpc-slurm/pending/phase-6-validation.md#task-044) |

**Key Deliverables**:

- Extract and create 3 new shared utility modules (`framework-cli.sh`, `framework-orchestration.sh`, `framework-template.sh`)
- Consolidate 11 test frameworks into 3 unified frameworks
- Refactor 4 standalone frameworks to use shared utilities
- Delete 25 obsolete test files
- Reduce test code duplication by 2,000-3,000 lines
- Update comprehensive test documentation

**Test Plan Integration**:

This stream implements the complete [Test Plan](test-plan/README.md) consolidation strategy:

- **Phase 1**: Documentation ✅ Complete
- **Phase 2-5**: Integrated into this workstream schedule

**Validation Pattern**:

```bash
# After each framework consolidation
cd tests
./test-hpc-packer-controller-framework.sh e2e
./test-hpc-runtime-framework.sh e2e
./test-beegfs-framework.sh e2e  # Refactored to use shared utils
make test-all
```

---

## Task Dependencies

```text
Stream A: TASK-044 → TASK-045 → TASK-046 → TASK-047 + TASK-040 → TASK-041,042,043
                                              (parallel)

Stream B: Phase 2 → TASK-036 → Phase 3a + TASK-035 → Phase 4 + TASK-037 → Phase 5 + TASK-044
          (extract)  (Packer)  (Runtime Framework)    (Refactor + Cleanup)  (Validation + Docs)

Cross-Stream: Stream B independent of Stream A (can run fully in parallel)
```

---

## Success Criteria

### Stream A: Role Consolidation & Infrastructure

- ✅ Ansible code duplication reduced by 1,200-2,000 lines
- ✅ 4 new common roles created (BeeGFS, SLURM, Package Manager, Base Packages)
- ✅ Container registry successfully running on BeeGFS storage
- ✅ BeeGFS performance validated and optimized
- ✅ SLURM integration tested with consolidated roles
- ✅ End-to-end container workflow validated

### Stream B: Test Infrastructure Consolidation

- ✅ 3 new shared utility modules created and integrated
- ✅ Test framework count reduced from 15 to 8
- ✅ Test code duplication reduced by 2,000-3,000 lines
- ✅ 25 obsolete test files deleted
- ✅ All 16 test suites preserved and functioning
- ✅ Standardized CLI implemented across all frameworks
- ✅ All existing tests pass with new infrastructure
- ✅ Test documentation complete and updated

### Combined Impact

- ✅ Total code duplication reduced by 3,200-5,000 lines
- ✅ All existing functionality preserved
- ✅ Deployment process unchanged for end users
- ✅ Test execution time unchanged or improved

---

## Risk Management

| Risk Level | Risk | Mitigation |
|------------|------|------------|
| High | Ansible role refactoring breaks deployments | Test each change with full cluster deployment |
| High | Test framework consolidation causes test failures | Run comprehensive test suite after each framework change |
| High | Breaking existing test suites during consolidation | Preserve all test suites unchanged, only modify frameworks |
| Medium | Parallel stream file conflicts | Stream A: `ansible/roles/`, Stream B: `tests/` - clear separation |
| Medium | Test utility extraction breaks existing frameworks | Extract incrementally, validate after each extraction |
| Low | Documentation lags behind code changes | Update READMEs as part of each task completion |
| Low | Test execution time increases | Benchmark before/after, optimize if needed |

---

## References

### Task Definitions

- [Phase 4 Consolidation Plan](hpc-slurm/pending/phase-4-consolidation.md) - Ansible role consolidation tasks
- [Phase 6 Validation Plan](hpc-slurm/pending/phase-6-validation.md) - Infrastructure validation tasks
- [HPC SLURM Task List](hpc-slurm-task-list.md) - Master task list

### Test Plan (Stream B)

- [Test Plan Overview](test-plan/README.md) - Complete test consolidation strategy
- [Test Inventory](test-plan/00-test-inventory.md) - Current test infrastructure baseline
- [Consolidation Strategy](test-plan/01-consolidation-plan.md) - How frameworks will be consolidated
- [Implementation Phases](test-plan/04-implementation-phases.md) - Detailed phase breakdown

---

**Next Action**: Begin Day 1 execution

- Stream A: TASK-044 (BeeGFS Common Role)
- Stream B: Phase 2 (Extract Common Test Patterns)

**Document Version**: 2.0
