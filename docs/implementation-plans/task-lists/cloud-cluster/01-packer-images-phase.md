# Phase 1: Packer Images for Cloud Cluster

**Duration:** 1 week
**Tasks:** CLOUD-1.1, CLOUD-1.2
**Dependencies:** Phase 0 (Foundation)

## Overview

Create minimal Packer-based VM images for Kubernetes cloud cluster deployment. These images provide a clean foundation
for Kubespray to deploy Kubernetes. The cloud-base image is a minimal Debian system ready for Ansible provisioning.
The GPU worker image extends this with pre-installed NVIDIA drivers to accelerate GPU node provisioning.

**Important:** These images do NOT include Kubernetes packages (kubeadm, kubelet, kubectl) or container runtime.
Kubespray handles all Kubernetes installation in Phase 2. Images focus on:

- Minimal system preparation
- Networking and cloud-init configuration
- GPU drivers (GPU image only) - pre-installed to save deployment time
- Basic monitoring stack

---

## CLOUD-1.1: Create Cloud Base Packer Image

**Duration:** 2-3 days
**Priority:** HIGH
**Status:** Completed
**Dependencies:** CLOUD-0.1

### Objective

Build a minimal Debian-based cloud image with essential system tools and cloud-init configuration. This image provides
a clean foundation for Kubespray to install Kubernetes. The image is universal and can be deployed as either controller
or worker node.

### Directory Structure

```text
packer/cloud-base/
├── README.md                           # Image build documentation
├── cloud-base.pkr.hcl                  # Packer HCL configuration
├── setup-cloud-base.sh                 # VM setup script
├── cloud-base-user-data.yml            # Cloud-init configuration
└── ansible/
    └── cloud-base-packages.yml         # Package installation playbook
```

### Image Requirements

**Base System:**

- Debian 13 (Trixie) with kernel 6.12+
- Cloud-init for automated configuration
- SSH server with key-based auth
- Essential system utilities (curl, wget, vim, htop)
- Python 3 for Ansible
- NetworkManager for network configuration

**Monitoring:**

- Node Exporter for system metrics
- Prometheus integration ready

**NOT Included (Kubespray installs these in Phase 2):**

- ❌ Kubernetes packages (kubeadm, kubelet, kubectl)
- ❌ Container runtime (containerd)
- ❌ CNI plugins
- ❌ Kubernetes APT repositories

### Packer Configuration

```hcl
# packer/cloud-base/cloud-base.pkr.hcl
source "qemu" "cloud-base" {
  iso_url          = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.0.0-amd64-netinst.iso"
  iso_checksum     = "sha256:..."
  
  disk_size        = "20G"
  format           = "qcow2"
  accelerator      = "kvm"
  
  memory           = 4096
  cpus             = 4
  
  ssh_username     = "debian"
  ssh_password     = "debian"
  ssh_timeout      = "30m"
  
  output_directory = "output/packer/cloud-base"
  vm_name          = "cloud-base.qcow2"
  
  boot_wait        = "5s"
  boot_command     = [
    "<esc><wait>",
    "install <wait>",
    "auto=true <wait>",
    "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg <wait>",
    "<enter>"
  ]
}

build {
  sources = ["source.qemu.cloud-base"]
  
  # Install packages via Ansible
  provisioner "ansible" {
    playbook_file = "ansible/cloud-base-packages.yml"
  }
  
  # Run setup script
  provisioner "shell" {
    script = "setup-cloud-base.sh"
  }
  
  # Cloud-init configuration
  provisioner "file" {
    source      = "cloud-base-user-data.yml"
    destination = "/etc/cloud/cloud.cfg.d/99_ai-how.cfg"
  }
  
  # Cleanup
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo cloud-init clean"
    ]
  }
}
```

### Ansible Playbook

The image build uses `playbook-cloud-packer-base.yml`:

```yaml
# ansible/playbooks/playbook-cloud-packer-base.yml
---
- name: Cloud Base Packer Build
  hosts: all
  become: true
  gather_facts: true
  
  vars:
    packer_build: true
    install_monitoring_stack: true
  
  roles:
    - monitoring-stack          # Node exporter for system metrics

# Note: Kubernetes packages and container runtime are installed by Kubespray in Phase 2
```

### CMake Integration

```cmake
# Add to packer/CMakeLists.txt

add_custom_target(packer-cloud-base
    COMMAND ${PACKER_EXECUTABLE} build -force cloud-base.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/packer/cloud-base
    COMMENT "Building cloud-base Packer image (universal controller/worker)..."
)

add_custom_target(packer-cloud-validate
    COMMAND ${PACKER_EXECUTABLE} validate cloud-base.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/packer/cloud-base
    COMMENT "Validating cloud-base Packer configuration..."
)
```

### Build Commands

```bash
# Validate Packer configuration
make run-docker COMMAND="cmake --build build --target packer-cloud-validate"

# Build the universal cloud base image
make run-docker COMMAND="cmake --build build --target packer-cloud-base"
```

### Deliverables

- [x] Packer HCL configuration (`cloud-base.pkr.hcl`)
- [x] Ansible playbook for package installation
- [x] Setup script for system configuration
- [x] Cloud-init configuration
- [x] CMake targets for building and validation
- [x] Documentation (`packer/cloud-base/README.md`)

### Validation

```bash
# Check image was created
ls -lh packer/output/cloud-base/cloud-base.qcow2

# Verify image contents
virt-filesystems -a packer/output/cloud-base/cloud-base.qcow2
guestfish -a packer/output/cloud-base/cloud-base.qcow2 -i ls /

# Test boot
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -drive file=packer/output/cloud-base/cloud-base.qcow2,format=qcow2 \
  -nographic

# Verify essential packages installed
# (after VM boots)
dpkg -l | grep -E "python3|cloud-init"
systemctl status node-exporter
```

### Success Criteria

- [x] Image builds successfully within 20 minutes (minimal packages)
- [x] Image size is small (<3 GB)
- [x] Essential packages installed (Python3, cloud-init, curl, wget, vim)
- [x] Node exporter is installed (not started)
- [x] Cloud-init is properly configured
- [x] VM boots and is SSH-accessible
- [x] NetworkManager is configured
- [x] Image provides clean foundation for Kubespray deployment

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-003`

---

## CLOUD-1.2: Create GPU Worker Cloud Image

**Duration:** 2 days
**Priority:** HIGH
**Status:** Completed
**Dependencies:** CLOUD-1.1

### Objective

Create GPU-enabled worker image with NVIDIA drivers pre-installed to accelerate GPU worker deployment. This image
extends the minimal cloud-base with only GPU drivers. Kubernetes and container runtime installation is still
delegated to Kubespray in Phase 2.

### Rationale

**Why Pre-install NVIDIA Drivers:**

- Faster GPU worker provisioning (drivers pre-installed, ~15min savings)
- Consistent NVIDIA driver versions across GPU workers
- Reduces complexity during Kubernetes deployment
- NVIDIA driver installation requires kernel headers and compilation

**Note:** NVIDIA Container Toolkit and GPU Operator are installed by Kubespray/Kubernetes in Phase 2.

### Directory Structure

```text
packer/cloud-gpu-worker/
├── README.md                          # GPU worker image documentation
├── cloud-gpu-worker.pkr.hcl          # Packer HCL configuration
├── setup-gpu-worker.sh               # GPU-specific setup script
└── cloud-gpu-worker-user-data.yml    # Cloud-init configuration
```

### Image Requirements

Extends cloud-base image with:

**NVIDIA GPU Drivers:**

- NVIDIA driver (535.x series or newer)
- nvidia-smi for diagnostics
- Nouveau driver blacklisted
- Kernel headers and DKMS for driver compilation

**NOT Included (Installed in Phase 2):**

- ❌ NVIDIA Container Toolkit (installed by GPU Operator)
- ❌ DCGM/DCGM Exporter (installed by GPU Operator)
- ❌ GPU Device Plugin (installed by GPU Operator)
- ❌ Container runtime NVIDIA configuration (handled by GPU Operator)

### Packer Configuration

```hcl
# packer/cloud-gpu-worker/cloud-gpu-worker.pkr.hcl
source "qemu" "cloud-gpu-worker" {
  # Start from cloud-base image
  disk_image       = true
  iso_url          = "../output/cloud-base/cloud-base.qcow2"
  iso_checksum     = "none"
  
  disk_size        = "30G"  # Larger for GPU drivers
  format           = "qcow2"
  accelerator      = "kvm"
  
  memory           = 4096
  cpus             = 4
  
  ssh_username     = "debian"
  ssh_password     = "debian"
  ssh_timeout      = "30m"
  
  output_directory = "output/packer/cloud-gpu-worker"
  vm_name          = "cloud-gpu-worker.qcow2"
}

build {
  sources = ["source.qemu.cloud-gpu-worker"]
  
  # Install NVIDIA drivers and GPU support
  provisioner "ansible" {
    playbook_file = "../../ansible/playbooks/playbook-cloud-packer-gpu-worker.yml"
  }
  
  # Cloud-init configuration for GPU workers
  provisioner "file" {
    source      = "cloud-gpu-worker-user-data.yml"
    destination = "/etc/cloud/cloud.cfg.d/99_ai-how-gpu.cfg"
  }
  
  # Cleanup
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo cloud-init clean"
    ]
  }
}
```

### Ansible Playbook

The GPU worker image build uses `playbook-cloud-packer-gpu-worker.yml`:

```yaml
# ansible/playbooks/playbook-cloud-packer-gpu-worker.yml
---
- name: Cloud GPU Worker Packer Build
  hosts: all
  become: true
  gather_facts: true
  
  vars:
    packer_build: true
    gpu_enabled: true
    nvidia_install_drivers_only: true      # Only drivers, no toolkit/DCGM
    nvidia_install_cuda: false              # CUDA in containers
    nvidia_packer_build: true               # Suppress reboot warnings
  
  roles:
    - nvidia-gpu-drivers                    # NVIDIA drivers only

# Note: NVIDIA Container Toolkit, DCGM, and GPU Device Plugin are installed
#       by GPU Operator in Phase 2 (CLOUD-2.2)
```

### CMake Integration

```cmake
# Add to packer/CMakeLists.txt

add_custom_target(packer-cloud-gpu-worker
    COMMAND ${PACKER_EXECUTABLE} build -force cloud-gpu-worker.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/packer/cloud-gpu-worker
    DEPENDS packer-cloud-base
    COMMENT "Building cloud-gpu-worker Packer image with NVIDIA support..."
)

add_custom_target(packer-cloud-gpu-validate
    COMMAND ${PACKER_EXECUTABLE} validate cloud-gpu-worker.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/packer/cloud-gpu-worker
    COMMENT "Validating cloud-gpu-worker Packer configuration..."
)
```

### Build Commands

```bash
# Validate GPU worker configuration
make run-docker COMMAND="cmake --build build --target packer-cloud-gpu-validate"

# Build GPU worker image (requires cloud-base built first)
make run-docker COMMAND="cmake --build build --target packer-cloud-gpu-worker"
```

### Deliverables

- [x] GPU worker Packer configuration (`cloud-gpu-worker.pkr.hcl`)
- [x] GPU worker Ansible playbook (`playbook-cloud-packer-gpu-worker.yml`)
- [x] Cloud-init configuration for GPU workers
- [x] CMake build targets
- [x] Documentation (`packer/cloud-gpu-worker/README.md`)

### Success Criteria

- [x] Image builds successfully on top of cloud-base
- [x] Image size is reasonable (<6 GB with drivers)
- [x] NVIDIA drivers are installed
- [x] nvidia-smi executable is present
- [x] Nouveau driver is blacklisted
- [x] Kernel modules can be loaded (nvidia, nvidia-uvm)
- [x] Provides foundation for GPU Operator deployment in Phase 2

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-004`

---

## Phase Completion Checklist

- [x] CLOUD-1.1: Minimal cloud-base image created and validated
- [x] CLOUD-1.2: GPU worker image created and validated
- [x] Ansible playbooks implemented and tested
- [x] CMake targets created and functional
- [x] Images build successfully
- [x] Images boot and are SSH-accessible
- [x] Images provide clean foundation for Kubespray deployment
- [x] Documentation clearly states Kubernetes installation is in Phase 2
- [x] No Kubernetes packages or container runtime in images

## Next Phase

Proceed to [Phase 2: Kubernetes Deployment](02-kubernetes-phase.md)
