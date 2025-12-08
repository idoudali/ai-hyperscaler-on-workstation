#!/bin/bash
# Standalone script to start TensorBoard
# Usage: ./start-tensorboard.sh [PORT] [LOG_DIR]

set -e

CONTAINER="${CONTAINER:-/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1-oumi.sif}"
# Use container's venv where PyTorch and TensorBoard are installed
VENV_PYTHON="${VENV_PYTHON:-/venv/bin/python3}"
TENSORBOARD_BIN="${TENSORBOARD_BIN:-/venv/bin/tensorboard}"
PORT="${PORT:-6006}"
LOG_DIR="${LOG_DIR:-/mnt/beegfs/experiments/logs}"

# If TENSORBOARD_BIN doesn't exist, try using python -m tensorboard
# Use array-based command construction to properly handle multi-word commands
if [ ! -f "$TENSORBOARD_BIN" ]; then
    CMD=("$VENV_PYTHON" -m tensorboard.main)
else
    CMD=("$TENSORBOARD_BIN")
fi

echo "Starting TensorBoard on port $PORT..."
echo "Container: $CONTAINER"
echo "Log Dir: $LOG_DIR"

export APPTAINER_BIND="/mnt/beegfs:/mnt/beegfs"

apptainer exec "$CONTAINER" "${CMD[@]}" \
    --logdir "$LOG_DIR" \
    --host 0.0.0.0 \
    --port "$PORT" \
    --reload_interval 30
