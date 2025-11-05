# Development Workflow Guide

**Status:** Production  
**Created:** 2025-11-05  
**Last Updated:** 2025-11-05

## Overview

This guide covers the complete development workflow for contributing to the Hyperscaler on Workstation project.
It includes setup, code quality tools, commit conventions, and testing procedures.

## Quick Reference

For developers already familiar with the project:

```bash
# Setup
make venv-create && source .venv/bin/activate

# Before committing
make pre-commit-run          # Run hooks on staged files
make lint-ai-how            # Lint Python code
make test-ai-how            # Run Python tests

# Commit
cz commit                   # Interactive commit (recommended)
# or
git commit -m "feat(scope): description"

# Testing
cd tests/ && make test      # Core infrastructure tests
```

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Development Environment](#development-environment)
3. [Code Quality and Linting](#code-quality-and-linting)
4. [Commit Message Format](#commit-message-format)
5. [Python Package Development](#python-package-development)
6. [Testing](#testing)
7. [Docker Development](#docker-development)
8. [CI/CD Pipeline](#cicd-pipeline)

---

## Initial Setup

### Prerequisites

Before starting development, ensure you have:

- Python 3.11+
- Docker (for containerized development)
- Git
- System dependencies for libvirt (see [Python Dependencies Setup](python-dependencies-setup.md))

### Clone and Setup

```bash
# Clone the repository
git clone <repository-url>
cd pharos.ai-hyperscaler-on-workskation-2

# Create and activate virtual environment
make venv-create
source .venv/bin/activate

# Install pre-commit hooks
pre-commit install
```

## Development Environment

### Virtual Environment (Recommended)

The project uses a Python virtual environment for dependency management:

```bash
# Create virtual environment and install dependencies
make venv-create

# Activate the virtual environment
source .venv/bin/activate

# Verify CLI installation
ai-how --help

# Deactivate when done
deactivate
```

### Docker Development Environment

For consistent development environments across platforms:

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

**When to use Docker:**

- Building Packer images
- Running CMake builds
- Ensuring consistent environment across team members
- Isolating build dependencies

**Related Documentation:**

- [Docker Environment Setup](../../docker/README.md)
- [Build System Architecture](../architecture/build-system.md)

## Code Quality and Linting

### Pre-commit Hooks

This project uses pre-commit hooks to enforce code quality standards automatically.

**Configured Hooks:**

- General formatting (whitespace, EOF, YAML/JSON/TOML/XML validation)
- Security checks (private keys, large files >10MB)
- Markdown linting
- Shell script linting (shellcheck)
- Dockerfile linting (hadolint)
- Commit message validation (Conventional Commits)

**Running Pre-commit:**

```bash
# Run on staged files (automatic on git commit)
make pre-commit-run

# Run on all files (for bulk fixes)
make pre-commit-run-all

# Run specific hook
pre-commit run <hook-id> --all-files

# Skip hooks (not recommended)
git commit --no-verify
```

**Common Workflows:**

```bash
# After making changes
git add <files>
make pre-commit-run      # Check before committing

# If hooks fail and auto-fix files
git add <fixed-files>    # Re-stage fixed files
git commit -m "..."      # Commit again

# Update hook versions
pre-commit autoupdate
```

**Complete Documentation:**

- [Code Quality & Linters Guide](code-quality-linters.md) - Comprehensive pre-commit documentation
- [CI/CD Pipeline](ci-cd-pipeline.md) - How hooks run in CI

## Commit Message Format

### Conventional Commits

This project follows [Conventional Commits](https://www.conventionalcommits.org/) specification.

**Format:**

```text
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `build`: Build system changes
- `ci`: CI/CD configuration changes
- `chore`: Maintenance tasks
- `revert`: Revert previous commit

**Scopes:**

- `ansible`: Ansible playbooks/roles
- `terraform`: Terraform configurations
- `packer`: Packer image templates
- `slurm`: SLURM configuration
- `k8s`: Kubernetes resources
- `gpu`: GPU configuration
- `docs`: Documentation
- `ci`: CI/CD pipelines
- `scripts`: Utility scripts
- `tests`: Test suite

**Examples:**

```bash
# Feature additions
feat(ansible): add GPU node provisioning playbook
feat(k8s): implement ingress controller deployment

# Bug fixes
fix(terraform): resolve VPC subnet configuration issue
fix(slurm): correct gres.conf GPU device mapping

# Documentation
docs(slurm): update MIG GPU configuration guide
docs(getting-started): add troubleshooting section

# Refactoring
refactor(packer): consolidate HPC image build stages
refactor(tests): extract common assertions to utility module

# Breaking changes
feat(ansible)!: change inventory structure for multi-cluster support

BREAKING CHANGE: inventory format changed from flat to hierarchical
```

### Interactive Commit (Recommended)

Use `commitizen` for interactive commit message creation:

```bash
# Install commitizen (already in dev dependencies)
cz commit

# Follow the prompts:
# 1. Select type
# 2. Enter scope
# 3. Write short description
# 4. Optionally add body
# 5. Mark breaking changes
```

### Commit Validation

Commit messages are validated by:

1. Pre-commit hook (local, can be bypassed with `--no-verify`)
2. CI/CD pipeline (cannot be bypassed)

**Common Issues:**

```bash
# Too short subject
❌ feat(ansible): add playbook
✓ feat(ansible): add GPU node provisioning playbook

# Missing scope
❌ feat: add new feature
✓ feat(ansible): add new feature

# Wrong type
❌ update(docs): fix typo
✓ docs: fix typo in installation guide

# Subject not lowercase
❌ feat(ansible): Add GPU support
✓ feat(ansible): add GPU support
```

**Related Documentation:**

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [Commitizen Documentation](https://commitizen-tools.github.io/commitizen/)

## Python Package Development

### AI-HOW CLI Package

The project includes a Python CLI package (`ai-how`) for cluster management.

**Development Workflow:**

```bash
# Install in development mode
make venv-create
source .venv/bin/activate

# Run tests
make test-ai-how

# Run linting
make lint-ai-how

# Auto-fix formatting issues
make format-ai-how

# Build documentation
make docs-ai-how

# Clean build artifacts
make clean-ai-how
```

### Running the CLI

```bash
# After activating venv
ai-how --help

# Or run as module
python -m ai_how.cli --help

# Example commands
ai-how cluster validate config/example.yaml
ai-how gpu list
ai-how cluster deploy --config config/example.yaml
```

### Nox Sessions

The Python package uses Nox for test automation:

```bash
cd python/ai_how/

# List available sessions
uv run nox --list

# Run specific session
uv run nox -s test-3.11
uv run nox -s lint-3.11
uv run nox -s format-3.11
uv run nox -s lint_fix-3.11
```

**Related Documentation:**

- [Python Dependencies Setup](python-dependencies-setup.md)
- [AI-HOW Package README](../../python/ai_how/README.md)

## Testing

### Test Suite Organization

The project includes comprehensive test suites organized into three main categories:

```text
tests/
├── foundation/       # Prerequisites validation
├── frameworks/       # Unified cluster tests
└── advanced/         # Integration tests
```

**Test Categories:**

- **`foundation/`** - Prerequisite validation tests
  - CLI functionality tests
  - Ansible roles validation
  - Packer images verification
  - Configuration file validation
  - Ensures all components work before deployment

- **`frameworks/`** - Unified cluster test frameworks
  - Controller node tests
  - Compute node tests
  - GPU passthrough validation
  - Network connectivity tests
  - Cluster integration tests

- **`advanced/`** - Integration test suites
  - BeeGFS parallel filesystem tests
  - Container registry functionality
  - VirtIO-FS shared filesystem tests
  - End-to-end workflow validation
  - Performance and stress tests

### Running Tests

```bash
# Core infrastructure tests (recommended for CI/CD)
cd tests/ && make test

# Comprehensive test suite
cd tests/ && make test-all

# Quick validation tests
cd tests/ && make test-quick

# Verbose output
cd tests/ && make test-verbose

# Specific test category
cd tests/ && make test-foundation
cd tests/ && make test-frameworks
cd tests/ && make test-advanced
```

### Python Package Tests

```bash
# Using Makefile
make test-ai-how

# Using Nox directly
cd python/ai_how/
uv run nox -s test-3.11

# With coverage
uv run nox -s test-3.11 -- --cov --cov-report=html
```

### Writing Tests

**Guidelines:**

- Use `pytest` for Python tests
- Use `bats` for shell script tests
- Place tests in appropriate category (foundation/frameworks/advanced)
- Follow existing test structure and naming conventions
- Use shared utilities from `tests/test-infra/utils/`

**Example Test Structure:**

```python
# tests/frameworks/test_cluster.py
import pytest
from test_infra.utils import cluster_utils

def test_cluster_validation():
    """Test cluster configuration validation."""
    config = cluster_utils.load_config("config/example.yaml")
    assert cluster_utils.validate_config(config)

def test_node_connectivity():
    """Test connectivity between cluster nodes."""
    nodes = cluster_utils.get_cluster_nodes()
    for node in nodes:
        assert cluster_utils.ping_node(node)
```

### For Test Framework Contributors

If you're writing new test frameworks or extending the test suite:

- **Full Documentation**: See [tests/README.md](../../tests/README.md) for comprehensive testing guide
- **Test Framework Standards**: Review "Writing New Test Frameworks" section in tests/README.md
- **Shared Utilities**: Use utilities in `tests/test-infra/utils/` for consistency across tests
- **Reference Implementations**: Study existing frameworks in `tests/frameworks/` as examples
- **Test Infrastructure**: Leverage shared test infrastructure components
- **Naming Conventions**: Follow established patterns for test file and function names

**Best Practices for Test Development:**

- Write clear, descriptive test names
- Include docstrings explaining what each test validates
- Use fixtures for common setup/teardown
- Implement proper error handling and cleanup
- Add assertions with meaningful messages
- Document any non-obvious test logic

**Related Documentation:**

- [Testing Framework Guide](../../tests/README.md)
- [Writing Test Frameworks](../../tests/README.md#writing-new-test-frameworks)

## Docker Development

### Development Container

The Docker development container provides a consistent environment with all tools pre-installed.

**Available Tools:**

- CMake 3.30+
- Ninja build system
- Packer 1.11+
- Terraform 1.9+
- Ansible 2.17+
- Python 3.11+
- libvirt and KVM tools

**Usage:**

```bash
# Build development image
make build-docker

# Interactive shell
make shell-docker

# Run CMake build
make run-docker COMMAND="cmake --build build"

# Run Packer build
make run-docker COMMAND="cd packer/hpc-base && packer build ."

# Multiple commands
make run-docker COMMAND="bash -c 'make config && cmake --build build'"
```

**Container Workflow:**

```bash
# 1. Build container (once or when Dockerfile changes)
make build-docker

# 2. Configure CMake (once or when CMakeLists.txt changes)
make config

# 3. Build targets
make run-docker COMMAND="cmake --build build --target <target>"

# 4. Clean up when done
make clean-docker
```

**Related Documentation:**

- [Docker Environment README](../../docker/README.md)
- [Build System Architecture](../architecture/build-system.md)

## CI/CD Pipeline

### GitHub Actions Workflow

The project uses GitHub Actions for continuous integration:

**Pipeline Stages:**

1. **Lint Job** - Code quality checks (2-3 minutes)
   - Python linting (ruff, black, mypy)
   - Shell script linting (shellcheck)
   - Dockerfile linting (hadolint)
   - Markdown linting

2. **Test Job** - Automated testing (2-5 minutes)
   - Python unit tests (pytest)
   - Coverage reporting
   - Only runs if lint passes

**Triggers:**

- Pull requests to any branch
- Pushes to `main` branch

**Required Status Checks:**

- `lint` - Must pass for PR merge
- `test` - Must pass for PR merge

**Local Validation:**

Before pushing, run the same checks locally:

```bash
# Lint checks (matches CI lint job)
make lint-ai-how
make pre-commit-run-all

# Tests (matches CI test job)
make test-ai-how
cd tests/ && make test
```

**Related Documentation:**

- [CI/CD Pipeline Guide](ci-cd-pipeline.md)
- [GitHub Actions Guide](github-actions-guide.md)

## Best Practices

### Before Committing

1. **Run pre-commit hooks:**

   ```bash
   make pre-commit-run
   ```

2. **Run relevant tests:**

   ```bash
   make test-ai-how              # If changing Python code
   cd tests/ && make test-quick  # For infrastructure changes
   ```

3. **Check linting:**

   ```bash
   make lint-ai-how
   ```

### Code Style

- **Python**: Follow PEP 8, enforced by ruff and black
- **Shell**: Follow Google Shell Style Guide
- **Markdown**: Follow markdownlint rules
- **YAML**: 2-space indentation, no trailing spaces
- **Line Length**: 120 characters for code, 100 for markdown

### Documentation

- Update relevant README files when adding features
- Add docstrings to Python functions
- Include examples in documentation
- Keep documentation in sync with code changes

### Git Workflow

```bash
# 1. Create feature branch
git checkout -b feat/my-feature

# 2. Make changes and commit frequently
git add <files>
make pre-commit-run
cz commit

# 3. Keep branch updated
git fetch origin
git rebase origin/main

# 4. Push to remote
git push origin feat/my-feature

# 5. Create pull request
# CI/CD will automatically run checks
```

## Troubleshooting

### Pre-commit Hook Failures

```bash
# Update hooks
pre-commit autoupdate

# Clear cache
pre-commit clean

# Reinstall hooks
pre-commit uninstall
pre-commit install
```

### Python Environment Issues

```bash
# Remove and recreate venv
make venv-clean
make venv-create

# Check Python version
python --version  # Should be 3.11+

# Verify dependencies
pip list | grep libvirt
```

### Docker Build Issues

```bash
# Clean Docker cache
make clean-docker

# Rebuild from scratch
docker system prune -a
make build-docker
```

### Test Failures

```bash
# Run with verbose output
cd tests/ && make test-verbose

# Run specific test
cd tests/ && pytest -v tests/foundation/test_cli.py::test_specific

# Check test logs
cat tests/test-infra/logs/*.log
```

## Additional Resources

### Development Documentation

- [Code Quality & Linters](code-quality-linters.md)
- [CI/CD Pipeline](ci-cd-pipeline.md)
- [GitHub Actions Guide](github-actions-guide.md)
- [Python Dependencies Setup](python-dependencies-setup.md)
- [Cursor Agent Setup](cursor-agent-setup.md)

### Architecture Documentation

- [System Overview](../architecture/overview.md)
- [Build System Architecture](../architecture/build-system.md)
- [Network Architecture](../architecture/network.md)
- [GPU Architecture](../architecture/gpu.md)

### Component Documentation

- [Ansible Roles](../../ansible/README.md)
- [Packer Images](../../packer/README.md)
- [Python CLI Package](../../python/ai_how/README.md)
- [Test Framework](../../tests/README.md)

## Getting Help

- **Documentation**: Check relevant READMEs in component directories
- **Issues**: Search existing GitHub issues or create new one
- **Discussions**: Use GitHub Discussions for questions
- **Code Review**: Ask for feedback in pull requests

---

**Happy Contributing! 🚀**
