#!/bin/bash
#
# PCIe Device Detection Test
# Validates that PCIe passthrough devices are visible in the VM
#

set -euo pipefail

echo "=== PCIe Device Detection Test ==="
echo "Timestamp: $(date)"
echo

# Test 1: Check if lspci is available
echo "Test 1: Checking lspci availability..."
if command -v lspci >/dev/null 2>&1; then
    echo "✓ lspci command available"
else
    echo "✗ lspci command not found"
    exit 1
fi

# Test 2: List all PCI devices
echo
echo "Test 2: Listing all PCI devices..."
lspci_output=$(lspci)
echo "$lspci_output"

# Test 3: Look for GPU devices (NVIDIA class 0300)
echo
echo "Test 3: Checking for GPU devices..."
gpu_devices=$(lspci | grep -i "vga\|3d\|display" || true)
if [ -n "$gpu_devices" ]; then
    echo "✓ GPU devices found:"
    echo "$gpu_devices"
    GPU_FOUND=true
else
    echo "✗ No GPU devices detected"
    GPU_FOUND=false
fi

# Test 4: Look for audio devices (related to GPU)
echo
echo "Test 4: Checking for audio devices..."
audio_devices=$(lspci | grep -i "audio" || true)
if [ -n "$audio_devices" ]; then
    echo "✓ Audio devices found:"
    echo "$audio_devices"
    AUDIO_FOUND=true
else
    echo "✗ No audio devices detected"
    AUDIO_FOUND=false
fi

# Test 5: Check specific NVIDIA devices by vendor ID
echo
echo "Test 5: Checking for NVIDIA devices by vendor ID..."
nvidia_devices=$(lspci -nn | grep "10de:" || true)
if [ -n "$nvidia_devices" ]; then
    echo "✓ NVIDIA devices found:"
    echo "$nvidia_devices"
    NVIDIA_FOUND=true
else
    echo "✗ No NVIDIA devices detected by vendor ID"
    NVIDIA_FOUND=false
fi

# Test 6: Check /proc/bus/pci directory
echo
echo "Test 6: Checking /proc/bus/pci directory..."
if [ -d /proc/bus/pci ]; then
    echo "✓ /proc/bus/pci directory exists"
    pci_count=$(find /proc/bus/pci -name "*.0" | wc -l)
    echo "  Found $pci_count PCI device entries"
else
    echo "✗ /proc/bus/pci directory not found"
fi

# Test 7: Check for VFIO devices
echo
echo "Test 7: Checking for VFIO devices..."
if [ -d /dev/vfio ]; then
    echo "✓ /dev/vfio directory exists"
    vfio_devices=$(for file in /dev/vfio/*; do [ -e "$file" ] && ls -la "$file"; done 2>/dev/null || true)
    if [ -n "$vfio_devices" ]; then
        echo "  VFIO devices:"
        echo "$vfio_devices"
    fi
else
    echo "! /dev/vfio directory not found (may be normal for simulated passthrough)"
fi

# Summary
echo
echo "=== PCIe Detection Summary ==="
echo "GPU devices found: $GPU_FOUND"
echo "Audio devices found: $AUDIO_FOUND"
echo "NVIDIA devices found: $NVIDIA_FOUND"

# Overall result
if [ "$GPU_FOUND" = true ] && [ "$NVIDIA_FOUND" = true ]; then
    echo
    echo "✓ PCIe Device Detection: PASSED"
    echo "  Required PCIe devices are visible in the VM"
    exit 0
else
    echo
    echo "✗ PCIe Device Detection: FAILED"
    echo "  PCIe passthrough devices not properly detected"
    exit 1
fi
