#!/bin/bash
#
# Distributed Training Test Suite - BATS Runner
# Executes all BATS tests with JUnit XML report generation
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# Check if BATS is installed
if ! command -v bats >/dev/null 2>&1; then
    echo "ERROR: BATS is not installed"
    echo "Install with: sudo apt-get install bats (or bats-core on some systems)"
    echo "Or see: https://bats-core.readthedocs.io/en/stable/installation.html"
    exit 1
fi

# BATS test files
BATS_FILES=(
    "$SCRIPT_DIR/check-pytorch-environment.bats"
    # "$SCRIPT_DIR/check-mnist-ddp-job.bats" # Will be added in Task 54
    # "$SCRIPT_DIR/check-monitoring-infrastructure.bats" # Will be added in Task 55
    # "$SCRIPT_DIR/check-oumi-installation.bats" # Will be added in Task 56
    # "$SCRIPT_DIR/check-smollm-finetuning.bats" # Will be added in Task 59
)

# Filter for existing files
EXISTING_BATS_FILES=()
for f in "${BATS_FILES[@]}"; do
    if [[ -f "$f" ]]; then
        EXISTING_BATS_FILES+=("$f")
    fi
done

if [[ ${#EXISTING_BATS_FILES[@]} -eq 0 ]]; then
    echo "No BATS test files found."
    exit 0
fi

echo "=========================================="
echo "Distributed Training Test Suite (BATS)"
echo "=========================================="
echo "Log Directory: $LOG_DIR"
echo ""

# Run BATS tests
# Use TAP formatter for non-interactive SSH sessions (no terminal)
# --formatter pretty requires tput/terminal which isn't available over SSH
export TERM="${TERM:-dumb}"

bats --formatter tap \
     --timing \
     --print-output-on-failure \
     "${EXISTING_BATS_FILES[@]}" \
     2>&1 | tee "$LOG_DIR/bats-output.log"

exit_code=${PIPESTATUS[0]}

echo ""
echo "=========================================="
if [ "$exit_code" -eq 0 ]; then
    echo "✓ All tests passed!"
else
    echo "✗ Some tests failed (exit code: $exit_code)"
fi
echo "=========================================="
echo "Test output log: $LOG_DIR/bats-output.log"

exit "$exit_code"
