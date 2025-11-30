#!/bin/bash
# Standalone script to start MLflow
# Usage: ./start-mlflow.sh [PORT] [DB_URI] [ARTIFACT_ROOT]

set -e

CONTAINER="${CONTAINER:-/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif}"
MLFLOW_BIN="${MLFLOW_BIN:-/mnt/beegfs/pytorch-env/bin/mlflow}"
PORT="${PORT:-5000}"
DB_URI="${DB_URI:-sqlite:////mnt/beegfs/monitoring/mlflow/db/mlflow.db}"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-/mnt/beegfs/monitoring/mlflow/artifacts}"

echo "Starting MLflow on port $PORT..."
echo "Container: $CONTAINER"
echo "Backend: $DB_URI"
echo "Artifacts: $ARTIFACT_ROOT"

# Ensure DB dir exists
DB_DIR=$(dirname "${DB_URI#sqlite:///}")
mkdir -p "$DB_DIR"
mkdir -p "$ARTIFACT_ROOT"

export APPTAINER_BIND="/mnt/beegfs:/mnt/beegfs"

apptainer exec "$CONTAINER" "$MLFLOW_BIN" server \
    --backend-store-uri "$DB_URI" \
    --default-artifact-root "$ARTIFACT_ROOT" \
    --host 0.0.0.0 \
    --port "$PORT"
