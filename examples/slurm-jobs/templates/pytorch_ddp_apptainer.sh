#!/bin/bash
#SBATCH --job-name=pytorch-ddp
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --gres=gpu:2
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --output=pytorch-ddp-%j.out
#SBATCH --error=pytorch-ddp-%j.err

# Container path
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"
TRAINING_SCRIPT="/mnt/beegfs/training/scripts/your_script.py"

# Print job info
echo "=========================================="
echo "PyTorch DDP Training with Apptainer"
echo "=========================================="
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Node List: $SLURM_NODELIST"
echo "Number of Nodes: $SLURM_NNODES"
echo "Tasks per Node: $SLURM_NTASKS_PER_NODE"
echo "Total GPUs: $((SLURM_NNODES * SLURM_NTASKS_PER_NODE))"
echo "Container: $CONTAINER"
echo "=========================================="

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

# Launch distributed training with Apptainer
# Using srun to launch MPI jobs across nodes
# Apptainer will use the host's MPI (PMI) for communication
srun --mpi=pmi2 apptainer exec --nv \
    $CONTAINER \
    python3 $TRAINING_SCRIPT \
        --epochs 10 \
        --batch-size 64 \
        --learning-rate 0.001

echo ""
echo "=========================================="
echo "Training completed"
echo "=========================================="
