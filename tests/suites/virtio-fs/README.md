# VirtioFS Test Suite

Tests VirtioFS host-guest filesystem sharing, mount functionality, and performance.

## Test Scripts

- **check-virtio-fs-config.sh** - Validates VirtioFS configuration in VM definitions
- **check-mount-functionality.sh** - Tests filesystem mount and access from guest VMs
- **check-performance.sh** - Validates filesystem performance characteristics
- **run-virtio-fs-tests.sh** - Main test runner for all VirtioFS tests

## Purpose

Ensures VirtioFS provides efficient host-to-guest filesystem sharing for development
workflows and data access patterns.

## Prerequisites

- Basic infrastructure tests passing
- VirtioFS configured in VM XML definitions
- Host directories shared via virtiofsd

## Usage

```bash
./run-virtio-fs-tests.sh
```

## Dependencies

- basic-infrastructure
