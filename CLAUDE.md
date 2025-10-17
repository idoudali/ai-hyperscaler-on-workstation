# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Pharos.ai Hyperscaler on Workstation** is an infrastructure-as-code project that emulates advanced AI/HPC
infrastructure (SLURM clusters with GPU support) on a single workstation using KVM virtualization, GPU partitioning,
and dual-stack orchestration (SLURM + Kubernetes-ready).

**Architecture Tiers:**

1. **Virtualization Layer**: KVM/QEMU via libvirt-python
2. **VM Image Building**: Packer with cloud-init provisioning
3. **Cluster Orchestration**: Python CLI (ai-how) with Typer framework
4. **Configuration Management**: Ansible with 10+ specialized roles
5. **Cluster Runtime**: SLURM + BeeGFS distributed storage
6. **Observability**: DCGM (GPU monitoring), Grafana, Prometheus

## Core Development Commands

### Building & Setup

```bash
# Build development Docker image (includes all dependencies)
make build-docker

# Create Python virtual environment with all dependencies
make venv-create

# Configure CMake build system (needed once)
make config

# Interactive shell in development container
make shell-docker

# Run specific command in development container
make run-docker COMMAND="make test-ai-how"
```

### Python CLI Development (ai-how)

```bash
# Run tests, linting, and type checking
make test-ai-how
make lint-ai-how
make format-ai-how

# Build package documentation
make docs-ai-how

# Inside venv: use CLI directly
source .venv/bin/activate
ai-how --help
python -m ai_how.cli --help  # Alternative
```

### Testing

```bash
# Core infrastructure tests (from tests/ directory)
cd tests/
make test              # Recommended for CI/CD
make test-quick       # Fast validation without builds
make test-ansible-syntax  # Validate Ansible

# Python package tests (from project root)
make test-ai-how
```

### Code Quality

```bash
# Install pre-commit hooks
make pre-commit-install

# Run pre-commit on staged files
make pre-commit-run

# Run pre-commit on all files
make pre-commit-run-all

# Format Python code
make format-ai-how
```

### Cluster Operations

```bash
# Generate inventory from cluster config
make cluster-inventory

# Start/stop/status cluster VMs
make cluster-start
make cluster-stop
make cluster-status

# Deploy runtime configuration
make cluster-deploy

# Complete validation: inventory -> start -> deploy -> test
make validate-cluster-full
```

## High-Level Architecture & Key Files

### Project Structure

```text
pharos.ai-hyperscaler-on-workstation-2/
├── ansible/                          # IaC: Infrastructure deployment
│   ├── playbooks/playbook-hpc-runtime.yml  # Main HPC deployment
│   ├── roles/                        # 10+ roles (slurm-*, beegfs-*, gpu-*, etc.)
│   └── requirements.txt              # Ansible dependencies
│
├── python/ai_how/                    # Python CLI package
│   ├── src/ai_how/
│   │   ├── cli.py                   # Entry point (Typer framework)
│   │   ├── vm_management/           # KVM/libvirt management
│   │   ├── pcie_validation/         # GPU assignment validation
│   │   └── schemas/                 # JSON schema for validation
│   ├── pyproject.toml               # Package config (Hatchling)
│   ├── noxfile.py                   # Nox-based test automation
│   └── tests/
│
├── packer/                           # Packer VM image definitions
│   ├── hpc-base/
│   ├── hpc-controller/
│   └── hpc-compute/
│
├── docker/                           # Development environment
│   ├── Dockerfile                    # Multi-stage dev image (Debian Trixie)
│   ├── entrypoint.sh                # Container init script
│   └── requirements.txt              # Python dependencies
│
├── tests/                            # Comprehensive testing framework
│   ├── Makefile                      # Test automation
│   ├── test-*-framework.sh          # Test framework scripts
│   ├── suites/                       # Individual test suites
│   └── test-infra/utils/            # Shared test utilities
│       ├── ansible-utils.sh         # Ansible deployment
│       ├── cluster-utils.sh         # Cluster lifecycle
│       ├── log-utils.sh             # Logging functions
│       └── test-framework-utils.sh  # Test execution
│
├── scripts/                          # Utility scripts
│   ├── run-in-dev-container.sh      # Docker wrapper
│   ├── generate-ansible-inventory.py # Dynamic inventory
│   └── setup-host-dependencies.sh   # Host setup
│
├── config/
│   └── example-multi-gpu-clusters.yaml  # Sample cluster config
│
├── .cursor/                          # Cursor IDE configuration
│   ├── rules/                        # Rule system
│   │   ├── agent/                   # Agent-requestable rules
│   │   ├── always/                  # Always-applied rules
│   │   ├── auto/                    # Auto-applied by file type
│   │   └── manual/                  # Manual trigger rules
│   └── docs/                         # Agent permission guides
│
├── Makefile                          # Primary development interface
├── CMakeLists.txt                    # CMake build configuration
├── pyproject.toml                    # Python project configuration
└── .pre-commit-config.yaml          # Code quality hooks
```

### Key Configuration Files

| File | Purpose |
|------|---------|
| `/Makefile` | Primary workflow automation interface |
| `/python/ai_how/pyproject.toml` | Python package config (uv, pytest, mypy, ruff) |
| `/docker/Dockerfile` | Development environment specification |
| `/.pre-commit-config.yaml` | Code linting & validation hooks |
| `/CMakeLists.txt` | Ninja build system configuration |
| `/config/example-multi-gpu-clusters.yaml` | Cluster configuration template |
| `/.cursor/rules/` | Cursor IDE rules system |

### Critical Patterns

**Data Flow:**

```text
Cluster YAML Config → ai-how CLI → Libvirt VMs → Ansible Deploy → Running HPC Cluster
```

**Makefile-Driven Workflow**: All development happens through Makefile targets. Every operation (build, test, lint,
deploy) is abstracted through make.

**Python CLI Architecture**: Typer-based command-line tool with type safety and automatic help generation. Entry point:
`python/ai_how/src/ai_how/cli.py`

**Ansible Roles**: Each component (SLURM, BeeGFS, GPU, containers) is a reusable role. Main playbook:
`ansible/playbooks/playbook-hpc-runtime.yml`

**Test Framework Standard**: All test frameworks follow a standard CLI interface:

- Commands: `e2e`, `start-cluster`, `stop-cluster`, `deploy-ansible`, `run-tests`, `list-tests`, `run-test NAME`,
  `status`, `help`
- Options: `-h`, `-v`, `--verbose`, `--no-cleanup`, `--interactive`

## Dependency Management

### Python Stack (via uv)

- **Core**: typer>=0.12, rich>=13.7, jsonschema>=4.21, PyYAML>=6, libvirt-python>=9, jinja2>=3.1
- **Testing**: pytest, pytest-cov, mypy, ruff, black
- **Docs**: mkdocs, mkdocstrings
- **Automation**: nox, nox-uv

### System Dependencies (in Docker)

- Build tools: ansible, cmake, ninja-build
- IaC tools: packer, terraform
- Virtualization: libvirt-dev, qemu-system-x86, qemu-utils
- Containers: Docker CE, Apptainer 1.4.3
- Languages: Go 1.23.2 (for Apptainer)

### Ansible Dependencies

- ansible>=8.0.0
- Additional Python packages: rich, tabulate, cryptography, paramiko

## Code Quality & Conventions

### Commit Messages

Enforced via commitizen with **Conventional Commits**:

```text
<type>(<scope>): <subject>
```

- **Types**: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- **Scopes**: ansible, terraform, packer, slurm, k8s, gpu, docs, ci, scripts, cursor, python, ai-how
- **Example**: `feat(ansible): add GPU node provisioning playbook`

Use interactive commits: `cz commit`

### Pre-commit Hooks

Automatically enforced on staged files. Run manually:

```bash
make pre-commit-run      # Staged files only
make pre-commit-run-all  # All files
```

**Hooks include:**

- Trailing whitespace, EOF validation, YAML/JSON/TOML/XML validation
- Private key detection, large file detection (>10MB)
- Markdown linting (markdownlint)
- Shell linting (shellcheck with SC1091, SC2317 disabled)
- CMake formatting
- Conventional Commits validation
- Python linting/formatting via ruff

### Linting & Formatting Tools

- **ruff**: Python linter/formatter (100 char lines, strict mode)
- **mypy**: Type checking (strict)
- **shellcheck**: Shell scripts
- **markdownlint**: Markdown (custom rules in `.markdownlint.yaml`)
- **hadolint**: Dockerfiles
- **cmake-format**: CMake files

## Development Environment Setup

### Prerequisites

- Host OS: Ubuntu/Debian (recommended)
- Docker CE installed and running
- System tools: curl, git, build-essential

### Quick Setup

```bash
# One-time host setup
./scripts/setup-host-dependencies.sh

# Build development Docker image
make build-docker

# Create Python environment
make venv-create

# Install pre-commit hooks
make pre-commit-install

# Verify setup
make help
```

### Docker Development Workflow

All builds should happen in the development container to ensure consistency:

```bash
# Option 1: Interactive shell
make shell-docker
# (now inside container)
make config
ninja -C build build-hpc-compute-image

# Option 2: Run command in container
make run-docker COMMAND="make test-ai-how"
```

## File Naming Conventions

- **Playbooks**: `playbook-*.yml`
- **Ansible roles**: Descriptive names (e.g., `slurm-controller`, `gpu-drivers`)
- **Test frameworks**: `test-*-framework.sh` (main entry point), `check-*.sh` (individual tests)
- **Utilities**: `*-utils.sh`
- **Configuration**: `*.yaml` or `*.yml`
- **Container images**: One `Dockerfile` per image directory

## When Working on Specific Components

### Ansible Development

- Roles located in `ansible/roles/`
- Validate syntax: `make test-ansible-syntax`
- Test specific role: `make test-role ROLE=role-name`
- Main playbook: `ansible/playbooks/playbook-hpc-runtime.yml`
- Always run in Docker to match CI environment

### Python CLI Development (ai-how)

- Entry point: `python/ai_how/src/ai_how/cli.py`
- Tests: `python/ai_how/tests/`
- Build via: `make test-ai-how`, `make lint-ai-how`, `make format-ai-how`
- Package config: `python/ai_how/pyproject.toml`
- Test automation: `python/ai_how/noxfile.py`

### Test Framework Development

- Follow standard CLI interface (documented in README.md)
- Use shared utilities from `tests/test-infra/utils/`
- Main entry: `test-*-framework.sh`
- Individual tests: `tests/suites/<component>/check-*.sh`
- This reduces code from ~600 to ~300-350 lines per framework

### Packer Image Development

- Image configs in `packer/*/`
- Build via: `make config` then `ninja -C build build-*-image`
- Use CMake for build orchestration: `CMakeLists.txt`

## Cursor IDE Integration

The project includes Cursor-specific configuration in `.cursor/`:

**Rule Categories:**

- `.cursor/rules/agent/` - Agent-requestable rules
- `.cursor/rules/always/` - Always-applied rules
- `.cursor/rules/auto/` - Auto-applied by file type
- `.cursor/rules/manual/` - User-triggered rules

**Documentation:**

- `.cursor/docs/agent-allow-guide.md` - Comprehensive guide
- `.cursor/agent-allow-reference.yaml` - Permission template

Key rules already in place:

- Ansible best practices enforcement
- Python code standards (ruff, mypy)
- Shell script best practices
- Terraform validation requirements
- Docker package sorting
- Kubernetes GPU resources
- Conventional commit validation
- Dev container build requirements
- Git safety (no force push/hard reset)

## Important Notes

1. **Always use Docker**: All builds and tests run in the development container. Use `make shell-docker` or
   `make run-docker COMMAND="..."`.

2. **Conventional Commits**: Commit messages are validated. Use `cz commit` for interactive commit builder.

3. **No Destructive Operations**: Pre-commit hooks and Cursor rules prevent `git push --force`, `git reset --hard`,
   and similar operations.

4. **State Management**: Cluster state is managed via JSON files in the state directory. Inspect these when debugging
   cluster issues.

5. **Shared Test Utilities**: When creating new test frameworks, reuse functions from `tests/test-infra/utils/` rather
   than reimplementing (reduces code by 40-50%).

6. **Configuration Validation**: Cluster configs are validated against JSON schemas in
   `python/ai_how/src/ai_how/schemas/`.

7. **GPU Support**: PCIe passthrough and GPU assignment validated via `pcie_validation/` module. Check GRES
   configuration in SLURM roles.

8. **Documentation**: Project docs use MkDocs with Material theme. Build via `make docs-ai-how` or `make docs-build`.

## Related Resources

- **README.md**: Quick start and overview
- **.cursor/docs/agent-allow-guide.md**: Cursor rules and agent permissions
- **tests/README.md**: Comprehensive testing framework documentation
- **docs/**: Implementation plans and design documents
- **Conventional Commits**: https://www.conventionalcommits.org/
