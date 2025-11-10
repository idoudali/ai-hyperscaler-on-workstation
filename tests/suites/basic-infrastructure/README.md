# Basic Infrastructure Test Suite

Tests foundational infrastructure components including VM lifecycle, networking, and SSH connectivity.

## Test Scripts

- **check-vm-lifecycle.sh** - Validates VM creation, startup, and state management
- **check-basic-networking.sh** - Tests network connectivity and configuration
- **check-ssh-connectivity.sh** - Verifies SSH access to all cluster nodes
- **check-configuration.sh** - Validates infrastructure configuration files
- **run-basic-infrastructure-tests.sh** - Main test runner for all infrastructure tests

## Purpose

Ensures the underlying virtualization and networking infrastructure is properly configured before
deploying higher-level services.

## Prerequisites

- VMs must be created and powered on
- Network bridges and virtual networks configured
- SSH keys deployed to cluster nodes

## Usage

```bash
./run-basic-infrastructure-tests.sh
```

## Dependencies

None - this is the foundational test suite that all others depend on.
