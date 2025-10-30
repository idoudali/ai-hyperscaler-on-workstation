# MLOps Validation Prerequisites

This document outlines all prerequisites required to execute the MLOps validation tasks.

## Infrastructure Requirements

### HPC Cluster

**SLURM Configuration:**

- SLURM operational with GPU GRES support
- GPU GRES configured in `gres.conf` and `slurm.conf`
- Cgroup GPU isolation configured
- Job accounting enabled

**Storage:**

- BeeGFS mounted on all nodes at `/mnt/beegfs`
- Minimum 500GB available space
- Read/write access for training user
- Directory structure:
  - `/mnt/beegfs/datasets/` - Training datasets
  - `/mnt/beegfs/models/` - Model checkpoints
  - `/mnt/beegfs/scripts/` - Training scripts
  - `/mnt/beegfs/configs/` - Configuration files
  - `/mnt/beegfs/containers/` - Apptainer images
  - `/mnt/beegfs/jobs/` - Job output logs

**Container Runtime:**

- Apptainer installed on all compute nodes
- Version: 1.1.0 or later
- GPU support enabled (`--nv` flag works)

**Containers Required:**

- PyTorch container: `pytorch_24.07-py3.sif`
- Oumi container: `oumi_latest.sif` (or Oumi installed via pip)

**GPUs:**

- NVIDIA GPUs with CUDA support
- Minimum 2 GPUs for multi-GPU testing
- GPU drivers installed and functional
- `nvidia-smi` accessible from compute nodes

### Cloud Cluster

**Kubernetes:**

- Kubernetes cluster operational (v1.27+)
- `kubectl` configured and authenticated
- Network connectivity to cluster

**Installed Components:**

- **GPU Operator**: For GPU resource management
- **KServe**: Model serving framework (v0.11+)
- **MLflow**: Experiment tracking and model registry
- **MinIO**: S3-compatible object storage
- **Prometheus**: Metrics collection
- **Grafana**: Visualization and dashboards

**Namespaces:**

- `default`: Test deployments
- `production`: Production inference services
- `mlops`: MLflow and related tools
- `monitoring`: Prometheus and Grafana

**Storage:**

- MinIO accessible from pods
- Buckets created:
  - `models`: Model artifacts
  - `datasets`: Dataset storage (optional)

**Network:**

- Ingress controller for external access
- DNS configured for services:
  - `mlflow.cloud-cluster.local`
  - `grafana.cloud-cluster.local`
  - `minio.cloud-cluster.local`

### Network Configuration

**HPC Cluster:**

- Network: 192.168.100.0/24
- Controller: 192.168.100.10
- Compute nodes: 192.168.100.11+

**Cloud Cluster:**

- Network: 192.168.200.0/24
- Control plane: 192.168.200.10
- Worker nodes: 192.168.200.11+

**Connectivity:**

- SSH access from workstation to both clusters
- HPC and cloud clusters can reach each other (for model sync)
- Internet access for:
  - HuggingFace Hub downloads
  - Container image pulls
  - Package installations

**Bandwidth:**

- Minimum 10 Mbps for model transfers
- Recommended 100+ Mbps for efficiency

## Software Requirements

### Local Workstation

**Python Environment:**

- Python 3.11 or later
- `pip` or `uv` package manager

**Python Packages:**

```bash
pip install oumi[gpu]  # Oumi framework
pip install mlflow     # MLflow client
pip install requests   # API testing
pip install numpy      # Data processing
```

**CLI Tools:**

- `kubectl`: Kubernetes CLI
- `mc`: MinIO client
- `ssh`: SSH client with key authentication

**Optional:**

- `hey`: HTTP load testing
- `jq`: JSON processing
- `watch`: Command monitoring

### HPC Cluster (Per Compute Node)

**System Packages:**

- SLURM client tools (`sbatch`, `squeue`, `scontrol`)
- Apptainer/Singularity
- NVIDIA drivers
- CUDA toolkit (if building from source)

**Python Packages (in containers):**

- PyTorch 2.0+
- torchvision
- transformers (HuggingFace)
- Oumi framework
- MLflow client

### Cloud Cluster

**Kubernetes Resources:**

- GPU Operator CRDs
- KServe CRDs
- HPA (Horizontal Pod Autoscaler)

**Container Images:**

- PyTorch serving images
- HuggingFace Text Generation Inference (TGI)
- MLflow server image
- MinIO image

## Data Requirements

### Datasets

**Download to BeeGFS:**

**MNIST** (~50 MB):

```bash
python -c "from torchvision import datasets; datasets.MNIST('/mnt/beegfs/datasets/mnist', download=True)"
```

**CIFAR-10** (~170 MB):

```bash
python -c "from torchvision import datasets; datasets.CIFAR10('/mnt/beegfs/datasets/cifar10', download=True)"
```

**WikiText** (~200 MB):

```bash
# Downloaded automatically by HuggingFace datasets library
# Cache: /mnt/beegfs/huggingface/datasets
```

**no_robots** (~500 MB):

```bash
# Downloaded automatically by HuggingFace datasets library
# Cache: /mnt/beegfs/huggingface/datasets
```

**Total Dataset Storage:** ~1 GB

### Pre-trained Models

**SmolLM-135M** (~500 MB):

```bash
# Downloaded automatically from HuggingFace Hub
# Cache: /mnt/beegfs/huggingface/transformers
```

**GPT-2** (~500 MB):

```bash
# Downloaded automatically from HuggingFace Hub
# Cache: /mnt/beegfs/huggingface/transformers
```

**Total Model Storage:** ~1 GB

### HuggingFace Cache Configuration

Set environment variables on HPC cluster:

```bash
export HF_HOME=/mnt/beegfs/huggingface
export TRANSFORMERS_CACHE=/mnt/beegfs/huggingface/transformers
export HF_DATASETS_CACHE=/mnt/beegfs/huggingface/datasets
```

Add to SLURM job scripts for persistence.

## Authentication and Access

### SSH Keys

**HPC Cluster:**

```bash
# Generate SSH key if needed
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ai_how_cluster_key

# Copy to HPC controller
ssh-copy-id -i ~/.ssh/ai_how_cluster_key admin@192.168.100.10

# Test connection
ssh -i ~/.ssh/ai_how_cluster_key admin@192.168.100.10
```

**SSH Config:**

```
# ~/.ssh/config
Host hpc-cluster
    HostName 192.168.100.10
    User admin
    IdentityFile ~/.ssh/ai_how_cluster_key

Host cloud-cluster
    HostName 192.168.200.10
    User admin
    IdentityFile ~/.ssh/ai_how_cluster_key
```

### Kubernetes Access

```bash
# Copy kubeconfig from cloud cluster
scp admin@192.168.200.10:~/.kube/config ~/.kube/config-cloud

# Set KUBECONFIG
export KUBECONFIG=~/.kube/config-cloud

# Test access
kubectl get nodes
```

### MinIO Access

```bash
# Configure MinIO client
mc alias set minio http://minio.cloud-cluster.local:9000 <access-key> <secret-key>

# Test access
mc ls minio/models
```

### MLflow Access

MLflow server should be accessible at:

- From cluster: `http://mlflow.mlops.svc.cluster.local:5000`
- From workstation: `http://mlflow.cloud-cluster.local` (via ingress)

Test access:

```bash
curl http://mlflow.cloud-cluster.local/api/2.0/mlflow/experiments/list
```

## Verification Checklist

### HPC Cluster Verification

```bash
# Connect to HPC
ssh hpc-cluster

# Check SLURM
sinfo -o "%P %D %N %G"

# Check BeeGFS
df -h /mnt/beegfs
ls /mnt/beegfs

# Check GPUs
ssh compute01 "nvidia-smi"

# Check Apptainer
apptainer --version
ls /mnt/beegfs/containers/

# Check datasets
ls /mnt/beegfs/datasets/
```

### Cloud Cluster Verification

```bash
# Check Kubernetes
kubectl get nodes
kubectl get pods -A

# Check GPU operator
kubectl get nodes -l nvidia.com/gpu.present=true

# Check KServe
kubectl get crd | grep serving.kserve

# Check MLflow
curl http://mlflow.cloud-cluster.local/health

# Check MinIO
mc ls minio/

# Check Prometheus/Grafana
kubectl get pods -n monitoring
```

### Network Verification

```bash
# HPC to Cloud connectivity
ssh hpc-cluster "ping -c 3 192.168.200.10"

# Cloud to HPC connectivity
ssh cloud-cluster "ping -c 3 192.168.100.10"

# Internet access
ssh hpc-cluster "curl -I https://huggingface.co"
ssh cloud-cluster "curl -I https://huggingface.co"
```

## Estimated Resource Usage

### HPC Cluster

**During Training:**

- CPU: 4-8 cores per job
- Memory: 8-32GB per job
- GPU: 1-2 GPUs per job
- Storage: 10-50GB for models/checkpoints
- Network: 10-100 MB/s during downloads

### Cloud Cluster

**During Inference:**

- CPU: 1-2 cores per pod
- Memory: 2-16GB per pod
- GPU: 0-1 GPU per pod
- Storage: 5-20GB for cached models
- Network: 1-10 MB/s for inference traffic

### Total Storage Requirements

- Datasets: ~1 GB
- Pre-trained models: ~1 GB
- Training checkpoints: ~5 GB
- Evaluation results: ~1 GB
- Logs and metrics: ~1 GB
- **Total**: ~10 GB minimum, 20-50 GB recommended

---

**See Also:**

- [Troubleshooting Guide](./troubleshooting.md) - Common setup issues
- [Validation Matrix](./validation-matrix.md) - Infrastructure coverage
