# Docker-in-Docker Configuration

## Overview

The development container supports Docker-in-Docker (DinD) functionality, allowing you to build and manage Docker
containers from within the development container. This feature is **disabled by default** for security reasons and
requires explicit opt-in.

## Security Considerations

**Note**: Mounting the Docker socket grants full control of the host Docker daemon to the container. In a development
environment, this is typically acceptable and necessary for container building workflows. However, be aware that:

- The container has full access to the host Docker daemon
- Processes inside the container can start privileged containers
- This should only be used in trusted development environments

For this reason, Docker-in-Docker is **disabled by default** and requires explicit opt-in with confirmation.

## Default Behavior

Docker-in-Docker is **disabled by default** for all development container invocations. This means:

- `make shell-docker` - Docker-in-Docker is disabled (no socket mounted)
- `make run-docker COMMAND="..."` - Docker-in-Docker is disabled (no socket mounted)
- `./scripts/run-in-dev-container.sh` - Docker-in-Docker is disabled (no socket mounted)

To use Docker commands, you must explicitly enable Docker-in-Docker and confirm the security risk.

## Enabling Docker-in-Docker

To enable Docker-in-Docker functionality, you must explicitly opt-in and confirm the security risk:

### Method 1: Environment Variable with Confirmation

```bash
# Enable for a single command (will prompt for confirmation)
DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 ./scripts/run-in-dev-container.sh <command>

# Enable for an interactive shell (will prompt for confirmation)
DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 ./scripts/run-in-dev-container.sh

# Skip confirmation prompt (use with caution)
DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 DEV_CONTAINER_DOCKER_SOCKET_CONFIRM=1 ./scripts/run-in-dev-container.sh <command>
```

### Method 2: Makefile Variable

```bash
# Enable for a specific make run-docker command (will prompt for confirmation)
make run-docker DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 COMMAND="some command"

# Skip confirmation prompt (use with caution)
make run-docker DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 DEV_CONTAINER_DOCKER_SOCKET_CONFIRM=1 COMMAND="some command"
```

### Method 3: Change Default in Makefile (Not Recommended)

**Warning**: Changing the default to enabled is not recommended for security reasons. If you must do this, edit the Makefile:

```makefile
# Change from 0 to 1 to enable by default (NOT RECOMMENDED)
DEV_CONTAINER_ENABLE_DOCKER_SOCKET ?= 1
```

## Usage Examples

### Building Containers

To build and deploy containers, you must enable Docker-in-Docker:

```bash
# Build and deploy containers (requires Docker-in-Docker to be enabled)
DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 DEV_CONTAINER_DOCKER_SOCKET_CONFIRM=1 make containers-deploy-beegfs
```

### Manual Container Builds

For manual container building operations:

```bash
# Build a specific container target (requires Docker-in-Docker)
DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 make run-docker COMMAND="cmake --build build --target build-all-containers"

# Run docker commands directly
DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 make run-docker COMMAND="docker build -t myimage:latest ./containers/myapp"

# Use docker-compose
DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 make run-docker COMMAND="docker-compose up -d"
```

### Interactive Development

Start an interactive shell with Docker-in-Docker enabled:

```bash
DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 make shell-docker

# Inside the container, you can use docker commands
docker ps
docker build -t test:latest .
docker run --rm test:latest
```

## Verification

To verify Docker-in-Docker is working:

```bash
# Start shell with Docker-in-Docker enabled
DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 make shell-docker

# Inside the container, check Docker access
docker info
docker ps
```

You should see output from the host Docker daemon.

## Behavior Indicators

When Docker-in-Docker **IS** enabled (after explicit opt-in):

- The script logs: `Docker socket will be mounted for Docker-in-Docker functionality (explicit opt-in and confirmation enabled)`
- Docker commands inside the container control the host Docker daemon
- You have full access to build, run, and manage containers

When Docker-in-Docker is **disabled** (default):

- The script logs: `Docker socket will NOT be mounted (disabled by default for security)`
- Docker commands inside the container will fail with "Cannot connect to Docker daemon"
- This provides additional isolation from the host

## Makefile Configuration

The Makefile includes a configuration variable with Docker-in-Docker disabled by default:

```makefile
# Docker-in-Docker support
# Disabled by default for security. Enable only if you need to build or run containers inside the dev container.
# Set DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 to explicitly opt-in.
# WARNING: Mounting Docker socket grants full control of host Docker daemon and can lead to privilege escalation.
# DO NOT enable unless you understand the risks.
DEV_CONTAINER_ENABLE_DOCKER_SOCKET ?= 0
```

You can override this:

- In your shell: `export DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1` (to enable, will prompt for confirmation)
- In command line: `make run-docker DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 COMMAND="..."` (to enable, will prompt for confirmation)
- To skip confirmation: `DEV_CONTAINER_DOCKER_SOCKET_CONFIRM=1` (use with caution)

## Targets That May Need Docker-in-Docker

Some development container targets may require Docker-in-Docker to be enabled:

- `shell-docker` - Interactive shell (Docker access optional)
- `run-docker` - Execute any command (Docker access optional)
- `containers-deploy-beegfs` - Builds all containers and deploys to BeeGFS (requires Docker-in-Docker)
- `config` - CMake configuration (may invoke container builds, may require Docker-in-Docker)

Enable Docker-in-Docker explicitly when needed: `DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 make <target>`

## Troubleshooting

### "Cannot connect to the Docker daemon" Error

**Possible causes**:

1. Docker-in-Docker is disabled by default: Set `DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1` to enable (and confirm when prompted)
2. Docker is not running on the host: Start Docker on the host machine
3. Docker socket not found: Check that `/var/run/docker.sock` exists on the host

### Permission Denied When Accessing Docker Socket

**Cause**: The user inside the container may not have the correct group memberships.

**Solution**: The entrypoint script should automatically add your user to the docker group. If this fails, check:

```bash
# Inside container
groups  # Should include 'docker'
ls -l /var/run/docker.sock  # Should be accessible
```

### Docker Socket Not Found

**Cause**: Docker is not running on the host, or the socket is in a non-standard location.

**Solution**: Ensure Docker is running on the host:

```bash
# On host
docker info
ls -l /var/run/docker.sock
```

## Best Practices

1. **Disabled by default for security**: Docker-in-Docker is off by default - only enable when needed
2. **Understand the security implications**: The container has full access to the host Docker daemon -
only use in trusted environments
3. **Enable only when needed**: For non-container-building tasks, leave Docker-in-Docker disabled
4. **Use Makefile targets**: Prefer `make shell-docker` and `make run-docker` over direct script invocation
5. **Production deployment**: Never enable Docker-in-Docker in production containers unless absolutely necessary
6. **Always confirm**: The confirmation prompt is there for your protection - read and understand the warning before proceeding

## Related Documentation

- [Build System Architecture](../architecture/build-system.md)
- [Container Development](../workflows/APPTAINER-CONVERSION-WORKFLOW.md)
- [Cursor Agent Setup](./cursor-agent-setup.md)
