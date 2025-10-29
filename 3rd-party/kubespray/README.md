# Kubespray Integration

**Status:** Active  
**Version:** v2.29.0  
**Purpose:** Kubernetes cluster deployment tool for cloud cluster

## Overview

Kubespray is a CNCF-approved Kubernetes deployment tool that provides production-ready
cluster installation using Ansible. This integration enables automated Kubernetes
 deployment for the cloud cluster infrastructure.

## Installation

Install Kubespray via CMake:

```bash
# Install Kubespray (clones repository to build directory)
cmake --build build --target install-kubespray

# Or using Docker container (recommended)
make run-docker COMMAND="cmake --build build --target install-kubespray"
```

This clones Kubespray to: `build/3rd-party/kubespray/kubespray-src/`

## Usage

### 1. Generate Inventory

Generate Kubespray inventory from cluster configuration:

```bash
# Generate inventory for cloud cluster
ai-how cloud generate-inventory config/cloud-cluster.yaml
```

This creates: `ansible/inventories/cloud-cluster/inventory.ini`

### 2. Deploy Kubernetes Cluster

Deploy using the wrapper playbook (recommended):

```bash
ansible-playbook -i ansible/inventories/cloud-cluster/inventory.ini \
  ansible/playbooks/deploy-cloud-cluster.yml
```

Or directly with Kubespray:

```bash
ansible-playbook -i ansible/inventories/cloud-cluster/inventory.ini \
  build/3rd-party/kubespray/kubespray-src/cluster.yml
```

## Configuration

Kubespray configuration is managed via Ansible group_vars:

- `ansible/inventories/cloud-cluster/group_vars/all/cloud-cluster.yml` - Main configuration
- `ansible/inventories/cloud-cluster/group_vars/k8s_cluster/k8s-cluster.yml` - Kubernetes settings

See the task documentation for full configuration details:
`planning/implementation-plans/task-lists/cloud-cluster/02-kubernetes-phase.md`

## Version Management

Kubespray version is pinned in `CMakeLists.txt`:

```cmake
set(KUBESPRAY_VERSION "v2.29.0")
```

To update: Change the version and rebuild. Test thoroughly before deploying to production.

## References

- **Kubespray Repository:** https://github.com/kubernetes-sigs/kubespray
- **Kubespray Documentation:** https://kubespray.io/
- **Getting Started:** https://github.com/kubernetes-sigs/kubespray/blob/master/docs/getting-started.md
