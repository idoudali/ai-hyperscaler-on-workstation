# BeeGFS Test Suite

Tests BeeGFS distributed filesystem deployment, services, and performance.

## Test Scripts

- **check-beegfs-services.sh** - Validates BeeGFS management, metadata, and storage services
- **check-filesystem-operations.sh** - Tests basic filesystem operations (read, write, delete)
- **check-performance-scaling.sh** - Validates filesystem performance and scalability
- **run-beegfs-tests.sh** - Main test runner for all BeeGFS tests

## Purpose

Verifies that BeeGFS is correctly deployed across the cluster and provides the expected
distributed storage functionality and performance characteristics.

## Prerequisites

- Basic infrastructure tests passing
- BeeGFS management, metadata, and storage servers deployed
- BeeGFS clients mounted on compute nodes

## Usage

```bash
./run-beegfs-tests.sh
```

## Dependencies

- basic-infrastructure
