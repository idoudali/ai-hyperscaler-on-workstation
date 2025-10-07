#!/bin/bash
# Test Apptainer images locally
# Usage: ./test-apptainer-local.sh [image.sif] [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APPTAINER_DIR="${PROJECT_ROOT}/build/containers/apptainer"

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

# Configuration
VERBOSE=false
TEST_IMAGE=""
TEST_GPU=false

# Usage information
usage() {
    cat << EOF
Usage: $0 [IMAGE.sif] [OPTIONS]

Test Apptainer images locally to verify functionality.

Arguments:
  IMAGE.sif         Path to Apptainer image to test (optional)
                    If not provided, tests all images in build/containers/apptainer/

Options:
  --verbose         Show detailed output from tests
  --gpu             Test GPU functionality (requires NVIDIA GPU)
  -h, --help        Show this help message

Examples:
  # Test all images
  $0

  # Test specific image
  $0 build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif

  # Test with verbose output
  $0 --verbose

  # Test GPU functionality
  $0 pytorch-cuda12.1-mpi4.1.sif --gpu

EOF
    exit 1
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --gpu)
                TEST_GPU=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *.sif)
                TEST_IMAGE="$1"
                shift
                ;;
            *)
                # Try to find image by name
                if [[ -f "${APPTAINER_DIR}/$1.sif" ]]; then
                    TEST_IMAGE="${APPTAINER_DIR}/$1.sif"
                    shift
                elif [[ -f "${APPTAINER_DIR}/$1" ]]; then
                    TEST_IMAGE="${APPTAINER_DIR}/$1"
                    shift
                else
                    log_error "Unknown option or image not found: $1"
                    usage
                fi
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    if ! command -v apptainer &> /dev/null; then
        log_error "Apptainer not found in PATH"
        exit 1
    fi

    if [[ "${TEST_GPU}" == "true" ]] && ! command -v nvidia-smi &> /dev/null; then
        log_warning "nvidia-smi not found, GPU tests may fail"
    fi
}

# Run command in container
run_in_container() {
    local image="$1"
    shift
    local cmd="$*"

    local flags="--cleanenv"
    if [[ "${TEST_GPU}" == "true" ]]; then
        flags="${flags} --nv"
    fi

    if [[ "${VERBOSE}" == "true" ]]; then
        apptainer exec ${flags} "${image}" bash -c "${cmd}"
    else
        apptainer exec ${flags} "${image}" bash -c "${cmd}" 2>&1 | grep -v "^INFO:" || true
    fi
}

# Test basic functionality
test_basic_functionality() {
    local image="$1"
    local test_name="Basic Functionality"

    log_info "Testing: ${test_name}"

    # Test 1: Container execution
    if run_in_container "${image}" "echo 'Container works'" | grep -q "Container works"; then
        log_success "  ✓ Container execution"
    else
        log_error "  ✗ Container execution failed"
        return 1
    fi

    # Test 2: Python availability
    if run_in_container "${image}" "python3 --version" | grep -q "Python"; then
        local python_version
        python_version=$(run_in_container "${image}" "python3 --version" | head -1)
        log_success "  ✓ Python available: ${python_version}"
    else
        log_error "  ✗ Python not available"
        return 1
    fi

    # Test 3: Basic Python execution
    if run_in_container "${image}" "python3 -c 'import sys; print(sys.version)'" &> /dev/null; then
        log_success "  ✓ Python execution"
    else
        log_error "  ✗ Python execution failed"
        return 1
    fi

    return 0
}

# Test PyTorch functionality
test_pytorch() {
    local image="$1"
    local test_name="PyTorch"

    log_info "Testing: ${test_name}"

    # Test 1: PyTorch import
    if run_in_container "${image}" "python3 -c 'import torch'" &> /dev/null; then
        log_success "  ✓ PyTorch import"
    else
        log_error "  ✗ PyTorch import failed"
        return 1
    fi

    # Test 2: PyTorch version
    local pytorch_version
    pytorch_version=$(run_in_container "${image}" "python3 -c 'import torch; print(torch.__version__)'")
    if [[ -n "${pytorch_version}" ]]; then
        log_success "  ✓ PyTorch version: ${pytorch_version}"
    else
        log_error "  ✗ Could not get PyTorch version"
        return 1
    fi

    # Test 3: Basic tensor operations
    if run_in_container "${image}" "python3 -c 'import torch; t = torch.ones(3,3); print(t.sum())'" | grep -q "9"; then
        log_success "  ✓ Tensor operations"
    else
        log_error "  ✗ Tensor operations failed"
        return 1
    fi

    return 0
}

# Test CUDA functionality
test_cuda() {
    local image="$1"
    local test_name="CUDA"

    if [[ "${TEST_GPU}" != "true" ]]; then
        log_info "Skipping: ${test_name} (use --gpu to enable)"
        return 0
    fi

    log_info "Testing: ${test_name}"

    # Test 1: CUDA availability
    local cuda_available
    cuda_available=$(run_in_container "${image}" "python3 -c 'import torch; print(torch.cuda.is_available())'")
    if [[ "${cuda_available}" == "True" ]]; then
        log_success "  ✓ CUDA available"
    else
        log_warning "  ⚠ CUDA not available (expected in container without GPU access)"
        return 0
    fi

    # Test 2: CUDA device count
    local device_count
    device_count=$(run_in_container "${image}" "python3 -c 'import torch; print(torch.cuda.device_count())'")
    if [[ ${device_count} -gt 0 ]]; then
        log_success "  ✓ GPU devices detected: ${device_count}"
    else
        log_warning "  ⚠ No GPU devices detected"
        return 0
    fi

    # Test 3: CUDA tensor operations
    if run_in_container "${image}" "python3 -c 'import torch; t = torch.ones(3,3).cuda(); print(t.sum())'" | grep -q "9"; then
        log_success "  ✓ CUDA tensor operations"
    else
        log_error "  ✗ CUDA tensor operations failed"
        return 1
    fi

    return 0
}

# Test MPI functionality
test_mpi() {
    local image="$1"
    local test_name="MPI"

    log_info "Testing: ${test_name}"

    # Test 1: MPI4Py import
    if run_in_container "${image}" "python3 -c 'from mpi4py import MPI'" &> /dev/null; then
        log_success "  ✓ MPI4Py import"
    else
        log_error "  ✗ MPI4Py import failed"
        return 1
    fi

    # Test 2: MPI version
    local mpi_version
    mpi_version=$(run_in_container "${image}" "python3 -c 'from mpi4py import MPI; print(MPI.Get_version())'")
    if [[ -n "${mpi_version}" ]]; then
        log_success "  ✓ MPI version: ${mpi_version}"
    else
        log_error "  ✗ Could not get MPI version"
        return 1
    fi

    # Test 3: Basic MPI functionality
    if run_in_container "${image}" "python3 -c 'from mpi4py import MPI; comm = MPI.COMM_WORLD; print(comm.Get_size())'" | grep -q "1"; then
        log_success "  ✓ MPI functionality"
    else
        log_error "  ✗ MPI functionality failed"
        return 1
    fi

    return 0
}

# Test image
test_image() {
    local image="$1"
    local image_name
    image_name=$(basename "${image}")

    log_info "=========================================="
    log_info "Testing image: ${image_name}"
    log_info "=========================================="

    # Verify image exists
    if [[ ! -f "${image}" ]]; then
        log_error "Image not found: ${image}"
        return 1
    fi

    # Display image info
    if [[ "${VERBOSE}" == "true" ]]; then
        log_info "Image information:"
        apptainer inspect "${image}" || log_warning "Could not inspect image"
    fi

    local tests_passed=0
    local tests_failed=0

    # Run tests
    if test_basic_functionality "${image}"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    if test_pytorch "${image}"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    if test_cuda "${image}"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    if test_mpi "${image}"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Summary
    log_info "Test Summary for ${image_name}:"
    log_success "  Passed: ${tests_passed}"
    if [[ ${tests_failed} -gt 0 ]]; then
        log_error "  Failed: ${tests_failed}"
        return 1
    else
        log_success "All tests passed for ${image_name}"
    fi

    return 0
}

# Test all images
test_all_images() {
    local images=()

    if [[ ! -d "${APPTAINER_DIR}" ]]; then
        log_error "Apptainer directory not found: ${APPTAINER_DIR}"
        log_info "Please convert Docker images first using:"
        log_info "  ${SCRIPT_DIR}/convert-all.sh"
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

    local total_passed=0
    local total_failed=0

    for image in "${images[@]}"; do
        if test_image "${image}"; then
            ((total_passed++))
        else
            ((total_failed++))
        fi
        echo ""
    done

    # Overall summary
    log_info "=========================================="
    log_info "Overall Test Summary:"
    log_success "  Images passed: ${total_passed}"
    if [[ ${total_failed} -gt 0 ]]; then
        log_error "  Images failed: ${total_failed}"
        return 1
    else
        log_success "All images passed testing"
    fi

    return 0
}

# Main script
main() {
    parse_args "$@"
    check_prerequisites

    log_info "Starting Apptainer image testing"

    if [[ -n "${TEST_IMAGE}" ]]; then
        # Test single image
        if test_image "${TEST_IMAGE}"; then
            log_success "Image testing completed successfully"
        else
            log_error "Image testing failed"
            exit 1
        fi
    else
        # Test all images
        if test_all_images; then
            log_success "All images tested successfully"
        else
            log_error "Some images failed testing"
            exit 1
        fi
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
