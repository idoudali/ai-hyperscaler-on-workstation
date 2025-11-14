#!/bin/bash
# Teardown Local Test Environment
# Cleans up the local test-run directory

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Local test environment directory
TEST_RUN_DIR="${TEST_RUN_DIR:-$SCRIPT_DIR/test-run}"

if [ -d "$TEST_RUN_DIR" ]; then
    echo "Cleaning up local test environment: $TEST_RUN_DIR"
    rm -rf "$TEST_RUN_DIR"
    echo "✓ Test environment cleaned up"
else
    echo "Test environment directory not found: $TEST_RUN_DIR"
fi

exit 0
