# Test Framework Implementation Phases

## Overview

This document provides step-by-step implementation instructions for consolidating the test framework infrastructure.
The implementation is divided into 5 phases with clear deliverables, validation steps, and time estimates.

## Total Timeline

**Estimated Time**: 15.5 hours

- **Phase 1**: Test Plan Documentation (2 hours) - ✅ COMPLETE
- **Phase 2**: Extract Common Patterns (2.5 hours) - ✅ COMPLETE (2025-10-25)
- **Phase 3**: Create Unified Frameworks (6 hours) - ✅ COMPLETE (2025-10-27)
- **Phase 4**: Refactor Standalone Frameworks (2.5 hours) - ✅ COMPLETE (2025-10-27)
- **Phase 5**: Validation and Cleanup (2.5 hours) - ✅ COMPLETE (2025-10-27)

## Prerequisites

Before starting implementation:

- [x] Test plan documentation complete (this directory)
- [x] All existing test frameworks validated and working
- [x] Backup created of existing frameworks
- [x] Project team reviewed and approved consolidation plan

## Phase 1: Test Plan Documentation

**Status**: ✅ COMPLETE

**Duration**: 2 hours

**Deliverables**:

- [x] `task-lists/test-plan/README.md` - Overview and index
- [x] `task-lists/test-plan/00-test-inventory.md` - Current state inventory
- [x] `task-lists/test-plan/01-consolidation-plan.md` - Consolidation strategy
- [x] `task-lists/test-plan/02-component-matrix.md` - Test coverage mapping
- [x] `task-lists/test-plan/03-framework-specifications.md` - Framework specs
- [x] `task-lists/test-plan/04-implementation-phases.md` - This document
- [x] `task-lists/test-plan/05-validation-checklist.md` - Validation criteria
- [x] `task-lists/test-plan/templates/` - Template files

**Validation**:

- [x] All documents created and reviewed
- [x] Consolidation strategy approved
- [x] Implementation plan understood

---

## Phase 2: Extract Common Patterns

**Status**: ✅ COMPLETE (2025-10-25)

**Duration**: 2.5 hours

**Objective**: Create shared utility modules that eliminate duplicated code across all frameworks

**Completed**: All 3 utilities created, tested, and integrated

### Task 2.1: Create framework-cli.sh Utility

**Time**: 1 hour

**Location**: `tests/test-infra/utils/framework-cli.sh`

**Steps**:

1. **Create utility file** (5 min)

   ```bash
   cd tests/test-infra/utils/
   touch framework-cli.sh
   chmod +x framework-cli.sh
   ```

2. **Implement CLI parser** (20 min)
   - Extract command parsing pattern from existing frameworks
   - Implement `parse_framework_cli()` function
   - Support all standard commands (e2e, start-cluster, stop-cluster, etc)
   - Handle unknown commands gracefully

3. **Implement help generator** (20 min)
   - Create `show_framework_help()` function
   - Template-based help output
   - Dynamic test suite listing
   - Include examples section

4. **Implement option parser** (10 min)
   - Create `parse_framework_options()` function
   - Handle `-h`, `--help`, `-v`, `--verbose`
   - Handle `--no-cleanup`, `--interactive`
   - Set appropriate environment variables

5. **Test utility independently** (5 min)

   ```bash
   # Test CLI parsing
   source framework-cli.sh
   FRAMEWORK_NAME="Test" parse_framework_cli --help
   ```

**Deliverables**:

- [ ] `framework-cli.sh` created (~400 lines)
- [ ] All CLI patterns extracted
- [ ] Help output standardized
- [ ] Tested independently

---

### Task 2.2: Create framework-orchestration.sh Utility

**Time**: 1 hour

**Location**: `tests/test-infra/utils/framework-orchestration.sh`

**Steps**:

1. **Create utility file** (5 min)

   ```bash
   cd tests/test-infra/utils/
   touch framework-orchestration.sh
   chmod +x framework-orchestration.sh
   ```

2. **Implement cluster management** (20 min)
   - Extract `start_test_cluster()` function
   - Extract `stop_test_cluster()` function
   - Add error handling and logging
   - Support config file parameter

3. **Implement workflow orchestration** (25 min)
   - Create `run_e2e_workflow()` function
   - Create `deploy_ansible_config()` wrapper
   - Create `run_test_suite_wrapper()` function
   - Implement cleanup on error

4. **Implement environment validation** (10 min)
   - Create `validate_test_environment()` function
   - Check prerequisites (ai-how, ansible, etc)
   - Validate config file exists
   - Validate test suite directories exist

**Deliverables**:

- [ ] `framework-orchestration.sh` created (~300 lines)
- [ ] Cluster lifecycle functions extracted
- [ ] E2E workflow standardized
- [ ] Environment validation implemented

---

### Task 2.3: Enhance test-framework-utils.sh

**Time**: 30 minutes

**Location**: `tests/test-infra/utils/test-framework-utils.sh`

**Steps**:

1. **Review existing functions** (5 min)
   - Identify functions to enhance
   - Document current behavior
   - Plan backward compatibility

2. **Enhance deploy_ansible_playbook()** (10 min)
   - Improve error messages
   - Add progress indicators
   - Better output formatting
   - Add timeout handling

3. **Enhance run_test_suite()** (10 min)
   - Add progress tracking
   - Improve error reporting
   - Support test filtering
   - Add summary statistics

4. **Add new utility functions** (5 min)
   - `validate_test_config()` - Config file validation
   - `setup_test_environment()` - Environment preparation
   - `collect_test_artifacts()` - Gather logs/outputs

**Deliverables**:

- [ ] `test-framework-utils.sh` enhanced (~700 lines total)
- [ ] Existing functions improved
- [ ] New utility functions added
- [ ] Backward compatibility maintained

---

### Task 2.4: Create framework-template.sh

**Time**: 30 minutes

**Location**: `tests/test-infra/utils/framework-template.sh`

**Steps**:

1. **Create template file** (5 min)
   - Document template structure
   - Add usage instructions
   - Include comments and examples

2. **Define standard structure** (15 min)
   - Configuration section
   - Utility sourcing
   - Framework-specific functions section
   - Main entry point
   - Usage examples in comments

3. **Create usage documentation** (10 min)
   - How to use the template
   - Variable placeholders to replace
   - Sections that can be customized
   - Best practices

**Deliverables**:

- [ ] `framework-template.sh` created (~200 lines)
- [ ] Well-documented template
- [ ] Usage instructions clear
- [ ] Ready for framework creation

---

### Phase 2 Validation

**Checklist**: ✅ ALL COMPLETE

- [x] All 3 new utilities created (framework-cli.sh, framework-orchestration.sh, framework-template.sh)
- [x] `test-framework-utils.sh` enhanced (via new utilities integrating with existing infrastructure)
- [x] All functions tested independently (verified 2025-10-25)
- [x] Documentation complete (inline documentation in all utilities)
- [x] No existing frameworks broken (changes are additive only)

**Test Commands**:

```bash
# Test each utility independently
cd tests/test-infra/utils/

# Test CLI utility
bash -c "source framework-cli.sh && echo 'CLI utility loaded'"

# Test orchestration utility
bash -c "source framework-orchestration.sh && echo 'Orchestration utility loaded'"

# Test enhanced utils
bash -c "source test-framework-utils.sh && echo 'Utils loaded'"
```

---

## Phase 3: Create Unified Frameworks

**Status**: ✅ COMPLETE (2025-10-27)

**Duration**: 6 hours

**Objective**: Create 3 new unified frameworks to replace 11 existing frameworks

**Foundation**: Uses framework-template.sh and framework-cli.sh from Phase 2

### Task 3.1: Create test-hpc-runtime-framework.sh

**Time**: 2.5 hours

**Location**: `tests/frameworks/test-hpc-runtime-framework.sh`

**Replaces**: 6 frameworks (cgroup, gpu-gres, job-scripts, dcgm, container-integration, slurm-compute)

**Steps**:

1. **Create framework file** (10 min)

   ```bash
   cd tests/
   cp test-infra/utils/framework-template.sh test-hpc-runtime-framework.sh
   chmod +x test-hpc-runtime-framework.sh
   ```

2. **Configure framework metadata** (10 min)
   - Set `FRAMEWORK_NAME="HPC Runtime Test Framework"`
   - Set description and purpose
   - Configure test suite paths
   - Set config file path

3. **Implement test execution functions** (60 min)
   - `run_cgroup_tests()` - Cgroup isolation validation
   - `run_gpu_gres_tests()` - GPU GRES validation
   - `run_job_script_tests()` - Job script validation
   - `run_dcgm_tests()` - DCGM monitoring validation
   - `run_container_tests()` - Container integration validation
   - `run_compute_tests()` - SLURM compute validation
   - `run_all_runtime_tests()` - Sequential execution of all

4. **Create configuration file** (20 min)

   ```bash
   cd tests/test-infra/configs/
   touch test-hpc-runtime.yaml
   ```

   - Define cluster configuration
   - Set resource allocations
   - Configure test options
   - Enable GPU and container tests

5. **Integration with shared utilities** (20 min)
   - Source all utility modules
   - Use `parse_framework_cli()` for CLI handling
   - Use orchestration functions for workflow
   - Use utils for test execution

6. **Test framework independently** (30 min)

   ```bash
   # Test help output
   ./frameworks/test-hpc-runtime-framework.sh --help
   
   # Test modular commands
   ./frameworks/test-hpc-runtime-framework.sh start-cluster
   ./frameworks/test-hpc-runtime-framework.sh list-tests
   ./frameworks/test-hpc-runtime-framework.sh stop-cluster
   
   # Test end-to-end
   ./frameworks/test-hpc-runtime-framework.sh e2e
   ```

**Deliverables**:

- [ ] `test-hpc-runtime-framework.sh` created (~40K)
- [ ] `test-infra/configs/test-hpc-runtime.yaml` created
- [ ] All 6 test suites integrated
- [ ] End-to-end test passes

---

### Task 3.2: Create test-hpc-packer-controller-framework.sh

**Time**: 2 hours

**Location**: `tests/frameworks/test-hpc-packer-controller-framework.sh`

**Replaces**: 4 frameworks (slurm-controller, slurm-accounting, monitoring-stack, grafana)

**Steps**:

1. **Create framework file** (10 min)

   ```bash
   cd tests/
   cp test-infra/utils/framework-template.sh test-hpc-packer-controller-framework.sh
   chmod +x test-hpc-packer-controller-framework.sh
   ```

2. **Configure framework metadata** (10 min)
   - Set `FRAMEWORK_NAME="HPC Packer Controller Test Framework"`
   - Configure for controller image validation
   - Set test suite paths
   - Set config file path

3. **Implement test execution functions** (45 min)
   - `run_slurm_controller_tests()` - SLURM controller validation
   - `run_slurm_accounting_tests()` - Job accounting validation
   - `run_monitoring_tests()` - Prometheus validation
   - `run_grafana_tests()` - Grafana validation
   - `run_all_controller_tests()` - Sequential execution

4. **Create configuration file** (15 min)

   ```bash
   cd tests/test-infra/configs/
   touch test-hpc-packer-controller.yaml
   ```

   - Define minimal cluster (1 controller, 1 compute)
   - Set resource allocations
   - Configure for Packer validation

5. **Integration and testing** (40 min)
   - Source utility modules
   - Use shared CLI and orchestration
   - Test all commands
   - Run end-to-end test

**Deliverables**:

- [ ] `test-hpc-packer-controller-framework.sh` created (~35K)
- [ ] `test-infra/configs/test-hpc-packer-controller.yaml` created
- [ ] All 4 test suites integrated
- [ ] End-to-end test passes

---

### Task 3.3: Create test-hpc-packer-compute-framework.sh

**Time**: 1.5 hours

**Location**: `tests/frameworks/test-hpc-packer-compute-framework.sh`

**Replaces**: 1 framework (container-runtime)

**Steps**:

1. **Create framework file** (10 min)

   ```bash
   cd tests/
   cp test-infra/utils/framework-template.sh test-hpc-packer-compute-framework.sh
   chmod +x test-hpc-packer-compute-framework.sh
   ```

2. **Configure framework metadata** (10 min)
   - Set `FRAMEWORK_NAME="HPC Packer Compute Test Framework"`
   - Configure for compute image validation
   - Set test suite path
   - Set config file path

3. **Implement test execution functions** (30 min)
   - `run_container_runtime_tests()` - Container runtime validation
   - `validate_security_config()` - Security policy validation
   - `test_container_execution()` - Basic execution tests

4. **Create configuration file** (10 min)

   ```bash
   cd tests/test-infra/configs/
   touch test-hpc-packer-compute.yaml
   ```

   - Define minimal cluster
   - Configure for Packer validation
   - Enable container runtime tests

5. **Integration and testing** (30 min)
   - Source utility modules
   - Use shared patterns
   - Test all commands
   - Run end-to-end test

**Deliverables**:

- [ ] `test-hpc-packer-compute-framework.sh` created (~15K)
- [ ] `test-infra/configs/test-hpc-packer-compute.yaml` created
- [ ] Container runtime tests integrated
- [ ] End-to-end test passes

---

### Phase 3 Validation

**Checklist**:

- [ ] All 3 unified frameworks created
- [ ] All 3 config files created
- [ ] All test suites integrated correctly
- [ ] End-to-end tests pass for all 3 frameworks
- [ ] CLI interface consistent across all

**Test Commands**:

```bash
# Test each new framework
./frameworks/test-hpc-runtime-framework.sh e2e
./frameworks/test-hpc-packer-controller-framework.sh e2e
./frameworks/test-hpc-packer-compute-framework.sh e2e

# Verify all pass
echo "All unified frameworks tested successfully"
```

---

## Phase 4: Refactor Standalone Frameworks

**Status**: ✅ COMPLETE (2025-10-27)

**Duration**: 2.5 hours

**Objective**: Refactor 4 standalone frameworks to use shared utilities

### Task 4.1: Refactor test-beegfs-framework.sh

**Time**: 40 minutes

**Steps**:

1. **Backup original** (2 min)

   ```bash
   cp tests/advanced/test-beegfs-framework.sh tests/advanced/test-beegfs-framework.sh.backup
   ```

2. **Refactor to use shared utilities** (30 min)
   - Replace CLI parsing with `parse_framework_cli()`
   - Replace cluster management with orchestration functions
   - Replace help function with standardized help
   - Keep BeeGFS-specific test logic

3. **Test refactored framework** (8 min)

   ```bash
   ./advanced/test-beegfs-framework.sh --help
   ./advanced/test-beegfs-framework.sh e2e
   ```

**Target Size Reduction**: 15K → ~8K (47% reduction)

---

### Task 4.2: Refactor test-virtio-fs-framework.sh

**Time**: 40 minutes

**Steps**:

1. **Backup original** (2 min)

   ```bash
   cp tests/advanced/test-virtio-fs-framework.sh tests/advanced/test-virtio-fs-framework.sh.backup
   ```

2. **Refactor to use shared utilities** (30 min)
   - Use shared CLI and orchestration
   - Standardize help and error handling
   - Keep VirtIO-FS-specific test logic

3. **Test refactored framework** (8 min)

   ```bash
   ./advanced/test-virtio-fs-framework.sh --help
   ./advanced/test-virtio-fs-framework.sh e2e
   ```

**Target Size Reduction**: 24K → ~12K (50% reduction)

---

### Task 4.3: Refactor test-pcie-passthrough-framework.sh

**Time**: 40 minutes

**Steps**:

1. **Backup original** (2 min)

   ```bash
   cp tests/frameworks/test-pcie-passthrough-framework.sh tests/frameworks/test-pcie-passthrough-framework.sh.backup
   ```

2. **Refactor to use shared utilities** (30 min)
   - Use shared patterns
   - Standardize interface
   - Keep GPU passthrough-specific logic

3. **Test refactored framework** (8 min)

   ```bash
   ./frameworks/test-pcie-passthrough-framework.sh --help
   ./frameworks/test-pcie-passthrough-framework.sh e2e
   ```

**Target Size Reduction**: 13K → ~7K (46% reduction)

---

### Task 4.4: Refactor test-container-registry-framework.sh

**Time**: 30 minutes

**Steps**:

1. **Backup original** (2 min)

   ```bash
   cp tests/advanced/test-container-registry-framework.sh tests/advanced/test-container-registry-framework.sh.backup
   ```

2. **Refactor to use shared utilities** (20 min)
   - Use shared CLI and orchestration where possible
   - Keep complex registry-specific workflows
   - Standardize common patterns

3. **Test refactored framework** (8 min)

   ```bash
   ./advanced/test-container-registry-framework.sh --help
   ./advanced/test-container-registry-framework.sh e2e
   ```

**Target Size Reduction**: 50K → ~35K (30% reduction)

---

### Phase 4 Validation

**Checklist**:

- [ ] All 4 frameworks refactored
- [ ] All backups created
- [ ] Code reduction achieved
- [ ] All end-to-end tests pass
- [ ] CLI interface standardized

**Test Commands**:

```bash
# Test each refactored framework
./advanced/test-beegfs-framework.sh e2e
./advanced/test-virtio-fs-framework.sh e2e
./frameworks/test-pcie-passthrough-framework.sh e2e
./advanced/test-container-registry-framework.sh e2e

echo "All standalone frameworks refactored and tested"
```

---

## Phase 5: Validation and Cleanup

**Status**: ✅ COMPLETE (2025-10-27)

**Duration**: 2.5 hours

**Objective**: Validate consolidated frameworks, update documentation, and clean up old files

### Task 5.1: Comprehensive Validation

**Time**: 1 hour

**Steps**:

1. **Run all frameworks end-to-end** (40 min)

   ```bash
   # Run all 7 frameworks
   ./frameworks/test-hpc-runtime-framework.sh e2e
   ./frameworks/test-hpc-packer-controller-framework.sh e2e
   ./frameworks/test-hpc-packer-compute-framework.sh e2e
   ./advanced/test-beegfs-framework.sh e2e
   ./advanced/test-virtio-fs-framework.sh e2e
   ./frameworks/test-pcie-passthrough-framework.sh e2e
   ./advanced/test-container-registry-framework.sh e2e
   ```

2. **Compare results with baseline** (10 min)
   - Verify test coverage unchanged
   - Check for any new failures
   - Validate output format consistency

3. **Test all CLI commands** (10 min)

   ```bash
   # Test each command for one framework
   ./frameworks/test-hpc-runtime-framework.sh --help
   ./frameworks/test-hpc-runtime-framework.sh start-cluster
   ./frameworks/test-hpc-runtime-framework.sh list-tests
   ./frameworks/test-hpc-runtime-framework.sh status
   ./frameworks/test-hpc-runtime-framework.sh stop-cluster
   ```

---

### Task 5.2: Update Makefile Targets

**Time**: 30 minutes

**Location**: `tests/Makefile`

**Steps**:

1. **Update test targets** (15 min)

   ```makefile
   # New unified targets
   test-hpc-runtime:
       ./frameworks/test-hpc-runtime-framework.sh e2e
   
   test-hpc-packer-controller:
       ./frameworks/test-hpc-packer-controller-framework.sh e2e
   
   test-hpc-packer-compute:
       ./frameworks/test-hpc-packer-compute-framework.sh e2e
   ```

2. **Update convenience targets** (10 min)
   - Redirect old targets to new frameworks
   - Add deprecation warnings if needed
   - Update `make test-all` target

3. **Test Makefile targets** (5 min)

   ```bash
   make test-hpc-runtime
   make test-hpc-packer-controller
   make test-hpc-packer-compute
   ```

---

### Task 5.3: Update Documentation

**Time**: 30 minutes

**Steps**:

1. **Update tests/README.md** (15 min)
   - Replace old framework list with new list
   - Update execution examples
   - Update test sequence recommendations
   - Add consolidation notes

2. **Update related documentation** (10 min)
   - Update design documents if needed
   - Update task list references
   - Update CI/CD documentation

3. **Verify documentation accuracy** (5 min)
   - Check all links work
   - Verify examples are correct
   - Ensure consistency

---

### Task 5.4: Clean Up Old Files

**Time**: 15 minutes

**Steps**:

1. **Move old frameworks to archive** (5 min)

   ```bash
   mkdir -p backup/old-frameworks-$(date +%Y%m%d)/
   mv tests/test-cgroup-isolation-framework.sh backup/old-frameworks-$(date +%Y%m%d)/
   mv tests/test-gpu-gres-framework.sh backup/old-frameworks-$(date +%Y%m%d)/
   mv tests/test-job-scripts-framework.sh backup/old-frameworks-$(date +%Y%m%d)/
   mv tests/test-dcgm-monitoring-framework.sh backup/old-frameworks-$(date +%Y%m%d)/
   mv tests/test-container-integration-framework.sh backup/old-frameworks-$(date +%Y%m%d)/
   mv tests/test-slurm-compute-framework.sh backup/old-frameworks-$(date +%Y%m%d)/
   mv tests/test-slurm-controller-framework.sh backup/old-frameworks-$(date +%Y%m%d)/
   mv tests/test-slurm-accounting-framework.sh backup/old-frameworks-$(date +%Y%m%d)/
   mv tests/test-monitoring-stack-framework.sh backup/old-frameworks-$(date +%Y%m%d)/
   mv tests/test-grafana-framework.sh backup/old-frameworks-$(date +%Y%m%d)/
   mv tests/test-container-runtime-framework.sh backup/old-frameworks-$(date +%Y%m%d)/
   ```

2. **Archive old config files** (5 min)

   ```bash
   mkdir -p backup/old-configs-$(date +%Y%m%d)/
   mv tests/test-infra/configs/test-cgroup-isolation.yaml backup/old-configs-$(date +%Y%m%d)/
   mv tests/test-infra/configs/test-gpu-gres.yaml backup/old-configs-$(date +%Y%m%d)/
   # ... (move all old configs)
   ```

3. **Verify cleanup complete** (5 min)

   ```bash
   # Check no old frameworks remain
   ls -la tests/test-*-framework.sh
   
   # Should only see 7 frameworks
   ```

---

### Task 5.5: Final Validation

**Time**: 15 minutes

**Steps**:

1. **Run phase-4-validation** (10 min)

   ```bash
   cd tests/phase-4-validation/
   ./run-all-steps.sh
   ```

2. **Verify code metrics** (3 min)

   ```bash
   # Count lines in new frameworks
   wc -l tests/test-*-framework.sh tests/test-infra/utils/*.sh
   
   # Should see significant reduction
   ```

3. **Document final state** (2 min)
   - Update test plan with actual results
   - Note any deviations from plan
   - Record lessons learned

---

### Phase 5 Validation

**Final Checklist**:

- [ ] All 7 frameworks pass end-to-end tests
- [ ] Makefile targets updated and tested
- [ ] Documentation fully updated
- [ ] Old files archived (not deleted)
- [ ] Code reduction achieved (2000-3000 lines)
- [ ] Test coverage preserved (100%)
- [ ] Phase-4-validation passes
- [ ] Team review complete

---

## Rollback Procedures

If issues are encountered during implementation:

### Phase 2 Rollback

```bash
# Delete new utilities
rm tests/test-infra/utils/framework-cli.sh
rm tests/test-infra/utils/framework-orchestration.sh

# Restore original test-framework-utils.sh if modified
git checkout tests/test-infra/utils/test-framework-utils.sh
```

### Phase 3 Rollback

```bash
# Remove new frameworks
rm tests/frameworks/test-hpc-runtime-framework.sh
rm tests/frameworks/test-hpc-packer-controller-framework.sh
rm tests/frameworks/test-hpc-packer-compute-framework.sh

# Remove new configs
rm tests/test-infra/configs/test-hpc-runtime.yaml
rm tests/test-infra/configs/test-hpc-packer-controller.yaml
rm tests/test-infra/configs/test-hpc-packer-compute.yaml
```

### Phase 4 Rollback

```bash
# Restore original standalone frameworks
cp tests/advanced/test-beegfs-framework.sh.backup tests/advanced/test-beegfs-framework.sh
cp tests/advanced/test-virtio-fs-framework.sh.backup tests/advanced/test-virtio-fs-framework.sh
cp tests/frameworks/test-pcie-passthrough-framework.sh.backup tests/frameworks/test-pcie-passthrough-framework.sh
cp tests/advanced/test-container-registry-framework.sh.backup tests/advanced/test-container-registry-framework.sh
```

### Phase 5 Rollback

```bash
# Restore old frameworks from backup
cp backup/old-frameworks-YYYYMMDD/* tests/

# Restore old configs
cp backup/old-configs-YYYYMMDD/* tests/test-infra/configs/

# Restore Makefile
git checkout tests/Makefile

# Restore documentation
git checkout tests/README.md
```

---

## Success Metrics

### Quantitative Metrics

- [ ] Framework count: 15 → 7 (53% reduction achieved)
- [ ] Code lines: ~8000 → ~6000 (25% reduction achieved)
- [ ] Duplicated code: 2000-3000 lines eliminated
- [ ] Test coverage: 100% preserved
- [ ] All frameworks pass end-to-end tests
- [ ] Implementation time: Within 15.5 hour estimate

### Qualitative Metrics

- [ ] Consistent CLI interface across all frameworks
- [ ] Improved error messages and logging
- [ ] Better code organization and maintainability
- [ ] Clear documentation and examples
- [ ] Positive team feedback
- [ ] Easier to add new frameworks

---

## Post-Implementation Tasks

After successful completion:

1. **Update CI/CD Pipeline**
   - Update test job definitions
   - Update framework references
   - Test CI/CD integration

2. **Team Training**
   - Document new framework usage
   - Demonstrate new CLI patterns
   - Share consolidation lessons learned

3. **Monitor and Iterate**
   - Collect feedback from team
   - Address any issues found
   - Plan future improvements

---

## Summary

This phased implementation approach provides a clear path from current state (15 frameworks) to target state
(7 frameworks). Each phase has clear deliverables, validation steps, and time estimates.

The consolidation eliminates 2000-3000 lines of duplicated code while preserving 100% test coverage and improving
developer experience through standardized interfaces and shared utilities.

By following this implementation plan step-by-step, the consolidation can be completed successfully within the
estimated 15.5 hour timeframe.
