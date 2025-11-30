#!/usr/bin/env bash
#
# Training Test Helper Functions
# Used for distributed training validation tests
#

# Load container helpers
if [ -f "$(dirname "${BASH_SOURCE[0]}")/container-helpers.bash" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/container-helpers.bash"
fi

# Container path
CONTAINER="${CONTAINER:-/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif}"

# Skip test if training script not found
skip_if_no_training_script() {
    local script_path="${1:-/mnt/beegfs/training/scripts/mnist_ddp.py}"
    if [ ! -f "$script_path" ]; then
        skip "Training script not found: $script_path"
    fi
}

# Skip test if data directory not accessible
skip_if_no_data_dir() {
    local data_dir="${1:-/mnt/beegfs/data/mnist}"
    if [ ! -d "$data_dir" ]; then
        skip "Data directory not found: $data_dir"
    fi
}

# Submit MNIST DDP job and return job ID
submit_mnist_job() {
    # Default to .sbatch extension now
    local sbatch_file="${1:-/mnt/beegfs/jobs/mnist-ddp.sbatch}"
    local job_name_suffix="${2:-}"
    local test_output_dir="${3:-}"
    local job_id

    if [ ! -f "$sbatch_file" ]; then
        echo "ERROR: SLURM script not found: $sbatch_file" >&2
        return 1
    fi

    # Dynamic Memory Configuration
    # Query SLURM for node memory to avoid "Memory specification can not be satisfied" errors
    # sinfo -o "%m" returns memory in MB
    local node_mem_mb
    node_mem_mb=$(sinfo --noheader -o "%m" 2>/dev/null | head -n1 | tr -d ' ')

    # Use array to properly handle multiple arguments
    local extra_args=()
    if [ -n "$node_mem_mb" ] && [ "$node_mem_mb" -gt 0 ]; then
        # Use 90% of available memory to be safe (leave room for overhead)
        # Bash arithmetic only does integers
        local req_mem=$(( node_mem_mb * 90 / 100 ))
        extra_args+=(--mem="${req_mem}M")
    else
        echo "WARN: Could not detect node memory. Falling back to script defaults." >&2
    fi

    # Handle output directory structure
    if [ -n "$test_output_dir" ]; then
        # Create structure:
        # /mnt/beegfs/tests/<test_id>/
        #   ├── slurm/
        #   ├── training-logs/
        #   └── monitoring-logs/
        mkdir -p "$test_output_dir/slurm"
        mkdir -p "$test_output_dir/training-logs"
        mkdir -p "$test_output_dir/monitoring-logs"

        # Point SLURM output to slurm/ subdirectory
        extra_args+=(--output="$test_output_dir/slurm/${job_name_suffix}-%j.out")
        extra_args+=(--error="$test_output_dir/slurm/${job_name_suffix}-%j.err")

        # Export env var for the sbatch script to pick up
        export TEST_OUTPUT_DIR="$test_output_dir"
    elif [ -n "$job_name_suffix" ]; then
        # Legacy/Fallback behavior
        extra_args+=(--output="${job_name_suffix}-%j.out")
        extra_args+=(--error="${job_name_suffix}-%j.err")
    fi

    # Debug: Print sbatch file content before submission (only if debug flag is set)
    # This prevents leaking secrets in CI logs
    if [ -n "${TRAINING_HELPERS_DEBUG:-}" ]; then
        echo "DEBUG: Submitting job script: $sbatch_file" >&2
        echo "DEBUG: Script content:" >&2
        cat "$sbatch_file" >&2
        echo "DEBUG: End script content" >&2
    fi

    # Submit with dynamic memory request override
    # Use array expansion to properly pass multiple arguments
    if job_id=$(sbatch --parsable "${extra_args[@]}" "$sbatch_file" 2>&1) && [ -n "$job_id" ]; then
        # Validate that job_id is numeric (sbatch --parsable returns just ID usually)
        if [[ "$job_id" =~ ^[0-9]+$ ]]; then
            echo "$job_id"
            return 0
        else
            echo "ERROR: Invalid job ID returned by sbatch: $job_id" >&2
            return 1
        fi
    else
        echo "ERROR: Job submission failed: $job_id" >&2
        # Debug: check node status on failure
        if [ -n "${TRAINING_HELPERS_DEBUG:-}" ]; then
            echo "DEBUG: Node status (sinfo):" >&2
            sinfo >&2
            echo "DEBUG: Node details (scontrol show node):" >&2
            scontrol show node >&2
        fi
        return 1
    fi
}

# Wait for job completion with timeout
wait_for_job() {
    local job_id="$1"
    local timeout="${2:-600}"  # Default 10 minutes
    local elapsed=0
    local interval=10

    if [ -z "$job_id" ]; then
        echo "ERROR: Job ID required" >&2
        return 1
    fi

    while [ $elapsed -lt "$timeout" ]; do
        local job_state
        job_state=$(squeue -j "$job_id" -h -o "%T" 2>/dev/null || echo "COMPLETED")

        # Job is considered completed if squeue returns empty (removed from queue)
        # or if it reports "COMPLETED" state
        if [ -z "$job_state" ] || [ "$job_state" = "COMPLETED" ]; then
            return 0
        elif [ "$job_state" = "FAILED" ] || [ "$job_state" = "CANCELLED" ] || [ "$job_state" = "TIMEOUT" ] || [ "$job_state" = "NODE_FAIL" ]; then
            echo "Job failed with state: $job_state" >&2
            return 1
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    echo "Job timeout after ${timeout} seconds" >&2
    return 1
}

# Check job log for success indicators
check_job_log() {
    local log_file="$1"
    local success_pattern="${2:-Training Complete}"

    if [ ! -f "$log_file" ]; then
        echo "ERROR: Log file not found: $log_file" >&2
        # Try to find alternative log files
        local log_dir
        log_dir=$(dirname "$log_file")
        if [ -d "$log_dir" ]; then
            echo "DEBUG: Available log files in $log_dir:" >&2
            find "$log_dir" -maxdepth 1 \( -name "*.out" -o -name "*.err" \) -ls 2>/dev/null | head -10 >&2 || true
        fi
        return 1
    fi

    # Check for success pattern
    if grep -q "$success_pattern" "$log_file" 2>/dev/null; then
        return 0
    else
        echo "ERROR: Pattern '$success_pattern' not found in log file: $log_file" >&2

        # Check corresponding .err file if it exists
        local err_file="${log_file%.out}.err"
        if [ -f "$err_file" ] && [ -s "$err_file" ]; then
            echo "DEBUG: Found error log file: $err_file" >&2
            echo "DEBUG: Contents of error log:" >&2
            cat "$err_file" >&2
        fi

        echo "DEBUG: Last 30 lines of output log file:" >&2
        tail -30 "$log_file" >&2 || true
        echo "DEBUG: Checking for error patterns in output log..." >&2
        if grep -iE "(error|failed|exception|traceback|unrecognized)" "$log_file" 2>/dev/null | head -10; then
            echo "DEBUG: Errors found in log file" >&2
        fi
        return 1
    fi
}

# Extract accuracy from log file
extract_accuracy() {
    local log_file="$1"
    local accuracy

    if [ ! -f "$log_file" ]; then
        echo "ERROR: Log file not found: $log_file" >&2
        return 1
    fi

    # Try multiple patterns to extract accuracy
    # Pattern 1: "Accuracy: XX.XX%" (from training output)
    accuracy=$(grep -oP 'Accuracy: \K[0-9.]+' "$log_file" 2>/dev/null | tail -1)

    # Pattern 2: "Test Accuracy: XX.XX%" (from test output)
    if [ -z "$accuracy" ]; then
        accuracy=$(grep -oP 'Test Accuracy: \K[0-9.]+' "$log_file" 2>/dev/null | tail -1)
    fi

    # Pattern 3: "Epoch X: Test Loss: X.XXXX, Test Accuracy: XX.XX%"
    if [ -z "$accuracy" ]; then
        accuracy=$(grep -oP 'Test Accuracy: \K[0-9.]+' "$log_file" 2>/dev/null | tail -1)
    fi

    if [ -n "$accuracy" ]; then
        echo "$accuracy"
        return 0
    else
        echo "ERROR: Could not extract accuracy from log file: $log_file" >&2
        echo "DEBUG: Searching for accuracy-related lines:" >&2
        grep -i "accuracy" "$log_file" 2>/dev/null | tail -5 >&2 || echo "No accuracy lines found" >&2
        return 1
    fi
}

# Check for NCCL errors in log
# Detects various NCCL error formats:
#   - "NCCL error" / "NCCL ERROR"
#   - "NCCL WARN" (warnings that indicate problems)
#   - ncclSystemError, ncclInvalidUsage, etc.
check_nccl_errors() {
    local log_file="$1"

    if [ ! -f "$log_file" ]; then
        echo "ERROR: Log file not found: $log_file" >&2
        return 1
    fi

    if grep -qiE "(NCCL error|NCCL WARN|ncclSystemError|ncclInvalidUsage|ncclInternalError)" "$log_file" 2>/dev/null; then
        return 1  # Errors found
    else
        return 0  # No errors
    fi
}

# Verify multi-node execution
verify_multi_node() {
    local log_file="$1"
    local min_nodes="${2:-2}"

    if [ ! -f "$log_file" ]; then
        echo "ERROR: Log file not found: $log_file" >&2
        return 1
    fi

    local node_count
    # Expects "Node: <hostname>" output in the log
    # Count UNIQUE hostnames to avoid false positives if a node logs multiple times
    node_count=$(grep -o "Node: [^ ]*" "$log_file" 2>/dev/null | awk '{print $2}' | sort -u | wc -l || echo "0")

    if [ "$node_count" -ge "$min_nodes" ]; then
        return 0
    else
        echo "DEBUG: Found only $node_count unique nodes in log (expected >= $min_nodes)" >&2
        return 1
    fi
}
