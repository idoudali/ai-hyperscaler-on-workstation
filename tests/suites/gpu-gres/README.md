# GPU GRES Test Suite

Tests SLURM GPU Generic RESources (GRES) configuration and GPU scheduling.

## Test Scripts

- **check-gres-configuration.sh** - Validates gres.conf and GPU resource definitions
- **check-gpu-detection.sh** - Tests SLURM GPU detection and inventory
- **check-gpu-scheduling.sh** - Validates GPU job scheduling and allocation
- **run-gpu-gres-tests.sh** - Main test runner for GPU GRES tests

## Purpose

Ensures SLURM can properly detect, manage, and schedule GPU resources for jobs
requesting GPU allocation.

## Prerequisites

- GPU validation tests passing
- SLURM controller and compute tests passing
- gres.conf configured on compute nodes
- SLURM controller aware of GPU resources

## Usage

```bash
./run-gpu-gres-tests.sh
```

## Dependencies

- basic-infrastructure
- gpu-validation
- slurm-controller
- slurm-compute
