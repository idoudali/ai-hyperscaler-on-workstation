# ArgoCD Access Guide

**Quick Reference:** How to access and use ArgoCD on your AI-HOW cluster

## Prerequisites

- ArgoCD deployed on cluster (via `make cloud-cluster-deploy`)
- KUBECONFIG set or using absolute path
- Network access to cluster

---

## Quick Access (3 Steps)

### 1. Get Admin Password

```bash
export KUBECONFIG="output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig"

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Or use shorter command:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

### 2. Start Port-Forward

```bash
# Keep this terminal open
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 3. Access Web UI

Open browser: **https://localhost:8080**

- Username: `admin`
- Password: _(from step 1)_
- Accept self-signed certificate warning

**⚠️ IMPORTANT:** Change password immediately after first login!

- Click **User Info** → **Update Password**

---

## Install ArgoCD CLI

### Linux / WSL

```bash
# Download latest version
curl -sSL -o argocd-linux-amd64 \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# Install to /usr/local/bin
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Clean up
rm argocd-linux-amd64

# Verify
argocd version
```

### macOS

```bash
# Using Homebrew (recommended)
brew install argocd

# Verify
argocd version
```

### Windows (PowerShell)

```powershell
# Download
$version = (Invoke-RestMethod https://api.github.com/repos/argoproj/argo-cd/releases/latest).tag_name
$url = "https://github.com/argoproj/argo-cd/releases/download/" + $version + "/argocd-windows-amd64.exe"
$output = "$PSScriptRoot\argocd.exe"

Invoke-WebRequest -Uri $url -OutFile $output

# Add to PATH or move to a directory in PATH
```

---

## Using ArgoCD CLI

### Login

```bash
# Start port-forward first (in separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login
argocd login localhost:8080 \
  --username admin \
  --password <password-from-secret> \
  --insecure

# Change password (REQUIRED)
argocd account update-password
```

### Common Commands

```bash
# List applications
argocd app list

# Get application details
argocd app get <app-name>

# Sync application (deploy changes)
argocd app sync <app-name>

# View diff before syncing
argocd app diff <app-name>

# Sync all applications
argocd app sync --all

# Watch sync status
argocd app sync <app-name> --watch

# View application logs
argocd app logs <app-name>

# Rollback to previous version
argocd app rollback <app-name>

# Delete application
argocd app delete <app-name>

# List repositories
argocd repo list

# Add repository
argocd repo add https://github.com/your-org/repo \
  --username <username> \
  --password <token>

# List clusters
argocd cluster list

# Get server info
argocd version
```

### Application Management

```bash
# Create application from CLI
argocd app create <app-name> \
  --repo https://github.com/your-org/repo \
  --path k8s-manifests/base/mlops/minio \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace mlops

# Enable auto-sync
argocd app set <app-name> --sync-policy automated

# Enable auto-prune
argocd app set <app-name> --auto-prune

# Enable self-heal
argocd app set <app-name> --self-heal

# View application history
argocd app history <app-name>

# Rollback to specific revision
argocd app rollback <app-name> <revision-id>
```

---

## Alternative Access Methods

### Via Ingress (if configured)

If ingress is enabled in your deployment:

```bash
# Check ingress
kubectl get ingress -n argocd

# Access via hostname
# http://argocd.cloud-cluster.local (or your configured hostname)
```

### Via NodePort (not recommended for production)

```bash
# Change service type to NodePort
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "NodePort"}}'

# Get NodePort
kubectl get svc argocd-server -n argocd

# Access via http://<node-ip>:<node-port>
```

### Via LoadBalancer (cloud environments)

```bash
# Change service type to LoadBalancer
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Get external IP
kubectl get svc argocd-server -n argocd

# Access via http://<external-ip>
```

---

## Troubleshooting

### Cannot Connect to ArgoCD

```bash
# Check pods are running
kubectl get pods -n argocd

# Check specific pod logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Check service
kubectl get svc argocd-server -n argocd

# Verify port-forward is running
lsof -i :8080
```

### Forgot Admin Password

```bash
# Reset to initial password (if secret still exists)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Or regenerate (deletes all ArgoCD data!)
kubectl delete secret argocd-secret -n argocd
kubectl rollout restart deployment argocd-server -n argocd
```

### CLI Login Issues

```bash
# Clear CLI cache
rm -rf ~/.argocd/

# Login with verbose output
argocd login localhost:8080 --username admin --grpc-web --insecure

# Use port-forward URL explicitly
argocd login 127.0.0.1:8080 --username admin --insecure
```

### Application Not Syncing

```bash
# Check application health
argocd app get <app-name>

# View sync status
argocd app diff <app-name>

# Force sync
argocd app sync <app-name> --force

# Check ArgoCD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Check repo-server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

---

## Security Best Practices

### 1. Change Admin Password

```bash
argocd account update-password

# Then delete initial secret
kubectl delete secret argocd-initial-admin-secret -n argocd
```

### 2. Enable SSO (Production)

Configure SSO with your identity provider:

- See: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/

### 3. Configure RBAC

Create ArgoCD Projects with limited permissions:

- See: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/

### 4. Use SSH Keys for Git

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -C "argocd@your-org.com"

# Add to ArgoCD
argocd repo add git@github.com:your-org/repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

---

## Environment Variables

Set these for convenience:

```bash
# Add to ~/.bashrc or ~/.zshrc
export KUBECONFIG="$HOME/Projects/pharos.ai-hyperscaler-on-workskation/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig"
export ARGOCD_SERVER="localhost:8080"
export ARGOCD_OPTS="--insecure --grpc-web"

# Reload shell
source ~/.bashrc
```

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Get password | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` |
| Port-forward | `kubectl port-forward svc/argocd-server -n argocd 8080:443` |
| Login CLI | `argocd login localhost:8080 --username admin --insecure` |
| List apps | `argocd app list` |
| Sync app | `argocd app sync <app-name>` |
| View diff | `argocd app diff <app-name>` |
| App logs | `argocd app logs <app-name>` |
| Rollback | `argocd app rollback <app-name>` |
| Add repo | `argocd repo add <url> --username <user> --password <token>` |
| Change password | `argocd account update-password` |

---

## Documentation Links

- **ArgoCD Official Docs:** https://argo-cd.readthedocs.io/
- **Getting Started Guide:** https://argo-cd.readthedocs.io/en/stable/getting_started/
- **Project Quick Start:** `docs/getting-started/quickstart-gitops.md`
- **Full GitOps Workflow:** `docs/workflows/gitops-deployment-workflow.md`
- **Ansible Role README:** `ansible/roles/argocd/README.md`

---

## Support

For project-specific issues:

- Check logs: `kubectl logs -n argocd <pod-name>`
- View events: `kubectl get events -n argocd --sort-by='.lastTimestamp'`
- Consult documentation in `docs/` directory
