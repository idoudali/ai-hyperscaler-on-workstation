# Test Suite Refactoring Plan

## Overview

This document outlines a comprehensive plan to refactor the test scripts in the `tests/suites/` folder to
eliminate code duplication and leverage existing utilities from `tests/test-infra/utils/`. The refactoring
focuses on extracting common patterns while preserving all test functionality.

## Current State Analysis

### Code Duplication Patterns Identified

Based on analysis of 80+ test scripts across 16 test suite directories, the following duplication patterns were identified:

#### 1. **Logging Functions** (137+ occurrences across 53 files)

Almost every script duplicates the same logging functions:

```bash
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}
log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}
```

#### 2. **Color Definitions** (232+ occurrences across 63 files)

Every script redefines the same color variables:

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
```

#### 3. **Test Tracking Variables** (80+ occurrences)

Most scripts duplicate test result tracking:

```bash
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()
```

#### 4. **Test Execution Functions** (60+ occurrences)

Similar test execution patterns:

```bash
run_test() {
    local test_name="$1"
    local test_function="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    # ... test execution logic
}
```

#### 5. **SSH Configuration** (40+ occurrences)

SSH connection patterns repeated across scripts:

```bash
SSH_KEY_PATH="${SSH_KEY_PATH:-$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
SSH_USER="${SSH_USER:-admin}"
SSH_OPTS="${SSH_OPTS:--o ConnectTimeout=10 -o StrictHostKeyChecking=no}"
```

#### 6. **Script Configuration** (80+ occurrences)

Common script setup patterns:

```bash
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-$(pwd)/logs/$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"
```

### Existing Utilities Analysis

The `tests/test-infra/utils/` folder already contains excellent utilities that can be leveraged:

#### Available Utilities

1. **`log-utils.sh`** (~261 lines) - Comprehensive logging with colors, timestamps, and caller info
2. **`cluster-utils.sh`** (~713 lines) - Cluster lifecycle management using ai-how API
3. **`vm-utils.sh`** (~505 lines) - VM discovery, IP resolution, SSH connectivity
4. **`ansible-utils.sh`** (~278 lines) - Ansible deployment and virtual environment management
5. **`test-framework-utils.sh`** (~1,160 lines) - High-level test orchestration and Ansible integration

#### Key Functions Available

- `log()`, `log_success()`, `log_warning()`, `log_error()` - Comprehensive logging
- `init_logging()` - Log directory initialization and management
- `get_vm_ips_for_cluster()` - VM discovery using ai-how API
- `wait_for_vm_ssh()` - SSH connectivity testing with retry logic
- `upload_scripts_to_vm()` - Script upload and remote execution
- `execute_script_on_vm()` - Remote script execution with output capture

## Refactoring Strategy

### Three-Tier Approach

1. **Create Shared Test Utilities** - Extract common patterns into reusable modules
2. **Refactor Individual Scripts** - Update scripts to use shared utilities
3. **Create Suite-Level Utilities** - Add suite-specific common functions

### New Utility Modules to Create

#### 1. `tests/suites/common/suite-utils.sh` (NEW)

**Purpose**: Common utilities for all test suite scripts

**Size**: ~300-400 lines

**Key Functions**:

```bash
# Test execution framework
run_test()                    # Standardized test execution
run_test_suite()              # Execute multiple tests
collect_test_results()        # Aggregate test results
generate_test_report()        # Create test summary

# Test tracking
init_test_tracking()          # Initialize test counters
update_test_results()         # Update pass/fail counts
get_test_summary()            # Get test summary statistics

# Common validations
check_service_running()       # Check systemd service status
check_file_exists()           # Validate file existence
check_command_success()       # Validate command execution
check_port_listening()        # Check if port is listening

# SSH operations
exec_on_node()                # Execute command on remote node
upload_file_to_node()         # Upload file to remote node
download_file_from_node()     # Download file from remote node
```

#### 2. `tests/suites/common/suite-logging.sh` (NEW)

**Purpose**: Standardized logging for test suites

**Size**: ~150-200 lines

**Key Functions**:

```bash
# Enhanced logging with suite context
log_suite_info()              # Suite-level info logging
log_suite_success()           # Suite-level success logging
log_suite_error()             # Suite-level error logging
log_test_start()              # Test start logging
log_test_end()                # Test end logging with results

# Log formatting
format_test_header()          # Format test section headers
format_test_results()         # Format test result summaries
format_suite_summary()        # Format suite completion summary
```

#### 3. `tests/suites/common/suite-config.sh` (NEW)

**Purpose**: Common configuration and environment setup

**Size**: ~200-250 lines

**Key Functions**:

```bash
# Environment setup
setup_suite_environment()    # Initialize suite environment
load_suite_config()           # Load suite-specific configuration
validate_suite_prerequisites() # Check prerequisites

# Common configurations
get_ssh_config()              # Get SSH configuration
get_test_timeouts()           # Get timeout configurations
get_test_directories()        # Get test directory paths
```

### Enhanced Existing Utilities

#### Enhance `tests/test-infra/utils/log-utils.sh`

**Add Suite-Specific Functions**:

```bash
# Suite-aware logging
log_suite()                   # Log with suite context
init_suite_logging()          # Initialize logging for test suite
create_suite_log_summary()    # Create suite log summary
```

## Implementation Plan

### Phase 1: Create Shared Utilities (4 hours)

#### 1.1 Create `suite-utils.sh` (2 hours)

- Extract common test execution patterns
- Implement standardized test tracking
- Add common validation functions
- Create SSH operation wrappers

#### 1.2 Create `suite-logging.sh` (1 hour)

- Extract logging patterns from existing scripts
- Enhance with suite-specific context
- Add formatted output functions

#### 1.3 Create `suite-config.sh` (1 hour)

- Extract configuration patterns
- Add environment setup functions
- Create common configuration loaders

### Phase 2: Refactor Test Suites (8 hours)

#### 2.1 High-Priority Suites (4 hours)

Refactor suites with most duplication first:

1. **`basic-infrastructure/`** (1 hour)
   - 5 scripts, high duplication
   - Simple refactoring, good test case

2. **`container-runtime/`** (1 hour)
   - Already has `test-utils.sh`
   - Migrate to new shared utilities

3. **`slurm-controller/`** (1 hour)
   - 5 scripts, complex patterns
   - Good representative of SLURM testing

4. **`monitoring-stack/`** (1 hour)
   - 5 scripts, service checking patterns
   - Good for service validation utilities

#### 2.2 Medium-Priority Suites (2 hours)

1. **`gpu-gres/`** (30 minutes)
2. **`cgroup-isolation/`** (30 minutes)
3. **`job-scripts/`** (30 minutes)
4. **`dcgm-monitoring/`** (30 minutes)

#### 2.3 Remaining Suites (2 hours)

1. **`slurm-compute/`** (30 minutes)
2. **`container-integration/`** (30 minutes)
3. **`container-registry/`** (30 minutes)
4. **`beegfs/`** (30 minutes)
5. **`virtio-fs/`** (30 minutes)

### Phase 3: Validation and Testing (2 hours)

#### 3.1 Test Refactored Scripts (1 hour)

- Run each refactored suite end-to-end
- Compare results with original scripts
- Fix any regressions

#### 3.2 Documentation and Cleanup (1 hour)

- Update documentation
- Remove old utility files
- Create migration guide

## Detailed Refactoring Specifications

### Common Test Execution Pattern

**Before** (duplicated in 60+ files):

```bash
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "\n${BLUE}Running Test ${TESTS_RUN}: ${test_name}${NC}"
    
    if $test_function; then
        log_info "✓ Test passed: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ Test failed: $test_name"
        FAILED_TESTS+=("$test_name")
        return 1
    fi
}
```

**After** (in `suite-utils.sh`):

```bash
run_test() {
    local test_name="$1"
    local test_function="$2"
    local timeout="${3:-300}"  # Default 5 minute timeout
    
    init_test_tracking
    
    log_test_start "$test_name"
    
    if timeout "$timeout" bash -c "$test_function"; then
        log_test_success "$test_name"
        update_test_results "PASS"
        return 0
    else
        log_test_failure "$test_name"
        update_test_results "FAIL"
        return 1
    fi
}
```

### Common SSH Execution Pattern

**Before** (duplicated in 40+ files):

```bash
exec_on_node() {
    local node_ip="$1"
    local command="$2"
    
    ssh $SSH_OPTS -i "$SSH_KEY_PATH" "$SSH_USER@$node_ip" "$command"
}
```

**After** (in `suite-utils.sh`):

```bash
exec_on_node() {
    local node_ip="$1"
    local command="$2"
    local timeout="${3:-30}"
    local retries="${4:-3}"
    
    local ssh_config
    ssh_config=$(get_ssh_config)
    
    for ((i=1; i<=retries; i++)); do
        if timeout "$timeout" ssh $ssh_config "$SSH_USER@$node_ip" "$command"; then
            return 0
        else
            log_warn "SSH attempt $i failed, retrying..."
            sleep 2
        fi
    done
    
    log_error "SSH execution failed after $retries attempts"
    return 1
}
```

### Common Service Check Pattern

**Before** (duplicated in 30+ files):

```bash
check_service_running() {
    local service_name="$1"
    local node_ip="$2"
    
    if exec_on_node "$node_ip" "systemctl is-active --quiet $service_name"; then
        log_info "✓ Service $service_name is running"
        return 0
    else
        log_error "✗ Service $service_name is not running"
        return 1
    fi
}
```

**After** (in `suite-utils.sh`):

```bash
check_service_running() {
    local service_name="$1"
    local node_ip="${2:-localhost}"
    local expected_status="${3:-active}"
    
    local status
    status=$(exec_on_node "$node_ip" "systemctl is-active $service_name" 2>/dev/null || echo "inactive")
    
    if [[ "$status" == "$expected_status" ]]; then
        log_suite_success "Service $service_name is $expected_status"
        return 0
    else
        log_suite_error "Service $service_name is $status (expected $expected_status)"
        return 1
    fi
}
```

## Migration Strategy

### Step-by-Step Migration Process

#### For Each Test Suite:

1. **Backup Original Scripts**

   ```bash
   cp -r tests/suites/suite-name tests/suites/suite-name.backup
   ```

2. **Source New Utilities**

   ```bash
   # Add to top of each script
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/../common/suite-utils.sh"
   source "$SCRIPT_DIR/../common/suite-logging.sh"
   source "$SCRIPT_DIR/../common/suite-config.sh"
   ```

3. **Replace Duplicated Functions**
   - Remove local logging functions
   - Remove color definitions
   - Remove test tracking variables
   - Replace with utility function calls

4. **Update Test Execution**
   - Replace local `run_test()` with utility version
   - Update test result collection
   - Use standardized logging

5. **Test and Validate**
   - Run refactored script
   - Compare output with original
   - Fix any issues

### Example Migration: `check-basic-networking.sh`

**Before** (300 lines):

```bash
#!/bin/bash
set -euo pipefail

# Script configuration
SCRIPT_NAME="check-basic-networking.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
FAILED_TESTS=()

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}
# ... more logging functions

# Test execution function
run_test() {
    # ... duplicated test execution logic
}

# Individual test functions
test_ping_connectivity() {
    # ... test logic
}

# Main execution
main() {
    # ... main logic
}
```

**After** (150 lines):

```bash
#!/bin/bash
set -euo pipefail

# Script configuration
SCRIPT_NAME="check-basic-networking.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared utilities
source "$SCRIPT_DIR/../common/suite-utils.sh"
source "$SCRIPT_DIR/../common/suite-logging.sh"
source "$SCRIPT_DIR/../common/suite-config.sh"

# Initialize suite
init_suite_logging "$SCRIPT_NAME"
setup_suite_environment

# Individual test functions
test_ping_connectivity() {
    log_test_start "Ping connectivity test"
    
    if check_command_success "ping -c 3 8.8.8.8"; then
        log_test_success "Ping connectivity working"
        return 0
    else
        log_test_failure "Ping connectivity failed"
        return 1
    fi
}

# Main execution
main() {
    log_suite_info "Starting basic networking validation"
    
    run_test "Ping Connectivity" test_ping_connectivity
    run_test "DNS Resolution" test_dns_resolution
    run_test "Port Connectivity" test_port_connectivity
    
    generate_test_report
}

main "$@"
```

## Benefits of Refactoring

### Quantifiable Improvements

1. **Code Reduction**: ~2,000-3,000 lines eliminated (~30-40% reduction)
2. **Maintenance Surface**: 80+ files → 80+ files + 3 utilities
3. **Consistency**: All scripts use identical patterns
4. **Test Coverage**: 100% preserved (no test logic changes)

### Qualitative Improvements

1. **Maintainability**: Bug fixes in one place benefit all scripts
2. **Consistency**: Standardized error handling and logging
3. **Developer Experience**: Consistent interface across all test suites
4. **Debugging**: Standardized error messages and log formats
5. **Testing**: Easier to test common functionality
6. **Documentation**: Single source of truth for patterns

## Risk Mitigation

### Identified Risks

1. **Test Behavior Changes**: Refactored scripts might behave differently
   - **Mitigation**: Extensive comparison testing against original scripts

2. **Hidden Dependencies**: Unknown dependencies on local functions
   - **Mitigation**: Keep backups and test incrementally

3. **Performance Impact**: Additional function calls might slow execution
   - **Mitigation**: Minimal overhead, benefits outweigh costs

4. **Learning Curve**: Developers need to learn new utilities
   - **Mitigation**: Clear documentation and examples

### Rollback Plan

If refactoring causes issues:

1. **Keep Backups**: All original scripts backed up before changes
2. **Incremental Rollback**: Can rollback individual suites if needed
3. **Documentation**: Rollback procedures documented
4. **Testing**: Rollback tested before production deployment

## Success Criteria

### Must-Have Criteria

- [ ] All 80+ test scripts refactored to use shared utilities
- [ ] All test suites execute successfully
- [ ] Code reduction of 2,000-3,000 lines achieved
- [ ] All original functionality preserved
- [ ] Documentation updated completely
- [ ] Original scripts backed up
- [ ] All validation tests pass

### Nice-to-Have Criteria

- [ ] Performance improvement in test execution
- [ ] Better error messages and logging
- [ ] Improved developer documentation
- [ ] CI/CD integration tested
- [ ] Utility functions used successfully

## Timeline Summary

**Total Estimated Time**: 14 hours

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| 1: Create Utilities | 4 hours | 3 new utility modules |
| 2: Refactor Suites | 8 hours | 80+ refactored scripts |
| 3: Validation | 2 hours | Complete validation + cleanup |

## Conclusion

This refactoring plan provides a clear, phased approach to eliminating code duplication in test suite
scripts while preserving 100% test functionality. By leveraging existing utilities and creating new shared
modules, we can significantly improve maintainability while providing a better developer experience through
consistent patterns.

The phased implementation approach allows stopping at any stable point, and comprehensive validation ensures
we don't introduce regressions during refactoring. The estimated 2,000-3,000 line reduction represents a
significant improvement in code maintainability while preserving all existing test coverage.

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-27  
**Status**: Ready for Implementation
