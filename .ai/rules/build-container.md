---
alwaysApply: true
---
# Container Build Requirements

## Critical Rule

**NEVER run build commands on host. Always use Docker container.**

## Required Commands

```bash
# Build container
make build-docker

# Configure CMake
make config

# Run commands in container
make run-docker COMMAND="..."

# Interactive shell
make shell-docker
```

## Build System

- **Generator**: CMake with Ninja (never use Make)
- **Build Directory**: `build/` (always)
- **Configuration**: `make config` (runs `cmake -G Ninja -S . -B build`)

## Important Rules

1. **NEVER** run builds on host - always use container
2. **ALWAYS** use Ninja generator - never use Make
3. **ALWAYS** use `build/` directory
4. Use Makefile wrapper when possible
5. Check Docker is running before commands

## Build Commands

```bash
# Build specific target
make run-docker COMMAND="cmake --build build --target <target>"

# Build all
make run-docker COMMAND="cmake --build build"

# List targets
make run-docker COMMAND="cmake --build build --target help"
```

## Container automatically handles file permissions and ownership.
