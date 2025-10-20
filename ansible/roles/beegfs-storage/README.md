# BeeGFS Storage Role

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This Ansible role configures BeeGFS storage target nodes that provide the actual data storage
capacity for the BeeGFS distributed file system. Storage nodes serve data blocks to clients
and work in parallel for high-performance I/O.

## Purpose

The BeeGFS storage role provides:

- **Storage Target Daemon**: Block storage and I/O operations
- **Data Management**: Block allocation and management
- **Performance Optimization**: I/O tuning and caching
- **Redundancy Support**: RAID and data protection configuration
- **Capacity Reporting**: Storage capacity and usage statistics
- **Data Integrity**: Checksums and consistency verification

## Variables

### Required Variables

- `beegfs_fs_name`: File system name (must match management node)
- `beegfs_mgmt_host`: Management node address
- `beegfs_storage_target_id`: Unique target ID (default: 101)
- `beegfs_storage_data_dir`: Storage data directory (default: /data/beegfs/storage)

### Key Configuration Variables

**Network Configuration:**

- `beegfs_storage_port`: Storage daemon port (default: 8003)
- `beegfs_storage_bindaddr`: Bind address for storage daemon

**Storage Configuration:**

- `beegfs_storage_data_dir`: Location for storage data
- `beegfs_storage_journal_dir`: Journal directory (default: same as data_dir)
- `beegfs_storage_target_id`: Unique identifier per storage target

**Performance Tuning:**

- `beegfs_storage_buffer_size`: I/O buffer size (default: 32MB)
- `beegfs_storage_num_workers`: Worker threads (default: 8)
- `beegfs_storage_direct_io`: Enable direct I/O (default: true)

**Data Protection:**

- `beegfs_storage_checksums`: Enable data checksums (default: false)
- `beegfs_storage_raid_type`: RAID configuration (default: none)
- `beegfs_storage_replication`: Replication factor (default: 1)

**Logging:**

- `beegfs_storage_log_dir`: Log directory (default: /var/log/beegfs)
- `beegfs_storage_log_level`: Log verbosity (default: 3)

## Usage

### Basic Storage Node Setup

```yaml
- hosts: beegfs_storage
  become: true
  roles:
    - beegfs-storage
  vars:
    beegfs_fs_name: "hpc_storage"
    beegfs_mgmt_host: "10.0.1.10"
    beegfs_storage_target_id: 101
    beegfs_storage_data_dir: "/data/beegfs/storage"
```

### High-Performance Storage

```yaml
- hosts: beegfs_storage
  become: true
  roles:
    - beegfs-storage
  vars:
    beegfs_fs_name: "hpc_storage"
    beegfs_mgmt_host: "10.0.1.10"
    beegfs_storage_direct_io: true
    beegfs_storage_num_workers: 16
    beegfs_storage_buffer_size: "64MB"
```

### With Data Protection

```yaml
- hosts: beegfs_storage
  become: true
  roles:
    - beegfs-storage
  vars:
    beegfs_fs_name: "hpc_storage"
    beegfs_mgmt_host: "10.0.1.10"
    beegfs_storage_checksums: true
    beegfs_storage_replication: 2
```

## Dependencies

This role requires:

- Debian-based system (Debian 11+)
- Root privileges
- BeeGFS management node deployed and running
- Sufficient disk space for storage targets
- Network access to management node

## What This Role Does

1. **Installs BeeGFS Storage**: Installs storage daemon package
2. **Creates Storage Directories**: Sets up data and journal directories
3. **Configures Storage Daemon**: Generates beegfs-storage.conf
4. **Sets Storage Parameters**: Configures performance and I/O settings
5. **Enables Data Protection**: Sets up checksums if requested
6. **Configures Logging**: Sets up log files and rotation
7. **Starts Services**: Enables and starts storage daemon
8. **Registers Target**: Registers with management node

## Tags

Available Ansible tags:

- `beegfs_storage`: All storage tasks
- `beegfs_packages`: Package installation
- `beegfs_config`: Configuration only
- `beegfs_performance`: Performance tuning
- `beegfs_protection`: Data protection setup

## Example Playbook

```yaml
---
- name: Deploy BeeGFS Storage Nodes
  hosts: beegfs_storage
  become: yes
  roles:
    - beegfs-storage
  vars:
    beegfs_fs_name: "production_storage"
    beegfs_mgmt_host: "beegfs-mgmt.local"
    beegfs_storage_target_id: "{{ groups['beegfs_storage'].index(inventory_hostname) + 101 }}"
    beegfs_storage_data_dir: "/data/beegfs/storage"
    beegfs_storage_checksums: true
```

## Service Management

```bash
# Check storage daemon status
systemctl status beegfs-storage

# Restart storage daemon
systemctl restart beegfs-storage

# View storage logs
journalctl -u beegfs-storage -f

# Enable auto-start
systemctl enable beegfs-storage
```

## Verification

After deployment, verify storage node setup:

```bash
# Check storage daemon running
ps aux | grep beegfs-storage

# List storage targets
beegfs-ctl --listnodes --nodetype storage

# View target capacity
beegfs-ctl --listtargets

# Monitor storage performance
beegfs-ctl --getnodes --nodetype storage

# Check reachability
beegfs-net
```

## Performance Monitoring

Monitor storage node performance:

```bash
# View I/O statistics
beegfs-ctl --getsysinfo target <targetID>

# Monitor real-time performance
watch -n 1 'beegfs-ctl --getsysinfo target'

# Check disk utilization
df -h /data/beegfs/storage

# Monitor I/O latency
iostat -x 1
```

## Log Files

Storage nodes generate logs at:

- `/var/log/beegfs/beegfs-storage.log` - Storage daemon log
- `/var/log/beegfs/beegfs-storage_stats.log` - Statistics log

View logs:

```bash
# Real-time monitoring
tail -f /var/log/beegfs/beegfs-storage.log

# Search for errors
grep ERROR /var/log/beegfs/beegfs-storage.log
```

## Troubleshooting

### Storage Daemon Won't Start

1. Check data directory: `ls -la /data/beegfs/storage`
2. Verify disk space: `df -h /data/beegfs/storage`
3. Check configuration: `beegfs-storage --cfgFile=/etc/beegfs/beegfs-storage.conf`
4. Review logs: `tail -f /var/log/beegfs/beegfs-storage.log`

### Can't Connect to Management Node

1. Verify management node is running and reachable
2. Check firewall rules for port 8008 (management)
3. Verify network connectivity: `ping <mgmt_host>`
4. Check DNS resolution

### Poor Performance

1. Verify direct I/O enabled: `grep directIO /etc/beegfs/beegfs-storage.conf`
2. Check worker threads: `grep numWorkers /etc/beegfs/beegfs-storage.conf`
3. Monitor disk I/O: `iostat -x 1`
4. Review buffer settings: `grep bufferSize /etc/beegfs/beegfs-storage.conf`

### Data Corruption Detected

1. Check checksums enabled: `grep checksums /etc/beegfs/beegfs-storage.conf`
2. Review error logs for corruption messages
3. Run consistency check on filesystem
4. Consider offline scrubbing

## Performance Tuning

### For NVMe Storage

```yaml
beegfs_storage_direct_io: true
beegfs_storage_num_workers: 32
beegfs_storage_buffer_size: "128MB"
```

### For SSD Storage

```yaml
beegfs_storage_direct_io: true
beegfs_storage_num_workers: 16
beegfs_storage_checksums: true
```

### For HDD Storage

```yaml
beegfs_storage_num_workers: 8
beegfs_storage_buffer_size: "64MB"
beegfs_storage_replication: 2
```

## Integration with Other Roles

This role works with:

- **beegfs-mgmt**: Management node (required)
- **beegfs-meta**: Metadata nodes
- **beegfs-client**: Client mount points
- **monitoring-stack**: Storage metrics

## See Also

- **[../README.md](../README.md)** - Main Ansible overview
- **[../beegfs-mgmt/README.md](../beegfs-mgmt/README.md)** - Management node setup
- **[../beegfs-meta/README.md](../beegfs-meta/README.md)** - Metadata node setup
- **[../beegfs-client/README.md](../beegfs-client/README.md)** - Client mount setup
- **[BeeGFS Official Docs](https://www.beegfs.io/wiki/)** - BeeGFS documentation
