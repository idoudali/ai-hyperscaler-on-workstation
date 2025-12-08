#!/bin/bash
#SBATCH --job-name=oumi-training
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --gres=gpu:2
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --output=/mnt/beegfs/logs/oumi-%j.out
#SBATCH --error=/mnt/beegfs/logs/oumi-%j.err

# Container path
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1-oumi.sif"
CONFIG_FILE="${1:-/mnt/beegfs/configs/oumi-template.yaml}"

# Print job info
echo "=========================================="
echo "Oumi Framework Training with Apptainer"
echo "=========================================="
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Node List: $SLURM_NODELIST"
echo "Number of Nodes: $SLURM_NNODES"
echo "Tasks per Node: $SLURM_NTASKS_PER_NODE"
echo "Total GPUs: $((SLURM_NNODES * SLURM_NTASKS_PER_NODE))"
echo "Container: $CONTAINER"
echo "Config: $CONFIG_FILE"
echo "=========================================="

# Verify container exists
if [ ! -f "$CONTAINER" ]; then
    echo "ERROR: Container not found: $CONTAINER"
    exit 1
fi

# Verify config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Set distributed training environment variables
MASTER_ADDR=$(scontrol show hostname "$SLURM_NODELIST" | head -n1)
export MASTER_ADDR
export MASTER_PORT=29500
export WORLD_SIZE=$SLURM_NTASKS
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=1  # Disable InfiniBand if not available

echo "Master Address: $MASTER_ADDR"
echo "Master Port: $MASTER_PORT"
echo "World Size: $WORLD_SIZE"
echo ""

# Apptainer bind mounts (BeeGFS shared storage)
export APPTAINER_BIND="/mnt/beegfs:/mnt/beegfs"

# Create output directory if it doesn't exist
OUTPUT_DIR=$(grep -A 1 "^training:" "$CONFIG_FILE" | grep "output_dir:" | awk '{print $2}' | tr -d '"')
if [ -n "$OUTPUT_DIR" ] && [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
    echo "Created output directory: $OUTPUT_DIR"
fi

# Create logs directory if it doesn't exist
mkdir -p /mnt/beegfs/logs

echo "Starting Oumi training..."
echo ""

# Launch Oumi training with Apptainer
# Using srun to launch MPI jobs across nodes
# Apptainer will use the host's MPI (PMI) for communication
# CRITICAL: Source the venv activation to ensure Oumi and other packages are available
# The entrypoint.sh is not automatically called with apptainer exec, so we must activate venv explicitly
srun --mpi=pmi2 apptainer exec --nv \
    "$CONTAINER" \
    bash -c "source /venv/bin/activate && oumi train --config $(printf %q "$CONFIG_FILE")"

TRAIN_EXIT_CODE=$?

echo ""
echo "=========================================="
if [ $TRAIN_EXIT_CODE -eq 0 ]; then
    echo "Training completed successfully"
else
    echo "Training failed with exit code: $TRAIN_EXIT_CODE"
fi
echo "=========================================="

exit $TRAIN_EXIT_CODE
