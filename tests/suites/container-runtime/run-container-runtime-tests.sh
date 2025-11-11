#!/bin/bash
#
# Container Runtime Test Suite Master Runner
# Task 008 - Master Test Runner for Container Runtime Validation (Apptainer v1.4.2)
# Orchestrates all container runtime tests per Task 008 requirements
# Adjusted for Apptainer 1.4.2 compatibility and enhanced testing
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
SCRIPT_NAME="run-container-runtime-tests.sh"
TEST_SUITE_NAME="Container Runtime Test Suite"
SCRIPT_DIR="$SUITE_SCRIPT_DIR"
TEST_SUITE_DIR="$SUITE_SCRIPT_DIR"
export SCRIPT_DIR
export TEST_SUITE_DIR
export PROJECT_ROOT

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

# Test scripts categorized by execution context
# BASIC_TESTS: Run on any node - container runtime installation and setup
# shellcheck disable=SC2034
declare -a BASIC_TESTS=(
    "check-singularity-install.sh"           # Task 008: Verify installation and version
)

# EXECUTION_TESTS: Run on any node - container execution capabilities
# shellcheck disable=SC2034
declare -a EXECUTION_TESTS=(
    "check-container-execution.sh"           # Task 008: Test container pull and execution
)

# SECURITY_TESTS: Run on any node - security validation
# shellcheck disable=SC2034
declare -a SECURITY_TESTS=(
    "check-comprehensive-security.sh"        # Task 009: Comprehensive security validation
)

# Legacy: all tests (for backwards compatibility)
TEST_SCRIPTS=(
    "check-singularity-install.sh"
    "check-container-execution.sh"
    "check-comprehensive-security.sh"
)

# Pre-flight check functions
check_container_runtime_availability() {
    log_info "Checking container runtime availability..."

    if command -v apptainer >/dev/null 2>&1; then
        log_success "✓ Container runtime (apptainer) is available"
        return 0
    else
        log_error "✗ Container runtime (apptainer) not found"
        return 1
    fi
}

# Parse script results from log
parse_script_results() {
    local script_name="$1"
    local log_file="$LOG_DIR/${script_name%.sh}.log"

    # Initialize defaults
    local tests_run=0
    local tests_passed=0
    local tests_failed=0

    # Debug output
    log_debug "Parsing results for: $script_name"
    log_debug "Log file path: $log_file"

    # Extract test counters from log if available
    if [[ -f "$log_file" ]]; then
        log_debug "Log file found, size: $(wc -c < "$log_file") bytes"

        # Look for test summary lines - match both formats:
        # "Tests Run:    $TESTS_RUN" and "Tests Run: $TESTS_RUN"
        tests_run=$(grep -E "^Tests Run:" "$log_file" 2>/dev/null | tail -1 | grep -oE '[0-9]+$') || tests_run=0
        tests_passed=$(grep -E "^Tests Passed:" "$log_file" 2>/dev/null | tail -1 | grep -oE '[0-9]+$') || tests_passed=0
        tests_failed=$(grep -E "^Tests Failed:" "$log_file" 2>/dev/null | tail -1 | grep -oE '[0-9]+$') || tests_failed=0

        log_debug "Initial parse: Run=$tests_run, Passed=$tests_passed, Failed=$tests_failed"

        # Fallback: count [PASS] and [FAIL] markers if summary not found
        if [[ $tests_run -eq 0 ]]; then
            log_debug "Summary lines not found, trying marker count fallback"
            local pass_count
            pass_count=$(grep -c "\\[PASS\\]" "$log_file" 2>/dev/null) || pass_count=0
            local fail_count
            fail_count=$(grep -c "\\[FAIL\\]" "$log_file" 2>/dev/null) || fail_count=0

            log_debug "Marker counts: Pass markers=$pass_count, Fail markers=$fail_count"

            if [[ $pass_count -gt 0 ]] || [[ $fail_count -gt 0 ]]; then
                tests_run=$((pass_count + fail_count))
                tests_passed=$pass_count
                tests_failed=$fail_count
                log_debug "Using fallback counts: Run=$tests_run, Passed=$tests_passed, Failed=$tests_failed"
            fi
        fi
    else
        log_warn "Log file not found: $log_file"
        log_debug "Expected log file at: $log_file"
    fi

    # Ensure we have valid numbers
    tests_run=${tests_run:-0}
    tests_passed=${tests_passed:-0}
    tests_failed=${tests_failed:-0}

    # Store results in associative array
    SCRIPT_RESULTS["${script_name}_run"]=$tests_run
    SCRIPT_RESULTS["${script_name}_passed"]=$tests_passed
    SCRIPT_RESULTS["${script_name}_failed"]=$tests_failed

    # Track executed scripts
    EXECUTED_SCRIPTS+=("$script_name")

    log_debug "Final stored results: Run=${SCRIPT_RESULTS["${script_name}_run"]}, Passed=${SCRIPT_RESULTS["${script_name}_passed"]}, Failed=${SCRIPT_RESULTS["${script_name}_failed"]}"
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

        # Accumulate totals
        total_run=$((total_run + run))
        total_passed=$((total_passed + passed))
        total_failed=$((total_failed + failed))

        # Determine status
        local status="⚠️  UNKNOWN"
        if [[ $failed -gt 0 ]]; then
            status="❌ FAILED"
        elif [[ $run -eq 0 ]]; then
            status="⊘  SKIPPED"
        elif [[ $passed -eq $run ]]; then
            status="✅ PASSED"
        fi

        # Format output (truncate script name if too long)
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
    # No specific cleanup needed for container runtime tests
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
    log_info "- Container Runtime: apptainer"
    log_info "- Test Suite: Container Runtime Validation (Task 008 & 009)"
    log_info "- Test Scripts: ${#TEST_SCRIPTS[@]}"
    echo ""

    log_info "Pre-flight Checks:"
    echo ""

    # Check if container runtime is available (LOCAL check)
    if ! check_container_runtime_availability; then
        log_error "ERROR: Pre-flight check failed"
        exit 1
    fi
    echo ""

    log_success "Pre-flight checks complete. Starting tests..."
    echo ""

    # Run each test script and capture results
    for script in "${TEST_SCRIPTS[@]}"; do
        log_info ""
        log_info "Executing: $script"
        log_info "Log output: $LOG_DIR/${script%.sh}.log"

        # Run test script with output redirected to log file
        if "$TEST_SUITE_DIR/$script" > "$LOG_DIR/${script%.sh}.log" 2>&1; then
            log_success "✓ Test script completed: $script"
        else
            local exit_code=$?
            log_warn "⚠ Test script exit code: $exit_code for $script"
        fi

        # Parse results from this script's log
        parse_script_results "$script"

        # Show parsed results
        local run=${SCRIPT_RESULTS["${script}_run"]:-0}
        local passed=${SCRIPT_RESULTS["${script}_passed"]:-0}
        local failed=${SCRIPT_RESULTS["${script}_failed"]:-0}
        log_info "Parsed results: Run=$run, Passed=$passed, Failed=$failed"
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

# Help and usage information
show_usage() {
    cat << EOF
$TEST_SUITE_NAME

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    Master test runner that executes all container runtime validation tests
    as specified in Task 008 and Task 009 requirements.

    This test suite validates:
    • Container runtime installation and version compliance (Task 008)
    • Container execution capabilities (pull, run, bind mounts) (Task 008)
    • Comprehensive security validation and enforcement (Task 009)
    • All required dependencies and security policies

OPTIONS:
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

ENVIRONMENT VARIABLES:
    LOG_DIR             Directory for test logs (default: ./logs/run-YYYY-MM-DD_HH-MM-SS)

TEST SCRIPTS INCLUDED:
EOF
    for script in "${TEST_SCRIPTS[@]}"; do
        echo "  - $script"
    done
    cat << EOF

LOG FILES:
    All test results saved to timestamped directories under LOG_DIR:
    • run-container-runtime-tests.log: Master runner output
    • check-singularity-install.log: Installation validation (Task 008)
    • check-container-execution.log: Execution capabilities (Task 008)
    • check-comprehensive-security.log: Comprehensive security validation (Task 009)

EXIT CODES:
    0: All tests passed successfully
    1: Some tests failed or framework error

EXAMPLES:
    # Run all tests with default settings
    $0

    # Run with verbose output
    $0 --verbose

    # Show help
    $0 --help

EOF
}

# Parse command line arguments
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Handle script interruption
trap cleanup_test_environment EXIT

# Enable verbose mode if requested
if [ "$VERBOSE" = true ]; then
    set -x
    log_debug "Verbose mode enabled"
fi

# Execute main function
main "$@"
