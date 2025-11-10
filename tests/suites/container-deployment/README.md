# Container Deployment Test Suite

Tests container image deployment, registry catalog management, and SLURM integration.

## Test Scripts

- **check-single-image-deploy.sh** - Tests single container image deployment
- **check-multi-node-sync.sh** - Validates image synchronization across nodes
- **check-image-integrity.sh** - Tests container image integrity and checksums
- **check-registry-catalog.sh** - Validates registry catalog and metadata
- **check-slurm-container-exec.sh** - Tests container execution via SLURM
- **run-image-deployment-tests.sh** - Main test runner for deployment tests

## Purpose

Verifies that container images can be deployed to the registry, synchronized across
nodes, and executed through SLURM's container plugin.

## Prerequisites

- Container runtime and registry tests passing
- SLURM container plugin configured
- Deployment tools available

## Usage

```bash
./run-image-deployment-tests.sh
```

## Dependencies

- basic-infrastructure
- container-runtime
- container-registry
- slurm-controller
- slurm-compute
