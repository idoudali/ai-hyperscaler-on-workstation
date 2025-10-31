# Ansible Role: ArgoCD

Deploy ArgoCD on Kubernetes for GitOps-based continuous delivery.

## Overview

This role deploys ArgoCD following the
[official getting started guide](https://argo-cd.readthedocs.io/en/stable/getting_started/).
ArgoCD is a declarative GitOps continuous delivery tool that automatically syncs application
definitions from Git repositories to Kubernetes clusters.

**What this role does:**

1. Creates the `argocd` namespace
2. Applies the official ArgoCD installation manifest
3. Waits for all ArgoCD pods to be ready
4. Optionally creates an Ingress for external access
5. Displays access information and credentials

**What this role does NOT do:**

- Configure admin password (should be done manually for security)
- Auto-configure Git repositories (done via ArgoCD Applications)
- Modify ArgoCD settings beyond basic installation

## Requirements

- Kubernetes cluster running
- `kubernetes.core` Ansible collection installed
- kubectl configured with admin access to the cluster

## Role Variables

Available variables with defaults (see `defaults/main.yml`):

```yaml
# ArgoCD version
argocd_version: "v2.9.3"

# Namespace
argocd_namespace: argocd

# Installation manifest URL (official ArgoCD release)
argocd_install_manifest_url: "https://raw.githubusercontent.com/argoproj/argo-cd/{{ argocd_version }}/manifests/install.yaml"

# Ingress configuration (optional)
argocd_ingress_enabled: true
argocd_ingress_host: argocd.cloud-cluster.local
argocd_ingress_class: nginx
argocd_ingress_tls_enabled: false
argocd_ingress_tls_secret: argocd-server-tls

# Resource limits (see defaults/main.yml for details)
argocd_controller_resources: { ... }
argocd_server_resources: { ... }
argocd_repo_server_resources: { ... }

# Wait timeout for deployment
argocd_wait_timeout: 600  # seconds
```

## Dependencies

None

## Example Playbook

```yaml
---
- name: Deploy ArgoCD
  hosts: localhost
  gather_facts: false
  roles:
    - role: argocd
      vars:
        argocd_ingress_enabled: true
        argocd_ingress_host: argocd.example.com
```

## Deployment

### Full Deployment

```bash
# Deploy ArgoCD as part of cloud runtime
ansible-playbook ansible/playbooks/playbook-cloud-runtime.yml --tags argocd

# Or deploy ArgoCD only
ansible-playbook ansible/playbooks/playbook-cloud-runtime.yml --tags argocd
```

### Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n argocd

# Check services
kubectl get svc -n argocd

# Check ArgoCD applications (if any deployed)
kubectl get applications -n argocd
```

## Access ArgoCD

### Method 1: Port-Forward (Recommended for Quick Access)

The official guide recommends port-forwarding as the default access method:

```bash
# Start port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open in browser
# https://localhost:8080
```

### Method 2: Ingress (Production)

If `argocd_ingress_enabled: true` in your configuration:

```bash
# Access via configured hostname
# http://argocd.cloud-cluster.local (or your argocd_ingress_host)
```

### Login Credentials

**Username:** `admin`

**Password:** Auto-generated and displayed at end of deployment, or retrieve manually:

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Or use argocd CLI
argocd admin initial-password -n argocd
```

**⚠️ Important:** Delete the initial password secret after changing your password:

```bash
kubectl -n argocd delete secret argocd-initial-admin-secret
```

## ArgoCD CLI

### Install CLI

```bash
# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Or via Homebrew (Mac/Linux/WSL)
brew install argocd
```

### Login and Basic Commands

```bash
# Login (port-forward method)
argocd login localhost:8080 --username admin --password <password> --insecure

# Change admin password (IMPORTANT: do this immediately)
argocd account update-password

# List applications
argocd app list

# Get application status
argocd app get <app-name>

# Sync application
argocd app sync <app-name>

# View diff
argocd app diff <app-name>
```

## Post-Installation Steps

### 1. Change Admin Password

**Immediately change the default admin password:**

```bash
argocd account update-password
```

### 2. Deploy Applications via GitOps

Create ArgoCD Application manifests in your Git repository:

```yaml
# k8s-manifests/argocd-apps/minio-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: minio
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/ai-how
    targetRevision: HEAD
    path: k8s-manifests/base/mlops/minio
  destination:
    server: https://kubernetes.default.svc
    namespace: mlops
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Apply the application:

```bash
kubectl apply -f k8s-manifests/argocd-apps/minio-app.yaml
```

### 3. Configure Git Repository Access (if private)

```bash
# Via CLI
argocd repo add https://github.com/your-org/ai-how \
  --username <username> \
  --password <token>

# Or via UI: Settings → Repositories → Connect Repo
```

### 4. Optional: Configure SSO

See [ArgoCD User Management docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/)
for SSO configuration with:

- Google
- GitHub
- GitLab
- OIDC providers

## ArgoCD Architecture

```text
┌─────────────────────────────────────────────────────────┐
│                    ArgoCD Components                     │
├─────────────────────────────────────────────────────────┤
│  • API Server       - REST/gRPC API, Web UI             │
│  • Repository       - Git repository connectivity       │
│  • Controller       - Monitors apps and syncs state     │
│  • Application      - CRD defining app source/dest      │
│  • Dex              - Identity service (optional)       │
│  • Redis            - Caching                           │
└─────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n argocd

# Check specific pod logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

### Cannot Access UI

```bash
# Verify service exists
kubectl get svc -n argocd argocd-server

# Check ingress (if enabled)
kubectl get ingress -n argocd
kubectl describe ingress argocd-server -n argocd

# Use port-forward as fallback (always works)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Then open: https://localhost:8080
```

### Applications Not Syncing

```bash
# Check application status
kubectl get applications -n argocd
argocd app list

# Get detailed application info
argocd app get <app-name>
kubectl describe application <app-name> -n argocd

# View sync errors
argocd app diff <app-name>

# Check controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100

# Force sync
argocd app sync <app-name> --force
```

### Git Repository Connection Issues

```bash
# List configured repositories
argocd repo list

# Test repository connection
argocd repo get <repo-url>

# Check repo-server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

## Security Best Practices

### 1. Change Admin Password Immediately

```bash
# After first login
argocd account update-password

# Then delete the initial secret
kubectl -n argocd delete secret argocd-initial-admin-secret
```

### 2. Enable TLS/HTTPS

For production, enable TLS on ingress:

```yaml
# In your variables
argocd_ingress_tls_enabled: true
argocd_ingress_tls_secret: argocd-server-tls
```

Create TLS secret:

```bash
kubectl create secret tls argocd-server-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n argocd
```

### 3. Configure SSO (Recommended)

Integrate with identity providers:

- [Google](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/google/)
- [GitHub](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/github/)
- [GitLab](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/)
- [OIDC](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/)

### 4. Implement RBAC

Define projects and configure role-based access:

```yaml
# ArgoCD AppProject example
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  sourceRepos:
    - 'https://github.com/your-org/*'
  destinations:
    - namespace: 'prod-*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
```

### 5. Secure Git Credentials

Use SSH keys or Personal Access Tokens (PAT) instead of passwords:

```bash
# Add repository with SSH
argocd repo add git@github.com:your-org/repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# Add repository with HTTPS token
argocd repo add https://github.com/your-org/repo \
  --username git \
  --password <github-token>
```

## Performance Optimization

For large clusters or many applications:

```yaml
# In defaults/main.yml, increase resources
argocd_controller_resources:
  requests:
    cpu: "1000m"
    memory: "2Gi"
  limits:
    cpu: "4000m"
    memory: "8Gi"
```

See [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/) for more tuning options.

## References

- [ArgoCD Official Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Getting Started Guide](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [ArgoCD GitHub Repository](https://github.com/argoproj/argo-cd)
- [GitOps Principles](https://opengitops.dev/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- Project Documentation: `docs/workflows/gitops-deployment-workflow.md` and `docs/getting-started/quickstart-gitops.md`
