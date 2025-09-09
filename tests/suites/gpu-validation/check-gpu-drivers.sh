#!/bin/bash
#
# GPU Driver Test
# Validates that GPU drivers are loaded and nvidia-smi is functional
#

set -euo pipefail

echo "=== GPU Driver Test ==="
echo "Timestamp: $(date)"
echo

# Test 1: Check if nvidia-smi is available
echo "Test 1: Checking nvidia-smi availability..."
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "✓ nvidia-smi command available"
    NVIDIA_SMI_AVAILABLE=true
else
    echo "✗ nvidia-smi command not found"
    NVIDIA_SMI_AVAILABLE=false
fi

# Test 2: Check NVIDIA kernel modules
echo
echo "Test 2: Checking NVIDIA kernel modules..."
loaded_modules=$(lsmod | grep nvidia || true)
if [ -n "$loaded_modules" ]; then
    echo "✓ NVIDIA modules loaded:"
    echo "$loaded_modules"
    NVIDIA_MODULES_LOADED=true
else
    echo "✗ No NVIDIA modules found in lsmod"
    NVIDIA_MODULES_LOADED=false
fi

# Test 3: Check /proc/driver/nvidia
echo
echo "Test 3: Checking /proc/driver/nvidia..."
if [ -d /proc/driver/nvidia ]; then
    echo "✓ /proc/driver/nvidia directory exists"

    if [ -f /proc/driver/nvidia/version ]; then
        echo "  Driver version:"
        head -3 /proc/driver/nvidia/version
    fi

    if [ -d /proc/driver/nvidia/gpus ]; then
        gpu_count=$(find /proc/driver/nvidia/gpus -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        echo "  GPU count from /proc: $gpu_count"
    fi

    PROC_NVIDIA_EXISTS=true
else
    echo "✗ /proc/driver/nvidia directory not found"
    PROC_NVIDIA_EXISTS=false
fi

# Test 4: Run nvidia-smi (if available)
echo
echo "Test 4: Running nvidia-smi..."
if [ "$NVIDIA_SMI_AVAILABLE" = true ]; then
    echo "Executing: nvidia-smi"
    if nvidia_smi_output=$(nvidia-smi 2>&1); then
        echo "✓ nvidia-smi executed successfully"
        echo "$nvidia_smi_output"
        NVIDIA_SMI_SUCCESS=true

        # Extract GPU count from nvidia-smi output
        gpu_count=$(echo "$nvidia_smi_output" | grep -c "NVIDIA" | head -1 || echo "0")
        echo "  Detected GPU count: $gpu_count"
    else
        echo "✗ nvidia-smi execution failed:"
        echo "$nvidia_smi_output"
        NVIDIA_SMI_SUCCESS=false
    fi
else
    echo "⚠ Skipping nvidia-smi test (command not available)"
    NVIDIA_SMI_SUCCESS=false
fi

# Test 5: Check device files
echo
echo "Test 5: Checking NVIDIA device files..."
nvidia_devices=$(ls -la /dev/nvidia* 2>/dev/null || true)
if [ -n "$nvidia_devices" ]; then
    echo "✓ NVIDIA device files found:"
    echo "$nvidia_devices"
    NVIDIA_DEVICES_EXIST=true
else
    echo "✗ No NVIDIA device files found in /dev/"
    NVIDIA_DEVICES_EXIST=false
fi

# Test 6: Check for CUDA runtime (basic check)
echo
echo "Test 6: Checking CUDA runtime..."
if [ -d /usr/local/cuda ] || [ -d /opt/cuda ]; then
    echo "✓ CUDA installation directory found"
    CUDA_INSTALLED=true
else
    echo "! CUDA installation directory not found (may be normal)"
    CUDA_INSTALLED=false
fi

# Check nvcc if available
if command -v nvcc >/dev/null 2>&1; then
    echo "✓ nvcc compiler available"
    nvcc_version=$(nvcc --version | grep "release" || echo "Version info not available")
    echo "  $nvcc_version"
else
    echo "! nvcc compiler not found (may be normal for runtime-only installs)"
fi

# Summary
echo
echo "=== GPU Driver Summary ==="
echo "nvidia-smi available: $NVIDIA_SMI_AVAILABLE"
echo "nvidia-smi success: $NVIDIA_SMI_SUCCESS"
echo "NVIDIA modules loaded: $NVIDIA_MODULES_LOADED"
echo "/proc/driver/nvidia exists: $PROC_NVIDIA_EXISTS"
echo "NVIDIA device files exist: $NVIDIA_DEVICES_EXIST"
echo "CUDA installed: $CUDA_INSTALLED"

# Overall result - determine if GPU drivers are working
if [ "$NVIDIA_SMI_AVAILABLE" = true ] && [ "$NVIDIA_SMI_SUCCESS" = true ]; then
    echo
    echo "✓ GPU Driver Test: PASSED"
    echo "  GPU drivers are loaded and functional"
    exit 0
elif [ "$NVIDIA_MODULES_LOADED" = true ] && [ "$PROC_NVIDIA_EXISTS" = true ]; then
    echo
    echo "⚠ GPU Driver Test: PARTIAL"
    echo "  Drivers loaded but nvidia-smi may not be working"
    exit 0
else
    echo
    echo "✗ GPU Driver Test: FAILED"
    echo "  GPU drivers are not properly loaded or functional"
    exit 1
fi
