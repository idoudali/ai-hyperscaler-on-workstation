# Project Scripts

**Status:** Complete
**Last Updated:** 2025-10-20

This directory contains utility scripts for project setup, testing, development, and system
validation. Scripts are organized by function and include comprehensive documentation.

## Overview

Scripts in this directory support the complete development lifecycle:

- **Setup & Installation**: Project initialization and dependency management
- **System Validation**: Cluster node health checks and system validation
- **Development**: Container management and development environment setup
- **Testing**: Automated test execution and validation

## Directory Structure

```text
scripts/
├── README.md                          # This file
├── setup-commitizen.sh               # Commitizen configuration setup
├── setup-host-dependencies.sh        # Host system dependency installation
├── setup-container-tools.sh          # Container tool installation (if exists)
├── run-in-dev-container.sh          # Development container execution
├── run_all_tests.sh                 # Complete test suite runner
├── cleanup_all.sh                   # Project cleanup script
├── generate-ansible-inventory.py    # Ansible inventory generation from config
├── system-checks/                   # System validation scripts
│   ├── README.md                    # System checks documentation
│   └── *.sh                         # Individual system check scripts
└── experiments/                     # Experimental scripts directory
    └── (experimental tools)
```

## Available Scripts

### Setup and Installation

#### setup-host-dependencies.sh

Installs all required system dependencies on the host machine.

**Usage:**

```bash
./scripts/setup-host-dependencies.sh
```

**Installs:**

- Development tools (gcc, g++, make, cmake)
- Python environment (Python 3.11+, pip, venv)
- Package managers (apt-get, snap if needed)
- Container tools (Docker, Apptainer/Singularity)
- Build system dependencies
- Documentation tools

**Platform Support:**

- Ubuntu 22.04 (Jammy)
- Ubuntu 20.04 (Focal)
- Debian 12 (Bookworm)
- Debian 11 (Bullseye)

**Interactive Mode:**

The script provides prompts for:

- Skipping already installed tools
- Optional vs. required components
- Tool-specific configuration

#### setup-commitizen.sh

Configures Commitizen for consistent commit message formatting.

**Usage:**

```bash
./scripts/setup-commitizen.sh
```

**Configures:**

- Commitizen for commit messages
- Pre-commit hooks
- Commit message validation
- Interactive commit interface (cz commit)

### Development

#### run-in-dev-container.sh

Runs commands in the development container environment.

**Usage:**

```bash
./scripts/run-in-dev-container.sh [command]
```

**Examples:**

```bash
# Interactive shell
./scripts/run-in-dev-container.sh bash

# Run specific command
./scripts/run-in-dev-container.sh make docs-build

# Run Python script
./scripts/run-in-dev-container.sh python myScript.py
```

**Features:**

- Automatic container image detection
- Volume mounting of project directory
- Environment variable forwarding
- GPU support detection
- Networking configuration

### Testing and Validation

#### run_all_tests.sh

Executes the complete test suite including unit tests, integration tests, and system validation.

**Usage:**

```bash
./scripts/run_all_tests.sh
```

**Runs:**

- Unit tests
- Integration tests
- System check validation
- Documentation build verification
- Code quality checks

**Output:**

- Summary report
- Test result details
- Coverage report (if applicable)
- Failure details with suggestions

#### System Checks (system-checks/)

Comprehensive system validation scripts. See [system-checks/README.md](system-checks/README.md)
for detailed information.

**Quick usage:**

```bash
# Run all system checks
./scripts/system-checks/run-all-checks.sh

# Run specific check
./scripts/system-checks/check-gpu-configuration.sh
```

### Utility Scripts

#### generate-ansible-inventory.py

Generates Ansible inventory from cluster configuration YAML.

**Usage:**

```bash
python3 scripts/generate-ansible-inventory.py [config-file] [output-file]
```

**Arguments:**

- `config-file`: Path to cluster configuration (default: config/cluster.yaml)
- `output-file`: Output inventory path (default: ansible/inventories/generated/hosts.yml)

**Features:**

- Automatic GPU detection from PCIe configuration
- GRES configuration generation
- Host group organization
- Variable assignment from config
- Validation and error checking

**Example:**

```bash
python3 scripts/generate-ansible-inventory.py \
  config/example-multi-gpu-clusters.yaml \
  ansible/inventories/hpc/hosts.yml
```

#### cleanup_all.sh

Removes all generated files, caches, and build artifacts.

**Usage:**

```bash
./scripts/cleanup_all.sh
```

**Removes:**

- Build directories
- Cache files
- Python bytecode and virtual environments
- Generated documentation
- Container build artifacts
- Test results

**Warning:** This script removes data. Use with caution in production environments.

## Scripting Standards

All scripts in this directory follow these standards:

### Header Documentation

Each script includes a header comment with:

```bash
#!/bin/bash
# Script description in one sentence

# Longer description explaining purpose, usage, and examples
#
# Usage: ./script-name.sh [args]
# Example: ./script-name.sh arg1 arg2
```

### Error Handling

Scripts implement proper error handling:

- Check command success: `command || exit 1`
- Set error flags: `set -e` (exit on error)
- Trap errors: `trap cleanup EXIT`
- Provide clear error messages

### Logging

Scripts provide logging at multiple levels:

```bash
# Info messages
echo "[INFO] Operation description"

# Warning messages
echo "[WARNING] Potentially risky operation"

# Error messages
echo "[ERROR] Operation failed" >&2
```

### Platform Detection

Scripts automatically detect and handle different operating systems:

```bash
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux-specific commands
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS-specific commands
fi
```

## Usage Guidelines

### Running Scripts

All scripts should be run from the project root:

```bash
./scripts/script-name.sh
```

Or from any directory using absolute path:

```bash
/path/to/project/scripts/script-name.sh
```

### Development Workflow

Typical development workflow:

```bash
# 1. Setup dependencies (once)
./scripts/setup-host-dependencies.sh

# 2. Setup commitizen (once)
./scripts/setup-commitizen.sh

# 3. Make changes to code

# 4. Run tests
./scripts/run_all_tests.sh

# 5. Commit changes (uses commitizen)
cz commit

# 6. Run development container
./scripts/run-in-dev-container.sh bash
```

### CI/CD Integration

Scripts can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Install dependencies
  run: ./scripts/setup-host-dependencies.sh

- name: Run tests
  run: ./scripts/run_all_tests.sh

- name: System validation
  run: ./scripts/system-checks/run-all-checks.sh
```

## Troubleshooting

### Script Not Executable

Make script executable:

```bash
chmod +x scripts/script-name.sh
```

### Permission Denied

Some scripts require sudo:

```bash
# Usually only for setup scripts
sudo ./scripts/setup-host-dependencies.sh
```

### Dependencies Not Found

Run setup script first:

```bash
./scripts/setup-host-dependencies.sh
```

### Container Issues

Verify Docker/Apptainer is installed and running:

```bash
docker --version
apptainer --version

# Run system checks
./scripts/system-checks/check-container-runtime.sh
```

## Contributing

When adding new scripts:

1. Follow the naming convention: `lowercase-with-dashes.sh`
2. Include comprehensive header comments
3. Implement error handling
4. Add logging for important operations
5. Update this README with script documentation
6. Test script execution
7. Ensure proper permissions: `chmod +x scripts/script-name.sh`

## Quick Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| setup-host-dependencies.sh | Install system dependencies | Run once during setup |
| setup-commitizen.sh | Configure commit conventions | Run once during setup |
| run-in-dev-container.sh | Execute commands in dev container | Use for development |
| run_all_tests.sh | Run complete test suite | Use before commits |
| cleanup_all.sh | Remove generated artifacts | Use for cleanup |
| generate-ansible-inventory.py | Generate Ansible inventory | Use for cluster setup |
| system-checks/* | Validate system configuration | Use for verification |

## See Also

- **[system-checks/README.md](system-checks/README.md)** - System validation scripts
- **[../Makefile](../Makefile)** - Build system (invokes some scripts)
- **[../README.md](../README.md)** - Project overview
- **[../AI-AGENT-GUIDE.md](../AI-AGENT-GUIDE.md)** - AI agent development guide
