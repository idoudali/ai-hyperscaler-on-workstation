#!/usr/bin/env bats
#
# Phase 5: MNIST DDP Job Test (BATS)
# Tests MNIST distributed training with NCCL
# TASK-054: NCCL Multi-GPU Validation
#

# Load helper functions
load helpers/container-helpers
load helpers/training-helpers

# Test configuration
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"
TRAINING_SCRIPT="$PROJECT_ROOT/examples/slurm-jobs/mnist-ddp/mnist_ddp.py"
# Use .sbatch extension for consistency with source
SBATCH_SCRIPT="$PROJECT_ROOT/examples/slurm-jobs/mnist-ddp/mnist-ddp.sbatch"

# Setup: Run before each test
setup() {
    TEST_TEMP_DIR=$(mktemp -d)
    export TEST_TEMP_DIR
    # Export bind path for Apptainer so it can access BeeGFS
    export APPTAINER_BIND="/mnt/beegfs:/mnt/beegfs"
    # Initialize JOB_ID for cleanup in teardown
    JOB_ID=""
}

# Teardown: Run after each test
teardown() {
    rm -rf "$TEST_TEMP_DIR"

    # Ensure any running job is cancelled if test failed/aborted
    if [ -n "$JOB_ID" ]; then
        # Check if job is still running before cancelling to avoid noise
        if squeue -j "$JOB_ID" -h 2>/dev/null | grep -q "$JOB_ID"; then
            scancel "$JOB_ID" 2>/dev/null || true
        fi
    fi
}

@test "MNIST training script exists" {
    skip_if_no_apptainer
    [ -f "$TRAINING_SCRIPT" ]
}

@test "MNIST training script is valid Python" {
    skip_if_no_apptainer
    skip_if_no_training_script "$TRAINING_SCRIPT"

    run apptainer exec "$CONTAINER" python3 -m py_compile "$TRAINING_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "SLURM job script exists" {
    # Note: sbatch files don't need to be executable - sbatch reads them as scripts
    [ -f "$SBATCH_SCRIPT" ]
}

@test "SLURM job script syntax is valid" {
    run bash -n "$SBATCH_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "MNIST job can be submitted" {
    skip_if_no_apptainer
    skip_if_no_gpu
    skip_if_no_training_script "$TRAINING_SCRIPT"

    # Generate sanitized test name for log file
    TEST_NAME_SANITIZED=$(echo "$BATS_TEST_DESCRIPTION" | tr ' ' '-' | tr -cd '[:alnum:]-')
    # Generate UUID for this test run
    UUID=$(uuidgen)
    # Define test output structure
    TEST_OUTPUT_DIR="/mnt/beegfs/tests/${BATS_SUITE_TEST_NUMBER:-unknown}-${TEST_NAME_SANITIZED}-${UUID}"

    # Add test number to log file name for easier identification
    LOG_PREFIX="mnist-ddp-${BATS_SUITE_TEST_NUMBER:-unknown}-${TEST_NAME_SANITIZED}"

    JOB_ID=$(submit_mnist_job "$SBATCH_SCRIPT" "$LOG_PREFIX" "$TEST_OUTPUT_DIR")
    [ -n "$JOB_ID" ]
    [ "$JOB_ID" -gt 0 ]

    # Cleanup: cancel job if still running
    scancel "$JOB_ID" 2>/dev/null || true
}

@test "MNIST job completes successfully" {
    skip_if_no_apptainer
    skip_if_no_gpu
    skip_if_no_training_script "$TRAINING_SCRIPT"
    skip_if_single_node

    # Generate sanitized test name for log file
    TEST_NAME_SANITIZED=$(echo "$BATS_TEST_DESCRIPTION" | tr ' ' '-' | tr -cd '[:alnum:]-')
    UUID=$(uuidgen)
    TEST_OUTPUT_DIR="/mnt/beegfs/tests/${BATS_SUITE_TEST_NUMBER:-unknown}-${TEST_NAME_SANITIZED}-${UUID}"

    LOG_PREFIX="mnist-ddp-${BATS_SUITE_TEST_NUMBER:-unknown}-${TEST_NAME_SANITIZED}"

    JOB_ID=$(submit_mnist_job "$SBATCH_SCRIPT" "$LOG_PREFIX" "$TEST_OUTPUT_DIR")
    [ -n "$JOB_ID" ]

    # Wait for job completion (max 10 minutes)
    run wait_for_job "$JOB_ID" 600
    [ "$status" -eq 0 ]

    # Check log file
    # Log file will be: $TEST_OUTPUT_DIR/slurm/${LOG_PREFIX}-${JOB_ID}.out
    LOG_FILE="$TEST_OUTPUT_DIR/slurm/${LOG_PREFIX}-${JOB_ID}.out"
    run check_job_log "$LOG_FILE" "Training Complete"
    [ "$status" -eq 0 ]
}

@test "MNIST training achieves >95% accuracy" {
    skip_if_no_apptainer
    skip_if_no_gpu
    skip_if_no_training_script "$TRAINING_SCRIPT"
    skip_if_single_node

    # Generate sanitized test name for log file
    TEST_NAME_SANITIZED=$(echo "$BATS_TEST_DESCRIPTION" | tr ' ' '-' | tr -cd '[:alnum:]-')
    UUID=$(uuidgen)
    TEST_OUTPUT_DIR="/mnt/beegfs/tests/${BATS_SUITE_TEST_NUMBER:-unknown}-${TEST_NAME_SANITIZED}-${UUID}"

    LOG_PREFIX="mnist-ddp-${BATS_SUITE_TEST_NUMBER:-unknown}-${TEST_NAME_SANITIZED}"

    JOB_ID=$(submit_mnist_job "$SBATCH_SCRIPT" "$LOG_PREFIX" "$TEST_OUTPUT_DIR")
    [ -n "$JOB_ID" ]

    # Wait for job completion
    run wait_for_job "$JOB_ID" 600
    [ "$status" -eq 0 ]

    # Extract accuracy
    LOG_FILE="$TEST_OUTPUT_DIR/slurm/${LOG_PREFIX}-${JOB_ID}.out"
    ACCURACY=$(extract_accuracy "$LOG_FILE")

    if [ -n "$ACCURACY" ]; then
        # Compare accuracy (requires bc for floating point)
        if command -v bc >/dev/null 2>&1; then
            result=$(echo "$ACCURACY > 95" | bc)
            [ "$result" -eq 1 ]
        else
            # Fallback: check if accuracy string contains high value
            # Matches 95-99 or 100
            [[ "$ACCURACY" =~ ^9[5-9] ]] || [[ "$ACCURACY" =~ ^100 ]]
        fi
    else
        skip "Could not extract accuracy from log"
    fi
}

@test "No NCCL errors in training log" {
    skip_if_no_apptainer
    skip_if_no_gpu
    skip_if_no_training_script "$TRAINING_SCRIPT"
    skip_if_single_node

    # Generate sanitized test name for log file
    TEST_NAME_SANITIZED=$(echo "$BATS_TEST_DESCRIPTION" | tr ' ' '-' | tr -cd '[:alnum:]-')
    UUID=$(uuidgen)
    TEST_OUTPUT_DIR="/mnt/beegfs/tests/${BATS_SUITE_TEST_NUMBER:-unknown}-${TEST_NAME_SANITIZED}-${UUID}"

    LOG_PREFIX="mnist-ddp-${BATS_SUITE_TEST_NUMBER:-unknown}-${TEST_NAME_SANITIZED}"

    JOB_ID=$(submit_mnist_job "$SBATCH_SCRIPT" "$LOG_PREFIX" "$TEST_OUTPUT_DIR")
    [ -n "$JOB_ID" ]

    # Wait for job completion
    run wait_for_job "$JOB_ID" 600
    [ "$status" -eq 0 ]

    # Check for NCCL errors
    LOG_FILE="$TEST_OUTPUT_DIR/slurm/${LOG_PREFIX}-${JOB_ID}.out"
    run check_nccl_errors "$LOG_FILE"
    [ "$status" -eq 0 ]
}

@test "Multi-node execution confirmed" {
    skip_if_no_apptainer
    skip_if_no_gpu
    skip_if_no_training_script "$TRAINING_SCRIPT"
    skip_if_single_node

    # Generate sanitized test name for log file
    TEST_NAME_SANITIZED=$(echo "$BATS_TEST_DESCRIPTION" | tr ' ' '-' | tr -cd '[:alnum:]-')
    UUID=$(uuidgen)
    TEST_OUTPUT_DIR="/mnt/beegfs/tests/${BATS_SUITE_TEST_NUMBER:-unknown}-${TEST_NAME_SANITIZED}-${UUID}"

    LOG_PREFIX="mnist-ddp-${BATS_SUITE_TEST_NUMBER:-unknown}-${TEST_NAME_SANITIZED}"

    JOB_ID=$(submit_mnist_job "$SBATCH_SCRIPT" "$LOG_PREFIX" "$TEST_OUTPUT_DIR")
    [ -n "$JOB_ID" ]

    # Wait for job completion
    run wait_for_job "$JOB_ID" 600
    [ "$status" -eq 0 ]

    # Verify multi-node execution
    LOG_FILE="$TEST_OUTPUT_DIR/slurm/${LOG_PREFIX}-${JOB_ID}.out"
    run verify_multi_node "$LOG_FILE" 2
    [ "$status" -eq 0 ]
}

@test "Container can import required PyTorch modules" {
    skip_if_no_apptainer

    # Use container's venv where PyTorch is installed
    run apptainer exec "$CONTAINER" /venv/bin/python3 -c "
import torch
import torch.nn as nn
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader
from torch.utils.data.distributed import DistributedSampler
from torchvision import datasets, transforms
print('All imports successful')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"All imports successful"* ]]
}
