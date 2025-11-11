#!/bin/bash
#
# Container Integration Test Suite Master Runner
# Orchestrates all container integration validation tests
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Resolve script and common utility directories (preserve this script's path)
SUITE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SUITE_SCRIPT_DIR/../common" && pwd)"
PROJECT_ROOT="$(cd "$SUITE_SCRIPT_DIR/../../.." && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "${COMMON_DIR}/suite-utils.sh"
# shellcheck source=/dev/null
source "${COMMON_DIR}/suite-logging.sh"
# shellcheck source=/dev/null
source "${COMMON_DIR}/suite-test-runner.sh"

# Script configuration
SCRIPT_NAME="run-container-integration-tests.sh"
TEST_SUITE_NAME="Container Integration Test Suite"
SCRIPT_DIR="$SUITE_SCRIPT_DIR"
TEST_SUITE_DIR="$SUITE_SCRIPT_DIR"
export SCRIPT_DIR
export TEST_SUITE_DIR
export PROJECT_ROOT
# Export SSH agent variables if available (for test scripts that need SSH)
export SSH_AUTH_SOCK SSH_AGENT_PID

# Configure logging directories
: "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME%.sh}.log"
touch "$LOG_FILE"

# Initialize suite logging and test runner
init_suite_logging "$TEST_SUITE_NAME"
init_test_runner

# Per-script results tracking
declare -A SCRIPT_RESULTS
declare -a EXECUTED_SCRIPTS

# Container configuration (can be overridden by framework via environment variables)
# Containers are deployed to BeeGFS for cluster-wide availability
export CONTAINER_IMAGE="${CONTAINER_IMAGE:-/mnt/beegfs/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif}"
export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-apptainer}"

# Test Controller configuration
# TEST_CONTROLLER defaults to localhost if not already set by framework
export TEST_CONTROLLER="${TEST_CONTROLLER:-localhost}"

# Test scripts categorized by execution context
# CONTROLLER_TESTS: Run on controller - orchestrate jobs via SLURM
# shellcheck disable=SC2034
declare -a CONTROLLER_TESTS=(
    "check-container-slurm-integration.sh"      # SLURM job submission, GPU GRES, batch jobs
)

# GPU_COMPUTE_TESTS: Run on compute node with GPU - direct GPU interaction
# shellcheck disable=SC2034
declare -a GPU_COMPUTE_TESTS=(
    "check-pytorch-cuda-integration.sh"         # GPU tensor operations, CUDA device access
)

# SHARED_FS_TESTS: Run once (container on shared BeeGFS) - any node OK
# shellcheck disable=SC2034
declare -a SHARED_FS_TESTS=(
    "check-mpi-communication.sh"                 # MPI within container
    "check-distributed-training.sh"             # Distributed training setup
)

# Legacy: all tests (for backwards compatibility)
# Note: Basic container functionality tests moved to container-runtime suite
TEST_SCRIPTS=(
    "check-pytorch-cuda-integration.sh"
    "check-mpi-communication.sh"
    "check-distributed-training.sh"
    "check-container-slurm-integration.sh"
)

# Test execution mode (can be overridden by framework)
# Values: "all" (legacy), "smart" (recommended), "controller-only", "gpu-node-only"
export TEST_EXECUTION_MODE="${TEST_EXECUTION_MODE:-smart}"

# Check container image availability (LOCAL check - runs ON target VM)
check_container_availability() {
    log_info "Checking container image availability..."

    if [[ -f "$CONTAINER_IMAGE" ]]; then
        log_success "✓ Container image exists: $CONTAINER_IMAGE"
        return 0
    else
        log_error "✗ Container image not found: $CONTAINER_IMAGE"
        log_error ""
        log_error "Container image must be deployed before running integration tests"
        log_error ""
        log_info "To deploy containers to BeeGFS (cluster-wide), run:"
        log_info "  make containers-deploy-beegfs"
        log_info ""
        log_info "Or to deploy to a local registry, run:"
        log_info "  make containers-deploy-single <path-to-sif-image>"
        log_info ""
        log_info "Expected container path: $CONTAINER_IMAGE"
        return 1
    fi
}

# Check SLURM availability (LOCAL check - runs ON target VM)
check_slurm_availability() {
    log_info "Checking SLURM availability..."

    if command -v sinfo >/dev/null 2>&1 && sinfo --version >/dev/null 2>&1; then
        log_success "✓ SLURM is running"
        return 0
    else
        log_warn "✗ SLURM is not running or not accessible"
        log_info ""
        log_warn "WARNING: Some integration tests may fail without SLURM"
        log_info ""
        log_info "Continuing with tests (some may be skipped)..."
        return 0  # Don't fail - continue with tests
    fi
}

# Parse script results from log
parse_script_results() {
    local script_name="$1"
    local log_file="$LOG_DIR/${script_name%.sh}.log"

    local tests_run=0
    local tests_passed=0
    local tests_failed=0

    if [[ -f "$log_file" ]]; then
        tests_run=$(grep -E "^Tests Run:" "$log_file" 2>/dev/null | tail -1 | awk '{print $NF}') || tests_run=0
        tests_passed=$(grep -E "^Tests Passed:" "$log_file" 2>/dev/null | tail -1 | awk '{print $NF}') || tests_passed=0
        tests_failed=$(grep -E "^Tests Failed:" "$log_file" 2>/dev/null | tail -1 | awk '{print $NF}') || tests_failed=0
    fi

    SCRIPT_RESULTS["${script_name}_run"]=$tests_run
    SCRIPT_RESULTS["${script_name}_passed"]=$tests_passed
    SCRIPT_RESULTS["${script_name}_failed"]=$tests_failed
    EXECUTED_SCRIPTS+=("$script_name")
}

# Print per-script summary table
print_scripts_summary() {
    if [[ ${#EXECUTED_SCRIPTS[@]} -eq 0 ]]; then
        return 0
    fi

    echo ""
    echo "─────────────────────────────────────────────────────────────"
    echo "Per-Script Test Results Summary"
    echo "─────────────────────────────────────────────────────────────"
    echo ""
    echo "Script Name                            | Run | Pass | Fail | Status"
    echo "──────────────────────────────────────┼─────┼──────┼──────┼────────"

    local total_run=0
    local total_passed=0
    local total_failed=0

    for script in "${EXECUTED_SCRIPTS[@]}"; do
        local run=${SCRIPT_RESULTS["${script}_run"]:-0}
        local passed=${SCRIPT_RESULTS["${script}_passed"]:-0}
        local failed=${SCRIPT_RESULTS["${script}_failed"]:-0}

        total_run=$((total_run + run))
        total_passed=$((total_passed + passed))
        total_failed=$((total_failed + failed))

        local status="⚠️  UNKNOWN"
        if [[ $failed -gt 0 ]]; then
            status="❌ FAILED"
        elif [[ $run -eq 0 ]]; then
            status="⊘  SKIPPED"
        elif [[ $passed -eq $run ]]; then
            status="✅ PASSED"
        fi

        local display_name="${script:0:36}"
        printf "%-37s | %3d | %4d | %4d | %s\n" "$display_name" "$run" "$passed" "$failed" "$status"
    done

    echo "──────────────────────────────────────┼─────┼──────┼──────┼────────"
    printf "%-37s | %3d | %4d | %4d | %s\n" "TOTAL" "$total_run" "$total_passed" "$total_failed" "═══════"
    echo ""
}

# Cleanup functions
cleanup_test_environment() {
    log_debug "Cleaning up test environment..."
    # No specific cleanup needed for container integration tests
    log_debug "Test environment cleanup completed"
}

# Main execution function
main() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $TEST_SUITE_NAME${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    log_info "Environment Information:"
    log_info "- Hostname: $(hostname)"
    log_info "- Test Controller: $TEST_CONTROLLER"
    log_info "- Container Image: $CONTAINER_IMAGE"
    log_info "- Container Runtime: $CONTAINER_RUNTIME"
    log_info "- Test Scripts: ${#TEST_SCRIPTS[@]}"
    echo ""

    log_info "Pre-flight Checks:"
    echo ""

    # Check if container image exists (LOCAL check)
    if ! check_container_availability; then
        log_error "ERROR: Pre-flight check failed"
        exit 1
    fi
    echo ""

    # Check if SLURM is running (LOCAL check)
    check_slurm_availability
    echo ""

    log_success "Pre-flight checks complete. Starting tests..."
    echo ""

    # Run each test script and capture results
    for script in "${TEST_SCRIPTS[@]}"; do
        run_test_script "$script" || true
        parse_script_results "$script"
    done

    # Cleanup
    cleanup_test_environment

    # Print per-script summary
    print_scripts_summary

    # Print overall test summary
    print_test_summary
    local test_result=$?

    # Exit with result from summary
    exit $test_result
}

# Handle script interruption
trap cleanup_test_environment EXIT

# Parse command line arguments
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Enable verbose output"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Description:"
            echo "  This suite runs ON the target VM (controller or compute node) to validate"
            echo "  container integration. The framework handles cluster orchestration."
            echo ""
            echo "Environment Variables:"
            echo "  LOG_DIR                    Directory for test logs (default: ./logs/run-YYYY-MM-DD_HH-MM-SS)"
            echo "  CONTAINER_IMAGE            Path to container image (default: /opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif)"
            echo "  CONTAINER_RUNTIME          Container runtime (default: apptainer)"
            echo ""
            echo "Test Scripts:"
            for script in "${TEST_SCRIPTS[@]}"; do
                echo "  - $script"
            done
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Enable verbose mode if requested
if [ "$VERBOSE" = true ]; then
    set -x
    log_debug "Verbose mode enabled"
fi

# Execute main function
main "$@"
