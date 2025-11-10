# Container End-to-End Test Suite

Tests complete end-to-end workflows for ML framework deployment and execution.

## Test Scripts

- **test-pytorch-deployment.sh** - End-to-end PyTorch container deployment and training
- **test-tensorflow-deployment.sh** - End-to-end TensorFlow container deployment and training
- **test-multi-image-deploy.sh** - Tests deployment of multiple framework images
- **test-job-container-execution.sh** - Tests complete job lifecycle with containers
- **run-container-e2e-tests.sh** - Main test runner for E2E tests

## Purpose

Validates complete end-to-end workflows from container deployment through job submission
and execution for real ML frameworks.

## Prerequisites

- All container integration tests passing
- ML framework images available
- GPU resources accessible
- Distributed training infrastructure ready

## Usage

```bash
./run-container-e2e-tests.sh
```

## Dependencies

- basic-infrastructure
- container-runtime
- container-registry
- container-deployment
- container-integration
- gpu-gres
- slurm-controller
- slurm-compute
