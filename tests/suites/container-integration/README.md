# Container Integration Test Suite

Tests SLURM container orchestration with GPU resources, MPI communication, and distributed training.

## Execution Context

**Location**: Executed FROM controller via SLURM job submission  
**Framework**: HPC Runtime Framework  
**Mode**: Cluster orchestration via SLURM

## Test Scripts

- **check-container-slurm-integration.sh** - Validates SLURM container plugin integration
- **check-pytorch-cuda-integration.sh** - Tests PyTorch GPU access within containers via SLURM
- **check-mpi-communication.sh** - Validates MPI communication between containerized SLURM jobs
- **check-distributed-training.sh** - Tests multi-node distributed training via SLURM containers
- **run-container-integration-tests.sh** - Main test runner for integration tests

**Note:** Basic container functionality tests are in `container-runtime/` suite (runs on compute nodes)

## Purpose

Validates that:

1. SLURM container plugin is properly configured
2. Containers can access GPUs when run through SLURM
3. MPI communication works between containerized jobs
4. Distributed training workflows execute correctly through SLURM

All tests execute via SLURM job submission from the controller node.

## Prerequisites

- Container runtime tests passing (ensures Apptainer works on compute nodes)
- GPU GRES configured and working
- MPI libraries available
- ML framework containers deployed to registry
- SLURM compute nodes registered and healthy

## Usage

```bash
./run-container-integration-tests.sh
```

## Related Suites

- **container-runtime** - Prerequisite: validates basic container execution on compute nodes
- **container-e2e** - Related: tests complete ML workflows (depends on this suite)
- **container-registry** - Related: manages container images used by these tests

## Dependencies

- basic-infrastructure
- container-runtime (must run first)
- container-registry
- gpu-gres
- slurm-controller
- slurm-compute
- cgroup-isolation
