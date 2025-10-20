# Virtio-FS Mount Role

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This Ansible role configures Virtio-FS shared storage mounts for VM-based workloads. Virtio-FS
provides high-performance shared file system access between host and guest virtual machines
using the virtio transport mechanism.

## Purpose

The Virtio-FS role provides:

- **Virtio-FS Daemon**: User-space file system daemon (virtiofsd)
- **Mount Configuration**: Persistent mount point setup
- **Performance Tuning**: Cache and buffer optimization
- **Security**: User mapping and permission control
- **Hot Plug Support**: Dynamic mount/unmount capability
- **Monitoring**: Performance statistics collection

## Variables

### Required Variables

- `virtiofs_mount_point`: Mount path (default: /mnt/virtiofs)
- `virtiofs_shared_dir`: Host directory to share (default: /shared)

### Configuration Variables

**Mount Configuration:**

- `virtiofs_mount_point`: Where to mount virtio-fs (default: /mnt/virtiofs)
- `virtiofs_mount_owner`: Mount directory owner (default: root)
- `virtiofs_mount_group`: Mount directory group (default: root)
- `virtiofs_mount_mode`: Directory permissions (default: 0755)

**Performance Tuning:**

- `virtiofs_cache_mode`: Cache mode ("auto", "always", "never", default: "auto")
- `virtiofs_thread_pool_size`: Thread pool size (default: 4)
- `virtiofs_queue_size`: Queue size (default: 256)
- `virtiofs_buffer_size`: Buffer size (default: 4MB)

**Security:**

- `virtiofs_uid_map`: UID mapping enabled (default: true)
- `virtiofs_gid_map`: GID mapping enabled (default: true)
- `virtiofs_uid_map_start`: UID map start (default: 0)
- `virtiofs_gid_map_start`: GID map start (default: 0)

**Advanced Options:**

- `virtiofs_direct_io`: Enable direct I/O (default: true)
- `virtiofs_keep_cache`: Keep cache mode (default: true)
- `virtiofs_readdirplus`: Readdir+ support (default: true)

## Usage

### Basic Virtio-FS Mount

```yaml
- hosts: vm_guests
  become: true
  roles:
    - virtio-fs-mount
  vars:
    virtiofs_mount_point: "/mnt/virtiofs"
```

### High-Performance Configuration

```yaml
- hosts: vm_guests
  become: true
  roles:
    - virtio-fs-mount
  vars:
    virtiofs_mount_point: "/mnt/virtiofs"
    virtiofs_cache_mode: "always"
    virtiofs_thread_pool_size: 8
    virtiofs_buffer_size: "16MB"
```

### With User Mapping

```yaml
- hosts: vm_guests
  become: true
  roles:
    - virtio-fs-mount
  vars:
    virtiofs_mount_point: "/mnt/virtiofs"
    virtiofs_uid_map: true
    virtiofs_gid_map: true
    virtiofs_uid_map_start: 1000
    virtiofs_gid_map_start: 1000
```

### Read-Only Mount

```yaml
- hosts: vm_guests
  become: true
  roles:
    - virtio-fs-mount
  vars:
    virtiofs_mount_point: "/mnt/virtiofs"
    virtiofs_cache_mode: "never"
    virtiofs_direct_io: true
```

## Dependencies

This role requires:

- Debian-based system (Debian 11+)
- Root privileges
- Virtio-FS device configured in VM
- Host running virtiofsd daemon
- Linux kernel with Virtio-FS support (5.4+)

## What This Role Does

1. **Installs Virtio-FS Tools**: Installs virtiofs packages
2. **Creates Mount Point**: Sets up directory for mount
3. **Configures Mount Parameters**: Sets up mount options
4. **Enables Auto-Mount**: Configures fstab for persistence
5. **Performs Initial Mount**: Mounts the file system
6. **Verifies Configuration**: Tests mount functionality
7. **Sets Up Monitoring**: Configures performance tracking

## Tags

Available Ansible tags:

- `virtiofs_mount`: All virtio-fs tasks
- `virtiofs_packages`: Package installation
- `virtiofs_config`: Configuration only
- `virtiofs_security`: Security setup
- `virtiofs_performance`: Performance tuning

## Example Playbook

```yaml
---
- name: Deploy Virtio-FS Mounts
  hosts: vm_guests
  become: yes
  roles:
    - virtio-fs-mount
  vars:
    virtiofs_mount_point: "/mnt/virtiofs"
    virtiofs_cache_mode: "always"
    virtiofs_thread_pool_size: 8
    virtiofs_uid_map: true
```

## Service Management

```bash
# Check mount status
mount | grep virtiofs

# View mount details
findmnt /mnt/virtiofs

# Unmount (if needed)
sudo umount /mnt/virtiofs

# Remount with new options
sudo mount -o remount,<options> /mnt/virtiofs
```

## Verification

After deployment, verify virtio-fs setup:

```bash
# Check mount point
df -h /mnt/virtiofs

# List directory
ls -la /mnt/virtiofs

# Test read/write
dd if=/dev/zero of=/mnt/virtiofs/test.txt bs=1M count=100

# Check mount options
mount | grep virtiofs

# View statistics
cat /proc/fs/virtiofs/stats
```

## Performance Monitoring

Monitor virtio-fs performance:

```bash
# View mount statistics
cat /proc/fs/virtiofs/stats

# Monitor I/O operations
iostat -x 1 /mnt/virtiofs

# Check cache efficiency
grep cache /proc/fs/virtiofs/stats

# Monitor network throughput
iftop -i <network_interface>
```

## Log Files

Virtio-FS generates logs at:

- System journal: `journalctl -u mount`
- Host virtiofsd logs (depends on host configuration)

View logs:

```bash
# Check mount operations
journalctl -u mount | grep virtiofs

# Check for errors
dmesg | grep -i virtio
```

## Troubleshooting

### Mount Fails

1. Check device exists: `ls -la /dev/vhost*`
2. Check host virtiofsd: Verify host daemon is running
3. Check logs: `dmesg | grep -i virtio`
4. Review fstab: `cat /etc/fstab | grep virtiofs`

### Can't Access Mount Point

1. Check mount is active: `mount | grep virtiofs`
2. Verify permissions: `ls -la /mnt/virtiofs`
3. Check owner/group: `stat /mnt/virtiofs`
4. Test access: `touch /mnt/virtiofs/test`

### Poor Performance

1. Check cache mode: `grep virtiofs /proc/mounts`
2. Verify thread pool: `cat /proc/fs/virtiofs/stats`
3. Monitor I/O: `iostat -x 1`
4. Check CPU usage

### Permission Denied

1. Verify UID/GID mapping: `grep uid_map /proc/mounts`
2. Check user permissions
3. Try as sudo
4. Verify ownership: `stat /mnt/virtiofs`

## Common Operations

### Remount with Different Cache Mode

```bash
# Unmount
sudo umount /mnt/virtiofs

# Remount with different cache
sudo mount -o cache=always /mnt/virtiofs

# Verify
mount | grep virtiofs
```

### Change Permissions

```bash
# Change owner
sudo chown user:group /mnt/virtiofs

# Change permissions
sudo chmod 0755 /mnt/virtiofs
```

### Monitor Performance

```bash
# Real-time I/O monitoring
watch -n 1 'iostat -x 1 /mnt/virtiofs'

# Cache statistics
watch -n 1 'cat /proc/fs/virtiofs/stats'
```

## Cache Modes

### Auto Mode (Default)

Kernel automatically manages caching based on access patterns.

```yaml
virtiofs_cache_mode: "auto"
```

### Always Cache

All data cached, fastest but risk of data loss.

```yaml
virtiofs_cache_mode: "always"
```

### Never Cache

No caching, safest but slower performance.

```yaml
virtiofs_cache_mode: "never"
```

## Performance Tuning

### For Read-Heavy Workloads

```yaml
virtiofs_cache_mode: "always"
virtiofs_thread_pool_size: 8
virtiofs_buffer_size: "16MB"
virtiofs_readdirplus: true
```

### For Write-Heavy Workloads

```yaml
virtiofs_cache_mode: "auto"
virtiofs_thread_pool_size: 16
virtiofs_direct_io: true
```

### For Low-Latency Workloads

```yaml
virtiofs_cache_mode: "never"
virtiofs_direct_io: true
virtiofs_thread_pool_size: 4
```

## Security Considerations

### User Mapping

Enable user namespace mapping for security:

```yaml
virtiofs_uid_map: true
virtiofs_gid_map: true
virtiofs_uid_map_start: 1000
virtiofs_gid_map_start: 1000
```

### Read-Only Mount

For read-only access:

```yaml
virtiofs_cache_mode: "never"
# Add ro to mount options in fstab
```

## Integration with Other Roles

This role works with:

- **beegfs-client**: Distributed storage mounting
- **container-runtime**: Container shared storage

## See Also

- **[../README.md](../README.md)** - Main Ansible overview
- **[../beegfs-client/README.md](../beegfs-client/README.md)** - BeeGFS client setup
- **[QEMU Virtio-FS](https://qemu.readthedocs.io/en/latest/tools/virtiofsd.html)** - virtiofsd documentation
- **[Linux Kernel Virtio-FS](https://www.kernel.org/doc/html/latest/filesystems/virtiofs.html)** - Kernel docs
