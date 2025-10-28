# Phase 7: Testing and Validation

**Duration:** 1 week
**Tasks:** CLOUD-7.1
**Dependencies:** Phase 0 (Foundation)

## Overview

Create comprehensive test framework for cloud cluster validation across deployment, Kubernetes, MLOps, and inference.

---

## CLOUD-7.1: Cloud Cluster Test Framework

**Duration:** 4-5 days
**Priority:** HIGH
**Status:** Not Started
**Dependencies:** CLOUD-0.2

### Objective

Develop comprehensive test framework to validate all aspects of cloud cluster functionality from provisioning through
inference.

### Test Framework Structure

```text
tests/
├── test-cloud-framework.sh             # Main test runner
├── test-configs/
│   ├── cloud-cluster-test-config.yaml  # Test cluster configuration
│   └── test-inference-service.yaml     # Test InferenceService manifest
├── lib/
│   ├── test-helpers.sh                 # Common test functions
│   └── assertions.sh                   # Test assertions
└── suites/
    ├── 01-cloud-cluster-deployment/
    │   ├── test-vm-provisioning.sh
    │   ├── test-vm-lifecycle.sh
    │   └── test-cli-commands.sh
    ├── 02-kubernetes-cluster/
    │   ├── test-cluster-health.sh
    │   ├── test-networking.sh
    │   ├── test-dns-resolution.sh
    │   └── test-gpu-scheduling.sh
    ├── 03-mlops-stack/
    │   ├── test-minio.sh
    │   ├── test-postgresql.sh
    │   ├── test-mlflow.sh
    │   └── test-kserve.sh
    └── 04-inference-validation/
        ├── test-model-deployment.sh
        ├── test-inference-api.sh
        ├── test-autoscaling.sh
        └── test-gpu-inference.sh
```

### Test Suites

#### Suite 1: Cloud Cluster Deployment

```bash
# tests/suites/01-cloud-cluster-deployment/test-vm-provisioning.sh

test_vm_provisioning() {
    echo "Testing VM provisioning..."
    
    # Provision cluster
    ai-how cloud start test-configs/cloud-cluster-test-config.yaml
    assert_exit_code 0 "Cloud cluster provisioning failed"
    
    # Verify VMs are running
    assert_vm_running "control-plane"
    assert_vm_running "gpu-worker-1"
    
    # Verify network connectivity
    assert_vm_reachable "control-plane" "192.168.200.10"
    
    echo "✓ VM provisioning test passed"
}

test_vm_lifecycle() {
    echo "Testing VM lifecycle operations..."
    
    # Stop cluster
    ai-how cloud stop test-configs/cloud-cluster-test-config.yaml
    assert_exit_code 0 "Cloud cluster stop failed"
    
    # Verify VMs are stopped
    assert_vm_stopped "control-plane"
    
    # Restart cluster
    ai-how cloud start test-configs/cloud-cluster-test-config.yaml
    assert_exit_code 0 "Cloud cluster restart failed"
    
    echo "✓ VM lifecycle test passed"
}

test_cli_commands() {
    echo "Testing CLI commands..."
    
    # Test status command
    ai-how cloud status test-configs/cloud-cluster-test-config.yaml
    assert_exit_code 0 "Cloud status command failed"
    
    # Test destroy with confirmation
    echo "yes" | ai-how cloud destroy test-configs/cloud-cluster-test-config.yaml
    assert_exit_code 0 "Cloud destroy command failed"
    
    echo "✓ CLI commands test passed"
}
```

#### Suite 2: Kubernetes Cluster

```bash
# tests/suites/02-kubernetes-cluster/test-cluster-health.sh

test_cluster_health() {
    echo "Testing Kubernetes cluster health..."
    
    # Check all nodes are Ready
    kubectl get nodes --no-headers | while read node status rest; do
        assert_equals "$status" "Ready" "Node $node is not Ready"
    done
    
    # Check system pods are Running
    kubectl get pods -n kube-system --no-headers | while read pod status rest; do
        assert_contains "$status" "Running" "Pod $pod is not Running"
    done
    
    echo "✓ Cluster health test passed"
}

test_networking() {
    echo "Testing Kubernetes networking..."
    
    # Deploy test pods
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-1
spec:
  containers:
  - name: nginx
    image: nginx:alpine
EOF
    
    # Wait for pod to be ready
    kubectl wait --for=condition=Ready pod/test-pod-1 --timeout=60s
    
    # Test pod-to-pod connectivity
    kubectl run test-pod-2 --image=busybox --rm -it --restart=Never -- \
        wget -O- test-pod-1 --timeout=5
    
    # Cleanup
    kubectl delete pod test-pod-1
    
    echo "✓ Networking test passed"
}

test_dns_resolution() {
    echo "Testing DNS resolution..."
    
    # Test cluster DNS
    kubectl run busybox --image=busybox --rm -it --restart=Never -- \
        nslookup kubernetes.default
    assert_exit_code 0 "DNS resolution failed"
    
    echo "✓ DNS resolution test passed"
}

test_gpu_scheduling() {
    echo "Testing GPU scheduling..."
    
    # Deploy GPU test pod
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test-pod
spec:
  restartPolicy: Never
  containers:
  - name: cuda-test
    image: nvidia/cuda:12.0.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
  nodeSelector:
    workload-type: inference
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
EOF
    
    # Wait for completion
    kubectl wait --for=condition=Ready pod/gpu-test-pod --timeout=120s
    
    # Check logs for GPU info
    kubectl logs gpu-test-pod | grep "NVIDIA"
    assert_exit_code 0 "GPU not accessible in pod"
    
    # Cleanup
    kubectl delete pod gpu-test-pod
    
    echo "✓ GPU scheduling test passed"
}
```

#### Suite 3: MLOps Stack

```bash
# tests/suites/03-mlops-stack/test-mlflow.sh

test_mlflow() {
    echo "Testing MLflow..."
    
    # Port forward MLflow
    kubectl port-forward -n mlops svc/mlflow 5000:5000 &
    PF_PID=$!
    sleep 5
    
    # Test API endpoint
    curl -f http://localhost:5000/api/2.0/mlflow/experiments/list
    assert_exit_code 0 "MLflow API not accessible"
    
    # Test experiment creation
    python3 << 'PYEOF'
import mlflow
mlflow.set_tracking_uri("http://localhost:5000")
exp_id = mlflow.create_experiment("test-experiment")
assert exp_id is not None, "Failed to create experiment"
PYEOF
    
    # Cleanup
    kill $PF_PID
    
    echo "✓ MLflow test passed"
}
```

#### Suite 4: Inference Validation

```bash
# tests/suites/04-inference-validation/test-inference-api.sh

test_inference_api() {
    echo "Testing inference API..."
    
    # Deploy test InferenceService
    kubectl apply -f test-configs/test-inference-service.yaml
    
    # Wait for InferenceService to be ready
    kubectl wait --for=condition=Ready inferenceservice/test-model --timeout=300s
    
    # Get inference URL
    INFERENCE_URL=$(kubectl get inferenceservice test-model -o jsonpath='{.status.url}')
    
    # Test inference endpoint
    curl -X POST "$INFERENCE_URL/v2/models/test-model/infer" \
        -H "Content-Type: application/json" \
        -d '{"inputs": [{"name": "input", "shape": [1, 10], "datatype": "FP32", "data": [1,2,3,4,5,6,7,8,9,10]}]}'
    assert_exit_code 0 "Inference API request failed"
    
    # Cleanup
    kubectl delete inferenceservice test-model
    
    echo "✓ Inference API test passed"
}
```

### Makefile Integration

```makefile
# Makefile

.PHONY: test-cloud-all test-cloud-deployment test-cloud-kubernetes test-cloud-mlops test-cloud-inference

test-cloud-all: test-cloud-deployment test-cloud-kubernetes test-cloud-mlops test-cloud-inference
 @echo "✓ All cloud cluster tests passed"

test-cloud-deployment:
 @echo "Running cloud cluster deployment tests..."
 @tests/test-cloud-framework.sh deployment

test-cloud-kubernetes:
 @echo "Running Kubernetes cluster tests..."
 @tests/test-cloud-framework.sh kubernetes

test-cloud-mlops:
 @echo "Running MLOps stack tests..."
 @tests/test-cloud-framework.sh mlops

test-cloud-inference:
 @echo "Running inference validation tests..."
 @tests/test-cloud-framework.sh inference
```

### Test Runner

**tests/test-cloud-framework.sh:**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"
source "$SCRIPT_DIR/lib/assertions.sh"

SUITE="${1:-all}"

run_test_suite() {
    local suite_name="$1"
    local suite_dir="$SCRIPT_DIR/suites/$suite_name"
    
    echo "=================================="
    echo "Running test suite: $suite_name"
    echo "=================================="
    
    for test_file in "$suite_dir"/*.sh; do
        echo "Running: $(basename "$test_file")"
        source "$test_file"
        
        # Extract and run test functions
        grep -E '^test_' "$test_file" | sed 's/().*//' | while read -r test_func; do
            $test_func
        done
    done
}

case "$SUITE" in
    all)
        run_test_suite "01-cloud-cluster-deployment"
        run_test_suite "02-kubernetes-cluster"
        run_test_suite "03-mlops-stack"
        run_test_suite "04-inference-validation"
        ;;
    deployment)
        run_test_suite "01-cloud-cluster-deployment"
        ;;
    kubernetes)
        run_test_suite "02-kubernetes-cluster"
        ;;
    mlops)
        run_test_suite "03-mlops-stack"
        ;;
    inference)
        run_test_suite "04-inference-validation"
        ;;
    *)
        echo "Unknown test suite: $SUITE"
        echo "Usage: $0 {all|deployment|kubernetes|mlops|inference}"
        exit 1
        ;;
esac

echo "✓ All tests passed!"
```

### Deliverables

- [ ] Test framework structure created
- [ ] Cloud cluster deployment tests
- [ ] Kubernetes cluster tests
- [ ] MLOps stack tests
- [ ] Inference validation tests
- [ ] Makefile targets for test execution
- [ ] CI/CD integration (optional)
- [ ] Test documentation

### Validation

```bash
# Run all tests
make test-cloud-all

# Run specific suite
make test-cloud-kubernetes

# Run individual test
./tests/suites/02-kubernetes-cluster/test-cluster-health.sh
```

### Success Criteria

- [ ] Test framework executes successfully
- [ ] All test suites pass
- [ ] Tests are idempotent (can be run multiple times)
- [ ] Tests clean up after themselves
- [ ] Clear pass/fail reporting
- [ ] Integration with existing test infrastructure

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-020`

---

## Phase Completion Checklist

- [ ] CLOUD-7.1: Test framework created and validated
- [ ] All test suites pass
- [ ] Documentation complete
- [ ] CI/CD integration (if applicable)

## Project Completion

All 8 phases complete! Cloud cluster is ready for production use.

**Next steps:**

- Begin implementation starting with Phase 0
- Track progress in GitHub issues
- Update task status as work progresses
- Validate each phase before moving to next
