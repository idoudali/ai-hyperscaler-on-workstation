# BeeGFS Client Installation Debugging Guide

**Purpose:** Historical analysis and troubleshooting guide for BeeGFS client installation issues.

**Last Updated:** 2025-10-26

## Root Cause Analysis: Tag Filtering + Variable Dependencies

### Problem Summary

BeeGFS client installation failed with a false positive error during Ansible playbook execution with tag
filtering (`--tags install`). The failure was caused by a cascade of skipped tasks due to incompatible
tag assignments.

### Task Execution Analysis

#### Before Tag Fix

**Log Reference:** `validation-output/phase-4-validation-20251025-164535/05-runtime-deployment/ansible-deploy.log`
(lines 8972-9244)

**Executed Tasks:**

- ✓ "Update apt cache and kernel headers..." (line 8975)
  - Tags: `[beegfs, beegfs-client, install, kernel-headers]`
  - Status: Ran successfully (matched 'install' tag filter)
  - Updated kernel headers from 6.12.38 to 6.12.48

**Skipped Tasks (silent due to `display_skipped_hosts=False`):**

- ✗ All check tasks (originally lines 34-88 in install.yml)
  - Tasks: Check DKMS installed, Check kernel module (early), Check client installed, Check packages dir
  - Reason: Had ONLY `[beegfs, beegfs-client, check]` tags (missing 'install')
  - Result: Variables never registered → undefined

**Cascade Failure:**

- ✗ All package copy/install tasks (lines 99-240) were skipped
  - Dependent variables: `beegfs_client_installed`, `beegfs_client_dkms_installed`, `beegfs_kernel_module_early_check`
  - Since check tasks were skipped, these variables were undefined
  - Ansible treats undefined variables in conditions as "skip this task"

**False Positive FAIL:**

- ✓ "FAIL if kernel module could not be built" (line 9244) - EXECUTED
  - Condition: `(beegfs_kernel_module_early_check.matched | default(0)) == 0`
  - `beegfs_kernel_module_early_check` was undefined → `default(0)` → `0 == 0` → TRUE → FAIL triggered
  - This was a FALSE POSITIVE - kernel module may have existed, but we never checked!

### Root Cause Chain

```text
1. Check tasks had [check] tag but NOT [install] tag
     ↓
2. Playbook ran with tag filter that required [install]
     ↓
3. Check tasks skipped → variables undefined
     ↓
4. Package install tasks skipped → conditions evaluated undefined vars as False
     ↓
5. FAIL task executed → checked undefined var, got default(0), triggered FAIL
     ↓
6. Result: False positive failure - no actual installation was attempted!
```

### The Fix

**Added `install` tag to all check tasks that register variables:**

- Line 67: Check if BeeGFS client DKMS package is installed
- Line 83: Check if BeeGFS kernel module exists (early check)
- Line 113: Check if BeeGFS client is already installed
- Line 125: Check if packages directory exists on remote host

**Result:**

- ✓ Check tasks always run when installation runs
- ✓ Variables are properly registered
- ✓ Package tasks can evaluate conditions correctly
- ✓ FAIL task only triggers on genuine failures

### After Tag Fix

All check tasks execute → variables defined → package install conditions evaluate correctly → installation
proceeds normally → FAIL only triggers if module truly missing.

## Kernel Compatibility: BeeGFS 8.1.0 + Kernel 6.12+

### Compatibility Status

BeeGFS 8.1.0 client kernel module is **FULLY COMPATIBLE** with Linux kernel 6.12+. All kernel API
compatibility issues from version 7.4.4 have been resolved.

### Fixed in BeeGFS 8.1.0

- ✅ `generic_fillattr()` function signature updated for kernel 6.12+
- ✅ `inode_owner_or_capable()` function signature updated for kernel 6.12+
- ✅ `SetPageError()` function replaced with compatible alternative
- ✅ `asm/unaligned.h` header path issues resolved

### Requirements

- Kernel headers must match between build and runtime environments
- Docker build container and Packer VMs must use same kernel version
- DKMS will build kernel module at install time

### Kernel Compatibility Matrix

| Kernel Version | Status             | Notes                    |
|----------------|--------------------|--------------------------|
| 6.1.x LTS      | ✅ Fully Supported | Long-term support        |
| 6.6.x LTS      | ✅ Fully Supported | Long-term support        |
| 6.11.x         | ✅ Fully Supported | Stable release           |
| 6.12.x+        | ✅ Fully Supported | Kernel 6.12 API complete |

### References

- Solution documented in: `docs/implementation-plans/phase-3-storage-fixes.md` (TASK-028.1)
- BeeGFS 8.1.0 release notes
- Kernel consistency requirement for DKMS builds

## Execution Summary

### Failed Run (before tag fix)

- **Total tasks in install.yml:** ~100+
- **Tasks that EXECUTED:** 2
  1. "Update apt cache..." - ✓ Succeeded
  2. "FAIL if kernel module..." - ✗ Failed (false positive)
- **Tasks that were SKIPPED:** ~98+ (silently, due to `display_skipped_hosts=False`)

### Successful Run (after tag fix)

- All check tasks execute → variables defined
- Package install conditions evaluate correctly
- Installation proceeds normally
- FAIL only triggers if module truly missing

## Lessons Learned

### Critical Design Pattern

**When tasks register variables used by other tasks' 'when' conditions, they MUST have compatible tags to
ensure proper execution order.**

### Silent Failures

Silent skipping (`display_skipped_hosts=False` in ansible.cfg) can hide critical issues. Consider:

- Using `display_skipped_hosts=True` during debugging
- Adding explicit debug output for critical variable registration
- Testing playbooks with tag filters to ensure expected task execution

### Tag Design Best Practices

1. **Include action tags** on prerequisite tasks (e.g., `install` tag on check tasks that install needs)
2. **Test with tag filters** to ensure proper execution flow
3. **Document tag dependencies** in comments or documentation
4. **Use explicit defaults** for registered variables used in conditions
5. **Validate variable registration** with debug tasks when debugging

## Related Documentation

- Ansible role: `ansible/roles/beegfs-client/tasks/install.yml`
- BeeGFS setup guide: `docs/components/beegfs-setup-guide.md`
- Implementation plan: `docs/implementation-plans/phase-3-storage-fixes.md`
- Ansible configuration: `ansible/ansible.cfg`
