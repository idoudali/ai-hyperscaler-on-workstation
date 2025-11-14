# Container Deployment Test Suite

Tests container image deployment, registry catalog management, and multi-node synchronization.

## Execution Context

**Location**: Executed FROM controller via SSH  
**Framework**: Container Registry Framework  
**Mode**: Image deployment and synchronization

## Test Scripts

- **check-single-image-deploy.sh** - Tests single container image deployment to registry
- **check-multi-node-sync.sh** - Validates image synchronization and availability across nodes
- **check-image-integrity.sh** - Tests container image integrity and checksums
- **check-registry-catalog.sh** - Validates registry catalog, permissions, and metadata
- **run-container-deployment-tests.sh** - Main test runner for deployment tests

**Note:** SLURM container execution is tested in:

- `container-runtime/` - Direct container execution on compute nodes
- `container-integration/` - SLURM job submission with containers

## Purpose

Verifies that:

1. Container images are correctly deployed to the registry
2. Images are synchronized and accessible on all compute nodes
3. Image integrity is maintained across nodes
4. Registry metadata and catalog are properly maintained

## Prerequisites

- Container registry infrastructure deployed
- All compute nodes accessible and healthy
- Deployment tools configured

## Usage

```bash
./run-container-deployment-tests.sh
```

## Related Suites

- **container-registry** - Related: registry infrastructure (prerequisite)
- **container-runtime** - Related: basic container execution validation
- **container-integration** - Related: SLURM-based container execution

## Dependencies

- basic-infrastructure
- container-registry (must run first)
- slurm-controller
- slurm-compute
