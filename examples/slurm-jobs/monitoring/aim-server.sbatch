#!/bin/bash
#SBATCH --job-name=aim-server
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=7-00:00:00
#SBATCH --output=aim-%j.out

# Configuration
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"
SCRIPT_DIR=$(dirname "$0")
START_SCRIPT="$SCRIPT_DIR/scripts/start-aim.sh"

echo "=========================================="
echo "Aim Server Job"
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
# If AIM_REPO is set in the environment (e.g. via --export), it will be used by the script
# We can also explicitly pass it if needed, but environment variable is cleaner for sbatch
bash "$START_SCRIPT"
