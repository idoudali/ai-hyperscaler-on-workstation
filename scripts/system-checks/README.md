# System Check Scripts

**Status:** TODO  
**Last Updated:** 2025-01-27

## Overview

This directory contains system check scripts for validating HPC infrastructure components and configurations.

## Available Scripts

### Prerequisites Check

- **check_prereqs.sh**: Validates system prerequisites for HPC deployment
  - Checks for required packages
  - Validates system configuration
  - Verifies network connectivity
  - Tests virtualization support

### Hardware Inventory

- **gpu_inventory.sh**: Discovers and reports GPU hardware
  - Lists available GPUs
  - Reports GPU capabilities
  - Checks driver installation
  - Validates GPU passthrough support

## Usage

Run scripts from the project root or system-checks directory:

```bash
# Check system prerequisites
./scripts/system-checks/check_prereqs.sh

# Inventory GPU hardware
./scripts/system-checks/gpu_inventory.sh
```

## Prerequisites

Scripts require:

- Bash shell
- Standard Unix utilities (grep, awk, sed)
- GPU utilities (nvidia-smi) for GPU checks
- Network tools for connectivity tests

## Output

Scripts provide:

- Pass/fail status for each check
- Detailed error messages for failures
- Hardware inventory information
- Configuration recommendations

## Integration

These scripts are used by:

- Deployment automation
- CI/CD pipelines
- Troubleshooting workflows
- System validation procedures
