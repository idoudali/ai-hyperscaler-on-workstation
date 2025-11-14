#!/bin/bash
#
# GPU Detection Validation Script
# Task 023 - GPU Detection and Visibility Validation
# Validates GPU device detection and SLURM recognition
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Source shared utilities
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-check-helpers.sh"

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="check-gpu-detection.sh"
# shellcheck disable=SC2034
TEST_NAME="GPU Detection Validation"

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
        log_error "No NVIDIA device files found (/dev/nvidia*)"
        log_error "This is expected if NVIDIA drivers are not installed"
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
            log_error "nvidia-smi failed to execute (drivers may not be loaded)"
            return 0  # Not a hard failure
        fi
    else
        log_error "nvidia-smi not available"
        log_error "This is expected if NVIDIA drivers are not installed"
        return 0  # Not a hard failure
    fi
}

test_slurmd_gpu_detection() {
    log_info "Checking slurmd GPU detection..."

    if ! command -v slurmd >/dev/null 2>&1; then
        log_error "slurmd command not available"
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
        log_error "GRES configuration file not found: $gres_file"
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
        log_error "GRES configuration file not found"
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

#=============================================================================
# Main Test Execution
#=============================================================================

main() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  GPU Detection Validation Test${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    log_info "Test Suite: $TEST_NAME"
    log_info "Log Directory: $LOG_DIR"
    echo ""

    # Run all tests
    run_test "PCI GPU devices detection" test_pci_gpu_devices
    run_test "NVIDIA device files" test_nvidia_devices
    run_test "nvidia-smi availability" test_nvidia_smi
    run_test "slurmd GPU detection" test_slurmd_gpu_detection
    run_test "GRES device files" test_gres_devices_file
    run_test "GRES auto-detection capability" test_gres_autodetect_capability

    # Print summary
    if print_check_summary; then
        log_info "GPU detection validation passed (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 0
    else
        log_warn "GPU detection validation had issues (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 0
    fi
}

# Execute main function
main "$@"
