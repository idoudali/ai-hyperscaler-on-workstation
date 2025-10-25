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

# Step 03: Container Image Build (5-10 min)
./step-03-container-image-build.sh

# Step 04: Configuration Rendering (5-10 min)
./step-04-config-rendering.sh

# Step 05: Runtime Deployment (10-20 min)
./step-05-runtime-deployment.sh

# Step 06: VirtIO-FS Mount Validation (10-15 min)
./step-06-virtio-fs-validation.sh

# Step 07: BeeGFS Setup Validation (15-20 min)
./step-07-beegfs-validation.sh

# Step 08: Container Image Push (5-10 min)
./step-08-container-image-push.sh

# Step 09: Functional Tests (2-5 min)
./step-09-functional-tests.sh

# Step 10: Regression Tests (1-2 min)
./step-10-regression-tests.sh
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

### Step 03: Container Image Build (5-10 minutes)

Builds container SIF images for deployment testing:

- Builds development Docker image (if not already built)
- Creates test container images using Apptainer/Singularity
- Builds ML framework containers (PyTorch, TensorFlow, etc.)
- Creates custom test containers for validation
- Verifies container images were created successfully
- Tests container image integrity and metadata
- Validates container can be executed
- Prepares container images for registry deployment

**Prerequisites:** Steps 1-2 must have passed (Packer images built)

### Step 04: Configuration Rendering (5-10 minutes)

Validates configuration template rendering and VirtIO-FS mount functionality:

- Tests `ai-how render` command with variable expansion
- Validates template syntax and variable detection
- Tests `make config-render` and `make config-validate` targets
- Verifies VirtIO-FS mount configuration in cluster config
- Tests VirtIO-FS mount handling in runtime playbook
- Validates cluster state directory management

**Prerequisites:** Steps 1-3 must have passed (Packer images built, containers created)

### Step 05: Runtime Deployment (10-20 minutes)

Deploys and validates runtime configuration:

- Checks playbook syntax
- Generates Ansible inventory
- Validates cluster configuration
- Starts cluster VMs
- Tests SSH connectivity
- Deploys runtime configuration
- Analyzes deployment results

**Note:** Cluster remains running for Steps 6-8

### Step 06: VirtIO-FS Mount Validation (10-15 minutes)

Validates VirtIO-FS mount configuration and functionality:

- Validates cluster configuration schema includes VirtIO-FS configuration
- Tests VirtIO-FS mount configuration parsing and validation
- Verifies VirtIO-FS configuration structure and fields
- Tests inventory generation with VirtIO-FS configuration
- Validates configuration template rendering with VirtIO-FS variables
- Tests VirtIO-FS mount configuration in runtime deployment

**Prerequisites:** Step 05 must be completed (cluster running)

### Step 07: BeeGFS Setup Validation (15-20 minutes)

Validates BeeGFS container registry and storage consolidation:

- Validates cluster configuration schema includes BeeGFS configuration
- Tests BeeGFS configuration parsing and validation
- Verifies BeeGFS configuration structure and fields
- Tests BeeGFS deployment via unified runtime playbook
- Verifies all BeeGFS services start correctly
- Tests BeeGFS filesystem mount on all nodes
- Validates container registry uses BeeGFS backend
- Tests container distribution across nodes
- Confirms unified playbook deploys complete HPC + storage stack

**Prerequisites:** Step 06 must be completed (VirtIO-FS validated)

### Step 08: Container Image Push (5-10 minutes)

Pushes container images to the validated storage system:

- Pushes container images from Step 3 to BeeGFS storage
- Verifies container images are accessible on controller
- Tests container image execution on controller
- Verifies container registry structure
- Tests container distribution across compute nodes
- Validates container registry consistency

**Prerequisites:** Step 07 must be completed (BeeGFS validated)

### Step 09: Functional Tests (2-5 minutes)

Tests deployed cluster functionality:

- Checks SLURM cluster info
- Verifies compute node registration
- Tests simple job execution
- Tests container runtime (Apptainer)

**Prerequisites:** Step 08 must be completed (containers pushed)

### Step 10: Regression Tests (1-2 minutes)

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
├── 03-container-image-build/         # Step 03 logs and results
├── 04-config-rendering/              # Step 04 logs and results
├── 05-runtime-playbook/              # Step 05 logs and results
├── 06-storage-consolidation/         # Step 06 logs and results
├── 07-functional-tests/              # Step 07 logs and results
└── 08-regression-tests/              # Step 08 logs and results
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

## SSH Configuration

All scripts use non-interactive SSH with the following options to prevent prompts:

- `StrictHostKeyChecking=no` - Auto-accept new host keys
- `UserKnownHostsFile=/dev/null` - Don't save host keys
- `BatchMode=yes` - Prevent interactive prompts
- `LogLevel=ERROR` - Suppress SSH warnings
- `ConnectTimeout=10` - Timeout after 10 seconds

This ensures validation can run without human interaction for host key acceptance.

## Troubleshooting

### SSH Host Key Prompts

If you see SSH host key fingerprint prompts, the SSH_OPTS may not be properly configured. All validation scripts
should use:

```bash
SSH_OPTS="-i ${SSH_KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR"
```

After cluster rebuilds, you can clean old SSH keys with:

```bash
make clean-ssh-keys  # From project root or tests/ directory
```

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
