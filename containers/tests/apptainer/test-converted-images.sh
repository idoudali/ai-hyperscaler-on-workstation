#!/bin/bash
# Test converted Apptainer images for functionality and correctness
# Usage: ./test-converted-images.sh [image.sif]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
APPTAINER_DIR="${PROJECT_ROOT}/build/containers/apptainer"
LOG_DIR="${PROJECT_ROOT}/build/test-logs/apptainer"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Create log directory
mkdir -p "${LOG_DIR}"

# Usage information
usage() {
    cat << EOF
Usage: $0 [IMAGE.sif] [OPTIONS]

Test converted Apptainer images for functionality and correctness.

Arguments:
  IMAGE.sif         Path to Apptainer image to test (optional)
                    If not provided, tests all images in build/containers/apptainer/

Options:
  --verbose         Show detailed output
  -h, --help        Show this help message

Tests:
  - Image format and integrity
  - File system structure
  - Package installations
  - Library availability
  - Metadata correctness

EOF
    exit 1
}

# Test image format
test_image_format() {
    local image="$1"
    local test_name="Image Format"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check if file exists
    if [[ ! -f "${image}" ]]; then
        log_error "  ✗ Image file does not exist"
        ((TESTS_FAILED++))
        return 1
    fi

    # Check file size
    local size
    size=$(stat -c%s "${image}")
    if [[ ${size} -lt 1048576 ]]; then  # Less than 1MB is suspicious
        log_error "  ✗ Image file too small: ${size} bytes"
        ((TESTS_FAILED++))
        return 1
    fi

    # Check SIF format
    if ! file "${image}" | grep -q "Singularity Image Format"; then
        log_error "  ✗ Not a valid Singularity Image Format file"
        ((TESTS_FAILED++))
        return 1
    fi

    log_success "  ✓ Valid SIF format ($(du -h "${image}" | cut -f1))"
    ((TESTS_PASSED++))
    return 0
}

# Test image inspection
test_image_inspection() {
    local image="$1"
    local test_name="Image Inspection"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Test apptainer inspect
    local inspect_output
    if ! inspect_output=$(apptainer inspect "${image}" 2>&1); then
        log_error "  ✗ Failed to inspect image"
        log_error "    ${inspect_output}"
        ((TESTS_FAILED++))
        return 1
    fi

    # Check for required labels
    local has_labels=false
    if echo "${inspect_output}" | grep -q -E "(org\.|Author|Version)"; then
        has_labels=true
    fi

    if [[ "${has_labels}" == "true" ]]; then
        log_success "  ✓ Image has metadata labels"
    else
        log_warning "  ⚠ Image missing metadata labels"
    fi

    log_success "  ✓ Image inspection successful"
    ((TESTS_PASSED++))
    return 0
}

# Test basic execution
test_basic_execution() {
    local image="$1"
    local test_name="Basic Execution"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Test simple command execution
    if ! apptainer exec "${image}" echo "test" | grep -q "test"; then
        log_error "  ✗ Failed to execute basic command"
        ((TESTS_FAILED++))
        return 1
    fi

    log_success "  ✓ Basic command execution works"

    # Test environment
    if ! apptainer exec "${image}" env | grep -q "PATH"; then
        log_error "  ✗ Environment not set up correctly"
        ((TESTS_FAILED++))
        return 1
    fi

    log_success "  ✓ Environment variables set"
    ((TESTS_PASSED++))
    return 0
}

# Test file system structure
test_filesystem_structure() {
    local image="$1"
    local test_name="File System Structure"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check for standard directories
    local required_dirs=("/usr" "/bin" "/lib" "/etc")
    for dir in "${required_dirs[@]}"; do
        if ! apptainer exec "${image}" test -d "${dir}"; then
            log_error "  ✗ Missing required directory: ${dir}"
            ((TESTS_FAILED++))
            return 1
        fi
    done

    log_success "  ✓ Standard directories present"

    # Check for workspace directory
    if ! apptainer exec "${image}" test -d "/workspace"; then
        log_warning "  ⚠ /workspace directory not found"
    else
        log_success "  ✓ Workspace directory present"
    fi

    ((TESTS_PASSED++))
    return 0
}

# Test Python environment
test_python_environment() {
    local image="$1"
    local test_name="Python Environment"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check Python availability
    if ! apptainer exec "${image}" python3 --version &> /dev/null; then
        log_error "  ✗ Python3 not available"
        ((TESTS_FAILED++))
        return 1
    fi

    local python_version
    python_version=$(apptainer exec "${image}" python3 --version 2>&1)
    log_success "  ✓ ${python_version}"

    # Check pip
    if ! apptainer exec "${image}" python3 -m pip --version &> /dev/null; then
        log_warning "  ⚠ pip not available"
    else
        log_success "  ✓ pip available"
    fi

    ((TESTS_PASSED++))
    return 0
}

# Test package installations
test_package_installations() {
    local image="$1"
    local test_name="Package Installations"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check for PyTorch
    if ! apptainer exec "${image}" python3 -c "import torch" &> /dev/null; then
        log_error "  ✗ PyTorch not installed"
        ((TESTS_FAILED++))
        return 1
    fi

    local torch_version
    torch_version=$(apptainer exec "${image}" python3 -c "import torch; print(torch.__version__)")
    log_success "  ✓ PyTorch ${torch_version}"

    # Check for MPI4Py
    if ! apptainer exec "${image}" python3 -c "from mpi4py import MPI" &> /dev/null; then
        log_error "  ✗ MPI4Py not installed"
        ((TESTS_FAILED++))
        return 1
    fi

    log_success "  ✓ MPI4Py installed"

    # Check for numpy
    if ! apptainer exec "${image}" python3 -c "import numpy" &> /dev/null; then
        log_warning "  ⚠ NumPy not installed"
    else
        log_success "  ✓ NumPy installed"
    fi

    ((TESTS_PASSED++))
    return 0
}

# Test library linking
test_library_linking() {
    local image="$1"
    local test_name="Library Linking"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check for CUDA libraries
    if apptainer exec "${image}" test -d "/usr/local/cuda"; then
        log_success "  ✓ CUDA directory present"
    else
        log_warning "  ⚠ CUDA directory not found"
    fi

    # Check for MPI libraries
    if apptainer exec "${image}" which mpirun &> /dev/null; then
        log_success "  ✓ MPI executables available"
    else
        log_warning "  ⚠ MPI executables not found"
    fi

    # Check for library dependencies
    if apptainer exec "${image}" ldconfig -p | grep -q "libcuda"; then
        log_success "  ✓ CUDA libraries linked"
    else
        log_info "  ℹ CUDA libraries not linked (expected without GPU)"
    fi

    ((TESTS_PASSED++))
    return 0
}

# Test container size
test_container_size() {
    local image="$1"
    local test_name="Container Size"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    local size_bytes
    size_bytes=$(stat -c%s "${image}")
    local size_gb=$((size_bytes / 1024 / 1024 / 1024))
    local size_mb=$((size_bytes / 1024 / 1024))

    log_info "  Image size: ${size_mb} MB"

    # Warn if image is very large (>10GB)
    if [[ ${size_gb} -gt 10 ]]; then
        log_warning "  ⚠ Image is very large (${size_gb} GB)"
    elif [[ ${size_gb} -gt 5 ]]; then
        log_info "  ℹ Image size is reasonable (${size_gb} GB)"
    else
        log_success "  ✓ Image size is optimal (<5 GB)"
    fi

    ((TESTS_PASSED++))
    return 0
}

# Test image for all checks
test_image() {
    local image="$1"
    local image_name
    image_name=$(basename "${image}")

    log_info "=========================================="
    log_info "Testing: ${image_name}"
    log_info "=========================================="

    test_image_format "${image}"
    test_image_inspection "${image}"
    test_basic_execution "${image}"
    test_filesystem_structure "${image}"
    test_python_environment "${image}"
    test_package_installations "${image}"
    test_library_linking "${image}"
    test_container_size "${image}"

    log_info ""
}

# Test all images
test_all_images() {
    local images=()

    if [[ ! -d "${APPTAINER_DIR}" ]]; then
        log_error "Apptainer directory not found: ${APPTAINER_DIR}"
        return 1
    fi

    # Find all .sif files
    while IFS= read -r -d '' sif_file; do
        images+=("${sif_file}")
    done < <(find "${APPTAINER_DIR}" -type f -name "*.sif" -print0 2>/dev/null)

    if [[ ${#images[@]} -eq 0 ]]; then
        log_error "No Apptainer images found in: ${APPTAINER_DIR}"
        return 1
    fi

    log_info "Found ${#images[@]} Apptainer image(s) to test"
    echo ""

    for image in "${images[@]}"; do
        test_image "${image}"
    done
}

# Generate test report
generate_report() {
    local report_file="${LOG_DIR}/test-converted-images-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "=========================================="
        echo "Apptainer Image Conversion Test Report"
        echo "=========================================="
        echo "Date: $(date)"
        echo "Tests Run: ${TESTS_RUN}"
        echo "Tests Passed: ${TESTS_PASSED}"
        echo "Tests Failed: ${TESTS_FAILED}"
        echo "Success Rate: $(awk "BEGIN {printf \"%.1f\", (${TESTS_PASSED}/${TESTS_RUN})*100}")%"
        echo "=========================================="
    } | tee "${report_file}"

    log_info "Test report saved to: ${report_file}"
}

# Main script
main() {
    if [[ $# -gt 0 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
    fi

    log_info "Starting Apptainer image conversion tests"
    echo ""

    if [[ $# -gt 0 ]]; then
        # Test specific image
        test_image "$1"
    else
        # Test all images
        test_all_images
    fi

    echo ""
    log_info "=========================================="
    log_info "Test Summary:"
    log_info "  Total tests run: ${TESTS_RUN}"
    log_success "  Tests passed:    ${TESTS_PASSED}"
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        log_error "  Tests failed:    ${TESTS_FAILED}"
    else
        log_info "  Tests failed:    ${TESTS_FAILED}"
    fi
    log_info "=========================================="

    generate_report

    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        exit 1
    fi

    log_success "All tests passed successfully"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
