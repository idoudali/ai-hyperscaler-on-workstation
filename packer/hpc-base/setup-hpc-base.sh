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

# Install essential networking and debugging packages (minimal set)
log "Installing essential networking and debugging packages..."
apt-get install -y -qq --no-install-recommends \
    acl \
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

# Remove unnecessary packages and clean up
log "Cleaning up unnecessary packages..."
apt-get autoremove -y -qq
apt-get autoclean -qq

# Ensure ACL support is properly configured
log "Configuring ACL support for Ansible..."
# Check if ACL is available
if command -v setfacl >/dev/null 2>&1; then
    log "ACL support is available"
else
    log "WARNING: ACL support not available, Ansible may have permission issues"
fi

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

# Final size optimization
log "Performing final size optimization..."
# Remove unnecessary files that might have been created during setup
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
# Clear package cache
apt-get clean 2>/dev/null || true
# Remove any log files created during setup
find /var/log -name "*.log" -type f -exec truncate -s 0 {} + 2>/dev/null || true

log "=== HPC Base Image Setup Completed ==="
