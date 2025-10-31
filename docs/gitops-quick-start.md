# GitOps Quick Start Guide

**For:** Developers deploying to AI-HOW cloud cluster
**Tools:** ArgoCD, Kustomize, kubectl, Git

## TL;DR

```bash
# 1. Deploy complete cloud cluster (Kubernetes + ArgoCD + Apps)
ai-how cloud start config/cloud-cluster.yaml
make cloud-cluster-deploy

# 2. Configure Git repository URL (if not done before deployment)
vim k8s-manifests/argocd-apps/*.yaml  # Update repoURL

# 4. Make changes via Git
vim k8s-manifests/base/mlops/minio/deployment.yaml
git commit -am "Update MinIO config"
git push
# ArgoCD auto-syncs within 3 minutes
```

## Installation (One-Time Setup)

### Step 1: Deploy Infrastructure

```bash
# Provision VMs and Kubernetes cluster
ai-how cloud start config/cloud-cluster.yaml

# Verify cluster
kubectl get nodes
```

### Step 2: Deploy Complete Cloud Runtime

```bash
# Deploy Kubernetes, ArgoCD, and GitOps applications
make cloud-cluster-deploy

# Or manually with specific tags
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook \
  -i output/cluster-state/inventory.yml \
  ansible/playbooks/playbook-cloud-runtime.yml

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Access UI (optional)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
```

### Step 3: Configure Git Repository

```bash
# Update Git URLs in ArgoCD Applications
sed -i 's|https://github.com/your-org/ai-how|https://github.com/YOUR_ORG/ai-how|g' \
  k8s-manifests/argocd-apps/*.yaml

# Commit and push
git add k8s-manifests/argocd-apps/
git commit -m "Configure Git repository URLs"
git push
```

### Step 4: Verify Deployment

```bash
# Check applications (already deployed by playbook-cloud-runtime.yml)
kubectl get applications -n argocd
kubectl get all -n mlops

# Or redeploy just GitOps apps using tags
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook \
  -i output/cluster-state/inventory.yml \
  ansible/playbooks/playbook-cloud-runtime.yml \
  --tags gitops-apps
```

## Daily Workflow

### Deploy New Application

```bash
# 1. Create Kustomize manifests
mkdir -p k8s-manifests/base/mlops/mlflow
# Add YAML files

# 2. Create kustomization.yaml
cat > k8s-manifests/base/mlops/mlflow/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: mlops
resources:
  - deployment.yaml
  - service.yaml
EOF

# 3. Create ArgoCD Application
cat > k8s-manifests/argocd-apps/mlflow-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mlflow
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/ai-how
    targetRevision: HEAD
    path: k8s-manifests/base/mlops/mlflow
  destination:
    server: https://kubernetes.default.svc
    namespace: mlops
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# 4. Commit and push
git add k8s-manifests/
git commit -m "Add MLflow application"
git push

# ArgoCD auto-deploys
```

### Update Existing Application

```bash
# 1. Edit manifest
vim k8s-manifests/base/mlops/minio/deployment.yaml
# Make changes

# 2. Commit and push
git add k8s-manifests/base/mlops/minio/deployment.yaml
git commit -m "Update MinIO replicas to 3"
git push

# 3. Wait for ArgoCD auto-sync (or force sync)
argocd app sync minio
```

### Scale Application

```bash
# Edit deployment
vim k8s-manifests/base/mlops/minio/deployment.yaml
# Change: replicas: 1 → replicas: 3

git commit -am "Scale MinIO to 3 replicas"
git push
```

### Update Image Version

```bash
# Edit kustomization.yaml
vim k8s-manifests/base/mlops/minio/kustomization.yaml
# Change newTag

git commit -am "Update MinIO to latest version"
git push
```

## ArgoCD Commands

### Installation

```bash
# Install CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd /usr/local/bin/argocd

# Login
argocd login localhost:8080 --username admin --password <password> --insecure
```

### Common Operations

```bash
# List applications
argocd app list

# Get application details
argocd app get minio

# Sync application
argocd app sync minio

# View diff
argocd app diff minio

# Rollback to previous version
argocd app rollback minio

# Delete application
argocd app delete minio
```

## Kubectl Commands

```bash
# View ArgoCD applications
kubectl get applications -n argocd

# View application status
kubectl describe application minio -n argocd

# View deployed resources
kubectl get all -n mlops

# Check pods
kubectl get pods -n mlops

# View logs
kubectl logs -n mlops deployment/minio

# Port-forward to service
kubectl port-forward -n mlops svc/minio 9000:9000
```

## Troubleshooting

### Application OutOfSync

```bash
# View diff
argocd app diff minio

# Manual sync
argocd app sync minio --force

# Check for manual changes
kubectl get deployment minio -n mlops -o yaml | grep -A5 annotations
```

### Application Unhealthy

```bash
# Check pods
kubectl get pods -n mlops -l app=minio

# View events
kubectl get events -n mlops --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n mlops deployment/minio
```

### Sync Failed

```bash
# View sync status
argocd app get minio

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Force sync with prune
argocd app sync minio --force --prune
```

## Common Tasks Cheat Sheet

| Task | Command |
|------|---------|
| List apps | `argocd app list` |
| App status | `argocd app get <app>` |
| Sync app | `argocd app sync <app>` |
| Force sync | `argocd app sync <app> --force` |
| View diff | `argocd app diff <app>` |
| App logs | `argocd app logs <app>` |
| Rollback | `argocd app rollback <app>` |
| Delete app | `argocd app delete <app>` |
| Port-forward | `kubectl port-forward svc/argocd-server -n argocd 8080:443` |
| Get password | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` |

## File Locations

| Component | Location |
|-----------|----------|
| Base manifests | `k8s-manifests/base/mlops/*/` |
| ArgoCD apps | `k8s-manifests/argocd-apps/` |
| Overlays | `k8s-manifests/overlays/*/` |
| ArgoCD role | `ansible/roles/argocd/` |
| Deployment playbooks | `ansible/playbooks/deploy-*.yml` |
| Documentation | `docs/gitops-workflow.md` |

## Security Best Practices

```bash
# NEVER commit plain secrets
git add base/mlops/minio/secret.yaml  # ❌ DON'T DO THIS

# Use Sealed Secrets instead
kubectl create secret generic minio-credentials \
  --from-literal=accesskey=admin \
  --from-literal=secretkey=SecurePass123! \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > base/mlops/minio/sealed-secret.yaml

git add base/mlops/minio/sealed-secret.yaml  # ✅ Safe to commit
```

## Resources

- **Full Guide:** `docs/gitops-workflow.md`
- **k8s-manifests README:** `k8s-manifests/README.md`
- **ArgoCD Apps README:** `k8s-manifests/argocd-apps/README.md`
- **ArgoCD Docs:** https://argo-cd.readthedocs.io/
- **Kustomize Docs:** https://kustomize.io/

## Getting Help

```bash
# ArgoCD CLI help
argocd --help
argocd app --help

# Kubectl help
kubectl explain application
kubectl explain application.spec

# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-application-controller
```

## Summary

✅ **Deploy once:** Infrastructure + ArgoCD (Ansible)
✅ **Manage forever:** Applications via Git
✅ **Auto-sync:** Changes applied within 3 minutes
✅ **Single source of truth:** Git repository
✅ **Rollback:** Git revert = cluster rollback

**Happy GitOps-ing! 🚀**
