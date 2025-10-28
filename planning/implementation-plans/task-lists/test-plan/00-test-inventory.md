# Test Inventory

## Overview

This document provides a complete inventory of all existing test frameworks, test suites, and validation infrastructure
in the HPC SLURM project as of the Phase 4 consolidation effort.

## Summary Statistics

| Category | Count | Status |
|----------|-------|--------|
| Test Framework Scripts | 15 | ⚠️ Needs consolidation |
| Test Suite Directories | 16 | ✅ Well-organized |
| Test Suite Scripts | ~80+ | ⚠️ Needs refactoring (code duplication) |
| Shared Utility Modules | 1 | ⚠️ Needs expansion |
| End-to-End Validation Steps | 10 | ✅ Complete |
| Total Test Scripts (in suites) | ~80+ | ✅ Comprehensive |

## Test Framework Scripts

### Current Frameworks (15 Total)

All framework scripts are located in `tests/` directory:

| Framework | File Size | Lines | Purpose | CLI Standard |
|-----------|-----------|-------|---------|--------------|
| `test-beegfs-framework.sh` | 15K | ~450 | BeeGFS deployment validation | ✅ Full |
| `test-cgroup-isolation-framework.sh` | 13K | ~400 | Cgroup isolation for SLURM | ✅ Full |
| `test-container-integration-framework.sh` | 32K | ~950 | ML/AI containerized workloads | ✅ Full |
| `test-container-registry-framework.sh` | 50K | ~1500 | Container registry + SLURM integration | ✅ Full |
| `test-container-runtime-framework.sh` | 13K | ~400 | Apptainer/Singularity installation | ✅ Full |
| `test-dcgm-monitoring-framework.sh` | 22K | ~650 | GPU monitoring (DCGM) | ✅ Full |
| `test-gpu-gres-framework.sh` | 11K | ~350 | GPU resource scheduling | ✅ Full |
| `test-grafana-framework.sh` | 13K | ~400 | Grafana dashboards | ✅ Full |
| `test-job-scripts-framework.sh` | 16K | ~480 | SLURM job script validation | ✅ Full |
| `test-monitoring-stack-framework.sh` | 19K | ~550 | Prometheus monitoring | ✅ Full |
| `test-pcie-passthrough-framework.sh` | 13K | ~400 | GPU PCIe passthrough | ✅ Full |
| `test-slurm-accounting-framework.sh` | 13K | ~400 | SLURM job accounting | ✅ Full |
| `test-slurm-compute-framework.sh` | 15K | ~450 | SLURM compute node installation | ✅ Full |
| `test-slurm-controller-framework.sh` | 13K | ~400 | SLURM controller installation | ✅ Full |
| `test-virtio-fs-framework.sh` | 24K | ~700 | VirtIO-FS filesystem sharing | ✅ Full |
| **TOTAL** | **~270K** | **~8000** | | |

### Framework Categories

#### Category 1: Controller Image Tests (Packer)

Test frameworks that validate HPC controller image builds:

1. **test-slurm-controller-framework.sh** (13K)
   - SLURM controller installation
   - Configuration validation
   - Job scheduling setup

2. **test-slurm-accounting-framework.sh** (13K)
   - SLURM job accounting database
   - slurmdbd configuration
   - Job tracking validation

3. **test-monitoring-stack-framework.sh** (19K)
   - Prometheus server installation
   - Node Exporter deployment
   - Metrics collection validation

4. **test-grafana-framework.sh** (13K)
   - Grafana installation
   - Dashboard provisioning
   - Monitoring integration

#### Category 2: Compute Image Tests (Packer)

Test frameworks that validate HPC compute image builds:

1. **test-container-runtime-framework.sh** (13K)
   - Apptainer/Singularity installation
   - Security policies
   - Container execution validation

#### Category 3: Runtime Validation Tests (Ansible)

Test frameworks that validate runtime configuration via Ansible:

1. **test-cgroup-isolation-framework.sh** (13K)
   - Cgroup configuration
   - Resource isolation
   - SLURM integration

2. **test-gpu-gres-framework.sh** (11K)
   - GPU GRES configuration
   - GPU detection and scheduling
   - SLURM GPU resource management

3. **test-job-scripts-framework.sh** (16K)
   - SLURM job script validation
   - Job submission and execution
   - Script templates

4. **test-dcgm-monitoring-framework.sh** (22K)
   - DCGM exporter installation
   - GPU metrics collection
   - Prometheus integration

5. **test-container-integration-framework.sh** (32K)
   - PyTorch + CUDA integration
   - MPI communication
   - Distributed training validation

6. **test-slurm-compute-framework.sh** (15K)
   - SLURM compute node deployment
   - Controller registration
   - Job execution capability

#### Category 4: Storage and Networking Tests

Test frameworks for specialized infrastructure:

1. **test-beegfs-framework.sh** (15K)
   - BeeGFS filesystem deployment
   - Storage performance validation
   - Multi-node filesystem access

2. **test-virtio-fs-framework.sh** (24K)
   - VirtIO-FS configuration
   - Host-guest filesystem sharing
   - Performance validation

3. **test-pcie-passthrough-framework.sh** (13K)
   - GPU PCIe passthrough
   - GPU visibility validation
   - Device assignment

#### Category 5: Registry and Distribution

Test frameworks for container distribution:

1. **test-container-registry-framework.sh** (50K)
   - Container registry deployment
   - Image distribution
   - SLURM integration

## Test Suite Directories

### Test Suites (16 Total)

All test suites are located in `tests/suites/` directory. Each suite contains actual test validation scripts.

| Suite Directory | Scripts | Purpose | Status |
|-----------------|---------|---------|--------|
| `basic-infrastructure/` | ~5 | Basic system validation | ✅ Complete |
| `beegfs/` | ~4 | BeeGFS filesystem tests | ✅ Complete |
| `cgroup-isolation/` | ~3 | Cgroup configuration tests | ✅ Complete |
| `container-deployment/` | ~5 | Container deployment tests | ✅ Complete |
| `container-e2e/` | ~8 | End-to-end container tests | ✅ Complete |
| `container-integration/` | ~12 | Container integration tests | ✅ Complete |
| `container-registry/` | ~6 | Registry functionality tests | ✅ Complete |
| `container-runtime/` | ~4 | Runtime installation tests | ✅ Complete |
| `dcgm-monitoring/` | ~4 | GPU monitoring tests | ✅ Complete |
| `gpu-gres/` | ~3 | GPU GRES configuration tests | ✅ Complete |
| `gpu-validation/` | ~5 | GPU functionality tests | ✅ Complete |
| `job-scripts/` | ~4 | Job script validation tests | ✅ Complete |
| `monitoring-stack/` | ~5 | Prometheus monitoring tests | ✅ Complete |
| `slurm-compute/` | ~6 | Compute node tests | ✅ Complete |
| `slurm-controller/` | ~5 | Controller installation tests | ✅ Complete |
| `virtio-fs/` | ~4 | VirtIO-FS filesystem tests | ✅ Complete |
| **TOTAL** | **~80+** | | |

### Suite Structure

Each test suite directory follows a consistent structure:

```text
tests/suites/<suite-name>/
├── check-*.sh              # Individual validation scripts
├── test-*.sh               # Test execution scripts
└── validate-*.sh           # Validation helper scripts
```

### Suite Categories by Component

#### HPC Controller Components

- `slurm-controller/` - SLURM controller installation
- `monitoring-stack/` - Prometheus + Node Exporter
- `basic-infrastructure/` - Basic system configuration

#### HPC Compute Components

- `slurm-compute/` - SLURM compute node installation
- `container-runtime/` - Apptainer/Singularity
- `cgroup-isolation/` - Resource isolation
- `gpu-gres/` - GPU resource scheduling
- `gpu-validation/` - GPU functionality

#### Storage and Filesystem

- `beegfs/` - BeeGFS parallel filesystem
- `virtio-fs/` - VirtIO-FS filesystem sharing

#### Container Infrastructure

- `container-registry/` - Container registry
- `container-deployment/` - Container distribution
- `container-integration/` - ML/AI workload integration
- `container-e2e/` - End-to-end container validation

#### Monitoring and Observability

- `monitoring-stack/` - Prometheus metrics collection
- `dcgm-monitoring/` - GPU monitoring with DCGM

#### Job Management

- `job-scripts/` - SLURM job script validation

## Shared Utilities

### Overview

The `tests/test-infra/utils/` directory contains **5 comprehensive utility modules** that provide all core functionality
needed for test framework scripts. These utilities implement:

- Logging with structured output and color formatting
- Cluster lifecycle management using ai-how API
- VM discovery and SSH connectivity
- Ansible deployment and virtual environment management
- Test orchestration and execution

**Total Size**: ~2,917 lines of well-tested, reusable code

**Key Principle**: New consolidated frameworks should **leverage these existing utilities** rather than duplicating
functionality. The consolidation effort focuses on **extracting CLI and orchestration patterns** while reusing all
core infrastructure code.

### Test Suite Refactoring Opportunity

**Status**: 📝 Planned (See [09-test-suite-refactoring-plan.md](09-test-suite-refactoring-plan.md))

The test suite scripts in `tests/suites/` contain significant code duplication that can be eliminated:

**Duplication Patterns Identified**:

- **Logging Functions**: 137+ occurrences across 53 files
- **Color Definitions**: 232+ occurrences across 63 files
- **Test Tracking Variables**: 80+ occurrences
- **Test Execution Functions**: 60+ occurrences
- **SSH Configuration**: 40+ occurrences
- **Script Configuration**: 80+ occurrences

**Estimated Impact**:

- **Code Reduction**: 2,000-3,000 lines eliminated (~30-40% reduction)
- **New Utilities**: 3 shared utility modules for test suites
- **Maintenance**: Centralized common functionality
- **Consistency**: Standardized patterns across all test scripts

**Implementation Plan**:

- Phase 1: Create shared utilities (4 hours)
- Phase 2: Refactor test suites (8 hours)
- Phase 3: Validation and testing (2 hours)
- **Total**: 14 hours estimated effort

### Current Utilities (5 Modules)

Located in `tests/test-infra/utils/`:

#### 1. log-utils.sh

**Purpose**: Comprehensive logging infrastructure with structured output

**Size**: ~261 lines

**Key Features**:

- Color-coded output (info, success, warning, error)
- Caller information tracking (file:line:function)
- Log directory initialization and management
- Test result tracking and summaries
- Configurable verbosity levels

**Core Functions**:

```bash
# Basic logging
log()              # General log message with timestamp
log_success()      # Success message (green ✓)
log_warning()      # Warning message (yellow ⚠)
log_error()        # Error message (red ✗)
log_verbose()      # Verbose logging (respects VERBOSE_MODE)

# Log initialization
init_logging()     # Initialize log directory structure

# Advanced logging
log_command()      # Execute and log command with output capture
log_test_result()  # Log structured test results
create_log_summary() # Generate comprehensive log summary

# Configuration
configure_logging_level() # Set verbosity (quiet/normal/verbose/debug)
```

**Usage Pattern**:

```bash
# Source at the beginning of scripts
source "$PROJECT_ROOT/tests/test-infra/utils/log-utils.sh"

# Initialize logging
init_logging "$(date '+%Y-%m-%d_%H-%M-%S')" "logs" "my-test"

# Use logging functions
log "Starting test execution..."
log_success "Test passed"
log_error "Test failed"
```

#### 2. cluster-utils.sh

**Purpose**: Cluster lifecycle management using ai-how API

**Size**: ~713 lines

**Key Features**:

- Integration with ai-how CLI for cluster operations
- JSON parsing using jq for ai-how plan data
- Cluster state verification and cleanup
- Interactive and automated operation modes
- Robust error handling and cleanup on failure

**Core Functions**:

```bash
# Path resolution
resolve_test_config_path()  # Resolve relative/absolute config paths

# Cluster lifecycle
start_cluster()             # Start cluster using ai-how
destroy_cluster()           # Destroy cluster with --force support
verify_cluster_cleanup()    # Ensure no VMs remain after destroy
check_cluster_not_running() # Pre-flight check for clean environment

# VM discovery using ai-how API
wait_for_cluster_vms()      # Wait for VMs to start using ai-how plan
parse_cluster_name()        # Extract cluster name from config
parse_expected_vms()        # Get expected VM list from ai-how plan
get_vm_specifications()     # Get VM specs from ai-how plan
get_cluster_plan_data()     # Generate cluster plan JSON

# Cleanup handling
cleanup_cluster_on_exit()   # Trap handler for automated cleanup
show_cleanup_instructions() # Display manual cleanup commands
manual_cluster_cleanup()    # Interactive cleanup prompts

# Interactive lifecycle (NEW - for framework CLI)
start_cluster_interactive() # Start with confirmation prompts
stop_cluster_interactive()  # Stop with confirmation prompts
show_cluster_status()       # Display cluster status
run_cluster_lifecycle()     # Complete lifecycle workflow
```

**Usage Pattern**:

```bash
# Source utilities
source "$PROJECT_ROOT/tests/test-infra/utils/cluster-utils.sh"

# Start cluster
start_cluster "$CONFIG_FILE" "$CLUSTER_NAME"

# Wait for VMs
wait_for_cluster_vms "$CONFIG_FILE" "hpc" 300

# Cleanup
destroy_cluster "$CONFIG_FILE" "$CLUSTER_NAME"
```

**ai-how Integration**:

This utility extensively uses the ai-how API for:

- `uv run ai-how plan clusters` - Generate cluster plans in JSON
- `uv run ai-how hpc start` - Start HPC clusters
- `uv run ai-how hpc destroy` - Destroy HPC clusters
- `uv run ai-how hpc status` - Check cluster status

#### 3. vm-utils.sh

**Purpose**: VM discovery, SSH connectivity, and remote script execution

**Size**: ~505 lines

**Key Features**:

- VM IP discovery using virsh and ai-how API
- SSH connectivity testing with retry logic
- Script upload and remote execution
- Connection info saving for debugging
- Legacy and modern discovery methods

**Core Functions**:

```bash
# VM IP discovery
get_vm_ip()                    # Get IP for single VM using virsh
get_vm_ips_for_cluster()       # Get all VMs using ai-how API (PREFERRED)
get_vm_ips_for_cluster_legacy() # Legacy VM discovery (backward compatibility)

# SSH operations
wait_for_vm_ssh()              # Wait for SSH connectivity with timeout
upload_scripts_to_vm()         # Upload test scripts via SCP
execute_script_on_vm()         # Execute script remotely and capture output

# Debugging
save_vm_connection_info()      # Save VM IPs and SSH commands to log dir
```

**Usage Pattern**:

```bash
# Source utilities
source "$PROJECT_ROOT/tests/test-infra/utils/vm-utils.sh"

# Get VM IPs using ai-how API
get_vm_ips_for_cluster "$CONFIG_FILE" "hpc"
# Populates VM_IPS and VM_NAMES arrays

# Wait for SSH
for i in "${!VM_IPS[@]}"; do
    wait_for_vm_ssh "${VM_IPS[$i]}" "${VM_NAMES[$i]}"
done

# Upload and execute tests
upload_scripts_to_vm "${VM_IPS[0]}" "${VM_NAMES[0]}" "$TEST_SCRIPTS_DIR"
execute_script_on_vm "${VM_IPS[0]}" "${VM_NAMES[0]}" "run-all-tests.sh"
```

**Important Variables**:

```bash
VM_IPS=()    # Array of VM IP addresses (populated by get_vm_ips_for_cluster)
VM_NAMES=()  # Array of VM names (populated by get_vm_ips_for_cluster)
```

#### 4. ansible-utils.sh

**Purpose**: Ansible deployment and Python virtual environment management

**Size**: ~278 lines

**Key Features**:

- Python virtual environment creation and activation
- Ansible availability verification
- Automated deployment workflows
- Integration with cluster utilities

**Core Functions**:

```bash
# Virtual environment management
check_venv_exists()             # Check if .venv exists
check_ansible_in_venv()         # Verify Ansible installation
create_virtual_environment()    # Create venv with dependencies
setup_virtual_environment()     # Complete venv setup workflow
activate_virtual_environment()  # Activate venv for current session

# Ansible deployment
wait_for_cluster_ready_ansible() # Wait for cluster (delegates to cluster-utils)
deploy_ansible_on_cluster()      # Deploy Ansible on running cluster
deploy_ansible_full_workflow()   # Complete deployment: wait + deploy

# Validation
check_ansible_available()        # Check if ansible-playbook is in PATH
validate_ansible_installation()  # Comprehensive Ansible validation
get_ansible_version()           # Get installed Ansible version

# Cleanup
cleanup_virtual_environment()    # Remove .venv directory
show_venv_status()              # Display venv status
```

**Usage Pattern**:

```bash
# Source utilities
source "$PROJECT_ROOT/tests/test-infra/utils/ansible-utils.sh"

# Setup virtual environment
setup_virtual_environment

# Deploy Ansible
deploy_ansible_full_workflow "$CONFIG_FILE"
```

**Dependencies**:

- Requires `cluster-utils.sh` for `wait_for_cluster_ready`
- Requires `test-framework-utils.sh` for `run_ansible_on_cluster`

#### 5. test-framework-utils.sh

**Purpose**: High-level test orchestration and Ansible integration

**Size**: ~1,160 lines

**Key Features**:

- Complete test framework workflow orchestration
- Ansible inventory generation from cluster state
- Test suite discovery and execution
- Monitoring stack provisioning
- Interactive test management

**Core Functions**:

```bash
# Main workflow
run_test_framework()            # Complete end-to-end test execution
check_test_prerequisites()      # Validate all prerequisites
cleanup_test_framework()        # Cleanup handler for trap

# Ansible integration
run_ansible_on_cluster()        # Execute Ansible on deployed VMs
provision_monitoring_stack_on_vms() # Deploy monitoring stack
generate_ansible_inventory()    # Create dynamic inventory from cluster
deploy_ansible_playbook()       # Deploy playbook with inventory generation

# Inventory management
extract_ips_from_inventory()    # Parse YAML inventory for IPs
wait_for_inventory_nodes_ssh()  # Wait for SSH on inventory nodes

# Test discovery and execution
list_tests_in_directory()       # List available tests with descriptions
execute_single_test_by_name()   # Run single test by name
validate_test_exists()          # Check if test script exists
run_master_tests()              # Run master test script
run_test_suite()                # Run complete test suite with aggregation
format_test_listing()           # Display test listing
```

**Usage Pattern**:

```bash
# Source ALL utilities (test-framework-utils sources others)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/tests/test-infra/utils/test-framework-utils.sh"

# Run complete test framework
run_test_framework \
    "$TEST_CONFIG" \
    "$TEST_SCRIPTS_DIR" \
    "$TARGET_VM_PATTERN" \
    "run-all-tests.sh"
```

**Dependencies**:

Sources and depends on:

- `log-utils.sh`
- `cluster-utils.sh`
- `vm-utils.sh`

### Integration Strategy for New Frameworks

New consolidated frameworks should follow this pattern:

```bash
#!/usr/bin/env bash
# Example: test-hpc-runtime-framework.sh

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source ALL existing utilities
source "$PROJECT_ROOT/tests/test-infra/utils/log-utils.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/cluster-utils.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/vm-utils.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/ansible-utils.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/test-framework-utils.sh"

# Source NEW utilities (to be created in consolidation)
source "$PROJECT_ROOT/tests/test-infra/utils/framework-cli.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/framework-orchestration.sh"

# Set configuration
export TEST_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/test-hpc-runtime.yaml"
export TEST_SCRIPTS_DIR="$PROJECT_ROOT/tests/suites"
export TEST_NAME="hpc-runtime"

# Initialize logging
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "$TEST_NAME"

# Parse CLI using NEW framework-cli.sh
parse_framework_cli "$@"

# Execute using NEW framework-orchestration.sh
execute_framework_workflow "$COMMAND" "$TEST_CONFIG" "$TEST_SCRIPTS_DIR"
```

### Utility Function Mapping

This table shows how existing utilities map to common framework needs:

| Framework Need | Utility Module | Function |
|----------------|----------------|----------|
| Initialize logging | `log-utils.sh` | `init_logging()` |
| Log messages | `log-utils.sh` | `log()`, `log_success()`, `log_error()` |
| Start cluster | `cluster-utils.sh` | `start_cluster()` |
| Stop cluster | `cluster-utils.sh` | `destroy_cluster()` |
| Wait for VMs | `cluster-utils.sh` | `wait_for_cluster_vms()` |
| Get VM IPs | `vm-utils.sh` | `get_vm_ips_for_cluster()` |
| Wait for SSH | `vm-utils.sh` | `wait_for_vm_ssh()` |
| Upload scripts | `vm-utils.sh` | `upload_scripts_to_vm()` |
| Execute remotely | `vm-utils.sh` | `execute_script_on_vm()` |
| Setup Ansible | `ansible-utils.sh` | `setup_virtual_environment()` |
| Deploy Ansible | `ansible-utils.sh` | `deploy_ansible_on_cluster()` |
| Run test suite | `test-framework-utils.sh` | `run_test_suite()` |
| List tests | `test-framework-utils.sh` | `list_tests_in_directory()` |
| Run single test | `test-framework-utils.sh` | `execute_single_test_by_name()` |
| Generate inventory | `test-framework-utils.sh` | `generate_ansible_inventory()` |

### Identified Utility Gaps (NEW Modules Needed)

Based on analysis of the 15 framework scripts, the following NEW utilities should be created to complete the
consolidation:

#### 1. framework-cli.sh (NEW)

**Purpose**: Standardized CLI parsing and command dispatch

**Estimated Size**: ~300-400 lines

**Functions to Extract**:

```bash
parse_framework_cli()      # Parse standardized CLI commands
show_framework_help()      # Display help message
validate_cli_arguments()   # Validate required arguments
set_framework_options()    # Set options (verbose, no-cleanup, etc.)
dispatch_command()         # Route command to appropriate handler
```

**Standardized Commands**:

- `e2e` - End-to-end workflow
- `start-cluster` - Start cluster only
- `deploy-ansible` - Deploy Ansible only
- `run-tests` - Run tests on existing cluster
- `list-tests` - List available tests
- `run-test` - Run single test
- `status` - Show cluster status
- `help` - Display help

**Standardized Options**:

- `--verbose` - Enable verbose output
- `--no-cleanup` - Skip cleanup on failure
- `--config <file>` - Custom config file
- `--test-suite <name>` - Specific test suite

#### 2. framework-orchestration.sh (NEW)

**Purpose**: High-level workflow orchestration that delegates to existing utilities

**Estimated Size**: ~400-500 lines

**Functions to Extract**:

```bash
execute_framework_workflow()   # Main workflow dispatcher
run_e2e_workflow()            # Complete end-to-end execution
run_cluster_start_only()      # Cluster start workflow
run_ansible_deploy_only()     # Ansible deploy workflow
run_tests_only()              # Test execution workflow
run_status_workflow()         # Status display workflow
```

**Key Pattern**: Orchestration functions delegate to existing utilities:

```bash
run_e2e_workflow() {
    # Uses existing utilities:
    start_cluster()                    # from cluster-utils.sh
    wait_for_cluster_vms()             # from cluster-utils.sh
    get_vm_ips_for_cluster()          # from vm-utils.sh
    deploy_ansible_on_cluster()        # from ansible-utils.sh
    run_test_suite()                   # from test-framework-utils.sh
    destroy_cluster()                  # from cluster-utils.sh
}
```

#### 3. framework-template.sh (NEW)

**Purpose**: Base template for new test frameworks

**Estimated Size**: ~200-250 lines (mostly boilerplate)

**Template Structure**:

```bash
#!/usr/bin/env bash
# Framework Template - Copy and customize for new frameworks

set -euo pipefail

# Standard header
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source all utilities
source "$PROJECT_ROOT/tests/test-infra/utils/log-utils.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/cluster-utils.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/vm-utils.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/ansible-utils.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/test-framework-utils.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/framework-cli.sh"
source "$PROJECT_ROOT/tests/test-infra/utils/framework-orchestration.sh"

# Configuration - CUSTOMIZE THIS SECTION
export TEST_NAME="my-test"
export TEST_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/test-my-test.yaml"
export TEST_SCRIPTS_DIR="$PROJECT_ROOT/tests/suites/my-test-suite"

# Initialize and execute
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "$TEST_NAME"

parse_framework_cli "$@"
execute_framework_workflow "$COMMAND" "$TEST_CONFIG" "$TEST_SCRIPTS_DIR"
```

### Consolidation Impact

**Before Consolidation**:

- 15 framework scripts with ~2,000-3,000 lines of duplicated code
- Inconsistent CLI patterns
- Manual cluster management
- No standardized workflow

**After Consolidation** (leveraging existing + 3 NEW utilities):

- 3 consolidated frameworks (~200-300 lines each)
- 4 standalone frameworks (refactored to use utilities)
- Consistent CLI via `framework-cli.sh`
- Standardized workflows via `framework-orchestration.sh`
- **ALL infrastructure operations** use existing utilities

**Code Reuse**: ~95% of infrastructure code already exists in the 5 utility modules. Consolidation focuses on
extracting the remaining 5% (CLI patterns and workflow orchestration) into 3 new utilities.

## End-to-End Validation

### Phase 4 Validation Framework

**Location**: `tests/phase-4-validation/`

**Status**: ✅ Complete and automated (10/10 steps)

**Purpose**: Comprehensive end-to-end validation of Phase 4 consolidation

**Main Script**: `run-all-steps.sh`

**Documentation**: `tests/phase-4-validation/README.md`

**Internal Utilities**: `lib-common.sh` (~411 lines)

**Consolidation Status**: **KEEP AS-IS** (not part of Phase 4 consolidation target)

**Key Characteristics**:

- Self-contained with its own utility functions (`lib-common.sh`)
- Proven stable and reliable for release validation
- Minimal overlap with `test-infra/utils/` (mostly logging ~100 lines)
- Unique state management system for step tracking and resume functionality
- Battle-tested across multiple releases

### Validation Steps

| Step | Script | Purpose | Status |
|------|--------|---------|--------|
| 00 | `step-00-prerequisites.sh` | Validate prerequisites | ✅ Automated |
| 01 | `step-01-build-base-images.sh` | Build Packer base images | ✅ Automated |
| 02 | `step-02-build-controller-image.sh` | Build HPC controller image | ✅ Automated |
| 03 | `step-03-build-compute-image.sh` | Build HPC compute image | ✅ Automated |
| 04 | `step-04-cluster-deployment.sh` | Deploy test cluster | ✅ Automated |
| 05 | `step-05-ansible-deployment.sh` | Deploy Ansible configurations | ✅ Automated |
| 06 | `step-06-basic-slurm-validation.sh` | Validate basic SLURM | ✅ Automated |
| 07 | `step-07-container-workloads.sh` | Validate container workloads | ✅ Automated |
| 08 | `step-08-monitoring-validation.sh` | Validate monitoring stack | ✅ Automated |
| 09 | `step-09-integration-tests.sh` | Run integration tests | ✅ Automated |
| 10 | `step-10-regression-tests.sh` | Run regression tests | ✅ Automated |

### Validation Execution

```bash
# Run full validation
cd tests/phase-4-validation
./run-all-steps.sh

# Resume from specific step
./run-all-steps.sh --resume step-05

# Use existing validation output
VALIDATION_ROOT=/path/to/validation-output ./run-all-steps.sh --resume step-07
```

## Code Duplication Analysis

### Duplicate Code Patterns

Analysis of the 15 framework scripts reveals significant duplication:

#### Pattern 1: Cluster Management (duplicated ~15 times)

```bash
stop_cluster() {
    log_info "Stopping test cluster..."
    ai-how cluster destroy --config "$TEST_CONFIG" || true
}
```

**Total duplication**: ~300 lines across 15 files

#### Pattern 2: Ansible Deployment (duplicated ~15 times)

```bash
deploy_ansible() {
    log_info "Deploying Ansible playbook..."
    deploy_ansible_playbook "$TEST_CONFIG" "$ANSIBLE_PLAYBOOK"
}
```

**Total duplication**: ~450 lines across 15 files

#### Pattern 3: CLI Parsing (duplicated ~15 times)

```bash
case "${1:-e2e}" in
    e2e|end-to-end)
        run_e2e
        ;;
    start-cluster)
        start_cluster
        ;;
    ...
esac
```

**Total duplication**: ~750 lines across 15 files

#### Pattern 4: Help Functions (duplicated ~15 times)

```bash
show_help() {
    cat << EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]
...
EOF
}
```

**Total duplication**: ~600 lines across 15 files

#### Pattern 5: Test Execution (duplicated ~15 times)

```bash
run_tests() {
    log_info "Running test suite..."
    run_test_suite "$TEST_SUITE_DIR"
}
```

**Total duplication**: ~300 lines across 15 files

### Total Code Duplication

**Estimated duplicated code**: 2000-3000 lines across 15 framework scripts

**Percentage of total code**: ~25-35% of framework code is duplicated

## Test Configuration Files

### Configuration Locations

All test configurations are located in `tests/test-infra/configs/`:

| Config File | Purpose | Framework |
|-------------|---------|-----------|
| `test-beegfs.yaml` | BeeGFS test cluster | test-beegfs-framework.sh |
| `test-cgroup-isolation.yaml` | Cgroup isolation test | test-cgroup-isolation-framework.sh |
| `test-container-integration.yaml` | Container integration test | test-container-integration-framework.sh |
| `test-container-registry.yaml` | Container registry test | test-container-registry-framework.sh |
| `test-container-runtime.yaml` | Container runtime test | test-container-runtime-framework.sh |
| `test-dcgm-monitoring.yaml` | DCGM monitoring test | test-dcgm-monitoring-framework.sh |
| `test-gpu-gres.yaml` | GPU GRES test | test-gpu-gres-framework.sh |
| `test-grafana.yaml` | Grafana test | test-grafana-framework.sh |
| `test-job-scripts.yaml` | Job scripts test | test-job-scripts-framework.sh |
| `test-monitoring-stack.yaml` | Monitoring stack test | test-monitoring-stack-framework.sh |
| `test-pcie-passthrough.yaml` | PCIe passthrough test | test-pcie-passthrough-framework.sh |
| `test-slurm-accounting.yaml` | SLURM accounting test | test-slurm-accounting-framework.sh |
| `test-slurm-compute.yaml` | SLURM compute test | test-slurm-compute-framework.sh |
| `test-slurm-controller.yaml` | SLURM controller test | test-slurm-controller-framework.sh |
| `test-virtio-fs.yaml` | VirtIO-FS test | test-virtio-fs-framework.sh |

## Makefile Targets

### Test Execution Targets

Located in `Makefile` at project root:

```bash
make test                          # Core infrastructure tests
make test-all                      # All tests including builds
make test-quick                    # Quick validation tests
make test-verbose                  # Tests with verbose output
make test-container-comprehensive  # Comprehensive container runtime tests
make test-monitoring-stack         # Monitoring stack tests
make test-gpu-gres                 # GPU GRES tests
make test-container-integration    # Container integration tests
make test-base-images              # Base image build tests
make test-ansible-roles            # Ansible role integration tests
make test-integration              # Integration tests
make test-precommit                # Pre-commit validation
```

## Documentation

### Test Documentation Files

| Document | Purpose | Location |
|----------|---------|----------|
| `tests/README.md` | Main test suite documentation | ✅ Complete |
| `tests/phase-4-validation/README.md` | End-to-end validation guide | ✅ Complete |
| `docs/CONTAINER-INTEGRATION-TESTING.md` | Container integration testing guide | ✅ Complete |
| `docs/GPU-GRES-WORKFLOW.md` | GPU GRES workflow documentation | ✅ Complete |
| Task lists | Individual component validation criteria | ✅ Complete |

## Test Execution Times

### Time Estimates by Phase

| Phase | Duration | Description |
|-------|----------|-------------|
| Pre-commit | ~30 seconds | Syntax, linting |
| Foundation | ~30-90 minutes | Base images, integration, Ansible |
| Core Infrastructure | ~40-80 minutes | SLURM, accounting, monitoring, Grafana |
| Compute Nodes | ~20-40 minutes | Container runtime, PCIe |
| Advanced Integration | ~45-70 minutes | Registry, container integration, DCGM |
| **Full Suite** | **~2.5-5 hours** | Complete validation |

### Individual Framework Times

| Framework | Duration | Notes |
|-----------|----------|-------|
| test-slurm-controller | ~10-20 min | Includes cluster deployment |
| test-slurm-accounting | ~10-20 min | Includes cluster deployment |
| test-monitoring-stack | ~10-20 min | Includes cluster deployment |
| test-grafana | ~10-20 min | Includes cluster deployment |
| test-container-runtime | ~10-20 min | Includes cluster deployment |
| test-pcie-passthrough | ~10-20 min | Requires GPU hardware |
| test-gpu-gres | ~10-20 min | Includes cluster deployment |
| test-container-registry | ~15-25 min | Includes registry deployment |
| test-container-integration | ~15-30 min | Requires pre-built containers |
| test-dcgm-monitoring | ~10-20 min | Includes cluster deployment |
| test-beegfs | ~15-25 min | Multi-node storage deployment |
| test-virtio-fs | ~10-20 min | Filesystem sharing validation |
| test-cgroup-isolation | ~10-20 min | Resource isolation validation |
| test-job-scripts | ~10-20 min | Job script validation |
| test-slurm-compute | ~10-20 min | Compute node deployment |

## Consolidation Opportunities

### High-Priority Consolidation Targets

Based on code duplication and logical grouping:

1. **HPC Runtime Framework** (NEW)
   - Consolidate: cgroup-isolation, gpu-gres, job-scripts, dcgm-monitoring, container-integration, slurm-compute
   - Rationale: All validate runtime configuration via Ansible
   - Estimated reduction: ~1200 lines

2. **HPC Packer Controller Framework** (NEW)
   - Consolidate: slurm-controller, slurm-accounting, monitoring-stack, grafana
   - Rationale: All validate HPC controller image builds
   - Estimated reduction: ~800 lines

3. **HPC Packer Compute Framework** (NEW)
   - Consolidate: container-runtime
   - Rationale: Validates HPC compute image builds
   - Keep as unified framework for consistency

### Standalone Frameworks to Keep

These frameworks have unique requirements and should remain standalone but be refactored to use shared utilities:

1. **test-beegfs-framework.sh** - Multi-node parallel filesystem
2. **test-virtio-fs-framework.sh** - Specialized filesystem sharing
3. **test-pcie-passthrough-framework.sh** - Hardware-dependent GPU passthrough
4. **test-container-registry-framework.sh** - Complex registry + distribution workflow

### Shared Utilities to Extract

1. **framework-cli.sh** - Standardized CLI parsing and command dispatch
2. **framework-orchestration.sh** - Cluster lifecycle and test orchestration
3. **framework-template.sh** - Base template for all frameworks

## Summary

### Current State

- **15 test framework scripts** with significant code duplication (~2000-3000 lines)
- **16 test suite directories** with ~80+ validation scripts (well-organized, no changes needed)
- **1 shared utility module** (needs expansion)
- **10 end-to-end validation steps** (complete and automated)
- **~8000 lines** of framework code total

### Target State

- **7 test framework scripts** after consolidation
  - 3 new unified frameworks
  - 4 refactored standalone frameworks
- **16 test suite directories** (unchanged, preserved)
- **4 shared utility modules** (expanded from 1)
- **10 end-to-end validation steps** (unchanged, preserved)
- **~5000-6000 lines** of framework code (25-35% reduction)

### Benefits

- **Eliminate 2000-3000 lines** of duplicated code
- **Reduce maintenance burden** by consolidating similar frameworks
- **Standardize CLI patterns** across all frameworks
- **Preserve test coverage** - no test logic changes
- **Improve developer experience** with consistent interfaces
