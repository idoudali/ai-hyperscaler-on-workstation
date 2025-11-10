# SLURM Controller Test Suite

Tests SLURM controller installation, configuration, authentication, and core functionality.

## Test Scripts

- **check-slurm-installation.sh** - Validates SLURM controller packages and binaries
- **check-munge-authentication.sh** - Tests MUNGE authentication between nodes
- **check-slurm-functionality.sh** - Verifies core SLURM operations and job submission
- **check-job-accounting.sh** - Tests job accounting database integration
- **check-pmix-integration.sh** - Validates PMIx/PMI2 integration for MPI jobs
- **check-container-plugin.sh** - Tests SLURM container plugin configuration
- **run-slurm-controller-tests.sh** - Main test runner for controller tests

## Purpose

Validates that the SLURM controller is properly installed, configured, and can manage
cluster resources and job submissions.

## Prerequisites

- Basic infrastructure tests passing
- SLURM controller node deployed and configured
- MariaDB/MySQL database for accounting

## Usage

```bash
./run-slurm-controller-tests.sh
```

## Dependencies

- basic-infrastructure
