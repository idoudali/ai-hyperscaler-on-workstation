#!/bin/bash
# Test test-apptainer-local.sh script correctness
# This validates the script without requiring Apptainer images

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_SCRIPT="${SCRIPT_DIR}/test-apptainer-local.sh"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=== Testing test-apptainer-local.sh Script Correctness ==="
echo ""

# Test 1: Bash syntax validation
echo "1. Validating bash syntax..."
if bash -n "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} Syntax valid"
else
    echo "   ✗ Syntax error found"
    exit 1
fi
echo ""

# Test 2: Script is executable
echo "2. Checking script is executable..."
if [ -x "${TEST_SCRIPT}" ]; then
    echo -e "   ${GREEN}✓${NC} Script is executable"
else
    echo "   ✗ Script is not executable"
    exit 1
fi
echo ""

# Test 3: Help output works
echo "3. Testing help output..."
set +e
output=$("${TEST_SCRIPT}" --help 2>&1)
set -e
if echo "$output" | grep -q "Usage:"; then
    echo -e "   ${GREEN}✓${NC} Help output working"
else
    echo "   ✗ Help output not working"
    echo "   Output was: $output"
    exit 1
fi
echo ""

# Test 4: Error handling - check for proper error messages in code
echo "4. Checking error handling code..."

if grep -q "No Apptainer images found" "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} 'No images found' error message present"
else
    echo "   ✗ 'No images found' error message missing"
    exit 1
fi

if grep -q "Apptainer directory not found" "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} 'Directory not found' error message present"
else
    echo "   ✗ 'Directory not found' error message missing"
    exit 1
fi

if grep -q "Image not found" "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} 'Image not found' error message present"
else
    echo "   ✗ 'Image not found' error message missing"
    exit 1
fi
echo ""

# Test 5: Check required functions exist
echo "5. Checking required test functions..."

if grep -q 'test_basic_functionality()' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} test_basic_functionality() found"
else
    echo "   ✗ test_basic_functionality() not found"
    exit 1
fi

if grep -q 'test_pytorch()' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} test_pytorch() found"
else
    echo "   ✗ test_pytorch() not found"
    exit 1
fi

if grep -q 'test_cuda()' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} test_cuda() found"
else
    echo "   ✗ test_cuda() not found"
    exit 1
fi

if grep -q 'test_mpi()' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} test_mpi() found"
else
    echo "   ✗ test_mpi() not found"
    exit 1
fi
echo ""

# Test 6: Check for proper command-line options
echo "6. Checking command-line option support..."

if grep -q '\-\-verbose' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} --verbose option supported"
else
    echo "   ✗ --verbose option not found"
    exit 1
fi

if grep -q '\-\-gpu' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} --gpu option supported"
else
    echo "   ✗ --gpu option not found"
    exit 1
fi
echo ""

# Test 7: Check for proper Apptainer execution
echo "7. Checking Apptainer execution commands..."

if grep -q 'apptainer exec' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} apptainer exec commands present"
else
    echo "   ✗ apptainer exec commands not found"
    exit 1
fi

if grep -q '\-\-nv' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} GPU support flag (--nv) present"
else
    echo "   ✗ GPU support flag not found"
    exit 1
fi
echo ""

# Test 8: Check for test result tracking
echo "8. Checking test result tracking..."

if grep -q 'tests_passed' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} Test pass counter found"
else
    echo "   ✗ Test pass counter not found"
    exit 1
fi

if grep -q 'tests_failed' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} Test fail counter found"
else
    echo "   ✗ Test fail counter not found"
    exit 1
fi

if grep -q 'total_passed' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} Total pass counter found"
else
    echo "   ✗ Total pass counter not found"
    exit 1
fi

if grep -q 'total_failed' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} Total fail counter found"
else
    echo "   ✗ Total fail counter not found"
    exit 1
fi
echo ""

# Test 9: Check for logging functions
echo "9. Checking logging functions..."

if grep -q 'log_info()' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} log_info() found"
else
    echo "   ✗ log_info() not found"
    exit 1
fi

if grep -q 'log_success()' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} log_success() found"
else
    echo "   ✗ log_success() not found"
    exit 1
fi

if grep -q 'log_error()' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} log_error() found"
else
    echo "   ✗ log_error() not found"
    exit 1
fi
echo ""

# Test 10: Check for proper cleanup
echo "10. Checking cleanup and exit handling..."

if grep -q 'run_in_container()' "${TEST_SCRIPT}"; then
    echo -e "   ${GREEN}✓${NC} Container execution wrapper found"
else
    echo "   ✗ Container execution wrapper not found"
    exit 1
fi
echo ""

echo "=== All Script Tests Passed ==="
echo ""
echo -e "${BLUE}Usage Examples:${NC}"
echo "  # Test all images"
echo "  ./containers/scripts/test-apptainer-local.sh"
echo ""
echo "  # Test specific image with GPU"
echo "  ./containers/scripts/test-apptainer-local.sh pytorch-cuda12.1-mpi4.1.sif --gpu"
echo ""
echo "  # Verbose output"
echo "  ./containers/scripts/test-apptainer-local.sh --verbose"
echo ""
