# Distributed Training Test Suite

This directory contains the automated test framework used to validate the distributed training infrastructure,
ensuring that SLURM, Apptainer, NCCL, and the monitoring stack are correctly configured and operational.

## Test Framework Overview

The test suite is built using **BATS (Bash Automated Testing System)** and validates the following core capabilities:

- **Container Environment**: Verifies PyTorch, CUDA, MPI, and NCCL availability within the Apptainer container.
- **Job Submission**: Ensures SLURM jobs can be submitted, queued, and executed.
- **Distributed Training**: Validates actual multi-node training using a reference MNIST DDP (Distributed Data
  Parallel) implementation.
- **Monitoring**: Checks that TensorBoard, Aim, and MLflow services are accessible and can receive data.

## Running Tests

To run the full suite of distributed training tests:

```bash
cd tests/suites/distributed-training
./run-distributed-training-tests.sh
```

This wrapper script executes all BATS tests defined in the suite, generating TAP-formatted output and logs in
`tests/suites/distributed-training/logs/`.

## Test Structure

### Core Components

- **`check-pytorch-environment.bats`**: Validates the container environment.
  - Checks for PyTorch, CUDA, and MPI availability.
  - Verifies NCCL backend support.
  - Tests multi-node container execution.
- **`check-mnist-ddp-job.bats`**: Validates an end-to-end distributed training job.
  - Submits a real MNIST DDP training job to SLURM.
  - Monitors the job for completion.
  - Verifies that training logs show successful convergence (>95% accuracy).
  - Checks for NCCL errors and confirms multi-node execution.
- **`check-monitoring-infrastructure.bats`**: Validates the monitoring stack.
  - Checks existence of monitoring directories on BeeGFS.
  - Verifies Python clients can connect to servers.
  - Runs integration tests for TensorBoard, Aim, and MLflow.

### Helper Libraries

The tests rely on shared helper functions defined in the `helpers/` directory:

- **`helpers/training-helpers.bash`**:
  - `submit_mnist_job`: Submits SLURM jobs with dynamic memory configuration.
  - `wait_for_job`: Polls SLURM for job completion with timeouts.
  - `check_job_log`: Scans logs for success patterns and errors.
  - `extract_accuracy`: Parses training logs for performance metrics.
- **`helpers/container-helpers.bash`**: Utilities for checking Apptainer images and GPU availability.
- **`helpers/monitoring-helpers.bash`**: Utilities for verifying monitoring service status.

## Test Artifacts

Test logs and output files are stored in:
`tests/suites/distributed-training/logs/`

Each test run creates a timestamped directory containing:

- **TAP output**: Standard test protocol output.
- **Job Logs**: SLURM output (`.out`) and error (`.err`) files for any jobs submitted during the test.
- **Cluster Plan**: JSON description of the test cluster configuration.
