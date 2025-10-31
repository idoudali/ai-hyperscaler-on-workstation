# GPU Quickstart

**Status:** Production  
**Last Updated:** 2025-10-31  
**Target Time:** 10-15 minutes  
**Prerequisites:** [Cluster Deployment Quickstart](quickstart-cluster.md) completed

## Overview

Configure GPU passthrough and run GPU-accelerated workloads in 10-15 minutes. This quickstart covers GPU detection,
PCIe passthrough configuration, and running your first GPU job on SLURM.

**What You'll Configure:**

- GPU passthrough for KVM VMs
- SLURM GRES (Generic Resource Scheduling)
- GPU-enabled compute nodes
- GPU job submission and monitoring

**Supported GPU Configurations:**

- Full GPU passthrough (entire GPU to one VM)
- NVIDIA MIG (Multi-Instance GPU) slices
- Multiple GPUs distributed across VMs

## Prerequisites Check

Before starting, ensure you have:

```bash
# Verify cluster is running
virsh list | grep running

# Verify SLURM is operational
ssh admin@192.168.190.10 sinfo

# Check for NVIDIA GPUs on host
lspci | grep -i nvidia
nvidia-smi
```

## Step 1: Detect Available GPUs (1 minute)

Use the GPU inventory script to scan your system:

```bash
# Run GPU detection
./scripts/system-checks/gpu_inventory.sh --show-summary --generate-yaml

# Save GPU configuration
./scripts/system-checks/gpu_inventory.sh --generate-yaml > config/gpu-config.yaml
```

**Expected Output:**

```text
=== GPU Summary ===
Found 1 NVIDIA GPU(s):
  GPU 0: NVIDIA GeForce RTX 3090
    - PCI Address: 0000:01:00.0
    - VRAM: 24576 MiB
    - IOMMU Group: 15
    - MIG Capable: No
    - MIG Mode: N/A
    - Driver: 535.129.03
    - Status: Available

PCIe Passthrough Configuration generated:
  - GPU device (0000:01:00.0) + Audio device (0000:01:00.1)
  - Ready for VM passthrough
```

**Note:** For NVIDIA Ampere GPUs (A100, A30), you can optionally enable MIG mode to create multiple vGPU slices:

```bash
# Enable MIG mode (Ampere only)
sudo nvidia-smi -i 0 -mig 1

# Create seven 1g.5gb instances
for i in {1..7}; do
  sudo nvidia-smi mig -i 0 -cgi 19 -C
done

# Verify MIG instances
nvidia-smi -L
```

## Step 2: Configure GPU Passthrough (2 minutes)

Edit your cluster configuration to enable GPU passthrough:

```bash
# Open cluster config
vi config/clusters/quickstart-cluster.yml

# Add GPU configuration to compute node
```

Add this to your compute node configuration:

```yaml
compute_nodes:
  - name: hpc-compute-01
    ip_address: 192.168.190.131
    cpu_cores: 6  # Increased for GPU workloads
    memory_gb: 16  # Increased for GPU workloads
    disk_gb: 50
    has_gpu: true  # Enable GPU
    pcie_passthrough:  # GPU passthrough config
      enabled: true
      devices:
        - pci_address: "0000:01:00.0"  # GPU device (from Step 1)
          device_type: "gpu"
          vendor_id: "0x10de"  # NVIDIA
          device_id: "0x2204"  # Device-specific
          iommu_group: 15
        - pci_address: "0000:01:00.1"  # Audio device
          device_type: "audio"
          vendor_id: "0x10de"
          device_id: "0x1aef"
          iommu_group: 15
    gres:  # SLURM GPU resource config
      - type: "gpu"
        name: "rtx3090"
        count: 1
        file: "/dev/nvidia0"
```

**Note:** Use the PCI addresses and device IDs from your `gpu-config.yaml` generated in Step 1.

## Step 3: Deploy GPU Compute Node (3-5 minutes)

Deploy the GPU-enabled compute node:

```bash
# Destroy existing compute node (if any)
ai-how vm destroy hpc-compute-01 --force

# Deploy GPU-enabled compute node
ai-how vm deploy hpc-compute-01 \
    --config config/clusters/quickstart-cluster.yml \
    --image build/packer/hpc-compute/output/hpc-compute.qcow2 \
    --enable-gpu

# Wait for VM to boot
sleep 90
```

**Expected Output:**

```text
Configuring PCIe passthrough for GPU...
  - GPU device: 0000:01:00.0 (IOMMU group 15)
  - Audio device: 0000:01:00.1 (IOMMU group 15)
VM 'hpc-compute-01' deployed successfully with GPU passthrough
```

## Step 4: Verify GPU in VM (1 minute)

SSH into the compute node and verify GPU is accessible:

```bash
# SSH to compute node
ssh admin@192.168.190.131

# Check GPU visibility
lspci | grep -i nvidia
nvidia-smi

# Verify CUDA
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
```

**Expected Output:**

```text
01:00.0 VGA compatible controller: NVIDIA Corporation GA102 [GeForce RTX 3090]
01:00.1 Audio device: NVIDIA Corporation GA102 High Definition Audio Controller

+-----------------------------------------------------------------------------+
| NVIDIA-SMI 535.129.03   Driver Version: 535.129.03   CUDA Version: 12.2   |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  GeForce RTX 3090    Off  | 00000000:01:00.0 Off |                  N/A |
| 30%   35C    P8    25W / 350W |      0MiB / 24576MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
```

## Step 5: Configure SLURM GRES (1 minute)

Update SLURM configuration to recognize the GPU:

```bash
# From controller node
ssh admin@192.168.190.10

# Edit gres.conf
sudo vi /etc/slurm/gres.conf

# Add GPU configuration:
# NodeName=hpc-compute-01 Name=gpu Type=rtx3090 File=/dev/nvidia0

# Edit slurm.conf to include GRES
sudo vi /etc/slurm/slurm.conf

# Ensure this line exists:
# GresTypes=gpu

# Update node definition to include GPU:
# NodeName=hpc-compute-01 ... Gres=gpu:rtx3090:1 State=UNKNOWN

# Restart SLURM services
sudo systemctl restart slurmctld
sudo systemctl restart slurmdbd
```

On compute node:

```bash
ssh admin@192.168.190.131

# Restart slurmd
sudo systemctl restart slurmd
```

## Step 6: Verify GPU Resources in SLURM (30 seconds)

```bash
# From controller
ssh admin@192.168.190.10

# Check node shows GPU
scontrol show node hpc-compute-01 | grep Gres

# Check partition with GPU
sinfo -o "%20N %10c %10m %25f %10G"
```

**Expected Output:**

```text
Gres=gpu:rtx3090:1

NODELIST             CPUS       MEMORY     AVAIL_FEATURES            GRES
hpc-compute-01       6          16000      (null)                    gpu:rtx3090:1
```

## Step 7: Submit GPU Job (1 minute)

Create and submit a GPU test job:

```bash
# From controller
cat > gpu-test-job.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=gpu-test
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
#SBATCH --time=00:05:00
#SBATCH --output=gpu-test-%j.out

echo "=== GPU Test Job ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "GPU Devices: $CUDA_VISIBLE_DEVICES"
echo

echo "=== nvidia-smi Output ==="
nvidia-smi

echo
echo "=== GPU Details ==="
nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free --format=csv

echo
echo "=== Simple CUDA Test ==="
# Run deviceQuery if available
if command -v deviceQuery &> /dev/null; then
    deviceQuery
else
    echo "deviceQuery not found (install CUDA samples to test)"
fi

echo
echo "=== Job completed successfully ==="
EOF

# Submit job
sbatch gpu-test-job.sh

# Monitor job
watch -n 2 'squeue; echo; sacct -j $(sacct | tail -1 | awk "{print \$1}")'
```

**Expected Output:**

```text
Submitted batch job 2
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
    2   compute gpu-test    admin  R       0:05      1 hpc-compute-01
```

## Step 8: Verify GPU Job Results (30 seconds)

```bash
# View job output
cat gpu-test-2.out
```

**Expected Output:**

```text
=== GPU Test Job ===
Job ID: 2
Node: hpc-compute-01
GPU Devices: 0

=== nvidia-smi Output ===
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 535.129.03   Driver Version: 535.129.03   CUDA Version: 12.2   |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  GeForce RTX 3090    Off  | 00000000:01:00.0 Off |                  N/A |
| 30%   42C    P0    60W / 350W |    125MiB / 24576MiB |      5%      Default |
+-------------------------------+----------------------+----------------------+

=== GPU Details ===
name, driver_version, memory.total [MiB], memory.free [MiB]
GeForce RTX 3090, 535.129.03, 24576, 24451

=== Job completed successfully ===
```

## ✅ Success!

You now have GPU-accelerated compute capabilities with:

- ✅ GPU passthrough configured for VMs
- ✅ SLURM GRES configured for GPU scheduling
- ✅ GPU-enabled compute node operational
- ✅ GPU jobs running successfully

## Next Steps

### Run ML/AI Workloads

```bash
# PyTorch GPU test
cat > pytorch-gpu-test.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=pytorch-gpu
#SBATCH --gres=gpu:1
#SBATCH --time=00:10:00

python3 << PYTHON
import torch
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA version: {torch.version.cuda}")
print(f"GPU count: {torch.cuda.device_count()}")
if torch.cuda.is_available():
    print(f"GPU name: {torch.cuda.get_device_name(0)}")
    # Simple tensor operation on GPU
    x = torch.rand(5, 3).cuda()
    print(f"Tensor on GPU: {x.device}")
PYTHON
EOF

sbatch pytorch-gpu-test.sh
```

### Deploy Multiple GPU Nodes

Edit your cluster config to add more GPU compute nodes:

```yaml
compute_nodes:
  - name: hpc-compute-01
    # ... existing GPU config
  - name: hpc-compute-02  # Second GPU node
    ip_address: 192.168.190.132
    cpu_cores: 6
    memory_gb: 16
    disk_gb: 50
    has_gpu: true
    pcie_passthrough:
      enabled: true
      devices:
        - pci_address: "0000:02:00.0"  # Different GPU
          device_type: "gpu"
          # ... config for second GPU
```

### Try Containerized GPU Workloads

See [Container Quickstart](quickstart-containers.md) to:

- Build GPU-enabled containers
- Run containerized ML training
- Use NGC (NVIDIA GPU Cloud) containers

### Multi-Node GPU Training

See [Distributed Training Tutorial](../tutorials/02-distributed-training.md) for:

- Multi-GPU parallel training
- Distributed PyTorch/TensorFlow
- MPI-based GPU communication

## GPU Monitoring

### Monitor GPU Usage

```bash
# Real-time GPU monitoring
watch -n 1 nvidia-smi

# GPU utilization over time
nvidia-smi dmon -s u -c 10

# GPU memory usage
nvidia-smi --query-gpu=memory.used,memory.free --format=csv -l 1
```

### SLURM GPU Tracking

```bash
# Show GPU allocation for running jobs
squeue --Format=JobID,Partition,Name,UserName,State,Gres,NodeList

# View GPU usage history
sacct --format=JobID,JobName,Partition,AllocGRES,State,ExitCode
```

## Troubleshooting

### GPU Not Visible in VM

**Issue:** `nvidia-smi` fails or shows no GPU

**Solution:**

```bash
# On host, verify IOMMU groups
for d in /sys/kernel/iommu_groups/*/devices/*; do
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s ' "$n"
    lspci -nns "${d##*/}"
done | grep -i nvidia

# Verify GPU is bound to vfio-pci driver
lspci -nnk -d 10de: | grep -A 3 "Kernel driver in use"

# Should show: Kernel driver in use: vfio-pci
```

### SLURM Not Scheduling GPU Jobs

**Issue:** Jobs pending with `(ReqNodeNotAvail, Reserved for maintenance)`

**Solution:**

```bash
# Check GRES configuration
scontrol show config | grep GresTypes

# Verify node GRES
scontrol show node hpc-compute-01 | grep Gres

# Check gres.conf
sudo cat /etc/slurm/gres.conf

# Ensure proper format:
# NodeName=hpc-compute-01 Name=gpu Type=rtx3090 File=/dev/nvidia0
```

### PCIe Passthrough Issues

**Issue:** VM fails to start with PCIe errors

**Solution:**

```bash
# Verify IOMMU is enabled
dmesg | grep -i iommu

# Check kernel boot parameters
cat /proc/cmdline | grep iommu

# Should include: intel_iommu=on iommu=pt (Intel)
# or: amd_iommu=on iommu=pt (AMD)

# If missing, add to GRUB:
sudo vi /etc/default/grub
# Add: GRUB_CMDLINE_LINUX="intel_iommu=on iommu=pt"
sudo update-grub
sudo reboot
```

For more troubleshooting:

- [GPU Debugging Guide](../troubleshooting/debugging-guide.md)
- [Common GPU Issues](../troubleshooting/common-issues.md)
- [PCIe Passthrough Validation](../../python/ai_how/docs/pcie-passthrough-validation.md)

## What's Next?

**Continue your GPU journey:**

- **[Container Quickstart](quickstart-containers.md)** - GPU containers (10 min)
- **[Distributed Training Tutorial](../tutorials/02-distributed-training.md)** - Multi-GPU training
- **[GPU Partitioning Tutorial](../tutorials/03-gpu-partitioning.md)** - MIG configuration

**Understand GPU architecture:**

- **[GPU Architecture](../architecture/gpu.md)** - GPU virtualization design
- **[SLURM GPU Scheduling](../architecture/slurm.md)** - GRES configuration
- **[Container GPU Access](../architecture/containers.md)** - GPU in containers

## Summary

In 10-15 minutes, you've:

1. ✅ Detected available GPUs on your system
2. ✅ Configured PCIe passthrough for GPU access
3. ✅ Deployed GPU-enabled compute node
4. ✅ Configured SLURM GRES for GPU scheduling
5. ✅ Submitted and ran GPU-accelerated job
6. ✅ Verified GPU functionality and monitoring

**Congratulations!** You now have a GPU-accelerated HPC cluster ready for ML training, inference, and scientific
computing workloads.
