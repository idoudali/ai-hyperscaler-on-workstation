# Virtio-FS Host Directory Sharing Integration

## Overview

This document describes the implementation of Virtio-FS (Virtio Filesystem) host directory sharing in the AI-HOW
HPC infrastructure. Virtio-FS enables seamless, high-performance file sharing between the host system and
virtual machines without the overhead of network-based solutions like NFS.

**Task:** TASK-027 - Implement Virtio-FS Host Directory Sharing  
**Status:** Implemented  
**Date:** 2025-10-15

## What is Virtio-FS?

Virtio-FS is a shared filesystem that lets virtual machines access a directory tree on the host. It is designed
specifically for virtual machines and offers:

- **High Performance**: Near-native I/O performance (>1GB/s typical)
- **Low Latency**: Direct memory access without network stack overhead
- **POSIX Compliance**: Full POSIX filesystem semantics
- **Zero Configuration**: No IP addresses, NFS exports, or network setup required
- **Security**: File operations run with host user permissions

## Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│ Host System                                                      │
│                                                                  │
│  ┌──────────────────┐                                           │
│  │ Host Directory   │                                           │
│  │ /host/datasets   │                                           │
│  └────────┬─────────┘                                           │
│           │                                                      │
│           │ virtiofs                                            │
│           │                                                      │
│  ┌────────▼─────────────────────────────────────────────────┐   │
│  │ QEMU/KVM (virtiofsd daemon)                              │   │
│  └────────┬─────────────────────────────────────────────────┘   │
│           │                                                      │
│           │ virtio-fs device                                    │
│           │                                                      │
│  ┌────────▼─────────────────────────────────────────────────┐   │
│  │ HPC Controller VM                                         │   │
│  │                                                            │   │
│  │  ┌──────────────────┐                                     │   │
│  │  │ Mount Point      │                                     │   │
│  │  │ /mnt/datasets    │ ◄─── virtiofs filesystem driver    │   │
│  │  └──────────────────┘                                     │   │
│  │                                                            │   │
│  │  Files appear as local filesystem                         │   │
│  │  Direct access, no network overhead                       │   │
│  └────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. VM Template Configuration

**File:** `python/ai_how/src/ai_how/vm_management/templates/controller.xml.j2`

The libvirt VM template includes virtio-fs filesystem device configuration:

```xml
{% if virtio_fs_mounts is defined and virtio_fs_mounts|length > 0 %}
<!-- Virtio-FS Host Directory Sharing -->
{% for mount in virtio_fs_mounts %}
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs' queue='1024'/>
  <source dir='{{ mount.host_path }}'/>
  <target dir='{{ mount.tag }}'/>
  {% if mount.readonly | default(false) %}
  <readonly/>
  {% endif %}
</filesystem>
{% endfor %}
{% endif %}
```

### 2. Ansible Role: virtio-fs-mount

**Location:** `ansible/roles/virtio-fs-mount/`

This role handles the guest-side configuration of virtio-fs mounts:

- **defaults/main.yml**: Default configuration values
- **tasks/main.yml**: Main role tasks (package installation, kernel module loading)
- **tasks/setup-mounts.yml**: Mount point creation, filesystem mounting, fstab persistence

**Key Features:**

- Installs required packages (fuse3, util-linux)
- Loads virtiofs kernel module
- Creates mount point directories
- Mounts virtio-fs filesystems
- Adds entries to /etc/fstab for persistence
- Sets proper permissions and ownership

### 3. Runtime Configuration Playbook

**File:** `ansible/playbooks/playbook-virtio-fs-runtime-config.yml`

This playbook applies virtio-fs configuration to running VMs:

```yaml
vars:
  packer_build: false
  virtio_fs_perform_mounts: true
  virtio_fs_mounts:
    - tag: "datasets"
      mount_point: "/mnt/host-datasets"
      readonly: false
      owner: "admin"
      group: "admin"
      mode: "0755"
```

### 4. Test Framework

**Location:** `tests/test-virtio-fs-framework.sh`

Complete test framework following the standard pattern:

**Test Suites:**

- `check-virtio-fs-config.sh`: Configuration validation (kernel modules, packages, fstab)
- `check-mount-functionality.sh`: Mount operations (read/write, permissions, persistence)
- `check-performance.sh`: Performance benchmarks (sequential I/O, random I/O, metadata operations)

## Configuration

### Cluster Configuration

To enable virtio-fs mounts on an HPC controller, add the `virtio_fs_mounts` section to your cluster configuration:

```yaml
clusters:
  hpc:
    controller:
      cpu_cores: 4
      memory_gb: 8
      disk_gb: 30
      ip_address: "192.168.100.10"
      
      # Virtio-FS host directory sharing
      virtio_fs_mounts:
        - tag: "datasets"              # Unique tag for this mount
          host_path: "/data/ml-datasets"  # Host directory to share
          mount_point: "/mnt/host-datasets"  # Guest mount point
          readonly: false
        
        - tag: "containers"
          host_path: "/var/lib/apptainer"
          mount_point: "/mnt/host-containers"
          readonly: true
```

### Mount Configuration Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tag` | string | Yes | Unique identifier for the mount (used in virtiofs protocol) |
| `host_path` | string | Yes | Absolute path on the host to share |
| `mount_point` | string | Yes | Mount point path inside the guest VM |
| `readonly` | boolean | No | Mount as read-only (default: false) |
| `owner` | string | No | Owner user for mount point (default: admin) |
| `group` | string | No | Owner group for mount point (default: admin) |
| `mode` | string | No | Permissions mode (default: 0755) |
| `options` | string | No | Mount options (default: rw,relatime) |

### Ansible Variables

Override in playbook or inventory:

```yaml
# Mount configuration
virtio_fs_mounts: []  # List of mount configurations

# Mount behavior
virtio_fs_create_mount_dirs: true
virtio_fs_persist_mounts: true
virtio_fs_perform_mounts: true

# Default values
virtio_fs_default_owner: "admin"
virtio_fs_default_group: "admin"
virtio_fs_default_mode: "0755"
virtio_fs_default_options: "rw,relatime"
```

## Usage

### Testing Virtio-FS

Run the complete test suite:

```bash
# Full end-to-end test (create cluster, configure, test, cleanup)
cd tests
make test-virtio-fs

# Or use the framework directly
./test-virtio-fs-framework.sh

# Phased workflow for debugging
make test-virtio-fs-start    # Start cluster
make test-virtio-fs-deploy   # Deploy virtio-fs config
make test-virtio-fs-tests    # Run tests
make test-virtio-fs-stop     # Stop cluster
```

### Applying to Running VMs

To configure virtio-fs on already-running VMs:

```bash
# 1. Ensure host directories exist
sudo mkdir -p /tmp/test-virtio-fs-datasets
sudo mkdir -p /tmp/test-virtio-fs-containers

# 2. Create Ansible inventory
cat > inventory.ini << EOF
[hpc_controller]
192.168.100.10 ansible_user=admin ansible_ssh_private_key_file=build/shared/ssh-keys/id_rsa
EOF

# 3. Run the runtime configuration playbook
ansible-playbook -i inventory.ini \
  ansible/playbooks/playbook-virtio-fs-runtime-config.yml
```

### Manual Mounting

If needed, mount virtio-fs manually inside the VM:

```bash
# Create mount point
sudo mkdir -p /mnt/host-datasets

# Mount using virtiofs
sudo mount -t virtiofs datasets /mnt/host-datasets

# Verify
mount | grep virtiofs
df -h /mnt/host-datasets
```

## Use Cases

### 1. ML/AI Dataset Access

Share large machine learning datasets from host to VMs:

```yaml
virtio_fs_mounts:
  - tag: "imagenet"
    host_path: "/data/datasets/imagenet"
    mount_point: "/mnt/datasets/imagenet"
    readonly: true  # Prevent accidental modification
```

### 2. Container Image Sharing

Share Apptainer/Singularity images without copying:

```yaml
virtio_fs_mounts:
  - tag: "containers"
    host_path: "/var/lib/apptainer/images"
    mount_point: "/opt/apptainer/images"
    readonly: true
```

### 3. Development Workflow

Edit code on host, run in VM instantly:

```yaml
virtio_fs_mounts:
  - tag: "workspace"
    host_path: "/home/user/projects"
    mount_point: "/workspace"
    readonly: false
```

### 4. Build Artifacts

Share build outputs across host and VMs:

```yaml
virtio_fs_mounts:
  - tag: "build"
    host_path: "/build/artifacts"
    mount_point: "/mnt/build"
    readonly: false
```

### 5. Log Collection

Collect VM logs directly to host:

```yaml
virtio_fs_mounts:
  - tag: "logs"
    host_path: "/var/log/cluster-logs"
    mount_point: "/var/log/cluster"
    readonly: false
```

## Performance

Virtio-FS provides excellent performance for virtualized environments:

### Expected Performance Metrics

| Operation | Performance | Notes |
|-----------|-------------|-------|
| Sequential Read | 1-3 GB/s | Depends on host storage |
| Sequential Write | 1-2 GB/s | Depends on host storage |
| Random Read IOPS | 50K-100K | 4KB blocks |
| Random Write IOPS | 40K-80K | 4KB blocks |
| Metadata Operations | 10K-50K ops/s | create/stat/delete |
| Small File I/O | 500-1000 MB/s | 4KB files |
| Latency | 0.1-1 ms | Typical operation latency |

### Performance Tips

1. **Use relatime mount option**: Reduces update overhead
2. **Avoid fsync-heavy workloads**: Virtio-fs synchronous operations are slower
3. **Batch metadata operations**: Group file operations when possible
4. **Large block sizes**: Better for throughput-oriented workloads

## Requirements

### Host Requirements

- Linux kernel >= 5.4 (virtiofs support)
- QEMU >= 4.2 (with virtiofsd)
- libvirt >= 6.2 (virtiofs XML support)
- virtiofsd daemon (usually included with QEMU)

### Guest Requirements

- Linux kernel >= 5.4 (virtiofs driver)
- fuse3 package
- util-linux package
- virtiofs kernel module

### Checking Requirements

```bash
# Host: Check QEMU version
qemu-system-x86_64 --version

# Host: Check libvirt version
virsh version

# Host: Check virtiofsd
which virtiofsd

# Guest: Check kernel version
uname -r

# Guest: Check virtiofs module
modinfo virtiofs
```

## Troubleshooting

### Mounts Not Appearing

**Problem:** Virtio-fs mounts don't appear in the VM

**Solutions:**

1. Check libvirt XML has filesystem device:

   ```bash
   virsh dumpxml vm-name | grep -A 10 filesystem
   ```

2. Verify virtiofs module loaded:

   ```bash
   lsmod | grep virtiofs
   sudo modprobe virtiofs
   ```

3. Check host directory exists:

   ```bash
   ls -la /host/path
   ```

### Permission Denied

**Problem:** Cannot read/write files on mounted filesystem

**Solutions:**

1. Check host directory permissions
2. Verify mount ownership in guest
3. Check readonly flag in configuration

### Poor Performance

**Problem:** Slow I/O performance

**Solutions:**

1. Check host storage performance
2. Verify relatime mount option
3. Use appropriate block sizes
4. Check for host system resource contention

### Module Not Found

**Problem:** virtiofs kernel module not available

**Solution:**

```bash
# Verify kernel version
uname -r  # Should be >= 5.4

# Update kernel if necessary
sudo apt update && sudo apt upgrade linux-image-generic
```

## Comparison with Other Solutions

| Feature | Virtio-FS | NFS | 9P |
|---------|-----------|-----|-----|
| Performance | Excellent (GB/s) | Good (100s MB/s) | Moderate |
| Setup Complexity | Low | Medium | Low |
| POSIX Compliance | Full | Full | Partial |
| Latency | Very Low | Low-Medium | Medium |
| Host Overhead | Minimal | Moderate | Low |
| Network Required | No | Yes | No |
| Security | Host UID/GID | Network ACLs | Host UID/GID |
| Best For | Local VMs | Distributed | Development |

## Best Practices

1. **Use Read-Only Mounts**: For shared datasets that shouldn't be modified
2. **Separate Mount Points**: One mount per use case for better organization
3. **Monitor Performance**: Use performance test suite to validate I/O
4. **Host Directory Structure**: Organize host directories logically
5. **Backup Strategy**: Include host directories in backup plans
6. **Permissions**: Set appropriate ownership and modes for security

## References

- [Virtio-FS Documentation](https://virtio-fs.gitlab.io/)
- [QEMU Virtio-FS Guide](https://qemu.readthedocs.io/en/latest/tools/virtiofsd.html)
- [Libvirt Filesystem Passthrough](https://libvirt.org/kbase/virtiofs.html)
- [Linux Kernel Virtio-FS Driver](https://www.kernel.org/doc/html/latest/filesystems/virtiofs.html)

## Related Documentation

- [Test Framework Pattern](../tests/test-infra/README.md)
