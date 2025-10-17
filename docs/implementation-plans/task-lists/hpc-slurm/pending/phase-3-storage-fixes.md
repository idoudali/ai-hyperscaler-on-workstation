# Phase 3: Storage Infrastructure Fixes (Task 028.1)

**Status**: In Progress  
**Last Updated**: 2025-10-17  
**Priority**: HIGH  
**Tasks**: 1

## Overview

Critical bug fix to resolve BeeGFS 7.4.4 client kernel module incompatibility with Linux kernel 6.12.x. This enables
full BeeGFS filesystem mounting and client functionality across all cluster nodes.

---

- **ID**: TASK-028.1
- **Phase**: 3 - Infrastructure Enhancements
- **Dependencies**: TASK-028
- **Estimated Time**: 6 hours
- **Difficulty**: Advanced
- **Status**: Pending
- **Priority**: HIGH
- **Type**: Bug Fix / Infrastructure Improvement

**Description:** Resolve BeeGFS 7.4.4 client kernel module incompatibility with Linux kernel 6.12.x by rebuilding VM
base images with a compatible kernel version. This enables full BeeGFS filesystem mounting and client functionality
across all cluster nodes.

**Problem Statement:**

BeeGFS 7.4.4 client kernel module fails to build on Linux kernel 6.12.x due to breaking kernel API changes:

```text
Root Cause: BeeGFS 7.4.4 is incompatible with kernel 6.12.x API

DKMS Build Errors:
- generic_fillattr() function signature changed
- inode_owner_or_capable() function signature changed  
- SetPageError() function removed from kernel
- asm/unaligned.h header moved/renamed

Impact:
- ✅ BeeGFS server services (mgmtd, meta, storage) running correctly
- ✅ All service daemons stable and communicating
- ❌ Client kernel module cannot be built or loaded
- ❌ Cannot mount BeeGFS filesystem on any node
- ❌ Filesystem operations and performance tests fail
- ❌ Cannot use distributed parallel storage capabilities
```

**Current Workaround (Implemented):**

The Ansible deployment has been updated to handle DKMS build failures gracefully:

- Kernel headers installation automated
- DKMS build attempted with proper error handling
- Deployment completes successfully with warnings
- Services operational but client mounting unavailable

**Deliverables:**

- ✅ Rebuild `hpc-controller` and `hpc-compute` base images with kernel 6.1 or 6.6 LTS
- ✅ Update Packer templates to install compatible kernel version
- ✅ Verify DKMS build succeeds with compatible kernel
- ✅ Test BeeGFS filesystem mounting on all nodes
- ✅ Validate filesystem operations and performance tests pass
- ✅ Update documentation with kernel compatibility requirements

**Proposed Solution (Solution 1): Use Compatible Kernel** ⭐ **RECOMMENDED**

Rebuild VM base images with Linux kernel 6.1 LTS or 6.6 LTS, which are fully supported by BeeGFS 7.4.4.

**Implementation Steps:**

1. **Update Packer Base Image Provisioning:**

```yaml
# File: packer/hpc-base/setup-hpc-base.sh
# Add before BeeGFS installation

# Install kernel 6.6 LTS (if available) or 6.1 LTS
apt-get update
apt-get install -y linux-image-6.6-cloud-amd64 linux-headers-6.6-cloud-amd64

# Set as default boot kernel
sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT="Advanced options>kernel-6.6"/' /etc/default/grub
update-grub

# Hold kernel version to prevent auto-updates
apt-mark hold linux-image-6.6-cloud-amd64 linux-headers-6.6-cloud-amd64
```

1. **Update Ansible BeeGFS Client Role:**

```yaml
# File: ansible/roles/beegfs-client/tasks/install.yml
# Add kernel version validation

- name: Check kernel compatibility with BeeGFS
  ansible.builtin.command:
    cmd: uname -r
  register: kernel_version
  changed_when: false

- name: Warn if kernel version may be incompatible
  ansible.builtin.debug:
    msg: "WARNING: Kernel {{ kernel_version.stdout }} may not be compatible with BeeGFS 7.4.4. Recommended: 6.1 or 6.6 LTS"
  when: "'6.12' in kernel_version.stdout or '6.13' in kernel_version.stdout or '6.14' in kernel_version.stdout"
```

1. **Rebuild VM Images:**

```bash
# Rebuild controller image with compatible kernel
cd packer/hpc-controller
packer build hpc-controller.pkr.hcl

# Rebuild compute images with compatible kernel
cd ../hpc-compute  
packer build hpc-compute.pkr.hcl

# Verify kernel version in built images
qemu-system-x86_64 -enable-kvm -m 4G \
  -hda ../../build/packer/hpc-controller/hpc-controller.qcow2 \
  -nographic
# Check: uname -r should show 6.1 or 6.6
```

1. **Redeploy and Validate:**

```bash
# Deploy BeeGFS with new images
cd tests
./test-beegfs-framework.sh deploy-ansible

# Verify kernel module builds successfully
ssh hpc-controller "dkms status beegfs"
# Expected: beegfs/7.4.4, 6.6.x-cloud-amd64, x86_64: installed

# Verify filesystem mounts
ssh hpc-controller "mount | grep beegfs"
# Expected: beegfs_nodev on /mnt/beegfs type beegfs

# Run full test suite
./test-beegfs-framework.sh run-tests
# Expected: All 29 service validation tests pass
```

**Alternative Solution (Solution 3): Accept Limitation and Document**

Document the kernel compatibility limitation and continue with BeeGFS server services only (no client mounting).

**Implementation:**

1. **Update Documentation:**

```markdown
# docs/BEEGFS-DEPLOYMENT.md

## Known Limitations

### Kernel Compatibility

BeeGFS 7.4.4 client kernel module is **not compatible** with Linux kernel 6.12+.

**Affected Functionality:**
- ❌ Client filesystem mounting
- ❌ Local filesystem operations
- ❌ Performance benchmarks requiring mounted filesystem

**Working Functionality:**
- ✅ Management service (beegfs-mgmtd)
- ✅ Metadata service (beegfs-meta)
- ✅ Storage services (beegfs-storage)
- ✅ Service-to-service communication
- ✅ Cluster health monitoring via beegfs-ctl

**Workaround:**
- Use network-based access (NFS gateway on top of BeeGFS)
- Access BeeGFS storage via API/tools rather than POSIX mount
- Wait for BeeGFS 7.5+ with kernel 6.12 support
```

1. **Update Test Expectations:**

```bash
# tests/suites/beegfs/run-beegfs-tests.sh
# Skip client mounting tests if kernel incompatible

if [[ "$(uname -r)" =~ ^6\.1[2-9] ]]; then
  echo "WARN: Kernel $(uname -r) not compatible with BeeGFS 7.4.4 client"
  echo "INFO: Skipping client mount and filesystem tests"
  SKIP_CLIENT_TESTS=true
fi
```

**Validation Criteria:**

- [ ] VM base images rebuilt with kernel 6.1 or 6.6 LTS
- [ ] Kernel version held to prevent auto-updates
- [ ] BeeGFS DKMS module builds successfully on new kernel
- [ ] Client kernel module loads without errors (`lsmod | grep beegfs`)
- [ ] BeeGFS filesystem mounts on all nodes
- [ ] All 29 service validation tests pass (100%)
- [ ] Filesystem operations tests pass
- [ ] Performance tests pass with expected benchmarks
- [ ] Documentation updated with kernel requirements

**Test Commands:**

```bash
# Verify kernel version on all nodes
for ip in 192.168.195.10 192.168.195.11 192.168.195.12 192.168.195.13; do
  echo "=== Node $ip ==="
  ssh -i build/shared/ssh-keys/id_rsa admin@$ip 'uname -r'
done

# Check DKMS module build status
ssh -i build/shared/ssh-keys/id_rsa admin@192.168.195.10 'dkms status beegfs'

# Verify kernel module loaded
ssh -i build/shared/ssh-keys/id_rsa admin@192.168.195.10 'lsmod | grep beegfs'

# Check filesystem mounted
ssh -i build/shared/ssh-keys/id_rsa admin@192.168.195.10 'mount | grep beegfs'

# Run full BeeGFS test suite
cd tests
./test-beegfs-framework.sh run-tests
```

**Success Criteria:**

- ✅ All VM nodes running kernel 6.1 or 6.6 LTS
- ✅ DKMS build completes without errors
- ✅ BeeGFS client kernel module loaded on all nodes
- ✅ BeeGFS filesystem mounted at `/mnt/beegfs` on all nodes
- ✅ Service validation: 29/29 tests pass (100%)
- ✅ Filesystem operations: All tests pass
- ✅ Performance tests: Meet or exceed baseline (>2GB/s)
- ✅ No kernel API compatibility errors
- ✅ Cluster fully functional for production workloads

**Technical Details:**

**BeeGFS 7.4.4 Kernel Compatibility Matrix:**

| Kernel Version | Compatibility | Status |
|----------------|---------------|--------|
| 6.1.x LTS | ✅ Fully Supported | Recommended |
| 6.6.x LTS | ✅ Fully Supported | Recommended |
| 6.11.x | ⚠️ May work | Testing needed |
| 6.12.x | ❌ Incompatible | API changes |
| 6.13+ | ❌ Incompatible | API changes |

**Kernel API Changes in 6.12:**

1. **generic_fillattr() signature change:**

   ```c
   // Old (6.11 and earlier)
   void generic_fillattr(struct inode *inode, struct kstat *stat);
   
   // New (6.12+)
   void generic_fillattr(struct mnt_idmap *idmap, u32 request_mask, 
                        struct inode *inode, struct kstat *stat);
   ```

2. **inode_owner_or_capable() signature change:**

   ```c
   // Old (6.11 and earlier)
   bool inode_owner_or_capable(const struct inode *inode);
   
   // New (6.12+)
   bool inode_owner_or_capable(struct mnt_idmap *idmap, const struct inode *inode);
   ```

3. **SetPageError() removed:**
   - Function completely removed from kernel API
   - BeeGFS needs alternative error handling mechanism

4. **Header relocation:**
   - `asm/unaligned.h` moved to different location or renamed

**Files Modified in Current Workaround:**

- `ansible/roles/beegfs-client/tasks/install.yml` - Graceful DKMS failure handling
- `ansible/roles/beegfs-meta/templates/beegfs-meta.conf.j2` - Removed invalid config parameters
- `ansible/roles/beegfs-storage/templates/beegfs-storage.conf.j2` - Removed invalid config parameters
- `ansible/roles/beegfs-{mgmt,meta,storage}/tasks/service.yml` - PID cleanup and timeout improvements
- `tests/suites/beegfs/check-beegfs-services.sh` - Removed `set -e` for better error handling

**Additional Considerations:**

- **Security Updates**: Kernel 6.1 and 6.6 are LTS versions receiving security patches
- **Performance**: No performance difference expected between 6.1/6.6 and 6.12
- **Stability**: LTS kernels provide better long-term stability for HPC workloads
- **Future Compatibility**: Monitor BeeGFS releases for kernel 6.12+ support

**Dependencies:**

- **Blocks**: Full BeeGFS filesystem functionality until resolved
- **Blocked By**: None (can be executed immediately after TASK-028)
- **Related**: TASK-027 (virtio-fs provides alternative host sharing while BeeGFS client is unavailable)

**Estimated Implementation Time:**

- Packer template update: 1 hour
- Controller image rebuild: 30 minutes
- Compute image rebuild: 30 minutes
- Testing and validation: 3 hours
- Documentation updates: 1 hour
- **Total**: 6 hours

**Notes:**

- **Immediate Action Required**: Kernel 6.12 incompatibility prevents BeeGFS client functionality
- **Recommended Approach**: Solution 1 (rebuild with compatible kernel) provides cleanest resolution
- **Alternative Available**: Solution 3 (document limitation) allows continuing with server-side only
- **Future Mitigation**: Monitor BeeGFS repository for kernel 6.12 support in version 7.5+ or 8.0
- **Current Status**: All BeeGFS server services operational (23/29 tests passing), only client mounting affected

---

## Related Documentation

- [Completed: TASK-028 - BeeGFS Deployment](../completed/phase-3-storage.md)
- [Completed: TASK-010.1 - Separate HPC Images](../completed/phase-1-core-infrastructure.md)

## Next Steps

After completion, proceed to Phase 4: Infrastructure Consolidation
