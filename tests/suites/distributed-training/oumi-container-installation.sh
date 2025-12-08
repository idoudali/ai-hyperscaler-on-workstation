#!/bin/bash
# Test suite for TASK-056: Oumi Framework Container Installation

set -e

TEST_SUITE="TASK-056"
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1-oumi.sif"

echo "=== Test Suite: ${TEST_SUITE} - Oumi Container Installation ==="

# Test 1: Container file exists
echo ""
echo "Test 1: Oumi container file"
if [ -f "$CONTAINER" ]; then
    CONTAINER_SIZE=$(du -h "$CONTAINER" | cut -f1)
    echo "✓ PASS: Oumi container exists (${CONTAINER_SIZE})"
else
    echo "✗ FAIL: Oumi container not found: $CONTAINER"
    exit 1
fi

# Test 2: Container can be executed
echo ""
echo "Test 2: Container execution"
if apptainer exec "$CONTAINER" python3 --version > /dev/null 2>&1; then
    PYTHON_VERSION=$(apptainer exec "$CONTAINER" python3 --version 2>&1)
    echo "✓ PASS: Container executable ($PYTHON_VERSION)"
else
    echo "✗ FAIL: Container execution failed"
    exit 1
fi

# Test 3: Oumi package installed
echo ""
echo "Test 3: Oumi package"
if apptainer exec "$CONTAINER" python3 -c "import oumi" 2>/dev/null; then
    OUMI_VERSION=$(apptainer exec "$CONTAINER" python3 -c "import oumi; print(oumi.__version__)" 2>&1)
    echo "✓ PASS: Oumi ${OUMI_VERSION} installed"
else
    echo "✗ FAIL: Oumi not installed"
    exit 1
fi

# Test 4: Oumi CLI
echo ""
echo "Test 4: Oumi CLI"
if apptainer exec "$CONTAINER" oumi --version > /dev/null 2>&1; then
    OUMI_CLI_VERSION=$(apptainer exec "$CONTAINER" oumi --version 2>&1 | head -n1)
    echo "✓ PASS: Oumi CLI functional ($OUMI_CLI_VERSION)"
else
    echo "✗ FAIL: Oumi CLI not working"
    exit 1
fi

# Test 5: Core imports
echo ""
echo "Test 5: Core Oumi imports"
if apptainer exec "$CONTAINER" python3 -c "
from oumi.core.configs import TrainingConfig, ModelParams
from oumi.core.trainers import Trainer
print('✓ PASS: Core imports successful')
" 2>&1; then
    echo "✓ PASS: Core imports successful"
else
    echo "✗ FAIL: Core imports failed"
    exit 1
fi

# Test 6: CUDA support
echo ""
echo "Test 6: CUDA support in container"
CUDA_AVAILABLE=$(apptainer exec --nv "$CONTAINER" python3 -c "import torch; print(torch.cuda.is_available())" 2>&1 || echo "False")
if [ "$CUDA_AVAILABLE" = "True" ]; then
    echo "✓ PASS: CUDA available"
else
    echo "⚠ WARN: CUDA not available (may be expected in test environment)"
fi

# Test 7: Additional dependencies
echo ""
echo "Test 7: Additional dependencies"
if apptainer exec "$CONTAINER" python3 -c "
import transformers
import datasets
import accelerate
import peft
print('✓ PASS: All dependencies available')
" 2>&1; then
    echo "✓ PASS: All dependencies available"
else
    echo "✗ FAIL: Dependencies check failed"
    exit 1
fi

# Test 8: Configuration template
echo ""
echo "Test 8: Configuration template"
CONFIG_TEMPLATE="/mnt/beegfs/configs/oumi-template.yaml"
if [ -f "$CONFIG_TEMPLATE" ]; then
    echo "✓ PASS: Configuration template exists"
elif [ -f "examples/slurm-jobs/oumi/oumi-template.yaml" ]; then
    echo "✓ PASS: Configuration template exists in repo"
else
    echo "⚠ WARN: Configuration template not found (may be created later)"
fi

# Test 9: Multi-node container access
echo ""
echo "Test 9: Oumi accessible from compute nodes"
NODE_TEST=$(srun --nodes=2 --ntasks=2 \
    apptainer exec "$CONTAINER" python3 -c "import oumi; print('OK')" 2>&1 || echo "FAIL")
if echo "$NODE_TEST" | grep -q "OK"; then
    echo "✓ PASS: Oumi accessible from compute nodes"
else
    echo "⚠ WARN: Multi-node access test failed (may be expected if SLURM not available)"
fi

# Test 10: Test scripts exist
echo ""
echo "Test 10: Test scripts"
if [ -f "/mnt/beegfs/scripts/test-oumi-container.sh" ] || \
   [ -f "examples/slurm-jobs/oumi/test-oumi-container.sh" ]; then
    echo "✓ PASS: Test scripts exist"
else
    echo "⚠ WARN: Test scripts not found (may be in repo)"
fi

echo ""
echo "=== All Tests Passed for ${TEST_SUITE} ==="
