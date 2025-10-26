# Testing Framework Developer Guide

**Status:** Production (Stream B - Test Infrastructure Consolidation)
**Created:** 2025-10-24
**Last Updated:** 2025-10-27

**Location:** `tests/` directory with infrastructure in `tests/test-infra/`

## Overview

The pharos.ai-hyperscaler testing framework is a sophisticated **Bash-based infrastructure testing
system** that validates HPC SLURM deployments, containerization, GPU support, distributed storage,
and monitoring across real virtual machines. It combines modular test suites with automated cluster
provisioning via the AI-HOW CLI.

**NEW (Phase 3-4):** Framework consolidation has reduced 15+ individual frameworks into 7 unified
frameworks using shared Phase 2 utilities (framework-cli.sh, framework-orchestration.sh), achieving
**71% code reduction** (2,338 lines eliminated).

## Quick Start

### Run Unified Framework (Recommended)

```bash
cd tests

# Run complete HPC Runtime test (consolidates 6 test suites)
./test-hpc-runtime-framework.sh

# Run with modular workflow (for debugging)
./test-hpc-runtime-framework.sh start-cluster
./test-hpc-runtime-framework.sh deploy-ansible
./test-hpc-runtime-framework.sh run-tests
./test-hpc-runtime-framework.sh stop-cluster

# Or use Makefile targets
make test-hpc-runtime
make test-hpc-runtime-start
```

### Run All Tests (CI/CD)

```bash
cd tests
make test-all
```

### Run Other Unified Frameworks

```bash
# HPC Packer Controller (4 consolidated suites)
./test-hpc-packer-controller-framework.sh

# HPC Packer Compute (1 test suite)
./test-hpc-packer-compute-framework.sh

# Refactored BeeGFS Framework (60% code reduction)
./test-beegfs-framework.sh

# Refactored Virtio-FS Framework (77% code reduction)
./test-virtio-fs-framework.sh

# Refactored PCIe Passthrough Framework (55% code reduction)
./test-pcie-passthrough-framework.sh

# Refactored Container Registry Framework (86% code reduction)
./test-container-registry-framework.sh
```

### Quick Validation (Pre-commit only)

```bash
make test-precommit
```

## Framework Architecture

### Directory Structure

```text
tests/
├── README.md                           # Main testing documentation
├── Makefile                            # Test targets (42+ unified framework targets + legacy)
├── test-hpc-runtime-framework.sh       # 7 UNIFIED TEST FRAMEWORKS (Phase 3-4)
├── test-hpc-packer-controller-framework.sh
├── test-hpc-packer-compute-framework.sh
├── test-beegfs-framework.sh            # (Refactored: 60% reduction)
├── test-virtio-fs-framework.sh         # (Refactored: 77% reduction)
├── test-pcie-passthrough-framework.sh  # (Refactored: 55% reduction)
├── test-container-registry-framework.sh # (Refactored: 86% reduction)
│
├── test-infra/
│   ├── README.md                       # Infrastructure guide
│   ├── configs/                        # 17 YAML test configurations
│   ├── utils/
│   │   ├── framework-cli.sh           # PHASE 2: Standardized CLI parsing (459 lines)
│   │   ├── framework-orchestration.sh # PHASE 2: Cluster lifecycle management (505 lines)
│   │   ├── framework-template.sh      # PHASE 2: Template for new frameworks (423 lines)
│   │   ├── log-utils.sh               # Color-coded logging
│   │   ├── cluster-utils.sh           # VM lifecycle management
│   │   ├── ansible-utils.sh           # Ansible integration
│   │   ├── test-framework-utils.sh    # Test orchestration
│   │   ├── vm-utils.sh                # SSH/networking utilities
│   │   └── [others...]
│   ├── inventory/                      # Ansible inventory templates
│   └── .shellcheckrc                   # ShellCheck configuration
│
├── suites/                             # Test suites consolidated into 7 frameworks
│   ├── slurm-compute/                 # (Runtime framework)
│   ├── cgroup-isolation/              # (Runtime framework)
│   ├── gpu-gres/                      # (Runtime framework)
│   ├── job-scripts/                   # (Runtime framework)
│   ├── dcgm-monitoring/               # (Runtime framework)
│   ├── container-integration/         # (Runtime framework)
│   ├── slurm-controller/              # (Controller framework)
│   ├── monitoring-stack/              # (Controller framework)
│   ├── grafana/                       # (Controller framework)
│   ├── slurm-accounting/              # (Controller framework)
│   ├── container-runtime/             # (Compute framework)
│   ├── beegfs/                        # (BeeGFS framework)
│   ├── virtio-fs/                     # (Virtio-FS framework)
│   ├── pcie-passthrough/              # (PCIe Passthrough framework)
│   ├── container-registry/            # (Container Registry framework)
│   └── [others...]
│
└── logs/                               # Timestamped test results and logs
    └── test-run-YYYY-MM-DD_HH-MM-SS/
        ├── framework.log               # Main execution log
        ├── cluster-start-*.log
        ├── cluster-destroy-*.log
        ├── test-results-*.log
        ├── vm-info.csv
        └── [additional artifacts...]
```

### Layer Architecture

```text
Test Orchestration Layer
  ├── Makefile (42+ unified framework targets + legacy targets)
  └── Framework Scripts (7 UNIFIED × test-*-framework.sh)
         │
         ├─→ start-cluster: AI-HOW CLI deploys VMs
         ├─→ deploy-ansible: Ansible provisions services
         ├─→ run-tests: Execute consolidated test suites
         └─→ stop-cluster: Clean up resources

  PHASE 3-4 UNIFIED FRAMEWORKS (971 total lines):
    1. test-hpc-runtime-framework.sh (69 lines)
       └─ Consolidates 6 test suites: slurm-compute, cgroup-isolation, gpu-gres, job-scripts, dcgm-monitoring, container-integration

    2. test-hpc-packer-controller-framework.sh (69 lines)
       └─ Consolidates 4 test suites: slurm-controller, monitoring-stack, grafana, slurm-accounting

    3. test-hpc-packer-compute-framework.sh (69 lines)
       └─ Consolidates 1 test suite: container-runtime

    4. test-beegfs-framework.sh (205 lines)
       └─ Refactored: 521 → 205 lines (60% reduction)

    5. test-virtio-fs-framework.sh (176 lines)
       └─ Refactored: 762 → 176 lines (77% reduction)

    6. test-pcie-passthrough-framework.sh (177 lines)
       └─ Refactored: 393 → 177 lines (55% reduction)

    7. test-container-registry-framework.sh (204 lines)
       └─ Refactored: 1424 → 204 lines (86% reduction)

Test Infrastructure Layer - PHASE 2 SHARED UTILITIES
  ├── Phase 2 Utility Modules (1,387 lines total)
  │   ├── framework-cli.sh (459 lines)
  │   │   └─ Standardized CLI parsing (parse_framework_cli, show_framework_help)
  │   ├── framework-orchestration.sh (505 lines)
  │   │   └─ Cluster lifecycle management (run_framework_e2e_workflow)
  │   └── framework-template.sh (423 lines)
  │       └─ Template for new framework development
  │
  ├── Core Utility Modules (7 .sh files)
  │   ├── log-utils.sh (color-coded logging)
  │   ├── cluster-utils.sh (VM lifecycle)
  │   ├── test-framework-utils.sh (orchestration)
  │   ├── ansible-utils.sh (Ansible integration)
  │   ├── vm-utils.sh (SSH/networking)
  │   ├── ssh-key-cleanup.sh (keys)
  │   └── extract-cluster-ips.sh (IP extraction)
  │
  ├── Test Configuration (17 YAML files)
  │   ├── test-minimal.yaml
  │   ├── test-slurm-controller.yaml
  │   ├── test-slurm-compute.yaml
  │   ├── test-gpu-gres.yaml
  │   └── [13 others...]
  │
  └── Test Suites (15+ test suites consolidated into 7 frameworks)
      ├── slurm-compute (7 checks)
      ├── slurm-controller (6 checks)
      ├── container-runtime (8 checks)
      ├── gpu-gres (5 checks)
      ├── cgroup-isolation (4 checks)
      ├── monitoring-stack (6 checks)
      ├── dcgm-monitoring (5 checks)
      ├── grafana (4 checks)
      ├── job-scripts (5 checks)
      ├── beegfs (6 checks)
      ├── virtio-fs (4 checks)
      ├── pcie-passthrough (4 checks)
      ├── container-registry (7 checks)
      ├── container-integration (6 checks)
      └── slurm-accounting (4 checks)

Virtual Infrastructure Layer
  ├── KVM/QEMU VMs (deployed via ai-how)
  ├── libvirt bridge networks (virbr###)
  └── Packer images (HPC controller, compute, cloud)

CODE REDUCTION ACHIEVED:
  ├── Framework Consolidation: 15+ frameworks → 7 unified frameworks
  ├── Duplicate Code Elimination: 2,338 lines removed (71% reduction)
  ├── Original Code: 3,100 lines → Unified: 969 lines
  └── Phase 2 Utilities: 1,387 lines of shared, reusable code
```

## Test Framework CLI Pattern

All 7 unified test framework scripts implement a standardized CLI pattern via Phase 2 shared
utilities (framework-cli.sh and framework-orchestration.sh):

```bash
./test-<component>-framework.sh [COMMAND] [OPTIONS]

COMMANDS:
  e2e, end-to-end      Run complete test with cleanup (default)
  start-cluster        Start cluster independently
  stop-cluster         Destroy cluster
  deploy-ansible       Deploy Ansible configuration
  run-tests            Run test suite
  list-tests           Show available tests
  run-test NAME        Run specific individual test
  status               Show cluster status
  help                 Show detailed help

OPTIONS:
  -h, --help           Display help message
  -v, --verbose        Verbose output
  --no-cleanup         Skip cleanup on failure
  --interactive        Interactive cleanup prompts
```

### Examples

```bash
# Full end-to-end (start → provision → test → cleanup)
./test-slurm-controller-framework.sh e2e

# Start cluster, keep it running
./test-slurm-controller-framework.sh start-cluster

# Deploy Ansible to running cluster
./test-slurm-controller-framework.sh deploy-ansible

# Run all tests
./test-slurm-controller-framework.sh run-tests

# Run specific test
./test-slurm-controller-framework.sh run-test check-slurm-installation.sh

# View available tests
./test-slurm-controller-framework.sh list-tests

# Check cluster status
./test-slurm-controller-framework.sh status

# Clean up
./test-slurm-controller-framework.sh stop-cluster
```

## Test Suites Reference

### 16 Modular Test Suites

| Suite | Category | Purpose | Framework | Lines |
|-------|----------|---------|-----------|-------|
| **basic-infrastructure** | Foundation | VM lifecycle, networking, SSH | `test-basic-infra-framework.sh` | 1000+ |
| **slurm-controller** | Core HPC | Installation, MUNGE, PMIx, accounting | `test-slurm-controller-framework.sh` | 1200+ |
| **slurm-compute** | Core HPC | Node registration, distributed jobs | `test-slurm-compute-framework.sh` | 488 |
| **container-runtime** | Container | Apptainer installation & security | `test-container-runtime-framework.sh` | 800+ |
| **container-registry** | Container | Registry structure, permissions, sync | `test-container-registry-framework.sh` | 1424 |
| **container-integration** | Integration | PyTorch+CUDA, MPI, distributed training | `test-container-integration-framework.sh` | 943 |
| **container-deployment** | Container | Image integrity, SLURM exec, sync | `test-container-deployment-framework.sh` | 700+ |
| **gpu-validation** | Hardware | PCIe devices, drivers, nvidia-smi | `test-gpu-validation-framework.sh` | 800+ |
| **gpu-gres** | GPU Scheduling | GRES config, GPU detection, scheduling | `test-gpu-gres-framework.sh` | 850+ |
| **dcgm-monitoring** | Monitoring | DCGM install, exporter, Prometheus | `test-dcgm-monitoring-framework.sh` | 693 |
| **monitoring-stack** | Monitoring | Prometheus, Node Exporter, integration | `test-monitoring-stack-framework.sh` | 602 |
| **job-scripts** | Jobs | Debug collection, failure detection | `test-job-scripts-framework.sh` | 515 |
| **beegfs** | Storage | Services, filesystem ops, performance | `test-beegfs-framework.sh` | 700+ |
| **cgroup-isolation** | Resource Mgmt | Cgroup config, resource isolation | `test-cgroup-isolation-framework.sh` | 650+ |
| **virtio-fs** | Shared FS | VirtIO-FS mount, config, performance | `test-virtio-fs-framework.sh` | 762 |
| **container-e2e** | End-to-End | Complete container workflow | `test-container-e2e-framework.sh` | 900+ |

### Suite Structure

Each suite directory contains:

```text
suites/slurm-controller/
├── README.md                      # Suite documentation
├── check-slurm-installation.sh    # Check 1: Installation
├── check-slurm-munge.sh           # Check 2: MUNGE
├── check-slurm-pmix.sh            # Check 3: PMIx
├── check-slurm-accounting.sh      # Check 4: Accounting
├── check-slurm-job-submission.sh  # Check 5: Job submission
├── check-distributed-jobs.sh      # Check 6: Distributed execution
└── run-slurm-controller-tests.sh  # Master test runner (executable)
```

Each check script:

- Runs independently
- Logs to timestamped file
- Returns exit code (0=pass, 1=fail)
- Can be run individually via framework

## Test Configurations

### Configuration Files (17 YAML)

Located in `tests/test-infra/configs/`:

```yaml
version: "1.0"
metadata:
  name: "test-slurm-controller"
  description: "SLURM controller installation and functionality"
  task: "010"  # Associated implementation task

clusters:
  hpc:
    name: "HPC Cluster"
    type: "HPC"
    base_image_path: "build/packer/hpc-controller/..."
    network:
      subnet: "192.168.100.0/24"
      bridge: "virbr100"
    hardware:
      acceleration: "KVM"  # or "NONE" for simulation
      vmx: true            # Intel VMX support
      svm: false           # AMD-V support
      iommu: false         # For GPU passthrough
    controller:
      name: "controller"
      cpu: 4
      memory: 8192
      disk_size: 100
      ip: "192.168.100.10"
      roles:
        - slurm-controller
        - slurm-database
        - monitoring-stack
    compute_nodes:
      - name: "compute-001"
        cpu: 4
        memory: 8192
        count: 2
        roles:
          - slurm-compute
          - nvidia-gpu-drivers  # Only if GPU testing
    slurm_config:
      partitions:
        - name: "compute"
          nodes: "compute-[001-002]"
          timeout: 30
        - name: "gpu"
          nodes: "gpu-[001-002]"
          timeout: 30
      accounting: true
      database_backend: "mysql"

  cloud:  # Optional, for cloud integration tests
    name: "Cloud Cluster"
    type: "CLOUD"
    # ... cloud-specific configuration

test:
  # Which tests to run on this cluster config
  test_suite: "slurm-controller"

  # Which components to validate
  test_categories:
    - "installation"
    - "munge"
    - "pmix"
    - "accounting"
    - "job-submission"

  # Environment variables for test execution
  environment:
    TEST_TIMEOUT: "300"
    LOG_LEVEL: "INFO"
    SSH_USER: "admin"
    SSH_KEY: "build/shared/ssh-keys/id_rsa"
```

### Common Test Configurations

**Minimal**: `test-minimal.yaml`

- 1 HPC controller
- 1 compute node
- ~5 minutes to deploy

**SLURM Controller**: `test-slurm-controller.yaml`

- Task 010: SLURM controller installation
- ~10 minutes to deploy

**SLURM Full Stack**: `test-full-stack.yaml`

- All SLURM features
- Container runtime
- Monitoring
- ~30 minutes to deploy

**GPU**: `test-gpu-gres.yaml`

- GPU GRES scheduling
- PCIe passthrough validation
- ~20 minutes to deploy

## Utility Modules Reference

### log-utils.sh

Provides centralized logging with timestamps and colors:

```bash
source test-infra/utils/log-utils.sh

log_info "Starting test"
log_warn "This is a warning"
log_error "This is an error"
log_debug "Debug information"

# Output:
# [2025-10-24 14:30:45] INFO  [test-slurm-controller-framework.sh:42] Starting test
# [2025-10-24 14:30:46] WARN  [test-slurm-controller-framework.sh:80] This is a warning
# [2025-10-24 14:30:47] ERROR [test-slurm-controller-framework.sh:95] This is an error
```

**Key Functions:**

- `log_info()`, `log_warn()`, `log_error()`, `log_debug()` - Output messages
- `setup_log_directory()` - Create timestamped log folder
- `log_file()` - Log to file and console
- `get_log_directory()` - Retrieve current log directory

### cluster-utils.sh

Manages VM cluster lifecycle via AI-HOW:

```bash
source test-infra/utils/cluster-utils.sh

# Start cluster from config
start_cluster "test-slurm-controller" "test-hpc-slurm-controller"

# Get VM IP
get_vm_ip "controller" "test-hpc-slurm-controller"

# Wait for SSH connectivity
wait_for_ssh "192.168.100.10" "admin" "build/shared/ssh-keys/id_rsa"

# Destroy cluster
destroy_cluster "test-hpc-slurm-controller"
```

**Key Functions:**

- `resolve_test_config_path()` - Find config file
- `start_cluster()` - Deploy cluster
- `destroy_cluster()` - Clean up resources
- `get_vm_ip()` - Retrieve VM IP by name
- `wait_for_ssh()` - Wait for SSH availability
- `is_cluster_running()` - Check cluster status

### ansible-utils.sh

Sets up Python venv and runs Ansible playbooks:

```bash
source test-infra/utils/ansible-utils.sh

# Set up virtual environment
setup_virtual_environment

# Deploy Ansible playbook
deploy_ansible_playbook "build/shared/ssh-keys/id_rsa" \
  "ansible/playbook-hpc-runtime.yml" \
  "inventory.ini"
```

**Key Functions:**

- `setup_virtual_environment()` - Create Python venv
- `check_ansible_in_venv()` - Verify Ansible available
- `check_venv_exists()` - Check venv status
- `deploy_ansible_playbook()` - Run playbook with venv

### vm-utils.sh

SSH and networking utilities:

```bash
source test-infra/utils/vm-utils.sh

# Get VM IP
vm_ip=$(get_vm_ip "controller" "cluster-name")

# SSH command helper
ssh_cmd=$(get_ssh_command "192.168.100.10" "admin" "key.pem" "whoami")
eval "$ssh_cmd"
```

### test-framework-utils.sh

Main orchestration that sources all utilities:

```bash
source test-infra/utils/test-framework-utils.sh

# Full orchestration happens here
provision_monitoring_stack_on_vms "inventory.ini" "roles"
```

## Writing New Tests

### Create a New Test Suite

1. **Create suite directory:**

   ```bash
   mkdir -p tests/suites/my-feature
   cd tests/suites/my-feature
   ```

2. **Create check scripts:**

   ```bash
   # check-feature-setup.sh
   #!/bin/bash
   set -e

   # Test description
   # Usage: called by framework, expects exit code 0 on pass

   echo "Checking feature setup..."

   # Validation logic
   if some_check; then
     echo "✓ Feature is set up correctly"
     exit 0
   else
     echo "✗ Feature setup failed"
     exit 1
   fi
   ```

3. **Create master runner** (`run-my-feature-tests.sh`):

   ```bash
   #!/bin/bash
   set -e

   # Source utilities
   source ../../test-infra/utils/test-framework-utils.sh

   # List of checks
   CHECKS=(
     "check-feature-setup.sh"
     "check-feature-config.sh"
     "check-feature-operation.sh"
   )

   # Run all checks
   for check in "${CHECKS[@]}"; do
     log_info "Running $check..."
     ./$check || exit 1
   done

   log_info "All tests passed!"
   ```

4. **Create README.md:**

   ```markdown
   # My Feature Test Suite

   Tests for [feature description].

   ## Prerequisites
   - [requirement 1]
   - [requirement 2]

   ## Checks
   - check-feature-setup.sh: Verify setup
   - check-feature-config.sh: Verify configuration
   - check-feature-operation.sh: Verify operation

   ## Running Tests
   ```

### Create Test Configuration

Add to `tests/test-infra/configs/`:

```yaml
version: "1.0"
metadata:
  name: "test-my-feature"
  description: "My feature validation"
  task: "999"

clusters:
  hpc:
    # ... cluster configuration
    controller:
      roles:
        - my-feature  # Add your Ansible role

test:
  test_suite: "my-feature"
  test_categories:
    - "setup"
    - "config"
    - "operation"
```

### Create Test Framework Script

Create `tests/test-my-feature-framework.sh`:

```bash
#!/bin/bash
set -e

# Imports
source test-infra/utils/test-framework-utils.sh

# Parse arguments
case "${1:-e2e}" in
  start-cluster)
    start_cluster "test-my-feature" "test-hpc-my-feature"
    ;;
  deploy-ansible)
    # Deploy to existing cluster
    deploy_ansible_playbook "$SSH_KEY" \
      "ansible/playbook-my-feature.yml" \
      "$INVENTORY_FILE"
    ;;
  run-tests)
    cd suites/my-feature
    ./run-my-feature-tests.sh
    ;;
  stop-cluster)
    destroy_cluster "test-hpc-my-feature"
    ;;
  *)
    log_error "Unknown command: $1"
    exit 1
    ;;
esac
```

## Test Execution Phases

### Recommended Execution Order

**Phase 1: Foundation (30-90 min)**

1. `make test-precommit` - Quick validation (~30 sec)
2. `make test-base-images` - Build validation (~20-60 min)
3. `make test-integration` - Framework tests (~2-5 min)
4. `make test-ansible-roles` - Ansible validation (~2-5 min)

**Phase 2: Core Infrastructure (40-80 min)**

1. `make test-slurm-controller` - Task 010 (~15 min)
2. `make test-slurm-accounting` - Task 019 (~15 min)
3. `make test-monitoring-stack` - Task 015 (~15 min)
4. `make test-grafana` - Task 017 (~15 min)

**Phase 3: Compute Nodes (20-40 min)**

1. `make test-slurm-compute` - Task 022 (~15 min)
2. `make test-container-runtime` - Task 008/009 (~10 min)
3. `make test-gpu-gres` - Task 023 (~15 min)
4. `make test-pcie-passthrough` - GPU validation (~15 min)

**Phase 4: Advanced Integration (45-70 min)**

1. `make test-container-registry` - Task 021 (~20 min)
2. `make test-container-integration` - Task 026 (~20 min)
3. `make test-dcgm-monitoring` - Task 018 (~15 min)

### Makefile Test Targets (22 targets)

```bash
# Foundation
make test-precommit            # YAML, Ansible, Shell linting
make test-base-images          # Build and validate base images
make test-integration          # Framework integration tests
make test-ansible-roles        # Ansible role validation

# Core Infrastructure
make test-slurm-controller     # SLURM controller (Task 010)
make test-slurm-accounting     # SLURM accounting (Task 019)
make test-monitoring-stack     # Prometheus/Grafana (Task 015)
make test-grafana              # Grafana setup (Task 017)

# Compute & Containers
make test-slurm-compute        # SLURM compute (Task 022)
make test-container-runtime    # Apptainer (Task 008/009)
make test-container-registry   # Container registry (Task 021)
make test-container-integration # Container + SLURM (Task 026)

# Storage & Monitoring
make test-beegfs               # BeeGFS filesystem
make test-dcgm-monitoring      # DCGM monitoring (Task 018)
make test-cgroup-isolation     # Cgroup isolation
make test-virtio-fs            # VirtIO-FS mounts

# GPU Support
make test-gpu-validation       # GPU drivers and PCIe
make test-gpu-gres             # GPU GRES scheduling (Task 023)
make test-pcie-passthrough     # PCIe passthrough validation

# Aggregate Targets
make test-all                  # Run all tests
make test-quick                # Fast tests only
make test-verbose              # Verbose output
make test-clean                # Clean logs and artifacts
```

## Logging and Output

### Log Directory Structure

```text
tests/logs/
└── slurm-controller-test-run-2025-10-24_14-30-45/
    ├── framework.log                    # Main execution log
    ├── cluster-start-test-hpc-slurm-controller.log
    ├── cluster-destroy-test-hpc-slurm-controller.log
    ├── test-results-test-hpc-slurm-controller-controller.log
    ├── test-results-test-hpc-slurm-controller-compute-001.log
    ├── ai-how-plan.log                 # Cluster plan output
    ├── cluster-plan-test-slurm-controller.json
    ├── vm-connection-info/
    │   ├── vm-list.txt                 # List of VMs deployed
    │   ├── vm-info.csv                 # VM IPs and SSH info
    │   └── ssh-commands.sh             # SSH helper commands
    └── summary.txt                      # Test summary and status
```

### Log Output Format

All logs use standardized format:

```text
[2025-10-24 14:30:45] INFO  [test-slurm-controller-framework.sh:42] Starting SLURM controller tests
[2025-10-24 14:30:46] INFO  [cluster-utils.sh:128] Deploying cluster from test-slurm-controller.yaml
[2025-10-24 14:30:47] INFO  [test-framework-utils.sh:56] Waiting for cluster deployment...
[2025-10-24 14:31:15] INFO  [test-framework-utils.sh:78] Cluster deployed successfully
[2025-10-24 14:31:20] INFO  [ansible-utils.sh:92] Running Ansible playbook-hpc-runtime.yml
[2025-10-24 14:32:45] INFO  [test-framework-utils.sh:156] Ansible deployment complete
[2025-10-24 14:32:50] INFO  [test-slurm-controller-framework.sh:88] Running test suite: slurm-controller
[2025-10-24 14:33:15] PASS  [suites/slurm-controller/check-slurm-installation.sh:45] SLURM installation OK
[2025-10-24 14:33:30] PASS  [suites/slurm-controller/check-slurm-munge.sh:78] MUNGE daemon OK
```

## Development Workflow

### Local Development

```bash
# 1. Make code changes to role or script
vim ansible/roles/slurm-controller/handlers/main.yml

# 2. Run pre-commit checks
make test-precommit

# 3. Start cluster for testing
cd tests
./test-slurm-controller-framework.sh start-cluster

# 4. Deploy Ansible
./test-slurm-controller-framework.sh deploy-ansible

# 5. Run specific test
./test-slurm-controller-framework.sh run-test check-slurm-installation.sh

# 6. Check logs
tail -f logs/slurm-controller-test-run-*/framework.log

# 7. After debugging, clean up
./test-slurm-controller-framework.sh stop-cluster
```

### Debugging Failed Tests

```bash
# 1. Find the logs
ls -lart tests/logs/

# 2. Review test output
tail -100 tests/logs/*/test-results-*.log

# 3. SSH to VM for investigation
cat tests/logs/*/vm-connection-info/ssh-commands.sh
source tests/logs/*/vm-connection-info/ssh-commands.sh
ssh-to-controller "journalctl -xe"

# 4. Leave cluster running for investigation
./test-slurm-controller-framework.sh start-cluster --no-cleanup

# 5. After done, destroy
./test-slurm-controller-framework.sh stop-cluster
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Infrastructure Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: [self-hosted, kvm, libvirt]

    steps:
      - uses: actions/checkout@v3

      - name: Pre-commit validation
        run: make test-precommit

      - name: Base images test
        run: make test-base-images

      - name: SLURM controller test
        run: make test-slurm-controller

      - name: Container integration test
        run: make test-container-integration

      - name: Upload test logs
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-logs
          path: tests/logs/
```

## Troubleshooting

### Common Issues

**Issue: SSH connection timeout**

```bash
# Check VM is running
virsh list

# Check network connectivity
virsh net-list
virsh net-info virbr100

# Test connectivity directly
ping 192.168.100.10

# Check SSH key permissions
ls -la build/shared/ssh-keys/
chmod 600 build/shared/ssh-keys/id_rsa
```

**Issue: Ansible playbook fails**

```bash
# Check inventory file
cat tests/test-infra/inventory.ini

# Test connectivity
cd tests
ansible -i test-infra/inventory.ini all -m ping

# Run playbook with verbose output
ansible-playbook -i test-infra/inventory.ini \
  -vvv ansible/playbook-hpc-runtime.yml
```

**Issue: Test script fails with "command not found"**

```bash
# Ensure utilities are sourced
head -20 tests/test-slurm-controller-framework.sh

# Check file permissions
ls -la tests/test-infra/utils/

# Source manually for debugging
source tests/test-infra/utils/test-framework-utils.sh
log_info "Testing logging"
```

## Further Reading

- [AI-HOW CLI Reference](../python/ai_how/docs/cli-reference.md) - Cluster deployment
- [Ansible Documentation](../ansible/README.md) - Role and playbook reference

**Note:** For comprehensive testing workflow documentation and test infrastructure configuration,
refer to `tests/README.md` and `tests/test-infra/README.md` in the project root
