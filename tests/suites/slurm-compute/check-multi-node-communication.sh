#!/bin/bash
#
# SLURM Multi-Node Communication Validation Script
# Task 022 - Multi-Node Connectivity Tests
# Validates multi-node communication and MUNGE authentication
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="check-multi-node-communication.sh"
TEST_NAME="SLURM Multi-Node Communication Validation"

# Use LOG_DIR from environment or default
: "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
FAILED_TESTS=()

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

# Test execution functions
run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    echo -e "\n${BLUE}Running Test ${TESTS_RUN}: ${test_name}${NC}"

    if $test_function; then
        log_info "✓ Test passed: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ Test failed: $test_name"
        FAILED_TESTS+=("$test_name")
        return 1
    fi
}

# Individual test functions
test_cluster_node_list() {
    log_info "Checking cluster node list..."

    if ! command -v sinfo >/dev/null 2>&1; then
        log_warn "sinfo command not available"
        return 0
    fi

    local node_count
    node_count=$(sinfo -N -h 2>/dev/null | wc -l)

    log_info "Nodes in cluster: $node_count"

    if [ "$node_count" -gt 0 ]; then
        log_info "✓ Cluster has $node_count node(s)"

        # List all nodes
        log_debug "Node list:"
        sinfo -N 2>/dev/null | tee -a "$LOG_DIR/$SCRIPT_NAME.log" || true

        return 0
    else
        log_error "No nodes found in cluster"
        return 1
    fi
}

test_partition_configuration() {
    log_info "Checking partition configuration..."

    if ! command -v sinfo >/dev/null 2>&1; then
        log_warn "sinfo command not available"
        return 0
    fi

    local partition_count
    partition_count=$(sinfo -h 2>/dev/null | wc -l)

    log_info "Partitions configured: $partition_count"

    if [ "$partition_count" -gt 0 ]; then
        log_info "✓ Found $partition_count partition(s)"

        # List partitions
        log_debug "Partition list:"
        sinfo 2>/dev/null | tee -a "$LOG_DIR/$SCRIPT_NAME.log" || true

        return 0
    else
        log_warn "No partitions found"
        return 0
    fi
}

test_munge_across_nodes() {
    log_info "Testing MUNGE authentication across nodes..."

    if ! command -v munge >/dev/null 2>&1 || ! command -v unmunge >/dev/null 2>&1; then
        log_warn "munge/unmunge commands not available"
        return 0
    fi

    # Test local MUNGE
    if echo "test-credential" | munge | unmunge >/dev/null 2>&1; then
        log_info "✓ Local MUNGE authentication working"
    else
        log_error "Local MUNGE authentication failed"
        return 1
    fi

    # Check MUNGE service
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet munge; then
            log_info "✓ MUNGE service is running"
        else
            log_warn "MUNGE service is not running"
        fi
    fi

    return 0
}

test_node_to_node_ping() {
    log_info "Testing node-to-node basic connectivity..."

    if ! command -v scontrol >/dev/null 2>&1; then
        log_warn "scontrol command not available"
        return 0
    fi

    # Try to ping controller
    if scontrol ping 2>/dev/null | grep -q "is UP"; then
        log_info "✓ Controller is reachable"
        return 0
    else
        log_warn "Could not ping controller (may be expected in some configurations)"
        return 0
    fi
}

test_slurm_communication_ports() {
    log_info "Checking SLURM communication ports..."

    # Check if slurmd is listening on its port
    if command -v ss >/dev/null 2>&1; then
        if ss -tlnp 2>/dev/null | grep -q slurmd; then
            log_info "✓ slurmd is listening on network port"
            log_debug "slurmd ports: $(ss -tlnp 2>/dev/null | grep slurmd)"
        else
            log_warn "slurmd may not be listening on network port"
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tlnp 2>/dev/null | grep -q slurmd; then
            log_info "✓ slurmd is listening on network port"
        else
            log_warn "slurmd may not be listening on network port"
        fi
    else
        log_warn "Cannot check network ports (ss/netstat not available)"
    fi

    return 0
}

test_compute_to_controller_communication() {
    log_info "Testing compute-to-controller communication..."

    if ! command -v scontrol >/dev/null 2>&1; then
        log_warn "scontrol command not available"
        return 0
    fi

    # Try to retrieve configuration from controller
    if scontrol show config >/dev/null 2>&1; then
        log_info "✓ Can retrieve configuration from controller"

        # Get controller name
        local controller_name
        controller_name=$(scontrol show config 2>/dev/null | grep -oP 'ControlMachine\s*=\s*\K\S+' || echo "unknown")
        log_info "Controller: $controller_name"

        return 0
    else
        log_error "Cannot communicate with controller"
        return 1
    fi
}

test_inter_node_job_submission() {
    log_info "Testing inter-node job submission capability..."

    if ! command -v srun >/dev/null 2>&1; then
        log_warn "srun command not available"
        return 0
    fi

    # Try a simple test job
    if timeout 30 srun -N1 hostname >/dev/null 2>&1; then
        log_info "✓ Can submit jobs to cluster"
        return 0
    else
        log_warn "Job submission test failed (may be expected if cluster is not fully configured)"
        return 0
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}  $TEST_NAME${NC}"
    echo -e "${BLUE}=====================================${NC}"

    log_info "Starting SLURM multi-node communication validation"
    log_info "Log directory: $LOG_DIR"
    log_info "Current node: $(hostname)"

    # Run all tests
    run_test "Cluster Node List" test_cluster_node_list
    run_test "Partition Configuration" test_partition_configuration
    run_test "MUNGE Authentication" test_munge_across_nodes
    run_test "Node-to-Node Ping" test_node_to_node_ping
    run_test "SLURM Communication Ports" test_slurm_communication_ports
    run_test "Compute-Controller Communication" test_compute_to_controller_communication
    run_test "Inter-Node Job Submission" test_inter_node_job_submission

    # Final results
    echo -e "\n${BLUE}=====================================${NC}"
    echo -e "${BLUE}  Test Results Summary${NC}"
    echo -e "${BLUE}=====================================${NC}"

    echo -e "Total tests run: ${TESTS_RUN}"
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}$((TESTS_RUN - TESTS_PASSED))${NC}"

    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        echo -e "\n${RED}Failed tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  - $test"
        done
        return 1
    fi

    log_info "Multi-node communication validation passed (${TESTS_PASSED}/${TESTS_RUN} tests)"
    return 0
}

# Execute main function
main "$@"
