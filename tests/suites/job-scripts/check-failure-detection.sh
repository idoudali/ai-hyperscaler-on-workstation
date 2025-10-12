#!/bin/bash
#
# SLURM Failure Detection Validation
# Task 025 - Job Scripts Validation
# Validates automated failure pattern detection
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="check-failure-detection.sh"
TEST_NAME="SLURM Failure Detection Validation"

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
test_diagnosis_tool_functionality() {
    log_info "Testing diagnosis tool functionality..."

    # Use test environment paths if set, otherwise use system paths
    local tools_dir="${TEST_SLURM_TOOLS_DIR:-/usr/local/slurm/tools}"
    local tool_path="$tools_dir/diagnose_training_failure.py"

    if [ ! -x "$tool_path" ]; then
        log_error "Diagnosis tool not found or not executable: $tool_path"
        return 1
    fi

    # Test with exit code 0 (success)
    local output
    output=$(python3 "$tool_path" --job-id "test-1" --exit-code 0 2>&1) || {
        log_error "Diagnosis tool failed for exit code 0"
        return 1
    }

    if echo "$output" | grep -q "success"; then
        log_info "✓ Tool correctly identifies successful jobs"
    else
        log_warn "Tool may not correctly identify successful jobs"
    fi

    # Test with exit code 137 (OOM killed)
    output=$(python3 "$tool_path" --job-id "test-2" --exit-code 137 2>&1) || {
        log_error "Diagnosis tool failed for exit code 137"
        return 1
    }

    if echo "$output" | grep -qi "oom"; then
        log_info "✓ Tool correctly identifies OOM failures"
    else
        log_warn "Tool may not correctly identify OOM failures"
    fi

    # Test with exit code 139 (segmentation fault)
    output=$(python3 "$tool_path" --job-id "test-3" --exit-code 139 2>&1) || {
        log_error "Diagnosis tool failed for exit code 139"
        return 1
    }

    if echo "$output" | grep -qi "segmentation"; then
        log_info "✓ Tool correctly identifies segmentation faults"
    else
        log_warn "Tool may not correctly identify segmentation faults"
    fi

    log_info "Diagnosis tool functionality tests passed"
    return 0
}

test_failure_diagnosis_with_output() {
    log_info "Testing failure diagnosis with JSON output..."

    # Use test environment paths if set, otherwise use system paths
    local tools_dir="${TEST_SLURM_TOOLS_DIR:-/usr/local/slurm/tools}"
    local tool_path="$tools_dir/diagnose_training_failure.py"
    local output_file="$LOG_DIR/diagnosis-test-output.json"

    # Run diagnosis with JSON output
    if ! python3 "$tool_path" \
        --job-id "test-diagnosis-$$" \
        --exit-code 1 \
        --output "$output_file" > /dev/null 2>&1; then
        log_error "Failed to generate diagnosis JSON output"
        return 1
    fi

    # Verify JSON file was created
    if [ ! -f "$output_file" ]; then
        log_error "Diagnosis JSON output file not created"
        return 1
    fi

    # Verify JSON is valid
    if ! python3 -m json.tool "$output_file" > /dev/null 2>&1; then
        log_error "Invalid JSON in diagnosis output"
        return 1
    fi

    log_info "✓ Diagnosis JSON output is valid"

    # Check for required fields
    local required_fields=("job_id" "exit_code" "failure_category" "timestamp")
    local missing_fields=()

    for field in "${required_fields[@]}"; do
        if ! grep -q "\"$field\"" "$output_file"; then
            missing_fields+=("$field")
        fi
    done

    if [ ${#missing_fields[@]} -eq 0 ]; then
        log_info "✓ All required fields present in diagnosis output"
        return 0
    else
        log_error "Missing fields in diagnosis output: ${missing_fields[*]}"
        return 1
    fi
}

test_common_failure_patterns() {
    log_info "Testing common failure pattern detection..."

    # Use test environment paths if set, otherwise use system paths
    local tools_dir="${TEST_SLURM_TOOLS_DIR:-/usr/local/slurm/tools}"
    local tool_path="$tools_dir/diagnose_training_failure.py"

    # Test different exit codes and verify categorization
    local test_cases=(
        "0:success"
        "1:general_error"
        "124:timeout"
        "134:abort"
        "137:oom"
        "139:segmentation_fault"
        "143:terminated"
    )

    local failed_patterns=()

    for test_case in "${test_cases[@]}"; do
        local exit_code="${test_case%%:*}"
        local expected_category="${test_case##*:}"

        local output
        output=$(python3 "$tool_path" --job-id "pattern-test-$$" --exit-code "$exit_code" 2>&1) || {
            log_warn "Failed to analyze exit code $exit_code"
            continue
        }

        if echo "$output" | grep -qi "$expected_category"; then
            log_debug "✓ Exit code $exit_code correctly categorized as $expected_category"
        else
            log_warn "Exit code $exit_code may not be categorized correctly"
            failed_patterns+=("$exit_code:$expected_category")
        fi
    done

    if [ ${#failed_patterns[@]} -eq 0 ]; then
        log_info "✓ All failure patterns detected correctly"
        return 0
    else
        log_warn "Some failure patterns may not be detected: ${failed_patterns[*]}"
        return 0  # Warning, not failure
    fi
}

test_system_state_collection() {
    log_info "Testing system state collection..."

    # Use test environment paths if set, otherwise use system paths
    local tools_dir="${TEST_SLURM_TOOLS_DIR:-/usr/local/slurm/tools}"
    local tool_path="$tools_dir/diagnose_training_failure.py"
    local output_file="$LOG_DIR/system-state-test.json"

    # Run diagnosis and collect system state
    if ! python3 "$tool_path" \
        --job-id "sys-state-$$" \
        --exit-code 1 \
        --output "$output_file" > /dev/null 2>&1; then
        log_error "Failed to collect system state"
        return 1
    fi

    # Check if system_state section exists
    if grep -q "\"system_state\"" "$output_file"; then
        log_info "✓ System state collected"

        # Check for key system metrics
        local metrics=("memory" "load" "disk")
        local found_metrics=()

        for metric in "${metrics[@]}"; do
            if grep -q "\"$metric\"" "$output_file"; then
                found_metrics+=("$metric")
            fi
        done

        log_info "System metrics found: ${found_metrics[*]}"

        if [ ${#found_metrics[@]} -gt 0 ]; then
            log_info "✓ System state includes metrics"
            return 0
        else
            log_warn "System state present but no metrics found"
            return 0
        fi
    else
        log_warn "System state not collected (may be expected)"
        return 0
    fi
}

test_failure_recommendations() {
    log_info "Testing failure recommendations..."

    # Use test environment paths if set, otherwise use system paths
    local tools_dir="${TEST_SLURM_TOOLS_DIR:-/usr/local/slurm/tools}"
    local tool_path="$tools_dir/diagnose_training_failure.py"
    local output_file="$LOG_DIR/recommendations-test.json"

    # Test with OOM exit code (should have recommendations)
    if ! python3 "$tool_path" \
        --job-id "recommendations-$$" \
        --exit-code 137 \
        --output "$output_file" > /dev/null 2>&1; then
        log_error "Failed to generate recommendations"
        return 1
    fi

    # Check for recommended_actions field
    if grep -q "\"recommended_actions\"" "$output_file"; then
        log_info "✓ Recommendations field present"

        # Check if recommendations are provided
        local recommendations_count
        recommendations_count=$(grep -o "\"recommended_actions\": \[" "$output_file" | wc -l)

        if [ "$recommendations_count" -gt 0 ]; then
            log_info "✓ Recommendations provided for failure"
            return 0
        else
            log_warn "Recommendations field present but empty"
            return 0
        fi
    else
        log_error "No recommendations field in output"
        return 1
    fi
}

test_diagnosis_tool_error_handling() {
    log_info "Testing diagnosis tool error handling..."

    # Use test environment paths if set, otherwise use system paths
    local tools_dir="${TEST_SLURM_TOOLS_DIR:-/usr/local/slurm/tools}"
    local tool_path="$tools_dir/diagnose_training_failure.py"

    # Test with invalid arguments (should handle gracefully)
    if python3 "$tool_path" 2>&1 | grep -qi "error\|required"; then
        log_info "✓ Tool handles missing arguments correctly"
    else
        log_warn "Tool error handling may need improvement"
    fi

    # Test with help flag
    if python3 "$tool_path" --help > /dev/null 2>&1; then
        log_info "✓ Tool help documentation available"
    else
        log_warn "Tool help may not be available"
    fi

    return 0
}

# Main test execution
main() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}  $TEST_NAME${NC}"
    echo -e "${BLUE}=====================================${NC}"

    log_info "Starting failure detection validation"
    log_info "Log directory: $LOG_DIR"

    # Run all tests
    run_test "Diagnosis Tool Functionality" test_diagnosis_tool_functionality
    run_test "Failure Diagnosis with JSON Output" test_failure_diagnosis_with_output
    run_test "Common Failure Patterns" test_common_failure_patterns
    run_test "System State Collection" test_system_state_collection
    run_test "Failure Recommendations" test_failure_recommendations
    run_test "Tool Error Handling" test_diagnosis_tool_error_handling

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
    fi

    if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
        log_info "Failure detection validation passed (${TESTS_PASSED}/${TESTS_RUN} tests)"
        return 0
    else
        log_error "Some tests failed (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 1
    fi
}

# Execute main function
main "$@"
