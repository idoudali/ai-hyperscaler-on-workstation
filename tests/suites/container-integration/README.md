# Container Integration Test Suite

Tests container integration with GPU resources, MPI communication, and distributed training.

## Test Scripts

- **check-container-functionality.sh** - Tests basic container operations
- **check-container-slurm-integration.sh** - Validates SLURM container plugin integration
- **check-pytorch-cuda-integration.sh** - Tests PyTorch GPU access within containers
- **check-mpi-communication.sh** - Validates MPI communication between containerized jobs
- **check-distributed-training.sh** - Tests multi-node distributed training in containers
- **run-container-integration-tests.sh** - Main test runner for integration tests

## Purpose

Ensures containers can properly access GPUs, communicate via MPI, and run distributed
workloads across multiple nodes.

## Prerequisites

- Container deployment tests passing
- GPU GRES configured
- MPI libraries available
- ML framework containers deployed

## Usage

```bash
./run-container-integration-tests.sh
```

## Dependencies

- basic-infrastructure
- container-runtime
- container-registry
- container-deployment
- gpu-gres
- slurm-controller
- slurm-compute
