#!/bin/bash
#
# SLURM Job Examples: Hello World MPI Job Test
# Tests basic multi-node MPI job execution via SLURM
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
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-check-helpers.sh"

TEST_NAME="Hello World MPI SLURM Job Test"
PROJECT_ROOT="${PROJECT_ROOT:-.}"
TESTS_DIR="${TESTS_DIR:-.}"
BEEGFS_MOUNT="/mnt/beegfs"
JOB_EXAMPLES_DIR="${BEEGFS_MOUNT}/slurm-jobs/hello-world"
BUILD_OUTPUT_DIR="${PROJECT_ROOT}/build/examples/slurm-jobs/hello-world"

# Logging and remote execution provided by suite-check-helpers.sh

# Build hello-world example
build_hello_world() {
    log_info "Building hello-world MPI example..."

    # Check if already built
    if [ -f "$BUILD_OUTPUT_DIR/hello" ]; then
        log_info "✓ hello-world example already built at $BUILD_OUTPUT_DIR/hello"
        return 0
    fi

    # Try to build only if we have access to Docker/Makefile
    if [ -f "$PROJECT_ROOT/Makefile" ]; then
        log_info "Building in Docker container..."
        if ! make -C "$PROJECT_ROOT" run-docker COMMAND="cmake --build build --target build-hello-world"; then
            log_error "Failed to build hello-world example in Docker container"
            return 1
        fi
    else
        log_warn "Makefile not found at $PROJECT_ROOT - skipping build (expecting pre-built artifacts)"
        return 0
    fi

    if [ ! -f "$BUILD_OUTPUT_DIR/hello" ]; then
        log_error "hello executable not found after build"
        return 1
    fi

    log_info "✓ hello-world example built successfully"
    return 0
}

# Copy hello-world to BeeGFS
copy_hello_world_to_beegfs() {
    log_info "Copying hello-world example to BeeGFS..."

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
            log_error "Failed to copy hello-world to controller"
            return 1
        fi
    else
        # Copy locally (for standalone testing)
        if ! mkdir -p "$JOB_EXAMPLES_DIR" || ! cp -r "$BUILD_OUTPUT_DIR"/* "$JOB_EXAMPLES_DIR/" 2>/dev/null; then
            log_error "Failed to copy hello-world to BeeGFS"
            return 1
        fi
    fi

    log_info "✓ hello-world copied to BeeGFS"
    return 0
}

# Submit and monitor hello-world job
submit_hello_world_job() {
    log_info "Submitting hello-world SLURM job..."

    # Submit job via SSH if controller IP is provided
    if [ -n "${CONTROLLER_IP:-}" ] && [ -n "${SSH_KEY_PATH:-}" ]; then
        local submit_cmd="cd $JOB_EXAMPLES_DIR && sbatch --parsable hello.sbatch"
        local job_id

        log_debug "Submitting via SSH to $CONTROLLER_IP..."
        if ! job_id=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
            "${SSH_USER}@${CONTROLLER_IP}" "$submit_cmd" 2>&1); then
            log_error "Failed to submit hello-world job"
            return 1
        fi

        log_info "Job submitted with ID: $job_id"

        # Monitor job until completion
        log_info "Waiting for job to complete (up to 5 minutes)..."
        local timeout=300
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

# Verify job output
verify_hello_world_output() {
    log_info "Verifying hello-world job output..."

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

        # Verify expected output
        if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
            "${SSH_USER}@${CONTROLLER_IP}" \
            "grep -q 'Hello from rank' $output_file && grep -q 'MPI Hello World Summary' $output_file" 2>&1; then
            log_info "✓ Job output contains expected MPI messages"

            # Show excerpt of output
            ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
                "${SSH_USER}@${CONTROLLER_IP}" \
                "echo '=== Job Output Excerpt ===' && head -30 $output_file | tail -20" 2>&1 | sed 's/^/  /'
            return 0
        else
            log_error "Job output does not contain expected MPI messages"
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
    if ! build_hello_world; then
        log_error "Failed to build hello-world example"
        return 1
    fi

    if ! copy_hello_world_to_beegfs; then
        log_error "Failed to copy hello-world to BeeGFS"
        return 1
    fi

    if ! submit_hello_world_job; then
        log_error "Failed to submit hello-world job"
        return 1
    fi

    if ! verify_hello_world_output; then
        log_error "Failed to verify hello-world job output"
        return 1
    fi

    log ""
    log_info "🎉 Hello-world MPI job test passed!"
    log ""
    return 0
}

# Execute main
main "$@"
