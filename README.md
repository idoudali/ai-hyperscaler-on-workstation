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

1.  **Install required tools:**

    ```bash
    pip install --user commitizen pre-commit
    ```

2.  **Install the git hooks:**

    ```bash
    pre-commit install --hook-type pre-commit --hook-type commit-msg
    ```

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
