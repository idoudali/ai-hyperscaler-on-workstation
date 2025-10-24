# GitHub Actions Workflows

**Location:** Component documentation for CI/CD automation
**Last Updated:** 2025-10-24

## Overview

This directory contains GitHub Actions workflow configurations that automate code quality checks
and testing for the AI-HOW project.

## Workflows

### CI Pipeline (`ci.yml`)

**Purpose:** Lint and test Python code, shell scripts, and Docker images on every pull request and push to main

**Trigger Events:**

- Pull requests targeting the `main` branch
- Pushes to the `main` branch

**Jobs:**

1. **Lint Job** (~2-3 minutes)
   - Python linting: ruff (style), mypy (types)
   - Shell script linting: shellcheck
   - Dockerfile linting: hadolint

2. **Test Job** (~2-5 minutes, runs only if lint passes)
   - Python unit tests: pytest with coverage

**Status Checks:**

- `Lint, Test, and Static Analysis / lint` - Code quality checks
- `Lint, Test, and Static Analysis / test` - Unit tests

## Quick Start

### For Developers

To run the same checks locally before pushing:

```bash
# Install development environment
make build-docker
make venv-create

# Run linting
make lint-ai-how

# Run tests
make test-ai-how

# Auto-fix formatting issues
make format-ai-how
```

### For CI/CD Maintainers

To modify workflows:

1. Edit `.github/workflows/ci.yml`
2. Push changes to `main` - workflow uses the version from the branch being tested
3. Changes take effect immediately on next PR

## Detailed Documentation

- **Full Architecture & Analysis:** See `docs/development/CI-CD-PIPELINE.md`
- **GitHub Actions Reference:** See `docs/development/GITHUB-ACTIONS-GUIDE.md`
- **Quick Reference:** See `docs/development/GITHUB-ACTIONS-GUIDE.md#quick-facts`

## Key Features

- ✅ **Sequential Pipeline:** Linting before testing ensures code quality gates
- ✅ **Dependency Caching:** Python dependencies cached for faster runs (~30-60s saved)
- ✅ **No Secrets:** All dependencies from public sources, safe for public repository
- ✅ **Local Integration:** Same commands run locally and in CI via Makefile

## What Gets Checked

| Check | Tool | Files | Purpose |
|-------|------|-------|---------|
| Python Style | ruff check | `python/ai_how/src/**/*.py` | Code formatting |
| Python Format | ruff format | `python/ai_how/src/**/*.py` | Format verification |
| Python Types | mypy | `python/ai_how/src/**/*.py` | Type checking |
| Shell Scripts | shellcheck | `scripts/**/*.sh` | Shell best practices |
| Dockerfile | hadolint | `docker/Dockerfile` | Docker best practices |
| Python Tests | pytest | `python/ai_how/tests/**` | Unit tests + coverage |

## Running CI Locally

### Pre-commit Hooks

Run before committing:

```bash
make pre-commit-run
```

### Full CI Simulation

Run the exact same checks as GitHub:

```bash
# Lint
cd python/ai_how
uv run nox -s lint

# Test
cd python/ai_how
uv run nox -s test
```

### Individual Checks

```bash
# Python linting only
cd python/ai_how
uv run nox -s lint

# Shell scripts only
cd scripts
shellcheck *.sh

# Dockerfile only
hadolint docker/Dockerfile

# Python tests only
cd python/ai_how
uv run nox -s test
```

## Troubleshooting

### PR Status: "Some checks were not successful"

1. Click "Details" next to the failed check
2. Read the error logs to find the issue
3. Fix locally using `make lint-ai-how` or `make format-ai-how`
4. Commit and push - CI will re-run automatically

### Common Issues

| Issue | Solution |
|-------|----------|
| Lint fails: "Unused variable" | Run `make format-ai-how` to auto-fix |
| Lint fails: "Type error" | Add type annotations to variables |
| ShellCheck fails | Review shellcheck recommendations |
| Test fails | Run `make test-ai-how` locally to debug |

## Performance

- **Optimistic case:** ~1.8 minutes (all caches hit)
- **Typical case:** ~2.5 minutes (most caches hit)
- **Pessimistic case:** ~3.8 minutes (cache miss)

Caching saves approximately 30-60 seconds per job by reusing Python dependencies.

## GitHub Branch Protection

The status checks created by these workflows can be used as required checks for pull requests:

1. Go to Settings → Branches → main
2. Under "Require status checks to pass before merging"
3. Select `Lint, Test, and Static Analysis / lint` (required)
4. Select `Lint, Test, and Static Analysis / test` (required)

## Related Documentation

- **Development Setup:** `README.md` (root project)
- **Agent Configuration:** `AI-AGENT-GUIDE.md`
- **Pre-commit Rules:** `.ai/rules/precommit-workflow.md`
