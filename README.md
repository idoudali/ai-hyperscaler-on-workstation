# Hyperscaler on Workstation

An automated approach to emulating advanced AI infrastructure on a single
workstation using KVM, GPU partitioning, and dual-stack orchestration.

## What This Project Is

This project is an educational playground where I try to cover (and educate
myself about) the software stack being used today for training in a distributed HPC
system, and for running inference in a Cloud.

It is a "poor-man's" solution to this problem where if you find yourself with a
machine with enough cores and more than 1 GPU then you can try to "emulate" an
HPC or a cloud cluster using multiple VMs and assigning our GPUs at will to the
different VMs.

This project is also a vibe-coding experiment (for better or worse)
where I am experimenting with the quality of the different coding assistance
tools and agents.

## What This Project Is Not

This project is not meant for production :). Use it at your own risk :). Yet, it can
be a really nice playground to learn from others' mistakes.

## Getting Started

**New to the project?** Follow these guides in order:

### Prerequisites and Installation

1. **[Prerequisites](getting-started/prerequisites.md)** - System requirements and verification scripts
2. **[Installation Guide](getting-started/installation.md)** - Complete installation instructions

**Quick Summary:** 8+ cores, 32+ GB RAM, 500+ GB disk, Ubuntu 22.04+ or Debian 13+

### Quickstart Guides

Once installation is complete, follow these quickstart guides to deploy your cluster:

1. **[5-Minute Quickstart](getting-started/quickstart-5min.md)** - Verify setup and build first Packer image
2. **[Cluster Deployment](getting-started/quickstart-cluster.md)** - Deploy complete HPC cluster with SLURM
3. **[GPU Configuration](getting-started/quickstart-gpu.md)** - Configure GPU passthrough and run GPU workloads
4. **[Container Workflows](getting-started/quickstart-containers.md)** - Build and deploy containerized applications
5. **[Monitoring Setup](getting-started/quickstart-monitoring.md)** - Deploy Prometheus and Grafana dashboards

**Total Time:** ~1 hour from installation to fully monitored cluster

---

## Contributing to the Project

The sections below are for **developers contributing to this project**. If you
just want to use the platform, follow the [Quickstart Guides](#quickstart-guides) above.

### Development Workflow

When contributing code changes, follow these steps after staging your changes:

### Pre-commit Hooks

This project uses the following pre-commit hooks:

- **General formatting**: trailing whitespace, end-of-file, YAML/JSON/TOML/XML
  validation
- **Security checks**: detect private keys, large files (>10MB)
- **Markdown linting**: with project-specific rules
- **Shell script linting**: using shellcheck with relaxed rules
- **Dockerfile linting**: using hadolint with common rules ignored
- **Commit message validation**: enforcing Conventional Commits format

**Running pre-commit hooks:**

```bash
# Run hooks on staged files
make pre-commit-run

# Run hooks on all files
make pre-commit-run-all
```

### AI-HOW Python Package Development

The project includes a Python CLI package that can be developed using Nox-based
workflows. Use the below targets to help with development:

```bash
# Run tests
make test-ai-how

# Run linting
make lint-ai-how

# Format code
make format-ai-how

# Build documentation
make docs-ai-how

# Clean build artifacts
make clean-ai-how
```

### Docker Development Environment

For consistent development environments:

```bash
# Build the development image
make build-docker

# Start interactive shell in container
make shell-docker

# Run specific commands in container
make run-docker COMMAND="pytest tests/"

# Clean up Docker artifacts
make clean-docker
```

### Commit Message Format

This project follows [Conventional
Commits](https://www.conventionalcommits.org/). Use the following format:

```plain
<type>(<scope>): <subject>
```

**Examples:**

- `feat(ansible): add GPU node provisioning playbook`
- `fix(terraform): resolve VPC subnet configuration issue`
- `docs(slurm): update MIG GPU configuration guide`

**Interactive commits:**

```bash
cz commit  # Interactive commit message builder
```

**Available types:** feat, fix, docs, style, refactor, perf, test, build, ci,
chore, revert  
**Available scopes:** ansible, terraform, packer, slurm, k8s, gpu, docs, ci,
scripts

For more details, please refer to the [Conventional Commits
specification](https://www.conventionalcommits.org/) and [commitizen
documentation](https://commitizen-tools.github.io/commitizen/).

## Python CLI (ai-how)

### Using the Makefile Workflow

The recommended approach uses the Makefile which handles virtual environment
creation and dependency management:

```bash
# Create virtual environment and install dependencies
make venv-create

# Activate the virtual environment
source .venv/bin/activate

# Use the CLI
ai-how --help
```

### Development Commands

```bash
# Run via module if needed
python -m ai_how.cli --help

# Run tests, linting, and formatting (via Makefile)
make test-ai-how
make lint-ai-how  
make format-ai-how
```

## Testing Framework

The project includes a comprehensive test suite for validating the entire HPC infrastructure. For complete
documentation, see **[tests/README.md](tests/README.md)**.

### Quick Start

```bash
# Run core infrastructure tests (recommended for CI/CD)
cd tests/ && make test

# Run comprehensive test suite with all phases
cd tests/ && make test-all

# Run quick validation tests
cd tests/ && make test-quick

# Run tests with verbose output
cd tests/ && make test-verbose
```

### Test Organization

The test suite is organized into three main categories:

- **`foundation/`** - Prerequisite validation tests (CLI, Ansible roles, Packer images, configuration)
- **`frameworks/`** - Unified cluster test frameworks (controller, compute, GPU passthrough)
- **`advanced/`** - Integration suites (BeeGFS, container registry, VirtIO-FS)

### For Contributors

If you're writing new test frameworks or extending the test suite:

- **Full documentation**: [tests/README.md](tests/README.md)
- **Test framework standards**: See "Writing New Test Frameworks" in tests/README.md
- **Shared utilities**: Use utilities in `tests/test-infra/utils/` for consistency
- **Reference implementations**: Study existing frameworks in `tests/frameworks/`

## Project Structure

Understanding the project layout helps navigate the codebase effectively. Each major directory has its own README with
detailed information.

### Core Directories

- **[`ansible/`](ansible/README.md)** - Ansible playbooks and roles for
  infrastructure automation

  - [`roles/`](ansible/roles/README.md) - Custom roles for SLURM, GPU, containers, monitoring
  - [`playbooks/`](ansible/playbooks/README.md) - Infrastructure deployment playbooks
  - [`inventories/`](ansible/inventories/README.md) - Inventory configurations

- **[`packer/`](packer/README.md)** - VM image building with Packer

  - [`hpc-base/`](packer/hpc-base/README.md) - Base HPC image templates
  - [`hpc-controller/`](packer/hpc-controller/README.md) - SLURM controller image
  - [`hpc-compute/`](packer/hpc-compute/README.md) - SLURM compute node image

- **[`docker/`](docker/README.md)** - Development environment container

  - Multi-stage Dockerfile for consistent builds
  - Container entrypoint and dependency management

- **[`scripts/`](scripts/README.md)** - Utility and automation scripts

  - [`system-checks/`](scripts/system-checks/README.md) - System validation and GPU inventory

- **[`tests/`](tests/README.md)** - Comprehensive testing framework

  - Foundation, frameworks, and advanced test suites
  - Test infrastructure and shared utilities

- **[`python/ai_how/`](python/ai_how/README.md)** - Python CLI package

  - HPC cluster management commands
  - PCIe passthrough configuration
  - Configuration validation

- **`docs/`** - Project documentation

  - [`getting-started/`](getting-started/prerequisites.md) - Prerequisites, installation, quickstarts
  - [`architecture/`](architecture/overview.md) - System design and architecture docs
  - [`tutorials/`](tutorials/01-first-cluster.md) - In-depth learning guides
  - [`components/`](components/README.md) - Component-specific documentation

- **[`config/`](config/README.md)** - Cluster configuration files

  - Example configurations for various deployment scenarios

- **[`containers/`](containers/README.md)** - Container image definitions

  - ML framework images (PyTorch, TensorFlow, etc.)

### Key Files

- **`Makefile`** - Main development workflow automation
- **`.pre-commit-config.yaml`** - Code quality and linting rules
- **`pyproject.toml`** - Python package configuration with commitizen settings
