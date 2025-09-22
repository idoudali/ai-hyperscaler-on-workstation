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

### 5. Integration Test (`test_integration.sh`)

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

- **Container Runtime**: `test_container_runtime.sh` and `make test-container-comprehensive`
- **Monitoring Stack (Task 015)**: `test-monitoring-stack-framework.sh` and `make test-monitoring-stack`
- **Base Images**: `test_base_images.sh`
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
