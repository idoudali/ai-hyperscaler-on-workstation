# Container Registry Test Suite

Tests container registry infrastructure deployed on BeeGFS, access controls, and multi-node accessibility.

## Test Scripts

- **check-registry-structure.sh** - Validates registry directory structure and organization on BeeGFS
- **check-registry-access.sh** - Tests registry access from compute nodes via BeeGFS
- **check-registry-permissions.sh** - Validates filesystem permissions and security
- **check-cross-node-sync.sh** - Tests BeeGFS cross-node accessibility (no sync needed - BeeGFS provides automatic distribution)
- **run-container-registry-tests.sh** - Main test runner for registry infrastructure

## Purpose

Ensures the container registry is properly accessible on BeeGFS with correct structure, permissions,
and automatic cross-node distribution (no manual synchronization required).

## Prerequisites

- Basic infrastructure tests passing
- Container runtime tests passing
- **BeeGFS deployed and mounted** at `/mnt/beegfs`
- Registry directory structure on BeeGFS (created automatically if missing)

## Usage

```bash
./run-container-registry-tests.sh
```

## Dependencies

- basic-infrastructure
- container-runtime
- **beegfs** (required - registry is deployed on BeeGFS at `/mnt/beegfs/containers`)

## Notes

- Container registry is deployed on BeeGFS, not via Ansible
- BeeGFS provides automatic cross-node synchronization - no rsync needed
- Registry path: `/mnt/beegfs/containers`
- All nodes access the same BeeGFS mount, so images are immediately available cluster-wide
