# GPU Configuration Guide for HPC Cluster

This guide provides step-by-step instructions for discovering, configuring, and
validating GPU support in the HPC cluster using PCIe passthrough for discrete
NVIDIA GPUs.

## Overview

The project now supports PCIe GPU passthrough for direct hardware access in
virtual machines, providing near-native GPU performance without virtualization
overhead. This guide covers the complete workflow from GPU discovery to
validation.

### Quick Start Workflow

1. **Discover GPUs**: Run `./scripts/system-checks/gpu_inventory.sh`
2. **Update Configuration**: Copy generated YAML sections into `config/template-cluster.yaml`
3. **Validate**: Run configuration validation
4. **Deploy**: Start clusters with GPU support
5. **Test**: Validate GPU functionality in VMs

## Prerequisites

Before starting, ensure:

- Host system has IOMMU enabled in BIOS/UEFI
- Intel VT-d or AMD-Vi is supported and enabled
- NVIDIA GPUs are installed and visible to the host
- Host system meets the requirements from `check_prereqs.sh`

## 1. GPU Discovery and Inventory

### 1.1 Run GPU Inventory Script

The project includes a GPU inventory script that discovers all available GPUs
and their capabilities:

```bash
# Execute the GPU inventory script
./scripts/system-checks/gpu_inventory.sh

# Save complete output to file for reference
./scripts/system-checks/gpu_inventory.sh > gpu_inventory_report.txt

# The script generates three outputs:
# 1. Human-readable report printed to stdout
# 2. Global GPU inventory YAML section
# 3. VM PCIe passthrough configuration sections
# 4. All YAML sections saved to ./output/gpu_inventory.yaml
```

### 1.2 Expected Output Format

The script will provide three types of output:

1. **Human-readable inventory report**
2. **Global GPU inventory YAML** (for global.gpu_inventory section)
3. **VM PCIe passthrough configurations** (for individual compute nodes)

#### Human-Readable Report

```text
=== GPU Inventory Report ===
Generated: 2025-01-15 14:30:15

GPU 0:
  Model: NVIDIA A100 80GB PCIe
  PCI Address: 0000:65:00.0
  Vendor ID: 10de
  Device ID: 2684
  IOMMU Group: 1
  MIG Capable: Yes
  Driver: nvidia (version 535.129.03)
  Status: Available

GPU 1:
  Model: NVIDIA RTX 6000 Ada Generation
  PCI Address: 0000:ca:00.0
  Vendor ID: 10de
  Device ID: 1e36
  IOMMU Group: 4
  MIG Capable: No
  Driver: nvidia (version 535.129.03)
  Status: Available

=== Summary ===
Total GPUs: 2
MIG Capable: 1
Available for Passthrough: 2
```

#### Generated YAML Sections

The script also generates ready-to-use YAML configurations:

1. **Global GPU Inventory Section** (copy into global.gpu_inventory)
2. **VM PCIe Passthrough Configurations** (copy into individual compute nodes)

The script also saves all YAML output to `./output/gpu_inventory.yaml` for easy access.

### 1.3 Manual GPU Discovery

If the script is not available, you can manually gather GPU information:

```bash
# List all NVIDIA GPUs
lspci | grep -i nvidia

# Get detailed GPU information
lspci -v -s $(lspci | grep -i nvidia | cut -d' ' -f1)

# Check IOMMU groups
find /sys/kernel/iommu_groups/ -type l | sort -V

# Get vendor and device IDs
lspci -n | grep -i nvidia
```

## 2. Updating template-cluster.yaml Configuration

### 2.1 Using Generated YAML Sections

The `gpu_inventory.sh` script generates ready-to-use YAML configurations that you
can copy directly into your `config/template-cluster.yaml` file. This eliminates
manual configuration errors and ensures consistency.

### 2.2 Update Global GPU Inventory

Copy the **Global GPU Inventory YAML** section from the script output into the
`global.gpu_inventory` section of your `config/template-cluster.yaml`:

```yaml
# Example output from gpu_inventory.sh (copy the entire section)
global:
  gpu_inventory:
    # Host GPU inventory for reference and conflict detection
    devices:
      - id: "GPU-0"
        pci_address: "0000:65:00.0"
        model: "NVIDIA A100 80GB PCIe"
        vendor_id: "10de"
        device_id: "2684"
        iommu_group: 1
        mig_capable: true
      - id: "GPU-1"
        pci_address: "0000:ca:00.0"
        model: "NVIDIA RTX 6000 Ada Generation"
        vendor_id: "10de"
        device_id: "1e36"
        iommu_group: 4
        mig_capable: false
```

### 2.3 Configure Compute Nodes with GPU Passthrough

Copy the appropriate **VM PCIe Passthrough Configuration** sections from the
script output to your compute nodes. Each GPU should be assigned to only one VM.

Example for HPC compute nodes:

```yaml
clusters:
  hpc:
    compute_nodes:
      - cpu_cores: 8
        memory_gb: 16
        disk_gb: 200
        ip: "192.168.100.11"
        # Copy this section from gpu_inventory.sh output for GPU-0
        pcie_passthrough:
          enabled: true
          devices:
            - pci_address: "0000:65:00.0"
              device_type: "gpu"
              vendor_id: "10de"
              device_id: "2684"
              iommu_group: 1
      - cpu_cores: 8
        memory_gb: 16
        disk_gb: 200
        ip: "192.168.100.12"
        # Copy this section from gpu_inventory.sh output for GPU-1
        pcie_passthrough:
          enabled: true
          devices:
            - pci_address: "0000:ca:00.0"
              device_type: "gpu"
              vendor_id: "10de"
              device_id: "1e36"
              iommu_group: 4
```

### 2.4 Configure Cloud Worker Nodes with GPU Passthrough

Similarly, for Kubernetes worker nodes with GPU support:

```yaml
clusters:
  cloud:
    worker_nodes:
      gpu:
        - worker_type: "gpu"
          cpu_cores: 8
          memory_gb: 16
          disk_gb: 200
          ip: "192.168.200.12"
          # Copy appropriate section from gpu_inventory.sh output
          pcie_passthrough:
            enabled: true
            devices:
              - pci_address: "0000:65:00.0"
                device_type: "gpu"
                vendor_id: "10de"
                device_id: "2684"
                iommu_group: 1
```

**Important Notes:**

- Each GPU can only be assigned to one VM at a time
- Ensure no conflicts between HPC and cloud cluster GPU assignments
- Use the exact values from `gpu_inventory.sh` output to avoid configuration errors

### 2.5 Configuration Validation

After updating the configuration, validate it:

```bash
# Validate the cluster configuration
ai-how validate

# Check for specific GPU-related errors
ai-how validate 2>&1 | grep -i gpu

# Verify GPU configuration sections are properly formatted
yamllint config/template-cluster.yaml
```

## 3. Host System Preparation

### 3.1 PCIe Passthrough Prerequisites

Before starting the cluster, ensure the host system is properly configured:

```bash
# Run PCIe passthrough validation (when implemented)
./scripts/check_pcie_passthrough.sh

# Prepare PCIe devices for passthrough (when implemented)
sudo ./scripts/prepare_pcie_devices.sh
```

### 3.2 Manual Host Preparation

If the automated scripts are not available, manually prepare the system:

```bash
# 1. Enable IOMMU in kernel parameters
# Add to /etc/default/grub:
# GRUB_CMDLINE_LINUX="intel_iommu=on iommu=pt" # For Intel
# GRUB_CMDLINE_LINUX="amd_iommu=on iommu=pt"   # For AMD
sudo update-grub && sudo reboot

# 2. Load VFIO modules
sudo modprobe vfio-pci

# 3. Bind GPU to VFIO driver (example for GPU at 0000:65:00.0)
echo "0000:65:00.0" | sudo tee /sys/bus/pci/devices/0000:65:00.0/driver/unbind
echo "10de 2684" | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id
```

## 4. GPU Validation Testing

### 4.1 Start HPC Cluster with GPU Support

```bash
# Start the HPC cluster with GPU-enabled configuration
ai-how --verbose hpc start

# Check cluster status
ai-how hpc status
```

### 4.2 VM-Level GPU Validation

#### 4.2.1 Basic GPU Detection

Connect to each GPU-enabled compute node and verify GPU detection:

```bash
# Connect to compute node (adjust IP as needed)
ssh root@192.168.100.11

# Check if GPU is detected by the system
lspci | grep -i nvidia

# Verify GPU is visible to the kernel
ls -la /dev/nvidia*

# Check dmesg for GPU-related messages
dmesg | grep -i nvidia
```

Expected output should show:

- GPU device visible in `lspci`
- `/dev/nvidia0` device file exists
- No error messages in dmesg

#### 4.2.2 NVIDIA Driver Installation Validation

```bash
# Check if NVIDIA driver is loaded
lsmod | grep nvidia

# Verify nvidia-smi works
nvidia-smi

# Check GPU status and memory
nvidia-smi -q
```

Expected `nvidia-smi` output should show:

- GPU model and memory information
- Driver version
- No processes running initially
- Temperature and power readings

#### 4.2.3 CUDA Runtime Validation

```bash
# Check CUDA installation
nvcc --version

# Run CUDA device query (if available)
/usr/local/cuda/extras/demo_suite/deviceQuery

# Test basic CUDA functionality
cat > test_cuda.py << 'EOF'
import pycuda.driver as cuda
import pycuda.autoinit

print(f"CUDA device count: {cuda.Device.count()}")
for i in range(cuda.Device.count()):
    device = cuda.Device(i)
    print(f"Device {i}: {device.name()}")
    print(f"  Memory: {device.total_memory() // 1024**2} MB")
EOF

python3 test_cuda.py
```

### 4.3 Performance Validation

#### 4.3.1 GPU Memory Bandwidth Test

```bash
# Run memory bandwidth test (if available)
/usr/local/cuda/extras/demo_suite/bandwidthTest

# Alternative: Use nvidia-ml-py for memory testing
cat > memory_test.py << 'EOF'
import pynvml
pynvml.nvmlInit()
handle = pynvml.nvmlDeviceGetHandleByIndex(0)
info = pynvml.nvmlDeviceGetMemoryInfo(handle)
print(f"Total memory: {info.total // 1024**2} MB")
print(f"Free memory: {info.free // 1024**2} MB")
print(f"Used memory: {info.used // 1024**2} MB")
EOF

python3 memory_test.py
```

#### 4.3.2 Compute Performance Test

```bash
# Run a simple compute test
cat > compute_test.py << 'EOF'
import time
import pycuda.driver as cuda
import pycuda.autoinit
from pycuda.compiler import SourceModule
import numpy as np

# Simple vector addition kernel
mod = SourceModule("""
__global__ void vector_add(float *a, float *b, float *c, int n) {
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    if (idx < n) {
        c[idx] = a[idx] + b[idx];
    }
}
""")

vector_add = mod.get_function("vector_add")

# Test data
n = 1000000
a = np.random.randn(n).astype(np.float32)
b = np.random.randn(n).astype(np.float32)
c = np.zeros_like(a)

# GPU memory allocation
a_gpu = cuda.mem_alloc(a.nbytes)
b_gpu = cuda.mem_alloc(b.nbytes)
c_gpu = cuda.mem_alloc(c.nbytes)

# Copy to GPU
cuda.memcpy_htod(a_gpu, a)
cuda.memcpy_htod(b_gpu, b)

# Run kernel
start_time = time.time()
vector_add(a_gpu, b_gpu, c_gpu, np.int32(n), block=(256, 1, 1), grid=((n + 255) // 256, 1))
cuda.Context.synchronize()
end_time = time.time()

print(f"Vector addition of {n} elements completed in {end_time - start_time:.4f} seconds")
print("GPU compute test PASSED")
EOF

python3 compute_test.py
```

### 4.4 SLURM GPU Integration Validation

#### 4.4.1 SLURM GPU Resource Configuration

Verify SLURM can see and manage GPU resources:

```bash
# On the SLURM controller node
scontrol show node | grep -A 10 -B 5 Gres

# Check GPU resource configuration
sinfo -o "%N %G %C %m"

# Test GPU job submission
cat > gpu_test_job.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=gpu_test
#SBATCH --nodes=1
#SBATCH --gres=gpu:1
#SBATCH --time=00:05:00

nvidia-smi
echo "GPU job completed successfully"
EOF

sbatch gpu_test_job.sh

# Check job status
squeue
scontrol show job <job_id>
```

#### 4.4.2 Multi-GPU Job Testing

```bash
# Test both GPUs are accessible
cat > multi_gpu_test.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=multi_gpu_test
#SBATCH --nodes=2
#SBATCH --gres=gpu:1
#SBATCH --time=00:05:00

echo "Testing GPU on node $(hostname)"
nvidia-smi
EOF

sbatch multi_gpu_test.sh
```

## 5. Troubleshooting

### 5.1 Common Issues

#### 5.1.1 GPU Not Detected in VM

**Symptoms:**

- `lspci` doesn't show GPU
- `/dev/nvidia*` devices missing
- nvidia-smi fails

**Solutions:**

1. Verify IOMMU is enabled:

   ```bash
   dmesg | grep -i iommu
   ```

2. Check VFIO driver binding:

   ```bash
   lspci -k -s 0000:65:00.0  # Check driver
   ```

3. Verify VM XML configuration includes hostdev entry

#### 5.1.2 NVIDIA Driver Issues

**Symptoms:**

- nvidia-smi returns "No devices were found"
- Driver not loaded

**Solutions:**

1. Install NVIDIA drivers in guest VM:

   ```bash
   # For Ubuntu/Debian
   sudo apt update
   sudo apt install nvidia-driver-535
   sudo reboot
   ```

2. Check driver compatibility with GPU model

#### 5.1.3 SLURM GPU Not Recognized

**Symptoms:**

- sinfo doesn't show GPU resources
- GPU jobs fail to schedule

**Solutions:**

1. Check `/etc/slurm/gres.conf`:

   ```text
   NodeName=hpc-compute-01 Name=gpu File=/dev/nvidia0
   NodeName=hpc-compute-02 Name=gpu File=/dev/nvidia0
   ```

2. Restart SLURM services:

   ```bash
   sudo systemctl restart slurmd
   sudo systemctl restart slurmctld
   ```

### 5.2 Performance Issues

#### 5.2.1 Poor GPU Performance

**Diagnostics:**

- Compare performance with native host
- Check for virtualization overhead
- Verify CPU affinity and NUMA topology

**Solutions:**

- Ensure CPU pinning is configured
- Verify huge pages are enabled
- Check for resource contention

### 5.3 Debug Information Collection

When reporting issues, collect the following information:

```bash
# Host system information
./scripts/check_prereqs.sh > host_info.txt
./scripts/system-checks/gpu_inventory.sh > gpu_info.txt

# Copy the generated YAML file as well
cp output/gpu_inventory.yaml ./gpu_inventory_debug.yaml

# VM configuration
ai-how hpc status > cluster_status.txt

# GPU status in VMs
ssh root@192.168.100.11 'nvidia-smi -q' > vm_gpu_status.txt

# SLURM configuration
scontrol show config > slurm_config.txt
sinfo -a > slurm_nodes.txt
```

## 6. Next Steps

After successful GPU validation:

1. **Deploy GPU Workloads**: Test actual ML/AI workloads
2. **Monitor Performance**: Set up GPU monitoring and alerting
3. **Scale Configuration**: Add more compute nodes as needed
4. **Optimize Performance**: Tune VM and GPU configurations
5. **Automate Testing**: Create automated validation scripts

## References

- [NVIDIA GPU Passthrough Documentation](https://docs.nvidia.com/vgpu/)
- [KVM GPU Passthrough
  Guide](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [SLURM GPU Scheduling](https://slurm.schedmd.com/gres.html)
- [Project Design Document](docs/design-docs/hyperscaler-on-workstation.md)
- [Project Plan GPU
  Tasks](docs/design-docs/project-plan.md#phase-3-infrastructure-provisioning-and-resource-management)
