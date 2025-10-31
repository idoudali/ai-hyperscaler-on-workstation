# Manual Kubernetes Deployment Guide

**Audience:** Developers who need to deploy applications without GitOps/ArgoCD
**Use Case:** Testing, development, or environments without Git access

## Overview

This guide explains how to deploy MinIO and PostgreSQL directly to Kubernetes
using `kubectl` and `kustomize`, bypassing the GitOps workflow.

**⚠️ Important:** For production deployments, use GitOps
(see [quickstart-gitops.md](quickstart-gitops.md)) instead of manual deployment.

## Quick Start

```bash
# Prerequisites: Kubernetes cluster deployed
make cloud-cluster-deploy

# Option 1: Deploy all applications manually (bypasses GitOps)
make k8s-deploy-manual
# Or from k8s-manifests directory:
cd k8s-manifests && make k8s-deploy-manual

# Option 2: Deploy individual applications
make k8s-deploy-minio-manual
make k8s-deploy-postgresql-manual
```

**Note:** The k8s deployment targets are implemented in `k8s-manifests/Makefile`
and can be called from either the project root or the `k8s-manifests` directory.

---

## Prerequisites

### 1. Kubernetes Cluster

Deploy the cloud cluster first:

```bash
# Start VMs and deploy Kubernetes + ArgoCD
make cloud-cluster-start
make cloud-cluster-deploy

# Verify deployment
make cloud-cluster-status
```

### 2. Kubeconfig

The deployment automatically generates a kubeconfig file:

```bash
# Location: output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig
export KUBECONFIG="$(pwd)/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig"

# Verify access
kubectl get nodes
kubectl get namespaces
```

### 3. Required Tools

- `kubectl` (1.28+)
- `kustomize` (5.0+, or use `kubectl kustomize`)

---

## Deployment Methods

### Method 1: Using Makefile (Recommended)

#### Deploy All Applications

```bash
# Deploy MinIO + PostgreSQL directly to Kubernetes
make k8s-deploy-manual
```

This will:

1. Deploy MinIO to `mlops` namespace
2. Deploy PostgreSQL to `mlops` namespace
3. Create all required resources (PVCs, Services, Deployments, etc.)

#### Deploy Individual Applications

```bash
# Deploy only MinIO
make k8s-deploy-minio-manual

# Deploy only PostgreSQL
make k8s-deploy-postgresql-manual
```

### Method 2: Using kubectl directly

#### Deploy MinIO

```bash
# Set kubeconfig
export KUBECONFIG="output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig"

# Deploy with kustomize
kubectl apply -k k8s-manifests/base/mlops/minio

# Verify deployment
kubectl get all -n mlops -l app=minio
kubectl get pvc -n mlops
```

#### Deploy PostgreSQL

```bash
# Deploy with kustomize
kubectl apply -k k8s-manifests/base/mlops/postgresql

# Verify deployment
kubectl get all -n mlops -l app.kubernetes.io/name=postgresql
kubectl get pvc -n mlops
```

---

## Validation

### Check Deployment Status

```bash
# All resources in mlops namespace
kubectl get all -n mlops

# Check pods
kubectl get pods -n mlops

# Check services
kubectl get svc -n mlops

# Check persistent volumes
kubectl get pvc -n mlops
```

### Check MinIO

```bash
# Pod status
kubectl get pods -n mlops -l app=minio

# Service endpoints
kubectl get svc minio -n mlops

# Logs
kubectl logs -n mlops deployment/minio

# Port-forward to access UI
kubectl port-forward -n mlops svc/minio 9000:9000 9001:9001
# MinIO API: http://localhost:9000
# MinIO Console: http://localhost:9001
```

**Default Credentials:**

- Access Key: `minioadmin`
- Secret Key: `minioadmin123`

### Check PostgreSQL

```bash
# Pod status
kubectl get pods -n mlops -l app.kubernetes.io/name=postgresql

# Service endpoints
kubectl get svc postgresql -n mlops

# Logs
kubectl logs -n mlops statefulset/postgresql

# Test connection
kubectl exec -n mlops postgresql-0 -- \
  psql -U mlflow -d mlflow -c "SELECT version();"
```

---

## Manifest Structure

### What Gets Deployed

```text
k8s-manifests/base/mlops/
├── minio/
│   ├── namespace.yaml        # mlops namespace
│   ├── secret.yaml           # MinIO credentials
│   ├── pvc.yaml              # 100Gi storage
│   ├── deployment.yaml       # MinIO server
│   ├── service.yaml          # ClusterIP service (ports 9000, 9001)
│   ├── bucket-job.yaml       # Creates buckets: mlflow-artifacts, models, datasets
│   └── kustomization.yaml    # Kustomize configuration
│
└── postgresql/
    ├── secret.yaml           # PostgreSQL credentials
    ├── configmap.yaml        # PostgreSQL configuration
    ├── pvc.yaml              # 20Gi storage
    ├── statefulset.yaml      # PostgreSQL StatefulSet
    ├── service.yaml          # Headless + ClusterIP services
    └── kustomization.yaml    # Kustomize configuration
```

### Preview Manifests

Before deploying, preview what will be created:

```bash
# Validate and preview manifests
make k8s-validate-manifests

# Or manually
kubectl kustomize k8s-manifests/base/mlops/minio
kubectl kustomize k8s-manifests/base/mlops/postgresql
```

---

## Configuration

### Customize Resources

Edit the Kubernetes manifests directly:

```bash
# Example: Increase MinIO storage
vim k8s-manifests/base/mlops/minio/pvc.yaml
# Change: storage: 100Gi → storage: 200Gi

# Apply changes
kubectl apply -k k8s-manifests/base/mlops/minio
```

### Environment Variables

```yaml
# MinIO environment (deployment.yaml)
env:
  - name: MINIO_ROOT_USER
    valueFrom:
      secretKeyRef:
        name: minio-credentials
        key: accesskey
  - name: MINIO_ROOT_PASSWORD
    valueFrom:
      secretKeyRef:
        name: minio-credentials
        key: secretkey
```

### Resource Limits

```yaml
# MinIO resources (deployment.yaml)
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "2000m"
    memory: "4Gi"
```

---

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n mlops

# Describe pod to see events
kubectl describe pod -n mlops <pod-name>

# Check logs
kubectl logs -n mlops <pod-name>

# Common issues:
# 1. PVC not bound: Check storage class
kubectl get pvc -n mlops
kubectl get storageclass

# 2. Image pull errors: Check image name/tag
kubectl describe pod -n mlops <pod-name> | grep -A5 Events
```

### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n mlops

# Check PV
kubectl get pv

# Check storage class
kubectl get storageclass

# If using local-path provisioner
kubectl get pods -n local-path-storage
```

### Service Not Accessible

```bash
# Check service
kubectl get svc -n mlops <service-name>

# Check endpoints
kubectl get endpoints -n mlops <service-name>

# Test from within cluster
kubectl run -n mlops test-pod --image=curlimages/curl --rm -it -- \
  curl http://minio:9000/minio/health/live
```

### Cannot Connect to PostgreSQL

```bash
# Check PostgreSQL pod
kubectl get pods -n mlops -l app.kubernetes.io/name=postgresql

# Check logs
kubectl logs -n mlops postgresql-0

# Test connection
kubectl exec -n mlops postgresql-0 -- \
  psql -U mlflow -d mlflow -c "\dt"

# Check service
kubectl get svc -n mlops postgresql
```

---

## Cleanup

### Delete Applications

```bash
# Delete all manually deployed applications
kubectl delete -k k8s-manifests/base/mlops/minio
kubectl delete -k k8s-manifests/base/mlops/postgresql

# Or delete namespace (removes everything)
kubectl delete namespace mlops
```

### Delete PVCs

```bash
# PVCs are not deleted automatically
kubectl get pvc -n mlops
kubectl delete pvc -n mlops minio-storage
kubectl delete pvc -n mlops postgresql-storage
```

---

## Migrating to GitOps

If you initially deployed manually and want to switch to GitOps:

### Step 1: Delete Manual Deployments

```bash
# Remove manually deployed resources
kubectl delete -k k8s-manifests/base/mlops/minio
kubectl delete -k k8s-manifests/base/mlops/postgresql

# Keep PVCs if you want to preserve data
kubectl get pvc -n mlops
```

### Step 2: Configure Git Repository

```bash
# Update repository URLs in ArgoCD Applications
make gitops-update-repo-url GIT_REPO_URL=https://github.com/YOUR_ORG/ai-how

# Commit changes
git add k8s-manifests/argocd-apps/
git commit -m "Configure Git repository URLs"
git push
```

### Step 3: Deploy via GitOps

```bash
# Validate configuration
make gitops-validate

# Deploy via ArgoCD (App of Apps pattern)
make gitops-deploy-mlops-stack

# Check status
make gitops-status
```

---

## Comparison: Manual vs GitOps

| Aspect | Manual Deployment | GitOps Deployment |
|--------|------------------|-------------------|
| **Command** | `kubectl apply -k` | `kubectl apply -f argocd-apps/` |
| **State Management** | Manual | Automatic (Git) |
| **Drift Detection** | None | Automatic |
| **Rollback** | Manual `kubectl apply` | `git revert` |
| **Audit Trail** | kubectl history | Git commits |
| **Multi-Cluster** | Repeat per cluster | ArgoCD ApplicationSets |
| **Change Process** | Direct kubectl | Git commit + push |
| **Production Ready** | ❌ Not recommended | ✅ Best practice |

**Recommendation:** Use manual deployment only for:

- Local development
- Testing manifests
- Environments without Git access
- Quick prototyping

For production, always use GitOps.

---

## Advanced Usage

### Using Kustomize Overlays

Create environment-specific configurations:

```yaml
# k8s-manifests/overlays/dev/minio/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../../base/mlops/minio

namespace: mlops-dev

replicas:
  - name: minio
    count: 1

patches:
  - patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: 512Mi
    target:
      kind: Deployment
      name: minio
```

Deploy overlay:

```bash
kubectl apply -k k8s-manifests/overlays/dev/minio
```

### Dry Run

Test deployment without applying:

```bash
# Client-side dry run
kubectl apply -k k8s-manifests/base/mlops/minio --dry-run=client

# Server-side dry run (validates against cluster)
kubectl apply -k k8s-manifests/base/mlops/minio --dry-run=server
```

### Diff Before Apply

```bash
# Show what would change
kubectl diff -k k8s-manifests/base/mlops/minio
```

---

## References

- **GitOps Guide:** [quickstart-gitops.md](quickstart-gitops.md)
- **GitOps Workflow:** [../../docs/workflows/gitops-deployment-workflow.md](../../docs/workflows/gitops-deployment-workflow.md)
- **k8s-manifests README:** [../../k8s-manifests/README.md](../../k8s-manifests/README.md)
- **Kustomize Documentation:** https://kustomize.io/
- **kubectl Reference:** https://kubernetes.io/docs/reference/kubectl/

---

## Summary

**Quick Commands:**

```bash
# Manual deployment (bypasses GitOps)
make k8s-deploy-manual

# Individual apps
make k8s-deploy-minio-manual
make k8s-deploy-postgresql-manual

# Validate manifests
make k8s-validate-manifests

# Check status
kubectl get all -n mlops
```

**Key Points:**

- ✅ Use for testing and development
- ✅ Direct control with kubectl
- ✅ No Git repository required
- ⚠️ No drift detection
- ⚠️ No automatic sync
- ❌ Not recommended for production

**For Production:** Use GitOps deployment instead (`make gitops-deploy-mlops-stack`)
