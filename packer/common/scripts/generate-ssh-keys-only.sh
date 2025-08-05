#!/bin/bash
set -e

# Simple script to generate SSH keys only (without cloud-init processing)
# This script is called from CMake to generate shared SSH keys for all Packer images

SSH_KEYS_DIR="$1"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <ssh_keys_dir>"
    exit 1
fi

# Ensure directory exists
mkdir -p "${SSH_KEYS_DIR}"

echo "Generating shared SSH key pair for Packer images..."
if [ -f "${SSH_KEYS_DIR}/id_rsa" ] && [ -f "${SSH_KEYS_DIR}/id_rsa.pub" ]; then
    echo "INFO: SSH keys already exist in ${SSH_KEYS_DIR}, reusing existing keys"
else
    ssh-keygen -t rsa -b 4096 -f "${SSH_KEYS_DIR}/id_rsa" -N "" -C "packer-build@shared"
fi

echo "Shared SSH key generation complete!"
