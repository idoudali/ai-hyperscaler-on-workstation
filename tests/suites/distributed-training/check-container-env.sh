#!/bin/bash
# Check containerized distributed training environment
# NOTE: This script runs on the controller and uses SLURM to test GPU access on compute nodes

set -euo pipefail

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

# Check basic PyTorch installation in container (without GPU - just verify import works)
echo ""
echo "2. PyTorch Basic Installation (in container):"
if ! apptainer exec "$CONTAINER" python3 -c "
import torch
print(f'✓ PyTorch Version: {torch.__version__}')
print(f'✓ PyTorch CUDA compiled version: {torch.version.cuda}')
nccl_available = torch.distributed.is_nccl_available()
print(f'✓ NCCL Available (compiled): {nccl_available}')
if not nccl_available:
    print('✗ ERROR: NCCL is not available in this PyTorch build')
    print('  NCCL is required for multi-GPU distributed training.')
    exit(1)
" 2>&1; then
    echo "✗ ERROR: PyTorch basic check failed"
    exit 1
fi

# Check MPI installation in container
echo ""
echo "3. MPI Installation (in container):"
apptainer exec "$CONTAINER" mpirun --version | head -3

# Check SLURM GPU configuration (REQUIRED)
echo ""
echo "4. SLURM GPU Configuration:"
gpu_info=$(sinfo -o "%N %G" 2>/dev/null | grep -v "NODELIST" || true)

# Check if GPUs are configured in SLURM
if echo "$gpu_info" | grep -qE "gpu:|gpu:"; then
    echo "$gpu_info" | grep -E "gpu:|gpu:"
else
    echo "✗ ERROR: No GPU GRES configured in SLURM (Gres shows null)"
    echo "  This test requires GPU support for distributed training."
    echo "  Please configure GPU resources in SLURM (gres.conf)."
    exit 1
fi

# Check available nodes (REQUIRED: at least 2 for multi-node test)
echo ""
echo "5. Available Compute Nodes:"
available_nodes=$(sinfo -h -o "%N" -t idle,alloc,mixed 2>/dev/null | head -1 || echo "")
node_count=$(sinfo -h -N -t idle,alloc,mixed 2>/dev/null | wc -l || echo "0")
# Ensure node_count is numeric
node_count=$((node_count + 0))
echo "Available nodes: $node_count ($available_nodes)"

if [ "$node_count" -lt 2 ]; then
    echo "✗ ERROR: Insufficient nodes for multi-node test"
    echo "  Required: 2+ nodes, Available: $node_count"
    echo "  This test requires multiple nodes for distributed training validation."
    exit 1
fi

# Verify GPUs are actually allocatable via SLURM
echo ""
echo "6. SLURM GPU Allocation Test:"
echo "Verifying GPU allocation on compute node..."
if ! srun --nodes=1 --gres=gpu:1 --time=1:00 hostname 2>&1; then
    echo "✗ ERROR: Cannot allocate GPU resources via SLURM"
    echo "  GPUs may be configured but not available for allocation."
    exit 1
fi
echo "✓ GPU allocation test passed"

# Test PyTorch CUDA/NCCL on a compute node via SLURM (REQUIRES --nv flag for GPU access)
echo ""
echo "7. PyTorch CUDA/NCCL Check (on compute node via SLURM):"
echo "Running GPU check on compute node with --nv flag..."
if ! srun --nodes=1 --ntasks=1 --gres=gpu:1 --time=2:00 \
    apptainer exec --nv "$CONTAINER" python3 -c "
import torch
import socket
hostname = socket.gethostname()
print(f'Node: {hostname}')
print(f'PyTorch Version: {torch.__version__}')
cuda_available = torch.cuda.is_available()
print(f'CUDA Available: {cuda_available}')
if not cuda_available:
    print('ERROR: CUDA is not available in container on compute node')
    print('  Ensure --nv flag is passed and NVIDIA drivers are installed.')
    exit(1)
print(f'CUDA Version: {torch.version.cuda}')
gpu_count = torch.cuda.device_count()
print(f'Number of GPUs visible: {gpu_count}')
if gpu_count == 0:
    print('ERROR: No GPUs detected in container')
    exit(1)
for i in range(gpu_count):
    print(f'  GPU {i}: {torch.cuda.get_device_name(i)}')
nccl_available = torch.distributed.is_nccl_available()
print(f'NCCL Available: {nccl_available}')
if not nccl_available:
    print('ERROR: NCCL is not available')
    exit(1)
print('SUCCESS: PyTorch CUDA/NCCL check passed')
" 2>&1; then
    echo "✗ ERROR: PyTorch CUDA/NCCL check failed on compute node"
    echo "  Distributed training requires CUDA and NCCL support."
    exit 1
fi
echo "✓ PyTorch CUDA/NCCL check passed on compute node"

# Test container on multiple compute nodes with GPU support (REQUIRED)
echo ""
echo "8. Multi-Node Container Test (with GPU):"
if ! srun --nodes=2 --ntasks=2 --gres=gpu:1 --time=2:00 \
    apptainer exec --nv "$CONTAINER" \
    python3 -c "import socket, torch; print(f'Node: {socket.gethostname()}, CUDA: {torch.cuda.is_available()}, GPUs: {torch.cuda.device_count()}')" 2>&1; then
    echo "✗ ERROR: Multi-node GPU test failed"
    echo "  Distributed training requires working GPU support across multiple nodes."
    exit 1
fi
echo "✓ Multi-node GPU test passed"

echo ""
echo "=== Check Complete ==="
echo "✓ All checks passed! Ready for distributed training."
