# Hyperscaler on Workstation

An automated approach to emulating advanced AI infrastructure on a single workstation using KVM,
GPU partitioning, and dual-stack orchestration.

## Quick Start

This project uses [pre-commit](https://pre-commit.com) for code quality
and [commitizen](https://commitizen-tools.github.io/commitizen/) for standardized commit messages.

### Automated Setup

Run the setup script to install all required tools:

```bash
./scripts/setup-commitizen.sh
```

### Manual Setup

If you prefer manual setup:

1.  **Install Python tools:**

    ```bash
    pip install --user commitizen pre-commit
    ```

2.  **Install hadolint (Dockerfile linter):**

    **On Ubuntu/Debian:**

    ```bash
    wget -O /bin/hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
    chmod +x /bin/hadolint
    ```

    **For other platforms:** See [hadolint installation guide](https://github.com/hadolint/hadolint#install)

3.  **Install shellcheck (shell script linter):**

    **On Ubuntu/Debian:**

    ```bash
    sudo apt-get install shellcheck
    ```

    **On macOS:**

    ```bash
    brew install shellcheck
    ```

    **On other Linux distributions:**

    ```bash
    # For RHEL/CentOS/Fedora
    sudo dnf install ShellCheck
    ```

4.  **Install the git hooks:**

    ```bash
    pre-commit install --hook-type pre-commit --hook-type commit-msg
    ```

### Pre-commit Hooks Overview

This project uses the following pre-commit hooks:

- **General formatting**: trailing whitespace, end-of-file, YAML/JSON/TOML/XML validation
- **Security checks**: detect private keys, large files (>10MB)
- **Markdown linting**: with project-specific rules
- **Shell script linting**: using shellcheck with relaxed rules
- **Dockerfile linting**: using hadolint with common rules ignored
- **Commit message validation**: enforcing Conventional Commits format

### Commit Message Format

This project follows [Conventional Commits](https://www.conventionalcommits.org/). Use the following format:

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

**Available types:** feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert  
**Available scopes:** ansible, terraform, packer, slurm, k8s, gpu, docs, ci, scripts

For more details, please refer to the [Conventional Commits specification](https://www.conventionalcommits.org/)
and [commitizen documentation](https://commitizen-tools.github.io/commitizen/).

## Python CLI (ai-how)

Install locally in a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -e ./python

# usage
ai-how --help
```

Run via module if needed:

```bash
python -m ai_how.cli --help
```
