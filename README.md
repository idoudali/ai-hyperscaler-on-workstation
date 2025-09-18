# Hyperscaler on Workstation

An automated approach to emulating advanced AI infrastructure on a single
workstation using KVM, GPU partitioning, and dual-stack orchestration.

## System Requirements

### Ubuntu/Debian (Recommended Platform)

For Ubuntu/Debian systems, use the automated setup script to install all
required dependencies. This is a best effort script to capture needed
dependencies. For the build dependencies see the `docker/Dockerfile` :

```bash
# Install all dependencies automatically
./scripts/setup-host-dependencies.sh

# Show all available options and how to selectively install some packages
./scripts/setup-host-dependencies.sh --help
```

The script installs:

- build tools
- Python development environment,
- Docker CE
- virtualization tools (libvirt, QEMU)
- and modern Python tooling (uv)

## Quick Start

This project uses a Makefile-based workflow with Docker containers for
consistent development environments.

### 1. Build Development Environment

```bash
# Build the Docker development image
make build-docker

# Create Python virtual environment and install all dependencies
make venv-create
```

### 2. Install Development Tools

Enable pre-commit in your repo. The below target installs the
[pre-commit](https://pre-commit.com/) tool in the above Python venv. You can
install pre-commit manually in your system and invoke it directly.

```bash
# Install pre-commit hooks
make pre-commit-install
```

### 3. Start Development

Setup commitizen

```bash
./scripts/setup-commitizen.sh
```

Setup [hadolint](https://github.com/hadolint/hadolint)

Setup [shellcheck](https://github.com/koalaman/shellcheck)

To build the Packer images you can try the following

```bash
# Enter interactive development container
make shell-docker

# Or run commands in the container
make run-docker COMMAND="your-command-here"

# Configure CMake build system (if needed)
make config
```

The above creates the `build` folder where we can execute ninja to build the
different build targets that we support.

```bash
cd build

# get the list of targets
ninja help | grep build | grep image

# Selecte the Packer image to build like the below
ninja build-hpc-compute-image
```

## Development Workflow

After you have staged your changes you need to run `pre-commit` and resolve any
linting errors.

### Pre-commit Hooks

This project uses the following pre-commit hooks:

- **General formatting**: trailing whitespace, end-of-file, YAML/JSON/TOML/XML
  validation
- **Security checks**: detect private keys, large files (>10MB)
- **Markdown linting**: with project-specific rules
- **Shell script linting**: using shellcheck with relaxed rules
- **Dockerfile linting**: using hadolint with common rules ignored
- **Commit message validation**: enforcing Conventional Commits format

**Running pre-commit hooks:**

```bash
# Run hooks on staged files
make pre-commit-run

# Run hooks on all files
make pre-commit-run-all
```

### AI-HOW Python Package Development

The project includes a Python CLI package that can be developed using Nox-based
workflows. Use the below targets to help with development:

```bash
# Run tests
make test-ai-how

# Run linting
make lint-ai-how

# Format code
make format-ai-how

# Build documentation
make docs-ai-how

# Clean build artifacts
make clean-ai-how
```

### Docker Development Environment

For consistent development environments:

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

### Commit Message Format

This project follows [Conventional
Commits](https://www.conventionalcommits.org/). Use the following format:

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

**Available types:** feat, fix, docs, style, refactor, perf, test, build, ci,
chore, revert  
**Available scopes:** ansible, terraform, packer, slurm, k8s, gpu, docs, ci,
scripts

For more details, please refer to the [Conventional Commits
specification](https://www.conventionalcommits.org/) and [commitizen
documentation](https://commitizen-tools.github.io/commitizen/).

## Python CLI (ai-how)

### Using the Makefile Workflow

The recommended approach uses the Makefile which handles virtual environment
creation and dependency management:

```bash
# Create virtual environment and install dependencies
make venv-create

# Activate the virtual environment
source .venv/bin/activate

# Use the CLI
ai-how --help
```

### Development Commands

```bash
# Run via module if needed
python -m ai_how.cli --help

# Run tests, linting, and formatting (via Makefile)
make test-ai-how
make lint-ai-how  
make format-ai-how
```

## Testing Framework

The project includes a comprehensive test suite for validating the entire HPC
infrastructure. Tests are located in the `tests/` directory with their own
Makefile.

### Core Test Suites

```bash
# Navigate to tests directory
cd tests/

# Run core infrastructure tests (recommended for CI/CD)
make test

# Run comprehensive test suite (includes builds and all validation)
make test-all

# Run specific test categories
make test-base-images          # Docker base image builds
make test-container-runtime    # Container runtime validation
make test-slurm-controller     # SLURM installation and configuration
make test-ansible-roles        # Ansible role validation
make test-integration          # End-to-end integration tests
make test-ai-how              # AI-HOW CLI validation
make test-pcie-validation     # PCIe passthrough validation
make test-infrastructure      # VM lifecycle, networking, SSH
make test-configuration       # YAML schema, network validation
```

### Quick Testing Options

```bash
# Fast validation (no builds)
make test-quick

# Verbose output for debugging
make test-verbose

# Stop on first error
make test-fail-fast

# Test specific Ansible role
make test-role ROLE=slurm-controller
```

### Pre-commit and Linting Tests

```bash
# Run all pre-commit hooks
make test-precommit

# Run only Ansible syntax/lint validation
make test-ansible-syntax

# Clean test artifacts
make clean
```

### Integration with Main Makefile

You can also run Python package tests from the root directory:

```bash
# From project root
make test-ai-how    # Nox-based Python testing
make lint-ai-how    # Python code linting
make format-ai-how  # Python code formatting
```

## Project Structure

Understanding the project layout helps navigate the codebase effectively:

```text
pharos.ai-hyperscaler-on-workskation/
├── ansible/                    # Ansible playbooks and roles
│   ├── roles/                  # Custom roles for SLURM, GPU, containers
│   ├── playbooks/              # Infrastructure deployment playbooks
│   └── collections/            # External Ansible collections
├── docker/                     # Development environment container
│   ├── Dockerfile              # Multi-stage development image
│   ├── entrypoint.sh          # Container initialization script
│   └── requirements.txt        # Python dependencies for container
├── packer/                     # VM image building configurations
│   ├── hpc-base/              # Base HPC image templates
│   ├── hpc-controller/        # SLURM controller image templates
│   └── hpc-compute/           # SLURM compute node image templates
├── scripts/                    # Utility and automation scripts
│   ├── run-in-dev-container.sh # Development container execution wrapper
│   ├── setup-commitizen.sh    # Development tools setup script
│   └── system-checks/         # System prerequisite validation scripts
├── tests/                      # Comprehensive testing framework
│   ├── Makefile               # Testing workflow automation
│   ├── suites/                # Organized test suites by category
│   └── test-infra/            # Testing infrastructure and utilities
├── python/ai_how/             # Python CLI package
│   ├── ai_how/                # Main package source
│   ├── pyproject.toml         # Package configuration
│   └── noxfile.py            # Development automation
├── docs/                      # Documentation and design documents
└── Makefile                  # Main development workflow automation
```

### Key Configuration Files

- **`Makefile`**: Main development workflow automation
- **`docker/Dockerfile`**: Development environment specification
- **`docker/requirements.txt`**: Python dependencies for development container
- **`ansible/requirements.txt`**: Ansible dependencies
- **`ansible/collections/requirements.yml`**: Required Ansible collections
- **`.pre-commit-config.yaml`**: Code quality and linting rules
- **`pyproject.toml`**: Python package configuration with commitizen settings

### Important Scripts

- **`scripts/run-in-dev-container.sh`**: Wrapper for executing commands in
  development container
- **`scripts/setup-commitizen.sh`**: Legacy setup script for development tools
- **`scripts/system-checks/check_prereqs.sh`**: System prerequisite validation
- **`scripts/system-checks/gpu_inventory.sh`**: GPU hardware inventory and
  validation
- **`tests/run_all_tests.sh`**: Execute comprehensive test suite
- **`docker/entrypoint.sh`**: Docker container initialization and user setup
