#!/bin/bash
#SBATCH --job-name=matrix-mult      # Job name
#SBATCH --nodes=2                   # Number of nodes
#SBATCH --ntasks-per-node=2         # MPI processes per node (total: 4)
#SBATCH --cpus-per-task=1           # CPU cores per MPI process
#SBATCH --mem=2G                    # Memory per node
#SBATCH --time=00:10:00             # Max runtime: 10 minutes
#SBATCH --output=slurm-%j.out       # Output file (%j = job ID)
#SBATCH --error=slurm-%j.err        # Error file
#SBATCH --partition=main            # Partition name (adjust if needed)

# ========================================
# SLURM Job Script: Matrix Multiplication
# ========================================
# Demonstrates memory-intensive parallel workload and resource allocation.

echo "========================================="
echo "Matrix Multiplication SLURM Job"
echo "========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Job Name: $SLURM_JOB_NAME"
echo "Nodes allocated: $SLURM_JOB_NODELIST"
echo "Number of nodes: $SLURM_JOB_NUM_NODES"
echo "Tasks per node: $SLURM_NTASKS_PER_NODE"
echo "Total tasks: $SLURM_NTASKS"
echo "Memory per node: $SLURM_MEM_PER_NODE MB"
echo "Working directory: $(pwd)"
echo "========================================="
echo ""

# Matrix size (must be divisible by number of processes)
# Default: 1000x1000 (~ 8MB per matrix, 24MB total)
MATRIX_SIZE=${1:-1000}

echo "Configuration:"
echo "  Matrix size: ${MATRIX_SIZE}x${MATRIX_SIZE}"
echo "  Rows per process: $((MATRIX_SIZE / SLURM_NTASKS))"
echo ""

# Load MPI module if using environment modules
# module load mpi/openmpi

# Check if executable exists
if [ ! -f "./matrix-mult" ]; then
    echo "ERROR: Executable ./matrix-mult not found"
    echo "Please run: bash compile.sh"
    exit 1
fi

# Validate matrix size is divisible by number of tasks
if [ $((MATRIX_SIZE % SLURM_NTASKS)) -ne 0 ]; then
    echo "ERROR: Matrix size ($MATRIX_SIZE) must be divisible by number of tasks ($SLURM_NTASKS)"
    echo "Suggested sizes: $((SLURM_NTASKS * 250)), $((SLURM_NTASKS * 500)), $((SLURM_NTASKS * 1000))"
    exit 1
fi

# Run the MPI program
echo "Starting matrix multiplication..."
echo "Command: mpirun ./matrix-mult $MATRIX_SIZE"
echo ""

# Execute
mpirun ./matrix-mult "$MATRIX_SIZE"
exit_code=$?

echo ""
echo "========================================="
echo "Job Completed"
echo "========================================="
echo "Exit code: $exit_code"
echo "========================================="

exit $exit_code
