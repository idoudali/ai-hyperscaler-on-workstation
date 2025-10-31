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
**Status:** Not Started
**Dependencies:** CLOUD-3.1, CLOUD-3.2

### Objective

Deploy MLflow tracking server for experiment tracking, model registry, and model versioning.

### Role Structure

```text
ansible/roles/mlflow/
├── README.md
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   ├── deploy-mlflow.yml
│   ├── configure-backend.yml
│   ├── configure-artifact-store.yml
│   └── validation.yml
└── templates/
    ├── mlflow-deployment.yaml.j2
    ├── mlflow-service.yaml.j2
    ├── mlflow-configmap.yaml.j2
    ├── mlflow-secret.yaml.j2
    └── mlflow-ingress.yaml.j2
```

### Configuration

**defaults/main.yml:**

```yaml
---
mlflow_namespace: mlops
mlflow_version: "2.9.2"
mlflow_replicas: 2

# Backend Store (PostgreSQL)
mlflow_backend_store_uri: "postgresql://mlflow:mlflow_secure_password@postgresql:5432/mlflow"

# Artifact Store (MinIO)
mlflow_artifact_root: "s3://mlflow-artifacts"
mlflow_s3_endpoint_url: "http://minio:9000"
mlflow_aws_access_key_id: "minioadmin"
mlflow_aws_secret_access_key: "minioadmin123"

# Server Configuration
mlflow_port: 5000
mlflow_host: "0.0.0.0"
mlflow_workers: 4

# Ingress
mlflow_ingress_enabled: true
mlflow_ingress_host: mlflow.cloud-cluster.local
```

### MLflow Deployment Template

**templates/mlflow-deployment.yaml.j2:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlflow
  namespace: {{ mlflow_namespace }}
spec:
  replicas: {{ mlflow_replicas }}
  selector:
    matchLabels:
      app: mlflow
  template:
    metadata:
      labels:
        app: mlflow
    spec:
      containers:
      - name: mlflow
        image: ghcr.io/mlflow/mlflow:v{{ mlflow_version }}
        ports:
        - containerPort: {{ mlflow_port }}
          name: http
        env:
        - name: MLFLOW_BACKEND_STORE_URI
          valueFrom:
            secretKeyRef:
              name: mlflow-secret
              key: backend-store-uri
        - name: MLFLOW_DEFAULT_ARTIFACT_ROOT
          value: "{{ mlflow_artifact_root }}"
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
          value: "{{ mlflow_s3_endpoint_url }}"
        command:
        - mlflow
        - server
        - --backend-store-uri
        - $(MLFLOW_BACKEND_STORE_URI)
        - --default-artifact-root
        - $(MLFLOW_DEFAULT_ARTIFACT_ROOT)
        - --host
        - "{{ mlflow_host }}"
        - --port
        - "{{ mlflow_port }}"
        - --workers
        - "{{ mlflow_workers }}"
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

### Deliverables

- [ ] MLflow server deployment
- [ ] Backend database integration
- [ ] Artifact store integration (MinIO)
- [ ] REST API configuration
- [ ] Model registry setup
- [ ] Ingress for external access
- [ ] Validation tests

### Validation

```bash
# Check MLflow pods
kubectl get pods -n mlops -l app=mlflow

# Test MLflow API
kubectl port-forward -n mlops svc/mlflow 5000:5000
curl http://localhost:5000/api/2.0/mlflow/experiments/list

# Test model registration
python -c "
import mlflow
mlflow.set_tracking_uri('http://localhost:5000')
with mlflow.start_run():
    mlflow.log_param('test', 'value')
"
```

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
- [ ] CLOUD-3.3: MLflow deployed with backend and artifact store (Next task)
- [ ] CLOUD-3.4: KServe deployed with GPU support
- [x] GitOps workflow established (ArgoCD + Kustomize)
- [x] Storage provisioner configured (local-path)
- [x] App of Apps pattern implemented
- [x] Documentation created (GitOps guides, kubectl tutorial)
- [ ] All components integrated
- [ ] Validation tests pass

## GitOps Infrastructure Summary

**Completed:**

- ✅ Kustomize manifests for MinIO and PostgreSQL
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
