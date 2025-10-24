# CI/CD Pipeline Documentation

**Status:** Production
**Created:** 2025-10-24
**Last Updated:** 2025-10-24

## Overview

The AI-HOW project implements a **two-stage CI/CD pipeline** using GitHub Actions that validates code
quality and functionality on every pull request and push to the main branch. The pipeline emphasizes
code quality first (linting before testing) to catch issues early.

**Pipeline Summary:**

- **1 Workflow:** `ci.yml` (127 lines)
- **2 Sequential Jobs:** Lint → Test
- **Trigger:** PR + Push to main branch only
- **Duration:** 4-7 minutes typical (2-3 for lint, 2-5 for test)
- **Secrets:** None required
- **Status Checks:** 2 (lint, test)

## Architecture

### High-Level Pipeline

```text
GitHub Event (PR/Push to main)
    ↓
┌─────────────────────────┐
│   LINT JOB              │
│   • Python linting      │
│   • Shell scripts       │
│   • Dockerfile checks   │
│   ~2-3 minutes          │
└─────────────────────────┘
    ↓ (must pass)
┌─────────────────────────┐
│   TEST JOB              │
│   • Unit tests (pytest) │
│   • Coverage reporting  │
│   ~2-5 minutes          │
│   (skipped if lint fails)
└─────────────────────────┘
    ↓
GitHub Status Update → PR Mergeable
```

### Workflow Triggers

The `ci.yml` workflow is triggered by:

```yaml
on:
  pull_request:
    branches: [ main ]
  push:
    branches: [ main ]
```

**Trigger Details:**

| Event | When | Purpose |
|-------|------|---------|
| Pull Request | PR created/updated targeting main | Pre-merge validation |
| Push | Commit pushed to main | Post-merge verification |

**Important:** Workflow only runs on the `main` branch, not on feature branches or other branches.

## Pipeline Stages

### Stage 1: LINT Job

**Duration:** ~2-3 minutes
**Status Check:** `Lint, Test, and Static Analysis / lint`
**Failure:** Blocks TEST job

#### Setup Steps

1. **Checkout repository** (2-3s)
   - Clone repository to runner workspace

2. **Setup Python 3.11** (3-5s, cached)
   - Install Python 3.11 runtime
   - Environment cached from previous runs

3. **Install system dependencies** (10-15s)

   ```bash
   libvirt-dev      # Libvirt development headers
   pkg-config       # Compiler configuration tool
   build-essential  # GCC and build tools
   python3-dev      # Python development headers
   libssl-dev       # OpenSSL development libraries
   libffi-dev       # Foreign Function Interface library
   ```

   - Required for compiling native Python packages (libvirt-python, cryptography)

4. **Set build environment variables** (~0.5s)

   ```bash
   PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig
   LDFLAGS=-L/usr/lib/x86_64-linux-gnu
   CPPFLAGS=-I/usr/include
   ```

   - Configures compiler to find system libraries

5. **Install uv package manager** (2-3s, cached)
   - Fast Python package manager (10-100x faster than pip)
   - Version: latest

6. **Lookup dependency cache** (~0.5s)
   - Cache Key: `Linux-python-deps-<hash of pyproject.toml + uv.lock>`
   - Cache Location: `~/.cache/uv`
   - Hit: Skip install, saves 15-30s per job
   - Miss: Install fresh, save to cache for next run

7. **Install project dependencies** (15-30s with cache, 45-60s without)

   ```bash
   uv venv --clear
   uv pip install -e ".[dev]"
   ```

   - Installs: pytest, mypy, ruff, nox, pre-commit, black, and other dev tools

#### Linting Checks

1. **Python Code Linting** (Nox session, ~10s)
   - **ruff check:** Python code style and common issues
     - Code style (E, F, W)
     - Import sorting (I)
     - Type issues (ARG, SIM, TID)
   - **ruff format:** Code formatting validation
   - **mypy:** Static type checking

2. **Shell Script Linting** (shellcheck, ~3-5s)
   - Scans: All `.sh` files in `./scripts/` directory
   - Checks: Syntax, best practices, potential bugs

3. **Dockerfile Linting** (hadolint, ~2-3s)
   - File: `docker/Dockerfile`
   - Checks: Best practices, security issues, layer optimization

**Lint Job Failure Conditions:**

- Python linting/formatting/type errors
- Shell script syntax or best practice violations
- Dockerfile best practice violations

**Status:** Creates check `Lint, Test, and Static Analysis / lint`

### Stage 2: TEST Job

**Duration:** ~2-5 minutes (only if lint passes)
**Status Check:** `Lint, Test, and Static Analysis / test`
**Dependency:** `needs: lint` - blocks until lint succeeds

#### Setup Steps (1-7: Same as Lint Job)

Same environment setup as lint job (checkout, Python, system deps, environment variables, uv, cache, dependencies).

#### Testing

1. **Python Unit Tests** (~10-20s)
   - Command: `uv run nox -s test` → `python -m pytest`
   - Tests: All files matching `test_*.py` in `tests/` directory
   - Configuration: From `pyproject.toml`:

     ```ini
     testpaths = ["tests"]
     python_files = ["test_*.py"]
     python_classes = ["Test*"]
     python_functions = ["test_*"]
     ```

   - Coverage: Reports generated (terminal + HTML, not uploaded)
   - Failure: Any test failure fails the job

**Test Job Failure Conditions:**

- Any pytest test fails
- Test setup/teardown errors
- Import errors
- Coverage report generation failures

**Status:** Creates check `Lint, Test, and Static Analysis / test`

- Result: ✓ PASS, ✗ FAIL, or ⊘ SKIPPED (if lint failed)

## Environment Variables

### Build Configuration Variables

Set in workflow to configure compiler flags:

| Variable | Value | Purpose |
|----------|-------|---------|
| `PKG_CONFIG_PATH` | `/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig` | Locates `.pc` files for library detection |
| `LDFLAGS` | `-L/usr/lib/x86_64-linux-gnu` | Linker flags for system libraries |
| `CPPFLAGS` | `-I/usr/include` | C preprocessor flags for headers |

**Purpose:** Help compiler find system libraries (libvirt, OpenSSL, libffi) during `pip install`

### Automatically Available Variables (GitHub)

| Variable | Usage | Example |
|----------|-------|---------|
| `${{ runner.os }}` | Cache key | `Linux` |
| `${{ github.ref }}` | Branch reference | `refs/heads/main` |
| `${{ github.sha }}` | Commit SHA | `abc123def456...` |
| `${{ github.event_name }}` | Trigger event | `push` or `pull_request` |

## Caching Strategy

### Python Dependencies Cache

**Purpose:** Reuse installed Python packages to speed up workflow

**Cache Configuration:**

```yaml
path: ~/.cache/uv
key: ${{ runner.os }}-python-deps-${{ hashFiles('**/pyproject.toml', '**/uv.lock') }}
restore-keys: |
  ${{ runner.os }}-python-deps-
```

**Cache Key Components:**

- `${{ runner.os }}` - OS identifier (Linux)
- Hash of all `pyproject.toml` files
- Hash of `uv.lock` file

**Cache Hit When:**

- `pyproject.toml` and `uv.lock` unchanged
- Saves ~15-30 seconds per job (30-60s saved in both lint + test)

**Cache Miss When:**

- Any dependency version changed
- Lock file updated
- New runner allocated (first run or cache evicted)

**Performance Impact:**

- **First run:** ~45-60s to install dependencies
- **Subsequent runs:** ~15-30s (cache hit) or full install on miss
- **Total savings:** 30-60 seconds per workflow run

### No Secrets Caching

**Secrets:** NONE used in workflows

All dependencies are from public sources:

- PyPI (Python packages)
- GitHub Actions marketplace
- Ubuntu apt repositories

Safe for public repositories with no credential exposure risk.

## Local Development Integration

### Pre-commit Hooks

Run before committing (local validation):

```bash
make pre-commit-install
make pre-commit-run
```

**Hooks include:** Trailing whitespace, YAML validation, shell linting, markdown linting, and conventional commits

### Makefile Commands

Local commands mirror CI checks:

```bash
# Lint (same as CI)
make lint-ai-how
  └─ Runs: cd python/ai_how && uv run nox -s lint

# Test (same as CI)
make test-ai-how
  └─ Runs: cd python/ai_how && uv run nox -s test

# Format (auto-fix)
make format-ai-how
  └─ Runs: cd python/ai_how && uv run nox -s format --fix
```

### Nox Configuration

`python/ai_how/noxfile.py` defines test sessions:

```python
@session(python=["3.11"])
def lint(s: Session) -> None:
    """Run linting and type checking."""
    s.install(".[dev]")
    s.run("ruff", "check", "src", "tests")
    s.run("ruff", "format", "--check", "src", "tests")
    s.run("mypy", "src")

@session(python=["3.11"])
def test(s: Session) -> None:
    """Run tests."""
    s.install(".[dev]")
    s.run("python", "-m", "pytest", *s.posargs)
```

### Running Locally

```bash
# Same commands as CI
cd python/ai_how

# Lint
uv run nox -s lint

# Test
uv run nox -s test

# Format with auto-fix
uv run nox -s format -- --fix
```

## Job Dependencies and Execution Order

### Dependency Graph

```text
START
  ↓
LINT JOB
  ├─ Checkout
  ├─ Python setup
  ├─ System dependencies
  ├─ Build environment
  ├─ uv + cache
  ├─ Python packages
  ├─ Nox lint (ruff + mypy)
  ├─ ShellCheck
  └─ Hadolint
  ↓ (must pass)
TEST JOB (only if LINT passed)
  ├─ Checkout (parallel possible, but sequential for simplicity)
  ├─ Python setup
  ├─ System dependencies
  ├─ Build environment
  ├─ uv + cache
  ├─ Python packages
  └─ Pytest
  ↓
WORKFLOW COMPLETE
  ├─ Success: All checks passed
  └─ Failure: Some checks failed
```

**Sequential Execution:** Test job waits for lint job to complete and succeed before starting

**Job Blocking:** `needs: lint` in test job configuration ensures dependency

## Status Checks and Reporting

### GitHub Status Checks

Two status checks visible on PR:

1. **`Lint, Test, and Static Analysis / lint`**
   - Status: ✓ Passed or ✗ Failed
   - Duration: ~2-3 minutes
   - Mergeable: PR cannot merge if failed

2. **`Lint, Test, and Static Analysis / test`**
   - Status: ✓ Passed, ✗ Failed, or ⊘ Skipped
   - Duration: ~2-5 minutes (only if lint passed)
   - Mergeable: PR cannot merge if failed

### Accessing Results

1. **PR Checks Tab**
   - Shows both status checks
   - Click "Details" to view logs

2. **Commit Status Page**
   - Shows status checks for specific commit
   - Accessible from commit history

3. **GitHub CLI**

   ```bash
   gh run list              # List recent runs
   gh run view <run-id>     # View run details
   ```

### Failure Reporting

**Lint Failures:**

- Output visible in "Run linting checks" step
- Shows file, line number, and specific issue
- Tool output: ruff, mypy, shellcheck, hadolint

**Test Failures:**

- Output visible in "Run Python unit tests" step
- Shows test name, assertion error, and stack trace
- Pytest output with coverage summary

## Performance Characteristics

### Typical Timeline

```text
Event (PR/Push)       → Queued
Queued (2-5s)         → Runner allocated
Setup (10-15s)        → Python environment
Install (15-30s)      → Dependencies (with cache)
Lint (15-20s)         → Code quality checks
Test (10-20s)         → Unit tests
Status (1s)           → GitHub updated

TOTAL: ~4-7 minutes typical
```

### Performance Cases

| Case | Duration | Notes |
|------|----------|-------|
| Optimistic (all cache hits) | ~1.8 minutes | Rare, perfect conditions |
| Typical (most cache hits) | ~2.5 minutes | Normal scenario |
| Pessimistic (cache miss) | ~3.8 minutes | First run or dependency change |

**Critical Path:**

1. Lint job (blocking factor: dependency install + linting checks)
2. Test job (blocking factor: dependency install + pytest)
3. GitHub status update (instantaneous)

### Optimization Opportunities

**Potential Improvements:**

1. **System Package Caching** (~10-15s savings)
   - Currently: Fresh `apt-get install` each run
   - Opportunity: Cache apt packages

2. **Parallel Setup** (~30-40s savings)
   - Currently: Duplicate setup in lint + test jobs
   - Opportunity: Shared setup job before both

3. **Workflow Dispatch** (no time impact)
   - Currently: Cannot manually trigger
   - Opportunity: Add `workflow_dispatch` event

4. **Test Artifacts** (no time impact)
   - Currently: None created
   - Opportunity: Upload coverage HTML reports

## Troubleshooting

### PR Status: Checks Not Passing

**Solution:**

1. Click "Details" next to failed check in PR
2. Review error logs in workflow run view
3. Fix locally:

   ```bash
   make lint-ai-how      # See linting errors
   make format-ai-how    # Auto-fix many issues
   make test-ai-how      # Debug tests
   ```

4. Commit and push - CI re-runs automatically

### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Linting fails: Code style | Formatting violations | `make format-ai-how` to auto-fix |
| Linting fails: Type errors | Missing type annotations | Add type hints to variables |
| Linting fails: Shell issue | Shell script problem | Review shellcheck output |
| Test fails: Assertion error | Test expectation not met | Fix code logic or test expectations |
| Test fails: Import error | Missing package | Add to `pyproject.toml` or install locally |
| Test skipped | Lint failed first | Fix lint errors, CI re-runs automatically |

### System Dependency Issues

**Scenario:** apt-get installation fails

- Rare - all packages are standard Ubuntu packages
- Solution: Update workflow to use different package or version
- File issue if package not available

## Secrets and Security

### Current Implementation

**Secrets Used:** NONE

**Security Posture:**

- ✅ No hardcoded credentials
- ✅ No external API authentication
- ✅ No registry credentials needed
- ✅ All dependencies from public sources
- ✅ Safe for public repository

### Future Secret Management

If secrets needed in future:

```yaml
steps:
  - name: Use secret
    run: |
      # Reference secret from GitHub repository settings
      curl -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
        https://api.github.com/repos/...
```

**Requirements:**

1. Define secret in GitHub repository settings (Settings → Secrets and variables → Actions)
2. Reference in workflow: `${{ secrets.SECRET_NAME }}`
3. Secret injected at runtime, never logged or visible
4. Never commit secrets to version control

## Integration Points

### Workflow Definition

**File:** `.github/workflows/ci.yml` (127 lines)

**Components:**

- Event triggers
- Job definitions
- Step configurations
- Tool integrations

### Configuration Files

| File | Purpose | Integrated |
|------|---------|-----------|
| `.github/workflows/ci.yml` | Workflow definition | Yes (primary) |
| `python/ai_how/pyproject.toml` | Python dependencies | Yes (cached) |
| `python/ai_how/uv.lock` | Locked versions | Yes (cache key) |
| `python/ai_how/noxfile.py` | Test sessions | Yes (via Nox) |
| `.pre-commit-config.yaml` | Pre-commit hooks | No (local only) |
| `Makefile` | Development commands | No (CI uses direct commands) |
| `docker/Dockerfile` | Container definition | Yes (linted by hadolint) |

### Local vs CI Commands

**Developers run locally:**

```bash
make lint-ai-how  # Local linting
make test-ai-how  # Local testing
```

**CI runs same commands:**

```bash
cd python/ai_how && uv run nox -s lint  # CI linting
cd python/ai_how && uv run nox -s test  # CI testing
```

## Best Practices

### For Developers

1. **Run checks locally before pushing**

   ```bash
   make lint-ai-how && make test-ai-how
   ```

2. **Fix formatting issues immediately**

   ```bash
   make format-ai-how
   ```

3. **Commit all dependency changes together**
   - Keeps cache effective
   - Reduces cache misses

4. **Read CI logs when PR fails**
   - Quick feedback loop
   - Fix issues locally

### For CI/CD Maintainers

1. **Edit workflows carefully**
   - Test changes on feature branches
   - Verify performance impact

2. **Document workflow changes**
   - Update this documentation
   - Note in commit messages

3. **Monitor workflow performance**
   - Track execution times
   - Identify optimization opportunities

4. **Review external actions**
   - Verify action versions
   - Check for security updates

## Related Documentation

- **Component Workflows:** `.github/workflows/README.md`
- **GitHub Actions Guide:** `docs/development/GITHUB-ACTIONS-GUIDE.md`
- **Development Setup:** `README.md` (root)
- **Agent Configuration:** `AI-AGENT-GUIDE.md`
- **Pre-commit Workflow:** `.ai/rules/precommit-workflow.md`
