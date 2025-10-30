# Category 5: End-to-End MLOps Workflow

**Category Overview:** Validate complete workflow: train on HPC → register in MLflow → deploy on cloud → serve inference.

**Tasks:** MLOPS-5.1, MLOPS-5.2  
**Total Duration:** 5 days  
**Target Infrastructure:** Both HPC and Cloud clusters, MLflow, complete MLOps pipeline

---

## MLOPS-5.1: Complete Training-to-Inference Pipeline

**Duration:** 3 days  
**Priority:** CRITICAL  
**Dependencies:** All previous tasks  
**Validation Target:** Complete MLOps workflow, HPC→Cloud integration

### Objective

Implement and validate complete ML workflow: train on HPC → register in MLflow → deploy on cloud → serve inference.

### Workflow Overview

**5-Step Pipeline:**

1. Train model on HPC cluster (SLURM job)
2. Register model in MLflow registry
3. Sync model to cloud storage (MinIO)
4. Deploy to KServe on cloud cluster
5. Serve inference requests

### Implementation

**Step 1: Train Model on HPC**

Training configuration with MLflow tracking:

```yaml
training:
  output_dir: "/mnt/beegfs/models/smollm-production"
  mlflow_tracking_uri: "http://mlflow.mlops.svc.cluster.local:5000"
  mlflow_experiment_name: "smollm-production"
  num_train_epochs: 3
```

See lines 1018-1027 in original file for training configuration.

**Step 2: Register Model in MLflow**

Script: `scripts/mlops/register_model_mlflow.py`

Key operations:

- Connect to MLflow server on cloud cluster
- Register model from BeeGFS path
- Tag with version and metadata
- Transition to "Production" stage

See lines 1029-1062 in original file for registration script.

**Step 3: Sync Model to Cloud Storage**

Script: `scripts/mlops/sync_model_to_cloud.sh`

Operations:

- Copy model files from BeeGFS to MinIO
- Uses MinIO client (`mc`)
- Preserves directory structure
- Verifies successful transfer

See lines 1064-1076 in original file for sync script.

**Step 4: Deploy to KServe**

Manifest: `manifests/mlops/smollm-production-inference.yaml`

Configuration:

- Model format: MLflow
- Storage URI: `s3://models/smollm-production`
- Resources: 1 GPU, 16GB memory
- Autoscaling: 2-5 replicas
- Namespace: `production`

Annotations:

- MLflow model name and version
- Deployment metadata

See lines 1078-1102 in original file for deployment manifest.

**Step 5: End-to-End Test**

Script: `scripts/mlops/e2e_test.py`

Test stages:

1. Verify model in MLflow registry
2. Verify model in MinIO storage
3. Test inference endpoint
4. Check Prometheus metrics
5. Validate complete workflow

See lines 1104-1153 in original file for E2E test script.

### Validation Steps

```bash
# Option 1: Automated workflow
make mlops-e2e-test

# Option 2: Manual step-by-step
# 1. Train on HPC
sbatch scripts/mlops/smollm_production_train.sbatch

# Wait for training completion
watch -n 10 'ssh admin@192.168.100.10 "squeue -u admin"'

# 2. Register model in MLflow
python scripts/mlops/register_model_mlflow.py

# 3. Sync to cloud storage
./scripts/mlops/sync_model_to_cloud.sh

# 4. Deploy inference service
kubectl apply -f manifests/mlops/smollm-production-inference.yaml

# Wait for deployment
kubectl wait --for=condition=Ready \
  inferenceservice/smollm-production \
  -n production --timeout=300s

# 5. Run end-to-end test
python scripts/mlops/e2e_test.py

# 6. Monitor deployment
kubectl top pods -n production
kubectl get hpa -n production
```

### Success Criteria

- [ ] Model trains successfully on HPC
- [ ] Model registered in MLflow with metadata
- [ ] Model synced to MinIO (cloud storage)
- [ ] InferenceService deploys successfully
- [ ] Inference endpoint accessible and functional
- [ ] End-to-end latency <5 seconds (train→deploy)
- [ ] Metrics visible in Grafana dashboards
- [ ] Complete workflow documented

### Workflow Timing

Expected durations for each step:

- Training (SmolLM-135M, 3 epochs): 15-20 minutes
- Model registration: <1 minute
- Model sync: 1-2 minutes
- Deployment: 2-3 minutes
- **Total**: ~20-25 minutes from training start to inference ready

### Monitoring and Observability

**MLflow Dashboard:**

- Experiment tracking
- Model versions and metadata
- Training metrics and artifacts
- URL: `http://mlflow.cloud-cluster.local`

**Grafana Dashboards:**

- Training metrics (GPU utilization, loss curves)
- Inference metrics (latency, throughput, errors)
- Resource utilization (CPU, memory, GPU)
- URL: `http://grafana.cloud-cluster.local`

**Prometheus Queries:**

```promql
# Inference request rate
rate(kserve_model_request_total{model="smollm-production"}[5m])

# Inference latency P95
histogram_quantile(0.95, rate(kserve_model_latency_bucket[5m]))

# GPU utilization
DCGM_FI_DEV_GPU_UTIL{pod=~"smollm-production.*"}
```

---

## MLOPS-5.2: MLOps Pipeline Automation

**Duration:** 2 days  
**Priority:** MEDIUM  
**Dependencies:** MLOPS-5.1  
**Validation Target:** Automated MLOps workflows, CI/CD integration

### Objective

Automate the complete MLOps pipeline with scripts and Makefile targets.

### Implementation

**Makefile Targets:** Add to main `Makefile`

Automation targets:

- `mlops-train`: Submit training job to HPC
- `mlops-register`: Register model in MLflow
- `mlops-sync`: Sync model to cloud storage
- `mlops-deploy`: Deploy inference service
- `mlops-e2e-test`: Run complete workflow
- `mlops-monitor`: Open monitoring dashboards

See lines 1208-1252 in original file for complete Makefile targets.

### Makefile Targets Detail

**Training Target:**

```makefile
mlops-train:
 @echo "Training model on HPC cluster..."
 ssh admin@192.168.100.10 "sbatch /mnt/beegfs/scripts/smollm_production_train.sbatch"
```

**End-to-End Target:**

```makefile
mlops-e2e-test: mlops-train
 @echo "Running end-to-end MLOps workflow..."
 sleep 60  # Wait for training to start
 # Poll for training completion
 while ssh admin@192.168.100.10 "squeue -u admin | grep smollm" > /dev/null; do \
  sleep 10; \
 done
 $(MAKE) mlops-register
 $(MAKE) mlops-sync
 $(MAKE) mlops-deploy
 python scripts/mlops/e2e_test.py
 @echo "✅ End-to-end MLOps workflow completed!"
```

**Monitoring Target:**

```makefile
mlops-monitor:
 @echo "Opening monitoring dashboards..."
 @echo "MLflow: http://mlflow.cloud-cluster.local"
 @echo "Grafana: http://grafana.cloud-cluster.local"
 kubectl port-forward -n mlops svc/mlflow 5000:5000 &
 kubectl port-forward -n monitoring svc/grafana 3000:3000 &
```

### Validation Steps

```bash
# 1. Test individual targets
make mlops-train
make mlops-register
make mlops-sync
make mlops-deploy

# 2. Test complete workflow
make mlops-e2e-test

# 3. Open monitoring dashboards
make mlops-monitor

# 4. Verify error handling
# Intentionally break a step and verify graceful failure
```

### Success Criteria

- [ ] Single command triggers complete workflow
- [ ] Pipeline handles errors gracefully
- [ ] Status reporting at each stage
- [ ] Logs captured for debugging
- [ ] Rollback capability on failure

### Error Handling

**Training Failure:**

```bash
# Check SLURM job output
ssh admin@192.168.100.10 "cat /mnt/beegfs/jobs/smollm-production-*.err"

# Retry training
make mlops-train
```

**Deployment Failure:**

```bash
# Check InferenceService events
kubectl describe inferenceservice smollm-production -n production

# Rollback to previous version
kubectl rollout undo deployment -n production

# Redeploy
make mlops-deploy
```

**End-to-End Failure:**

```bash
# Check which step failed
make mlops-e2e-test 2>&1 | tee mlops-e2e.log

# Resume from failed step
make mlops-register  # if registration failed
make mlops-sync      # if sync failed
make mlops-deploy    # if deployment failed
```

### CI/CD Integration (Optional)

**GitHub Actions Workflow:**

```yaml
name: MLOps Pipeline

on:
  push:
    branches: [main]
    paths:
      - 'configs/mlops/**'
      - 'scripts/mlops/**'

jobs:
  train-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run MLOps Pipeline
        run: make mlops-e2e-test
```

### Pipeline Observability

**Logs:**

- Training logs: `/mnt/beegfs/jobs/smollm-production-*.out`
- Registration logs: `mlops-register.log`
- Deployment logs: `kubectl logs -n production -l app=smollm-production`

**Notifications (Optional):**

- Slack notifications on pipeline completion/failure
- Email alerts for critical failures
- Prometheus alerts for inference issues

---

## Category Summary

This category validates the complete MLOps workflow:

**MLOPS-5.1** establishes:

- End-to-end pipeline from training to inference
- HPC-to-Cloud integration
- MLflow model registry
- Production deployment workflow
- Complete observability

**MLOPS-5.2** extends to:

- Pipeline automation via Makefile
- Error handling and recovery
- Monitoring and logging
- CI/CD readiness

**Complete Infrastructure Validated:**

- HPC: SLURM, BeeGFS, GPU training
- Cloud: Kubernetes, KServe, GPU inference
- MLOps: MLflow, MinIO, Prometheus/Grafana
- Integration: SSH, network connectivity, data sync

**Pipeline Metrics:**

- Training time: 15-20 minutes
- Model registration: <1 minute
- Model sync: 1-2 minutes
- Deployment: 2-3 minutes
- **Total time**: ~20-25 minutes train-to-inference

**Production Readiness:**

- Automated deployment workflow
- Comprehensive monitoring
- Error handling and recovery
- Rollback capability
- Documentation and runbooks

---

**Related Documentation:**

- [Prerequisites](./reference/prerequisites.md) - Complete setup requirements
- [Troubleshooting Guide](./reference/troubleshooting.md) - Pipeline debugging
- [Validation Matrix](./reference/validation-matrix.md) - Complete infrastructure coverage
- **MLflow Documentation**: https://mlflow.org/docs/
- **KServe Documentation**: https://kserve.github.io/
