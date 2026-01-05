#!/bin/bash
# Test Oumi container basic functionality

set -e

CONTAINER="${1:-/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1-oumi.sif}"

echo "=== Oumi Container Validation Test ==="
echo "Container: $CONTAINER"
echo ""

# Check if container exists
if [ ! -f "$CONTAINER" ]; then
    echo "✗ FAIL: Container not found: $CONTAINER"
    exit 1
fi

echo "✓ Container file exists"
echo ""

# Test 1: Python version
echo "Test 1: Python version"
PYTHON_VERSION=$(apptainer exec "$CONTAINER" python3 --version 2>&1)
echo "  $PYTHON_VERSION"
echo ""

# Test 2: PyTorch installation
echo "Test 2: PyTorch installation"
PYTORCH_VERSION=$(apptainer exec "$CONTAINER" python3 -c "import torch; print(torch.__version__)" 2>&1)
echo "  PyTorch: $PYTORCH_VERSION"
echo ""

# Test 3: CUDA availability
echo "Test 3: CUDA support"
CUDA_AVAILABLE=$(apptainer exec --nv "$CONTAINER" python3 -c "import torch; print(torch.cuda.is_available())" 2>&1)
echo "  CUDA Available: $CUDA_AVAILABLE"
if [ "$CUDA_AVAILABLE" = "True" ]; then
    CUDA_VERSION=$(apptainer exec --nv "$CONTAINER" python3 -c "import torch; print(torch.version.cuda)" 2>&1)
    GPU_COUNT=$(apptainer exec --nv "$CONTAINER" python3 -c "import torch; print(torch.cuda.device_count())" 2>&1)
    echo "  CUDA Version: $CUDA_VERSION"
    echo "  GPU Count: $GPU_COUNT"
fi
echo ""

# Test 4: Oumi installation
echo "Test 4: Oumi framework"
if apptainer exec "$CONTAINER" python3 -c "import oumi" 2>/dev/null; then
    OUMI_VERSION=$(apptainer exec "$CONTAINER" python3 -c "import oumi; print(oumi.__version__)" 2>&1)
    echo "  ✓ Oumi installed: $OUMI_VERSION"
else
    echo "  ✗ FAIL: Oumi not installed"
    exit 1
fi
echo ""

# Test 5: Oumi CLI
echo "Test 5: Oumi CLI"
if apptainer exec "$CONTAINER" oumi --version > /dev/null 2>&1; then
    OUMI_CLI_VERSION=$(apptainer exec "$CONTAINER" oumi --version 2>&1 | head -n1)
    echo "  ✓ Oumi CLI available: $OUMI_CLI_VERSION"
else
    echo "  ✗ FAIL: Oumi CLI not available"
    exit 1
fi
echo ""

# Test 6: Core Oumi imports
echo "Test 6: Core Oumi imports"
apptainer exec "$CONTAINER" python3 -c "
from oumi.core.configs import TrainingConfig, ModelParams
from oumi.core.trainers import Trainer
print('  ✓ TrainingConfig imported successfully')
print('  ✓ ModelParams imported successfully')
print('  ✓ Trainer imported successfully')
" || { echo "  ✗ FAIL: Core imports failed"; exit 1; }
echo ""

# Test 7: Additional dependencies
echo "Test 7: Additional dependencies"
apptainer exec "$CONTAINER" python3 -c "
import transformers
import datasets
import accelerate
import peft
print('  ✓ transformers: ' + transformers.__version__)
print('  ✓ datasets: ' + datasets.__version__)
print('  ✓ accelerate: ' + accelerate.__version__)
print('  ✓ peft: ' + peft.__version__)
" || { echo "  ✗ FAIL: Dependencies check failed"; exit 1; }
echo ""

# Test 8: Monitoring tools
echo "Test 8: Monitoring tools"
apptainer exec "$CONTAINER" python3 -c "
import tensorboard
import aim
import mlflow
print('  ✓ tensorboard available')
print('  ✓ aim available')
print('  ✓ mlflow available')
" || { echo "  ✗ FAIL: Monitoring tools check failed"; exit 1; }
echo ""

# Test 9: MPI support
echo "Test 9: MPI support"
MPI_VERSION=$(apptainer exec "$CONTAINER" mpirun --version 2>&1 | head -n1)
echo "  $MPI_VERSION"
apptainer exec "$CONTAINER" python3 -c "import mpi4py; print('  ✓ mpi4py available')" || { echo "  ✗ FAIL: mpi4py not available"; exit 1; }
echo ""

echo "=== All Container Tests Passed ==="
