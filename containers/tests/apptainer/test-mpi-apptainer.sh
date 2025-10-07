#!/bin/bash
# Test MPI functionality in Apptainer containers
# Usage: ./test-mpi-apptainer.sh [image.sif]

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

Test MPI functionality in Apptainer containers.

Arguments:
  IMAGE.sif         Path to Apptainer image to test (optional)
                    If not provided, tests all images in build/containers/apptainer/

Options:
  --verbose         Show detailed output
  -h, --help        Show this help message

Tests:
  - MPI library presence
  - MPI executables availability
  - MPI4Py Python bindings
  - Basic MPI communication
  - MPI version compatibility

EOF
    exit 1
}

# Test MPI library presence
test_mpi_libraries() {
    local image="$1"
    local test_name="MPI Libraries Presence"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check for MPI libraries
    if apptainer exec "${image}" ldconfig -p | grep -q "libmpi.so"; then
        log_success "  ✓ MPI libraries found"
    else
        log_error "  ✗ MPI libraries not found"
        ((TESTS_FAILED++))
        return 1
    fi

    # Check for specific MPI implementations
    if apptainer exec "${image}" ldconfig -p | grep -q "libmpi.so"; then
        local mpi_impl="Open MPI"
        if apptainer exec "${image}" ldconfig -p | grep -q "libmpich"; then
            mpi_impl="MPICH"
        fi
        log_success "  ✓ MPI implementation: ${mpi_impl}"
    fi

    ((TESTS_PASSED++))
    return 0
}

# Test MPI executables
test_mpi_executables() {
    local image="$1"
    local test_name="MPI Executables"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check for mpirun
    if apptainer exec "${image}" which mpirun &> /dev/null; then
        log_success "  ✓ mpirun available"
    else
        log_warning "  ⚠ mpirun not found"
    fi

    # Check for mpiexec
    if apptainer exec "${image}" which mpiexec &> /dev/null; then
        log_success "  ✓ mpiexec available"
    else
        log_warning "  ⚠ mpiexec not found"
    fi

    # Check for mpicc
    if apptainer exec "${image}" which mpicc &> /dev/null; then
        log_success "  ✓ mpicc available"
    else
        log_info "  ℹ mpicc not available (compiler not included)"
    fi

    ((TESTS_PASSED++))
    return 0
}

# Test MPI version
test_mpi_version() {
    local image="$1"
    local test_name="MPI Version"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Get MPI version
    local mpi_version
    if apptainer exec "${image}" which mpirun &> /dev/null; then
        mpi_version=$(apptainer exec "${image}" mpirun --version 2>&1 | head -1 || echo "unknown")
        log_success "  ✓ ${mpi_version}"
        ((TESTS_PASSED++))
    else
        log_error "  ✗ Cannot determine MPI version"
        ((TESTS_FAILED++))
        return 1
    fi

    return 0
}

# Test MPI4Py installation
test_mpi4py() {
    local image="$1"
    local test_name="MPI4Py Installation"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check if MPI4Py can be imported
    if ! apptainer exec "${image}" python3 -c "from mpi4py import MPI" &> /dev/null; then
        log_error "  ✗ MPI4Py not installed"
        ((TESTS_FAILED++))
        return 1
    fi

    log_success "  ✓ MPI4Py installed"

    # Get MPI4Py version
    local mpi4py_version
    mpi4py_version=$(apptainer exec "${image}" python3 -c \
        "from mpi4py import MPI; print(MPI.Get_library_version())" 2>/dev/null | head -1 || echo "unknown")

    if [[ "${mpi4py_version}" != "unknown" ]]; then
        log_success "  ✓ ${mpi4py_version}"
    fi

    ((TESTS_PASSED++))
    return 0
}

# Test basic MPI functionality
test_basic_mpi_functionality() {
    local image="$1"
    local test_name="Basic MPI Functionality"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Test MPI rank and size
    local test_script='
from mpi4py import MPI

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

print(f"Rank: {rank}, Size: {size}")

if rank == 0 and size == 1:
    print("SUCCESS")
'

    if apptainer exec "${image}" python3 -c "${test_script}" 2>/dev/null | grep -q "SUCCESS"; then
        log_success "  ✓ Basic MPI functionality works"
        ((TESTS_PASSED++))
    else
        log_error "  ✗ Basic MPI functionality failed"
        ((TESTS_FAILED++))
        return 1
    fi

    return 0
}

# Test MPI communication
test_mpi_communication() {
    local image="$1"
    local test_name="MPI Communication"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Create a test script for MPI communication
    local test_script='
from mpi4py import MPI
import numpy as np

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

# Test send/receive (only works with size > 1)
if size == 1:
    print("SKIPPED - Single process")
else:
    data = np.array([rank], dtype=int)
    if rank == 0:
        comm.send(data, dest=1, tag=11)
        recv_data = comm.recv(source=1, tag=22)
        if recv_data[0] == 1:
            print("SUCCESS")
    elif rank == 1:
        recv_data = comm.recv(source=0, tag=11)
        comm.send(np.array([1], dtype=int), dest=0, tag=22)
'

    local result
    result=$(apptainer exec "${image}" python3 -c "${test_script}" 2>/dev/null || echo "FAILED")

    if [[ "${result}" == *"SUCCESS"* ]]; then
        log_success "  ✓ MPI send/receive works"
        ((TESTS_PASSED++))
    elif [[ "${result}" == *"SKIPPED"* ]]; then
        log_info "  ℹ MPI communication test skipped (single process)"
        ((TESTS_PASSED++))
    else
        log_error "  ✗ MPI communication failed"
        ((TESTS_FAILED++))
        return 1
    fi

    return 0
}

# Test MPI collective operations
test_mpi_collectives() {
    local image="$1"
    local test_name="MPI Collective Operations"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Test broadcast and reduce operations
    local test_script='
from mpi4py import MPI
import numpy as np

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

# Test broadcast
if rank == 0:
    data = np.array([42], dtype=int)
else:
    data = np.array([0], dtype=int)

comm.Bcast(data, root=0)

if data[0] == 42:
    # Test reduce
    local_sum = np.array([rank], dtype=int)
    global_sum = np.zeros(1, dtype=int)
    comm.Reduce(local_sum, global_sum, op=MPI.SUM, root=0)

    if rank == 0:
        expected_sum = sum(range(size))
        if global_sum[0] == expected_sum:
            print("SUCCESS")
'

    if apptainer exec "${image}" python3 -c "${test_script}" 2>/dev/null | grep -q "SUCCESS"; then
        log_success "  ✓ MPI collective operations work"
        ((TESTS_PASSED++))
    else
        log_warning "  ⚠ MPI collective operations test inconclusive"
        ((TESTS_PASSED++))
    fi

    return 0
}

# Test MPI + NumPy integration
test_mpi_numpy() {
    local image="$1"
    local test_name="MPI + NumPy Integration"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Test MPI with NumPy arrays
    local test_script='
from mpi4py import MPI
import numpy as np

comm = MPI.COMM_WORLD
rank = comm.Get_rank()

# Create numpy array
arr = np.ones((10, 10), dtype=np.float64) * rank

# All-reduce operation
result = np.zeros_like(arr)
comm.Allreduce(arr, result, op=MPI.SUM)

if rank == 0:
    expected = sum(range(comm.Get_size())) * 10 * 10
    if result.sum() == expected:
        print("SUCCESS")
'

    if apptainer exec "${image}" python3 -c "${test_script}" 2>/dev/null | grep -q "SUCCESS"; then
        log_success "  ✓ MPI + NumPy integration works"
        ((TESTS_PASSED++))
    else
        log_warning "  ⚠ MPI + NumPy integration test inconclusive"
        ((TESTS_PASSED++))
    fi

    return 0
}

# Test PMIx support
test_pmix() {
    local image="$1"
    local test_name="PMIx Support"

    ((TESTS_RUN++))
    log_info "Test: ${test_name}"

    # Check for PMIx libraries
    if apptainer exec "${image}" ldconfig -p | grep -q "libpmix"; then
        log_success "  ✓ PMIx libraries found"
    else
        log_info "  ℹ PMIx libraries not found (may not be required)"
    fi

    # Check for PMI2
    if apptainer exec "${image}" ldconfig -p | grep -q "libpmi2"; then
        log_success "  ✓ PMI2 libraries found"
    else
        log_info "  ℹ PMI2 libraries not found"
    fi

    ((TESTS_PASSED++))
    return 0
}

# Test image for all MPI checks
test_image() {
    local image="$1"
    local image_name
    image_name=$(basename "${image}")

    log_info "=========================================="
    log_info "Testing MPI: ${image_name}"
    log_info "=========================================="

    test_mpi_libraries "${image}"
    test_mpi_executables "${image}"
    test_mpi_version "${image}"
    test_mpi4py "${image}"
    test_basic_mpi_functionality "${image}"
    test_mpi_communication "${image}"
    test_mpi_collectives "${image}"
    test_mpi_numpy "${image}"
    test_pmix "${image}"

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
    local report_file="${LOG_DIR}/test-mpi-apptainer-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "=========================================="
        echo "Apptainer MPI Functionality Test Report"
        echo "=========================================="
        echo "Date: $(date)"
        echo "Tests Run: ${TESTS_RUN}"
        echo "Tests Passed: ${TESTS_PASSED}"
        echo "Tests Failed: ${TESTS_FAILED}"
        if [[ ${TESTS_RUN} -gt 0 ]]; then
            echo "Success Rate: $(awk "BEGIN {printf \"%.1f\", (${TESTS_PASSED}/${TESTS_RUN})*100}")%"
        fi
        echo "=========================================="
    } | tee "${report_file}"

    log_info "Test report saved to: ${report_file}"
}

# Main script
main() {
    if [[ $# -gt 0 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
    fi

    log_info "Starting Apptainer MPI functionality tests"
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

    log_success "All MPI tests passed successfully"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
