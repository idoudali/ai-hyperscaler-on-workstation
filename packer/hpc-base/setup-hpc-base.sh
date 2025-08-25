#!/bin/bash

# HPC Base Image Setup Script
# This script installs networking tools and configures debugging capabilities
# for the HPC base image built by Packer

set -e

echo "=== HPC Base Image Setup Started ==="
echo "Timestamp: $(date)"

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update package lists
log "Updating package lists..."
apt-get update -qq

# Install essential networking and debugging packages
log "Installing networking and debugging packages..."
apt-get install -y -qq \
    net-tools \
    ifupdown \
    curl \
    wget \
    vim \
    htop \
    lsof \
    procps
