# Kubernetes Native Migration - Implementation Summary

This document summarizes the implementation of Kubernetes-native deployment for HPC and Cloud
environments, replacing the previous VM-based approach.

## Overview

The migration enables running HPC (Slurm) and Cloud (Kubernetes) environments directly on Kubernetes
pods without requiring Virtual Machines. This provides:

- **No VM Overhead**: Uses container-native approach (k3s recommended for GPU workloads)
- **Local Development**: Run on workstation without hypervisors
- **Container-First**: All components run as Kubernetes pods
- **Better Resource Utilization**: More efficient than VM-based setup
- **GPU Support**: Native GPU passthrough with k3s (unlike Kind which has limitations)

## What Was Implemented

### 1. Documentation

**K8s Native Setup Guide** (`docs/guides/k8s-native-setup.md`):

- **Local K8s Installation**: Step-by-step instructions for setting up Kind cluster
- **Slurm Deployment Options**:
  - **Slinky** (SchedMD's official solution) - Recommended for production
  - **Static Deployment** - Manual Kubernetes manifests for learning/development
- **vCluster Setup**: Instructions for multi-tenant cloud environment simulation
- **Container Build**: Building and loading Slurm container images
- **Verification**: Testing and validation procedures

**K3s Local Setup Guide** (`docs/guides/k3s-local-setup.md`):

- **K3s Installation**: Step-by-step instructions for k3s with GPU support
- **GPU Configuration**: NVIDIA device plugin setup
- **Multi-Cluster Kubeconfig Management**: Working with multiple clusters
- **Storage Configuration**: Local-path-provisioner setup
- **Troubleshooting**: Common issues and solutions

**Local Storage Guide** (`docs/guides/local-storage-pvc.md`):

- **PVC Creation**: How to create and use PersistentVolumeClaims
- **Storage Examples**: Database, training data, Slurm state
- **Best Practices**: Storage sizing, backup, monitoring

### 2. Container Images (`containers/images/slurm-base/`)

Created containerized Slurm base image:

- **Dockerfile**: Base Ubuntu image with Slurm dependencies
- **Entrypoint Script**: Configures container for different roles (controller, compute, database)
- **Install Script**: Installs Slurm packages from mounted volume
- **Multi-Role Support**: Single image can serve as controller, compute node, or database daemon

### 3. Kubernetes Manifests (`k8s-manifests/hpc-slurm/`)

Complete Kubernetes deployment manifests:

- **namespace.yaml**: Slurm namespace
- **secrets.yaml**: Database credentials template
- **storage.yaml**: Persistent volume claims for database and state
- **mariadb-deployment.yaml**: MariaDB StatefulSet for Slurm accounting
- **slurmdbd-deployment.yaml**: Slurm database daemon deployment
- **slurmctld-deployment.yaml**: Slurm controller deployment
- **slurmd-statefulset.yaml**: Slurm compute nodes StatefulSet
- **slurm-config-template.yaml**: Slurm configuration template
- **README.md**: Deployment instructions

### 4. Helper Scripts

- **`scripts/generate-munge-key.sh`**: Generates MUNGE authentication key
- **`scripts/verify-k8s-hpc.sh`**: Verifies Kubernetes-native HPC deployment

### 5. Kind Configuration

- **`kind-config.yaml`**: Kind cluster configuration with port mappings for Slurm services

### 6. vCluster Documentation

Complete instructions for setting up virtual clusters for multi-tenant cloud environments:

- vCluster CLI installation
- Operator deployment
- Virtual cluster creation
- ArgoCD deployment in virtual cluster

## Architecture

### Static Deployment Architecture

```text
┌─────────────────────────────────────────────────────────┐
│              Kubernetes Cluster (Kind)                   │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐    ┌──────────────┐                  │
│  │   MariaDB    │◄───┤  slurmdbd    │                  │
│  │ (StatefulSet)│    │(Deployment)  │                  │
│  └──────────────┘    └──────┬───────┘                  │
│                             │                            │
│                      ┌──────▼───────┐                   │
│                      │ slurmctld    │                   │
│                      │(Deployment)  │                   │
│                      └──────┬───────┘                   │
│                             │                            │
│         ┌───────────────────┼───────────────────┐      │
│         │                   │                   │       │
│  ┌──────▼──────┐   ┌───────▼──────┐  ┌────────▼─────┐│
│  │ slurmd-0    │   │ slurmd-1     │  │ slurmd-2     ││
│  │(StatefulSet)│   │(StatefulSet) │  │(StatefulSet) ││
│  └─────────────┘   └──────────────┘  └──────────────┘│
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Deployment Methods

### Local Development: K3s (Recommended for GPU Workloads)

K3s is recommended for local development with GPU support:

- **Native GPU Support**: Direct GPU passthrough (no nested container limitations)
- **Lightweight**: Single binary, fast startup
- **Production-Ready API**: Full Kubernetes compatibility
- **Multi-Cluster Support**: Integrated kubeconfig management

See: `docs/guides/k3s-local-setup.md`

**Note:** Kind does not support GPU passthrough effectively due to nested container limitations. Use k3s for GPU workloads.

### Production: Slinky (Recommended)

SchedMD's official Kubernetes operator for Slurm:

- **Dynamic Autoscaling**: Automatically scales compute nodes
- **Official Support**: Commercial support available
- **Production-Ready**: Best for production deployments

See: `docs/guides/k8s-native-setup.md#slinky-deployment`

### Development: Static Deployment

Manual Kubernetes manifests:

- **Full Control**: Complete control over configuration
- **Learning**: Great for understanding Slurm on Kubernetes
- **Simple Clusters**: Good for small, static clusters

See: `docs/guides/k8s-native-setup.md#static-slurm-deployment`

## Key Files Created

### Documentation

- `docs/guides/k8s-native-setup.md` - Complete setup guide
- `docs/guides/k8s-native-migration-summary.md` - This file

### Container Images

- `containers/images/slurm-base/Docker/Dockerfile` - Base Slurm container
- `containers/images/slurm-base/Docker/entrypoint.sh` - Container entrypoint
- `containers/images/slurm-base/Docker/install-slurm.sh` - Package installer

### Kubernetes Manifests

- `k8s-manifests/hpc-slurm/namespace.yaml`
- `k8s-manifests/hpc-slurm/secrets.yaml`
- `k8s-manifests/hpc-slurm/storage.yaml`
- `k8s-manifests/hpc-slurm/mariadb-deployment.yaml`
- `k8s-manifests/hpc-slurm/slurmdbd-deployment.yaml`
- `k8s-manifests/hpc-slurm/slurmctld-deployment.yaml`
- `k8s-manifests/hpc-slurm/slurmd-statefulset.yaml`
- `k8s-manifests/hpc-slurm/slurm-config-template.yaml`
- `k8s-manifests/hpc-slurm/README.md`

### Scripts

- `scripts/generate-munge-key.sh` - MUNGE key generator
- `scripts/verify-k8s-hpc.sh` - Deployment verification

### Configuration

- `kind-config.yaml` - Kind cluster configuration

## Next Steps

1. **Review Documentation**: Read `docs/guides/k8s-native-setup.md` for complete instructions

2. **Build Container Images**:

   ```bash
   docker build -t slurm-base:latest containers/images/slurm-base/Docker/
   kind load docker-image slurm-base:latest --name ai-hyperscaler
   ```

3. **Generate MUNGE Key**:

   ```bash
   ./scripts/generate-munge-key.sh
   kubectl create secret generic slurm-munge-key \
     --from-file=munge.key=build/shared/munge/munge.key \
     --namespace=slurm
   ```

4. **Customize Configuration**:
   - Update `k8s-manifests/hpc-slurm/slurm-config-template.yaml` with your cluster settings
   - Update hostPath paths in manifests to point to your Slurm packages
   - Adjust resource requests/limits based on your hardware

5. **Deploy**:

   ```bash
   kubectl apply -f k8s-manifests/hpc-slurm/
   ```

6. **Verify**:

   ```bash
   ./scripts/verify-k8s-hpc.sh
   ```

## Comparison: VM-based vs K8s-native

| Aspect | VM-based | K8s-native |
|--------|----------|------------|
| **Infrastructure** | Virtual Machines (KVM/libvirt) | Kubernetes Pods |
| **Resource Overhead** | Higher (full OS per VM) | Lower (shared OS) |
| **Startup Time** | Minutes (VM boot) | Seconds (container start) |
| **Scaling** | Manual VM provisioning | Automatic pod scaling |
| **Development** | Requires hypervisor | Just Docker |
| **Isolation** | Strong (VM-level) | Good (container-level) |
| **Storage** | VM disk images | Kubernetes volumes |
| **Networking** | VM networking | Kubernetes networking |

## Benefits

1. **No VMs Required**: Run on any workstation with Docker
2. **Faster Iteration**: Containers start much faster than VMs
3. **Better Resource Usage**: Shared kernel reduces overhead
4. **Cloud-Native**: Aligns with modern container orchestration
5. **Easier Development**: No need for hypervisors or VM management
6. **Consistent Environment**: Same containers across dev/staging/prod

## Limitations

1. **Kind GPU Support**: Kind does not support GPU passthrough effectively (use k3s instead)
2. **Network Performance**: Container networking may have overhead vs VM networking
3. **Storage**: Local storage limited compared to dedicated VM storage
4. **Isolation**: Container isolation vs VM-level isolation (may matter for security)

**Note:** For GPU workloads, k3s is recommended over Kind. K3s provides native GPU support without nested container limitations.

## Related Documentation

- **Setup Guide**: `docs/guides/k8s-native-setup.md`
- **Slinky Documentation**: https://www.schedmd.com/slinky/why-slinky/
- **vCluster Documentation**: https://www.vcluster.com/docs
- **Kind Documentation**: https://kind.sigs.k8s.io/docs/

## Status

✅ **Completed**:

- Documentation with Kind setup instructions
- **K3s setup guide with GPU support** (recommended for local GPU workloads)
- Slinky deployment instructions
- Static deployment manifests
- Container images structure
- Helper scripts (k3s setup, teardown, verification)
- vCluster setup documentation
- **Local storage/PVC guide**
- **Multi-cluster kubeconfig management**
- **GPU device plugin manifests**
- **Makefile targets for k3s management**

⏳ **Future Work**:

- Complete Slurm ConfigMap generation
- Automated deployment scripts
- CI/CD integration
- Performance benchmarking
