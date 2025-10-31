# ArgoCD Applications

This directory contains ArgoCD Application definitions for deploying the MLOps stack using GitOps.

## Overview

ArgoCD Applications define how your Kubernetes resources should be deployed and managed. These manifests connect
your Git repository (source of truth) with your Kubernetes cluster (deployment target).

## Applications

| Application | Description | Path | Namespace |
|-------------|-------------|------|-----------|
| **minio-app.yaml** | MinIO object storage | `k8s-manifests/base/mlops/minio` | mlops |
| **postgresql-app.yaml** | PostgreSQL database | `k8s-manifests/base/mlops/postgresql` | mlops |
| **mlops-stack-app.yaml** | App of Apps (deploys all) | `k8s-manifests/argocd-apps` | argocd |

## Setup

### 1. Update Git Repository URL

**IMPORTANT:** Before deploying, update the `repoURL` in all application manifests:

```yaml
spec:
  source:
    repoURL: https://github.com/your-org/ai-how  # Update this!
```

Replace `https://github.com/your-org/ai-how` with your actual Git repository URL.

### 2. Deploy Applications

**Option A: Individual Applications**

```bash
# Deploy MinIO
kubectl apply -f k8s-manifests/argocd-apps/minio-app.yaml

# Deploy PostgreSQL
kubectl apply -f k8s-manifests/argocd-apps/postgresql-app.yaml
```

**Option B: App of Apps (Recommended)**

Deploy all applications at once using the App of Apps pattern:

```bash
kubectl apply -f k8s-manifests/argocd-apps/mlops-stack-app.yaml
```

This creates a parent Application that manages all child Applications (MinIO, PostgreSQL, etc.).

### 3. Verify Deployment

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check application status
kubectl describe application minio -n argocd

# View in ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
```

## GitOps Workflow

### Making Changes

1. **Edit Kubernetes manifests** in `k8s-manifests/base/mlops/*/`
2. **Commit and push** to Git
3. **ArgoCD automatically syncs** changes to the cluster

```bash
# Example: Update MinIO storage size
vim k8s-manifests/base/mlops/minio/pvc.yaml
# Change storage: 100Gi → storage: 200Gi

git add k8s-manifests/base/mlops/minio/pvc.yaml
git commit -m "Increase MinIO storage to 200Gi"
git push

# ArgoCD will detect and apply the change automatically
```

### Manual Sync

If auto-sync is disabled or you want to sync immediately:

```bash
# Via kubectl
kubectl patch application minio -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# Via ArgoCD CLI
argocd app sync minio

# Via ArgoCD UI
# Click on application → SYNC button
```

## Application Configuration

### Sync Policies

All applications use automated sync:

```yaml
syncPolicy:
  automated:
    prune: true        # Remove resources deleted from Git
    selfHeal: true     # Revert manual changes in cluster
    allowEmpty: false  # Prevent accidental deletion of all resources
```

### Sync Options

- `CreateNamespace=true`: Auto-create target namespace
- `PrunePropagationPolicy=foreground`: Delete dependent resources first
- `PruneLast=true`: Prune resources after new resources are healthy

### Retry Policy

Automatic retry on sync failure:

```yaml
retry:
  limit: 5           # Max retry attempts
  backoff:
    duration: 5s     # Initial backoff
    factor: 2        # Backoff multiplier
    maxDuration: 3m  # Max backoff duration
```

## Troubleshooting

### Application OutOfSync

```bash
# Check diff
argocd app diff minio

# Force sync
argocd app sync minio --force

# View detailed status
kubectl describe application minio -n argocd
```

### Application Unhealthy

```bash
# Check health status
kubectl get application minio -n argocd -o jsonpath='{.status.health}'

# Check deployed resources
kubectl get all -n mlops -l app.kubernetes.io/instance=minio

# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### Sync Failed

```bash
# View sync operation
kubectl get application minio -n argocd -o jsonpath='{.status.operationState}'

# Check sync errors
argocd app get minio

# Retry sync
argocd app sync minio --retry-limit 3
```

## Advanced Patterns

### Multiple Environments

Use Kustomize overlays for environment-specific configurations:

```yaml
# dev-minio-app.yaml
spec:
  source:
    path: k8s-manifests/overlays/dev/mlops/minio  # Dev overlay

# prod-minio-app.yaml
spec:
  source:
    path: k8s-manifests/overlays/prod/mlops/minio  # Prod overlay
```

### Progressive Sync

Deploy applications in a specific order:

```yaml
# PostgreSQL first, then MinIO
spec:
  syncPolicy:
    syncOptions:
      - SyncWave=1  # PostgreSQL
---
spec:
  syncPolicy:
    syncOptions:
      - SyncWave=2  # MinIO (after PostgreSQL)
```

## References

- [ArgoCD Applications](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern)
- [Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [Health Assessment](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/)
