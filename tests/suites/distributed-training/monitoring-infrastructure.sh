#!/bin/bash
# Test suite for TASK-055: Monitoring Infrastructure Setup

set -e

TEST_SUITE="TASK-055"

echo "=== Test Suite: ${TEST_SUITE} - Monitoring Infrastructure ==="

# Test 1: Python packages installed
echo ""
echo "Test 1: Monitoring packages installed"
PACKAGES=("tensorboard" "aim" "mlflow")
for pkg in "${PACKAGES[@]}"; do
    if python3 -c "import $pkg" 2>/dev/null; then
        echo "✓ PASS: $pkg installed"
    else
        echo "✗ FAIL: $pkg not installed"
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
    fi
done

# Test 3: Aim repository initialized
echo ""
echo "Test 3: Aim repository initialization"
if [ -d "/mnt/beegfs/monitoring/aim/.aim" ]; then
    echo "✓ PASS: Aim repository initialized"
else
    echo "✗ FAIL: Aim repository not initialized"
fi

# Test 4: Server scripts exist
echo ""
echo "Test 4: Server launch scripts"
SCRIPTS=(
    "$PROJECT_ROOT/examples/slurm-jobs/monitoring/tensorboard-server.sbatch"
    "$PROJECT_ROOT/examples/slurm-jobs/monitoring/aim-server.sbatch"
    "$PROJECT_ROOT/examples/slurm-jobs/monitoring/mlflow-server.sbatch"
)
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "✓ PASS: $script exists"
    else
        echo "✗ FAIL: $script not found"
    fi
done

# Test 5: Management script
echo ""
echo "Test 5: Server management script"
if [ -f "$PROJECT_ROOT/scripts/manage-monitoring-servers.sh" ]; then
    echo "✓ PASS: Management script found"
else
    echo "✗ FAIL: Management script not found"
    exit 1
fi

echo ""
echo "=== Tests Completed for ${TEST_SUITE} ==="
