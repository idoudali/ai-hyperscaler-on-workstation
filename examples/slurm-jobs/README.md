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
# Build all examples (on your laptop, from project root)
make run-docker COMMAND="cmake --build build --target build-slurm-jobs"

# Copy to controller's BeeGFS shared storage (includes binaries and sbatch scripts)
scp -i build/shared/ssh-keys/id_rsa -r build/examples/slurm-jobs \
    admin@<controller-ip>:/mnt/beegfs/

# SSH to controller node
ssh -i build/shared/ssh-keys/id_rsa admin@<controller-ip>

# Navigate to example on BeeGFS (accessible from all nodes)
cd /mnt/beegfs/slurm-jobs/hello-world

# Submit the job
sbatch hello.sbatch

# Check job status
squeue

# View output (after job completes)
cat slurm-*.out
```

**Note:**

- The CMake build process automatically copies the sbatch scripts to the build directory alongside the binaries.
- Examples are copied to `/mnt/beegfs/` (shared BeeGFS storage) so all compute nodes can access them.
- The sbatch scripts use `--chdir` to run from the BeeGFS directory.

## Example Structure

Each example directory contains:

- `*.c` - C source code for the MPI program
- `CMakeLists.txt` - CMake build configuration
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

## Building MPI Programs

All examples are built using CMake in the Docker container:

```bash
# Build all examples
make run-docker COMMAND="cmake --build build --target build-slurm-jobs"

# Build specific example
make run-docker COMMAND="cmake --build build --target build-hello-world"
make run-docker COMMAND="cmake --build build --target build-pi-calculation"
make run-docker COMMAND="cmake --build build --target build-matrix-multiply"
```

**Output:**

- Binaries: `build/examples/slurm-jobs/<example-name>/<binary-name>`
- Sbatch scripts: `build/examples/slurm-jobs/<example-name>/<script-name>.sbatch`

The build process automatically copies sbatch scripts alongside the binaries for easy deployment.

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

### Build errors

- Ensure Docker container is built: `make build-docker`
- Reconfigure CMake: `make config`
- Check MPI is found: Look for "Found MPI" in CMake output
- Verify build directory exists: `ls -la build/`

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
