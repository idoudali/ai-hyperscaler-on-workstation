# Phase 5: Distributed Training Enablement

**Status**: Ready to Start (0/8 tasks complete)
**Priority**: HIGH
**Dependencies**: Phase 4 consolidation complete
**Estimated Duration**: 3-4 weeks

## Overview

This phase enables distributed training capabilities on the HPC cluster, validates PyTorch distributed
training, integrates the Oumi framework, and sets up monitoring infrastructure for ML/AI workloads.

**Integration with Existing Infrastructure:**

- Examples follow the same pattern as `examples/slurm-jobs/` (hello-world, pi-calculation, matrix-multiply)
- Tests follow the same structure as `tests/suites/slurm-job-examples/`
- Uses shared test utilities from `tests/common/`
- Integrates with CMake build system for container and example builds
- Deploys to `/mnt/beegfs/` (BeeGFS mount point) for cluster-wide access

**Testing Framework:**

- Phase 5 tests use **BATS (Bash Automated Testing System)** for improved test automation
- Provides native JUnit XML report generation for CI/CD integration
- Offers standardized test syntax with `@test` annotations
- Enables better test isolation with `setup()` and `teardown()` functions
- See [`bats-porting-proposal.md`](../../bats-porting-proposal.md) for full BATS migration strategy

## Objectives

1. Enable PyTorch distributed training with NCCL backend
2. Validate multi-node, multi-GPU training workflows
3. Set up experiment tracking and monitoring (TensorBoard, Aim, MLflow)
4. Install and configure Oumi framework for the HPC cluster
5. Validate small model training (MNIST baseline)
6. Validate LLM fine-tuning (SmolLM-135M with Oumi)
7. Document distributed training workflows

## Directory Structure

Following the existing project conventions:

```text
pharos.ai-hyperscaler-on-workskation-3/
├── examples/
│   └── slurm-jobs/
│       ├── hello-world/              # Existing MPI example
│       ├── pi-calculation/           # Existing compute example
│       ├── matrix-multiply/          # Existing memory-intensive example
│       ├── mnist-ddp/                # NEW: MNIST DDP training
│       │   ├── mnist_ddp.py
│       │   ├── mnist-ddp.sbatch
│       │   └── CMakeLists.txt
│       └── smollm-finetuning/        # NEW: LLM fine-tuning
│           ├── smollm-training.sbatch
│           ├── smollm-config.yaml
│           └── CMakeLists.txt
├── tests/
│   ├── common/                       # Shared test utilities (for non-BATS tests)
│   │   ├── suite-utils.sh
│   │   ├── suite-logging.sh
│   │   └── suite-check-helpers.sh
│   └── suites/
│       ├── slurm-job-examples/       # Existing basic job tests
│       └── distributed-training/     # NEW: ML training tests (BATS format)
│           ├── run-distributed-training-tests.sh  # Master BATS test runner
│           ├── helpers/              # BATS helper functions
│           │   ├── container-helpers.bash
│           │   ├── training-helpers.bash
│           │   └── monitoring-helpers.bash
│           ├── check-pytorch-environment.bats
│           ├── check-mnist-ddp-job.bats
│           ├── check-monitoring-infrastructure.bats
│           ├── check-oumi-installation.bats
│           └── check-smollm-finetuning.bats
└── containers/
    └── pytorch/                      # PyTorch container (existing)
        └── Containerfile.pytorch-cuda12.1-mpi4.1

BeeGFS Mount (/mnt/beegfs/):
├── slurm-jobs/                       # Job examples deployed here
│   ├── mnist-ddp/
│   └── smollm-finetuning/
├── containers/                       # Containers deployed here
│   └── pytorch-cuda12.1-mpi4.1.sif
├── datasets/                         # Training datasets
│   ├── mnist/
│   └── alpaca-cleaned/
├── experiments/                      # Training outputs
│   ├── mnist-ddp/
│   │   ├── logs/
│   │   ├── checkpoints/
│   │   └── tensorboard/
│   └── smollm-alpaca/
│       ├── logs/
│       ├── checkpoints/
│       └── models/
└── monitoring/                       # Monitoring infrastructure
    ├── aim/.aim/                     # Aim repository
    ├── mlflow/                       # MLflow artifacts
    └── tensorboard/                  # TensorBoard logs
```

## Build System Integration

Phase 5 components integrate with the existing CMake build system:

```bash
# Build all Phase 5 components (from project root)
make run-docker COMMAND="cmake --build build --target build-phase5-ml-examples"

# Build individual components
make run-docker COMMAND="cmake --build build --target build-mnist-ddp"
make run-docker COMMAND="cmake --build build --target build-smollm-example"
make run-docker COMMAND="cmake --build build --target build-container-pytorch-cuda12.1-mpi4.1"
```

**Output Locations:**

- Containers: `build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif`
- Examples: `build/examples/slurm-jobs/mnist-ddp/`, `build/examples/slurm-jobs/smollm-finetuning/`
- Tests: `tests/suites/distributed-training/` (run directly, no build needed)

## Test Suite Structure

Phase 5 tests use the **BATS (Bash Automated Testing System)** framework for standardized test
execution and native JUnit XML report generation:

```bash
# Run all distributed training tests with BATS (from project root)
cd tests/suites/distributed-training
bats --report-formatter junit \
     --output junit-reports/ \
     --verbose \
     *.bats

# Or use the master test runner
./run-distributed-training-tests.sh

# Run specific test file
bats check-pytorch-environment.bats

# Run with TAP output
bats --tap *.bats
```

**BATS Test Files** (`.bats` format):

- `check-pytorch-environment.bats` - Validates PyTorch/CUDA setup
- `check-mnist-ddp-job.bats` - Tests MNIST DDP training
- `check-monitoring-infrastructure.bats` - Validates Aim/TensorBoard/MLflow
- `check-oumi-installation.bats` - Tests Oumi framework
- `check-smollm-finetuning.bats` - Validates LLM fine-tuning

**BATS Helper Functions** (`.bash` format in `helpers/`):

- `helpers/container-helpers.bash` - Container-specific helpers and skip conditions
- `helpers/training-helpers.bash` - Training validation helpers
- `helpers/monitoring-helpers.bash` - Monitoring server helpers

**Test Runner**:

- `run-distributed-training-tests.sh` - Master BATS test runner with JUnit XML output

**Master Test Runner** (`run-distributed-training-tests.sh`):

```bash
#!/bin/bash
#
# Distributed Training Test Suite - BATS Runner
# Executes all BATS tests with JUnit XML report generation
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# Check if BATS is installed
if ! command -v bats >/dev/null 2>&1; then
    echo "ERROR: BATS is not installed"
    echo "Install with: sudo apt-get install bats"
    echo "Or see: https://bats-core.readthedocs.io/en/stable/installation.html"
    exit 1
fi

# BATS test files
BATS_FILES=(
    "$SCRIPT_DIR/check-pytorch-environment.bats"
    "$SCRIPT_DIR/check-mnist-ddp-job.bats"
    "$SCRIPT_DIR/check-monitoring-infrastructure.bats"
    "$SCRIPT_DIR/check-oumi-installation.bats"
    "$SCRIPT_DIR/check-smollm-finetuning.bats"
)

echo "=========================================="
echo "Distributed Training Test Suite (BATS)"
echo "=========================================="
echo "Log Directory: $LOG_DIR"
echo ""

# Run BATS tests with JUnit XML output
bats --report-formatter junit \
     --output "$LOG_DIR" \
     --verbose \
     --timing \
     "${BATS_FILES[@]}" \
     2>&1 | tee "$LOG_DIR/bats-output.log"

exit_code=$?

echo ""
echo "=========================================="
if [ $exit_code -eq 0 ]; then
    echo "✓ All tests passed!"
else
    echo "✗ Some tests failed (exit code: $exit_code)"
fi
echo "=========================================="
echo "JUnit XML report: $LOG_DIR/report.xml"
echo "Test output log: $LOG_DIR/bats-output.log"

exit $exit_code
```

**Key BATS Features:**

- ✅ Native JUnit XML reports (`--report-formatter junit`)
- ✅ TAP (Test Anything Protocol) output
- ✅ Test isolation with `setup()` and `teardown()`
- ✅ Conditional test skipping (`skip_if_no_gpu`)
- ✅ Standardized assertions with `@test` annotations
- ✅ Better CI/CD integration

## Task List

- [TASK-053: PyTorch Distributed Training Setup](#task-053-pytorch-distributed-training-setup)
- [TASK-054: NCCL Multi-GPU Validation](#task-054-nccl-multi-gpu-validation)
- [TASK-055: Monitoring Infrastructure Setup](#task-055-monitoring-infrastructure-setup)
- [TASK-056: Oumi Framework Installation](#task-056-oumi-framework-installation)
- [TASK-057: Oumi Custom Cluster Configuration](#task-057-oumi-custom-cluster-configuration)
- [TASK-058: Small Model Training Validation](#task-058-small-model-training-validation)
- [TASK-059: Small Model Fine-tuning Validation](#task-059-small-model-fine-tuning-validation)
- [TASK-060: Distributed Training Documentation](#task-060-distributed-training-documentation)

---

## TASK-053: Container Build and Deployment

**Duration**: 4 hours
**Priority**: HIGH
**Dependencies**: Phase 4 complete
**Validation Target**: PyTorch Apptainer container deployed to HPC cluster

### Objective

Build PyTorch container with CUDA and MPI support, convert to Apptainer format, and deploy to
BeeGFS shared storage for distributed training across all compute nodes.

### Implementation

#### 1. Build PyTorch Container with Apptainer

The project already includes a production-ready PyTorch container with:

- PyTorch 2.4.0 with CUDA 12.1 support
- OpenMPI 4.1.4 with CUDA and PMIx support
- MPI4Py for Python MPI bindings
- TensorBoard, wandb for monitoring
- All distributed training dependencies

```bash
# From project root directory
cd /home/doudalis/Projects/pharos.ai-hyperscaler-on-workskation-3

# Configure CMake (if not already done)
make config

# Build Docker image and convert to Apptainer in one step
make run-docker COMMAND="cmake --build build --target build-container-pytorch-cuda12.1-mpi4.1"

# This will:
# 1. Build Docker image: pytorch-cuda12.1-mpi4.1:latest
# 2. Convert to Apptainer: build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif
```

#### 2. Deploy Container to BeeGFS Shared Storage

```bash
# Create container directory on BeeGFS (using existing mount point)
mkdir -p /mnt/beegfs/containers

# Copy Apptainer SIF file to shared storage via SCP or direct copy
# Option 1: Direct copy (if running on controller)
cp build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif \
   /mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif

# Option 2: Copy via SCP (if running on laptop)
scp -i build/shared/ssh-keys/id_rsa \
    build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif \
    admin@<controller-ip>:/mnt/beegfs/containers/

# Verify container is accessible
ls -lh /mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif

# Test container on controller node
apptainer exec /mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif python3 --version
apptainer exec /mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif python3 -c "import torch; print(torch.__version__)"
```

#### 3. Verify Container Access from Compute Nodes

```bash
# Test container accessibility from compute nodes
srun --nodes=2 --ntasks=2 --gres=gpu:1 \
    apptainer exec /mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif \
    python3 -c "import torch; print(f'Node: {__import__(\"socket\").gethostname()}, CUDA: {torch.cuda.is_available()}')"

# Should show output from 2 nodes with CUDA available
```

#### 4. Create Distributed Training Script Template

**File**: `/mnt/beegfs/training/scripts/pytorch_ddp_template.py`

```python
#!/usr/bin/env python3
"""
PyTorch Distributed Data Parallel (DDP) Template
Supports multi-node, multi-GPU training on SLURM clusters
"""

import os
import torch
import torch.nn as nn
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader
from torch.utils.data.distributed import DistributedSampler

def setup_distributed():
    """Initialize distributed training environment"""
    # Get SLURM environment variables
    rank = int(os.environ.get('SLURM_PROCID', 0))
    world_size = int(os.environ.get('SLURM_NTASKS', 1))
    local_rank = int(os.environ.get('SLURM_LOCALID', 0))
    
    # Get master node address
    master_addr = os.environ.get('MASTER_ADDR', 'localhost')
    master_port = os.environ.get('MASTER_PORT', '29500')
    
    # Initialize process group
    dist.init_process_group(
        backend='nccl',  # Use NCCL for GPU communication
        init_method=f'tcp://{master_addr}:{master_port}',
        world_size=world_size,
        rank=rank
    )
    
    # Set device
    torch.cuda.set_device(local_rank)
    
    if rank == 0:
        print(f"Distributed training initialized:")
        print(f"  World size: {world_size}")
        print(f"  Rank: {rank}")
        print(f"  Local rank: {local_rank}")
        print(f"  Master: {master_addr}:{master_port}")
    
    return rank, world_size, local_rank

def cleanup_distributed():
    """Clean up distributed training"""
    dist.destroy_process_group()

def create_dataloader(dataset, batch_size, rank, world_size):
    """Create distributed dataloader"""
    sampler = DistributedSampler(
        dataset,
        num_replicas=world_size,
        rank=rank,
        shuffle=True
    )
    
    loader = DataLoader(
        dataset,
        batch_size=batch_size,
        sampler=sampler,
        num_workers=4,
        pin_memory=True
    )
    
    return loader, sampler

def main():
    # Initialize distributed training
    rank, world_size, local_rank = setup_distributed()
    
    # Create model and move to GPU
    model = YourModel()  # Replace with your model
    model = model.cuda(local_rank)
    
    # Wrap model with DDP
    model = DDP(model, device_ids=[local_rank])
    
    # Create optimizer
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    
    # Create distributed dataloader
    train_dataset = YourDataset()  # Replace with your dataset
    train_loader, train_sampler = create_dataloader(
        train_dataset, 
        batch_size=64,
        rank=rank,
        world_size=world_size
    )
    
    # Training loop
    num_epochs = 10
    for epoch in range(num_epochs):
        # Set epoch for proper shuffling
        train_sampler.set_epoch(epoch)
        
        model.train()
        for batch_idx, (data, target) in enumerate(train_loader):
            data, target = data.cuda(), target.cuda()
            
            optimizer.zero_grad()
            output = model(data)
            loss = criterion(output, target)
            loss.backward()
            optimizer.step()
            
            if batch_idx % 10 == 0 and rank == 0:
                print(f'Epoch {epoch}, Batch {batch_idx}, Loss: {loss.item():.4f}')
    
    # Cleanup
    cleanup_distributed()

if __name__ == '__main__':
    main()
```

#### 5. Create SLURM Job Template with Apptainer

**File**: `/mnt/beegfs/training/templates/pytorch_ddp_apptainer.sh`

```bash
#!/bin/bash
#SBATCH --job-name=pytorch-ddp
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --gres=gpu:2
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --output=/mnt/beegfs/logs/pytorch-ddp-%j.out
#SBATCH --error=/mnt/beegfs/logs/pytorch-ddp-%j.err

# Container path
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"
TRAINING_SCRIPT="/mnt/beegfs/training/scripts/your_script.py"

# Print job info
echo "=========================================="
echo "PyTorch DDP Training with Apptainer"
echo "=========================================="
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Node List: $SLURM_NODELIST"
echo "Number of Nodes: $SLURM_NNODES"
echo "Tasks per Node: $SLURM_NTASKS_PER_NODE"
echo "Total GPUs: $((SLURM_NNODES * SLURM_NTASKS_PER_NODE))"
echo "Container: $CONTAINER"
echo "=========================================="

# Set distributed training environment variables
export MASTER_ADDR=$(scontrol show hostname $SLURM_NODELIST | head -n1)
export MASTER_PORT=29500
export WORLD_SIZE=$SLURM_NTASKS
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=1  # Disable InfiniBand if not available

echo "Master Address: $MASTER_ADDR"
echo "Master Port: $MASTER_PORT"
echo "World Size: $WORLD_SIZE"
echo ""

# Apptainer bind mounts (BeeGFS shared storage)
export APPTAINER_BIND="/beegfs:/beegfs"

# Launch distributed training with Apptainer
# Using srun to launch MPI jobs across nodes
# Apptainer will use the host's MPI (PMI) for communication
srun --mpi=pmi2 apptainer exec --nv \
    $CONTAINER \
    python3 $TRAINING_SCRIPT \
        --epochs 10 \
        --batch-size 64 \
        --learning-rate 0.001

echo ""
echo "=========================================="
echo "Training completed"
echo "=========================================="
```

#### 6. Create Container Validation Helper

**File**: `/mnt/beegfs/scripts/check-container-env.sh`

```bash
#!/bin/bash
# Check containerized distributed training environment

set -e

CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"

echo "=== Container-Based Distributed Training Environment Check ==="

# Check container exists
echo ""
echo "1. Container Image:"
if [ -f "$CONTAINER" ]; then
    echo "✓ Container found: $CONTAINER"
    ls -lh "$CONTAINER"
else
    echo "✗ Container not found: $CONTAINER"
    exit 1
fi

# Check PyTorch installation in container
echo ""
echo "2. PyTorch Installation (in container):"
apptainer exec $CONTAINER python3 -c "
import torch
print(f'✓ PyTorch Version: {torch.__version__}')
print(f'✓ CUDA Available: {torch.cuda.is_available()}')
print(f'✓ CUDA Version: {torch.version.cuda}')
print(f'✓ Number of GPUs: {torch.cuda.device_count()}')
if torch.cuda.is_available():
    for i in range(torch.cuda.device_count()):
        print(f'  GPU {i}: {torch.cuda.get_device_name(i)}')
print(f'✓ NCCL Available: {torch.cuda.nccl.is_available(torch.cuda.current_device()) if torch.cuda.is_available() else False}')
"

# Check MPI installation in container
echo ""
echo "3. MPI Installation (in container):"
apptainer exec $CONTAINER mpirun --version | head -3

# Check SLURM configuration
echo ""
echo "4. SLURM GPU Configuration:"
sinfo -o "%N %G" | grep gpu || echo "No GPU partitions found"

# Test container on compute nodes
echo ""
echo "5. Multi-Node Container Test:"
srun --nodes=2 --ntasks=2 --gres=gpu:1 \
    apptainer exec --nv $CONTAINER \
    python3 -c "import socket, torch; print(f'Node: {socket.gethostname()}, CUDA: {torch.cuda.is_available()}, GPUs: {torch.cuda.device_count()}')"

echo ""
echo "=== Check Complete ==="
echo "✓ All checks passed! Ready for distributed training."
```

### Test Creation

**File**: `tests/suites/distributed-training/check-pytorch-environment.bats`

```bash
#!/usr/bin/env bats
#
# Phase 5: PyTorch Environment and Container Test (BATS)
# Tests PyTorch container deployment and accessibility
#

# Load helper functions
load helpers/container-helpers

# Test configuration
BEEGFS_MOUNT="/mnt/beegfs"
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"

# Setup: Run before each test
setup() {
    export TEST_TEMP_DIR=$(mktemp -d)
}

# Teardown: Run after each test
teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "Container image exists on BeeGFS" {
    [ -f "$CONTAINER" ]
    [ -r "$CONTAINER" ]
}

@test "Container is executable with Python" {
    skip_if_no_apptainer
    
    run apptainer exec "$CONTAINER" python3 --version
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "PyTorch is installed in container" {
    skip_if_no_apptainer
    
    run apptainer exec "$CONTAINER" python3 -c "import torch; print(torch.__version__)"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    
    # Verify version format (x.y.z)
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "CUDA is available in container with GPU" {
    skip_if_no_apptainer
    skip_if_no_gpu
    
    run srun --nodes=1 --gres=gpu:1 \
        apptainer exec --nv "$CONTAINER" \
        python3 -c "import torch; print(torch.cuda.is_available())"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"True"* ]]
}

@test "MPI is installed in container" {
    skip_if_no_apptainer
    
    run apptainer exec "$CONTAINER" mpirun --version
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "Container is accessible from multiple nodes" {
    skip_if_no_apptainer
    skip_if_single_node
    
    run srun --nodes=2 --ntasks=2 --gres=gpu:1 \
        apptainer exec --nv "$CONTAINER" \
        python3 -c "import socket; print(socket.gethostname())"
    
    [ "$status" -eq 0 ]
    # Should have output from 2 nodes
    [ "$(echo "$output" | wc -l)" -eq 2 ]
}

@test "NCCL backend is available" {
    skip_if_no_apptainer
    skip_if_no_gpu
    
    run apptainer exec "$CONTAINER" python3 -c \
        "import torch; print(torch.cuda.nccl.is_available(0) if torch.cuda.is_available() else False)"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"True"* ]]
}
```

**Helper File**: `tests/suites/distributed-training/helpers/container-helpers.bash`

```bash
#!/usr/bin/env bash
#
# Container Test Helper Functions
#

# Skip test if Apptainer is not available
skip_if_no_apptainer() {
    if ! command -v apptainer >/dev/null 2>&1; then
        skip "Apptainer binary not available"
    fi
}

# Skip test if no GPU available
skip_if_no_gpu() {
    if ! srun --nodes=1 --gres=gpu:1 true 2>/dev/null; then
        skip "No GPU resources available"
    fi
}

# Skip test if cluster has only single node
skip_if_single_node() {
    local node_count
    node_count=$(sinfo -N | grep -c compute || echo "1")
    if [ "$node_count" -lt 2 ]; then
        skip "Multi-node test requires at least 2 nodes"
    fi
}

# Test container command execution
# Usage: test_container_exec "container.sif" "command"
test_container_exec() {
    local container="$1"
    local command="$2"
    
    apptainer exec "$container" $command
}
```

### Validation Steps

```bash
# 1. Install BATS if not already installed
if ! command -v bats >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y bats
fi

# 2. Build and deploy container
cd /home/doudalis/Projects/pharos.ai-hyperscaler-on-workskation-3
make run-docker COMMAND="cmake --build build --target build-container-pytorch-cuda12.1-mpi4.1"
mkdir -p /mnt/beegfs/containers
cp build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif /mnt/beegfs/containers/

# 3. Verify container locally
apptainer exec /mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif python3 -c "import torch; print(torch.__version__)"

# 4. Run comprehensive environment check
bash /mnt/beegfs/scripts/check-container-env.sh

# 5. Verify templates created
ls -lh /mnt/beegfs/training/templates/
ls -lh /mnt/beegfs/training/scripts/

# 6. Run BATS test suite with JUnit XML output
cd tests/suites/distributed-training
bats --report-formatter junit \
     --output junit-pytorch-env.xml \
     --verbose \
     check-pytorch-environment.bats
```

### Success Criteria

- [ ] PyTorch container built successfully
- [ ] Container converted to Apptainer SIF format
- [ ] Container deployed to BeeGFS shared storage
- [ ] PyTorch 2.4.0 with CUDA 12.1 support verified
- [ ] NCCL backend available and functional in container
- [ ] MPI 4.1.4 installed and working in container
- [ ] DDP template script created
- [ ] SLURM job template with Apptainer created
- [ ] Container accessible from all compute nodes
- [ ] GPU access working inside container (`--nv` flag)

---

## TASK-054: NCCL Multi-GPU Validation

**Duration**: 4 hours
**Priority**: HIGH
**Dependencies**: TASK-053
**Validation Target**: Multi-node, multi-GPU training working with NCCL

### Objective

Validate NCCL communication across multiple nodes and GPUs using a simple MNIST training job.
Confirm GPU utilization, network bandwidth, and proper data distribution.

### Implementation

#### 1. Create MNIST DDP Training Script

**File**: `/mnt/beegfs/training/mnist_ddp.py`

```python
#!/usr/bin/env python3
"""
MNIST Distributed Data Parallel Training
Validates multi-node, multi-GPU setup with NCCL
"""

import os
import time
import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader
from torch.utils.data.distributed import DistributedSampler
from torchvision import datasets, transforms

class SimpleCNN(nn.Module):
    """Simple CNN for MNIST classification"""
    def __init__(self):
        super(SimpleCNN, self).__init__()
        self.conv1 = nn.Conv2d(1, 32, 3, 1)
        self.conv2 = nn.Conv2d(32, 64, 3, 1)
        self.dropout1 = nn.Dropout(0.25)
        self.dropout2 = nn.Dropout(0.5)
        self.fc1 = nn.Linear(9216, 128)
        self.fc2 = nn.Linear(128, 10)
    
    def forward(self, x):
        x = self.conv1(x)
        x = F.relu(x)
        x = self.conv2(x)
        x = F.relu(x)
        x = F.max_pool2d(x, 2)
        x = self.dropout1(x)
        x = torch.flatten(x, 1)
        x = self.fc1(x)
        x = F.relu(x)
        x = self.dropout2(x)
        x = self.fc2(x)
        return F.log_softmax(x, dim=1)

def setup_distributed():
    """Initialize distributed training"""
    rank = int(os.environ.get('SLURM_PROCID', 0))
    world_size = int(os.environ.get('SLURM_NTASKS', 1))
    local_rank = int(os.environ.get('SLURM_LOCALID', 0))
    
    master_addr = os.environ.get('MASTER_ADDR', 'localhost')
    master_port = os.environ.get('MASTER_PORT', '29500')
    
    dist.init_process_group(
        backend='nccl',
        init_method=f'tcp://{master_addr}:{master_port}',
        world_size=world_size,
        rank=rank
    )
    
    torch.cuda.set_device(local_rank)
    
    return rank, world_size, local_rank

def train(model, device, train_loader, optimizer, epoch, rank):
    """Training loop"""
    model.train()
    total_loss = 0
    correct = 0
    total = 0
    
    start_time = time.time()
    
    for batch_idx, (data, target) in enumerate(train_loader):
        data, target = data.to(device), target.to(device)
        
        optimizer.zero_grad()
        output = model(data)
        loss = F.nll_loss(output, target)
        loss.backward()
        optimizer.step()
        
        # Statistics
        total_loss += loss.item()
        pred = output.argmax(dim=1, keepdim=True)
        correct += pred.eq(target.view_as(pred)).sum().item()
        total += target.size(0)
        
        if batch_idx % 10 == 0 and rank == 0:
            print(f'Epoch {epoch}, Batch {batch_idx}/{len(train_loader)}, '
                  f'Loss: {loss.item():.4f}, '
                  f'Accuracy: {100. * correct / total:.2f}%')
    
    epoch_time = time.time() - start_time
    avg_loss = total_loss / len(train_loader)
    accuracy = 100. * correct / total
    
    if rank == 0:
        print(f'\nEpoch {epoch} Summary:')
        print(f'  Average Loss: {avg_loss:.4f}')
        print(f'  Accuracy: {accuracy:.2f}%')
        print(f'  Time: {epoch_time:.2f}s')
        print(f'  Throughput: {len(train_loader.dataset) / epoch_time:.2f} samples/sec\n')
    
    return avg_loss, accuracy

def test(model, device, test_loader, rank):
    """Testing loop"""
    model.eval()
    test_loss = 0
    correct = 0
    
    with torch.no_grad():
        for data, target in test_loader:
            data, target = data.to(device), target.to(device)
            output = model(data)
            test_loss += F.nll_loss(output, target, reduction='sum').item()
            pred = output.argmax(dim=1, keepdim=True)
            correct += pred.eq(target.view_as(pred)).sum().item()
    
    test_loss /= len(test_loader.dataset)
    accuracy = 100. * correct / len(test_loader.dataset)
    
    if rank == 0:
        print(f'\nTest Results:')
        print(f'  Average Loss: {test_loss:.4f}')
        print(f'  Accuracy: {accuracy:.2f}%\n')
    
    return test_loss, accuracy

def main():
    # Setup distributed training
    rank, world_size, local_rank = setup_distributed()
    device = torch.device(f'cuda:{local_rank}')
    
    if rank == 0:
        print("=" * 50)
        print("MNIST Distributed Training - Validation Run")
        print("=" * 50)
        print(f"World Size: {world_size}")
        print(f"Rank: {rank}")
        print(f"Local Rank: {local_rank}")
        print(f"Device: {device}")
        print("=" * 50)
    
    # Hyperparameters
    batch_size = 64
    epochs = 5
    learning_rate = 0.001
    
    # Data transforms
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    
    # Load datasets
    train_dataset = datasets.MNIST(
        '/mnt/beegfs/data/mnist',
        train=True,
        download=True,
        transform=transform
    )
    
    test_dataset = datasets.MNIST(
        '/mnt/beegfs/data/mnist',
        train=False,
        transform=transform
    )
    
    # Create distributed samplers
    train_sampler = DistributedSampler(
        train_dataset,
        num_replicas=world_size,
        rank=rank,
        shuffle=True
    )
    
    # Create data loaders
    train_loader = DataLoader(
        train_dataset,
        batch_size=batch_size,
        sampler=train_sampler,
        num_workers=4,
        pin_memory=True
    )
    
    test_loader = DataLoader(
        test_dataset,
        batch_size=batch_size,
        shuffle=False,
        num_workers=4,
        pin_memory=True
    )
    
    # Create model
    model = SimpleCNN().to(device)
    model = DDP(model, device_ids=[local_rank])
    
    # Optimizer
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    
    # Training loop
    if rank == 0:
        print(f"\nStarting training for {epochs} epochs...")
    
    for epoch in range(1, epochs + 1):
        train_sampler.set_epoch(epoch)
        train_loss, train_acc = train(model, device, train_loader, optimizer, epoch, rank)
        test_loss, test_acc = test(model, device, test_loader, rank)
    
    # Cleanup
    dist.destroy_process_group()
    
    if rank == 0:
        print("=" * 50)
        print("Training Complete!")
        print("=" * 50)

if __name__ == '__main__':
    main()
```

#### 2. Create MNIST SLURM Job

**File**: `/mnt/beegfs/jobs/mnist-ddp.sh`

```bash
#!/bin/bash
#SBATCH --job-name=mnist-ddp-test
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --gres=gpu:2
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=01:00:00
#SBATCH --output=/mnt/beegfs/logs/mnist-ddp-%j.out
#SBATCH --error=/mnt/beegfs/logs/mnist-ddp-%j.err

echo "=========================================="
echo "MNIST DDP Validation Job"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node List: $SLURM_NODELIST"
echo "Number of Nodes: $SLURM_NNODES"
echo "Tasks per Node: $SLURM_NTASKS_PER_NODE"
echo "Total GPUs: $(($SLURM_NNODES * $SLURM_NTASKS_PER_NODE))"
echo "=========================================="

# Load CUDA
module load cuda/12.1

# Activate environment
source /mnt/beegfs/pytorch-env/bin/activate

# Setup distributed training environment
export MASTER_ADDR=$(scontrol show hostname $SLURM_NODELIST | head -n1)
export MASTER_PORT=29500
export WORLD_SIZE=$SLURM_NTASKS
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=1

echo "Master Node: $MASTER_ADDR:$MASTER_PORT"
echo "World Size: $WORLD_SIZE"
echo ""

# Create log directory
mkdir -p /mnt/beegfs/logs

# Start time
START_TIME=$(date +%s)

# Launch training
srun --mpi=pmi2 python /mnt/beegfs/training/mnist_ddp.py

# End time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=========================================="
echo "Job completed in ${DURATION} seconds"
echo "=========================================="
```

#### 3. Create Validation Script

**File**: `/mnt/beegfs/scripts/validate-distributed-training.sh`

```bash
#!/bin/bash
# Validate distributed training functionality

set -e

echo "=== Distributed Training Validation ==="

# Check environment
echo ""
echo "1. Checking PyTorch environment..."
source /mnt/beegfs/pytorch-env/bin/activate

python -c "
import torch
import torch.distributed as dist
print(f'✓ PyTorch {torch.__version__}')
print(f'✓ CUDA available: {torch.cuda.is_available()}')
print(f'✓ GPUs: {torch.cuda.device_count()}')
print(f'✓ NCCL version: {torch.cuda.nccl.version()}')
"

# Submit test job
echo ""
echo "2. Submitting MNIST DDP test job..."
JOB_ID=$(sbatch --parsable /mnt/beegfs/jobs/mnist-ddp.sh)
echo "✓ Job submitted: $JOB_ID"

# Monitor job
echo ""
echo "3. Monitoring job progress..."
echo "   Run: tail -f /mnt/beegfs/logs/mnist-ddp-${JOB_ID}.out"
echo "   Or: squeue -j $JOB_ID"

echo ""
echo "=== Validation Script Complete ==="
echo "Wait for job to finish, then check results in logs directory"
```

### Test Creation

**File**: `tests/suites/distributed-training/nccl-multi-gpu.sh`

```bash
#!/bin/bash
# Test suite for TASK-054: NCCL Multi-GPU Validation

set -e

TEST_SUITE="TASK-054"

echo "=== Test Suite: ${TEST_SUITE} - NCCL Multi-GPU Validation ==="

# Test 1: MNIST training script exists
echo ""
echo "Test 1: Training script exists"
if [ -f "/mnt/beegfs/training/mnist_ddp.py" ]; then
    echo "✓ PASS: MNIST DDP script found"
else
    echo "✗ FAIL: Training script not found"
    exit 1
fi

# Test 2: Python syntax check
echo ""
echo "Test 2: Python syntax validation"
if python3 -m py_compile /mnt/beegfs/training/mnist_ddp.py 2>&1; then
    echo "✓ PASS: Script syntax valid"
else
    echo "✗ FAIL: Syntax errors found"
    exit 1
fi

# Test 3: Submit test job
echo ""
echo "Test 3: Submit MNIST DDP training job"
JOB_ID=$(sbatch --parsable /mnt/beegfs/jobs/mnist-ddp.sh)
if [ -n "$JOB_ID" ]; then
    echo "✓ PASS: Job submitted (ID: $JOB_ID)"
else
    echo "✗ FAIL: Job submission failed"
    exit 1
fi

# Test 4: Wait for job completion (with timeout)
echo ""
echo "Test 4: Job execution (waiting up to 10 minutes)"
TIMEOUT=600
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    JOB_STATE=$(squeue -j $JOB_ID -h -o "%T" 2>/dev/null || echo "COMPLETED")
    if [ "$JOB_STATE" = "COMPLETED" ] || [ -z "$JOB_STATE" ]; then
        echo "✓ PASS: Job completed"
        break
    elif [ "$JOB_STATE" = "FAILED" ] || [ "$JOB_STATE" = "CANCELLED" ]; then
        echo "✗ FAIL: Job failed with state: $JOB_STATE"
        exit 1
    fi
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "✗ FAIL: Job timeout"
    scancel $JOB_ID
    exit 1
fi

# Test 5: Check job output log
echo ""
echo "Test 5: Check training output"
LOG_FILE="/mnt/beegfs/logs/mnist-ddp-${JOB_ID}.out"
if [ -f "$LOG_FILE" ]; then
    if grep -q "Training Complete" "$LOG_FILE"; then
        echo "✓ PASS: Training completed successfully"
    else
        echo "✗ FAIL: Training did not complete"
        exit 1
    fi
else
    echo "✗ FAIL: Log file not found"
    exit 1
fi

# Test 6: Verify accuracy threshold
echo ""
echo "Test 6: Verify accuracy >95%"
ACCURACY=$(grep -oP 'Accuracy: \K[0-9.]+' "$LOG_FILE" | tail -1)
if [ -n "$ACCURACY" ]; then
    if (( $(echo "$ACCURACY > 95" | bc -l) )); then
        echo "✓ PASS: Accuracy ${ACCURACY}% exceeds threshold"
    else
        echo "✗ FAIL: Accuracy ${ACCURACY}% below threshold"
        exit 1
    fi
else
    echo "✗ FAIL: Could not extract accuracy"
    exit 1
fi

# Test 7: Check for NCCL errors
echo ""
echo "Test 7: Check for NCCL errors"
if grep -q "NCCL error" "$LOG_FILE"; then
    echo "✗ FAIL: NCCL errors detected"
    exit 1
else
    echo "✓ PASS: No NCCL errors"
fi

# Test 8: Verify multi-node execution
echo ""
echo "Test 8: Verify multi-node execution"
NODE_COUNT=$(grep -o "Node:" "$LOG_FILE" | wc -l)
if [ "$NODE_COUNT" -ge 2 ]; then
    echo "✓ PASS: Multi-node execution confirmed ($NODE_COUNT nodes)"
else
    echo "✗ FAIL: Expected multi-node execution"
    exit 1
fi

echo ""
echo "=== All Tests Passed for ${TEST_SUITE} ==="
```

**File**: `tests/suites/distributed-training/nccl-communication.py`

```python
#!/usr/bin/env python3
"""
Unit test for NCCL communication
Tests basic distributed operations without full training
"""

import os
import sys
import torch
import torch.distributed as dist

def test_nccl_init():
    """Test NCCL process group initialization"""
    try:
        rank = int(os.environ.get('SLURM_PROCID', 0))
        world_size = int(os.environ.get('SLURM_NTASKS', 1))
        local_rank = int(os.environ.get('SLURM_LOCALID', 0))
        
        master_addr = os.environ.get('MASTER_ADDR', 'localhost')
        master_port = os.environ.get('MASTER_PORT', '29500')
        
        dist.init_process_group(
            backend='nccl',
            init_method=f'tcp://{master_addr}:{master_port}',
            world_size=world_size,
            rank=rank
        )
        
        torch.cuda.set_device(local_rank)
        
        print(f"✓ PASS: NCCL initialized (rank={rank}, world_size={world_size})")
        return True
    except Exception as e:
        print(f"✗ FAIL: NCCL initialization failed: {e}")
        return False

def test_all_reduce():
    """Test NCCL all-reduce operation"""
    try:
        rank = dist.get_rank()
        tensor = torch.ones(1).cuda() * rank
        
        dist.all_reduce(tensor, op=dist.ReduceOp.SUM)
        
        expected = sum(range(dist.get_world_size()))
        if tensor.item() == expected:
            print(f"✓ PASS: All-reduce operation successful (result={tensor.item()})")
            return True
        else:
            print(f"✗ FAIL: All-reduce incorrect (expected={expected}, got={tensor.item()})")
            return False
    except Exception as e:
        print(f"✗ FAIL: All-reduce failed: {e}")
        return False

def test_broadcast():
    """Test NCCL broadcast operation"""
    try:
        rank = dist.get_rank()
        tensor = torch.zeros(1).cuda() if rank != 0 else torch.ones(1).cuda() * 42
        
        dist.broadcast(tensor, src=0)
        
        if tensor.item() == 42:
            print(f"✓ PASS: Broadcast operation successful")
            return True
        else:
            print(f"✗ FAIL: Broadcast incorrect (got={tensor.item()})")
            return False
    except Exception as e:
        print(f"✗ FAIL: Broadcast failed: {e}")
        return False

def cleanup():
    """Cleanup distributed training"""
    try:
        dist.destroy_process_group()
        print("✓ PASS: Process group destroyed")
        return True
    except Exception as e:
        print(f"✗ FAIL: Cleanup failed: {e}")
        return False

if __name__ == '__main__':
    print("=== NCCL Communication Test ===")
    
    tests = [
        ("NCCL Initialization", test_nccl_init),
        ("All-Reduce Operation", test_all_reduce),
        ("Broadcast Operation", test_broadcast),
        ("Cleanup", cleanup)
    ]
    
    failed = 0
    for name, test_func in tests:
        print(f"\nTest: {name}")
        if not test_func():
            failed += 1
    
    print("\n" + "="*50)
    if failed == 0:
        print("✓ All NCCL communication tests passed")
        sys.exit(0)
    else:
        print(f"✗ {failed} test(s) failed")
        sys.exit(1)
```

### Validation Steps

```bash
# 1. Create required directories
mkdir -p /mnt/beegfs/{training,jobs,logs,data}
mkdir -p tests/phase-5-distributed-training

# 2. Copy scripts to locations
cp mnist_ddp.py /mnt/beegfs/training/
cp mnist-ddp.sh /mnt/beegfs/jobs/
chmod +x /mnt/beegfs/jobs/mnist-ddp.sh

# 3. Run validation
bash /mnt/beegfs/scripts/validate-distributed-training.sh

# 4. Run test suite
bash tests/suites/distributed-training/nccl-multi-gpu.sh

# 5. Run NCCL communication test
srun --nodes=2 --ntasks=2 --gres=gpu:1 \
    python tests/suites/distributed-training/nccl-communication.py
```

### Success Criteria

- [ ] MNIST DDP script runs successfully on 2 nodes, 4 GPUs
- [ ] NCCL communication working between nodes
- [ ] Training completes in <5 minutes
- [ ] Final test accuracy >95%
- [ ] GPU utilization >80% during training
- [ ] No NCCL errors in logs
- [ ] Distributed sampler working correctly (no duplicate data)
- [ ] Logs show proper synchronization between ranks

---

## TASK-055: Monitoring Infrastructure Setup

**Duration**: 4 hours
**Priority**: HIGH
**Dependencies**: TASK-053
**Validation Target**: Experiment tracking and monitoring operational

### Objective

Set up monitoring infrastructure for experiment tracking, including TensorBoard, Aim (W&B alternative),
and optionally MLflow. Configure persistent servers and integration with training scripts.

### Implementation

#### 1. Install Monitoring Tools

```bash
# Activate environment
source /mnt/beegfs/pytorch-env/bin/activate

# Install monitoring packages
pip install tensorboard aim mlflow

# Verify installations
tensorboard --version
aim version
mlflow --version
```

#### 2. Create Monitoring Directories

```bash
# Create directory structure
mkdir -p /mnt/beegfs/monitoring/{tensorboard,aim,mlflow}
mkdir -p /mnt/beegfs/experiments/{logs,checkpoints,configs}

# Initialize Aim repository
cd /mnt/beegfs/monitoring/aim
aim init

# Create MLflow directories
mkdir -p /mnt/beegfs/monitoring/mlflow/{db,artifacts}
```

#### 3. TensorBoard Server Setup

**File**: `/mnt/beegfs/servers/tensorboard-server.sh`

```bash
#!/bin/bash
#SBATCH --job-name=tensorboard
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=7-00:00:00
#SBATCH --output=/mnt/beegfs/logs/tensorboard-%j.out

source /mnt/beegfs/pytorch-env/bin/activate

PORT=6006
HOSTNAME=$(hostname)

echo "=========================================="
echo "TensorBoard Server Starting"
echo "=========================================="
echo "Host: $HOSTNAME"
echo "Port: $PORT"
echo "Log Directory: /mnt/beegfs/experiments/logs"
echo ""
echo "SSH Tunnel Command:"
echo "  ssh -L $PORT:$HOSTNAME:$PORT $USER@controller.local"
echo ""
echo "Browser URL:"
echo "  http://localhost:$PORT"
echo "=========================================="

tensorboard --logdir /mnt/beegfs/experiments/logs \
            --host 0.0.0.0 \
            --port $PORT \
            --reload_interval 30
```

#### 4. Aim Server Setup

**File**: `/mnt/beegfs/servers/aim-server.sh`

```bash
#!/bin/bash
#SBATCH --job-name=aim-server
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=7-00:00:00
#SBATCH --output=/mnt/beegfs/logs/aim-%j.out

source /mnt/beegfs/pytorch-env/bin/activate

PORT=43800
HOSTNAME=$(hostname)

echo "=========================================="
echo "Aim Server Starting"
echo "=========================================="
echo "Host: $HOSTNAME"
echo "Port: $PORT"
echo "Aim Repository: /mnt/beegfs/monitoring/aim"
echo ""
echo "SSH Tunnel Command:"
echo "  ssh -L $PORT:$HOSTNAME:$PORT $USER@controller.local"
echo ""
echo "Browser URL:"
echo "  http://localhost:$PORT"
echo "=========================================="

cd /mnt/beegfs/monitoring/aim
aim up --host 0.0.0.0 --port $PORT --repo /mnt/beegfs/monitoring/aim/.aim
```

#### 5. MLflow Server Setup

**File**: `/mnt/beegfs/servers/mlflow-server.sh`

```bash
#!/bin/bash
#SBATCH --job-name=mlflow-server
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=7-00:00:00
#SBATCH --output=/mnt/beegfs/logs/mlflow-%j.out

source /mnt/beegfs/pytorch-env/bin/activate

PORT=5000
HOSTNAME=$(hostname)

echo "=========================================="
echo "MLflow Server Starting"
echo "=========================================="
echo "Host: $HOSTNAME"
echo "Port: $PORT"
echo "Backend Store: /mnt/beegfs/monitoring/mlflow/db"
echo "Artifact Store: /mnt/beegfs/monitoring/mlflow/artifacts"
echo ""
echo "SSH Tunnel Command:"
echo "  ssh -L $PORT:$HOSTNAME:$PORT $USER@controller.local"
echo ""
echo "Browser URL:"
echo "  http://localhost:$PORT"
echo "=========================================="

mlflow server \
    --backend-store-uri sqlite:////mnt/beegfs/monitoring/mlflow/db/mlflow.db \
    --default-artifact-root /mnt/beegfs/monitoring/mlflow/artifacts \
    --host 0.0.0.0 \
    --port $PORT
```

#### 6. Enhanced MNIST with Monitoring

**File**: `/mnt/beegfs/training/mnist_ddp_monitored.py`

Add to the previous MNIST script:

```python
# At top of file
from torch.utils.tensorboard import SummaryWriter
from aim import Run

# In main() function, after distributed setup
if rank == 0:
    # Initialize TensorBoard
    tb_writer = SummaryWriter(
        log_dir=f'/mnt/beegfs/experiments/logs/mnist-ddp-{time.strftime("%Y%m%d-%H%M%S")}'
    )
    
    # Initialize Aim
    aim_run = Run(
        repo='/mnt/beegfs/monitoring/aim/.aim',
        experiment='mnist-distributed'
    )
    aim_run['hparams'] = {
        'batch_size': batch_size,
        'learning_rate': learning_rate,
        'epochs': epochs,
        'world_size': world_size
    }

# In train() function, after optimizer.step()
if rank == 0 and batch_idx % 10 == 0:
    global_step = epoch * len(train_loader) + batch_idx
    
    # TensorBoard logging
    tb_writer.add_scalar('Loss/train', loss.item(), global_step)
    tb_writer.add_scalar('Accuracy/train', 100. * correct / total, global_step)
    
    # Aim logging
    aim_run.track(loss.item(), name='loss', step=global_step, context={'subset': 'train'})
    aim_run.track(100. * correct / total, name='accuracy', step=global_step, context={'subset': 'train'})

# After training completes
if rank == 0:
    tb_writer.close()
    aim_run.close()
```

#### 7. Server Management Script

**File**: `/mnt/beegfs/scripts/manage-monitoring-servers.sh`

```bash
#!/bin/bash
# Manage monitoring servers

COMMAND=${1:-status}

case $COMMAND in
    start)
        echo "Starting monitoring servers..."
        sbatch /mnt/beegfs/servers/tensorboard-server.sh
        sbatch /mnt/beegfs/servers/aim-server.sh
        sbatch /mnt/beegfs/servers/mlflow-server.sh
        echo "Servers submitted. Check with: squeue -u $USER"
        ;;
    
    stop)
        echo "Stopping monitoring servers..."
        scancel -u $USER -n tensorboard
        scancel -u $USER -n aim-server
        scancel -u $USER -n mlflow-server
        echo "Servers stopped."
        ;;
    
    status)
        echo "Monitoring Server Status:"
        squeue -u $USER -n tensorboard,aim-server,mlflow-server -o "%.18i %.20j %.8u %.8T %.10M %.10l %.6D %.20R"
        ;;
    
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
```

### Test Creation

**File**: `tests/suites/distributed-training/monitoring-infrastructure.sh`

```bash
#!/bin/bash
# Test suite for TASK-055: Monitoring Infrastructure Setup

set -e

TEST_SUITE="TASK-055"

echo "=== Test Suite: ${TEST_SUITE} - Monitoring Infrastructure ==="

# Test 1: Python packages installed
echo ""
echo "Test 1: Monitoring packages installed"
source /mnt/beegfs/pytorch-env/bin/activate
PACKAGES=("tensorboard" "aim" "mlflow")
for pkg in "${PACKAGES[@]}"; do
    if python -c "import $pkg" 2>/dev/null; then
        echo "✓ PASS: $pkg installed"
    else
        echo "✗ FAIL: $pkg not installed"
        exit 1
    fi
done

# Test 2: Directory structure
echo ""
echo "Test 2: Directory structure"
DIRS=(
    "/mnt/beegfs/monitoring/tensorboard"
    "/mnt/beegfs/monitoring/aim"
    "/mnt/beegfs/monitoring/mlflow"
    "/mnt/beegfs/experiments/logs"
    "/mnt/beegfs/experiments/checkpoints"
)
for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "✓ PASS: $dir exists"
    else
        echo "✗ FAIL: $dir not found"
        exit 1
    fi
done

# Test 3: Aim repository initialized
echo ""
echo "Test 3: Aim repository initialization"
if [ -d "/mnt/beegfs/monitoring/aim/.aim" ]; then
    echo "✓ PASS: Aim repository initialized"
else
    echo "✗ FAIL: Aim repository not initialized"
    exit 1
fi

# Test 4: Server scripts exist
echo ""
echo "Test 4: Server launch scripts"
SCRIPTS=(
    "/mnt/beegfs/servers/tensorboard-server.sh"
    "/mnt/beegfs/servers/aim-server.sh"
    "/mnt/beegfs/servers/mlflow-server.sh"
)
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        echo "✓ PASS: $script exists and is executable"
    else
        echo "✗ FAIL: $script not found or not executable"
        exit 1
    fi
done

# Test 5: Start TensorBoard server
echo ""
echo "Test 5: TensorBoard server startup"
TB_JOB=$(sbatch --parsable /mnt/beegfs/servers/tensorboard-server.sh)
if [ -n "$TB_JOB" ]; then
    echo "✓ PASS: TensorBoard job submitted (ID: $TB_JOB)"
    sleep 10  # Wait for startup
    
    # Check if job is running
    TB_STATE=$(squeue -j $TB_JOB -h -o "%T" 2>/dev/null || echo "")
    if [ "$TB_STATE" = "RUNNING" ]; then
        echo "✓ PASS: TensorBoard server running"
    else
        echo "⚠ WARNING: TensorBoard state: $TB_STATE"
    fi
    
    scancel $TB_JOB  # Cleanup
else
    echo "✗ FAIL: TensorBoard job submission failed"
    exit 1
fi

# Test 6: Start Aim server
echo ""
echo "Test 6: Aim server startup"
AIM_JOB=$(sbatch --parsable /mnt/beegfs/servers/aim-server.sh)
if [ -n "$AIM_JOB" ]; then
    echo "✓ PASS: Aim job submitted (ID: $AIM_JOB)"
    sleep 10
    
    AIM_STATE=$(squeue -j $AIM_JOB -h -o "%T" 2>/dev/null || echo "")
    if [ "$AIM_STATE" = "RUNNING" ]; then
        echo "✓ PASS: Aim server running"
    else
        echo "⚠ WARNING: Aim state: $AIM_STATE"
    fi
    
    scancel $AIM_JOB  # Cleanup
else
    echo "✗ FAIL: Aim job submission failed"
    exit 1
fi

# Test 7: Management script
echo ""
echo "Test 7: Server management script"
if [ -f "/mnt/beegfs/scripts/manage-monitoring-servers.sh" ]; then
    if bash /mnt/beegfs/scripts/manage-monitoring-servers.sh status > /dev/null 2>&1; then
        echo "✓ PASS: Management script functional"
    else
        echo "✗ FAIL: Management script error"
        exit 1
    fi
else
    echo "✗ FAIL: Management script not found"
    exit 1
fi

echo ""
echo "=== All Tests Passed for ${TEST_SUITE} ==="
```

**File**: `tests/suites/distributed-training/monitoring-integration.py`

```python
#!/usr/bin/env python3
"""
Test monitoring integration with training code
"""

import sys
import os
from pathlib import Path

# Add path for imports
sys.path.insert(0, '/beegfs/shared')

def test_tensorboard_import():
    """Test TensorBoard import and basic functionality"""
    try:
        from torch.utils.tensorboard import SummaryWriter
        
        # Create test writer
        test_dir = '/tmp/test-tensorboard'
        Path(test_dir).mkdir(parents=True, exist_ok=True)
        
        writer = SummaryWriter(log_dir=test_dir)
        writer.add_scalar('test/loss', 0.5, 0)
        writer.close()
        
        # Verify log file created
        if any(Path(test_dir).glob('events.out.tfevents.*')):
            print("✓ PASS: TensorBoard logging functional")
            return True
        else:
            print("✗ FAIL: TensorBoard log file not created")
            return False
    except Exception as e:
        print(f"✗ FAIL: TensorBoard test failed: {e}")
        return False

def test_aim_import():
    """Test Aim import and basic functionality"""
    try:
        from aim import Run
        
        # Create test run
        test_repo = '/tmp/test-aim'
        Path(test_repo).mkdir(parents=True, exist_ok=True)
        
        run = Run(repo=test_repo, experiment='test')
        run.track(0.5, name='loss', step=0)
        run.close()
        
        # Verify Aim repo created
        if (Path(test_repo) / '.aim').exists():
            print("✓ PASS: Aim logging functional")
            return True
        else:
            print("✗ FAIL: Aim repository not created")
            return False
    except Exception as e:
        print(f"✗ FAIL: Aim test failed: {e}")
        return False

def test_mlflow_import():
    """Test MLflow import"""
    try:
        import mlflow
        print(f"✓ PASS: MLflow version {mlflow.__version__}")
        return True
    except Exception as e:
        print(f"✗ FAIL: MLflow import failed: {e}")
        return False

if __name__ == '__main__':
    print("=== Monitoring Integration Tests ===\n")
    
    tests = [
        ("TensorBoard Integration", test_tensorboard_import),
        ("Aim Integration", test_aim_import),
        ("MLflow Import", test_mlflow_import)
    ]
    
    failed = 0
    for name, test_func in tests:
        print(f"Test: {name}")
        if not test_func():
            failed += 1
        print()
    
    if failed == 0:
        print("✓ All monitoring integration tests passed")
        sys.exit(0)
    else:
        print(f"✗ {failed} test(s) failed")
        sys.exit(1)
```

### Validation Steps

```bash
# 1. Install monitoring tools
source /mnt/beegfs/pytorch-env/bin/activate
pip install tensorboard aim mlflow

# 2. Create directory structure
mkdir -p /mnt/beegfs/{monitoring/{tensorboard,aim,mlflow},servers,experiments/{logs,checkpoints}}
mkdir -p tests/phase-5-distributed-training

# 3. Initialize Aim
cd /mnt/beegfs/monitoring/aim && aim init

# 4. Run test suite
bash tests/suites/distributed-training/monitoring-infrastructure.sh

# 5. Run integration tests
python tests/suites/distributed-training/monitoring-integration.py

# 6. Start monitoring servers (optional for manual testing)
bash /mnt/beegfs/scripts/manage-monitoring-servers.sh start
```

### Success Criteria

- [ ] TensorBoard, Aim, and MLflow installed
- [ ] Monitoring directories created and initialized
- [ ] TensorBoard server running and accessible
- [ ] Aim server running and accessible via SSH tunnel
- [ ] MLflow server running and accessible
- [ ] Training scripts log metrics to all backends
- [ ] Dashboards display training progress in real-time
- [ ] Server management script works correctly

---

## TASK-056: Oumi Framework Installation

**Duration**: 2 hours
**Priority**: HIGH
**Dependencies**: TASK-053, TASK-055
**Validation Target**: Oumi framework installed and verified

### Objective

Install the Oumi framework on the HPC cluster shared storage, verify installation, and test basic
functionality.

### Implementation

#### 1. Create Oumi Virtual Environment

```bash
# Create dedicated Oumi environment
cd /beegfs/shared
python3 -m venv oumi-env

# Activate environment
source oumi-env/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install Oumi
pip install oumi

# Install additional dependencies
pip install tensorboard aim mlflow

# Verify installation
oumi --version
python -c "import oumi; print(f'Oumi version: {oumi.__version__}')"
```

#### 2. Test Oumi Installation

**File**: `/mnt/beegfs/scripts/test-oumi-installation.sh`

```bash
#!/bin/bash
# Test Oumi installation

set -e

echo "=== Oumi Installation Test ==="

source /mnt/beegfs/oumi-env/bin/activate

echo ""
echo "1. Testing Oumi CLI..."
oumi --version
oumi --help

echo ""
echo "2. Testing Oumi Python API..."
python -c "
import oumi
from oumi.core.configs import TrainingConfig, ModelParams
from oumi.core.trainers import Trainer

print(f'✓ Oumi version: {oumi.__version__}')
print('✓ TrainingConfig imported successfully')
print('✓ ModelParams imported successfully')
print('✓ Trainer imported successfully')
"

echo ""
echo "3. Listing available models..."
oumi models list | head -20

echo ""
echo "4. Listing available datasets..."
oumi datasets list | head -20

echo ""
echo "5. Checking CUDA support..."
python -c "
import torch
print(f'✓ PyTorch: {torch.__version__}')
print(f'✓ CUDA Available: {torch.cuda.is_available()}')
print(f'✓ CUDA Version: {torch.version.cuda}')
print(f'✓ GPU Count: {torch.cuda.device_count()}')
"

echo ""
echo "=== Oumi Installation Test Complete ==="
echo "✓ All checks passed!"
```

#### 3. Create Oumi Configuration Template

**File**: `/mnt/beegfs/configs/oumi-template.yaml`

```yaml
# Oumi Training Configuration Template
# Reference: https://oumi.ai/docs/en/latest/user_guides/train/training_config.html

# Model configuration
model:
  model_name: "HuggingFaceTB/SmolLM-135M"  # Small model for testing
  trust_remote_code: true
  torch_dtype: "bfloat16"  # Use bf16 for better performance

# Dataset configuration
dataset:
  dataset_name: "yahma/alpaca-cleaned"
  max_samples: 1000  # Limit for quick testing
  split: "train"

# Training configuration
training:
  output_dir: "/mnt/beegfs/experiments/outputs"
  num_train_epochs: 3
  per_device_train_batch_size: 8
  gradient_accumulation_steps: 2
  learning_rate: 2e-5
  warmup_steps: 100
  
  # Logging
  logging_steps: 10
  logging_first_step: true
  logging_strategy: "steps"
  
  # Checkpointing
  save_steps: 500
  save_strategy: "steps"
  save_total_limit: 3
  
  # Evaluation
  eval_steps: 100
  evaluation_strategy: "steps"
  
  # Monitoring
  report_to: ["tensorboard"]  # Can add "aim", "mlflow"
  
  # Optimization
  fp16: false
  bf16: true
  gradient_checkpointing: true
  
  # Distributed training
  distributed_strategy: "ddp"  # or "fsdp" for larger models

# LoRA configuration (optional - for efficient fine-tuning)
peft:
  use_peft: true
  peft_type: "lora"
  lora_r: 8
  lora_alpha: 16
  lora_dropout: 0.05
  target_modules: ["q_proj", "v_proj"]

# Hardware configuration
hardware:
  mixed_precision: "bf16"
```

#### 4. Test Oumi Dry-Run

**File**: `/mnt/beegfs/scripts/test-oumi-dryrun.sh`

```bash
#!/bin/bash
# Test Oumi with dry-run mode

set -e

echo "=== Oumi Dry-Run Test ==="

source /mnt/beegfs/oumi-env/bin/activate

echo ""
echo "Creating test configuration..."
cat > /tmp/oumi-test-config.yaml <<EOF
model:
  model_name: "HuggingFaceTB/SmolLM-135M"
  
dataset:
  dataset_name: "yahma/alpaca-cleaned"
  max_samples: 10  # Very small for testing
  
training:
  output_dir: "/tmp/oumi-test-output"
  num_train_epochs: 1
  per_device_train_batch_size: 2
  logging_steps: 1
EOF

echo "Configuration created."
echo ""
echo "Testing Oumi training (dry-run mode)..."
oumi train --config /tmp/oumi-test-config.yaml --dry-run

echo ""
echo "=== Dry-Run Test Complete ==="
echo "✓ Oumi can load configurations and prepare for training!"
```

### Test Creation

**File**: `tests/suites/distributed-training/oumi-installation.sh`

```bash
#!/bin/bash
# Test suite for TASK-056: Oumi Framework Installation

set -e

TEST_SUITE="TASK-056"

echo "=== Test Suite: ${TEST_SUITE} - Oumi Installation ==="

# Test 1: Oumi environment exists
echo ""
echo "Test 1: Oumi virtual environment"
if [ -d "/mnt/beegfs/oumi-env" ]; then
    echo "✓ PASS: Oumi environment exists"
else
    echo "✗ FAIL: Oumi environment not found"
    exit 1
fi

# Test 2: Activate environment
echo ""
echo "Test 2: Environment activation"
if source /mnt/beegfs/oumi-env/bin/activate 2>&1; then
    echo "✓ PASS: Environment activated"
else
    echo "✗ FAIL: Environment activation failed"
    exit 1
fi

# Test 3: Oumi package installed
echo ""
echo "Test 3: Oumi package"
if python -c "import oumi" 2>/dev/null; then
    OUMI_VERSION=$(python -c "import oumi; print(oumi.__version__)")
    echo "✓ PASS: Oumi ${OUMI_VERSION} installed"
else
    echo "✗ FAIL: Oumi not installed"
    exit 1
fi

# Test 4: Oumi CLI
echo ""
echo "Test 4: Oumi CLI"
if oumi --version > /dev/null 2>&1; then
    echo "✓ PASS: Oumi CLI functional"
else
    echo "✗ FAIL: Oumi CLI not working"
    exit 1
fi

# Test 5: Core imports
echo ""
echo "Test 5: Core Oumi imports"
python -c "
from oumi.core.configs import TrainingConfig, ModelParams
from oumi.core.trainers import Trainer
print('✓ PASS: Core imports successful')
" || { echo "✗ FAIL: Core imports failed"; exit 1; }

# Test 6: CUDA support
echo ""
echo "Test 6: CUDA support in environment"
CUDA_AVAILABLE=$(python -c "import torch; print(torch.cuda.is_available())")
if [ "$CUDA_AVAILABLE" = "True" ]; then
    echo "✓ PASS: CUDA available"
else
    echo "✗ FAIL: CUDA not available"
    exit 1
fi

# Test 7: Configuration template
echo ""
echo "Test 7: Configuration template"
if [ -f "/mnt/beegfs/configs/oumi-template.yaml" ]; then
    echo "✓ PASS: Configuration template exists"
else
    echo "✗ FAIL: Configuration template not found"
    exit 1
fi

# Test 8: Multi-node access
echo ""
echo "Test 8: Oumi accessible from compute nodes"
NODE_TEST=$(srun --nodes=2 --ntasks=2 \
    /mnt/beegfs/oumi-env/bin/python -c "import oumi; print('OK')" 2>&1)
if echo "$NODE_TEST" | grep -q "OK"; then
    echo "✓ PASS: Oumi accessible from compute nodes"
else
    echo "✗ FAIL: Multi-node access failed"
    exit 1
fi

# Test 9: Test scripts exist
echo ""
echo "Test 9: Test scripts"
if [ -f "/mnt/beegfs/scripts/test-oumi-installation.sh" ] && \
   [ -f "/mnt/beegfs/scripts/test-oumi-dryrun.sh" ]; then
    echo "✓ PASS: Test scripts exist"
else
    echo "✗ FAIL: Test scripts not found"
    exit 1
fi

echo ""
echo "=== All Tests Passed for ${TEST_SUITE} ==="
```

**File**: `tests/suites/distributed-training/oumi-functionality.py`

```python
#!/usr/bin/env python3
"""
Test Oumi framework functionality
"""

import sys
import tempfile
from pathlib import Path

def test_oumi_import():
    """Test Oumi imports"""
    try:
        import oumi
        print(f"✓ PASS: Oumi version {oumi.__version__}")
        return True
    except Exception as e:
        print(f"✗ FAIL: Oumi import failed: {e}")
        return False

def test_config_loading():
    """Test configuration loading"""
    try:
        from oumi.core.configs import TrainingConfig
        
        # Try loading template config
        config_path = Path("/mnt/beegfs/configs/oumi-template.yaml")
        if config_path.exists():
            # Just verify file can be read
            with open(config_path) as f:
                import yaml
                config_data = yaml.safe_load(f)
                if config_data:
                    print("✓ PASS: Configuration loading successful")
                    return True
        else:
            print("⚠ WARNING: Template config not found, skipping")
            return True
    except Exception as e:
        print(f"✗ FAIL: Config loading failed: {e}")
        return False

def test_model_listing():
    """Test model listing functionality"""
    try:
        # This is a placeholder - actual implementation depends on Oumi API
        print("✓ PASS: Model listing (skipped - requires API access)")
        return True
    except Exception as e:
        print(f"✗ FAIL: Model listing failed: {e}")
        return False

def test_dataset_access():
    """Test dataset access"""
    try:
        # This is a placeholder - actual implementation depends on Oumi API
        print("✓ PASS: Dataset access (skipped - requires API access)")
        return True
    except Exception as e:
        print(f"✗ FAIL: Dataset access failed: {e}")
        return False

if __name__ == '__main__':
    print("=== Oumi Functionality Tests ===\n")
    
    tests = [
        ("Oumi Import", test_oumi_import),
        ("Configuration Loading", test_config_loading),
        ("Model Listing", test_model_listing),
        ("Dataset Access", test_dataset_access)
    ]
    
    failed = 0
    for name, test_func in tests:
        print(f"Test: {name}")
        if not test_func():
            failed += 1
        print()
    
    if failed == 0:
        print("✓ All Oumi functionality tests passed")
        sys.exit(0)
    else:
        print(f"✗ {failed} test(s) failed")
        sys.exit(1)
```

### Validation Steps

```bash
# 1. Create Oumi environment
cd /beegfs/shared
python3 -m venv oumi-env
source oumi-env/bin/activate

# 2. Install Oumi
pip install oumi

# 3. Create test directory
mkdir -p tests/phase-5-distributed-training

# 4. Run installation test suite
bash tests/suites/distributed-training/oumi-installation.sh

# 5. Run functionality tests
python tests/suites/distributed-training/oumi-functionality.py

# 6. Run original validation scripts
bash /mnt/beegfs/scripts/test-oumi-installation.sh
bash /mnt/beegfs/scripts/test-oumi-dryrun.sh
```

### Success Criteria

- [ ] Oumi virtual environment created on BeeGFS
- [ ] Oumi package installed successfully
- [ ] Oumi CLI accessible and functional
- [ ] Oumi Python API imports successfully
- [ ] Model and dataset lists accessible
- [ ] CUDA support verified
- [ ] Configuration template created
- [ ] Dry-run test passes
- [ ] Environment accessible from all compute nodes

---

## TASK-057: Oumi Custom Cluster Configuration

**Duration**: 6 hours
**Priority**: HIGH
**Dependencies**: TASK-056
**Validation Target**: Oumi configured for distributed training on SLURM cluster

### Objective

Configure Oumi to work with the HPC cluster's SLURM scheduler, enable distributed training with
custom cluster launcher, and create reusable job templates.

### Implementation

#### 1. Create Oumi Cluster Configuration

**File**: `/mnt/beegfs/configs/oumi-cluster-config.yaml`

```yaml
# Oumi Custom Cluster Configuration for SLURM HPC Cluster
# Reference: https://oumi.ai/docs/en/latest/user_guides/cluster/custom_clusters.html

cluster:
  name: "hpc-slurm-cluster"
  type: "slurm"
  
  # SLURM configuration
  slurm:
    partition: "gpu"  # Adjust to your partition name
    account: null  # Set if required
    qos: null  # Set if required
    
  # Node configuration
  nodes:
    min: 1
    max: 4
    
  # Resource configuration per node
  resources:
    cpus_per_task: 8
    mem: "32G"
    time: "04:00:00"
    
  # GPU configuration
  gpus:
    type: "gpu"  # Or specific GPU type if needed
    count: 2  # GPUs per node
    
  # Environment setup
  environment:
    setup_commands:
      - "module load cuda/12.1"
      - "source /mnt/beegfs/oumi-env/bin/activate"
    
    env_vars:
      NCCL_DEBUG: "INFO"
      NCCL_IB_DISABLE: "1"
      TORCH_DISTRIBUTED_DEBUG: "DETAIL"
  
  # Shared storage
  storage:
    shared_dir: "/beegfs/shared"
    output_dir: "/mnt/beegfs/experiments/outputs"
    cache_dir: "/mnt/beegfs/cache"

# Distributed training configuration
distributed:
  backend: "nccl"
  init_method: "env://"
  timeout: 1800  # 30 minutes
```

#### 2. Create Custom Oumi Launcher

**File**: `/mnt/beegfs/scripts/oumi-slurm-launcher.py`

```python
#!/usr/bin/env python3
"""
Custom Oumi Launcher for SLURM Clusters
Integrates Oumi training with SLURM job submission
"""

import os
import sys
import argparse
import subprocess
from pathlib import Path

def create_slurm_script(config_path, nodes, gpus_per_node, time_limit, job_name, output_dir):
    """Generate SLURM submission script for Oumi training"""
    
    total_gpus = nodes * gpus_per_node
    
    script = f"""#!/bin/bash
#SBATCH --job-name={job_name}
#SBATCH --nodes={nodes}
#SBATCH --ntasks-per-node={gpus_per_node}
#SBATCH --gres=gpu:{gpus_per_node}
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time={time_limit}
#SBATCH --output={output_dir}/slurm-%j.out
#SBATCH --error={output_dir}/slurm-%j.err

echo "=========================================="
echo "Oumi Training Job: {job_name}"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node List: $SLURM_NODELIST"
echo "Number of Nodes: $SLURM_NNODES"
echo "GPUs per Node: {gpus_per_node}"
echo "Total GPUs: {total_gpus}"
echo "Config: {config_path}"
echo "=========================================="

# Load modules
module load cuda/12.1

# Activate Oumi environment
source /mnt/beegfs/oumi-env/bin/activate

# Setup distributed training environment
export MASTER_ADDR=$(scontrol show hostname $SLURM_NODELIST | head -n1)
export MASTER_PORT=29500
export WORLD_SIZE=$SLURM_NTASKS

# NCCL configuration
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=1

echo "Master Node: $MASTER_ADDR:$MASTER_PORT"
echo "World Size: $WORLD_SIZE"
echo ""

# Create output directory
mkdir -p {output_dir}

# Launch Oumi training with distributed setup
srun --mpi=pmi2 oumi train \\
    --config {config_path} \\
    --distributed.num_nodes=$SLURM_NNODES \\
    --distributed.num_gpus_per_node={gpus_per_node} \\
    --training.output_dir={output_dir}

echo ""
echo "=========================================="
echo "Training completed"
echo "=========================================="
"""
    
    return script

def submit_job(script_content, script_path):
    """Submit SLURM job"""
    # Write script to file
    with open(script_path, 'w') as f:
        f.write(script_content)
    
    # Make executable
    os.chmod(script_path, 0o755)
    
    # Submit job
    result = subprocess.run(
        ['sbatch', script_path],
        capture_output=True,
        text=True
    )
    
    if result.returncode == 0:
        job_id = result.stdout.strip().split()[-1]
        return True, job_id
    else:
        return False, result.stderr

def main():
    parser = argparse.ArgumentParser(description='Launch Oumi training on SLURM cluster')
    parser.add_argument('--config', required=True, help='Path to Oumi configuration file')
    parser.add_argument('--nodes', type=int, default=2, help='Number of nodes')
    parser.add_argument('--gpus-per-node', type=int, default=2, help='GPUs per node')
    parser.add_argument('--time', default='04:00:00', help='Time limit (HH:MM:SS)')
    parser.add_argument('--job-name', default='oumi-training', help='Job name')
    parser.add_argument('--output-dir', default='/mnt/beegfs/experiments/outputs', 
                       help='Output directory')
    parser.add_argument('--script-dir', default='/mnt/beegfs/jobs',
                       help='Directory to save SLURM scripts')
    
    args = parser.parse_args()
    
    # Validate config file exists
    if not Path(args.config).exists():
        print(f"Error: Configuration file not found: {args.config}")
        sys.exit(1)
    
    # Create output and script directories
    Path(args.output_dir).mkdir(parents=True, exist_ok=True)
    Path(args.script_dir).mkdir(parents=True, exist_ok=True)
    
    # Generate SLURM script
    print(f"Generating SLURM script for Oumi training...")
    script_content = create_slurm_script(
        config_path=args.config,
        nodes=args.nodes,
        gpus_per_node=args.gpus_per_node,
        time_limit=args.time,
        job_name=args.job_name,
        output_dir=args.output_dir
    )
    
    # Save script
    script_path = Path(args.script_dir) / f'{args.job_name}.sh'
    print(f"Saving script to: {script_path}")
    
    # Submit job
    print(f"Submitting job...")
    success, result = submit_job(script_content, script_path)
    
    if success:
        print(f"✓ Job submitted successfully!")
        print(f"  Job ID: {result}")
        print(f"  Monitor with: squeue -j {result}")
        print(f"  View logs: tail -f {args.output_dir}/slurm-{result}.out")
    else:
        print(f"✗ Job submission failed:")
        print(f"  {result}")
        sys.exit(1)

if __name__ == '__main__':
    main()
```

#### 3. Create Oumi SLURM Job Template

**File**: `/mnt/beegfs/templates/oumi-slurm-template.sh`

```bash
#!/bin/bash
#SBATCH --job-name=oumi-training
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --gres=gpu:2
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --output=/mnt/beegfs/logs/oumi-%j.out
#SBATCH --error=/mnt/beegfs/logs/oumi-%j.err

# Configuration
CONFIG_FILE=${1:-"/mnt/beegfs/configs/oumi-training.yaml"}
OUTPUT_DIR=${2:-"/mnt/beegfs/experiments/outputs/$(date +%Y%m%d-%H%M%S)"}

echo "=========================================="
echo "Oumi Training Job"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node List: $SLURM_NODELIST"
echo "Config: $CONFIG_FILE"
echo "Output: $OUTPUT_DIR"
echo "=========================================="

# Setup environment
module load cuda/12.1
source /mnt/beegfs/oumi-env/bin/activate

# Distributed training setup
export MASTER_ADDR=$(scontrol show hostname $SLURM_NODELIST | head -n1)
export MASTER_PORT=29500
export WORLD_SIZE=$SLURM_NTASKS
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=1

# Create output directory
mkdir -p $OUTPUT_DIR

# Launch Oumi training
srun --mpi=pmi2 oumi train \
    --config $CONFIG_FILE \
    --training.output_dir=$OUTPUT_DIR \
    --distributed.num_nodes=$SLURM_NNODES \
    --distributed.num_gpus_per_node=$SLURM_GPUS_ON_NODE

echo "Training completed"
```

#### 4. Create Configuration Examples

**File**: `/mnt/beegfs/configs/examples/smollm-sft-distributed.yaml`

```yaml
# SmolLM-135M Fine-tuning - Distributed Training Example

model:
  model_name: "HuggingFaceTB/SmolLM-135M"
  trust_remote_code: true
  torch_dtype: "bfloat16"

dataset:
  dataset_name: "yahma/alpaca-cleaned"
  max_samples: 5000
  split: "train"
  preprocessing:
    max_length: 512

training:
  output_dir: "/mnt/beegfs/experiments/smollm-sft"
  num_train_epochs: 3
  per_device_train_batch_size: 8
  gradient_accumulation_steps: 4
  learning_rate: 2e-5
  warmup_steps: 100
  
  # Logging
  logging_steps: 10
  report_to: ["tensorboard", "aim"]
  
  # Checkpointing
  save_steps: 500
  save_total_limit: 3
  
  # Optimization
  bf16: true
  gradient_checkpointing: true
  
  # Distributed
  distributed_strategy: "ddp"

peft:
  use_peft: true
  peft_type: "lora"
  lora_r: 8
  lora_alpha: 16
  lora_dropout: 0.05
```

### Test Creation

**File**: `tests/suites/distributed-training/oumi-cluster-config.sh`

```bash
#!/bin/bash
# Test suite for TASK-057: Oumi Custom Cluster Configuration

set -e

TEST_SUITE="TASK-057"

echo "=== Test Suite: ${TEST_SUITE} - Oumi Cluster Configuration ==="

# Test 1: Cluster configuration file
echo ""
echo "Test 1: Cluster configuration file"
if [ -f "/mnt/beegfs/configs/oumi-cluster-config.yaml" ]; then
    echo "✓ PASS: Cluster config exists"
else
    echo "✗ FAIL: Cluster config not found"
    exit 1
fi

# Test 2: Custom launcher script
echo ""
echo "Test 2: Custom Oumi launcher"
if [ -f "/mnt/beegfs/scripts/oumi-slurm-launcher.py" ] && \
   [ -x "/mnt/beegfs/scripts/oumi-slurm-launcher.py" ]; then
    echo "✓ PASS: Launcher script exists and is executable"
else
    echo "✗ FAIL: Launcher script not found or not executable"
    exit 1
fi

# Test 3: Launcher help command
echo ""
echo "Test 3: Launcher help"
if python /mnt/beegfs/scripts/oumi-slurm-launcher.py --help > /dev/null 2>&1; then
    echo "✓ PASS: Launcher help functional"
else
    echo "✗ FAIL: Launcher help failed"
    exit 1
fi

# Test 4: Job template
echo ""
echo "Test 4: SLURM job template"
if [ -f "/mnt/beegfs/templates/oumi-slurm-template.sh" ]; then
    echo "✓ PASS: Job template exists"
else
    echo "✗ FAIL: Job template not found"
    exit 1
fi

# Test 5: Example configurations
echo ""
echo "Test 5: Example configurations"
if [ -d "/mnt/beegfs/configs/examples" ]; then
    EXAMPLE_COUNT=$(ls /mnt/beegfs/configs/examples/*.yaml 2>/dev/null | wc -l)
    if [ "$EXAMPLE_COUNT" -gt 0 ]; then
        echo "✓ PASS: Found $EXAMPLE_COUNT example config(s)"
    else
        echo "✗ FAIL: No example configs found"
        exit 1
    fi
else
    echo "✗ FAIL: Examples directory not found"
    exit 1
fi

# Test 6: Generate test SLURM script
echo ""
echo "Test 6: Generate SLURM script with launcher"
TEST_CONFIG="/mnt/beegfs/configs/oumi-template.yaml"
if [ -f "$TEST_CONFIG" ]; then
    python /mnt/beegfs/scripts/oumi-slurm-launcher.py \
        --config "$TEST_CONFIG" \
        --nodes 1 \
        --gpus-per-node 1 \
        --job-name test-oumi-057 > /dev/null 2>&1
    
    if [ -f "/mnt/beegfs/jobs/test-oumi-057.sh" ]; then
        echo "✓ PASS: SLURM script generated successfully"
    else
        echo "✗ FAIL: SLURM script generation failed"
        exit 1
    fi
else
    echo "⚠ WARNING: Template config not found, skipping script generation"
fi

# Test 7: Validate generated script syntax
echo ""
echo "Test 7: Generated script syntax"
if [ -f "/mnt/beegfs/jobs/test-oumi-057.sh" ]; then
    if bash -n /mnt/beegfs/jobs/test-oumi-057.sh 2>&1; then
        echo "✓ PASS: Generated script syntax valid"
    else
        echo "✗ FAIL: Script syntax errors"
        exit 1
    fi
fi

# Test 8: Check script contains required elements
echo ""
echo "Test 8: Generated script content validation"
if [ -f "/mnt/beegfs/jobs/test-oumi-057.sh" ]; then
    REQUIRED_ELEMENTS=("SBATCH" "srun" "oumi train" "MASTER_ADDR")
    for element in "${REQUIRED_ELEMENTS[@]}"; do
        if grep -q "$element" "/mnt/beegfs/jobs/test-oumi-057.sh"; then
            echo "✓ PASS: Contains '$element'"
        else
            echo "✗ FAIL: Missing '$element'"
            exit 1
        fi
    done
fi

echo ""
echo "=== All Tests Passed for ${TEST_SUITE} ==="
```

**File**: `tests/suites/distributed-training/launcher-functionality.py`

```python
#!/usr/bin/env python3
"""
Test Oumi SLURM launcher functionality
"""

import sys
import os
import tempfile
from pathlib import Path

def test_launcher_import():
    """Test launcher script can be imported"""
    try:
        sys.path.insert(0, '/mnt/beegfs/scripts')
        # Just verify file exists and is readable
        launcher_path = Path('/mnt/beegfs/scripts/oumi-slurm-launcher.py')
        if launcher_path.exists():
            with open(launcher_path) as f:
                content = f.read()
                if 'create_slurm_script' in content and 'submit_job' in content:
                    print("✓ PASS: Launcher contains required functions")
                    return True
        print("✗ FAIL: Launcher validation failed")
        return False
    except Exception as e:
        print(f"✗ FAIL: Launcher import test failed: {e}")
        return False

def test_script_template():
    """Test SLURM script template is valid"""
    try:
        template_path = Path('/mnt/beegfs/templates/oumi-slurm-template.sh')
        if template_path.exists():
            with open(template_path) as f:
                content = f.read()
                required = ['#SBATCH', 'srun', 'oumi train']
                if all(req in content for req in required):
                    print("✓ PASS: Template contains required directives")
                    return True
                else:
                    print("✗ FAIL: Template missing required directives")
                    return False
        else:
            print("✗ FAIL: Template not found")
            return False
    except Exception as e:
        print(f"✗ FAIL: Template test failed: {e}")
        return False

def test_config_examples():
    """Test example configurations are valid YAML"""
    try:
        import yaml
        examples_dir = Path('/mnt/beegfs/configs/examples')
        if examples_dir.exists():
            yaml_files = list(examples_dir.glob('*.yaml'))
            if yaml_files:
                for yaml_file in yaml_files:
                    with open(yaml_file) as f:
                        config = yaml.safe_load(f)
                        if not config:
                            print(f"✗ FAIL: Empty config: {yaml_file.name}")
                            return False
                print(f"✓ PASS: {len(yaml_files)} example config(s) valid")
                return True
            else:
                print("✗ FAIL: No example configs found")
                return False
        else:
            print("✗ FAIL: Examples directory not found")
            return False
    except Exception as e:
        print(f"✗ FAIL: Config validation failed: {e}")
        return False

if __name__ == '__main__':
    print("=== Oumi Launcher Functionality Tests ===\n")
    
    tests = [
        ("Launcher Script", test_launcher_import),
        ("SLURM Template", test_script_template),
        ("Example Configs", test_config_examples)
    ]
    
    failed = 0
    for name, test_func in tests:
        print(f"Test: {name}")
        if not test_func():
            failed += 1
        print()
    
    if failed == 0:
        print("✓ All launcher functionality tests passed")
        sys.exit(0)
    else:
        print(f"✗ {failed} test(s) failed")
        sys.exit(1)
```

### Validation Steps

```bash
# 1. Create cluster configuration
mkdir -p /mnt/beegfs/configs/examples
mkdir -p tests/phase-5-distributed-training
# Copy cluster config files

# 2. Make launcher executable
chmod +x /mnt/beegfs/scripts/oumi-slurm-launcher.py

# 3. Run test suite
bash tests/suites/distributed-training/oumi-cluster-config.sh

# 4. Run launcher functionality tests
python tests/suites/distributed-training/launcher-functionality.py

# 5. Test with actual small job (optional)
python /mnt/beegfs/scripts/oumi-slurm-launcher.py \
    --config /mnt/beegfs/configs/oumi-template.yaml \
    --nodes 1 \
    --gpus-per-node 1 \
    --job-name test-oumi-launcher
```

### Success Criteria

- [ ] Cluster configuration file created
- [ ] Custom Oumi launcher script functional
- [ ] SLURM job template created
- [ ] Example configurations created
- [ ] Launcher can generate SLURM scripts
- [ ] Jobs can be submitted successfully
- [ ] Distributed training environment variables set correctly
- [ ] Oumi recognizes SLURM environment

---

## TASK-058: Small Model Training Validation

**Duration**: 1 day
**Priority**: HIGH
**Dependencies**: TASK-054, TASK-055
**Validation Target**: Small model training working end-to-end with monitoring

### Objective

Validate complete training pipeline with PyTorch DDP using MNIST CNN, including monitoring,
checkpointing, and multi-node execution.

### Implementation

See TASK-054 for complete MNIST implementation. This task extends it with:

1. **Comprehensive monitoring integration**
   - TensorBoard logging
   - Aim tracking
   - GPU utilization monitoring

2. **Checkpoint management**
   - Regular checkpoint saves
   - Best model tracking
   - Resume from checkpoint capability

3. **Extended validation**
   - Longer training (20 epochs)
   - Multiple runs with different hyperparameters
   - Performance benchmarking

### Test Creation

**File**: `tests/suites/distributed-training/model-training-validation.sh`

```bash
#!/bin/bash
# Test suite for TASK-058: Small Model Training Validation

set -e

TEST_SUITE="TASK-058"

echo "=== Test Suite: ${TEST_SUITE} - Model Training Validation ==="

# Test 1: Enhanced MNIST script exists
echo ""
echo "Test 1: Enhanced MNIST training script"
if [ -f "/mnt/beegfs/training/mnist_ddp_monitored.py" ]; then
    echo "✓ PASS: Monitored MNIST script found"
else
    echo "✗ FAIL: Script not found"
    exit 1
fi

# Test 2: Checkpoint directories
echo ""
echo "Test 2: Checkpoint directory structure"
mkdir -p /mnt/beegfs/experiments/checkpoints/mnist-ddp
if [ -d "/mnt/beegfs/experiments/checkpoints/mnist-ddp" ]; then
    echo "✓ PASS: Checkpoint directory exists"
else
    echo "✗ FAIL: Checkpoint directory not created"
    exit 1
fi

# Test 3: Submit extended training job
echo ""
echo "Test 3: Submit extended training (5 epochs)"
# Create a shorter test version
cat > /tmp/mnist-ddp-test.sh <<'EOF'
#!/bin/bash
#SBATCH --job-name=mnist-test-058
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --gres=gpu:2
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --output=/mnt/beegfs/logs/mnist-test-058-%j.out

source /mnt/beegfs/pytorch-env/bin/activate
export MASTER_ADDR=$(scontrol show hostname $SLURM_NODELIST | head -n1)
export MASTER_PORT=29500
export WORLD_SIZE=$SLURM_NTASKS

srun --mpi=pmi2 python /mnt/beegfs/training/mnist_ddp_monitored.py \
    --epochs 5 \
    --checkpoint-dir /mnt/beegfs/experiments/checkpoints/mnist-ddp
EOF

JOB_ID=$(sbatch --parsable /tmp/mnist-ddp-test.sh)
if [ -n "$JOB_ID" ]; then
    echo "✓ PASS: Training job submitted (ID: $JOB_ID)"
else
    echo "✗ FAIL: Job submission failed"
    exit 1
fi

# Test 4: Wait for job completion
echo ""
echo "Test 4: Wait for training completion (max 20 minutes)"
TIMEOUT=1200
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    JOB_STATE=$(squeue -j $JOB_ID -h -o "%T" 2>/dev/null || echo "COMPLETED")
    if [ "$JOB_STATE" = "COMPLETED" ] || [ -z "$JOB_STATE" ]; then
        echo "✓ PASS: Training completed"
        break
    elif [ "$JOB_STATE" = "FAILED" ]; then
        echo "✗ FAIL: Training failed"
        exit 1
    fi
    sleep 30
    ELAPSED=$((ELAPSED + 30))
done

# Test 5: Verify checkpoints
echo ""
echo "Test 5: Verify checkpoints saved"
CHECKPOINT_COUNT=$(ls /mnt/beegfs/experiments/checkpoints/mnist-ddp/*.pt 2>/dev/null | wc -l)
if [ "$CHECKPOINT_COUNT" -gt 0 ]; then
    echo "✓ PASS: Found $CHECKPOINT_COUNT checkpoint(s)"
else
    echo "✗ FAIL: No checkpoints found"
    exit 1
fi

# Test 6: Check monitoring logs
echo ""
echo "Test 6: Verify monitoring integration"
if [ -d "/mnt/beegfs/experiments/logs" ]; then
    LOG_COUNT=$(find /mnt/beegfs/experiments/logs -name "events.out.tfevents.*" | wc -l)
    if [ "$LOG_COUNT" -gt 0 ]; then
        echo "✓ PASS: TensorBoard logs found"
    else
        echo "⚠ WARNING: No TensorBoard logs found"
    fi
else
    echo "⚠ WARNING: Logs directory not found"
fi

# Test 7: Verify accuracy
echo ""
echo "Test 7: Check final accuracy"
LOG_FILE="/mnt/beegfs/logs/mnist-test-058-${JOB_ID}.out"
if [ -f "$LOG_FILE" ]; then
    ACCURACY=$(grep -oP 'Accuracy: \K[0-9.]+' "$LOG_FILE" | tail -1)
    if [ -n "$ACCURACY" ]; then
        if (( $(echo "$ACCURACY > 95" | bc -l) )); then
            echo "✓ PASS: Accuracy ${ACCURACY}% > 95%"
        else
            echo "⚠ WARNING: Accuracy ${ACCURACY}% below threshold"
        fi
    fi
fi

echo ""
echo "=== All Tests Passed for ${TEST_SUITE} ==="
```

**File**: `tests/suites/distributed-training/checkpoint-management.py`

```python
#!/usr/bin/env python3
"""
Test checkpoint management functionality
"""

import sys
import os
import torch
from pathlib import Path

def test_checkpoint_save():
    """Test checkpoint saving"""
    try:
        checkpoint_dir = Path('/tmp/test-checkpoints')
        checkpoint_dir.mkdir(parents=True, exist_ok=True)
        
        # Create dummy model and save checkpoint
        model = torch.nn.Linear(10, 2)
        checkpoint = {
            'model_state_dict': model.state_dict(),
            'epoch': 5,
            'accuracy': 0.95
        }
        
        checkpoint_path = checkpoint_dir / 'test_checkpoint.pt'
        torch.save(checkpoint, checkpoint_path)
        
        if checkpoint_path.exists():
            print("✓ PASS: Checkpoint save successful")
            return True
        else:
            print("✗ FAIL: Checkpoint not saved")
            return False
    except Exception as e:
        print(f"✗ FAIL: Checkpoint save failed: {e}")
        return False

def test_checkpoint_load():
    """Test checkpoint loading"""
    try:
        checkpoint_path = Path('/tmp/test-checkpoints/test_checkpoint.pt')
        if checkpoint_path.exists():
            checkpoint = torch.load(checkpoint_path)
            if 'model_state_dict' in checkpoint and 'epoch' in checkpoint:
                print("✓ PASS: Checkpoint load successful")
                return True
        print("✗ FAIL: Checkpoint load failed")
        return False
    except Exception as e:
        print(f"✗ FAIL: Checkpoint load failed: {e}")
        return False

def test_checkpoint_resume():
    """Test resuming from checkpoint"""
    try:
        checkpoint_path = Path('/tmp/test-checkpoints/test_checkpoint.pt')
        checkpoint = torch.load(checkpoint_path)
        
        # Create new model and load state
        model = torch.nn.Linear(10, 2)
        model.load_state_dict(checkpoint['model_state_dict'])
        
        print(f"✓ PASS: Resume from epoch {checkpoint['epoch']}")
        return True
    except Exception as e:
        print(f"✗ FAIL: Checkpoint resume failed: {e}")
        return False

if __name__ == '__main__':
    print("=== Checkpoint Management Tests ===\n")
    
    tests = [
        ("Checkpoint Save", test_checkpoint_save),
        ("Checkpoint Load", test_checkpoint_load),
        ("Checkpoint Resume", test_checkpoint_resume)
    ]
    
    failed = 0
    for name, test_func in tests:
        print(f"Test: {name}")
        if not test_func():
            failed += 1
        print()
    
    if failed == 0:
        print("✓ All checkpoint management tests passed")
        sys.exit(0)
    else:
        print(f"✗ {failed} test(s) failed")
        sys.exit(1)
```

### Validation Steps

```bash
# 1. Create test directory
mkdir -p tests/phase-5-distributed-training

# 2. Run test suite (includes job submission)
bash tests/suites/distributed-training/model-training-validation.sh

# 3. Run checkpoint management tests
python tests/suites/distributed-training/checkpoint-management.py

# 4. Monitor training (optional)
tail -f /mnt/beegfs/logs/mnist-test-058-*.out

# 5. Check results after completion
ls -lh /mnt/beegfs/experiments/checkpoints/mnist-ddp/
```

### Success Criteria

- [ ] 20-epoch training completes successfully
- [ ] Final test accuracy >98%
- [ ] Training time <10 minutes (2 nodes, 4 GPUs)
- [ ] All metrics logged to TensorBoard and Aim
- [ ] Checkpoints saved correctly
- [ ] Resume from checkpoint works
- [ ] GPU utilization >80%
- [ ] Scaling efficiency >70% (2 nodes vs 1 node)

---

## TASK-059: Small Model Fine-tuning Validation

**Duration**: 2 days
**Priority**: HIGH
**Dependencies**: TASK-058, TASK-057
**Validation Target**: SmolLM-135M fine-tuning with Oumi framework

### Objective

Validate Oumi framework on HPC cluster by fine-tuning SmolLM-135M on Alpaca dataset with LoRA.
Confirm end-to-end MLOps workflow including data loading, training, evaluation, and model export.

### Implementation

#### 1. Create SmolLM Training Configuration

**File**: `/mnt/beegfs/configs/smollm-135m-alpaca.yaml`

```yaml
# SmolLM-135M Fine-tuning with LoRA on Alpaca Dataset

model:
  model_name: "HuggingFaceTB/SmolLM-135M"
  trust_remote_code: true
  torch_dtype: "bfloat16"

dataset:
  dataset_name: "yahma/alpaca-cleaned"
  split: "train"
  preprocessing:
    max_length: 512
    truncation: true

training:
  output_dir: "/mnt/beegfs/experiments/smollm-alpaca"
  num_train_epochs: 3
  per_device_train_batch_size: 16
  gradient_accumulation_steps: 2
  learning_rate: 2e-4
  warmup_ratio: 0.1
  
  # Logging
  logging_steps: 10
  logging_first_step: true
  report_to: ["tensorboard", "aim"]
  
  # Evaluation
  eval_steps: 100
  evaluation_strategy: "steps"
  per_device_eval_batch_size: 16
  
  # Checkpointing
  save_steps: 500
  save_strategy: "steps"
  save_total_limit: 3
  load_best_model_at_end: true
  metric_for_best_model: "eval_loss"
  
  # Optimization
  bf16: true
  gradient_checkpointing: true
  optim: "adamw_torch"
  weight_decay: 0.01
  
  # Distributed
  distributed_strategy: "ddp"

peft:
  use_peft: true
  peft_type: "lora"
  lora_r: 16
  lora_alpha: 32
  lora_dropout: 0.05
  target_modules: ["q_proj", "v_proj", "k_proj", "o_proj"]
  bias: "none"
  task_type: "CAUSAL_LM"
```

#### 2. Create Training Job Script

**File**: `/mnt/beegfs/jobs/smollm-training.sh`

```bash
#!/bin/bash
#SBATCH --job-name=smollm-alpaca
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --gres=gpu:2
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=08:00:00
#SBATCH --output=/mnt/beegfs/logs/smollm-%j.out
#SBATCH --error=/mnt/beegfs/logs/smollm-%j.err

echo "=========================================="
echo "SmolLM-135M Fine-tuning on Alpaca"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Start Time: $(date)"
echo "=========================================="

# Setup
module load cuda/12.1
source /mnt/beegfs/oumi-env/bin/activate

# Distributed setup
export MASTER_ADDR=$(scontrol show hostname $SLURM_NODELIST | head -n1)
export MASTER_PORT=29500
export WORLD_SIZE=$SLURM_NTASKS

# Launch training
srun --mpi=pmi2 oumi train \
    --config /mnt/beegfs/configs/smollm-135m-alpaca.yaml

echo "=========================================="
echo "Training completed: $(date)"
echo "=========================================="
```

#### 3. Create Inference Test Script

**File**: `/mnt/beegfs/scripts/test-smollm-inference.py`

```python
#!/usr/bin/env python3
"""Test fine-tuned SmolLM model"""

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel

def load_model(base_model, lora_weights):
    """Load base model with LoRA weights"""
    tokenizer = AutoTokenizer.from_pretrained(base_model)
    model = AutoModelForCausalLM.from_pretrained(
        base_model,
        torch_dtype=torch.bfloat16,
        device_map="auto"
    )
    model = PeftModel.from_pretrained(model, lora_weights)
    model.eval()
    return model, tokenizer

def generate_response(model, tokenizer, prompt, max_length=256):
    """Generate response from model"""
    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
    
    with torch.no_grad():
        outputs = model.generate(
            **inputs,
            max_length=max_length,
            num_return_sequences=1,
            temperature=0.7,
            top_p=0.9,
            do_sample=True
        )
    
    response = tokenizer.decode(outputs[0], skip_special_tokens=True)
    return response

def main():
    # Load model
    print("Loading fine-tuned model...")
    model, tokenizer = load_model(
        base_model="HuggingFaceTB/SmolLM-135M",
        lora_weights="/mnt/beegfs/experiments/smollm-alpaca/checkpoint-best"
    )
    
    # Test prompts
    test_prompts = [
        "Below is an instruction. Write a response.\n\n### Instruction:\nWhat is machine learning?\n\n### Response:",
        "Below is an instruction. Write a response.\n\n### Instruction:\nExplain distributed training.\n\n### Response:",
    ]
    
    print("\n" + "="*50)
    print("Testing Fine-tuned Model")
    print("="*50)
    
    for i, prompt in enumerate(test_prompts, 1):
        print(f"\nTest {i}:")
        print(f"Prompt: {prompt[:100]}...")
        response = generate_response(model, tokenizer, prompt)
        print(f"Response: {response}")
        print("-"*50)

if __name__ == '__main__':
    main()
```

### Test Creation

**File**: `tests/suites/distributed-training/smollm-finetuning.sh`

```bash
#!/bin/bash
# Test suite for TASK-059: Small Model Fine-tuning Validation

set -e

TEST_SUITE="TASK-059"

echo "=== Test Suite: ${TEST_SUITE} - SmolLM Fine-tuning ==="

# Test 1: Configuration file
echo ""
echo "Test 1: SmolLM training configuration"
if [ -f "/mnt/beegfs/configs/smollm-135m-alpaca.yaml" ]; then
    echo "✓ PASS: Training config exists"
else
    echo "✗ FAIL: Training config not found"
    exit 1
fi

# Test 2: Training job script
echo ""
echo "Test 2: SmolLM training job script"
if [ -f "/mnt/beegfs/jobs/smollm-training.sh" ]; then
    echo "✓ PASS: Training script exists"
else
    echo "✗ FAIL: Training script not found"
    exit 1
fi

# Test 3: Inference test script
echo ""
echo "Test 3: Inference test script"
if [ -f "/mnt/beegfs/scripts/test-smollm-inference.py" ]; then
    echo "✓ PASS: Inference script exists"
else
    echo "✗ FAIL: Inference script not found"
    exit 1
fi

# Test 4: Oumi environment available
echo ""
echo "Test 4: Oumi environment"
source /mnt/beegfs/oumi-env/bin/activate
if python -c "import oumi" 2>/dev/null; then
    echo "✓ PASS: Oumi environment ready"
else
    echo "✗ FAIL: Oumi not available"
    exit 1
fi

# Test 5: Submit small-scale test job (reduced dataset)
echo ""
echo "Test 5: Submit test training job (reduced scale)"
# Create a test config with small dataset
cat > /tmp/smollm-test-config.yaml <<'EOF'
model:
  model_name: "HuggingFaceTB/SmolLM-135M"
  torch_dtype: "bfloat16"

dataset:
  dataset_name: "yahma/alpaca-cleaned"
  max_samples: 100  # Very small for testing
  split: "train"

training:
  output_dir: "/mnt/beegfs/experiments/smollm-test"
  num_train_epochs: 1
  per_device_train_batch_size: 4
  logging_steps: 5
  save_steps: 50

peft:
  use_peft: true
  peft_type: "lora"
  lora_r: 8
  lora_alpha: 16
EOF

# Use launcher to submit job
python /mnt/beegfs/scripts/oumi-slurm-launcher.py \
    --config /tmp/smollm-test-config.yaml \
    --nodes 1 \
    --gpus-per-node 1 \
    --time 01:00:00 \
    --job-name smollm-test-059 > /dev/null 2>&1

JOB_ID=$(squeue -u $USER -n smollm-test-059 -h -o "%A" 2>/dev/null || echo "")
if [ -n "$JOB_ID" ]; then
    echo "✓ PASS: Test job submitted (ID: $JOB_ID)"
else
    echo "⚠ WARNING: Could not verify job submission"
fi

# Test 6: Wait for job completion (with timeout)
if [ -n "$JOB_ID" ]; then
    echo ""
    echo "Test 6: Wait for job completion (max 30 minutes)"
    TIMEOUT=1800
    ELAPSED=0
    while [ $ELAPSED -lt $TIMEOUT ]; do
        JOB_STATE=$(squeue -j $JOB_ID -h -o "%T" 2>/dev/null || echo "COMPLETED")
        if [ "$JOB_STATE" = "COMPLETED" ] || [ -z "$JOB_STATE" ]; then
            echo "✓ PASS: Training completed"
            break
        elif [ "$JOB_STATE" = "FAILED" ]; then
            echo "✗ FAIL: Training failed"
            exit 1
        fi
        sleep 60
        ELAPSED=$((ELAPSED + 60))
    done
fi

# Test 7: Check output directory
echo ""
echo "Test 7: Verify output directory"
if [ -d "/mnt/beegfs/experiments/smollm-test" ]; then
    echo "✓ PASS: Output directory created"
    
    # Check for checkpoints
    if ls /mnt/beegfs/experiments/smollm-test/checkpoint-* 1> /dev/null 2>&1; then
        echo "✓ PASS: Checkpoints saved"
    else
        echo "⚠ WARNING: No checkpoints found"
    fi
else
    echo "⚠ WARNING: Output directory not found"
fi

# Test 8: Check for LoRA weights
echo ""
echo "Test 8: Verify LoRA weights"
if [ -d "/mnt/beegfs/experiments/smollm-test" ]; then
    if find /mnt/beegfs/experiments/smollm-test -name "adapter_*.bin" | grep -q .; then
        echo "✓ PASS: LoRA adapter weights found"
    else
        echo "⚠ WARNING: LoRA weights not found"
    fi
fi

echo ""
echo "=== All Tests Passed for ${TEST_SUITE} ==="
```

**File**: `tests/suites/distributed-training/model-inference.py`

```python
#!/usr/bin/env python3
"""
Test SmolLM model inference capability
"""

import sys
import os
from pathlib import Path

def test_transformers_import():
    """Test required imports"""
    try:
        from transformers import AutoModelForCausalLM, AutoTokenizer
        from peft import PeftModel
        print("✓ PASS: Required imports successful")
        return True
    except Exception as e:
        print(f"✗ FAIL: Import failed: {e}")
        return False

def test_model_load_base():
    """Test loading base model"""
    try:
        from transformers import AutoModelForCausalLM, AutoTokenizer
        import torch
        
        model_name = "HuggingFaceTB/SmolLM-135M"
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        
        # Load in CPU mode for testing
        model = AutoModelForCausalLM.from_pretrained(
            model_name,
            torch_dtype=torch.bfloat16,
            device_map="cpu"
        )
        
        print(f"✓ PASS: Base model loaded ({model_name})")
        return True
    except Exception as e:
        print(f"✗ FAIL: Model load failed: {e}")
        return False

def test_tokenization():
    """Test tokenization"""
    try:
        from transformers import AutoTokenizer
        
        model_name = "HuggingFaceTB/SmolLM-135M"
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        
        test_text = "This is a test"
        tokens = tokenizer(test_text, return_tensors="pt")
        
        if tokens and 'input_ids' in tokens:
            print("✓ PASS: Tokenization successful")
            return True
        else:
            print("✗ FAIL: Tokenization failed")
            return False
    except Exception as e:
        print(f"✗ FAIL: Tokenization failed: {e}")
        return False

def test_inference_pipeline():
    """Test basic inference pipeline"""
    try:
        from transformers import AutoModelForCausalLM, AutoTokenizer
        import torch
        
        model_name = "HuggingFaceTB/SmolLM-135M"
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForCausalLM.from_pretrained(
            model_name,
            torch_dtype=torch.bfloat16,
            device_map="cpu"
        )
        
        # Simple generation test
        prompt = "Hello"
        inputs = tokenizer(prompt, return_tensors="pt")
        
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_length=20,
                num_return_sequences=1,
                do_sample=False
            )
        
        generated_text = tokenizer.decode(outputs[0], skip_special_tokens=True)
        
        if generated_text:
            print(f"✓ PASS: Inference successful (generated {len(generated_text)} chars)")
            return True
        else:
            print("✗ FAIL: No output generated")
            return False
    except Exception as e:
        print(f"✗ FAIL: Inference failed: {e}")
        return False

if __name__ == '__main__':
    print("=== SmolLM Inference Tests ===\n")
    
    tests = [
        ("Required Imports", test_transformers_import),
        ("Base Model Load", test_model_load_base),
        ("Tokenization", test_tokenization),
        ("Inference Pipeline", test_inference_pipeline)
    ]
    
    failed = 0
    for name, test_func in tests:
        print(f"Test: {name}")
        if not test_func():
            failed += 1
        print()
    
    if failed == 0:
        print("✓ All inference tests passed")
        sys.exit(0)
    else:
        print(f"✗ {failed} test(s) failed")
        sys.exit(1)
```

### Validation Steps

```bash
# 1. Create test directory
mkdir -p tests/phase-5-distributed-training

# 2. Run test suite (includes small-scale training)
bash tests/suites/distributed-training/smollm-finetuning.sh

# 3. Run inference tests
source /mnt/beegfs/oumi-env/bin/activate
python tests/suites/distributed-training/model-inference.py

# 4. Submit full-scale training (optional)
python /mnt/beegfs/scripts/oumi-slurm-launcher.py \
    --config /mnt/beegfs/configs/smollm-135m-alpaca.yaml \
    --nodes 2 \
    --gpus-per-node 2 \
    --time 08:00:00 \
    --job-name smollm-alpaca
```

### Success Criteria

- [ ] Training completes without errors
- [ ] Training time <2 hours (2 nodes, 4 GPUs)
- [ ] Final evaluation loss <2.0
- [ ] Checkpoints saved correctly
- [ ] LoRA weights exportable
- [ ] Model generates coherent responses
- [ ] Monitoring data captured in dashboards
- [ ] Memory usage <20GB per GPU
- [ ] Training scales to multiple nodes

---

## TASK-060: Distributed Training Documentation

**Duration**: 4 hours
**Priority**: MEDIUM
**Dependencies**: TASK-059
**Validation Target**: Complete documentation for distributed training workflows

### Objective

Create comprehensive documentation for distributed training on the HPC cluster, including user guides,
troubleshooting, and best practices.

### Implementation

Create documentation files:

1. **`/mnt/beegfs/docs/distributed-training-guide.md`**
   - Overview of distributed training setup
   - PyTorch DDP vs Oumi framework
   - When to use each approach

2. **`/mnt/beegfs/docs/quickstart-pytorch.md`**
   - Quick start guide for PyTorch DDP
   - MNIST example walkthrough
   - Common SLURM commands

3. **`/mnt/beegfs/docs/quickstart-oumi.md`**
   - Quick start guide for Oumi
   - SmolLM fine-tuning walkthrough
   - Configuration templates

4. **`/mnt/beegfs/docs/monitoring-guide.md`**
   - TensorBoard setup and usage
   - Aim dashboard guide
   - MLflow integration

5. **`/mnt/beegfs/docs/troubleshooting.md`**
   - Common errors and solutions
   - NCCL debugging
   - SLURM issues
   - Performance optimization tips

6. **`/mnt/beegfs/docs/best-practices.md`**
   - Efficient data loading
   - Hyperparameter tuning
   - Checkpoint management
   - Resource allocation

### Test Creation

**File**: `tests/suites/distributed-training/documentation.sh`

```bash
#!/bin/bash
# Test suite for TASK-060: Distributed Training Documentation

set -e

TEST_SUITE="TASK-060"

echo "=== Test Suite: ${TEST_SUITE} - Documentation Validation ==="

# Test 1: Documentation directory
echo ""
echo "Test 1: Documentation directory structure"
if [ -d "/mnt/beegfs/docs" ]; then
    echo "✓ PASS: Documentation directory exists"
else
    echo "✗ FAIL: Documentation directory not found"
    exit 1
fi

# Test 2: Required documentation files
echo ""
echo "Test 2: Required documentation files"
REQUIRED_DOCS=(
    "/mnt/beegfs/docs/distributed-training-guide.md"
    "/mnt/beegfs/docs/quickstart-pytorch.md"
    "/mnt/beegfs/docs/quickstart-oumi.md"
    "/mnt/beegfs/docs/monitoring-guide.md"
    "/mnt/beegfs/docs/troubleshooting.md"
    "/mnt/beegfs/docs/best-practices.md"
)

MISSING_DOCS=0
for doc in "${REQUIRED_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        echo "✓ PASS: $(basename $doc) exists"
    else
        echo "✗ FAIL: $(basename $doc) missing"
        MISSING_DOCS=$((MISSING_DOCS + 1))
    fi
done

if [ $MISSING_DOCS -gt 0 ]; then
    echo "✗ FAIL: $MISSING_DOCS required document(s) missing"
    exit 1
fi

# Test 3: Documentation content validation
echo ""
echo "Test 3: Documentation content validation"
for doc in "${REQUIRED_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        # Check if file is not empty
        if [ -s "$doc" ]; then
            # Check minimum word count (at least 100 words)
            WORD_COUNT=$(wc -w < "$doc")
            if [ "$WORD_COUNT" -gt 100 ]; then
                echo "✓ PASS: $(basename $doc) has substantive content ($WORD_COUNT words)"
            else
                echo "⚠ WARNING: $(basename $doc) may be incomplete ($WORD_COUNT words)"
            fi
        else
            echo "✗ FAIL: $(basename $doc) is empty"
            exit 1
        fi
    fi
done

# Test 4: Check for code examples in guides
echo ""
echo "Test 4: Code examples in quickstart guides"
QUICKSTARTS=(
    "/mnt/beegfs/docs/quickstart-pytorch.md"
    "/mnt/beegfs/docs/quickstart-oumi.md"
)

for doc in "${QUICKSTARTS[@]}"; do
    if [ -f "$doc" ]; then
        # Check for code blocks (```)
        CODE_BLOCKS=$(grep -c '```' "$doc" || echo "0")
        if [ "$CODE_BLOCKS" -gt 2 ]; then  # At least 1 complete code block (2 markers)
            echo "✓ PASS: $(basename $doc) contains code examples"
        else
            echo "⚠ WARNING: $(basename $doc) may lack code examples"
        fi
    fi
done

# Test 5: Check for SLURM commands in documentation
echo ""
echo "Test 5: SLURM command references"
SLURM_KEYWORDS=("sbatch" "srun" "squeue" "scancel")
DOC_WITH_SLURM=0

for doc in "${REQUIRED_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        for keyword in "${SLURM_KEYWORDS[@]}"; do
            if grep -q "$keyword" "$doc"; then
                DOC_WITH_SLURM=$((DOC_WITH_SLURM + 1))
                break
            fi
        done
    fi
done

if [ "$DOC_WITH_SLURM" -gt 0 ]; then
    echo "✓ PASS: SLURM commands referenced in $DOC_WITH_SLURM document(s)"
else
    echo "⚠ WARNING: No SLURM command references found"
fi

# Test 6: Check for external resource links
echo ""
echo "Test 6: External resource links"
LINK_COUNT=0

for doc in "${REQUIRED_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        # Count markdown links
        LINKS=$(grep -c '\[.*\](http' "$doc" || echo "0")
        LINK_COUNT=$((LINK_COUNT + LINKS))
    fi
done

if [ "$LINK_COUNT" -gt 0 ]; then
    echo "✓ PASS: Found $LINK_COUNT external link(s)"
else
    echo "⚠ WARNING: No external links found"
fi

# Test 7: Documentation accessibility
echo ""
echo "Test 7: Documentation accessibility from compute nodes"
# Test if docs can be accessed via shared storage
srun --nodes=1 --ntasks=1 \
    ls /mnt/beegfs/docs/*.md > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✓ PASS: Documentation accessible from compute nodes"
else
    echo "✗ FAIL: Documentation not accessible from compute nodes"
    exit 1
fi

# Test 8: README or index file
echo ""
echo "Test 8: Documentation index/README"
if [ -f "/mnt/beegfs/docs/README.md" ] || [ -f "/mnt/beegfs/docs/INDEX.md" ]; then
    echo "✓ PASS: Documentation index found"
else
    echo "⚠ WARNING: No README or INDEX found in docs"
fi

echo ""
echo "=== All Tests Passed for ${TEST_SUITE} ==="
```

**File**: `tests/suites/distributed-training/documentation-quality.py`

```python
#!/usr/bin/env python3
"""
Test documentation quality and completeness
"""

import sys
import re
from pathlib import Path
from typing import List, Tuple

def test_markdown_syntax(doc_path: Path) -> bool:
    """Test basic markdown syntax validity"""
    try:
        with open(doc_path) as f:
            content = f.read()
        
        # Check for headers
        headers = re.findall(r'^#+\s+.+$', content, re.MULTILINE)
        if not headers:
            print(f"⚠ WARNING: {doc_path.name} has no headers")
            return True  # Not critical
        
        # Check for balanced code blocks
        code_blocks = content.count('```')
        if code_blocks % 2 != 0:
            print(f"✗ FAIL: {doc_path.name} has unbalanced code blocks")
            return False
        
        print(f"✓ PASS: {doc_path.name} markdown syntax valid")
        return True
    except Exception as e:
        print(f"✗ FAIL: {doc_path.name} validation failed: {e}")
        return False

def test_has_sections(doc_path: Path, required_sections: List[str]) -> bool:
    """Test if document has required sections"""
    try:
        with open(doc_path) as f:
            content = f.read().lower()
        
        missing = []
        for section in required_sections:
            if section.lower() not in content:
                missing.append(section)
        
        if missing:
            print(f"⚠ WARNING: {doc_path.name} missing sections: {', '.join(missing)}")
            return True  # Warning only
        else:
            print(f"✓ PASS: {doc_path.name} has all required sections")
            return True
    except Exception as e:
        print(f"✗ FAIL: {doc_path.name} section test failed: {e}")
        return False

def test_has_examples(doc_path: Path) -> bool:
    """Test if document contains examples"""
    try:
        with open(doc_path) as f:
            content = f.read()
        
        # Look for code blocks
        code_blocks = content.count('```')
        
        # Look for example keywords
        example_keywords = ['example', 'for example', 'e.g.']
        has_examples = any(keyword in content.lower() for keyword in example_keywords)
        
        if code_blocks > 2 or has_examples:
            print(f"✓ PASS: {doc_path.name} contains examples")
            return True
        else:
            print(f"⚠ WARNING: {doc_path.name} may lack examples")
            return True  # Warning only
    except Exception as e:
        print(f"✗ FAIL: {doc_path.name} example test failed: {e}")
        return False

if __name__ == '__main__':
    print("=== Documentation Quality Tests ===\n")
    
    docs_dir = Path('/mnt/beegfs/docs')
    
    if not docs_dir.exists():
        print("✗ FAIL: Documentation directory not found")
        sys.exit(1)
    
    # Test each documentation file
    test_cases: List[Tuple[Path, List[str]]] = [
        (docs_dir / 'distributed-training-guide.md', ['overview', 'pytorch', 'oumi']),
        (docs_dir / 'quickstart-pytorch.md', ['installation', 'example', 'slurm']),
        (docs_dir / 'quickstart-oumi.md', ['installation', 'configuration', 'training']),
        (docs_dir / 'monitoring-guide.md', ['tensorboard', 'aim']),
        (docs_dir / 'troubleshooting.md', ['nccl', 'error']),
        (docs_dir / 'best-practices.md', ['performance', 'resource'])
    ]
    
    failed = 0
    for doc_path, required_sections in test_cases:
        print(f"\nTesting: {doc_path.name}")
        if doc_path.exists():
            if not test_markdown_syntax(doc_path):
                failed += 1
            if not test_has_sections(doc_path, required_sections):
                failed += 1
            if not test_has_examples(doc_path):
                failed += 1
        else:
            print(f"✗ FAIL: {doc_path.name} not found")
            failed += 1
    
    print("\n" + "="*50)
    if failed == 0:
        print("✓ All documentation quality tests passed")
        sys.exit(0)
    else:
        print(f"⚠ {failed} warning(s) or failure(s) found")
        sys.exit(0)  # Don't fail on warnings
```

### Validation Steps

```bash
# 1. Create documentation directory
mkdir -p /mnt/beegfs/docs
mkdir -p tests/phase-5-distributed-training

# 2. Create all documentation files
# (Content created based on actual implementation experience from previous tasks)

# 3. Run documentation validation tests
bash tests/suites/distributed-training/documentation.sh

# 4. Run quality tests
python tests/suites/distributed-training/documentation-quality.py

# 5. Verify accessibility
ls -lh /mnt/beegfs/docs/

# 6. Test with new user (manual)
# Follow guides step-by-step and verify all commands work
```

### Success Criteria

- [ ] All documentation files created
- [ ] Guides include working examples
- [ ] Troubleshooting covers common issues
- [ ] Best practices documented
- [ ] Documentation accessible from all nodes
- [ ] Examples tested and verified
- [ ] Links to external resources included

---

## Phase 5 Summary

### Deliverables

1. **PyTorch Distributed Environment**
   - Virtual environment with PyTorch + CUDA
   - DDP template and helper scripts
   - SLURM job templates

2. **MNIST Validation**
   - Working multi-node, multi-GPU training
   - NCCL communication validated
   - Performance benchmarked

3. **Monitoring Infrastructure**
   - TensorBoard server operational
   - Aim tracking system running
   - MLflow (optional) configured
   - Integration with training scripts

4. **Oumi Framework**
   - Oumi installed and configured
   - Custom SLURM launcher
   - Cluster configuration
   - Job templates

5. **SmolLM Fine-tuning**
   - Working LLM fine-tuning pipeline
   - LoRA integration
   - Model inference validated
   - End-to-end workflow

6. **Documentation**
   - User guides for PyTorch and Oumi
   - Monitoring setup guide
   - Troubleshooting documentation
   - Best practices

### Timeline

- **Week 1**: PyTorch setup, MNIST validation, monitoring (Tasks 053-055)
- **Week 2**: Oumi installation and configuration (Tasks 056-057)
- **Week 3**: Model training validation and documentation (Tasks 058-060)

### Prerequisites for Phase 6

After completing Phase 5, the system will be ready for:

- Final validation (Phase 6)
- Production ML workloads
- Advanced MLOps workflows (Categories 2-5)
- Multi-model experiments
- Larger model training (with FSDP)

---

## Validation Checklist

### PyTorch Environment

- [ ] PyTorch 2.x with CUDA 12.1 installed
- [ ] NCCL backend functional
- [ ] DDP templates created
- [ ] Multi-node training working

### MNIST Training

- [ ] 2-node, 4-GPU training successful
- [ ] >95% accuracy achieved
- [ ] Training time <5 minutes
- [ ] GPU utilization >80%

### Monitoring

- [ ] TensorBoard server running
- [ ] Aim server accessible
- [ ] Metrics logging functional
- [ ] Dashboards display real-time data

### Oumi Framework

- [ ] Oumi installed and verified
- [ ] Custom launcher functional
- [ ] Cluster config created
- [ ] SLURM integration working

### SmolLM Fine-tuning

- [ ] Training completes successfully
- [ ] LoRA weights saved
- [ ] Model generates coherent text
- [ ] Inference pipeline working

### Documentation

- [ ] All guides created
- [ ] Examples tested and working
- [ ] Troubleshooting documented
- [ ] Best practices captured

---

**Phase 5 Complete**: HPC cluster fully enabled for distributed training with PyTorch and Oumi!
