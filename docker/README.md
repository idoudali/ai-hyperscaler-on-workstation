# Development Environment

This directory contains the `Dockerfile` and related files for creating a containerized development environment.

## Prerequisites

- [Docker](https://www.docker.com/get-started) must be installed and running on your system.

## Quick Start

To start a development shell inside the container, run the following command from the project root:

```bash
make shell-docker
```

This command will:

1. Build the Docker image if it doesn't exist.
2. Start a new container.
3. Mount your project directory into the container at the same path as the host.
4. Give you an interactive `bash` shell.

## Makefile Targets

The `Makefile` in the root of the project provides several commands to manage the development environment:

- `make build-docker`: Builds the Docker image with the tag `ai-how-dev:latest`.
- `make shell-docker`: Starts an interactive shell inside a new container. Your local project directory is mounted at
    the same path as the host.
- `make push-docker`: Pushes the image to a container registry. You will need to configure the `REGISTRY_URL` in the `Makefile`.
- `make clean-docker`: Removes the `ai-how-dev:latest` Docker image and any stopped containers.
- `make lint-docker`: Lints the `Dockerfile`. You need to add a linter tool for this to work.

## Development Workflow

1.  **Start the environment**: Run `make shell-docker`.
2.  **Work in the container**: All tools (`uv`, `nox`, `terraform`, `ansible`, `packer`,
etc.) are available inside the container's shell.
    Your project files are available in the same directory structure as on the host.
3.  **Exit the container**: Simply type `exit` in the container's shell. The container will be automatically removed.
4.  **Clean up**: Run `make clean-docker` to remove the Docker image.

## Included Tools and Libraries

The development container includes:

- **Python 3.11** with pip and virtual environment support
- **CMake 3.28+** with Ninja build system
- **Terraform** for infrastructure as code
- **Ansible** for configuration management
- **Packer** for image building
- **Build tools** (gcc, g++, make, gzip, tar, wget, curl)
- **System development libraries** (libvirt-dev, libssl-dev, libffi-dev, etc.)
- **Documentation tools** (markdown, sphinx, mkdocs)

## Documentation

For detailed information on specific topics:

- **[Development Workflow Guide](development-workflow.md)** - Modifying the Docker image and workflow

## Environment Details

### Image Size

Uncompressed size: ~2-3GB

### Build Time

First build: 5-10 minutes (depending on internet speed and system performance)
Subsequent builds: 1-2 minutes (using cached layers)

### Network Access

Containers have full network access by default. DNS resolution and internet connectivity work out
of the box.

### File Mounting

Your project directory is mounted read-write inside the container, allowing seamless file sharing:

- Edit files on host, see changes immediately in container
- Changes made in container are immediately visible on host
- No manual copying or syncing required

### Resource Limits

By default, containers have access to:

- All available CPU cores
- 50% of host RAM
- Unlimited disk (limited by host filesystem)

To customize resource allocation, modify Makefile targets.
