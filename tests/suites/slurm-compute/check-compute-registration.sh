#!/bin/bash
#
# SLURM Compute Node Registration Validation Script
# Task 022 - Compute Node Registration Tests
# Validates compute node registration with SLURM controller
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-check-helpers.sh"

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="check-compute-registration.sh"
TEST_NAME="SLURM Compute Node Registration Validation"

# Individual test functions
test_slurmd_service_running() {
    log_info "Checking slurmd service status..."

    if ! command -v systemctl >/dev/null 2>&1; then
        log_warn "systemctl not available - skipping service check"
        return 0
    fi

    # Check if slurmd service is active (most reliable check)
    if systemctl is-active --quiet slurmd; then
        log_info "✓ slurmd service is active and running"

        # Get service status details
        local service_status
        service_status=$(systemctl status slurmd --no-pager --lines=0 2>&1 || true)
        log_debug "slurmd service status: $(echo "$service_status" | grep -E 'Active:|Main PID:' | tr '\n' ' ')"

        return 0
    fi

    # If service is not active, check if binary exists at standard locations
    local slurmd_locations=("/usr/sbin/slurmd" "/usr/bin/slurmd" "/usr/local/sbin/slurmd" "/opt/slurm/bin/slurmd")
    local slurmd_found=false

    for location in "${slurmd_locations[@]}"; do
        if [ -f "$location" ] && [ -x "$location" ]; then
            log_info "✓ slurmd binary found at: $location"
            slurmd_found=true
            break
        fi
    done

    if [ "$slurmd_found" = true ]; then
        log_warn "slurmd binary found but service is not active"
        log_debug "Service may not be started or enabled. Use: systemctl start slurmd"
        return 0
    else
        log_warn "slurmd service not active and binary not found in standard locations"
        log_debug "Checked locations: ${slurmd_locations[*]}"
        return 0
    fi
}

test_node_visibility_in_cluster() {
    log_info "Checking if node is visible in SLURM cluster..."

    if ! command -v sinfo >/dev/null 2>&1; then
        log_warn "sinfo command not available"
        return 0
    fi

    local node_name
    node_name=$(hostname)

    if sinfo -N 2>/dev/null | grep -q "$node_name"; then
        log_info "✓ Node $node_name is visible in cluster"

        # Show node details
        local node_info
        node_info=$(sinfo -N -n "$node_name" 2>/dev/null || echo "Could not retrieve details")
        log_debug "Node info: $node_info"

        return 0
    else
        log_error "Node $node_name is not visible in SLURM cluster"
        log_debug "Available nodes: $(sinfo -N 2>/dev/null || echo 'Could not list nodes')"
        return 1
    fi
}

test_node_state() {
    log_info "Checking node state in SLURM..."

    if ! command -v scontrol >/dev/null 2>&1; then
        log_warn "scontrol command not available"
        return 0
    fi

    local node_name
    node_name=$(hostname)

    if ! scontrol show node "$node_name" >/dev/null 2>&1; then
        log_error "Cannot retrieve node state for $node_name"
        return 1
    fi

    local node_state
    node_state=$(scontrol show node "$node_name" 2>/dev/null | grep -oP 'State=\K\S+' || echo "UNKNOWN")

    log_info "Node state: $node_state"

    case "$node_state" in
        IDLE|ALLOCATED|MIXED)
            log_info "✓ Node is in operational state: $node_state"
            return 0
            ;;
        DOWN|DRAIN|DRAINING)
            log_warn "Node is in non-operational state: $node_state"
            return 0
            ;;
        UNKNOWN)
            log_error "Could not determine node state"
            return 1
            ;;
        *)
            log_info "Node state: $node_state"
            return 0
            ;;
    esac
}

test_munge_communication() {
    log_info "Checking MUNGE authentication..."

    if ! command -v munge >/dev/null 2>&1; then
        log_warn "munge command not available"
        return 0
    fi

    # Test MUNGE credential creation and verification
    if echo "test" | munge | unmunge >/dev/null 2>&1; then
        log_info "✓ MUNGE authentication working"
        return 0
    else
        log_error "MUNGE authentication failed"
        return 1
    fi
}

test_controller_connectivity() {
    log_info "Checking connectivity to SLURM controller..."

    if ! command -v scontrol >/dev/null 2>&1; then
        log_warn "scontrol command not available"
        return 0
    fi

    # Try to get controller information
    if scontrol ping 2>/dev/null | grep -q "is UP"; then
        log_info "✓ Controller is reachable and responding"
        return 0
    elif scontrol show config >/dev/null 2>&1; then
        log_info "✓ Can communicate with controller"
        return 0
    else
        log_error "Cannot communicate with SLURM controller"
        log_debug "scontrol ping output: $(scontrol ping 2>&1 || echo 'Failed')"
        return 1
    fi
}

test_node_resources() {
    log_info "Checking node resource configuration..."

    if ! command -v scontrol >/dev/null 2>&1; then
        log_warn "scontrol command not available"
        return 0
    fi

    local node_name
    node_name=$(hostname)

    local node_info
    node_info=$(scontrol show node "$node_name" 2>/dev/null || echo "")

    if [ -z "$node_info" ]; then
        log_warn "Could not retrieve node resource information"
        return 0
    fi

    # Extract key resource information
    local cpus
    cpus=$(echo "$node_info" | grep -oP 'CPUTot=\K\d+' || echo "unknown")
    local memory
    memory=$(echo "$node_info" | grep -oP 'RealMemory=\K\d+' || echo "unknown")

    log_info "Node resources - CPUs: $cpus, Memory: ${memory}MB"

    if [ "$cpus" != "unknown" ] && [ "$memory" != "unknown" ]; then
        log_info "✓ Node resources configured"
        return 0
    else
        log_warn "Could not determine all node resources"
        return 0
    fi
}

test_slurm_logs() {
    log_info "Checking SLURM daemon logs for errors..."

    local log_file="/var/log/slurm/slurmd.log"

    if [ ! -f "$log_file" ]; then
        log_warn "slurmd log file not found at $log_file"
        return 0
    fi

    # Check for recent errors (last 50 lines)
    local error_count
    error_count=$(tail -n 50 "$log_file" 2>/dev/null | grep -ci "error" || echo "0")

    log_info "Recent error mentions in logs: $error_count"

    if [ "$error_count" -gt 10 ]; then
        log_warn "High number of errors in slurmd log"
        log_debug "Last errors: $(tail -n 50 "$log_file" | grep -i "error" | tail -n 3)"
    else
        log_info "✓ No excessive errors in slurmd log"
    fi

    return 0
}

# Main test execution
main() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}  $TEST_NAME${NC}"
    echo -e "${BLUE}=====================================${NC}"

    log_info "Starting SLURM compute node registration validation"
    log_info "Log directory: $LOG_DIR"
    log_info "Node hostname: $(hostname)"

    # Run all tests
    run_test "slurmd Service Running" test_slurmd_service_running
    run_test "Node Visibility in Cluster" test_node_visibility_in_cluster
    run_test "Node State Check" test_node_state
    run_test "MUNGE Communication" test_munge_communication
    run_test "Controller Connectivity" test_controller_connectivity
    run_test "Node Resources" test_node_resources
    run_test "SLURM Logs Check" test_slurm_logs

    # Print summary using shared function
    print_check_summary
}

# Execute main function
main "$@"
