# BeeGFS Client Role

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This Ansible role configures BeeGFS client nodes for mounting and accessing the BeeGFS
distributed file system. Clients connect to BeeGFS storage and metadata nodes to access
shared storage.

## Purpose

The BeeGFS client role provides:

- **BeeGFS Client Daemon**: User-space file system daemon (FUSE)
- **Mount Configuration**: Mount point setup and persistence
- **Performance Tuning**: Client-side cache and buffer tuning
- **Failover Support**: Automatic failover to redundant targets
- **Statistics**: Client-side performance monitoring
- **Striping**: Data distribution across storage targets

## Variables

### Required Variables

- `beegfs_fs_name`: File system name (must match cluster)
- `beegfs_mgmt_host`: Management node address
- `beegfs_mount_point`: Mount path (default: /mnt/beegfs)

### Key Configuration Variables

**Mount Configuration:**

- `beegfs_mount_point`: Where to mount BeeGFS (default: /mnt/beegfs)
- `beegfs_mount_owner`: Mount directory owner (default: root)
- `beegfs_mount_group`: Mount directory group (default: root)
- `beegfs_mount_mode`: Directory permissions (default: 0755)

**Performance Tuning:**

- `beegfs_client_cache_size`: Client cache size (default: 1GB)
- `beegfs_client_num_threads`: Worker threads (default: 8)
- `beegfs_client_stripe_pattern`: Striping configuration (default: RAID0)

**Advanced Options:**

- `beegfs_client_write_cache`: Enable write caching (default: true)
- `beegfs_client_read_ahead`: Read-ahead buffer (default: 4M)
- `beegfs_client_remote_fsync`: Remote fsync (default: true)

**Failover:**

- `beegfs_client_failover_enabled`: Enable failover (default: true)
- `beegfs_client_failover_timeout`: Failover timeout (default: 30s)

## Usage

### Basic Client Mount

```yaml
- hosts: hpc_compute
  become: true
  roles:
    - beegfs-client
  vars:
    beegfs_fs_name: "hpc_storage"
    beegfs_mgmt_host: "10.0.1.10"
    beegfs_mount_point: "/mnt/beegfs"
```

### High-Performance Client Configuration

```yaml
- hosts: hpc_compute
  become: true
  roles:
    - beegfs-client
  vars:
    beegfs_fs_name: "hpc_storage"
    beegfs_mgmt_host: "10.0.1.10"
    beegfs_mount_point: "/mnt/beegfs"
    beegfs_client_cache_size: "4GB"
    beegfs_client_num_threads: 16
    beegfs_client_read_ahead: "16M"
```

### With Persistent Mount

```yaml
- hosts: hpc_compute
  become: true
  roles:
    - beegfs-client
  vars:
    beegfs_fs_name: "hpc_storage"
    beegfs_mgmt_host: "10.0.1.10"
    beegfs_mount_point: "/mnt/beegfs"
    beegfs_client_failover_enabled: true
```

## Dependencies

This role requires:

- Debian-based system (Debian 11+)
- Root privileges
- FUSE library installed
- BeeGFS management and storage nodes running
- Network access to management and storage nodes

## What This Role Does

1. **Installs FUSE**: Installs FUSE libraries required for client
2. **Installs BeeGFS Client**: Installs beegfs-client package
3. **Creates Mount Point**: Creates directory for mount point
4. **Configures Client**: Generates beegfs-client.conf
5. **Sets Performance Parameters**: Tuning for client performance
6. **Configures Mount**: Sets up fstab for persistent mounting
7. **Starts Client Service**: Enables and starts client daemon
8. **Mounts File System**: Performs initial mount

## Tags

Available Ansible tags:

- `beegfs_client`: All client tasks
- `beegfs_packages`: Package installation
- `beegfs_config`: Configuration only
- `beegfs_mount`: Mount operations
- `beegfs_performance`: Performance tuning

## Example Playbook

```yaml
---
- name: Deploy BeeGFS Clients
  hosts: hpc_compute
  become: yes
  roles:
    - beegfs-client
  vars:
    beegfs_fs_name: "production_storage"
    beegfs_mgmt_host: "beegfs-mgmt.local"
    beegfs_mount_point: "/mnt/beegfs"
    beegfs_client_cache_size: "4GB"
```

## Service Management

```bash
# Check client daemon status
systemctl status beegfs-client

# Restart client
systemctl restart beegfs-client

# View client logs
journalctl -u beegfs-client -f

# Mount status
mount | grep beegfs

# Unmount BeeGFS (if needed)
sudo umount /mnt/beegfs
```

## Verification

After deployment, verify client setup:

```bash
# Check mount point
df -h /mnt/beegfs

# List directory
ls -la /mnt/beegfs

# Test read/write
dd if=/dev/zero of=/mnt/beegfs/test.txt bs=1M count=100

# Check client status
beegfs-net

# View mount options
mount | grep beegfs
```

## Performance Monitoring

Monitor client performance:

```bash
# View client I/O statistics
beegfs-ctl --getquotainfo

# Monitor real-time performance
watch -n 1 'df -h /mnt/beegfs'

# Check cache statistics
cat /proc/fs/beegfs/*/stats

# Monitor network
iftop -i eth0
```

## Log Files

Client generates logs at:

- `/var/log/beegfs/beegfs-client.log` - Client daemon log
- `/var/log/beegfs/beegfs-client_stats.log` - Statistics log

View logs:

```bash
# Real-time monitoring
tail -f /var/log/beegfs/beegfs-client.log

# Search for errors
grep ERROR /var/log/beegfs/beegfs-client.log
```

## Troubleshooting

### Mount Fails

1. Verify management node reachable: `ping <mgmt_host>`
2. Check client daemon: `systemctl status beegfs-client`
3. Verify mount point exists: `ls -la /mnt/beegfs`
4. Review logs: `tail -f /var/log/beegfs/beegfs-client.log`

### Poor Performance

1. Check cache size: `grep clientMaxCacheSize /etc/beegfs/beegfs-client.conf`
2. Verify worker threads: `grep numThreads /etc/beegfs/beegfs-client.conf`
3. Monitor network: `iftop -i eth0`
4. Check storage responsiveness

### Can't Access Mount Point

1. Verify mount is active: `mount | grep beegfs`
2. Check permissions: `ls -la /mnt/beegfs`
3. Verify network connectivity to all storage nodes
4. Check firewall rules

## Common Operations

### Remount with Different Options

```bash
# Unmount
sudo umount /mnt/beegfs

# Remount with new options
sudo mount -a

# Verify
mount | grep beegfs
```

### Monitor Stripe Pattern

```bash
# View default stripe pattern
beegfs-ctl --getdefaultstriping

# Set stripe pattern
beegfs-ctl --setstriping --pattern=raid10 --chunksize=512K /mnt/beegfs
```

### Check Storage Connectivity

```bash
# List all storage targets
beegfs-ctl --listtargets

# Check individual target
beegfs-ctl --getsysinfo target <targetID>
```

## Performance Tuning

### For Small Files

```yaml
beegfs_client_cache_size: "2GB"
beegfs_client_read_ahead: "8M"
beegfs_client_stripe_pattern: "RAID0"
```

### For Large Files

```yaml
beegfs_client_cache_size: "8GB"
beegfs_client_read_ahead: "32M"
beegfs_client_stripe_pattern: "RAID10"
```

### For Sequential I/O

```yaml
beegfs_client_read_ahead: "64M"
beegfs_client_num_threads: 16
beegfs_client_write_cache: true
```

## Integration with Other Roles

This role works with:

- **beegfs-mgmt**: Management node (required)
- **beegfs-storage**: Storage nodes (required)
- **beegfs-meta**: Metadata nodes
- **monitoring-stack**: Client metrics

## See Also

- **[../README.md](../README.md)** - Main Ansible overview
- **[../beegfs-mgmt/README.md](../beegfs-mgmt/README.md)** - Management node setup
- **[../beegfs-storage/README.md](../beegfs-storage/README.md)** - Storage node setup
- **[../beegfs-meta/README.md](../beegfs-meta/README.md)** - Metadata node setup
- **TODO**: **BeeGFS Official Docs** - Find correct BeeGFS documentation URL (wiki appears down)
