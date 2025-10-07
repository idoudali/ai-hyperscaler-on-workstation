#!/bin/bash
# Test convert-single.sh script correctness
# This validates the script without requiring Docker images

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERT_SINGLE="${SCRIPT_DIR}/convert-single.sh"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=== Testing convert-single.sh Script Correctness ==="
echo ""

# Test 1: Bash syntax validation
echo "1. Validating bash syntax..."
if bash -n "${CONVERT_SINGLE}"; then
    echo -e "   ${GREEN}✓${NC} Syntax valid"
else
    echo "   ✗ Syntax error found"
    exit 1
fi
echo ""

# Test 2: Script is executable
echo "2. Checking script is executable..."
if [ -x "${CONVERT_SINGLE}" ]; then
    echo -e "   ${GREEN}✓${NC} Script is executable"
else
    echo "   ✗ Script is not executable"
    exit 1
fi
echo ""

# Test 3: Help output works
echo "3. Testing help output..."
# Capture output and ignore exit code (usage() exits with 1)
set +e  # Temporarily disable exit on error
output=$("${CONVERT_SINGLE}" --help 2>&1)
set -e  # Re-enable exit on error
if echo "$output" | grep -q "Usage:"; then
    echo -e "   ${GREEN}✓${NC} Help output working"
else
    echo "   ✗ Help output not working"
    echo "   Output was: $output"
    exit 1
fi
echo ""

# Test 4: Error handling for missing arguments
echo "4. Testing error handling (missing arguments)..."
set +e  # Temporarily disable exit on error
output=$("${CONVERT_SINGLE}" 2>&1)
set -e  # Re-enable exit on error
if echo "$output" | grep -q "Missing required argument"; then
    echo -e "   ${GREEN}✓${NC} Error handling working"
else
    echo "   ✗ Error handling not working"
    echo "   Output was: $output"
    exit 1
fi
echo ""

# Test 5: Check required functions exist
echo "5. Checking required functions..."

if grep -q 'check_prerequisites()' "${CONVERT_SINGLE}"; then
    echo -e "   ${GREEN}✓${NC} check_prerequisites() found"
else
    echo "   ✗ check_prerequisites() not found"
    exit 1
fi

if grep -q 'convert_image()' "${CONVERT_SINGLE}"; then
    echo -e "   ${GREEN}✓${NC} convert_image() found"
else
    echo "   ✗ convert_image() not found"
    exit 1
fi

if grep -q 'log_error()' "${CONVERT_SINGLE}"; then
    echo -e "   ${GREEN}✓${NC} log_error() found"
else
    echo "   ✗ log_error() not found"
    exit 1
fi
echo ""

# Test 6: Check for proper error messages
echo "6. Validating error messages..."
if grep -q "HPC container manager CLI not found" "${CONVERT_SINGLE}"; then
    echo -e "   ${GREEN}✓${NC} CLI error message present"
else
    echo "   ✗ CLI error message missing"
    exit 1
fi

if grep -q "Apptainer not found" "${CONVERT_SINGLE}"; then
    echo -e "   ${GREEN}✓${NC} Apptainer error message present"
else
    echo "   ✗ Apptainer error message missing"
    exit 1
fi

if grep -q "Docker daemon not accessible" "${CONVERT_SINGLE}"; then
    echo -e "   ${GREEN}✓${NC} Docker error message present"
else
    echo "   ✗ Docker error message missing"
    exit 1
fi
echo ""

# Test 7: Check for proper environment variable handling
echo "7. Checking environment variable support..."
if grep -q 'HPC_CLI' "${CONVERT_SINGLE}"; then
    echo -e "   ${GREEN}✓${NC} HPC_CLI environment variable supported"
else
    echo "   ✗ HPC_CLI environment variable not supported"
    exit 1
fi
echo ""

echo "=== All Script Tests Passed ==="
echo ""
echo -e "${BLUE}Usage:${NC} ./containers/scripts/convert-single.sh pytorch-cuda12.1-mpi4.1:latest"
echo ""
