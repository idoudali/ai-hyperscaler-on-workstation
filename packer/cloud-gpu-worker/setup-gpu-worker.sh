#!/bin/bash

# Cloud GPU Worker Image Setup Script (Simplified)
# Basic system preparation for GPU-accelerated Kubernetes worker image

set -eo pipefail

echo "=== Cloud GPU Worker Setup Started ==="

# Display current kernel information for GPU driver compatibility
echo "Current kernel information:"
uname -r || echo "Kernel version check failed"
dpkg -l | grep -E 'linux-image-[0-9]' | awk '{print $2, $3}' || true

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

# Install GPU-specific prerequisites
echo "Installing GPU-specific prerequisites..."
# Install packages including kernel headers meta package
# linux-headers-cloud-amd64 is a meta package that automatically pulls
# the correct headers for the running cloud kernel
apt-get install -y -qq --no-install-recommends \
    pciutils \
    kmod \
    build-essential \
    dkms \
    linux-headers-cloud-amd64

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

echo "=== Cloud GPU Worker Setup Completed ==="
