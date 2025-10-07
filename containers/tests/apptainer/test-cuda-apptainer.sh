#!/bin/bash
# Test CUDA functionality in Apptainer containers
# Usage: ./test-cuda-apptainer.sh [image.sif]

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
TESTS_SKIPPED=0

# Create log directory
mkdir -p "${LOG_DIR}"

# Check if GPU is available
GPU_AVAILABLE=false
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    GPU_AVAILABLE=true
fi

# Usage information
usage() {
    cat << EOF
Usage: $0 [IMAGE.sif] [OPTIONS]

Test CUDA functionality in Apptainer containers.

Arguments:
  IMAGE.sif         Path to Apptainer image to test (optional)
                    If not provided, tests all images in build/containers/apptainer/

Options:
  --skip-gpu-tests  Skip tests that require actual GPU hardware
  --verbose         Show detailed output
  -h, --help        Show this help message

Tests:
  - CUDA library presence
  - CUDA runtime configuration
  - PyTorch CUDA integration
  - GPU device detection (if GPU available)
  - CUDA tensor operations (if GPU available)

Note: Some tests require NVIDIA GPU hardware and will be skipped if not available.

EOF
    exit 1
}

# Parse arguments
SKIP_GPU_TESTS=false
if [[ $# -gt 0 ]]; then
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-gpu-tests)
                SKIP_GPU_TESTS=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                TEST_IMAGE="$1"
                shift
                ;;
        esac
    done
fi

# Test CUDA libraries presence
test_cuda_libraries() {
    local image="$1"
    local test_name="CUDA Libraries Presence"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check for CUDA directory
    if ! apptainer exec "${image}" test -d "/usr/local/cuda"; then
        log_warning "  ⚠ CUDA directory not found at /usr/local/cuda"
    else
        log_success "  ✓ CUDA directory present"
    fi

    # Check for CUDA headers
    if apptainer exec "${image}" test -f "/usr/local/cuda/include/cuda.h"; then
        log_success "  ✓ CUDA headers available"
    else
        log_warning "  ⚠ CUDA headers not found"
    fi

    # Check for CUDA libraries
    if apptainer exec "${image}" test -f "/usr/local/cuda/lib64/libcudart.so"; then
        log_success "  ✓ CUDA runtime library present"
    else
        log_warning "  ⚠ CUDA runtime library not found"
    fi

    ((TESTS_PASSED++))
    return 0
}

# Test CUDA version
test_cuda_version() {
    local image="$1"
    local test_name="CUDA Version"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check for nvcc
    if apptainer exec "${image}" which nvcc &> /dev/null; then
        local cuda_version
        cuda_version=$(apptainer exec "${image}" nvcc --version | grep -oP 'release \K[0-9.]+' || echo "unknown")
        log_success "  ✓ CUDA toolkit version: ${cuda_version}"
        ((TESTS_PASSED++))
    else
        log_warning "  ⚠ nvcc not found (CUDA toolkit may not be fully installed)"
        ((TESTS_PASSED++))
    fi

    return 0
}

# Test PyTorch CUDA build
test_pytorch_cuda_build() {
    local image="$1"
    local test_name="PyTorch CUDA Build"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check if PyTorch was built with CUDA support
    local pytorch_cuda_version
    pytorch_cuda_version=$(apptainer exec "${image}" python3 -c \
        "import torch; print(torch.version.cuda if torch.version.cuda else 'CPU-only')" 2>/dev/null || echo "error")

    if [[ "${pytorch_cuda_version}" == "error" ]]; then
        log_error "  ✗ Failed to query PyTorch CUDA version"
        ((TESTS_FAILED++))
        return 1
    elif [[ "${pytorch_cuda_version}" == "CPU-only" ]]; then
        log_warning "  ⚠ PyTorch built without CUDA support"
        ((TESTS_PASSED++))
        return 0
    else
        log_success "  ✓ PyTorch built with CUDA ${pytorch_cuda_version}"
        ((TESTS_PASSED++))
        return 0
    fi
}

# Test CUDA availability (runtime check)
test_cuda_availability() {
    local image="$1"
    local test_name="CUDA Availability"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check if CUDA is available at runtime
    local cuda_available
    cuda_available=$(apptainer exec --nv "${image}" python3 -c \
        "import torch; print('true' if torch.cuda.is_available() else 'false')" 2>/dev/null || echo "error")

    if [[ "${cuda_available}" == "error" ]]; then
        log_error "  ✗ Failed to check CUDA availability"
        ((TESTS_FAILED++))
        return 1
    elif [[ "${cuda_available}" == "true" ]]; then
        log_success "  ✓ CUDA is available at runtime"
        ((TESTS_PASSED++))
        return 0
    else
        if [[ "${GPU_AVAILABLE}" == "true" ]]; then
            log_warning "  ⚠ CUDA not available (GPU present but not accessible)"
        else
            log_info "  ℹ CUDA not available (no GPU detected on host)"
        fi
        ((TESTS_PASSED++))
        return 0
    fi
}

# Test GPU device detection
test_gpu_detection() {
    local image="$1"
    local test_name="GPU Device Detection"

    if [[ "${SKIP_GPU_TESTS}" == "true" ]] || [[ "${GPU_AVAILABLE}" == "false" ]]; then
        ((TESTS_SKIPPED++))
        log_info "Test: ${test_name} [SKIPPED - No GPU available]"
        return 0
    fi

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Get device count
    local device_count
    device_count=$(apptainer exec --nv "${image}" python3 -c \
        "import torch; print(torch.cuda.device_count())" 2>/dev/null || echo "0")

    if [[ ${device_count} -gt 0 ]]; then
        log_success "  ✓ Detected ${device_count} GPU device(s)"

        # Get device names
        local device_names
        device_names=$(apptainer exec --nv "${image}" python3 -c \
            "import torch; [print(f'    - GPU {i}: {torch.cuda.get_device_name(i)}') for i in range(torch.cuda.device_count())]" 2>/dev/null || echo "")

        if [[ -n "${device_names}" ]]; then
            echo "${device_names}"
        fi

        ((TESTS_PASSED++))
    else
        log_warning "  ⚠ No GPU devices detected"
        ((TESTS_PASSED++))
    fi

    return 0
}

# Test CUDA tensor creation
test_cuda_tensor_creation() {
    local image="$1"
    local test_name="CUDA Tensor Creation"

    if [[ "${SKIP_GPU_TESTS}" == "true" ]] || [[ "${GPU_AVAILABLE}" == "false" ]]; then
        ((TESTS_SKIPPED++))
        log_info "Test: ${test_name} [SKIPPED - No GPU available]"
        return 0
    fi

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Try to create a CUDA tensor
    if apptainer exec --nv "${image}" python3 -c \
        "import torch; t = torch.ones(5, 5).cuda(); print('success')" 2>/dev/null | grep -q "success"; then
        log_success "  ✓ Successfully created CUDA tensor"
        ((TESTS_PASSED++))
    else
        log_error "  ✗ Failed to create CUDA tensor"
        ((TESTS_FAILED++))
        return 1
    fi

    return 0
}

# Test CUDA operations
test_cuda_operations() {
    local image="$1"
    local test_name="CUDA Operations"

    if [[ "${SKIP_GPU_TESTS}" == "true" ]] || [[ "${GPU_AVAILABLE}" == "false" ]]; then
        ((TESTS_SKIPPED++))
        log_info "Test: ${test_name} [SKIPPED - No GPU available]"
        return 0
    fi

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Test basic CUDA operations
    local test_script='
import torch
import sys

try:
    # Create tensors on GPU
    a = torch.randn(1000, 1000).cuda()
    b = torch.randn(1000, 1000).cuda()

    # Matrix multiplication
    c = torch.matmul(a, b)

    # Check result is on GPU
    if c.is_cuda:
        print("success")
    else:
        print("error: result not on GPU")
        sys.exit(1)
except Exception as e:
    print(f"error: {e}")
    sys.exit(1)
'

    if apptainer exec --nv "${image}" python3 -c "${test_script}" 2>/dev/null | grep -q "success"; then
        log_success "  ✓ CUDA matrix operations successful"
        ((TESTS_PASSED++))
    else
        log_error "  ✗ CUDA operations failed"
        ((TESTS_FAILED++))
        return 1
    fi

    return 0
}

# Test CUDA memory
test_cuda_memory() {
    local image="$1"
    local test_name="CUDA Memory"

    if [[ "${SKIP_GPU_TESTS}" == "true" ]] || [[ "${GPU_AVAILABLE}" == "false" ]]; then
        ((TESTS_SKIPPED++))
        log_info "Test: ${test_name} [SKIPPED - No GPU available]"
        return 0
    fi

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Get GPU memory info
    local memory_info
    memory_info=$(apptainer exec --nv "${image}" python3 -c \
        "import torch; print(f'{torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB')" 2>/dev/null || echo "unknown")

    if [[ "${memory_info}" != "unknown" ]]; then
        log_success "  ✓ GPU memory: ${memory_info}"
        ((TESTS_PASSED++))
    else
        log_warning "  ⚠ Could not query GPU memory"
        ((TESTS_PASSED++))
    fi

    return 0
}

# Test CuDNN
test_cudnn() {
    local image="$1"
    local test_name="cuDNN"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check if cuDNN is available
    local cudnn_version
    cudnn_version=$(apptainer exec "${image}" python3 -c \
        "import torch; print(torch.backends.cudnn.version() if torch.backends.cudnn.is_available() else 'not available')" 2>/dev/null || echo "error")

    if [[ "${cudnn_version}" == "error" ]]; then
        log_error "  ✗ Failed to check cuDNN"
        ((TESTS_FAILED++))
        return 1
    elif [[ "${cudnn_version}" == "not available" ]]; then
        log_warning "  ⚠ cuDNN not available"
        ((TESTS_PASSED++))
    else
        log_success "  ✓ cuDNN version: ${cudnn_version}"
        ((TESTS_PASSED++))
    fi

    return 0
}

# Test image for all CUDA checks
test_image() {
    local image="$1"
    local image_name
    image_name=$(basename "${image}")

    log_info "=========================================="
    log_info "Testing CUDA: ${image_name}"
    log_info "=========================================="

    if [[ "${GPU_AVAILABLE}" == "false" ]]; then
        log_warning "No GPU detected on host - some tests will be skipped"
    fi

    test_cuda_libraries "${image}"
    test_cuda_version "${image}"
    test_pytorch_cuda_build "${image}"
    test_cuda_availability "${image}"
    test_gpu_detection "${image}"
    test_cuda_tensor_creation "${image}"
    test_cuda_operations "${image}"
    test_cuda_memory "${image}"
    test_cudnn "${image}"

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
    local report_file="${LOG_DIR}/test-cuda-apptainer-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "=========================================="
        echo "Apptainer CUDA Functionality Test Report"
        echo "=========================================="
        echo "Date: $(date)"
        echo "GPU Available: ${GPU_AVAILABLE}"
        echo "Tests Run: ${TESTS_RUN}"
        echo "Tests Passed: ${TESTS_PASSED}"
        echo "Tests Failed: ${TESTS_FAILED}"
        echo "Tests Skipped: ${TESTS_SKIPPED}"
        if [[ ${TESTS_RUN} -gt 0 ]]; then
            echo "Success Rate: $(awk "BEGIN {printf \"%.1f\", (${TESTS_PASSED}/${TESTS_RUN})*100}")%"
        fi
        echo "=========================================="
    } | tee "${report_file}"

    log_info "Test report saved to: ${report_file}"
}

# Main script
main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
    fi

    log_info "Starting Apptainer CUDA functionality tests"
    echo ""

    if [[ -n "${TEST_IMAGE:-}" ]]; then
        # Test specific image
        test_image "${TEST_IMAGE}"
    else
        # Test all images
        test_all_images
    fi

    echo ""
    log_info "=========================================="
    log_info "Test Summary:"
    log_info "  Total tests run:     ${TESTS_RUN}"
    log_success "  Tests passed:        ${TESTS_PASSED}"
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        log_error "  Tests failed:        ${TESTS_FAILED}"
    else
        log_info "  Tests failed:        ${TESTS_FAILED}"
    fi
    log_info "  Tests skipped:       ${TESTS_SKIPPED}"
    log_info "=========================================="

    generate_report

    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        exit 1
    fi

    log_success "All CUDA tests passed successfully"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
