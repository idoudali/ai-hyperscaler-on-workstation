#!/bin/bash
#
# SLURM Job Examples: Pi Calculation Monte Carlo Test
# Tests computational parallelism and result accuracy
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"

# Note: Logging functions now provided by suite-logging.sh

TEST_NAME="Pi Calculation Monte Carlo SLURM Job Test"
PROJECT_ROOT="${PROJECT_ROOT:-.}"
TESTS_DIR="${TESTS_DIR:-.}"
BEEGFS_MOUNT="/mnt/beegfs"
JOB_EXAMPLES_DIR="${BEEGFS_MOUNT}/slurm-jobs/pi-calculation"
BUILD_OUTPUT_DIR="${PROJECT_ROOT}/build/examples/slurm-jobs/pi-calculation"

# Check if running via SSH (remote mode)
check_remote_mode() {
    if [ "${TEST_MODE:-local}" = "remote" ] && [ -n "${CONTROLLER_IP:-}" ]; then
        return 0
    fi
    return 1
}

# Execute command on controller via SSH
run_ssh() {
    local cmd="$1"
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "${SSH_USER}@${CONTROLLER_IP}" "$cmd"
}

# Build pi-calculation example
build_pi_calculation() {
    log_info "Building pi-calculation Monte Carlo example..."

    # Check if already built
    if [ -f "$BUILD_OUTPUT_DIR/pi-monte-carlo" ]; then
        log_info "✓ pi-calculation example already built at $BUILD_OUTPUT_DIR/pi-monte-carlo"
        return 0
    fi

    # Try to build only if we have access to Docker/Makefile
    if [ -f "$PROJECT_ROOT/Makefile" ]; then
        log_info "Building in Docker container..."
        if ! make -C "$PROJECT_ROOT" run-docker COMMAND="cmake --build build --target build-pi-calculation"; then
            log_error "Failed to build pi-calculation example in Docker container"
            return 1
        fi
    else
        log_warn "Makefile not found at $PROJECT_ROOT - skipping build (expecting pre-built artifacts)"
        return 0
    fi

    if [ ! -f "$BUILD_OUTPUT_DIR/pi-monte-carlo" ]; then
        log_error "pi-monte-carlo executable not found after build"
        return 1
    fi

    log_info "✓ pi-calculation example built successfully"
    return 0
}

# Copy pi-calculation to BeeGFS
copy_pi_calculation_to_beegfs() {
    log_info "Copying pi-calculation example to BeeGFS..."

    if [ ! -d "$BUILD_OUTPUT_DIR" ]; then
        log_error "Build output directory not found: $BUILD_OUTPUT_DIR"
        return 1
    fi

    # Skip if no binaries to copy
    if ! ls "$BUILD_OUTPUT_DIR"/* >/dev/null 2>&1; then
        log_error "No files to copy from $BUILD_OUTPUT_DIR (build incomplete)"
        return 1
    fi

    # For remote mode, copy via SCP to controller
    if [ -n "${CONTROLLER_IP:-}" ] && [ -n "${SSH_KEY_PATH:-}" ]; then
        log_debug "Copying to controller ($CONTROLLER_IP) via SCP..."

        # Ensure directory exists on controller
        if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
            "${SSH_USER}@${CONTROLLER_IP}" "mkdir -p $JOB_EXAMPLES_DIR" 2>/dev/null; then
            log_error "Failed to create BeeGFS directory on controller"
            return 1
        fi

        if ! scp -i "$SSH_KEY_PATH" -r -o StrictHostKeyChecking=no \
            "$BUILD_OUTPUT_DIR"/* \
            "${SSH_USER}@${CONTROLLER_IP}:${JOB_EXAMPLES_DIR}/" 2>/dev/null; then
            log_error "Failed to copy pi-calculation to controller"
            return 1
        fi
    else
        # Copy locally (for standalone testing)
        if ! mkdir -p "$JOB_EXAMPLES_DIR" || ! cp -r "$BUILD_OUTPUT_DIR"/* "$JOB_EXAMPLES_DIR/" 2>/dev/null; then
            log_error "Failed to copy pi-calculation to BeeGFS"
            return 1
        fi
    fi

    log_info "✓ pi-calculation copied to BeeGFS"
    return 0
}

# Submit and monitor pi-calculation job
submit_pi_calculation_job() {
    log_info "Submitting pi-calculation SLURM job..."

    # Submit job via SSH if controller IP is provided
    if [ -n "${CONTROLLER_IP:-}" ] && [ -n "${SSH_KEY_PATH:-}" ]; then
        # Use smaller sample size for testing (10 million instead of 100 million)
        local submit_cmd="cd $JOB_EXAMPLES_DIR && sbatch --export=ALL,NUM_SAMPLES=10000000 --parsable pi.sbatch"
        local job_id

        log_debug "Submitting via SSH to $CONTROLLER_IP..."
        if ! job_id=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
            "${SSH_USER}@${CONTROLLER_IP}" "$submit_cmd" 2>&1); then
            log_error "Failed to submit pi-calculation job"
            return 1
        fi

        log_info "Job submitted with ID: $job_id"

        # Monitor job until completion
        log_info "Waiting for job to complete (up to 10 minutes)..."
        local timeout=600
        local elapsed=0
        local poll_interval=5

        while [ $elapsed -lt $timeout ]; do
            local job_status
            if ! job_status=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
                "${SSH_USER}@${CONTROLLER_IP}" "squeue -j $job_id -h 2>/dev/null || echo 'COMPLETED'"); then
                log_debug "Job completed or error checking status"
                break
            fi

            if [ -z "$job_status" ]; then
                log_debug "Job $job_id completed"
                break
            fi

            log_debug "Job status: $job_status"
            sleep $poll_interval
            elapsed=$((elapsed + poll_interval))
        done

        if [ $elapsed -ge $timeout ]; then
            log_error "Job timeout after ${timeout}s"
            return 1
        fi

        # Check job exit code
        local exit_code
        if exit_code=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
            "${SSH_USER}@${CONTROLLER_IP}" "sacct -j $job_id --format=ExitCode -n | head -1" 2>&1); then
            log_info "Job exit code: $exit_code"
        fi

        return 0
    else
        log_error "CONTROLLER_IP and SSH_KEY_PATH not set - cannot submit job via SSH"
        return 1
    fi
}

# Verify job output and accuracy
verify_pi_calculation_output() {
    log_info "Verifying pi-calculation job output and accuracy..."

    # Verify output via SSH if controller IP is provided
    if [ -n "${CONTROLLER_IP:-}" ] && [ -n "${SSH_KEY_PATH:-}" ]; then
        # Check for output files
        local output_file
        if ! output_file=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
            "${SSH_USER}@${CONTROLLER_IP}" "ls -1 $JOB_EXAMPLES_DIR/slurm-*.out 2>/dev/null | head -1" 2>&1); then
            log_error "No job output files found"
            return 1
        fi

        log_debug "Output file: $output_file"

        # Extract pi estimate from output
        local pi_estimate
        if ! pi_estimate=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
            "${SSH_USER}@${CONTROLLER_IP}" "grep 'Pi estimate' $output_file | head -1 | awk '{print \$NF}'" 2>&1); then
            log_error "Could not extract pi estimate from output"
            return 1
        fi

        log_info "Estimated pi value: $pi_estimate"

        # Verify output contains expected elements
        if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
            "${SSH_USER}@${CONTROLLER_IP}" \
            "grep -q 'Parallel Monte Carlo Pi Estimation' $output_file && grep -q 'Points inside circle' $output_file" 2>&1; then
            log_info "✓ Job output contains expected calculation results"

            # Show excerpt of output
            ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
                "${SSH_USER}@${CONTROLLER_IP}" \
                "echo '=== Pi Calculation Output Excerpt ===' && grep -A 5 'Results' $output_file | head -10" 2>&1 | sed 's/^/  /'
            return 0
        else
            log_error "Job output does not contain expected results"
            # Show output for debugging
            ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
                "${SSH_USER}@${CONTROLLER_IP}" \
                "cat $output_file | head -50" 2>&1 | sed 's/^/  /'
            return 1
        fi
    else
        log_error "CONTROLLER_IP and SSH_KEY_PATH not set - cannot verify output"
        return 1
    fi
}

# Main test execution
main() {
    log ""
    log "${BLUE}=====================================${NC}"
    log "${BLUE}  $TEST_NAME${NC}"
    log "${BLUE}=====================================${NC}"
    log ""

    # Determine if running in remote or local mode
    if [ "${TEST_MODE:-local}" = "remote" ]; then
        if [ -z "${CONTROLLER_IP:-}" ] || [ -z "${SSH_KEY_PATH:-}" ] || [ -z "${SSH_USER:-}" ]; then
            log_error "Remote mode requires CONTROLLER_IP, SSH_KEY_PATH, and SSH_USER"
            exit 1
        fi
        log_info "Operating in remote mode: $CONTROLLER_IP"
    else
        log_info "Operating in local mode"
    fi

    log ""

    # Run tests in sequence
    if ! build_pi_calculation; then
        log_error "Failed to build pi-calculation example"
        return 1
    fi

    if ! copy_pi_calculation_to_beegfs; then
        log_error "Failed to copy pi-calculation to BeeGFS"
        return 1
    fi

    if ! submit_pi_calculation_job; then
        log_error "Failed to submit pi-calculation job"
        return 1
    fi

    if ! verify_pi_calculation_output; then
        log_error "Failed to verify pi-calculation job output"
        return 1
    fi

    log ""
    log_info "🎉 Pi-calculation Monte Carlo job test passed!"
    log ""
    return 0
}

# Execute main
main "$@"
