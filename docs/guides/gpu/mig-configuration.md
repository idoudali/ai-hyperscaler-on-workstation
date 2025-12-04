# NVIDIA MIG (Multi-Instance GPU) Configuration Guide

**Status:** Draft
**Last Updated:** 2025-12-04
**Related Tasks:** TASK-DOC-3.4, TASK-DOC-2.3

## 1. Overview

Multi-Instance GPU (MIG) is a feature available on NVIDIA Ampere and newer architectures (e.g., A100, A30) that
allows a single physical GPU to be partitioned into multiple isolated GPU instances. Each instance has its own
high-bandwidth memory, cache, and compute cores.

This guide covers:

1.  Driver Requirements
2.  Configuring MIG
3.  SLURM Integration
4.  MIG with Containers and Kubernetes
5.  MIG and Virtual Machines (Passthrough)

## 2. Driver Requirements

To support MIG, you must install the NVIDIA proprietary drivers (Data Center / Tesla drivers).

-   **Minimum Version:** 470.x or higher (535.x+ recommended for full feature support).
-   **Installation Method:** Use the project's Ansible role `nvidia-gpu-drivers`.

### Verifying Driver Installation

Run the following command to verify the driver version and GPU status:

```bash
nvidia-smi
```

Ensure the output shows a supported GPU (e.g., A100, A30) and a valid driver version.

## 3. Configuring MIG

### 3.1 Enable MIG Mode

MIG mode must be enabled on the physical GPU before instances can be created. **Note:** This requires a GPU reset
(or system reboot) if not already enabled.

```bash
# Enable MIG mode on GPU 0
sudo nvidia-smi -i 0 -mig 1

# Reset the GPU (if no processes are using it)
sudo nvidia-smi --gpu-reset -i 0
# OR Reboot the system
sudo reboot
```

### 3.2 List Available MIG Profiles

Different GPUs support different partitioning profiles (slices). To see what is available:

```bash
nvidia-smi mig --list-gpu-instance-profiles
```

Common profiles for A100-40GB:

-   `1g.5gb`: 7 instances (1 compute slice, 5GB memory each)
-   `2g.10gb`: 3 instances
-   `3g.20gb`: 2 instances
-   `7g.40gb`: 1 instance (Full GPU)

### 3.3 Create MIG Instances

You can create instances manually using `nvidia-smi`.

**Example: Create 7 instances of 1g.5gb**

```bash
# -i 0: Target GPU 0
# -cgi 19: Profile ID 19 (1g.5gb) - Check ID from list-gpu-instance-profiles
# -C: Create Compute Instances (required)
sudo nvidia-smi mig -i 0 -cgi 19 -C
```

**Example: Create mixed profiles**
(Note: Profiles must fit within the physical resources)

```bash
sudo nvidia-smi mig -i 0 -cgi 9,19,19 -C
```

### 3.4 Verify Configuration

```bash
nvidia-smi -L
```

Output should show UUIDs for "MIG Xg.Ygb Device".

## 4. SLURM Integration

To schedule jobs on MIG instances, SLURM must be configured to recognize them as GRES (Generic Resources).

### 4.1 `gres.conf` Configuration

The project's Ansible role `slurm-compute` includes a template for MIG detection. Ensure your `gres.conf`
(usually `/etc/slurm/gres.conf`) looks like this:

```conf
# Standard Physical GPU
# NodeName=compute-01 Name=gpu Type=a100 File=/dev/nvidia0

# MIG Instances
# Map specific MIG device files (created by driver) to SLURM GRES
NodeName=compute-01 Name=gpu Type=1g.5gb File=/dev/nvidia-caps/nvidia-cap1
NodeName=compute-01 Name=gpu Type=1g.5gb File=/dev/nvidia-caps/nvidia-cap2
# ...
```

**Note:** The `/dev/nvidia-caps/*` files or `/dev/nvidiaX` files for MIG instances depend on how the driver exposes
them. You may need to inspect `/proc/driver/nvidia/capabilities/` or use `nvidia-smi` to find the correct device
paths if not using standard `/dev/nvidiaX`.

### 4.2 `slurm.conf` Configuration

Define the GRES types in `slurm.conf`:

```conf
GresTypes=gpu
```

And in the Node definition:

```conf
NodeName=compute-01 ... Gres=gpu:a100:1,gpu:1g.5gb:7
```

### 4.3 Static vs. Dynamic MIG Configuration

**Question 1: Does the user need to slice the GPU manually and specify the configuration?**

**Answer: Yes, manual slicing is required.**

SLURM does **not** automatically create or destroy MIG instances. The administrator must:

1.  **Manually create MIG instances** before SLURM starts (see Section 3.3).
2.  **Configure `gres.conf`** to map the existing MIG instances to SLURM GRES resources.
3.  **Update `slurm.conf`** to declare the available GRES types and counts.

**Example Workflow:**

```bash
# Step 1: Create MIG instances manually (on compute node)
sudo nvidia-smi mig -i 0 -cgi 19,19,19,19,19,19,19 -C

# Step 2: Verify instances exist
nvidia-smi -L

# Step 3: Configure SLURM to recognize them (in gres.conf)
# NodeName=compute-01 Name=gpu Type=1g.5gb File=/dev/nvidia-caps/nvidia-cap1
# ... (repeat for each instance)

# Step 4: Restart SLURM daemon
sudo systemctl restart slurmd
```

**Question 2: Can SLURM do dynamic re-configuration of the GPU based on task requirements?**

**Answer: No, standard SLURM does not support dynamic MIG reconfiguration.**

SLURM treats MIG instances as **static resources** that exist independently of job requirements:

-   **Static Resource Model:** SLURM schedules jobs to available MIG instances that match the requested profile.
-   **No Automatic Repartitioning:** If a job requests `3g.20gb` but only `1g.5gb` instances are configured, the job
    will remain in `PENDING` state (or fail), even if the GPU could theoretically be repartitioned.
-   **Manual Reconfiguration Required:** To change the MIG geometry (e.g., switch from 7x `1g.5gb` to 2x `3g.20gb`),
    the administrator must:
    1.  Drain the compute node: `scontrol update NodeName=compute-01 State=DRAIN`
    2.  Wait for running jobs to complete.
    3.  Destroy existing instances: `sudo nvidia-smi mig -i 0 -dgi`
    4.  Create new instances: `sudo nvidia-smi mig -i 0 -cgi 9,9 -C`
    5.  Update `gres.conf` and `slurm.conf` to reflect new resource counts.
    6.  Restart `slurmd`: `sudo systemctl restart slurmd`
    7.  Resume the node: `scontrol update NodeName=compute-01 State=RESUME`

**Best Practice:** Choose a MIG configuration that matches your typical workload patterns. For example:

-   **High-density inference:** 7x `1g.5gb` instances
-   **Mixed workloads:** 3x `2g.10gb` instances
-   **Large model training:** 2x `3g.20gb` instances

**Note:** Some research projects are exploring dynamic MIG management with custom SLURM plugins, but this is not
part of standard SLURM and requires custom development.

## 5. MIG with Containers and Kubernetes

MIG instances can be exposed to Docker containers and Kubernetes pods, allowing multiple isolated containerized
workloads to share a single physical GPU.

**Question: Do we need special drivers for containers?**

**Answer: No special GPU drivers are needed.** You need the same NVIDIA Data Center drivers (470+) used for bare metal
MIG. However, you must install additional container runtime components.

### 5.1 Required Components

To use MIG with containers and Kubernetes, install:

1.  **NVIDIA Container Toolkit** (formerly nvidia-docker2)
    -   Enables GPU access from containers
    -   Version 1.7.0+ required for MIG support
    -   Installation: [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

2.  **Kubernetes NVIDIA GPU Device Plugin** (for Kubernetes only)
    -   Exposes MIG instances as schedulable resources
    -   Version 0.13.0+ required for MIG support
    -   Installation: [NVIDIA k8s Device Plugin](https://github.com/NVIDIA/k8s-device-plugin)

3.  **GPU Feature Discovery** (optional but recommended)
    -   Auto-labels nodes with GPU capabilities
    -   Simplifies pod scheduling
    -   Installation: [GPU Feature Discovery](https://github.com/NVIDIA/gpu-feature-discovery)

### 5.2 Docker with MIG

After creating MIG instances (Section 3), you can assign specific slices to containers.

**Example: Run container on specific MIG instance**

```bash
# List MIG device UUIDs
nvidia-smi -L

# Run container with first MIG slice (using UUID)
docker run --rm --gpus '"device=MIG-<uuid>"' nvidia/cuda:11.0-base nvidia-smi

# Or use index-based notation (MIG device 0)
docker run --rm --gpus '"device=0"' nvidia/cuda:11.0-base nvidia-smi
```

**Example: Docker Compose**

```yaml
version: '3.8'
services:
  inference-service:
    image: nvidia/cuda:11.0-base
    environment:
      - NVIDIA_VISIBLE_DEVICES=MIG-<uuid>
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ['MIG-<uuid>']
              capabilities: [gpu]
```

### 5.3 Kubernetes with MIG

Kubernetes can schedule pods to specific MIG instances using resource requests.

**Step 1: Enable MIG Mode on Worker Nodes**

```bash
# On each GPU worker node, enable MIG and create instances
sudo nvidia-smi -i 0 -mig 1
sudo nvidia-smi --gpu-reset -i 0
sudo nvidia-smi mig -i 0 -cgi 19,19,19,19,19,19,19 -C
```

**Step 2: Configure Device Plugin**

Deploy the NVIDIA device plugin with MIG strategy:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin-ds
  template:
    metadata:
      labels:
        name: nvidia-device-plugin-ds
    spec:
      containers:
      - name: nvidia-device-plugin-ctr
        image: nvcr.io/nvidia/k8s-device-plugin:v0.14.0
        env:
          - name: MIG_STRATEGY
            value: "single"  # Options: single, mixed
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        volumeMounts:
          - name: device-plugin
            mountPath: /var/lib/kubelet/device-plugins
      volumes:
        - name: device-plugin
          hostPath:
            path: /var/lib/kubelet/device-plugins
```

**MIG Strategy Options:**

-   `single`: Each MIG instance is a separate resource (e.g., `nvidia.com/gpu: 1` requests one MIG slice)
-   `mixed`: Both full GPUs and MIG instances available (use resource names like `nvidia.com/mig-1g.5gb: 1`)

**Step 3: Deploy Workload**

Request MIG resources in pod specification:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mig-test-pod
spec:
  containers:
  - name: cuda-container
    image: nvidia/cuda:11.0-base
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1  # With "single" strategy, requests one MIG slice
        # OR with "mixed" strategy:
        # nvidia.com/mig-1g.5gb: 1
```

**Step 4: Verify Assignment**

```bash
# Check pod allocation
kubectl describe pod mig-test-pod

# Inside the pod, verify MIG access
kubectl exec -it mig-test-pod -- nvidia-smi -L
```

### 5.4 Assigning Different MIG Slices to Different Containers

**Question: Can we assign different MIG slices to different containers?**

**Answer: Yes, each container/pod can be assigned a specific MIG instance.**

**Docker Example (Multiple Containers):**

```bash
# Terminal 1: Container using MIG slice 0
docker run --rm --gpus '"device=0"' --name inference1 nvidia/cuda:11.0-base nvidia-smi

# Terminal 2: Container using MIG slice 1
docker run --rm --gpus '"device=1"' --name inference2 nvidia/cuda:11.0-base nvidia-smi

# Terminal 3: Container using MIG slice 2
docker run --rm --gpus '"device=2"' --name training1 nvidia/cuda:11.0-base nvidia-smi
```

Each container sees only its assigned MIG slice as "GPU 0" and is isolated from other slices.

**Kubernetes Example (Multiple Pods):**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: inference-pod-1
spec:
  nodeSelector:
    nvidia.com/gpu.product: A100-SXM4-40GB
  containers:
  - name: inference
    image: my-inference-image:latest
    resources:
      limits:
        nvidia.com/mig-1g.5gb: 1
---
apiVersion: v1
kind: Pod
metadata:
  name: training-pod-1
spec:
  nodeSelector:
    nvidia.com/gpu.product: A100-SXM4-40GB
  containers:
  - name: training
    image: my-training-image:latest
    resources:
      limits:
        nvidia.com/mig-3g.20gb: 1
```

Kubernetes scheduler assigns pods to nodes with available MIG resources, ensuring isolation between workloads.

### 5.5 Best Practices for Container/K8s MIG Usage

1.  **Resource Planning:**
    -   Define MIG profiles based on typical container workload requirements
    -   Consider using smaller slices (1g.5gb) for inference, larger (3g.20gb) for training

2.  **Node Labeling:**
    -   Use GPU Feature Discovery to auto-label nodes with MIG capabilities
    -   Apply custom labels for workload-specific scheduling

3.  **Monitoring:**
    -   Use DCGM Exporter to expose per-MIG-instance metrics to Prometheus
    -   Monitor utilization to optimize slice allocation

4.  **Static Configuration:**
    -   Like SLURM, Kubernetes does not dynamically reconfigure MIG
    -   Plan your MIG geometry before deploying workloads
    -   Drain and reconfigure nodes manually if workload patterns change

### 5.6 References

-   [NVIDIA Container Toolkit Documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/overview.html)
-   [Kubernetes Device Plugin for NVIDIA GPUs](https://github.com/NVIDIA/k8s-device-plugin)
-   [MIG Support in Kubernetes](https://docs.nvidia.com/datacenter/cloud-native/kubernetes/mig-k8s.html)
-   [GPU Feature Discovery](https://github.com/NVIDIA/gpu-feature-discovery)

## 6. MIG and Virtual Machines

There are two primary ways to use MIG with VMs:

### 6.1 Full Passthrough + Internal MIG (Recommended for Workstations)

Pass the **entire physical GPU** to the VM using PCIe Passthrough (`vfio-pci`). Inside the VM, install the NVIDIA
drivers and configure MIG exactly as you would on bare metal.

**Requirements:**

-   Host: IOMMU enabled, `vfio-pci` bound to GPU.
-   VM: Full PCI device attached (`<hostdev mode='subsystem' type='pci'>`).
-   Guest: NVIDIA Drivers installed.

### 6.2 MIG Slice Passthrough (vGPU)

Pass a **single MIG slice** to a VM.

**Requirements:**

1.  **NVIDIA vGPU Software License:** Required for vGPU functionality.
2.  **Host Driver:** NVIDIA vGPU Manager (not the standard datacenter driver).
3.  **Virtualization:**
    -   MIG instances are exposed as **Mediated Devices (mdev)**, not standard PCI devices.
    -   QEMU/Libvirt must use `<hostdev mode='subsystem' type='mdev'>`.
    -   The current project templates (`compute_node.xml.j2`) support `type='pci'` (Standard Passthrough). To
        support MIG-vGPU, templates must be updated to support `mdev`.

**Installation and Configuration:**

To enable vGPU functionality with MIG slices, follow these steps:

1.  **Obtain NVIDIA vGPU License:**
    -   vGPU software requires an NVIDIA vGPU license subscription.
    -   Contact NVIDIA or an authorized partner to obtain licensing.
    -   See: [NVIDIA vGPU Software](https://www.nvidia.com/en-us/data-center/virtual-solutions/)

2.  **Install vGPU Manager (Host):**
    -   Download the vGPU Manager package from the NVIDIA Licensing Portal.
    -   Follow the installation guide for your hypervisor:
        -   [NVIDIA vGPU Installation Guide](https://docs.nvidia.com/grid/latest/grid-vgpu-user-guide/index.html)
        -   [KVM/QEMU Setup](https://docs.nvidia.com/grid/latest/grid-vgpu-user-guide/index.html#kvm-setup)

3.  **Configure MIG-backed vGPU:**
    -   Enable MIG mode and create instances (as shown in Section 3).
    -   Create mdev devices for each MIG instance:

        ```bash
        # List available mdev types for MIG instances
        ls /sys/class/mdev_bus/*/mdev_supported_types
        
        # Create mdev device (example for first MIG instance)
        uuidgen > /sys/class/mdev_bus/0000:01:00.0/mdev_supported_types/nvidia-<type>/create
        ```

    -   See: [MIG-Backed vGPU Guide](https://docs.nvidia.com/grid/latest/grid-vgpu-user-guide/index.html#mig-backed-vgpus)

4.  **Attach mdev to VM:**
    -   Update VM XML configuration to use `mdev` instead of `pci`:

        ```xml
        <hostdev mode='subsystem' type='mdev' managed='no' model='vfio-pci'>
          <source>
            <address uuid='<mdev-uuid>'/>
          </source>
        </hostdev>
        ```

    -   Or use `virsh attach-device` with mdev configuration.

5.  **Install vGPU Guest Driver (VM):**
    -   Download the vGPU Guest Driver from NVIDIA Licensing Portal.
    -   Install inside the VM following the guest driver installation guide.
    -   Verify with `nvidia-smi` inside the VM.

**Important Notes:**

-   This method is **not currently supported** by the project's standard Ansible roles and VM templates.
-   Requires manual configuration of mdev devices and VM XML templates.
-   Licensing costs and management overhead make this approach more suitable for enterprise deployments.
-   For most workstation/lab setups, **Method 6.1 (Full GPU Passthrough)** is recommended.

**Conclusion:** For this project's current setup (Standard Linux Drivers + Standard PCI Passthrough),
**Method 6.1 (Full Passthrough)** is the supported path for using MIG in VMs. Method 6.2 requires additional licensing
and infrastructure changes.

## 7. References

-   [NVIDIA MIG User Guide](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/)
-   [NVIDIA Multi-Instance GPU (MIG) Architecture](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/index.html)
-   [Slurm GRES Documentation](https://slurm.schedmd.com/gres.html)
