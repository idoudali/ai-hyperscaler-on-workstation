# Docker Image Development Workflow

**Status:** Production
**Created:** 2025-10-24
**Last Updated:** 2025-10-24

## Overview

This guide explains how to make changes to the Docker development image for the AI-HOW project.
It covers modifying the Dockerfile, rebuilding the image, testing changes, and troubleshooting
the build process.

## Prerequisites

- Docker installed and running
- Project cloned locally
- Basic familiarity with `make` commands and Docker

## Dockerfile Location

The main Dockerfile is located at:

```text
docker/Dockerfile
```

View current Dockerfile:

```bash
cat docker/Dockerfile
```

## Making Changes to the Dockerfile

### 1. Edit the Dockerfile

```bash
# Edit the Dockerfile using your preferred editor
vim docker/Dockerfile

# Or use any editor
code docker/Dockerfile
```

### 2. Common Dockerfile Modifications

#### Adding a New Package

```dockerfile
RUN apt-get update && apt-get install -y \
    existing-package \
    new-package-name \
    && rm -rf /var/lib/apt/lists/*
```

#### Installing Python Packages

```dockerfile
RUN pip install package-name
# Or for multiple packages
RUN pip install -r requirements-dev.txt
```

#### Adding Environment Variables

```dockerfile
ENV VARIABLE_NAME=value
ENV PATH="/new/path:${PATH}"
```

#### Adding Files or Directories

```dockerfile
COPY docker/scripts/ /app/scripts/
COPY config/ /app/config/
```

#### Running Setup Commands

```dockerfile
RUN ./scripts/setup.sh
RUN apt-get clean
```

## Building the Docker Image

### Standard Build

Build the image with the default tag:

```bash
make build-docker
```

This creates an image tagged as `ai-how-dev:latest`.

### Build Without Cache

Force a complete rebuild by skipping cached layers:

```bash
make build-docker --no-cache
```

Use this when:

- Package repositories have changed
- You need fresh package versions
- Previous build had issues

### Build with Specific Tag

Build and tag with a custom version:

```bash
docker build -t ai-how-dev:v1.0 docker/
```

### Monitor Build Progress

To see detailed build output:

```bash
docker build -v --progress=plain -t ai-how-dev:latest docker/
```

## Testing Docker Image Changes

### Quick Test After Build

Verify the image built successfully:

```bash
docker image ls | grep ai-how-dev
```

Should show output like:

```text
ai-how-dev    latest    abc123def456    2 minutes ago    2.5GB
```

### Run Container with New Image

Start a container to test the image:

```bash
make shell-docker
```

Inside the container, verify changes:

```bash
# Check if new package is installed
which package-name

# Check Python packages
pip list | grep package-name

# Check environment variables
echo $VARIABLE_NAME

# Test functionality
command-name --version
```

### Test Specific Functionality

Test that new tools work correctly:

```bash
# Exit container
exit

# Start fresh container
make shell-docker

# Test inside container
# Run the specific functionality you added
your-tool --help
your-tool --version
```

### Run Container Commands Without Entering Shell

Execute commands directly in the container:

```bash
docker run --rm ai-how-dev:latest command-to-test

# Example: Check if package is installed
docker run --rm ai-how-dev:latest which terraform
docker run --rm ai-how-dev:latest python3 --version
```

## Build Troubleshooting

### Build Fails During Package Installation

**Error:** `E: Unable to locate package package-name`

**Solution:**

```bash
# Update package list in Dockerfile
FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y package-name

# Then rebuild
make build-docker --no-cache
```

### Out of Disk Space During Build

**Error:** `no space left on device`

**Solution:**

```bash
# Clean up old Docker resources
docker system prune -a

# Remove build artifacts
rm -rf build/

# Retry build
make build-docker
```

### Build Hangs or Timeout

**Error:** Build process appears stuck or takes too long

**Solution:**

```bash
# Build with timeout specified
timeout 600 docker build -t ai-how-dev:latest docker/

# If it hangs, stop with Ctrl+C and check logs
# Try building without cache
make build-docker --no-cache

# Check if network is the issue
docker run --rm ubuntu:22.04 apt-get update
```

### Layer Caching Issues

**Problem:** Changes to earlier layer not reflected in final image

**Solution:**

```bash
# Force rebuild by adding timestamp
docker build --no-cache -t ai-how-dev:latest docker/

# Or rebuild specific layers by modifying Dockerfile
# Add a comment to force cache invalidation:
# RUN echo "Cache invalidation: $(date)"
```

## Validating Image Changes

### Verify All Tools Are Installed

```bash
docker run --rm ai-how-dev:latest bash << 'EOF'
echo "Python version:"
python3 --version

echo "CMake version:"
cmake --version

echo "Terraform version:"
terraform --version

echo "Ansible version:"
ansible --version

echo "Packer version:"
packer --version

echo "Git version:"
git --version
EOF
```

### Check Image Size

```bash
# Get image size
docker image inspect ai-how-dev:latest --format='{{.Size}}' | numfmt --to=iec

# Or using ls
docker images | grep ai-how-dev
```

If image size increased unexpectedly:

```bash
# Optimize by clearing apt cache in Dockerfile:
RUN apt-get update && apt-get install -y package && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
```

### Test Volume Mounting

Ensure file mounting works correctly:

```bash
# Start container with volume mount
docker run -it -v $(pwd):/workspace ai-how-dev:latest bash

# Inside container, verify mount
ls -la /workspace
pwd
```

## Iterative Development Workflow

### 1. Make Dockerfile Change

Edit `docker/Dockerfile` to add a package, environment variable, or command:

```bash
vim docker/Dockerfile
```

### 2. Build Image

```bash
make build-docker --no-cache
```

### 3. Test in Container

```bash
make shell-docker

# Inside container, verify change
command-to-test

# Exit if successful
exit
```

### 4. If Changes Needed, Repeat

Go back to step 1 and modify the Dockerfile again.

### 5. Clean Up Old Images

Once satisfied with changes:

```bash
docker image prune -a  # Remove unused images
```

## Committing Dockerfile Changes

Once your Docker image changes are tested and working:

```bash
# Stage the Dockerfile change
git add docker/Dockerfile

# Commit with descriptive message
git commit -m "docker: add new package to development image

Added package-name for feature X.
Tested with make shell-docker and verified installation."

# Push to branch
git push origin your-branch-name
```

## Rolling Back Image Changes

### Revert to Previous Dockerfile

```bash
# See recent changes
git log docker/Dockerfile

# Revert to previous commit
git checkout HEAD~1 docker/Dockerfile

# Rebuild image
make build-docker --no-cache
```

### Remove Image Completely

```bash
# Stop any running containers
docker stop ai-how-dev

# Remove image
docker rmi ai-how-dev:latest

# Verify removal
docker images | grep ai-how-dev
```

## Best Practices

1. **Test changes locally** - Always test Dockerfile changes in a container before committing
2. **Minimize layer count** - Combine multiple RUN commands to reduce image layers
3. **Clean package managers** - Always run `apt-get clean` after installations
4. **Use specific versions** - Pin package versions for reproducibility
5. **Document changes** - Add comments in Dockerfile explaining why something is needed
6. **Keep image small** - Remove unnecessary files and build artifacts
7. **Build without cache** - Use `--no-cache` when making critical changes
8. **Test thoroughly** - Verify all tools and dependencies work in the built image

## Related Documentation

- **Docker Setup:** `docker/README.md`
- **GPU Support:** `docker/gpu-support.md`
- **Troubleshooting:** `docker/troubleshooting.md`
- **Build Container Rules:** `.ai/rules/build-container.md`
