# BeeGFS Metadata Role

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This Ansible role configures BeeGFS metadata nodes that store file system metadata including
file attributes, permissions, and inode information. Metadata nodes work in parallel to
provide scalable metadata performance.

## Purpose

The BeeGFS metadata role provides:

- **Metadata Daemon**: Metadata service and inode management
- **Metadata Storage**: File attributes and directory structure
- **Performance**: Parallel metadata operations across multiple nodes
- **Redundancy**: Metadata mirroring and failover support
- **Quota Tracking**: Per-user and per-group quota management
- **Access Control**: File permissions and ACL support

## Variables

### Required Variables

- `beegfs_fs_name`: File system name (must match management node)
- `beegfs_mgmt_host`: Management node address
- `beegfs_meta_node_id`: Unique metadata node ID (default: 1)
- `beegfs_meta_data_dir`: Metadata storage directory (default: /data/beegfs/meta)

### Key Configuration Variables

**Network Configuration:**

- `beegfs_meta_port`: Metadata daemon port (default: 8005)
- `beegfs_meta_bindaddr`: Bind address for metadata daemon

**Storage Configuration:**

- `beegfs_meta_data_dir`: Location for metadata storage
- `beegfs_meta_node_id`: Unique identifier per metadata node
- `beegfs_meta_journal_enabled`: Enable journaling (default: true)

**Performance Tuning:**

- `beegfs_meta_num_workers`: Worker threads (default: 8)
- `beegfs_meta_cache_size`: Metadata cache size (default: 512MB)
- `beegfs_meta_inode_hash_size`: Inode hash table size (default: auto)

**Redundancy:**

- `beegfs_meta_mirroring_enabled`: Enable metadata mirroring (default: false)
- `beegfs_meta_mirror_buddy_group_id`: Mirror buddy group (if mirroring)

**Logging:**

- `beegfs_meta_log_dir`: Log directory (default: /var/log/beegfs)
- `beegfs_meta_log_level`: Log verbosity (default: 3)

## Usage

### Basic Metadata Node Setup

```yaml
- hosts: beegfs_meta
  become: true
  roles:
    - beegfs-meta
  vars:
    beegfs_fs_name: "hpc_storage"
    beegfs_mgmt_host: "10.0.1.10"
    beegfs_meta_node_id: 1
    beegfs_meta_data_dir: "/data/beegfs/meta"
```

### High-Performance Metadata

```yaml
- hosts: beegfs_meta
  become: true
  roles:
    - beegfs-meta
  vars:
    beegfs_fs_name: "hpc_storage"
    beegfs_mgmt_host: "10.0.1.10"
    beegfs_meta_num_workers: 16
    beegfs_meta_cache_size: "2GB"
```

### With Mirroring for HA

```yaml
- hosts: beegfs_meta
  become: true
  roles:
    - beegfs-meta
  vars:
    beegfs_fs_name: "hpc_storage"
    beegfs_mgmt_host: "10.0.1.10"
    beegfs_meta_mirroring_enabled: true
    beegfs_meta_mirror_buddy_group_id: "1001"
```

## Dependencies

This role requires:

- Debian-based system (Debian 11+)
- Root privileges
- BeeGFS management node deployed and running
- Sufficient disk space for metadata storage
- Network access to management node

## What This Role Does

1. **Installs BeeGFS Metadata**: Installs metadata daemon package
2. **Creates Metadata Directories**: Sets up metadata storage
3. **Configures Metadata Daemon**: Generates beegfs-meta.conf
4. **Enables Journaling**: Sets up transaction logging
5. **Configures Performance**: Sets worker threads and cache
6. **Enables Mirroring**: Sets up metadata redundancy if requested
7. **Starts Services**: Enables and starts metadata daemon
8. **Registers with Management**: Registers metadata node

## Tags

Available Ansible tags:

- `beegfs_meta`: All metadata tasks
- `beegfs_packages`: Package installation
- `beegfs_config`: Configuration only
- `beegfs_performance`: Performance tuning
- `beegfs_mirroring`: Mirroring setup

## Example Playbook

```yaml
---
- name: Deploy BeeGFS Metadata Nodes
  hosts: beegfs_meta
  become: yes
  roles:
    - beegfs-meta
  vars:
    beegfs_fs_name: "production_storage"
    beegfs_mgmt_host: "beegfs-mgmt.local"
    beegfs_meta_node_id: "{{ groups['beegfs_meta'].index(inventory_hostname) + 1 }}"
    beegfs_meta_data_dir: "/data/beegfs/meta"
    beegfs_meta_num_workers: 16
```

## Service Management

```bash
# Check metadata daemon status
systemctl status beegfs-meta

# Restart metadata daemon
systemctl restart beegfs-meta

# View metadata logs
journalctl -u beegfs-meta -f

# Enable auto-start
systemctl enable beegfs-meta
```

## Verification

After deployment, verify metadata node setup:

```bash
# Check metadata daemon running
ps aux | grep beegfs-meta

# List metadata nodes
beegfs-ctl --listnodes --nodetype meta

# View metadata statistics
beegfs-ctl --getsysinfo metadata

# Check file system health
beegfs-check --nodetype meta

# Monitor metadata performance
beegfs-ctl --getnodes --nodetype meta
```

## Performance Monitoring

Monitor metadata node performance:

```bash
# View metadata statistics
beegfs-ctl --getsysinfo metadata <metaID>

# Monitor real-time metadata operations
watch -n 1 'beegfs-ctl --getsysinfo metadata'

# Check disk utilization
df -h /data/beegfs/meta

# Monitor cache efficiency
cat /proc/fs/beegfs/*/meta_stats
```

## Log Files

Metadata nodes generate logs at:

- `/var/log/beegfs/beegfs-meta.log` - Metadata daemon log
- `/var/log/beegfs/beegfs-meta_stats.log` - Statistics log

View logs:

```bash
# Real-time monitoring
tail -f /var/log/beegfs/beegfs-meta.log

# Search for errors
grep ERROR /var/log/beegfs/beegfs-meta.log
```

## Troubleshooting

### Metadata Daemon Won't Start

1. Check data directory: `ls -la /data/beegfs/meta`
2. Verify disk space: `df -h /data/beegfs/meta`
3. Check configuration: `beegfs-meta --cfgFile=/etc/beegfs/beegfs-meta.conf`
4. Review logs: `tail -f /var/log/beegfs/beegfs-meta.log`

### Can't Connect to Management Node

1. Verify management node running
2. Check firewall rules for port 8008
3. Verify network connectivity: `ping <mgmt_host>`
4. Check DNS resolution

### Metadata Mirroring Issues

1. Verify mirroring enabled: `grep mirroring /etc/beegfs/beegfs-meta.conf`
2. Check mirror buddy status: `beegfs-ctl --mirrorgroupinfo`
3. Review mirroring logs
4. Verify disk synchronization

### Poor Performance

1. Check worker threads: `grep numWorkers /etc/beegfs/beegfs-meta.conf`
2. Verify cache size: `grep cacheSize /etc/beegfs/beegfs-meta.conf`
3. Monitor disk I/O: `iostat -x 1`
4. Check CPU usage on metadata node

## Performance Tuning

### For Workload with Many Small Files

```yaml
beegfs_meta_num_workers: 16
beegfs_meta_cache_size: "4GB"
beegfs_meta_inode_hash_size: 524288
```

### For Workload with Few Large Files

```yaml
beegfs_meta_num_workers: 8
beegfs_meta_cache_size: "1GB"
```

### For High-Concurrency Workload

```yaml
beegfs_meta_num_workers: 32
beegfs_meta_cache_size: "8GB"
beegfs_meta_journal_enabled: true
```

## Metadata Mirroring

### Enable Mirroring Between Two Nodes

```bash
# Register mirror buddy group
beegfs-ctl --addmirrorbuddygroup --nodetype meta \
  --primarynodeid 1 --secondarynodeid 2 --groupid 1001
```

### Check Mirror Status

```bash
# View mirror group info
beegfs-ctl --mirrorgroupinfo --nodetype meta

# View sync status
beegfs-ctl --getmirrorgroupstats --nodetype meta
```

## Integration with Other Roles

This role works with:

- **beegfs-mgmt**: Management node (required)
- **beegfs-storage**: Storage nodes
- **beegfs-client**: Client mount points
- **monitoring-stack**: Metadata metrics

## See Also

- **[../README.md](../README.md)** - Main Ansible overview
- **[../beegfs-mgmt/README.md](../beegfs-mgmt/README.md)** - Management node setup
- **[../beegfs-storage/README.md](../beegfs-storage/README.md)** - Storage node setup
- **[../beegfs-client/README.md](../beegfs-client/README.md)** - Client mount setup
- **[BeeGFS Official Docs](https://www.beegfs.io/wiki/)** - BeeGFS documentation
