# Phase 0: Test Infrastructure Setup (Tasks 001-006)

**Status**: 100% Complete  
**Last Updated**: 2025-10-17  
**Tasks**: 6 (5 completed, 1 optional skipped)

## Overview

This phase established the foundational testing infrastructure for the HPC SLURM deployment project. All base images,
CLI tools, test configurations, and automated testing frameworks were successfully implemented.

## Completed Tasks

- **TASK-001**: Build HPC Base Images ✅
- **TASK-002**: Install and Configure AI-HOW CLI ✅
- **TASK-003**: Create Test Cluster Configurations ✅
- **TASK-004**: Automated PCIe Passthrough Testing Framework ✅
- **TASK-005**: Create Basic Infrastructure Testing Suite ✅
- **TASK-006**: CI/CD Integration Testing Pipeline (OPTIONAL - Skipped)

---

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
- Updated `example-multi-gpu-clusters.yaml` with correct image paths

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
uv run ai-how validate config/example-multi-gpu-clusters.yaml

# Test PCIe validation (with simulation)
uv run ai-how validate --skip-pcie-validation config/example-multi-gpu-clusters.yaml

# Test inventory commands
uv run ai-how inventory pcie

# Test cluster management commands (dry run)
uv run ai-how hpc --help
```

**Success Criteria:**

- ✅ CLI installation completes without dependency issues
- ✅ Configuration validation passes on example-multi-gpu-clusters.yaml
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
- Configuration validation testing with `config/example-multi-gpu-clusters.yaml`
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
example-multi-gpu-clusters.yaml for different validation scenarios.

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

#### Task 005: Create Basic Infrastructure Testing Suite ✅ COMPLETED

- **ID**: TASK-005
- **Phase**: 0 - Test Infrastructure
- **Dependencies**: TASK-003, TASK-004
- **Estimated Time**: 2 hours  
- **Difficulty**: Junior-Intermediate
- **Status**: ✅ COMPLETED
- **Completion Date**: 2025-01-27
- **Branch**: `idoudali/task-005`
- **Test Type**: Infrastructure Tests

**Description:** Create basic infrastructure testing suite that validates currently available functionality:
cluster lifecycle, VM networking, SSH connectivity, and configuration validation using Task 004's framework.

**Deliverables:**

- ✅ Modular test framework replacing monolithic approach
- ✅ Specialized test scripts for networking, configuration, SSH, and VM lifecycle
- ✅ Comprehensive logging and diagnostic capabilities
- ✅ Enhanced Makefile integration with new test targets
- ✅ Improved integration with existing test framework utilities

**New Modular Test Structure:**

```text
tests/suites/basic-infrastructure/     # Modular test approach
├── check-basic-networking.sh         # Network bridge, interface, and connectivity validation
├── check-configuration.sh            # YAML syntax and schema validation across all configs
├── check-ssh-connectivity.sh         # SSH key, authentication, and command execution testing
├── check-vm-lifecycle.sh             # VM state, resource allocation, and lifecycle management
└── run-basic-infrastructure-tests.sh # Original monolithic script (replaced)

tests/
├── test_run_basic_infrastructure.sh  # Main orchestrator with comprehensive CLI options
└── test_config_validation.sh         # Enhanced with --all-configs and --enhanced flags
```

**Key Framework Components:**

1. **Modular Test Scripts** - Each focused on specific infrastructure validation:
   - `check-basic-networking.sh`: Network bridges, VM interfaces, IP assignment, connectivity
   - `check-configuration.sh`: YAML syntax, schema validation, configuration script testing
   - `check-ssh-connectivity.sh`: SSH key validation, authentication, command execution
   - `check-vm-lifecycle.sh`: VM running state, definitions, resource allocation

2. **Main Orchestrator** - `test_run_basic_infrastructure.sh`:
   - Comprehensive CLI interface with help, verbose, and quick modes
   - Integration with existing test framework utilities
   - Support for custom configurations and target VM patterns
   - Cleanup and debugging options

3. **Enhanced Configuration Validation**:
   - `--all-configs` flag: Validates all test configuration files
   - `--enhanced` flag: Network subnet uniqueness and base image path validation
   - Integration with AI-HOW CLI validation

**BREAKING CHANGE:** Replaces `run-basic-infrastructure-tests.sh` with modular approach

**Implementation Summary:**

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

**Validation Criteria:**

- [x] Modular test scripts created and functional
- [x] Each test module includes detailed logging and error reporting
- [x] Main orchestrator script with comprehensive CLI options
- [x] Enhanced configuration validation with new flags
- [x] Makefile updated with new test targets
- [x] Integration with existing test framework utilities
- [x] Task 005 compliance patterns for maintainability

**Test Commands:**

```bash
# Primary approach: Use enhanced Makefile system
cd tests/
make test-infrastructure              # New target for basic infrastructure tests
make test-configuration              # Enhanced configuration validation
make test                           # Run core infrastructure tests

# Direct test suite execution
./tests/test_run_basic_infrastructure.sh

# Individual test modules
./tests/suites/basic-infrastructure/check-basic-networking.sh
./tests/suites/basic-infrastructure/check-configuration.sh
./tests/suites/basic-infrastructure/check-ssh-connectivity.sh
./tests/suites/basic-infrastructure/check-vm-lifecycle.sh

# Enhanced configuration validation
./tests/test_config_validation.sh --all-configs --enhanced

# Custom configuration and target patterns
./tests/test_run_basic_infrastructure.sh --config test-infra/configs/test-custom.yaml
./tests/test_run_basic_infrastructure.sh --target-vm "controller" --verbose
```

**Success Criteria:**

- ✅ Modular test framework provides focused, maintainable validation
- ✅ Each test module validates specific infrastructure components
- ✅ Main orchestrator integrates seamlessly with existing framework
- ✅ Enhanced configuration validation covers all test configs
- ✅ Makefile targets provide easy access to infrastructure testing
- ✅ Comprehensive logging and diagnostic capabilities
- ✅ Task 005 compliance patterns ensure maintainability

**Implementation Summary:**

**Files Created/Modified:**

- `tests/suites/basic-infrastructure/check-basic-networking.sh` - Network validation (300 lines)
- `tests/suites/basic-infrastructure/check-configuration.sh` - Configuration validation (285 lines)
- `tests/suites/basic-infrastructure/check-ssh-connectivity.sh` - SSH validation (291 lines)
- `tests/suites/basic-infrastructure/check-vm-lifecycle.sh` - VM lifecycle validation (242 lines)
- `tests/test_run_basic_infrastructure.sh` - Main orchestrator (269 lines)
- `tests/test_config_validation.sh` - Enhanced with new validation flags
- `tests/Makefile` - Updated with new test targets
- `tests/test-infra/configs/test-full-stack.yaml` - Updated with unique subnet ranges

**Key Features Implemented:**

- **Modular Architecture**: Replaced monolithic script with focused test modules
- **Comprehensive Logging**: Each module includes detailed logging with LOG_DIR compliance
- **Enhanced CLI Interface**: Main orchestrator with help, verbose, quick, and debugging options
- **Configuration Validation**: Extended validation to cover all test configs with uniqueness checks
- **Framework Integration**: Seamless integration with existing test framework utilities
- **Task 005 Compliance**: Follows established patterns for maintainability and diagnostics

**Test Module Features:**

- **Basic Networking**: Network bridges, VM interfaces, IP assignment, internal connectivity, DNS, ping
- **Configuration**: File existence, YAML syntax, validation script testing, schema validation
- **SSH Connectivity**: Key validation, permissions, VM connectivity, authentication, sudo access
- **VM Lifecycle**: Running state, definitions, network interfaces, memory/CPU allocation

**Integration Benefits:**

- **Consistency**: All tests follow Task 005 compliance patterns
- **Maintainability**: Modular approach enables independent development and testing
- **Diagnostics**: Comprehensive logging and error reporting for troubleshooting
- **Flexibility**: Support for custom configurations and target patterns
- **Framework Alignment**: Leverages existing comprehensive test infrastructure

**Network Configuration Updates:**

- Updated `test-full-stack.yaml` with unique subnet ranges:
  - HPC cluster: 192.168.180.0/24 (was 192.168.170.0/24)
  - Cloud cluster: 192.168.181.0/24 (was 192.168.180.0/24)
- Prevents network conflicts in concurrent test execution

**Makefile Integration:**

```makefile
# Run basic infrastructure tests (Task 005 - leveraging existing framework)
test-infrastructure:
 @./test_run_basic_infrastructure.sh

# Run configuration validation tests (Task 005 - enhanced validation)
test-configuration:
 @./tests/test_config_validation.sh --all-configs --enhanced
```

**Testing Requirements:**

- **Test Suite**: Complete modular test suite with specialized validation scripts
- **Framework Integration**: Full integration with existing Task 004 framework utilities
- **Enhanced Validation**: Extended configuration validation with new CLI flags
- **Makefile Integration**: New test targets for infrastructure and configuration testing
- **Documentation**: Comprehensive CLI help and usage examples

**Notes:**

- Task completed successfully with comprehensive modular framework
- All deliverables met with enhanced functionality beyond original scope
- Framework provides foundation for specialized test suites in later phases
- Ready for production use with comprehensive validation capabilities

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
          uv run ai-how validate --skip-pcie-validation ../../config/example-multi-gpu-clusters.yaml

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
cd python/ai_how && uv run ai-how validate ../../config/example-multi-gpu-clusters.yaml
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
          uv run ai-how validate --skip-pcie-validation ../../config/example-multi-gpu-clusters.yaml
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

- Builds on `example-multi-gpu-clusters.yaml` as baseline configuration
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

## Summary

Phase 0 successfully established:

- Packer-based HPC and Cloud base images
- AI-HOW CLI for cluster lifecycle management
- Test cluster configurations for various scenarios
- Automated PCIe passthrough testing framework
- Modular basic infrastructure testing suite
- Foundation for all subsequent testing phases

## Next Phase

→ [Phase 1: Core Infrastructure Setup](phase-1-core-infrastructure.md)
