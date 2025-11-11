# Container End-to-End Test Suite

Tests complete end-to-end ML framework workflows via SLURM container orchestration.

## Execution Context

**Location**: Executed FROM controller via SLURM job submission  
**Framework**: HPC Runtime Framework  
**Mode**: End-to-end ML workflows

## Test Scripts

- **test-pytorch-deployment.sh** - End-to-end PyTorch training via SLURM containers ✨ (now uses srun)
- **test-tensorflow-deployment.sh** - End-to-end TensorFlow training via SLURM containers ✨ (now uses srun)
- **test-multi-image-deploy.sh** - Tests deployment of multiple framework images
- **test-job-container-execution.sh** - Tests complete job lifecycle with containers (already used SLURM)
- **run-container-e2e-tests.sh** - Main test runner for E2E tests

## Purpose

Validates complete end-to-end workflows for ML frameworks running through SLURM:

1. Container image deployment and availability
2. Job submission via SLURM scheduler
3. GPU resource allocation and access within containers
4. Multi-node distributed training
5. Complete job lifecycle (queuing, execution, completion)

All tests use SLURM job submission (srun/sbatch) for realistic production workflows.

## Prerequisites

- Container runtime and integration tests passing
- ML framework images deployed to registry and synchronized
- GPU GRES configured and available
- Distributed training infrastructure ready
- SLURM controller and compute nodes healthy

## Usage

```bash
./run-container-e2e-tests.sh
```

## Test Scenarios

### Single-Node Training

- PyTorch distributed training on single GPU-equipped compute node
- TensorFlow training on single GPU-equipped compute node

### Multi-Node Training

- Multi-image deployments tested across nodes
- Complete job lifecycle validation

## Related Suites

- **container-runtime** - Prerequisite: basic container execution
- **container-integration** - Related: GPU + MPI + container tests
- **container-registry/deployment** - Prerequisites: image infrastructure

## Dependencies

- basic-infrastructure
- container-runtime (must run first)
- container-registry
- container-deployment
- container-integration (should run after)
- gpu-gres
- slurm-controller
- slurm-compute
- cgroup-isolation
