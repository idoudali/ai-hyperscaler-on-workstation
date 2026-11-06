# K3s Local Setup Guide

This guide covers setting up a local k3s Kubernetes cluster with GPU support on your workstation.

## Overview

K3s is a lightweight Kubernetes distribution that runs natively on the host, making it ideal for
local development with GPU support. Unlike Kind (which runs in containers), k3s allows direct GPU
passthrough to pods.

**Why K3s for Local Development:**

- Native GPU support (no nested container limitations)
- Lightweight and fast startup
- Single binary installation
- Production-ready Kubernetes API
- Ideal for workstation development

## Prerequisites

Before setting up k3s, ensure you have:

1. **NVIDIA Driver** installed and loaded

   ```bash
   nvidia-smi  # Should show GPU information
   ```

2. **NVIDIA Container Toolkit** installed

   ```bash
   nvidia-container-cli --version
   ```

3. **Root/sudo access** for installation

4. **At least 50GB free disk space** for storage

## Quick Start

### 1. Setup K3s Cluster

```bash
# Using Makefile (recommended)
make k3s-setup

# Or manually
sudo ./scripts/k8s/setup-k3s-cluster.sh
```

This script will:

- Check NVIDIA driver and container toolkit
- Install k3s with containerd runtime
- Configure NVIDIA container runtime
- Deploy NVIDIA device plugin
- Deploy local-path-provisioner for storage
- Export kubeconfig for multi-cluster management

### 2. Verify Installation

```bash
# Check cluster status
make k3s-status

# Or manually
./scripts/k8s/verify-k3s-gpu.sh
```

### 3. Access the Cluster

```bash
# Export kubeconfig
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/k3s-local.kubeconfig

# Or use kubeconfig management
make kubeconfig-use CLUSTER=k3s-local

# Verify access
kubectl get nodes
kubectl get pods -A
```

## Multi-Cluster Kubeconfig Management

This project supports working with multiple Kubernetes clusters simultaneously. Kubeconfigs are stored in `output/cluster-state/kubeconfigs/`.

### Available Commands

| Command | Description |
|---------|-------------|
| `make kubeconfig-list` | List all available cluster configs |
| `make kubeconfig-use CLUSTER=k3s-local` | Switch to k3s cluster |
| `make kubeconfig-current` | Show current context |
| `make kubeconfig-merge` | Merge all configs for multi-context |

### Manual Usage

```bash
# List clusters
./scripts/manage-kubeconfig.sh list

# Use specific cluster
./scripts/manage-kubeconfig.sh use k3s-local

# Set KUBECONFIG for session
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/k3s-local.kubeconfig

# Merge all configs
./scripts/manage-kubeconfig.sh merge
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/merged.kubeconfig
kubectl config get-contexts
kubectl config use-context k3s-local
```

### Working with Multiple Clusters

```bash
# List all clusters
make kubeconfig-list

# Switch between clusters
make kubeconfig-use CLUSTER=k3s-local
kubectl get nodes

make kubeconfig-use CLUSTER=cloud-cluster
kubectl get nodes

# Or merge and use kubectl context switching
make kubeconfig-merge
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/merged.kubeconfig
kubectl config use-context k3s-local
kubectl config use-context cloud-cluster
```

## GPU Configuration

### Verify GPU Availability

After setup, verify GPUs are available:

```bash
# Check node GPU capacity
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPUS:.status.capacity.'nvidia\.com/gpu'

# Check device plugin
kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds
```

### Requesting GPUs in Pods

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  containers:
  - name: cuda-test
    image: nvidia/cuda:12.0.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
```

### Deploying Slurm with GPU Support

The Slurm compute nodes are configured to request GPUs:

```bash
# Deploy Slurm to k3s
make k3s-deploy-slurm

# Or manually
kubectl apply -f k8s-manifests/hpc-slurm/
```

Each `slurmd` pod will request 1 GPU. With 2 GPUs available, you can run 2 compute nodes.

## Storage Configuration

K3s uses local-path-provisioner for dynamic PVC provisioning. See [Local Storage PVC Guide](./local-storage-pvc.md) for details.

### Quick Storage Example

```bash
# Create a PVC
kubectl apply -f k8s-manifests/storage/examples/pvc-small.yaml

# Use in a pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: storage-test
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: pvc-small
EOF
```

## Troubleshooting

### K3s Service Not Running

```bash
# Check service status
sudo systemctl status k3s

# Restart service
sudo systemctl restart k3s

# Check logs
sudo journalctl -u k3s -f
```

### GPUs Not Visible

1. **Check NVIDIA driver:**

   ```bash
   nvidia-smi
   ```

2. **Check device plugin:**

   ```bash
   kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds
   kubectl logs -n kube-system -l name=nvidia-device-plugin-ds
   ```

3. **Check containerd NVIDIA runtime:**

   ```bash
   sudo nvidia-ctk runtime configure --runtime=containerd
   sudo systemctl restart containerd
   sudo systemctl restart k3s
   ```

4. **Verify node capacity:**

   ```bash
   kubectl describe node | grep nvidia.com/gpu
   ```

### Storage Issues

1. **Check local-path-provisioner:**

   ```bash
   kubectl get pods -n local-path-storage
   kubectl logs -n local-path-storage -l app=local-path-provisioner
   ```

2. **Check storage class:**

   ```bash
   kubectl get storageclass
   ```

3. **Verify storage directory exists:**

   ```bash
   ls -la /opt/k3s-storage/
   ```

### Kubeconfig Issues

1. **Regenerate kubeconfig:**

   ```bash
   make k3s-kubeconfig
   ```

2. **Check permissions:**

   ```bash
   ls -la output/cluster-state/kubeconfigs/k3s-local.kubeconfig
   # Should be 600
   ```

3. **Test connectivity:**

   ```bash
   export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/k3s-local.kubeconfig
   kubectl cluster-info
   ```

## Teardown

To remove k3s cluster:

```bash
# Using Makefile
make k3s-teardown

# Or manually
sudo ./scripts/k8s/teardown-k3s-cluster.sh
```

This will:

- Stop k3s service
- Uninstall k3s
- Remove kubeconfig
- Optionally clean storage directories

## Next Steps

- [Local Storage PVC Guide](./local-storage-pvc.md) - Using persistent volumes
- [Kubernetes GPU Tutorial](../tutorials/kubernetes/03-local-k8s-gpu.md) - Running GPU workloads
- [K8s Native Migration Summary](./k8s-native-migration-summary.md) - Architecture overview

## Reference

- [K3s Documentation](https://k3s.io/)
- [NVIDIA Device Plugin](https://github.com/NVIDIA/k8s-device-plugin)
- [Local Path Provisioner](https://github.com/rancher/local-path-provisioner)
