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
**Status:** Not Started
**Dependencies:** CLOUD-2.1

### Objective

Deploy MinIO as S3-compatible object storage for model artifacts, datasets, and MLflow artifacts.

### Role Structure

```text
ansible/roles/minio/
├── README.md
├── defaults/
│   └── main.yml                        # Default variables
├── tasks/
│   ├── main.yml                        # Main orchestration
│   ├── deploy-minio.yml                # MinIO deployment
│   ├── create-buckets.yml              # Bucket creation
│   ├── configure-policies.yml          # Access policies
│   └── validation.yml                  # Health checks
└── templates/
    ├── minio-deployment.yaml.j2        # Kubernetes Deployment
    ├── minio-service.yaml.j2           # Kubernetes Service
    ├── minio-pvc.yaml.j2               # PersistentVolumeClaim
    └── minio-ingress.yaml.j2           # Ingress configuration
```

### Configuration

**defaults/main.yml:**

```yaml
---
minio_namespace: mlops
minio_version: "RELEASE.2024-10-02T17-50-41Z"
minio_replicas: 1
minio_storage_size: 100Gi
minio_storage_class: local-path

minio_access_key: "minioadmin"
minio_secret_key: "minioadmin123"  # Should be overridden with secure value

minio_buckets:
  - name: mlflow-artifacts
    policy: private
  - name: models
    policy: private
  - name: datasets
    policy: private
  - name: experiments
    policy: private

minio_ingress_enabled: true
minio_ingress_host: minio.cloud-cluster.local
```

### Deliverables

- [ ] MinIO Kubernetes manifests
- [ ] Persistent storage configuration
- [ ] Automatic bucket creation
- [ ] Access policy configuration
- [ ] Ingress for external access
- [ ] Validation tests

### Validation

```bash
# Check MinIO pods
kubectl get pods -n mlops -l app=minio

# Check buckets
kubectl exec -n mlops deployment/minio -- mc ls local/

# Test upload/download
kubectl run test-minio --image=minio/mc --rm -it -- \
  mc alias set minio http://minio:9000 minioadmin minioadmin123
kubectl run test-minio --image=minio/mc --rm -it -- \
  mc mb minio/test-bucket
```

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-009`

---

## CLOUD-3.2: Deploy PostgreSQL Database

**Duration:** 2 days
**Priority:** HIGH
**Status:** Not Started
**Dependencies:** CLOUD-2.1

### Objective

Deploy PostgreSQL as the backend database for MLflow metadata storage.

### Role Structure

```text
ansible/roles/postgresql/
├── README.md
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   ├── deploy-postgresql.yml
│   ├── initialize-database.yml
│   ├── create-mlflow-schema.yml
│   └── validation.yml
└── templates/
    ├── postgresql-statefulset.yaml.j2
    ├── postgresql-service.yaml.j2
    ├── postgresql-pvc.yaml.j2
    └── init-mlflow-db.sql.j2
```

### Configuration

**defaults/main.yml:**

```yaml
---
postgresql_namespace: mlops
postgresql_version: "15.4"
postgresql_storage_size: 20Gi
postgresql_storage_class: local-path

postgresql_database: mlflow
postgresql_user: mlflow
postgresql_password: "mlflow_secure_password"  # Override with secure value

postgresql_max_connections: 100
postgresql_shared_buffers: "256MB"
postgresql_effective_cache_size: "1GB"
```

### Deliverables

- [ ] PostgreSQL StatefulSet
- [ ] Persistent storage for data
- [ ] MLflow database initialization
- [ ] Backup configuration
- [ ] Connection validation

### Validation

```bash
# Check PostgreSQL pod
kubectl get pods -n mlops -l app=postgresql

# Test database connection
kubectl exec -n mlops postgresql-0 -- \
  psql -U mlflow -d mlflow -c "SELECT version();"

# Verify MLflow schema
kubectl exec -n mlops postgresql-0 -- \
  psql -U mlflow -d mlflow -c "\dt"
```

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

- [ ] CLOUD-3.1: MinIO deployed and buckets created
- [ ] CLOUD-3.2: PostgreSQL deployed and initialized
- [ ] CLOUD-3.3: MLflow deployed with backend and artifact store
- [ ] CLOUD-3.4: KServe deployed with GPU support
- [ ] All components integrated
- [ ] Validation tests pass
- [ ] Documentation updated

## Next Phase

Proceed to [Phase 4: Monitoring and Observability](04-monitoring-phase.md)
