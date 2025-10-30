# Tutorial 08: SLURM Basics - Your First Distributed Jobs

**Level:** Beginner  
**Prerequisites:** Tutorial 01 (First Cluster)  
**Duration:** 30-45 minutes  
**Goal:** Learn to submit and manage SLURM jobs on your HPC cluster

---

## Overview

This tutorial teaches you how to:

1. Understand SLURM architecture and terminology
2. Submit your first job to the SLURM queue
3. Monitor job status and read output
4. Run parallel MPI jobs across multiple nodes
5. Understand resource requests and allocation
6. Debug common job failures

By the end, you'll be comfortable submitting workloads to your HPC cluster.

---

## Prerequisites

Before starting, ensure you have:

```bash
# 1. Cluster deployed and running
make hpc-cluster-status

# 2. SSH key and controller IP
ssh-add build/shared/ssh-keys/id_rsa
CONTROLLER_IP=$(virsh domifaddr hpc-cluster-controller | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
echo "Controller IP: $CONTROLLER_IP"

# 3. SSH connectivity
ssh -i build/shared/ssh-keys/id_rsa admin@$CONTROLLER_IP "sinfo"
```

If any command fails, revisit Tutorial 01 or run:

```bash
make hpc-cluster-start
make hpc-cluster-deploy
```

---

## Part 1: Understanding SLURM

### What is SLURM?

SLURM (Simple Linux Utility for Resource Management) is a workload manager for HPC clusters. It:

- **Schedules jobs** - Queues jobs and runs them when resources are available
- **Allocates resources** - Assigns CPU cores, memory, GPUs to jobs
- **Manages priorities** - Enforces fair share and priority policies
- **Monitors usage** - Tracks resource consumption and job history

### Key Components

```text
┌─────────────────┐
│  Your Laptop    │  Submit jobs with sbatch/srun
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Controller    │  slurmctld (scheduler) + slurmdbd (accounting)
│  (Head Node)    │  Manages queue, allocates resources
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│Compute │ │Compute │  slurmd (daemon on each node)
│Node 1  │ │Node 2  │  Executes jobs, reports status
└────────┘ └────────┘
```

### SLURM Terminology

| Term | Definition |
|------|------------|
| **Job** | A resource allocation request (CPUs, memory, time) |
| **Task** | An instance of your program (often = MPI process) |
| **Node** | A physical or virtual machine in the cluster |
| **Partition** | A logical group of nodes (like a queue) |
| **JobID** | Unique identifier assigned to each job |
| **srun** | Run a job step (interactive or within a job) |
| **sbatch** | Submit a batch job script |
| **squeue** | View jobs in the queue |
| **scancel** | Cancel a job |
| **sinfo** | View cluster and partition status |

---

## Part 2: Your First Job - Hello World

### Step 1: SSH to Controller

```bash
# Set controller IP
CONTROLLER_IP=$(virsh domifaddr hpc-cluster-controller | awk '/ipv4/ {print $4}' | cut -d'/' -f1)

# SSH to controller
ssh -i build/shared/ssh-keys/id_rsa admin@$CONTROLLER_IP
```

### Step 2: Check Cluster Status

```bash
# View partition and node status
sinfo

# Expected output (example):
# PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
# main*        up   infinite      2   idle compute-[1-2]
```

**Columns explained:**

- `PARTITION` - Logical group of nodes (use this in job scripts)
- `AVAIL` - Partition availability (up = available)
- `NODES` - Number of nodes in this state
- `STATE` - Node state (idle, allocated, down, etc.)
- `NODELIST` - Node names in this partition

### Step 3: Interactive Job with srun

Run a simple command across all nodes:

```bash
# Run hostname on 2 nodes, 1 task per node
srun --nodes=2 --ntasks-per-node=1 hostname
```

**Expected output:**

```text
compute-1
compute-2
```

**What just happened?**

- SLURM allocated 2 nodes
- Ran `hostname` command on each node
- Printed the results
- Released the allocation

**Try this:**

```bash
# Run on 4 tasks total (2 nodes × 2 tasks/node)
srun --nodes=2 --ntasks-per-node=2 bash -c 'echo "Hello from $(hostname)"'
```

### Step 4: Your First Batch Job

Batch jobs run in the background and save output to files.

Create a job script:

```bash
cat > hello-job.sh <<'EOF'
#!/bin/bash
#SBATCH --job-name=hello-test
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:01:00
#SBATCH --output=hello-%j.out

# Print job information
echo "=========================================="
echo "Job started at: $(date)"
echo "Running on node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo "=========================================="

# Simple computation
echo "Hello from SLURM!"
sleep 5
echo "Job finished at: $(date)"
EOF

chmod +x hello-job.sh
```

**Submit the job:**

```bash
sbatch hello-job.sh
```

**Output:**

```text
Submitted batch job 123
```

**Monitor job status:**

```bash
# Check queue (watch job run)
squeue

# View job details
scontrol show job 123

# After completion, view output
cat hello-123.out
```

**Understanding the output file:**

- Named `hello-123.out` where `123` is the JobID
- Contains all stdout from your job script
- Created in the directory where you ran `sbatch`

---

## Part 3: Parallel MPI Jobs

### Step 1: Copy MPI Examples

```bash
# On your laptop (project root)
scp -i build/shared/ssh-keys/id_rsa -r examples/slurm-jobs \
    admin@$CONTROLLER_IP:~/
```

### Step 2: Compile Hello World

```bash
# SSH to controller (if not already there)
ssh -i build/shared/ssh-keys/id_rsa admin@$CONTROLLER_IP

# Navigate to example
cd ~/slurm-jobs/hello-world

# Compile
bash compile.sh
```

**Expected output:**

```text
=========================================
Compiling MPI Hello World
=========================================
MPI Compiler: gcc (Ubuntu ...) ...
Compiling hello.c...
✓ Compilation successful
```

### Step 3: Test Locally

Before submitting to SLURM, test the program works:

```bash
# Run with 4 MPI processes
mpirun -np 4 ./hello
```

**Expected output:**

```text
Hello from rank 0 of 4 processes on host controller (MPI processor: controller)
Hello from rank 1 of 4 processes on host controller (MPI processor: controller)
Hello from rank 2 of 4 processes on host controller (MPI processor: controller)
Hello from rank 3 of 4 processes on host controller (MPI processor: controller)

========================================
MPI Hello World Summary
========================================
Total processes: 4
Master rank: 0 (on controller)
========================================
```

### Step 4: Submit to SLURM

```bash
# View the batch script
cat hello.sbatch

# Submit job
sbatch hello.sbatch

# Monitor until complete
watch -n 1 squeue
# (Press Ctrl+C to exit)
```

### Step 5: Review Results

```bash
# After job completes, view output
ls -lh slurm-*.out

# Read the output file
cat slurm-<jobid>.out
```

**Expected output includes:**

- Job information (ID, nodes, tasks)
- MPI environment details
- Hello messages from each rank (across multiple nodes)
- Job completion summary

**Key observation:** Notice ranks run on different nodes - this proves multi-node execution!

---

## Part 4: Understanding Resource Requests

### Anatomy of a SLURM Batch Script

```bash
#!/bin/bash
#SBATCH --job-name=my-job          # Name shown in squeue
#SBATCH --nodes=2                  # Number of nodes
#SBATCH --ntasks-per-node=4        # MPI processes per node
#SBATCH --cpus-per-task=1          # CPU cores per MPI process
#SBATCH --mem=4G                   # Memory per node
#SBATCH --time=01:00:00            # Max runtime (HH:MM:SS)
#SBATCH --output=job-%j.out        # Output file (%j = jobid)
#SBATCH --error=job-%j.err         # Separate error file (optional)
#SBATCH --partition=main           # Partition to use

# Your commands here
srun ./my-program
```

### Resource Request Examples

#### Single-Node, Single-Core

```bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
```

**Use case:** Serial programs, preprocessing

#### Single-Node, Multi-Core (OpenMP)

```bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
```

**Use case:** Threaded programs (OpenMP), multi-core computations

#### Multi-Node, MPI

```bash
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=8
```

**Use case:** Distributed parallel programs (MPI), total 32 processes

#### Hybrid MPI + OpenMP

```bash
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4    # 4 MPI processes per node
#SBATCH --cpus-per-task=4      # Each MPI process gets 4 cores
```

**Use case:** Hybrid parallel programs, total 8 MPI processes × 4 threads/process

### Time Limits

```bash
# Format: HH:MM:SS or MM:SS or MM
#SBATCH --time=00:30:00    # 30 minutes
#SBATCH --time=02:00:00    # 2 hours
#SBATCH --time=1-12:00:00  # 1 day, 12 hours
```

**Important:** Jobs exceeding time limit are automatically killed. Always overestimate slightly.

---

## Part 5: Monitoring and Managing Jobs

### View Queue

```bash
# All jobs in queue
squeue

# Your jobs only
squeue -u $USER

# All jobs (including recently completed)
squeue -a

# Wide format (more columns)
squeue -o "%.10i %.9P %.20j %.8u %.8T %.10M %.6D %R"
```

**Job states:**

- `PD` (Pending) - Waiting for resources
- `R` (Running) - Currently executing
- `CG` (Completing) - Finishing up
- `CD` (Completed) - Finished successfully
- `F` (Failed) - Exited with error
- `CA` (Cancelled) - Cancelled by user or admin

### Job Details

```bash
# Show job configuration and state
scontrol show job 123

# Show job accounting info (after completion)
sacct -j 123

# Detailed accounting with custom format
sacct -j 123 --format=JobID,JobName,Partition,State,ExitCode,Elapsed,MaxRSS
```

### Cancel Jobs

```bash
# Cancel specific job
scancel 123

# Cancel all your jobs
scancel -u $USER

# Cancel all pending jobs
scancel -u $USER -t PENDING
```

### Node Information

```bash
# Node status summary
sinfo

# Detailed node info
scontrol show nodes

# Specific node details
scontrol show node compute-1
```

---

## Part 6: Running Pi Calculation Example

Let's run a more computationally intensive example.

### Step 1: Compile Pi Calculator

```bash
cd ~/slurm-jobs/pi-calculation
bash compile.sh
```

### Step 2: Test Locally

```bash
# Small test (1 million samples)
mpirun -np 4 ./pi-monte-carlo 1000000
```

**Expected output:**

```text
========================================
Parallel Monte Carlo Pi Estimation
========================================
Total samples: 1000000
Number of processes: 4
Samples per process: 250000
========================================

========================================
Results
========================================
Points inside circle: 785123
Total points: 1000000
Pi estimate: 3.1404920000
Actual Pi: 3.1415926536
...
========================================
```

### Step 3: Submit Large Job

```bash
# View batch script
cat pi.sbatch

# Submit with default samples (100 million)
sbatch pi.sbatch

# Or specify custom sample count
sbatch pi.sbatch --export=ALL,NUM_SAMPLES=1000000000
```

### Step 4: Monitor and Analyze

```bash
# Watch job progress
watch -n 2 squeue

# After completion, view results
cat slurm-<jobid>.out

# Check runtime and accuracy
grep "Execution time" slurm-<jobid>.out
grep "Pi estimate" slurm-<jobid>.out
```

---

## Part 7: Common Issues and Solutions

### Issue 1: Job Stays Pending

```bash
squeue
# STATE: PD
```

**Causes:**

- Not enough resources available (check `sinfo`)
- Requesting more resources than cluster has
- Other jobs using resources (wait)

**Solutions:**

```bash
# Check why job is pending
squeue -j 123 --start

# View available resources
sinfo -o "%20P %5a %.10l %16F %N"

# Reduce resource request if possible
```

### Issue 2: Job Fails Immediately

```bash
squeue  # Job disappears quickly
sacct -j 123  # Shows FAILED
```

**Causes:**

- Error in job script (syntax error)
- Executable not found or not executable
- Missing dependencies

**Debug steps:**

```bash
# Check output and error files
cat slurm-123.out
cat slurm-123.err

# Get exit code
sacct -j 123 --format=JobID,State,ExitCode

# Test commands manually
bash -x your-script.sh
```

### Issue 3: Job Killed for Time Limit

```bash
sacct -j 123
# State: TIMEOUT
```

**Solution:** Increase time limit in batch script:

```bash
#SBATCH --time=02:00:00  # Was 01:00:00
```

### Issue 4: Job Killed for Memory

```bash
sacct -j 123 --format=JobID,State,MaxRSS,ReqMem
# State: OUT_OF_MEMORY
```

**Solution:** Increase memory request:

```bash
#SBATCH --mem=8G  # Was 4G
```

### Issue 5: MPI Program Won't Start

**Symptom:** "mpirun: command not found" or MPI errors

**Solutions:**

```bash
# 1. Check MPI installed
which mpirun

# 2. Load MPI module (if using modules)
module load mpi/openmpi

# 3. Verify compilation used correct mpicc
which mpicc
mpicc --version
```

---

## Part 8: Best Practices

### 1. Resource Requests

- **Request what you need:** Over-requesting blocks resources for others
- **Test first:** Run small tests before large jobs
- **Check actual usage:** Use `sacct` to see what resources jobs actually used

```bash
# After job completes
sacct -j 123 --format=JobID,Elapsed,MaxRSS,MaxVMSize,ReqMem
```

### 2. Job Organization

```bash
# Create directories for different experiments
mkdir -p ~/jobs/{hello-world,pi-calc,matrix-mult}

# Use descriptive job names
#SBATCH --job-name=pi-1B-samples

# Organize output files
#SBATCH --output=logs/pi-%j.out
mkdir -p logs
```

### 3. Testing

Always test before submitting large jobs:

```bash
# 1. Test locally first
mpirun -np 4 ./program

# 2. Test small SLURM job
#SBATCH --nodes=1 --time=00:05:00

# 3. Scale up gradually
#SBATCH --nodes=2  # Then 4, 8, etc.
```

### 4. Output Management

```bash
# Separate stdout and stderr
#SBATCH --output=job-%j.out
#SBATCH --error=job-%j.err

# Include job name in output
#SBATCH --output=%x-%j.out  # %x = job name

# Redirect output to specific directory
#SBATCH --output=logs/%x-%j.out
```

---

## Part 9: Quick Reference Card

### Essential Commands

```bash
# Submit job
sbatch script.sh

# Interactive job (2 nodes, 30 minutes)
srun --nodes=2 --time=00:30:00 --pty bash

# View queue
squeue
squeue -u $USER

# Cancel job
scancel <jobid>

# Job details
scontrol show job <jobid>
sacct -j <jobid>

# Cluster status
sinfo
scontrol show nodes
```

### Common Batch Script Headers

```bash
#!/bin/bash
#SBATCH --job-name=my-job
#SBATCH --output=%x-%j.out
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --time=01:00:00
#SBATCH --partition=main
```

### Environment Variables in Jobs

```bash
$SLURM_JOB_ID          # Job ID
$SLURM_JOB_NAME        # Job name
$SLURM_JOB_NODELIST    # Nodes allocated
$SLURM_NTASKS          # Total tasks
$SLURM_CPUS_PER_TASK   # CPUs per task
$SLURM_SUBMIT_DIR      # Directory where job submitted
```

---

## Next Steps

Congratulations! You can now:

✅ Submit and monitor SLURM jobs  
✅ Run parallel MPI programs across nodes  
✅ Request appropriate resources  
✅ Debug common job failures

**Continue learning:**

- **Tutorial 09: SLURM Intermediate** (Coming Soon) - Job arrays, dependencies, advanced scheduling
- **Tutorial 10: SLURM Advanced** (Coming Soon) - GPU jobs, container integration, profiling
- **Tutorial 02: Distributed Training** - Apply SLURM to machine learning workloads

**Explore more examples:**

```bash
# Matrix multiplication (memory-intensive)
cd ~/slurm-jobs/matrix-multiply
bash compile.sh
sbatch matrix.sbatch

# Experiment with different sizes
sbatch matrix.sbatch --export=ALL,MATRIX_SIZE=2000
```

**Useful resources:**

- [SLURM Documentation](https://slurm.schedmd.com/documentation.html)
- [SLURM Quick Start](https://slurm.schedmd.com/quickstart.html)
- Project workflow docs: `docs/workflows/SLURM-COMPUTE-WORKFLOW.md`

---

## Summary

In this tutorial, you learned:

- SLURM architecture and terminology
- How to submit interactive and batch jobs
- Resource request syntax and best practices
- Job monitoring and management commands
- Running parallel MPI programs across nodes
- Debugging common job failures

You're now ready to use your HPC cluster for real workloads!

**Questions or issues?** Check:

- Project troubleshooting: `docs/TROUBLESHOOTING.md`
- Test validation: `cd tests && make validate-slurm`
- SLURM logs: `/var/log/slurm/` on controller

---

*Last updated: 2025-01-30*
