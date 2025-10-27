#!/bin/bash
set -e

# Generic script to generate SSH keys and prepare cloud-init configuration
# This script is called from CMake to ensure proper out-of-source builds
# and supports all image types: cloud-base, cloud-gpu-worker, hpc-base, hpc-controller, and hpc-compute

SSH_KEYS_DIR="$1"
CLOUD_INIT_BUILD_DIR="$2"
IMAGE_TYPE="$3"  # "cloud-base", "cloud-gpu-worker", "hpc-base", "hpc-controller", or "hpc-compute"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <ssh_keys_dir> <cloud_init_build_dir> <image_type>"
    echo "  image_type: cloud-base, cloud-gpu-worker, hpc-base, hpc-controller, or hpc-compute"
    exit 1
fi

# Validate image type
if [ "$IMAGE_TYPE" != "cloud-base" ] && [ "$IMAGE_TYPE" != "cloud-gpu-worker" ] && [ "$IMAGE_TYPE" != "hpc-base" ] && [ "$IMAGE_TYPE" != "hpc-controller" ] && [ "$IMAGE_TYPE" != "hpc-compute" ]; then
    echo "Error: image_type must be 'cloud-base', 'cloud-gpu-worker', 'hpc-base', 'hpc-controller', or 'hpc-compute'"
    exit 1
fi

# Set source directory based on script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_CLOUD_INIT_DIR="${COMMON_DIR}/cloud-init"

# Ensure directories exist
mkdir -p "${SSH_KEYS_DIR}"
mkdir -p "${CLOUD_INIT_BUILD_DIR}"

echo "Generating SSH key pair for ${IMAGE_TYPE}..."
if [ -f "${SSH_KEYS_DIR}/id_rsa" ] && [ -f "${SSH_KEYS_DIR}/id_rsa.pub" ]; then
    echo "INFO: SSH keys already exist in ${SSH_KEYS_DIR}, reusing existing keys"
else
    ssh-keygen -t rsa -b 4096 -f "${SSH_KEYS_DIR}/id_rsa" -N "" -C "packer-build@${IMAGE_TYPE}"
fi

echo "Preparing cloud-init configuration for ${IMAGE_TYPE}..."

# Copy and update user-data with the generated SSH key (no .yml extension for cloud-init compatibility)
cp "${SOURCE_CLOUD_INIT_DIR}/${IMAGE_TYPE}-user-data.yml" "${CLOUD_INIT_BUILD_DIR}/user-data"
# shellcheck disable=SC2086
sed -i "s|REPLACE_SSH_KEY|$(cat ${SSH_KEYS_DIR}/id_rsa.pub)|" "${CLOUD_INIT_BUILD_DIR}/user-data"

# Copy and update meta-data with correct instance information
cp "${SOURCE_CLOUD_INIT_DIR}/${IMAGE_TYPE}-meta-data.yml" "${CLOUD_INIT_BUILD_DIR}/meta-data"

echo "SSH key generation and cloud-init preparation complete for ${IMAGE_TYPE}!"
