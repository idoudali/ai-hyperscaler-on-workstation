#!/bin/bash
#
# Setup Local Test Environment
# Creates a local test-run directory with all necessary files for testing
# without requiring sudo or system-level directories
#

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Local test environment directory
TEST_RUN_DIR="${TEST_RUN_DIR:-$SCRIPT_DIR/test-run}"

echo "Setting up local test environment in: $TEST_RUN_DIR"

# Create directory structure
mkdir -p "$TEST_RUN_DIR/usr/local/slurm/scripts"
mkdir -p "$TEST_RUN_DIR/usr/local/slurm/tools"
mkdir -p "$TEST_RUN_DIR/var/log/slurm/job-debug"
mkdir -p "$TEST_RUN_DIR/var/log/slurm/epilog"
mkdir -p "$TEST_RUN_DIR/var/log/slurm/prolog"

# Install epilog script
if [ -f "$PROJECT_ROOT/ansible/roles/slurm-compute/templates/epilog.sh.j2" ]; then
    cp "$PROJECT_ROOT/ansible/roles/slurm-compute/templates/epilog.sh.j2" \
       "$TEST_RUN_DIR/usr/local/slurm/scripts/epilog.sh"
    chmod 755 "$TEST_RUN_DIR/usr/local/slurm/scripts/epilog.sh"
    echo "✓ Epilog script installed"
else
    echo "✗ Epilog script template not found"
    exit 1
fi

# Install prolog script
if [ -f "$PROJECT_ROOT/ansible/roles/slurm-compute/templates/prolog.sh.j2" ]; then
    cp "$PROJECT_ROOT/ansible/roles/slurm-compute/templates/prolog.sh.j2" \
       "$TEST_RUN_DIR/usr/local/slurm/scripts/prolog.sh"
    chmod 755 "$TEST_RUN_DIR/usr/local/slurm/scripts/prolog.sh"
    echo "✓ Prolog script installed"
else
    echo "✗ Prolog script template not found"
    exit 1
fi

# Install diagnosis tool
if [ -f "$PROJECT_ROOT/ansible/roles/slurm-compute/files/diagnose_training_failure.py" ]; then
    cp "$PROJECT_ROOT/ansible/roles/slurm-compute/files/diagnose_training_failure.py" \
       "$TEST_RUN_DIR/usr/local/slurm/tools/diagnose_training_failure.py"
    chmod 755 "$TEST_RUN_DIR/usr/local/slurm/tools/diagnose_training_failure.py"
    echo "✓ Diagnosis tool installed"
else
    echo "✗ Diagnosis tool not found"
    exit 1
fi

# Export environment variables for tests to use
export TEST_SLURM_SCRIPTS_DIR="$TEST_RUN_DIR/usr/local/slurm/scripts"
export TEST_SLURM_TOOLS_DIR="$TEST_RUN_DIR/usr/local/slurm/tools"
export TEST_SLURM_LOG_DIR="$TEST_RUN_DIR/var/log/slurm"

# Create an environment file that tests can source
cat > "$TEST_RUN_DIR/test-env.sh" << EOF
# Test Environment Variables
# Source this file in test scripts to use local test environment
export TEST_SLURM_SCRIPTS_DIR="$TEST_RUN_DIR/usr/local/slurm/scripts"
export TEST_SLURM_TOOLS_DIR="$TEST_RUN_DIR/usr/local/slurm/tools"
export TEST_SLURM_LOG_DIR="$TEST_RUN_DIR/var/log/slurm"
EOF

echo ""
echo "Local test environment setup complete!"
echo ""
echo "Environment variables:"
echo "  TEST_SLURM_SCRIPTS_DIR=$TEST_SLURM_SCRIPTS_DIR"
echo "  TEST_SLURM_TOOLS_DIR=$TEST_SLURM_TOOLS_DIR"
echo "  TEST_SLURM_LOG_DIR=$TEST_SLURM_LOG_DIR"
echo ""
echo "Tests can source: $TEST_RUN_DIR/test-env.sh"
echo ""

exit 0
