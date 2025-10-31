# Kubernetes Manifests

GitOps-managed Kubernetes resources for the AI-HOW cloud cluster.

## Structure

```text
k8s-manifests/
├── base/                       # Base configurations
│   ├── mlops/
│   │   ├── minio/             # MinIO object storage
│   │   └── postgresql/        # PostgreSQL database
│   ├── gpu-operator/          # NVIDIA GPU Operator (TODO)
│   └── monitoring/            # Prometheus/Grafana (TODO)
├── overlays/                   # Environment-specific
│   ├── dev/                   # Development overrides
│   └── prod/                  # Production overrides
└── argocd-apps/               # ArgoCD Application definitions
    ├── minio-app.yaml
    ├── postgresql-app.yaml
    └── mlops-stack-app.yaml   # App of Apps
```

## Base Manifests

Base manifests contain the common configuration for all environments.

### MinIO (`base/mlops/minio/`)

S3-compatible object storage for ML artifacts.

**Resources:**

- Namespace: `mlops`
- Deployment: `minio`
- Service: `minio` (ClusterIP)
- PVC: `minio-storage` (100Gi)
- Secret: `minio-credentials`
- Job: `minio-create-buckets`

**Buckets Created:**

- `mlflow-artifacts`
- `models`
- `datasets`
- `experiments`

### PostgreSQL (`base/mlops/postgresql/`)

Database for MLflow metadata.

**Resources:**

- StatefulSet: `postgresql`
- Service: `postgresql` (headless), `postgresql-external` (ClusterIP)
- PVC: `postgresql-storage` (20Gi)
- Secret: `postgresql-credentials`
- ConfigMap: `postgresql-config`, `postgresql-init-scripts`

## ArgoCD Applications

ArgoCD Application definitions connect Git manifests to Kubernetes clusters.

### Deploying Applications

**Option 1: Individual Applications**

```bash
kubectl apply -f argocd-apps/minio-app.yaml
kubectl apply -f argocd-apps/postgresql-app.yaml
```

**Option 2: App of Apps (Recommended)**

```bash
kubectl apply -f argocd-apps/mlops-stack-app.yaml
```

This deploys all child applications automatically.

### Before Deploying

**Update Git Repository URL:**

Edit all `*-app.yaml` files and replace:

```yaml
spec:
  source:
    repoURL: https://github.com/your-org/ai-how  # Change this!
```

## Understanding kubectl and YAML Processing

For detailed information about how kubectl works internally and how YAML files are parsed and processed, see:

**[How kubectl Works Tutorial](../docs/tutorials/kubernetes/02-how-kubectl-works.md)**

This tutorial covers:

- How kubectl processes YAML files step-by-step
- YAML file structure and organization
- How kubectl commands work internally
- How Kustomize processes manifests
- API server interaction and controller workflows

## Kustomize

All base manifests use Kustomize for configuration management.

### Building Manifests

```bash
# Build MinIO manifests
kubectl kustomize k8s-manifests/base/mlops/minio

# Build PostgreSQL manifests
kubectl kustomize k8s-manifests/base/mlops/postgresql

# Apply directly
kubectl apply -k k8s-manifests/base/mlops/minio
```

### Creating Overlays

Overlays allow environment-specific customizations without modifying base manifests.

**Example: Dev Overlay**

```yaml
# overlays/dev/mlops/minio/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../../../base/mlops/minio

namespace: mlops-dev

patchesStrategicMerge:
  - patches.yaml

replicas:
  - name: minio
    count: 1

resources:
  requests:
    cpu: "250m"
    memory: "512Mi"
```

## Git Workflow

### Making Changes

1. **Edit manifests** in `base/` or `overlays/`
2. **Test locally** with `kubectl kustomize`
3. **Commit and push** to Git
4. **ArgoCD syncs** automatically

```bash
# Example: Update MinIO storage
vim base/mlops/minio/pvc.yaml
# Change storage size

git add base/mlops/minio/pvc.yaml
git commit -m "Increase MinIO storage to 200Gi"
git push

# ArgoCD syncs within ~3 minutes
```

### Adding New Applications

**Step 1: Create base manifests**

```bash
mkdir -p base/mlops/mlflow
cd base/mlops/mlflow

# Create deployment, service, etc.
# Create kustomization.yaml
```

**Step 2: Create ArgoCD Application**

```bash
cat > argocd-apps/mlflow-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mlflow
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/ai-how
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
```

**Step 3: Commit and push**

```bash
git add base/mlops/mlflow argocd-apps/mlflow-app.yaml
git commit -m "Add MLflow application"
git push
```

## Secrets Management

**⚠️ NEVER commit plain secrets to Git!**

### Recommended Approaches

**1. Sealed Secrets (Recommended)**

```bash
# Encrypt secret
kubectl create secret generic minio-credentials \
  --from-literal=accesskey=admin \
  --from-literal=secretkey=SecurePassword123! \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > base/mlops/minio/sealed-secret.yaml

# Safe to commit
git add base/mlops/minio/sealed-secret.yaml
git commit -m "Add MinIO sealed secret"
git push
```

**2. External Secrets Operator**

```yaml
# Create ExternalSecret resource
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: minio-credentials
  namespace: mlops
spec:
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: minio-credentials
  data:
    - secretKey: accesskey
      remoteRef:
        key: minio/credentials
        property: accesskey
```

**3. SOPS Encryption**

```bash
# Encrypt with SOPS
sops --encrypt --age <public-key> \
  base/mlops/minio/secret.yaml > \
  base/mlops/minio/secret.enc.yaml
```

## Validation

### Linting

```bash
# Lint manifests with kubeval
kubeval base/mlops/minio/*.yaml

# Lint with kustomize
kubectl kustomize base/mlops/minio > /tmp/output.yaml
kubeval /tmp/output.yaml
```

### Dry Run

```bash
# Test apply without actually applying
kubectl apply -k base/mlops/minio --dry-run=client
kubectl apply -k base/mlops/minio --dry-run=server
```

### Kustomize Build

```bash
# Build and inspect
kubectl kustomize base/mlops/minio | less

# Check for errors
kubectl kustomize base/mlops/minio > /tmp/test.yaml
```

## Troubleshooting

### Kustomize Build Fails

```bash
# Check kustomization.yaml syntax
kubectl kustomize base/mlops/minio

# Validate resource files
for f in base/mlops/minio/*.yaml; do
  echo "Checking $f..."
  kubectl apply -f $f --dry-run=client
done
```

### ArgoCD Not Syncing

```bash
# Check Application status
kubectl describe application minio -n argocd

# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Manual sync
argocd app sync minio --force
```

### Resource Not Deploying

```bash
# Check ArgoCD Application
kubectl get application minio -n argocd -o yaml

# Check deployed resources
kubectl get all -n mlops -l app.kubernetes.io/instance=minio

# View events
kubectl get events -n mlops --sort-by='.lastTimestamp'
```

## Best Practices

1. **Use Kustomize bases and overlays** for environment management
2. **Never commit plain secrets** - use Sealed Secrets or External Secrets
3. **Test locally** before pushing to Git
4. **Use meaningful commit messages** - they appear in ArgoCD UI
5. **Keep manifests DRY** - use Kustomize features to avoid duplication
6. **Version images** - don't use `latest` tag
7. **Set resource limits** - always define requests and limits
8. **Use labels** - consistent labeling for all resources

## How Manifests Are Applied

There are two ways to deploy Kubernetes manifests:

### Method 1: GitOps (ArgoCD) - Production

**Workflow:**

1. Apply ArgoCD Application manifest → Creates GitOps connection
2. ArgoCD watches Git repository → Detects changes
3. ArgoCD builds manifests with Kustomize → Processes `kustomization.yaml`
4. ArgoCD applies to cluster → Creates/updates resources
5. Auto-sync every ~3 minutes → Keeps cluster in sync with Git

**Commands:**

```bash
# Deploy via GitOps (recommended for production)
kubectl apply -f argocd-apps/mlops-stack-app.yaml
```

**See:** [GitOps Quick Start](../docs/getting-started/quickstart-gitops.md)

### Method 2: Manual (kubectl) - Testing/Development

**Workflow:**

1. Build manifests with Kustomize → `kubectl kustomize`
2. Apply directly with kubectl → `kubectl apply -k`
3. No GitOps sync → Manual management only

**Commands:**

```bash
# Deploy all applications manually (bypasses GitOps)
make k8s-deploy-manual

# Or deploy individually
make k8s-deploy-minio-manual
make k8s-deploy-postgresql-manual

# Or use kubectl directly
kubectl apply -k k8s-manifests/base/mlops/minio
kubectl apply -k k8s-manifests/base/mlops/postgresql
```

**See:** [Manual Deployment Guide](../docs/getting-started/manual-k8s-deployment.md) for complete instructions.

### When to Use Each Method

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **GitOps (ArgoCD)** | Production, CI/CD | Auto-sync, drift detection, audit trail | Requires Git access |
| **Manual (kubectl)** | Testing, development, quick prototyping | Direct control, no Git needed | No drift detection, manual management |

## References

- **Manual Deployment Guide:** [docs/getting-started/manual-k8s-deployment.md](../docs/getting-started/manual-k8s-deployment.md)
- **GitOps Quick Start:** [docs/getting-started/quickstart-gitops.md](../docs/getting-started/quickstart-gitops.md)
- **GitOps Workflow:** [docs/workflows/gitops-deployment-workflow.md](../docs/workflows/gitops-deployment-workflow.md)
- **Kustomize Documentation:** https://kustomize.io/
- **ArgoCD Applications:** https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications
- **Sealed Secrets:** https://github.com/bitnami-labs/sealed-secrets
- **External Secrets:** https://external-secrets.io/

## Deployment Status

| Component | Status | Kustomize Manifest | ArgoCD App |
|-----------|--------|-------------------|------------|
| MinIO | ✅ Complete | `base/mlops/minio` | `argocd-apps/minio-app.yaml` |
| PostgreSQL | ✅ Complete | `base/mlops/postgresql` | `argocd-apps/postgresql-app.yaml` |
| MLflow | ⏳ TODO | TBD | TBD |
| GPU Operator | ⏳ TODO | TBD | TBD |
| KServe | ⏳ TODO | TBD | TBD |
| Monitoring | ⏳ TODO | TBD | TBD |

**Note:** All applications are deployed via GitOps using ArgoCD. Ansible is used only for infrastructure setup.
