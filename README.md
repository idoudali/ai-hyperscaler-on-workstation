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

### Writing New Test Frameworks

This project uses a standardized CLI API for test frameworks. When creating new test frameworks, follow the
established patterns to ensure consistency and maintainability.

#### Test Framework CLI Standard

All test framework scripts (`test-*-framework.sh`) must implement a standardized CLI interface that provides:

**Required Commands:**

- `e2e` or `end-to-end` - Complete end-to-end test with automatic cleanup (default)
- `start-cluster` - Start the test cluster independently (keeps cluster running)
- `stop-cluster` - Stop and destroy the test cluster
- `deploy-ansible` - Deploy via Ansible on running cluster (assumes cluster exists)
- `run-tests` - Run test suite on deployed cluster (assumes deployment complete)
- `list-tests` - List all available individual test scripts
- `run-test NAME` - Run a specific individual test by name
- `status` - Show current cluster status and configuration
- `help` - Display comprehensive usage information

**Required Options:**

- `-h, --help` - Show help message with examples
- `-v, --verbose` - Enable verbose output for debugging
- `--no-cleanup` - Skip cleanup after test completion (for debugging)
- `--interactive` - Enable interactive prompts for cleanup/confirmation

#### Quick Start: Create a New Test Framework

**1. Use the Template Structure:**

```bash
#!/bin/bash
#
# New Test Framework - Task XXX
# Description of what this test framework validates
#

set -euo pipefail

# Framework configuration
FRAMEWORK_NAME="Your Test Framework"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Validate PROJECT_ROOT
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "Error: Invalid PROJECT_ROOT directory: $PROJECT_ROOT"
    exit 1
fi

# Source shared utilities (IMPORTANT: these provide most functionality)
UTILS_DIR="$PROJECT_ROOT/tests/test-infra/utils"
for util in log-utils.sh cluster-utils.sh test-framework-utils.sh ansible-utils.sh; do
    if [[ ! -f "$UTILS_DIR/$util" ]]; then
        echo "Error: Shared utility not found: $UTILS_DIR/$util"
        exit 1
    fi
    # shellcheck source=./test-infra/utils/
    source "$UTILS_DIR/$util"
done

# Test-specific configuration
TEST_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/test-your-component.yaml"
TEST_SCRIPTS_DIR="$PROJECT_ROOT/tests/suites/your-component"
TARGET_VM_PATTERN="controller"  # or "compute" or other pattern
MASTER_TEST_SCRIPT="run-your-tests.sh"

# ... rest of framework implementation
```

**2. Implement Help Function:**

```bash
show_help() {
    cat << EOF
Your Test Framework - Task XXX Validation

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    e2e, end-to-end   Run complete end-to-end test with cleanup (default)
    start-cluster     Start the HPC cluster independently
    stop-cluster      Stop and destroy the HPC cluster
    deploy-ansible    Deploy your component via Ansible
    run-tests         Run tests on deployed cluster
    list-tests        List all available individual test scripts
    run-test NAME     Run a specific individual test by name
    status            Show cluster status
    help              Show this help message

OPTIONS:
    -h, --help        Show this help message
    -v, --verbose     Enable verbose output
    --no-cleanup      Skip cleanup after test completion
    --interactive     Enable interactive cleanup prompts

EXAMPLES:
    # Run complete end-to-end test (recommended for CI/CD)
    $0
    $0 e2e

    # Modular workflow for debugging
    $0 start-cluster
    $0 deploy-ansible
    $0 run-tests
    $0 list-tests
    $0 run-test check-specific-component.sh
    $0 stop-cluster
EOF
}
```

**3. Use Shared Utility Functions:**

The shared utilities in `tests/test-infra/utils/` provide most of the required functionality:

**From `ansible-utils.sh`:**

- `setup_virtual_environment()` - Setup Ansible virtual environment
- `activate_virtual_environment()` - Activate venv and export paths
- `deploy_ansible_full_workflow()` - Complete Ansible deployment

**From `cluster-utils.sh`:**

- `start_cluster_interactive()` - Start cluster with optional confirmation
- `stop_cluster_interactive()` - Stop cluster with optional confirmation
- `show_cluster_status()` - Display cluster status
- `check_cluster_status()` - Check if cluster is running

**From `test-framework-utils.sh`:**

- `list_tests_in_directory()` - List all test scripts with descriptions
- `execute_single_test_by_name()` - Run a specific test
- `run_master_tests()` - Execute master test script
- `run_test_suite()` - Run all tests with aggregation

**4. Implement Required Functions:**

Most functions can use the shared utilities:

```bash
# Parse arguments (standard pattern)
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -v|--verbose) export VERBOSE=true; shift ;;
            --no-cleanup) export CLEANUP_REQUIRED=false; shift ;;
            --interactive) INTERACTIVE=true; shift ;;
            e2e|end-to-end|start-cluster|stop-cluster|deploy-ansible|run-tests|list-tests|status|help)
                COMMAND="$1"; shift ;;
            run-test)
                COMMAND="run-test"
                TEST_TO_RUN="$2"
                shift 2 ;;
            *) echo "Error: Unknown option '$1'"; exit 1 ;;
        esac
    done
}

# Start cluster (uses shared utilities)
start_cluster() {
    start_cluster_interactive "$TEST_CONFIG" "$INTERACTIVE"
}

# Stop cluster (uses shared utilities)
stop_cluster() {
    stop_cluster_interactive "$TEST_CONFIG" "$INTERACTIVE"
}

# Deploy Ansible (uses shared utilities)
deploy_ansible() {
    deploy_ansible_full_workflow "$TEST_CONFIG" "$TARGET_VM_PATTERN"
}

# Run tests (uses shared utilities)
run_tests() {
    run_master_tests "$TEST_SCRIPTS_DIR" "$MASTER_TEST_SCRIPT"
}

# List tests (uses shared utilities)
list_tests() {
    list_tests_in_directory "$TEST_SCRIPTS_DIR"
}

# Run single test (uses shared utilities)
run_single_test() {
    local test_name="$1"
    execute_single_test_by_name "$TEST_SCRIPTS_DIR" "$test_name"
}

# Show status (uses shared utilities)
show_status() {
    show_cluster_status "$TEST_CONFIG"
}
```

#### Directory Structure for New Tests

```text
tests/
├── test-your-component-framework.sh       # Main test framework script
├── test-infra/
│   ├── configs/
│   │   └── test-your-component.yaml       # Test cluster configuration
│   └── utils/                             # Shared utilities (already exist)
└── suites/
    └── your-component/                    # Test suite directory
        ├── run-your-tests.sh              # Master test script
        ├── check-installation.sh          # Individual tests
        ├── check-functionality.sh
        └── check-integration.sh
```

#### Best Practices

1. **Use Shared Utilities**: Don't reinvent functionality - use `ansible-utils.sh`, `cluster-utils.sh`, and
   `test-framework-utils.sh`
2. **Follow Naming Conventions**: `test-*-framework.sh` for main scripts, `check-*.sh` or `test-*.sh` for
   individual tests
3. **Make `e2e` the Default**: When no command is specified, run the complete end-to-end test
4. **Include Comprehensive Help**: Users should understand all commands and options from `--help`
5. **Support Modular Execution**: Enable users to run individual phases for debugging
6. **Add Test Descriptions**: Include `# Test: Description` comments in individual test scripts
7. **Log Everything**: Use `log()`, `log_success()`, `log_error()`, `log_warning()` from `log-utils.sh`
8. **Handle Cleanup**: Support `--no-cleanup` for debugging but cleanup by default
9. **Enable Interactive Mode**: Support `--interactive` for manual confirmation during debugging

#### Reference Implementations

Study these frameworks as examples:

- **Best Practice**: `tests/test-dcgm-monitoring-framework.sh` - Reference implementation with all features
- **Comprehensive**: `tests/test-container-registry-framework.sh` - Complex multi-phase testing
- **Simple**: `tests/test-slurm-controller-framework.sh` - Clean, straightforward implementation

#### Code Reduction

By using shared utilities, new test frameworks require only ~300-350 lines instead of ~600 lines:

- **Without shared utilities**: ~600 lines per framework
- **With shared utilities**: ~300-350 lines per framework
- **Savings**: 40-50% code reduction + consistent behavior

#### Testing Your New Framework

```bash
# Basic validation
./test-your-component-framework.sh --help

# Test individual commands
./test-your-component-framework.sh start-cluster
./test-your-component-framework.sh status
./test-your-component-framework.sh list-tests
./test-your-component-framework.sh stop-cluster

# Full end-to-end test
./test-your-component-framework.sh e2e
```

#### Documentation Requirements

When creating a new test framework, update:

1. `tests/README.md` - Add section documenting your framework
2. Framework help message - Comprehensive usage examples
3. Test scripts - Include `# Test: Description` comments

## Project Structure

Understanding the project layout helps navigate the codebase effectively:

```text
ai-hyperscaler-on-workskation/
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
