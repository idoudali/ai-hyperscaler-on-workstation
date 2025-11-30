#!/bin/bash
#SBATCH --job-name=tensorboard
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=7-00:00:00
#SBATCH --output=tensorboard-%j.out

# Configuration
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"
SCRIPT_DIR=$(dirname "$0")
START_SCRIPT="$SCRIPT_DIR/scripts/start-tensorboard.sh"

echo "=========================================="
echo "TensorBoard Server Job"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Host: $(hostname)"
echo ""

# Check script
if [ ! -f "$START_SCRIPT" ]; then
    echo "ERROR: Start script not found at $START_SCRIPT"
    exit 1
fi

chmod +x "$START_SCRIPT"

# Run the standalone script
# Environment variables will be passed through or can be set here
export CONTAINER
bash "$START_SCRIPT"
