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

# Run phased test execution (recommended for complete validation)
make test-all-phased
```

## Directory Structure

The test directory is organized into logical categories by purpose and execution phase:

### Test Directories

- **`foundation/`** — Local prerequisite and validation tests (run first)
  - `test_ai_how_cli.sh`
    - Purpose: Verifies AI-HOW CLI installation, configuration, and PCIe commands
    - VMs: none
    - Config: `config/example-multi-gpu-clusters.yaml`
    - Suites: none
  - `test_ansible_roles.sh`
    - Purpose: Validates role structure, dependencies, and playbook integration
    - VMs: none
    - Config: not applicable (discovers roles dynamically)
    - Suites: none
  - `test_base_images.sh`
    - Purpose: Builds and verifies Packer images for controller and compute targets
    - VMs: ephemeral Packer builder VMs
    - Config: not applicable (invokes CMake/Packer targets)
    - Suites: none
  - `test_config_validation.sh`
    - Purpose: Checks AI-HOW configuration files via the CLI validators
    - VMs: none
    - Config: `config/example-multi-gpu-clusters.yaml`
    - Suites: none
  - `test_pcie_validation.sh`
    - Purpose: Exercises PCIe inventory and validation CLI workflows
    - VMs: none
    - Config: not applicable (CLI-only)
    - Suites: none
  - `test_run_basic_infrastructure.sh`
    - Purpose: Validates VM lifecycle, SSH, and config plumbing
    - VMs: 1 controller + 1 compute
    - Config: `tests/test-infra/configs/test-minimal.yaml`
    - Suites:
      - `suites/basic-infrastructure/run-basic-infrastructure-tests.sh`
  - `test_test_configs.sh`
    - Purpose: Validates test configuration YAML schema and resource bounds
    - VMs: none
    - Config: iterates over `tests/test-infra/configs/test-*.yaml`
    - Suites: none

- **`frameworks/`** — Unified cluster frameworks
  - `test-hpc-packer-slurm-framework.sh`
    - Purpose: Unified SLURM testing across controller and compute nodes with BeeGFS and job examples
    - VMs: 1 controller + 2 compute nodes
    - Config: `config/example-multi-gpu-clusters.yaml`
    - Suites:
      - `suites/slurm-controller/run-slurm-controller-tests.sh` (controller mode)
      - `suites/monitoring-stack/run-monitoring-stack-tests.sh` (controller mode)
      - `suites/container-runtime/run-container-runtime-tests.sh` (compute mode)
      - `suites/slurm-job-examples/run-slurm-job-examples-tests.sh` (optional)
    - Modes: `controller`, `compute`, `full` (default)
  - `test-hpc-runtime-framework.sh`
    - Purpose: Validates compute services, container runtime, GPU GRES, cgroup isolation,
      job scripts, DCGM, and container workloads
    - VMs: 1 controller + 2 GPU-capable compute nodes
    - Config: `tests/test-infra/configs/test-slurm-compute.yaml`
    - Suites:
      - `suites/slurm-compute/run-slurm-compute-tests.sh`
      - `suites/cgroup-isolation/run-cgroup-isolation-tests.sh`
      - `suites/gpu-gres/run-gpu-gres-tests.sh`
      - `suites/job-scripts/run-job-scripts-tests.sh`
      - `suites/dcgm-monitoring/run-dcgm-monitoring-tests.sh`
      - `suites/container-integration/run-container-integration-tests.sh`
  - `test-pcie-passthrough-framework.sh`
    - Purpose: Verifies PCIe GPU passthrough and workload execution
    - VMs: 1 controller + 1 GPU passthrough compute
    - Config: `tests/test-infra/configs/test-pcie-passthrough.yaml`
    - Suites:
      - `suites/gpu-validation/run-all-tests.sh` for GPU validation

- **`advanced/`** — Integration suites for storage, registry, and sharing workflows
  - `test-container-registry-framework.sh`
    - Purpose: Deploys the registry, syncs images, and validates SLURM access
    - VMs: 1 controller + 2 compute
    - Config: `tests/test-infra/configs/test-container-registry.yaml`
    - Suites:
      - `suites/container-registry/run-ansible-infrastructure-tests.sh`
  - `test-beegfs-framework.sh`
    - Purpose: Provisions BeeGFS services and exercises distributed filesystem performance
    - VMs: 1 controller + 3 BeeGFS/compute nodes
    - Config: `tests/test-infra/configs/test-beegfs.yaml`
    - Suites:
      - `suites/beegfs/run-beegfs-tests.sh`
  - `test-virtio-fs-framework.sh`
    - Purpose: Validates VirtIO-FS host directory sharing and performance checks
    - VMs: 1 controller + 1 compute
    - Config: `tests/test-infra/configs/test-virtio-fs.yaml`
    - Suites:
      - `suites/virtio-fs/run-virtio-fs-tests.sh`

- **`suites/`**
  - Purpose: component-level suites executed inside clusters created by the frameworks.
  - Behavior:
    - Suites rely on an already-provisioned cluster.
    - Suites never start VMs themselves.
- **`legacy/`**
  - Purpose: archived scripts kept for reference; behavior is frozen and not maintained.
  - Examples:
    - `legacy/test-grafana.sh`
    - `legacy/test-ai-how-api-integration.sh`
    - `legacy/run_base_images_test.sh`
  - VMs: varies by script; treat as historical reference only.

### Supporting Directories

- **`test-infra/`**
  - Shared orchestration utilities, cluster configuration YAML, logging helpers, CLI plumbing.
  - See `tests/test-infra/README.md` for details on configuration files and utilities.
- **`utilities/`**
  - Helper scripts for SSH cleanup, container deployment, and validation helpers (invoked by other tests).
- **`e2e-system-setup/`**
  - Comprehensive step-by-step validation framework for complete system validation.
  - Includes phased validation from prerequisites through functional and regression testing.
  - See `tests/e2e-system-setup/README.md` for detailed workflow documentation.
- **`suites/common/`**
  - Shared suite helpers (logging/config utilities); not executed directly.

#### Suite Execution Map

- `foundation/test_run_basic_infrastructure.sh`
  - Suites:
    - `suites/basic-infrastructure`
- `frameworks/test-hpc-packer-slurm-framework.sh`
  - Suites (controller mode):
    - `suites/slurm-controller`
    - `suites/monitoring-stack`
  - Suites (compute mode):
    - `suites/container-runtime`
  - Suites (job examples, optional):
    - `suites/slurm-job-examples`
- `frameworks/test-hpc-runtime-framework.sh`
  - Suites:
    - `suites/slurm-compute`
    - `suites/cgroup-isolation`
    - `suites/gpu-gres`
    - `suites/job-scripts`
    - `suites/dcgm-monitoring`
    - `suites/container-integration`
- `frameworks/test-pcie-passthrough-framework.sh`
  - Suites:
    - `suites/gpu-validation`
- `advanced/test-container-registry-framework.sh`
  - Suites:
    - `suites/container-registry`
- `advanced/test-beegfs-framework.sh`
  - Suites:
    - `suites/beegfs`
- `advanced/test-virtio-fs-framework.sh`
  - Suites:
    - `suites/virtio-fs`

All other foundation scripts are self-contained and do not execute suites.

#### Orphan Suites

The following suites exist but are not currently used by any framework:

- `container-deployment`
- `container-e2e`

Refer to the "Recommended Test Execution Sequence" section below for guidance on running the test directories in order.

## Test Framework CLI Pattern

All test framework scripts (`test-*-framework.sh`) provide a standardized CLI interface for modular test execution.

### Standard Commands

Each framework implements:

- `e2e` / `end-to-end` - Complete end-to-end test with automatic cleanup
- `start-cluster` - Start the test cluster
- `stop-cluster` - Stop and destroy the test cluster
- `deploy-ansible` - Deploy via Ansible on running cluster
- `run-tests` - Run test suite on deployed cluster
- `list-tests` - List all available test scripts
- `status` - Show cluster status and configuration
- `help` - Display usage information

### Standard Options

- `-h, --help` - Show help message
- `-v, --verbose` - Enable verbose output
- `--no-cleanup` - Skip cleanup after completion
- `--interactive` - Enable interactive prompts

Run any framework script with `--help` to see detailed usage.

## Test Execution Order

### Recommended Test Execution Sequence

Tests should be executed in phases to ensure proper validation:

#### Phase 1: Foundation Tests

Foundation tests validate prerequisites without requiring VMs:

- Pre-commit validation
- Base image builds
- Integration tests
- Ansible role validation

#### Phase 2: Core Infrastructure (SLURM)

The SLURM framework validates controller and compute node functionality:

- `test-hpc-packer-slurm-framework.sh` - SLURM controller, compute nodes, monitoring, job examples

#### Phase 3: Compute Runtime

Runtime framework validates compute node services:

- `test-hpc-runtime-framework.sh` - Container runtime, GPU GRES, cgroups, DCGM, job scripts
- `test-pcie-passthrough-framework.sh` - GPU passthrough validation

#### Phase 4: Advanced Integration

Advanced frameworks validate storage and registry integration:

- `test-container-registry-framework.sh` - Container registry deployment
- `test-beegfs-framework.sh` - BeeGFS distributed filesystem
- `test-virtio-fs-framework.sh` - VirtIO-FS host sharing

### Test Execution Approaches

#### Quick Validation

Essential tests for development workflow:

- `make test-precommit` - Syntax and linting
- `make test-quick` - Quick integration
- Core SLURM functionality via frameworks

#### Complete Validation

Full test suite execution:

1. Phase 1: Foundation tests (Makefile targets)
2. Phase 2: SLURM framework
3. Phase 3: Runtime and PCIe frameworks
4. Phase 4: Advanced integration frameworks

#### Category-Specific Testing

**Core HPC Infrastructure:**

- SLURM framework in `tests/frameworks/`
- Runtime framework in `tests/frameworks/`
- PCIe framework in `tests/frameworks/`

**Storage Infrastructure:**

- BeeGFS framework in `tests/advanced/`
- VirtIO-FS framework in `tests/advanced/`

**Registry Infrastructure:**

- Container registry framework in `tests/advanced/`

### Test Dependencies

#### Execution Order Rationale

The recommended order ensures:

- Prerequisites validated before cluster deployment
- Base images available before VM creation
- Controller services running before compute nodes
- Basic services validated before advanced features

#### Test Isolation

Each framework is independent and can run standalone, but sequential execution:

- Validates dependencies progressively
- Catches integration issues early
- Provides logical debugging workflow
- Matches typical deployment sequence

#### Resource Considerations

Sequential execution is recommended as cluster-based tests:

- Compete for system resources when run in parallel
- May conflict on VM names or network ports
- Share virtualization infrastructure

Sequential execution provides:

- Automatic cleanup between runs
- Predictable resource usage
- Easier failure diagnosis

### Development Workflows

#### Daily Development

For quick validation during feature development:

- Run pre-commit checks
- Run quick integration tests
- Test affected framework

#### Pre-Commit Validation

Before committing changes:

- Syntax and linting checks
- Core integration tests
- Affected framework tests

#### Debugging

For debugging failed tests:

- Use modular framework commands (`start-cluster`, `deploy-ansible`, `run-tests`, `stop-cluster`)
- Keep cluster running between test iterations
- Use `list-tests` to identify failing tests
- Run specific tests individually

### Makefile Targets

Convenience wrappers for common operations:

- `make test-quick` - Foundation tests
- `make test` - Core infrastructure
- `make test-all` - Complete validation
- Component-specific targets available

## Test Architecture Overview

Detailed architecture notes live in the design documentation under `docs/` and in the header comments of each
framework script. Use those sources (and the script `--help` output) for implementation specifics so this README stays a
lightweight index.

## Test Operations Summary

- **Pre-commit hooks:** Defined in `.pre-commit-config.yaml` with helper scripts in `tests/test-infra/`
- **Framework scripts:** All framework scripts support `--help` for detailed usage
- **Make wrappers:** Convenience targets forward to framework scripts (see `tests/Makefile`)
- **Documentation:** Design docs in `docs/` contain detailed validation criteria

## Troubleshooting

- Execute tests through the development container for consistent toolchain
- Use `--help` flag on any framework script for usage information
- Check logs in `tests/logs/` for detailed error information
- Use framework's `stop-cluster` command to clean up stale VMs
- Verify prerequisites against design documentation in `docs/`
