# Container Registry Test Suite

Tests container registry infrastructure, access controls, and multi-node synchronization.

## Test Scripts

- **check-registry-structure.sh** - Validates registry directory structure and organization
- **check-registry-access.sh** - Tests registry access from compute nodes
- **check-registry-permissions.sh** - Validates filesystem permissions and security
- **check-cross-node-sync.sh** - Tests image synchronization across cluster nodes
- **run-ansible-infrastructure-tests.sh** - Main test runner for registry infrastructure

## Purpose

Ensures the container registry is properly deployed with correct structure, permissions,
and accessibility from all compute nodes.

## Prerequisites

- Basic infrastructure tests passing
- Container runtime tests passing
- Registry directory structure created
- NFS/BeeGFS share mounted for registry

## Usage

```bash
./run-ansible-infrastructure-tests.sh
```

## Dependencies

- basic-infrastructure
- container-runtime
- beegfs (or NFS)
