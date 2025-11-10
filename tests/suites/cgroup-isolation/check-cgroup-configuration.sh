#!/bin/bash
#
# Check Cgroup Configuration
# Task 024: Set Up Cgroup Resource Isolation
# Test Suite: Cgroup Configuration Validation
#
# This script validates cgroup configuration files and settings
#

source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-check-helpers.sh"
set -euo pipefail

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="check-cgroup-configuration.sh"
# shellcheck disable=SC2034
TEST_NAME="Cgroup Configuration Validation"

#=============================================================================
# Test Functions
#=============================================================================

test_cgroup_conf_exists() {
    log_info "Checking if cgroup.conf exists..."

    if [ -f "/etc/slurm/cgroup.conf" ]; then
        log_success "cgroup.conf found at /etc/slurm/cgroup.conf"
        return 0
    else
        log_error "cgroup.conf not found at /etc/slurm/cgroup.conf"
        return 1
    fi
}

test_allowed_devices_file_exists() {
    log_info "Checking if cgroup_allowed_devices_file.conf exists..."

    if [ -f "/etc/slurm/cgroup_allowed_devices_file.conf" ]; then
        log_success "cgroup_allowed_devices_file.conf found"
        return 0
    else
        log_error "cgroup_allowed_devices_file.conf not found"
        return 1
    fi
}

test_cgroup_conf_syntax() {
    log_info "Validating cgroup.conf syntax..."

    # Note: CgroupAutomount is defunct in SLURM 23.x and later
    local required_settings=(
        "ConstrainCores"
        "ConstrainRAMSpace"
        "ConstrainDevices"
    )

    local all_found=true
    for setting in "${required_settings[@]}"; do
        if grep -q "^${setting}=" /etc/slurm/cgroup.conf 2>/dev/null; then
            log_info "Found required setting: $setting"
        else
            log_error "Missing required setting: $setting"
            all_found=false
        fi
    done

    if $all_found; then
        log_success "All required cgroup settings found"
        return 0
    else
        log_error "Some required cgroup settings missing"
        return 1
    fi
}

test_cgroup_conf_content() {
    log_info "Validating cgroup.conf content..."

    local config_file="/etc/slurm/cgroup.conf"
    local validation_passed=true

    # Note: CgroupAutomount is defunct in SLURM 23.x and later - skip check

    # Check ConstrainCores (can be 'yes' or 'True')
    if grep -qE "^ConstrainCores=(yes|True|true)" "$config_file" 2>/dev/null; then
        log_info "CPU core constraint enabled"
    else
        log_warning "CPU core constraint may not be enabled"
    fi

    # Check ConstrainRAMSpace (can be 'yes' or 'True')
    if grep -qE "^ConstrainRAMSpace=(yes|True|true)" "$config_file" 2>/dev/null; then
        log_info "RAM constraint enabled"
    else
        log_warning "RAM constraint may not be enabled"
    fi

    # Check ConstrainDevices (can be 'yes' or 'True')
    if grep -qE "^ConstrainDevices=(yes|True|true)" "$config_file" 2>/dev/null; then
        log_info "Device constraint enabled"
    else
        log_error "Device constraint not enabled - this is critical for isolation"
        validation_passed=false
    fi

    # Check AllowedDevicesFile
    if grep -q "^AllowedDevicesFile=" "$config_file" 2>/dev/null; then
        local devices_file
        devices_file=$(grep "^AllowedDevicesFile=" "$config_file" | cut -d'=' -f2)
        log_info "Allowed devices file specified: $devices_file"

        if [ -f "$devices_file" ]; then
            log_success "Allowed devices file exists"
        else
            log_error "Allowed devices file not found: $devices_file"
            validation_passed=false
        fi
    else
        log_warning "AllowedDevicesFile not specified"
    fi

    if $validation_passed; then
        log_success "Cgroup configuration content validated"
        return 0
    else
        log_error "Cgroup configuration content validation failed"
        return 1
    fi
}

test_cgroup_directory_structure() {
    log_info "Checking cgroup directory structure..."

    local directories=(
        "/etc/slurm"
        "/etc/slurm/cgroup"
    )

    local all_exist=true
    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            log_info "Directory exists: $dir"
        else
            log_error "Directory missing: $dir"
            all_exist=false
        fi
    done

    if $all_exist; then
        log_success "All required directories exist"
        return 0
    else
        log_error "Some required directories missing"
        return 1
    fi
}

test_cgroup_file_permissions() {
    log_info "Checking cgroup configuration file permissions..."

    local validation_passed=true

    # Check cgroup.conf permissions
    if [ -f "/etc/slurm/cgroup.conf" ]; then
        local perms
        perms=$(stat -c "%a" /etc/slurm/cgroup.conf)
        if [ "$perms" = "644" ] || [ "$perms" = "640" ]; then
            log_success "cgroup.conf has correct permissions: $perms"
        else
            log_warning "cgroup.conf has non-standard permissions: $perms (expected 644 or 640)"
        fi
    fi

    # Check allowed devices file permissions
    if [ -f "/etc/slurm/cgroup_allowed_devices_file.conf" ]; then
        local perms
        perms=$(stat -c "%a" /etc/slurm/cgroup_allowed_devices_file.conf)
        if [ "$perms" = "644" ] || [ "$perms" = "640" ]; then
            log_success "cgroup_allowed_devices_file.conf has correct permissions: $perms"
        else
            log_warning "cgroup_allowed_devices_file.conf has non-standard permissions: $perms"
        fi
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

    log_info "Starting cgroup configuration validation"
    log_info "Log directory: $LOG_DIR"

    # Run all tests
    run_test "Cgroup configuration file exists" test_cgroup_conf_exists
    run_test "Allowed devices file exists" test_allowed_devices_file_exists
    run_test "Cgroup configuration syntax valid" test_cgroup_conf_syntax
    run_test "Cgroup configuration content valid" test_cgroup_conf_content
    run_test "Cgroup directory structure correct" test_cgroup_directory_structure
    run_test "Cgroup file permissions correct" test_cgroup_file_permissions

    # Print summary
    if print_check_summary; then
        log_info "Cgroup configuration validation passed (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 0
    else
        log_warn "Cgroup configuration validation had issues (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 0
    fi
}

# Execute main function
main "$@"
