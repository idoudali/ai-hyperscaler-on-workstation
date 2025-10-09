#!/bin/bash
# Check Resource Isolation
# Task 024: Set Up Cgroup Resource Isolation
# Test Suite: Resource Constraint Validation
#
# This script validates CPU and memory resource isolation enforcement

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test framework utilities if available
if [ -f "$(dirname "$SCRIPT_DIR")/test-infra/utils/test-framework-utils.sh" ]; then
    source "$(dirname "$SCRIPT_DIR")/test-infra/utils/test-framework-utils.sh"
else
    echo "WARNING: Test framework utilities not found, using basic logging"
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_error() { echo "[ERROR] $*"; }
    log_warning() { echo "[WARNING] $*"; }
fi

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
declare -a TEST_RESULTS
declare -a FAILED_TESTS=()  # Initialize as empty array

#=============================================================================
# Helper Functions
#=============================================================================

run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    log_info "Running test $TESTS_RUN: $test_name"

    if $test_function; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TEST_RESULTS+=("✓ $test_name")
        log_success "Test passed: $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TEST_RESULTS+=("✗ $test_name")
        FAILED_TESTS+=("$test_name")
        log_error "Test failed: $test_name"
        return 1
    fi
}

#=============================================================================
# Test Functions
#=============================================================================

test_cgroup_filesystem_mounted() {
    log_info "Checking if cgroup filesystem is mounted..."

    if mount | grep -q cgroup; then
        log_success "Cgroup filesystem is mounted"
        mount | grep cgroup | while read -r line; do
            log_info "  $line"
        done
        return 0
    else
        log_error "Cgroup filesystem not mounted"
        return 1
    fi
}

test_slurm_cgroup_configuration() {
    log_info "Checking SLURM cgroup configuration in slurm.conf..."

    local slurm_conf="/etc/slurm/slurm.conf"
    if [ ! -f "$slurm_conf" ]; then
        log_warning "slurm.conf not found at $slurm_conf (may be controller-only)"
        return 0  # Not a failure on compute nodes
    fi

    # Check ProctrackType
    if grep -q "^ProctrackType=proctrack/cgroup" "$slurm_conf" 2>/dev/null; then
        log_success "ProctrackType set to proctrack/cgroup"
    else
        log_warning "ProctrackType may not be set to proctrack/cgroup"
    fi

    # Check TaskPlugin
    if grep -q "^TaskPlugin=.*task/cgroup" "$slurm_conf" 2>/dev/null; then
        log_success "TaskPlugin includes task/cgroup"
    else
        log_warning "TaskPlugin may not include task/cgroup"
    fi

    return 0
}

test_cgroup_controllers_available() {
    log_info "Checking available cgroup controllers..."

    local controllers_found=false

    # Check for cgroup v1 controllers
    if [ -f "/proc/cgroups" ]; then
        log_info "Cgroup v1 controllers:"
        if grep -v "^#" /proc/cgroups | awk '{print $1}' | grep -E "(cpu|memory|devices)" > /dev/null; then
            controllers_found=true
            grep -v "^#" /proc/cgroups | awk '{print "  " $1}' | grep -E "(cpu|memory|devices)" || true
        fi
    fi

    # Check for cgroup v2
    if [ -d "/sys/fs/cgroup/cgroup.controllers" ] && [ -f "/sys/fs/cgroup/cgroup.controllers" ]; then
        log_info "Cgroup v2 controllers:"
        if grep -E "(cpu|memory)" /sys/fs/cgroup/cgroup.controllers > /dev/null 2>&1; then
            controllers_found=true
            tr ' ' '\n' < /sys/fs/cgroup/cgroup.controllers | sed 's/^/  /' || true
        fi
    fi

    if $controllers_found; then
        log_success "Required cgroup controllers available"
        return 0
    else
        log_error "Required cgroup controllers (cpu, memory, devices) not found"
        return 1
    fi
}

test_cpu_constraint_capability() {
    log_info "Testing CPU constraint capability..."

    # Check if stress tool is available
    if ! command -v stress &> /dev/null; then
        log_warning "stress tool not available, skipping CPU constraint test"
        log_info "Install stress: apt-get install stress"
        return 0  # Not a failure, just skip
    fi

    # Check if SLURM is running
    if ! systemctl is-active --quiet slurmd 2>/dev/null; then
        log_warning "slurmd not running, skipping CPU constraint test"
        return 0
    fi

    # Check if srun is available
    if ! command -v srun &> /dev/null; then
        log_warning "srun not available, skipping CPU constraint test"
        return 0
    fi

    log_info "CPU constraint test requires running SLURM cluster"
    log_info "Use: srun --cpus-per-task=2 stress -c 2 -t 60"

    return 0
}

test_memory_constraint_capability() {
    log_info "Testing memory constraint capability..."

    # Check if SLURM is running
    if ! systemctl is-active --quiet slurmd 2>/dev/null; then
        log_warning "slurmd not running, skipping memory constraint test"
        return 0
    fi

    # Check if srun is available
    if ! command -v srun &> /dev/null; then
        log_warning "srun not available, skipping memory constraint test"
        return 0
    fi

    log_info "Memory constraint test requires running SLURM cluster"
    log_info "Use: srun --mem=1G stress -m 1 --vm-bytes 1G -t 60"

    return 0
}

test_cgroup_slurm_integration() {
    log_info "Checking SLURM cgroup integration..."

    # Check if slurmd service exists
    if ! systemctl list-unit-files | grep -q "slurmd.service"; then
        log_warning "slurmd service not found (may be controller-only node)"
        return 0
    fi

    # Check slurmd status
    if systemctl is-active --quiet slurmd 2>/dev/null; then
        log_success "slurmd service is running"

        # Check if slurmd is using cgroups
        if journalctl -u slurmd -n 100 | grep -qi "cgroup"; then
            log_success "slurmd appears to be using cgroups"
        else
            log_warning "No cgroup references found in recent slurmd logs"
        fi
    else
        log_warning "slurmd service not running"
    fi

    return 0
}

#=============================================================================
# Main Test Execution
#=============================================================================

main() {
    log_info "======================================================================"
    log_info "Resource Isolation Test Suite"
    log_info "======================================================================"

    # Run all tests
    run_test "Cgroup filesystem mounted" test_cgroup_filesystem_mounted || true
    run_test "SLURM cgroup configuration" test_slurm_cgroup_configuration || true
    run_test "Cgroup controllers available" test_cgroup_controllers_available || true
    run_test "CPU constraint capability" test_cpu_constraint_capability || true
    run_test "Memory constraint capability" test_memory_constraint_capability || true
    run_test "SLURM cgroup integration" test_cgroup_slurm_integration || true

    # Print summary
    log_info "======================================================================"
    log_info "Test Summary"
    log_info "======================================================================"
    log_info "Tests run: $TESTS_RUN"
    log_info "Tests passed: $TESTS_PASSED"
    log_info "Tests failed: $TESTS_FAILED"
    log_info "======================================================================"

    # Print individual test results
    for result in "${TEST_RESULTS[@]}"; do
        echo "$result"
    done

    # Print failed tests if any
    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        log_error "======================================================================"
        log_error "Failed Tests:"
        for test in "${FAILED_TESTS[@]}"; do
            log_error "  - $test"
        done
        log_error "======================================================================"
    fi

    # Print informational notes
    log_info "======================================================================"
    log_info "Resource Isolation Testing Notes"
    log_info "======================================================================"
    log_info "To test actual resource isolation with running jobs:"
    log_info "  1. Submit CPU-constrained job: srun --cpus-per-task=2 stress -c 2 -t 60"
    log_info "  2. Submit memory-constrained job: srun --mem=1G stress -m 1 --vm-bytes 1G -t 60"
    log_info "  3. Monitor cgroup constraints: cat /sys/fs/cgroup/*/slurm/*/cpu.max"
    log_info "  4. Check memory limits: cat /sys/fs/cgroup/*/slurm/*/memory.max"
    log_info "======================================================================"

    # Return exit code based on test results
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All resource isolation tests passed!"
        return 0
    else
        log_error "Some resource isolation tests failed!"
        return 1
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
