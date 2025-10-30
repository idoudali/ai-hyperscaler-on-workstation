#!/bin/bash
# Compile MPI Pi Monte Carlo program

set -e

echo "========================================="
echo "Compiling MPI Pi Monte Carlo"
echo "========================================="

# Check if mpicc is available
if ! command -v mpicc &> /dev/null; then
    echo "ERROR: mpicc not found"
    echo "Please install OpenMPI or MPICH"
    exit 1
fi

echo "MPI Compiler: $(mpicc --version | head -1)"
echo ""

# Compile with math library
echo "Compiling pi-monte-carlo.c..."
if mpicc -O3 -Wall -o pi-monte-carlo pi-monte-carlo.c -lm; then
    echo "✓ Compilation successful"
    echo ""
    echo "Executable: ./pi-monte-carlo"
    echo ""
    echo "Next steps:"
    echo "  1. Test locally:  mpirun -np 4 ./pi-monte-carlo 1000000"
    echo "  2. Submit to SLURM: sbatch pi.sbatch"
    echo ""
    echo "Usage: ./pi-monte-carlo [num_samples]"
    echo "  Default: 10,000,000 samples"
else
    echo "✗ Compilation failed"
    exit 1
fi
