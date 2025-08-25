#!/bin/bash

# HPC Base Image Setup Script
# This script installs networking tools and configures debugging capabilities
# for the HPC base image built by Packer

set -eo pipefail

set -x

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
    procps \
    network-manager \
    systemd-resolved

# Configure networking for libvirt environment
log "Configuring networking for libvirt environment..."

# Ensure NetworkManager is enabled and running
systemctl enable NetworkManager
# systemctl start NetworkManager

# Configure NetworkManager to use DHCP by default
cat > /etc/NetworkManager/conf.d/90-globally-managed-devices.conf << 'EOF'
[keyfile]
unmanaged-devices=*,except:type:wifi,except:type:wwan,except:type:ethernet
EOF

# Create a default ethernet connection that uses DHCP
# Note: No interface-name specified - will work with any ethernet interface
cat > /etc/NetworkManager/system-connections/default-ethernet.nmconnection << 'EOF'
[connection]
id=default-ethernet
type=ethernet
# No interface-name specified - will be applied to any available ethernet interface
autoconnect=true

[ethernet]
# No hardcoded MAC address - will use whatever is assigned to the VM

[ipv4]
method=auto
dns=auto

[ipv6]
method=auto
dns=auto
EOF

# Set proper permissions for NetworkManager connection files
chmod 600 /etc/NetworkManager/system-connections/default-ethernet.nmconnection

# Restart NetworkManager to apply changes
#systemctl restart NetworkManager

# Wait for network to be ready
# log "Waiting for network to be ready..."
# sleep 5

# # Verify network configuration
# log "Verifying network configuration..."
# ip addr show
# nmcli connection show

log "=== HPC Base Image Setup Completed ==="
