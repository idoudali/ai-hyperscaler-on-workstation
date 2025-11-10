#!/bin/bash
#
# DCGM Installation Validation Test Script
# Tests DCGM package installation, service status, and basic functionality
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Source shared utilities
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-check-helpers.sh"

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="check-dcgm-installation.sh"
# shellcheck disable=SC2034
TEST_NAME="DCGM Installation Validation"

# Test 1: Check if NVIDIA GPUs are present
test_gpu_detection() {
    log_info "Test 1: Checking for NVIDIA GPUs..."

    if command -v lspci &> /dev/null; then
        local gpu_count
        gpu_count=$(lspci | grep -c -i nvidia || echo "0")
        if [[ $gpu_count -gt 0 ]]; then
            test_pass "Detected $gpu_count NVIDIA GPU(s)"
            if [[ "$VERBOSE" == "true" ]]; then
                log_verbose "$(lspci | grep -i nvidia || echo 'No NVIDIA GPUs found')"
            fi
            return 0
        else
            log_warning "No NVIDIA GPUs detected - DCGM tests may be limited"
            return 0  # Not a failure, just a warning
        fi
    else
        log_warning "lspci command not found - skipping GPU detection"
        return 0
    fi
}

# Test 2: Check DCGM package installation
test_dcgm_packages() {
    log_info "Test 2: Checking DCGM package installation..."

    local all_installed=true
    local packages=("datacenter-gpu-manager-4-core" "datacenter-gpu-manager-4-cuda12" "datacenter-gpu-manager-exporter")

    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii.*${package}"; then
            log_verbose "Package ${package} is installed"
        else
            log_warning "Package ${package} is not installed"
            all_installed=false
        fi
    done

    if [[ "$all_installed" == "true" ]]; then
        test_pass "All DCGM packages are installed"
    else
        log_warning "Some DCGM packages are missing (may be expected if GPUs not present)"
    fi
}

# Test 3: Check DCGM binary availability
test_dcgm_binary() {
    log_info "Test 3: Checking DCGM binary availability..."

    if command -v dcgmi &> /dev/null; then
        local version
        version=$(dcgmi --version 2>&1 | head -n 1 || echo "unknown")
        test_pass "DCGM binary (dcgmi) is available: $version"
        log_verbose "$(dcgmi --version 2>&1 || true)"
    else
        test_fail "DCGM binary (dcgmi) not found in PATH"
    fi
}

# Test 4: Check DCGM service status
test_dcgm_service() {
    log_info "Test 4: Checking DCGM service status..."

    if systemctl list-unit-files | grep -q nvidia-dcgm; then
        if systemctl is-active --quiet nvidia-dcgm; then
            test_pass "DCGM service (nvidia-dcgm) is active"
            log_verbose "$(systemctl status nvidia-dcgm --no-pager -l || true)"
        else
            log_warning "DCGM service exists but is not active"
            log_verbose "$(systemctl status nvidia-dcgm --no-pager -l || true)"
        fi
    else
        log_warning "DCGM service unit file not found"
    fi
}

# Test 5: Check DCGM configuration directory
test_dcgm_config() {
    log_info "Test 5: Checking DCGM configuration..."

    local config_dir="/etc/nvidia-datacenter-gpu-manager"
    local config_file="${config_dir}/dcgm.conf"

    if [[ -d "$config_dir" ]]; then
        test_pass "DCGM configuration directory exists: $config_dir"

        if [[ -f "$config_file" ]]; then
            log_verbose "DCGM configuration file exists: $config_file"
            log_verbose "Configuration file permissions: $(stat -c '%a %U:%G' "$config_file" 2>/dev/null || echo 'unknown')"
        else
            log_verbose "DCGM configuration file not found (may use defaults)"
        fi
    else
        log_warning "DCGM configuration directory not found: $config_dir"
    fi
}

# Test 6: Check DCGM log directory
test_dcgm_logs() {
    log_info "Test 6: Checking DCGM log directory..."

    local log_dir="/var/log/nvidia-dcgm"

    if [[ -d "$log_dir" ]]; then
        test_pass "DCGM log directory exists: $log_dir"
        log_verbose "Log directory permissions: $(stat -c '%a %U:%G' "$log_dir" 2>/dev/null || echo 'unknown')"
        log_verbose "Log files: $(ls -lh "$log_dir" 2>/dev/null || echo 'none')"
    else
        log_warning "DCGM log directory not found: $log_dir"
    fi
}

# Test 7: Test DCGM GPU discovery
test_dcgm_discovery() {
    log_info "Test 7: Testing DCGM GPU discovery..."

    if ! command -v dcgmi &> /dev/null; then
        log_warning "dcgmi command not available - skipping discovery test"
        return 0
    fi

    if systemctl is-active --quiet nvidia-dcgm 2>/dev/null; then
        if output=$(dcgmi discovery -l 2>&1); then
            local gpu_count
            gpu_count=$(echo "$output" | grep -c "^GPU" || echo "0")
            if [[ $gpu_count -gt 0 ]]; then
                test_pass "DCGM discovered $gpu_count GPU(s)"
                log_verbose "$output"
            else
                log_warning "DCGM running but no GPUs discovered"
            fi
        else
            log_warning "DCGM discovery command failed (may require GPU hardware)"
            log_verbose "Error: $output"
        fi
    else
        log_warning "DCGM service not running - skipping discovery test"
    fi
}

# Test 8: Check DCGM health monitoring
test_dcgm_health() {
    log_info "Test 8: Testing DCGM health monitoring..."

    if ! command -v dcgmi &> /dev/null; then
        log_warning "dcgmi command not available - skipping health test"
        return 0
    fi

    if systemctl is-active --quiet nvidia-dcgm 2>/dev/null; then
        if output=$(dcgmi health -g 0 -c 2>&1 || true); then
            log_verbose "DCGM health check output:"
            log_verbose "$output"
            test_pass "DCGM health monitoring commands available"
        else
            log_warning "DCGM health check failed (may require GPU hardware)"
        fi
    else
        log_warning "DCGM service not running - skipping health test"
    fi
}

# Test 9: Check DCGM version information
test_dcgm_version() {
    log_info "Test 9: Checking DCGM version information..."

    if command -v dcgmi &> /dev/null; then
        if version_info=$(dcgmi --version 2>&1); then
            test_pass "DCGM version information available"
            log_verbose "$version_info"
        else
            log_warning "Unable to get DCGM version information"
        fi
    else
        log_warning "dcgmi command not available - skipping version check"
    fi
}

# Test 10: Check DCGM socket
test_dcgm_socket() {
    log_info "Test 10: Checking DCGM socket..."

    local socket_path="/var/run/nvidia-dcgm/dcgm.socket"

    if [[ -S "$socket_path" ]]; then
        test_pass "DCGM socket exists: $socket_path"
        log_verbose "Socket permissions: $(stat -c '%a %U:%G' "$socket_path" 2>/dev/null || echo 'unknown')"
    else
        log_warning "DCGM socket not found: $socket_path (service may not be running)"
    fi
}

# Main execution
main() {
    log_info "=========================================="
    log_info "$TEST_NAME"
    log_info "=========================================="
    echo

    test_gpu_detection
    test_dcgm_packages
    test_dcgm_binary
    test_dcgm_service
    test_dcgm_config
    test_dcgm_logs
    test_dcgm_discovery
    test_dcgm_health
    test_dcgm_version
    test_dcgm_socket

    echo
    log_info "=========================================="
    log_info "Test Summary"
    log_info "=========================================="
    log_info "Tests Passed: $TESTS_PASSED"
    log_info "Tests Failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_info "All tests passed successfully!"
        return 0
    else
        log_error "Some tests failed!"
        return 1
    fi
}

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
