# AI Agent Guide: Cursor & Claude

This comprehensive guide applies to **both Cursor IDE and Claude Code CLI** when working in this repository.

## Project Overview

**AI Hyperscaler on Workstation** is an infrastructure-as-code project that emulates advanced AI/HPC
infrastructure (SLURM clusters with GPU support) on a single workstation using KVM virtualization, GPU partitioning,
and dual-stack orchestration (SLURM + Kubernetes-ready).

**Architecture Tiers:**

1. **Virtualization Layer**: KVM/QEMU via libvirt-python
2. **VM Image Building**: Packer with cloud-init provisioning
3. **Cluster Orchestration**: Python CLI (ai-how) with Typer framework
4. **Configuration Management**: Ansible with 10+ specialized roles
5. **Cluster Runtime**: SLURM + BeeGFS distributed storage
6. **Observability**: DCGM (GPU monitoring), Grafana, Prometheus

## Quick Start

```bash
# Build container
make build-docker

# Configure CMake
make config

# Run tests
cd tests/ && make test

# Python CLI
source .venv/bin/activate && ai-how --help
```

## Table of Contents

- [AI Agent Configuration](#ai-agent-configuration)
- [Core Development Commands](#core-development-commands)
- [Critical Safety Rules](#critical-safety-rules)
- [Project Architecture](#project-architecture)
- [Development Environment](#development-environment)
- [Code Quality](#code-quality)
- [Component Development](#component-development)
- [Troubleshooting](#troubleshooting)

## AI Agent Configuration

### Shared Configuration

Both agents use shared rules from `.ai/rules/` to ensure consistent behavior. Rules are optimized to fit within
Cursor's context window (~380 lines total):

- **Git Workflow** (88 lines): Git safety, staging control, and merge conflict handling
- **Pre-commit Workflow** (67 lines): Run pre-commit on staged files only, never auto-stage fixes
- **Build Container** (54 lines): Container-only build requirements
- **Commit Workflow** (40 lines): User approval before commits

Plus Cursor-specific rules in `.cursor/rules/always/`:

- **Command Safety** (71 lines): Deny-list for dangerous commands
- **Markdown Formatting** (53 lines): Markdownlint compliance standards

### Agent-Specific Setup

#### Cursor IDE

- **Config Location**: `.cursor/` directory
- **Rules**: Symlinked from `.ai/rules/` + Cursor-specific in `.cursor/rules/`
- **How It Works**: Cursor automatically loads rules when you open the workspace
- **Additional Rules**: File-type specific rules in `.cursor/rules/auto/`
- **Detailed Guide**: See `.ai/docs/cursor-guide.md`

#### Claude Code CLI

- **Config Location**: `.claude/settings.json`
- **Permission Mode**: `default` (use `acceptEdits` for rapid iteration)
- **Workflows**: Predefined workflows in settings.json
- **How It Works**: Claude loads config automatically from repository root
- **Detailed Guide**: See `.ai/docs/claude-guide.md`

#### Permission Modes (Claude Only)

| Mode | Use Case | Auto-Edit | Auto-Execute |
|------|----------|-----------|--------------|
| `default` | Learning/review | No | No |
| `acceptEdits` | Daily dev | Yes | No |
| `plan` | Planning only | No | No |
| `bypassPermissions` | Trusted tasks | Yes | Yes |

**Current setting**: `default` mode (recommended for infrastructure-as-code projects)

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

## Critical Safety Rules

### 🚫 Never Execute

These operations are **prohibited** without explicit user approval:

- `git push --force` or `git push -f`
- `git reset --hard`
- `git rebase --continue` after conflicts (delegate to user)
- `git cherry-pick --continue` after conflicts (delegate to user)
- `git add` without user approval (present files, let user stage)
- Build commands on host (must use container)
- `sudo` commands without approval
- Auto-commit without presenting summary
- Destructive file operations
- `pre-commit run --all-files` (use staged files only)
- Auto-staging pre-commit fixes (delegate to user)

### ✅ Always Execute

These are the **required** patterns:

- **Builds in container**: `make run-docker COMMAND="..."`
- **Present modified files**: Show what changed and provide staging commands
- **Present change summary** before commit
- **Wait for user approval** before git operations
- **Use conventional commits** format
- **Delegate merge conflict continuations** to user
- **Delegate file staging** to user (never auto-stage)

### Common Workflows

#### Build Workflow

```bash
make build-docker           # Build development container
make config                 # Configure CMake with Ninja
make run-docker COMMAND="cmake --build build --target <target>"
```

#### Test Workflow

```bash
cd tests/
make test                   # Full test suite
make test-quick            # Quick validation
make test-ai-how           # Test ai-how CLI package
```

#### Commit Workflow

```bash
# Agents should:
# 1. Present summary of changes
# 2. Explain what was changed and why
# 3. Suggest conventional commit message
# 4. Wait for approval
# 5. Then execute: git add && git commit

# Recommended interactive commit:
cz commit
```

#### After Merge Conflicts

```bash
# Agents should:
# 1. Help identify conflicts (git status)
# 2. Show conflicted files
# 3. Help resolve conflicts (edit files)
# 4. Stage resolved files: git add <files>
# 5. Tell user: "Please run manually: git rebase --continue"
# 6. NEVER run continuation commands automatically
```

## Project Architecture

### Data Flow

```text
Cluster YAML Config → ai-how CLI → Libvirt VMs → Ansible Deploy → Running HPC Cluster
```

### Components

- **ai-how CLI**: Python CLI tool with type safety (Typer framework)
- **Libvirt/KVM**: VM hypervisor for emulating nodes
- **Ansible**: IaC for deploying SLURM/BeeGFS/K8s stack (10+ specialized roles)
- **Packer**: VM image building with cloud-init provisioning
- **SLURM**: HPC workload scheduler with MIG GPU support
- **BeeGFS**: Parallel filesystem for distributed storage
- **Kubernetes**: Container orchestration (planned)

### Project Structure

```text
ai-hyperscaler-on-workstation-3/
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
├── .ai/                              # Shared AI agent config
│   ├── rules/                        # Shared rules
│   ├── context/                      # Shared context
│   └── docs/                         # Agent guides
│
├── .cursor/                          # Cursor IDE configuration
│   └── rules/                        # Rule system (symlinks to .ai/)
│
├── .claude/                          # Claude Code CLI config
│   └── settings.json
│
├── Makefile                          # Primary development interface
├── CMakeLists.txt                    # CMake build configuration
├── pyproject.toml                    # Python project configuration
└── .pre-commit-config.yaml          # Code quality hooks
```

### Key Configuration Files

| File | Purpose |
|------|---------|
| `Makefile` | Primary workflow automation interface |
| `python/ai_how/pyproject.toml` | Python package config (uv, pytest, mypy, ruff) |
| `docker/Dockerfile` | Development environment specification |
| `.pre-commit-config.yaml` | Code linting & validation hooks |
| `CMakeLists.txt` | Ninja build system configuration |
| `config/example-multi-gpu-clusters.yaml` | Cluster configuration template |
| `.ai/rules/` | Shared AI agent rules |
| `.cursor/rules/` | Cursor IDE rules system |
| `.claude/settings.json` | Claude Code CLI configuration |

### Critical Patterns

**Makefile-Driven Workflow**: All development happens through Makefile targets. Every operation (build, test, lint,
deploy) is abstracted through make.

**Python CLI Architecture**: Typer-based command-line tool with type safety and automatic help generation. Entry point:
`python/ai_how/src/ai_how/cli.py`

**Ansible Roles**: Each component (SLURM, BeeGFS, GPU, containers) is a reusable role. Main playbook:
`ansible/playbooks/playbook-hpc-runtime.yml`

**Test Framework Standard**: All test frameworks follow a standard CLI interface with commands: `e2e`, `start-cluster`,
`stop-cluster`, `deploy-ansible`, `run-tests`, `list-tests`, `run-test NAME`, `status`, `help`

## Development Environment

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

### Dependency Management

#### Python Stack (via uv)

- **Core**: typer>=0.12, rich>=13.7, jsonschema>=4.21, PyYAML>=6, libvirt-python>=9, jinja2>=3.1
- **Testing**: pytest, pytest-cov, mypy, ruff, black
- **Docs**: mkdocs, mkdocstrings
- **Automation**: nox, nox-uv

#### System Dependencies (in Docker)

- Build tools: ansible, cmake, ninja-build
- IaC tools: packer, terraform
- Virtualization: libvirt-dev, qemu-system-x86, qemu-utils
- Containers: Docker CE, Apptainer 1.4.3
- Languages: Go 1.23.2 (for Apptainer)

#### Ansible Dependencies

- ansible>=8.0.0
- Additional Python packages: rich, tabulate, cryptography, paramiko

## Code Quality

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

## Component Development

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

## File Naming Conventions

- **Playbooks**: `playbook-*.yml`
- **Ansible roles**: Descriptive names (e.g., `slurm-controller`, `gpu-drivers`)
- **Test frameworks**: `test-*-framework.sh` (main entry point), `check-*.sh` (individual tests)
- **Utilities**: `*-utils.sh`
- **Configuration**: `*.yaml` or `*.yml`
- **Container images**: One `Dockerfile` per image directory

## Protected Files

Both agents must request approval before modifying:

- `Makefile`, `CMakeLists.txt`
- `pyproject.toml`, `.gitignore`
- `.cursor/rules/**`, `.claude/settings.json`
- `.ai/rules/**`, `.ai/docs/**`

## Important Notes

1. **Always use Docker**: All builds and tests run in the development container. Use `make shell-docker` or
   `make run-docker COMMAND="..."`.

2. **Conventional Commits**: Commit messages are validated. Use `cz commit` for interactive commit builder.

3. **No Destructive Operations**: Pre-commit hooks and agent rules prevent `git push --force`, `git reset --hard`,
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

## Troubleshooting

### Agent not respecting rules?

**Cursor**:

- Restart Cursor IDE
- Check symlinks: `ls -la .cursor/rules/always/`
- Verify rules in Settings → Cursor Settings → Rules

**Claude**:

- Check `settings.json` syntax: `python -m json.tool .claude/settings.json`
- Verify `sharedRulesDirectory` path exists
- Use `claude code --check-config` (if available)

### Symlinks broken?

```bash
# Recreate symlinks
cd .cursor/rules/always/
ln -sf ../../../.ai/rules/git-safety.md git-safety.mdc
ln -sf ../../../.ai/rules/commit-workflow.md commit-workflow.mdc
ln -sf ../../../.ai/rules/build-container.md build-container.mdc
ln -sf ../../../.ai/rules/merge-conflicts.md merge-conflicts.mdc
```

### Different behavior between agents?

1. Check agent-specific configs (`.cursor/rules/` vs `.claude/settings.json`)
2. Verify shared rules are identical in `.ai/rules/`
3. Review environment variables in `.env.ai`
4. Check for agent-specific overrides

### Build fails?

```bash
# Verify container exists
docker images | grep hyperscaler

# Rebuild container
make build-docker

# Reconfigure CMake
make config

# Check build directory
ls -la build/
```

## Additional Documentation

- **Project README**: `README.md` - General project overview
- **Cursor Guide**: `.ai/docs/cursor-guide.md` - Cursor-specific details
- **Claude Guide**: `.ai/docs/claude-guide.md` - Claude-specific details
- **Project Overview**: `.ai/context/project-overview.md` - Architecture details
- **Quick Reference**: `.ai/context/quick-reference.md` - Command cheat sheet
- **Test Documentation**: `tests/README.md` - Testing framework
- **Python CLI Docs**: `python/ai_how/README.md` - CLI package details

## Related Resources

- Claude Code Docs: https://docs.claude.com/en/docs/claude-code/settings
- Claude Best Practices: https://www.anthropic.com/engineering/claude-code-best-practices
- Cursor Documentation: https://docs.cursor.com/
- Conventional Commits: https://www.conventionalcommits.org/
- Commitizen: https://commitizen-tools.github.io/commitizen/
