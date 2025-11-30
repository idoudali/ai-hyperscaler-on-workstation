#!/bin/bash
# Setup Monitoring Environment
# Part of Task 055: Monitoring Infrastructure Setup

set -e

# Configuration
VENV_PATH="/mnt/beegfs/pytorch-env"
REQUIREMENTS_FILE="requirements-monitoring.txt"
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"

echo "=== Setting up Monitoring Environment ==="

# 1. Check if container exists
if [ ! -f "$CONTAINER" ]; then
    echo "ERROR: Container not found at $CONTAINER"
    echo "The monitoring environment must be created using the container to ensure binary compatibility."
    echo "Please ensure the container is available before running this script."
    exit 1
fi

echo "Using container python to ensure compatibility..."
PYTHON_CMD="apptainer exec --nv -B /mnt/beegfs:/mnt/beegfs $CONTAINER python3"

# 2. Create environment (if not exists)
if [ ! -d "$VENV_PATH" ]; then
    echo "Creating virtual environment at $VENV_PATH..."
    $PYTHON_CMD -m venv "$VENV_PATH" --system-site-packages
else
    echo "Using existing environment at $VENV_PATH"
fi

# 3. Install dependencies using the container context
echo "Installing monitoring tools..."
# We use the pip inside the venv, running via the container
PIP_CMD="apptainer exec --nv -B /mnt/beegfs:/mnt/beegfs $CONTAINER $VENV_PATH/bin/pip"

if [ -f "$REQUIREMENTS_FILE" ]; then
    $PIP_CMD install -r "$REQUIREMENTS_FILE"
else
    $PIP_CMD install tensorboard aim mlflow
fi

# 4. Verify installation
echo "Verifying installation..."
TEST_CMD="apptainer exec --nv -B /mnt/beegfs:/mnt/beegfs $CONTAINER $VENV_PATH/bin/python3"
$TEST_CMD -c "import tensorboard; print(f'TensorBoard: installed')"
$TEST_CMD -c "import aim; print(f'Aim: installed')"
$TEST_CMD -c "import mlflow; print(f'MLflow: installed')"

echo "=== Setup Complete ==="
echo "Environment created at: $VENV_PATH"
