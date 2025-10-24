# GitHub Actions Guide

**Status:** Production
**Created:** 2025-10-24
**Last Updated:** 2025-10-24

## Quick Facts

| Property | Value |
|----------|-------|
| **Workflows** | 1 file: `ci.yml` (127 lines) |
| **Trigger Events** | Push + Pull Request (main branch) |
| **Jobs** | 2 sequential jobs: lint → test |
| **Runners** | ubuntu-latest (GitHub-hosted) |
| **Python Version** | 3.11 (fixed) |
| **Estimated Duration** | 4-7 minutes total |
| **Secrets Used** | None |
| **Environment Variables** | 3 build environment variables |
| **Caching Strategy** | Python dependencies (based on lock files) |
| **Status Checks** | 2 checks: lint, test |

## Workflow Basics

### What is a Workflow?

A workflow is an automated process defined in YAML that GitHub Actions runs in response to events in your repository.

**Key Components:**

- **Trigger:** Event that starts the workflow (push, pull request)
- **Jobs:** Tasks to run (lint, test)
- **Steps:** Individual commands in each job
- **Actions:** Reusable workflow components

### The CI Workflow Structure

```yaml
name: Lint, Test, and Static Analysis    # Workflow name

on:                                       # Triggers
  pull_request:
    branches: [ main ]
  push:
    branches: [ main ]

jobs:                                     # Jobs
  lint:                                   # Job 1
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3        # Step 1: Action
      - run: make lint-ai-how             # Step 2: Command

  test:                                   # Job 2
    runs-on: ubuntu-latest
    needs: lint                           # Dependency on lint job
    steps:
      - uses: actions/checkout@v3
      - run: make test-ai-how
```

## Trigger Events

### Pull Request Event

Triggered when:

- PR is opened against `main` branch
- PR is updated (new commits pushed)
- Existing PR comment created/edited

**Configuration:**

```yaml
on:
  pull_request:
    branches: [ main ]
```

**Use Case:** Validate changes before merge

### Push Event

Triggered when:

- Commits pushed to `main` branch
- Also triggers on PR merge (automatic push)

**Configuration:**

```yaml
on:
  push:
    branches: [ main ]
```

**Use Case:** Validate merged changes post-merge

### Other Events (Not Used)

**workflow_dispatch:** Manual trigger from GitHub UI

```yaml
on:
  workflow_dispatch:
    inputs:
      skip_tests:
        description: 'Skip tests'
```

**schedule:** Cron-based scheduling

```yaml
on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight
```

**tag:** Triggered on tag creation

```yaml
on:
  push:
    tags: [ 'v*' ]
```

## Secrets and Environment Variables

### Environment Variables in Workflow

**Build Configuration Variables:**

```yaml
env:
  PKG_CONFIG_PATH: /usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig
  LDFLAGS: -L/usr/lib/x86_64-linux-gnu
  CPPFLAGS: -I/usr/include
```

**Purpose:** Configure compiler to find system libraries during build

**Scope:** Available to all steps in the job

### GitHub Secrets

**Current Implementation:** NONE

**How to Use Secrets:**

1. **Define in Repository Settings**
   - Go to Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `MY_SECRET`
   - Value: `secret_value` (hidden from logs)

2. **Reference in Workflow**

   ```yaml
   steps:
     - name: Use secret
       env:
         MY_SECRET: ${{ secrets.MY_SECRET }}
       run: |
         # Secret available as environment variable
         echo "Secret: $MY_SECRET"
         # Secret automatically masked in logs (output: "Secret: ***")
   ```

3. **Best Practices**
   - ✅ Never echo secrets to logs
   - ✅ Use environment variables, not inline
   - ✅ Scope secrets to specific workflows
   - ✅ Rotate secrets regularly
   - ✅ Use organization secrets for shared values

### GitHub Context Variables

Available automatically in workflows:

```yaml
${{ github.ref }}           # Branch: refs/heads/main
${{ github.sha }}           # Commit SHA: abc123...
${{ github.event_name }}    # Event type: push, pull_request
${{ github.actor }}         # User: username
${{ github.repository }}    # Repo: owner/repo
${{ github.run_id }}        # Run ID: unique identifier
```

## Status Checks

### What are Status Checks?

Status checks are requirements that must pass before a PR can merge. They appear in the PR's "Checks" tab.

### Status Checks in This Project

Two checks created by the workflow:

**1. `Lint, Test, and Static Analysis / lint`**

- Status: ✓ Passed or ✗ Failed
- Fails if: Any linting error detected
- Re-runnable: Yes (individually)

**2. `Lint, Test, and Static Analysis / test`**

- Status: ✓ Passed, ✗ Failed, or ⊘ Skipped
- Fails if: Any test fails
- Skipped if: Lint job failed
- Re-runnable: Yes (individually)

### Viewing Status Checks

**In Pull Request:**

1. Go to PR "Checks" tab
2. See both checks with status
3. Click "Details" to see logs

**In Commit History:**

1. Go to commit in history
2. Status checks shown with checkmark or X
3. Click check to view details

### Branch Protection Rules

Make status checks required for merging:

1. Go to Settings → Branches
2. Click "Edit" on main branch rule
3. Check "Require status checks to pass before merging"
4. Select `Lint, Test, and Static Analysis / lint`
5. Select `Lint, Test, and Static Analysis / test`
6. Save

Now PRs cannot merge until both checks pass.

## Job Dependencies

### Understanding Job Dependencies

Jobs run in parallel by default. Use `needs:` to create dependencies.

**Syntax:**

```yaml
jobs:
  job1:
    # This job runs immediately

  job2:
    needs: job1
    # This job waits for job1 to complete and succeed
```

### In This Project

```yaml
jobs:
  lint:
    # Runs immediately on workflow start

  test:
    needs: lint
    # Waits for lint job to complete
    # If lint fails, test is skipped (status: ⊘)
```

**Result:**

- Lint runs first
- Test waits for lint to succeed
- If lint fails, test doesn't run
- Reduces noise on failures

### Multiple Dependencies

```yaml
test:
  needs: [lint, build]
  # Waits for both lint AND build to succeed
```

## Common Workflow Patterns

### Pattern 1: Conditional Steps

```yaml
- name: Run tests
  if: github.event_name == 'push'
  run: make test
```

Only run if event is push (not on PR).

### Pattern 2: Conditional Jobs

```yaml
jobs:
  test:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - run: make test
```

Only run test job on main branch.

### Pattern 3: Matrix Strategy

```yaml
jobs:
  test:
    strategy:
      matrix:
        python-version: [3.10, 3.11, 3.12]
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - run: make test
```

Run tests on multiple Python versions and OS platforms (creates multiple job runs).

### Pattern 4: Continue on Error

```yaml
- name: Run tests
  continue-on-error: true
  run: make test

- name: Always run this
  run: echo "Done"
```

Workflow continues even if step fails.

### Pattern 5: Conditional Artifact Upload

```yaml
- name: Upload coverage
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: coverage-reports
    path: htmlcov/
```

Upload artifacts whether tests passed or failed.

## Adding New Workflows

### Step 1: Create Workflow File

Create new file: `.github/workflows/new-workflow.yml`

```yaml
name: New Workflow Name

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  my-job:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Do something
        run: echo "Hello from GitHub Actions!"
```

### Step 2: Commit and Push

```bash
git add .github/workflows/new-workflow.yml
git commit -m "feat: add new GitHub Actions workflow"
git push
```

Workflow automatically runs on next PR/push.

### Step 3: Monitor Workflow

1. Go to repository → Actions tab
2. Select "New Workflow Name" from left sidebar
3. See all runs with status and logs

### Best Practices for New Workflows

1. **Use meaningful names**
   - Good: `build-docker-images.yml`
   - Bad: `workflow1.yml`

2. **Add caching where possible**

   ```yaml
   - uses: actions/cache@v3
     with:
       path: ~/.cache/pip
       key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
   ```

3. **Document with comments**

   ```yaml
   # This step caches Python dependencies
   - name: Cache pip packages
     uses: actions/cache@v3
   ```

4. **Use appropriate events**
   - Push: Post-merge validation
   - PR: Pre-merge validation
   - Schedule: Nightly tests
   - Manual: One-off operations

5. **Fail fast on errors**

   ```yaml
   jobs:
     build:
       strategy:
         fail-fast: true  # Cancel other matrix jobs if one fails
       matrix:
         python: [3.11, 3.12]
   ```

## Troubleshooting Workflows

### Workflow Not Triggering

**Issue:** Workflow not running on push/PR

**Check:**

1. Workflow file exists in `.github/workflows/`
2. File is committed to repository (not uncommitted)
3. Event filters match (e.g., `branches: [main]`)
4. No syntax errors in YAML

**Fix:**

```bash
# Verify file structure
cat .github/workflows/ci.yml | head -20

# Check for syntax errors
# Try pushing again after fixing
git push
```

### Status Check Failing

**Issue:** Status check shows "Some checks were incomplete"

**Check:**

1. Workflow completed (check Actions tab)
2. Check name matches exactly
3. Job didn't timeout

**Fix:**

- Click "Details" to see logs
- Fix issues and push again
- Use "Re-run jobs" button for quick retry

### Secrets Not Working

**Issue:** Secret appears as empty or `null`

**Check:**

1. Secret defined in Settings → Secrets
2. Secret referenced correctly: `${{ secrets.NAME }}`
3. Secret has value (not empty)

**Fix:**

```yaml
# ✗ Wrong
env:
  SECRET: my-secret

# ✓ Correct
env:
  SECRET: ${{ secrets.MY_SECRET }}
```

### Job Timeout

**Issue:** Job runs longer than 6 hours (GitHub max)

**Check:**

- Job taking too long
- Infinite loop in workflow
- External service not responding

**Fix:**

- Optimize workflow steps
- Add `timeout-minutes` to job:

  ```yaml
  jobs:
    test:
      runs-on: ubuntu-latest
      timeout-minutes: 30  # Job times out after 30 min
  ```

## Performance Tips

### 1. Use Caching

```yaml
- uses: actions/cache@v3
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
```

Saves 15-60 seconds per workflow.

### 2. Parallelize Jobs

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: ruff check src/

  test:
    needs: lint  # Remove dependency if not needed
    runs-on: ubuntu-latest
    steps:
      - run: pytest
```

Without `needs:`, jobs run in parallel.

### 3. Use Specific Action Versions

```yaml
- uses: actions/checkout@v3    # ✓ Specific version
- uses: actions/checkout@main  # ✗ Latest (slower, less stable)
```

Specific versions cache faster.

### 4. Minimize Checkout

```yaml
- uses: actions/checkout@v3
  with:
    fetch-depth: 1  # Only current commit
```

Reduces git clone time.

### 5. Run Only When Needed

```yaml
- name: Run expensive task
  if: github.event_name == 'push'  # Skip on PR
  run: expensive-command
```

Skips unnecessary steps.

## Security Best Practices

### 1. Never Log Secrets

```bash
# ✗ Bad - secret will be logged
echo "Secret: ${{ secrets.DB_PASSWORD }}"

# ✓ Good - GitHub automatically masks secrets
export DB_PASSWORD=${{ secrets.DB_PASSWORD }}
./configure
```

### 2. Minimize Permissions

```yaml
permissions:
  contents: read           # Only read repository
  pull-requests: read      # Only read PRs
```

Restricts what workflow can do.

### 3. Use Branch Protection

```text
Settings → Branches → main
- Require status checks
- Require code review
- Dismiss stale reviews
```

Prevents bypassing status checks.

### 4. Audit Workflow Changes

```bash
# Review workflow changes before merge
git diff main -- .github/workflows/
```

Check for credential exposure or dangerous operations.

### 5. Use Organization Secrets

For shared secrets across repositories:

1. Organization Settings → Secrets
2. Set environment where secret is available
3. Reference in workflow: `${{ secrets.ORG_SECRET }}`

## Related Documentation

- **Full Pipeline Details:** `docs/development/ci-cd-pipeline.md`
- **Workflow Component Docs:** `.github/workflows/README.md`
- **GitHub Actions Official Docs:** https://docs.github.com/en/actions
- **Workflow Syntax Reference:** https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions

## Quick Reference

### Common Actions Used

| Action | Purpose | Example |
|--------|---------|---------|
| `actions/checkout` | Clone repository | `uses: actions/checkout@v3` |
| `actions/setup-python` | Install Python | `uses: actions/setup-python@v5` with `python-version: 3.11` |
| `actions/cache` | Cache files | `uses: actions/cache@v3` with `path, key` |
| `actions/upload-artifact` | Store build artifacts | `uses: actions/upload-artifact@v3` |

### Useful Contexts

| Context | Value | Usage |
|---------|-------|-------|
| `${{ github.ref }}` | Branch name | `if: github.ref == 'refs/heads/main'` |
| `${{ github.event_name }}` | Trigger type | `if: github.event_name == 'push'` |
| `${{ runner.os }}` | OS type | Cache key: `${{ runner.os }}-cache` |
| `${{ secrets.NAME }}` | Secret value | `env: SECRET: ${{ secrets.NAME }}` |

### File Locations

| Item | Location |
|------|----------|
| Workflows | `.github/workflows/` |
| Main workflow | `.github/workflows/ci.yml` |
| Workflow docs | `.github/workflows/README.md` |
| CI/CD docs | `docs/development/ci-cd-pipeline.md` |
| Nox config | `python/ai_how/noxfile.py` |
| Makefile | `Makefile` (root) |
