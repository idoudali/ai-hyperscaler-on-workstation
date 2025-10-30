#!/bin/bash
# Compile MPI Matrix Multiplication program

set -e

echo "========================================="
echo "Compiling MPI Matrix Multiplication"
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
echo "Compiling matrix-mult.c..."
if mpicc -O3 -Wall -o matrix-mult matrix-mult.c -lm; then
    echo "✓ Compilation successful"
    echo ""
    echo "Executable: ./matrix-mult"
    echo ""
    echo "Next steps:"
    echo "  1. Test locally:  mpirun -np 4 ./matrix-mult 100"
    echo "  2. Submit to SLURM: sbatch matrix.sbatch"
    echo ""
    echo "Usage: ./matrix-mult [matrix_size]"
    echo "  Default: 100x100 matrices"
    echo "  Note: Size must be divisible by number of processes"
else
    echo "✗ Compilation failed"
    exit 1
fi
