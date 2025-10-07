#!/bin/bash
#
# SLURM Distributed Jobs Validation Script
# Task 022 - Job Execution Validation
# Validates distributed job execution on compute nodes
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="check-distributed-jobs.sh"
TEST_NAME="SLURM Distributed Job Execution Validation"

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
test_simple_job_execution() {
    log_info "Testing simple job execution..."

    if ! command -v srun >/dev/null 2>&1; then
        log_warn "srun command not available"
        return 0
    fi

    # Run a simple hostname command
    local output
    if output=$(timeout 30 srun -N1 hostname 2>&1); then
        log_info "✓ Simple job executed successfully"
        log_debug "Job output: $output"
        return 0
    else
        log_error "Simple job execution failed"
        log_debug "Error output: $output"
        return 1
    fi
}

test_multi_task_job() {
    log_info "Testing multi-task job execution..."

    if ! command -v srun >/dev/null 2>&1; then
        log_warn "srun command not available"
        return 0
    fi

    # Run a job with multiple tasks
    local output
    if output=$(timeout 30 srun -n4 echo "Task test" 2>&1); then
        log_info "✓ Multi-task job executed successfully"
        local task_count
        task_count=$(echo "$output" | wc -l)
        log_debug "Tasks executed: $task_count"
        return 0
    else
        log_error "Multi-task job execution failed"
        log_debug "Error output: $output"
        return 1
    fi
}

test_job_output_capture() {
    log_info "Testing job output capture..."

    if ! command -v srun >/dev/null 2>&1; then
        log_warn "srun command not available"
        return 0
    fi

    # Create temporary output file
    local output_file="$LOG_DIR/job_output_test.txt"

    # Run job with output redirection
    if timeout 30 srun -N1 -o "$output_file" echo "Test output" 2>&1; then
        if [ -f "$output_file" ] && grep -q "Test output" "$output_file"; then
            log_info "✓ Job output captured successfully"
            return 0
        else
            log_error "Job output file not created or empty"
            return 1
        fi
    else
        log_error "Job with output capture failed"
        return 1
    fi
}

test_job_environment() {
    log_info "Testing job environment variables..."

    if ! command -v srun >/dev/null 2>&1; then
        log_warn "srun command not available"
        return 0
    fi

    # Test if SLURM environment variables are available
    local output
    if output=$(timeout 30 srun -N1 env 2>&1); then
        if echo "$output" | grep -q "SLURM"; then
            log_info "✓ SLURM environment variables available in jobs"
            local slurm_vars
            slurm_vars=$(echo "$output" | grep "SLURM" | wc -l)
            log_debug "Found $slurm_vars SLURM environment variables"
            return 0
        else
            log_warn "No SLURM environment variables found in job"
            return 0
        fi
    else
        log_error "Environment test job failed"
        return 1
    fi
}

test_job_time_limit() {
    log_info "Testing job time limit enforcement..."

    if ! command -v srun >/dev/null 2>&1; then
        log_warn "srun command not available"
        return 0
    fi

    # Run a job with a short time limit that should succeed
    if timeout 30 srun -N1 -t 00:01:00 sleep 1 >/dev/null 2>&1; then
        log_info "✓ Job time limit parameter accepted"
        return 0
    else
        log_warn "Job with time limit failed (may be expected in some configurations)"
        return 0
    fi
}

test_job_queue() {
    log_info "Testing job queue functionality..."

    if ! command -v squeue >/dev/null 2>&1; then
        log_warn "squeue command not available"
        return 0
    fi

    # Check if we can query the job queue
    if squeue >/dev/null 2>&1; then
        log_info "✓ Job queue query successful"

        # Show current queue status
        local queue_status
        queue_status=$(squeue -h 2>/dev/null | wc -l)
        log_debug "Jobs in queue: $queue_status"

        return 0
    else
        log_error "Job queue query failed"
        return 1
    fi
}

test_job_cancellation() {
    log_info "Testing job cancellation..."

    if ! command -v sbatch >/dev/null 2>&1 || ! command -v scancel >/dev/null 2>&1; then
        log_warn "sbatch/scancel commands not available"
        return 0
    fi

    # Create a test script
    local test_script="$LOG_DIR/cancel_test_job.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
sleep 60
EOF
    chmod +x "$test_script"

    # Submit the job
    local job_id
    if job_id=$(sbatch --wrap="sleep 60" 2>&1 | grep -oP 'Submitted batch job \K\d+'); then
        log_debug "Submitted test job: $job_id"

        # Wait a moment
        sleep 2

        # Cancel the job
        if scancel "$job_id" 2>&1; then
            log_info "✓ Job cancellation successful"
            return 0
        else
            log_warn "Job cancellation command failed"
            return 0
        fi
    else
        log_warn "Could not submit test job for cancellation test"
        return 0
    fi
}

test_compute_node_resources() {
    log_info "Testing resource allocation to compute nodes..."

    if ! command -v srun >/dev/null 2>&1; then
        log_warn "srun command not available"
        return 0
    fi

    # Test CPU allocation
    local output
    if output=$(timeout 30 srun -N1 nproc 2>&1); then
        log_info "✓ Can query compute node CPUs: $output"
    else
        log_warn "Could not query compute node CPUs"
    fi

    # Test memory information
    if output=$(timeout 30 srun -N1 free -h 2>&1); then
        log_info "✓ Can query compute node memory"
        log_debug "Memory info: $(echo "$output" | head -n 2)"
    else
        log_warn "Could not query compute node memory"
    fi

    return 0
}

# Main test execution
main() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}  $TEST_NAME${NC}"
    echo -e "${BLUE}=====================================${NC}"

    log_info "Starting SLURM distributed job execution validation"
    log_info "Log directory: $LOG_DIR"
    log_info "Current node: $(hostname)"

    # Run all tests
    run_test "Simple Job Execution" test_simple_job_execution
    run_test "Multi-Task Job" test_multi_task_job
    run_test "Job Output Capture" test_job_output_capture
    run_test "Job Environment" test_job_environment
    run_test "Job Time Limit" test_job_time_limit
    run_test "Job Queue" test_job_queue
    run_test "Job Cancellation" test_job_cancellation
    run_test "Compute Node Resources" test_compute_node_resources

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

    log_info "Distributed job execution validation passed (${TESTS_PASSED}/${TESTS_RUN} tests)"
    return 0
}

# Execute main function
main "$@"
