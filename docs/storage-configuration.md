# Storage Configuration Guide

**Status:** Production  
**Version:** 1.0  
**Last Updated:** 2025-10-24

This guide explains how to configure storage backends for HPC clusters, including BeeGFS parallel filesystem and
VirtIO-FS host directory sharing.

## Overview

The HPC cluster supports two main storage backends:

1. **BeeGFS Parallel Filesystem** - High-performance distributed storage across all cluster nodes
2. **VirtIO-FS Host Directory Sharing** - Direct access to host filesystem directories from VMs

Both storage backends are configured through the cluster configuration YAML file and deployed via the unified `playbook-hpc-runtime.yml`.

## Cluster Configuration Schema

### Storage Configuration Structure

```yaml
clusters:
  hpc:
    # Storage backend configuration (cluster-wide)
    storage:
      # BeeGFS parallel filesystem
      beegfs:
        enabled: true  # Enable BeeGFS deployment
        mount_point: "/mnt/beegfs"
        
        # Service placement (auto-detected from roles if not specified)
        management_node: "controller"  # Management service location
        metadata_nodes:  # Metadata service locations
          - "controller"
        storage_nodes:   # Storage service locations (defaults to all compute nodes)
          - "compute-01"
          - "compute-02"
        
        # Client configuration
        client_config:
          mount_options: "defaults,_netdev"
          auto_mount: true
          
      # VirtIO-FS host directory sharing (per-node)
      virtio_fs:
        enabled: true  # Enable VirtIO-FS on applicable nodes
        
    controller:
      # ... existing controller config ...
      
      # VirtIO-FS mounts (node-specific)
      virtio_fs_mounts:
        - tag: "project-repo"
          host_path: "${TOT}"
          mount_point: "${TOT}"
          owner: "admin"
          group: "admin"
          mode: "0755"
```

## BeeGFS Configuration

### Overview

BeeGFS provides high-performance parallel filesystem access across all cluster nodes. It's ideal for:

- Large-scale data processing workloads
- Multi-node parallel I/O operations
- Shared datasets across compute nodes
- Container image storage

### Configuration Options

#### `beegfs.enabled`

**Type:** Boolean  
**Default:** `false`  
**Description:** Enable or disable BeeGFS deployment

```yaml
storage:
  beegfs:
    enabled: true
```

#### `beegfs.mount_point`

**Type:** String (path)  
**Default:** `"/mnt/beegfs"`  
**Description:** Mount point for BeeGFS filesystem on all nodes

```yaml
storage:
  beegfs:
    mount_point: "/mnt/beegfs"
```

#### `beegfs.management_node`

**Type:** String  
**Default:** `"controller"`  
**Description:** Node where BeeGFS management service runs

```yaml
storage:
  beegfs:
    management_node: "controller"
```

#### `beegfs.metadata_nodes`

**Type:** Array of strings  
**Default:** `["controller"]`  
**Description:** Nodes where BeeGFS metadata services run

```yaml
storage:
  beegfs:
    metadata_nodes:
      - "controller"
      - "compute-01"  # For high availability
```

#### `beegfs.storage_nodes`

**Type:** Array of strings  
**Default:** All compute nodes  
**Description:** Nodes where BeeGFS storage services run

```yaml
storage:
  beegfs:
    storage_nodes:
      - "compute-01"
      - "compute-02"
      - "compute-03"
```

#### `beegfs.client_config`

**Type:** Object  
**Description:** Client configuration options

```yaml
storage:
  beegfs:
    client_config:
      mount_options: "defaults,_netdev"
      auto_mount: true
```

**Client Configuration Options:**

- `mount_options`: Mount options for BeeGFS filesystem
- `auto_mount`: Automatically mount BeeGFS on boot

### BeeGFS Service Architecture

```text
Controller Node:
├── beegfs-mgmtd (Management Service)
└── beegfs-meta (Metadata Service)

Compute Nodes:
├── beegfs-storage (Storage Service)
└── beegfs-client (Client Service)

All Nodes:
└── beegfs-client (Client Service)
```

### BeeGFS Benefits

- **Parallel I/O**: Multiple nodes serving data simultaneously
- **No Single Point of Failure**: Metadata and storage distributed
- **Linear Scaling**: Performance grows with node count
- **POSIX Compliant**: Drop-in NFS replacement
- **High Performance**: Optimized for HPC workloads

## VirtIO-FS Configuration

### Overview

VirtIO-FS provides direct access to host filesystem directories from VMs. It's ideal for:

- Development workflows
- Shared project repositories
- Dataset access without copying
- Host-VM file sharing

### Configuration Options

#### `virtio_fs.enabled`

**Type:** Boolean  
**Default:** `false`  
**Description:** Enable VirtIO-FS on applicable nodes

```yaml
storage:
  virtio_fs:
    enabled: true
```

#### `virtio_fs_mounts`

**Type:** Array of mount objects  
**Description:** Per-node VirtIO-FS mount configurations

```yaml
controller:
  virtio_fs_mounts:
    - tag: "project-repo"
      host_path: "/home/user/projects"
      mount_point: "/mnt/host-projects"
      owner: "admin"
      group: "admin"
      mode: "0755"
      options: "rw,relatime"
```

**Mount Object Properties:**

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `tag` | String | Yes | Unique identifier for the mount |
| `host_path` | String (path) | Yes | Path on host system |
| `mount_point` | String (path) | Yes | Path inside VM |
| `owner` | String | No | File ownership (default: "admin") |
| `group` | String | No | File group (default: "admin") |
| `mode` | String | No | File permissions (default: "0755") |
| `options` | String | No | Mount options (default: "rw,relatime") |

**Note:** Read-only mode is not currently supported by virtiofs in libvirt/QEMU.

### VirtIO-FS Benefits

- **High Performance**: Direct kernel-level file sharing
- **Low Latency**: No network overhead
- **Transparent**: Appears as local filesystem
- **Flexible**: Per-node mount configuration
- **Secure**: VM-level access control

## Common Configuration Examples

### Basic BeeGFS Setup

```yaml
clusters:
  hpc:
    storage:
      beegfs:
        enabled: true
        mount_point: "/mnt/beegfs"
        management_node: "controller"
        metadata_nodes: ["controller"]
        # storage_nodes defaults to all compute nodes
        client_config:
          mount_options: "defaults,_netdev"
          auto_mount: true
```

### High Availability BeeGFS

```yaml
clusters:
  hpc:
    storage:
      beegfs:
        enabled: true
        mount_point: "/mnt/beegfs"
        management_node: "controller"
        metadata_nodes: 
          - "controller"
          - "compute-01"  # Backup metadata server
        storage_nodes:
          - "compute-01"
          - "compute-02"
          - "compute-03"
        client_config:
          mount_options: "defaults,_netdev"
          auto_mount: true
```

### Development Environment with VirtIO-FS

```yaml
clusters:
  hpc:
    storage:
      virtio_fs:
        enabled: true
        
    controller:
      virtio_fs_mounts:
        - tag: "project-repo"
          host_path: "/home/user/Projects/pharos.ai-hyperscaler"
          mount_point: "/mnt/host-repo"
          owner: "admin"
          group: "admin"
          mode: "0755"
        
        - tag: "datasets"
          host_path: "/data/ml-datasets"
          mount_point: "/mnt/datasets"
          owner: "admin"
          group: "admin"
          mode: "0755"
```

### Production Environment with Both Storage Types

```yaml
clusters:
  hpc:
    storage:
      beegfs:
        enabled: true
        mount_point: "/mnt/beegfs"
        management_node: "controller"
        metadata_nodes: ["controller"]
        client_config:
          mount_options: "defaults,_netdev"
          auto_mount: true
          
      virtio_fs:
        enabled: true
        
    controller:
      virtio_fs_mounts:
        - tag: "config"
          host_path: "/etc/cluster-config"
          mount_point: "/mnt/host-config"
          owner: "admin"
          group: "admin"
          mode: "0755"
```

## Deployment

### Automatic Deployment

Storage backends are automatically deployed when using the unified runtime playbook:

```bash
# Deploy complete HPC cluster with storage
ansible-playbook -i inventory.yml playbook-hpc-runtime.yml
```

### Conditional Deployment

Storage backends are only deployed if enabled in configuration:

- BeeGFS: Deployed if `storage.beegfs.enabled: true`
- VirtIO-FS: Deployed if `storage.virtio_fs.enabled: true`

### Verification

After deployment, verify storage functionality:

```bash
# Check BeeGFS services
ssh controller "systemctl status beegfs-mgmtd beegfs-meta"
ssh compute01 "systemctl status beegfs-storage beegfs-client"

# Check BeeGFS mount
ssh controller "mount | grep beegfs"
ssh controller "beegfs-ctl --listnodes --nodetype=all"

# Check VirtIO-FS mounts
ssh controller "mount | grep virtiofs"
ssh controller "ls -la /mnt/host-*"
```

## Troubleshooting

### BeeGFS Issues

**Problem**: BeeGFS services not starting

**Solution**:

```bash
# Check service status
systemctl status beegfs-mgmtd beegfs-meta beegfs-storage beegfs-client

# Check logs
journalctl -u beegfs-mgmtd -f
journalctl -u beegfs-meta -f

# Restart services
systemctl restart beegfs-mgmtd beegfs-meta beegfs-storage beegfs-client
```

**Problem**: BeeGFS not mounting

**Solution**:

```bash
# Check mount point exists
ls -la /mnt/beegfs

# Check client configuration
cat /etc/beegfs/beegfs-client.conf

# Manual mount
mount -t beegfs beegfs /mnt/beegfs
```

### VirtIO-FS Issues

**Problem**: VirtIO-FS mounts not working

**Solution**:

```bash
# Check virtiofs kernel module
lsmod | grep virtiofs

# Check mount configuration
cat /etc/fstab | grep virtiofs

# Check mount points
ls -la /mnt/host-*
```

**Problem**: Permission denied on VirtIO-FS mounts

**Solution**:

```bash
# Check ownership
ls -la /mnt/host-*

# Fix ownership
sudo chown -R admin:admin /mnt/host-*

# Check mount options
mount | grep virtiofs
```

## Best Practices

### BeeGFS Best Practices

1. **Service Placement**:
   - Management service on controller
   - Metadata service on controller (or dedicated node)
   - Storage services on all compute nodes

2. **Performance Optimization**:
   - Use dedicated storage nodes for large datasets
   - Configure appropriate mount options
   - Monitor I/O performance

3. **High Availability**:
   - Deploy multiple metadata servers
   - Use redundant storage nodes
   - Regular backup of metadata

### VirtIO-FS Best Practices

1. **Mount Configuration**:
   - Use descriptive tags for mounts
   - Set appropriate permissions
   - Use read-only mounts for datasets

2. **Performance**:
   - Mount frequently accessed directories
   - Avoid mounting large directory trees
   - Use appropriate mount options

3. **Security**:
   - Limit host path access
   - Use read-only mounts when possible
   - Set appropriate file permissions

## See Also

- [BeeGFS Installation Flow](components/beegfs/installation-flow.md) - Detailed BeeGFS setup guide
- [VirtIO-FS Integration](workflows/VIRTIO-FS-INTEGRATION.md) - VirtIO-FS implementation details
- [Cluster Configuration Schema](implementation-plans/task-lists/hpc-slurm/pending/phase-4-consolidation.md) -
  Complete schema reference
