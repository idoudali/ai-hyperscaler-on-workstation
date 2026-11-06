# Kubernetes Scripts

This directory contains scripts for managing local Kubernetes clusters, specifically k3s with GPU support.

## Scripts Overview

| Script | Purpose |
|--------|---------|
| `setup-k3s-cluster.sh` | Install and configure k3s with GPU support |
| `teardown-k3s-cluster.sh` | Clean uninstall of k3s cluster |
| `verify-k3s-gpu.sh` | Verify cluster health and GPU availability |
| `get-k3s-kubeconfig.sh` | Export kubeconfig for multi-cluster management |

## Usage

All scripts should be run from the project root directory:

```bash
# Setup k3s cluster
./scripts/k8s/setup-k3s-cluster.sh

# Verify cluster
./scripts/k8s/verify-k3s-gpu.sh

# Export kubeconfig
./scripts/k8s/get-k3s-kubeconfig.sh

# Teardown cluster
./scripts/k8s/teardown-k3s-cluster.sh
```

## Makefile Targets

These scripts are also accessible via Makefile targets:

```bash
make k3s-setup          # Setup k3s cluster
make k3s-status         # Verify cluster status
make k3s-kubeconfig     # Export kubeconfig
make k3s-teardown       # Teardown cluster
```

## Prerequisites

- NVIDIA driver installed and loaded
- NVIDIA Container Toolkit installed
- Root/sudo access for k3s installation
- At least 50GB free disk space

## Multi-Cluster Support

Kubeconfigs are exported to `output/cluster-state/kubeconfigs/k3s-local.kubeconfig` for integration
with the project's multi-cluster kubeconfig management system.

See `scripts/manage-kubeconfig.sh` for managing multiple cluster configs.
