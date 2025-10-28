# Cloud Base Packer Image

**Status:** Production
**Image Type:** Universal Kubernetes Node (Controller or Worker)
**Base OS:** Debian 13 (Trixie)

## Overview

This Packer configuration creates a universal cloud base image suitable for both Kubernetes controller and worker
nodes. The image includes all prerequisites for Kubernetes cluster deployment via Kubespray.

## Image Contents

**Base System:**

- Debian 13 (Trixie) with kernel 6.12+
- Cloud-init for automated provisioning
- SSH server with key-based authentication
- Essential system utilities (vim, htop, tmux, net-tools)

**Container Runtime:**

- Containerd 1.7.23+ with systemd cgroup driver
- CNI plugins for network management
- runc container runtime

**Kubernetes Components:**

- kubeadm, kubelet, kubectl (installed but not started)
- Kubernetes APT repository configured
- Kernel parameters configured for Kubernetes

**Networking:**

- IP forwarding enabled
- Bridge netfilter enabled
- IPTables/NFTables configured
- Network policy prerequisites

**Monitoring:**

- Prometheus node exporter for metrics collection

## Prerequisites

Before building this image:

1. **Packer installed** (1.8.0+)
2. **QEMU/KVM available** on build system
3. **Ansible installed** for provisioning
4. **Internet access** for downloading Debian ISO

## Building the Image

### Using CMake (Recommended)

```bash
# Validate configuration
make run-docker COMMAND="cmake --build build --target packer-cloud-validate"

# Build image
make run-docker COMMAND="cmake --build build --target packer-cloud-base"
```

### Using Packer Directly

```bash
# Navigate to this directory
cd packer/cloud-base

# Initialize Packer
packer init .

# Validate configuration
packer validate cloud-base.pkr.hcl

# Build image
packer build cloud-base.pkr.hcl
```

## Output

**Image Location:** `output/packer/cloud-base/cloud-base.qcow2`
**Expected Size:** ~4-5 GB
**Build Time:** ~20-30 minutes

## Verification

After building, verify the image:

```bash
# Check image was created
ls -lh ../../output/packer/cloud-base/cloud-base.qcow2

# Inspect image
qemu-img info ../../output/packer/cloud-base/cloud-base.qcow2

# List filesystems
virt-filesystems -a ../../output/packer/cloud-base/cloud-base.qcow2

# Test boot (optional)
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -drive file=../../output/packer/cloud-base/cloud-base.qcow2,format=qcow2 \
  -nographic
```

## Deployment

This image can be deployed as:

1. **Kubernetes Controller Node** - Run Kubespray with controller role
2. **Kubernetes Worker Node (CPU)** - Run Kubespray with worker role
3. **Base for GPU Worker** - Extend with GPU support (see cloud-gpu-worker)

### First Boot Configuration

The image uses cloud-init for first-boot configuration:

1. Set hostname via cloud-init
2. Configure network interfaces
3. Add SSH keys for access
4. Start Kubernetes services (via Kubespray)

### Example cloud-init User Data

```yaml
#cloud-config
hostname: k8s-controller-01

users:
  - name: admin
    ssh_authorized_keys:
      - ssh-rsa AAAAB3...your-key-here

runcmd:
  - systemctl enable containerd
  - systemctl start containerd
```

## What's Included

### Services (Enabled but not Started)

- `containerd.service` - Container runtime
- `prometheus-node-exporter.service` - Metrics collection
- `ssh.service` - SSH access

### Kernel Modules (Loaded on Boot)

- `br_netfilter` - Bridge netfilter support
- `overlay` - Overlay filesystem for containers

### System Configuration

- Swap disabled (required for Kubernetes)
- IP forwarding enabled
- Bridge netfilter enabled
- Systemd cgroup driver configured for containerd

## Customization

### Modifying the Image

To customize the image, edit:

1. **`cloud-base.pkr.hcl`** - Packer configuration
2. **`setup-cloud-base.sh`** - System setup script
3. **`cloud-base-user-data.yml`** - Cloud-init defaults
4. **`../../ansible/playbooks/playbook-cloud-packer-base.yml`** - Ansible provisioning

### Adding Packages

Add packages in the Ansible playbook (`cloud-base-packages` role) rather than in shell scripts.

## Troubleshooting

### Build Fails with SSH Timeout

- Increase `ssh_wait_timeout` in `cloud-base.pkr.hcl`
- Check QEMU/KVM is working: `kvm-ok`
- Verify network connectivity in build environment

### Ansible Provisioning Fails

- Run with extra verbosity: `PACKER_LOG=1 packer build cloud-base.pkr.hcl`
- Check Ansible playbook syntax: `ansible-playbook --syntax-check playbook-cloud-packer-base.yml`
- Verify all required Ansible roles exist

### Image Too Large

- Check for leftover package caches
- Verify cleanup steps run successfully
- Use `virt-sparsify` to reduce image size:

```bash
virt-sparsify --compress ../../output/packer/cloud-base/cloud-base.qcow2 cloud-base-sparse.qcow2
```

## Related Documentation

- Note: Cloud Cluster Implementation Plan is available in `../../planning/implementation-plans/task-lists/cloud-cluster/`
- Note: Kubespray Documentation (see design docs in `../../docs/design-docs/`)
- [Ansible Playbook Documentation](../../ansible/playbooks/README.md)

## See Also

- **[cloud-gpu-worker](../cloud-gpu-worker/README.md)** - GPU-enabled worker image
- **[Cloud Base Packages Role](../../ansible/roles/cloud-base-packages/README.md)** - Package installation
- **[Container Runtime Role](../../ansible/roles/container-runtime/README.md)** - Containerd configuration
