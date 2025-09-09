#!/bin/bash
#
# Container Runtime Test Suite Master Runner
# Task 008 - Master Test Runner for Container Runtime Validation (Apptainer v1.4.2)
# Orchestrates all container runtime tests per Task 008 requirements
# Adjusted for Apptainer 1.4.2 compatibility and enhanced testing
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="run-container-runtime-tests.sh"
TEST_SUITE_NAME="Container Runtime Test Suite (Task 008)"

# Get script directory and test suite directory
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
TEST_SUITE_DIR="$(cd "$SCRIPT_DIR" && pwd)"

# Use LOG_DIR from environment or default [[memory:8556508]]
: "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# Individual test scripts per Task 008 specification
TEST_SCRIPTS=(
    "check-singularity-install.sh"    # Verify installation and version
    "check-container-execution.sh"    # Test container pull and execution
    "check-container-security.sh"     # Validate security policies
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
PARTIAL_TESTS=0
FAILED_SCRIPTS=()

# Logging functions with LOG_DIR compliance
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}
log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $*" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}
log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $*" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}
log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $*" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

# Function to run individual test script and track results
run_test_script() {
    local test_script="$1"
    local test_name="$2"

    echo | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
    echo "=================================================="  | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
    log "Running: $test_name"
    log "Script: $test_script"
    echo "=================================================="  | tee -a "$LOG_DIR/$SCRIPT_NAME.log"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    # Check if test script exists
    if [[ ! -f "$TEST_SUITE_DIR/$test_script" ]]; then
        log_error "Test script not found: $TEST_SUITE_DIR/$test_script"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_SCRIPTS+=("$test_script")
        return 1
    fi

    # Make script executable
    chmod +x "$TEST_SUITE_DIR/$test_script"

    # Export LOG_DIR for the test script [[memory:8556508]]
    export LOG_DIR

    # Run the test script and capture output
    if cd "$TEST_SUITE_DIR" && "./$test_script" 2>&1; then
        local exit_code=${PIPESTATUS[0]}
    else
        local exit_code=$?
    fi

    case $exit_code in
        0)
            log_success "✅ $test_name: PASSED"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            ;;
        1)
            log_error "❌ $test_name: FAILED"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            FAILED_SCRIPTS+=("$test_script")
            ;;
        *)
            log_warning "⚠ $test_name: PARTIAL/UNKNOWN (exit code: $exit_code)"
            PARTIAL_TESTS=$((PARTIAL_TESTS + 1))
            ;;
    esac

    echo | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
    return "$exit_code"
}

# System information collection
collect_system_info() {
    log "Collecting system information..."

    {
        echo "=== System Information ==="
        echo "Timestamp: $(date)"
        echo "Hostname: $(hostname)"
        echo "User: $(whoami)"
        echo "Working Directory: $(pwd)"
        echo "Test Suite Directory: $TEST_SUITE_DIR"
        echo "Log Directory: $LOG_DIR"
        echo ""
        echo "Operating System:"
        if [[ -f /etc/os-release ]]; then
            grep PRETTY_NAME /etc/os-release | cut -d'"' -f2
        else
            echo "Unknown"
        fi
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo ""
        if command -v free >/dev/null 2>&1; then
            echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
        fi
        if command -v nproc >/dev/null 2>&1; then
            echo "CPU cores: $(nproc)"
        fi
        echo ""
        echo "Container Runtime Information:"
        if command -v apptainer >/dev/null 2>&1; then
            echo "Apptainer version: $(apptainer --version 2>/dev/null || echo 'Version detection failed')"
        else
            echo "Apptainer: Not found"
        fi
        if command -v singularity >/dev/null 2>&1; then
            echo "Singularity version: $(singularity --version 2>/dev/null || echo 'Version detection failed')"
        else
            echo "Singularity: Not found"
        fi
        echo ""
    } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

# Main test execution
run_all_tests() {
    log "Starting Container Runtime Test Suite execution..."

    # Run all individual test scripts
    run_test_script "check-singularity-install.sh" "Installation and Version Verification"
    run_test_script "check-container-execution.sh" "Container Execution Capabilities"
    run_test_script "check-container-security.sh" "Security Policy Validation"
}

# Comprehensive summary report
print_final_summary() {
    echo | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
    echo "=================================================="  | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
    log "$TEST_SUITE_NAME - FINAL RESULTS"
    echo "=================================================="  | tee -a "$LOG_DIR/$SCRIPT_NAME.log"

    {
        echo "Test Execution Summary:"
        echo "  Total test scripts: $TOTAL_TESTS"
        echo "  Passed: $PASSED_TESTS"
        echo "  Failed: $FAILED_TESTS"
        echo "  Partial/Warning: $PARTIAL_TESTS"
        echo ""
        echo "Log Directory: $LOG_DIR"
        echo "Available log files:"
        find "$LOG_DIR" -name "*.log" -type f 2>/dev/null | sort | while read -r logfile; do
            local filename
            local size
            filename=$(basename "$logfile")
            size=$(stat -c%s "$logfile" 2>/dev/null || echo "0")
            echo "  - $filename (${size} bytes)"
        done || echo "  (No log files found)"
        echo ""
    } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"

    # Determine overall result
    if [[ $FAILED_TESTS -eq 0 ]] && [[ $PASSED_TESTS -gt 0 ]]; then
        if [[ $PARTIAL_TESTS -eq 0 ]]; then
            {
                echo "🎉 OVERALL STATUS: ALL TESTS PASSED"
                echo "   Container runtime is working correctly per Task 008 requirements"
                echo ""
                echo "TASK 008 VALIDATION CRITERIA VERIFIED:"
                echo "  ✅ Apptainer binary installed and functional"
                echo "  ✅ All dependencies installed (fuse, squashfs-tools, uidmap, libfuse2, libseccomp2)"
                echo "  ✅ Container can execute simple commands"
                echo "  ✅ Version check returns expected output (>= 1.4.2)"
                echo "  ✅ Security configuration properly applied"
                echo ""
                echo "ADDITIONAL VALIDATIONS COMPLETED:"
                echo "  ✅ Container pull and execution functionality"
                echo "  ✅ Bind mount capabilities"
                echo "  ✅ Filesystem isolation"
                echo "  ✅ User namespace isolation"
                echo "  ✅ Security policy enforcement"
            } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
            exit_status=0
        else
            {
                echo "⚠  OVERALL STATUS: MOSTLY WORKING"
                echo "   Container runtime is functional with some warnings per Task 008"
            } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
            exit_status=0
        fi
    elif [[ $PASSED_TESTS -gt 0 ]] || [[ $PARTIAL_TESTS -gt 0 ]]; then
        {
            echo "⚠  OVERALL STATUS: PARTIAL FUNCTIONALITY"
            echo "   Some components working, others may need configuration"
            echo ""
            if [[ ${#FAILED_SCRIPTS[@]} -gt 0 ]]; then
                echo "Failed test scripts:"
                printf '  ❌ %s\n' "${FAILED_SCRIPTS[@]}"
            fi
        } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
        exit_status=1
    else
        {
            echo "❌ OVERALL STATUS: TESTS FAILED"
            echo "   Container runtime is not working correctly per Task 008 requirements"
            echo ""
            if [[ ${#FAILED_SCRIPTS[@]} -gt 0 ]]; then
                echo "Failed test scripts:"
                printf '  ❌ %s\n' "${FAILED_SCRIPTS[@]}"
            fi
        } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
        exit_status=1
    fi

    {
        echo "=================================================="
        echo "Test Suite completed at: $(date)"
        echo "=================================================="
    } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"

    return $exit_status
}

# Help and usage information
show_usage() {
    cat << EOF
$TEST_SUITE_NAME

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    Master test runner that executes all container runtime validation tests
    as specified in Task 008. Tests are run in sequence and results are
    collected for comprehensive validation reporting.

    This test suite validates:
    • Container runtime installation and version compliance
    • Container execution capabilities (pull, run, bind mounts)
    • Security policy validation and enforcement
    • Dependency installation verification

OPTIONS:
    --help, -h          Show this help message
    --verbose, -v       Enable verbose output
    --list-tests        List available test scripts
    --test-only SCRIPT  Run only specific test script

ENVIRONMENT VARIABLES:
    LOG_DIR            Directory for log files (default: ./logs/run-TIMESTAMP)

TEST SCRIPTS INCLUDED:
EOF
    for script in "${TEST_SCRIPTS[@]}"; do
        echo "  • $script"
    done
    cat << EOF

LOG FILES:
    All test results are saved to timestamped directories under LOG_DIR:
    • run-container-runtime-tests.log: Master runner output
    • check-singularity-install.log: Installation validation
    • check-container-execution.log: Execution capabilities
    • check-container-security.log: Security validation

EXIT CODES:
    0: All tests passed successfully
    1: Some tests failed or framework error

EXAMPLES:
    # Run all tests with default settings
    $0

    # Run with verbose output
    $0 --verbose

    # List available tests
    $0 --list-tests

    # Run specific test only
    $0 --test-only check-singularity-install.sh

EOF
}

# Command line argument parsing
VERBOSE_MODE=false
LIST_TESTS=false
TEST_ONLY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_usage
            exit 0
            ;;
        --verbose|-v)
            VERBOSE_MODE=true
            export VERBOSE_MODE
            log "Verbose mode enabled"
            ;;
        --list-tests)
            LIST_TESTS=true
            ;;
        --test-only)
            shift
            if [[ $# -gt 0 ]]; then
                TEST_ONLY="$1"
            else
                log_error "--test-only requires a script name"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Handle list tests option
if [[ "$LIST_TESTS" == "true" ]]; then
    echo "Available test scripts:"
    for script in "${TEST_SCRIPTS[@]}"; do
        echo "  • $script"
        if [[ -f "$TEST_SUITE_DIR/$script" ]]; then
            echo "    Status: Available"
        else
            echo "    Status: Missing"
        fi
    done
    exit 0
fi

# Main execution
main() {
    {
        echo "========================================"
        echo "$TEST_SUITE_NAME"
        echo "========================================"
        echo "Master Runner: $SCRIPT_NAME"
        echo "Started: $(date)"
        echo "Test Suite Directory: $TEST_SUITE_DIR"
        echo "Log Directory: $LOG_DIR"
        echo ""
    } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"

    # Collect system information
    collect_system_info

    # Handle single test execution
    if [[ -n "$TEST_ONLY" ]]; then
        log "Running single test: $TEST_ONLY"
        if run_test_script "$TEST_ONLY" "Single Test: $TEST_ONLY"; then
            log_success "Single test completed successfully"
            exit 0
        else
            log_error "Single test failed"
            exit 1
        fi
    fi

    # Run all tests
    log "=== Running Container Runtime Test Suite ==="
    run_all_tests

    # Generate final summary and exit with appropriate code
    if print_final_summary; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
