#!/bin/bash
# Standalone script to start Aim
# Usage: ./start-aim.sh [PORT] [REPO_PATH]
#
# Repository Path Behavior:
# - Aim stores data in a .aim directory (the "repository")
# - REPO_PATH can be either:
#   1. Parent directory: /path/to/repo (Aim will use /path/to/repo/.aim)
#   2. .aim directory: /path/to/repo/.aim (explicit path to repository)
# - The script handles both formats automatically
#
# See: https://aimstack.readthedocs.io/en/latest/quick_start/setup.html

set -e

# Help message
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: ./start-aim.sh [PORT] [REPO_PATH]"
    echo ""
    echo "Starts the Aim server using Apptainer."
    echo ""
    echo "Arguments:"
    echo "  PORT        Port to listen on (default: 43800)"
    echo "  REPO_PATH   Path to Aim repository directory"
    echo "              Can be parent dir (/path/to/repo) or .aim dir (/path/to/repo/.aim)"
    echo "              Default: /mnt/beegfs/monitoring/aim/.aim"
    echo ""
    echo "Environment Variables:"
    echo "  CONTAINER   Path to Apptainer container image"
    echo "  AIM_BIN     Path to Aim executable inside the container"
    echo "  PORT        Alternative to first argument"
    echo "  AIM_REPO    Alternative to second argument"
    echo ""
    echo "Repository Path:"
    echo "  Aim stores tracked data in a .aim directory. You can specify either:"
    echo "  - Parent directory: /mnt/beegfs/monitoring/aim (Aim uses .aim inside)"
    echo "  - Repository path: /mnt/beegfs/monitoring/aim/.aim (explicit)"
    echo ""
    echo "  When using Python SDK: Run(repo='/path/to/repo') creates /path/to/repo/.aim"
    echo "  See: https://aimstack.readthedocs.io/en/latest/using/configure_runs.html"
    echo ""
    exit 0
fi

CONTAINER="${CONTAINER:-/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1-oumi.sif}"
# Use container's venv where Aim is installed
AIM_BIN="${AIM_BIN:-/venv/bin/aim}"

# Handle arguments
if [ -n "$1" ]; then PORT="$1"; else PORT="${PORT:-43800}"; fi
if [ -n "$2" ]; then AIM_REPO="$2"; else AIM_REPO="${AIM_REPO:-/mnt/beegfs/monitoring/aim/.aim}"; fi

echo "Starting Aim on port $PORT..."
echo "Container: $CONTAINER"
echo "Repo: $AIM_REPO"

export APPTAINER_BIND="/mnt/beegfs:/mnt/beegfs"

# Normalize repository path
# If AIM_REPO ends with /.aim, use it directly
# Otherwise, treat it as parent directory and append /.aim
if [[ "$AIM_REPO" == *"/.aim" ]]; then
    # Already points to .aim directory
    REPO_DIR="$(dirname "$AIM_REPO")"
    AIM_REPO_PATH="$AIM_REPO"
else
    # Points to parent directory, append .aim
    REPO_DIR="$AIM_REPO"
    AIM_REPO_PATH="$AIM_REPO/.aim"
fi

# Ensure repo exists (init if needed)
if [ ! -d "$AIM_REPO_PATH" ]; then
    echo "Initializing Aim repo at $AIM_REPO_PATH..."
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR"
    apptainer exec "$CONTAINER" "$AIM_BIN" init
fi

# Run Aim UI
# The --repo flag accepts either the parent directory or the .aim path
# We use the parent directory for consistency with aim init behavior
cd "$REPO_DIR"
apptainer exec "$CONTAINER" "$AIM_BIN" up --host 0.0.0.0 --port "$PORT" --repo "$REPO_DIR"
