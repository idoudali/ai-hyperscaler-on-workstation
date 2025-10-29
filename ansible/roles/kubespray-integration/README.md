# Kubespray Integration Role

This Ansible role integrates Kubespray for deploying Kubernetes clusters in the cloud cluster infrastructure.

## Purpose

The role:

1. Verifies Kubespray is installed
2. Verifies inventory file exists
3. Executes Kubespray's `cluster.yml` playbook to deploy Kubernetes

## Prerequisites

1. **Kubespray Installation**: Kubespray must be installed via CMake:

   ```bash
   cmake --build build --target install-kubespray
   ```

2. **Inventory Generation**: Generate Kubespray inventory:

   ```bash
   python scripts/generate-kubespray-inventory.py config/cloud-cluster.yaml cloud \
     ansible/inventories/cloud-cluster/inventory.ini
   ```

3. **VMs Running**: Cloud cluster VMs must be provisioned and running with SSH access.

## Role Variables

### Required Variables

None - defaults should work, but can be overridden:

- `kubespray_source_dir`: Path to Kubespray source (default: `../../build/3rd-party/kubespray/kubespray-src`)
- `kubespray_inventory_file`: Path to inventory file (default: `../../ansible/inventories/cloud-cluster/inventory.ini`)

### Configuration via group_vars

Kubespray configuration is managed via:

- `ansible/inventories/cloud-cluster/group_vars/all/cloud-cluster.yml`
- `ansible/inventories/cloud-cluster/group_vars/k8s_cluster/k8s-cluster.yml`

## Usage

The role is used by the `deploy-cloud-cluster.yml` playbook:

```yaml
- name: Deploy Kubernetes with Kubespray
  hosts: localhost
  roles:
    - kubespray-integration
```

## What Kubespray Deploys

- Container runtime (containerd)
- Kubernetes control plane (API server, etcd, controller-manager, scheduler)
- Worker node components (kubelet, kube-proxy)
- CNI plugin (Calico)
- CoreDNS
- Metrics-server
- NGINX Ingress Controller

## Dependencies

- Kubespray v2.29.0+ installed
- Ansible 2.14+
- Python 3.9+ on all target nodes
- SSH access to all cluster nodes

## References

- Main task: `planning/implementation-plans/task-lists/cloud-cluster/02-kubernetes-phase.md`
- Kubespray docs: https://kubespray.io/
