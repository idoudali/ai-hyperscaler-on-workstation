# SLURM Compute Test Suite

Tests SLURM compute node deployment, registration, and distributed job execution.

## Test Scripts

- **check-compute-installation.sh** - Validates compute node package installation
- **check-compute-registration.sh** - Tests compute node registration with controller
- **check-multi-node-communication.sh** - Verifies inter-node communication
- **check-distributed-jobs.sh** - Tests multi-node job execution
- **run-slurm-compute-tests.sh** - Main test runner for compute node tests

## Purpose

Ensures SLURM compute nodes are properly configured, registered with the controller,
and can execute distributed workloads across multiple nodes.

## Prerequisites

- SLURM controller tests passing
- Compute nodes deployed and configured
- MUNGE keys synchronized across cluster

## Usage

```bash
./run-slurm-compute-tests.sh
```

## Dependencies

- basic-infrastructure
- slurm-controller
