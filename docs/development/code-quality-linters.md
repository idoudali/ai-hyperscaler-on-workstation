# Code Quality & Linters Configuration

**Status:** Production
**Created:** 2025-10-24
**Last Updated:** 2025-10-24

## Overview

This document provides comprehensive documentation for all code quality tools, linters, formatters, and checkers
used in the AI-HOW project. It covers the pre-commit hooks framework, markdown linting, shell script linting,
CMake formatting, Python quality tools, and commit message validation.

## Pre-commit Hooks Framework

### Architecture Overview

The project uses pre-commit framework to run automated checks before each commit:

```text
Pre-commit Framework
├── Configuration (.pre-commit-config.yaml)
├── Hooks (20+ configured)
├── Stages
│   ├── pre-commit (default)
│   └── commit-msg
├── Triggers
│   ├── Manual: pre-commit run [hook]
│   ├── Git hook: automatic on git commit
│   └── CI/CD: GitHub Actions workflow
└── Actions
    ├── Pass (allow commit)
    ├── Fail (block commit)
    └── Auto-fix (modify files)
```

### How Pre-commit Works

1. **Configuration Loading:** Reads `.pre-commit-config.yaml`
2. **Hook Installation:** `pre-commit install` sets up git hooks
3. **File Staging:** Detects changed files in git staging area
4. **Hook Execution:** Runs configured hooks on staged files
5. **Validation:** Checks pass or fail
6. **Auto-fix:** Some hooks automatically fix files
7. **Result:** Allows or blocks commit

### Installation and Setup

#### Initial Setup

```bash
# Install pre-commit framework
pip install pre-commit

# Install git hooks
pre-commit install

# Verify installation
pre-commit run --all-files
```

#### Uninstall (if needed)

```bash
# Remove git hooks
pre-commit uninstall

# Uninstall framework
pip uninstall pre-commit
```

### Running Hooks Manually

#### Run All Hooks on Staged Files

```bash
# Default: checks only staged files
pre-commit run
```

#### Run Specific Hook

```bash
# Only markdownlint
pre-commit run markdownlint

# Only shellcheck
pre-commit run shellcheck

# Only trailing whitespace
pre-commit run trailing-whitespace
```

#### Run All Hooks on All Files

```bash
# WARNING: Use only when explicitly needed
# Runs checks on entire repository
pre-commit run --all-files
```

**When to use `--all-files`:**

- After adding new hooks to configuration
- When migrating to stricter rules
- During refactoring campaigns
- In CI/CD pipeline (GitHub Actions)

**When NOT to use `--all-files`:**

- Normal development workflow
- Local commits (use staged files only)
- Large repositories (slow)
- Per project rules

#### Verbose Output

```bash
# Show detailed output
pre-commit run -v

# Very verbose with timing
pre-commit run -vv
```

### Hook Stages

#### Pre-commit Stage (default)

```yaml
stages: [pre-commit]
```

Runs before the commit is created. Can block the commit.

#### Commit-msg Stage

```yaml
stages: [commit-msg]
```

Runs after the commit message is written. Can reject commit based on message format.

### Configuration File Structure

Location: `.pre-commit-config.yaml`

```yaml
# Repos define where hooks come from
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0                    # Version to use
    hooks:
      - id: trailing-whitespace    # Hook identifier
        stages: [pre-commit]        # When to run
      - id: end-of-file-fixer
        stages: [pre-commit]

  - repo: local                     # Local hooks
    hooks:
      - id: my-custom-hook
        name: Custom Hook
        entry: ./scripts/check.sh
        language: script
        types: [python]
        stages: [pre-commit]
```

### Available Hooks in Project

#### 1. Trailing Whitespace

```yaml
- id: trailing-whitespace
```

Removes trailing whitespace from files.

**What it does:** Strips spaces/tabs at end of lines
**Languages:** All text files
**Auto-fix:** Yes

#### 2. End of File Fixer

```yaml
- id: end-of-file-fixer
```

Ensures files end with newline.

**What it does:** Adds newline if missing
**Languages:** All text files
**Auto-fix:** Yes

#### 3. Check YAML

```yaml
- id: check-yaml
```

Validates YAML file syntax.

**What it does:** Parses YAML for syntax errors
**Languages:** YAML files
**Auto-fix:** No
**Example error:** Invalid indentation, duplicate keys

#### 4. Check JSON

```yaml
- id: check-json
```

Validates JSON file syntax.

**What it does:** Parses JSON for syntax errors
**Languages:** JSON files
**Auto-fix:** No

#### 5. Check TOML

```yaml
- id: check-toml
```

Validates TOML file syntax.

**What it does:** Parses TOML for syntax errors
**Languages:** TOML files
**Auto-fix:** No

#### 6. Check XML

```yaml
- id: check-xml
```

Validates XML file syntax.

**What it does:** Parses XML for syntax errors
**Languages:** XML files
**Auto-fix:** No

#### 7. Check for Large Files

```yaml
- id: check-added-large-files
  args: ['--maxkb=5000']
```

Prevents committing large files.

**Threshold:** 5MB (5000 KB)
**What it does:** Blocks files larger than limit
**Auto-fix:** No
**Exception:** Binary files that are intentionally large

#### 8. Check for Case Conflicts

```yaml
- id: check-case-conflict
```

Prevents case-only filename conflicts.

**What it does:** Detects `MyFile.md` and `myfile.md`
**Languages:** All files
**Auto-fix:** No
**Why it matters:** Causes issues on case-insensitive filesystems (Windows, macOS)

#### 9. Check for Merge Conflicts

```yaml
- id: check-merge-conflict
```

Detects merge conflict markers.

**What it does:** Finds `<<<<<<<` and `>>>>>>>`
**Auto-fix:** No
**Example:** Incomplete merge resolution

#### 10. Check for Broken Symlinks

```yaml
- id: check-symlinks
```

Validates symlink targets exist.

**What it does:** Ensures symlinks point to valid files
**Auto-fix:** No
**Languages:** All files

#### 11. Detect Private Keys

```yaml
- id: detect-private-key
```

Prevents committing private keys or secrets.

**What it does:** Scans for patterns matching private key markers
**Auto-fix:** No
**Blocked patterns:**

- Private SSH keys and certificates
- AWS credentials and access keys
- API tokens and bearer tokens
- Database passwords and connection strings

#### 12. Mixed Line Ending

```yaml
- id: mixed-line-ending
```

Ensures consistent line endings.

**What it does:** Enforces uniform line endings
**Options:** `--fix=lf` (Unix), `--fix=crlf` (Windows), `--fix=auto`
**Auto-fix:** Yes

## Markdown Linting (markdownlint)

### Configuration File

Location: `.markdownlint.yaml`

### Rule Configuration

#### MD001 - Heading Levels

Headings should increase by one level at a time.

```markdown
# Valid
## Valid
### Valid

# Invalid
### Skipped level
```

#### MD003 - Heading Style

Use consistent heading style (ATX-style).

```markdown
# Good - ATX style
## Even better

# Bad - Setext style underline
======================
```

#### MD004 - Unordered List Marker

Use consistent bullet markers (dash).

```markdown
- Good bullet
- Consistent

* Bad bullet
+ Another bad
```

#### MD008 - Unordered List Indentation

Consistent indentation (2 spaces).

```markdown
- Item 1
  - Nested (2 spaces)
    - Double nested

- Item 2
   - Bad indentation (3 spaces)
```

#### MD009 - Trailing Spaces

Maximum 2 trailing spaces (for line breaks).

```markdown
Line with two spaces  (hard break)
Line with no spaces (soft break)
Line with three spaces   (error)
```

#### MD010 - Hard Tabs

Spaces only (no tabs).

```markdown
- No tabs in indentation
  Only spaces for indentation

✗ No tab characters
```

#### MD013 - Line Length

Maximum 120 characters per line.

```markdown
# Good (under 120 chars)
This is a line under the character limit for readability.

# Bad (over 120 chars)
This is a very long line that exceeds the limit and should be wrapped to
multiple lines for better readability and adherence to standards.
```

**Exceptions:**

- Code blocks (URLs can be long)
- Tables
- Links

#### MD024 - Duplicate Heading

No duplicate headings in document.

```markdown
# Valid Approach

## Section 1
## Section 2
## Section 3

# Invalid Approach

## Duplicate
## Duplicate (error)
```

#### MD025 - Multiple Top-Level Headings

Only one top-level heading (`#`) per file.

```markdown
# Document Title (only one)

## Section 1
## Section 2

✗ # Another Top Level (error)
```

#### MD040 - Fenced Code Blocks

Code blocks must have language specified.

```markdown
# Good
\`\`\`bash
echo "Hello"
\`\`\`

\`\`\`python
print("Hello")
\`\`\`

# Bad (no language)
\`\`\`
echo "Hello"
\`\`\`
```

**Why it matters:**

- Enables syntax highlighting
- Helps readers understand code context
- Use `text` for generic output

### Disabled Rules

#### MD002 - First Heading Level

Why disabled: Flexibility in document structure

#### MD006 - Start Ordered List at Beginning

Why disabled: Allows indented lists

#### MD014 - Dollar Signs in Code Blocks

Why disabled: Shell prompts are common and helpful

#### MD032 - Blank Lines Around Lists

Why disabled: Varies by context

#### MD034 - Bare URLs

Why disabled: Sometimes URLs alone are acceptable

### Running Markdownlint

#### Check Single File

```bash
markdownlint docs/my-guide.md
```

#### Check All Markdown

```bash
markdownlint '**/*.md'
```

#### Fix Common Issues

```bash
markdownlint --fix docs/my-guide.md
```

Auto-fixes:

- Trailing whitespace
- End-of-file newline
- Consistent heading style
- List markers
- Line endings

#### Custom Configuration

```bash
markdownlint -c .markdownlint.yaml docs/
```

## Shell Script Linting (shellcheck)

### Configuration

Location: `.shellcheckrc`

### Common Checks

#### SC2006 - Use `$()` Instead of Backticks

```bash
# Good
result=$(command)

# Bad
result=`command`
```

#### SC2181 - Check Exit Code

```bash
# Good
if ! command; then
  echo "Failed"
fi

# Bad
command
if [ $? -ne 0 ]; then
  echo "Failed"
fi
```

#### SC2086 - Quote Variables

```bash
# Good
find "$directory" -name "*.md"

# Bad (breaks on spaces)
find $directory -name *.md
```

### Running Shellcheck

#### Check Single Script

```bash
shellcheck script.sh
```

#### Check All Scripts

```bash
shellcheck scripts/**/*.sh
```

#### Enable Specific Codes

```bash
shellcheck -S warning script.sh
```

## CMake Formatting (cmake-format)

### Configuration

Location: `.cmake-format.py`

### Standards

- Line length: 80 characters
- Indentation: 2 spaces
- Function calls consistent
- Comments aligned

### Running cmake-format

#### Format Single File

```bash
cmake-format -i CMakeLists.txt
```

#### Format All CMake Files

```bash
find . -name 'CMakeLists.txt' -exec cmake-format -i {} \;
```

#### Check Without Modifying

```bash
cmake-format --check CMakeLists.txt
```

## Python Quality Tools (via Nox)

### Ruff - Linter and Formatter

#### Installation

```bash
pip install ruff
```

#### Check Code

```bash
ruff check .
```

#### Fix Issues

```bash
ruff check --fix .
```

#### Format Code

```bash
ruff format .
```

### Mypy - Type Checking

#### Installation

```bash
pip install mypy
```

#### Type Check

```bash
mypy python/ai_how
```

#### With Configuration

```bash
mypy --config-file pyproject.toml python/ai_how
```

### Integration with Pre-commit

Python tools run through Makefile targets:

```bash
make lint-ai-how      # Ruff check
make format-ai-how    # Ruff format
make test-ai-how      # Pytest + mypy
```

## Commit Message Validation

### Conventional Commits Standard

Format: `<type>(<scope>): <subject>`

```text
docs(docker): add development workflow guide
feat(cli): implement new command
fix(build): resolve CMake error
refactor(ansible): simplify role structure
test(framework): add integration tests
```

### Configured Scopes

Allowed scopes (components):

- `docker` - Docker development environment
- `cli` - Python CLI (ai-how)
- `build` - Build system (CMake, Makefile)
- `test` - Testing framework
- `ci` - CI/CD pipeline
- `docs` - Documentation
- `ansible` - Ansible configuration
- `packer` - Packer image building
- `container` - Container definitions
- `config` - Configuration files
- `components` - Component documentation
- `core` - Core project files

### Configured Types

- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Code refactoring (no feature change)
- `test` - Testing additions/changes
- `docs` - Documentation
- `chore` - Build system, dependencies
- `ci` - CI/CD changes
- `perf` - Performance improvements
- `style` - Code formatting
- `revert` - Revert previous commit

### Validation Rules

- Type must be one of above
- Scope optional but recommended
- Subject lowercase start
- No period at end
- Maximum 72 characters

### Examples

**Valid:**

```text
feat(cli): add cluster deployment command
fix(build): resolve BeeGFS compilation error
docs(components): update CMake documentation
test(framework): add SSH connection tests
ci: update GitHub Actions workflow
```

**Invalid:**

```text
Added new feature          (no type)
FEATs(cli): Added feature  (wrong format)
feat(cli): Add feature.    (period, capitalized)
feat(cli): This is a very long commit message that exceeds seventy-two characters limit
```

## General File Checks

### Trailing Whitespace

**Check:** Removes spaces/tabs at end of lines
**Auto-fix:** Yes
**Affected:** All text files

### End-of-File Fixer

**Check:** Ensures files end with newline
**Auto-fix:** Yes
**Affected:** All text files except binary

### YAML/JSON/TOML Validation

**Check:** Syntax validation
**Auto-fix:** No (requires manual fix)
**Error types:** Invalid syntax, unclosed braces, wrong types

### Large File Detection

**Check:** Blocks files >5MB
**Auto-fix:** No
**Solution:** Use Git LFS for large files

```bash
# Setup Git LFS
git lfs install
git lfs track "*.bin"
```

## Troubleshooting

### Hook Failures

#### "Hook Failed: trailing-whitespace"

**Problem:** File has trailing spaces

**Solution:**

```bash
# Fix automatically
pre-commit run trailing-whitespace --all-files

# Or manually remove trailing spaces in your editor
```

#### "Hook Failed: markdownlint"

**Problem:** Markdown style violation

**Common issues:**

```bash
# Line too long (>120 chars)
# Solution: Wrap long lines

# Missing code block language
# Solution: Add language after backticks: ```bash

# Wrong list marker
# Solution: Use only dashes (-) for bullets

# Duplicate heading
# Solution: Use unique heading titles
```

**Check violations:**

```bash
markdownlint docs/file.md
```

#### "Hook Failed: shellcheck"

**Problem:** Shell script issue

**Solutions:**

```bash
# Check specific script
shellcheck script.sh

# Fix common issues
shellcheck -S suggestion script.sh

# Disable specific checks
# Add comment: # shellcheck disable=SC2086
```

#### "Hook Failed: CMake Format"

**Problem:** CMake formatting issue

**Solution:**

```bash
# Reformat file
cmake-format -i CMakeLists.txt

# Check without modifying
cmake-format --check CMakeLists.txt
```

### Validation Error Resolution

#### Line Length Exceeded

**Error:** `MD013/line-too-long`

**Fix:** Wrap line to <120 characters

```markdown
# Bad (134 characters)
This is a very long line that exceeds the maximum character limit and should be wrapped to multiple lines for consistency.

# Good (under 120 chars)
This is a long line that exceeds the limit and should be wrapped to multiple
lines for consistency with project standards.
```

#### Missing Code Language

**Error:** `MD040/fenced-code-language`

**Fix:** Add language to code fence

```text
# Bad - markdown example
` ` `
echo "hello"
` ` `

# Good - markdown example
` ` `bash
echo "hello"
` ` `
```

#### Case Conflict

**Error:** `check-case-conflict`

**Fix:** Rename file to consistent case

```bash
# Bad (both exist)
MyFile.md
myfile.md

# Good (choose one)
mv myfile.md my-file.md
```

### Editor Integration

#### VS Code

Install extensions:

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "[markdown]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[python]": {
    "editor.defaultFormatter": "charliermarsh.ruff"
  }
}
```

#### Vim

Configure for pre-commit:

```vim
" Run pre-commit on save
autocmd BufWritePost *.md execute '!pre-commit run --files %'
```

#### Neovim (nvim)

Install LSP and formatter:

```lua
require('conform').setup({
  formatters_by_ft = {
    markdown = { 'markdownlint' },
    python = { 'ruff' },
    bash = { 'shellcheck' },
  },
})
```

### Performance Optimization

#### Slow Pre-commit Runs

**Cause:** Too many files checked

**Solution:**

```bash
# Check only changed files (default)
pre-commit run

# Skip hooks you don't need
# Edit .pre-commit-config.yaml and remove expensive hooks

# Use skip option
pre-commit run --skip markdownlint

# Exclude files
pre-commit run --exclude 'venv|.nox'
```

#### Skip Hooks for Specific Commit

```bash
# Skip pre-commit hooks (use carefully!)
git commit --no-verify

# Skip commit-msg hook only
git commit --no-verify
```

## Best Practices

### When to Add New Checks

**Good reasons:**

- Catch common bugs
- Enforce consistency
- Prevent security issues
- Improve code quality

**Bad reasons:**

- Too strict for developers
- Slows down workflow
- Conflicts with other tools
- Requires too many exceptions

### How to Exclude Files Properly

```yaml
# Exclude specific files
exclude: |
  (?x)^(
    tests/fixtures/|
    vendor/|
    docs/old/
  )

# Exclude by extension
exclude_types: [python-compiled]

# Language-specific exclusion
files: '\.py$'
```

### Balancing Strictness vs Usability

```yaml
# Too strict (too many failures)
- id: markdownlint
  args: ['--strict']

# Right balance (catches real issues)
- id: markdownlint
  args: ['--config', '.markdownlint.yaml']

# Too lenient (misses issues)
- repo: skip
  skip: [markdownlint]
```

### CI/CD Integration Patterns

#### GitHub Actions

```yaml
- name: Run pre-commit hooks
  uses: pre-commit/action@v3.0.0
  with:
    extra_args: --all-files

- name: Check code quality
  run: |
    make lint-ai-how
    make test-ai-how
```

#### Local Development

```bash
# Install hooks (once)
pre-commit install

# Auto-check on commit (automatic)
git commit -m "my changes"

# Manual check when needed
pre-commit run --all-files
```

## Related Documentation

- **Build System:** `docs/architecture/build-system.md`
- **CI/CD Pipeline:** `docs/development/ci-cd-pipeline.md`
- **Documentation Build:** `docs/components/documentation-build-system.md`
- **GitHub Actions:** `docs/development/github-actions-guide.md`

## References

- Pre-commit Framework: https://pre-commit.com/
- Markdownlint: https://github.com/DavidAnson/markdownlint
- Shellcheck: https://www.shellcheck.net/
- CMake Format: https://cmake-format.readthedocs.io/
- Ruff: https://github.com/astral-sh/ruff
- Mypy: https://www.mypy-lang.org/
- Conventional Commits: https://www.conventionalcommits.org/
