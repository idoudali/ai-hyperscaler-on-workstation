# SLURM Job Examples

This directory contains simple MPI examples for testing SLURM job submission and multi-node execution.

## Examples

### 1. Hello World (`hello-world/`)

A basic MPI program that demonstrates:

- MPI initialization and finalization
- Rank identification
- Hostname retrieval
- Multi-node execution validation

**Purpose:** Verify SLURM can schedule jobs across multiple nodes and that MPI communication works.

### 2. Pi Calculation (`pi-calculation/`)

Monte Carlo π estimation using parallel random sampling:

- Work distribution across MPI processes
- MPI reduction operations for aggregating results
- Configurable problem size for scaling tests
- Demonstrates parallel computation patterns

**Purpose:** Test computational workloads and verify scaling across nodes.

### 3. Matrix Multiply (`matrix-multiply/`)

Simple distributed matrix multiplication:

- Matrix decomposition across processes
- Point-to-point MPI communication
- Collective operations (broadcast, gather)
- Resource allocation demonstration

**Purpose:** Demonstrate memory-intensive parallel workload and resource allocation.

## Prerequisites

- HPC cluster deployed via `make hpc-cluster-deploy`
- SSH access to controller node
- MPI library installed (OpenMPI or MPICH)
- C compiler (gcc)

## Quick Start

```bash
# SSH to controller node
ssh -i build/shared/ssh-keys/id_rsa admin@<controller-ip>

# Copy examples to controller (if not already there)
# scp -i build/shared/ssh-keys/id_rsa -r examples/slurm-jobs admin@<controller-ip>:~/

# Navigate to an example
cd ~/slurm-jobs/hello-world

# Compile the program
bash compile.sh

# Submit the job
sbatch hello.sbatch

# Check job status
squeue

# View output (after job completes)
cat slurm-*.out
```

## Example Structure

Each example directory contains:

- `*.c` - C source code for the MPI program
- `compile.sh` - Compilation script (handles MPI compiler wrapper)
- `*.sbatch` - SLURM batch script with resource requests

## SLURM Batch Script Anatomy

All example batch scripts follow this pattern:

```bash
#!/bin/bash
#SBATCH --job-name=example-name    # Job name in queue
#SBATCH --nodes=2                  # Number of nodes
#SBATCH --ntasks-per-node=2        # MPI processes per node
#SBATCH --time=00:05:00            # Max runtime (5 minutes)
#SBATCH --output=slurm-%j.out      # Output file (%j = job ID)

# Load environment (if needed)
# module load mpi/openmpi

# Run MPI program
mpirun ./program_name
```

## Compiling MPI Programs

All examples use `mpicc` (MPI C compiler wrapper):

```bash
# Basic compilation
mpicc -o program_name source.c

# With optimization
mpicc -O2 -o program_name source.c

# With debugging symbols
mpicc -g -o program_name source.c
```

## Monitoring Jobs

```bash
# List jobs in queue
squeue

# Show all jobs (including completed)
squeue -a

# Show only your jobs
squeue -u $USER

# Detailed job information
scontrol show job <job-id>

# Cancel a job
scancel <job-id>
```

## Troubleshooting

### Job doesn't start

- Check node availability: `sinfo`
- Check partition status: `scontrol show partition`
- Verify resource request doesn't exceed available resources

### MPI errors

- Ensure MPI library is installed on all nodes
- Check `mpirun` is in PATH
- Verify network connectivity between nodes

### Compilation errors

- Check gcc is installed: `gcc --version`
- Check MPI compiler wrapper: `mpicc --version`
- Verify MPI headers are accessible

### Job output not found

- Check job completed: `squeue -a | grep <job-id>`
- Look for output file: `ls -lh slurm-*.out`
- Check SLURM log directory: `/var/log/slurm/`

## Performance Testing

To test scaling, modify the batch script to use different node counts:

```bash
# Test with 1, 2, 4 nodes
for nodes in 1 2 4; do
    sed "s/--nodes=.*/--nodes=$nodes/" pi.sbatch > pi-${nodes}nodes.sbatch
    sbatch pi-${nodes}nodes.sbatch
done
```

## Integration with Validation

These examples are used by the validation script:

```bash
# From project root
cd tests
./validate-makefile-cluster.sh run-examples
```

Or via Makefile:

```bash
cd tests
make validate-slurm-jobs
```

## References

- [SLURM Documentation](https://slurm.schedmd.com/documentation.html)
- [MPI Tutorial](https://mpitutorial.com/)
- [OpenMPI Documentation](https://www.open-mpi.org/doc/)

## Next Steps

After running these examples successfully:

1. Review the tutorial: `docs/tutorials/08-slurm-basics.md`
2. Create custom job scripts for your workloads
3. Explore GPU job scheduling (if GPUs available)
4. Set up job arrays for parameter sweeps
