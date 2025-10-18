#!/bin/bash

# HPC Compute Image Setup Script (Simplified)
# Basic system preparation for HPC compute image

set -eo pipefail

echo "=== HPC Compute Setup Started ==="

# Fix broken beegfs-client-dkms package if present
# BeeGFS 7.4.4 DKMS module cannot build on kernel 6.12+
# This is expected in Packer build mode
echo "Checking for broken BeeGFS packages..."
if dpkg -s beegfs-client-dkms >/dev/null 2>&1; then
    echo "Found beegfs-client-dkms package - removing to prevent dpkg errors..."
    dpkg --remove --force-remove-reinstreq beegfs-client-dkms 2>&1 || true
    echo "Fixing broken dependencies..."
    apt-get install -f -y 2>&1 || true
    echo "BeeGFS DKMS cleanup completed"
else
    echo "No beegfs-client-dkms package found - skipping cleanup"
fi

# Update package lists
echo "Updating package lists..."
apt-get update -qq

# Install essential packages for Ansible and system management
echo "Installing essential packages..."
apt-get install -y -qq --no-install-recommends \
    acl \
    curl \
    wget \
    vim \
    htop

# Configure basic networking
echo "Configuring networking..."
systemctl enable NetworkManager

# Create default ethernet connection for DHCP
cat > /etc/NetworkManager/system-connections/default-ethernet.nmconnection << 'EOF'
[connection]
id=default-ethernet
type=ethernet
autoconnect=true

[ipv4]
method=auto

[ipv6]
method=auto
EOF

chmod 600 /etc/NetworkManager/system-connections/default-ethernet.nmconnection

# Basic cleanup
apt-get autoremove -y -qq
apt-get clean

echo "=== HPC Compute Setup Completed ==="
