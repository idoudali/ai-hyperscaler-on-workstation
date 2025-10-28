#!/bin/bash
#
# Setup Test Environment for Job Scripts Tests
# Installs required SLURM job scripts and creates necessary directories
#

set -euo pipefail

echo "Setting up SLURM job scripts test environment..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo"
    exit 1
fi

# Project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Project root: $PROJECT_ROOT"

# Create directories
echo "Creating directories..."
mkdir -p /usr/local/slurm/scripts
mkdir -p /usr/local/slurm/tools
mkdir -p /var/log/slurm/job-debug
mkdir -p /var/log/slurm/epilog
mkdir -p /var/log/slurm/prolog

# Set ownership for log directories (if slurm user exists)
if id slurm &>/dev/null; then
    echo "Setting ownership for log directories..."
    chown -R slurm:slurm /var/log/slurm
else
    echo "Warning: slurm user not found, skipping ownership change"
    # Make directories writable by all for testing
    chmod 777 /var/log/slurm/job-debug /var/log/slurm/epilog /var/log/slurm/prolog
fi

# Install epilog script
echo "Installing epilog script..."
if [ -f "$PROJECT_ROOT/ansible/roles/slurm-compute/templates/epilog.sh.j2" ]; then
    cp "$PROJECT_ROOT/ansible/roles/slurm-compute/templates/epilog.sh.j2" /usr/local/slurm/scripts/epilog.sh
    chmod 755 /usr/local/slurm/scripts/epilog.sh
    echo "✓ Epilog script installed"
else
    echo "✗ Epilog script template not found"
    exit 1
fi

# Install prolog script
echo "Installing prolog script..."
if [ -f "$PROJECT_ROOT/ansible/roles/slurm-compute/templates/prolog.sh.j2" ]; then
    cp "$PROJECT_ROOT/ansible/roles/slurm-compute/templates/prolog.sh.j2" /usr/local/slurm/scripts/prolog.sh
    chmod 755 /usr/local/slurm/scripts/prolog.sh
    echo "✓ Prolog script installed"
else
    echo "✗ Prolog script template not found"
    exit 1
fi

# Install diagnosis tool
echo "Installing diagnosis tool..."
if [ -f "$PROJECT_ROOT/ansible/roles/slurm-compute/files/diagnose_training_failure.py" ]; then
    cp "$PROJECT_ROOT/ansible/roles/slurm-compute/files/diagnose_training_failure.py" /usr/local/slurm/tools/diagnose_training_failure.py
    chmod 755 /usr/local/slurm/tools/diagnose_training_failure.py
    echo "✓ Diagnosis tool installed"
else
    echo "✗ Diagnosis tool not found"
    exit 1
fi

# Verify installations
echo ""
echo "Verifying installations..."
echo ""

# Check scripts
if [ -x /usr/local/slurm/scripts/epilog.sh ]; then
    echo "✓ Epilog script: /usr/local/slurm/scripts/epilog.sh"
else
    echo "✗ Epilog script not executable"
fi

if [ -x /usr/local/slurm/scripts/prolog.sh ]; then
    echo "✓ Prolog script: /usr/local/slurm/scripts/prolog.sh"
else
    echo "✗ Prolog script not executable"
fi

if [ -x /usr/local/slurm/tools/diagnose_training_failure.py ]; then
    echo "✓ Diagnosis tool: /usr/local/slurm/tools/diagnose_training_failure.py"
else
    echo "✗ Diagnosis tool not executable"
fi

# Check directories
echo ""
echo "Directories:"
for dir in /var/log/slurm/job-debug /var/log/slurm/epilog /var/log/slurm/prolog; do
    if [ -d "$dir" ]; then
        echo "✓ $dir ($(stat -c '%a %U:%G' "$dir"))"
    else
        echo "✗ $dir - not found"
    fi
done

echo ""
echo "Setup complete! You can now run the tests:"
echo "  cd $SCRIPT_DIR"
echo "  ./test-job-scripts-framework.sh run-tests"
echo ""
