#!/bin/bash
#SBATCH --job-name=mnist-ddp-test
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --output=/mnt/beegfs/logs/mnist-ddp-%j.out
#SBATCH --error=/mnt/beegfs/logs/mnist-ddp-%j.err

# MNIST DDP Training Job with Apptainer Container
# Uses PyTorch container from TASK-053 for distributed training

# Container path (deployed in TASK-053)
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"
TRAINING_SCRIPT="/mnt/beegfs/training/scripts/mnist_ddp.py"

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

# Create log directory
mkdir -p /mnt/beegfs/logs
mkdir -p /mnt/beegfs/data/mnist

# Apptainer bind mounts (BeeGFS shared storage)
export APPTAINER_BIND="/mnt/beegfs:/mnt/beegfs"

# Start time
START_TIME=$(date +%s)

# Launch distributed training with Apptainer
# Using srun to launch MPI jobs across nodes
# Apptainer will use the host's MPI (PMI) for communication
srun --mpi=pmi2 apptainer exec --nv \
    $CONTAINER \
    python3 $TRAINING_SCRIPT

# End time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=========================================="
echo "Job completed in ${DURATION} seconds"
echo "=========================================="
