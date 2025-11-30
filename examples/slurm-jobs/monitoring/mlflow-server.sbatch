#!/bin/bash
#SBATCH --job-name=mlflow-server
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=7-00:00:00
#SBATCH --output=mlflow-%j.out

# Configuration
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"
SCRIPT_DIR=$(dirname "$0")
START_SCRIPT="$SCRIPT_DIR/scripts/start-mlflow.sh"

echo "=========================================="
echo "MLflow Server Job"
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
export CONTAINER
bash "$START_SCRIPT"
