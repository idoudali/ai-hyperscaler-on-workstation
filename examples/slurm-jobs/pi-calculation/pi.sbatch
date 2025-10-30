#!/bin/bash
#SBATCH --job-name=pi-monte-carlo   # Job name
#SBATCH --nodes=2                   # Number of nodes
#SBATCH --ntasks-per-node=4         # MPI processes per node (total: 8)
#SBATCH --cpus-per-task=1           # CPU cores per MPI process
#SBATCH --time=00:10:00             # Max runtime: 10 minutes
#SBATCH --output=slurm-%j.out       # Output file (%j = job ID)
#SBATCH --error=slurm-%j.err        # Error file
#SBATCH --partition=main            # Partition name (adjust if needed)

# ========================================
# SLURM Job Script: Monte Carlo Pi Estimation
# ========================================
# This job estimates π using parallel Monte Carlo simulation.
# Demonstrates scaling and computational performance across nodes.

echo "========================================="
echo "Monte Carlo Pi Estimation SLURM Job"
echo "========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Job Name: $SLURM_JOB_NAME"
echo "Nodes allocated: $SLURM_JOB_NODELIST"
echo "Number of nodes: $SLURM_JOB_NUM_NODES"
echo "Tasks per node: $SLURM_NTASKS_PER_NODE"
echo "Total tasks: $SLURM_NTASKS"
echo "Working directory: $(pwd)"
echo "========================================="
echo ""

# Number of samples (default: 100 million for better accuracy)
NUM_SAMPLES=${1:-100000000}

echo "Configuration:"
echo "  Samples: $NUM_SAMPLES"
echo "  Samples per process: $((NUM_SAMPLES / SLURM_NTASKS))"
echo ""

# Load MPI module if using environment modules
# module load mpi/openmpi

# Check if executable exists
if [ ! -f "./pi-monte-carlo" ]; then
    echo "ERROR: Executable ./pi-monte-carlo not found"
    echo "Please run: bash compile.sh"
    exit 1
fi

# Run the MPI program
echo "Starting Monte Carlo simulation..."
echo "Command: mpirun ./pi-monte-carlo $NUM_SAMPLES"
echo ""

# Execute
mpirun ./pi-monte-carlo "$NUM_SAMPLES"
exit_code=$?

echo ""
echo "========================================="
echo "Job Completed"
echo "========================================="
echo "Exit code: $exit_code"
echo "========================================="

exit $exit_code
