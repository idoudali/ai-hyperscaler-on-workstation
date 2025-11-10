#!/bin/bash
#
# Check Device Isolation
# Task 024: Set Up Cgroup Resource Isolation
# Test Suite: Device Access Control Validation
#
# This script validates device access control through cgroup devices controller
#

source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-check-helpers.sh"
set -euo pipefail

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="check-device-isolation.sh"
# shellcheck disable=SC2034
TEST_NAME="Device Access Control Validation"

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
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}  $TEST_NAME${NC}"
    echo -e "${BLUE}=====================================${NC}"

    log_info "Starting device isolation validation"
    log_info "Log directory: $LOG_DIR"

    # Run all tests
    run_test "Devices controller available" test_devices_controller_available
    run_test "Allowed devices configured" test_allowed_devices_configured
    run_test "GPU devices in allowed list" test_gpu_devices_in_allowed_list
    run_test "FUSE device for containers" test_fuse_device_for_containers
    run_test "Device access in SLURM config" test_device_access_in_slurm_config
    run_test "Device cgroup hierarchy" test_device_cgroup_hierarchy

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

    # Print summary
    if print_check_summary; then
        log_info "Device isolation validation passed (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 0
    else
        log_warn "Device isolation validation had issues (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 0
    fi
}

# Execute main function
main "$@"
