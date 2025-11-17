# Phase 3: MLOps Stack Deployment

**Duration:** 2 weeks
**Tasks:** CLOUD-3.1, CLOUD-3.2, CLOUD-3.3, CLOUD-3.4
**Dependencies:** Phase 2 (Kubernetes)

## Overview

Deploy the complete MLOps stack for model management, experiment tracking, and inference serving. This phase establishes
the infrastructure needed for Oumi model deployment and serving.

**Stack Components:**

- MinIO: Object storage for models and artifacts
- PostgreSQL: Metadata storage for MLflow
- MLflow: Experiment tracking and model registry
- KServe: Scalable model inference serving

---

## CLOUD-3.1: Deploy MinIO Object Storage

**Duration:** 2-3 days
**Priority:** HIGH
**Status:** ✅ **Completed**
**Dependencies:** CLOUD-2.1

### Objective

Deploy MinIO as S3-compatible object storage for model artifacts, datasets, and MLflow artifacts.

**Implementation:** GitOps-based deployment using ArgoCD and Kustomize manifests.

### Manifest Structure

**Kustomize-based manifests in `k8s-manifests/base/mlops/minio/`:**

```text
k8s-manifests/base/mlops/minio/
├── namespace.yaml              # mlops namespace
├── secret.yaml                 # MinIO credentials
├── pvc.yaml                    # 100Gi storage (local-path)
├── deployment.yaml             # MinIO server
├── service.yaml                # ClusterIP service (ports 9000, 9001)
├── bucket-job.yaml             # Post-install bucket creation job
└── kustomization.yaml          # Kustomize configuration
```

**ArgoCD Application in `k8s-manifests/argocd-apps/`:**

```text
k8s-manifests/argocd-apps/
├── minio-app.yaml              # MinIO Application definition
├── postgresql-app.yaml         # PostgreSQL Application definition
└── mlops-stack-app.yaml        # App of Apps (parent application)
```

### Configuration

**MinIO deployment configuration:**

```yaml
# From k8s-manifests/base/mlops/minio/deployment.yaml
namespace: mlops
image: quay.io/minio/minio:RELEASE.2024-10-02T17-50-41Z
replicas: 1
storage: 100Gi (local-path storage class)
credentials: minioadmin/minioadmin123

# Ports
api: 9000
console: 9001

# Buckets created automatically
- mlflow-artifacts
- models
- datasets
- experiments
```

### Implementation Details

**GitOps Workflow:**

1. **Kustomize manifests** define MinIO resources
2. **ArgoCD Application** monitors Git repository
3. **Auto-sync** applies changes within 3 minutes
4. **Self-healing** reverts manual cluster changes

**Deployment Methods:**

```bash
# Method 1: GitOps (Production - Recommended)
make gitops-deploy-mlops-stack    # Deploys all MLOps apps
# Or individually:
make gitops-deploy-minio

# Method 2: Manual (Testing/Development)
make k8s-deploy-minio-manual
```

### Deliverables

- [x] MinIO Kustomize manifests (`k8s-manifests/base/mlops/minio/`)
- [x] ArgoCD Application definition (`k8s-manifests/argocd-apps/minio-app.yaml`)
- [x] Persistent storage configuration (local-path provisioner)
- [x] Automatic bucket creation (post-install Job)
- [x] Service configuration (API + Console)
- [x] GitOps deployment workflow
- [x] Manual deployment workflow (for testing)
- [x] Documentation (GitOps guides, kubectl tutorial)
- [x] Makefile targets for deployment and validation
- [x] Port-forwarding helpers

### Validation

```bash
# Check MinIO deployment
kubectl get pods -n mlops -l app=minio
kubectl get svc -n mlops minio
kubectl get pvc -n mlops minio-storage

# Check ArgoCD Application status
kubectl get application minio -n argocd
make gitops-status

# Access MinIO Console (port-forward)
make port-forward-minio
# Open http://localhost:9001
# Credentials: make minio-credentials

# Check buckets (after deployment)
kubectl logs -n mlops job/minio-create-buckets
```

### Documentation

**Created:**

- `docs/getting-started/quickstart-gitops.md` - GitOps quick start
- `docs/gitops-workflow.md` - Complete GitOps workflow guide
- `docs/getting-started/manual-k8s-deployment.md` - Manual deployment guide
- `docs/tutorials/kubernetes/02-how-kubectl-works.md` - kubectl and YAML processing
- `k8s-manifests/README.md` - Kubernetes manifests overview
- `k8s-manifests/argocd-apps/README.md` - ArgoCD Applications guide

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-009`

---

## CLOUD-3.2: Deploy PostgreSQL Database

**Duration:** 2 days
**Priority:** HIGH
**Status:** ✅ **Completed**
**Dependencies:** CLOUD-2.1

### Objective

Deploy PostgreSQL as the backend database for MLflow metadata storage.

**Implementation:** GitOps-based deployment using ArgoCD and Kustomize manifests.

### Manifest Structure

**Kustomize-based manifests in `k8s-manifests/base/mlops/postgresql/`:**

```text
k8s-manifests/base/mlops/postgresql/
├── secret.yaml                 # PostgreSQL credentials
├── configmap.yaml              # PostgreSQL configuration + init scripts
├── pvc.yaml                    # 20Gi storage (local-path)
├── statefulset.yaml            # PostgreSQL StatefulSet
├── service.yaml                # Headless + ClusterIP services
└── kustomization.yaml          # Kustomize configuration
```

**ArgoCD Application:**

- `k8s-manifests/argocd-apps/postgresql-app.yaml` - PostgreSQL Application definition
- Included in `mlops-stack-app.yaml` (App of Apps)

### Configuration

**PostgreSQL deployment configuration:**

```yaml
# From k8s-manifests/base/mlops/postgresql/statefulset.yaml
namespace: mlops
image: postgres:15.4
replicas: 1 (StatefulSet)
storage: 20Gi (local-path storage class)

# Credentials (from secret)
database: mlflow
user: mlflow
password: mlflow_secure_password

# Configuration (from configmap)
max_connections: 100
shared_buffers: 256MB
effective_cache_size: 1GB
work_mem: 4MB

# Services
- postgresql (headless for StatefulSet)
- postgresql-external (ClusterIP for external access)
```

**Init Scripts:**

- `01-create-extensions.sql` - Creates PostgreSQL extensions (uuid-ossp, pg_stat_statements)
- `02-mlflow-schema.sql` - Grants permissions (MLflow creates schema automatically)

### Implementation Details

**GitOps Workflow:**

1. **Kustomize manifests** define PostgreSQL resources
2. **ArgoCD Application** monitors Git repository
3. **Auto-sync** applies changes within 3 minutes
4. **StatefulSet** provides stable network identity and persistent storage

**Deployment Methods:**

```bash
# Method 1: GitOps (Production - Recommended)
make gitops-deploy-mlops-stack    # Deploys all MLOps apps
# Or individually:
make gitops-deploy-postgresql

# Method 2: Manual (Testing/Development)
make k8s-deploy-postgresql-manual
```

### Deliverables

- [x] PostgreSQL Kustomize manifests (`k8s-manifests/base/mlops/postgresql/`)
- [x] ArgoCD Application definition (`k8s-manifests/argocd-apps/postgresql-app.yaml`)
- [x] StatefulSet for stable identity and storage
- [x] Persistent storage configuration (local-path provisioner)
- [x] MLflow database initialization scripts
- [x] Service configuration (headless + ClusterIP)
- [x] PostgreSQL configuration via ConfigMap
- [x] GitOps deployment workflow
- [x] Manual deployment workflow (for testing)
- [x] Documentation and validation helpers

### Validation

```bash
# Check PostgreSQL deployment
kubectl get pods -n mlops -l app.kubernetes.io/name=postgresql
kubectl get statefulset -n mlops postgresql
kubectl get svc -n mlops postgresql
kubectl get pvc -n mlops postgresql-storage

# Check ArgoCD Application status
kubectl get application postgresql -n argocd
make gitops-status

# Test database connection
kubectl exec -n mlops postgresql-0 -- \
  psql -U mlflow -d mlflow -c "SELECT version();"

# Verify extensions
kubectl exec -n mlops postgresql-0 -- \
  psql -U mlflow -d mlflow -c "\dx"

# Check connection string
kubectl get secret postgresql-credentials -n mlops -o jsonpath='{.data.connection-string}' | base64 -d
```

### Success Criteria

- [x] PostgreSQL StatefulSet deployed successfully
- [x] Persistent storage bound and accessible
- [x] Database initialized with MLflow schema
- [x] Extensions created (uuid-ossp, pg_stat_statements)
- [x] Services accessible (headless + ClusterIP)
- [x] ArgoCD Application synced and healthy
- [x] Documentation and validation helpers available

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-010`

---

## CLOUD-3.3: Deploy MLflow Tracking Server

**Duration:** 3-4 days
**Priority:** HIGH
**Status:** ✅ **Completed**
**Dependencies:** CLOUD-3.1, CLOUD-3.2

### Objective

Deploy MLflow tracking server for experiment tracking, model registry, and model versioning.

**Implementation:** GitOps-based deployment using ArgoCD and Kustomize manifests.

### Manifest Structure

**Kustomize-based manifests in `k8s-manifests/base/mlops/mlflow/`:**

```text
k8s-manifests/base/mlops/mlflow/
├── secret.yaml                 # MLflow credentials (backend URI, S3 credentials)
├── deployment.yaml              # MLflow server deployment
├── service.yaml                 # ClusterIP service (port 5000)
├── ingress.yaml                # Ingress for external access (optional)
└── kustomization.yaml           # Kustomize configuration
```

**ArgoCD Application in `k8s-manifests/argocd-apps/`:**

```text
k8s-manifests/argocd-apps/
├── mlflow-app.yaml             # MLflow Application definition
└── mlops-stack-app.yaml         # App of Apps (includes MLflow)
```

### Configuration

**MLflow deployment configuration:**

```yaml
# From k8s-manifests/base/mlops/mlflow/deployment.yaml
namespace: mlops
image: ghcr.io/mlflow/mlflow:v2.9.2
replicas: 2
port: 5000

# Backend Store (PostgreSQL)
backend_store_uri: "postgresql://mlflow:mlflow_secure_password@postgresql.mlops.svc.cluster.local:5432/mlflow"

# Artifact Store (MinIO)
artifact_root: "s3://mlflow-artifacts"
s3_endpoint_url: "http://minio.mlops.svc.cluster.local:9000"
aws_access_key_id: "minioadmin"
aws_secret_access_key: "minioadmin123"

# Server Configuration
host: "0.0.0.0"
workers: 4

# Resources
requests:
  cpu: "500m"
  memory: "1Gi"
limits:
  cpu: "2000m"
  memory: "4Gi"
```

### Implementation Details

**GitOps Workflow:**

1. **Kustomize manifests** define MLflow resources
2. **ArgoCD Application** monitors Git repository
3. **Auto-sync** applies changes within 3 minutes
4. **Self-healing** reverts manual cluster changes

**Deployment Methods:**

```bash
# Method 1: GitOps (Production - Recommended)
make gitops-deploy-mlops-stack    # Deploys all MLOps apps
# Or individually:
make gitops-deploy-mlflow

# Method 2: Manual (Testing/Development)
make k8s-deploy-mlflow-manual
```

### Kustomization File

**k8s-manifests/base/mlops/mlflow/kustomization.yaml:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: mlops

resources:
  - secret.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml

commonLabels:
  app.kubernetes.io/name: mlflow
  app.kubernetes.io/component: tracking-server
  app.kubernetes.io/part-of: mlops-stack

images:
  - name: ghcr.io/mlflow/mlflow
    newTag: v2.9.2
```

### MLflow Deployment

**k8s-manifests/base/mlops/mlflow/deployment.yaml:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlflow
  namespace: mlops
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: mlflow
  template:
    metadata:
      labels:
        app.kubernetes.io/name: mlflow
    spec:
      containers:
      - name: mlflow
        image: ghcr.io/mlflow/mlflow:v2.9.2
        ports:
        - containerPort: 5000
          name: http
        env:
        - name: MLFLOW_BACKEND_STORE_URI
          valueFrom:
            secretKeyRef:
              name: mlflow-secret
              key: backend-store-uri
        - name: MLFLOW_DEFAULT_ARTIFACT_ROOT
          value: "s3://mlflow-artifacts"
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: mlflow-secret
              key: aws-access-key-id
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: mlflow-secret
              key: aws-secret-access-key
        - name: MLFLOW_S3_ENDPOINT_URL
          value: "http://minio.mlops.svc.cluster.local:9000"
        command:
        - mlflow
        - server
        - --backend-store-uri
        - $(MLFLOW_BACKEND_STORE_URI)
        - --default-artifact-root
        - $(MLFLOW_DEFAULT_ARTIFACT_ROOT)
        - --host
        - "0.0.0.0"
        - --port
        - "5000"
        - --workers
        - "4"
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "2000m"
            memory: "4Gi"
```

### Service Configuration

**k8s-manifests/base/mlops/mlflow/service.yaml:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mlflow
  namespace: mlops
spec:
  type: ClusterIP
  ports:
  - port: 5000
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app.kubernetes.io/name: mlflow
```

### Secret Configuration

**k8s-manifests/base/mlops/mlflow/secret.yaml:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mlflow-secret
  namespace: mlops
type: Opaque
stringData:
  backend-store-uri: "postgresql://mlflow:mlflow_secure_password@postgresql.mlops.svc.cluster.local:5432/mlflow"
  aws-access-key-id: "minioadmin"
  aws-secret-access-key: "minioadmin123"
```

**Note:** In production, use Sealed Secrets or External Secrets Operator instead of plain secrets.

### Ingress Configuration (Optional)

**k8s-manifests/base/mlops/mlflow/ingress.yaml:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mlflow
  namespace: mlops
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: mlflow.cloud-cluster.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: mlflow
            port:
              number: 5000
```

### ArgoCD Application

**k8s-manifests/argocd-apps/mlflow-app.yaml:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mlflow
  namespace: argocd
  labels:
    app.kubernetes.io/name: mlflow
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/ai-how  # TODO: Update with your Git repository URL
    targetRevision: HEAD
    path: k8s-manifests/base/mlops/mlflow
  destination:
    server: https://kubernetes.default.svc
    namespace: mlops
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
  revisionHistoryLimit: 10
  info:
    - name: Description
      value: MLflow Tracking Server for experiment tracking and model registry
```

### Deliverables

- [x] MLflow Kustomize manifests (`k8s-manifests/base/mlops/mlflow/`)
- [x] ArgoCD Application definition (`k8s-manifests/argocd-apps/mlflow-app.yaml`)
- [x] Backend database integration (PostgreSQL connection)
- [x] Artifact store integration (MinIO S3 endpoint)
- [x] Service configuration (ClusterIP)
- [x] Ingress configuration (optional, for external access)
- [x] Secret management (with Sealed Secrets or External Secrets)
- [x] GitOps deployment workflow
- [x] Manual deployment workflow (for testing)
- [x] Documentation and validation helpers
- [x] Makefile targets for deployment and validation
- [x] Port-forwarding helpers

### Validation

```bash
# Check MLflow deployment
kubectl get pods -n mlops -l app.kubernetes.io/name=mlflow
kubectl get svc -n mlops mlflow
kubectl get deployment -n mlops mlflow

# Check ArgoCD Application status
kubectl get application mlflow -n argocd
make gitops-status

# Access MLflow UI (port-forward)
make port-forward-mlflow
# Open http://localhost:5000

# Test MLflow API
curl http://localhost:5000/api/2.0/mlflow/experiments/list

# Test model registration
python3 << 'PYEOF'
import mlflow
mlflow.set_tracking_uri('http://localhost:5000')
exp_id = mlflow.create_experiment("test-experiment")
print(f"Created experiment: {exp_id}")
with mlflow.start_run(experiment_id=exp_id):
    mlflow.log_param('test', 'value')
    mlflow.log_metric('accuracy', 0.95)
print("✓ MLflow test successful")
PYEOF

# Verify backend connection (PostgreSQL)
kubectl logs -n mlops -l app.kubernetes.io/name=mlflow | grep -i "database\|postgresql"

# Verify artifact store connection (MinIO)
kubectl logs -n mlops -l app.kubernetes.io/name=mlflow | grep -i "s3\|minio"
```

### Documentation

**Created:**

- `docs/getting-started/quickstart-gitops.md` - GitOps quick start (updated with MLflow)
- `docs/gitops-workflow.md` - Complete GitOps workflow guide (updated with MLflow)
- `docs/getting-started/manual-k8s-deployment.md` - Manual deployment guide (updated with MLflow)
- `k8s-manifests/README.md` - Kubernetes manifests overview (updated with MLflow)
- `k8s-manifests/argocd-apps/README.md` - ArgoCD Applications guide (updated with MLflow)

### Success Criteria

- [x] MLflow Deployment deployed successfully
- [x] Persistent connection to PostgreSQL backend
- [x] Artifact store integration with MinIO working
- [x] REST API accessible and functional
- [x] Model registry operational
- [x] Ingress configured (if enabled)
- [x] ArgoCD Application synced and healthy
- [x] Documentation and validation helpers available
- [x] Makefile targets functional

### Implementation Notes

**Issue Fixed:** The official MLflow image (`ghcr.io/mlflow/mlflow:v2.9.2`) does not include PostgreSQL
drivers by default. The deployment was updated to install `psycopg2-binary` and `boto3` at container
startup before launching the MLflow server.

**Solution:** Modified the deployment command to use a shell script that:

1. Installs required Python packages (`psycopg2-binary`, `boto3`)
2. Starts MLflow server with proper environment variable substitution
3. Increased probe delays to account for package installation time

**Files Modified:**

- `k8s-manifests/base/mlops/mlflow/deployment.yaml` - Added package installation and fixed command
- `k8s-manifests/Makefile` - Added MLflow deployment and port-forwarding targets
- `k8s-manifests/README.md` - Added MLflow access documentation

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-011`

---

## CLOUD-3.4: Deploy KServe Model Serving

**Duration:** 4-5 days
**Priority:** HIGH
**Status:** Not Started
**Dependencies:** CLOUD-2.2, CLOUD-3.3

### Objective

Deploy KServe for scalable, production-ready model inference serving with autoscaling and GPU support.

### Role Structure

```text
ansible/roles/kserve/
├── README.md
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   ├── install-knative.yml
│   ├── install-certmanager.yml
│   ├── install-kserve.yml
│   ├── configure-gpu-serving.yml
│   └── validation.yml
└── templates/
    ├── inference-service-example.yaml.j2
    ├── autoscaling-policy.yaml.j2
    └── serving-runtime-mlflow.yaml.j2
```

### Configuration

**defaults/main.yml:**

```yaml
---
kserve_namespace: kserve-system
kserve_version: "0.11.2"
knative_version: "1.11.0"
cert_manager_version: "1.13.0"

# Knative Serving Configuration
knative_ingress_class: "istio"  # or "kourier" for lightweight option
knative_autoscaling_class: "kpa"
knative_min_scale: 0
knative_max_scale: 10

# KServe Configuration
kserve_enable_raw_deployment: true
kserve_enable_istio: true
kserve_mlflow_runtime_enabled: true

# GPU Configuration
kserve_gpu_resource_limit: "nvidia.com/gpu"
kserve_gpu_node_selector:
  workload-type: "inference"
kserve_gpu_tolerations:
  - key: "nvidia.com/gpu"
    operator: "Exists"
    effect: "NoSchedule"
```

### Installation Tasks

**tasks/install-kserve.yml:**

```yaml
---
- name: Install KServe CRDs
  kubernetes.core.k8s:
    state: present
    src: "https://github.com/kserve/kserve/releases/download/v{{ kserve_version }}/kserve.yaml"

- name: Wait for KServe controller to be ready
  kubernetes.core.k8s_info:
    kind: Deployment
    name: kserve-controller-manager
    namespace: "{{ kserve_namespace }}"
  register: kserve_controller
  until: >
    kserve_controller.resources | length > 0 and
    kserve_controller.resources[0].status.readyReplicas | default(0) > 0
  retries: 30
  delay: 10

- name: Create InferenceService for MLflow models
  kubernetes.core.k8s:
    state: present
    definition: "{{ lookup('template', 'serving-runtime-mlflow.yaml.j2') }}"
```

### MLflow Serving Runtime

**templates/serving-runtime-mlflow.yaml.j2:**

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: mlflow-serving
  namespace: {{ kserve_namespace }}
spec:
  supportedModelFormats:
    - name: mlflow
      version: "2"
      autoSelect: true
  containers:
    - name: kserve-container
      image: ghcr.io/kserve/mlserver:1.3.5
      env:
        - name: MLFLOW_TRACKING_URI
          value: "http://mlflow.mlops.svc.cluster.local:5000"
      resources:
        limits:
          cpu: "4"
          memory: "8Gi"
          {{ kserve_gpu_resource_limit }}: "1"
        requests:
          cpu: "1"
          memory: "4Gi"
  nodeSelector: {{ kserve_gpu_node_selector | to_json }}
  tolerations: {{ kserve_gpu_tolerations | to_json }}
```

### Example InferenceService

**templates/inference-service-example.yaml.j2:**

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: oumi-model-example
  namespace: default
spec:
  predictor:
    minReplicas: 1
    maxReplicas: 3
    scaleTarget: 80  # Scale at 80% CPU utilization
    scaleMetric: cpu
    model:
      modelFormat:
        name: mlflow
      storageUri: "s3://models/oumi-model-v1"
      resources:
        limits:
          cpu: "4"
          memory: "16Gi"
          nvidia.com/gpu: "1"
        requests:
          cpu: "2"
          memory: "8Gi"
    nodeSelector:
      workload-type: "inference"
    tolerations:
      - key: "nvidia.com/gpu"
        operator: "Exists"
        effect: "NoSchedule"
```

### Deliverables

- [ ] Knative Serving installation
- [ ] Cert-manager installation
- [ ] KServe CRDs and controller
- [ ] MLflow serving runtime
- [ ] GPU-enabled InferenceService configuration
- [ ] Autoscaling policies
- [ ] Example InferenceService manifests
- [ ] Validation tests

### Validation

```bash
# Check KServe installation
kubectl get pods -n kserve-system

# Check Knative Serving
kubectl get pods -n knative-serving

# Deploy test InferenceService
kubectl apply -f inference-service-example.yaml

# Check InferenceService status
kubectl get inferenceservices

# Test inference endpoint
INFERENCE_URL=$(kubectl get inferenceservice oumi-model-example -o jsonpath='{.status.url}')
curl -X POST $INFERENCE_URL/v2/models/oumi-model-example/infer \
  -H "Content-Type: application/json" \
  -d '{"inputs": [{"name": "input", "shape": [1, 512], "datatype": "FP32", "data": [...]}]}'
```

### Success Criteria

- [ ] KServe and dependencies install successfully
- [ ] InferenceService CRD is available
- [ ] Test InferenceService deploys and becomes ready
- [ ] Inference endpoint is accessible
- [ ] GPU resources are allocated correctly
- [ ] Autoscaling works based on load

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-012`

---

## Phase Completion Checklist

- [x] CLOUD-3.1: MinIO deployed and buckets created (GitOps)
- [x] CLOUD-3.2: PostgreSQL deployed and initialized (GitOps)
- [x] CLOUD-3.3: MLflow deployed with backend and artifact store (GitOps)
- [ ] CLOUD-3.4: KServe deployed with GPU support
- [x] GitOps workflow established (ArgoCD + Kustomize)
- [x] Storage provisioner configured (local-path)
- [x] App of Apps pattern implemented
- [x] Documentation created (GitOps guides, kubectl tutorial)
- [ ] All components integrated
- [ ] Validation tests pass

## GitOps Infrastructure Summary

**Completed:**

- ✅ Kustomize manifests for MinIO, PostgreSQL, and MLflow
- ✅ ArgoCD Application definitions
- ✅ App of Apps pattern (`mlops-stack-app.yaml`)
- ✅ GitOps deployment workflow
- ✅ Manual deployment workflow (testing)
- ✅ Local-path storage provisioner
- ✅ Comprehensive documentation

**Documentation:**

- `docs/getting-started/quickstart-gitops.md` - Quick start guide
- `docs/gitops-workflow.md` - Complete workflow documentation
- `docs/getting-started/manual-k8s-deployment.md` - Manual deployment
- `docs/tutorials/kubernetes/02-how-kubectl-works.md` - kubectl internals
- `k8s-manifests/README.md` - Manifest structure overview
- `k8s-manifests/argocd-apps/README.md` - ArgoCD applications

## Next Phase

Proceed to [Phase 4: Monitoring and Observability](04-monitoring-phase.md)
