# HPC SLURM and Cloud Cluster Test Plan

## Overview

This directory contains a comprehensive, modular test plan for the HPC SLURM infrastructure and the new Kubernetes-based
cloud cluster for model inference. The test plan is structured to be both human-readable and optimized for Large
Language Model (LLM) context consumption.

## Purpose

- **Consolidate Test Infrastructure**: Reduce code duplication across 15+ test frameworks (HPC)
- **Expand Cloud Coverage**: Add 4 new test frameworks for cloud cluster validation
- **Explicit Test Coverage**: Map all tests to components, frameworks, and validation goals
- **Standardize Test Execution**: Implement consistent CLI patterns across all frameworks
- **Enable Modular Testing**: Support running individual tests, test suites, or full end-to-end validation
- **Multi-Cluster Validation**: Test HPC-to-Cloud ML workflow scenarios

## Current Implementation Status

**Framework Consolidation**: ✅ COMPLETE (October 2025)

**Phase 1**: ✅ COMPLETE (Documentation)
**Phase 2**: ✅ COMPLETE (2025-10-25) - Shared utilities created

- framework-cli.sh (459 lines) - Standardized CLI parser
- framework-orchestration.sh (504 lines) - Cluster lifecycle & orchestration
- framework-template.sh (419 lines) - Framework template for new frameworks

**Phase 3**: ✅ COMPLETE (2025-10-27) - 3 unified frameworks created
**Phase 4**: ✅ COMPLETE (2025-10-27) - 3 standalone frameworks refactored
**Phase 5**: ✅ COMPLETE (2025-10-27) - Validation and cleanup complete
**Phase 6**: ✅ COMPLETE (2025-10-27) - Directory reorganization complete

**Test Suite Refactoring**: 🔄 IN PROGRESS (November 2025)

**Phase 1**: ✅ COMPLETE (2025-11-18) - Shared suite utilities created
**Phase 2**: 🔄 IN PROGRESS (2025-11-18) - Test suite script refactoring (~50% complete)
**Phase 3**: ⏳ PLANNED - Validation and cleanup

**Framework Consolidation Results**:

- **11 deprecated frameworks deleted**
- **6 frameworks consolidated and refactored** (3 in `frameworks/`, 3 in `advanced/`)
- **42 new Makefile targets added**
- **~2000-3000 lines of duplicated code eliminated**
- **Consistent CLI patterns across all frameworks**
- **Directory structure reorganized** (`foundation/`, `frameworks/`, `advanced/`, `legacy/`, `utilities/`, `e2e-system-setup/`)

**Test Suite Refactoring Progress** (as of 2025-11-18):

- **15+ test suites refactored** to use standardized utilities
- **40+ test scripts updated** with consistent patterns
- **~500-1000 lines of duplicated code eliminated**
- **Consistent logging and error handling** across refactored suites
- **PS4 debug traces added** for better troubleshooting
- **SSH key path handling improved** for cross-node test execution

**Next Phase**: 🔄 IN PROGRESS - Test Suite Refactoring (see [09-test-suite-refactoring-plan.md](09-test-suite-refactoring-plan.md))

- ✅ Phase 1 Complete: Shared suite utilities created in `tests/suites/common/`
- 🔄 Phase 2 In Progress: Test suite script refactoring
  - ✅ 15+ test suites refactored to use common utilities
  - ✅ 40+ test scripts updated with standardized patterns
  - ✅ ~500-1000 lines of duplicated code eliminated
  - ✅ Consistent logging and error handling implemented
  - ⏳ Remaining: Complete full audit of all 80+ scripts
- ⏳ Phase 3 Planned: Validation and cleanup

## Structure

This test plan is organized into focused, manageable documents:

### Core Documents

| File | Purpose | Size | Status |
|------|---------|------|--------|
| `00-test-inventory.md` | Complete inventory of all test frameworks and suites | ~500 lines | ✅ Complete |
| `01-consolidation-plan.md` | Strategy for consolidating test frameworks | ~800 lines | ✅ Complete |
| `02-component-matrix.md` | Detailed matrix of test coverage by component | ~600 lines | ✅ Complete |
| `03-framework-specifications.md` | Specifications for each test framework | ~700 lines | ✅ Complete |
| `04-implementation-phases.md` | Step-by-step implementation plan with tasks | ~600 lines | ✅ Complete |
| `05-validation-checklist.md` | Validation criteria and acceptance tests | ~400 lines | ✅ Complete |
| `06-test-dependencies-matrix.md` | Per-test dependencies and cluster configuration requirements | ~900 lines | ✅ Complete |
| `07-directory-reorganization.md` | Directory reorganization implementation task | ~600 lines | ✅ Complete |
| `08-cloud-cluster-testing.md` | Cloud cluster testing requirements and frameworks | ~1200 lines | 📝 New |
| `09-test-suite-refactoring-plan.md` | Test suite scripts refactoring to eliminate code duplication | ~600 lines | 📝 New |
| `cloud-testing-tasks.md` | Cloud testing task breakdown and implementation checklist | ~500 lines | 📝 New |

### Templates

| File | Purpose | Usage |
|------|---------|-------|
| `templates/framework-template.md` | Template for new test framework documentation | Copy and customize |
| `templates/test-suite-template.md` | Template for new test suite documentation | Copy and customize |

## How to Use This Test Plan

### For Implementation

1. **Start with**: `00-test-inventory.md` - Understand current state
2. **Review**: `01-consolidation-plan.md` - Understand the strategy
3. **Reference**: `02-component-matrix.md` - Verify test coverage
4. **Check**: `06-test-dependencies-matrix.md` - Understand test requirements and cluster configs
5. **Implement**: `03-framework-specifications.md` - Build to spec
6. **Follow**: `04-implementation-phases.md` - Execute in order
7. **Validate**: `05-validation-checklist.md` - Ensure quality

### For LLM Context

Each file is designed to be included in LLM context independently or as a set:

```bash
# Include full test plan in context
cat task-lists/test-plan/*.md

# Include specific sections
cat task-lists/test-plan/00-test-inventory.md task-lists/test-plan/02-component-matrix.md

# Include implementation guidance
cat task-lists/test-plan/03-framework-specifications.md task-lists/test-plan/04-implementation-phases.md
```

### File Size Optimization

All files are kept under 1000 lines for easy LLM consumption:

- **Small files**: 400-500 lines (quick reference)
- **Medium files**: 600-700 lines (detailed specifications)
- **Large files**: 800-1000 lines (comprehensive plans)

## Key Concepts

### Three-Tier Architecture

1. **Tier 1: End-to-End Validation** (`tests/e2e-system-setup/`)
   - Comprehensive step-by-step validation framework
   - **Kept as-is** (golden standard for release validation)
   - Self-contained validation orchestration
   - Status: ✅ Complete and automated
   - **Not part of framework consolidation**

2. **Tier 2: Test Frameworks** (`tests/frameworks/` and `tests/advanced/`)
   - Orchestrate cluster lifecycle and test execution
   - **CONSOLIDATION COMPLETE**: ✅ Reduced from 15+ to 6 frameworks
   - Standardized CLI patterns and shared utilities implemented
   - **Current frameworks**:
     - `frameworks/`: HPC Packer SLURM, HPC Runtime, PCIe Passthrough (3 frameworks)
     - `advanced/`: BeeGFS, Container Registry, VirtIO-FS (3 frameworks)

3. **Tier 3: Component Test Suites** (`tests/suites/*/`)
   - Actual test logic and validation scripts
   - **20 suite directories** with 80+ test scripts
   - **NEXT TARGET**: Suite refactoring to eliminate code duplication (~2000-3000 lines)
   - Well-organized, focused, and proven

### Consolidation Strategy (Complete)

- **Combine**: ✅ 11 frameworks → 3 unified frameworks (in `frameworks/`)
- **Refactor**: ✅ 3 standalone frameworks to use shared utilities (in `advanced/`)
- **Eliminate**: ✅ ~2000-3000 lines of duplicated code in frameworks
- **Standardize**: ✅ Consistent CLI patterns across all 6 frameworks
- **Reorganize**: ✅ Directory structure implemented (`foundation/`, `frameworks/`, `advanced/`, `legacy/`, `utilities/`)

### Key Decision: phase-4-validation vs test-infra Utilities

**Question**: Should `tests/phase-4-validation/` be refactored to use `tests/test-infra/utils/`?

**Answer**: **No, not in Phase 4 consolidation**

**Rationale**:

- **Stability Priority**: phase-4-validation is the golden standard for release validation
- **Low Duplication**: Only ~100 lines of logging code overlap with `test-infra/utils/log-utils.sh`
- **Unique Features**: State management and resume functionality are unique to phase-4-validation
- **Risk vs Benefit**: Breaking the stable validation framework is not worth ~100 lines of code reduction
- **Future Opportunity**: Consider gradual migration in Phase 5 without risking stability

**Current State**:

- `phase-4-validation/lib-common.sh`: ~411 lines (self-contained)
- `test-infra/utils/`: 5 modules, ~2,917 lines (shared infrastructure)
- Overlap: Minimal (mostly logging patterns)

**See [Consolidation Plan](01-consolidation-plan.md#tier-1-end-to-end-validation-keep-as-is) for detailed analysis**

## References

### Related Documentation

- **Test Frameworks**: `tests/README.md` - Current test execution guide
- **End-to-End Validation**: `tests/e2e-system-setup/README.md` - Step-by-step validation framework
- **Phase 4 Consolidation**: `task-lists/hpc-slurm/pending/phase-4-consolidation.md` - Ansible consolidation tasks
- **Design Documents**: `docs/design-docs/` - Architecture and design documentation

### Existing Utilities (Leverage in Consolidation)

The `tests/test-infra/utils/` directory contains **5 comprehensive utility modules** (~2,917 lines) providing:

- **`log-utils.sh`** (~261 lines) - Logging infrastructure with structured output
- **`cluster-utils.sh`** (~713 lines) - Cluster lifecycle management using ai-how API
- **`vm-utils.sh`** (~505 lines) - VM discovery, SSH connectivity, remote execution
- **`ansible-utils.sh`** (~278 lines) - Ansible deployment and virtual environment management
- **`test-framework-utils.sh`** (~1,160 lines) - Test orchestration and Ansible integration

**See [Test Inventory](00-test-inventory.md#shared-utilities) for comprehensive utility documentation.**

### Framework Utilities (Created)

- **`framework-cli.sh`** ✅ (~459 lines) - Standardized CLI parsing and command dispatch
- **`framework-orchestration.sh`** ✅ (~504 lines) - High-level workflow orchestration
- **`framework-template.sh`** ✅ (~419 lines) - Base template for new frameworks

All located in `tests/test-infra/utils/` and used by all 6 frameworks.

## Timeline

**Framework Consolidation**: ✅ COMPLETE (15.5 hours)

| Phase | Duration | Status |
|-------|----------|--------|
| Phase 1: Test Plan Documentation | 2 hours | ✅ COMPLETE (2025-10-24) |
| Phase 2: Extract Common Patterns | 2.5 hours | ✅ COMPLETE (2025-10-25) |
| Phase 3: Create Unified Frameworks | 6 hours | ✅ COMPLETE (2025-10-27) |
| Phase 4: Refactor Standalone Frameworks | 2.5 hours | ✅ COMPLETE (2025-10-27) |
| Phase 5: Validation and Testing | 2.5 hours | ✅ COMPLETE (2025-10-27) |
| Phase 6: Directory Reorganization | 2-3 hours | ✅ COMPLETE (2025-10-27) |

**Next Initiative**: Test Suite Refactoring (14 hours, 3 phases) - See [09-test-suite-refactoring-plan.md](09-test-suite-refactoring-plan.md)

## Quick Links

### HPC SLURM Testing (Complete ✅)

- [Test Inventory](00-test-inventory.md) - What tests exist today
- [Consolidation Plan](01-consolidation-plan.md) - Consolidation strategy and execution
- [Component Matrix](02-component-matrix.md) - Test coverage by component
- [Framework Specifications](03-framework-specifications.md) - Detailed framework specs
- [Implementation Phases](04-implementation-phases.md) - Step-by-step execution record
- [Validation Checklist](05-validation-checklist.md) - Quality assurance criteria
- [Test Dependencies Matrix](06-test-dependencies-matrix.md) - Per-test requirements and cluster configuration
- [Directory Reorganization](07-directory-reorganization.md) - Directory structure reorganization (COMPLETE)

### Cloud Cluster Testing (New)

- [Cloud Cluster Testing](08-cloud-cluster-testing.md) - Kubernetes, MLOps, and inference testing requirements
- [Cloud Testing Tasks](cloud-testing-tasks.md) - Task breakdown and implementation checklist for cloud testing

### Test Suite Refactoring (New)

- [Test Suite Refactoring Plan](09-test-suite-refactoring-plan.md) - Eliminate code duplication in test suite scripts

## Contributing

When adding or modifying tests:

1. Update the relevant files in this test plan
2. Follow the templates in `templates/`
3. Maintain the three-tier architecture
4. Adhere to standardized CLI patterns
5. Keep files under 1000 lines for LLM optimization

## Questions or Issues

For questions about the test plan, refer to:

- `tests/README.md` for execution guidance
- `tests/e2e-system-setup/README.md` for end-to-end validation
- This test plan for strategic decisions and consolidation approach
