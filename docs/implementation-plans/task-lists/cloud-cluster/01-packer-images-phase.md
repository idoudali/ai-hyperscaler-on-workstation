# Phase 1: Packer Images for Cloud Cluster

**Duration:** 1 week
**Tasks:** CLOUD-1.1, CLOUD-1.2
**Dependencies:** Phase 0 (Foundation)

## Overview

Create Packer-based VM images optimized for Kubernetes cloud cluster deployment. The base image includes all
prerequisites for Kubespray deployment, while specialized images provide optional optimizations for specific node types.

---

## CLOUD-1.1: Create Cloud Base Packer Image

**Duration:** 2-3 days
**Priority:** HIGH
**Status:** Not Started
**Dependencies:** CLOUD-0.1

### Objective

Build Debian-based cloud base image with Kubernetes prerequisites, container runtime, and cloud-init for automated
provisioning.

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
- Standard system utilities

**Container Runtime:**

- Containerd 1.7.23+
- CNI plugins
- runc runtime

**Kubernetes Components:**

- kubeadm, kubelet, kubectl (not started, just installed)
- Kubernetes APT repository configured

**GPU Support (conditional):**

- NVIDIA container toolkit
- NVIDIA driver dependencies (not driver itself)

**Networking:**

- Bridge utilities
- IPTables/NFTables
- Network policy prerequisites

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

### CMake Integration

```cmake
# Add to packer/CMakeLists.txt

add_custom_target(packer-cloud-base
    COMMAND ${PACKER_EXECUTABLE} build -force cloud-base.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/packer/cloud-base
    COMMENT "Building cloud-base Packer image..."
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
cmake --build build --target packer-cloud-validate

# Build the image
cmake --build build --target packer-cloud-base

# Or using Docker container
make run-docker COMMAND="cmake --build build --target packer-cloud-base"
```

### Deliverables

- [ ] Packer HCL configuration (`cloud-base.pkr.hcl`)
- [ ] Ansible playbook for package installation
- [ ] Setup script for system configuration
- [ ] Cloud-init configuration
- [ ] CMake targets for building and validation
- [ ] Documentation (`packer/cloud-base/README.md`)

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

# Verify packages installed
# (after VM boots)
dpkg -l | grep -E "containerd|kubeadm|kubectl"
```

### Success Criteria

- [ ] Image builds successfully within 30 minutes
- [ ] Image size is reasonable (<5 GB)
- [ ] All required packages are installed
- [ ] Cloud-init is properly configured
- [ ] VM boots and is SSH-accessible
- [ ] Containerd runtime is functional

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-003`

---

## CLOUD-1.2: Create Specialized Cloud Images

**Duration:** 2 days
**Priority:** MEDIUM
**Status:** Not Started
**Dependencies:** CLOUD-1.1

### Objective

Create optional specialized images for GPU workers with NVIDIA drivers pre-installed to reduce deployment time.

### Rationale

**Why Specialized Images:**

- Faster GPU worker provisioning (drivers pre-installed)
- Consistent NVIDIA driver versions across cluster
- Reduced Ansible execution time during cluster deployment

**Why Optional:**

- Base image + Ansible configuration works fine
- Specialized images add maintenance overhead
- Driver updates require image rebuilds

### GPU Worker Image

```text
packer/cloud-gpu-worker/
├── README.md
├── cloud-gpu-worker.pkr.hcl
├── setup-gpu-worker.sh
└── ansible/
    └── install-nvidia-drivers.yml
```

**Additional Components:**

- NVIDIA driver (535.x series)
- CUDA toolkit (optional, can be containerized)
- NVIDIA container runtime
- GPU monitoring tools (nvidia-smi)

### Packer Configuration

```hcl
# packer/cloud-gpu-worker/cloud-gpu-worker.pkr.hcl
source "qemu" "cloud-gpu-worker" {
  # Start from cloud-base image
  disk_image       = true
  iso_url          = "../output/cloud-base/cloud-base.qcow2"
  iso_checksum     = "none"
  
  disk_size        = "25G"
  format           = "qcow2"
  
  output_directory = "output/packer/cloud-gpu-worker"
  vm_name          = "cloud-gpu-worker.qcow2"
}

build {
  sources = ["source.qemu.cloud-gpu-worker"]
  
  # Install NVIDIA drivers
  provisioner "ansible" {
    playbook_file = "ansible/install-nvidia-drivers.yml"
  }
  
  # Configure GPU settings
  provisioner "shell" {
    script = "setup-gpu-worker.sh"
  }
}
```

### CMake Integration

```cmake
# Add to packer/CMakeLists.txt

add_custom_target(packer-cloud-gpu-worker
    COMMAND ${PACKER_EXECUTABLE} build -force cloud-gpu-worker.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/packer/cloud-gpu-worker
    DEPENDS packer-cloud-base
    COMMENT "Building cloud-gpu-worker Packer image..."
)
```

### Deliverables

- [ ] GPU worker Packer configuration
- [ ] NVIDIA driver installation playbook
- [ ] GPU configuration script
- [ ] CMake build target
- [ ] Documentation

### Decision Point

Before implementing, evaluate:

**Pros:**

- ~10 minutes faster GPU worker deployment
- Known-good driver configuration

**Cons:**

- Additional image to maintain
- Driver updates require rebuild
- Larger image size

**Recommendation:** **Optional** - Start with base image + Ansible. Create specialized image only if deployment
time becomes a bottleneck.

### Success Criteria (if implemented)

- [ ] Image builds on top of cloud-base
- [ ] NVIDIA drivers are functional
- [ ] nvidia-smi works in booted VM
- [ ] Container runtime recognizes GPU

### Reference

Full specification: `docs/design-docs/cloud-cluster-oumi-inference.md#task-cloud-004`

---

## Phase Completion Checklist

- [ ] CLOUD-1.1: Cloud base image created and validated
- [ ] CLOUD-1.2: Specialized images evaluated (and created if needed)
- [ ] CMake targets functional
- [ ] Images tested with VM provisioning
- [ ] Documentation complete

## Next Phase

Proceed to [Phase 2: Kubernetes Deployment](02-kubernetes-phase.md)
