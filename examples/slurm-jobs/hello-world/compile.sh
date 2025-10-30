#!/bin/bash
# Compile MPI Hello World program

set -e

echo "========================================="
echo "Compiling MPI Hello World"
echo "========================================="

# Check if mpicc is available
if ! command -v mpicc &> /dev/null; then
    echo "ERROR: mpicc not found"
    echo "Please install OpenMPI or MPICH"
    echo ""
    echo "On Debian/Ubuntu:"
    echo "  sudo apt-get install libopenmpi-dev openmpi-bin"
    echo ""
    echo "On CentOS/RHEL:"
    echo "  sudo yum install openmpi openmpi-devel"
    exit 1
fi

echo "MPI Compiler: $(mpicc --version | head -1)"
echo ""

# Compile the program
echo "Compiling hello.c..."
if mpicc -O2 -Wall -o hello hello.c; then
    echo "✓ Compilation successful"
    echo ""
    echo "Executable: ./hello"
    echo ""
    echo "Next steps:"
    echo "  1. Test locally:  mpirun -np 4 ./hello"
    echo "  2. Submit to SLURM: sbatch hello.sbatch"
else
    echo "✗ Compilation failed"
    exit 1
fi
