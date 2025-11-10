# GPU Validation Test Suite

Tests GPU driver installation, PCIe device detection, and basic GPU functionality.

## Test Scripts

- **check-pcie-devices.sh** - Validates PCIe passthrough and GPU device visibility
- **check-gpu-drivers.sh** - Tests NVIDIA driver installation and nvidia-smi functionality
- **run-all-tests.sh** - Main test runner for GPU validation

## Purpose

Ensures GPUs are properly passed through to VMs, drivers are installed correctly,
and basic GPU operations are functional.

## Prerequisites

- Basic infrastructure tests passing
- GPU PCIe passthrough configured in VM definitions
- VMs with GPU access started

## Usage

```bash
./run-all-tests.sh
```

## Dependencies

- basic-infrastructure
