# BATS Porting Proposal: Container Runtime Test Suite

**Status:** Proposal  
**Date:** 2025-11-18  
**Author:** AI Agent  
**Target:** Container Runtime Test Suite Migration to BATS

## Executive Summary

This proposal outlines the migration of the Container Runtime test suite from custom bash test
scripts to [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core), a
TAP-compliant testing framework for Bash. The migration will provide standardized test execution,
native JUnit XML report generation, and improved CI/CD integration while maintaining all existing
test coverage.

**Key Benefits:**

- ✅ Native JUnit XML report generation (`--report-formatter junit`)
- ✅ Standardized test framework with active community support
- ✅ Better test isolation and error reporting
- ✅ Improved CI/CD integration
- ✅ Reduced maintenance overhead

**Estimated Effort:** 16-24 hours  
**Timeline:** 2-3 weeks (incremental migration)  
**Risk Level:** Medium

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [BATS Overview](#bats-overview)
3. [Proposed Structure](#proposed-structure)
4. [Migration Examples](#migration-examples)
5. [Implementation Plan](#implementation-plan)
6. [Timeline and Effort](#timeline-and-effort)
7. [Risk Assessment](#risk-assessment)
8. [Success Criteria](#success-criteria)

---

## Current State Analysis

### Current Test Structure

The Container Runtime test suite consists of:

| File | Lines | Tests | Purpose |
|------|-------|-------|---------|
| `check-singularity-install.sh` | 273 | 6 | Apptainer installation validation |
| `check-container-execution.sh` | 295 | 5 | Container execution capabilities |
| `check-comprehensive-security.sh` | 470 | ~10 | Security configuration validation |
| `test-utils.sh` | 432 | - | Shared utility functions |
| `run-container-runtime-tests.sh` | 361 | - | Master test runner |

**Total:** ~1,831 lines of test code

### Current Architecture Patterns

**1. Manual Test Tracking:**

```bash
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_apptainer_binary_available() {
    ((TESTS_RUN++))
    if command -v apptainer >/dev/null 2>&1; then
        log_pass "Apptainer found"
        return 0
    else
        log_fail "Apptainer not found"
        return 1
    fi
}
```

**2. Custom Logging:**

- Uses `suite-logging.sh` for colored output
- Custom `log_pass()`, `log_fail()`, `log_test()` functions
- Per-script log files

**3. Test Execution:**

- Functions called sequentially with `|| true` to continue on failure
- Results parsed from log files
- Custom summary generation

**4. Shared Utilities:**

- `test-utils.sh` provides helper functions
- Functions like `test_container_runtime_available()`, `execute_container_command()`

### Current Limitations

1. **No Standardized Reporting:** Custom summary format, not CI/CD friendly
2. **Manual Test Tracking:** Error-prone counter management
3. **Limited Test Isolation:** Tests can affect each other
4. **Custom Assertions:** Non-standard assertion patterns
5. **No JUnit XML:** Requires custom implementation for CI/CD integration

---

## BATS Overview

### What is BATS?

[BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) is a TAP-compliant
testing framework for Bash 3.2+. It provides:

- **Standardized Test Syntax:** `@test` annotations for test cases
- **Built-in Assertions:** Standard shell test operators `[ ]`, `[[ ]]`
- **Test Isolation:** Each test runs in a subshell
- **JUnit XML Support:** Native `--report-formatter junit` option
- **Active Community:** 5.6k+ stars, actively maintained

### Installation Options

According to [BATS documentation](https://bats-core.readthedocs.io/en/stable/installation.html):

1. **Package Manager:**

   ```bash
   # Ubuntu/Debian
   apt-get install bats
   
   # Fedora
   dnf install bats
   
   # macOS
   brew install bats-core
   ```

2. **npm:**

   ```bash
   npm install -g bats
   ```

3. **From Source:**

   ```bash
   git clone https://github.com/bats-core/bats-core.git
   cd bats-core
   ./install.sh /usr/local
   ```

### BATS Syntax

**Basic Test Structure:**

```bash
#!/usr/bin/env bats

@test "test description" {
    run command_to_test
    [ "$status" -eq 0 ]
    [ "$output" = "expected output" ]
}
```

**Key Features:**

- `@test` annotation marks test functions
- `run` command captures command output and status
- `$status` contains exit code
- `$output` contains stdout/stderr
- Standard shell test operators for assertions

---

## Proposed Structure

### Directory Layout

```text
tests/suites/container-runtime/
├── README.md
├── BATS-PORTING-PROPOSAL.md          # This document
├── bats/                              # BATS test files
│   ├── check-singularity-install.bats
│   ├── check-container-execution.bats
│   └── check-comprehensive-security.bats
├── bats/helpers/                     # BATS helper functions
│   ├── container-runtime-helpers.bash
│   └── security-helpers.bash
├── bats/fixtures/                     # Test fixtures/data
│   └── test-containers/
├── run-container-runtime-tests.sh    # Updated runner (BATS-aware)
└── legacy/                           # Original scripts (for reference)
    ├── check-singularity-install.sh
    ├── check-container-execution.sh
    └── check-comprehensive-security.sh
```

### Test File Structure

**Example: `bats/check-singularity-install.bats`**

```bash
#!/usr/bin/env bats
#
# Container Runtime Installation Verification
# Task 008 - Check Apptainer Installation and Version
# BATS version

# Load helper functions
load helpers/container-runtime-helpers

# Test configuration
CONTAINER_RUNTIME_BINARY="apptainer"
REQUIRED_VERSION="1.4.2"

# Setup: Run before each test
setup() {
    # Initialize test environment
    export TEST_TEMP_DIR=$(mktemp -d)
}

# Teardown: Run after each test
teardown() {
    # Cleanup
    rm -rf "$TEST_TEMP_DIR"
}

@test "Apptainer binary is available in PATH" {
    run command -v "$CONTAINER_RUNTIME_BINARY"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    
    # Verify it's executable
    installed_path="$output"
    [ -x "$installed_path" ]
}

@test "Apptainer version meets requirement (>= $REQUIRED_VERSION)" {
    skip_if_no_apptainer
    
    run "$CONTAINER_RUNTIME_BINARY" --version
    [ "$status" -eq 0 ]
    
    # Extract version number
    version=$(echo "$output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$version" ]
    
    # Version comparison using helper
    assert_version_gte "$version" "$REQUIRED_VERSION"
}

@test "Required dependencies are installed" {
    local required_packages=(
        "fuse"
        "squashfs-tools"
        "uidmap"
        "libfuse2"
        "libseccomp2"
    )
    
    for package in "${required_packages[@]}"; do
        run dpkg -l "$package"
        [ "$status" -eq 0 ]
    done
}

@test "Apptainer help command works" {
    skip_if_no_apptainer
    
    run "$CONTAINER_RUNTIME_BINARY" --help
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    assert_output --partial "Usage:"
}

@test "Apptainer basic functionality test" {
    skip_if_no_apptainer
    
    run "$CONTAINER_RUNTIME_BINARY" version
    [ "$status" -eq 0 ]
    
    # Verify output contains version pattern
    assert_output --regexp '^[0-9]+\.[0-9]+\.[0-9]+$'
}

@test "Singularity compatibility layer available (optional)" {
    # This test is optional - singularity may not be available
    run command -v singularity
    if [ "$status" -eq 0 ]; then
        run singularity --version
        [ "$status" -eq 0 ]
    else
        skip "Singularity compatibility not required (using Apptainer)"
    fi
}
```

### Helper Functions Structure

**Example: `bats/helpers/container-runtime-helpers.bash`**

```bash
#!/usr/bin/env bash
#
# Container Runtime Test Helpers
# Shared utility functions for BATS tests

# Skip test if Apptainer is not available
skip_if_no_apptainer() {
    if ! command -v apptainer >/dev/null 2>&1; then
        skip "Apptainer binary not available"
    fi
}

# Version comparison helper
# Usage: assert_version_gte "1.4.2" "1.4.0"
assert_version_gte() {
    local installed="$1"
    local required="$2"
    
    local installed_major installed_minor installed_patch
    local required_major required_minor required_patch
    
    IFS='.' read -r installed_major installed_minor installed_patch <<< "$installed"
    IFS='.' read -r required_major required_minor required_patch <<< "$required"
    
    if [[ $installed_major -gt $required_major ]] || \
       { [[ $installed_major -eq $required_major ]] && \
         [[ $installed_minor -gt $required_minor ]]; } || \
       { [[ $installed_major -eq $required_major ]] && \
         [[ $installed_minor -eq $required_minor ]] && \
         [[ $installed_patch -ge $required_patch ]]; }; then
        return 0
    else
        echo "Version $installed is less than required $required" >&2
        return 1
    fi
}

# Execute container command with timeout
# Usage: run_container_command "container.sif" "echo test" 30
run_container_command() {
    local container="$1"
    local command="$2"
    local timeout="${3:-60}"
    
    timeout "${timeout}s" apptainer exec "$container" $command
}

# Test container path access
# Usage: test_container_path_access "container.sif" "/path"
test_container_path_access() {
    local container="$1"
    local path="$2"
    
    apptainer exec "$container" test -r "$path"
}
```

### Updated Test Runner

**Example: `run-container-runtime-tests.sh` (BATS-aware)**

```bash
#!/bin/bash
#
# Container Runtime Test Suite Master Runner (BATS)
# Executes BATS test files and generates JUnit XML reports

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS_DIR="$SCRIPT_DIR/bats"
LOG_DIR="${LOG_DIR:-$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# Check if BATS is installed
if ! command -v bats >/dev/null 2>&1; then
    echo "ERROR: BATS is not installed"
    echo "Install with: apt-get install bats (or see https://bats-core.readthedocs.io)"
    exit 1
fi

# Test files to run
BATS_TEST_FILES=(
    "$BATS_DIR/check-singularity-install.bats"
    "$BATS_DIR/check-container-execution.bats"
    "$BATS_DIR/check-comprehensive-security.bats"
)

echo "=========================================="
echo "Container Runtime Test Suite (BATS)"
echo "=========================================="
echo ""

# Run BATS tests with JUnit XML output
bats --report-formatter junit \
     --output "$LOG_DIR/junit.xml" \
     --verbose \
     "${BATS_TEST_FILES[@]}" \
     2>&1 | tee "$LOG_DIR/bats-output.log"

# Exit with BATS exit code
exit $?
```

---

## Migration Examples

### Example 1: Simple Test Function

**Before (Current):**

```bash
test_apptainer_binary_available() {
    ((TESTS_RUN++))
    log_test "Checking for Apptainer binary"

    if command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        local installed_path
        installed_path=$(which "$CONTAINER_RUNTIME_BINARY")
        log_pass "Apptainer found at: $installed_path"
        return 0
    else
        log_fail "Apptainer binary not found in PATH"
        return 1
    fi
}
```

**After (BATS):**

```bash
@test "Apptainer binary is available in PATH" {
    run command -v apptainer
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    
    # Verify executable
    [ -x "$output" ]
}
```

**Changes:**

- ✅ Removed manual counter (`TESTS_RUN++`)
- ✅ Removed custom logging (`log_test`, `log_pass`, `log_fail`)
- ✅ Uses BATS `run` command
- ✅ Uses standard shell assertions `[ ]`
- ✅ Automatic test tracking by BATS

### Example 2: Test with Complex Logic

**Before (Current):**

```bash
test_apptainer_version() {
    ((TESTS_RUN++))
    log_test "Verifying Apptainer version (>= $REQUIRED_VERSION)"

    if ! command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        log_fail "Apptainer binary not available for version check"
        return 1
    fi

    local installed_version
    installed_version=$($CONTAINER_RUNTIME_BINARY --version 2>/dev/null | \
                        grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) || {
        log_fail "Failed to get Apptainer version"
        return 1
    }

    # Version comparison logic...
    if [[ $installed_major -gt $required_major ]] || ...; then
        log_pass "Version requirement met: $installed_version >= $REQUIRED_VERSION"
        return 0
    else
        log_fail "Version requirement not met: $installed_version < $REQUIRED_VERSION"
        return 1
    fi
}
```

**After (BATS):**

```bash
@test "Apptainer version meets requirement (>= $REQUIRED_VERSION)" {
    skip_if_no_apptainer
    
    run apptainer --version
    [ "$status" -eq 0 ]
    
    # Extract version
    version=$(echo "$output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$version" ]
    
    # Use helper function for comparison
    assert_version_gte "$version" "$REQUIRED_VERSION"
}
```

**Changes:**

- ✅ Uses `skip_if_no_apptainer` helper for conditional skipping
- ✅ Version comparison logic moved to helper function
- ✅ Cleaner, more readable test code
- ✅ Better error messages from BATS

### Example 3: Container Execution Test

**Before (Current):**

```bash
test_container_execution() {
    ((TESTS_RUN++))
    log_test "Testing container execution"

    if ! command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        log_fail "Container runtime not available for execution test"
        return 1
    fi

    local test_container
    test_container=$(cat "/tmp/pulled_container_$$.txt")

    if timeout 120s "$CONTAINER_RUNTIME_BINARY" exec "$test_container" \
       echo "Container execution test successful" >/dev/null 2>&1; then
        log_pass "Successfully executed container"
        return 0
    else
        log_fail "Failed to execute container"
        return 1
    fi
}
```

**After (BATS):**

```bash
@test "Container execution works" {
    skip_if_no_apptainer
    
    # Setup: Pull container if not exists
    local container_file="$TEST_TEMP_DIR/test-container.sif"
    if [ ! -f "$container_file" ]; then
        run apptainer pull "$container_file" docker://ubuntu:22.04
        [ "$status" -eq 0 ]
    fi
    
    # Test execution
    run apptainer exec "$container_file" echo "Container execution test successful"
    [ "$status" -eq 0 ]
    assert_output --partial "Container execution test successful"
}
```

**Changes:**

- ✅ Uses `setup()` and `teardown()` for container management
- ✅ Better test isolation with `$TEST_TEMP_DIR`
- ✅ Automatic cleanup in teardown
- ✅ Uses BATS assertions for output verification

---

## Implementation Plan

### Phase 1: Setup and Proof of Concept (4-6 hours)

**Tasks:**

1. Install BATS in development container
   - Add to Dockerfile or install script
   - Verify installation: `bats --version`

2. Create BATS directory structure

   ```bash
   mkdir -p tests/suites/container-runtime/bats/{helpers,fixtures}
   ```

3. Convert one simple test file as proof of concept
   - Start with `check-singularity-install.bats`
   - Convert 2-3 simple tests
   - Validate JUnit XML output

4. Create helper functions file
   - Extract common patterns to `container-runtime-helpers.bash`
   - Implement version comparison, skip conditions

5. Update test runner to support BATS
   - Add BATS execution path
   - Generate JUnit XML reports
   - Validate integration

**Deliverables:**

- ✅ BATS installed and working
- ✅ One test file converted (proof of concept)
- ✅ JUnit XML reports generating correctly
- ✅ CI/CD integration validated

### Phase 2: Full Test File Migration (10-14 hours)

**Tasks:**

1. Complete `check-singularity-install.bats` conversion
   - Convert all 6 tests
   - Add setup/teardown functions
   - Test and validate

2. Convert `check-container-execution.bats`
   - Convert all 5 tests
   - Handle container pull/execution
   - Add timeout handling
   - Test cleanup in teardown

3. Convert `check-comprehensive-security.bats`
   - Convert all security tests (~10 tests)
   - Preserve complex validation logic
   - Add security-specific helpers

4. Migrate shared utilities
   - Convert `test-utils.sh` functions to BATS helpers
   - Update function signatures for BATS compatibility
   - Test helper functions

**Deliverables:**

- ✅ All test files converted to BATS
- ✅ All tests passing
- ✅ Helper functions working

### Phase 3: Integration and Validation (4-6 hours)

**Tasks:**

1. Update test runner
   - Replace custom runner with BATS execution
   - Generate JUnit XML reports
   - Preserve logging capabilities

2. Update CI/CD pipelines
   - Configure to use BATS test runner
   - Collect JUnit XML reports
   - Validate test result visualization

3. Documentation updates
   - Update README with BATS usage
   - Document helper functions
   - Add migration notes

4. Final validation
   - Run full test suite
   - Verify all tests pass
   - Validate JUnit XML output
   - Check CI/CD integration

**Deliverables:**

- ✅ Complete test suite running with BATS
- ✅ CI/CD integration working
- ✅ Documentation updated

### Phase 4: Cleanup and Legacy (2-4 hours)

**Tasks:**

1. Move original scripts to `legacy/` directory
   - Keep for reference during transition
   - Document deprecation

2. Remove unused code
   - Remove custom test tracking
   - Clean up old logging functions (if not used elsewhere)

3. Final testing
   - Run tests in all environments
   - Validate edge cases
   - Performance testing

**Deliverables:**

- ✅ Legacy code archived
- ✅ Codebase cleaned up
- ✅ All environments validated

---

## Timeline and Effort

### Effort Breakdown

| Phase | Tasks | Estimated Hours | Complexity |
|-------|-------|-----------------|------------|
| **Phase 1: Setup & POC** | BATS install, structure, 1 test file | 4-6 hours | Low-Medium |
| **Phase 2: Full Migration** | Convert all test files, helpers | 10-14 hours | High |
| **Phase 3: Integration** | Runner, CI/CD, docs | 4-6 hours | Medium |
| **Phase 4: Cleanup** | Legacy code, final validation | 2-4 hours | Low |
| **Total** | | **20-30 hours** | **Medium-High** |

### Timeline Estimate

**Incremental Approach (Recommended):**

- **Week 1:** Phase 1 (Setup & POC) - 4-6 hours
- **Week 2:** Phase 2 (Full Migration) - 10-14 hours
- **Week 3:** Phase 3 (Integration) + Phase 4 (Cleanup) - 6-10 hours

**Total Timeline:** 2-3 weeks

**Parallel Work Possible:**

- Phase 2 can be split across multiple test files
- Helper function development can happen in parallel
- Documentation can be updated incrementally

---

## Risk Assessment

### Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **BATS compatibility issues** | High | Low | Test in development container first, validate early |
| **Test behavior changes** | Medium | Medium | Careful conversion, side-by-side testing |
| **Helper function complexity** | Medium | Medium | Start simple, refactor incrementally |
| **CI/CD integration issues** | Low | Low | Validate JUnit XML format early |
| **Performance degradation** | Low | Low | BATS overhead is minimal |

### Process Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Learning curve** | Medium | Medium | Provide training, start with simple tests |
| **Timeline overrun** | Medium | Medium | Incremental approach, prioritize critical tests |
| **Breaking existing workflows** | High | Low | Maintain backward compatibility during transition |

### Mitigation Strategies

1. **Incremental Migration:** Convert one file at a time, validate before proceeding
2. **Side-by-Side Testing:** Run both old and new tests during transition
3. **Early Validation:** Test JUnit XML output and CI/CD integration in Phase 1
4. **Documentation:** Maintain clear migration notes and examples
5. **Rollback Plan:** Keep original scripts in `legacy/` for quick rollback if needed

---

## Success Criteria

### Functional Requirements

- ✅ All existing tests converted to BATS format
- ✅ All tests passing with same coverage as before
- ✅ JUnit XML reports generating correctly
- ✅ CI/CD integration working
- ✅ Test execution time acceptable (< 10% increase)

### Quality Requirements

- ✅ Test code is readable and maintainable
- ✅ Helper functions are well-documented
- ✅ Error messages are clear and actionable
- ✅ Test isolation is improved

### Integration Requirements

- ✅ CI/CD pipelines updated and working
- ✅ Test reports visible in CI/CD dashboard
- ✅ Documentation updated
- ✅ Team trained on BATS usage

### Acceptance Criteria

1. **Test Coverage:** 100% of original tests converted
2. **Test Results:** All tests pass in all environments
3. **Report Generation:** JUnit XML reports generated successfully
4. **CI/CD Integration:** Reports visible in CI/CD dashboard
5. **Documentation:** README and helper docs updated
6. **Performance:** Test execution time within acceptable limits

---

## Alternative Approaches

### Option A: Hybrid Approach (Recommended for Quick Wins)

**Keep current structure, add JUnit XML generator:**

- Effort: 2-3 hours
- No test file changes needed
- Preserves existing infrastructure
- Can migrate to BATS later if desired

**Implementation:**

```bash
# Add to suite-test-runner.sh
generate_junit_xml() {
    # Generate XML from TESTS_RUN, TESTS_PASSED, TESTS_FAILED
    # ...
}
```

### Option B: Gradual BATS Adoption

**Migrate one test suite at a time:**

- Start with container-runtime (this proposal)
- Evaluate benefits
- Migrate other suites if successful

### Option C: Full BATS Migration

**Migrate all test suites to BATS:**

- Higher effort (80-120 hours estimated)
- Consistent framework across all tests
- Long-term maintenance benefits

---

## Recommendations

### Immediate Action (Short-term)

1. **Evaluate BATS:** Run proof of concept (Phase 1) to validate approach
2. **Decision Point:** After POC, decide on full migration vs. hybrid approach
3. **If Proceeding:** Follow incremental migration plan (Phases 2-4)

### Long-term Strategy

1. **Standardize:** If BATS works well, consider migrating other test suites
2. **Maintain:** Keep BATS version updated, contribute improvements
3. **Document:** Maintain clear examples and best practices

### Decision Factors

**Choose BATS Migration If:**

- ✅ JUnit XML reports are critical for CI/CD
- ✅ Team wants standardized testing framework
- ✅ Long-term maintenance is a priority
- ✅ 2-3 weeks timeline is acceptable

**Choose Hybrid Approach If:**

- ✅ Need JUnit XML reports quickly (2-3 hours)
- ✅ Want to minimize changes
- ✅ Can evaluate BATS migration later

---

## References

- [BATS Core GitHub Repository](https://github.com/bats-core/bats-core)
- [BATS Documentation](https://bats-core.readthedocs.io/)
- [BATS Installation Guide](https://bats-core.readthedocs.io/en/stable/installation.html)
- [TAP (Test Anything Protocol) Specification](https://testanything.org/)

---

## Appendix

### A. BATS Installation Commands

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install bats

# Fedora
sudo dnf install bats

# macOS
brew install bats-core

# From Source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local

# Verify Installation
bats --version
```

### B. Example BATS Test File Template

```bash
#!/usr/bin/env bats
#
# Test Suite Description
# BATS test file

# Load helper functions
load helpers/helper-functions

# Setup: Run before each test
setup() {
    export TEST_TEMP_DIR=$(mktemp -d)
}

# Teardown: Run after each test
teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "Test description" {
    run command_to_test
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}
```

### C. JUnit XML Report Usage

```bash
# Generate JUnit XML report
bats --report-formatter junit --output junit.xml test-file.bats

# Run with verbose output
bats --verbose test-file.bats

# Run specific test
bats --filter "test name" test-file.bats
```

---

**Document Status:** Proposal - Awaiting Approval  
**Next Steps:** Review proposal, approve Phase 1 (POC), begin implementation
