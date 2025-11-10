# SLURM Job Examples Test Suite

Tests realistic SLURM job submissions and cluster health validation using example workloads.

## Test Scripts

- **check-cluster-health.sh** - Validates overall cluster health and node availability
- **check-hello-world-job.sh** - Tests basic single-node job submission
- **check-pi-calculation-job.sh** - Tests CPU-intensive computation job
- **check-matrix-multiply-job.sh** - Tests multi-threaded job execution
- **check-beegfs-shared-storage.sh** - Tests BeeGFS integration with SLURM jobs
- **run-slurm-job-examples-tests.sh** - Main test runner for job examples

## Purpose

Validates end-to-end SLURM functionality through realistic job submission scenarios,
ensuring the cluster can handle typical HPC workloads.

## Prerequisites

- SLURM controller and compute tests passing
- BeeGFS filesystem mounted and accessible
- Job submission tools (sbatch, srun) available

## Usage

```bash
./run-slurm-job-examples-tests.sh
```

## Dependencies

- basic-infrastructure
- slurm-controller
- slurm-compute
- beegfs
