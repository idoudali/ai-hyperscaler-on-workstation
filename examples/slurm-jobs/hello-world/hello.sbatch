#!/bin/bash
#SBATCH --job-name=mpi-hello        # Job name
#SBATCH --nodes=2                   # Number of nodes
#SBATCH --ntasks-per-node=2         # MPI processes per node (total: 4)
#SBATCH --cpus-per-task=1           # CPU cores per MPI process
#SBATCH --time=00:05:00             # Max runtime: 5 minutes
#SBATCH --output=slurm-%j.out       # Output file (%j = job ID)
#SBATCH --error=slurm-%j.err        # Error file
#SBATCH --partition=main            # Partition name (adjust if needed)

# ========================================
# SLURM Job Script: MPI Hello World
# ========================================
# This job demonstrates basic MPI execution across multiple nodes.
# It verifies that SLURM can schedule multi-node jobs and that
# MPI processes can communicate correctly.

echo "========================================="
echo "MPI Hello World SLURM Job"
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

# Load MPI module if using environment modules
# Uncomment and adjust if your cluster uses modules
# module load mpi/openmpi

# Print MPI environment info
echo "MPI Environment:"
echo "  mpirun: $(command -v mpirun || echo 'not found')"
if command -v mpirun &> /dev/null; then
    echo "  version: $(mpirun --version 2>&1 | head -1)"
fi
echo ""

# Check if executable exists
if [ ! -f "./hello" ]; then
    echo "ERROR: Executable ./hello not found"
    echo "Please run: bash compile.sh"
    exit 1
fi

# Run the MPI program
echo "Starting MPI Hello World..."
echo "Command: mpirun ./hello"
echo ""

# Execute with timing
start_time=$(date +%s)
mpirun ./hello
exit_code=$?
end_time=$(date +%s)

# Calculate runtime
runtime=$((end_time - start_time))

echo ""
echo "========================================="
echo "Job Completed"
echo "========================================="
echo "Exit code: $exit_code"
echo "Runtime: ${runtime}s"
echo "========================================="

# Exit with MPI program's exit code
exit $exit_code
