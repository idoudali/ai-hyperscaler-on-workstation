# Development Documentation

This folder contains comprehensive guides for developers contributing to the Hyperscaler on Workstation project.

## Getting Started

New contributors should start here:

1. **[Development Workflow Guide](development-workflow.md)** - Start here for complete setup and workflow
2. **[Python Dependencies Setup](python-dependencies-setup.md)** - System dependencies and troubleshooting
3. **[Code Quality & Linters](code-quality-linters.md)** - Understanding pre-commit hooks and linting

## Documentation Index

### Core Workflow

- **[Development Workflow Guide](development-workflow.md)**
  - Initial setup and environment configuration
  - Code quality tools and pre-commit hooks
  - Commit message conventions
  - Python package development
  - Testing procedures
  - Docker development environment
  - Best practices and troubleshooting

### Code Quality

- **[Code Quality & Linters Configuration](code-quality-linters.md)**
  - Pre-commit hooks framework
  - Markdown linting (markdownlint)
  - Shell script linting (shellcheck)
  - CMake formatting (cmake-format)
  - Python quality tools (ruff, black, mypy)
  - Commit message validation (commitizen)
  - Comprehensive configuration reference

### CI/CD

- **[CI/CD Pipeline Documentation](ci-cd-pipeline.md)**
  - GitHub Actions workflow architecture
  - Lint and test job configuration
  - Pipeline triggers and requirements
  - Status checks and PR requirements
  - Troubleshooting failed builds

- **[GitHub Actions Guide](github-actions-guide.md)**
  - Detailed workflow documentation
  - Action configurations and usage
  - Secrets and environment variables
  - Workflow optimization

### Environment Setup

- **[Python Dependencies Setup](python-dependencies-setup.md)**
  - System package requirements
  - libvirt-python installation
  - Common issues and solutions
  - Platform-specific guidance

- **[Cursor Agent Setup](cursor-agent-setup.md)**
  - AI-assisted development configuration
  - Cursor IDE integration
  - Agent rules and best practices
  - Project-specific settings

## Quick Reference

### Essential Commands

```bash
# Setup
make venv-create && source .venv/bin/activate
pre-commit install

# Development
make test-ai-how       # Run Python tests
make lint-ai-how       # Lint Python code
make format-ai-how     # Format Python code
make pre-commit-run    # Run all quality checks

# Commit
cz commit              # Interactive commit (recommended)

# Docker
make build-docker      # Build development container
make shell-docker      # Interactive shell in container

# Testing
cd tests/ && make test      # Core infrastructure tests
cd tests/ && make test-all  # Comprehensive test suite
```

### File Structure

```text
docs/development/
├── README.md                          # This file
├── development-workflow.md            # Complete workflow guide (START HERE)
├── code-quality-linters.md           # Pre-commit and linting tools
├── ci-cd-pipeline.md                 # GitHub Actions pipeline
├── github-actions-guide.md           # Detailed CI/CD guide
├── python-dependencies-setup.md      # Python environment setup
└── cursor-agent-setup.md             # AI-assisted development
```

## Common Workflows

### First-Time Setup

```bash
# 1. Clone and setup
git clone <repo>
cd pharos.ai-hyperscaler-on-workskation-2

# 2. Create virtual environment
make venv-create
source .venv/bin/activate

# 3. Install pre-commit hooks
pre-commit install

# 4. Verify setup
ai-how --help
make test-ai-how
```

### Making Changes

```bash
# 1. Create feature branch
git checkout -b feat/my-feature

# 2. Make changes
# ... edit files ...

# 3. Run quality checks
make pre-commit-run
make lint-ai-how
make test-ai-how

# 4. Commit
git add <files>
cz commit

# 5. Push and create PR
git push origin feat/my-feature
```

### Before Committing

Always run these checks:

```bash
make pre-commit-run    # Code quality checks
make lint-ai-how       # Python linting
make test-ai-how       # Python tests
```

## Documentation Hierarchy

1. **Quick Start** → [Development Workflow Guide](development-workflow.md)
2. **Environment Setup** → [Python Dependencies Setup](python-dependencies-setup.md)
3. **Code Quality** → [Code Quality & Linters](code-quality-linters.md)
4. **CI/CD** → [CI/CD Pipeline](ci-cd-pipeline.md)
5. **Troubleshooting** → Check individual guides for specific issues

## Additional Resources

### Related Documentation

- [Main README](../../README.md) - Project overview and getting started
- [Architecture Documentation](../architecture/overview.md) - System design and architecture
- [Component Documentation](../../ansible/README.md) - Individual component guides
- [Test Framework](../../tests/README.md) - Testing documentation

### External Resources

- [Conventional Commits](https://www.conventionalcommits.org/) - Commit message format
- [Pre-commit Framework](https://pre-commit.com/) - Pre-commit hooks
- [Python Packaging](https://packaging.python.org/) - Python package development
- [pytest Documentation](https://docs.pytest.org/) - Testing framework

## Getting Help

- **Documentation Issues**: Check relevant guide or component README
- **Build Errors**: See [Development Workflow Guide](development-workflow.md#troubleshooting)
- **Python Issues**: See [Python Dependencies Setup](python-dependencies-setup.md)
- **CI/CD Issues**: See [CI/CD Pipeline](ci-cd-pipeline.md)
- **Code Quality**: See [Code Quality & Linters](code-quality-linters.md)

## Contributing to Documentation

When updating development documentation:

1. Keep this README index up to date
2. Follow markdown linting rules (see [Code Quality Guide](code-quality-linters.md))
3. Include practical examples
4. Test all command examples
5. Update related documentation references

---

**Start with the [Development Workflow Guide](development-workflow.md) for a complete walkthrough.**
