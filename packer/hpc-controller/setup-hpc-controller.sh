#!/bin/bash

# HPC Controller Image Setup Script (Simplified)
# Basic system preparation for HPC controller image

set -eo pipefail

echo "=== HPC Controller Setup Started ==="

# TASK-028.1: BeeGFS 8.1.0 Compatibility with Default Debian Trixie Kernel
# BeeGFS 8.1.0 supports kernel 6.12+ - using default Debian Trixie kernel
echo "================================================================"
echo "TASK-028.1: Using Default Debian Trixie Kernel for BeeGFS 8.1.0"
echo "================================================================"

# Display current kernel information
echo "Current kernel information:"
uname -r || echo "Kernel version check failed"
dpkg -l | grep -E 'linux-image-[0-9]' | awk '{print $2, $3}' || true

echo "================================================================"
echo "Debian Trixie default kernel will be used (6.12+ with BeeGFS 8.1.0 support)"
echo "================================================================"

# Clean up any broken BeeGFS packages from previous installations
# BeeGFS 8.1.0 DKMS module will be built during Ansible deployment
echo "Checking for broken BeeGFS packages..."
if dpkg -s beegfs-client-dkms >/dev/null 2>&1; then
    echo "Found beegfs-client-dkms package - checking status..."
    dpkg --configure -a 2>&1 || true
    apt-get install -f -y 2>&1 || true
    echo "BeeGFS package check completed"
else
    echo "No beegfs-client-dkms package found - clean install expected"
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

echo "=== HPC Controller Setup Completed ==="
