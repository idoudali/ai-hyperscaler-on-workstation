#!/bin/bash
# GPU Driver Test
# Validates that GPU drivers are loaded and nvidia-smi is functional

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"

TEST_NAME="GPU Driver Validation"

# Main tests
test_nvidia_smi_available() {
    log_test "Checking nvidia-smi availability"
    if command -v nvidia-smi >/dev/null 2>&1; then
        log_pass "nvidia-smi command available"
        NVIDIA_SMI_AVAILABLE=true
        return 0
    else
        log_fail "nvidia-smi command not found"
        NVIDIA_SMI_AVAILABLE=false
        return 1
    fi
}

test_nvidia_modules() {
    log_test "Checking NVIDIA kernel modules"
    local loaded_modules
    loaded_modules=$(lsmod | grep nvidia || true)
    if [ -n "$loaded_modules" ]; then
        log_pass "NVIDIA modules loaded:"
        echo "$loaded_modules"
        NVIDIA_MODULES_LOADED=true
        return 0
    else
        log_fail "No NVIDIA modules found in lsmod"
        NVIDIA_MODULES_LOADED=false
        return 1
    fi
}

test_proc_driver_nvidia() {
    log_test "Checking /proc/driver/nvidia"
    if [ -d /proc/driver/nvidia ]; then
        log_pass "/proc/driver/nvidia directory exists"

        if [ -f /proc/driver/nvidia/version ]; then
            log_info "Driver version:"
            head -3 /proc/driver/nvidia/version
        fi

        if [ -d /proc/driver/nvidia/gpus ]; then
            local gpu_count
            gpu_count=$(find /proc/driver/nvidia/gpus -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
            log_info "GPU count from /proc: $gpu_count"
        fi

        PROC_NVIDIA_EXISTS=true
        return 0
    else
        log_fail "/proc/driver/nvidia directory not found"
        PROC_NVIDIA_EXISTS=false
        return 1
    fi
}

test_nvidia_smi_execution() {
    log_test "Running nvidia-smi"
    if [ "$NVIDIA_SMI_AVAILABLE" != true ]; then
        log_info "Skipping (nvidia-smi not available)"
        NVIDIA_SMI_SUCCESS=false
        return 0
    fi

    if nvidia_smi_output=$(nvidia-smi 2>&1); then
        log_pass "nvidia-smi executed successfully"
        echo "$nvidia_smi_output"
        NVIDIA_SMI_SUCCESS=true

        # Extract GPU count
        local gpu_count
        gpu_count=$(echo "$nvidia_smi_output" | grep -c "NVIDIA" | head -1 || echo "0")
        log_info "Detected GPU count: $gpu_count"
        return 0
    else
        log_fail "nvidia-smi execution failed:"
        echo "$nvidia_smi_output"
        NVIDIA_SMI_SUCCESS=false
        return 1
    fi
}

test_nvidia_device_files() {
    log_test "Checking NVIDIA device files"
    local nvidia_devices
    nvidia_devices=$(ls -la /dev/nvidia* 2>/dev/null || true)
    if [ -n "$nvidia_devices" ]; then
        log_pass "NVIDIA device files found:"
        echo "$nvidia_devices"
        NVIDIA_DEVICES_EXIST=true
        return 0
    else
        log_fail "No NVIDIA device files found in /dev/"
        NVIDIA_DEVICES_EXIST=false
        return 1
    fi
}

test_cuda_runtime() {
    log_test "Checking CUDA runtime"
    if [ -d /usr/local/cuda ] || [ -d /opt/cuda ]; then
        log_pass "CUDA installation directory found"
        CUDA_INSTALLED=true
    else
        log_info "CUDA installation directory not found (may be normal)"
        CUDA_INSTALLED=false
    fi

    if command -v nvcc >/dev/null 2>&1; then
        log_pass "nvcc compiler available"
        local nvcc_version
        nvcc_version=$(nvcc --version | grep "release" || echo "Version info not available")
        log_info "$nvcc_version"
    else
        log_info "nvcc compiler not found (may be normal for runtime-only installs)"
    fi

    return 0
}

main() {
    init_suite_logging "$TEST_NAME"

    NVIDIA_SMI_AVAILABLE=false
    NVIDIA_SMI_SUCCESS=false
    NVIDIA_MODULES_LOADED=false
    PROC_NVIDIA_EXISTS=false
    NVIDIA_DEVICES_EXIST=false
    CUDA_INSTALLED=false

    run_test "nvidia-smi Available" test_nvidia_smi_available
    run_test "NVIDIA Kernel Modules" test_nvidia_modules
    run_test "/proc/driver/nvidia" test_proc_driver_nvidia
    run_test "nvidia-smi Execution" test_nvidia_smi_execution
    run_test "NVIDIA Device Files" test_nvidia_device_files
    run_test "CUDA Runtime" test_cuda_runtime

    # Summary
    log_info ""
    log_info "=== GPU Driver Summary ==="
    log_info "nvidia-smi available: $NVIDIA_SMI_AVAILABLE"
    log_info "nvidia-smi success: $NVIDIA_SMI_SUCCESS"
    log_info "NVIDIA modules loaded: $NVIDIA_MODULES_LOADED"
    log_info "/proc/driver/nvidia exists: $PROC_NVIDIA_EXISTS"
    log_info "NVIDIA device files exist: $NVIDIA_DEVICES_EXIST"
    log_info "CUDA installed: $CUDA_INSTALLED"

    print_test_summary "$TEST_NAME"

    # Overall result
    if [ "$NVIDIA_SMI_AVAILABLE" = true ] && [ "$NVIDIA_SMI_SUCCESS" = true ]; then
        log_pass "GPU Driver Test: PASSED - GPU drivers are loaded and functional"
        exit 0
    elif [ "$NVIDIA_MODULES_LOADED" = true ] && [ "$PROC_NVIDIA_EXISTS" = true ]; then
        log_warn "GPU Driver Test: PARTIAL - Drivers loaded but nvidia-smi may not be working"
        exit 0
    else
        log_fail "GPU Driver Test: FAILED - GPU drivers are not properly loaded or functional"
        exit 1
    fi
}

main "$@"
