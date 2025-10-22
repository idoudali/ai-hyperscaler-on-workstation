# BeeGFS Management Role

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This Ansible role configures BeeGFS management nodes that serve as the central administrative
point for BeeGFS distributed file system clusters. The management node maintains the file
system metadata and configuration for all BeeGFS services.

## Purpose

The BeeGFS management role provides:

- **BeeGFS Management Daemon**: Central control point for the file system
- **Metadata Management**: Configuration and metadata storage
- **Cluster Monitoring**: Health status and statistics collection
- **Node Registration**: Discovery and registration of storage/metadata nodes
- **Access Control**: User and permission management
- **Quotas**: File system quota configuration and enforcement

## Variables

### Required Variables

- `beegfs_fs_name`: File system name (default: beegfs_fs)
- `beegfs_mgmt_port`: Management daemon port (default: 8008)
- `beegfs_mgmt_data_dir`: Data directory path (default: /data/beegfs/mgmt)

### Key Configuration Variables

**Network Configuration:**

- `beegfs_mgmt_interface`: Network interface for management (default: eth0)
- `beegfs_mgmt_bindaddr`: Bind address for management daemon
- `beegfs_mgmt_port_udp`: UDP port for discovery (default: 8008)

**Storage Configuration:**

- `beegfs_mgmt_data_dir`: Management metadata storage
- `beegfs_mgmt_backup_dir`: Backup directory (default: /data/beegfs/mgmt_bak)

**Logging and Monitoring:**

- `beegfs_mgmt_log_dir`: Log file directory (default: /var/log/beegfs)
- `beegfs_mgmt_log_level`: Log verbosity level (default: 3)
- `beegfs_mgmt_stats_enabled`: Enable statistics (default: true)

**Quotas:**

- `beegfs_quotas_enabled`: Enable quota support (default: false)
- `beegfs_quota_size_limit`: Default size quota (default: unlimited)
- `beegfs_quota_inode_limit`: Default inode quota (default: unlimited)

**High Availability:**

- `beegfs_mgmt_ha_enabled`: Enable HA mode (default: false)
- `beegfs_mgmt_backup_host`: HA backup management node (if HA enabled)

## Usage

### Basic Management Node Setup

```yaml
- hosts: beegfs_mgmt
  become: true
  roles:
    - beegfs-mgmt
  vars:
    beegfs_fs_name: "hpc_storage"
    beegfs_mgmt_port: 8008
    beegfs_mgmt_data_dir: "/data/beegfs/mgmt"
```

### With Quotas Enabled

```yaml
- hosts: beegfs_mgmt
  become: true
  roles:
    - beegfs-mgmt
  vars:
    beegfs_fs_name: "hpc_storage"
    beegfs_quotas_enabled: true
    beegfs_quota_size_limit: "1TB"
```

### High Availability Setup

```yaml
- hosts: beegfs_mgmt
  become: true
  roles:
    - beegfs-mgmt
  vars:
    beegfs_fs_name: "hpc_storage"
    beegfs_mgmt_ha_enabled: true
    beegfs_mgmt_backup_host: "beegfs-mgmt-backup.local"
```

## Dependencies

This role requires:

- Debian-based system (Debian 11+)
- Root privileges
- BeeGFS repositories configured
- Sufficient disk space for metadata
- Network access from all cluster nodes

## What This Role Does

1. **Installs BeeGFS Management**: Installs management daemon package
2. **Creates Data Directories**: Sets up metadata storage directories
3. **Configures Management Daemon**: Generates beegfs-mgmtd.conf
4. **Sets Up Logging**: Configures log files and rotation
5. **Enables Statistics**: Sets up performance metrics collection
6. **Configures Quotas**: Enables quota system if requested
7. **Starts Services**: Enables and starts management daemon
8. **Verifies Setup**: Tests management daemon connectivity

## Tags

Available Ansible tags:

- `beegfs_mgmt`: All management tasks
- `beegfs_packages`: Package installation only
- `beegfs_config`: Configuration only
- `beegfs_quotas`: Quota configuration
- `beegfs_ha`: High availability setup

## Example Playbook

```yaml
---
- name: Deploy BeeGFS Management Node
  hosts: beegfs_mgmt
  become: yes
  roles:
    - beegfs-mgmt
  vars:
    beegfs_fs_name: "production_storage"
    beegfs_mgmt_port: 8008
    beegfs_mgmt_data_dir: "/data/beegfs/mgmt"
    beegfs_quotas_enabled: true
```

## Service Management

```bash
# Check management daemon status
systemctl status beegfs-mgmtd

# Restart management daemon
systemctl restart beegfs-mgmtd

# View management logs
journalctl -u beegfs-mgmtd -f

# Enable auto-start
systemctl enable beegfs-mgmtd
```

## Verification

After deployment, verify management node setup:

```bash
# Check management daemon running
ps aux | grep beegfs-mgmtd

# Check listening ports
netstat -tulpn | grep beegfs

# View file system status
beegfs-ctl --listnodes --nodetype mgmt

# Check quota status (if enabled)
beegfs-ctl --getquotainfo

# Monitor file system
beegfs-mon
```

## Log Files

Management node generates logs at:

- `/var/log/beegfs/beegfs-mgmtd.log` - Management daemon log
- `/var/log/beegfs/beegfs-mgmtd_stats.log` - Statistics log (if enabled)

View logs:

```bash
# Real-time monitoring
tail -f /var/log/beegfs/beegfs-mgmtd.log

# Search for errors
grep ERROR /var/log/beegfs/beegfs-mgmtd.log
```

## Troubleshooting

### Management Daemon Won't Start

1. Check configuration syntax: `beegfs-mgmtd --cfgFile=/etc/beegfs/beegfs-mgmtd.conf`
2. Verify data directory permissions: `ls -la /data/beegfs/mgmt`
3. Check port availability: `netstat -tulpn | grep 8008`
4. Review logs: `tail -f /var/log/beegfs/beegfs-mgmtd.log`

### Nodes Can't Connect

1. Verify management daemon is running: `systemctl status beegfs-mgmtd`
2. Check firewall rules for port 8008
3. Verify network connectivity from other nodes
4. Check DNS resolution

### Quota Issues

1. Verify quotas enabled: `beegfs-ctl --getquotainfo`
2. Check quota database: `ls -la /data/beegfs/mgmt/`
3. Review quota logs
4. Verify user/group quotas are set: `beegfs-ctl --getquota`

## Integration with Other Roles

This role works with:

- **beegfs-storage**: Storage target nodes
- **beegfs-meta**: Metadata nodes
- **beegfs-client**: Client mount points
- **monitoring-stack**: BeeGFS metrics monitoring

## See Also

- **[../README.md](../README.md)** - Main Ansible overview
- **[../beegfs-storage/README.md](../beegfs-storage/README.md)** - Storage node setup
- **[../beegfs-meta/README.md](../beegfs-meta/README.md)** - Metadata node setup
- **[../beegfs-client/README.md](../beegfs-client/README.md)** - Client mount setup
- **TODO**: **BeeGFS Official Docs** - Find correct BeeGFS documentation URL (wiki appears down)
