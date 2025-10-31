# Container Quickstart

**Status:** Production  
**Last Updated:** 2025-10-31  
**Target Time:** 10 minutes  
**Prerequisites:** [Cluster Deployment Quickstart](quickstart-cluster.md) completed

## Overview

Build, convert, and run containerized workloads on SLURM in 10 minutes. This quickstart covers building Docker images,
converting to Apptainer format, and executing containers as SLURM jobs.

**What You'll Do:**

- Build a PyTorch Docker container
- Convert Docker image to Apptainer SIF format
- Deploy container to cluster
- Submit containerized SLURM job
- Run GPU-accelerated container workload

**Why Containers for HPC:**

- **Reproducibility**: Identical environment across nodes
- **Portability**: Same container works everywhere
- **Isolation**: Dependencies don't conflict
- **Performance**: Near-native speed with Apptainer

## Prerequisites Check

Before starting, ensure you have:

```bash
# Verify cluster is running
virsh list | grep running

# Check Docker is available
docker ps

# Verify Apptainer/Singularity
apptainer --version
# or
singularity --version

# Confirm SLURM cluster operational
ssh admin@192.168.190.10 sinfo
```

## Step 1: Build Docker Container (2-3 minutes)

Build a PyTorch container using the project's CMake build system:

```bash
make shell-docker

# Navigate to build directory
cd build

# List available container targets
ninja help | grep "build-docker"

# Build PyTorch container with CUDA and MPI support
ninja build-docker-pytorch-cuda12.1-mpi4.1
```

**Expected Output:**

```text
Building Docker image: pytorch-cuda12.1-mpi4.1:latest
Step 1/15 : FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04
...
Successfully built pytorch-cuda12.1-mpi4.1:latest
Docker image ready: pytorch-cuda12.1-mpi4.1:latest
```

**What's Included:**

- Ubuntu 22.04 base
- CUDA 12.1 with cuDNN
- PyTorch 2.x with GPU support
- OpenMPI 4.1 for distributed training
- Python scientific stack (NumPy, SciPy, pandas)

## Step 2: Verify Docker Image (30 seconds)

```bash
# List built images
docker images | grep pytorch

# Test container locally
docker run --rm pytorch-cuda12.1-mpi4.1:latest python3 -c "import torch; print(torch.__version__)"

# Test CUDA availability (requires GPU on host)
docker run --rm --gpus all pytorch-cuda12.1-mpi4.1:latest \
    python3 -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"
```

**Expected Output:**

```text
pytorch-cuda12.1-mpi4.1   latest    abc123def456   5 minutes ago   8.2GB

2.1.0+cu121
CUDA: True
```

## Step 3: Convert to Apptainer (2 minutes)

Convert Docker image to Apptainer SIF format for HPC deployment:

```bash
# Convert using CMake target
ninja convert-to-apptainer-pytorch-cuda12.1-mpi4.1

# Or use CLI directly
cd ..
source .venv/bin/activate
hpc-container-manager convert to-apptainer \
    pytorch-cuda12.1-mpi4.1:latest \
    build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif
```

**Expected Output:**

```text
Converting pytorch-cuda12.1-mpi4.1 to Apptainer...
INFO:    Starting build...
INFO:    Creating SIF file...
INFO:    Build complete: build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif
Successfully converted to Apptainer format
```

**Note:** Conversion takes ~2 minutes depending on image size. The resulting `.sif` file is a compressed, immutable
container image optimized for HPC.

## Step 4: Test Apptainer Locally (30 seconds)

```bash
# Test basic functionality
apptainer exec build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif \
    python3 --version

# Test PyTorch
apptainer exec build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif \
    python3 -c "import torch; print(f'PyTorch {torch.__version__}')"

# Test with GPU (if available on host)
apptainer exec --nv build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif \
    python3 -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"
```

**Expected Output:**

```text
Python 3.10.12
PyTorch 2.1.0+cu121
CUDA: True
```

## Step 5: Deploy to Cluster (1 minute)

Copy the container to your cluster's shared storage or compute node:

```bash
# Option 1: Using SCP (if no shared storage)
scp build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif \
    admin@192.168.190.10:/opt/containers/

# Option 2: Using Ansible for multiple nodes
ansible hpc_compute_nodes -m copy \
    -a "src=build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif \
        dest=/opt/containers/ mode=0644" \
    -i ansible/inventories/hpc/hosts.yml

# Option 3: If using shared NFS, copy once
sudo mkdir -p /mnt/shared/containers
sudo cp build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif \
    /mnt/shared/containers/
```

**Expected Output:**

```text
pytorch-cuda12.1-mpi4.1.sif   100% 8.2GB   200MB/s   00:41
Container deployed to cluster
```

## Step 6: Create Containerized Job Script (1 minute)

SSH to the controller and create a SLURM job that uses the container:

```bash
# SSH to controller
ssh admin@192.168.190.10

# Create container job script
cat > container-pytorch-job.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=container-pytorch
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=00:10:00
#SBATCH --output=container-pytorch-%j.out

# Path to container image
CONTAINER_PATH="/opt/containers/pytorch-cuda12.1-mpi4.1.sif"

echo "=== Container PyTorch Job ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "Container: $CONTAINER_PATH"
echo

echo "=== Environment Check ==="
apptainer --version
echo

echo "=== PyTorch Version ==="
apptainer exec $CONTAINER_PATH python3 << 'PYTHON'
import torch
import sys

print(f"Python: {sys.version}")
print(f"PyTorch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA version: {torch.version.cuda}")
print(f"cuDNN version: {torch.backends.cudnn.version()}")
PYTHON

echo
echo "=== Simple PyTorch Computation ==="
apptainer exec $CONTAINER_PATH python3 << 'PYTHON'
import torch
import time

# Create random tensors
x = torch.randn(1000, 1000)
y = torch.randn(1000, 1000)

# Matrix multiplication (CPU)
start = time.time()
z = torch.matmul(x, y)
cpu_time = time.time() - start

print(f"Matrix multiplication (1000x1000):")
print(f"  CPU time: {cpu_time:.4f} seconds")
print(f"  Result shape: {z.shape}")
print(f"  Result mean: {z.mean():.4f}")
PYTHON

echo
echo "=== Job completed successfully ==="
EOF

chmod +x container-pytorch-job.sh
```

## Step 7: Submit Containerized Job (30 seconds)

```bash
# Submit the job
sbatch container-pytorch-job.sh

# Monitor job status
squeue

# Wait for completion
sleep 30
watch -n 2 squeue
```

**Expected Output:**

```text
Submitted batch job 3
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST
    3   compute container    admin  R       0:05      1 hpc-compute-01
```

## Step 8: Verify Results (30 seconds)

```bash
# View job output
cat container-pytorch-3.out
```

**Expected Output:**

```text
=== Container PyTorch Job ===
Job ID: 3
Node: hpc-compute-01
Container: /opt/containers/pytorch-cuda12.1-mpi4.1.sif

=== Environment Check ===
apptainer version 1.3.6

=== PyTorch Version ===
Python: 3.10.12
PyTorch: 2.1.0+cu121
CUDA available: False
CUDA version: 12.1
cuDNN version: 8902

=== Simple PyTorch Computation ===
Matrix multiplication (1000x1000):
  CPU time: 0.0234 seconds
  Result shape: torch.Size([1000, 1000])
  Result mean: -0.0123

=== Job completed successfully ===
```

## ✅ Success!

You now have containerized workloads running on SLURM with:

- ✅ Docker image built for PyTorch
- ✅ Container converted to Apptainer format
- ✅ Container deployed to cluster
- ✅ Containerized job executed on SLURM
- ✅ Reproducible environment for ML workloads

## Next Steps

### Run GPU Container Jobs

For GPU-enabled compute nodes, modify the job script:

```bash
cat > container-gpu-job.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=container-gpu
#SBATCH --gres=gpu:1
#SBATCH --partition=gpu
#SBATCH --time=00:10:00

CONTAINER_PATH="/opt/containers/pytorch-cuda12.1-mpi4.1.sif"

# Use --nv flag to enable NVIDIA GPU support
apptainer exec --nv $CONTAINER_PATH python3 << 'PYTHON'
import torch

print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU device: {torch.cuda.get_device_name(0)}")
    print(f"GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")
    
    # Run computation on GPU
    x = torch.randn(5000, 5000).cuda()
    y = torch.randn(5000, 5000).cuda()
    z = torch.matmul(x, y)
    print(f"GPU computation successful: {z.shape}")
PYTHON
EOF

sbatch container-gpu-job.sh
```

### Build Custom Containers

Create your own container definition:

```bash
# Create Dockerfile
cat > containers/images/my-custom-container/Dockerfile << 'EOF'
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

# Install Python and ML libraries
RUN apt-get update && apt-get install -y \
    python3-pip python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install your requirements
RUN pip3 install torch torchvision torchaudio \
    scikit-learn pandas matplotlib seaborn

# Add your code
COPY your_code/ /app/
WORKDIR /app

CMD ["python3", "train.py"]
EOF

# Build with CMake
cd build
ninja build-docker-my-custom-container
ninja convert-to-apptainer-my-custom-container
```

### Multi-Node Distributed Training

See [Distributed Training Tutorial](../tutorials/02-distributed-training.md) for:

- Multi-node PyTorch with MPI
- Distributed data parallel training
- Container orchestration across nodes

### Use NGC Containers

Pull pre-built containers from NVIDIA GPU Cloud:

```bash
# Pull NVIDIA container
apptainer pull docker://nvcr.io/nvidia/pytorch:23.10-py3

# Deploy to cluster
scp pytorch_23.10-py3.sif admin@192.168.190.10:/opt/containers/

# Use in SLURM job
apptainer exec --nv /opt/containers/pytorch_23.10-py3.sif python3 train.py
```

## Container Management

### List Available Containers

```bash
# On controller
ls -lh /opt/containers/

# Check container info
apptainer inspect /opt/containers/pytorch-cuda12.1-mpi4.1.sif
```

### Update Container

```bash
# Rebuild Docker image with changes
cd build
ninja build-docker-pytorch-cuda12.1-mpi4.1

# Reconvert to Apptainer
ninja convert-to-apptainer-pytorch-cuda12.1-mpi4.1

# Redeploy
scp build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif \
    admin@192.168.190.10:/opt/containers/
```

### Container Registry

For production, set up a container registry:

```bash
# Option 1: Local registry on controller
docker run -d -p 5000:5000 --name registry registry:2

# Option 2: Use Harbor (enterprise)
# See: https://goharbor.io/

# Push/pull workflow
docker tag pytorch-cuda12.1-mpi4.1:latest controller:5000/pytorch:latest
docker push controller:5000/pytorch:latest
apptainer pull docker://controller:5000/pytorch:latest
```

## Troubleshooting

### Container Build Fails

**Issue:** Docker build errors or CMake target fails

**Solution:**

```bash
# Check Docker daemon
docker ps

# Rebuild with verbose output
cd containers/images/pytorch-cuda12.1-mpi4.1
docker build -t pytorch-cuda12.1-mpi4.1:latest .

# Check CMake configuration
cd ../../..
cmake -L build | grep CONTAINER
```

### Apptainer Conversion Fails

**Issue:** `apptainer build` fails or produces invalid SIF

**Solution:**

```bash
# Check Apptainer installation
apptainer --version  # Should be 1.3.6+

# Manual conversion with debug output
apptainer build --force \
    build/containers/apptainer/test.sif \
    docker-daemon://pytorch-cuda12.1-mpi4.1:latest

# Check disk space
df -h /tmp  # Apptainer needs temp space
```

### Container Not Found in Job

**Issue:** SLURM job fails with "container not found"

**Solution:**

```bash
# Verify container exists on compute node
ssh admin@192.168.190.131 ls -lh /opt/containers/

# Check file permissions
ssh admin@192.168.190.131 ls -l /opt/containers/*.sif

# Should be readable by job user
sudo chmod 644 /opt/containers/*.sif
```

### GPU Not Available in Container

**Issue:** `torch.cuda.is_available()` returns False in container

**Solution:**

```bash
# Ensure --nv flag is used
apptainer exec --nv container.sif nvidia-smi

# Check NVIDIA drivers visible
apptainer exec --nv container.sif ls /dev/nvidia*

# Verify GPU GRES in SLURM job
#SBATCH --gres=gpu:1
```

For more troubleshooting:

- [Container Troubleshooting Guide](../troubleshooting/common-issues.md)
- [Apptainer Documentation](https://apptainer.org/docs/)
- [Container Workflow Guide](../workflows/APPTAINER-CONVERSION-WORKFLOW.md)

## What's Next?

**Continue with containers:**

- **[Container Management Tutorial](../tutorials/04-container-management.md)** - Advanced container workflows
- **[Distributed Training Tutorial](../tutorials/02-distributed-training.md)** - Multi-node container jobs
- **[Custom Images Tutorial](../tutorials/05-custom-images.md)** - Build your own containers

**Explore the architecture:**

- **[Container Architecture](../architecture/containers.md)** - Container design and integration
- **[SLURM Container Support](../architecture/slurm.md)** - How SLURM manages containers
- **[Build System](../architecture/build-system.md)** - Container build automation

## Summary

In 10 minutes, you've:

1. ✅ Built a PyTorch Docker container with CUDA and MPI
2. ✅ Converted Docker image to Apptainer SIF format
3. ✅ Deployed container to your HPC cluster
4. ✅ Submitted and ran a containerized SLURM job
5. ✅ Verified container execution and results

**Congratulations!** You now have a complete containerized workflow for running reproducible ML workloads on your HPC
cluster with SLURM orchestration.
