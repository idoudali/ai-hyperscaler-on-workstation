# MLOps Validation Troubleshooting Guide

This document provides solutions to common issues encountered during MLOps validation tasks.

## HPC Cluster Issues

### SLURM Job Failures

**Issue: "Unable to allocate resources"**

Symptoms:

- Job remains in queue indefinitely
- `squeue` shows job in `PD` (pending) state
- Error: `Resources currently unavailable`

Solutions:

```bash
# 1. Check GPU availability
sinfo -o "%P %D %N %G"

# 2. Check GPU GRES configuration
scontrol show node | grep -A 20 Gres

# 3. Verify node state
scontrol show node compute01

# 4. Check if GPUs are actually present
ssh compute01 "nvidia-smi"

# 5. Restart SLURM if needed
ssh hpc-cluster "sudo systemctl restart slurmd" # on compute nodes
ssh hpc-cluster "sudo systemctl restart slurmctld" # on controller
```

Common causes:

- GPUs not configured in `gres.conf`
- Node is in `DRAIN` or `DOWN` state
- All GPUs already allocated to other jobs

**Issue: Job starts but GPU not available**

Symptoms:

- `torch.cuda.is_available()` returns `False`
- Training runs on CPU instead of GPU

Solutions:

```bash
# 1. Check GRES allocation in job
squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R %b"

# 2. Verify --gres flag in sbatch script
grep "gres" scripts/mlops/*.sbatch

# 3. Check cgroup GPU isolation
ssh compute01 "cat /sys/fs/cgroup/devices/slurm/uid_*/job_*/devices.list | grep nvidia"

# 4. Verify GPU passthrough in container
apptainer exec --nv <container> nvidia-smi
```

**Issue: "Job exceeded memory limit"**

Symptoms:

- Job killed with `OUT_OF_MEMORY` error
- `scontrol show job` shows `State=OUT_OF_MEMORY`

Solutions:

```bash
# 1. Increase memory allocation
#SBATCH --mem=32G  # or higher

# 2. Enable gradient checkpointing (for LLMs)
# In config.yaml:
training:
  gradient_checkpointing: true

# 3. Reduce batch size
# In config.yaml:
training:
  per_device_train_batch_size: 2  # reduce from 4 or 8
```

### BeeGFS Issues

**Issue: "Permission denied" on BeeGFS**

Solutions:

```bash
# 1. Check BeeGFS mount
df -h /mnt/beegfs
mount | grep beegfs

# 2. Check permissions
ls -ld /mnt/beegfs
ls -l /mnt/beegfs/scripts

# 3. Fix permissions if needed
sudo chown -R admin:admin /mnt/beegfs/scripts
sudo chmod -R 755 /mnt/beegfs/scripts
```

**Issue: "Slow BeeGFS performance"**

Symptoms:

- Data loading very slow
- Training I/O bound

Solutions:

```bash
# 1. Check BeeGFS bandwidth
beegfs-ctl --serverstats

# 2. Increase DataLoader workers
# In training script:
DataLoader(dataset, num_workers=4, pin_memory=True)

# 3. Cache datasets in memory if possible
# Or copy to local /tmp first
```

### Apptainer Container Issues

**Issue: "Container not found"**

Solutions:

```bash
# 1. Check container exists
ls -lh /mnt/beegfs/containers/

# 2. Pull container if missing
cd /mnt/beegfs/containers
apptainer pull docker://nvcr.io/nvidia/pytorch:24.07-py3

# 3. Convert to SIF if needed
apptainer build pytorch_24.07-py3.sif docker://nvcr.io/nvidia/pytorch:24.07-py3
```

**Issue: "GPU not accessible in container"**

Solutions:

```bash
# 1. Ensure --nv flag is used
apptainer exec --nv <container> nvidia-smi

# 2. Check NVIDIA driver binding
apptainer exec --nv <container> nvidia-smi --query-gpu=driver_version --format=csv

# 3. Verify GPU device files
ls -l /dev/nvidia*
```

## Oumi Framework Issues

**Issue: "Oumi cannot connect to cluster"**

Symptoms:

- `oumi cluster test` fails
- SSH connection errors

Solutions:

```bash
# 1. Test SSH connection manually
ssh -i ~/.ssh/ai_how_cluster_key admin@192.168.100.10

# 2. Check SSH key permissions
chmod 600 ~/.ssh/ai_how_cluster_key

# 3. Add to SSH config
cat >> ~/.ssh/config << EOF
Host hpc-cluster
    HostName 192.168.100.10
    User admin
    IdentityFile ~/.ssh/ai_how_cluster_key
EOF

# 4. Test Oumi connection
oumi cluster test ai-how-hpc --verbose
```

**Issue: "Oumi job submission fails"**

Solutions:

```bash
# 1. Check cluster config
oumi cluster show ai-how-hpc

# 2. Verify paths in config
# All paths must be absolute and exist on cluster
ssh hpc-cluster "ls /mnt/beegfs/containers"

# 3. Check SLURM from Oumi perspective
oumi cluster exec ai-how-hpc "sinfo"
```

**Issue: "HuggingFace model download fails"**

Symptoms:

- `Connection timeout` or `SSL error`
- Downloads very slow or hang

Solutions:

```bash
# 1. Test internet connectivity
ssh hpc-cluster "curl -I https://huggingface.co"

# 2. Set HuggingFace cache on BeeGFS
export HF_HOME=/mnt/beegfs/huggingface

# 3. Pre-download models
python -c "from transformers import AutoModel; AutoModel.from_pretrained('HuggingFaceTB/SmolLM-135M', cache_dir='/mnt/beegfs/huggingface')"

# 4. Use local mirror if available
export HF_ENDPOINT=http://local-mirror.example.com
```

## Cloud Cluster Issues

### KServe Deployment Issues

**Issue: "InferenceService not becoming ready"**

Symptoms:

- `kubectl get inferenceservice` shows status not `Ready`
- Pods crash or fail to start

Solutions:

```bash
# 1. Check pod status
kubectl get pods -l serving.kserve.io/inferenceservice=<name>

# 2. Check pod logs
kubectl logs <pod-name>

# 3. Check events
kubectl describe inferenceservice <name>

# 4. Check resource availability
kubectl describe node | grep -A 5 "Allocated resources"

# Common issues:
# - Model not found in storage
# - Insufficient memory/GPU
# - Image pull errors
```

**Issue: "Model not found in storage"**

Solutions:

```bash
# 1. Verify model in MinIO
mc ls minio/models/

# 2. Check storage URI in manifest
kubectl get inferenceservice <name> -o yaml | grep storageUri

# 3. Test model accessibility from pod
kubectl run test-pod --image=alpine --rm -it -- \
  wget -O- http://minio.default.svc.cluster.local:9000/models/model.pt

# 4. Re-sync model if needed
./scripts/mlops/sync_model_to_cloud.sh
```

**Issue: "Inference returns errors"**

Solutions:

```bash
# 1. Check predictor logs
kubectl logs -l component=predictor

# 2. Test with simple request
curl -X POST http://<service>/v1/models/<model>:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [...]}'

# 3. Check model format matches runtime
# PyTorch models need PyTorch runtime
# HuggingFace models need TGI or similar
```

### GPU Allocation Issues

**Issue: "GPU not allocated to inference pod"**

Solutions:

```bash
# 1. Check GPU operator
kubectl get nodes -l nvidia.com/gpu.present=true

# 2. Verify GPU resource in manifest
grep -A 3 "resources:" manifests/mlops/*.yaml

# 3. Check node labels and taints
kubectl describe node | grep -A 5 "Labels"
kubectl describe node | grep -A 5 "Taints"

# 4. Check GPU availability
kubectl describe node <gpu-node> | grep "nvidia.com/gpu"
```

**Issue: "Poor GPU inference performance"**

Solutions:

```bash
# 1. Check GPU utilization
kubectl exec -it <pod-name> -- nvidia-smi dmon -s u

# 2. Enable batch inference
# In InferenceService env:
- name: MAX_BATCH_SIZE
  value: "4"

# 3. Optimize model
# Consider quantization, TensorRT, or model optimization
```

### MLflow Issues

**Issue: "Cannot register model in MLflow"**

Solutions:

```bash
# 1. Check MLflow server
curl http://mlflow.cloud-cluster.local/health

# 2. Test API access
curl http://mlflow.cloud-cluster.local/api/2.0/mlflow/experiments/list

# 3. Check model path accessibility
# MLflow must be able to read model from path

# 4. Use S3 URI instead of file path
mlflow.register_model(
    model_uri="s3://models/model-path",
    name="model-name"
)
```

**Issue: "MLflow metrics not showing"**

Solutions:

```bash
# 1. Verify tracking URI
echo $MLFLOW_TRACKING_URI

# 2. Check experiment exists
curl http://mlflow.cloud-cluster.local/api/2.0/mlflow/experiments/list

# 3. Enable autologging
# In training script:
import mlflow
mlflow.pytorch.autolog()
```

## Network and Connectivity Issues

**Issue: "HPC and Cloud clusters cannot communicate"**

Solutions:

```bash
# 1. Test connectivity
ssh hpc-cluster "ping -c 3 192.168.200.10"
ssh cloud-cluster "ping -c 3 192.168.100.10"

# 2. Check routing
ssh hpc-cluster "ip route"
ssh cloud-cluster "ip route"

# 3. Check firewall rules
ssh hpc-cluster "sudo iptables -L -n"
ssh cloud-cluster "sudo iptables -L -n"
```

**Issue: "Model sync fails between clusters"**

Solutions:

```bash
# 1. Test MinIO access from HPC
ssh hpc-cluster "mc ls minio/models"

# 2. Check MinIO credentials
mc config host ls

# 3. Use alternative sync method
# rsync via SSH instead of MinIO client
rsync -avz /mnt/beegfs/models/model/ \
  admin@192.168.200.10:/path/to/models/
```

## Performance Issues

**Issue: "Training slower than expected"**

Diagnostics:

```bash
# 1. Check GPU utilization
nvidia-smi dmon -s u

# 2. Check I/O bottlenecks
iostat -x 1

# 3. Profile training
# Add to training script:
from torch.profiler import profile, ProfilerActivity
with profile(activities=[ProfilerActivity.CPU, ProfilerActivity.CUDA]) as prof:
    # training step
print(prof.key_averages().table())
```

Common causes and solutions:

- **Low GPU utilization**: Increase batch size
- **High I/O wait**: Use more DataLoader workers, cache data
- **CPU bottleneck**: Reduce preprocessing, use pin_memory

**Issue: "Inference latency too high"**

Solutions:

```bash
# 1. Enable model optimization
# TensorRT for NVIDIA
# ONNX Runtime
# Model quantization

# 2. Batch requests
# Configure MAX_BATCH_SIZE

# 3. Warm up model
# Send dummy requests after deployment

# 4. Check network latency
kubectl exec <pod> -- ping <service>
```

## Data and Model Issues

**Issue: "Dataset download fails"**

Solutions:

```bash
# 1. Check disk space
df -h /mnt/beegfs

# 2. Download manually
python << EOF
from torchvision import datasets
datasets.MNIST('/mnt/beegfs/datasets/mnist', download=True)
EOF

# 3. Use mirror or local copy
# Set up local dataset mirror
```

**Issue: "Model checkpoint corrupted"**

Symptoms:

- `RuntimeError: Error loading state_dict`
- `Checkpoint format invalid`

Solutions:

```bash
# 1. Verify checkpoint file
ls -lh /mnt/beegfs/models/*/checkpoint.pt

# 2. Test loading
python << EOF
import torch
checkpoint = torch.load('/mnt/beegfs/models/model.pt')
print(checkpoint.keys())
EOF

# 3. Retrain if necessary
sbatch scripts/mlops/training.sbatch
```

---

**Quick Reference Commands**

```bash
# HPC Cluster Debug
ssh hpc-cluster "sinfo; squeue; nvidia-smi"

# Cloud Cluster Debug
kubectl get nodes,pods,svc,inferenceservice -A

# Check all logs
ssh hpc-cluster "tail -100 /mnt/beegfs/jobs/*.err"
kubectl logs -l app=<service> --tail=100

# Resource usage
ssh hpc-cluster "df -h; free -h; nvidia-smi"
kubectl top nodes; kubectl top pods

# Connectivity
ping 192.168.100.10; ping 192.168.200.10
curl http://mlflow.cloud-cluster.local/health
```

---

**See Also:**

- [Prerequisites](./prerequisites.md) - Setup requirements
- [Validation Matrix](./validation-matrix.md) - Infrastructure coverage
