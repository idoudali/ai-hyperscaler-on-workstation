# PyTorch CUDA 12.1 + MPI 4.1 Container

**Status:** Production
**Last Updated:** 2025-10-20
**Base Image:** nvidia/cuda:12.1.0-devel-ubuntu22.04

## Overview

This container provides a production-ready PyTorch environment optimized for distributed HPC
workloads with GPU acceleration and MPI support for multi-node training and simulations.

## Purpose

The PyTorch CUDA 12.1 + MPI 4.1 container provides:

- **PyTorch with CUDA Support**: GPU-accelerated deep learning framework
- **CUDA 12.1 Toolkit**: NVIDIA CUDA libraries and development tools
- **MPI 4.1**: Open MPI for distributed computing across nodes
- **Development Tools**: Compilers, debugging tools, and libraries
- **HPC Extensions**: Integration with cluster scheduling and deployment

## Contents

### Base Image

- **OS**: Ubuntu 22.04 (Jammy)
- **NVIDIA CUDA**: 12.1.0 (devel variant with full toolkit)
- **cuDNN**: Latest stable version
- **NCCL**: NVIDIA Collective Communications Library

### Core Libraries

- **PyTorch**: Latest stable with CUDA 12.1 support
- **Open MPI**: 4.1 (OpenMPI)
- **MPI4Py**: Python MPI bindings
- **NumPy, SciPy**: Scientific computing libraries
- **Pandas**: Data analysis framework

### Development Tools

- **GCC/G++**: Full C/C++ development environment
- **CMake**: Build system
- **Git**: Version control
- **Vim, Nano**: Text editors
- **pkg-config**: Library configuration
- **Python Development Headers**: For building extensions

## Building

### Using CMake

```bash
# Build Docker image
cmake --build build --target build-docker-pytorch-cuda12.1-mpi4.1

# Build Apptainer image
cmake --build build --target convert-to-apptainer-pytorch-cuda12.1-mpi4.1

# Build both
cmake --build build --target build-container-pytorch-cuda12.1-mpi4.1
```

### Using CLI

```bash
# Using HPC container manager
hpc-container-manager docker build pytorch-cuda12.1-mpi4.1

# Using Docker directly
docker build -f images/pytorch-cuda12.1-mpi4.1/Docker/Dockerfile \
  -t pytorch-cuda12.1-mpi4.1:latest .
```

### Using Make

```bash
# Build image
make container-build-pytorch-cuda12.1-mpi4.1

# Test image
make container-test-pytorch-cuda12.1-mpi4.1

# Convert to Apptainer
make container-convert-pytorch-cuda12.1-mpi4.1
```

## Usage

### Docker Usage

```bash
# Interactive bash shell
docker run -it --gpus all pytorch-cuda12.1-mpi4.1:latest bash

# Run Python script
docker run --gpus all pytorch-cuda12.1-mpi4.1:latest python script.py

# Mount local directory
docker run -it --gpus all -v /data:/workspace/data \
  pytorch-cuda12.1-mpi4.1:latest bash

# Run with MPI
docker run -it --gpus all --network host \
  pytorch-cuda12.1-mpi4.1:latest mpirun -np 2 python mpi_script.py
```

### Apptainer Usage

```bash
# Interactive shell
apptainer shell --nv pytorch-cuda12.1-mpi4.1.sif

# Execute command
apptainer exec --nv pytorch-cuda12.1-mpi4.1.sif python script.py

# Run with GPU support
apptainer run --nv pytorch-cuda12.1-mpi4.1.sif

# Distributed MPI execution
mpirun -np 4 apptainer exec --nv pytorch-cuda12.1-mpi4.1.sif python script.py
```

### SLURM Job Submission

```bash
#!/bin/bash
#SBATCH --job-name=pytorch-distributed
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --gpus-per-task=1
#SBATCH --partition=gpu

# Load container if needed
module load apptainer

# Run distributed training
srun apptainer exec --nv /opt/containers/pytorch-cuda12.1-mpi4.1.sif \
  python -m torch.distributed.launch \
  --nproc_per_node=4 \
  train_distributed.py
```

## Verification

### Container Contents

```bash
# Check PyTorch installation
docker run pytorch-cuda12.1-mpi4.1:latest python -c \
  "import torch; print(torch.__version__); print(torch.cuda.is_available())"

# Check MPI version
docker run pytorch-cuda12.1-mpi4.1:latest mpirun --version

# Check CUDA version
docker run pytorch-cuda12.1-mpi4.1:latest nvcc --version

# Check GPU access
docker run --gpus all pytorch-cuda12.1-mpi4.1:latest nvidia-smi
```

### Test Suite

```bash
# Run comprehensive tests
cmake --build build --target test-apptainer-pytorch-cuda12.1-mpi4.1

# Run CUDA tests specifically
cmake --build build --target test-cuda-apptainer

# Run MPI tests specifically
cmake --build build --target test-mpi-apptainer
```

## Environment Variables

Key environment variables within the container:

- `CUDA_HOME`: /usr/local/cuda
- `PATH`: Includes CUDA bin and MPI bin
- `LD_LIBRARY_PATH`: Includes CUDA libraries and MPI libraries
- `PYTHONPATH`: Includes site-packages

## Performance Optimization

### GPU Memory

```python
import torch

# Check GPU memory
print(torch.cuda.memory_allocated())
print(torch.cuda.max_memory_allocated())

# Clear cache
torch.cuda.empty_cache()

# Set memory fraction
torch.cuda.set_per_process_memory_fraction(0.9)
```

### MPI Optimization

```bash
# Set MPI environment variables for performance
export OMPI_MCA_btl_openib_ib_pkey=0
export OMPI_MCA_btl_openib_if_include=mlx5_0

# Run with optimized settings
mpirun -np 4 -mca btl_openib_ib_pkey 0 python script.py
```

### Mixed Precision Training

```python
from torch.cuda.amp import autocast, GradScaler

scaler = GradScaler()
with autocast():
    outputs = model(inputs)
    loss = criterion(outputs, targets)

scaler.scale(loss).backward()
scaler.step(optimizer)
scaler.update()
```

## Troubleshooting

### GPU Not Available

```bash
# Verify NVIDIA Docker runtime
docker run --rm --runtime=nvidia nvidia/cuda:12.1.0-base nvidia-smi

# Use --gpus flag instead
docker run --gpus all pytorch-cuda12.1-mpi4.1:latest nvidia-smi
```

### MPI Communication Issues

```bash
# Test MPI connectivity
mpirun -np 2 python -c "from mpi4py import MPI; print(MPI.COMM_WORLD.rank)"

# Enable MPI debugging
export OMPI_MCA_orte_verbose=1
mpirun -np 2 python script.py
```

### Out of Memory Errors

```python
# Reduce batch size
batch_size = 32  # Instead of 64

# Use gradient checkpointing
from torch.utils.checkpoint import checkpoint
output = checkpoint(model, input)

# Use mixed precision
from torch.cuda.amp import autocast
with autocast():
    output = model(input)
```

## Integration with Cluster

### Registry Deployment

```bash
# Push to container registry
docker tag pytorch-cuda12.1-mpi4.1:latest \
  registry.hpc.local:5000/pytorch-cuda12.1-mpi4.1:latest

docker push registry.hpc.local:5000/pytorch-cuda12.1-mpi4.1:latest
```

### Cluster Deployment

```bash
# Deploy to cluster nodes using Ansible
hpc-container-manager deploy to-cluster \
  pytorch-cuda12.1-mpi4.1.sif \
  /opt/containers/pytorch-cuda12.1-mpi4.1.sif \
  --controller hpc-controller.local \
  --user root \
  --sync-nodes
```

### Custom Image Builds

To extend this image with additional packages:

```dockerfile
FROM pytorch-cuda12.1-mpi4.1:latest

# Add custom packages
RUN pip install scipy scikit-learn pandas

# Add custom configuration
COPY config/ /workspace/config/

WORKDIR /workspace
```

## File Locations

Inside the container:

- **Workspace**: `/workspace`
- **Data**: `/workspace/data` (recommended mount point)
- **Models**: `/workspace/models`
- **Scripts**: `/workspace/scripts`
- **Logs**: `/workspace/logs`

## Common Use Cases

### Single-Node Training

```bash
docker run -it --gpus all -v /data:/workspace/data \
  pytorch-cuda12.1-mpi4.1:latest python train.py
```

### Multi-Node Distributed Training

```bash
# On each node
mpirun -np 4 -H node1,node2,node3,node4 \
  docker run -it --gpus all --network host \
  pytorch-cuda12.1-mpi4.1:latest python train_distributed.py
```

### Jupyter Notebook

```bash
docker run -it --gpus all -p 8888:8888 \
  pytorch-cuda12.1-mpi4.1:latest \
  jupyter notebook --ip=0.0.0.0 --no-browser
```

### Interactive Development

```bash
docker run -it --gpus all -v $(pwd):/workspace/src \
  pytorch-cuda12.1-mpi4.1:latest bash
```

## Support

For issues or questions:

- Check logs: Review container output and system logs
- Verify GPU: Ensure GPU drivers and NVIDIA Docker runtime installed
- Test MPI: Run MPI test programs to diagnose communication issues
- Check Memory: Monitor GPU memory usage during execution

## See Also

- **[Container Build System](../../README.md)** - Container build system overview
- **Dockerfile** - Container definition at `images/pytorch-cuda12.1-mpi4.1/Docker/Dockerfile`
- **[PyTorch Docs](https://pytorch.org/docs/)** - PyTorch documentation
- **[OpenMPI Docs](https://www.open-mpi.org/doc/)** - MPI documentation
