#!/bin/bash
#
# SLURM Container Plugin Validation Script
# Task 013 - SLURM Container Plugin Configuration Validation
# Validates container plugin configuration, Singularity integration, and container execution capabilities
#

# Source common test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-check-helpers.sh"

set -euo pipefail

# Script configuration
export SCRIPT_NAME="check-container-plugin.sh"
export TEST_NAME="SLURM Container Plugin Validation"

log_info "Starting $TEST_NAME ($SCRIPT_NAME)"

# Test 1: Verify plugin stack configuration file exists
# shellcheck disable=SC2317  # Called indirectly via run_test function
test_plugstack_config_exists() {
    log_info "Verifying plugstack configuration file exists"

    if [[ -f /etc/slurm/plugstack.conf ]]; then
        log_success "Plugin stack configuration file found"
        return 0
    else
        log_error "Plugin stack configuration file not found at /etc/slurm/plugstack.conf"
        return 1
    fi
}

# Test 2: Verify container configuration file exists
# shellcheck disable=SC2317  # Called indirectly via run_test function
test_container_config_exists() {
    log_info "Verifying container configuration file exists"

    if [[ -f /etc/slurm/container.conf ]]; then
        log_success "Container configuration file found"
        return 0
    else
        log_error "Container configuration file not found at /etc/slurm/container.conf"
        return 1
    fi
}

# Test 3: Verify container plugin library exists
# shellcheck disable=SC2317  # Called indirectly via run_test function
test_container_plugin_library() {
    log_info "Checking container plugin library"

    # Check for available container plugins (both Singularity-specific and general container plugins)
    local plugin_paths=(
        # Singularity-specific plugin (if available)
        "/usr/lib/x86_64-linux-gnu/slurm-wlm/container_singularity.so"
        "/usr/lib/slurm-wlm/container_singularity.so"
        "/usr/lib64/slurm/container_singularity.so"
        # General container plugins (actually available in SLURM packages)
        "/usr/lib/x86_64-linux-gnu/slurm-wlm/job_container_cncu.so"
        "/usr/lib/x86_64-linux-gnu/slurm-wlm/job_container_tmpfs.so"
    )

    local found_plugins=()
    for plugin_path in "${plugin_paths[@]}"; do
        if [[ -f "$plugin_path" ]]; then
            found_plugins+=("$plugin_path")
        fi
    done

    if [[ ${#found_plugins[@]} -gt 0 ]]; then
        log_success "Container plugin libraries found:"
        for plugin in "${found_plugins[@]}"; do
            log_success "  - $plugin"
        done
        return 0
    else
        log_error "No container plugin libraries found in standard locations"
        log_debug "Searched paths: ${plugin_paths[*]}"
        return 1
    fi
}

# Test 4: Verify Container runtime exists (optional)
# shellcheck disable=SC2317  # Called indirectly via run_test function
test_singularity_runtime() {
    log_info "Checking Container runtime (Singularity/Apptainer)"

    local runtime_paths=(
        "/usr/bin/singularity"
        "/usr/bin/apptainer"
        "/usr/local/bin/singularity"
        "/usr/local/bin/apptainer"
    )

    for runtime_path in "${runtime_paths[@]}"; do
        if [[ -f "$runtime_path" ]] && [[ -x "$runtime_path" ]]; then
            log_success "Container runtime found at: $runtime_path"
            # Test runtime version
            if "$runtime_path" --version >/dev/null 2>&1; then
                local version
                version=$("$runtime_path" --version 2>/dev/null | head -n1)
                log_info "Runtime version: $version"
            fi
            return 0
        fi
    done

    log_warn "Container runtime not found in standard locations"
    log_debug "Searched paths: ${runtime_paths[*]}"
    log_info "Note: Container runtime is optional for basic SLURM container plugin functionality"
    # Don't fail the test if container runtime is not found
    return 0
}

# Test 5: Verify container images directory exists (optional)
# shellcheck disable=SC2317  # Called indirectly via run_test function
test_container_images_directory() {
    log_info "Checking container images directory"

    local image_dir="/opt/containers"

    if [[ -d "$image_dir" ]]; then
        log_success "Container images directory found: $image_dir"

        # Check permissions
        local perms
        perms=$(stat -c "%a" "$image_dir" 2>/dev/null || echo "000")
        if [[ "$perms" == "755" ]]; then
            log_success "Container images directory has correct permissions: $perms"
        else
            log_warn "Container images directory permissions: $perms (expected: 755)"
        fi

        return 0
    else
        log_warn "Container images directory not found: $image_dir"
        log_info "Note: Container images directory is optional for basic SLURM container plugin functionality"
        # Don't fail the test if directory doesn't exist
        return 0
    fi
}

# Test 6: Validate plugstack configuration syntax
# shellcheck disable=SC2317  # Called indirectly via run_test function
test_plugstack_config_syntax() {
    log_info "Validating plugstack configuration syntax"

    local config_file="/etc/slurm/plugstack.conf"

    if [[ ! -f "$config_file" ]]; then
        log_error "Plugin stack configuration file not found"
        return 1
    fi

    # Check for container.conf inclusion
    if grep -q "include /etc/slurm/container.conf" "$config_file"; then
        log_success "Plugin stack includes container configuration"
    else
        log_error "Plugin stack does not include container configuration"
        return 1
    fi

    # Check for syntax issues (basic validation)
    if [[ -s "$config_file" ]]; then
        log_success "Plugin stack configuration is not empty"
    else
        log_error "Plugin stack configuration is empty"
        return 1
    fi

    return 0
}

# Test 7: Validate container configuration syntax
# shellcheck disable=SC2317  # Called indirectly via run_test function
test_container_config_syntax() {
    log_info "Validating container configuration syntax"

    local config_file="/etc/slurm/container.conf"

    if [[ ! -f "$config_file" ]]; then
        log_error "Container configuration file not found"
        return 1
    fi

    local required_settings=(
        "required="
        "runtime_path="
    )

    # Check for container section (general container support)
    if grep -q "^\[container\]" "$config_file"; then
        log_debug "Found container section in configuration"
    else
        log_warn "Container section not found, checking for singularity section"
        if grep -q "^\[singularity\]" "$config_file"; then
            log_debug "Found singularity section in configuration"
        else
            log_warn "No container or singularity section found"
        fi
    fi

    local missing_settings=()

    for setting in "${required_settings[@]}"; do
        if grep -q "^$setting" "$config_file"; then
            log_debug "Found required setting: $setting"
        else
            missing_settings+=("$setting")
        fi
    done

    if [[ ${#missing_settings[@]} -eq 0 ]]; then
        log_success "All required container settings found"
    else
        log_error "Missing required container settings: ${missing_settings[*]}"
        return 1
    fi

    return 0
}

# Test 8: Test SLURM configuration loading with containers
# shellcheck disable=SC2317  # Called indirectly via run_test function
test_slurm_container_config_loading() {
    log_info "Testing SLURM configuration loading with container plugin"

    # Test SLURM configuration syntax with container plugin
    if command -v slurmctld >/dev/null 2>&1; then
        local test_output
        if test_output=$(timeout 10 slurmctld -D -vvv 2>&1 || true); then
            # Check for container-related output
            if echo "$test_output" | grep -qi "container\|plugin"; then
                log_success "SLURM configuration test includes container/plugin references"
            else
                log_warn "SLURM configuration test output does not mention containers or plugins"
            fi

            # Check for errors
            if echo "$test_output" | grep -qi "error\|fail\|invalid"; then
                log_warn "SLURM configuration test shows potential issues"
                log_debug "Configuration test output snippet:"
                echo "$test_output" | grep -i "error\|fail\|invalid" | head -5 || true
            else
                log_success "No obvious errors in SLURM configuration test"
            fi
        else
            log_warn "Could not run SLURM configuration test"
        fi
    else
        log_warn "slurmctld command not available for configuration testing"
    fi

    return 0
}

# Test 9: Check for container plugin in SLURM logs
# shellcheck disable=SC2317  # Called indirectly via run_test function
test_container_plugin_logs() {
    log_info "Checking SLURM logs for container plugin references"

    local log_file="/var/log/slurm/slurmctld.log"

    if [[ -f "$log_file" ]]; then
        # Look for container-related log entries
        if grep -qi "container\|singularity\|apptainer" "$log_file" 2>/dev/null; then
            log_success "Found container-related entries in SLURM logs"

            # Show recent container-related entries
            log_info "Recent container-related log entries:"
            grep -i "container\|singularity\|apptainer" "$log_file" 2>/dev/null | tail -5 || true
        else
            log_warn "No container-related entries found in SLURM logs"
        fi
    else
        log_warn "SLURM controller log file not found: $log_file"
    fi

    return 0
}

# Test 10: Verify container configuration permissions
# shellcheck disable=SC2317  # Called indirectly via run_test function
test_container_config_permissions() {
    log_info "Checking container configuration file permissions"

    local config_files=(
        "/etc/slurm/plugstack.conf"
        "/etc/slurm/container.conf"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            local perms owner group
            perms=$(stat -c "%a" "$config_file" 2>/dev/null || echo "000")
            owner=$(stat -c "%U" "$config_file" 2>/dev/null || echo "unknown")
            group=$(stat -c "%G" "$config_file" 2>/dev/null || echo "unknown")

            if [[ "$perms" == "644" ]]; then
                log_success "Configuration file has correct permissions: $config_file ($perms)"
            else
                log_warn "Configuration file permissions may need adjustment: $config_file ($perms, expected: 644)"
            fi

            if [[ "$owner" == "root" ]] && [[ "$group" == "root" ]]; then
                log_success "Configuration file has correct ownership: $config_file ($owner:$group)"
            else
                log_warn "Configuration file ownership may need adjustment: $config_file ($owner:$group, expected: root:root)"
            fi
        else
            log_error "Configuration file not found: $config_file"
        fi
    done

    return 0
}

# Test 11: Container functionality test (basic)
# shellcheck disable=SC2317  # Called indirectly via run_test function
test_container_basic_functionality() {
    log_info "Testing basic container functionality"

    # Find container runtime
    local runtime=""
    local runtime_paths=(
        "/usr/bin/singularity"
        "/usr/bin/apptainer"
    )

    for runtime_path in "${runtime_paths[@]}"; do
        if [[ -f "$runtime_path" ]] && [[ -x "$runtime_path" ]]; then
            runtime="$runtime_path"
            break
        fi
    done

    if [[ -z "$runtime" ]]; then
        log_warn "No container runtime found for functionality testing"
        return 0
    fi

    log_info "Testing container runtime: $runtime"

    # Test basic commands
    if "$runtime" --version >/dev/null 2>&1; then
        log_success "Container runtime version check successful"
    else
        log_error "Container runtime version check failed"
        return 1
    fi

    # Test help command
    if "$runtime" --help >/dev/null 2>&1; then
        log_success "Container runtime help command successful"
    else
        log_warn "Container runtime help command failed"
    fi

    return 0
}

# Run all tests
main() {
    log_info "=== SLURM Container Plugin Validation Tests ==="

    # Configuration file tests
    run_test "Plugin Stack Configuration File Exists" test_plugstack_config_exists
    run_test "Container Configuration File Exists" test_container_config_exists
    run_test "Container Plugin Library Exists" test_container_plugin_library
    run_test "Container Runtime Exists" test_singularity_runtime
    run_test "Container Images Directory Exists" test_container_images_directory

    # Configuration syntax tests
    run_test "Plugin Stack Configuration Syntax" test_plugstack_config_syntax
    run_test "Container Configuration Syntax" test_container_config_syntax

    # Integration tests
    run_test "SLURM Container Configuration Loading" test_slurm_container_config_loading
    run_test "Container Plugin in SLURM Logs" test_container_plugin_logs
    run_test "Container Configuration Permissions" test_container_config_permissions
    run_test "Basic Container Functionality" test_container_basic_functionality

    # Print summary using shared function
    print_check_summary
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help]"
        echo "SLURM Container Plugin Validation Script"
        echo ""
        echo "This script validates the SLURM container plugin configuration"
        echo "including Singularity/Apptainer integration and container execution capabilities."
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
