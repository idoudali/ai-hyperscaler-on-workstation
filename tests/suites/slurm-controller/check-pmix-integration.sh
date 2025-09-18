#!/bin/bash
#
# SLURM PMIx Integration Validation Script
# Task 011 - SLURM PMIx Integration Configuration Validation
# Validates PMIx configuration, MPI integration, and SLURM PMIx settings
#

set -euo pipefail

# Source common test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../test-infra/utils/test-framework-utils.sh" 2>/dev/null || {
    echo "Warning: test-framework-utils.sh not found, using basic logging"
    log_info() { echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_warn() { echo "[WARN] $*"; }
    log_debug() { echo "[DEBUG] $*"; }
}

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
FAILED_TESTS=()

# Test execution function
run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    echo -e "\n[TEST ${TESTS_RUN}] Running: ${test_name}"

    if $test_function; then
        log_success "✓ Test passed: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ Test failed: $test_name"
        FAILED_TESTS+=("$test_name")
        return 1
    fi
}

# Test configuration
TEST_NAME="SLURM PMIx Integration Validation"

log_info "Starting $TEST_NAME"

# Expected PMIx configuration values
EXPECTED_MPI_DEFAULT="pmix"
EXPECTED_MPI_PORTS="12000-12999"
EXPECTED_GRES_TYPES="gpu"
EXPECTED_SELECT_TYPE="select/cons_tres"
EXPECTED_PROCTRACK_TYPE="proctrack/cgroup"

# PMIx configuration file paths
SLURM_CONF="/etc/slurm/slurm.conf"
PMIX_CONF="/etc/slurm/pmix.conf"

# PMIx library paths to check
PMIX_LIBRARY_PATHS=(
    "/usr/lib/x86_64-linux-gnu/libpmix.so.2"
    "/usr/lib/x86_64-linux-gnu/libpmix.so"
    "/usr/lib/libpmix.so.2"
    "/usr/lib/libpmix.so"
)

test_slurm_configuration_exists() {
    log_info "Checking SLURM configuration file..."

    if [ ! -f "$SLURM_CONF" ]; then
        log_error "SLURM configuration file not found: $SLURM_CONF"
        return 1
    fi

    log_success "SLURM configuration file found: $SLURM_CONF"
    return 0
}

test_pmix_configuration_exists() {
    log_info "Checking PMIx configuration file..."

    if [ ! -f "$PMIX_CONF" ]; then
        log_warn "PMIx configuration file not found: $PMIX_CONF"
        log_info "This may be expected if PMIx configuration is integrated into slurm.conf"
        return 0  # Don't fail - PMIx config may be in slurm.conf
    fi

    log_success "PMIx configuration file found: $PMIX_CONF"
    return 0
}

test_mpi_default_configuration() {
    log_info "Checking MPI default configuration..."

    if ! grep -q "^MpiDefault=${EXPECTED_MPI_DEFAULT}" "$SLURM_CONF"; then
        log_error "MPI default not set to '$EXPECTED_MPI_DEFAULT' in $SLURM_CONF"
        log_debug "Current MPI default: $(grep '^MpiDefault=' "$SLURM_CONF" || echo 'Not found')"
        return 1
    fi

    log_success "MPI default correctly set to '$EXPECTED_MPI_DEFAULT'"
    return 0
}

test_mpi_ports_configuration() {
    log_info "Checking MPI ports configuration..."

    if ! grep -q "MpiParams.*ports=${EXPECTED_MPI_PORTS}" "$SLURM_CONF"; then
        log_error "MPI ports not configured as '$EXPECTED_MPI_PORTS' in $SLURM_CONF"
        log_debug "Current MPI params: $(grep '^MpiParams=' "$SLURM_CONF" || echo 'Not found')"
        return 1
    fi

    log_success "MPI ports correctly configured as '$EXPECTED_MPI_PORTS'"
    return 0
}

test_gres_types_configuration() {
    log_info "Checking GRES types configuration..."

    if ! grep -q "^GresTypes=${EXPECTED_GRES_TYPES}" "$SLURM_CONF"; then
        log_error "GRES types not set to '$EXPECTED_GRES_TYPES' in $SLURM_CONF"
        log_debug "Current GRES types: $(grep '^GresTypes=' "$SLURM_CONF" || echo 'Not found')"
        return 1
    fi

    log_success "GRES types correctly set to '$EXPECTED_GRES_TYPES'"
    return 0
}

test_select_type_configuration() {
    log_info "Checking SelectType configuration..."

    if ! grep -q "^SelectType=${EXPECTED_SELECT_TYPE}" "$SLURM_CONF"; then
        log_error "SelectType not set to '$EXPECTED_SELECT_TYPE' in $SLURM_CONF"
        log_debug "Current SelectType: $(grep '^SelectType=' "$SLURM_CONF" || echo 'Not found')"
        return 1
    fi

    log_success "SelectType correctly set to '$EXPECTED_SELECT_TYPE'"
    return 0
}

test_proctrack_type_configuration() {
    log_info "Checking ProctrackType configuration..."

    if ! grep -q "^ProctrackType=${EXPECTED_PROCTRACK_TYPE}" "$SLURM_CONF"; then
        log_error "ProctrackType not set to '$EXPECTED_PROCTRACK_TYPE' in $SLURM_CONF"
        log_debug "Current ProctrackType: $(grep '^ProctrackType=' "$SLURM_CONF" || echo 'Not found')"
        return 1
    fi

    log_success "ProctrackType correctly set to '$EXPECTED_PROCTRACK_TYPE'"
    return 0
}

test_pmix_libraries_availability() {
    log_info "Checking PMIx libraries availability..."

    local found_libraries=0

    for lib_path in "${PMIX_LIBRARY_PATHS[@]}"; do
        if [ -f "$lib_path" ]; then
            log_info "✓ PMIx library found: $lib_path"
            found_libraries=$((found_libraries + 1))
        fi
    done

    # Also check with find for any libpmix files
    local system_pmix_libs
    system_pmix_libs=$(find /usr/lib /usr/lib64 /usr/lib/x86_64-linux-gnu -name "libpmix*" 2>/dev/null | wc -l)

    if [ "$system_pmix_libs" -gt 0 ]; then
        log_info "✓ Found $system_pmix_libs PMIx library files in system"
        found_libraries=$((found_libraries + system_pmix_libs))
    fi

    if [ "$found_libraries" -eq 0 ]; then
        log_error "No PMIx libraries found in expected locations"
        return 1
    fi

    log_success "PMIx libraries available ($found_libraries found)"
    return 0
}

test_slurm_mpi_list() {
    log_info "Testing SLURM MPI list functionality..."

    # Check if srun command is available
    if ! command -v srun >/dev/null 2>&1; then
        log_warn "srun command not available, skipping MPI list test"
        return 0
    fi

    # Test srun --mpi=list (this should work even without a running cluster)
    if srun --mpi=list >/dev/null 2>&1; then
        local mpi_list_output
        mpi_list_output=$(srun --mpi=list 2>/dev/null || echo "")

        if echo "$mpi_list_output" | grep -q -i "pmix"; then
            log_success "PMIx listed as available MPI implementation"
            log_debug "Available MPI types: $mpi_list_output"
        else
            log_warn "PMIx not listed in available MPI implementations"
            log_debug "Available MPI types: $mpi_list_output"
        fi
    else
        log_warn "srun --mpi=list command failed (SLURM may not be running)"
    fi

    return 0
}

test_pmix_configuration_content() {
    log_info "Checking PMIx configuration content..."

    # Only test if PMIx config file exists
    if [ ! -f "$PMIX_CONF" ]; then
        log_info "PMIx configuration file not present, skipping content validation"
        return 0
    fi

    local required_pmix_settings=(
        "pmix_server_addr"
        "pmix_server_port"
        "pmix_client_addr"
        "pmix_client_port"
    )

    local missing_settings=()

    for setting in "${required_pmix_settings[@]}"; do
        if ! grep -q "^${setting}=" "$PMIX_CONF"; then
            missing_settings+=("$setting")
        fi
    done

    if [ ${#missing_settings[@]} -gt 0 ]; then
        log_error "Missing PMIx configuration settings: ${missing_settings[*]}"
        return 1
    fi

    log_success "All required PMIx configuration settings present"
    return 0
}

test_slurm_configuration_syntax() {
    log_info "Validating SLURM configuration syntax..."

    # Check if slurmctld is available
    if ! command -v slurmctld >/dev/null 2>&1; then
        log_warn "slurmctld command not available, skipping syntax validation"
        return 0
    fi

    # Test configuration syntax with dry run
    if slurmctld -t >/dev/null 2>&1; then
        log_success "SLURM configuration syntax validation passed"
    else
        local syntax_output
        syntax_output=$(slurmctld -t 2>&1 || true)
        log_error "SLURM configuration syntax validation failed"
        log_debug "Syntax validation output: $syntax_output"
        return 1
    fi

    return 0
}

test_pmix_version_info() {
    log_info "Checking PMIx version information..."

    # Try different PMIx utilities
    local pmix_commands=("pmix_info" "prte" "prun")
    local version_found=false

    for cmd in "${pmix_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            if "$cmd" --version >/dev/null 2>&1; then
                local version_output
                version_output=$("$cmd" --version 2>/dev/null || echo "")
                log_success "PMIx version info available via $cmd"
                log_debug "Version: $version_output"
                version_found=true
                break
            fi
        fi
    done

    if [ "$version_found" = false ]; then
        log_info "PMIx utilities not found or not responding (may be integrated with SLURM)"
    fi

    return 0
}

# Main test execution
main() {
    log_info "=== $TEST_NAME ==="

    # Run all tests
    run_test "SLURM Configuration File" test_slurm_configuration_exists
    run_test "PMIx Configuration File" test_pmix_configuration_exists
    run_test "MPI Default Configuration" test_mpi_default_configuration
    run_test "MPI Ports Configuration" test_mpi_ports_configuration
    run_test "GRES Types Configuration" test_gres_types_configuration
    run_test "SelectType Configuration" test_select_type_configuration
    run_test "ProctrackType Configuration" test_proctrack_type_configuration
    run_test "PMIx Libraries Availability" test_pmix_libraries_availability
    run_test "SLURM MPI List" test_slurm_mpi_list
    run_test "PMIx Configuration Content" test_pmix_configuration_content
    run_test "SLURM Configuration Syntax" test_slurm_configuration_syntax
    run_test "PMIx Version Information" test_pmix_version_info

    # Final results
    echo -e "\n====================================="
    echo -e "  Test Results Summary"
    echo -e "====================================="
    echo -e "Total tests run: ${TESTS_RUN}"
    echo -e "Tests passed: ${TESTS_PASSED}"
    echo -e "Tests failed: $((TESTS_RUN - TESTS_PASSED))"

    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        echo -e "\nFailed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  - $test"
        done
    fi

    # Success criteria: All tests should pass
    if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
        log_success "$TEST_NAME completed successfully (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 0
    else
        log_error "$TEST_NAME had issues (${TESTS_PASSED}/${TESTS_RUN} tests passed) - check configuration"
        return 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
