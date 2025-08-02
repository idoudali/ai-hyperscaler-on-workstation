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
3. Mount your project directory into the `/workspace` directory in the container.
4. Give you an interactive `bash` shell.

## Makefile Targets

The `Makefile` in the root of the project provides several commands to manage the development environment:

- `make build-docker`: Builds the Docker image with the tag `pharos-dev:latest`.
- `make shell-docker`: Starts an interactive shell inside a new container. Your local project directory is mounted at `/workspace`.
- `make push-docker`: Pushes the image to a container registry. You will need to configure the `REGISTRY_URL` in the `Makefile`.
- `make clean-docker`: Removes the `pharos-dev:latest` Docker image and any stopped containers.
- `make lint-docker`: Lints the `Dockerfile`. You need to add a linter tool for this to work.

## Development Workflow

1.  **Start the environment**: Run `make shell-docker`.
2.  **Work in the container**: All tools (`terraform`, `ansible`, `packer`, etc.) are available inside the container's shell.
    Your project files are available in the `/workspace` directory.
3.  **Exit the container**: Simply type `exit` in the container's shell. The container will be automatically removed.
4.  **Clean up**: Run `make clean-docker` to remove the Docker image.
