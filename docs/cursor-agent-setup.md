# Cursor Agent Configuration for Pharos AI Hyperscaler Project

This document explains how to configure and use the Cursor agent with this project's Docker-based
development environment and CMake build system.

## Overview

This project uses:

- **Development Container**: Docker-based isolated environment
- **Build System**: CMake with Ninja generator
- **Image Building**: Packer for VM image creation
- **Container Script**: `./scripts/run-in-dev-container.sh`

## Quick Start for Cursor Agent

### 1. Initial Setup

```bash
# Build the development container
make build-docker

# Configure CMake (always use this)
make config

# Verify setup
make run-docker COMMAND="cmake --build build --target help"
```

### 2. Common Build Commands

#### Build Commands

```bash
# Build all targets
make run-docker COMMAND="cmake --build build"

# Build specific target
make run-docker COMMAND="cmake --build build --target <target-name>"

# List available targets
make run-docker COMMAND="cmake --build build --target help"
```

#### Packer Image Builds

```bash
# Build specific Packer targets (after CMake configuration)
make run-docker COMMAND="cmake --build build --target <packer-target-name>"

# List available Packer targets
make run-docker COMMAND="cmake --build build --target help"
```

## Configuration Files

### 1. `.cursor/rules/always/dev-container-build.mdc`

Contains instructions for the Cursor agent on how to:

- Use the development container for all builds
- Always use Ninja generator with CMake
- Use the correct build directory (`build/`)
- Handle file permissions properly

### 2. `.vscode/settings.json`

VS Code configuration that:

- Sets CMake to use Ninja generator
- Configures build directory as `build/`
- Provides pre-configured tasks for common operations
- Sets up terminal profiles for container usage

### 3. `CMakePresets.json`

Standardized CMake presets for:

- Default (Release) configuration
- Debug configuration
- Container-optimized configuration

### 4. `Makefile`

Core targets for:

- Docker container management
- CMake configuration
- Container-based command execution

## Agent Instructions

When working with this project, the Cursor agent should:

### Always Use Container

```bash
# ✅ Correct - Use container
make run-docker COMMAND="cmake --build build --target <target>"

# ❌ Wrong - Direct host execution
cmake --build build --target <target>
```

### Always Use Ninja Generator

```bash
# ✅ Correct - Ninja generator
make config

# ❌ Wrong - Other generators
cmake -G Unix Makefiles -S . -B build
```

### Use Standard Build Directory

```bash
# ✅ Correct - Standard build directory
make config  # Creates build/
make run-docker COMMAND="cmake --build build"  # Uses build/

# ❌ Wrong - Custom directories
cmake -S . -B custom-build
```

## Available Make Targets

### Docker Environment

- `make build-docker` - Build the development Docker image
- `make shell-docker` - Start an interactive shell in the container
- `make run-docker COMMAND="..."` - Run a command in the container
- `make clean-docker` - Remove Docker images and containers

### Build Configuration

- `make config` - Configure CMake with Ninja generator

### Python Environment

- `make venv-create` - Create virtual environment and install dependencies
- `make pre-commit-install` - Install pre-commit hooks
- `make pre-commit-run` - Run pre-commit hooks on staged files
- `make pre-commit-run-all` - Run pre-commit hooks on all files

### Documentation

- `make docs-build` - Build the documentation site
- `make docs-serve` - Serve documentation locally
- `make docs-clean` - Clean documentation build artifacts

### AI-HOW Package

- `make test-ai-how` - Run tests for the ai-how package
- `make lint-ai-how` - Run linting for the ai-how package
- `make format-ai-how` - Format the code for the ai-how package
- `make docs-ai-how` - Build documentation for the ai-how package
- `make clean-ai-how` - Clean the ai-how package build artifacts

### Help

- `make help` - Display all available targets

## Troubleshooting

### Container Issues

```bash
# Check if container is running
docker ps

# Rebuild container if needed
make build-docker

# Check container logs
docker logs <container-id>
```

### Build Issues

```bash
# Clean and reconfigure
rm -rf build/
make config

# Check available targets
make run-docker COMMAND="cmake --build build --target help"

# Verify container is working
make shell-docker
```

### Permission Issues

The container automatically handles file permissions and ownership to match the host user. If you encounter permission issues:

```bash
# Rebuild container
make build-docker

# Or check file ownership
ls -la build/
```

## Best Practices

1. **Always use the container** for build operations
2. **Use `make config`** to configure CMake with Ninja generator
3. **Use `make run-docker COMMAND="..."`** for all build commands
4. **Configure CMake first** before building
5. **Use `cmake --build build --target help`** to discover available targets

## Examples

### Complete Build Workflow

```bash
# 1. Setup
make build-docker
make config

# 2. Build everything
make run-docker COMMAND="cmake --build build"

# 3. Build specific target
make run-docker COMMAND="cmake --build build --target <target-name>"

# 4. Clean up
make run-docker COMMAND="cmake --build build --target clean"
```

### Development Workflow

```bash
# Enter container for development
make shell-docker

# Or run specific commands
make run-docker COMMAND="cmake --build build --target help"
```

This configuration ensures that the Cursor agent can effectively work with your project's containerized
build environment while maintaining consistency and proper isolation.
