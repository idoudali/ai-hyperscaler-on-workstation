# Managing Multiple Kubernetes Configs

This guide explains how to manage multiple Kubernetes cluster configurations on the same system.

## Overview

When deploying multiple Kubernetes clusters (e.g., cloud-cluster, HPC clusters, different environments),
each cluster has its own kubeconfig file. This document explains how to manage them effectively.

## Prerequisites

Before you can manage Kubernetes clusters locally, you need:

### 1. Kubernetes Cluster Deployed

The cluster must be deployed using the Ansible playbooks. During deployment, kubeconfig files
are automatically generated and saved locally.

**If you haven't deployed a cluster yet:**

```bash
# Deploy a cloud cluster (see ansible/playbooks/README.md for details)
ansible-playbook -i inventories/cloud-cluster/inventory.ini \
  playbooks/playbook-cloud-runtime.yml \
  -e kubeconfig_cluster_name=cloud-cluster
```

The playbook will automatically:

- Deploy the Kubernetes cluster
- Save kubeconfig to `output/cluster-state/kubeconfigs/{cluster_name}.kubeconfig`
- Configure the kubeconfig for local access (API server IP, context names)

### 2. kubectl Installed Locally

Install kubectl on your local machine:

**Linux:**

```bash
# Download latest kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
```

**macOS:**

```bash
# Using Homebrew
brew install kubectl

# Or download binary
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**Windows:**

```powershell
# Using Chocolatey
choco install kubernetes-cli

# Or using direct download
# Download from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
```

### 3. Network Access to Cluster

Ensure your local machine can reach the Kubernetes API server:

- **Control plane IP** (typically port 6443)
- **SSH access** to control plane node (for troubleshooting)

Verify network connectivity:

```bash
# Test API server connectivity (after setting up kubeconfig)
kubectl cluster-info
```

### 4. Kubeconfig Files Present

After deployment, verify kubeconfig files exist:

```bash
# List available kubeconfigs
./scripts/manage-kubeconfig.sh list

# Expected output:
# Available clusters:
#   cloud-cluster - 2.3K - Context: kubernetes-admin@cloud-cluster
```

If no kubeconfigs are found, the cluster may not be deployed, or the playbook didn't complete successfully.

## Getting Started (Complete Workflow)

### Step 1: Deploy Your First Cluster

If you haven't deployed a cluster yet, start here:

```bash
# Navigate to ansible directory
cd ansible

# Deploy cloud cluster
ansible-playbook -i inventories/cloud-cluster/inventory.ini \
  playbooks/playbook-cloud-runtime.yml \
  -e kubeconfig_cluster_name=cloud-cluster

# Wait for deployment to complete (can take 15-30 minutes)
```

After successful deployment, you'll see:

```text
===============================================================
Kubeconfig Saved for Cluster: cloud-cluster
===============================================================
Location: /path/to/project/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig
Kubernetes API Server: <control-plane-ip>:6443
```

### Step 2: Verify Local kubectl Access

From your local machine (not on the cluster nodes):

```bash
# Switch to the deployed cluster
./scripts/manage-kubeconfig.sh use cloud-cluster

# Test connectivity
kubectl cluster-info
kubectl get nodes
```

**Expected output:**

```text
Kubernetes control plane is running at https://<control-plane-ip>:6443
CoreDNS is running at https://<control-plane-ip>:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

NAME                STATUS   ROLES           AGE   VERSION
cloud-control-01    Ready    control-plane   30d   v1.28.x
cloud-worker-01     Ready    worker          30d   v1.28.x
```

### Step 3: Start Using Kubernetes

You're now ready to manage your cluster locally! See the [Quick Start](#quick-start) section below for common operations.

## Kubeconfig Storage

The playbook automatically saves cluster-specific kubeconfigs in the repository's output directory:

```text
output/cluster-state/kubeconfigs/
├── cloud-cluster.kubeconfig   # Cloud cluster kubeconfig
├── hpc-cluster.kubeconfig     # HPC cluster kubeconfig (if applicable)
├── dev.kubeconfig             # Development cluster (if applicable)
└── merged.kubeconfig          # Merged config (optional, for multi-cluster access)
```

**Important:**

- This directory is **gitignored** (contains sensitive certificates)
- All paths are relative to the project root
- Use `KUBECONFIG` environment variable to point to specific files

## Quick Start

### 1. List Available Clusters

```bash
./scripts/manage-kubeconfig.sh list
```

Output:

```text
Available clusters:

  cloud-cluster - 2.3K - Context: kubernetes-admin@cloud-cluster
  hpc-cluster - 2.1K - Context: kubernetes-admin@hpc-cluster
```

### 2. Use a Specific Cluster

**Option A: Temporary (Current Shell Session)**

```bash
# Use helper script (recommended)
./scripts/manage-kubeconfig.sh use cloud-cluster

# Or manually with absolute path
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig
kubectl get nodes
```

**Option B: Permanent (Add to ~/.bashrc or ~/.zshrc)**

```bash
# Use absolute path from project root
export KUBECONFIG="${HOME}/Projects/pharos.ai-hyperscaler-on-workskation/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig"

# Or use helper script to get path
source <(./scripts/manage-kubeconfig.sh use cloud-cluster)
```

### 3. Set Default Cluster

```bash
./scripts/manage-kubeconfig.sh set-default cloud-cluster
```

This copies the cluster config to `~/.kube/config` (the default kubectl location).

### 4. Merge All Clusters (Multi-Cluster Access)

Merge all cluster configs into one file to access all clusters with context switching:

```bash
./scripts/manage-kubeconfig.sh merge
```

This creates `~/.kube/config` with all contexts. Switch between clusters:

```bash
kubectl config use-context kubernetes-admin@cloud-cluster
kubectl config use-context kubernetes-admin@hpc-cluster
```

## Helper Script Usage

The `scripts/manage-kubeconfig.sh` script provides easy management:

### Commands

| Command | Description | Example |
|---------|-------------|---------|
| `list` | List all available clusters | `./scripts/manage-kubeconfig.sh list` |
| `use <cluster>` | Switch to a cluster | `./scripts/manage-kubeconfig.sh use cloud-cluster` |
| `merge [output]` | Merge all configs | `./scripts/manage-kubeconfig.sh merge` |
| `current` | Show current context | `./scripts/manage-kubeconfig.sh current` |
| `show <cluster>` | Show cluster details | `./scripts/manage-kubeconfig.sh show cloud-cluster` |
| `set-default <cluster>` | Set as default | `./scripts/manage-kubeconfig.sh set-default cloud-cluster` |

### Examples

```bash
# List all clusters
./scripts/manage-kubeconfig.sh list

# Switch to cloud-cluster for this session
./scripts/manage-kubeconfig.sh use cloud-cluster
kubectl get nodes

# Show details about a cluster
./scripts/manage-kubeconfig.sh show cloud-cluster

# Set cloud-cluster as default
./scripts/manage-kubeconfig.sh set-default cloud-cluster

# Merge all clusters and switch contexts
./scripts/manage-kubeconfig.sh merge
kubectl config use-context kubernetes-admin@cloud-cluster
kubectl config use-context kubernetes-admin@hpc-cluster

# Check current context
./scripts/manage-kubeconfig.sh current
```

## Manual Methods

### Method 1: KUBECONFIG Environment Variable

Switch clusters using environment variable (from project root):

```bash
# Use cloud-cluster
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig
kubectl get nodes

# Use hpc-cluster
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/hpc-cluster.kubeconfig
kubectl get nodes
```

### Method 2: Merge Multiple Configs

Use multiple kubeconfigs simultaneously:

```bash
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig:$(pwd)/output/cluster-state/kubeconfigs/hpc-cluster.kubeconfig

# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context kubernetes-admin@cloud-cluster
kubectl config use-context kubernetes-admin@hpc-cluster
```

### Method 3: Merge All Configs (Helper Script)

Use the helper script to merge all configs:

```bash
# Merge all configs into one file
./scripts/manage-kubeconfig.sh merge

# Then use the merged config
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/merged.kubeconfig
kubectl config get-contexts
kubectl config use-context kubernetes-admin@cloud-cluster
```

## Context Switching

When using merged configs, switch between clusters using contexts:

```bash
# List all available contexts
kubectl config get-contexts

# Switch to a specific cluster
kubectl config use-context kubernetes-admin@cloud-cluster

# Verify current context
kubectl config current-context

# Get nodes from current cluster
kubectl get nodes
```

## Best Practices

### 1. Use Cluster-Specific Configs for Scripts

For automation and scripts, explicitly set KUBECONFIG using project-relative paths:

```bash
#!/bin/bash
# Get absolute path to kubeconfig from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export KUBECONFIG="${SCRIPT_DIR}/../output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig"
kubectl apply -f my-manifests.yaml
```

### 2. Use Merged Config for Interactive Work

For daily development work, merge configs and use context switching:

```bash
# Once: Merge all configs
./scripts/manage-kubeconfig.sh merge

# Then switch contexts as needed
kubectl config use-context kubernetes-admin@cloud-cluster
```

### 3. Default Cluster for CI/CD

For CI/CD pipelines, use specific cluster configs from the repository:

```yaml
# GitHub Actions example
env:
  KUBECONFIG: ${{ github.workspace }}/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig

# GitLab CI example
variables:
  KUBECONFIG: ${CI_PROJECT_DIR}/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig

# Or use absolute path after deployment step
before_script:
  - export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig
```

### 4. Shell Aliases

Add convenient aliases to your shell profile:

```bash
# ~/.bashrc or ~/.zshrc
# Update PROJECT_ROOT to your actual project path
PROJECT_ROOT="${HOME}/Projects/pharos.ai-hyperscaler-on-workskation"
alias kube-cloud='export KUBECONFIG="${PROJECT_ROOT}/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig"'
alias kube-hpc='export KUBECONFIG="${PROJECT_ROOT}/output/cluster-state/kubeconfigs/hpc-cluster.kubeconfig"'
alias kube-list='cd "${PROJECT_ROOT}" && ./scripts/manage-kubeconfig.sh list'
alias kube-current='./scripts/manage-kubeconfig.sh current'
alias kube-use='cd "${PROJECT_ROOT}" && ./scripts/manage-kubeconfig.sh use'
```

## Troubleshooting

### Issue: kubectl can't connect to cluster

**Problem:** `kubectl cluster-info` fails

**Solution:** Verify kubeconfig points to correct API server:

```bash
# Check kubeconfig server URL
grep server output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig

# Should point to control plane IP, not 127.0.0.1
# server: https://192.168.200.10:6443
```

### Issue: Context not found

**Problem:** `kubectl config use-context` fails

**Solution:** List available contexts:

```bash
kubectl config get-contexts
```

If context doesn't exist, verify kubeconfig file exists and is valid:

```bash
kubectl --kubeconfig output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig config view
```

### Issue: Multiple contexts with same name

**Problem:** Context name conflicts after merging

**Solution:** Context names are automatically prefixed with cluster name during deployment:

- `kubernetes-admin@cloud-cluster`
- `kubernetes-admin@hpc-cluster`

If conflicts occur, manually edit context names:

```bash
kubectl config set-context new-name --cluster=cluster-name --user=user-name
```

## Integration with Ansible Playbooks

When running playbooks, specify the cluster name for kubeconfig management:

```bash
# Deploy and save kubeconfig with cluster name
ansible-playbook -i inventories/cloud-cluster/inventory.ini \
  playbooks/playbook-cloud-runtime.yml \
  -e kubeconfig_cluster_name=cloud-cluster

# For multiple clusters
ansible-playbook -i inventories/hpc-cluster/inventory.ini \
  playbooks/playbook-hpc-runtime.yml \
  -e kubeconfig_cluster_name=hpc-cluster
```

The playbook will automatically:

1. Save kubeconfig as `output/cluster-state/kubeconfigs/{cluster_name}.kubeconfig`
2. Update context name to include cluster name (e.g., `kubernetes-admin@cloud-cluster`)
3. Fix API server URL to use control plane IP (not 127.0.0.1)
4. All kubeconfigs are gitignored for security

## Related Documentation

- [Kubernetes Basics Tutorial](tutorials/kubernetes/01-kubernetes-basics.md) - Comprehensive guide to using
Kubernetes on the cluster
- [Cloud Cluster Deployment](../../ansible/playbooks/playbook-cloud-runtime.yml) - Deployment playbook
- [Kubernetes Configuration](../../ansible/inventories/cloud-cluster/group_vars/all/cloud-cluster.yml) - Cluster config
