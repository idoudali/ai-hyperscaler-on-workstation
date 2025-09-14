# HPC SLURM Deployment - Individual Task List

**Objective:** Break down HPC SLURM deployment into granular, self-contained
tasks for individual execution and testing.

**Status:** Task Breakdown Complete - Implementation In Progress  
**Updated:** 2025-01-27  
**Total Tasks:** 30 individual tasks across 4 phases
**Completed Tasks:** 5 (TASK-001, TASK-002, TASK-003, TASK-004, TASK-008)

## Overview

This document provides a detailed breakdown of the HPC SLURM deployment
implementation plan into individual, testable tasks that can be executed
independently by junior software engineers or coding agents. Each task includes
specific deliverables, validation criteria, and clear dependencies.

## Task Execution Principles

- **Self-Contained**: Each task can be developed and tested independently
- **Clear Dependencies**: Explicit prerequisite relationships between tasks
- **Testable Outcomes**: Specific validation criteria and test commands
- **Incremental Progress**: System functionality builds progressively
- **Rollback Safety**: Failed tasks don't break previous working components

## Phase 0: Test Infrastructure Setup (Tasks 001-006)

### Test Environment Foundation

#### Task 001: Build HPC Base Images with Packer ✅ COMPLETED

- **ID**: TASK-001
- **Phase**: 0 - Test Infrastructure
- **Dependencies**: None
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate
- **Status**: ✅ COMPLETED
- **Completion Date**: 2025-01-27
- **Branch**: `idoudali/task-001`

**Description:** Build HPC and Cloud base images using the existing Packer
infrastructure to create consistent, tested base images for cluster deployment
validation.

**Deliverables:**

- Built HPC base image (`hpc-base.qcow2`)
- Built Cloud base image (`cloud-base.qcow2`)
- Verified base image functionality
- Updated `template-cluster.yaml` with correct image paths

**Packer Build Process:**

```bash
# Build HPC base image
cd packer
make build-hpc-image

# Build Cloud base image  
make build-cloud-image

# Verify images are created
ls -la build/packer/hpc-base/hpc-base/hpc-base.qcow2
ls -la build/packer/cloud-base/cloud-base/cloud-base.qcow2
```

**Base Image Features:**

- **HPC Image**: Debian 13 (trixie) with networking tools, SSH access, and
  HPC-optimized configuration
- **Cloud Image**: Debian 13 (trixie) minimal base for Kubernetes workloads
- **Security**: Proper SSH key management, disabled root login, firewall
  configuration
- **Size Optimization**: Compressed QCOW2 format with zero-fill optimization

**Validation Criteria:**

- [x] HPC base image builds without errors
- [x] Cloud base image builds without errors  
- [x] Images boot successfully in libvirt/QEMU
- [x] SSH access works with generated keys
- [x] Base system packages are properly installed

**Test Commands:**

```bash
# Test HPC image boot
qemu-system-x86_64 -enable-kvm -m 2G -hda build/packer/hpc-base/hpc-base/hpc-base.qcow2 -nographic

# Test Cloud image boot
qemu-system-x86_64 -enable-kvm -m 2G -hda build/packer/cloud-base/cloud-base/cloud-base.qcow2 -nographic

# Check image info
qemu-img info build/packer/hpc-base/hpc-base/hpc-base.qcow2
qemu-img info build/packer/cloud-base/cloud-base/cloud-base.qcow2
```

**Success Criteria:**

- ✅ Both images build successfully within reasonable time (<30 minutes each)
- ✅ Images boot to login prompt without errors
- ✅ SSH connectivity functional with generated keys
- ✅ Image sizes are reasonable (<2GB compressed)

**Implementation Notes:**

- ✅ Comprehensive test suite implemented (`tests/test_base_images.sh`)
- ✅ Test runner script created (`tests/run_base_images_test.sh`)
- ✅ Makefile integration for test automation (`tests/Makefile`)
- ✅ Dev container integration for consistent builds
- ✅ Signal handling for clean interruption (Ctrl+C support)
- ✅ Verbose mode and force cleanup options
- ✅ QEMU image integrity validation
- ✅ SSH key generation and validation
- ✅ Image size validation (<2GB requirement)
- ✅ All validation criteria met and tested

**Test Suite Features:**

- Automated Packer image building with dev container
- QEMU boot validation and integrity checks
- SSH key generation and format validation
- Image size and format verification
- Comprehensive error handling and logging
- Clean interruption support for long-running builds
- Reusable existing images to save build time

---

#### Task 002: Install and Configure AI-HOW CLI ✅ COMPLETED

- **ID**: TASK-002
- **Phase**: 0 - Test Infrastructure
- **Dependencies**: TASK-001
- **Estimated Time**: 3 hours
- **Difficulty**: Junior-Intermediate
- **Status**: ✅ **COMPLETED**
- **Completion Date**: 2025-01-02

**Description:** Install and configure the AI-HOW Python CLI tool for cluster
lifecycle management and validation testing.

**Deliverables:**

- ✅ AI-HOW CLI installed in development environment
- ✅ Configuration validation working
- ✅ PCIe passthrough validation functional
- ✅ Test cluster configuration files prepared

**Installation Process:**

```bash
# Install AI-HOW CLI in development mode
cd python/ai_how
uv sync --dev
uv run ai-how --help

# Verify installation
uv run ai-how validate --help
uv run ai-how hpc --help
```

**CLI Features Available:**

- **Configuration Validation**: JSON schema validation with detailed error
  reporting
- **PCIe Passthrough Validation**: System readiness checks for GPU passthrough
- **HPC Cluster Lifecycle**: Full start/stop/destroy cluster management
- **VM Management**: libvirt integration for VM lifecycle operations
- **Network Management**: Virtual network creation and IP allocation
- **Storage Management**: Volume and storage pool management

**Validation Criteria:**

- [x] AI-HOW CLI installs without errors
- [x] Help commands display correctly
- [x] Configuration validation works on sample files
- [x] PCIe validation detects system capabilities
- [x] Logging configuration functional

**Test Commands:**

```bash
# Test configuration validation
uv run ai-how validate config/template-cluster.yaml

# Test PCIe validation (with simulation)
uv run ai-how validate --skip-pcie-validation config/template-cluster.yaml

# Test inventory commands
uv run ai-how inventory pcie

# Test cluster management commands (dry run)
uv run ai-how hpc --help
```

**Success Criteria:**

- ✅ CLI installation completes without dependency issues
- ✅ Configuration validation passes on template-cluster.yaml
- ✅ PCIe inventory command works (even if no GPUs present)
- ✅ All CLI subcommands are accessible and show help text

**Implementation Summary:**

**Files Created/Modified:**

- `tests/test_ai_how_cli.sh` - Comprehensive test suite (295 lines)
- `tests/Makefile` - Updated with AI-HOW CLI test targets
- `docker/entrypoint.sh` - Container user management improvements
- `docker/Dockerfile` - Enhanced container with proper dependencies
- `scripts/run-in-dev-container.sh` - Improved container execution

**Key Features Implemented:**

- Complete AI-HOW CLI installation validation using `uv sync --dev`
- Configuration validation testing with `config/template-cluster.yaml`
- PCIe inventory functionality (`uv run ai-how inventory pcie`)
- All CLI subcommands available: `validate`, `hpc`, `inventory`, `plan`
- Comprehensive error handling and user-friendly output
- Container improvements for proper user/permission management

**Code Quality:**

- ✅ All requirements met with comprehensive test coverage
- ✅ Well-structured test architecture following KISS principles
- ✅ Excellent error handling and user experience
- ✅ Proper container security and user management
- ⚠️ 3 minor improvements recommended (see `claude-review.md`)

**Notes:**

- Task completed successfully with all deliverables met
- Comprehensive code review completed (`claude-review.md`)
- Minor improvements recommended but not blocking
- Ready for production use after applying minor fixes

---

#### Task 003: Create Test Cluster Configurations ✅ COMPLETED

- **ID**: TASK-003
- **Phase**: 0 - Test Infrastructure
- **Dependencies**: TASK-002
- **Estimated Time**: 3 hours
- **Difficulty**: Junior-Intermediate
- **Status**: ✅ COMPLETED
- **Completion Date**: 2025-01-27

**Description:** Create specialized test cluster configurations based on
template-cluster.yaml for different validation scenarios.

**Deliverables:**

- `test-infra/configs/test-minimal.yaml` - Minimal test cluster (no GPU)
- `test-infra/configs/test-gpu-simulation.yaml` - GPU passthrough simulation
- `test-infra/configs/test-full-stack.yaml` - Complete HPC + Cloud setup
- Updated base image paths in configurations

**Test Configuration Variants:**

```yaml
# test-minimal.yaml - Basic functionality testing
clusters:
  hpc:
    name: "test-hpc-minimal"
    base_image_path: "build/packer/hpc-base/hpc-base/hpc-base.qcow2"
  controller:
    cpu_cores: 2
    memory_gb: 4
      disk_gb: 20
    compute_nodes:
      - cpu_cores: 2
        memory_gb: 4
        disk_gb: 20
        # No PCIe passthrough for minimal testing

# test-gpu-simulation.yaml - GPU simulation testing  
clusters:
  hpc:
    compute_nodes:
      - cpu_cores: 4
        memory_gb: 8
        disk_gb: 30
        pcie_passthrough:
          enabled: true
          devices:
            - pci_address: "0000:01:00.0" 
              device_type: "gpu"
              vendor_id: "10de"
              device_id: "2684"
```

**Configuration Features:**

- **Resource Scaling**: Smaller resource allocations suitable for development/CI
  environments
- **Network Isolation**: Dedicated test subnets to avoid conflicts
- **Flexible GPU Config**: Support for both real GPU passthrough and simulation
- **Base Image Integration**: Proper paths to Packer-built images

**Validation Criteria:**

- [x] All test configurations validate against schema
- [x] Base image paths correctly reference Packer outputs
- [x] Network configurations are non-conflicting
- [x] Resource allocations are realistic for test environments

**Test Commands:**

```bash
# Validate test configurations
uv run ai-how validate test-infra/configs/test-minimal.yaml
uv run ai-how validate test-infra/configs/test-gpu-simulation.yaml
uv run ai-how validate test-infra/configs/test-full-stack.yaml

# Verify base image paths exist
ls -la build/packer/hpc-base/hpc-base/hpc-base.qcow2
ls -la build/packer/cloud-base/cloud-base/cloud-base.qcow2

# Check configuration schema compliance
python3 -c "import yaml; print('Valid YAML') if yaml.safe_load(open('test-infra/configs/test-minimal.yaml')) else print('Invalid')"
```

**Success Criteria:**

- ✅ All test configurations pass AI-HOW schema validation
- ✅ Base image paths resolve correctly
- ✅ Network subnets don't conflict with host networking
- ✅ Resource requirements are achievable on test hardware

**Implementation Notes:**

- ✅ Created `tests/test-infra/configs/` directory structure
- ✅ Implemented 3 test configuration variants:
  - `test-minimal.yaml` - Basic functionality testing (2 CPU, 4GB RAM, no GPU)
  - `test-gpu-simulation.yaml` - GPU simulation testing (4 CPU, 8GB RAM, simulated GPU)
  - `test-full-stack.yaml` - Complete HPC + Cloud setup (full feature set)
- ✅ All configurations include both HPC and Cloud clusters (schema requirement)
- ✅ Network subnets isolated: 192.168.150.0/24, 192.168.160.0/24, 192.168.170.0/24, 192.168.180.0/24
- ✅ Resource allocations optimized for test environments (2-8 CPU cores, 4-16GB RAM)
- ✅ Comprehensive test suite implemented (`tests/test_test_configs.sh`)
- ✅ Updated `tests/Makefile` with new test target `test-test-configs`
- ✅ All 9 test cases pass successfully
- ✅ Integration with existing test infrastructure complete

**Test Suite Features:**

- Automated configuration validation using AI-HOW CLI
- YAML syntax validation for all test configurations
- Base image path verification with warnings if images not built
- Network subnet isolation checking to prevent conflicts
- Resource allocation validation for realistic test requirements
- Schema compliance testing with proper error handling
- Comprehensive error reporting and verbose output options

---

#### Task 004: Automated PCIe Passthrough Testing Framework ✅ COMPLETED

- **ID**: TASK-004
- **Phase**: 0 - Test Infrastructure
- **Dependencies**: TASK-001
- **Estimated Time**: 4 hours
- **Difficulty**: Advanced
- **Status**: ✅ COMPLETED
- **Completion Date**: 2025-01-27
- **Branch**: `idoudali/task-004`
- **✅ CLEAN APPROACH**: No host system modification required

**Description:** Create an automated testing framework that validates PCIe
passthrough functionality using real ai-how cluster deployments. This approach
tests the complete end-to-end workflow without requiring host system modifications.

**Deliverables:**

- Minimal test configuration for PCIe passthrough testing
- Automated test framework script
- GPU validation test suite for remote execution
- Complete end-to-end test workflow
- Clean teardown and validation

**Test Configuration:**

**File:** `tests/test-infra/configs/test-pcie-passthrough-minimal.yaml`

- Single HPC compute node with PCIe passthrough enabled
- Simulated NVIDIA GPU devices (10de:2684 / 10de:22bd)
- Minimal resource allocation for fast testing
- Isolated network (192.168.140.0/24)

**Test Framework Components:**

1. **Main Framework**: `tests/test-infra/test-pcie-passthrough-framework.sh`
   - Orchestrates complete test workflow
   - Manages cluster lifecycle with ai-how
   - Handles SSH connectivity and script deployment
   - Provides comprehensive logging and cleanup

2. **GPU Validation Suite**: `tests/test-infra/scripts/gpu-validation/`
   - `check-pcie-devices.sh`: Validates PCIe device visibility
   - `check-gpu-drivers.sh`: Tests GPU driver functionality
   - `run-all-tests.sh`: Master test runner

**Test Workflow:**

1. **Cluster Deployment**: Uses `ai-how create` to start test cluster
2. **VM Discovery**: Uses `virsh` to get VM IP addresses
3. **SSH Connectivity**: Waits for SSH access to VMs
4. **Script Deployment**: Uploads and executes validation scripts
5. **Result Collection**: Gathers test results and logs
6. **Clean Teardown**: Uses `ai-how destroy` for cleanup
7. **Verification**: Ensures no VMs remain after testing

**Usage Examples:**

```bash
# Run complete PCIe passthrough test
./tests/test-infra/test-pcie-passthrough-framework.sh

# Run with custom configuration
./tests/test-infra/test-pcie-passthrough-framework.sh \
  --config tests/test-infra/configs/test-full-stack.yaml

# Run with debugging (no auto-cleanup on failure)
./tests/test-infra/test-pcie-passthrough-framework.sh --no-cleanup

# Show help and options
./tests/test-infra/test-pcie-passthrough-framework.sh --help
```

**Test Validation Criteria:**

- [x] **PCIe Device Detection**: lspci shows GPU and audio devices
- [x] **Driver Loading**: NVIDIA kernel modules loaded correctly
- [x] **nvidia-smi Functionality**: GPU management interface works
- [x] **Device File Access**: /dev/nvidia* devices present

**Advantages of This Approach:**

✅ **No Host Modification**: Works on any development system  
✅ **Real Testing**: Tests actual ai-how deployment workflow  
✅ **End-to-End Validation**: Complete GPU passthrough pipeline  
✅ **Automated Cleanup**: No manual VM management required  
✅ **Comprehensive Logging**: Detailed test results and debugging  
✅ **CI/CD Ready**: Can be integrated into automated testing  

**Prerequisites:**

- ai-how tool installed and functional
- Base HPC image built with Packer (`build/packer/hpc-base/hpc-base/hpc-base.qcow2`)
- virsh command available (libvirt)
- SSH key pair configured
- KVM virtualization enabled

**Success Criteria:**

- ✅ Test framework completes without errors
- ✅ All GPU validation tests pass on deployed VMs
- ✅ Cluster tears down cleanly with no remaining VMs
- ✅ Test logs provide clear pass/fail status for each component
- ✅ Framework can be run repeatedly without conflicts

**Error Handling:**

- Timeout handling for VM startup and SSH connectivity
- Graceful cleanup on test failure
- Option for manual cleanup if automated cleanup fails
- Detailed error logging for troubleshooting
- Interactive cleanup prompts when needed

**Implementation Notes:**

- ✅ Complete automated testing framework implemented (`tests/test-infra/test-pcie-passthrough-framework.sh`)
- ✅ Minimal PCIe passthrough test configuration created (`tests/test-infra/configs/test-pcie-passthrough-minimal.yaml`)
- ✅ Comprehensive GPU validation test suite delivered:
  - `tests/scripts/gpu-validation/check-pcie-devices.sh` - PCIe device visibility validation
  - `tests/scripts/gpu-validation/check-gpu-drivers.sh` - NVIDIA driver and nvidia-smi testing
  - `tests/scripts/gpu-validation/run-all-tests.sh` - Master test runner
- ✅ Complete orchestration workflow with ai-how integration
- ✅ Automated VM discovery and SSH connectivity handling
- ✅ Comprehensive logging and cleanup mechanisms
- ✅ Detailed documentation with usage examples (`tests/test-infra/README.md`)
- ✅ CI/CD integration support with timeout handling
- ✅ Clean approach requiring no host system modifications
- ✅ All deliverables tested and validated

**Framework Features:**

- End-to-end cluster deployment using ai-how CLI
- Automatic VM IP discovery via virsh integration
- Robust SSH connectivity with timeout and retry logic
- Modular GPU validation test suite execution
- Comprehensive result collection and logging
- Automated cluster cleanup and verification
- Verbose debugging and troubleshooting support

```bash
# Test configurations without PCIe simulation
uv run ai-how validate --skip-pcie-validation test-infra/configs/test-gpu-simulation.yaml
uv run ai-how validate --skip-pcie-validation test-infra/configs/test-full-stack.yaml

# Create test configs that don't require PCIe passthrough
# Focus on SLURM functionality, networking, and container execution testing
# Use schema validation only for GPU configurations
```

This approach avoids host system modification while still validating
configuration schemas and core functionality.

---

#### Task 005: Create Basic Infrastructure Testing Suite

- **ID**: TASK-005
- **Phase**: 0 - Test Infrastructure
- **Dependencies**: TASK-003, TASK-004
- **Estimated Time**: 2 hours  
- **Difficulty**: Junior-Intermediate
- **Test Type**: Infrastructure Tests

**Description:** Create basic infrastructure testing suite
that validates currently available functionality: cluster lifecycle,
VM networking, SSH connectivity, and configuration validation using Task 004's framework.

**Deliverables:**

- Basic infrastructure test validation scripts using Task 004's framework
- VM lifecycle and networking validation tests
- Configuration schema validation extensions
- SSH connectivity and basic cluster validation tests

**Basic Infrastructure Test Structure:**

```text
test-infra/suites/                    # Leverages Task 004's framework
├── infrastructure/                  # Basic infrastructure tests (AVAILABLE NOW)
│   ├── test-infrastructure.yaml    # Basic VM deployment config
│   └── scripts/validation/         # Infrastructure validation scripts
│       ├── check-vm-lifecycle.sh   # VM start/stop/destroy
│       ├── check-networking.sh     # VM networking and connectivity
│       ├── check-ssh-access.sh     # SSH connectivity validation
│       └── run-infrastructure-tests.sh
├── configuration/                   # Configuration validation tests (AVAILABLE NOW)
│   ├── test-configs/               # Test configuration files
│   └── scripts/validation/         # Configuration validation scripts
│       ├── validate-all-configs.sh
│       └── run-config-tests.sh
└── gpu-passthrough/                # GPU validation (uses Task 004 scripts - AVAILABLE)
    ├── test-pcie-passthrough-minimal.yaml  # Already implemented
    └── scripts/gpu-validation/      # Already implemented in Task 004
```

**Note:** Container runtime and multi-node testing will be added to their respective implementation tasks in later phases.

**Updated Implementation Approach (Leveraging Existing Infrastructure):**

Given the comprehensive test infrastructure already available, Task 005 will focus on filling specific gaps:

```bash
# Create basic infrastructure test suite using existing framework utilities
# File: tests/suites/basic-infrastructure/run-basic-infrastructure-tests.sh

#!/bin/bash
# Basic Infrastructure Test Suite
# Leverages existing test-framework-utils.sh for VM orchestration

set -euo pipefail

# Source existing framework utilities
source "$(dirname "$0")/../../test-infra/utils/test-framework-utils.sh"

# Test configuration
TEST_CONFIG="tests/test-infra/configs/test-minimal.yaml"  # Already exists
TEST_SUITE_NAME="Basic Infrastructure Validation"

echo "=== $TEST_SUITE_NAME ==="

# VM lifecycle validation (using existing patterns)
test_vm_lifecycle() {
    log_info "Testing VM lifecycle management..."
    
    # Start cluster using existing utilities
    start_cluster "$TEST_CONFIG" "test-basic-infra"
    
    # Wait for VMs using existing utilities  
    wait_for_cluster_vms "test-basic-infra"
    
    # Get VM IPs using existing utilities
    get_cluster_vm_ips "test-basic-infra"
    
    log_success "VM lifecycle test passed"
}

# SSH connectivity validation (using existing patterns)
test_ssh_connectivity() {
    log_info "Testing SSH connectivity..."
    
    for vm_ip in "${VM_IPS[@]}"; do
        wait_for_ssh "$vm_ip" "basic-infra-vm"
        test_ssh_command "$vm_ip" "echo 'SSH working'" 
    done
    
    log_success "SSH connectivity test passed"
}

# Basic networking validation
test_basic_networking() {
    log_info "Testing basic networking..."
    
    for vm_ip in "${VM_IPS[@]}"; do
        # Test internal connectivity
        if ssh_execute "$vm_ip" "ip route show"; then
            log_success "Internal routing working on $vm_ip"
        else
            log_error "Internal routing failed on $vm_ip"
            return 1
        fi
        
        # Test DNS resolution (expected to work)
        if ssh_execute "$vm_ip" "nslookup localhost"; then
            log_success "DNS resolution working on $vm_ip"
        else
            log_warning "DNS resolution issues on $vm_ip (may be expected)"
        fi
    done
    
    log_success "Basic networking test passed"
}

# Execute test suite using existing framework patterns
main() {
    init_logging "$(date '+%Y-%m-%d_%H-%M-%S')" "tests/logs" "basic-infrastructure"
    
    run_test "VM Lifecycle" test_vm_lifecycle
    run_test "SSH Connectivity" test_ssh_connectivity  
    run_test "Basic Networking" test_basic_networking
    
    # Cleanup using existing utilities
    cleanup_cluster_on_exit "$TEST_CONFIG"
    
    print_test_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

**Updated Usage with Existing Comprehensive Test Infrastructure:**

```bash
# Option 1: Use existing Makefile system (RECOMMENDED)
cd tests/
make test-basic-infrastructure          # New target to be added
make test-config-validation            # Enhanced configuration validation
make test                             # Run core infrastructure tests (already exists)

# Option 2: Use individual test runners (leveraging existing patterns)
./tests/suites/basic-infrastructure/run-basic-infrastructure-tests.sh

# Option 3: Use existing framework runners with basic config
./tests/test-pcie-passthrough-framework.sh \
  --config tests/test-infra/configs/test-minimal.yaml

# Option 4: Enhanced configuration validation (extending existing)
./tests/test_config_validation.sh --enhanced  # To be enhanced

# Option 5: Use container runtime framework for basic validation
./tests/test-container-runtime-framework.sh --quick --target-vm "compute"
```

**Updated Validation Criteria (Based on Current Infrastructure):**

- [ ] Basic infrastructure test suite created in `tests/suites/basic-infrastructure/`
- [ ] Tests leverage existing framework utilities from `tests/test-infra/utils/`
- [ ] VM lifecycle testing uses existing cluster management functions
- [ ] SSH connectivity validation uses existing SSH utilities
- [ ] Basic networking validation covers internal routing and DNS
- [ ] Configuration validation enhanced to cover all test configs in `tests/test-infra/configs/`
- [ ] New Makefile targets added for basic infrastructure testing
- [ ] Tests integrate with existing logging and error handling patterns

**Updated Test Commands (Leveraging Existing Infrastructure):**

```bash
# Primary approach: Use enhanced Makefile system
cd tests/
make test-basic-infrastructure     # New target (to be added)
make test-config-validation       # Enhanced target (to be updated)
make test                        # Existing core tests

# Alternative: Direct test suite execution
./tests/suites/basic-infrastructure/run-basic-infrastructure-tests.sh

# Configuration validation for all available configs
for config in tests/test-infra/configs/*.yaml; do
    echo "Validating $config"
    uv run ai-how validate "$config"
done

# Quick validation using existing frameworks
./tests/test-pcie-passthrough-framework.sh \
    --config tests/test-infra/configs/test-minimal.yaml \
    --quick

# Enhanced configuration testing
./tests/test_config_validation.sh --all-configs --enhanced
```

**Revised Success Criteria (Focused on Gaps):**

- Basic infrastructure test suite fills the gap between existing specialized tests (GPU/container)
and general infrastructure validation
- Tests reuse existing comprehensive framework utilities rather than reinventing functionality  
- VM lifecycle validation covers deployment, networking, SSH connectivity using existing patterns
- Enhanced configuration validation covers all test configurations in `tests/test-infra/configs/`
- New Makefile targets integrate seamlessly with existing comprehensive test system
- Basic infrastructure tests serve as foundation for specialized test suites without duplicating
existing functionality

**Updated Implementation Summary:**

The current `tests/` directory already contains a comprehensive test infrastructure that
significantly exceeds the original Task 005 scope. The updated approach focuses on filling
specific gaps rather than building from scratch:

**What's Already Available:**

- ✅ Comprehensive test framework utilities (`tests/test-infra/utils/`)
- ✅ Advanced orchestration frameworks (`test-pcie-passthrough-framework.sh`, `test-container-runtime-framework.sh`)
- ✅ Multiple test configurations (`tests/test-infra/configs/`)
- ✅ Specialized test suites (GPU validation, container runtime)  
- ✅ Comprehensive Makefile system with multiple targets
- ✅ Detailed documentation and logging infrastructure

**Task 005 Specific Implementation (Remaining Gaps):**

1. **Create `tests/suites/basic-infrastructure/`** - Basic infrastructure test suite focused on VM
 lifecycle, networking, SSH without specialized focus
2. **Add Makefile targets** - `test-basic-infrastructure` and enhanced `test-config-validation`
3. **Enhance configuration validation** - Extend `test_config_validation.sh` to cover all configs
  in `tests/test-infra/configs/`
4. **Integration** - Ensure basic infrastructure tests integrate seamlessly with existing comprehensive system

**Reduced Scope Justification:**
Task 005's original scope has been largely fulfilled by the advanced test infrastructure
already implemented. The remaining work focuses on specific gaps that provide value without
duplicating existing comprehensive functionality.

---

#### Task 006: Implement Comprehensive CI/CD Integration Testing Pipeline (OPTIONAL)

- **ID**: TASK-006
- **Phase**: 0 - Test Infrastructure
- **Dependencies**: TASK-002, TASK-005
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate-Advanced
- **⚠️ OPTIONAL**: Requires sudo access to install system packages and modify
  user groups
- **Test Type**: Integration Tests (CI/CD)

**Description:** Create a comprehensive CI/CD pipeline that builds base images,
validates configurations, and runs integration tests for cluster deployment
using AI-HOW CLI.

**⚠️ WARNING - Host System Modification:** The CI/CD pipeline installs system
packages (`qemu-kvm`, `libvirt-daemon-system`) and modifies user groups, which
could affect the host system configuration.

**Deliverables:**

- `.github/workflows/hpc-slurm-integration-tests.yml` - Main integration testing
  pipeline
- `.github/workflows/build-base-images.yml` - Packer image build pipeline for
  integration tests
- Docker-based integration test environment for CI runners
- Automated integration test reporting and metrics

**CI/CD Integration Testing Pipeline Structure:**

```yaml
# .github/workflows/hpc-slurm-integration-tests.yml
name: HPC SLURM Integration Testing Pipeline

on:
  push:
    paths: ['ansible/**', 'packer/**', 'python/ai_how/**', 'config/**']
  pull_request:
    paths: ['ansible/**', 'packer/**', 'python/ai_how/**', 'config/**']

jobs:
  build-base-images:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Packer
        run: |
          curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
          sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
          sudo apt-get update && sudo apt-get install packer
      
      - name: Build HPC base image
        run: |
          cd packer
          make build-hpc-image
          
      - name: Build Cloud base image
        run: |
          cd packer  
          make build-cloud-image
          
      - name: Archive built images
        uses: actions/upload-artifact@v4
        with:
          name: base-images
          path: |
            build/packer/hpc-base/hpc-base/hpc-base.qcow2
            build/packer/cloud-base/cloud-base/cloud-base.qcow2

  validate-configurations:
    needs: build-base-images
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          name: base-images
          path: build/packer/
          
      - name: Setup AI-HOW CLI
        run: |
          cd python/ai_how
          pip install uv
          uv sync --dev
          
      - name: Validate cluster configurations
        run: |
          cd python/ai_how
          uv run ai-how validate ../../test-infra/configs/test-minimal.yaml
          uv run ai-how validate --skip-pcie-validation ../../test-infra/configs/test-gpu-simulation.yaml
          uv run ai-how validate --skip-pcie-validation ../../config/template-cluster.yaml

  run-integration-tests:
    needs: [build-base-images, validate-configurations]
    runs-on: ubuntu-latest
    steps:
      - name: Setup libvirt for integration testing
        run: |
          sudo apt-get update
          sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients
          sudo usermod -a -G libvirt $USER
          
      - name: Run cluster lifecycle integration tests
        run: |
          pytest test-infra/validation/cluster_lifecycle/ -v -k "integration" --junitxml=lifecycle-results.xml
          
      - name: Run service validation integration tests
        run: |
          pytest test-infra/validation/service_validation/ -v -k "integration" --junitxml=service-results.xml
          
      - name: Run end-to-end integration tests
        run: |
          pytest test-infra/validation/integration_tests/ -v --junitxml=integration-results.xml
          
      - name: Publish integration test results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: HPC SLURM Integration Test Suite
          path: '*-results.xml'
          reporter: java-junit
```

**Integration Testing Pipeline Features:**

- **Parallel Execution**: Image building, validation, and integration testing
  run in parallel where possible
- **Artifact Management**: Built images cached and reused across integration
  testing stages  
- **Comprehensive Integration Testing**: Configuration validation, cluster
  lifecycle, service interactions, and end-to-end integration tests
- **Failure Isolation**: Each integration testing stage can fail independently
  with clear error reporting
- **Performance Tracking**: Integration test execution times and resource usage
  monitoring
- **Cross-Service Validation**: Tests verify interactions between AI-HOW CLI,
  libvirt, networking, and SLURM components

**Integration Testing Pipeline Validation Criteria:**

- [ ] Pipeline builds base images successfully for integration testing
- [ ] Configuration validation passes for all integration test configs
- [ ] Cluster lifecycle integration tests complete without errors
- [ ] End-to-end integration tests verify multi-component functionality
- [ ] Cross-service integration test results published with clear pass/fail
  status
- [ ] Integration tests demonstrate interoperability between all system
  components

**Integration Testing Pipeline Commands:**

```bash
# Test integration testing pipeline locally with Act
act -j build-base-images
act -j validate-configurations  
act -j run-integration-tests

# Validate integration testing workflow syntax
yamllint .github/workflows/hpc-slurm-integration-tests.yml
yamllint .github/workflows/build-base-images.yml

# Test individual integration testing pipeline components
cd packer && make build-hpc-image
cd python/ai_how && uv run ai-how validate ../../config/template-cluster.yaml
pytest test-infra/validation/ -v -k "integration" --junitxml=integration-results.xml

# Run full integration test suite locally
pytest test-infra/validation/integration_tests/ -v --tb=short
```

**Integration Testing Pipeline Success Criteria:**

- Complete integration testing pipeline executes within 45 minutes
- All integration tests pass on clean checkout
- Integration test failures provide actionable debugging information
- Pipeline scales to handle multiple concurrent PRs with integration testing
- Integration test results integrate with GitHub PR status checks
- Cross-service integration is validated across all system components

**🔄 SAFER ALTERNATIVE - No Host Modification:** Create a limited CI/CD
integration testing pipeline that avoids system package installation:

```yaml
# .github/workflows/hpc-slurm-integration-tests-safe.yml
name: HPC SLURM Safe Integration Testing Pipeline

jobs:
  build-base-images:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build images (Packer may work without libvirt)
        run: |
          cd packer
          make validate-packer  # Validation only
          
  validate-configurations:
    runs-on: ubuntu-latest  
    steps:
      - name: Setup AI-HOW CLI
        run: |
          cd python/ai_how
          pip install uv
          uv sync --dev
          
      - name: Validate configurations (schema only)
        run: |
          cd python/ai_how
          uv run ai-how validate --skip-pcie-validation ../../config/template-cluster.yaml
          uv run ai-how validate --skip-pcie-validation ../../test-infra/configs/test-minimal.yaml
          
  syntax-and-lint-checks:
    runs-on: ubuntu-latest
    steps:
      - name: Validate YAML syntax
        run: find . -name "*.yaml" -o -name "*.yml" | xargs yamllint
      - name: Python linting
        run: |
          cd python/ai_how
          uv sync --dev
          uv run ruff check src/
```

This safer approach focuses on configuration validation, syntax checking, and
basic integration testing without requiring system modifications or full VM
orchestration.

---

## Test Infrastructure Integration Summary

### Leveraged Components

**Packer Infrastructure (Tasks 001)**

- Uses existing `packer/hpc-base/` and `packer/cloud-base/` configurations
- Builds consistent, tested base images with proper provisioning
- Integrates with CMake build system for reproducible image creation
- Provides optimized QCOW2 images with size and performance optimizations

**AI-HOW Python CLI (Tasks 002, 005, 006)**

- Leverages comprehensive cluster lifecycle management (`ai-how hpc
  start/stop/destroy`)
- Uses built-in configuration validation with JSON schema support
- Integrates PCIe passthrough validation for GPU testing scenarios
- Provides VM management through libvirt with proper state tracking
- Includes network and storage management for complete infrastructure handling

**Template Configuration System (Tasks 003)**

- Builds on `template-cluster.yaml` as baseline configuration
- Creates test-specific variants with reduced resource requirements
- Maintains compatibility with production deployment patterns
- Supports both GPU simulation and real hardware testing modes

### Integration Testing Approach Benefits

1. **Production Alignment**: Integration test infrastructure uses the same tools
   (AI-HOW CLI, Packer) as production deployment
2. **Real System Integration Testing**: Deploys actual VMs with real networking
   and storage for cross-service validation
3. **Comprehensive Integration Validation**: Tests complete cluster lifecycle
   integration from image building through service deployment
4. **CI/CD Integration Testing**: Automated pipeline validates cross-component
   interactions (with safe alternatives for host-constrained environments)
5. **Scalable Integration Testing**: Supports both minimal integration test
   configs and full production-like integration deployments
6. **Hardware Flexibility**: Works with or without actual GPU hardware through
   integration test bypass modes
7. **Host System Safety**: Optional integration test tasks are clearly marked,
   with safer alternatives that avoid sudo requirements

### Integration Test Coverage

- **Image Building Integration**: Validates Packer templates and base image
  functionality within the deployment pipeline
- **Configuration Schema Integration**: Ensures cluster configs integrate
  properly with AI-HOW CLI validation
- **Cluster Lifecycle Integration**: Tests complete deployment, status
  monitoring, and cleanup across all services
- **Cross-Service Integration**: Validates SSH connectivity, networking, and
  storage access between components
- **PCIe Passthrough Integration**: Tests GPU configuration and VFIO driver
  binding with container orchestration
- **End-to-End Integration Workflows**: Verifies complete system functionality
  from infrastructure through application layer

This integration test infrastructure provides robust cross-service validation
capabilities that closely mirror production deployment scenarios while
maintaining efficiency for development and CI/CD workflows.

### Host System Safety Summary

**Safe Integration Test Tasks (No sudo required):**

- TASK-001: Packer image building for integration testing (creates files in
  build directory)
- TASK-002: AI-HOW CLI installation for integration testing (user-space Python
  environment)
- TASK-003: Integration test configuration file creation (project directory
  only)
- TASK-005: Integration test script creation (project directory only)

**Optional Integration Test Tasks (Require sudo):**

- TASK-004: PCIe simulation integration testing (modifies `/sys` filesystem) -
  **Use `--skip-pcie-validation` instead**
- TASK-006: Full CI/CD integration testing pipeline (installs system packages) -
  **Use safe integration testing pipeline alternative**

The core integration test validation functionality can be achieved using only
the safe tasks, with PCIe and full system integration testing available as
optional enhancements for environments where host modification is acceptable.

---

## Phase 1: Core Infrastructure Setup (Tasks 007-018)

### Container Runtime Foundation

#### Task 007: Extend Ansible Role Structure for Container Support ✅ COMPLETED

- **ID**: TASK-007
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-006 (SKIPPED - Optional)
- **Estimated Time**: 2 hours
- **Difficulty**: Junior
- **Status**: ✅ COMPLETED
- **Completion Date**: 2025-01-27
- **Branch**: `feature/task-007-ansible-role-structure`

**Description:** Create the extended Ansible role directory structure to support
container-based HPC deployment.

**Deliverables:**

- ✅ `ansible/roles/container-runtime/` directory structure
- ✅ `ansible/roles/slurm-controller/` directory structure  
- ✅ `ansible/roles/slurm-compute/` directory structure
- ✅ `ansible/roles/ml-container-images/` directory structure
- ✅ Proper subdirectories: `tasks/`, `templates/`, `defaults/`, `handlers/`,
  `vars/`, `files/`

**Validation Criteria:**

- [x] All required role directories exist
- [x] Each role has proper subdirectory structure
- [x] Directory permissions are correct (755 for directories)
- [x] Initial placeholder files created (main.yml in tasks/ and defaults/)

**Test Commands:**

```bash
# Verify directory structure
find ansible/roles -type d -name "container-runtime" -o -name "slurm-controller" -o -name "slurm-compute" -o -name "ml-container-images"

# Check subdirectory structure
for role in container-runtime slurm-controller slurm-compute ml-container-images; do
  ls -la ansible/roles/$role/
done

# Validate main.yml files exist
find ansible/roles -name "main.yml" | grep -E "(tasks|defaults)"
```

**Success Criteria:**

- ✅ Directory structure matches the specification in hpc-slurm-deployment.md section 2.1
- ✅ All placeholder files are syntactically valid YAML
- ✅ Ansible can discover and list the new roles

**Implementation Notes:**

- Successfully skipped optional TASK-006 dependency (CI/CD pipeline)
- Created comprehensive default variables for each role
- All 4 roles now have complete directory structure with proper permissions
- 12 main.yml files created (tasks/ and defaults/ for each role)
- Ready for dependent tasks: TASK-010, TASK-014, TASK-015
- TASK-008: ✅ COMPLETED - Container runtime implementation ready

---

#### Task 008: Create Container Runtime Ansible Role ✅ COMPLETED

- **ID**: TASK-008
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-007
- **Estimated Time**: 4 hours
- **Difficulty**: Junior-Intermediate
- **Status**: ✅ COMPLETED
- **Completion Date**: 2025-01-27
- **Branch**: `ansible`

**Description:** Implement Apptainer container runtime installation with proper
dependency management using Debian packages and official repositories.

**Deliverables:**

- `ansible/roles/container-runtime/tasks/main.yml` - Main orchestration
- `ansible/roles/container-runtime/tasks/singularity.yml` - Apptainer/Singularity
  installation
- `ansible/roles/container-runtime/tasks/security.yml` - Security policies
- `ansible/roles/container-runtime/defaults/main.yml` - Default variables

**Implementation Details:**

```yaml
# Primary installation method: Debian packages
container_runtime_type: "apptainer"  # Apptainer is the successor to Singularity
container_runtime_install_method: "debian"
container_runtime_version: "4.1.5+ds4-1"  # From Debian unstable

# Key packages to install
required_packages:
  - fuse                    # FUSE filesystem support
  - squashfs-tools         # SquashFS utilities
  - uidmap                 # User namespace mapping
  - wget                   # Download utilities
  - build-essential        # Compilation tools
  - libfuse2               # FUSE runtime libraries
  - libseccomp2            # Seccomp security support
```

**Apptainer Installation Sources:**

- **Primary**: Debian `singularity-container` package (4.1.5+ds4-1)
- **Alternative**: Official Apptainer repository setup
- **Fallback**: GitHub releases for both Apptainer and Singularity

**Validation Criteria:**

- [x] Apptainer binary installed and functional
- [x] All dependencies (fuse, squashfs-tools, uidmap, libfuse2, libseccomp2) installed
- [x] Container can execute simple commands
- [x] Version check returns expected output
- [x] Security configuration properly applied

**Test Commands:**

```bash
# Check Apptainer installation
apptainer --version

# Check Singularity compatibility (if using singularity-container package)
singularity --version

# Test basic functionality
apptainer exec docker://hello-world echo "Container runtime working"

# Verify dependencies
dpkg -l | grep -E "(fuse|squashfs-tools|uidmap|libfuse2|libseccomp2)"

# Test security configuration
apptainer config validate
```

**Success Criteria:**

- Apptainer version >= 4.1.5 (or Singularity >= 4.1.5 if using singularity-container)
- Can pull and execute Docker containers
- No permission errors during container execution
- Security policies properly configured
- Debian package installation method working

**Testing Requirements:**

- **Test Suite**: Create `test-infra/suites/container-runtime/` using Task 004 framework
- **Validation Scripts**:
  - `check-singularity-install.sh` - Verify installation and version
  - `check-container-execution.sh` - Test container pull and execution
  - `check-container-security.sh` - Validate security policies
  - `run-container-runtime-tests.sh` - Master test runner
- **Test Configuration**: `test-container-runtime.yaml` with container-enabled nodes
- **Integration**: Extend Task 004's framework to support container validation

**Implementation Summary:**

Based on the implementation in the `ansible` branch, the following deliverables were completed:

- ✅ **Container Runtime Role**: Complete Ansible role with Apptainer installation
- ✅ **Security Policies**: Comprehensive security configuration for container runtime
- ✅ **Test Framework**: Full test suite with validation scripts
- ✅ **Integration**: Updated playbooks and SLURM configuration for container support
- ✅ **Documentation**: Configuration templates and usage examples

**Key Implementation Details:**

- Apptainer version updated to 1.4.2 (from originally planned 4.1.5+ds4-1)
- Complete security policy configuration implemented
- Test scripts created: `check-singularity-install.sh`, `check-container-execution.sh`, `check-container-security.sh`
- Integration with existing test framework from Task 004
- Updated SLURM configuration to use Apptainer as container runtime

---

#### Task 009: Configure Container Security Policies

- **ID**: TASK-009
- **Phase**: 1 - Infrastructure  
- **Dependencies**: TASK-008
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate

**Description:** Create and deploy container security configuration to prevent
privilege escalation and ensure proper isolation.

**Deliverables:**

- `ansible/roles/container-runtime/templates/singularity.conf.j2`
- `ansible/roles/container-runtime/tasks/security.yml`
- Security policy validation tests

**Security Configuration:**

```ini
# Key security settings
allow suid = no
allow pid ns = yes
config passwd = yes
config group = yes
config resolv_conf = yes
mount proc = yes
mount sys = yes
mount dev = yes
mount home = yes
mount tmp = yes
mount hostfs = no
bind path = /etc/localtime
bind path = /etc/hosts
user bind control = yes
enable overlay = yes
enable underlay = no
mount slave = yes
sessiondir max size = 16
allow container squashfs = yes
allow container extfs = yes
allow container dir = yes
limit container owners = null
limit container groups = null
allow container encrypted = yes
allow net users = null
allow net groups = null
allow net networks = null
always use nv = no
root default capabilities = full
```

**Validation Criteria:**

- [ ] Configuration file deployed to `/etc/singularity/singularity.conf`
- [ ] Security policies prevent SUID execution
- [ ] Container cannot access host root filesystem
- [ ] User namespace isolation working

**Test Commands:**

```bash
# Test security policies
singularity exec docker://ubuntu:20.04 whoami
singularity exec docker://ubuntu:20.04 ls /root  # Should fail
singularity exec docker://ubuntu:20.04 mount     # Should show limited mounts

# Verify configuration
cat /etc/singularity/singularity.conf | grep -E "(allow suid|mount hostfs)"
```

**Success Criteria:**

- Container cannot escalate privileges
- Host filesystem properly isolated
- Configuration passes security audit

**Testing Requirements:**

- **Security Validation**: Extend `test-infra/suites/container-runtime/` with security tests
- **Test Scripts**:
  - `check-privilege-escalation.sh` - Verify no privilege escalation possible
  - `check-filesystem-isolation.sh` - Test host filesystem access restrictions
  - `check-security-policies.sh` - Validate security configuration
- **Integration Testing**: Security tests integrated with Task 008's container testing suite

---

### SLURM Controller Foundation

#### Task 010: Create SLURM Controller Installation Task

- **ID**: TASK-010
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-007
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate

**Description:** Install SLURM controller packages with PMIx support and all
required dependencies.

**Deliverables:**

- `ansible/roles/slurm-controller/tasks/install.yml`
- `ansible/roles/slurm-controller/defaults/main.yml`
- Package installation validation

**Required Packages:**

```yaml
slurm_controller_packages:
  - slurm-wlm              # Core SLURM workload manager
  - slurm-wlm-doc          # Documentation
  - slurmdbd               # Database daemon for accounting
  - slurm-client           # Client tools
  - munge                  # Authentication daemon
  - libmunge-dev           # Development libraries
  - mariadb-server         # Database backend
  - libmariadb-dev         # Database client libraries
  - libpmix2               # PMIx for MPI integration
  - libpmix-dev            # PMIx development headers
```

**Validation Criteria:**

- [ ] All SLURM packages installed successfully
- [ ] PMIx libraries available
- [ ] MariaDB server installed and running
- [ ] MUNGE authentication service available

**Test Commands:**

```bash
# Verify SLURM installation
slurmctld -V
slurmdbd -V
sinfo --version

# Check PMIx support
ls /usr/lib/x86_64-linux-gnu/libpmix*

# Verify database
systemctl status mariadb
mysql --version

# Check MUNGE
systemctl status munge
mungekey --version
```

**Success Criteria:**

- SLURM version >= 21.08
- PMIx libraries version >= 2.0
- MariaDB service active and running
- All package dependencies resolved

---

#### Task 011: Configure SLURM PMIx Integration

- **ID**: TASK-011
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-010
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate-Advanced

**Description:** Create SLURM configuration template with PMIx integration and
MPI support.

**Deliverables:**

- `ansible/roles/slurm-controller/templates/slurm.conf.j2`
- PMIx configuration parameters
- MPI integration validation

**Key Configuration Settings:**

```ini
# MPI Integration (PMIx Compliant)
MpiDefault=pmix
MpiParams=ports=12000-12999

# Resource Management
GresTypes=gpu
SelectType=select/cons_tres
SelectTypeParameters=CR_Core_Memory

# Process Tracking
ProctrackType=proctrack/cgroup
TaskPlugin=task/cgroup,task/affinity
TaskPluginParam=Sched
```

**Validation Criteria:**

- [ ] slurm.conf contains PMIx configuration
- [ ] MPI port range properly configured
- [ ] Resource management settings correct
- [ ] Configuration syntax valid

**Test Commands:**

```bash
# Validate configuration syntax
slurmctld -D -vvv  # Dry run with verbose output

# Check PMIx support
srun --mpi=list | grep pmix

# Verify configuration values
grep -E "(MpiDefault|MpiParams|GresTypes)" /etc/slurm/slurm.conf
```

**Success Criteria:**

- SLURM accepts configuration without errors
- PMIx listed as available MPI implementation
- Port range 12000-12999 reserved for MPI

---

#### Task 012: Set Up MUNGE Authentication

- **ID**: TASK-012
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-010
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate

**Description:** Configure MUNGE authentication system for secure SLURM
communication across cluster nodes.

**Deliverables:**

- `ansible/roles/slurm-controller/tasks/munge.yml`
- MUNGE key generation and distribution
- Service configuration and startup

**Implementation Steps:**

1. Generate MUNGE key on controller
2. Distribute key to all cluster nodes
3. Configure MUNGE service
4. Start and enable MUNGE daemon

**Validation Criteria:**

- [ ] MUNGE key generated and distributed
- [ ] MUNGE service running on all nodes
- [ ] Authentication working between nodes
- [ ] Proper file permissions (600 for munge.key)

**Test Commands:**

```bash
# Check MUNGE service
systemctl status munge

# Test authentication
munge -n | unmunge
echo "test" | munge | ssh compute-node unmunge

# Verify key permissions
ls -la /etc/munge/munge.key
```

**Success Criteria:**

- MUNGE service active on all nodes
- Cross-node authentication successful
- Key file has correct ownership (munge:munge) and permissions (600)

---

#### Task 013: Configure SLURM Container Plugin

- **ID**: TASK-013
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-009, TASK-011
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate-Advanced

**Description:** Set up SLURM container plugin integration for
Singularity/Apptainer container execution.

**Deliverables:**

- `ansible/roles/slurm-controller/templates/plugstack.conf.j2`
- `ansible/roles/slurm-controller/templates/container.conf.j2`
- Container plugin validation

**Configuration Files:**

```ini
# plugstack.conf
include /etc/slurm/container.conf

# container.conf
required=/usr/lib/x86_64-linux-gnu/slurm-wlm/container_singularity.so

[singularity]
runtime_path=/usr/bin/singularity
enable_overlay=true
enable_gpu=true
enable_nv=true
mount_home=true
mount_tmp=true
image_path=/opt/containers
allow_suid=false
contain=true
writable=false
```

**Validation Criteria:**

- [ ] Container plugin configuration files created
- [ ] Singularity plugin library exists
- [ ] SLURM can load container plugin
- [ ] Container execution parameters correct

**Test Commands:**

```bash
# Verify plugin library
ls -la /usr/lib/x86_64-linux-gnu/slurm-wlm/container_singularity.so

# Check configuration syntax
slurmctld -D -vvv | grep -i container

# Test container plugin loading
grep -i "container" /var/log/slurm/slurmctld.log
```

**Success Criteria:**

- Container plugin loads without errors
- SLURM recognizes container execution capabilities
- Configuration passes validation checks

---

### Infrastructure Enhancement

#### Task 014: Enhance Inventory Generator for GPU Detection

- **ID**: TASK-014
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-007
- **Estimated Time**: 6 hours
- **Difficulty**: Intermediate-Advanced

**Description:** Extend the Python inventory generator to detect PCIe
passthrough GPUs and generate proper SLURM GRES configuration.

**Deliverables:**

- Enhanced `ansible/inventories/generate_inventory.py`
- GPU detection and mapping logic
- GRES configuration generation
- Validation tests for inventory generation

**Key Enhancements:**

```python
def detect_gpu_resources(self, node_config):
    """Detect GPU resources via PCIe passthrough configuration"""
    gpu_devices = []
    if node_config.get('pcie_passthrough', {}).get('enabled', False):
        for device in node_config['pcie_passthrough']['devices']:
            if device['device_type'] == 'gpu':
                gpu_devices.append({
                    'device_id': device['device_id'],
                    'vendor': device.get('vendor', 'nvidia'),
                    'memory': device.get('memory', 'unknown')
                })
    return gpu_devices

def generate_gres_config(self, gpu_devices, node_name):
    """Generate GRES configuration for GPU resources"""
    gres_config = []
    for i, gpu in enumerate(gpu_devices):
        gres_config.append(f"NodeName={node_name} Name=gpu Type={gpu['device_id']} File=/dev/nvidia{i}")
    return gres_config
```

**Validation Criteria:**

- [ ] Script detects GPU devices from cluster.yaml
- [ ] GRES configuration generated correctly
- [ ] Inventory includes GPU-specific variables
- [ ] Output validates against SLURM configuration requirements

**Test Commands:**

```bash
# Run inventory generator
cd ansible/inventories
python3 generate_inventory.py

# Verify GPU detection
grep -A5 -B5 "gpu" inventories/hpc/hosts.yml

# Check GRES configuration
grep "slurm_gres" inventories/hpc/hosts.yml

# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('inventories/hpc/hosts.yml'))"
```

**Success Criteria:**

- GPU nodes correctly identified in inventory
- GRES configuration matches PCIe passthrough setup
- Inventory passes YAML validation
- Generated configuration compatible with SLURM

---

### Monitoring Infrastructure

#### Task 015: Install Prometheus Monitoring Stack

- **ID**: TASK-015
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-007
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate

**Description:** Install and configure Prometheus monitoring system for HPC
cluster metrics collection.

**Deliverables:**

- `ansible/roles/monitoring-stack/tasks/prometheus.yml`
- Prometheus configuration template
- Node exporter installation
- Basic monitoring setup

**Required Components:**

```yaml
prometheus_packages:
  - prometheus              # Metrics collection server
  - prometheus-node-exporter # System metrics
  - alertmanager           # Alert routing
```

**Validation Criteria:**

- [ ] Prometheus server installed and running
- [ ] Node exporters running on all nodes
- [ ] Basic system metrics being collected
- [ ] Prometheus web UI accessible

**Test Commands:**

```bash
# Check Prometheus service
systemctl status prometheus
curl http://localhost:9090/api/v1/query?query=up

# Verify node exporters
systemctl status prometheus-node-exporter
curl http://localhost:9100/metrics | head -20

# Test metrics collection
curl http://localhost:9090/api/v1/query?query=node_cpu_seconds_total
```

**Success Criteria:**

- Prometheus service active and healthy
- Node metrics visible in Prometheus UI
- All cluster nodes reporting metrics
- No configuration errors in logs

---

#### Task 016: Set Up Grafana Dashboard Platform

- **ID**: TASK-016
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-015
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate

**Description:** Install Grafana and create basic system monitoring dashboard
for HPC cluster visualization.

**Deliverables:**

- Grafana installation and configuration
- Prometheus data source configuration
- Basic system dashboard
- Dashboard access and security

**Dashboard Components:**

- CPU utilization by node
- Memory usage statistics
- Network I/O metrics
- System load averages
- Node availability status

**Validation Criteria:**

- [ ] Grafana service running and accessible
- [ ] Prometheus data source configured
- [ ] Basic dashboard displaying metrics
- [ ] Authentication working properly

**Test Commands:**

```bash
# Check Grafana service
systemctl status grafana-server
curl http://localhost:3000/api/health

# Test data source connection
curl -u admin:admin http://localhost:3000/api/datasources

# Verify dashboard
curl -u admin:admin http://localhost:3000/api/dashboards/home
```

**Success Criteria:**

- Grafana UI accessible on port 3000
- Prometheus data source connected and working
- System metrics visible in dashboard
- No authentication or connection errors

---

#### Task 017: Configure SLURM Job Accounting

- **ID**: TASK-017
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-010, TASK-012
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate-Advanced

**Description:** Set up SLURM job accounting with MariaDB backend for
comprehensive job metrics and resource usage tracking.

**Deliverables:**

- `ansible/roles/slurm-controller/tasks/accounting.yml`
- MariaDB database setup for SLURM accounting
- slurmdbd configuration
- Job accounting validation

**Configuration Components:**

```ini
# slurm.conf additions
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost=controller
AccountingStoragePort=6819
JobAcctGatherType=jobacct_gather/linux
JobAcctGatherParams=UsePss,NoOverMemoryKill
```

**Database Setup:**

- Create `slurm_acct_db` database
- Configure slurmdbd user and permissions
- Set up accounting tables

**Validation Criteria:**

- [ ] MariaDB configured for SLURM accounting
- [ ] slurmdbd service running and connected
- [ ] Job accounting data being collected
- [ ] sacct command returns job information

**Test Commands:**

```bash
# Check slurmdbd service
systemctl status slurmdbd

# Test database connection
mysql -u slurm -p slurm_acct_db -e "SHOW TABLES;"

# Verify job accounting
sacct --format=JobID,JobName,Partition,Account,AllocCPUS,State,ExitCode
squeue -o "%18i %12j %4t %10u %20q %20a %10g %20S %20e %8D %20R"

# Check accounting configuration
scontrol show config | grep -i accounting
```

**Success Criteria:**

- slurmdbd connects to MariaDB successfully
- Job submission creates accounting records
- sacct shows historical job information
- Resource usage metrics collected

---

#### Task 018: Deploy DCGM GPU Monitoring

- **ID**: TASK-018
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-015
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate

**Description:** Install and configure NVIDIA DCGM (Data Center GPU Manager) for
GPU metrics collection and Prometheus integration.

**Deliverables:**

- `ansible/roles/monitoring-stack/tasks/dcgm.yml`
- DCGM exporter configuration
- GPU metrics collection setup
- Prometheus GPU metrics integration

**Required Components:**

```yaml
dcgm_packages:
  - nvidia-dcgm            # Data Center GPU Manager
  - dcgm-exporter         # GPU Prometheus exporter
```

**Validation Criteria:**

- [ ] DCGM service running on GPU nodes
- [ ] GPU metrics exported to Prometheus
- [ ] GPU utilization and memory metrics visible
- [ ] No GPU monitoring errors

**Test Commands:**

```bash
# Check DCGM service
systemctl status nvidia-dcgm
dcgmi discovery -l

# Verify GPU metrics export
curl http://localhost:9400/metrics | grep -i gpu

# Test GPU monitoring
nvidia-smi
dcgmi dmon -e 155,204,1001,1002,1003,1004,1005,1006,1007,1008,1009,1010

# Check Prometheus integration
curl http://localhost:9090/api/v1/query?query=dcgm_gpu_utilization
```

**Success Criteria:**

- DCGM discovers all GPU devices
- GPU metrics available in Prometheus
- Utilization and memory metrics accurate
- No GPU communication errors

---

## Phase 2: Container Images & Compute Integration (Tasks 019-026)

### Container Image Development

#### Task 019: Create PyTorch Container Definition

- **ID**: TASK-019
- **Phase**: 2 - Container Development
- **Dependencies**: TASK-009
- **Estimated Time**: 6 hours
- **Difficulty**: Intermediate-Advanced

**Description:** Write Singularity definition file for PyTorch+MPI container
with CUDA support and monitoring tools.

**Deliverables:**

- `ansible/roles/ml-container-images/templates/pytorch-mpi.def.j2`
- Container requirements specification
- Build environment configuration
- Container validation tests

**Container Components:**

- NVIDIA CUDA 12.1 base image
- Python 3.10 with PyTorch >= 2.0
- Open MPI 4.1.4 with PMIx support
- Monitoring tools (tensorboard, wandb, nvitop)
- Development and debugging tools

**Key Software Stack:**

```bash
# Base: nvidia/cuda:12.1-devel-ubuntu22.04
# PyTorch: torch>=2.0.0+cu121
# MPI: OpenMPI 4.1.4 with CUDA and PMIx support
# Tools: tensorboard, wandb, nvitop, py-spy, memory-profiler
```

**Validation Criteria:**

- [ ] Singularity definition file syntactically correct
- [ ] All required software components included
- [ ] CUDA and PyTorch integration working
- [ ] MPI functionality validated

**Test Commands:**

```bash
# Validate definition syntax
singularity build --dry-run pytorch-test.sif pytorch-mpi.def

# Check template rendering
ansible-playbook -i localhost, --check --diff test-container-template.yml

# Verify required components listed
grep -E "(pytorch|openmpi|cuda)" pytorch-mpi.def
```

**Success Criteria:**

- Definition file passes Singularity syntax validation
- Template variables properly configured
- All required dependencies specified
- Build instructions complete and accurate

---

#### Task 020: Automate Container Image Building

- **ID**: TASK-020
- **Phase**: 2 - Container Development
- **Dependencies**: TASK-019
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate

**Description:** Create Ansible tasks to automatically build Singularity
container images from definition files with validation.

**Deliverables:**

- `ansible/roles/ml-container-images/tasks/pytorch-mpi.yml`
- Container build automation
- Image validation tests
- Build artifact management

**Build Process:**

1. Render Singularity definition from template
2. Execute container build with proper permissions
3. Validate container functionality
4. Store image in registry location

**Validation Criteria:**

- [ ] Container builds successfully without errors
- [ ] Built image passes functionality tests
- [ ] Image stored in correct registry location
- [ ] Build process is repeatable

**Test Commands:**

```bash
# Test build process
ansible-playbook -i inventories/hpc/hosts.yml build-containers.yml --limit controller

# Verify built image
ls -la /opt/containers/pytorch-mpi-*.sif

# Test container functionality
singularity exec /opt/containers/pytorch-mpi-*.sif python3 -c "import torch; print(torch.__version__)"
singularity exec /opt/containers/pytorch-mpi-*.sif mpirun --version
```

**Success Criteria:**

- Container builds without compilation errors
- PyTorch and CUDA functional in container
- MPI communication working
- Image size reasonable (<5GB for base image)

---

#### Task 021: Set Up Container Image Registry

- **ID**: TASK-021
- **Phase**: 2 - Container Development
- **Dependencies**: TASK-020
- **Estimated Time**: 3 hours
- **Difficulty**: Junior-Intermediate

**Description:** Create shared directory structure and permissions system for
container image distribution across cluster.

**Deliverables:**

- Container registry directory structure
- Proper permissions and ownership
- Image distribution mechanism
- Registry management tools

**Registry Structure:**

```text
/opt/containers/
├── pytorch-mpi-2.0-mpi4.1.4.sif
├── pytorch-mpi-2.1-mpi4.1.4.sif
├── base-images/
├── custom-images/
└── registry.yaml (metadata)
```

**Validation Criteria:**

- [ ] Registry directory created with correct permissions
- [ ] All cluster nodes can access registry
- [ ] Image metadata tracking working
- [ ] Version management functional

**Test Commands:**

```bash
# Check registry structure
ls -la /opt/containers/

# Verify permissions
stat -c "%a %U:%G" /opt/containers/

# Test access from compute nodes
ansible slurm_compute -i inventories/hpc/hosts.yml -m shell -a "ls /opt/containers/"

# Validate image accessibility
singularity exec /opt/containers/pytorch-mpi-*.sif echo "Registry access working"
```

**Success Criteria:**

- All nodes can read from registry
- Proper ownership (root:slurm) and permissions (755)
- Images accessible for container execution
- Registry structure supports versioning

---

### Compute Node Integration

#### Task 022: Create SLURM Compute Node Installation

- **ID**: TASK-022
- **Phase**: 2 - Compute Integration
- **Dependencies**: TASK-008, TASK-012
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate

**Description:** Install SLURM compute node components with container runtime
integration.

**Deliverables:**

- `ansible/roles/slurm-compute/tasks/install.yml`
- Compute node package installation
- Service configuration
- Node registration with controller

**Required Packages:**

```yaml
slurm_compute_packages:
  - slurmd                 # SLURM daemon
  - slurm-client          # Client tools
  - munge                 # Authentication
  - libmunge2             # Runtime libraries
  - libpmix2              # PMIx runtime
  - singularity-container # Container runtime (if available)
```

**Validation Criteria:**

- [ ] All compute packages installed successfully
- [ ] slurmd service configured and running
- [ ] Node communicates with controller
- [ ] Container runtime available

**Test Commands:**

```bash
# Check slurmd service
systemctl status slurmd

# Verify node registration
sinfo -N -l | grep compute

# Test SLURM communication
srun --nodes=1 --ntasks=1 hostname

# Verify container availability
singularity --version
```

**Success Criteria:**

- slurmd service active on all compute nodes
- Nodes show as available in sinfo output
- Can execute simple jobs on compute nodes
- Container runtime functional

**Testing Requirements:**

- **Multi-Node Test Suite**: Create `test-infra/suites/multi-node/` using Task 004 framework
- **Validation Scripts**:
  - `check-slurm-cluster.sh` - Verify all nodes available in SLURM
  - `check-multi-node-communication.sh` - Test node-to-node connectivity
  - `check-distributed-jobs.sh` - Validate multi-node job execution
  - `run-multi-node-tests.sh` - Master test runner
- **Test Configuration**: `test-multi-node.yaml` with multiple compute nodes
- **Job Validation**: Multi-node test jobs for SLURM functionality verification

---

#### Task 023: Configure GPU Resources (GRES)

- **ID**: TASK-023
- **Phase**: 2 - Compute Integration
- **Dependencies**: TASK-014, TASK-022
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate-Advanced

**Description:** Create GRES configuration for GPU resource management and
scheduling in SLURM.

**Deliverables:**

- `ansible/roles/slurm-compute/templates/gres.conf.j2`
- GPU device mapping configuration
- NVML auto-detection setup
- GPU resource validation

**GRES Configuration Example:**

```ini
# Manual GPU configuration
NodeName=compute-01 Name=gpu Type=rtx4090 File=/dev/nvidia0
NodeName=compute-01 Name=gpu Type=rtx4090 File=/dev/nvidia1

# Auto-detection alternative
NodeName=compute-01 AutoDetect=nvml
```

**Validation Criteria:**

- [ ] GRES configuration deployed to compute nodes
- [ ] GPU devices properly mapped
- [ ] SLURM recognizes GPU resources
- [ ] GPU scheduling functional

**Test Commands:**

```bash
# Check GRES configuration
cat /etc/slurm/gres.conf

# Verify GPU detection
sinfo -o "%20N %10c %10m %25f %10G %6t"

# Test GPU job submission
srun --gres=gpu:1 nvidia-smi

# Validate resource allocation
scontrol show node compute-01 | grep -i gres
```

**Success Criteria:**

- GPU resources visible in sinfo output
- Can submit jobs requesting GPU resources
- GPU allocation prevents conflicts
- Resource counts match physical hardware

---

#### Task 024: Set Up Cgroup Resource Isolation

- **ID**: TASK-024
- **Phase**: 2 - Compute Integration
- **Dependencies**: TASK-022
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate-Advanced

**Description:** Configure cgroup-based resource isolation for CPU, memory, and
GPU device access control.

**Deliverables:**

- `ansible/roles/slurm-compute/templates/cgroup.conf.j2`
- Cgroup hierarchy setup
- Resource limit enforcement
- Device isolation configuration

**Cgroup Configuration:**

```ini
CgroupAutomount=yes
CgroupReleaseAgentDir="/etc/slurm/cgroup"
ConstrainCores=yes
ConstrainDevices=yes
ConstrainRAMSpace=yes
ConstrainSwapSpace=no
TaskAffinity=yes
AllowedDevicesFile="/etc/slurm/cgroup_allowed_devices_file.conf"
```

**Validation Criteria:**

- [ ] Cgroup configuration deployed and active
- [ ] Resource constraints enforced
- [ ] GPU device isolation working
- [ ] Jobs cannot exceed allocated resources

**Test Commands:**

```bash
# Check cgroup configuration
cat /etc/slurm/cgroup.conf

# Verify cgroup mounting
mount | grep cgroup

# Test resource isolation
srun --mem=1G --cpus-per-task=1 stress --vm 1 --vm-bytes 2G --timeout 10s  # Should fail

# Check device constraints
srun --gres=gpu:1 nvidia-smi -L | wc -l  # Should show 1 GPU
```

**Success Criteria:**

- Jobs respect memory and CPU limits
- GPU access properly isolated
- Resource oversubscription prevented
- Cgroup hierarchy properly structured

---

#### Task 025: Create Failure Detection Scripts

- **ID**: TASK-025
- **Phase**: 2 - Compute Integration
- **Dependencies**: TASK-017
- **Estimated Time**: 6 hours
- **Difficulty**: Advanced

**Description:** Implement SLURM epilog/prolog scripts for job completion
analysis and distributed training failure debugging.

**Deliverables:**

- `/etc/slurm/epilog.sh` - Job completion analysis
- `/etc/slurm/prolog.sh` - Job initialization checks
- `/opt/slurm/bin/diagnose_training_failure.py` - Failure diagnosis tool
- Failure analysis automation

**Script Functionality:**

- GPU utilization tracking at job completion
- Container execution validation
- MPI communication health checks
- Distributed training environment validation
- Automated failure pattern detection

**Validation Criteria:**

- [ ] Epilog/prolog scripts execute on job events
- [ ] Failure diagnosis captures relevant information
- [ ] Debug information stored in structured format
- [ ] Common failure patterns detected automatically

**Test Commands:**

```bash
# Test epilog execution
srun --job-name=test-epilog echo "Testing epilog"
grep "test-epilog" /var/log/slurm/job_metrics.log

# Verify prolog execution
srun --job-name=test-prolog echo "Testing prolog"

# Test failure diagnosis
python3 /opt/slurm/bin/diagnose_training_failure.py

# Check debug directory creation
ls -la /var/log/slurm/debug/
```

**Success Criteria:**

- Scripts execute without errors on job events
- Failure diagnosis captures comprehensive system state
- Debug information helps identify common issues
- Automation reduces manual debugging time

---

#### Task 026: Create Container Validation Tests

- **ID**: TASK-026
- **Phase**: 2 - Integration Validation
- **Dependencies**: TASK-021, TASK-023, TASK-024
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate-Advanced

**Description:** Implement comprehensive validation tests for PyTorch CUDA, MPI
functionality, and GPU access within containers.

**Deliverables:**

- Container functionality test suite
- PyTorch distributed training validation
- GPU access and utilization tests
- MPI communication verification

**Test Categories:**

1. **Basic Container Functionality**
   - Container execution and environment
   - Python and package availability
   - File system access and permissions

2. **PyTorch and CUDA Validation**
   - PyTorch installation and version
   - CUDA availability and device detection
   - GPU memory allocation and computation

3. **MPI Communication Tests**
   - MPI library functionality
   - Multi-process communication
   - PMIx integration validation

4. **Distributed Training Simulation**
   - Multi-node container coordination
   - Environment variable propagation
   - NCCL backend functionality

**Validation Criteria:**

- [ ] All container functionality tests pass
- [ ] PyTorch can utilize GPUs within containers
- [ ] MPI communication works across container instances
- [ ] Distributed training environment properly configured

**Test Commands:**

```bash
# Run comprehensive validation
ansible-playbook -i inventories/hpc/hosts.yml validate-containers.yml

# Test PyTorch CUDA in container
srun --gres=gpu:1 --container-image=/opt/containers/pytorch-mpi-*.sif \
  python3 -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"

# Test MPI across nodes
srun --nodes=2 --ntasks=4 --container-image=/opt/containers/pytorch-mpi-*.sif \
  python3 -c "from mpi4py import MPI; print(f'Rank {MPI.COMM_WORLD.Get_rank()}')"

# Validate distributed training setup
srun --nodes=2 --ntasks-per-node=1 --gres=gpu:1 \
  --container-image=/opt/containers/pytorch-mpi-*.sif \
  python3 /opt/test-scripts/validate_distributed_pytorch.py
```

**Success Criteria:**

- Container tests pass on all node types
- PyTorch detects and utilizes GPUs correctly
- MPI processes communicate across nodes
- Distributed training environment variables set correctly
- No container execution or permission errors

**Testing Requirements:**

- **Container Integration Test Suite**: Create `test-infra/suites/container-integration/` using Task 004 framework
- **Advanced Validation Scripts**:
  - `check-pytorch-cuda-integration.sh` - PyTorch + CUDA functionality
  - `check-mpi-communication.sh` - MPI across container instances
  - `check-distributed-training.sh` - Multi-node distributed training setup
  - `check-container-slurm-integration.sh` - SLURM + container execution
  - `run-container-integration-tests.sh` - Master test runner
- **Full Integration Testing**: Combines container runtime, SLURM scheduling, and GPU resources

---

## Phase 3: Integration Testing & Validation (Tasks 027-030)

### End-to-End Integration Testing

#### Task 027: Execute Full-Stack Integration Testing

- **ID**: TASK-027
- **Phase**: 3 - Integration Testing
- **Dependencies**: TASK-005, TASK-018, TASK-021
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate-Advanced

**Description:** Execute comprehensive full-stack integration
testing using the established Task 004/005 framework with
complete HPC SLURM deployment validation.

**Deliverables:**

- Full-stack test configuration extending Task 005's framework
- Production-scale test validation suite
- Complete system integration test execution
- Performance and reliability baseline documentation

**Framework-Based Integration Testing:**

Using established framework to validate:

- Complete HPC SLURM stack (controller + compute nodes)
- Container runtime integration with SLURM scheduling
- GPU resource management and allocation
- Monitoring stack integration (Prometheus, Grafana, DCGM)
- Multi-node distributed workload execution

**Validation Criteria:**

- [ ] Full-stack deployment validates using established framework
- [ ] All component test suites pass in integrated environment
- [ ] Production-scale workloads execute successfully
- [ ] Performance metrics meet baseline requirements
- [ ] System resilience validated under load testing

**Framework-Based Test Execution:**

```bash
# Execute full-stack integration testing using established framework
# Production-scale test configuration
./test-infra/test-pcie-passthrough-framework.sh \
    --config test-infra/suites/full-stack/test-full-stack.yaml \
    --validation-suite full-stack \
    --verbose

# Run comprehensive test suite covering all components
for suite in basic-cluster container-runtime gpu-passthrough multi-node full-stack; do
    echo "=== Running $suite test suite ==="
    ./test-infra/test-pcie-passthrough-framework.sh \
        --config "test-infra/suites/$suite/test-$suite.yaml" \
        --validation-suite "$suite"
done

# Performance and load testing using framework
./test-infra/test-pcie-passthrough-framework.sh \
    --config test-infra/suites/performance/test-performance.yaml \
    --validation-suite performance \
    --no-cleanup  # For performance analysis
```

**Framework-Based Success Criteria:**

- All test suites pass using established framework pattern
- Full-stack deployment completes within framework timeout limits
- Performance test suite validates system under production-scale loads
- Framework logging captures comprehensive system state for analysis

---

#### Task 028: Execute Comprehensive Validation Suite

- **ID**: TASK-028
- **Phase**: 3 - Integration Testing
- **Dependencies**: TASK-027
- **Estimated Time**: 6 hours
- **Difficulty**: Advanced

**Description:** Run comprehensive test suite validating all task
implementations and system functionality.

**Deliverables:**

- Complete validation test execution
- Test results report and analysis
- Performance metrics collection
- Failure scenario testing

**Test Categories:**

1. **Service Integration Tests**: All services communicate properly
2. **Container Execution Tests**: Various container scenarios work
3. **GPU Resource Tests**: GPU scheduling and utilization
4. **MPI Communication Tests**: Multi-node distributed jobs
5. **Monitoring Integration Tests**: Metrics collection and alerting
6. **Failure Recovery Tests**: System behavior under failure conditions

**Validation Criteria:**

- [ ] All integration tests pass
- [ ] Performance metrics within acceptable ranges
- [ ] Failure scenarios handled gracefully
- [ ] Resource utilization optimized

**Test Commands:**

```bash
# Run comprehensive validation suite
python3 test-infra/test-framework/test_runner.py --suite=comprehensive --report=detailed

# Execute performance tests
python3 test-infra/test-framework/test_runner.py --suite=performance --baseline

# Test failure scenarios
python3 test-infra/test-framework/test_runner.py --suite=failure-scenarios

# Generate final report
python3 test-infra/test-framework/test_runner.py --generate-final-report
```

**Success Criteria:**

- >95% of tests pass
- Performance within 20% of baseline expectations
- All failure scenarios handled without system crash
- Complete test coverage of all task deliverables

---

#### Task 029: Create Production Deployment Documentation

- **ID**: TASK-029
- **Phase**: 3 - Documentation
- **Dependencies**: TASK-028
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate

**Description:** Generate comprehensive documentation for production deployment
based on validated test results.

**Deliverables:**

- Production deployment guide
- Configuration templates and examples
- Troubleshooting and maintenance procedures
- Performance tuning recommendations

**Documentation Components:**

- Step-by-step deployment instructions
- Hardware and software requirements
- Network and security configuration
- Monitoring and alerting setup
- Backup and recovery procedures
- Scaling and optimization guidelines

**Validation Criteria:**

- [ ] Documentation complete and accurate
- [ ] All configuration examples tested
- [ ] Troubleshooting procedures validated
- [ ] Production readiness checklist created

**Test Commands:**

```bash
# Validate documentation examples
cd docs/deployment/
bash validate-config-examples.sh

# Test troubleshooting procedures
python3 test-troubleshooting-scenarios.py

# Check documentation completeness
python3 validate-documentation-coverage.py
```

**Success Criteria:**

- Documentation enables successful production deployment
- All examples and procedures tested and working
- Troubleshooting covers common scenarios
- Clear migration path from test to production

---

#### Task 030: Conduct Final Integration Validation

- **ID**: TASK-030
- **Phase**: 3 - Final Validation
- **Dependencies**: TASK-029
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate

**Description:** Perform final validation of complete system against original
requirements and success criteria.

**Deliverables:**

- Final system validation report
- Requirements traceability matrix
- Performance benchmark results
- Production readiness assessment

**Final Validation Areas:**

- All original requirements satisfied
- System performance meets specifications
- Security and isolation working properly
- Monitoring and observability complete
- Documentation accurate and complete
- Production deployment ready

**Validation Criteria:**

- [ ] All requirements met and verified
- [ ] Performance benchmarks achieved
- [ ] Security validation passed
- [ ] Complete system traceability

**Test Commands:**

```bash
# Final requirements validation
python3 test-infra/validation/final-requirements-check.py

# Performance benchmark validation
python3 test-infra/validation/performance-benchmark.py

# Security and isolation validation
python3 test-infra/validation/security-validation.py

# Generate final assessment report
python3 test-infra/validation/final-assessment.py
```

**Success Criteria:**

- 100% requirements coverage validated
- Performance meets or exceeds specifications
- Security model properly implemented
- System ready for production deployment

---

## Task Dependencies and Execution Order

### Phase 0 Execution Flow

```text
TASK-001 → TASK-002 → TASK-003 → TASK-004 → TASK-005 → TASK-006 (Optional)
                                     ↑
                              ✅ COMPLETED - Framework Foundation
```

**Important Update**: TASK-004 is now **COMPLETED** and provides the
foundational testing framework that subsequent tasks leverage. This
eliminates the need for separate pytest-based testing infrastructure
and provides a consistent, proven approach for all integration testing.

**Framework Impact:**

- **TASK-005**: Now leverages TASK-004's framework instead of creating separate infrastructure
- **TASK-027**: Uses established framework pattern for full-stack testing
- **Testing Consistency**: All integration tests use the same reliable framework
- **Reduced Complexity**: Eliminates redundant testing infrastructure development

### Testing Plan Evolution Summary

**Before Task 004 Implementation:**

- Separate pytest-based integration test infrastructure (Task 005)
- Ansible playbook-based deployment testing (Task 027)
- **Testing functionality before implementation** (logical inconsistency)
- Multiple different testing approaches and patterns
- Potential for testing inconsistencies and maintenance overhead

**After Task 004 Implementation + Logical Restructuring:**

- **Unified Framework**: Single, proven testing framework for all scenarios  
- **Testing-at-Implementation**: Tests added to tasks that implement functionality
- **Logical Dependencies**: No testing of unimplemented functionality
- **Real Deployments**: All tests use actual ai-how cluster deployments
- **Modular Test Suites**: Specialized validation scripts following consistent patterns
- **Production Alignment**: Testing approach matches production deployment tools

**Restructured Testing Approach:**

- **Task 005**: Basic infrastructure testing (what's available in Phase 0)
- **Task 008-009**: Container runtime testing (when containers implemented)  
- **Task 022**: Multi-node testing (when SLURM compute nodes implemented)
- **Task 026**: Container integration testing (when full stack available)
- **Task 027**: Full-stack integration testing (leveraging all previous tests)

**Key Benefits of Framework-Centric + Logic-First Approach:**

1. **Logical Consistency**: Tests only what's implemented
2. **Reduced Development Time**: Task 005 reduced from 4h to 2h  
3. **Improved Reliability**: Proven framework with comprehensive error handling
4. **Better Maintainability**: Single testing pattern, tests with implementation
5. **Enhanced Consistency**: All tests follow the same execution and validation patterns
6. **Real-World Validation**: Tests actual deployments rather than simulated environments

### Phase 1 Execution Flow

```text
TASK-007 → TASK-008 ✅ → TASK-009
    ↓         ↓
TASK-010 → TASK-011 → TASK-012 → TASK-013
    ↓
TASK-014
    ↓
TASK-015 → TASK-016
    ↓         ↓
TASK-017   TASK-018
```

### Phase 2 Execution Flow

```text
TASK-019 → TASK-020 → TASK-021
    ↓
TASK-022 → TASK-023 → TASK-024 → TASK-025
    ↓                     ↓         ↓
TASK-026 ←←←←←←←←←←←←←←←←←←←←←←←←←
```

### Phase 3 Execution Flow

```text
TASK-027 → TASK-028 → TASK-029 → TASK-030
```

## Success Metrics

### Individual Task Success

- **Technical Validation**: All test commands pass
- **Integration Testing**: Task output works with dependent tasks
- **Documentation**: Deliverables match specifications
- **Repeatability**: Task can be executed multiple times safely

### Overall Implementation Success

- **Functional SLURM Cluster**: All nodes active and job scheduling working
- **Container Integration**: Containerized jobs execute successfully
- **GPU Scheduling**: GPU resources properly allocated and utilized
- **Monitoring Active**: Metrics collection and alerting functional
- **Failure Detection**: Automated debugging and analysis working

## Testing Framework

**Framework-Centric Approach (Based on Task 004 Implementation):**

The testing strategy leverages the comprehensive automated testing framework
established in Task 004, providing consistent, reliable, and scalable testing
across all deployment scenarios.

**Framework Components:**

- **Automated Cluster Orchestration**: Real ai-how deployments for authentic testing
- **Modular Test Suites**: Specialized validation scripts for different scenarios
- **Comprehensive Logging**: Detailed test execution and debugging information
- **Automated Cleanup**: Ensures no test artifacts remain after execution

**Test Categories Using Framework:**

- **Basic Functionality Tests**: Core SLURM service validation
- **Container Integration Tests**: Singularity/container runtime validation  
- **GPU Passthrough Tests**: PCIe device and driver validation (Task 004)
- **Multi-Node Tests**: Distributed computing and MPI validation
- **Full-Stack Tests**: Complete system integration validation
- **Performance Tests**: Production-scale load and reliability testing

**Benefits of Framework-Centric Approach:**

- **Consistency**: All tests use the same proven framework pattern
- **Reliability**: Automated cleanup and error handling
- **Scalability**: Easy to add new test scenarios
- **CI/CD Ready**: Framework designed for automated pipeline integration
- **Real Testing**: Uses actual deployments, not mocks or simulations

## Documentation and Handoff

For each completed task:

- **Implementation Notes**: Decisions made and alternatives considered
- **Configuration Files**: All templates and configuration artifacts
- **Test Results**: Validation output and performance metrics
- **Troubleshooting Guide**: Common issues and resolution steps
- **Next Steps**: Recommendations for dependent tasks

This task breakdown provides a comprehensive roadmap for implementing the HPC
SLURM deployment with clear, testable milestones that can be executed
independently by junior engineers or automated systems.
