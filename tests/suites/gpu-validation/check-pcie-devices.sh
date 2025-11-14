#!/bin/bash
# PCIe Device Detection Test
# Validates that PCIe passthrough devices are visible in the VM

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"

TEST_NAME="PCIe Device Detection"

# Main tests
test_lspci_available() {
    log_test "Checking lspci availability"
    if command -v lspci >/dev/null 2>&1; then
        log_pass "lspci command available"
        return 0
    else
        log_fail "lspci command not found"
        return 1
    fi
}

test_list_pci_devices() {
    log_test "Listing all PCI devices"
    local lspci_output
    lspci_output=$(lspci)
    if [ -n "$lspci_output" ]; then
        log_pass "PCI devices listed successfully"
        echo "$lspci_output"
        return 0
    else
        log_fail "No PCI devices found"
        return 1
    fi
}

test_gpu_devices() {
    log_test "Checking for GPU devices"
    local gpu_devices
    gpu_devices=$(lspci | grep -i "vga\|3d\|display" || true)
    if [ -n "$gpu_devices" ]; then
        log_pass "GPU devices found:"
        echo "$gpu_devices"
        GPU_FOUND=true
        return 0
    else
        log_fail "No GPU devices detected"
        GPU_FOUND=false
        return 1
    fi
}

test_audio_devices() {
    log_test "Checking for audio devices"
    local audio_devices
    audio_devices=$(lspci | grep -i "audio" || true)
    if [ -n "$audio_devices" ]; then
        log_pass "Audio devices found:"
        echo "$audio_devices"
        AUDIO_FOUND=true
        return 0
    else
        log_info "No audio devices detected (may be normal)"
        AUDIO_FOUND=false
        return 0
    fi
}

test_nvidia_devices() {
    log_test "Checking for NVIDIA devices by vendor ID"
    local nvidia_devices
    nvidia_devices=$(lspci -nn | grep "10de:" || true)
    if [ -n "$nvidia_devices" ]; then
        log_pass "NVIDIA devices found:"
        echo "$nvidia_devices"
        NVIDIA_FOUND=true
        return 0
    else
        log_fail "No NVIDIA devices detected by vendor ID"
        NVIDIA_FOUND=false
        return 1
    fi
}

test_proc_bus_pci() {
    log_test "Checking /proc/bus/pci directory"
    if [ -d /proc/bus/pci ]; then
        local pci_count
        pci_count=$(find /proc/bus/pci -name "*.0" 2>/dev/null | wc -l)
        log_pass "/proc/bus/pci directory exists ($pci_count PCI device entries)"
        return 0
    else
        log_warn "/proc/bus/pci directory not found"
        return 1
    fi
}

test_vfio_devices() {
    log_test "Checking for VFIO devices"
    if [ -d /dev/vfio ]; then
        log_pass "/dev/vfio directory exists"
        local vfio_devices
        vfio_devices=$(ls -la /dev/vfio/* 2>/dev/null || true)
        if [ -n "$vfio_devices" ]; then
            echo "VFIO devices:"
            echo "$vfio_devices"
        fi
        return 0
    else
        log_info "/dev/vfio directory not found (may be normal for simulated passthrough)"
        return 0
    fi
}

main() {
    init_suite_logging "$TEST_NAME"

    GPU_FOUND=false
    AUDIO_FOUND=false
    NVIDIA_FOUND=false

    run_test "lspci Available" test_lspci_available
    run_test "List PCI Devices" test_list_pci_devices
    run_test "GPU Devices" test_gpu_devices
    run_test "Audio Devices" test_audio_devices
    run_test "NVIDIA Devices" test_nvidia_devices
    run_test "/proc/bus/pci" test_proc_bus_pci
    run_test "VFIO Devices" test_vfio_devices

    # Summary
    log_info ""
    log_info "=== PCIe Detection Summary ==="
    log_info "GPU devices found: $GPU_FOUND"
    log_info "Audio devices found: $AUDIO_FOUND"
    log_info "NVIDIA devices found: $NVIDIA_FOUND"

    print_test_summary "$TEST_NAME"

    # Overall result
    if [ "$GPU_FOUND" = true ] && [ "$NVIDIA_FOUND" = true ]; then
        log_pass "PCIe Device Detection: PASSED - Required PCIe devices are visible"
        exit 0
    else
        log_fail "PCIe Device Detection: FAILED - PCIe passthrough devices not properly detected"
        exit 1
    fi
}

main "$@"
