#!/bin/bash
#
# Container E2E Test Suite Master Runner
# Orchestrates end-to-end container integration tests
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
SCRIPT_NAME="run-container-e2e-tests.sh"
TEST_SUITE_NAME="Container E2E Test Suite"
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

# Test configuration (local execution on controller node)
REGISTRY_PATH="${REGISTRY_PATH:-/mnt/beegfs/containers/apptainer}"
TEST_IMAGE="${TEST_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"

# Test scripts - Consolidated container E2E tests
# All tests are now in the unified test-container-suite.sh
# shellcheck disable=SC2034
declare -a E2E_TESTS=(
    "test-container-suite.sh"           # Consolidated E2E tests
)

# Main test scripts array (used for execution)
TEST_SCRIPTS=(
    "test-container-suite.sh"           # Container E2E Suite
)

# Validate local environment prerequisites
validate_environment() {
    log_info "Validating local environment..."

    # Check hostname
    local hostname
    hostname=$(hostname)
    log_info "Running on: $hostname"

    return 0
}

# Parse script results from log
parse_script_results() {
    local script_name="$1"
    local log_file="$LOG_DIR/${script_name%.sh}.log"

    local tests_run=0
    local tests_passed=0
    local tests_failed=0

    if [[ -f "$log_file" ]]; then
        # Try multiple patterns for summary lines
        # Pattern 1: "Tests Run:  X" / "Tests Passed:  X" / "Tests Failed:  X"
        tests_run=$(grep -E "^Tests Run:" "$log_file" 2>/dev/null | tail -1 | grep -oE '[0-9]+$') || tests_run=0
        tests_passed=$(grep -E "^Tests Passed:" "$log_file" 2>/dev/null | tail -1 | grep -oE '[0-9]+$') || tests_passed=0
        tests_failed=$(grep -E "^Tests Failed:" "$log_file" 2>/dev/null | tail -1 | grep -oE '[0-9]+$') || tests_failed=0

        # If no explicit summary found, count PASS/FAIL lines
        if [[ $tests_run -eq 0 ]]; then
            local pass_count
            pass_count=$(grep -c "\\[PASS\\]" "$log_file" 2>/dev/null) || pass_count=0
            local fail_count
            fail_count=$(grep -c "\\[FAIL\\]" "$log_file" 2>/dev/null) || fail_count=0

            if [[ $pass_count -gt 0 ]] || [[ $fail_count -gt 0 ]]; then
                tests_run=$((pass_count + fail_count))
                tests_passed=$pass_count
                tests_failed=$fail_count
            fi
        fi
    else
        log_warn "Log file not found: $log_file"
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
    log_info "- Registry Path: $REGISTRY_PATH"
    log_info "- Test Image: $TEST_IMAGE"
    log_info "- Test Scripts: ${#TEST_SCRIPTS[@]}"
    echo ""

    log_info "Pre-flight Checks:"
    echo ""

    # Validate local environment
    validate_environment
    echo ""

    log_info "Checking container runtime and registry..."

    # Check Apptainer
    if command -v apptainer >/dev/null 2>&1; then
        local apptainer_version
        apptainer_version=$(apptainer --version 2>&1 || echo "unknown")
        log_success "✓ Apptainer available: $apptainer_version"
    else
        log_warn "⚠ Apptainer not found. Install with: apt install apptainer"
    fi

    # Check registry path
    if [[ -d "$REGISTRY_PATH" ]]; then
        log_success "✓ Registry path exists: $REGISTRY_PATH"
    else
        log_error "✗ Registry path not found: $REGISTRY_PATH"
        log_info "Please ensure: REGISTRY_PATH is set to correct container registry location"
        exit 1
    fi

    # Check if test image exists
    if [[ -f "$REGISTRY_PATH/$TEST_IMAGE" ]]; then
        log_success "✓ Test image available: $TEST_IMAGE"
    else
        log_warn "⚠ Test image not found: $REGISTRY_PATH/$TEST_IMAGE"
        log_info "Available images:"
        find "$REGISTRY_PATH" -name "*.sif" -type f 2>/dev/null | head -10 || true
    fi

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
            echo "  Container E2E test suite for validating end-to-end container deployment"
            echo "  and execution with SLURM and container runtime integration."
            echo ""
            echo "  This suite runs ON the test controller to validate container deployment"
            echo "  and execution. The framework handles cluster orchestration."
            echo ""
            echo "Environment Variables:"
            echo "  LOG_DIR                    Directory for test logs (default: ./logs/run-YYYY-MM-DD_HH-MM-SS)"
            echo "  REGISTRY_PATH              Path to container registry (default: /mnt/beegfs/containers/apptainer)"
            echo "  TEST_IMAGE                 Container image name (default: pytorch-cuda12.1-mpi4.1.sif)"
            echo ""
            echo "Test Scripts:"
            echo "  - test-container-suite.sh (consolidated E2E tests)"
            echo ""
            echo "Included Tests:"
            echo "  1. Multi-image deployment validation"
            echo "  2. Container job execution"
            echo "  3. PyTorch E2E workflow"
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
