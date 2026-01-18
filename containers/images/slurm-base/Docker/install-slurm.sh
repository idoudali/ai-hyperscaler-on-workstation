#!/bin/bash
# Install Slurm packages from /tmp/slurm-packages directory
set -euo pipefail

SLURM_VERSION="${SLURM_VERSION:-24.11.0}"
PACKAGE_DIR="${SLURM_PACKAGE_DIR:-/tmp/slurm-packages}"
ROLE="${SLURM_ROLE:-all}"

if [ ! -d "$PACKAGE_DIR" ]; then
    echo "ERROR: Package directory $PACKAGE_DIR does not exist"
    exit 1
fi

# Check if packages are already installed
if command -v slurmctld &> /dev/null || command -v slurmd &> /dev/null; then
    echo "Slurm appears to be already installed, skipping package installation"
    exit 0
fi

echo "Installing Slurm packages from $PACKAGE_DIR..."

# Install common packages (always needed)
COMMON_PACKAGES=(
    "slurm-smd_${SLURM_VERSION}-1_amd64.deb"
    "slurm-smd-client_${SLURM_VERSION}-1_amd64.deb"
)

# Role-specific packages
if [ "$ROLE" = "controller" ] || [ "$ROLE" = "all" ]; then
    COMMON_PACKAGES+=(
        "slurm-smd-slurmctld_${SLURM_VERSION}-1_amd64.deb"
        "slurm-smd-slurmdbd_${SLURM_VERSION}-1_amd64.deb"
    )
fi

if [ "$ROLE" = "compute" ] || [ "$ROLE" = "all" ]; then
    COMMON_PACKAGES+=(
        "slurm-smd-slurmd_${SLURM_VERSION}-1_amd64.deb"
    )
fi

# Install packages
for pkg in "${COMMON_PACKAGES[@]}"; do
    pkg_path="${PACKAGE_DIR}/${pkg}"
    if [ -f "$pkg_path" ]; then
        echo "Installing $pkg..."
        dpkg -i "$pkg_path" || apt-get install -f -y
    else
        echo "WARNING: Package $pkg not found at $pkg_path"
    fi
done

# Install any missing dependencies
apt-get update && apt-get install -f -y

echo "Slurm packages installed successfully"

