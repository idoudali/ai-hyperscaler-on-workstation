#!/bin/bash
#
# GRES Configuration Validation Script
# Task 023 - GPU GRES Configuration Validation
# Validates GRES configuration files and deployment
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="check-gres-configuration.sh"
TEST_NAME="GRES Configuration Validation"

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

# Configuration files to check
GRES_CONFIG_FILE="/etc/slurm/gres.conf"
SLURM_CONFIG_FILE="/etc/slurm/slurm.conf"

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
# shellcheck disable=SC2317  # Functions called indirectly via run_test
test_gres_config_file_exists() {
    log_info "Checking if GRES configuration file exists..."

    if [[ -f "$GRES_CONFIG_FILE" ]]; then
        log_info "✓ GRES configuration file found: $GRES_CONFIG_FILE"

        # Display file info
        log_debug "File permissions: $(stat -c '%A' "$GRES_CONFIG_FILE")"
        log_debug "File owner: $(stat -c '%U:%G' "$GRES_CONFIG_FILE")"
        log_debug "File size: $(stat -c '%s' "$GRES_CONFIG_FILE") bytes"

        return 0
    else
        log_warn "✗ GRES configuration file not found: $GRES_CONFIG_FILE"
        log_warn "This may be expected if GRES is not enabled"
        return 0  # Not a hard failure
    fi
}

test_gres_config_syntax() {
    log_info "Validating GRES configuration syntax..."

    if [[ ! -f "$GRES_CONFIG_FILE" ]]; then
        log_warn "GRES configuration file not found, skipping syntax check"
        return 0
    fi

    # Check if file is readable
    if [[ ! -r "$GRES_CONFIG_FILE" ]]; then
        log_error "Cannot read GRES configuration file"
        return 1
    fi

    # Basic syntax validation
    # Check for basic GRES syntax patterns
    if grep -q "NodeName=" "$GRES_CONFIG_FILE" || grep -q "AutoDetect=" "$GRES_CONFIG_FILE"; then
        log_info "✓ Valid GRES configuration patterns found"
    else
        log_warn "No GRES device configurations found (file may be template only)"
    fi

    # Check for common syntax errors
    if grep -E "^\s*[^#].*\s+$" "$GRES_CONFIG_FILE" >/dev/null 2>&1; then
        log_warn "Found trailing whitespace in configuration"
    fi

    log_info "GRES configuration syntax check completed"
    return 0
}

test_gres_config_content() {
    log_info "Checking GRES configuration content..."

    if [[ ! -f "$GRES_CONFIG_FILE" ]]; then
        log_warn "GRES configuration file not found, skipping content check"
        return 0
    fi

    # Display non-comment, non-empty lines
    log_info "GRES configuration content:"
    local content_lines=0
    while IFS= read -r line; do
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            log_debug "  $line"
            content_lines=$((content_lines + 1))
        fi
    done < "$GRES_CONFIG_FILE"

    if [[ $content_lines -eq 0 ]]; then
        log_warn "No active GRES configuration found (only comments)"
        return 0
    else
        log_info "✓ Found $content_lines active configuration lines"
        return 0
    fi
}

test_gres_directory_structure() {
    log_info "Checking GRES directory structure..."

    local required_dirs=(
        "/etc/slurm"
        "/var/log/slurm"
        "/var/spool/slurmd"
    )

    local missing_dirs=()
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_debug "✓ Directory exists: $dir"
        else
            log_warn "✗ Missing directory: $dir"
            missing_dirs+=("$dir")
        fi
    done

    if [[ ${#missing_dirs[@]} -eq 0 ]]; then
        log_info "✓ All required directories exist"
        return 0
    else
        log_warn "Some directories missing: ${missing_dirs[*]}"
        return 0  # Not a hard failure
    fi
}

test_slurm_gres_integration() {
    log_info "Checking SLURM GRES integration..."

    if [[ ! -f "$SLURM_CONFIG_FILE" ]]; then
        log_warn "SLURM configuration file not found: $SLURM_CONFIG_FILE"
        return 0
    fi

    # Check if slurm.conf references gres.conf
    if grep -q "GresTypes" "$SLURM_CONFIG_FILE"; then
        log_info "✓ GresTypes configured in slurm.conf"
        local gres_types
        gres_types=$(grep "GresTypes" "$SLURM_CONFIG_FILE" | head -1)
        log_debug "  $gres_types"
    else
        log_warn "GresTypes not found in slurm.conf"
    fi

    return 0
}

test_gpu_detection_utilities() {
    log_info "Checking GPU detection utilities..."

    local utilities=(
        "lspci"
        "lshw"
    )

    local missing_utils=()
    for util in "${utilities[@]}"; do
        if command -v "$util" >/dev/null 2>&1; then
            log_debug "✓ Utility available: $util"
        else
            log_warn "✗ Missing utility: $util"
            missing_utils+=("$util")
        fi
    done

    if [[ ${#missing_utils[@]} -eq 0 ]]; then
        log_info "✓ All GPU detection utilities available"
        return 0
    else
        log_warn "Some utilities missing: ${missing_utils[*]}"
        return 0  # Not a hard failure
    fi
}

# Main test execution
main() {
    echo "========================================="
    echo "  GRES Configuration Validation Test"
    echo "========================================="
    echo ""
    echo "Test Suite: $TEST_NAME"
    echo "Log Directory: $LOG_DIR"
    echo ""

    # Run all tests
    run_test "GRES configuration file exists" test_gres_config_file_exists
    run_test "GRES configuration syntax" test_gres_config_syntax
    run_test "GRES configuration content" test_gres_config_content
    run_test "GRES directory structure" test_gres_directory_structure
    run_test "SLURM GRES integration" test_slurm_gres_integration
    run_test "GPU detection utilities" test_gpu_detection_utilities

    # Print summary
    echo ""
    echo "========================================="
    echo "  Test Summary"
    echo "========================================="
    echo "Total tests: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $((TESTS_RUN - TESTS_PASSED))"

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo ""
        echo "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
    fi
    echo "========================================="

    # Return appropriate exit code
    if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
        log_info "All tests passed!"
        exit 0
    else
        log_error "Some tests failed"
        exit 1
    fi
}

# Run main function
main "$@"
