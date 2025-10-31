# GitOps Quick Start Guide

**For:** Developers deploying to AI-HOW cloud cluster
**Tools:** ArgoCD, Kustomize, kubectl, Git
**Reference:** [ArgoCD Getting Started Guide](https://argo-cd.readthedocs.io/en/stable/getting_started/)

## TL;DR

```bash
# 1. Deploy complete cloud cluster (Kubernetes + ArgoCD + Apps)
ai-how cloud start config/cloud-cluster.yaml
make cloud-cluster-deploy

# 2. Change admin password immediately (security)
argocd account update-password

# 3. Configure Git repository URL (if not done before deployment)
vim k8s-manifests/argocd-apps/*.yaml  # Update repoURL

# 4. Make changes via Git
vim k8s-manifests/base/mlops/minio/deployment.yaml
git commit -am "Update MinIO config"
git push
# ArgoCD auto-syncs within 3 minutes
```

## Quick Access (Already Deployed?)

If ArgoCD is already deployed and you just need to access it:

```bash
# 1. Get admin password
export KUBECONFIG="output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# 2. Start port-forward (keep terminal open)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 3. Open browser: https://localhost:8080
# Login: admin / <password-from-step-1>

# 4. IMPORTANT: Change password immediately!
# User Info → Update Password (in Web UI)
```

See [Accessing ArgoCD](#accessing-argocd) section for CLI installation and more options.

---

## What is GitOps?

GitOps uses Git as the single source of truth for declarative infrastructure and applications. With ArgoCD:

- **Declare** your desired state in Git (YAML manifests)
- **Commit** changes to Git repository
- **Sync** automatically to Kubernetes cluster
- **Rollback** instantly with `git revert`

Learn more: [GitOps Principles](https://opengitops.dev/)

## Installation (One-Time Setup)

### Step 1: Deploy Infrastructure

```bash
# Provision VMs and Kubernetes cluster
ai-how cloud start config/cloud-cluster.yaml

# Verify cluster is ready
kubectl get nodes
```

### Step 2: Deploy Cloud Runtime with ArgoCD

The deployment follows the [official ArgoCD installation guide](https://argo-cd.readthedocs.io/en/stable/getting_started/):

```bash
# Deploy Kubernetes, ArgoCD, and GitOps applications
make cloud-cluster-deploy

# Or manually run Ansible playbook
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook \
  -i output/cluster-state/inventory.yml \
  ansible/playbooks/playbook-cloud-runtime.yml
```

**What gets deployed:**

1. Kubernetes cluster (via Kubespray)
2. ArgoCD (official manifest from stable branch)
3. Kubernetes Dashboard
4. MLOps applications (MinIO, Prometheus, etc.)

### Step 3: Get ArgoCD Access Credentials

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Or use argocd CLI
argocd admin initial-password -n argocd
```

### Step 4: Access ArgoCD UI

**Method 1: Port-Forward (Recommended)**

```bash
# Start port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open in browser: https://localhost:8080
# Login: admin / <password-from-step-3>
```

**Method 2: Ingress (if enabled)**

```bash
# Access via hostname (configured in deployment)
# http://argocd.cloud-cluster.local
```

### Step 5: Change Admin Password (IMPORTANT)

**Security requirement:** Change the default password immediately:

```bash
# Via CLI
argocd login localhost:8080 --username admin --password <initial-password> --insecure
argocd account update-password

# Then delete the initial secret
kubectl -n argocd delete secret argocd-initial-admin-secret
```

Or change via Web UI: **User Info → Update Password**

### Step 6: Configure Git Repository

Update ArgoCD Applications to point to your Git repository:

```bash
# Update repository URLs in application manifests
sed -i 's|https://github.com/your-org/ai-how|https://github.com/YOUR_ORG/ai-how|g' \
  k8s-manifests/argocd-apps/*.yaml

# Commit and push
git add k8s-manifests/argocd-apps/
git commit -m "Configure Git repository URLs"
git push
```

### Step 7: Verify Deployment

```bash
# Check ArgoCD applications
kubectl get applications -n argocd
argocd app list

# Check deployed resources
kubectl get all -n mlops
kubectl get all -n monitoring
```

---

## Accessing ArgoCD

### Quick Access via Port-Forward

The simplest way to access ArgoCD (recommended by official guide):

```bash
# Start port-forward (keep this terminal open)
export KUBECONFIG="output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig"
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open in browser: https://localhost:8080
# Accept self-signed certificate warning
```

**Login:**

- Username: `admin`
- Password: Get from secret (see Step 3 above)

### Install ArgoCD CLI

**Linux:**

```bash
# Download latest version
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# Install to /usr/local/bin
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Clean up
rm argocd-linux-amd64

# Verify installation
argocd version
```

**macOS:**

```bash
# Using Homebrew (recommended)
brew install argocd

# Or download binary
curl -sSL -o argocd-darwin-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
chmod +x argocd-darwin-amd64
sudo mv argocd-darwin-amd64 /usr/local/bin/argocd
```

**Windows (WSL):**

```bash
# Same as Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

### Using ArgoCD CLI

```bash
# 1. Start port-forward (in separate terminal)
export KUBECONFIG="output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig"
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 2. Login to ArgoCD
argocd login localhost:8080 \
  --username admin \
  --password <password-from-secret> \
  --insecure

# 3. Change password (REQUIRED)
argocd account update-password

# 4. List applications
argocd app list

# 5. Get application details
argocd app get <app-name>

# 6. Sync application
argocd app sync <app-name>

# 7. View diff before sync
argocd app diff <app-name>

# 8. List clusters
argocd cluster list

# 9. View logs
argocd app logs <app-name>
```

### Access via Ingress (Optional)

If you configured ingress during deployment:

```bash
# Check ingress configuration
kubectl get ingress -n argocd

# Access via configured hostname
# http://argocd.cloud-cluster.local (or your configured hostname)
```

**To configure ingress after installation:**

Edit `ansible/roles/argocd/defaults/main.yml`:

```yaml
argocd_ingress_enabled: true
argocd_ingress_host: argocd.example.com
argocd_ingress_tls_enabled: true
```

Then redeploy:

```bash
ansible-playbook ansible/playbooks/playbook-cloud-runtime.yml --tags argocd-ingress
```

---

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
| Documentation | `docs/workflows/gitops-deployment-workflow.md` |

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

- **Quick Start:** `docs/getting-started/quickstart-gitops.md`
- **Full Guide:** `docs/workflows/gitops-deployment-workflow.md`
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

This guide follows the
[official ArgoCD getting started guide](https://argo-cd.readthedocs.io/en/stable/getting_started/)
with project-specific customizations.

✅ **Deploy once:** Infrastructure + ArgoCD (simplified Ansible role)
✅ **Manage forever:** Applications via Git (GitOps workflow)
✅ **Auto-sync:** Changes applied within 3 minutes
✅ **Single source of truth:** Git repository
✅ **Rollback:** `git revert` = instant cluster rollback
✅ **Security:** Manual password change (not automated)

**Key Simplifications:**

- Direct application of official ArgoCD manifest (no custom parsing)
- Removed unnecessary health check pods
- Manual password configuration for security
- Block-structured Ansible tasks (reduced duplication)

**Official Resources:**

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [GitOps Principles](https://opengitops.dev/)

**Project Documentation:**

- Full workflow: `docs/workflows/gitops-deployment-workflow.md`
- ArgoCD role: `ansible/roles/argocd/README.md`
- Manifests guide: `k8s-manifests/README.md`

**Happy GitOps-ing! 🚀**
