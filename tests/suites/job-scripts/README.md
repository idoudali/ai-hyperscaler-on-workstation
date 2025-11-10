# Job Scripts Test Suite

Tests SLURM prolog/epilog scripts, job lifecycle hooks, and failure detection mechanisms.

## Test Scripts

- **check-epilog-prolog.sh** - Validates prolog and epilog script execution
- **check-failure-detection.sh** - Tests job failure detection and error handling
- **check-debug-collection.sh** - Validates debug information collection on failures
- **setup-local-test-env.sh** - Sets up local test environment
- **teardown-local-test-env.sh** - Cleans up test environment
- **run-job-scripts-tests.sh** - Main test runner for job script tests

## Purpose

Ensures SLURM prolog/epilog scripts are properly configured and execute correctly
during job lifecycle events, including failure scenarios and debug collection.

## Prerequisites

- SLURM controller and compute tests passing
- Prolog/epilog scripts deployed to SLURM nodes
- Job script configuration in slurm.conf

## Usage

```bash
./run-job-scripts-tests.sh
```

## Dependencies

- basic-infrastructure
- slurm-controller
- slurm-compute
