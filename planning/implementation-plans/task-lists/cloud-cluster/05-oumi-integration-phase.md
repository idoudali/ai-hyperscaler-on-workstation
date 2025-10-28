# Phase 5: Oumi Integration

**Duration:** 1 week
**Tasks:** CLOUD-5.1, CLOUD-5.2
**Dependencies:** Phase 3 (MLOps Stack)

## Overview

Configure Oumi for the custom Kubernetes cluster and validate the complete end-to-end ML workflow from HPC training
to cloud inference.

---

## CLOUD-5.1: Oumi Configuration and Testing

**Duration:** 3-4 days
**Priority:** CRITICAL
**Status:** Not Started
**Dependencies:** CLOUD-3.4

### Objective

Configure Oumi to work with the custom Kubernetes cluster and validate the complete training-to-inference workflow.

### Deliverables

- [ ] `oumi_config.yaml` for custom cluster
- [ ] Job launcher configuration
- [ ] MLflow integration
- [ ] End-to-end workflow validation
- [ ] Performance baseline metrics

### Validation Workflow

```bash
# 1. Train model on HPC cluster
ai-how hpc start config/hpc-cluster.yaml
sbatch scripts/train-oumi-model.sh

# 2. Register model in MLflow
python scripts/register-model-mlflow.py

# 3. Deploy to cloud cluster
ai-how cloud start config/cloud-cluster.yaml
kubectl apply -f manifests/oumi-inference-service.yaml

# 4. Test inference
curl -X POST http://oumi-model.cloud-cluster.local/v2/models/oumi/infer \
  -d '{"inputs": [...]}'

# 5. Monitor performance
kubectl top pods
```

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-015`

---

## CLOUD-5.2: ML Workflow Documentation

**Duration:** 2 days
**Priority:** HIGH
**Status:** Not Started
**Dependencies:** CLOUD-5.1

### Objective

Create comprehensive documentation for the complete ML workflow from training to inference.

### Deliverables

- [ ] `docs/tutorials/08-oumi-training-to-inference.md`
- [ ] `docs/architecture/ml-workflow.md`
- [ ] `docs/operations/model-deployment.md`
- [ ] Example training scripts
- [ ] Example inference deployment manifests

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-016`

---

## Phase Completion Checklist

- [ ] CLOUD-5.1: Oumi configured and validated
- [ ] CLOUD-5.2: Workflow documentation complete
- [ ] End-to-end workflow tested
- [ ] Performance metrics documented

## Next Phase

Proceed to [Phase 6: Integration and Optimization](06-integration-phase.md)
