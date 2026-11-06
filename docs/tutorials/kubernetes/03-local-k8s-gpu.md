# Tutorial: Running GPU Workloads on Local K3s

This tutorial walks you through running GPU workloads on a local k3s cluster.

## Prerequisites

- k3s cluster set up with GPU support (see [K3s Local Setup Guide](../../guides/k3s-local-setup.md))
- At least one GPU available
- kubectl configured to access the cluster

## Step 1: Verify GPU Availability

First, verify that GPUs are visible to Kubernetes:

```bash
# Check node GPU capacity
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPUS:.status.capacity.'nvidia\.com/gpu'

# Expected output:
# NAME          GPUS
# <hostname>    2
```

If GPUs are not visible, check the device plugin:

```bash
# Check device plugin status
kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds

# Check logs if needed
kubectl logs -n kube-system -l name=nvidia-device-plugin-ds
```

## Step 2: Run a Simple GPU Test

Create a test pod that uses a GPU:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  containers:
  - name: cuda-test
    image: nvidia/cuda:12.0.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
  restartPolicy: Never
EOF
```

Wait for the pod to run and check output:

```bash
# Wait for pod to complete
kubectl wait --for=condition=Ready pod/gpu-test --timeout=60s

# View output
kubectl logs gpu-test
```

You should see nvidia-smi output showing the GPU information.

## Step 3: Run a GPU Training Job

Create a simple PyTorch training job:

```bash
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: pytorch-training
spec:
  template:
    spec:
      containers:
      - name: trainer
        image: pytorch/pytorch:2.0.1-cuda12.1-cudnn8-runtime
        command:
        - python
        - -c
        - |
          import torch
          print(f"PyTorch version: {torch.__version__}")
          print(f"CUDA available: {torch.cuda.is_available()}")
          if torch.cuda.is_available():
              print(f"CUDA version: {torch.version.cuda}")
              print(f"GPU count: {torch.cuda.device_count()}")
              for i in range(torch.cuda.device_count()):
                  print(f"GPU {i}: {torch.cuda.get_device_name(i)}")
        resources:
          limits:
            nvidia.com/gpu: 1
      restartPolicy: Never
  backoffLimit: 3
EOF
```

Check the job status:

```bash
# Watch job status
kubectl get job pytorch-training -w

# View logs
kubectl logs job/pytorch-training
```

## Step 4: Deploy Slurm with GPU Support

Deploy Slurm compute nodes that can use GPUs:

```bash
# Deploy Slurm
make k3s-deploy-slurm

# Or manually
kubectl apply -f k8s-manifests/hpc-slurm/
```

Check that Slurm compute nodes are running:

```bash
# Check pods
kubectl get pods -n slurm

# Check GPU allocation
kubectl describe pod -n slurm -l app=slurm-compute | grep nvidia.com/gpu
```

## Step 5: Submit a GPU Job to Slurm

Access the Slurm controller and submit a GPU job:

```bash
# Get controller pod name
CONTROLLER=$(kubectl get pods -n slurm -l app=slurm-controller -o jsonpath='{.items[0].metadata.name}')

# Access controller
kubectl exec -it -n slurm $CONTROLLER -- bash

# Inside the controller, submit a GPU job
cat > /tmp/gpu-job.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=gpu-test
#SBATCH --gres=gpu:1
#SBATCH --output=/tmp/gpu-job-%j.out

nvidia-smi
python3 -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"
EOF

sbatch /tmp/gpu-job.sh
squeue
```

## Step 6: Monitor GPU Usage

Monitor GPU utilization across the cluster:

```bash
# Check GPU allocation in pods
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.containers[].resources.limits."nvidia.com/gpu") |
  "\(.metadata.namespace)/\(.metadata.name): " +
  "\(.spec.containers[].resources.limits."nvidia.com/gpu") GPU(s)"'

# Check node GPU capacity vs allocatable
kubectl describe node | grep -A 5 "nvidia.com/gpu"
```

## Step 7: Run Multiple GPU Workloads

With 2 GPUs, you can run 2 workloads simultaneously:

```bash
# Deploy first GPU workload
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-workload-1
spec:
  containers:
  - name: worker
    image: nvidia/cuda:12.0.0-base-ubuntu22.04
    command: ["sleep", "3600"]
    resources:
      limits:
        nvidia.com/gpu: 1
EOF

# Deploy second GPU workload
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-workload-2
spec:
  containers:
  - name: worker
    image: nvidia/cuda:12.0.0-base-ubuntu22.04
    command: ["sleep", "3600"]
    resources:
      limits:
        nvidia.com/gpu: 1
EOF

# Verify both pods are running
kubectl get pods -o wide
```

## Step 8: Clean Up

Remove test resources:

```bash
# Delete test pods
kubectl delete pod gpu-test gpu-workload-1 gpu-workload-2

# Delete training job
kubectl delete job pytorch-training

# Or delete all in namespace
kubectl delete all --all -n default
```

## Troubleshooting

### Pod Stuck in Pending

If a pod requesting GPU is stuck in Pending:

```bash
# Check pod events
kubectl describe pod <pod-name>

# Common issues:
# - Insufficient GPU resources (all GPUs allocated)
# - Node selector mismatch
# - Taint/toleration issues
```

### GPU Not Available in Pod

If GPU is not accessible inside pod:

```bash
# Check if GPU is actually allocated
kubectl describe pod <pod-name> | grep nvidia.com/gpu

# Check device plugin logs
kubectl logs -n kube-system -l name=nvidia-device-plugin-ds

# Verify NVIDIA runtime in containerd
kubectl exec -it <pod> -- nvidia-smi
```

### CUDA Not Available in PyTorch

If PyTorch reports CUDA not available:

1. **Check CUDA version compatibility:**

   ```bash
   kubectl exec -it <pod> -- nvidia-smi
   kubectl exec -it <pod> -- python -c "import torch; print(torch.version.cuda)"
   ```

2. **Use compatible PyTorch image:**

   ```yaml
   image: pytorch/pytorch:2.0.1-cuda12.1-cudnn8-runtime
   ```

## Next Steps

- [K3s Local Setup Guide](../../guides/k3s-local-setup.md) - Complete setup instructions
- [Local Storage PVC Guide](../../guides/local-storage-pvc.md) - Using persistent storage
- [Slurm Basics Tutorial](../slurm/08-slurm-basics.md) - Learn Slurm job submission

## Reference

- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
- [Kubernetes GPU Scheduling](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)
- [PyTorch Docker Images](https://hub.docker.com/r/pytorch/pytorch)
