#!/bin/bash
#
# Log Utilities for Test Framework
# Shared logging functionality between test suites
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global log directory - must be set by calling script
# Default fallback to avoid /tmp usage per project memory
: "${LOG_DIR:=$(pwd)/logs/test-run-$(date '+%Y-%m-%d_%H-%M-%S')}"

# Ensure LOG_DIR exists
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Helper function to get caller information
_get_caller_info() {
    local caller_source="${BASH_SOURCE[2]:-${BASH_SOURCE[1]}}"
    local caller_line="${BASH_LINENO[1]}"
    local caller_func="${FUNCNAME[2]}"

    if [[ -n "$caller_source" ]]; then
        if command -v realpath >/dev/null 2>&1; then
            caller_source="$(realpath "$caller_source" 2>/dev/null || echo "$caller_source")"
        else
            local caller_dir
            caller_dir="$(cd "$(dirname "$caller_source")" 2>/dev/null && pwd)"
            if [[ -n "$caller_dir" ]]; then
                caller_source="${caller_dir}/$(basename "$caller_source")"
            fi
        fi
    fi

    local display_source
    if [[ -n "$caller_source" ]]; then
        display_source="$(basename "$caller_source")"
    else
        display_source="<unknown>"
    fi

    # Handle main script calls (no function name)
    if [[ "$caller_func" == "main" ]] || [[ -z "$caller_func" ]]; then
        caller_func="<main>"
    fi

    echo "${display_source}:${caller_line}:${caller_func}"
}

# Logging functions - All output to stderr to avoid contaminating stdout with log messages
# This ensures functions that return values via echo/stdout are not affected by logging output

log() {
    local caller_info
    caller_info=$(_get_caller_info)
    {
        echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [${caller_info}]${NC} $*"
        echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [${caller_info}] $*" >> "$LOG_DIR/framework.log"
    } >&2
}

log_success() {
    local caller_info
    caller_info=$(_get_caller_info)
    {
        echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [${caller_info}] ✓${NC} $*"
        echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [${caller_info}] ✓ $*" >> "$LOG_DIR/framework.log"
    } >&2
}

log_warning() {
    local caller_info
    caller_info=$(_get_caller_info)
    {
        echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [${caller_info}] ⚠${NC} $*"
        echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [${caller_info}] ⚠ $*" >> "$LOG_DIR/framework.log"
    } >&2
}

log_error() {
    local caller_info
    caller_info=$(_get_caller_info)
    {
        echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [${caller_info}] ✗${NC} $*"
        echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [${caller_info}] ✗ $*" >> "$LOG_DIR/framework.log"
    } >&2
}

log_info() {
    local caller_info
    caller_info=$(_get_caller_info)
    {
        echo -e "${GREEN}[INFO] [${caller_info}]${NC} $1"
        echo -e "[INFO] [${caller_info}] $1" >> "$LOG_DIR/framework.log"
    } >&2
}

log_warn() {
    local caller_info
    caller_info=$(_get_caller_info)
    {
        echo -e "${YELLOW}[WARN] [${caller_info}]${NC} $1"
        echo -e "[WARN] [${caller_info}] $1" >> "$LOG_DIR/framework.log"
    } >&2
}

log_verbose() {
    if [[ "${VERBOSE_MODE:-false}" == "true" ]]; then
        local caller_info
        caller_info=$(_get_caller_info)
        {
            echo -e "${GREEN}[VERBOSE] [${caller_info}]${NC} $1"
            echo -e "[VERBOSE] [${caller_info}] $1" >> "$LOG_DIR/framework.log"
        } >&2
    fi
}

# Debug logging - always goes to stderr
log_debug() {
    local caller_info
    caller_info=$(_get_caller_info)
    {
        echo -e "${BLUE}[DEBUG] [${caller_info}]${NC} $*"
        echo -e "[DEBUG] [${caller_info}] $*" >> "$LOG_DIR/framework.log"
    } >&2
}

# Initialize log directory and basic logging
init_logging() {
    local run_timestamp="${1:-$(date '+%Y-%m-%d_%H-%M-%S')}"
    local log_base_dir="${2:-logs}"
    local test_name="${3:-test}"

    # Override LOG_DIR if not set or create subdirectory
    if [[ -z "${LOG_DIR_SET:-}" ]]; then
        LOG_DIR="$(pwd)/$log_base_dir/${test_name}-test-run-$run_timestamp"
        export LOG_DIR_SET=true
    fi

    mkdir -p "$LOG_DIR" || {
        echo "Error: Failed to create log directory: $LOG_DIR" >&2
        return 1
    }

    # Create log file with initial entry
    {
        echo "# Test Framework Log"
        echo "# Started: $(date)"
        echo "# Log Directory: $LOG_DIR"
        echo "# Working Directory: $(pwd)"
        echo ""
    } > "$LOG_DIR/framework.log"

    log "Logging initialized: $LOG_DIR"
}

# Save command output to log file
log_command() {
    local log_file="$1"
    shift
    local cmd="$*"

    log "Executing: $cmd"
    {
        echo "=== Command: $cmd ==="
        echo "=== Started: $(date) ==="
        echo
    } >> "$LOG_DIR/$log_file"

    # Execute command and capture both stdout/stderr and exit code
    if "$@" >> "$LOG_DIR/$log_file" 2>&1; then
        {
            echo
            echo "=== Completed: $(date) ==="
            echo "=== Exit Code: 0 ==="
            echo
        } >> "$LOG_DIR/$log_file"
        return 0
    else
        local exit_code=$?
        {
            echo
            echo "=== Failed: $(date) ==="
            echo "=== Exit Code: $exit_code ==="
            echo
        } >> "$LOG_DIR/$log_file"
        return $exit_code
    fi
}

# Log test results in structured format
log_test_result() {
    local test_name="$1"
    local status="$2"
    local details="${3:-}"

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local results_file="$LOG_DIR/test-results.json"

    # Create results file if it doesn't exist
    if [[ ! -f "$results_file" ]]; then
        echo '{"test_results": [], "summary": {"total": 0, "passed": 0, "failed": 0}}' > "$results_file"
    fi

    # Add test result (simplified JSON append)
    local result_entry="{\"name\": \"$test_name\", \"status\": \"$status\", \"timestamp\": \"$timestamp\""
    if [[ -n "$details" ]]; then
        result_entry+=", \"details\": \"$details\""
    fi
    result_entry+="}"

    # Append to results file (simple approach)
    {
        echo "Test Result: $test_name = $status ($timestamp)"
        if [[ -n "$details" ]]; then
            echo "  Details: $details"
        fi
    } >> "$LOG_DIR/test-results.log"
}

# Create comprehensive log summary
create_log_summary() {
    local summary_file="$LOG_DIR/summary.txt"

    {
        echo "# Test Framework Run Summary"
        echo "# Generated: $(date)"
        echo "# Log Directory: $LOG_DIR"
        echo ""

        echo "## Log Files Created:"
        find "$LOG_DIR" -name "*.log" -type f | sort | while read -r logfile; do
            local filename
            local size
            filename=$(basename "$logfile")
            size=$(stat -c%s "$logfile" 2>/dev/null || echo "0")
            echo "  - $filename (${size} bytes)"
        done

        echo ""
        echo "## Test Results:"
        if [[ -f "$LOG_DIR/test-results.log" ]]; then
            cat "$LOG_DIR/test-results.log"
        else
            echo "  No test results recorded"
        fi

        echo ""
        echo "## Framework Log (last 50 lines):"
        if [[ -f "$LOG_DIR/framework.log" ]]; then
            tail -50 "$LOG_DIR/framework.log"
        else
            echo "  No framework log available"
        fi

    } > "$summary_file"

    log_success "Log summary created: $summary_file"
}

# Configure logging level for test frameworks
# Sets environment variables that control log output verbosity
configure_logging_level() {
    local level="${1:-normal}"

    case "$level" in
        quiet)
            export VERBOSE_MODE=false
            export LOG_LEVEL_QUIET=true
            log_info "Logging level: QUIET (errors and critical messages only)"
            ;;
        normal)
            export VERBOSE_MODE=false
            export LOG_LEVEL_QUIET=false
            log_verbose "Logging level: NORMAL (standard output)"
            ;;
        verbose)
            export VERBOSE_MODE=true
            export LOG_LEVEL_QUIET=false
            log_verbose "Logging level: VERBOSE (detailed output)"
            ;;
        debug)
            export VERBOSE_MODE=true
            export LOG_LEVEL_QUIET=false
            set -x  # Enable bash debug mode
            log_verbose "Logging level: DEBUG (maximum verbosity with trace)"
            ;;
        *)
            log_warning "Unknown log level: $level, using 'normal'"
            export VERBOSE_MODE=false
            export LOG_LEVEL_QUIET=false
            ;;
    esac

    # Export the current log level for reference
    export LOG_LEVEL="$level"
}

# Export functions for use in other scripts
export -f _get_caller_info
export -f log log_success log_warning log_error log_info log_warn log_verbose log_debug
export -f init_logging log_command log_test_result create_log_summary
export -f configure_logging_level
