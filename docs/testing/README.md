# HPC SLURM Test Suite

Comprehensive test infrastructure for validating the HPC SLURM infrastructure components including
Packer images, Ansible roles, and system integration.

## Quick Start

```bash
# Run core infrastructure tests (recommended)
make test

# Run comprehensive test suite including builds and CLI validation
make test-all

# Run comprehensive container runtime validation
make test-container-comprehensive

# Run quick validation tests only
make test-quick

# Run tests with verbose output
make test-verbose
```

## Test Framework CLI Pattern

**IMPORTANT:** All test framework scripts (`test-*-framework.sh`) MUST provide a standardized CLI interface for
modular test execution. This pattern enables flexible testing workflows and debugging capabilities.

### Standard CLI Commands

Every test framework should implement these commands:

- `e2e` or `end-to-end` - Run complete end-to-end test (start cluster → deploy ansible → run tests → stop cluster)
- `start-cluster` - Start the test cluster independently (keeps cluster running)
- `stop-cluster` - Stop and destroy the test cluster
- `deploy-ansible` - Deploy via Ansible on running cluster (assumes cluster exists)
- `run-tests` - Run test suite on deployed cluster (assumes deployment complete)
- `list-tests` - List all available individual test scripts
- `run-test NAME` - Run a specific individual test by name
- `status` - Show current cluster status and configuration
- `help` - Display comprehensive usage information

### Standard CLI Options

- `-h, --help` - Show help message with examples
- `-v, --verbose` - Enable verbose output for debugging
- `--no-cleanup` - Skip cleanup after test completion (for debugging)
- `--interactive` - Enable interactive prompts for cleanup/confirmation

### Example Usage Pattern

```bash
# Reference implementation: test-dcgm-monitoring-framework.sh
# All test frameworks should follow this pattern

# Complete end-to-end test with automatic cleanup (default, recommended for CI/CD)
./test-example-framework.sh
./test-example-framework.sh e2e          # Explicit
./test-example-framework.sh end-to-end   # Alternative syntax

# Modular workflow for debugging (keeps cluster running between steps):
# 1. Start cluster and keep it running for debugging
./test-example-framework.sh start-cluster

# 2. Deploy configuration separately
./test-example-framework.sh deploy-ansible

# 3. Run tests on deployed cluster
./test-example-framework.sh run-tests

# 4. List available individual tests
./test-example-framework.sh list-tests

# 5. Run specific individual test for focused debugging
./test-example-framework.sh run-test check-specific-component.sh

# 6. Check cluster status
./test-example-framework.sh status

# 7. Clean up when done
./test-example-framework.sh stop-cluster
```

### Benefits of CLI Pattern

1. **CI/CD Integration**: Use `e2e` command for automated testing with full cleanup
2. **Debugging**: Keep cluster running between test iterations using individual commands
3. **Development**: Deploy once, run tests multiple times with modular commands
4. **Incremental Testing**: Test individual phases independently
5. **Focused Testing**: List and run individual tests for granular debugging
6. **Different Pipeline Stages**: Use different commands for different CI/CD stages
7. **Manual Validation**: Deploy with Ansible, validate manually before running tests
8. **Test Discovery**: Easy discovery of all available tests via list-tests command

### Implementation Reference

See `test-dcgm-monitoring-framework.sh` (Task 018) and `test-container-registry-framework.sh` (Task 021) as reference implementations:

```bash
# View help and available commands
./test-dcgm-monitoring-framework.sh --help

# Complete end-to-end test with cleanup (CI/CD mode)
./test-dcgm-monitoring-framework.sh e2e

# Example workflow for debugging
./test-dcgm-monitoring-framework.sh start-cluster      # Start once
./test-dcgm-monitoring-framework.sh deploy-ansible     # Deploy changes
./test-dcgm-monitoring-framework.sh run-tests          # Test multiple times

# List and run individual tests (required feature)
./test-dcgm-monitoring-framework.sh list-tests         # Show all available tests
./test-dcgm-monitoring-framework.sh run-test check-dcgm-service.sh  # Run specific test

./test-dcgm-monitoring-framework.sh stop-cluster       # Clean up
```

### Required for New Test Frameworks

When creating new test frameworks (e.g., `test-container-registry-framework.sh` for Task 021):

- ✅ **Implement `e2e` or `end-to-end` command** - Complete test with cleanup (start → deploy → test → stop)
- ✅ Implement all standard commands (`start-cluster`, `stop-cluster`, `deploy-ansible`, `run-tests`, `status`)
- ✅ **Implement `list-tests` command** - Show all available individual test scripts
- ✅ **Implement `run-test NAME` command** - Run specific individual tests by name
- ✅ Support all standard options (`--help`, `--verbose`, `--no-cleanup`, `--interactive`)
- ✅ Provide comprehensive `--help` output with examples including e2e, list-tests, and run-test
- ✅ Allow modular execution of test phases
- ✅ Make `e2e` the default behavior when no command is specified

**Existing Test Frameworks:**

**Category 1: Full CLI API Standard (list-tests, run-test commands implemented):**

- ✅ `test-dcgm-monitoring-framework.sh` (Task 018) - Reference implementation
- ✅ `test-monitoring-stack-framework.sh` (Task 015) - CLI pattern implemented
- ✅ `test-container-registry-framework.sh` (Task 021) - CLI pattern implemented
- ✅ `test-slurm-controller-framework.sh` (Task 010) - CLI pattern implemented
- ✅ `test-slurm-compute-framework.sh` (Task 022) - CLI pattern implemented
- ✅ `test-gpu-gres-framework.sh` (Task 023) - CLI pattern implemented
- ✅ `test-grafana-framework.sh` (Task 017) - CLI pattern implemented
- ✅ `test-slurm-accounting-framework.sh` (Task 019) - CLI pattern implemented
- ✅ `test-container-runtime-framework.sh` (Task 008/009) - CLI pattern implemented
- ✅ `test-pcie-passthrough-framework.sh` (GPU Passthrough) - CLI pattern implemented
- ✅ `test-container-integration-framework.sh` (Task 026) - CLI pattern implemented

## Test Execution Order

### Recommended Test Execution Sequence

The test frameworks should be executed in the following order to ensure proper validation and avoid conflicts:

#### Phase 1: Foundation Tests (Prerequisites)

1. **Pre-commit Validation** - Run first to catch syntax errors early

   ```bash
   make test-precommit
   ```

2. **Base Images Test** - Build and validate base images (required for all cluster tests)

   ```bash
   make test-base-images
   # OR
   ./test_base_images.sh
   ```

3. **Integration Test** - Validate project structure and consistency

   ```bash
   make test-integration
   # OR
   ./test_integration.sh
   ```

4. **Ansible Roles Test** - Validate role structure and integration

   ```bash
   make test-ansible-roles
   # OR
   ./test_ansible_roles.sh
   ```

#### Phase 2: Core Infrastructure Tests (HPC Controller)

These tests validate HPC controller components and should run before compute node tests:

1. **SLURM Controller Test** - Validate SLURM controller installation (Task 010)

   ```bash
   ./test-slurm-controller-framework.sh e2e
   ```

2. **SLURM Job Accounting Test** - Validate job accounting after SLURM controller (Task 019)

   ```bash
   ./test-slurm-accounting-framework.sh e2e
   ```

3. **Monitoring Stack Test** - Validate Prometheus monitoring (Task 015)

   ```bash
   ./test-monitoring-stack-framework.sh e2e
   # OR
   make test-monitoring-stack
   ```

4. **Grafana Test** - Validate Grafana dashboards after monitoring stack (Task 017)

   ```bash
   ./test-grafana-framework.sh e2e
   ```

#### Phase 3: Compute Node Tests

These tests validate HPC compute node components:

1. **SLURM Compute Node Test** - Validate SLURM compute node installation (Task 022)

   ```bash
   ./test-slurm-compute-framework.sh e2e
   ```

2. **Container Runtime Test** - Validate Apptainer/Singularity (Task 008/009)

   ```bash
   ./test-container-runtime-framework.sh e2e
   # OR
   make test-container-comprehensive
   ```

3. **GPU GRES Test** - Validate GPU resource scheduling configuration (Task 023)

   ```bash
   ./test-gpu-gres-framework.sh e2e
   # OR
   make test-gpu-gres
   ```

4. **PCIe Passthrough Test** - Validate GPU passthrough (requires GPU hardware)

   ```bash
   ./test-pcie-passthrough-framework.sh e2e
   ```

#### Phase 4: Advanced Integration Tests

These tests validate complete system integration:

1. **Container Registry Test** - Validate container registry and SLURM integration (Task 021)

   ```bash
   ./test-container-registry-framework.sh e2e
   ```

2. **Container Integration Test** - Validate containerized ML/AI workloads (Task 026)

   ```bash
   ./test-container-integration-framework.sh e2e
   ```

   **Note**: Requires pre-built container images (see Build Dependencies in section 11)

3. **DCGM Monitoring Test** - Validate GPU monitoring (Task 018)

   ```bash
   ./test-dcgm-monitoring-framework.sh e2e
   ```

### Complete Test Suite Execution

#### Sequential Execution (Recommended for CI/CD)

```bash
# Complete test suite in proper order
cd /path/to/ai-hyperscaler-on-workskation/tests

# Phase 1: Foundation
make test-precommit
make test-base-images
make test-integration
make test-ansible-roles

# Phase 2: Core Infrastructure (Controller)
./test-slurm-controller-framework.sh e2e
./test-slurm-accounting-framework.sh e2e
./test-monitoring-stack-framework.sh e2e
./test-grafana-framework.sh e2e

# Phase 3: Compute Nodes
./test-slurm-compute-framework.sh e2e
./test-container-runtime-framework.sh e2e
./test-gpu-gres-framework.sh e2e
./test-pcie-passthrough-framework.sh e2e

# Phase 4: Advanced Integration
./test-container-registry-framework.sh e2e
./test-container-integration-framework.sh e2e    # Requires pre-built containers
./test-dcgm-monitoring-framework.sh e2e
```

#### Quick Validation (Essential Tests Only)

```bash
# Fast validation for development workflow
make test-precommit              # Syntax and linting
make test-quick                  # Quick integration
./test-slurm-controller-framework.sh e2e  # Core functionality
```

#### Category-Specific Execution

**Category 1: Full CLI API Standard Tests**

```bash
# Run all Category 1 frameworks (automated script)
./run-all-category1-tests.sh

# Or manually in sequence
./test-slurm-controller-framework.sh e2e
./test-grafana-framework.sh e2e
./test-slurm-accounting-framework.sh e2e
./test-container-runtime-framework.sh e2e
./test-pcie-passthrough-framework.sh e2e
```

**Monitoring and Observability Stack**

```bash
# Test monitoring infrastructure in order
./test-monitoring-stack-framework.sh e2e      # Prometheus first
./test-grafana-framework.sh e2e               # Grafana depends on Prometheus
./test-dcgm-monitoring-framework.sh e2e       # GPU monitoring (if applicable)
```

**Container Infrastructure Stack**

```bash
# Test container infrastructure in order
./test-container-runtime-framework.sh e2e     # Runtime first
./test-container-registry-framework.sh e2e    # Registry with SLURM integration
```

### Test Dependencies and Rationale

#### Why This Order Matters

1. **Pre-commit First**: Catches syntax errors before spending time on integration tests
2. **Base Images Early**: All cluster-based tests require base images
3. **Integration Before Cluster**: Validates project structure before deploying clusters
4. **SLURM Controller Before Accounting**: Accounting requires functional SLURM controller
5. **Monitoring Before Grafana**: Grafana depends on Prometheus/monitoring infrastructure
6. **Controller Before Compute**: Compute nodes require controller for job scheduling
7. **Container Runtime Before Registry**: Registry tests assume runtime is functional

#### Test Isolation

Each test framework is designed to be independent and can be run standalone, but running in order:

- Validates dependencies progressively
- Catches integration issues early
- Provides logical debugging workflow
- Matches typical deployment sequence

#### Resource Considerations

**Parallel Execution**: Not recommended for cluster-based tests as they:

- Compete for system resources (CPU, memory, disk)
- May conflict on VM names or network ports
- Share the same virtualization infrastructure

**Sequential Execution**: Recommended because:

- Tests include automatic cleanup between runs
- Resource usage is predictable
- Failures are easier to diagnose
- Matches CI/CD pipeline constraints

### Development Workflow Examples

#### Daily Development Workflow

```bash
# Quick validation during feature development
make test-precommit                    # Fast: ~30 seconds
make test-quick                        # Fast: ~2-5 minutes

# Test specific component you're working on
./test-slurm-controller-framework.sh e2e  # ~10-20 minutes
```

#### Before Committing Changes

```bash
# Full validation before commit
make test-precommit                    # Syntax and linting
make test                             # Core integration
./test-<affected-component>-framework.sh e2e  # Specific component test
```

#### Complete Pre-Release Validation

```bash
# Run all tests in proper order (allow 2.5-5 hours + container build time)
cd /path/to/ai-hyperscaler-on-workskation/tests

# Foundation
make test-precommit && \
make test-base-images && \
make test-integration && \
make test-ansible-roles && \

# Core Infrastructure
./test-slurm-controller-framework.sh e2e && \
./test-slurm-accounting-framework.sh e2e && \
./test-monitoring-stack-framework.sh e2e && \
./test-grafana-framework.sh e2e && \

# Compute Nodes
./test-slurm-compute-framework.sh e2e && \
./test-container-runtime-framework.sh e2e && \
./test-pcie-passthrough-framework.sh e2e && \

# Build container images (required for container integration tests)
cd /path/to/ai-hyperscaler-on-workskation
make config && \
make run-docker COMMAND="cmake --build build --target build-docker-pytorch-cuda12.1-mpi4.1" && \
make run-docker COMMAND="cmake --build build --target convert-to-apptainer-pytorch-cuda12.1-mpi4.1" && \

# Advanced Integration
cd /path/to/ai-hyperscaler-on-workskation/tests
./test-container-registry-framework.sh e2e && \
./test-container-integration-framework.sh e2e && \
./test-dcgm-monitoring-framework.sh e2e

echo "All tests completed successfully!"
```

#### Debugging Failed Tests

```bash
# If a test fails, use modular commands to debug
./test-slurm-controller-framework.sh start-cluster    # Start once
./test-slurm-controller-framework.sh deploy-ansible   # Deploy changes
./test-slurm-controller-framework.sh run-tests        # Test repeatedly
./test-slurm-controller-framework.sh list-tests       # Find failing test
./test-slurm-controller-framework.sh run-test check-slurm-installation.sh
./test-slurm-controller-framework.sh stop-cluster     # Cleanup
```

### Makefile Targets (Convenience Wrappers)

```bash
# Quick validation
make test-quick          # Foundation tests only

# Core validation
make test               # Core infrastructure tests

# Complete validation
make test-all           # All tests including builds

# Specific components
make test-base-images
make test-ansible-roles
make test-monitoring-stack
make test-container-comprehensive
```

### Time Estimates

| Test Phase | Duration | Tests |
|------------|----------|-------|
| Pre-commit | ~30 seconds | Syntax, linting |
| Foundation | ~30-90 minutes | Base images, integration, Ansible |
| Core Infrastructure | ~40-80 minutes | SLURM, accounting, monitoring, Grafana |
| Compute Nodes | ~20-40 minutes | Container runtime, PCIe |
| Advanced Integration | ~45-70 minutes | Registry, container integration, DCGM |
| **Total** | **~2.5-5 hours** | Complete suite |

**Notes**:

- Times vary based on system performance and whether base images need rebuilding
- Container integration tests require pre-built container images (add ~30-60 minutes for initial build)
- Advanced Integration phase includes container registry deployment and container image distribution

## Test script list

TODO document the tests and what they test

## Test Architecture Overview

The test infrastructure uses a **two-tier approach**:

1. **Pre-commit Hooks**: Fast, automatic validation of basic syntax and linting
2. **Integration Tests**: Comprehensive validation of component integration and consistency

This separation ensures:

- ⚡ **Fast feedback** during development via pre-commit hooks
- 🔧 **Comprehensive validation** via integration test suite
- 🚀 **Efficient CI/CD** with appropriate validation at each stage

## Pre-commit Validation

Basic syntax and linting validation is handled automatically by pre-commit hooks:

```bash
# Run all pre-commit validation
make test-precommit

# Run only Ansible validation
make test-ansible-syntax

# Manual pre-commit commands
pre-commit run --all-files ansible-lint
pre-commit run --all-files ansible-playbook-syntax-check
pre-commit run --all-files check-yaml
```

**Pre-commit Hook Coverage:**

- ✅ YAML syntax validation for all files
- ✅ ansible-lint with production profile
- ✅ Ansible playbook syntax checking
- ✅ Ansible role structure validation
- ✅ Shell script linting (shellcheck)
- ✅ Markdown formatting
- ✅ General file formatting

## Integration Test Components

### 1. Base Images Test (`test_base_images.sh`)

Tests Packer base image building and validation:

- **Purpose**: Validates that HPC and Cloud base images build correctly
- **Components**: HPC base image, Cloud base image, SSH keys, QEMU validation
- **Duration**: 20-60 minutes (includes image building)
- **Prerequisites**: Dev container, QEMU, sufficient disk space

```bash
# Run base images test
make test-base-images

# Options
./test_base_images.sh --help
./test_base_images.sh --skip-build    # Test existing images only
./test_base_images.sh --verbose       # Detailed output
./test_base_images.sh --force-cleanup # Rebuild from scratch
```

### 2. Container Runtime Test (`test_container_runtime.sh`)

Tests Apptainer/Singularity container runtime implementation:

- **Purpose**: Validates Task 008 - Container Runtime Ansible Role
- **Components**: Ansible role structure, installation, security, functionality, actual deployment
- **Duration**: 5-15 minutes
- **Prerequisites**: Dev container, Ansible

**Validation Criteria (Task 008):**

**ANSIBLE ROLE COMPONENTS:**

- ✅ Ansible role structure complete
- ✅ Role syntax validation passed
- ✅ Playbook integration working
- ✅ Container runtime installation process

**CONFIGURATION COMPONENTS:**

- ✅ Container runtime functionality
- ✅ Security configuration proper
- ✅ Resource limits configured

**ACTUAL DEPLOYMENT COMPONENTS:**

- ✅ Package installation (apptainer + dependencies)
- ✅ Configuration files deployment
- ✅ Service status and permissions
- ✅ Container execution capability
- ✅ Real container execution (pull, run, bind mounts)

```bash
# Run container runtime tests
make test-container-runtime

# Run comprehensive container runtime tests (includes role-specific integration)
make test-container-comprehensive

# Options
./test_container_runtime.sh --help
./test_container_runtime.sh --skip-build       # Structure tests only
./test_container_runtime.sh --deployment-only  # Actual deployment tests only
./test_container_runtime.sh --verbose          # Detailed output
```

### 3. Ansible Roles Integration Test (`test_ansible_roles.sh`)

High-level integration validation of Ansible roles and playbooks:

- **Purpose**: Validates integration, consistency, and dependencies between roles
- **Components**: Role dependencies, template consistency, cross-role variables
- **Duration**: 2-5 minutes
- **Prerequisites**: Dev container
- **Note**: Basic syntax/linting handled by pre-commit hooks

**Integration Test Coverage:**

- Role dependencies and conflicts
- Template variable consistency
- Cross-role variable consistency
- Variable usage patterns
- Documentation coverage
- Playbook-role integration
- Global consistency validation

**Note**: The integration tests gracefully handle roles without
`defaults/main.yml` files, as these are optional in Ansible roles.

**Basic Validation (Pre-commit Hooks):**

- YAML syntax validation (check-yaml hook)
- ansible-lint checks (ansible-lint hook)
- Playbook syntax validation (local hook)
- Role structure validation (local hook)

```bash
# Run integration tests
make test-ansible-roles

# Test specific role integration
make test-role ROLE=container-runtime

# Run basic syntax/linting validation
make test-ansible-syntax

# Options
./test_ansible_roles.sh --help
./test_ansible_roles.sh --role ROLE           # Test single role integration
./test_ansible_roles.sh --integration-only    # Global consistency only
./test_ansible_roles.sh --verbose             # Detailed output
./test_ansible_roles.sh --fail-fast           # Stop on first test failure
```

### 4. Monitoring Stack Test (`test-monitoring-stack-framework.sh`)

Comprehensive Prometheus monitoring stack validation (Task 015):

- **Purpose**: Validates Prometheus monitoring stack deployment and functionality
- **Components**: Prometheus server, Node Exporter, monitoring integration
- **Duration**: 10-20 minutes (includes cluster deployment)
- **Prerequisites**: AI-HOW tool, dev container, base images

**Validation Coverage:**

- **Components Installation**: Prometheus and Node Exporter package installation, configuration, and service status
- **Integration Testing**: Prometheus targets, metrics collection, data quality validation
- **Environment Validation**: System prerequisites and Packer integration validation (built into framework)

**Simplified Test Structure (Post-Consolidation):**

- `suites/monitoring-stack/check-components-installation.sh`: Combined Prometheus + Node Exporter installation tests
- `suites/monitoring-stack/check-monitoring-integration.sh`: Integration and data quality tests
- Environment validation: Built into the main test framework

```bash
# Run monitoring stack tests
make test-monitoring-stack

# Run direct framework test
./test-monitoring-stack-framework.sh

# Options
./test-monitoring-stack-framework.sh --help
./test-monitoring-stack-framework.sh --verbose           # Detailed output
./test-monitoring-stack-framework.sh start-cluster       # Start cluster independently
./test-monitoring-stack-framework.sh deploy-ansible      # Deploy monitoring stack only
./test-monitoring-stack-framework.sh run-tests          # Run tests on existing cluster
```

### 5. SLURM Controller Test (`test-slurm-controller-framework.sh`)

SLURM controller installation and functionality validation (Task 010):

- **Purpose**: Validates SLURM controller installation in HPC controller images
- **Components**: SLURM controller service, configuration, job scheduling
- **Duration**: 10-20 minutes (includes cluster deployment)
- **Prerequisites**: AI-HOW tool, dev container, HPC controller image

```bash
# Run SLURM controller tests
./test-slurm-controller-framework.sh

# Options and modular commands
./test-slurm-controller-framework.sh --help
./test-slurm-controller-framework.sh e2e                 # Complete test with cleanup
./test-slurm-controller-framework.sh start-cluster       # Start cluster independently
./test-slurm-controller-framework.sh deploy-ansible      # Deploy SLURM controller
./test-slurm-controller-framework.sh run-tests           # Run tests on existing cluster
./test-slurm-controller-framework.sh list-tests          # List available tests
./test-slurm-controller-framework.sh run-test check-slurm-installation.sh
```

### 6. Grafana Test (`test-grafana-framework.sh`)

Grafana dashboard platform implementation and validation (Task 017):

- **Purpose**: Validates Grafana installation and functionality in HPC controller images
- **Components**: Grafana server, dashboards, monitoring integration
- **Duration**: 10-20 minutes (includes cluster deployment)
- **Prerequisites**: AI-HOW tool, dev container, HPC controller image

```bash
# Run Grafana tests
./test-grafana-framework.sh

# Options and modular commands
./test-grafana-framework.sh --help
./test-grafana-framework.sh e2e                 # Complete test with cleanup
./test-grafana-framework.sh start-cluster       # Start cluster independently
./test-grafana-framework.sh deploy-ansible      # Deploy monitoring stack with Grafana
./test-grafana-framework.sh run-tests           # Run tests on existing cluster
./test-grafana-framework.sh list-tests          # List available tests
./test-grafana-framework.sh run-test check-grafana-installation.sh
```

### 7. SLURM Job Accounting Test (`test-slurm-accounting-framework.sh`)

SLURM job accounting configuration and validation (Task 019):

- **Purpose**: Validates SLURM job accounting functionality in HPC controller images
- **Components**: SLURM accounting database, slurmdbd, job tracking
- **Duration**: 10-20 minutes (includes cluster deployment)
- **Prerequisites**: AI-HOW tool, dev container, HPC controller image

```bash
# Run SLURM accounting tests
./test-slurm-accounting-framework.sh

# Options and modular commands
./test-slurm-accounting-framework.sh --help
./test-slurm-accounting-framework.sh e2e                 # Complete test with cleanup
./test-slurm-accounting-framework.sh start-cluster       # Start cluster independently
./test-slurm-accounting-framework.sh deploy-ansible      # Deploy SLURM accounting
./test-slurm-accounting-framework.sh run-tests           # Run tests on existing cluster
./test-slurm-accounting-framework.sh list-tests          # List available tests
./test-slurm-accounting-framework.sh run-test check-job-accounting.sh
```

### 8. Container Runtime Test (`test-container-runtime-framework.sh`)

Container runtime installation and security validation (Task 008/009):

- **Purpose**: Validates Apptainer/Singularity container runtime in HPC compute images
- **Components**: Container runtime, dependencies, security policies
- **Duration**: 10-20 minutes (includes cluster deployment)
- **Prerequisites**: AI-HOW tool, dev container, HPC compute image

**Validation Coverage:**

- **Task 008**: Apptainer installation, version, dependencies, execution capabilities
- **Task 009**: Security configuration, privilege escalation prevention, filesystem restrictions

```bash
# Run container runtime tests
./test-container-runtime-framework.sh

# Options and modular commands
./test-container-runtime-framework.sh --help
./test-container-runtime-framework.sh e2e                 # Complete test with cleanup
./test-container-runtime-framework.sh start-cluster       # Start cluster independently
./test-container-runtime-framework.sh deploy-ansible      # Deploy container runtime
./test-container-runtime-framework.sh run-tests           # Run tests on existing cluster
./test-container-runtime-framework.sh list-tests          # List available tests
./test-container-runtime-framework.sh run-test check-singularity-install.sh
```

### 9. PCIe Passthrough Test (`test-pcie-passthrough-framework.sh`)

GPU passthrough validation for HPC compute nodes:

- **Purpose**: Validates PCIe GPU passthrough in HPC compute images
- **Components**: GPU visibility, passthrough configuration, GPU workloads
- **Duration**: 10-20 minutes (includes cluster deployment)
- **Prerequisites**: AI-HOW tool, dev container, HPC compute image, GPU hardware

```bash
# Run PCIe passthrough tests
./test-pcie-passthrough-framework.sh

# Options and modular commands
./test-pcie-passthrough-framework.sh --help
./test-pcie-passthrough-framework.sh e2e                 # Complete test with cleanup
./test-pcie-passthrough-framework.sh start-cluster       # Start cluster independently
./test-pcie-passthrough-framework.sh deploy-ansible      # Deploy GPU passthrough
./test-pcie-passthrough-framework.sh run-tests           # Run tests on existing cluster
./test-pcie-passthrough-framework.sh list-tests          # List available tests
./test-pcie-passthrough-framework.sh run-test check-gpu-visibility.sh
```

### 10. GPU GRES Test (`test-gpu-gres-framework.sh`)

GPU resource scheduling validation for HPC compute nodes (Task 023):

- **Purpose**: Validates GPU GRES (Generic Resource Scheduling) configuration in HPC compute images
- **Components**: GRES configuration, GPU detection, GPU scheduling
- **Duration**: 10-20 minutes (includes cluster deployment)
- **Prerequisites**: AI-HOW tool, dev container, HPC compute image

**Validation Coverage:**

- **GRES Configuration**: Configuration file deployment, syntax validation, directory structure
- **GPU Detection**: PCI device detection, NVIDIA device files, GPU visibility
- **GPU Scheduling**: SLURM GPU resource scheduling, job allocation, resource management

```bash
# Run GPU GRES tests
./test-gpu-gres-framework.sh

# Options and modular commands
./test-gpu-gres-framework.sh --help
./test-gpu-gres-framework.sh e2e                 # Complete test with cleanup
./test-gpu-gres-framework.sh start-cluster       # Start cluster independently
./test-gpu-gres-framework.sh deploy-ansible      # Deploy GRES configuration
./test-gpu-gres-framework.sh run-tests           # Run tests on existing cluster
./test-gpu-gres-framework.sh list-tests          # List available tests
./test-gpu-gres-framework.sh run-test check-gres-configuration.sh
```

### 11. Container Integration Test (`test-container-integration-framework.sh`)

Container integration validation for PyTorch CUDA, MPI, and GPU access (Task 026):

- **Purpose**: Validates containerized ML/AI workload execution within HPC SLURM environment
- **Components**: PyTorch + CUDA, MPI communication, distributed training, SLURM integration
- **Duration**: 15-30 minutes (includes cluster deployment and comprehensive validation)
- **Prerequisites**: AI-HOW tool, dev container, HPC compute image, **built container images**

**Build Dependencies (MUST be completed before running tests):**

These containers must be built and deployed before running container integration tests:

```bash
# Step 1: Build Docker image (Task 019)
cd /path/to/ai-hyperscaler-on-workskation
make config
make run-docker COMMAND="cmake --build build --target build-docker-pytorch-cuda12.1-mpi4.1"

# Step 2: Convert to Apptainer SIF format (Task 020)
make run-docker COMMAND="cmake --build build --target convert-to-apptainer-pytorch-cuda12.1-mpi4.1"

# Step 3: Verify built images
docker images | grep pytorch-cuda12.1-mpi4.1
ls -lh build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif

# Step 4: Deploy to cluster (Task 021)
cd tests
make test-container-registry-deploy

# Step 5: Verify deployment
ssh hpc-controller "ls -lh /opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif"
```

**Required Infrastructure (must be deployed):**

- ✅ **TASK-021**: Container Registry Infrastructure
- ✅ **TASK-022**: SLURM Compute Node Installation
- ✅ **TASK-023**: GPU Resources (GRES) Configuration
- ✅ **TASK-024**: Cgroup Resource Isolation

**Validation Coverage:**

- **Container Functionality**: Basic execution, Python environment, PyTorch import, file system access
- **PyTorch CUDA Integration**: CUDA availability, GPU device detection, tensor operations, memory allocation
- **MPI Communication**: MPI runtime, multi-process execution, point-to-point, collective operations
- **Distributed Training**: Process groups, DistributedDataParallel, NCCL backend, multi-node coordination
- **SLURM Integration**: Container execution via srun/sbatch, GPU GRES, resource isolation, multi-node jobs

```bash
# Run container integration tests
./test-container-integration-framework.sh

# Options and modular commands
./test-container-integration-framework.sh --help
./test-container-integration-framework.sh e2e                 # Complete test with cleanup
./test-container-integration-framework.sh start-cluster       # Start cluster independently
./test-container-integration-framework.sh deploy-ansible      # Deploy validation configuration
./test-container-integration-framework.sh run-tests           # Run tests on existing cluster
./test-container-integration-framework.sh list-tests          # List available tests
./test-container-integration-framework.sh run-test check-pytorch-cuda-integration.sh

# Makefile convenience targets
cd tests
make test-container-integration                               # Full workflow
make test-container-integration-start                         # Start cluster
make test-container-integration-deploy                        # Deploy configuration
make test-container-integration-tests                         # Run tests
make test-container-integration-stop                          # Stop cluster
make test-container-integration-status                        # Show status
```

**Important Notes:**

- GPU tests will skip gracefully if GPU hardware is not available (expected in test environments)
- Container images MUST be built before running tests (see Build Dependencies above)
- SLURM compute nodes must be deployed and registered
- Container registry must be deployed with images distributed to all compute nodes
- See `docs/CONTAINER-INTEGRATION-TESTING.md` for comprehensive documentation

### 12. Integration Test (`test_integration.sh`)

End-to-end integration validation:

- **Purpose**: Tests overall infrastructure integration and consistency
- **Components**: Project structure, build system, component integration
- **Duration**: 2-5 minutes
- **Prerequisites**: Dev container

**Integration Validation:**

- Project structure completeness
- Build system functionality
- Packer-Ansible integration
- Role dependencies consistency
- Configuration consistency
- Documentation coverage
- Build artifacts validation

```bash
# Run integration tests
make test-integration

# Options
./test_integration.sh --help
./test_integration.sh --quick    # Skip slow tests
./test_integration.sh --verbose  # Detailed output
```

## Test Architecture

### Common Test Patterns

All test scripts follow consistent patterns established in `test_base_images.sh`:

```bash
# Function-based testing with tracking
run_test "Test Name" test_function_name

# Consistent logging with colors
log_info "Information message"
log_warn "Warning message"  
log_error "Error message"
log_verbose "Detailed information (only in --verbose mode)"

# Signal handling for clean interruption
trap cleanup INT TERM

# Test tracking and summary
print_summary  # Shows pass/fail counts and detailed results
```

### Test States

- **✅ PASSED**: Test completed successfully
- **❌ FAILED**: Test failed - check error messages
- **⚠️ SKIPPED**: Test skipped due to conditions or options
- **🎉 ALL PASSED**: All tests in suite completed successfully

### Dev Container Integration

All tests run inside the development container for consistency:

- Uses `scripts/run-in-dev-container.sh` for command execution
- Ensures consistent environment across different host systems
- Provides necessary tools (Ansible, QEMU, Python, etc.)

## Usage Examples

### Daily Development Workflow

```bash
# 1. Fast validation during development (pre-commit)
make test-precommit                    # All pre-commit validation
make test-ansible-syntax              # Only Ansible validation

# 2. Integration testing after changes
make test-quick                       # Quick integration tests
make test                            # Core infrastructure validation

# 3. Component-specific testing
make test-container-comprehensive     # Comprehensive container runtime tests
make test-role ROLE=container-runtime # Test specific role integration
./test_container_runtime.sh --verbose # Detailed container runtime testing
```

### Pre-commit Integration

```bash
# Install pre-commit hooks (one-time setup)
pre-commit install

# Pre-commit runs automatically on git commit
git commit -m "feat: update ansible role"

# Manual validation
pre-commit run --all-files           # All hooks
pre-commit run ansible-lint          # Just ansible-lint
```

### CI/CD Pipeline

```bash
# Stage 1: Fast syntax/linting validation
make test-precommit

# Stage 2: Integration testing
make test-quick                      # Quick integration tests

# Stage 3: Comprehensive validation
make test-all                       # Full validation including builds
```

### Debugging Failed Tests

```bash
# Run with verbose output
make test-verbose

# Run with fail-fast mode (stop on first error)
make test-fail-fast

# Test individual components
./test_integration.sh --verbose
./test_ansible_roles.sh --role problematic-role --verbose
./test_container_runtime.sh --skip-build --verbose

# Use fail-fast for debugging specific issues
./test_ansible_roles.sh --fail-fast --verbose
```

## Test Dependencies

### Required Tools (provided in dev container)

- **Ansible**: Role validation and playbook syntax
- **Python**: YAML parsing and validation
- **QEMU**: Image validation and testing
- **BC Calculator**: Size calculations
- **Standard Unix tools**: grep, find, sed, etc.

### Optional Tools (enhance testing)

- **ansible-lint**: Enhanced Ansible validation
- **yamllint**: Enhanced YAML validation

## Test Data and Artifacts

### Generated Artifacts

- `/tmp/ansible_test_outputs/`: Temporary test outputs
- `/tmp/container_test_output.log`: Container test logs
- Various temporary inventory and playbook files

### Cleanup

All tests clean up temporary files unless run in verbose mode (for debugging).

```bash
# Manual cleanup
make clean
```

## Extending the Test Suite

### Adding New Tests

1. **Follow existing patterns** from `test_base_images.sh`
2. **Use consistent logging** and error handling
3. **Add command line options** (--help, --verbose, --skip-*)
4. **Update Makefile** with new targets
5. **Document in this README**

### Test Function Template

```bash
test_new_functionality() {
    log_info "Testing new functionality..."
    
    # Test implementation
    [[ condition ]] || {
        log_error "Test failure reason"
        return 1
    }
    
    log_info "New functionality test passed"
}

# Add to main()
run_test "New functionality" test_new_functionality
```

## Integration with Task List

These tests directly support the HPC SLURM task list validation:

- **Base Images (Task 001)**: `test_base_images.sh`
- **Container Runtime (Task 008/009)**: `test_container_runtime.sh` and `make test-container-comprehensive`
- **SLURM Controller (Task 010)**: `test-slurm-controller-framework.sh`
- **Monitoring Stack (Task 015)**: `test-monitoring-stack-framework.sh` and `make test-monitoring-stack`
- **Grafana (Task 017)**: `test-grafana-framework.sh`
- **SLURM Accounting (Task 019)**: `test-slurm-accounting-framework.sh`
- **Container Registry (Task 021)**: `test-container-registry-framework.sh`
- **SLURM Compute (Task 022)**: `test-slurm-compute-framework.sh`
- **GPU GRES (Task 023)**: `test-gpu-gres-framework.sh` and `make test-gpu-gres`
- **Container Integration (Task 026)**: `test-container-integration-framework.sh` and `make test-container-integration`
- **General Infrastructure**: `test_integration.sh` and `test_ansible_roles.sh`
- **AI-HOW CLI**: `test_ai_how_cli.sh`, `test_config_validation.sh`, `test_pcie_validation.sh`

### Container Runtime Comprehensive Testing

The `make test-container-comprehensive` target runs comprehensive validation for the Container Runtime Ansible Role:

1. **Structure and Syntax**: Validates role structure, YAML syntax, and Ansible lint compliance
2. **Integration**: Tests role integration with playbooks and other roles
3. **Functionality**: Validates container runtime installation, configuration, and security
4. **Deployment**: Tests actual package installation, service configuration, and container execution
5. **Cross-Role Validation**: Ensures container-runtime role integrates properly with other roles

### Monitoring Stack Comprehensive Testing

The `make test-monitoring-stack` target runs comprehensive validation for the Prometheus Monitoring Stack (Task 015):

1. **Environment Validation**: Validates system prerequisites, Ansible installation, and Packer integration (built into framework)
2. **Components Installation**: Tests Prometheus server and Node Exporter installation, configuration, and service management
3. **Integration Testing**: Validates Prometheus target discovery, metrics collection, and data quality
4. **End-to-End Deployment**: Tests complete cluster deployment with monitoring stack via Ansible provisioning
5. **Simplified Test Structure**: Consolidated test files reduce maintenance while preserving comprehensive coverage

**Key Improvements from Consolidation:**

- Reduced from 3 individual test files to 2 consolidated files
- Combined Prometheus and Node Exporter installation tests for efficiency
- Integrated environment validation into main test framework
- Simplified test execution while maintaining full test coverage

See `docs/implementation-plans/task-lists/hpc-slurm-task-list.md` for specific validation criteria.

### GPU GRES Comprehensive Testing

The `make test-gpu-gres` target runs comprehensive validation for GPU GRES (Generic Resource Scheduling) configuration
(Task 023):

1. **GRES Configuration**: Validates configuration file deployment, syntax, and directory structure
2. **GPU Detection**: Tests PCI device detection, NVIDIA device files, and GPU visibility
3. **GPU Scheduling**: Validates SLURM GPU resource scheduling and job allocation
4. **Integration**: Tests GRES integration with SLURM controller and scheduler
5. **End-to-End Deployment**: Tests complete cluster deployment with GRES configuration via Ansible provisioning

**Test Coverage:**

- Configuration file validation (`/etc/slurm/gres.conf`)
- GPU detection utilities (lspci, nvidia-smi)
- SLURM GRES integration (`GresTypes` in `slurm.conf`)
- Node resource reporting (`scontrol show node`)
- GPU scheduling capability (`sinfo -o "%N %G"`)
- Configuration consistency checks

**Documentation:**

See `docs/GPU-GRES-WORKFLOW.md` for detailed workflow documentation and
`docs/implementation-plans/task-lists/hpc-slurm-task-list.md` for specific validation criteria.

### Container Integration Comprehensive Testing

The `make test-container-integration` target runs comprehensive validation for containerized ML/AI workload execution
(Task 026):

1. **Container Functionality**: Tests basic container execution, Python environment, PyTorch import, and file system access
2. **PyTorch CUDA Integration**: Validates CUDA availability, GPU device detection, tensor operations, and memory allocation
3. **MPI Communication**: Tests MPI runtime, multi-process execution, point-to-point communication, and collective operations
4. **Distributed Training**: Validates process groups, DistributedDataParallel, NCCL backend, and multi-node coordination
5. **SLURM Integration**: Tests container execution via srun/sbatch, GPU GRES allocation, resource
isolation, and multi-node jobs
6. **End-to-End Deployment**: Tests complete cluster deployment with container integration via Ansible provisioning

**Test Coverage:**

- Container image accessibility and runtime availability (40+ individual validation checks)
- PyTorch framework with CUDA integration (GPU tests skip gracefully without hardware)
- MPI library functionality and multi-process communication
- Distributed training environment setup (process groups, data parallelism)
- SLURM scheduling with containers and GPU resources

**Build Dependencies:**

Container integration tests require pre-built container images:

```bash
# 1. Build Docker image (Task 019)
make run-docker COMMAND="cmake --build build --target build-docker-pytorch-cuda12.1-mpi4.1"

# 2. Convert to Apptainer SIF (Task 020)
make run-docker COMMAND="cmake --build build --target convert-to-apptainer-pytorch-cuda12.1-mpi4.1"

# 3. Deploy to cluster (Task 021)
cd tests && make test-container-registry-deploy
```

**Documentation:**

See `docs/CONTAINER-INTEGRATION-TESTING.md` for comprehensive testing guide and
`docs/implementation-plans/task-lists/hpc-slurm-task-list.md` for specific validation criteria.

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure test scripts are executable (`chmod +x`)
2. **Container Errors**: Verify dev container script works (`./scripts/run-in-dev-container.sh echo test`)
3. **Missing Dependencies**: Run tests in dev container environment
4. **Disk Space**: Base image tests require ~4GB free space
5. **Network Access**: Container execution tests may need internet access

### Debug Commands

```bash
# Test dev container
./scripts/run-in-dev-container.sh echo "Container working"

# Check available space
df -h build/

# Verify test script permissions
ls -la tests/test_*.sh

# Manual test execution
cd tests
./test_integration.sh --verbose
```
