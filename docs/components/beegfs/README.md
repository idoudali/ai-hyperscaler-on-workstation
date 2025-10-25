# BeeGFS (BeeOND) - Berkeley Parallel File System Documentation

**Status:** Production  
**Last Updated:** 2025-10-26  
**Scope:** Complete distributed storage setup, deployment, troubleshooting, and monitoring

## Overview

BeeGFS (also known as BeeOND - Beegfs On Demand) is a parallel clustered file system designed for high-performance
computing environments. This documentation provides comprehensive guidance for deploying BeeGFS in the AI-HOW
hyperscaler infrastructure.

**BeeGFS Features:**

- **Parallel I/O**: Multiple storage nodes for concurrent data access
- **Scalability**: Dynamically add storage nodes to increase capacity
- **Redundancy**: Metadata mirroring and RAID protection options
- **Performance**: User-space FUSE client with optimized access patterns
- **Flexibility**: Shared storage for HPC, containers, and analytics workloads

## Documentation Index

### Main Setup Guide

**→ [BeeGFS (BeeOND) Setup Guide](setup-guide.md)** ⭐ START HERE

The authoritative guide for deploying BeeGFS in the AI-HOW project. Contains:

- Complete architecture overview
- Step-by-step deployment of all components (management, metadata, storage, client)
- Kernel module build troubleshooting
- Performance optimization
- Comprehensive troubleshooting section
- Integration with Ansible roles and playbooks

### Installation and Deployment

- **[Installation Flow](installation-flow.md)** - Complete BeeGFS deployment workflow and component integration patterns
- **[Setup Guide](setup-guide.md)** - Detailed step-by-step setup for each BeeGFS component

### Critical Fixes and Troubleshooting

- **[Fixes Summary](fixes-summary.md)** - Summary of all critical issues identified and fixed during implementation
- **[Client Role Fixes](client-role-fixes.md)** - Detailed documentation of DKMS build failure fixes
- **[Kernel Module Quick Reference](kernel-module-fix.txt)** - Quick troubleshooting guide for kernel module mount failures

### Related Ansible Resources

All BeeGFS roles are documented within the Ansible component structure:

| Component | Path | Purpose |
|-----------|------|---------|
| Management | `ansible/roles/beegfs-mgmt/README.md` | Management node setup |
| Metadata | `ansible/roles/beegfs-meta/README.md` | Metadata server configuration |
| Storage | `ansible/roles/beegfs-storage/README.md` | Storage target setup |
| Client | `ansible/roles/beegfs-client/README.md` | Client mount and configuration |

## Quick Troubleshooting

### Mount Fails with "unknown filesystem type 'beegfs'"

**Root Cause:** Kernel module not built or loaded

**Quick Fix:**

```bash
sudo apt-get update
sudo apt-get install -y linux-headers-$(uname -r) build-essential dkms
sudo dkms install beegfs/8.1.0 -k $(uname -r) --force
sudo modprobe beegfs
sudo mount -a
```

See [Kernel Module Quick Reference](kernel-module-fix.txt) for detailed diagnostics.

### DKMS Build Fails

**Most Common Cause:** Kernel headers don't match running kernel

```bash
uname -r  # Check running kernel
dpkg -s linux-headers-$(uname -r)  # Verify headers installed
```

See [Setup Guide - Kernel Module Build Issues](setup-guide.md#kernel-module-build-issues) for detailed troubleshooting.

### Clients Can't Access Mount

**Diagnosis:**

```bash
beegfs-ctl --listnodes --nodetype mgmt  # Check management node
beegfs-ctl --listtargets                 # List storage targets
beegfs-net                                # Check network connectivity
```

See [Setup Guide - Troubleshooting](setup-guide.md#troubleshooting-guide) for solutions.

## Key Implementation Details

### Kernel Version Mismatch Fix (CRITICAL)

**The Problem:**

- Packer bakes in kernel headers for kernel version X
- At runtime, VM boots with kernel version Y  
- DKMS tries to build against headers for X, fails

**The Solution:**

```yaml
# File: ansible/roles/beegfs-client/tasks/install.yml
- name: Update apt cache and kernel headers to match running kernel
  ansible.builtin.apt:
    name: "linux-headers-{{ ansible_kernel }}"
    state: present
    update_cache: true  # Critical!
```

This ensures headers match before DKMS attempts compilation.

See [Fixes Summary](fixes-summary.md) for complete analysis.

## Testing and Validation

### Running BeeGFS Validation Tests

```bash
# Start BeeGFS test cluster
cd tests
./test-beegfs-framework.sh start-cluster

# Deploy BeeGFS configuration
./test-beegfs-framework.sh deploy-ansible

# Run validation tests
./test-beegfs-framework.sh run-tests

# Clean up
./test-beegfs-framework.sh stop-cluster
```

### Manual Validation

After deployment, verify:

```bash
# All nodes registered
beegfs-ctl --listnodes --nodetype mgmt
beegfs-ctl --listnodes --nodetype meta
beegfs-ctl --listtargets

# Mount successful
mount | grep beegfs
df -h /mnt/beegfs

# Read/write works
dd if=/dev/zero of=/mnt/beegfs/test.txt bs=1M count=100
rm /mnt/beegfs/test.txt
```

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────┐
│                  BeeGFS (BeeOND) File System            │
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

## Performance Monitoring

### Monitor Storage Performance

```bash
beegfs-ctl --getsysinfo target <targetID>
watch -n 1 'iostat -x 1 | grep sda'
beegfs-ctl --listtargets
```

### Monitor Metadata Performance

```bash
beegfs-ctl --getsysinfo metadata <metaID>
cat /proc/fs/beegfs/*/meta_stats
watch -n 1 'beegfs-ctl --getsysinfo metadata'
```

### Monitor Client Performance

```bash
watch -n 1 'iostat -x 1'
mount | grep beegfs
iftop -i eth0
```

## Log Files and Diagnostics

| Component | Log Location |
|-----------|--------------|
| Management | `/var/log/beegfs/beegfs-mgmtd.log` |
| Metadata | `/var/log/beegfs/beegfs-meta.log` |
| Storage | `/var/log/beegfs/beegfs-storage.log` |
| Client | `/var/log/beegfs/beegfs-client.log` |

### Collect Diagnostic Information

```bash
mkdir -p ~/beegfs-diagnostics
cd ~/beegfs-diagnostics

# System info
uname -a > uname.log
dkms status beegfs > dkms-status.log

# BeeGFS status
beegfs-ctl --listnodes --nodetype mgmt > mgmt-nodes.log
beegfs-ctl --listtargets > storage-targets.log
mount | grep beegfs > mounts.log

# Copy logs
cp -r /var/log/beegfs/* .

# Compress for sharing
tar czf ~/beegfs-diagnostics.tar.gz ~/beegfs-diagnostics
```

## Related Documentation

### Project Components

- **Ansible Roles:** See `ansible/roles/beegfs-*/` for detailed role documentation
- **Design Documents:** See `docs/design-docs/` for architecture and design decisions
- **Test Framework:** See `tests/test-beegfs-framework.sh` for validation procedures

### External References

- BeeGFS Official: https://www.beegfs.io/
- Debian BeeGFS: https://wiki.debian.org/BeeGFS
- DKMS Documentation: https://github.com/dell/dkms

## Deployment Integration

### Using with Ansible Playbooks

```bash
# Full HPC runtime including BeeGFS
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml

# BeeGFS components only
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml \
  --tags beegfs

# Configuration only
ansible-playbook -i inventories/hpc/hosts.yml playbook-beegfs-runtime-config.yml
```

### Packer Image Integration

BeeGFS packages are pre-installed in Packer-built VM images:

1. **Build Time:** BeeGFS packages installed and kernel module compiled
2. **Runtime:** Kernel headers updated to match running kernel, module re-built as needed

See [Installation Flow](installation-flow.md) for complete details.

## Summary

This BeeGFS (BeeOND) documentation provides:

✅ Complete setup guide with architecture overview  
✅ Step-by-step deployment procedures  
✅ Critical fixes identified and implemented  
✅ Comprehensive troubleshooting  
✅ Performance optimization recommendations  
✅ Integration with Ansible playbooks  
✅ Testing and validation procedures  

**Start with:** [BeeGFS (BeeOND) Setup Guide](setup-guide.md)

---

**Last Updated:** 2025-10-26  
**Version:** 1.0 (Production)  
**Maintainer:** AI-HOW Project
