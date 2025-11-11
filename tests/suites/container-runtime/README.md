# Container Runtime Test Suite

Tests Singularity/Apptainer installation, configuration, and container execution on compute nodes.

## Execution Context

**Location**: Executed ON compute nodes (not from controller)  
**Framework**: HPC Runtime Framework  
**Mode**: Compute node validation

## Test Scripts

- **check-singularity-install.sh** - Validates Singularity/Apptainer installation
- **check-container-execution.sh** - Tests basic container execution capabilities
- **check-comprehensive-security.sh** - Validates container security configuration
- **test-utils.sh** - Shared utilities for container testing
- **run-container-runtime-tests.sh** - Main test runner for container runtime tests

## Purpose

Validates that Singularity/Apptainer is properly installed on compute nodes and can execute
containers with appropriate security settings and resource access. Tests container runtime
locally on each compute node before attempting SLURM orchestration.

## Prerequisites

- Basic infrastructure tests passing
- Compute nodes provisioned and accessible
- Singularity/Apptainer installed on compute nodes

## Usage

```bash
./run-container-runtime-tests.sh
```

## Related Suites

- **container-integration** - Tests container execution via SLURM (requires this suite passing)
- **container-e2e** - Tests ML frameworks via SLURM containers (requires this suite passing)

## Dependencies

- basic-infrastructure
- slurm-compute (SLURM must be running on compute nodes)
