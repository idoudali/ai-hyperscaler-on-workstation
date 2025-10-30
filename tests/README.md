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

- **`frameworks/`** — Unified cluster frameworks (Phase 2-3)
  - `test-hpc-packer-controller-framework.sh`
    - Purpose: Validates SLURM controller, accounting, monitoring stack, and Grafana
    - VMs: 1 controller
    - Config: `tests/test-infra/configs/test-slurm-controller.yaml`
    - Suites:
      - `suites/slurm-controller/run-slurm-controller-tests.sh`
      - `suites/monitoring-stack/run-monitoring-stack-tests.sh`
      - Legacy references (missing today): `grafana`, `slurm-accounting`
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
  - `test-hpc-packer-compute-framework.sh`
    - Purpose: Validates the compute image via container-runtime tests
    - VMs: 1 controller + 1 compute
    - Config: `tests/test-infra/configs/test-container-runtime.yaml`
    - Suites:
      - `suites/container-runtime/run-container-runtime-tests.sh`
  - `test-pcie-passthrough-framework.sh`
    - Purpose: Verifies PCIe GPU passthrough and workload execution
    - VMs: 1 controller + 1 GPU passthrough compute
    - Config: expects `tests/test-infra/configs/test-pcie-passthrough.yaml`
    - Suites:
      - *(expected)* `suites/pcie-passthrough/run-pcie-passthrough-tests.sh` (directory currently missing)

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
- **`utilities/`**
  - Helper scripts for SSH cleanup, container deployment, and validation helpers (invoked by other tests).
- **`phase-4-validation/`**
  - Step-wise harness kept for legacy flows; advanced frameworks reuse selected helpers.
- **`suites/common/`**
  - Shared suite helpers (logging/config utilities); not executed directly.

#### Suite Execution Map

- `foundation/test_run_basic_infrastructure.sh`
  - Suites:
    - `suites/basic-infrastructure`
- `frameworks/test-hpc-packer-controller-framework.sh`
  - Suites:
    - `suites/slurm-controller`
    - `suites/monitoring-stack`
- `frameworks/test-hpc-runtime-framework.sh`
  - Suites:
    - `suites/slurm-compute`
    - `suites/cgroup-isolation`
    - `suites/gpu-gres`
    - `suites/job-scripts`
    - `suites/dcgm-monitoring`
    - `suites/container-integration`
- `frameworks/test-hpc-packer-compute-framework.sh`
  - Suites:
    - `suites/container-runtime`
- `frameworks/test-pcie-passthrough-framework.sh`
  - Suites:
    - *(expected)* `suites/pcie-passthrough` (directory currently missing)
- `advanced/test-container-registry-framework.sh`
  - Suites:
    - `suites/container-registry`
- `advanced/test-beegfs-framework.sh`
  - Suites:
    - `suites/beegfs`
- `advanced/test-virtio-fs-framework.sh`
  - Suites:
    - `suites/virtio-fs`

All other foundation scripts are self-contained and do not execute suites. Notes:

- Controller framework references to `grafana` and `slurm-accounting` remain for historical reasons; the directories and
  configs were removed, so the script logs warnings when it cannot find them.
- The PCIe framework expects a `pcie-passthrough` suite and matching config; neither exists yet, so the test exits after
  logging a missing-suite warning.

#### Orphan Suites

- `container-deployment` — no owning test or framework today.
- `container-e2e` — no owning test or framework today.
- `gpu-validation` — manual suite referenced only by documentation examples.
- `pcie-passthrough`
  - Expected by the PCIe framework.
  - Add suite directory plus config (for example `tests/test-infra/configs/test-pcie-passthrough.yaml`).
- `grafana`
  - Legacy controller suite still referenced in code.
  - Directory removed from `tests/suites/` alongside configs.
- `slurm-accounting`
  - Legacy controller suite still referenced in code.
  - Directory removed from `tests/suites/` alongside configs.

Refer to the "Recommended Test Execution Sequence" section below for guidance on running the test directories in order.

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

These tests validate HPC controller components and should run before compute node tests.
Use the unified `test-hpc-packer-controller-framework.sh` which consolidates all controller tests:

```bash
# Complete end-to-end (includes SLURM controller, job accounting, monitoring, grafana)
make test-hpc-packer-controller
# OR
./test-hpc-packer-controller-framework.sh e2e
```

**Individual Commands (if needed for debugging):**

```bash
./test-hpc-packer-controller-framework.sh start-cluster    # Start once
./test-hpc-packer-controller-framework.sh deploy-ansible   # Deploy Ansible
./test-hpc-packer-controller-framework.sh run-tests        # Run all controller tests
./test-hpc-packer-controller-framework.sh stop-cluster     # Clean up
```

#### Phase 3: Compute Node Tests

These tests validate HPC compute node components.
Use the unified `test-hpc-runtime-framework.sh` which consolidates all runtime tests:

```bash
# Complete end-to-end (includes SLURM compute, container runtime, GPU GRES, cgroup, job-scripts, DCGM)
make test-hpc-runtime
# OR
./test-hpc-runtime-framework.sh e2e
```

**Individual Commands (if needed for debugging):**

```bash
./test-hpc-runtime-framework.sh start-cluster    # Start once
./test-hpc-runtime-framework.sh deploy-ansible   # Deploy Ansible
./test-hpc-runtime-framework.sh run-tests        # Run all runtime tests
./test-hpc-runtime-framework.sh stop-cluster     # Clean up
```

**PCIe Passthrough (GPU Passthrough) - Separate Framework:**

```bash
make test-pcie-passthrough
# OR
./test-pcie-passthrough-framework.sh e2e
```

#### Phase 4: Advanced Integration Tests

These tests validate complete system integration:

1. **Container Registry Test** - Validate container registry and SLURM integration (Task 021)

   ```bash
   make test-container-registry-unified
   # OR
   ./test-container-registry-framework.sh e2e
   ```

2. **BeeGFS Parallel Filesystem Test** - Validate distributed storage (Task 028)

   ```bash
   make test-beegfs-unified
   # OR
   ./test-beegfs-framework.sh e2e
   ```

3. **Virtio-FS Host Directory Sharing Test** - Validate filesystem passthrough (Task 027)

   ```bash
   make test-virtio-fs-unified
   # OR
   ./test-virtio-fs-framework.sh e2e
   ```

**Note**: Container integration tests are consolidated into `test-hpc-runtime-framework.sh`
and GPU monitoring (DCGM) is also consolidated into `test-hpc-runtime-framework.sh`

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

# Phase 2: Core Infrastructure (Controller) - Unified Framework
make test-hpc-packer-controller

# Phase 3: Compute Nodes & Runtime - Unified Framework
make test-hpc-runtime

# Phase 3b: GPU Passthrough
make test-pcie-passthrough

# Phase 4: Advanced Integration
make test-container-registry-unified
make test-beegfs-unified
make test-virtio-fs-unified
```

#### Quick Validation (Essential Tests Only)

```bash
# Fast validation for development workflow
make test-precommit              # Syntax and linting (~30 sec)
make test-quick                  # Quick integration (~2-5 min)
make test-hpc-packer-controller  # Core controller functionality (~15-20 min)
```

#### Category-Specific Execution

**Core HPC Infrastructure (Unified Framework)**

```bash
# All controller and runtime tests in unified frameworks
make test-hpc-packer-controller
make test-hpc-runtime
make test-pcie-passthrough
```

**Storage Infrastructure**

```bash
# BeeGFS and Virtio-FS storage validation
make test-beegfs-unified
make test-virtio-fs-unified
```

**Container and Registry Infrastructure**

```bash
# Container registry and integration
make test-container-registry-unified
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

# Test specific framework you're working on
make test-hpc-packer-controller        # ~15-20 minutes
# OR
make test-hpc-runtime                  # ~20-30 minutes
```

#### Before Committing Changes

```bash
# Full validation before commit
make test-precommit                    # Syntax and linting
make test                             # Core integration tests
make test-hpc-packer-controller       # Affected framework test (example)
```

#### Complete Pre-Release Validation

```bash
# Run all tests in proper order (allow 1.5-3 hours)
cd /path/to/ai-hyperscaler-on-workskation/tests

# Phase 1: Foundation (required prerequisites)
make test-precommit && \
make test-base-images && \
make test-integration && \
make test-ansible-roles && \

# Phase 2: Core Infrastructure (Controller - Unified Framework)
make test-hpc-packer-controller && \

# Phase 3: Compute Nodes & Runtime (Unified Framework)
make test-hpc-runtime && \
make test-pcie-passthrough && \

# Phase 4: Advanced Integration (Storage & Registry)
make test-container-registry-unified && \
make test-beegfs-unified && \
make test-virtio-fs-unified

echo "All unified framework tests completed successfully!"
```

#### Debugging Failed Tests

```bash
# If a test fails, use modular commands to debug
# Example: Debugging HPC Runtime Framework

./test-hpc-runtime-framework.sh start-cluster    # Start once
./test-hpc-runtime-framework.sh deploy-ansible   # Deploy changes
./test-hpc-runtime-framework.sh run-tests        # Test repeatedly
./test-hpc-runtime-framework.sh list-tests       # Find failing test
./test-hpc-runtime-framework.sh run-test check-slurm-compute.sh  # Run specific test
./test-hpc-runtime-framework.sh stop-cluster     # Cleanup
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

## Test Architecture Overview

Detailed architecture notes live in the design documentation under `docs/` and in the header comments of each
framework script. Use those sources (and the script `--help` output) for implementation specifics so this README stays a
lightweight index.

## Test Operations Summary

- **Pre-commit hooks:** Run `make test-precommit` (or the narrower `make test-ansible-syntax`) before touching cluster
  resources. Hook behaviour is defined in `.pre-commit-config.yaml` and the helper scripts in `tests/test-infra/`.
- **Core flows:** Follow the steps in "Recommended Test Execution Sequence". Every script under `tests/` exposes
  `--help`, which details subcommands, prerequisites, and optional flags.
- **Make wrappers:** Targets such as `make test`, `make test-all`, `make test-quick`, and the component-specific
  `make test-*-unified` simply forward to the framework scripts. See `tests/Makefile` for the authoritative mapping.
- **Documentation sources:** Update the individual script headers or the design docs (e.g. `docs/CONTAINER-INTEGRATION-*
  `.md`) when validation criteria change—this README intentionally avoids duplicating those explanations.

## Troubleshooting

- Always execute tests through the development container (`./scripts/run-in-dev-container.sh`) to guarantee the expected
  toolchain and permissions.
- If a framework fails, rerun it with `--help` to confirm prerequisites and review the log paths printed by the script
  (logs are emitted under `tests/logs/`). Use the matching `stop-cluster` subcommand or `make clean` to tear down stale
  VMs before retrying.
- Verify external prerequisites—GPU availability, container images, registry content—against the relevant design doc
  before escalating an issue.
