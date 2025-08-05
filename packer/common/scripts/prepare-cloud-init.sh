#!/bin/bash
set -e

# Script to prepare cloud-init configuration using existing SSH keys
# This script copies and processes cloud-init files for a specific image type

SSH_KEYS_DIR="$1"
CLOUD_INIT_BUILD_DIR="$2"
IMAGE_TYPE="$3"  # "cloud-base" or "hpc-base"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <ssh_keys_dir> <cloud_init_build_dir> <image_type>"
    echo "  image_type: cloud-base or hpc-base"
    exit 1
fi

# Validate image type
if [ "$IMAGE_TYPE" != "cloud-base" ] && [ "$IMAGE_TYPE" != "hpc-base" ]; then
    echo "Error: image_type must be 'cloud-base' or 'hpc-base'"
    exit 1
fi

# Validate SSH keys exist
if [ ! -f "${SSH_KEYS_DIR}/id_rsa.pub" ]; then
    echo "Error: SSH public key not found at ${SSH_KEYS_DIR}/id_rsa.pub"
    echo "Make sure to run generate-shared-ssh-keys target first"
    exit 1
fi

# Set source directory based on script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_CLOUD_INIT_DIR="${COMMON_DIR}/cloud-init"

# Ensure directories exist
mkdir -p "${CLOUD_INIT_BUILD_DIR}"

echo "Preparing cloud-init configuration for ${IMAGE_TYPE}..."

# Copy and update user-data with the generated SSH key (no .yml extension for cloud-init compatibility)
cp "${SOURCE_CLOUD_INIT_DIR}/${IMAGE_TYPE}-user-data.yml" "${CLOUD_INIT_BUILD_DIR}/user-data"
SSH_PUB_KEY="$(cat "${SSH_KEYS_DIR}/id_rsa.pub")"
sed -i "s|REPLACE_SSH_KEY|${SSH_PUB_KEY}|g" "${CLOUD_INIT_BUILD_DIR}/user-data"

# Copy and update meta-data with correct instance information
cp "${SOURCE_CLOUD_INIT_DIR}/${IMAGE_TYPE}-meta-data.yml" "${CLOUD_INIT_BUILD_DIR}/meta-data"

echo "Cloud-init preparation complete for ${IMAGE_TYPE}!"
