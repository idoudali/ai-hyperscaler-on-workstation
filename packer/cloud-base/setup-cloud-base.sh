#!/bin/bash

# Cloud Base Image Setup Script (Simplified)
# Basic system preparation for Kubernetes cloud base image

set -eo pipefail

echo "=== Cloud Base Setup Started ==="

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

echo "=== Cloud Base Setup Completed ==="
