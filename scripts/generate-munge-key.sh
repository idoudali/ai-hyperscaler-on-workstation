#!/bin/bash
# Generate MUNGE key for Slurm cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${PROJECT_ROOT}/build/shared/munge"
KEY_FILE="${OUTPUT_DIR}/munge.key"

echo "Generating MUNGE key for Slurm cluster..."

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate MUNGE key using Docker (no need to install munge on host)
docker run --rm \
    -v "${OUTPUT_DIR}:/output" \
    ubuntu:22.04 bash -c "
        apt-get update -qq && \
        apt-get install -y -qq munge >/dev/null 2>&1 && \
        /usr/sbin/create-munge-key -f && \
        cp /etc/munge/munge.key /output/munge.key && \
        chmod 644 /output/munge.key
    "

if [ ! -f "$KEY_FILE" ]; then
    echo "ERROR: Failed to generate MUNGE key"
    exit 1
fi

echo "MUNGE key generated at: $KEY_FILE"
echo ""
echo "To create Kubernetes secret:"
echo "  kubectl create secret generic slurm-munge-key \\"
echo "    --from-file=munge.key=${KEY_FILE} \\"
echo "    --namespace=slurm"

