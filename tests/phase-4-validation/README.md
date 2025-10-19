# Phase 4 Validation Framework

Comprehensive validation framework for HPC infrastructure consolidation.

## Overview

This validation framework provides automated testing and verification for the Phase 4 consolidation of HPC
playbooks and infrastructure. It validates Packer image builds, runtime deployments, and functional cluster
operations.

## Quick Start

### Run Full Validation

```bash
# Run all validation steps
./run-all-steps.sh

# Run with verbose logging
./run-all-steps.sh --verbose
```

### Run Individual Steps

```bash
# Step 00: Prerequisites (required first)
./step-00-prerequisites.sh

# Step 01: Packer Controller Build (15-30 min)
./step-01-packer-controller.sh

# Step 02: Packer Compute Build (15-30 min)
./step-02-packer-compute.sh

# Step 03: Runtime Deployment (10-20 min)
./step-03-runtime-deployment.sh

# Step 04: Functional Tests (2-5 min)
./step-04-functional-tests.sh

# Step 05: Regression Tests (1-2 min)
./step-05-regression-tests.sh
```

## Resume from Existing Validation

If validation is interrupted or a step fails, you can resume from an existing validation directory:

```bash
# Resume using --resume option
./run-all-steps.sh --resume validation-output/phase-4-validation-20251019-143022

# Resume using --validation-folder option
./run-all-steps.sh --validation-folder validation-output/phase-4-validation-20251019-143022

# Resume using environment variable
VALIDATION_ROOT=validation-output/phase-4-validation-20251019-143022 ./run-all-steps.sh

# Resume individual step
./step-01-packer-controller.sh --resume validation-output/phase-4-validation-20251019-143022
```

### How Resume Works

- The framework tracks completed steps in `.state/` directory within the validation folder
- When resuming, completed steps are automatically skipped
- Each step checks its completion status and displays the timestamp if already completed
- You can view completed steps by inspecting the `.state/` directory:

```bash
ls -la validation-output/phase-4-validation-20251019-143022/.state/
```

### Resume Use Cases

1. **Step Failure**: If Step 02 fails, fix the issue and resume - Steps 00 and 01 will be skipped
2. **Interrupted Run**: If validation is interrupted (Ctrl+C), resume to continue from last completed step
3. **Testing**: Run specific steps against an existing validation to test fixes or changes
4. **Debugging**: Keep validation directory and re-run specific steps with different logging levels

## Command-Line Options

All scripts support the following options:

- `-v, --verbose`: Enable verbose command logging (shows all executed commands)
- `--log-level LEVEL`: Set log level (DEBUG, INFO)
- `--resume PATH`: Resume from existing validation directory
- `--validation-folder PATH`: Specify validation directory (alias for --resume)
- `-h, --help`: Show help message

## Validation Steps

### Step 00: Prerequisites (5-10 minutes)

Verifies and prepares the environment:

- Docker installation and version
- CMake configuration
- pharos-dev Docker image build
- Container tools (Packer, Ansible, CMake)
- SLURM packages (builds from source)
- Cluster configuration files
- Ansible playbooks

### Step 01: Packer Controller Build (15-30 minutes)

Builds the HPC controller VM image:

- Validates Packer template syntax
- Builds controller image via CMake/Docker
- Verifies image artifacts (*.qcow2)
- Analyzes Ansible execution results
- Confirms no task failures

Output: `build/packer/hpc-controller/hpc-controller/*.qcow2`

### Step 02: Packer Compute Build (15-30 minutes)

Builds the HPC compute VM image:

- Validates Packer template syntax
- Builds compute image via CMake/Docker
- Verifies image artifacts (*.qcow2)
- Analyzes Ansible execution results
- Confirms GPU driver installation

Output: `build/packer/hpc-compute/hpc-compute/*.qcow2`

### Step 03: Runtime Deployment (10-20 minutes)

Deploys and validates runtime configuration:

- Checks playbook syntax
- Generates Ansible inventory
- Validates cluster configuration
- Starts cluster VMs
- Tests SSH connectivity
- Deploys runtime configuration
- Analyzes deployment results

**Note:** Cluster remains running for Steps 4-5

### Step 04: Functional Tests (2-5 minutes)

Tests deployed cluster functionality:

- Checks SLURM cluster info
- Verifies compute node registration
- Tests simple job execution
- Tests container runtime (Apptainer)

**Prerequisites:** Step 03 must be completed (cluster running)

### Step 05: Regression Tests (1-2 minutes)

Validates consolidation against backups:

- Compares consolidated playbook against backups
- Analyzes playbook structure
- Verifies feature preservation
- Generates comparison report

## Output Structure

Validation outputs are saved to timestamped directories:

```bash
validation-output/phase-4-validation-YYYYMMDD-HHMMSS/
├── .state/                           # State tracking directory
│   ├── step-00-prerequisites.completed
│   ├── step-01-packer-controller.completed
│   └── ...
├── validation-info.txt               # Environment and version information
├── 00-prerequisites/                 # Step 00 logs and results
│   ├── validation-summary.txt
│   ├── cmake-config.log
│   ├── docker-build.log
│   └── slurm-packages-build.log
├── 01-packer-controller/             # Step 01 logs and results
│   ├── validation-summary.txt
│   ├── packer-validate.log
│   ├── packer-build.log
│   └── packer-build-error.log
├── 02-packer-compute/                # Step 02 logs and results
├── 03-runtime-playbook/              # Step 03 logs and results
├── 04-functional-tests/              # Step 04 logs and results
└── 05-regression-tests/              # Step 05 logs and results
```

## Environment Variables

- `VALIDATION_VERBOSE=1`: Enable verbose logging (shows all commands)
- `VALIDATION_LOG_LEVEL=DEBUG`: Set log level to DEBUG
- `VALIDATION_ROOT=path`: Specify validation directory for resume

## Examples

### Full Validation with Verbose Logging

```bash
./run-all-steps.sh --verbose
```

### Resume After Failure

```bash
# Initial run fails at Step 02
./run-all-steps.sh

# Fix issue, then resume
./run-all-steps.sh --resume validation-output/phase-4-validation-20251019-143022
```

### Run Individual Step with Existing Validation

```bash
# Re-run Step 01 against existing validation (for debugging)
./step-01-packer-controller.sh --resume validation-output/phase-4-validation-20251019-143022
```

### Debug Specific Step

```bash
# Run with DEBUG logging level
./step-03-runtime-deployment.sh --log-level DEBUG
```

## Cleanup

After validation is complete, stop the cluster:

```bash
make cluster-stop CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml CLUSTER_NAME=hpc
```

## Troubleshooting

### Step Already Completed Warning

If you see "Step XX already completed", the framework detected this step was already run. This is normal when
resuming. To force re-run, manually remove the state file:

```bash
rm validation-output/phase-4-validation-TIMESTAMP/.state/step-XX-*.completed
```

### Prerequisites Not Completed Error

Steps 1-3 require prerequisites. Always run Step 00 first or ensure it was completed in the resume directory:

```bash
./step-00-prerequisites.sh --resume validation-output/phase-4-validation-TIMESTAMP
```

### Invalid Validation Directory

If you get "This does not appear to be a valid validation directory", verify:

1. The directory exists
2. The `.state/` subdirectory is present
3. You're pointing to the correct validation root directory

## Integration with CI/CD

The validation framework can be integrated into CI/CD pipelines:

```bash
#!/bin/bash
# CI/CD validation script

set -euo pipefail

# Run validation
if ./tests/phase-4-validation/run-all-steps.sh; then
  echo "✅ Phase 4 validation PASSED"
  exit 0
else
  echo "❌ Phase 4 validation FAILED"
  exit 1
fi
```

## Requirements

- Docker
- CMake
- Make
- Bash 4.0+
- Project configured: `make config`
- Docker image built: `make build-docker`
