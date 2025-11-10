# Container Runtime Test Suite

Tests Singularity/Apptainer installation, configuration, and container execution.

## Test Scripts

- **check-singularity-install.sh** - Validates Singularity/Apptainer installation
- **check-container-execution.sh** - Tests basic container execution capabilities
- **check-comprehensive-security.sh** - Validates container security configuration
- **test-utils.sh** - Shared utilities for container testing
- **run-container-runtime-tests.sh** - Main test runner for container runtime tests

## Purpose

Ensures Singularity/Apptainer is properly installed and can execute containers with
appropriate security settings and resource access.

## Prerequisites

- Basic infrastructure tests passing
- Singularity/Apptainer installed on compute nodes
- Test container images available

## Usage

```bash
./run-container-runtime-tests.sh
```

## Dependencies

- basic-infrastructure
