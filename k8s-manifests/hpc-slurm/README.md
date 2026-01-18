# Slurm on Kubernetes Manifests

Kubernetes manifests for deploying Slurm HPC workload manager on Kubernetes.

## Architecture

```
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

## Prerequisites

1. **Kind cluster** created (see `docs/guides/k8s-native-setup.md`)
2. **Slurm container image** built and loaded into Kind:
   ```bash
   # Build the image
   docker build -t slurm-base:latest containers/images/slurm-base/Docker/
   
   # Load into Kind
   kind load docker-image slurm-base:latest --name ai-hyperscaler
   ```
3. **Slurm packages** available at `build/packages/slurm/` (from CMake build)
4. **MUNGE key** generated (see deployment instructions)

## Deployment Order

1. `namespace.yaml` - Create namespace
2. `munge-key-secret.yaml` - Create MUNGE key secret
3. `storage.yaml` - Create persistent volume claims
4. `mariadb-deployment.yaml` - Deploy MariaDB
5. `slurmdbd-deployment.yaml` - Deploy Slurm database daemon
6. `slurmctld-deployment.yaml` - Deploy Slurm controller
7. `slurmd-statefulset.yaml` - Deploy Slurm compute nodes

## Quick Start

```bash
# Generate MUNGE key
./scripts/generate-munge-key.sh

# Deploy all components
kubectl apply -f k8s-manifests/hpc-slurm/

# Check status
kubectl get pods -n slurm
kubectl get svc -n slurm

# Access Slurm
kubectl exec -it -n slurm deployment/slurm-controller -- sinfo
```

## Alternative: Use Slinky

For production deployments with dynamic autoscaling, consider using [Slinky](https://www.schedmd.com/slinky/why-slinky/) instead. See `docs/guides/k8s-native-setup.md` for Slinky setup instructions.

