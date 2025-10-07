# Container Build System

This directory contains the container build system for HPC workloads, integrated with CMake for consistent
build management.

## Architecture

- **Dockerfile-First Development**: Create Docker images, test locally, convert to Apptainer
- **HPC Extensions**: Custom HPC-specific functionality for Apptainer conversion and cluster deployment
- **CMake Integration**: Consistent build system with Packer infrastructure
- **External Dependencies**: Uses docker-wrapper library (when available) for Docker operations

## Directory Structure

```text
containers/
├── CMakeLists.txt                  # CMake build configuration
├── images/                         # Container image definitions
│   ├── pytorch-cuda12.1-mpi4.1/
│   │   ├── Docker/
│   │   │   └── Dockerfile
│   │   └── docker_wrapper_extensions.py
│   └── tensorflow-cuda12.1/
│       ├── Docker/
│       │   └── Dockerfile
│       └── docker_wrapper_extensions.py
├── tools/
│   ├── hpc_extensions/             # HPC-specific extensions
│   │   ├── apptainer_converter.py
│   │   └── cluster_deploy.py
│   └── cli/
│       └── hpc-container-manager   # Main CLI tool
├── requirements.txt                # Python dependencies (docker-wrapper when available)
└── builds/                         # Build outputs (created by CMake)
    ├── docker/
    └── apptainer/
```

## Prerequisites

- Docker (for building Docker images)
- Apptainer (for converting Docker images to HPC format)
- Python 3.10+ with venv support
- CMake 3.18+
- uv (optional, for faster Python package installation)
- docker-wrapper library (optional, when available from PyPI or local installation)

## CMake Build System Usage

### Initial Setup

```bash
# Configure CMake (from project root)
cmake -G Ninja -S . -B build

# Set up container tools and CLI
cmake --build build --target setup-container-tools
cmake --build build --target setup-hpc-cli
```

### Building Docker Images

```bash
# Build specific Docker image
cmake --build build --target build-docker-pytorch-cuda12.1-mpi4.1

# Build all Docker images
cmake --build build --target build-all-docker-images

# Test Docker image
cmake --build build --target test-docker-pytorch-cuda12.1-mpi4.1
```

### Converting to Apptainer

```bash
# Convert specific image
cmake --build build --target convert-to-apptainer-pytorch-cuda12.1-mpi4.1

# Convert all images
cmake --build build --target convert-all-to-apptainer

# Test Apptainer image
cmake --build build --target test-apptainer-pytorch-cuda12.1-mpi4.1
```

### Complete Workflow

```bash
# Build Docker + Convert to Apptainer for specific container
cmake --build build --target build-container-pytorch-cuda12.1-mpi4.1

# Build all containers (Docker + Apptainer)
cmake --build build --target build-all-containers
```

### List Available Targets

```bash
# Show container build system help
cmake --build build --target help-containers

# List all available targets
cmake --build build --target help
```

### Cleanup

```bash
# Clean Docker images
cmake --build build --target clean-docker-images

# Clean Apptainer images
cmake --build build --target clean-apptainer-images

# Clean virtual environment
cmake --build build --target clean-container-venv

# Clean all container artifacts
cmake --build build --target clean-all-containers
```

## Direct CLI Usage

After setup, you can use the HPC container manager CLI directly:

```bash
# Activate virtual environment
source build/containers/venv/bin/activate

# Or use direct path to CLI
build/containers/venv/bin/hpc-container-manager --help

# Build Docker image
build/containers/venv/bin/hpc-container-manager docker build pytorch-cuda12.1-mpi4.1

# Interactive prompt
build/containers/venv/bin/hpc-container-manager docker prompt pytorch-cuda12.1-mpi4.1

# Convert to Apptainer
build/containers/venv/bin/hpc-container-manager convert to-apptainer pytorch-cuda12.1-mpi4.1:latest \
    build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif

# Deploy to cluster
build/containers/venv/bin/hpc-container-manager deploy to-cluster \
    build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif \
    /opt/containers/pytorch-cuda12.1-mpi4.1.sif \
    --controller <controller-ip> --user root --sync-nodes
```

## Adding New Containers

### 1. Create Extension Directory

```bash
mkdir -p images/my-container/Docker
```

### 2. Create Dockerfile

```dockerfile
# images/my-container/Docker/Dockerfile
FROM nvidia/cuda:12.1.0-devel-ubuntu22.04

RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip

RUN pip3 install torch torchvision

WORKDIR /workspace
CMD ["/bin/bash"]
```

### 3. Create DockerWrapper Extension

```python
# images/my-container/docker_wrapper_extensions.py
from pathlib import Path
from docker_wrapper.hpc_extensions import HPCDockerImage

class MyContainer(HPCDockerImage):
    NAME = "my-container"
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.name = self.NAME
        self.docker_folder = str(Path(__file__).parent / "Docker")
        self.version = "1.0.0"
```

### 4. Reconfigure CMake

```bash
# CMake will automatically discover the new container
cmake -G Ninja -S . -B build

# Build new container
cmake --build build --target build-container-my-container
```

## Build System Integration

The container build system integrates with the existing CMake infrastructure:

```bash
# Build everything (Packer + Containers)
cmake --build build

# Build only Packer images
cmake --build build --target build-packer-images

# Build only containers
cmake --build build --target build-all-containers
```

## Virtual Environment Location

The container virtual environment is created at: `build/containers/venv/`

This includes:

- docker-wrapper Python package
- All dependencies
- hpc-container-manager CLI tool

## Target Naming Convention

- `build-docker-<name>` - Build Docker image
- `test-docker-<name>` - Test Docker image
- `convert-to-apptainer-<name>` - Convert to Apptainer
- `test-apptainer-<name>` - Test Apptainer image
- `build-container-<name>` - Complete workflow (Docker + Apptainer)

## Troubleshooting

### Docker Not Available

```text
CMake Warning: Docker executable not found. Docker build targets will not be available.
```

**Solution**: Install Docker and ensure it's in your PATH.

### Apptainer Not Available

```text
CMake Warning: Apptainer executable not found. Apptainer conversion targets will not be available.
```

**Solution**: Install Apptainer and ensure it's in your PATH.

### Virtual Environment Issues

```bash
# Clean and recreate virtual environment
cmake --build build --target clean-container-venv
cmake --build build --target setup-docker-wrapper
```

### Container Extension Not Found

```bash
# Reconfigure CMake to discover new extensions
cmake -G Ninja -S . -B build
```

## Performance Tips

### Use uv for Faster Installation

Install `uv` for significantly faster Python package installation:

```bash
pip install uv
cmake --build build --target setup-docker-wrapper
```

### Parallel Docker Builds

CMake will automatically use Ninja's parallel build capabilities:

```bash
# Build all containers in parallel
cmake --build build --target build-all-docker-images -j $(nproc)
```

### Docker Build Cache

Docker's build cache is preserved between builds. To force rebuild:

```bash
# Clean and rebuild
cmake --build build --target clean-docker-images
cmake --build build --target build-all-docker-images
```

## Task 020: Docker to Apptainer Conversion Workflow

### Overview

Convert Docker images to Apptainer format for HPC deployment and validate functionality with comprehensive test suites.

### Quick Start

```bash
# 1. Convert single Docker image
./scripts/convert-single.sh pytorch-cuda12.1-mpi4.1:latest

# 2. Convert all Docker images (use CMake target)
cmake --build build --target convert-all-to-apptainer

# 3. Test converted images
./scripts/test-apptainer-local.sh
```

### Conversion Methods

**Single Image Conversion:**

```bash
# Using shell script (recommended)
./scripts/convert-single.sh pytorch-cuda12.1-mpi4.1:latest

# Using HPC CLI
build/containers/venv/bin/hpc-container-manager convert to-apptainer \
  pytorch-cuda12.1-mpi4.1:latest \
  build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif

# Using CMake
cmake --build build --target convert-to-apptainer-pytorch-cuda12.1-mpi4.1
```

**Batch Conversion:**

```bash
# Convert all Docker images to Apptainer
cmake --build build --target convert-all-to-apptainer

# This will automatically:
# - Discover all built Docker images
# - Convert each to Apptainer SIF format
# - Skip already converted images (unless Docker is newer)
```

### Testing Converted Images

**Quick Local Testing:**

```bash
# Test all images
./scripts/test-apptainer-local.sh

# Test specific image
./scripts/test-apptainer-local.sh pytorch-cuda12.1-mpi4.1.sif

# With GPU testing
./scripts/test-apptainer-local.sh --gpu
```

**Comprehensive Test Suites:**

```bash
# Run all test suites
cmake --build build --target test-apptainer-all

# Individual test suites
cmake --build build --target test-converted-images  # Format and functionality
cmake --build build --target test-cuda-apptainer    # CUDA functionality
cmake --build build --target test-mpi-apptainer     # MPI functionality
```

### CMake Targets (Task 020)

**Conversion Workflow Scripts:**

- `convert-single` - Interactive single image conversion
- `test-apptainer-local` - Quick local testing

**Comprehensive Test Suite:**

- `test-converted-images` - Image format and functionality tests
- `test-cuda-apptainer` - CUDA functionality tests
- `test-mpi-apptainer` - MPI functionality tests
- `test-apptainer-all` - Run all test suites

**Complete Workflow:**

```bash
# Build Docker + convert to Apptainer
cmake --build build --target build-container-pytorch-cuda12.1-mpi4.1

# This runs:
# 1. build-docker-pytorch-cuda12.1-mpi4.1
# 2. convert-to-apptainer-pytorch-cuda12.1-mpi4.1
```

### Test Suite Details

**Image Format Tests** (`test-converted-images.sh`):

- SIF format validation
- File system structure
- Python environment
- Package installations
- Library linking
- Container size optimization

**CUDA Tests** (`test-cuda-apptainer.sh`):

- CUDA libraries presence
- CUDA version detection
- PyTorch CUDA build verification
- GPU device detection (requires GPU)
- CUDA tensor operations (requires GPU)
- cuDNN availability

**MPI Tests** (`test-mpi-apptainer.sh`):

- MPI libraries presence
- MPI executables availability
- MPI4Py installation
- Basic MPI functionality
- MPI communication
- Collective operations
- PMIx support

### Documentation

For complete workflow documentation, see:

- [Apptainer Conversion Workflow Guide](../docs/APPTAINER-CONVERSION-WORKFLOW.md)
- Conversion best practices
- Testing strategies
- Troubleshooting guide
- Performance optimization

## Next Steps

- See `tools/cli/hpc-container-manager` for CLI usage
- See `tools/hpc_extensions/` for conversion and deployment utilities
- See `../docs/APPTAINER-CONVERSION-WORKFLOW.md` for detailed workflow
- Task 021: Container Registry Infrastructure & Cluster Deployment
