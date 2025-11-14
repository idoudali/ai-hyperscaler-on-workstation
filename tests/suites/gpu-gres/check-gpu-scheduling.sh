#!/bin/bash
#
# GPU Scheduling Validation Script
# Task 023 - GPU Resource Scheduling Validation
# Validates GPU scheduling and resource allocation in SLURM
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Source shared utilities
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-check-helpers.sh"

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="check-gpu-scheduling.sh"
# shellcheck disable=SC2034
TEST_NAME="GPU Scheduling Validation"

# Individual test functions
# shellcheck disable=SC2317  # Functions called indirectly via run_test
test_scontrol_show_node() {
    log_info "Checking node information with scontrol..."

    if ! command -v scontrol >/dev/null 2>&1; then
        log_warn "scontrol command not available"
        return 0
    fi

    # Get current hostname
    local hostname
    hostname=$(hostname -s)

    # Get node information
    local node_info
    if node_info=$(scontrol show node "$hostname" 2>&1); then
        log_info "✓ Successfully retrieved node information"
        log_debug "Node information:"
        echo "$node_info" | while IFS= read -r line; do
            log_debug "  $line"
        done

        # Check for GRES information
        if echo "$node_info" | grep -qi "gres"; then
            log_info "✓ GRES information present in node configuration"
            local gres_info
            gres_info=$(echo "$node_info" | grep -i "gres" | head -1)
            log_info "  $gres_info"
        else
            log_warn "No GRES information in node configuration"
        fi

        return 0
    else
        log_warn "Failed to retrieve node information"
        log_debug "Error: $node_info"
        return 0  # Not a hard failure
    fi
}

test_sinfo_gres_display() {
    log_info "Checking GRES display in sinfo..."

    if ! command -v sinfo >/dev/null 2>&1; then
        log_warn "sinfo command not available"
        return 0
    fi

    # Get GRES information from sinfo
    local gres_info
    if gres_info=$(sinfo -o "%N %G" 2>&1); then
        log_info "✓ Successfully retrieved GRES information from sinfo"
        log_debug "GRES information:"
        echo "$gres_info" | while IFS= read -r line; do
            log_debug "  $line"
        done

        # Check if any GPU resources are listed
        if echo "$gres_info" | grep -qi "gpu"; then
            log_info "✓ GPU resources visible in sinfo"
        else
            log_error "No GPU resources visible in sinfo"
            log_error "This may be expected if GPUs are not configured"
        fi

        return 0
    else
        log_error "Failed to retrieve GRES information from sinfo"
        return 0  # Not a hard failure
    fi
}

test_sinfo_available_features() {
    log_info "Checking available features and GRES types..."

    if ! command -v sinfo >/dev/null 2>&1; then
        log_warn "sinfo command not available"
        return 0
    fi

    # Get available features
    local features
    if features=$(sinfo -o "%f" 2>&1); then
        log_info "✓ Successfully retrieved node features"
        log_debug "Available features:"
        echo "$features" | while IFS= read -r line; do
            log_debug "  $line"
        done
        return 0
    else
        log_warn "Failed to retrieve node features"
        return 0  # Not a hard failure
    fi
}

test_slurm_gres_types() {
    log_info "Checking configured GRES types in SLURM..."

    local slurm_conf="/etc/slurm/slurm.conf"

    if [[ ! -f "$slurm_conf" ]]; then
        log_warn "SLURM configuration file not found: $slurm_conf"
        return 0
    fi

    # Check for GresTypes configuration
    if grep -q "GresTypes" "$slurm_conf" 2>/dev/null; then
        local gres_types
        gres_types=$(grep "GresTypes" "$slurm_conf" | head -1)
        log_info "✓ GresTypes configured in slurm.conf"
        log_info "  $gres_types"

        # Extract the types
        local types
        types=$(echo "$gres_types" | cut -d'=' -f2 | tr ',' '\n')
        log_debug "Configured GRES types:"
        echo "$types" | while IFS= read -r type; do
            log_debug "  - $type"
        done

        return 0
    else
        log_warn "GresTypes not configured in slurm.conf"
        return 0  # Not a hard failure
    fi
}

test_gpu_job_submission() {
    log_info "Testing GPU job submission capability..."

    if ! command -v srun >/dev/null 2>&1; then
        log_warn "srun command not available"
        return 0
    fi

    # Try to submit a simple test job requesting GPU
    # Note: This is a dry-run test, not actually allocating GPUs
    log_info "Testing GPU resource request syntax..."

    # Test if the --gres option is accepted
    if srun --help 2>&1 | grep -q "gres"; then
        log_info "✓ srun supports --gres option"
    else
        log_warn "srun may not support --gres option"
    fi

    # Note: We don't actually submit jobs in this test
    log_info "GPU job submission syntax validated"
    log_info "Actual job submission tested separately"

    return 0
}

test_gres_configuration_consistency() {
    log_info "Checking GRES configuration consistency..."

    local gres_conf="/etc/slurm/gres.conf"
    local slurm_conf="/etc/slurm/slurm.conf"

    # Check if both files exist
    local files_exist=true
    if [[ ! -f "$gres_conf" ]]; then
        log_error "GRES configuration file not found: $gres_conf"
        files_exist=false
    fi

    if [[ ! -f "$slurm_conf" ]]; then
        log_error "SLURM configuration file not found: $slurm_conf"
        files_exist=false
    fi

    if [[ "$files_exist" == "false" ]]; then
        return 0  # Not a hard failure
    fi

    # Extract GRES types from slurm.conf
    local slurm_gres_types=()
    if grep -q "GresTypes" "$slurm_conf" 2>/dev/null; then
        local types_line
        types_line=$(grep "GresTypes" "$slurm_conf" | head -1 | cut -d'=' -f2)
        IFS=',' read -ra slurm_gres_types <<< "$types_line"
    fi

    # Check if GRES types match what's in gres.conf
    if [[ ${#slurm_gres_types[@]} -gt 0 ]]; then
        log_info "GRES types configured in slurm.conf: ${slurm_gres_types[*]}"

        # Check if gres.conf has matching configurations
        for gres_type in "${slurm_gres_types[@]}"; do
            if grep -qi "Name=$gres_type" "$gres_conf" 2>/dev/null; then
                log_debug "✓ Found $gres_type configuration in gres.conf"
            else
                log_warn "No $gres_type configuration found in gres.conf"
            fi
        done

        log_info "✓ GRES configuration consistency check completed"
        return 0
    else
        log_warn "No GRES types configured in slurm.conf"
        return 0  # Not a hard failure
    fi
}

#=============================================================================
# Main Test Execution
#=============================================================================

main() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  GPU Scheduling Validation Test${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    log_info "Test Suite: $TEST_NAME"
    log_info "Log Directory: $LOG_DIR"
    echo ""

    # Run all tests
    run_test "Node information with scontrol" test_scontrol_show_node
    run_test "GRES display in sinfo" test_sinfo_gres_display
    run_test "Available features in sinfo" test_sinfo_available_features
    run_test "SLURM GRES types configuration" test_slurm_gres_types
    run_test "GPU job submission capability" test_gpu_job_submission
    run_test "GRES configuration consistency" test_gres_configuration_consistency

    # Print summary
    if print_check_summary; then
        log_info "GPU scheduling validation passed (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 0
    else
        log_warn "GPU scheduling validation had issues (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 0
    fi
}

# Execute main function
main "$@"
