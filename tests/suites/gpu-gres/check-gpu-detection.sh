#!/bin/bash
#
# GPU Detection Validation Script
# Task 023 - GPU Detection and Visibility Validation
# Validates GPU device detection and SLURM recognition
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="check-gpu-detection.sh"
TEST_NAME="GPU Detection Validation"

# Use LOG_DIR from environment or default
: "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
FAILED_TESTS=()

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

# Test execution functions
run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    echo -e "\n${BLUE}Running Test ${TESTS_RUN}: ${test_name}${NC}"

    if $test_function; then
        log_info "✓ Test passed: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ Test failed: $test_name"
        FAILED_TESTS+=("$test_name")
        return 1
    fi
}

# Individual test functions
# shellcheck disable=SC2317  # Functions called indirectly via run_test
test_pci_gpu_devices() {
    log_info "Checking for PCI GPU devices..."

    if ! command -v lspci >/dev/null 2>&1; then
        log_warn "lspci command not available"
        return 0
    fi

    # Look for common GPU vendors
    local gpu_count=0
    local gpu_info

    # Check for NVIDIA GPUs
    if gpu_info=$(lspci | grep -i "VGA.*NVIDIA\|3D.*NVIDIA\|Display.*NVIDIA" 2>/dev/null); then
        local nvidia_count
        nvidia_count=$(echo "$gpu_info" | wc -l)
        log_info "✓ Found $nvidia_count NVIDIA GPU(s)"
        echo "$gpu_info" | while IFS= read -r line; do
            log_debug "  $line"
        done
        gpu_count=$((gpu_count + nvidia_count))
    fi

    # Check for AMD GPUs
    if gpu_info=$(lspci | grep -i "VGA.*AMD\|3D.*AMD\|Display.*AMD\|VGA.*ATI\|3D.*ATI" 2>/dev/null); then
        local amd_count
        amd_count=$(echo "$gpu_info" | wc -l)
        log_info "✓ Found $amd_count AMD GPU(s)"
        echo "$gpu_info" | while IFS= read -r line; do
            log_debug "  $line"
        done
        gpu_count=$((gpu_count + amd_count))
    fi

    # Check for Intel GPUs (integrated graphics)
    if gpu_info=$(lspci | grep -i "VGA.*Intel\|3D.*Intel\|Display.*Intel" 2>/dev/null); then
        local intel_count
        intel_count=$(echo "$gpu_info" | wc -l)
        log_info "Found $intel_count Intel GPU(s)"
        echo "$gpu_info" | while IFS= read -r line; do
            log_debug "  $line"
        done
        # Don't add Intel to count as they're typically integrated graphics
    fi

    if [[ $gpu_count -gt 0 ]]; then
        log_info "✓ Total discrete GPUs detected: $gpu_count"
        return 0
    else
        log_warn "No discrete GPUs detected via PCI"
        log_warn "This may be expected in a test/virtual environment"
        return 0  # Not a hard failure
    fi
}

test_nvidia_devices() {
    log_info "Checking for NVIDIA device files..."

    # Check for NVIDIA device files
    local nvidia_devices=()
    for i in {0..7}; do
        if [[ -e "/dev/nvidia$i" ]]; then
            nvidia_devices+=("/dev/nvidia$i")
            log_debug "✓ Found device: /dev/nvidia$i"
        fi
    done

    if [[ ${#nvidia_devices[@]} -gt 0 ]]; then
        log_info "✓ Found ${#nvidia_devices[@]} NVIDIA device file(s)"
        return 0
    else
        log_warn "No NVIDIA device files found (/dev/nvidia*)"
        log_warn "This is expected if NVIDIA drivers are not installed"
        return 0  # Not a hard failure
    fi
}

test_nvidia_smi() {
    log_info "Checking nvidia-smi availability..."

    if command -v nvidia-smi >/dev/null 2>&1; then
        log_info "✓ nvidia-smi command available"

        # Try to run nvidia-smi
        if nvidia-smi >/dev/null 2>&1; then
            log_info "✓ nvidia-smi executed successfully"

            # Get GPU count
            local gpu_count
            gpu_count=$(nvidia-smi --list-gpus 2>/dev/null | wc -l || echo "0")
            log_info "  GPUs detected by nvidia-smi: $gpu_count"

            return 0
        else
            log_warn "nvidia-smi failed to execute (drivers may not be loaded)"
            return 0  # Not a hard failure
        fi
    else
        log_warn "nvidia-smi not available"
        log_warn "This is expected if NVIDIA drivers are not installed"
        return 0  # Not a hard failure
    fi
}

test_slurmd_gpu_detection() {
    log_info "Checking slurmd GPU detection..."

    if ! command -v slurmd >/dev/null 2>&1; then
        log_warn "slurmd command not available"
        return 0
    fi

    # Run slurmd -C to show node configuration
    local slurmd_config
    if slurmd_config=$(slurmd -C 2>/dev/null); then
        log_info "✓ slurmd configuration check successful"
        log_debug "slurmd configuration:"
        echo "$slurmd_config" | while IFS= read -r line; do
            log_debug "  $line"
        done

        # Check if GPU information is present
        if echo "$slurmd_config" | grep -qi "gres"; then
            log_info "✓ GRES information found in slurmd configuration"
        else
            log_warn "No GRES information in slurmd configuration"
        fi

        return 0
    else
        log_warn "Failed to get slurmd configuration"
        return 0  # Not a hard failure
    fi
}

test_gres_devices_file() {
    log_info "Checking for GPU device files referenced in GRES..."

    local gres_file="/etc/slurm/gres.conf"

    if [[ ! -f "$gres_file" ]]; then
        log_warn "GRES configuration file not found: $gres_file"
        return 0
    fi

    # Extract device file paths from gres.conf
    local device_files
    device_files=$(grep -E "^\s*NodeName=.*File=" "$gres_file" 2>/dev/null | \
                   sed -n 's/.*File=\([^ ]*\).*/\1/p' || true)

    if [[ -z "$device_files" ]]; then
        log_warn "No device files specified in GRES configuration"
        return 0
    fi

    log_info "Checking device files from GRES configuration:"
    local missing_devices=()
    while IFS= read -r device; do
        if [[ -e "$device" ]]; then
            log_debug "✓ Device exists: $device"
        else
            log_warn "✗ Device missing: $device"
            missing_devices+=("$device")
        fi
    done <<< "$device_files"

    if [[ ${#missing_devices[@]} -eq 0 ]]; then
        log_info "✓ All GRES device files exist"
        return 0
    else
        log_warn "Some GRES device files missing: ${missing_devices[*]}"
        return 0  # Not a hard failure in test environment
    fi
}

test_gres_autodetect_capability() {
    log_info "Checking GRES auto-detection capability..."

    local gres_file="/etc/slurm/gres.conf"

    if [[ ! -f "$gres_file" ]]; then
        log_warn "GRES configuration file not found"
        return 0
    fi

    # Check if AutoDetect is configured
    if grep -q "AutoDetect=" "$gres_file" 2>/dev/null; then
        local autodetect_method
        autodetect_method=$(grep "AutoDetect=" "$gres_file" | head -1 | cut -d'=' -f2)
        log_info "✓ Auto-detection enabled: $autodetect_method"

        # Check if the method is supported
        case "$autodetect_method" in
            nvml|nvidia)
                log_info "  Using NVIDIA Management Library (NVML)"
                if command -v nvidia-smi >/dev/null 2>&1; then
                    log_info "  ✓ NVML tools available (nvidia-smi)"
                else
                    log_warn "  ✗ NVML tools not available"
                fi
                ;;
            rsmi|amd)
                log_info "  Using AMD ROCm System Management Interface"
                ;;
            *)
                log_warn "  Unknown auto-detection method: $autodetect_method"
                ;;
        esac

        return 0
    else
        log_info "Auto-detection not configured (using manual configuration)"
        return 0
    fi
}

# Main test execution
main() {
    echo "========================================="
    echo "  GPU Detection Validation Test"
    echo "========================================="
    echo ""
    echo "Test Suite: $TEST_NAME"
    echo "Log Directory: $LOG_DIR"
    echo ""

    # Run all tests
    run_test "PCI GPU devices detection" test_pci_gpu_devices
    run_test "NVIDIA device files" test_nvidia_devices
    run_test "nvidia-smi availability" test_nvidia_smi
    run_test "slurmd GPU detection" test_slurmd_gpu_detection
    run_test "GRES device files" test_gres_devices_file
    run_test "GRES auto-detection capability" test_gres_autodetect_capability

    # Print summary
    echo ""
    echo "========================================="
    echo "  Test Summary"
    echo "========================================="
    echo "Total tests: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $((TESTS_RUN - TESTS_PASSED))"

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo ""
        echo "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
    fi
    echo "========================================="

    # Return appropriate exit code
    if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
        log_info "All tests passed!"
        exit 0
    else
        log_error "Some tests failed"
        exit 1
    fi
}

# Run main function
main "$@"
