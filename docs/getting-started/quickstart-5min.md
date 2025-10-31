# 5-Minute Quickstart

**Status:** Production  
**Last Updated:** 2025-10-31  
**Target Time:** 5 minutes  
**Prerequisites:** [Installation Guide](installation.md) completed

## Overview

Get your development environment up and running in 5 minutes. This quickstart covers the minimal steps to verify your
installation and build your first Packer image.

**What You'll Do:**

1. Verify prerequisites
2. Build Docker development container
3. Create Python virtual environment
4. Configure build system
5. Build your first Packer image

## Step 1: Verify Prerequisites (30 seconds)

Ensure you've completed the [Installation Guide](installation.md):

```bash
# Check required tools
docker --version
python3 --version
git --version

# Verify Docker is running
docker ps
```

**Expected Output:**

```text
Docker version 24.0.0 or higher
Python 3.11.0 or higher
git version 2.30.0 or higher
Docker daemon running (should show container list)
```

## Step 2: Clone and Navigate (30 seconds)

```bash
# Clone the repository (if not already done)
git clone https://github.com/your-org/pharos.ai-hyperscaler-on-workskation.git
cd pharos.ai-hyperscaler-on-workskation
```

## Step 3: Build Development Container (2 minutes)

```bash
# Build the Docker development image
make build-docker
```

**Expected Output:**

```text
Successfully built development-image:latest
Development container ready
```

**Note:** First build takes ~2 minutes. Subsequent builds are cached and faster.

## Step 4: Create Python Environment (1 minute)

```bash
# Create and setup Python virtual environment
make venv-create
```

**Expected Output:**

```text
Virtual environment created at .venv/
All dependencies installed successfully
```

## Step 5: Configure Build System (30 seconds)

```bash
# Configure CMake with Ninja generator
make config
```

**Expected Output:**

```text
-- Configuring done
-- Generating done
-- Build files written to: build/
```

## Step 6: Build Your First Image (30 seconds)

```bash
# Enter the build directory and list available targets
cd build
ninja help | grep packer

# Build the HPC base image (smallest image, fastest build for testing)
ninja build-hpc-base-image
```

**Expected Output:**

```text
Building HPC base image...
Packer build completed successfully
Image available at: packer/hpc-base/output/
```

## ✅ Success!

You now have:

- ✅ Development container built and ready
- ✅ Python environment configured
- ✅ Build system configured with CMake + Ninja
- ✅ First Packer image built

## Next Steps

Now that your development environment is ready, try these:

### Build More Images

```bash
# List all available Packer image targets
cd build
ninja help | grep packer

# Build controller image
ninja build-hpc-controller-image

# Build compute image
ninja build-hpc-compute-image
```

### Deploy Your First Cluster

Follow the [Cluster Deployment Quickstart](quickstart-cluster.md) to:

- Deploy a complete HPC cluster
- Submit your first SLURM job
- View job results

### Explore Containers

See [Container Quickstart](quickstart-containers.md) to:

- Build containerized workloads
- Convert Docker images to Apptainer
- Run containers on SLURM

## Quick Reference

### Essential Commands

```bash
# Build development container
make build-docker

# Enter development shell
make shell-docker

# Configure CMake
make config

# Run command in container
make run-docker COMMAND="your-command"
```

### Build System Workflow

```bash
# Always work from build/ directory
cd build

# List targets
ninja help

# Build specific target
ninja <target-name>

# Reconfigure (if CMakeLists.txt changed)
cd .. && make config
```

## Troubleshooting

### Docker Build Fails

**Issue:** Cannot connect to Docker daemon

**Solution:**

```bash
# Start Docker service
sudo systemctl start docker

# Verify Docker is running
docker ps
```

### CMake Configuration Fails

**Issue:** CMake cannot find dependencies

**Solution:**

```bash
# Clean and reconfigure
rm -rf build/
make config
```

### Ninja Not Found

**Issue:** `ninja: command not found`

**Solution:**

```bash
# Install ninja-build
sudo apt install ninja-build  # Ubuntu/Debian
```

For more troubleshooting, see the [Common Issues Guide](../troubleshooting/common-issues.md).

## What's Next?

**Ready for more?** Choose your learning path:

- **[Cluster Deployment](quickstart-cluster.md)** - Deploy complete HPC cluster (15 min)
- **[GPU Setup](quickstart-gpu.md)** - Configure GPU passthrough (10 min)
- **[Container Workflow](quickstart-containers.md)** - Build and deploy containers (10 min)
- **[Monitoring](quickstart-monitoring.md)** - Set up monitoring dashboards (10 min)

**Want deeper understanding?**

- **[Architecture Overview](../architecture/overview.md)** - Understand system design
- **[First Cluster Tutorial](../tutorials/01-first-cluster.md)** - Comprehensive cluster guide
- **[Build System Documentation](../architecture/build-system.md)** - Deep dive into build process

## Summary

In just 5 minutes, you've:

1. ✅ Verified your installation
2. ✅ Built the development container
3. ✅ Set up Python environment
4. ✅ Configured the build system
5. ✅ Built your first Packer image

**Congratulations!** You're ready to start building HPC infrastructure on your workstation.
