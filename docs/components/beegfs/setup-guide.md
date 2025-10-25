# BeeGFS (BeeOND) Distributed File System Setup Guide

**Status:** Production  
**Last Updated:** 2025-10-26  
**Scope:** Complete BeeGFS deployment from management node through client mounting

## Overview

This guide consolidates the complete BeeGFS (also known as BeeOND - Beegfs On Demand) setup process, including
kernel module compilation, installation of management, metadata, storage, and client components, and
troubleshooting common issues.

BeeGFS is a parallel clustered file system designed for high-performance computing environments, providing:

- **Parallel I/O**: Multiple storage nodes for concurrent data access
- **Scalability**: Easily add storage nodes to increase capacity
- **Redundancy**: Metadata mirroring and RAID protection options
- **Performance**: User-space FUSE client with optimized access patterns
- **Flexibility**: Shared storage for HPC, containers, and analytics workloads

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────┐
│                   BeeGFS (BeeOND) File System           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐      ┌──────────────┐                │
│  │ Management   │      │ Metadata     │                │
│  │ Node         │ ◄──► │ Nodes        │                │
│  │ (beegfs-mgmt)│      │ (beegfs-meta)│                │
│  └──────────────┘      └──────────────┘                │
│         ▲                       ▲                        │
│         │                       │                        │
│         └───────────┬───────────┘                        │
│                     │                                    │
│    ┌────────────────┴─────────────────┐                │
│    │                                   │                 │
│  ┌─▼─────────────────┐    ┌──────────▼──┐              │
│  │ Storage Nodes     │    │ Storage      │              │
│  │ (beegfs-storage)  │    │ Nodes        │              │
│  │ Target: 101       │    │ Target: 102  │              │
│  └───────────────────┘    └──────────────┘              │
│           ▲                       ▲                      │
│           │                       │                      │
│           └───────────┬───────────┘                      │
│                       │                                   │
│  ┌────────────────────┴─────────────────┐               │
│  │                                        │               │
│ ┌▼─────────────────┐  ┌────────────────▼┐              │
│ │ Client 1        │  │ Client 2        │              │
│ │ (beegfs-client) │  │ (beegfs-client) │              │
│ │ Mount: /mnt/... │  │ Mount: /mnt/... │              │
│ └─────────────────┘  └─────────────────┘              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Deployment Prerequisites

### Kernel Module Build Requirements

Before deploying BeeGFS, ensure the kernel module can be built on all nodes:

**CRITICAL:** The kernel headers installed must match the RUNNING kernel version:

```bash
# Check running kernel
uname -r
# Example output: 6.12.48+deb13-cloud-amd64

# Verify matching headers are installed
dpkg -s linux-headers-$(uname -r)
# Should show: Status: install ok installed

# If headers don't match, update them
sudo apt-get update
sudo apt-get install -y linux-headers-$(uname -r)
```

**Build Dependencies:**

```bash
sudo apt-get install -y \
  build-essential \
  dkms \
  linux-headers-$(uname -r) \
  gcc \
  make
```

### Prerequisites Checklist

Before deploying BeeGFS, verify:

- ✅ All nodes have matching kernel versions
- ✅ Kernel headers installed matching running kernel
- ✅ Build-essential and DKMS installed on all nodes
- ✅ Network connectivity between all nodes (firewall rules open)
- ✅ Sufficient disk space for metadata and storage directories
- ✅ Root/sudo access on all nodes
- ✅ Debian 11+ (Trixie/Bookworm) systems

## Component Deployment Order

Deploy BeeGFS in this specific order:

1. **Management Node** (beegfs-mgmt) - Central administrative point
2. **Metadata Nodes** (beegfs-meta) - File attributes and inode storage
3. **Storage Nodes** (beegfs-storage) - Actual data storage
4. **Client Nodes** (beegfs-client) - Mount and access file system

### 1. Management Node Deployment

The management node is the central administrative point for the BeeGFS cluster.

**Role:** `beegfs-mgmt`  
**File:** `ansible/roles/beegfs-mgmt/README.md`

#### Key Variables

```yaml
beegfs_fs_name: "hpc_storage"           # File system name
beegfs_mgmt_port: 8008                  # Management port
beegfs_mgmt_data_dir: "/data/beegfs/mgmt"  # Metadata directory
beegfs_quotas_enabled: false            # Enable quotas (optional)
beegfs_mgmt_ha_enabled: false           # Enable HA (optional)
```

#### Deployment Steps

1. **Install management daemon:**
   - Downloads and installs beegfs-mgmtd package
   - Creates data directories with proper permissions
   - Generates configuration file (beegfs-mgmtd.conf)

2. **Configure management node:**
   - Sets file system name
   - Configures listening port
   - Enables statistics collection
   - Sets up log files and rotation

3. **Start services:**
   - Enables beegfs-mgmtd for auto-start
   - Starts management daemon
   - Verifies connectivity

#### Verification

```bash
# Check management daemon is running
systemctl status beegfs-mgmtd

# View listening ports
netstat -tulpn | grep 8008

# Check file system status
beegfs-ctl --listnodes --nodetype mgmt

# View logs
tail -f /var/log/beegfs/beegfs-mgmtd.log
```

### 2. Metadata Node Deployment

Metadata nodes store file attributes, permissions, and inode information.

**Role:** `beegfs-meta`  
**File:** `ansible/roles/beegfs-meta/README.md`

#### Key Variables

```yaml
beegfs_fs_name: "hpc_storage"           # Must match management node
beegfs_mgmt_host: "192.168.100.10"      # Management node address
beegfs_meta_node_id: 1                  # Unique per metadata node
beegfs_meta_data_dir: "/data/beegfs/meta"  # Metadata directory
beegfs_meta_num_workers: 8              # Worker threads
beegfs_meta_cache_size: "512MB"         # Metadata cache
beegfs_meta_journal_enabled: true       # Transaction logging
```

#### Deployment Steps

1. **Install metadata daemon:**
   - Installs beegfs-meta package
   - Creates metadata storage directories
   - Sets up journaling

2. **Configure metadata node:**
   - Assigns unique node ID
   - Configures connection to management node
   - Sets performance parameters
   - Enables journaling for crash recovery

3. **Register and start:**
   - Registers with management node
   - Enables auto-start
   - Starts metadata daemon

#### Verification

```bash
# Check metadata daemon status
systemctl status beegfs-meta

# List all metadata nodes
beegfs-ctl --listnodes --nodetype meta

# View metadata statistics
beegfs-ctl --getsysinfo metadata

# Check logs
tail -f /var/log/beegfs/beegfs-meta.log
```

### 3. Storage Node Deployment

Storage nodes provide the actual data storage capacity.

**Role:** `beegfs-storage`  
**File:** `ansible/roles/beegfs-storage/README.md`

#### Key Variables

```yaml
beegfs_fs_name: "hpc_storage"           # Must match management node
beegfs_mgmt_host: "192.168.100.10"      # Management node address
beegfs_storage_target_id: 101           # Unique per storage node
beegfs_storage_data_dir: "/data/beegfs/storage"  # Storage directory
beegfs_storage_port: 8003               # Storage daemon port
beegfs_storage_direct_io: true          # Enable direct I/O
beegfs_storage_num_workers: 8           # Worker threads
beegfs_storage_buffer_size: "32MB"      # I/O buffer size
beegfs_storage_checksums: false         # Data checksums (optional)
```

#### Deployment Steps

1. **Install storage daemon:**
   - Installs beegfs-storage package
   - Creates storage directories
   - Prepares storage targets

2. **Configure storage node:**
   - Assigns unique target ID
   - Configures connection to management node
   - Sets performance parameters
   - Enables direct I/O for performance

3. **Register and start:**
   - Registers storage target with management
   - Enables auto-start
   - Starts storage daemon

#### Verification

```bash
# Check storage daemon status
systemctl status beegfs-storage

# List all storage targets
beegfs-ctl --listtargets

# View target capacity
beegfs-ctl --getnodes --nodetype storage

# Check reachability
beegfs-net

# View logs
tail -f /var/log/beegfs/beegfs-storage.log
```

### 4. Client Node Deployment

Client nodes mount and access the BeeGFS file system.

**Role:** `beegfs-client`  
**File:** `ansible/roles/beegfs-client/README.md`

#### Key Variables

```yaml
beegfs_fs_name: "hpc_storage"           # Must match management node
beegfs_mgmt_host: "192.168.100.10"      # Management node address
beegfs_mount_point: "/mnt/beegfs"       # Mount path
beegfs_client_cache_size: "1GB"         # Client cache size
beegfs_client_num_threads: 8            # Worker threads
beegfs_client_write_cache: true         # Write caching
beegfs_client_failover_enabled: true    # Automatic failover
```

#### Deployment Steps

1. **Install client packages:**
   - Installs FUSE library
   - Installs beegfs-client package
   - Builds kernel module via DKMS
   - ⚠️ **CRITICAL**: This step fails if kernel headers don't match!

2. **Configure client:**
   - Creates mount point
   - Generates client configuration
   - Sets performance parameters
   - Configures persistent mount in fstab

3. **Mount file system:**
   - Loads kernel module
   - Performs initial mount
   - Verifies connectivity to management and storage nodes

#### Verification

```bash
# Check mount point
mount | grep beegfs
df -h /mnt/beegfs

# List directory
ls -la /mnt/beegfs

# Test read/write
dd if=/dev/zero of=/mnt/beegfs/test-$(hostname).txt bs=1M count=10

# Check client status
beegfs-net

# View logs
tail -f /var/log/beegfs/beegfs-client.log
```

---

## Kernel Module Build Issues

The most common deployment failure is BeeGFS client kernel module build failure.

### Root Cause: Kernel Version Mismatch

The kernel headers installed on a node may not match the RUNNING kernel version.

**Example Scenario:**

```bash
# Packer build installed headers for:
6.12.38+deb13-cloud-amd64

# But at runtime, VM boots with:
6.12.48+deb13-cloud-amd64

# DKMS fails because it can't find headers for 6.12.48
```

### Fix: Update Kernel Headers

The beegfs-client role includes an early kernel headers update to fix this:

```yaml
# File: ansible/roles/beegfs-client/tasks/install.yml
- name: Update apt cache and kernel headers to match running kernel
  ansible.builtin.apt:
    name: "linux-headers-{{ ansible_kernel }}"
    state: present
    update_cache: true  # Important: update cache first
```

This ensures headers match `ansible_kernel` (the running kernel) before DKMS attempts compilation.

### Common DKMS Build Errors

#### Error 1: "kernel headers cannot be found"

```bash
Error! Your kernel headers for kernel 6.12.48+deb13-cloud-amd64 cannot be found
```

**Fix:**

```bash
sudo apt-get update
sudo apt-get install -y linux-headers-$(uname -r)
```

#### Error 2: "gcc/build-essential not found"

```bash
gcc: command not found
```

**Fix:**

```bash
sudo apt-get install -y build-essential dkms
```

#### Error 3: "DKMS build fails with compilation errors"

**Fix:**

```bash
# View detailed build output
sudo dkms install beegfs/8.1.0 -k $(uname -r) --verbose 2>&1 | tee ~/dkms-build.log

# Check DKMS build log
cat /var/lib/dkms/beegfs/8.1.0/build/make.log

# Review kernel logs
dmesg | tail -50
```

### Manual Kernel Module Build and Mount

If the role fails, manually fix and mount BeeGFS:

```bash
# 1. Update kernel headers to match running kernel
sudo apt-get update
sudo apt-get install -y linux-headers-$(uname -r) build-essential dkms

# 2. Build DKMS module manually
sudo dkms install beegfs/8.1.0 -k $(uname -r) --verbose 2>&1 | tee ~/dkms-build.log

# 3. Verify module was built
find /lib/modules/$(uname -r) -name "beegfs.ko*"
# Should output: /lib/modules/6.12.48+deb13-cloud-amd64/updates/dkms/beegfs.ko.xz

# 4. Load module
sudo modprobe beegfs
lsmod | grep beegfs
# Should show: beegfs ... 0

# 5. Create mount point and mount
sudo mkdir -p /mnt/beegfs
sudo mount -t beegfs beegfs_nodev /mnt/beegfs \
  -o cfgFile=/etc/beegfs/beegfs-client.conf,_netdev

# 6. Verify mount
mount | grep beegfs
df -h /mnt/beegfs
```

---

## Troubleshooting Guide

### Issue: Mount Fails with "unknown filesystem type 'beegfs'"

**Cause:** Kernel module not loaded or not found

**Diagnosis:**

```bash
# Check if module exists
find /lib/modules/$(uname -r) -name "beegfs.ko*"
# If empty, module not built

# Check if module is loaded
lsmod | grep beegfs
# If empty, module not loaded
```

**Fix:**

```bash
# 1. Check DKMS status
/usr/sbin/dkms status beegfs
# Should show: beegfs/8.1.0, 6.12.48+deb13-cloud-amd64, x86_64: installed

# 2. If status shows "installed" but module missing, rebuild
sudo dkms install beegfs/8.1.0 -k $(uname -r) --force

# 3. Load module
sudo modprobe beegfs

# 4. Try mount again
sudo mount -a
```

### Issue: Clients Can't Connect to Storage

**Diagnosis:**

```bash
# Check if storage nodes are visible
beegfs-ctl --listtargets

# Check connectivity
beegfs-net

# Check logs for connection errors
tail -f /var/log/beegfs/beegfs-client.log | grep -i "error\|connection"
```

**Common Causes:**

1. **Storage nodes not running:**

   ```bash
   ssh storage-node-1 systemctl status beegfs-storage
   ```

2. **Network connectivity issues:**

   ```bash
   # From client
   ping storage-node-1
   # Check firewall rules on storage nodes
   sudo iptables -L | grep 8003
   ```

3. **Management node not reachable:**

   ```bash
   # Verify management daemon running
   ssh mgmt-node systemctl status beegfs-mgmtd
   # Check connectivity from client
   nc -zv mgmt-node 8008
   ```

### Issue: Poor Performance

**Check current configuration:**

```bash
# View client configuration
cat /etc/beegfs/beegfs-client.conf | grep -E "^[^#]" | head -20

# Check cache size
grep clientMaxCacheSize /etc/beegfs/beegfs-client.conf

# Check worker threads
grep numWorkers /etc/beegfs/beegfs-client.conf

# Check read-ahead
grep readAheadSize /etc/beegfs/beegfs-client.conf
```

**Optimization suggestions:**

For **small files** workload:

```yaml
beegfs_client_cache_size: "2GB"
beegfs_client_read_ahead: "8M"
beegfs_client_stripe_pattern: "RAID0"
```

For **large files** workload:

```yaml
beegfs_client_cache_size: "8GB"
beegfs_client_read_ahead: "32M"
beegfs_client_stripe_pattern: "RAID10"
```

For **sequential I/O** workload:

```yaml
beegfs_client_read_ahead: "64M"
beegfs_client_num_threads: 16
beegfs_client_write_cache: true
```

### Issue: Metadata Node High CPU Usage

**Diagnosis:**

```bash
# Monitor CPU on metadata node
top -p $(pgrep beegfs-meta)

# Check worker threads setting
grep numWorkers /etc/beegfs/beegfs-meta.conf

# Check cache hit ratio
cat /proc/fs/beegfs/*/meta_stats
```

**Optimization:**

```yaml
# For many small files
beegfs_meta_num_workers: 16
beegfs_meta_cache_size: "4GB"
beegfs_meta_inode_hash_size: 524288
```

### Issue: Storage Node Disk Full

**Diagnosis:**

```bash
# Check disk usage
df -h /data/beegfs/storage

# Check storage target status
beegfs-ctl --getnodes --nodetype storage
```

**Solution:**

1. Free up disk space
2. Add new storage targets if needed
3. Rebalance data:

   ```bash
   beegfs-ctl --rebalance
   ```

---

## Performance Monitoring

### Monitor Storage Performance

```bash
# View storage target stats
beegfs-ctl --getsysinfo target <targetID>

# Monitor I/O latency
watch -n 1 'iostat -x 1 | grep sda'

# Check storage capacity
beegfs-ctl --listtargets

# Monitor real-time I/O
iotop -o
```

### Monitor Metadata Performance

```bash
# View metadata stats
beegfs-ctl --getsysinfo metadata <metaID>

# Check cache efficiency
cat /proc/fs/beegfs/*/meta_stats

# Monitor metadata operations
watch -n 1 'beegfs-ctl --getsysinfo metadata'
```

### Monitor Client Performance

```bash
# View client stats
beegfs-ctl --getquotainfo

# Monitor I/O from client
watch -n 1 'iostat -x 1'

# Check mount options
mount | grep beegfs

# Monitor network usage
iftop -i eth0
```

---

## Log Files and Diagnostics

### Log File Locations

| Component | Log File |
|-----------|----------|
| Management | `/var/log/beegfs/beegfs-mgmtd.log` |
| Metadata | `/var/log/beegfs/beegfs-meta.log` |
| Storage | `/var/log/beegfs/beegfs-storage.log` |
| Client | `/var/log/beegfs/beegfs-client.log` |

### View Real-Time Logs

```bash
# View management logs
tail -f /var/log/beegfs/beegfs-mgmtd.log

# View errors only
grep ERROR /var/log/beegfs/*.log | tail -20

# Search specific patterns
grep "Connection refused" /var/log/beegfs/beegfs-client.log
```

### Collect Diagnostic Information

```bash
# Create diagnostic bundle
mkdir -p ~/beegfs-diagnostics
cd ~/beegfs-diagnostics

# Collect system info
uname -a > uname.log
dkms status beegfs > dkms-status.log
beegfs-ctl --listnodes --nodetype mgmt > mgmt-nodes.log
beegfs-ctl --listnodes --nodetype meta > meta-nodes.log
beegfs-ctl --listtargets > storage-targets.log
mount | grep beegfs > mounts.log
df -h /mnt/beegfs >> mounts.log

# Collect logs
cp -r /var/log/beegfs/* .

# Compress
tar czf ~/beegfs-diagnostics.tar.gz ~/beegfs-diagnostics
```

---

## Integration with Ansible Playbooks

### Full HPC Runtime Deployment with BeeGFS

```bash
# Run complete HPC runtime including BeeGFS
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml

# Run only BeeGFS components
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml \
  --tags beegfs

# Configure BeeGFS separately
ansible-playbook -i inventories/hpc/hosts.yml playbook-beegfs-runtime-config.yml
```

### Playbook Breakdown

The BeeGFS deployment happens in stages:

1. **Packer Image Build** (pre-deployment):
   - Installs BeeGFS packages
   - Builds kernel module for image kernel version
   - Baked into VM images

2. **Runtime Deployment** (post-VM boot):
   - Early kernel headers update (critical fix!)
   - Re-builds kernel module for actual running kernel
   - Deploys management, metadata, storage, client services
   - Mounts file system

---

## Related Documentation

- **Ansible Roles:** See `ansible/roles/beegfs-*/README.md` for detailed role documentation
- **Fixes Summary:** See [Fixes Summary](fixes-summary.md) for critical fixes implemented
- **Installation Flow:** See [Installation Flow](installation-flow.md) for component integration
- **Quick Reference:** See [Kernel Module Quick Reference](kernel-module-fix.txt) for kernel module troubleshooting

---

## References

- BeeGFS Official Documentation: https://www.beegfs.io/
- Debian Wiki: https://wiki.debian.org/BeeGFS
- Project Design: `docs/design-docs/slurm-config.md`

---

**Last Updated:** 2025-10-26  
**Maintainer:** AI-HOW Team  
**Status:** Production
