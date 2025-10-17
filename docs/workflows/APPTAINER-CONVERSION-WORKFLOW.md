# Apptainer Conversion Workflow

**Task 020 Documentation** - Docker to Apptainer Conversion and Testing

## Overview

This document describes the complete workflow for converting Docker container images to Apptainer (Singularity
Image Format) for deployment on HPC clusters. The workflow includes Docker image building, conversion to
Apptainer format using CMake targets, local testing, and validation of all functionality.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Workflow Overview](#workflow-overview)
- [Docker to Apptainer Conversion](#docker-to-apptainer-conversion)
  - [Single Image Conversion](#single-image-conversion)
  - [Batch Conversion](#batch-conversion)
  - [CMake Integration](#cmake-integration)
- [Local Testing](#local-testing)
  - [Quick Testing](#quick-testing)
  - [Comprehensive Testing](#comprehensive-testing)
  - [GPU Testing](#gpu-testing)
- [Test Suites](#test-suites)
  - [Image Format and Functionality Tests](#image-format-and-functionality-tests)
  - [CUDA Functionality Tests](#cuda-functionality-tests)
  - [MPI Functionality Tests](#mpi-functionality-tests)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before starting the conversion workflow, ensure you have:

- **Apptainer installed** (v1.3.6 or higher)

  ```bash
  apptainer --version
  ```

- **Docker daemon running** with appropriate permissions

  ```bash
  docker info
  ```

- **Built Docker images** from Task 019

  ```bash
  cmake --build build --target build-all-docker-images
  ```

- **HPC container manager CLI** set up

  ```bash
  cmake --build build --target setup-hpc-cli
  build/containers/venv/bin/hpc-container-manager --help
  ```

## Workflow Overview

The complete Docker to Apptainer workflow consists of the following steps:

```text
1. Build Docker Image        → docker build
2. Convert to Apptainer      → apptainer build (docker-daemon://)
3. Local Testing             → apptainer exec/run
4. Comprehensive Validation  → test suites
5. Cluster Deployment        → Task 021
```

### Typical Workflow Commands

```bash
# 1. Build Docker image
cmake --build build --target build-docker-pytorch-cuda12.1-mpi4.1

# 2. Convert to Apptainer (CMake target)
cmake --build build --target convert-to-apptainer-pytorch-cuda12.1-mpi4.1

# 3. Test locally
containers/scripts/test-apptainer-local.sh

# 4. Comprehensive validation
cmake --build build --target test-apptainer-all
```

## Docker to Apptainer Conversion

### Single Image Conversion

Convert a specific Docker image to Apptainer format:

**Using Shell Script:**

```bash
# Basic conversion (default output path)
./containers/scripts/convert-single.sh pytorch-cuda12.1-mpi4.1:latest

# Custom output path
./containers/scripts/convert-single.sh \
  pytorch-cuda12.1-mpi4.1:latest \
  /tmp/my-pytorch-image.sif
```

**Using HPC CLI:**

```bash
# Direct conversion using CLI
build/containers/venv/bin/hpc-container-manager convert to-apptainer \
  pytorch-cuda12.1-mpi4.1:latest \
  build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif
```

**Using CMake (Recommended):**

```bash
# CMake target (uses CLI internally)
cmake --build build --target convert-to-apptainer-pytorch-cuda12.1-mpi4.1
```

### Batch Conversion

Convert all Docker images to Apptainer format using CMake:

**CMake Batch Conversion (Recommended):**

```bash
# Convert all images automatically
cmake --build build --target convert-all-to-apptainer

# This will:
# - Discover all built Docker images
# - Convert each to Apptainer SIF format
# - Skip already converted images (unless Docker is newer)
# - Create output in build/containers/apptainer/
```

**Features:**

- Automatic discovery of Docker images
- Smart conversion (only converts when needed)
- Parallel processing through CMake/Ninja
- Integrated error handling
- Progress reporting

### CMake Integration

The conversion workflow is fully integrated into the CMake build system:

**Available CMake Targets:**

- `convert-to-apptainer-<name>` - Convert specific image
- `convert-all-to-apptainer` - Convert all images (batch)
- `convert-single` - Interactive single image conversion (script wrapper)
- `build-container-<name>` - Complete workflow: build Docker + convert to Apptainer

**Example Usage:**

```bash
# Complete workflow for specific container
cmake --build build --target build-container-pytorch-cuda12.1-mpi4.1

# This internally runs:
# 1. build-docker-pytorch-cuda12.1-mpi4.1
# 2. convert-to-apptainer-pytorch-cuda12.1-mpi4.1
```

## Testing Approach

Task 020 provides two levels of testing:

1. **Script Validation** - Tests the scripts themselves (no images required)
2. **Image Validation** - Tests converted Apptainer images (requires images)

### Script Validation (Development/CI)

Validate conversion workflow scripts without requiring Docker images or Apptainer images:

```bash
# Test all conversion scripts
make run-docker COMMAND="ninja -C build test-conversion-scripts"

# Or test individually
make run-docker COMMAND="ninja -C build test-convert-single-script"
make run-docker COMMAND="ninja -C build test-apptainer-local-script"
```

**Script Validation Coverage:**

**convert-single.sh validation (7 tests):**

- Bash syntax validation
- Executable permissions check
- Help output functionality
- Error handling for missing arguments
- Required functions present (check_prerequisites, convert_image, log_error)
- Proper error messages (CLI, Apptainer, Docker)
- Environment variable support (HPC_CLI)

**test-apptainer-local.sh validation (10 tests):**

- Bash syntax validation
- Executable permissions check
- Help output functionality
- Error handling code present
- Required test functions (test_basic_functionality, test_pytorch, test_cuda, test_mpi)
- Command-line options (--verbose, --gpu)
- Apptainer execution commands
- GPU support flag (--nv)
- Test result tracking (pass/fail counters)
- Logging functions (log_info, log_success, log_error)

**Use Cases:**

- CI/CD pipeline validation (no images needed)
- Development environment setup verification
- Pre-commit checks
- Script correctness validation

## Local Testing

### Quick Testing

Rapid validation of converted images:

```bash
# Test all Apptainer images
./containers/scripts/test-apptainer-local.sh

# Test specific image
./containers/scripts/test-apptainer-local.sh pytorch-cuda12.1-mpi4.1.sif

# Verbose output
./containers/scripts/test-apptainer-local.sh --verbose
```

**Quick Test Coverage:**

- Basic functionality (execution, environment)
- PyTorch availability and version
- CUDA support (if GPU present)
- MPI libraries and functionality

### Comprehensive Testing

Full validation using test suites:

```bash
# Run all test suites
cmake --build build --target test-apptainer-all

# Or individually
cmake --build build --target test-converted-images
cmake --build build --target test-cuda-apptainer
cmake --build build --target test-mpi-apptainer
```

### GPU Testing

Test GPU functionality if NVIDIA GPU is available:

```bash
# Enable GPU testing
./containers/scripts/test-apptainer-local.sh --gpu

# Test CUDA specifically
./containers/tests/apptainer/test-cuda-apptainer.sh

# Skip GPU tests if hardware unavailable
./containers/tests/apptainer/test-cuda-apptainer.sh --skip-gpu-tests
```

## Test Suites

### Image Format and Functionality Tests

**Test Script:** `containers/tests/apptainer/test-converted-images.sh`

**Validation Coverage:**

- **Image Format:**
  - SIF (Singularity Image Format) validation
  - File integrity and size checks
  - Metadata and labels verification

- **File System Structure:**
  - Standard directories present (`/usr`, `/bin`, `/lib`, `/etc`)
  - Workspace directory configuration
  - Proper permissions and ownership

- **Python Environment:**
  - Python 3.x availability
  - pip package manager
  - Core package installations

- **Package Installations:**
  - PyTorch presence and version
  - MPI4Py availability
  - NumPy and scientific computing libraries

- **Library Linking:**
  - CUDA libraries detection
  - MPI executables availability
  - Shared library dependencies

- **Container Size:**
  - Size optimization validation
  - Warning for oversized images (>10GB)

**Usage:**

```bash
# Test all images
./containers/tests/apptainer/test-converted-images.sh

# Test specific image
./containers/tests/apptainer/test-converted-images.sh pytorch-cuda12.1-mpi4.1.sif

# Via CMake
cmake --build build --target test-converted-images
```

### CUDA Functionality Tests

**Test Script:** `containers/tests/apptainer/test-cuda-apptainer.sh`

**Validation Coverage:**

- **CUDA Libraries:**
  - CUDA directory structure (`/usr/local/cuda`)
  - CUDA headers availability
  - CUDA runtime libraries

- **CUDA Version:**
  - CUDA toolkit version detection
  - nvcc compiler availability

- **PyTorch CUDA Build:**
  - PyTorch CUDA support verification
  - CUDA version compatibility

- **CUDA Availability:**
  - Runtime CUDA detection
  - GPU device accessibility with `--nv` flag

- **GPU Device Detection:**
  - GPU count and enumeration
  - Device names and properties
  - Memory capacity

- **CUDA Operations:**
  - Tensor creation on GPU
  - Matrix operations (matmul, etc.)
  - GPU memory allocation and management

- **cuDNN:**
  - cuDNN library availability
  - cuDNN version detection

**Usage:**

```bash
# Test all images (requires GPU)
./containers/tests/apptainer/test-cuda-apptainer.sh

# Skip GPU hardware tests
./containers/tests/apptainer/test-cuda-apptainer.sh --skip-gpu-tests

# Via CMake
cmake --build build --target test-cuda-apptainer
```

**GPU Testing Requirements:**

- NVIDIA GPU hardware
- NVIDIA driver installed
- `nvidia-smi` command available
- Apptainer run with `--nv` flag for GPU access

### MPI Functionality Tests

**Test Script:** `containers/tests/apptainer/test-mpi-apptainer.sh`

**Validation Coverage:**

- **MPI Libraries:**
  - MPI shared libraries (`libmpi.so`)
  - MPI implementation detection (OpenMPI, MPICH)

- **MPI Executables:**
  - `mpirun` availability
  - `mpiexec` availability
  - `mpicc` compiler (optional)

- **MPI Version:**
  - MPI implementation version
  - Standard compliance

- **MPI4Py:**
  - Python MPI bindings installation
  - MPI4Py version detection

- **Basic MPI Functionality:**
  - MPI rank and size detection
  - Communicator initialization
  - Single-process execution

- **MPI Communication:**
  - Point-to-point communication (send/recv)
  - Multi-process coordination

- **MPI Collective Operations:**
  - Broadcast operations
  - Reduce operations
  - All-reduce functionality

- **MPI + NumPy Integration:**
  - NumPy array communication
  - Collective operations on arrays

- **PMIx Support:**
  - PMIx libraries detection
  - PMI2 availability

**Usage:**

```bash
# Test all images
./containers/tests/apptainer/test-mpi-apptainer.sh

# Test specific image
./containers/tests/apptainer/test-mpi-apptainer.sh pytorch-cuda12.1-mpi4.1.sif

# Via CMake
cmake --build build --target test-mpi-apptainer
```

## Best Practices

### Conversion Best Practices

1. **Clean Docker Environment:**

   ```bash
   # Ensure Docker image is fresh
   docker system prune -f
   docker build --no-cache ...
   ```

2. **Verify Docker Image:**

   ```bash
   # Test Docker image before conversion
   cmake --build build --target test-docker-pytorch-cuda12.1-mpi4.1
   ```

3. **Use CMake Targets:**

   ```bash
   # Preferred method for batch conversion
   cmake --build build --target convert-all-to-apptainer
   ```

4. **Optimize Image Size:**
   - Remove build artifacts in Dockerfile
   - Use multi-stage builds
   - Clean package caches

### Testing Best Practices

1. **Progressive Testing:**

   ```bash
   # Test in order of complexity
   1. Quick test (test-apptainer-local.sh)
   2. Format test (test-converted-images.sh)
   3. CUDA test (test-cuda-apptainer.sh)
   4. MPI test (test-mpi-apptainer.sh)
   ```

2. **GPU Testing:**
   - Always test without GPU first
   - Use `--skip-gpu-tests` for CI/CD
   - Verify `--nv` flag behavior

3. **Test Reports:**

   ```bash
   # Review test logs
   ls -la build/test-logs/apptainer/
   ```

### Deployment Best Practices

1. **Version Control:**
   - Tag Docker images with versions
   - Track .sif file checksums
   - Document conversion dates

2. **Storage Management:**

   ```bash
   # Check image sizes
   du -h build/containers/apptainer/*.sif
   ```

3. **Distribution:**
   - Compress large images for transfer
   - Use rsync for cluster deployment
   - Verify checksums after transfer

## Troubleshooting

### Conversion Issues

**Problem:** Conversion fails with permission error

```bash
# Solution: Check Docker permissions
sudo usermod -aG docker $USER
newgrp docker
```

**Problem:** Out of disk space during conversion

```bash
# Solution: Clean up Docker
docker system prune -a -f
docker volume prune -f

# Check disk space
df -h
```

**Problem:** Apptainer not found

```bash
# Solution: Install Apptainer
# See: https://apptainer.org/docs/admin/latest/installation.html

# Or use development container
./scripts/run-in-dev-container.sh
```

### Testing Issues

**Problem:** GPU tests fail

```bash
# Solution 1: Check GPU availability
nvidia-smi

# Solution 2: Use --nv flag explicitly
apptainer exec --nv image.sif nvidia-smi

# Solution 3: Skip GPU tests
./test-cuda-apptainer.sh --skip-gpu-tests
```

**Problem:** MPI tests fail

```bash
# Solution: Check MPI installation in container
apptainer exec image.sif which mpirun
apptainer exec image.sif python3 -c "from mpi4py import MPI"
```

**Problem:** Image too large

```bash
# Solution: Optimize Dockerfile
# 1. Use multi-stage builds
# 2. Clean package caches
# 3. Remove unnecessary files

# Check image layers
apptainer inspect image.sif
```

### Performance Issues

**Problem:** Slow conversion

```bash
# Solution: Use CMake's parallel build
cmake --build build --target convert-all-to-apptainer -j $(nproc)

# Or use faster storage
export APPTAINER_CACHEDIR=/tmp/apptainer-cache
```

**Problem:** High memory usage

```bash
# Solution: Monitor and limit resources
# Check memory usage
free -h

# Convert one at a time if needed
cmake --build build --target convert-to-apptainer-<name>
```

## Summary

The Docker to Apptainer conversion workflow (Task 020) provides:

- **CMake-Driven Conversion**: Integrated build targets for automation
- **Comprehensive Testing**: Format, CUDA, and MPI validation
- **Flexible Options**: Single, batch conversion via CMake
- **Production Ready**: Complete validation and deployment preparation

**Key CMake Targets:**

- `convert-to-apptainer-<name>` - Convert specific image
- `convert-all-to-apptainer` - Batch conversion
- `test-apptainer-all` - Comprehensive testing
- `build-container-<name>` - Complete workflow

**Next Steps:**

- Task 021: Container Registry Infrastructure & Cluster Deployment
- Deploy validated Apptainer images to HPC cluster
- Configure SLURM container integration

## References

- [Apptainer Documentation](https://apptainer.org/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Task 019: PyTorch Container Creation](../containers/README.md)
- [Task 021: Container Registry Infrastructure](../ansible/roles/container-registry/README.md)
