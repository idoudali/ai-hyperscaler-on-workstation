# HPC Packer Test Frameworks

Consolidated test frameworks for validating the HPC cluster deployment, including SLURM
controller, compute nodes, and job execution.

## Overview

The unified SLURM test framework validates:

1. **SLURM Controller** - Cluster manager and scheduling components
2. **SLURM Compute Nodes** - Job execution and resource allocation
3. **BeeGFS Shared Storage** - Cross-node file accessibility
4. **SLURM Job Examples** - Real-world parallel job execution (Tutorial 08)

## Cluster Configuration

All tests use the multi-GPU cluster configuration defined in `config/example-multi-gpu-clusters.yaml`:

- **Controller**: 4 cores, 8GB RAM, IP 192.168.100.10
- **Compute-01**: 8 cores, 16GB RAM, IP 192.168.100.11 (GPU passthrough)
- **Compute-02**: 8 cores, 16GB RAM, IP 192.168.100.12 (GPU passthrough)
- **Network**: 192.168.100.0/24, bridge virbr100
- **BeeGFS**: Shared mount at `/mnt/beegfs` with management on controller, storage on compute nodes
- **SLURM Partitions**: `gpu` (default), `debug`

## Unified SLURM Framework

### File

`tests/frameworks/test-hpc-packer-slurm-framework.sh`

### Usage

```bash
# Full SLURM testing (controller + compute + job examples)
./tests/frameworks/test-hpc-packer-slurm-framework.sh

# Test only controller components
./tests/frameworks/test-hpc-packer-slurm-framework.sh --mode controller

# Test only compute components
./tests/frameworks/test-hpc-packer-slurm-framework.sh --mode compute

# Full testing without job examples
./tests/frameworks/test-hpc-packer-slurm-framework.sh --skip-examples

# End-to-end workflow: start cluster, deploy, run all tests
./tests/frameworks/test-hpc-packer-slurm-framework.sh e2e

# Start cluster only
./tests/frameworks/test-hpc-packer-slurm-framework.sh start-cluster

# Stop cluster only
./tests/frameworks/test-hpc-packer-slurm-framework.sh stop-cluster

# Deploy SLURM configuration
./tests/frameworks/test-hpc-packer-slurm-framework.sh deploy-ansible

# Check cluster status
./tests/frameworks/test-hpc-packer-slurm-framework.sh status

# Show help
./tests/frameworks/test-hpc-packer-slurm-framework.sh help
```

### Commands

- `e2e` / `end-to-end` - Run end-to-end SLURM testing workflow
- `start-cluster` - Start the SLURM cluster (VMs)
- `stop-cluster` - Stop the SLURM cluster
- `deploy-ansible` - Deploy SLURM configuration via Ansible
- `run-tests` - Run configured test suites only
- `status` - Check cluster status
- `list-tests` - List available test suites
- `help` / `--help` - Show help message

### Options

- `--mode PATTERN` - Set test mode: `controller`, `compute`, or `full` (default: `full`)
- `--skip-examples` - Skip SLURM job example tests

### Environment Variables

- `TEST_MODE` - Test mode (controller, compute, full)
- `SKIP_JOB_EXAMPLES` - Skip job example tests (true/false)
- `TARGET_VM_PATTERN` - VM pattern for testing
- `CONTROLLER_IP` - Controller IP address (for remote testing)
- `SSH_KEY_PATH` - Path to SSH private key
- `SSH_USER` - SSH user for remote testing

## Test Suites

### Controller Tests (`tests/suites/slurm-controller/`)

Validates SLURM controller installation and functionality:

- SLURM package installation and dependencies
- Basic SLURM functionality and configuration
- PMIx integration and configuration
- MUNGE authentication system
- Container plugin configuration
- Job accounting and database integration

**Run**: `cd tests/suites/slurm-controller && ./run-slurm-controller-tests.sh`

### Compute Tests (`tests/suites/slurm-compute/`)

Validates SLURM compute node setup:

- Compute node installation
- Compute node registration with controller
- Distributed job execution
- Multi-node communication

**Run**: `cd tests/suites/slurm-compute && ./run-slurm-compute-tests.sh`

### Job Example Tests (`tests/suites/slurm-job-examples/`)

Tests real-world SLURM job execution using Tutorial 08 examples:

#### Tests Included

1. **BeeGFS Shared Storage** (`check-beegfs-shared-storage.sh`)
   - Verify BeeGFS mounted on all nodes
   - Test cross-node file access
   - Validate concurrent I/O operations
   - Check file permissions and storage space

2. **Hello World MPI** (`check-hello-world-job.sh`)
   - Build hello-world MPI example using Docker
   - Submit multi-node job to SLURM
   - Verify correct rank distribution across nodes
   - Validate output files on BeeGFS

3. **Pi Calculation** (`check-pi-calculation-job.sh`)
   - Build pi-monte-carlo executable
   - Submit computational parallel job
   - Verify pi estimation accuracy
   - Check parallel scaling across nodes

4. **Matrix Multiply** (`check-matrix-multiply-job.sh`)
   - Build matrix-mult executable
   - Submit memory-intensive job
   - Verify memory allocation
   - Validate resource constraints

**Run**: `cd tests/suites/slurm-job-examples && ./run-slurm-job-examples-tests.sh`

#### Job Examples Directory Structure

All job examples are stored on BeeGFS at `/mnt/beegfs/slurm-jobs/`:

- `hello-world/` - Hello world MPI binaries and scripts
- `pi-calculation/` - Pi monte carlo binaries and scripts
- `matrix-multiply/` - Matrix multiply binaries and scripts

## BeeGFS Integration

The test framework leverages BeeGFS shared storage for:

- Storing compiled job binaries that are accessible from all nodes
- Writing job output files that persist after job completion
- Testing cross-node file I/O and concurrent access patterns

### BeeGFS Configuration

- **Mount Point**: `/mnt/beegfs`
- **Management Node**: Controller (192.168.100.10)
- **Metadata Servers**: Controller
- **Storage Servers**: Compute-01, Compute-02
- **Accessibility**: All nodes (controller + compute)

### Using BeeGFS in Tests

1. Build binaries using Docker on laptop:

   ```bash
   make run-docker COMMAND="cmake --build build --target build-hello-world"
   ```

2. Copy to BeeGFS:

   ```bash
   scp -i build/shared/ssh-keys/id_rsa -r build/examples/slurm-jobs \
       admin@<controller-ip>:/mnt/beegfs/
   ```

3. Submit jobs from controller:

   ```bash
   cd /mnt/beegfs/slurm-jobs/hello-world
   sbatch hello.sbatch
   ```

4. Verify output on shared storage:

   ```bash
   # Output files accessible from all nodes
   cat /mnt/beegfs/slurm-jobs/hello-world/slurm-*.out
   ```

## Test Execution Flow

### Full End-to-End Workflow

```text
1. Start Cluster
   └─ Create and start VMs (controller + compute nodes)

2. Deploy Ansible
   └─ Configure SLURM, BeeGFS, monitoring stack

3. Run Tests
   ├─ SLURM Controller Tests
   │  ├─ Installation validation
   │  ├─ Functionality tests
   │  ├─ PMIx integration
   │  ├─ MUNGE authentication
   │  ├─ Container plugin
   │  └─ Job accounting
   │
   ├─ SLURM Compute Tests
   │  ├─ Compute node registration
   │  ├─ Multi-node communication
   │  └─ Distributed jobs
   │
   └─ SLURM Job Examples
      ├─ BeeGFS shared storage validation
      ├─ Hello World MPI job
      ├─ Pi Calculation job
      └─ Matrix Multiply job
```

## Test Output

Test results are saved in `logs/` directory with timestamp:

- `logs/run-YYYY-MM-DD_HH-MM-SS/` - Log directory for each test run
- `test_report_summary.txt` - Summary of test results
- Individual test logs for each test script

## Troubleshooting

### Tests Fail with SSH Errors

Ensure SSH key and configuration are correct:

```bash
# Verify SSH access
ssh -i build/shared/ssh-keys/id_rsa -o StrictHostKeyChecking=no admin@192.168.100.10 "echo OK"
```

### BeeGFS Not Accessible

Check BeeGFS mount status:

```bash
# On controller
ssh admin@192.168.100.10 "df /mnt/beegfs"

# From compute nodes
ssh admin@192.168.100.10 "srun --nodes=2 df /mnt/beegfs"
```

### Job Examples Not Building

Ensure Docker image is built:

```bash
cd /path/to/project
make build-docker
make config
```

### SLURM Not Running

Check cluster status:

```bash
./tests/frameworks/test-hpc-packer-slurm-framework.sh status
```

Restart services if needed:

```bash
./tests/frameworks/test-hpc-packer-slurm-framework.sh deploy-ansible
```

## Related Documentation

- **SLURM Tutorials**: See `docs/tutorials/slurm/` for detailed guides
  - Tutorial 08: SLURM Basics (hello-world, pi-calculation, matrix-multiply)
  - Tutorial 09: Job Arrays and Dependencies (placeholder)
  - Tutorial 10: GPU Jobs and Containers (placeholder)
  - Tutorial 11: SLURM Debugging and Troubleshooting

- **Cluster Configuration**: `config/example-multi-gpu-clusters.yaml`
- **Infrastructure Code**: `terraform/`, `ansible/`
- **Project Documentation**: `docs/`

## Development Guide

### Adding New Tests

1. Create test script in `tests/suites/<suite-name>/check-<test-name>.sh`
2. Add test script to `TEST_SCRIPTS` array in `run-<suite-name>-tests.sh`
3. Follow test script conventions from existing tests
4. Test locally before committing

### Test Script Template

```bash
#!/bin/bash
# Test: [Description]

set -euo pipefail

TEST_NAME="[Test Name]"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

main() {
    log_info "Starting $TEST_NAME"
    
    # Test logic here
    
    log_info "✓ $TEST_NAME passed"
}

main "$@"
```

## Maintenance

- Update test suites when SLURM configuration changes
- Keep BeeGFS configuration synchronized across nodes
- Review test logs regularly for patterns or recurring issues
- Document any workarounds or special configurations needed

---

*Last Updated: 2025-01-30*
