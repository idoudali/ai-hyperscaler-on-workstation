#!/bin/bash
# Entrypoint script for Slurm containers
# Configures the container based on SLURM_ROLE environment variable
set -euo pipefail

ROLE="${SLURM_ROLE:-controller}"
PACKAGE_DIR="${SLURM_PACKAGE_DIR:-/tmp/slurm-packages}"

echo "Starting Slurm container with role: $ROLE"

# Install Slurm packages if not already installed
if [ -d "$PACKAGE_DIR" ] && [ -n "$(ls -A $PACKAGE_DIR/*.deb 2>/dev/null)" ]; then
    export SLURM_ROLE="$ROLE"
    /usr/local/bin/install-slurm.sh
fi

# Wait for MUNGE key to be available (mounted as secret)
if [ ! -f /etc/munge/munge.key ]; then
    echo "WARNING: MUNGE key not found at /etc/munge/munge.key"
    echo "Waiting for MUNGE key to be mounted..."
    while [ ! -f /etc/munge/munge.key ]; do
        sleep 1
    done
fi

# Set correct permissions on MUNGE key
if [ -f /etc/munge/munge.key ]; then
    chown munge:munge /etc/munge/munge.key
    chmod 0600 /etc/munge/munge.key
fi

# Start MUNGE daemon
echo "Starting MUNGE daemon..."
munge -n || true  # Generate key if not exists (for testing only)
/usr/sbin/munged --force || true
sleep 2

# Role-specific startup
case "$ROLE" in
    controller)
        echo "Starting Slurm controller (slurmctld)..."
        exec /usr/sbin/slurmctld -D
        ;;
    compute)
        echo "Starting Slurm compute node (slurmd)..."
        exec /usr/sbin/slurmd -D
        ;;
    database)
        echo "Starting Slurm database daemon (slurmdbd)..."
        exec /usr/sbin/slurmdbd -D
        ;;
    *)
        echo "Unknown role: $ROLE"
        echo "Available roles: controller, compute, database"
        exec /bin/bash
        ;;
esac

