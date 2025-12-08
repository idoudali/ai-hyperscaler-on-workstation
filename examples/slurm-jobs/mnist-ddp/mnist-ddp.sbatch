#!/bin/bash
#SBATCH --job-name=mnist-ddp-test
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --output=mnist-ddp-%j.out
#SBATCH --error=mnist-ddp-%j.err

# MNIST DDP Training Job with Apptainer Container
# Uses PyTorch container from TASK-053 for distributed training

# Configuration
# If PROJECT_ROOT is set, use it. Otherwise assume standard deployment paths
if [ -n "$PROJECT_ROOT" ]; then
    CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"
    TRAINING_SCRIPT="$PROJECT_ROOT/examples/slurm-jobs/mnist-ddp/mnist_ddp.py"
else
    CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"
    TRAINING_SCRIPT="/mnt/beegfs/training/scripts/mnist_ddp.py"
fi

# Point to the python executable in the container's venv
# The container has PyTorch installed in /venv (created by Dockerfile)
VENV_PYTHON="/venv/bin/python3"

# Print job info
echo "=========================================="
echo "MNIST DDP Validation Job"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node List: $SLURM_NODELIST"
echo "Number of Nodes: $SLURM_NNODES"
echo "Tasks per Node: $SLURM_NTASKS_PER_NODE"
echo "Total GPUs: $((SLURM_NNODES * SLURM_NTASKS_PER_NODE))"
echo "Container: $CONTAINER"
echo "Python: $VENV_PYTHON"
echo "Training Script: $TRAINING_SCRIPT"
echo "=========================================="

# Check if container exists before execution
if [ ! -f "$CONTAINER" ]; then
    echo "ERROR: Container not found: $CONTAINER"
    echo "Please ensure the container is deployed correctly."
    exit 1
fi

# Set distributed training environment variables
# Quote SLURM_NODELIST for safety
MASTER_ADDR=$(scontrol show hostname "$SLURM_NODELIST" | head -n1)
export MASTER_ADDR
export MASTER_PORT=29500
export WORLD_SIZE=$SLURM_NTASKS
export NCCL_DEBUG=INFO

# Disable InfiniBand if not available (default to 1=disabled)
# Can be overridden by setting NCCL_IB_DISABLE=0 before submission
export NCCL_IB_DISABLE=${NCCL_IB_DISABLE:-1}

echo "Master Node: $MASTER_ADDR:$MASTER_PORT"
echo "World Size: $WORLD_SIZE"
echo "NCCL_IB_DISABLE: $NCCL_IB_DISABLE"
echo ""

# Create data directory
mkdir -p /mnt/beegfs/data/mnist

# Apptainer bind mounts (BeeGFS shared storage)
export APPTAINER_BIND="/mnt/beegfs:/mnt/beegfs"

# Set up output directories and arguments based on TEST_OUTPUT_DIR
# Use array to properly handle arguments with spaces
PYTHON_ARGS=()
if [ -n "$TEST_OUTPUT_DIR" ]; then
    echo "Using Test Output Directory: $TEST_OUTPUT_DIR"
    mkdir -p "$TEST_OUTPUT_DIR/training-logs"
    mkdir -p "$TEST_OUTPUT_DIR/monitoring-logs/aim"
    PYTHON_ARGS+=("--monitor")
    PYTHON_ARGS+=("--log-dir" "$TEST_OUTPUT_DIR/training-logs")
    PYTHON_ARGS+=("--aim-repo" "$TEST_OUTPUT_DIR/monitoring-logs/aim")
fi

# Start time
START_TIME=$(date +%s)

# Launch distributed training with Apptainer
# Critical: We execute the PYTHON from the VENV *inside* the container
# This gives us access to libraries in the VENV (aim, tensorboard)
# AND libraries in the container (torch, cuda, mpi) because we used --system-site-packages
if [ ${#PYTHON_ARGS[@]} -gt 0 ]; then
    echo "Training with monitoring enabled"
    echo "Arguments: ${PYTHON_ARGS[*]}"
fi

# Execute with proper error handling
# The challenge: Arrays don't always serialize correctly through srun -> apptainer
# Solution: Use a wrapper command that reconstructs the arguments inside the container
set +e  # Temporarily disable exit on error to capture exit code

# Create a command string that will be executed inside the container
# We'll use bash -c with the arguments properly quoted
# Build the command by quoting each argument separately
PYTHON_CMD="$VENV_PYTHON"
PYTHON_CMD="$PYTHON_CMD $(printf %q "$TRAINING_SCRIPT")"

# Add each argument, properly quoted
for arg in "${PYTHON_ARGS[@]}"; do
    PYTHON_CMD="$PYTHON_CMD $(printf %q "$arg")"
done

# Execute using bash -c to ensure proper argument parsing
# The bash -c will properly split the quoted arguments
# CRITICAL: Source the venv activation to ensure PyTorch and other packages are available
# The entrypoint.sh is not automatically called with apptainer exec, so we must activate venv explicitly
srun --mpi=pmi2 apptainer exec --nv "$CONTAINER" \
    bash -c "source /venv/bin/activate && $PYTHON_CMD"

EXIT_CODE=$?
set -e  # Re-enable exit on error

if [ $EXIT_CODE -ne 0 ]; then
    echo "ERROR: Training script failed with exit code: $EXIT_CODE" >&2
    echo "ERROR: Check stderr output for details" >&2
    exit $EXIT_CODE
fi

# End time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=========================================="
echo "Job completed in ${DURATION} seconds"
echo "=========================================="
