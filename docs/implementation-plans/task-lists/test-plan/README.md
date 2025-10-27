# HPC SLURM Test Plan

## Overview

This directory contains a comprehensive, modular test plan for the HPC SLURM infrastructure consolidation project.
The test plan is structured to be both human-readable and optimized for Large Language Model (LLM) context consumption.

## Purpose

- **Consolidate Test Infrastructure**: Reduce code duplication across 15+ test frameworks
- **Explicit Test Coverage**: Map all tests to components, frameworks, and validation goals
- **Standardize Test Execution**: Implement consistent CLI patterns across all frameworks
- **Enable Modular Testing**: Support running individual tests, test suites, or full end-to-end validation

## Current Implementation Status

**Phase 1**: ✅ COMPLETE (Documentation)
**Phase 2**: ✅ COMPLETE (2025-10-25) - Shared utilities created

- framework-cli.sh (459 lines) - Standardized CLI parser
- framework-orchestration.sh (504 lines) - Cluster lifecycle & orchestration
- framework-template.sh (419 lines) - Framework template for new frameworks

**Phase 3**: ✅ COMPLETE (2025-10-27) - 3 unified frameworks created
**Phase 4**: ✅ COMPLETE (2025-10-27) - 4 standalone frameworks refactored
**Phase 5**: ✅ COMPLETE (2025-10-27) - Validation and cleanup complete

**Final Results**:

- **11 deprecated frameworks deleted**
- **7 frameworks consolidated and refactored**
- **42 new Makefile targets added**
- **~2000-3000 lines of duplicated code eliminated**
- **Consistent CLI patterns across all frameworks**

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

1. **Tier 1: End-to-End Validation** (`tests/phase-4-validation/`)
   - Comprehensive 10-step validation framework
   - **Kept as-is** (golden standard for release validation)
   - Self-contained with `lib-common.sh` (~411 lines)
   - Status: ✅ Complete and automated
   - **Not part of Phase 4 consolidation target**

2. **Tier 2: Test Frameworks** (`tests/test-*-framework.sh`)
   - Orchestrate cluster lifecycle and test execution
   - **CONSOLIDATION TARGET**: Reduce from 15 to 7 frameworks
   - Standardize CLI patterns and shared utilities

3. **Tier 3: Component Test Suites** (`tests/suites/*/`)
   - Actual test logic and validation scripts
   - **PRESERVED**: No changes to existing test suites
   - Well-organized, focused, and proven

### Consolidation Strategy

- **Combine**: 11 frameworks → 3 unified frameworks
- **Refactor**: 4 standalone frameworks to use shared utilities
- **Eliminate**: ~2000-3000 lines of duplicated code
- **Standardize**: Consistent CLI patterns across all frameworks

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

- **Test Frameworks**: `tests/README.md`
- **End-to-End Validation**: `tests/phase-4-validation/README.md`
- **Phase 4 Consolidation**: `task-lists/hpc-slurm/pending/phase-4-consolidation.md`
- **Design Documents**: `docs/design-docs/`

### Existing Utilities (Leverage in Consolidation)

The `tests/test-infra/utils/` directory contains **5 comprehensive utility modules** (~2,917 lines) providing:

- **`log-utils.sh`** (~261 lines) - Logging infrastructure with structured output
- **`cluster-utils.sh`** (~713 lines) - Cluster lifecycle management using ai-how API
- **`vm-utils.sh`** (~505 lines) - VM discovery, SSH connectivity, remote execution
- **`ansible-utils.sh`** (~278 lines) - Ansible deployment and virtual environment management
- **`test-framework-utils.sh`** (~1,160 lines) - Test orchestration and Ansible integration

**See [Test Inventory](00-test-inventory.md#shared-utilities) for comprehensive utility documentation.**

### New Utilities (To Be Created)

- **`framework-cli.sh`** (NEW) - Standardized CLI parsing and command dispatch
- **`framework-orchestration.sh`** (NEW) - High-level workflow orchestration
- **`framework-template.sh`** (NEW) - Base template for new frameworks

## Timeline

**Total Estimated Effort**: 15.5 hours

| Phase | Duration | Status |
|-------|----------|--------|
| Phase 1: Test Plan Documentation | 2 hours | ✅ COMPLETE |
| Phase 2: Extract Common Patterns | 2.5 hours | ✅ COMPLETE (2025-10-25) |
| Phase 3: Create Unified Frameworks | 6 hours | ✅ COMPLETE (2025-10-27) |
| Phase 4: Refactor Standalone Frameworks | 2.5 hours | ✅ COMPLETE (2025-10-27) |
| Phase 5: Validation and Testing | 2.5 hours | ✅ COMPLETE (2025-10-27) |

## Quick Links

- [Test Inventory](00-test-inventory.md) - What tests exist today
- [Consolidation Plan](01-consolidation-plan.md) - How we'll consolidate
- [Component Matrix](02-component-matrix.md) - What each test validates
- [Framework Specifications](03-framework-specifications.md) - Detailed framework specs
- [Implementation Phases](04-implementation-phases.md) - Step-by-step execution
- [Validation Checklist](05-validation-checklist.md) - Quality assurance
- [Test Dependencies Matrix](06-test-dependencies-matrix.md) - Per-test requirements and cluster configuration

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
- `tests/phase-4-validation/README.md` for end-to-end validation
- This test plan for strategic decisions and consolidation approach
