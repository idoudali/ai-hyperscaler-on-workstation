# Test Framework Consolidation Plan

## Overview

This document outlines the strategy for consolidating 15 test framework scripts into 7 frameworks, eliminating
2000-3000 lines of duplicated code while preserving all test coverage and improving maintainability.

## Current State Analysis

### Problems Identified

1. **Code Duplication**: ~25-35% of framework code is duplicated across 15 scripts
2. **Inconsistent Patterns**: Minor variations in CLI parsing and error handling
3. **Maintenance Burden**: Changes require updating 15 separate files
4. **Testing Complexity**: 15 frameworks to test, validate, and maintain
5. **Documentation Overhead**: Each framework has its own documentation to maintain

### Current Test Architecture (3 Tiers)

#### Tier 1: End-to-End Validation (KEEP AS-IS)

**Location**: `tests/phase-4-validation/`

**Status**: ✅ Complete and automated

**Purpose**: Comprehensive 10-step end-to-end validation framework

**Rationale for Preservation**:

- Proven, stable, and fully automated
- Serves as "golden standard" for complete system validation
- Well-documented and battle-tested
- No duplication issues
- Critical for release validation

**Components**:

- `run-all-steps.sh` - Main orchestration script
- `step-00-prerequisites.sh` through `step-10-regression-tests.sh`
- `lib-common.sh` - Internal utility functions
- Comprehensive documentation in `tests/phase-4-validation/README.md`

**Relationship with `test-infra/` Utilities**:

The phase-4-validation framework currently maintains its own `lib-common.sh` (~411 lines) with utility functions
that partially overlap with `test-infra/utils/`:

| Function Category | phase-4-validation | test-infra/utils/ | Overlap |
|-------------------|-------------------|-------------------|---------|
| Logging | `lib-common.sh` | `log-utils.sh` | ✅ Yes (~100 lines) |
| State Management | `lib-common.sh` | N/A | ❌ Unique |
| Cluster Management | `lib-common.sh` | `cluster-utils.sh` | Partial |
| VM Operations | `lib-common.sh` | `vm-utils.sh` | Minimal |
| Ansible Deployment | `lib-common.sh` | `ansible-utils.sh` | Minimal |

**Future Improvement Opportunity (Post-Consolidation)**:

While phase-4-validation is preserved as-is for this consolidation effort, a **future Phase 5 improvement** could:

1. **Gradually migrate** `lib-common.sh` to use `test-infra/utils/` modules
2. **Preserve state management** functions (unique to phase-4-validation)
3. **Maintain backward compatibility** to avoid breaking the stable validation framework
4. **Reduce duplication** by ~100 lines of logging code

**Consolidation Decision**:

- ✅ **Keep phase-4-validation AS-IS** for Phase 4 consolidation
- ✅ **Do NOT refactor** `lib-common.sh` during this consolidation
- ⏸️ **Consider for Phase 5** - gradual utility migration without risk to stability

#### Tier 2: Test Frameworks (CONSOLIDATION TARGET)

**Location**: `tests/test-*-framework.sh`

**Current Count**: 15 frameworks

**Target Count**: 7 frameworks (53% reduction)

**Purpose**: Orchestrate cluster lifecycle and test suite execution

**Consolidation Strategy**: Combine frameworks with similar purposes and refactor standalone frameworks

#### Tier 3: Component Test Suites (PRESERVE)

**Location**: `tests/suites/*/`

**Count**: 16 test suite directories with ~80+ validation scripts

**Status**: ✅ Well-organized and comprehensive

**Rationale for Preservation**:

- Actual test logic is sound and proven
- Well-organized by component
- No significant duplication
- Changes would require extensive re-testing
- Clear separation of concerns

**Action**: NO CHANGES to test suites - only framework orchestration changes

## Consolidation Strategy

### Three-Tier Consolidation Approach

1. **Create 3 New Unified Frameworks**: Replace 11 existing frameworks
2. **Refactor 4 Standalone Frameworks**: Keep but improve with shared utilities
3. **Extract Shared Utilities**: Create reusable modules for common patterns

### New Unified Frameworks (3 Total)

#### 1. test-hpc-runtime-framework.sh (NEW)

**Purpose**: Unified runtime validation framework for HPC compute nodes

**Replaces 6 Frameworks**:

1. `test-cgroup-isolation-framework.sh` (13K) - Cgroup configuration
2. `test-gpu-gres-framework.sh` (11K) - GPU GRES configuration
3. `test-job-scripts-framework.sh` (16K) - Job script validation
4. `test-dcgm-monitoring-framework.sh` (22K) - GPU monitoring
5. `test-container-integration-framework.sh` (32K) - Container integration
6. `test-slurm-compute-framework.sh` (15K) - Compute node deployment

**Rationale**:

- All validate runtime configuration via Ansible
- All use similar cluster configurations
- All test compute node functionality
- Logical grouping by deployment phase

**Test Suite Integration**:

- `suites/cgroup-isolation/` - Cgroup tests
- `suites/gpu-gres/` - GPU GRES tests
- `suites/job-scripts/` - Job script tests
- `suites/dcgm-monitoring/` - DCGM tests
- `suites/container-integration/` - Container tests
- `suites/slurm-compute/` - Compute tests

**Configuration**: `test-infra/configs/test-hpc-runtime.yaml`

**Estimated Size**: ~40K (vs 109K for 6 separate frameworks)

**Code Reduction**: ~69K (63% reduction)

#### 2. test-hpc-packer-controller-framework.sh (NEW)

**Purpose**: Unified Packer validation for HPC controller images

**Replaces 4 Frameworks**:

1. `test-slurm-controller-framework.sh` (13K) - SLURM controller
2. `test-slurm-accounting-framework.sh` (13K) - Job accounting
3. `test-monitoring-stack-framework.sh` (19K) - Prometheus monitoring
4. `test-grafana-framework.sh` (13K) - Grafana dashboards

**Rationale**:

- All validate HPC controller Packer image builds
- All deploy similar cluster configurations
- All test controller-side components
- Logical grouping by image type

**Test Suite Integration**:

- `suites/slurm-controller/` - Controller tests
- `suites/monitoring-stack/` - Monitoring tests
- `suites/basic-infrastructure/` - Basic infrastructure tests

**Configuration**: `test-infra/configs/test-hpc-packer-controller.yaml`

**Estimated Size**: ~35K (vs 58K for 4 separate frameworks)

**Code Reduction**: ~23K (40% reduction)

#### 3. test-hpc-packer-compute-framework.sh (NEW)

**Purpose**: Unified Packer validation for HPC compute images

**Replaces 1 Framework**:

1. `test-container-runtime-framework.sh` (13K) - Apptainer/Singularity

**Rationale**:

- Validates HPC compute Packer image builds
- Provides consistent Packer validation pattern
- Matches controller framework structure
- Room for future compute image components

**Test Suite Integration**:

- `suites/container-runtime/` - Container runtime tests

**Configuration**: `test-infra/configs/test-hpc-packer-compute.yaml`

**Estimated Size**: ~15K (slightly larger than original for consistency)

**Code Reduction**: Minimal, but provides consistency and future scalability

### Standalone Frameworks to Keep (4 Total)

These frameworks have unique requirements and should remain standalone but be refactored to use shared utilities:

#### 1. test-beegfs-framework.sh (REFACTOR)

**Current Size**: 15K

**Keep Because**:

- Multi-node parallel filesystem with complex deployment
- Unique storage validation requirements
- Specialized BeeGFS-specific test suite
- Not logically part of HPC runtime or Packer builds

**Refactor Actions**:

- Extract duplicated CLI parsing to `framework-cli.sh`
- Use `framework-orchestration.sh` for cluster management
- Reduce from 15K to ~8K (47% reduction)

**Test Suite**: `suites/beegfs/`

#### 2. test-virtio-fs-framework.sh (REFACTOR)

**Current Size**: 24K

**Keep Because**:

- Specialized VirtIO-FS filesystem sharing
- Unique host-guest integration testing
- Not part of standard HPC deployment
- Complex validation requirements

**Refactor Actions**:

- Extract duplicated patterns to shared utilities
- Standardize CLI interface
- Reduce from 24K to ~12K (50% reduction)

**Test Suite**: `suites/virtio-fs/`

#### 3. test-pcie-passthrough-framework.sh (REFACTOR)

**Current Size**: 13K

**Keep Because**:

- Hardware-dependent GPU passthrough testing
- Requires specific GPU hardware
- Specialized PCI validation
- Not applicable to all deployments

**Refactor Actions**:

- Use shared utility functions
- Standardize CLI and error handling
- Reduce from 13K to ~7K (46% reduction)

**Test Suite**: `suites/gpu-validation/`

#### 4. test-container-registry-framework.sh (REFACTOR)

**Current Size**: 50K

**Keep Because**:

- Complex multi-phase deployment workflow
- Registry installation + image distribution + SLURM integration
- Extensive validation requirements
- Large, feature-rich test suite

**Refactor Actions**:

- Extract common patterns to shared utilities
- Use standardized orchestration
- Reduce from 50K to ~35K (30% reduction)

**Test Suite**: `suites/container-registry/`

## Code Duplication Elimination

### Pattern 1: CLI Command Parsing (~750 lines)

**Current Duplication**: Repeated in all 15 frameworks

**Solution**: Extract to `tests/test-infra/utils/framework-cli.sh`

**New Shared Function**:

```bash
# Parse and dispatch framework CLI commands
# Usage: parse_framework_cli "$@"
parse_framework_cli() {
    local command="${1:-e2e}"
    shift || true
    
    case "$command" in
        e2e|end-to-end)
            run_e2e_workflow "$@"
            ;;
        start-cluster)
            start_test_cluster "$@"
            ;;
        stop-cluster)
            stop_test_cluster "$@"
            ;;
        deploy-ansible)
            deploy_ansible_config "$@"
            ;;
        run-tests)
            run_test_suite_wrapper "$@"
            ;;
        list-tests)
            list_test_scripts "$@"
            ;;
        run-test)
            run_individual_test "$@"
            ;;
        status)
            show_cluster_status "$@"
            ;;
        help|-h|--help)
            show_framework_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_framework_help
            return 1
            ;;
    esac
}
```

**Benefits**:

- Single source of truth for CLI parsing
- Consistent command handling
- Easy to add new commands
- Reduces each framework by ~50 lines

### Pattern 2: Cluster Lifecycle Management (~300 lines)

**Current Duplication**: Repeated in all 15 frameworks

**Solution**: Extract to `tests/test-infra/utils/framework-orchestration.sh`

**New Shared Functions**:

```bash
# Start test cluster
start_test_cluster() {
    log_info "Starting test cluster: $TEST_CONFIG"
    ai-how cluster create --config "$TEST_CONFIG" || {
        log_error "Failed to start cluster"
        return 1
    }
    log_success "Cluster started successfully"
}

# Stop and destroy test cluster
stop_test_cluster() {
    log_info "Stopping test cluster"
    ai-how cluster destroy --config "$TEST_CONFIG" || true
    log_info "Cluster stopped"
}

# Run end-to-end workflow
run_e2e_workflow() {
    start_test_cluster || return 1
    deploy_ansible_config || { stop_test_cluster; return 1; }
    run_test_suite_wrapper || { stop_test_cluster; return 1; }
    stop_test_cluster
}
```

**Benefits**:

- Consistent cluster management
- Centralized error handling
- Easy to modify workflow
- Reduces each framework by ~20 lines

### Pattern 3: Help Functions (~600 lines)

**Current Duplication**: Each framework has custom help text

**Solution**: Extract to `tests/test-infra/utils/framework-cli.sh` with templating

**New Shared Function**:

```bash
# Generate standardized help output
# Usage: show_framework_help
show_framework_help() {
    cat << EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

${FRAMEWORK_NAME} - ${FRAMEWORK_DESCRIPTION}

COMMANDS:
    e2e, end-to-end    Run complete end-to-end test (default)
    start-cluster      Start test cluster (keeps running)
    stop-cluster       Stop and destroy test cluster
    deploy-ansible     Deploy Ansible configuration
    run-tests          Run test suite on deployed cluster
    list-tests         List all available test scripts
    run-test NAME      Run specific test by name
    status             Show cluster status
    help               Show this help message

OPTIONS:
    -h, --help         Show this help message
    -v, --verbose      Enable verbose output
    --no-cleanup       Skip cleanup after tests
    --interactive      Enable interactive prompts

EXAMPLES:
    # Complete end-to-end test with cleanup
    $(basename "$0") e2e

    # Modular workflow for debugging
    $(basename "$0") start-cluster
    $(basename "$0") deploy-ansible
    $(basename "$0") run-tests
    $(basename "$0") stop-cluster

    # Run specific test
    $(basename "$0") list-tests
    $(basename "$0") run-test check-installation.sh

TEST SUITES:
$(list_test_suites_help)

CONFIGURATION:
    Config File: $TEST_CONFIG
    Test Suite:  $TEST_SUITE_DIR

For more information, see:
    tests/README.md
    tests/phase-4-validation/README.md
EOF
}
```

**Benefits**:

- Consistent help format
- Automatic test suite listing
- Easy to maintain
- Reduces each framework by ~40 lines

### Pattern 4: Test Execution (~300 lines)

**Current Duplication**: Similar test execution logic

**Solution**: Enhance existing `run_test_suite()` in `test-framework-utils.sh`

**Benefits**:

- Already partially implemented
- Consistent test execution
- Centralized error handling
- Reduces each framework by ~20 lines

### Pattern 5: Ansible Deployment (~450 lines)

**Current Duplication**: Similar deployment patterns

**Solution**: Enhance existing `deploy_ansible_playbook()` in `test-framework-utils.sh`

**Benefits**:

- Already partially implemented
- Consistent deployment
- Better error messages
- Reduces each framework by ~30 lines

## Shared Utilities Structure

### New Utility Modules

#### 1. framework-cli.sh (NEW)

**Purpose**: Standardized CLI parsing and command dispatch

**Size**: ~400 lines

**Functions**:

- `parse_framework_cli()` - Main CLI parser
- `show_framework_help()` - Standardized help output
- `parse_framework_options()` - Option parsing
- `list_test_suites_help()` - Test suite listing for help

#### 2. framework-orchestration.sh (NEW)

**Purpose**: Cluster lifecycle and workflow orchestration

**Size**: ~300 lines

**Functions**:

- `start_test_cluster()` - Start cluster
- `stop_test_cluster()` - Stop cluster
- `run_e2e_workflow()` - End-to-end orchestration
- `deploy_ansible_config()` - Deploy Ansible
- `run_test_suite_wrapper()` - Run tests with error handling

#### 3. framework-template.sh (NEW)

**Purpose**: Base template for new test frameworks

**Size**: ~200 lines

**Contains**:

- Framework structure template
- Variable declaration template
- Function stubs
- Usage examples

#### 4. test-framework-utils.sh (ENHANCE)

**Current**: ~500 lines

**Target**: ~700 lines

**Enhancements**:

- Improve `deploy_ansible_playbook()` with better error handling
- Enhance `run_test_suite()` with progress indicators
- Add `validate_test_config()` for config validation
- Add `setup_test_environment()` for environment preparation

## Framework Template Structure

### Base Template for All Frameworks

```bash
#!/usr/bin/env bash
# Framework Name: [FRAMEWORK_NAME]
# Purpose: [FRAMEWORK_PURPOSE]
# Test Suites: [TEST_SUITE_LIST]

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Framework metadata
export FRAMEWORK_NAME="[Framework Name]"
export FRAMEWORK_DESCRIPTION="[Framework Description]"

# Source shared utilities
source "$PROJECT_ROOT/tests/test-infra/utils/test-framework-utils.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/framework-cli.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/framework-orchestration.sh"

# Framework-specific configuration
export TEST_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/[config-file].yaml"
export TEST_SUITE_DIR="$PROJECT_ROOT/tests/suites/[suite-name]"
export ANSIBLE_PLAYBOOK="$PROJECT_ROOT/ansible/playbooks/[playbook].yml"

# ============================================================================
# Framework-Specific Functions
# ============================================================================

# Override or extend default behavior as needed
# [framework-specific functions here]

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    # Validate environment
    ensure_project_root
    
    # Parse CLI and dispatch command
    parse_framework_cli "$@"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Implementation Benefits

### Quantifiable Improvements

1. **Code Reduction**: 2000-3000 lines eliminated (~25-35%)
2. **Framework Count**: 15 → 7 frameworks (53% reduction)
3. **Maintenance Surface**: 15 files → 7 files + 3 utilities
4. **Test Coverage**: 100% preserved (no test logic changes)
5. **Development Time**: ~15.5 hours total implementation

### Qualitative Improvements

1. **Consistency**: All frameworks use identical CLI patterns
2. **Maintainability**: Bug fixes in one place benefit all frameworks
3. **Documentation**: Single source of truth for patterns
4. **Developer Experience**: Consistent interface across all tests
5. **Testability**: Smaller, focused frameworks are easier to test
6. **Scalability**: Easy to add new frameworks following template
7. **Debugging**: Standardized error handling and logging

## Migration Path

### Phase-by-Phase Migration

#### Phase 1: Test Plan Documentation (2 hours)

- Create test plan documents (this directory)
- Document current state
- Define target architecture
- Create implementation plan

#### Phase 2: Extract Common Patterns (2.5 hours)

- Create `framework-cli.sh` utility
- Create `framework-orchestration.sh` utility
- Create `framework-template.sh` base template
- Enhance `test-framework-utils.sh`
- Validate utilities work independently

#### Phase 3: Create Unified Frameworks (6 hours)

- Create `test-hpc-runtime-framework.sh` (2.5 hours)
- Create `test-hpc-packer-controller-framework.sh` (2 hours)
- Create `test-hpc-packer-compute-framework.sh` (1.5 hours)
- Test each framework independently

#### Phase 4: Refactor Standalone Frameworks (2.5 hours)

- Refactor `test-beegfs-framework.sh` (40 minutes)
- Refactor `test-virtio-fs-framework.sh` (40 minutes)
- Refactor `test-pcie-passthrough-framework.sh` (40 minutes)
- Refactor `test-container-registry-framework.sh` (30 minutes)

#### Phase 5: Validation and Cleanup (2.5 hours)

- Run all new frameworks end-to-end (1 hour)
- Update Makefile targets (30 minutes)
- Update documentation (30 minutes)
- Delete old frameworks and configs (15 minutes)
- Final validation (15 minutes)

## Validation Strategy

### Before Consolidation

1. **Baseline**: Run all 15 existing frameworks successfully
2. **Document**: Record test outputs for comparison
3. **Backup**: Create backup of all framework scripts
4. **Verify**: Confirm all test suites are executable

### During Consolidation

1. **Incremental**: Build and test each new framework independently
2. **Compare**: Verify new frameworks produce same results as old ones
3. **Iterate**: Fix issues before moving to next framework
4. **Document**: Track any behavior changes or improvements

### After Consolidation

1. **Full Suite**: Run all 7 new frameworks end-to-end
2. **Compare Results**: Match against baseline from old frameworks
3. **Test Coverage**: Verify all test suites still execute
4. **CLI Validation**: Test all CLI commands and options
5. **Documentation**: Confirm all documentation is updated

## Risk Mitigation

### Identified Risks

1. **Test Behavior Changes**: New frameworks might behave differently
   - **Mitigation**: Extensive comparison testing against baselines

2. **CLI Compatibility**: Scripts or CI/CD might depend on old CLIs
   - **Mitigation**: Maintain backward compatibility where possible

3. **Hidden Dependencies**: Unknown dependencies on old frameworks
   - **Mitigation**: Keep backups and document rollback procedures

4. **Time Overruns**: Implementation might take longer than estimated
   - **Mitigation**: Phased approach allows stopping at any stable point

5. **Regression Issues**: New bugs introduced during refactoring
   - **Mitigation**: Comprehensive validation before old framework deletion

### Rollback Plan

If consolidation causes issues:

1. **Keep Backups**: All old frameworks backed up before deletion
2. **Phased Rollback**: Can rollback individual frameworks if needed
3. **Documentation**: Rollback procedures documented
4. **Testing**: Rollback tested before production deployment

## Success Criteria

### Must-Have Criteria

- [ ] All 7 new/refactored frameworks created
- [ ] All test suites execute successfully
- [ ] All CLI commands work correctly
- [ ] Code reduction of 2000-3000 lines achieved
- [ ] Documentation updated completely
- [ ] Old frameworks backed up and deleted
- [ ] Makefile targets updated
- [ ] All validation tests pass

### Nice-to-Have Criteria

- [ ] Performance improvement in test execution
- [ ] Better error messages and logging
- [ ] Improved developer documentation
- [ ] CI/CD integration tested
- [ ] Framework template used successfully

## Timeline Summary

**Total Estimated Time**: 15.5 hours

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| 1: Test Plan | 2 hours | Complete test plan documentation |
| 2: Utilities | 2.5 hours | 3 new utilities + enhancements |
| 3: Unified Frameworks | 6 hours | 3 new unified frameworks |
| 4: Refactor Standalone | 2.5 hours | 4 refactored frameworks |
| 5: Validation | 2.5 hours | Complete validation + cleanup |

## Conclusion

This consolidation plan provides a clear, phased approach to reducing test framework complexity while preserving
100% test coverage. The three-tier architecture (End-to-End Validation, Test Frameworks, Component Test Suites)
ensures we consolidate at the right level without disrupting proven test logic.

By eliminating 2000-3000 lines of duplicated code and reducing framework count from 15 to 7, we significantly
improve maintainability while providing a better developer experience through consistent CLI patterns and
standardized utilities.

The phased implementation approach allows stopping at any stable point, and comprehensive validation ensures
we don't introduce regressions during consolidation.

## Related Refactoring Opportunities

### Test Suite Script Refactoring

**Status**: 📝 Planned (See [09-test-suite-refactoring-plan.md](09-test-suite-refactoring-plan.md))

While this consolidation plan focuses on test framework scripts, there is a **separate opportunity** to refactor
the test suite scripts in `tests/suites/` to eliminate code duplication:

**Scope**: 80+ test scripts across 16 test suite directories
**Duplication**: 2,000-3,000 lines of duplicated logging, color definitions, and test execution patterns
**Impact**: 30-40% code reduction in test suite scripts
**Timeline**: 14 hours estimated effort

**Key Benefits**:

- Centralized logging and color definitions
- Standardized test execution patterns
- Improved maintainability and consistency
- Better developer experience

**Implementation Strategy**:

- Create shared utilities for test suites (`tests/suites/common/`)
- Refactor individual test scripts to use shared utilities
- Preserve all test logic and functionality
- Maintain backward compatibility

This refactoring complements the framework consolidation by addressing duplication at the test script level,
providing comprehensive code deduplication across the entire test infrastructure.
