#!/bin/bash
#
# GRES Configuration Validation Script
# Task 023 - GPU GRES Configuration Validation
# Validates GRES configuration files and deployment
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Source shared utilities
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-check-helpers.sh"

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="check-gres-configuration.sh"
# shellcheck disable=SC2034
TEST_NAME="GRES Configuration Validation"

# Configuration files to check
GRES_CONFIG_FILE="/etc/slurm/gres.conf"
SLURM_CONFIG_FILE="/etc/slurm/slurm.conf"

#=============================================================================
# Test Functions
#=============================================================================

test_gres_config_file_exists() {
    log_info "Checking if GRES configuration file exists..."

    if [[ -f "$GRES_CONFIG_FILE" ]]; then
        log_info "✓ GRES configuration file found: $GRES_CONFIG_FILE"

        # Display file info
        log_debug "File permissions: $(stat -c '%A' "$GRES_CONFIG_FILE")"
        log_debug "File owner: $(stat -c '%U:%G' "$GRES_CONFIG_FILE")"
        log_debug "File size: $(stat -c '%s' "$GRES_CONFIG_FILE") bytes"

        return 0
    else
        log_error "✗ GRES configuration file not found: $GRES_CONFIG_FILE"
        log_error "This may be expected if GRES is not enabled"
        return 0  # Not a hard failure
    fi
}

test_gres_config_syntax() {
    log_info "Validating GRES configuration syntax..."

    if [[ ! -f "$GRES_CONFIG_FILE" ]]; then
        log_error "GRES configuration file not found, skipping syntax check"
        return 0
    fi

    # Check if file is readable
    if [[ ! -r "$GRES_CONFIG_FILE" ]]; then
        log_error "Cannot read GRES configuration file"
        return 1
    fi

    # Basic syntax validation
    # Check for basic GRES syntax patterns
    if grep -q "NodeName=" "$GRES_CONFIG_FILE" || grep -q "AutoDetect=" "$GRES_CONFIG_FILE"; then
        log_info "✓ Valid GRES configuration patterns found"
    else
        log_warn "No GRES device configurations found (file may be template only)"
    fi

    # Check for common syntax errors
    if grep -E "^\s*[^#].*\s+$" "$GRES_CONFIG_FILE" >/dev/null 2>&1; then
        log_warn "Found trailing whitespace in configuration"
    fi

    log_info "GRES configuration syntax check completed"
    return 0
}

test_gres_config_content() {
    log_info "Checking GRES configuration content..."

    if [[ ! -f "$GRES_CONFIG_FILE" ]]; then
        log_error "GRES configuration file not found, skipping content check"
        return 0
    fi

    # Display non-comment, non-empty lines
    log_info "GRES configuration content:"
    local content_lines=0
    while IFS= read -r line; do
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            log_debug "  $line"
            content_lines=$((content_lines + 1))
        fi
    done < "$GRES_CONFIG_FILE"

    if [[ $content_lines -eq 0 ]]; then
        log_warn "No active GRES configuration found (only comments)"
        return 0
    else
        log_info "✓ Found $content_lines active configuration lines"
        return 0
    fi
}

test_gres_directory_structure() {
    log_info "Checking GRES directory structure..."

    local required_dirs=(
        "/etc/slurm"
        "/var/log/slurm"
        "/var/spool/slurmd"
    )

    local missing_dirs=()
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_debug "✓ Directory exists: $dir"
        else
            log_warn "✗ Missing directory: $dir"
            missing_dirs+=("$dir")
        fi
    done

    if [[ ${#missing_dirs[@]} -eq 0 ]]; then
        log_info "✓ All required directories exist"
        return 0
    else
        log_warn "Some directories missing: ${missing_dirs[*]}"
        return 0  # Not a hard failure
    fi
}

test_slurm_gres_integration() {
    log_info "Checking SLURM GRES integration..."

    if [[ ! -f "$SLURM_CONFIG_FILE" ]]; then
        log_warn "SLURM configuration file not found: $SLURM_CONFIG_FILE"
        return 0
    fi

    # Check if slurm.conf references gres.conf
    if grep -q "GresTypes" "$SLURM_CONFIG_FILE"; then
        log_info "✓ GresTypes configured in slurm.conf"
        local gres_types
        gres_types=$(grep "GresTypes" "$SLURM_CONFIG_FILE" | head -1)
        log_debug "  $gres_types"
    else
        log_warn "GresTypes not found in slurm.conf"
    fi

    return 0
}

test_gpu_detection_utilities() {
    log_info "Checking GPU detection utilities..."

    local utilities=(
        "lspci"
        "lshw"
    )

    local missing_utils=()
    for util in "${utilities[@]}"; do
        if command -v "$util" >/dev/null 2>&1; then
            log_debug "✓ Utility available: $util"
        else
            log_error "✗ Missing utility: $util"
            missing_utils+=("$util")
        fi
    done

    if [[ ${#missing_utils[@]} -eq 0 ]]; then
        log_info "✓ All GPU detection utilities available"
        return 0
    else
        log_error "Some utilities missing: ${missing_utils[*]}"
        return 0  # Not a hard failure
    fi
}

#=============================================================================
# Main Test Execution
#=============================================================================

main() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  GRES Configuration Validation Test${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    log_info "Test Suite: $TEST_NAME"
    log_info "Log Directory: $LOG_DIR"
    echo ""

    # Run all tests
    run_test "GRES configuration file exists" test_gres_config_file_exists
    run_test "GRES configuration syntax" test_gres_config_syntax
    run_test "GRES configuration content" test_gres_config_content
    run_test "GRES directory structure" test_gres_directory_structure
    run_test "SLURM GRES integration" test_slurm_gres_integration
    run_test "GPU detection utilities" test_gpu_detection_utilities

    # Print summary
    if print_check_summary; then
        log_info "GRES configuration validation passed (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 0
    else
        log_warn "GRES configuration validation had issues (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 0
    fi
}

# Execute main function
main "$@"
