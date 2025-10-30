# Category 4: Inference Deployment

**Category Overview:** Validate model serving, inference APIs, and autoscaling on Kubernetes.

**Tasks:** MLOPS-4.1, MLOPS-4.2  
**Total Duration:** 3 days  
**Target Infrastructure:** Cloud Cluster (Kubernetes, KServe, GPU Operator, MinIO)

---

## MLOPS-4.1: Simple Model Inference (CPU)

**Duration:** 1 day  
**Priority:** HIGH  
**Dependencies:** MLOPS-1.1, Cloud cluster operational  
**Validation Target:** Basic inference deployment, KServe, model serving

### Objective

Deploy MNIST model for CPU inference using KServe on cloud cluster.

### Implementation

**InferenceService Manifest:** `manifests/mlops/mnist-inference.yaml`

Key configuration:

- Model: MNIST CNN from MLOPS-1.1
- Storage: MinIO S3-compatible storage
- Resources: CPU-only (1-2 cores, 2-4GB memory)
- Autoscaling: 1-3 replicas based on load

KServe configuration:

- PyTorch predictor
- Model URI: `s3://models/mnist/mnist_cnn_single_gpu.pt`
- Min replicas: 1, Max replicas: 3

See lines 784-806 in original file for InferenceService manifest.

**Test Script:** `scripts/mlops/test_mnist_inference.py`

Test components:

- Creates random 28x28 image input
- Sends inference request to KServe endpoint
- Validates response format and predictions
- Checks latency and success rate

Endpoint: `http://mnist-classifier.default.svc.cluster.local/v1/models/mnist-classifier:predict`

See lines 808-843 in original file for test script.

### Validation Steps

```bash
# 1. Copy trained model to MinIO
mc cp /mnt/beegfs/models/mnist/mnist_cnn_single_gpu.pt \
     minio/models/mnist/

# 2. Deploy InferenceService
kubectl apply -f manifests/mlops/mnist-inference.yaml

# 3. Wait for InferenceService ready
kubectl wait --for=condition=Ready \
  inferenceservice/mnist-classifier --timeout=300s

# 4. Check deployment status
kubectl get inferenceservice mnist-classifier
kubectl get pods -l serving.kserve.io/inferenceservice=mnist-classifier

# 5. Test inference
kubectl run test-inference --image=python:3.11 --rm -it -- \
  python3 scripts/mlops/test_mnist_inference.py

# 6. Check autoscaling
kubectl get hpa
kubectl get pods -l serving.kserve.io/inferenceservice=mnist-classifier -w
```

### Success Criteria

- [ ] InferenceService deploys successfully
- [ ] Inference endpoint accessible
- [ ] Inference returns valid predictions
- [ ] Response time <100ms
- [ ] Autoscaling works (scales 1→2→3 under load)
- [ ] CPU utilization monitored in Grafana

### Load Testing

Generate load to test autoscaling:

```bash
# Install hey (HTTP load generator)
kubectl run load-test --image=williamyeh/hey --rm -it -- \
  /hey -z 60s -c 10 \
  -m POST \
  -H "Content-Type: application/json" \
  -d '{"instances": [[[0.5, ...]]]}' \
  http://mnist-classifier.default.svc.cluster.local/v1/models/mnist-classifier:predict

# Watch pods scale
watch -n 2 'kubectl get pods -l serving.kserve.io/inferenceservice=mnist-classifier'
```

Expected behavior:

- Initial: 1 pod
- Under load: Scales to 2-3 pods within 30-60 seconds
- After load: Scales back to 1 pod after 5 minutes

---

## MLOPS-4.2: GPU Model Inference

**Duration:** 2 days  
**Priority:** HIGH  
**Dependencies:** MLOPS-4.1, GPU operator deployed  
**Validation Target:** GPU inference, model optimization, throughput

### Objective

Deploy SmolLM model for GPU-accelerated inference with KServe.

### Implementation

**InferenceService Manifest:** `manifests/mlops/smollm-inference.yaml`

Key configuration:

- Model: SmolLM-135M from MLOPS-1.2
- Runtime: HuggingFace Text Generation Inference (TGI)
- GPU: 1 NVIDIA GPU per pod
- Resources: 1 GPU, 8-16GB memory
- Autoscaling: 1-2 replicas

TGI settings:

- `NUM_SHARD: 1` (single GPU)
- `MAX_BATCH_SIZE: 4` (batch inference)
- Model loaded from MinIO

Node placement:

- `nodeSelector: workload-type: inference`
- `tolerations` for GPU nodes

See lines 890-929 in original file for InferenceService manifest.

**Load Test Script:** `scripts/mlops/load_test_smollm.py`

Load testing features:

- Concurrent requests (10 workers)
- 100 requests total
- Various prompts for diversity
- Metrics: success rate, latency (avg, P50, P95, P99), throughput

See lines 931-989 in original file for load test script.

### Validation Steps

```bash
# 1. Copy trained model to MinIO
mc cp --recursive /mnt/beegfs/models/smollm-135m-sft \
     minio/models/

# 2. Verify GPU operator
kubectl get nodes -l nvidia.com/gpu.present=true

# 3. Deploy InferenceService
kubectl apply -f manifests/mlops/smollm-inference.yaml

# 4. Wait for ready (may take 2-3 minutes for model loading)
kubectl wait --for=condition=Ready \
  inferenceservice/smollm-text-generation --timeout=600s

# 5. Check GPU allocation
kubectl describe pod -l serving.kserve.io/inferenceservice=smollm-text-generation | grep -A 5 "Limits"

# 6. Test single inference
curl -X POST http://smollm-text-generation.default.svc.cluster.local/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Explain AI in simple terms:", "max_tokens": 50}'

# 7. Run load test
python scripts/mlops/load_test_smollm.py

# 8. Monitor GPU utilization
kubectl exec -it <pod-name> -- nvidia-smi dmon -s u -c 30
```

### Success Criteria

- [ ] InferenceService with GPU deployed
- [ ] GPU allocated to inference pod
- [ ] Inference produces coherent text
- [ ] P95 latency <500ms
- [ ] Throughput >10 req/s
- [ ] Autoscaling triggered by load
- [ ] GPU utilization >60%

### Performance Expectations

**Latency (P95):**

- Cold start (first request): 1-3 seconds
- Warm inference: 200-500ms
- Batch inference (4 requests): 300-600ms

**Throughput:**

- Single pod: 10-20 req/s
- With batching: 15-25 req/s
- 2 pods (scaled): 20-40 req/s

**GPU Utilization:**

- Idle: 5-10%
- Active inference: 60-80%
- Under load: 70-90%

### Optimization Options

**Model Optimization:**

- Quantization (INT8): 2-3x faster, <1% quality loss
- Flash Attention: 20-30% faster for long sequences
- Tensor parallelism: For larger models

**Serving Optimization:**

- Batch size tuning (4-16 depending on GPU memory)
- Max sequence length limiting
- KV cache optimization

**Example with quantization:**

```yaml
env:
- name: QUANTIZE
  value: "bitsandbytes-nf4"  # or "gptq", "awq"
```

### Monitoring

Key metrics to monitor in Grafana:

- Request latency (P50, P95, P99)
- Requests per second
- GPU utilization
- GPU memory usage
- Pod CPU/memory
- Queue depth (if requests are queuing)

---

## Category Summary

This category validates inference deployment on cloud cluster:

**MLOPS-4.1** establishes:

- KServe deployment workflow
- CPU-based inference serving
- Autoscaling based on load
- MinIO integration for model storage

**MLOPS-4.2** extends to:

- GPU-accelerated inference
- LLM serving with HuggingFace TGI
- GPU resource management in Kubernetes
- Production-grade inference performance

**Key Infrastructure Validated:**

- KServe: Model serving framework
- GPU Operator: GPU resource scheduling
- MinIO: Model artifact storage
- HPA: Horizontal Pod Autoscaling
- Prometheus/Grafana: Metrics and monitoring

**Performance Comparison:**

| Metric | CPU (MLOPS-4.1) | GPU (MLOPS-4.2) |
|--------|-----------------|-----------------|
| Latency (P95) | <100ms | <500ms |
| Throughput | 50-100 req/s | 10-20 req/s |
| Cost | Lower | Higher |
| Use Case | Simple models | LLMs, complex models |

**Next Steps:** Proceed to [Category 5: End-to-End Workflow](./category-5-e2e-workflow.md) to validate complete MLOps pipeline.

---

**Related Documentation:**

- [Prerequisites](./reference/prerequisites.md) - Cloud cluster requirements
- [Troubleshooting Guide](./reference/troubleshooting.md) - KServe and GPU issues
- **KServe Documentation**: https://kserve.github.io/
- **HuggingFace TGI**: https://huggingface.co/docs/text-generation-inference/
