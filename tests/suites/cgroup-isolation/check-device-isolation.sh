#!/bin/bash
# Check Device Isolation
# Task 024: Set Up Cgroup Resource Isolation
# Test Suite: Device Access Control Validation
#
# This script validates device access control through cgroup devices controller

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

test_devices_controller_available() {
    log_info "Checking if devices cgroup controller is available..."

    local controller_found=false

    # Check cgroup v1
    if [ -f "/proc/cgroups" ]; then
        if grep -q "^devices" /proc/cgroups; then
            log_success "Devices controller available (cgroup v1)"
            controller_found=true
        fi
    fi

    # Check cgroup v2 (devices controller not available in v2, uses eBPF)
    if [ -f "/sys/fs/cgroup/cgroup.controllers" ]; then
        log_info "Cgroup v2 detected (uses eBPF for device control)"
        controller_found=true
    fi

    if $controller_found; then
        return 0
    else
        log_error "Devices controller not available"
        return 1
    fi
}

test_allowed_devices_configured() {
    log_info "Checking allowed devices configuration..."

    local devices_file="/etc/slurm/cgroup_allowed_devices_file.conf"

    if [ ! -f "$devices_file" ]; then
        log_error "Allowed devices file not found: $devices_file"
        return 1
    fi

    log_success "Allowed devices file exists"

    # Check for essential devices
    local essential_devices=(
        "/dev/null"
        "/dev/zero"
        "/dev/urandom"
        "/dev/pts/*"
    )

    for device in "${essential_devices[@]}"; do
        if grep -q "^$device" "$devices_file" 2>/dev/null; then
            log_info "Essential device configured: $device"
        else
            log_warning "Essential device may not be configured: $device"
        fi
    done

    return 0
}

test_gpu_devices_in_allowed_list() {
    log_info "Checking GPU devices in allowed list..."

    local devices_file="/etc/slurm/cgroup_allowed_devices_file.conf"

    if [ ! -f "$devices_file" ]; then
        log_error "Allowed devices file not found"
        return 1
    fi

    # Check for GPU device entries
    if grep -q "/dev/nvidia" "$devices_file"; then
        log_success "NVIDIA GPU devices found in allowed list"
        grep "/dev/nvidia" "$devices_file" | while read -r line; do
            log_info "  $line"
        done
    else
        log_warning "No NVIDIA GPU devices in allowed list (may be intentional)"
    fi

    return 0
}

test_fuse_device_for_containers() {
    log_info "Checking FUSE device for container support..."

    local devices_file="/etc/slurm/cgroup_allowed_devices_file.conf"

    if [ ! -f "$devices_file" ]; then
        log_error "Allowed devices file not found"
        return 1
    fi

    # Check for /dev/fuse (required for Singularity/Apptainer)
    if grep -q "^/dev/fuse" "$devices_file"; then
        log_success "FUSE device configured for container support"
    else
        log_error "FUSE device not configured - containers may not work"
        return 1
    fi

    return 0
}

test_device_access_in_slurm_config() {
    log_info "Checking device access configuration in SLURM..."

    local cgroup_conf="/etc/slurm/cgroup.conf"

    if [ ! -f "$cgroup_conf" ]; then
        log_error "cgroup.conf not found"
        return 1
    fi

    # Check ConstrainDevices setting (can be 'yes' or 'True')
    if grep -qE "^ConstrainDevices=(yes|True|true)" "$cgroup_conf"; then
        log_success "Device constraint enabled in cgroup.conf"
    else
        log_error "Device constraint not enabled - device isolation may not work"
        return 1
    fi

    # Check AllowedDevicesFile setting
    if grep -q "^AllowedDevicesFile=" "$cgroup_conf"; then
        local devices_file
        devices_file=$(grep "^AllowedDevicesFile=" "$cgroup_conf" | cut -d'=' -f2)
        log_success "AllowedDevicesFile configured: $devices_file"

        if [ -f "$devices_file" ]; then
            log_success "Allowed devices file exists and is accessible"
        else
            log_error "Allowed devices file not found: $devices_file"
            return 1
        fi
    else
        log_error "AllowedDevicesFile not configured"
        return 1
    fi

    return 0
}

test_device_cgroup_hierarchy() {
    log_info "Checking device cgroup hierarchy..."

    # Check for SLURM cgroup hierarchy
    local cgroup_paths=(
        "/sys/fs/cgroup/devices/slurm"
        "/sys/fs/cgroup/slurm"
    )

    local hierarchy_found=false
    for path in "${cgroup_paths[@]}"; do
        if [ -d "$path" ]; then
            log_success "SLURM cgroup hierarchy found: $path"
            hierarchy_found=true
            break
        fi
    done

    if ! $hierarchy_found; then
        log_warning "SLURM cgroup hierarchy not found (may be created at runtime)"
    fi

    return 0
}

#=============================================================================
# Main Test Execution
#=============================================================================

main() {
    log_info "======================================================================"
    log_info "Device Isolation Test Suite"
    log_info "======================================================================"

    # Run all tests
    run_test "Devices controller available" test_devices_controller_available || true
    run_test "Allowed devices configured" test_allowed_devices_configured || true
    run_test "GPU devices in allowed list" test_gpu_devices_in_allowed_list || true
    run_test "FUSE device for containers" test_fuse_device_for_containers || true
    run_test "Device access in SLURM config" test_device_access_in_slurm_config || true
    run_test "Device cgroup hierarchy" test_device_cgroup_hierarchy || true

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
    log_info "Device Isolation Testing Notes"
    log_info "======================================================================"
    log_info "To test device isolation with running jobs:"
    log_info "  1. Submit job and check device access: srun ls -la /dev/"
    log_info "  2. Test GPU access with GRES: srun --gres=gpu:1 nvidia-smi"
    log_info "  3. Test container support: srun apptainer exec image.sif ls"
    log_info "  4. Check cgroup device list: cat /sys/fs/cgroup/devices/slurm/*/devices.list"
    log_info "======================================================================"

    # Return exit code based on test results
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All device isolation tests passed!"
        return 0
    else
        log_error "Some device isolation tests failed!"
        return 1
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
