#!/bin/bash
#
# Test Suite Logging Utilities
# Standardized logging functions for test suite scripts
# Provides enhanced logging with suite context and formatted output
#

set -euo pipefail

# Source existing utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Derive PROJECT_ROOT with fallback for remote VMs
# When running locally: SCRIPT_DIR is tests/suites/common, go up 3 levels to project root
# When running on remote VM via SCP: PROJECT_ROOT may need to be passed via environment
PROJECT_ROOT="${PROJECT_ROOT:-}"
if [[ -z "$PROJECT_ROOT" ]]; then
    # Try to derive from SCRIPT_DIR (works when script is in original location)
    PROJECT_ROOT_DERIVED="$(cd "$SCRIPT_DIR/../../.." && pwd)"
    if [[ -d "$PROJECT_ROOT_DERIVED/tests/test-infra/utils" ]]; then
        PROJECT_ROOT="$PROJECT_ROOT_DERIVED"
    fi
fi

TEST_INFRA_UTILS_DIR="$PROJECT_ROOT/tests/test-infra/utils"
LOG_UTILS_FILE="$TEST_INFRA_UTILS_DIR/log-utils.sh"

# Diagnostic output when DEBUG mode enabled
if [[ "${DEBUG_SUITE_PATHS:-0}" == "1" ]]; then
    echo "[DEBUG] Running in: $(pwd)" >&2
    echo "[DEBUG] SCRIPT_DIR: $SCRIPT_DIR" >&2
    echo "[DEBUG] PROJECT_ROOT: $PROJECT_ROOT" >&2
    echo "[DEBUG] TEST_INFRA_UTILS_DIR: $TEST_INFRA_UTILS_DIR" >&2
fi

# Verify test-infra utilities are available - fail immediately if not found
if [[ ! -d "$TEST_INFRA_UTILS_DIR" ]]; then
    echo "FATAL: Test infrastructure utilities directory not found: $TEST_INFRA_UTILS_DIR" >&2
    echo "FATAL: Running from directory: $(pwd)" >&2
    echo "FATAL: SCRIPT_DIR: $SCRIPT_DIR" >&2
    echo "FATAL: PROJECT_ROOT: $PROJECT_ROOT" >&2
    echo "FATAL: Suite logging requires shared utilities from tests/test-infra/utils/" >&2
    echo "FATAL: Set PROJECT_ROOT environment variable to correct location on remote systems" >&2
    exit 1
fi

if [[ ! -f "$LOG_UTILS_FILE" ]]; then
    echo "FATAL: Required log utilities not found: $LOG_UTILS_FILE" >&2
    echo "FATAL: Expected shared logging functions from tests/test-infra/utils/log-utils.sh" >&2
    exit 1
fi

# Source log utilities - required for test suite operation
# shellcheck source=/dev/null
source "$LOG_UTILS_FILE"

# Color definitions (standardized across all test suites)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Suite context variables
SUITE_NAME=""
SUITE_START_TIME=""
CURRENT_TEST=""

# Initialize suite logging
init_suite_logging() {
    local suite_name="$1"
    SUITE_NAME="$suite_name"
    SUITE_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

    # Ensure LOG_DIR exists
    : "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
    mkdir -p "$LOG_DIR"

    log_suite_info "Initializing test suite: $suite_name"
    log_suite_info "Log directory: $LOG_DIR"
    log_suite_info "Start time: $SUITE_START_TIME"
}

# Suite-level logging functions

# Log suite information
log_suite_info() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    echo -e "${BLUE}[SUITE-INFO]${NC} ${timestamp} | $message" | tee -a "$LOG_DIR/${SUITE_NAME}.log"
}

# Log suite success
log_suite_success() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    echo -e "${GREEN}[SUITE-SUCCESS]${NC} ${timestamp} | $message" | tee -a "$LOG_DIR/${SUITE_NAME}.log"
}

# Log suite error
log_suite_error() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    echo -e "${RED}[SUITE-ERROR]${NC} ${timestamp} | $message" | tee -a "$LOG_DIR/${SUITE_NAME}.log"
}

# Log suite warning
log_suite_warning() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    echo -e "${YELLOW}[SUITE-WARNING]${NC} ${timestamp} | $message" | tee -a "$LOG_DIR/${SUITE_NAME}.log"
}

# Test-level logging functions

# Log test start
log_test_start() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    echo -e "${CYAN}[TEST-START]${NC} ${timestamp} | Starting: $test_name" | tee -a "$LOG_DIR/${SUITE_NAME}.log"
}

# Log test success
log_test_success() {
    local test_name="${1:-$CURRENT_TEST}"
    local message="${2:-Test completed successfully}"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    echo -e "${GREEN}[TEST-SUCCESS]${NC} ${timestamp} | $test_name: $message" | tee -a "$LOG_DIR/${SUITE_NAME}.log"
}

# Log test failure
log_test_failure() {
    local test_name="${1:-$CURRENT_TEST}"
    local message="${2:-Test failed}"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    echo -e "${RED}[TEST-FAILURE]${NC} ${timestamp} | $test_name: $message" | tee -a "$LOG_DIR/${SUITE_NAME}.log"
}

# Log test end with result
log_test_end() {
    local test_name="${1:-$CURRENT_TEST}"
    local result="$2"
    local duration="${3:-}"
    local timestamp
    timestamp=$(date '+%H:%M:%S')

    local duration_str=""
    if [[ -n "$duration" ]]; then
        duration_str=" (${duration}s)"
    fi

    case "$result" in
        "PASS"|"SUCCESS")
            echo -e "${GREEN}[TEST-END]${NC} ${timestamp} | $test_name: PASSED${duration_str}" | tee -a "$LOG_DIR/${SUITE_NAME}.log"
            ;;
        "FAIL"|"FAILURE")
            echo -e "${RED}[TEST-END]${NC} ${timestamp} | $test_name: FAILED${duration_str}" | tee -a "$LOG_DIR/${SUITE_NAME}.log"
            ;;
        *)
            echo -e "${YELLOW}[TEST-END]${NC} ${timestamp} | $test_name: $result${duration_str}" | tee -a "$LOG_DIR/${SUITE_NAME}.log"
            ;;
    esac
}

# Log formatting functions

# Format test section header
format_test_header() {
    local title="$1"
    local width="${2:-60}"

    echo
    echo -e "${PURPLE}$(printf '=%.0s' $(seq 1 "$width"))${NC}"
    echo -e "${PURPLE}$(printf "%*s" $(((width + ${#title}) / 2)) "$title")${NC}"
    echo -e "${PURPLE}$(printf '=%.0s' $(seq 1 "$width"))${NC}"
    echo
}

# Format test results summary
format_test_results() {
    local total="$1"
    local passed="$2"
    local failed="$3"
    local duration="${4:-Unknown}"

    echo
    echo -e "${BLUE}=== Test Results Summary ===${NC}"
    echo -e "Total Tests: ${total}"
    echo -e "Passed: ${GREEN}${passed}${NC}"
    echo -e "Failed: ${RED}${failed}${NC}"
    echo -e "Duration: ${duration}"

    if [[ $total -gt 0 ]]; then
        local pass_rate=$((passed * 100 / total))
        echo -e "Pass Rate: ${pass_rate}%"
    fi
    echo
}

# Format suite completion summary
format_suite_summary() {
    local suite_name="${1:-$SUITE_NAME}"
    local end_time
    end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local duration=""

    if [[ -n "$SUITE_START_TIME" ]]; then
        duration=$(calculate_suite_duration "$SUITE_START_TIME" "$end_time")
    fi

    echo
    echo -e "${GREEN}=== Suite Completion Summary ===${NC}"
    echo -e "Suite: ${suite_name}"
    echo -e "Start Time: ${SUITE_START_TIME}"
    echo -e "End Time: ${end_time}"
    echo -e "Duration: ${duration}"
    echo -e "Log Directory: ${LOG_DIR}"
    echo
}

# Calculate suite duration
calculate_suite_duration() {
    local start="$1"
    local end="$2"

    local start_epoch
    start_epoch=$(date -d "$start" +%s 2>/dev/null || echo "0")
    local end_epoch
    end_epoch=$(date -d "$end" +%s 2>/dev/null || echo "0")

    if [[ $start_epoch -gt 0 && $end_epoch -gt 0 ]]; then
        local duration=$((end_epoch - start_epoch))
        printf "%02d:%02d:%02d" $((duration/3600)) $((duration%3600/60)) $((duration%60))
    else
        echo "Unknown"
    fi
}

# Enhanced logging with context

# Log with script context - skip wrapper layers to get actual caller
log_with_context() {
    local level="$1"
    local message="$2"
    local script_name="${SCRIPT_NAME:-$(basename "$0")}"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    local context_label="$script_name"

    # Get caller info, skipping wrapper functions in suite-check-helpers.sh
    # BASH_SOURCE[0] = suite-logging.sh (this file)
    # BASH_SOURCE[1] = suite-check-helpers.sh (wrapper like log_test, log_pass, log_fail)
    # BASH_SOURCE[2] = actual caller (the test script)
    local caller_source="${BASH_SOURCE[2]:-${BASH_SOURCE[1]}}"
    local caller_line="${BASH_LINENO[1]}"

    if [[ -n "$caller_source" ]]; then
        local display_source
        display_source="$(basename "$caller_source")"
        if [[ -n "$caller_line" ]]; then
            context_label="${display_source}:L${caller_line}"
        else
            context_label="${display_source}"
        fi
    fi

    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} ${timestamp} | ${context_label} | $message" | tee -a "$LOG_DIR/${script_name}.log"
            ;;
        "WARN"|"WARNING")
            echo -e "${YELLOW}[WARN]${NC} ${timestamp} | ${context_label} | $message" | tee -a "$LOG_DIR/${script_name}.log"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${timestamp} | ${context_label} | $message" | tee -a "$LOG_DIR/${script_name}.log"
            ;;
        "SUCCESS"|"PASS")
            echo -e "${GREEN}[${level}]${NC} ${timestamp} | ${context_label} | $message" | tee -a "$LOG_DIR/${script_name}.log"
            ;;
        "FAIL")
            echo -e "${RED}[${level}]${NC} ${timestamp} | ${context_label} | $message" | tee -a "$LOG_DIR/${script_name}.log"
            ;;
        "TEST")
            echo -e "${CYAN}[${level}]${NC} ${timestamp} | ${context_label} | $message" | tee -a "$LOG_DIR/${script_name}.log"
            ;;
        *)
            echo -e "${BLUE}[${level}]${NC} ${timestamp} | ${context_label} | $message" | tee -a "$LOG_DIR/${script_name}.log"
            ;;
    esac
}

# Log command execution
log_command() {
    local command="$1"
    local description="${2:-Executing command}"

    log_suite_info "$description: $command"
}

# Log command result
log_command_result() {
    local command="$1"
    local exit_code="$2"
    local description="${3:-Command execution}"

    if [[ $exit_code -eq 0 ]]; then
        log_suite_success "$description completed successfully"
    else
        log_suite_error "$description failed with exit code $exit_code"
    fi
}

# Log file operations
log_file_operation() {
    local operation="$1"
    local file_path="$2"
    local result="$3"

    case "$operation" in
        "CREATE"|"WRITE")
            if [[ "$result" == "SUCCESS" ]]; then
                log_suite_success "File created/written: $file_path"
            else
                log_suite_error "Failed to create/write file: $file_path"
            fi
            ;;
        "READ")
            if [[ "$result" == "SUCCESS" ]]; then
                log_suite_success "File read successfully: $file_path"
            else
                log_suite_error "Failed to read file: $file_path"
            fi
            ;;
        "DELETE")
            if [[ "$result" == "SUCCESS" ]]; then
                log_suite_success "File deleted: $file_path"
            else
                log_suite_error "Failed to delete file: $file_path"
            fi
            ;;
        *)
            log_suite_info "File operation $operation on $file_path: $result"
            ;;
    esac
}

# Log network operations
log_network_operation() {
    local operation="$1"
    local target="$2"
    local result="$3"

    case "$operation" in
        "PING")
            if [[ "$result" == "SUCCESS" ]]; then
                log_suite_success "Ping successful to: $target"
            else
                log_suite_error "Ping failed to: $target"
            fi
            ;;
        "SSH")
            if [[ "$result" == "SUCCESS" ]]; then
                log_suite_success "SSH connection successful to: $target"
            else
                log_suite_error "SSH connection failed to: $target"
            fi
            ;;
        "PORT")
            if [[ "$result" == "SUCCESS" ]]; then
                log_suite_success "Port accessible on: $target"
            else
                log_suite_error "Port not accessible on: $target"
            fi
            ;;
        *)
            log_suite_info "Network operation $operation on $target: $result"
            ;;
    esac
}

# Create log summary
create_log_summary() {
    local suite_name="${1:-$SUITE_NAME}"
    local summary_file="$LOG_DIR/${suite_name}-summary.txt"

    {
        echo "Test Suite Log Summary"
        echo "====================="
        echo "Suite: $suite_name"
        echo "Start Time: $SUITE_START_TIME"
        echo "End Time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Duration: $(calculate_suite_duration "$SUITE_START_TIME" "$(date '+%Y-%m-%d %H:%M:%S')")"
        echo "Log Directory: $LOG_DIR"
        echo

        # Count log entries by type
        if [[ -f "$LOG_DIR/${suite_name}.log" ]]; then
            echo "Log Entry Summary:"
            echo "  INFO: $(grep -c "\[SUITE-INFO\]" "$LOG_DIR/${suite_name}.log" 2>/dev/null || echo "0")"
            echo "  SUCCESS: $(grep -c "\[SUITE-SUCCESS\]" "$LOG_DIR/${suite_name}.log" 2>/dev/null || echo "0")"
            echo "  WARNING: $(grep -c "\[SUITE-WARNING\]" "$LOG_DIR/${suite_name}.log" 2>/dev/null || echo "0")"
            echo "  ERROR: $(grep -c "\[SUITE-ERROR\]" "$LOG_DIR/${suite_name}.log" 2>/dev/null || echo "0")"
            echo "  TEST-START: $(grep -c "\[TEST-START\]" "$LOG_DIR/${suite_name}.log" 2>/dev/null || echo "0")"
            echo "  TEST-SUCCESS: $(grep -c "\[TEST-SUCCESS\]" "$LOG_DIR/${suite_name}.log" 2>/dev/null || echo "0")"
            echo "  TEST-FAILURE: $(grep -c "\[TEST-FAILURE\]" "$LOG_DIR/${suite_name}.log" 2>/dev/null || echo "0")"
        fi
    } > "$summary_file"

    log_suite_info "Log summary saved to: $summary_file"
}

# Export functions for use by other scripts
export -f init_suite_logging
export -f log_suite_info
export -f log_suite_success
export -f log_suite_error
export -f log_suite_warning
export -f log_test_start
export -f log_test_success
export -f log_test_failure
export -f log_test_end
export -f format_test_header
export -f format_test_results
export -f format_suite_summary
export -f calculate_suite_duration
export -f log_with_context
export -f log_command
export -f log_command_result
export -f log_file_operation
export -f log_network_operation
export -f create_log_summary

# Export color variables
export RED GREEN YELLOW BLUE PURPLE CYAN NC

# Verify required logging functions are available from log-utils.sh
if ! command -v log_info >/dev/null 2>&1; then
    echo "FATAL: log_info function not available from log-utils.sh" >&2
    echo "FATAL: Required logging function not found in: $LOG_UTILS_FILE" >&2
    exit 1
fi

# Logging functions are now available from sourced log-utils.sh
log_info "Test suite logging utilities loaded from: $LOG_UTILS_FILE"
