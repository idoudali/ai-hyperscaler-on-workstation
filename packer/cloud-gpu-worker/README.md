# Cloud GPU Worker Packer Image

**Status:** Production
**Image Type:** GPU-Enabled Kubernetes Worker Node
**Base OS:** Debian 13 (Trixie)

## Overview

This Packer configuration creates a minimal GPU-enabled cloud worker image for Kubernetes deployments with NVIDIA drivers
pre-installed. The image includes only NVIDIA drivers - container toolkit, DCGM, and GPU device plugin are installed by
Kubespray and GPU Operator in Phase 2.

## Image Contents

**Base System:**

- Debian 13 (Trixie) with kernel 6.12+
- Cloud-init for automated provisioning
- SSH server with key-based authentication
- Essential system utilities (curl, wget, vim, htop)
- Python 3 for Ansible
- NetworkManager for network configuration

**NVIDIA GPU Drivers (drivers only):**

- NVIDIA driver (latest data center drivers)
- nvidia-smi for diagnostics
- Nouveau driver blacklisted
- Kernel headers and DKMS for driver compilation

**NOT Included (installed in Phase 2 by Kubespray/GPU Operator):**

- ❌ Kubernetes packages (kubeadm, kubelet, kubectl)
- ❌ Container runtime (containerd, runc, CNI)
- ❌ NVIDIA Container Toolkit (installed by GPU Operator)
- ❌ DCGM/DCGM Exporter (installed by GPU Operator)
- ❌ GPU Device Plugin (installed by GPU Operator)
- ❌ Container runtime NVIDIA configuration (handled by GPU Operator)

## Prerequisites

Before building this image:

1. **Packer installed** (1.8.0+)
2. **QEMU/KVM available** on build system
3. **Ansible installed** for provisioning
4. **Internet access** for downloading Debian ISO and NVIDIA drivers

## Building the Image

### Using CMake (Recommended)

```bash
# Validate configuration
make run-docker COMMAND="cmake --build build --target validate-cloud-gpu-worker-packer"

# Build image
make run-docker COMMAND="cmake --build build --target build-cloud-gpu-worker-image"
```

### Using Packer Directly

```bash
# Navigate to this directory
cd packer/cloud-gpu-worker

# Initialize Packer
packer init .

# Validate configuration
packer validate cloud-gpu-worker.pkr.hcl

# Build image
packer build cloud-gpu-worker.pkr.hcl
```

## Output

**Image Location:** `build/packer/cloud-gpu-worker/cloud-gpu-worker/cloud-gpu-worker.qcow2`
**Expected Size:** ~5-7 GB
**Build Time:** ~30-45 minutes (includes NVIDIA driver compilation)

## Verification

After building, verify the image:

```bash
# Check image was created
ls -lh build/packer/cloud-gpu-worker/cloud-gpu-worker/cloud-gpu-worker.qcow2

# Inspect image
qemu-img info build/packer/cloud-gpu-worker/cloud-gpu-worker/cloud-gpu-worker.qcow2

# List filesystems
virt-filesystems -a build/packer/cloud-gpu-worker/cloud-gpu-worker/cloud-gpu-worker.qcow2

# Test boot (optional - note: nvidia-smi will fail without GPU passthrough)
qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -drive file=build/packer/cloud-gpu-worker/cloud-gpu-worker/cloud-gpu-worker.qcow2,format=qcow2 \
  -nographic
```

## Deployment

This image is designed for deployment as a GPU-enabled Kubernetes worker node:

1. **Kubernetes GPU Worker Node** - Run Kubespray with GPU worker role
2. **GPU-Accelerated Workloads** - Deploy ML/AI workloads with GPU support

### GPU Passthrough Requirements

For GPU functionality, the deployed VM requires:

- Host IOMMU enabled (`intel_iommu=on` or `amd_iommu=on` in host kernel)
- GPU bound to `vfio-pci` driver on host
- Proper PCI device isolation
- GPU PCI address passed to VM

### First Boot Configuration

The image uses cloud-init for first-boot configuration:

1. Set hostname via cloud-init
2. Configure network interfaces
3. Add SSH keys for access
4. Start Kubernetes services (via Kubespray)
5. Initialize GPU (via cloud-init runcmd)

### Example cloud-init User Data

```yaml
#cloud-config
hostname: k8s-gpu-worker-01

users:
  - name: admin
    ssh_authorized_keys:
      - ssh-rsa AAAAB3...your-key-here

runcmd:
  - systemctl enable containerd
  - systemctl start containerd
  - nvidia-smi -pm 1
  - systemctl start dcgm-exporter
```

## What's Included

### Services (Enabled)

- `ssh.service` - SSH access for remote management

### NVIDIA Driver Components

- NVIDIA driver modules installed (but modules won't load without physical GPU)
- nvidia-smi utility available
- Nouveau driver blacklisted in modprobe configuration
- Kernel headers and DKMS configured for driver updates

### System Configuration

- Nouveau driver blacklisted
- Essential networking tools installed
- Python 3 for Ansible provisioning
- Cloud-init for automated configuration

**Note:** Container runtime, Kubernetes, and NVIDIA Container Toolkit are installed by Kubespray and GPU Operator in
Phase 2 deployment.

## GPU Support Details

### NVIDIA Driver Version

This image installs the latest NVIDIA data center drivers compatible with Debian 13 (Trixie). The exact version
is determined at build time by the `nvidia-gpu-drivers` Ansible role.

**Why No CUDA in Base Image:**

- Different workloads need different CUDA versions (9.x through 12.x)
- CUDA toolkit adds 3-5GB per version to image size
- Containerized CUDA provides better flexibility and version management
- Driver supports forward compatibility with newer CUDA versions in containers

### Container GPU Access

**Note:** NVIDIA Container Toolkit is installed by GPU Operator in Phase 2, not during Packer build. After deployment:

```bash
# Test GPU access with Docker/containerd
ctr run --rm --gpus all docker.io/nvidia/cuda:12.0-base nvidia-smi

# Or with nerdctl (if installed)
nerdctl run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

### GPU Monitoring

**DCGM Exporter** is installed by GPU Operator in Phase 2 (not in Packer image). After deployment,
it provides Prometheus-compatible metrics:

```bash
# View GPU metrics
curl http://localhost:9400/metrics | grep dcgm
```

**nvidia-smi** for quick checks:

```bash
# Check GPU status
nvidia-smi

# Continuous monitoring
watch -n 1 nvidia-smi
```

## Customization

### GPU-Specific Ansible Roles

- `nvidia-gpu-drivers`: Edit GPU driver configuration and version
- `monitoring-stack`: Modify DCGM exporter settings

```bash
# Edit GPU worker playbook
vim ansible/playbooks/playbook-cloud-packer-gpu-worker.yml

# Edit NVIDIA drivers role
vim ansible/roles/nvidia-gpu-drivers/tasks/main.yml

# Rebuild image
make run-docker COMMAND="cmake --build build --target build-cloud-gpu-worker-image"
```

### Enabling CUDA in Base Image

By default, CUDA is **NOT** included (use containerized CUDA instead):

**Rationale:**

- Different workloads need different CUDA versions
- CUDA toolkit adds 3-5GB to image size
- Containerized CUDA is easier to update and more flexible

To enable CUDA in base image (not recommended):

```bash
# Edit playbook
vim ansible/playbooks/playbook-cloud-packer-gpu-worker.yml
# Change: nvidia_install_cuda: false → nvidia_install_cuda: true
```

### Changing Disk Size

Edit `CMakeLists.txt`:

```cmake
set(DISK_SIZE "40G")  # Default is 30G
```

## Troubleshooting

### Build Issues

#### GPU Driver Installation Fails

**Symptoms:** Ansible provisioning fails during NVIDIA driver installation

**Solutions:**

1. Check internet connectivity (drivers downloaded from NVIDIA)
2. Verify kernel headers are installed (`linux-headers-$(uname -r)`)
3. Review Ansible logs for specific errors
4. Check NVIDIA driver role configuration

#### DKMS Module Build Fails

**Symptoms:** NVIDIA DKMS module fails to compile

**Solutions:**

1. Ensure `build-essential` and kernel headers are installed
2. Check kernel version compatibility with driver version
3. Review `/var/log/dkms.log` for compilation errors

### Runtime Issues

#### nvidia-smi Not Found

**Symptoms:** `nvidia-smi: command not found` after boot

**Solutions:**

1. Verify NVIDIA driver installation completed successfully
2. Check `/usr/bin/nvidia-smi` exists in image
3. Review build logs for errors during provisioning

#### No GPU Detected

**Symptoms:** `nvidia-smi` shows "No devices were found"

**Solutions:**

1. **Verify GPU passthrough** is configured (PCI device passed to VM)
2. Check host IOMMU is enabled: `dmesg | grep -i iommu`
3. Verify GPU is bound to `vfio-pci` on host: `lspci -nnk | grep -A3 NVIDIA`
4. Check VM configuration includes GPU PCI device

#### Containerd Cannot Access GPU (After Phase 2 Deployment)

**Symptoms:** Containers cannot access GPU even with `--gpus` flag

**Solutions:**

1. Verify NVIDIA Container Toolkit is installed (by GPU Operator): `which nvidia-container-runtime`
2. Check containerd configuration: `cat /etc/containerd/config.toml | grep nvidia`
3. Restart containerd: `systemctl restart containerd`
4. Verify GPU Operator installed container toolkit: `kubectl get pods -n gpu-operator-resources`
5. Test with simple container: `ctr run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi`

**Note:** This is a Phase 2 issue - containerd and NVIDIA Container Toolkit are not in the Packer image.

## Performance Tuning

### GPU Performance Optimization

**Enable Persistence Mode** (recommended for production):

```bash
# Enable persistence mode
nvidia-smi -pm 1

# Make persistent across reboots
systemctl enable nvidia-persistenced
```

**Set GPU Clock Speeds:**

```bash
# Query supported clocks
nvidia-smi -q -d SUPPORTED_CLOCKS

# Set application clocks
nvidia-smi -ac <memory_clock>,<graphics_clock>
```

### Container Optimization

**Use GPU-Optimized Container Images:**

- Use official NVIDIA CUDA images from Docker Hub
- Specify CUDA version matching your workload requirements
- Use minimal base images when possible

## Design Decisions

### Data Center GPU Drivers

Latest stable NVIDIA data center drivers are installed:

- **Forward Compatibility**: Supports newer CUDA versions in containers
- **Stability**: Production-grade drivers for reliability
- **Long-term Support**: Extended maintenance and updates

### No CUDA in Base Image

CUDA libraries are intentionally **NOT** included:

1. **Flexibility**: Different workloads need different CUDA versions (9.x through 12.x)
2. **Size**: CUDA toolkit adds 3-5GB per version to image
3. **Updates**: Containerized CUDA updates don't require image rebuilds
4. **Compatibility**: Containers provide better version management

**Recommendation**: Use containerized CUDA with appropriate runtime flags

### Minimal Image Design - Drivers Only

This image includes only NVIDIA drivers, not the full GPU stack:

1. **Faster Build**: Driver-only installation takes ~15 minutes vs ~45 minutes for full stack
2. **Kubespray Alignment**: GPU Operator handles container toolkit and DCGM in Phase 2
3. **Consistency**: Ensures all GPU components come from GPU Operator (desired state)
4. **Flexibility**: Driver updates don't require full stack reinstallation

**What's NOT in the image:**

- ❌ NVIDIA Container Toolkit (installed by GPU Operator)
- ❌ DCGM/DCGM Exporter (installed by GPU Operator)
- ❌ GPU Device Plugin (installed by GPU Operator)
- ❌ Container runtime GPU configuration (handled by GPU Operator)

## Related Documentation

### GPU-Specific

- **GPU Drivers**: [ansible/roles/nvidia-gpu-drivers/README.md](../../ansible/roles/nvidia-gpu-drivers/README.md)
- **Container Runtime**: [ansible/roles/container-runtime/README.md](../../ansible/roles/container-runtime/README.md)
- **Monitoring Stack**: [ansible/roles/monitoring-stack/README.md](../../ansible/roles/monitoring-stack/README.md)

### General

- **Cloud Cluster Implementation Plan**: Available in `../../planning/implementation-plans/task-lists/cloud-cluster/`
- **Cloud Base Image**: [../cloud-base/README.md](../cloud-base/README.md)
- **Kubespray Documentation**: See design docs in `../../docs/design-docs/`

## GPU Reference

### Supported GPU Types

- NVIDIA A100 (80GB / 40GB)
- NVIDIA H100
- NVIDIA A30
- NVIDIA T4
- NVIDIA V100

### GPU Monitoring Commands

```bash
# Real-time monitoring
watch -n 1 nvidia-smi

# GPU processes
nvidia-smi pmon

# Detailed GPU info
nvidia-smi -q

# Prometheus metrics (DCGM exporter)
curl http://localhost:9400/metrics | grep dcgm
```

### Common GPU Metrics

**Key metrics to monitor:**

- `dcgm_gpu_utilization` - GPU utilization %
- `dcgm_fb_used` - GPU memory used (MB)
- `dcgm_gpu_temp` - GPU temperature (°C)
- `dcgm_power_usage` - Power consumption (W)
- `dcgm_sm_clock` - Streaming multiprocessor clock (MHz)
