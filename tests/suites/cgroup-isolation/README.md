# Cgroup Isolation Test Suite

Tests cgroup-based resource isolation for GPU devices in SLURM jobs.

## Test Scripts

- **check-cgroup-configuration.sh** - Validates cgroup.conf and device constraints
- **check-resource-isolation.sh** - Tests CPU and memory isolation via cgroups
- **check-device-isolation.sh** - Validates GPU device isolation between jobs
- **run-cgroup-isolation-tests.sh** - Main test runner for cgroup isolation tests

## Purpose

Ensures that SLURM uses cgroups to properly isolate GPU and other resources between
concurrent jobs, preventing resource contention and unauthorized access.

## Prerequisites

- GPU GRES tests passing
- cgroup.conf configured for device isolation
- SLURM cgroup plugin enabled

## Usage

```bash
./run-cgroup-isolation-tests.sh
```

## Dependencies

- basic-infrastructure
- gpu-validation
- gpu-gres
- slurm-controller
- slurm-compute
