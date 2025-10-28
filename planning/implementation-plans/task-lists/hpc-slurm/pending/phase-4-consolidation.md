# Phase 4: Infrastructure Consolidation (Tasks 029-048, 046.1)

**Status**: ✅ **95% COMPLETE** (22/23 tasks)
**Last Updated**: 2025-10-28 (Test Framework Consolidation Verified Complete)
**Priority**: HIGH
**Tasks**: 23 total (Ansible: 8, Storage: 6, Testing: 3, Configuration: 1, Role Consolidation: 6)
**Remaining**: Only Task 040 (Container Registry on BeeGFS) pending

## ✅ **Progress Summary**

| Task | Status | Completion | Notes |
|------|--------|------------|-------|
| **029** | ✅ **COMPLETE** | 100% | HPC Packer Controller Playbook exists and functional |
| **030** | ✅ **COMPLETE** | 100% | HPC Packer Compute Playbook exists and functional |
| **031** | ✅ **COMPLETE** | 100% | Unified Runtime Playbook exists and functional |
| **032** | ✅ **COMPLETE** | 100% | Packer Templates updated (verification needed) |
| **033** | ✅ **COMPLETE** | 100% | Packer builds functional |
| **034** | ✅ **COMPLETE** | 100% | 9 obsolete playbooks deleted - 8 playbooks remain |
| **034.1** | ✅ **COMPLETE** | 100% | SLURM uses pre-built packages (install.yml verified) |
| **035** | ✅ **COMPLETE** | 100% | HPC Runtime Test Framework created & functional (tests/frameworks/) |
| **036** | ✅ **COMPLETE** | 100% | HPC Packer Test Frameworks created & functional (controller + compute) |
| **037** | ✅ **COMPLETE** | 100% | Test framework consolidation complete - 42+ Makefile targets |
| **038** | ✅ **COMPLETE** | 100% | BeeGFS Packer installation consolidated into HPC playbooks |
| **039** | ✅ **COMPLETE** | 100% | VirtIO-FS integrated into playbook-hpc-runtime.yml |
| **040** | ❌ **PENDING** | 0% | Registry uses /opt/containers not /mnt/beegfs |
| **041** | ✅ **COMPLETE** | 100% | virtio_fs_mounts and beegfs_config added to cluster config schema |
| **042** | ✅ **COMPLETE** | 100% | Configuration template rendering system implemented |
| **043** | ✅ **COMPLETE** | 100% | BeeGFS & VirtIO-FS consolidation into runtime playbook |
| **044** | ✅ **COMPLETE** | 100% | BeeGFS Common Role created (beeGFS installation logic consolidated) |
| **045** | ✅ **COMPLETE** | 100% | SLURM Common Role created (MUNGE, directories, user creation consolidated) |
| **046** | ✅ **COMPLETE** | 100% | Shared package management role created and functional |
| **046.1** | ✅ **COMPLETE** | 100% | Integrate package-manager into BeeGFS and SLURM roles |
| **047** | ✅ **COMPLETE** | 100% | Base package roles consolidated into unified base-packages role |
| **048** | ✅ **COMPLETE** | 100% | Shared utilities role created with reusable validation tasks |

**Completed**: Tasks 029-035, 038, 039, 041, 042, 043, 044, 045, 046, 046.1, 047, 048
(Ansible consolidation + validation framework + BeeGFS consolidation + VirtIO-FS integration +
storage schema + template rendering + BeeGFS common role + SLURM common role +
package management role + base packages role + shared utilities role achieved!)  
**Phase 2 Utilities**: ✅ COMPLETED 2025-10-25 (framework-cli.sh, framework-orchestration.sh, framework-template.sh)
**Pending**: Tasks 036-037, 040 (HPC test frameworks + Container registry)
**Achievement**: ✅ **50% playbook reduction achieved** (14 → 7 playbooks, target: 7)  
**New**: Phase 4.8 added 5 role consolidation tasks to eliminate duplicate code across Ansible roles (COMPLETE)

## Overview

This phase consolidates the Ansible playbook and test framework infrastructure, reducing complexity while maintaining
all functionality. The goal is to streamline from 14 playbooks to 7 playbooks and 15+ test frameworks to 3 frameworks.

## Current State (As of 2025-10-22 - Status Updated)

**Ansible Playbooks:** ✅ **5 playbooks** (down from 14 - 64% reduction achieved!)

- Core HPC (3 playbooks): ✅ **CONSOLIDATED & VERIFIED**
  - `playbook-hpc-packer-controller.yml` ✅ EXISTS - Packer controller image builds
  - `playbook-hpc-packer-compute.yml` ✅ EXISTS - Packer compute image builds
  - `playbook-hpc-runtime.yml` ✅ EXISTS - Unified runtime configuration
- Infrastructure (2 playbooks): ✅ **VERIFIED**
  - `playbook-cloud.yml` ✅ EXISTS - Kubernetes cloud setup
  - `playbook-container-registry.yml` ✅ EXISTS - Container registry deployment

**Deleted Playbooks (11 files):** ❌

- `playbook-hpc.yml`
- `playbook-hpc-controller.yml`
- `playbook-hpc-compute.yml`
- `playbook-slurm-compute-runtime-config.yml`
- `playbook-cgroup-runtime-config.yml`
- `playbook-gres-runtime-config.yml`
- `playbook-job-scripts-runtime-config.yml`
- `playbook-dcgm-runtime-config.yml`
- `playbook-container-validation-runtime-config.yml`
- `playbook-beegfs-runtime-config.yml`
- `playbook-virtio-fs-runtime-config.yml`

**Test Frameworks:** ⚠️ **15 OLD frameworks still exist** (Phase 2 utilities created - framework consolidation READY TO START)

- ✅ KEEP: test-{beegfs,container-registry,pcie-passthrough,virtio-fs}-framework.sh (4)
- ❌ CONSOLIDATE: test-{cgroup-isolation,container-{integration,runtime},dcgm-monitoring}-framework.sh
- ❌ CONSOLIDATE: test-{gpu-gres,grafana,job-scripts,monitoring-stack}-framework.sh
- ❌ CONSOLIDATE: test-{slurm-{accounting,compute,controller}}-framework.sh (total: 11 to consolidate)

**Test Configs:** ⚠️ **17+ YAML files in `tests/test-infra/configs/`** (cleanup NOT started)

**New Frameworks Required:** ⚠️ **UTILITIES CREATED - READY FOR FRAMEWORK GENERATION**

- ✅ **Phase 4 Validation Framework** - `tests/phase-4-validation/` (Task 035 - COMPLETED)
  - Comprehensive validation framework with 5 steps
  - Automated testing for Packer builds and runtime deployment
  - Resume capability and state tracking
- ✅ **Phase 2 Shared Utilities** - `tests/test-infra/utils/framework-*.sh` (COMPLETED - 2025-10-25)
  - `framework-cli.sh` - Standardized CLI parser (451 lines, 14KB)
  - `framework-orchestration.sh` - Cluster lifecycle & orchestration (501 lines, 15KB)
  - `framework-template.sh` - Framework creation template (411 lines, 14KB)
  - **Impact**: Foundation for creating new frameworks, eliminates 2,400+ lines of duplication
- ⏳ test-hpc-runtime-framework.sh (replaces 6 frameworks) - READY TO START
- ⏳ test-hpc-packer-controller-framework.sh (replaces 3 frameworks) - READY TO START
- ⏳ test-hpc-packer-compute-framework.sh (replaces 2 frameworks) - READY TO START

**Ansible Roles:** All roles support modular task execution ✅

- `slurm-compute/tasks/`: configure.yml, cgroup.yml, gres.yml, job-scripts.yml
- `slurm-controller/tasks/`: configure.yml, install.yml, munge.yml, accounting.yml
- `monitoring-stack/tasks/`: prometheus.yml, grafana.yml, node-exporter.yml, dcgm.yml

## Consolidation Goals

1. **Ansible Simplification**: 14 playbooks → 7 focused playbooks (50% reduction)
   - ✅ **ACHIEVED**: 8 playbooks currently (Tasks 029-034 complete) - 43% reduction
   - 🎯 **TARGET**: 7 playbooks (Task 038 pending - BeeGFS consolidation needed)
   - ✅ 2 NEW Packer playbooks created (controller + compute)
   - ✅ 1 NEW unified runtime playbook created
   - ✅ 2 storage playbooks kept (BeeGFS runtime + VirtIO-FS)
   - ✅ 2 infrastructure playbooks kept (cloud + registry)
   - ✅ 9 obsolete playbooks deleted (verified in codebase)

2. **Storage Enhancement** (NEW):
   - ✅ Consolidate BeeGFS Packer installation into HPC playbooks (Task 038)
   - ✅ Integrate VirtIO-FS into unified runtime playbook (Task 039)
   - ❌ Configure container registry on BeeGFS for distributed access (Task 040)
   - ✅ Update cluster configuration schema for storage options (Task 041)

3. **Configuration Template Rendering** (NEW - 2025-10-23):
   - ✅ Added `ai-how render` command with bash-compatible variable expansion
   - ✅ Added `make config-render` and `make config-validate` targets
   - ✅ Added `expandvars` Python dependency for variable processing
   - ✅ Added VirtIO-FS mount configuration to cluster config schema
   - ✅ Added VirtIO-FS mount handling in runtime playbook
   - ✅ Added cluster state directory management (`output/cluster-state/`)

4. **Test Framework Cleanup**: 15 frameworks → 7 frameworks (53% reduction)
   - ❌ **PENDING**: 11 old frameworks still exist (should be consolidated)
   - ❌ **PENDING**: 3 new unified frameworks NOT created yet
   - ❌ **PENDING**: 10+ old test configs still exist (should be removed)
   - ❌ **PENDING**: Test suites preserved but frameworks need consolidation
   - ⚠️ **STATUS**: Tasks 035-037 NOT started - all old frameworks still in place

5. **Maintainability**: Clean architecture with no deprecated code
   - ✅ **ACHIEVED**: All 9 obsolete playbooks removed (verified)
   - ✅ **ACHIEVED**: SLURM uses pre-built packages (install.yml verified)
   - ✅ **ACHIEVED**: BeeGFS Packer consolidated into HPC playbooks (Task 038)
   - ✅ **ACHIEVED**: VirtIO-FS integrated into runtime playbook (Task 039)
   - ✅ **ACHIEVED**: Configuration template rendering with variable expansion
   - ✅ **ACHIEVED**: Phase 2 shared utilities created (framework-cli.sh, framework-orchestration.sh, framework-template.sh)
   - ⏳ **IN PROGRESS**: Framework consolidation (Tasks 036-037 READY TO START)

---

## Prerequisites

### Required Inventory Variables

```yaml
# Required for GPU nodes
gpu_enabled: true|false

# Required for monitoring configuration
monitoring_role: server|node|gpu|all|none

# Required for unified runtime playbook
slurm_cgroup_enabled: true|false
slurm_gres_enabled: true|false
slurm_container_enabled: true|false

# Reference cluster configuration for validation
example_cluster_config: "config/example-multi-gpu-clusters.yaml"
```

### Role Requirements

- All roles must support modular task imports via `tasks_from:` ✅
- Roles must support `packer_build` variable for build vs runtime modes ✅
- Current roles already meet these requirements ✅

---

## Phase 4: Ansible Playbook Consolidation (Tasks 029-034.1)

### Task 029: Create HPC Packer Controller Playbook

- **ID**: TASK-029
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-010.1, TASK-015, TASK-017
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate
- **Status**: ✅ Complete (Verified 2025-10-20)
- **Priority**: HIGH

**Description:** Create unified Packer build playbook for HPC controller images, consolidating multiple
component playbooks into single streamlined build process.

**Current Playbook Analysis:**

- Existing `playbook-hpc-controller.yml` is 135 lines with good structure ✅
- Already supports `packer_build` variable ✅
- Has comprehensive validation tasks (lines 46-135) ✅
- Uses role-based architecture ✅

**Deliverables:**

- `ansible/playbooks/playbook-hpc-packer-controller.yml` - Unified controller Packer playbook
- Consolidates roles: slurm-controller, monitoring-stack, hpc-base-packages, container-runtime
- Supports `packer_build=true` mode for install-only operations
- Based on existing `playbook-hpc-controller.yml` but optimized for Packer builds
- **Keep validation tasks from current playbook for build verification**

**Playbook Structure:**

```yaml
---
# HPC Controller Packer Build Playbook
# Optimized for Packer image creation with comprehensive validation
# Usage: packer build (automatically sets packer_build=true)

- name: HPC Controller Packer Build
  hosts: all
  become: true
  gather_facts: true

  vars:
    packer_build: true
    hpc_node_type: controller
    monitoring_role: server
    install_monitoring_stack: true
    install_slurm_controller: true
    container_runtime_enable_service: false

  roles:
    - role: hpc-base-packages
    - role: container-runtime
    - role: slurm-controller
    - role: monitoring-stack

  tasks:
    # Keep all validation tasks from playbook-hpc-controller.yml lines 46-135
    - name: Verify HPC base packages installation
      debug:
        msg: "HPC base packages have been installed successfully"

    - name: Verify container runtime installation
      command: "{{ container_runtime_binary | default('apptainer') }} --version"
      register: container_runtime_version_check
      changed_when: false
      failed_when: false

    - name: Display container runtime version
      debug:
        msg: "Container runtime version: {{ container_runtime_version_check.stdout }}"
      when: container_runtime_version_check.rc == 0

    - name: Verify SLURM controller installation
      command: "{{ item }}"
      register: slurm_version_check
      changed_when: false
      failed_when: false
      loop:
        - "slurmctld -V"
        - "slurmdbd -V"

    - name: Verify monitoring stack installation
      command: "{{ item }}"
      register: monitoring_check
      changed_when: false
      failed_when: false
      loop:
        - "prometheus --version"
        - "grafana-server --version"

    - name: Display deployment summary
      debug:
        msg: |
          HPC Controller Packer Build Complete
          - SLURM Controller: Installed
          - Monitoring Stack: Installed (Prometheus, Grafana, Node Exporter)
          - Container Runtime: Installed
          - Services: Enabled but not started (Packer mode)
```

**Validation Criteria:**

- [ ] Playbook creates functional controller image
- [ ] All roles execute without errors
- [ ] SLURM controller components installed (slurmctld, slurmdbd)
- [ ] Monitoring stack (Prometheus, Grafana, Node Exporter) installed
- [ ] Container runtime installed (Apptainer)
- [ ] Image size reasonable and optimized
- [ ] No runtime services started during build
- [ ] All validation tasks pass

**Test Commands:**

```bash
# Test playbook syntax
cd ansible
ansible-playbook playbooks/playbook-hpc-packer-controller.yml --syntax-check

# Test playbook with Packer (requires packer/ directory)
cd packer/hpc-controller
packer build hpc-controller.pkr.hcl

# Verify image built successfully
ls -lh ../../build/packer/hpc-controller/
```

---

### Task 030: Create HPC Packer Compute Playbook

- **ID**: TASK-030
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-008, TASK-022
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate
- **Status**: ✅ Complete (Verified 2025-10-20)
- **Priority**: HIGH

**Description:** Create unified Packer build playbook for HPC compute images, consolidating compute node
components into single streamlined build process.

**Current Playbook Analysis:**

- Existing `playbook-hpc-compute.yml` is 141 lines with good structure ✅
- Already supports `packer_build` variable ✅
- Has comprehensive validation tasks (lines 53-140) ✅
- Uses role-based architecture ✅

**Deliverables:**

- `ansible/playbooks/playbook-hpc-packer-compute.yml` - Unified compute Packer playbook
- Consolidates roles: slurm-compute, container-runtime, monitoring-stack, nvidia-gpu-drivers
- Supports `packer_build=true` mode for install-only operations
- Based on existing `playbook-hpc-compute.yml` but optimized for Packer builds
- **Keep validation tasks from current playbook for build verification**

**Playbook Structure:**

```yaml
---
# HPC Compute Packer Build Playbook
# Optimized for Packer image creation with GPU support and validation
# Usage: packer build (automatically sets packer_build=true)

- name: HPC Compute Packer Build
  hosts: all
  become: true
  gather_facts: true

  vars:
    packer_build: true
    hpc_node_type: compute
    monitoring_role: node
    install_slurm_compute: true
    install_container_runtime: true
    install_gpu_support: true
    install_monitoring_stack: true
    container_runtime_enable_service: false

  roles:
    - role: hpc-base-packages
    - role: container-runtime
    - role: nvidia-gpu-drivers
      when: gpu_enabled | default(true)
    - role: monitoring-stack
    - role: slurm-compute

  tasks:
    # Keep all validation tasks from playbook-hpc-compute.yml lines 53-140
    - name: Verify HPC base packages installation
      debug:
        msg: "HPC base packages have been installed successfully"

    - name: Verify container runtime installation
      command: "{{ container_runtime_binary | default('apptainer') }} --version"
      register: container_runtime_version_check
      changed_when: false
      failed_when: false

    - name: Display container runtime version
      debug:
        msg: "Container runtime version: {{ container_runtime_version_check.stdout }}"
      when: container_runtime_version_check.rc == 0

    - name: Verify NVIDIA driver installation
      shell: "nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits"
      register: nvidia_driver_version
      changed_when: false
      failed_when: false
      when: gpu_enabled | default(true)

    - name: Display NVIDIA driver version
      debug:
        msg: "NVIDIA driver version: {{ nvidia_driver_version.stdout }}"
      when:
        - gpu_enabled | default(true)
        - nvidia_driver_version.rc == 0

    - name: Verify SLURM compute installation
      command: "slurmd -V"
      register: slurm_compute_check
      changed_when: false
      failed_when: false

    - name: Verify Node Exporter installation
      command: "prometheus-node-exporter --version"
      register: node_exporter_check
      changed_when: false
      failed_when: false

    - name: Display deployment summary
      debug:
        msg: |
          HPC Compute Packer Build Complete
          - SLURM Compute: Installed
          - Container Runtime: Installed
          - GPU Drivers: {{ 'Installed' if nvidia_driver_version.rc == 0 else 'Skipped' }}
          - Node Exporter: Installed
          - Services: Enabled but not started (Packer mode)
```

**Validation Criteria:**

- [ ] Playbook creates functional compute image
- [ ] All roles execute without errors
- [ ] SLURM compute components installed (slurmd)
- [ ] Apptainer/Singularity installed
- [ ] Node Exporter installed
- [ ] GPU drivers installed (if enabled)
- [ ] No runtime services started during build
- [ ] All validation tasks pass

**Test Commands:**

```bash
# Test playbook syntax
cd ansible
ansible-playbook playbooks/playbook-hpc-packer-compute.yml --syntax-check

# Test playbook with Packer (requires packer/ directory)
cd packer/hpc-compute
packer build hpc-compute.pkr.hcl

# Verify image built successfully
ls -lh ../../build/packer/hpc-compute/
```

---

### Task 031: Create Unified Runtime Configuration Playbook

- **ID**: TASK-031
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-022, TASK-023, TASK-024, TASK-025
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate-Advanced
- **Status**: ✅ Complete (Verified 2025-10-20)
- **Priority**: HIGH

**Description:** Create single unified playbook for complete HPC cluster runtime configuration,
consolidating 6 specialized runtime playbooks into one maintainable file.

**Current Runtime Playbooks Analysis:**

- `playbook-slurm-compute-runtime-config.yml` ✅ (133 lines) - Has good validation structure
- `playbook-cgroup-runtime-config.yml` ✅ (178 lines) - Excellent pre/post validation
- `playbook-gres-runtime-config.yml` ✅
- `playbook-job-scripts-runtime-config.yml` ✅
- `playbook-dcgm-runtime-config.yml` ✅
- `playbook-container-validation-runtime-config.yml` ✅

All have detailed troubleshooting sections and validation logic to preserve.

**Deliverables:**

- `ansible/playbooks/playbook-hpc-runtime.yml` - Unified runtime configuration playbook
- Consolidates all runtime configuration tasks
- Supports controller and compute node configuration
- GPU-conditional tasks for GRES and DCGM
- Replaces 6 runtime-specific playbooks
- **Preserves detailed validation and troubleshooting output from existing playbooks**

**Consolidates These Existing Playbooks:**

1. `playbook-slurm-compute-runtime-config.yml` ✅ (exists, 133 lines)
2. `playbook-cgroup-runtime-config.yml` ✅ (exists, 178 lines)
3. `playbook-gres-runtime-config.yml` ✅ (exists)
4. `playbook-job-scripts-runtime-config.yml` ✅ (exists)
5. `playbook-dcgm-runtime-config.yml` ✅ (exists)
6. `playbook-container-validation-runtime-config.yml` ✅ (exists)

**Design Principles:**

- Leverage existing role modular structure (roles already have separate task files) ✅
- Use `import_role` with `tasks_from:` for targeted task execution ✅
- Maintain pre-validation, post-validation, and troubleshooting sections ✅
- Keep detailed debug output for operational clarity ✅

**Playbook Structure:**

```yaml
---
# HPC Runtime Configuration Playbook
# Unified runtime configuration for complete HPC cluster deployment
# Consolidates 6 specialized runtime playbooks into one maintainable file
#
# Usage:
#   ansible-playbook -i inventories/production playbooks/playbook-hpc-runtime.yml
#
# IMPORTANT: This playbook is for RUNTIME deployment only (packer_build=false)

# Pre-validation
- name: HPC Runtime Configuration - Pre-validation
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Verify runtime deployment mode
      assert:
        that:
          - not ((packer_build | default(false)) | bool)
        fail_msg: |
          ERROR: This playbook is for RUNTIME deployment only!
          It must be run with packer_build=false on live VMs.
          Do NOT run this during Packer image builds.
        success_msg: "Runtime deployment mode confirmed"

    - name: Display runtime configuration plan
      debug:
        msg: |
          ====================================================================
          HPC Runtime Configuration
          ====================================================================
          
          This playbook will configure:
          - Controllers: {{ groups['hpc_controllers'] | default([]) | join(', ') }}
          - Compute Nodes: {{ groups['compute_nodes'] | default([]) | join(', ') }}
          
          Configuration includes:
          - SLURM controller and compute services
          - Cgroup resource isolation
          - GPU GRES configuration (if GPUs present)
          - Job scripts deployment
          - Monitoring stack (Prometheus, Grafana, DCGM)
          - Container runtime validation
          
          ====================================================================

# Controller configuration
- name: Configure HPC Controllers
  hosts: hpc_controllers
  become: true
  gather_facts: true
  vars:
    packer_build: false
  
  pre_tasks:
    - name: Display controller configuration
      debug:
        msg: "Configuring HPC controller: {{ inventory_hostname }}"

  tasks:
    - name: Configure SLURM controller services
      import_role:
        name: slurm-controller
        tasks_from: configure
      tags:
        - slurm
        - controller

    - name: Start and configure monitoring stack
      import_role:
        name: monitoring-stack
        tasks_from: configure
      when: install_monitoring_stack | default(true)
      tags:
        - monitoring

  post_tasks:
    - name: Verify SLURM controller services
      systemd:
        name: "{{ item }}"
        state: started
      register: controller_services
      loop:
        - slurmctld
        - slurmdbd
      failed_when: false

    - name: Display controller status
      debug:
        msg: |
          Controller {{ inventory_hostname }} configured:
          - slurmctld: {{ 'Running' if controller_services.results[0].state == 'started' else 'Check logs' }}
          - slurmdbd: {{ 'Running' if controller_services.results[1].state == 'started' else 'Check logs' }}

# Compute node configuration
- name: Configure HPC Compute Nodes
  hosts: compute_nodes
  become: true
  gather_facts: true
  vars:
    packer_build: false
  
  pre_tasks:
    - name: Display compute node configuration
      debug:
        msg: |
          Configuring compute node: {{ inventory_hostname }}
          - Cgroup enabled: {{ slurm_cgroup_enabled | default(true) }}
          - GPU enabled: {{ gpu_enabled | default(false) }}
          - Container runtime: {{ slurm_container_enabled | default(true) }}

  tasks:
    - name: Configure SLURM compute services
      import_role:
        name: slurm-compute
        tasks_from: configure
      tags:
        - slurm
        - compute

    - name: Configure cgroup isolation
      import_role:
        name: slurm-compute
        tasks_from: cgroup
      when: slurm_cgroup_enabled | default(true)
      tags:
        - cgroup

    - name: Configure GPU GRES
      import_role:
        name: slurm-compute
        tasks_from: gres
      when: gpu_enabled | default(false)
      tags:
        - gres
        - gpu

    - name: Deploy job scripts
      import_role:
        name: slurm-compute
        tasks_from: job-scripts
      tags:
        - job-scripts

    - name: Configure DCGM monitoring
      import_role:
        name: monitoring-stack
        tasks_from: dcgm
      when: gpu_enabled | default(false)
      tags:
        - dcgm
        - monitoring
        - gpu

  post_tasks:
    - name: Verify slurmd service
      systemd:
        name: slurmd
        state: started
      register: slurmd_service
      failed_when: false

    - name: Check node registration with controller
      shell: |
        timeout 30 bash -c 'until scontrol show node {{ inventory_hostname }} 2>/dev/null | \
          grep -q "State="; do sleep 2; done'
      register: node_registration
      changed_when: false
      failed_when: false

    - name: Display compute node status
      debug:
        msg: |
          Compute node {{ inventory_hostname }} configured:
          - slurmd: {{ 'Running' if slurmd_service.state == 'started' else 'Check logs' }}
          - Registration: {{ 'SUCCESS' if node_registration.rc == 0 else 'FAILED - Check MUNGE/network' }}
          - Cgroup: {{ 'Configured' if slurm_cgroup_enabled | default(true) else 'Disabled' }}
          - GPU GRES: {{ 'Configured' if gpu_enabled | default(false) else 'Disabled' }}

    - name: Display troubleshooting information on failure
      debug:
        msg: |
          Node registration failed. Troubleshooting steps:
          1. Check MUNGE service: systemctl status munge
          2. Verify MUNGE key matches controller
          3. Check network connectivity to controller
          4. Review slurmd logs: journalctl -u slurmd -n 50
          5. Verify slurm.conf has correct controller hostname
          6. Check firewall rules allowing SLURM traffic
      when: node_registration.rc != 0

# Post-validation
- name: HPC Runtime Configuration - Post-validation
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Display configuration completion
      debug:
        msg: |
          ====================================================================
          HPC Runtime Configuration Complete
          ====================================================================
          
          Cluster configured successfully!
          
          Next steps:
          1. Verify cluster status: sinfo
          2. Check node states: scontrol show nodes
          3. Test job submission: srun -N1 hostname
          4. Run comprehensive tests: make test-hpc-runtime
          
          Monitoring:
          - Prometheus: http://controller:9090
          - Grafana: http://controller:3000
          - Node metrics: http://nodes:9100/metrics
          
          For troubleshooting:
          - Controller logs: journalctl -u slurmctld -f
          - Compute logs: journalctl -u slurmd -f
          - Database logs: journalctl -u slurmdbd -f
          
          ====================================================================
```

**Validation Criteria:**

- [ ] Playbook configures complete cluster successfully
- [ ] Pre-validation catches packer_build errors
- [ ] Controller services start and run correctly
- [ ] Compute nodes register with controller
- [ ] Cgroup isolation configured properly
- [ ] GPU GRES configured (if GPUs present)
- [ ] Job scripts deployed and functional
- [ ] DCGM monitoring active (if GPUs present)
- [ ] All original functionality preserved
- [ ] Troubleshooting output provided on failures

**Test Commands:**

```bash
# Test playbook syntax
cd ansible
ansible-playbook playbooks/playbook-hpc-runtime.yml --syntax-check

# Test runtime configuration on test cluster
ansible-playbook -i inventories/test playbooks/playbook-hpc-runtime.yml

# Verify cluster operational
ssh controller "sinfo"
ssh controller "scontrol show config | grep ProctrackType"
ssh compute01 "srun -N1 hostname"
```

---

### Task 032: Update Packer Templates for New Playbooks

- **ID**: TASK-032
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-029, TASK-030
- **Estimated Time**: 1 hour
- **Difficulty**: Junior
- **Status**: ✅ Complete (Needs verification)
- **Priority**: HIGH

**Description:** Update Packer HCL templates to reference new consolidated playbooks instead of old playbook names.

**Prerequisites:**

- Verify `packer/hpc-controller/` directory exists
- Verify `packer/hpc-compute/` directory exists
- Verify Packer templates have ansible provisioner blocks

**Deliverables:**

- Update `packer/hpc-controller/hpc-controller.pkr.hcl`
- Update `packer/hpc-compute/hpc-compute.pkr.hcl`
- Test Packer builds with new playbook references
- Verify images build successfully

**Changes Required:**

**File:** `packer/hpc-controller/hpc-controller.pkr.hcl`

```hcl
# OLD
provisioner "ansible" {
  playbook_file = "../../ansible/playbooks/playbook-hpc-controller.yml"
}

# NEW
provisioner "ansible" {
  playbook_file = "../../ansible/playbooks/playbook-hpc-packer-controller.yml"
}
```

**File:** `packer/hpc-compute/hpc-compute.pkr.hcl`

```hcl
# OLD
provisioner "ansible" {
  playbook_file = "../../ansible/playbooks/playbook-hpc-compute.yml"
}

# NEW
provisioner "ansible" {
  playbook_file = "../../ansible/playbooks/playbook-hpc-packer-compute.yml"
}
```

**Validation Criteria:**

- [ ] Packer directories verified to exist
- [ ] Controller Packer build completes successfully
- [ ] Compute Packer build completes successfully
- [ ] Images are functionally identical to previous builds
- [ ] No Ansible errors during provisioning
- [ ] All validation tasks pass in new playbooks

**Test Commands:**

```bash
# Verify Packer directories exist
ls -la packer/hpc-controller/hpc-controller.pkr.hcl
ls -la packer/hpc-compute/hpc-compute.pkr.hcl

# Build controller image
cd packer/hpc-controller
packer validate hpc-controller.pkr.hcl
packer build hpc-controller.pkr.hcl

# Build compute image
cd ../hpc-compute
packer validate hpc-compute.pkr.hcl
packer build hpc-compute.pkr.hcl

# Verify images created
ls -lh ../../build/packer/
```

---

### Task 033: Validate New Playbooks Before Deletion

- **ID**: TASK-033
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-029, TASK-030, TASK-031, TASK-032
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate-Advanced
- **Status**: ✅ Complete (Verified 2025-10-20)
- **Priority**: HIGH

**Description:** Thoroughly validate new consolidated playbooks work correctly before deleting old ones.
This ensures safe migration with rollback capability.

**Validation Steps:**

1. **Test Packer Controller Playbook:**

```bash
cd packer/hpc-controller
packer build hpc-controller.pkr.hcl
# Verify image boots and all services installed
```

1. **Test Packer Compute Playbook:**

```bash
cd packer/hpc-compute
packer build hpc-compute.pkr.hcl
# Verify image boots and all services installed
```

1. **Test Unified Runtime Playbook:**

```bash
cd ansible
# Deploy to test cluster
ansible-playbook -i inventories/test playbooks/playbook-hpc-runtime.yml

# Verify all functionality
ssh controller "sinfo"
ssh controller "scontrol show config | grep ProctrackType"
ssh compute01 "srun -N1 hostname"
```

1. **Compare Outputs:**

- Verify new playbooks produce identical results to old playbooks
- Check all services start correctly
- Validate all configuration files created
- Confirm no missing functionality

**Comprehensive Validation Checklist:**

**Packer Builds:**

- [ ] Controller image builds without errors
- [ ] Controller image contains all required packages
- [ ] Controller image passes all validation tasks
- [ ] Compute image builds without errors
- [ ] Compute image contains all required packages
- [ ] Compute image passes all validation tasks
- [ ] GPU drivers installed correctly (compute)
- [ ] Container runtime functional in both images

**Runtime Configuration:**

- [ ] Runtime playbook deploys complete cluster
- [ ] All SLURM services start correctly
- [ ] Controller services: slurmctld, slurmdbd, munge
- [ ] Compute services: slurmd, munge
- [ ] Cgroup isolation configured and active
- [ ] GPU GRES configured on GPU nodes
- [ ] Job scripts deployed and accessible
- [ ] Monitoring stack operational (Prometheus, Grafana)
- [ ] DCGM monitoring active on GPU nodes
- [ ] Container runtime functional on compute nodes

**Functional Tests:**

- [ ] Compute nodes register with controller
- [ ] Simple job runs successfully: `srun -N1 hostname`
- [ ] Multi-node job works: `srun -N2 hostname`
- [ ] GPU job works (if GPU): `srun --gres=gpu:1 nvidia-smi`
- [ ] Container job works: `srun apptainer exec container.sif command`
- [ ] Cgroup limits enforced: CPU and memory constraints
- [ ] Monitoring metrics available in Prometheus

**Regression Testing:**

- [ ] No missing functionality compared to old playbooks
- [ ] All configuration files identical
- [ ] Service configurations match
- [ ] Performance equivalent

**Rollback Plan:**

If validation fails:

1. Document specific failure points
2. Revert Packer template changes (Task 032)
3. Keep using old playbooks
4. Debug new playbooks in isolation
5. **Do NOT proceed to deletion (Task 034)**
6. Fix issues and re-run validation

**Test Commands:**

```bash
# Full validation test sequence
cd tests

# Test Packer builds (if packer/ exists)
if [ -d ../packer ]; then
  make test-base-images
fi

# Test unified runtime playbook
make test-hpc-runtime

# Run all HPC tests
make test-slurm-controller
make test-slurm-compute
make test-cgroup-isolation
make test-gpu-gres
make test-job-scripts
make test-dcgm-monitoring
make test-container-integration

# Verify no regressions
echo "✅ All tests passed - safe to proceed with deletion"
```

**Success Criteria:**

All validation tests must pass before proceeding to Task 034 (deletion).

---

### Task 034: Delete Obsolete Ansible Playbooks

- **ID**: TASK-034
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-033 (validation must pass)
- **Estimated Time**: 1 hour
- **Difficulty**: Junior
- **Status**: ✅ Complete (Verified 2025-10-20 - 9 playbooks deleted)
- **Priority**: MEDIUM (only after successful validation)

**Description:** Remove obsolete Ansible playbooks after confirming new consolidated playbooks work correctly
through comprehensive validation (Task 033).

**⚠️ CRITICAL:** Only proceed if Task 033 validation passed completely.

**Files to Delete (9 playbooks):**

```bash
# Obsolete/Generic playbooks
ansible/playbooks/playbook-hpc.yml                               # Generic, outdated

# Runtime config playbooks (consolidated into playbook-hpc-runtime.yml)
ansible/playbooks/playbook-slurm-compute-runtime-config.yml      # ✅ Exists (133 lines)
ansible/playbooks/playbook-cgroup-runtime-config.yml             # ✅ Exists (178 lines)
ansible/playbooks/playbook-gres-runtime-config.yml               # ✅ Exists
ansible/playbooks/playbook-job-scripts-runtime-config.yml        # ✅ Exists
ansible/playbooks/playbook-dcgm-runtime-config.yml               # ✅ Exists
ansible/playbooks/playbook-container-validation-runtime-config.yml  # ✅ Exists

# Original HPC playbooks (replaced by Packer-specific versions)
ansible/playbooks/playbook-hpc-controller.yml                    # ✅ Exists (135 lines)
ansible/playbooks/playbook-hpc-compute.yml                       # ✅ Exists (141 lines)
```

**Keep These Playbooks (7 playbooks):**

```bash
# New consolidated playbooks (3)
playbook-hpc-packer-controller.yml  # NEW - Packer controller builds
playbook-hpc-packer-compute.yml     # NEW - Packer compute builds
playbook-hpc-runtime.yml            # NEW - Unified runtime configuration

# Storage infrastructure - optional backends (3)
playbook-beegfs-packer-install.yml  # KEEP - BeeGFS Packer installation
# playbook-beegfs-runtime-config.yml  # DELETED - BeeGFS functionality integrated into playbook-hpc-runtime.yml
# playbook-virtio-fs-runtime-config.yml  # DELETED - VirtIO-FS functionality integrated into playbook-hpc-runtime.yml

# Separate infrastructure (2)
playbook-cloud.yml                  # KEEP - Kubernetes cloud infrastructure
playbook-container-registry.yml     # KEEP - Optional container registry
```

**Storage Playbook Strategy:**

BeeGFS and VirtIO-FS playbooks are intentionally **NOT consolidated** because:

- They are optional storage backends (not required for basic HPC)
- Used independently from core HPC deployment
- Different deployment lifecycle (optional post-install)
- Clean separation of concerns (storage vs compute)
- Users may choose neither, one, or both storage backends

**Deletion Commands:**

```bash
cd ansible/playbooks

# Create backup before deletion (safety measure)
mkdir -p ../../backup/playbooks-$(date +%Y%m%d)
cp playbook-hpc.yml \
   playbook-slurm-compute-runtime-config.yml \
   playbook-cgroup-runtime-config.yml \
   playbook-gres-runtime-config.yml \
   playbook-job-scripts-runtime-config.yml \
   playbook-dcgm-runtime-config.yml \
   playbook-container-validation-runtime-config.yml \
   playbook-hpc-controller.yml \
   playbook-hpc-compute.yml \
   ../../backup/playbooks-$(date +%Y%m%d)/ 2>/dev/null || true

# Delete obsolete playbooks
rm -f playbook-hpc.yml
rm -f playbook-slurm-compute-runtime-config.yml
rm -f playbook-cgroup-runtime-config.yml
rm -f playbook-gres-runtime-config.yml
rm -f playbook-job-scripts-runtime-config.yml
rm -f playbook-dcgm-runtime-config.yml
rm -f playbook-container-validation-runtime-config.yml
rm -f playbook-hpc-controller.yml
rm -f playbook-hpc-compute.yml

# Verify deletion
echo "Remaining playbooks:"
ls -1 playbook-*.yml

# Should show exactly 7 playbooks
ls -1 playbook-*.yml | wc -l
```

**Documentation Updates:**

1. **Update ansible/README.md:**
   - Document new 3-playbook structure
   - Explain Packer vs Runtime playbooks
   - Update usage examples
   - Add migration guide

2. **Update ansible/README-packer-ansible.md:**
   - Update with new Packer playbook names
   - Document new playbook structure

3. **Create migration guide:**
   - Document changes for users of old playbooks
   - Provide mapping: old → new playbooks
   - Include example commands

**Validation Criteria:**

- [ ] Task 033 validation passed completely
- [ ] Backup created successfully
- [ ] All 9 obsolete playbooks deleted
- [ ] Exactly 7 playbooks remain (3 new + 2 storage + 2 infrastructure)
- [ ] No broken references in codebase
- [ ] ansible/README.md updated
- [ ] ansible/README-packer-ansible.md updated
- [ ] Documentation reflects new structure
- [ ] Grep confirms no remaining references to deleted playbooks
- [ ] Packer builds still work with new playbooks
- [ ] Migration guide created

**Verification Commands:**

```bash
# Count remaining playbooks (should be 7)
ls -1 ansible/playbooks/playbook-*.yml | wc -l

# List remaining playbooks
echo "Remaining playbooks:"
ls -1 ansible/playbooks/playbook-*.yml

# Verify no references to deleted playbooks
cd ansible
echo "Checking for references to deleted playbooks..."

for playbook in \
  playbook-hpc.yml \
  playbook-hpc-controller.yml \
  playbook-hpc-compute.yml \
  playbook-slurm-compute-runtime-config.yml \
  playbook-cgroup-runtime-config.yml \
  playbook-gres-runtime-config.yml \
  playbook-job-scripts-runtime-config.yml \
  playbook-dcgm-runtime-config.yml \
  playbook-container-validation-runtime-config.yml
do
  echo "  Checking: $playbook"
  if grep -r "$playbook" . --exclude-dir=.git 2>/dev/null; then
    echo "    ⚠️  References found - needs update"
  else
    echo "    ✅ No references found"
  fi
done

# Verify README updated
echo "Verifying README documentation:"
grep -A 20 "Playbooks" ansible/README.md | head -30

# Verify packer templates reference new playbooks
grep -h "playbook_file" packer/hpc-*/hpc-*.pkr.hcl 2>/dev/null || echo "Packer templates not found"
```

**Post-Deletion Verification:**

```bash
# Run tests with new playbooks
cd tests
make test-hpc-runtime

# Verify everything still works
echo "✅ Cleanup complete and verified"
```

---

### Task 034.1: Fix SLURM Installation to Use Pre-Built Packages

- **ID**: TASK-034.1
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-028.2 (SLURM source build), TASK-034 (playbook cleanup)
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate
- **Status**: ✅ Complete (Verified 2025-10-20 - install.yml uses pre-built packages)
- **Priority**: HIGH

**Description:** Update Ansible SLURM roles to install from pre-built Debian packages created in TASK-028.2,
using the same pattern as BeeGFS package installation (check, copy, install).

**Problem Statement:**

Current SLURM installation uses Debian Trixie repositories which are missing or have incomplete packages:

```yaml
# Current broken installation (ansible/roles/slurm-controller/tasks/install.yml)
- name: Install SLURM packages
  apt:
    name:
      - slurm-wlm
      - slurmdbd
      - slurm-client
    state: present
# FAILS: Packages not available in Trixie repos
```

**Solution Pattern (Same as BeeGFS):**

Follow the proven BeeGFS package installation pattern:

<<<<<<< HEAD

```yaml
# New installation method (uses pre-built packages)
- name: Check if SLURM meta package exists
  stat:
    path: "{{ slurm_package_path }}/slurm-smd_{{ slurm_version }}_amd64.deb"
  register: slurm_meta_package
  delegate_to: localhost

- name: Copy SLURM packages to target
  copy:
    src: "{{ slurm_package_path }}/"
    dest: "/tmp/slurm-packages/"
  when: slurm_meta_package.stat.exists

- name: Install SLURM controller packages from pre-built packages
  apt:
    deb: "{{ item }}"
  loop:
    - "/tmp/slurm-packages/slurm-smd_{{ slurm_version }}_amd64.deb"
    - "/tmp/slurm-packages/slurm-smd-slurmctld_{{ slurm_version }}_amd64.deb"
    - "/tmp/slurm-packages/slurm-smd-slurmdbd_{{ slurm_version }}_amd64.deb"
  when: slurm_meta_package.stat.exists
```

=======

1. **Check if already installed** - Skip if SLURM binaries exist
2. **Check packages on remote host** - Look in `/tmp/slurm-packages/` (Packer provisioner copies them)
3. **Check packages on Ansible controller** - Look in `build/packages/slurm/` (runtime deployments)
4. **Copy packages if needed** - From controller to remote (runtime only)
5. **Install from local packages** - Use `apt deb:` to install
6. **Fail with clear message** - If packages not found anywhere

>>>>>>> 785d57b (refactor(ansible): consolidate runtime playbooks into unified structure)

**Deliverables:**

- `ansible/roles/slurm-controller/tasks/install.yml` - Rewritten using BeeGFS pattern
- `ansible/roles/slurm-compute/tasks/install.yml` - Rewritten using BeeGFS pattern
- `ansible/roles/slurm-controller/defaults/main.yml` - Add package path variables
- `ansible/roles/slurm-compute/defaults/main.yml` - Add package path variables
- Test validation ensuring SLURM installs correctly from pre-built packages

**Implementation Steps:**

**1. Update slurm-controller Role Variables:**

**File:** `ansible/roles/slurm-controller/defaults/main.yml`

```yaml
<<<<<<< HEAD
# Add these variables
slurm_version: "24.11.0"
slurm_package_path: "{{ playbook_dir }}/../build/packages/slurm"
slurm_install_method: "prebuilt"  # Options: prebuilt, repository
slurm_meta_package: "slurm-smd_{{ slurm_version }}_amd64.deb"
slurm_controller_packages:
  - "slurm-smd_{{ slurm_version }}_amd64.deb"
  - "slurm-smd-slurmctld_{{ slurm_version }}_amd64.deb"
  - "slurm-smd-slurmdbd_{{ slurm_version }}_amd64.deb"
=======
# SLURM Package Installation Configuration
slurm_version: "23.11.10"
slurm_packages_path: "/tmp/slurm-packages"  # Runtime path on target nodes
slurm_packages_source_dir: "build/packages/slurm"  # Source on Ansible controller

# Required packages for controller
slurm_controller_required_packages:
  - "slurm-wlm_{{ slurm_version }}_amd64.deb"
  - "slurm-wlm-basic-plugins_{{ slurm_version }}_amd64.deb"
  - "slurmctld_{{ slurm_version }}_amd64.deb"
  - "slurmdbd_{{ slurm_version }}_amd64.deb"

# Dependencies (from Debian repos)
slurm_controller_dependencies:
  - libmunge2
  - munge
  - libmariadb3
  - mariadb-client
  - libpmix2
  - libpam0g
  - libhwloc15
  - liblua5.3-0
  - libjson-c5
>>>>>>> 785d57b (refactor(ansible): consolidate runtime playbooks into unified structure)
```

**2. Update slurm-compute Role Variables:**

**File:** `ansible/roles/slurm-compute/defaults/main.yml`

```yaml
# SLURM Package Installation Configuration
slurm_version: "23.11.10"
slurm_packages_path: "/tmp/slurm-packages"  # Runtime path on target nodes
slurm_packages_source_dir: "build/packages/slurm"  # Source on Ansible controller

# Required packages for compute
slurm_compute_required_packages:
  - "slurm-wlm_{{ slurm_version }}_amd64.deb"
  - "slurm-wlm-basic-plugins_{{ slurm_version }}_amd64.deb"
  - "slurmd_{{ slurm_version }}_amd64.deb"

# Dependencies (from Debian repos)
slurm_compute_dependencies:
  - libmunge2
  - munge
  - libpmix2
  - libpam0g
  - libhwloc15
  - liblua5.3-0
  - libjson-c5
```

**3. Rewrite slurm-controller Installation Task (BeeGFS Pattern):**

**File:** `ansible/roles/slurm-controller/tasks/install.yml`

```yaml
---
# SLURM Controller Package Installation
# Uses pre-built packages from TASK-028.2 (same pattern as BeeGFS)
#
# Installation Flow:
# 1. Check if already installed (skip if binaries exist)
# 2. Check packages on remote host (Packer: /tmp/slurm-packages/)
# 3. Check packages on controller (Runtime: build/packages/slurm/)
# 4. Copy packages if needed (Runtime only)
# 5. Install from local packages
# 6. Fail with clear message if packages not found

- name: Check if SLURM controller is already installed
  ansible.builtin.stat:
    path: /usr/sbin/slurmctld
  register: slurmctld_installed
  tags:
    - slurm
    - slurm-controller
    - check

# Pre-built package installation (NEW METHOD)
- name: Install SLURM from pre-built packages
  when: slurm_install_method == "prebuilt"
  block:
    - name: Check if SLURM meta package exists
      stat:
        path: "{{ slurm_package_path }}/{{ slurm_meta_package }}"
      register: slurm_prebuilt_package
      delegate_to: localhost

    - name: Fail if pre-built packages not found
      fail:
        msg: |
          SLURM pre-built packages not found: {{ slurm_package_path }}/{{ slurm_meta_package }}
          
          Build packages first:
            make config
            make run-docker COMMAND="cmake --build build --target build-slurm-packages"
          
          Or change slurm_install_method to 'repository' (may fail on Trixie)
      when: not slurm_prebuilt_package.stat.exists

- name: Check if packages exist on Ansible controller (for runtime deployment)
  ansible.builtin.find:
    paths: "{{ slurm_packages_source_dir }}"
    patterns: "slurm-wlm_{{ slurm_version }}_*.deb"
  register: controller_packages_check
  delegate_to: localhost
  become: false
  when:
    - not slurmctld_installed.stat.exists
    - (not packages_dir_check.stat.exists) or (prebuilt_packages_check.matched | default(0) == 0)
  tags:
    - slurm
    - slurm-controller
    - check

    - name: Copy SLURM pre-built packages to target
      copy:
        src: "{{ slurm_package_path }}/"
        dest: "/tmp/slurm-packages/"
        mode: '0644'

    - name: Install dependencies for SLURM packages
      apt:
        name:
          - libmunge2
          - libmariadb3
          - libpmix2
          - libpam0g
          - libhwloc15
          - liblua5.3-0
          - libjson-c5
        state: present
        update_cache: yes

    - name: Install SLURM controller packages from pre-built packages
      apt:
        deb: "/tmp/slurm-packages/{{ item }}"
        state: present
      loop: "{{ slurm_controller_packages }}"

- name: Fail if pre-built packages not found
  ansible.builtin.fail:
    msg: >-
      SLURM pre-built packages not found at {{ slurm_packages_path }}.
      Expected: slurm-wlm_{{ slurm_version }}_*.deb
      Checked on controller: {{ slurm_packages_source_dir }}
      For Packer builds: Packages should be copied by Packer to /tmp/slurm-packages/
      For runtime: Build packages first with: cmake --build build --target build-slurm-packages
  when:
    - not slurmctld_installed.stat.exists
    - prebuilt_packages_check_final.matched | default(0) == 0
  tags:
    - slurm
    - slurm-controller

- name: Display package installation method
  ansible.builtin.debug:
    msg: >-
      {{ 'SLURM controller already installed, skipping' if slurmctld_installed.stat.exists
      else 'Installing SLURM controller packages from ' + slurm_packages_path }}
  tags:
    - slurm
    - slurm-controller

- name: Install SLURM controller dependencies
  ansible.builtin.apt:
    name: "{{ slurm_controller_dependencies }}"
    state: present
    update_cache: true
  when: not slurmctld_installed.stat.exists
  tags:
    - slurm
    - slurm-controller
    - install

- name: Find SLURM controller package files
  ansible.builtin.find:
    paths: "{{ slurm_packages_path }}"
    patterns: "{{ slurm_controller_required_packages }}"
  register: slurm_controller_pkgs
  when: not slurmctld_installed.stat.exists
  tags:
    - slurm
    - slurm-controller
    - install

- name: Install SLURM controller packages
  ansible.builtin.apt:
    deb: "{{ item.path }}"
    state: present
  loop: "{{ slurm_controller_pkgs.files }}"
  when:
    - not slurmctld_installed.stat.exists
    - slurm_controller_pkgs.matched | default(0) > 0
  tags:
    - slurm
    - slurm-controller
    - install

- name: Verify SLURM controller installation
  ansible.builtin.command: "slurmctld -V"
  register: slurmctld_version
  changed_when: false
  failed_when: false
  tags:
    - slurm
    - slurm-controller
    - verify

- name: Display SLURM controller version
  ansible.builtin.debug:
    msg: "SLURM controller installed: {{ slurmctld_version.stdout }}"
  when: slurmctld_version.rc == 0
  tags:
    - slurm
    - slurm-controller
    - verify

- name: Verify slurmdbd installation
  ansible.builtin.command: "slurmdbd -V"
  register: slurmdbd_version
  changed_when: false
  failed_when: false
  tags:
    - slurm
    - slurm-controller
    - verify

- name: Display slurmdbd version
  ansible.builtin.debug:
    msg: "slurmdbd installed: {{ slurmdbd_version.stdout }}"
  when: slurmdbd_version.rc == 0
  tags:
    - slurm
    - slurm-controller
    - verify
```

**4. Rewrite slurm-compute Installation Task (BeeGFS Pattern):**

**File:** `ansible/roles/slurm-compute/tasks/install.yml`

Follow exact same pattern as controller, but use compute-specific packages and check for `/usr/sbin/slurmd` instead.

**5. Update Packer Templates to Copy Packages:**

**File:** `packer/hpc-controller/hpc-controller.pkr.hcl`

```hcl
build {
  sources = ["source.qemu.hpc-controller"]

  # Copy SLURM pre-built packages to VM (before Ansible)
  provisioner "file" {
    source      = "../../build/packages/slurm/"
    destination = "/tmp/slurm-packages/"
  }

  provisioner "ansible" {
    playbook_file = "../../ansible/playbooks/playbook-hpc-packer-controller.yml"
    # ... rest of config
  }
}
```

**File:** `packer/hpc-compute/hpc-compute.pkr.hcl`

Same pattern - copy packages before Ansible runs.

**6. Update Build Documentation:**

**File:** `docs/README.md` (or relevant build docs)

Update the documentation to include SLURM package build instructions:

```markdown
## Building HPC Cluster Images

### Prerequisites

Before building HPC images, you MUST build SLURM packages from source.
```

```bash
# 1. Configure CMake build system
make config

# 2. Build SLURM packages (required for Debian Trixie)
make run-docker COMMAND="cmake --build build --target build-slurm-packages"

# 3. Verify packages were built
ls -lh build/packages/slurm/
# Should show: slurm-wlm_23.11.10_amd64.deb, slurmctld_23.11.10_amd64.deb, etc.

# 4. Build HPC images (will use packages from step 2)
make run-docker COMMAND="cmake --build build --target build-hpc-controller-image"
make run-docker COMMAND="cmake --build build --target build-hpc-compute-image"
```

```markdown
### Why Pre-built Packages?

Debian Trixie repositories lack complete SLURM packages. We build from source to ensure:

- ✅ All SLURM components available (slurmctld, slurmdbd, slurmd)
- ✅ PMIx integration for MPI support
- ✅ Latest stable version (23.11.10)
- ✅ Consistent across all nodes

### Package Lifecycle

**Packer Builds**: Packages copied to `/tmp/slurm-packages/` before Ansible runs  
**Runtime Deployments**: Packages copied from `build/packages/slurm/` by Ansible

Same pattern as BeeGFS packages for consistency.
```

**Validation Criteria:**

- [ ] SLURM packages checked on remote host first (Packer mode)
- [ ] SLURM packages checked on controller second (runtime mode)
- [ ] Packages copy from controller to remote when needed
- [ ] SLURM installs successfully from local packages
- [ ] All dependencies resolve correctly
- [ ] slurmctld, slurmdbd, slurmd binaries work
- [ ] Packer controller image builds successfully
- [ ] Packer compute image builds successfully
- [ ] Clear error message if packages not found
- [ ] Installation skipped if already installed
- [ ] Pattern consistent with BeeGFS installation

**Test Commands:**

```bash
# 1. Build SLURM packages (prerequisite)
make config
make run-docker COMMAND="cmake --build build --target build-slurm-packages"

# Verify packages exist
ls -lh build/packages/slurm/*.deb
# Should show slurm-smd_24.11.0_amd64.deb and related packages

# 3. Build controller image
make run-docker COMMAND="cmake --build build --target build-hpc-controller-image"

# 4. Build compute image
make run-docker COMMAND="cmake --build build --target build-hpc-compute-image"

# 5. Test runtime deployment (uses same packages)
make cluster-deploy

# 6. Verify SLURM functional
ssh -i build/shared/ssh-keys/id_rsa admin@192.168.100.10 'slurmctld -V'
ssh -i build/shared/ssh-keys/id_rsa admin@192.168.100.11 'slurmd -V'
```

**Success Criteria:**

- ✅ Packages detected in Packer builds (file provisioner)
- ✅ Packages detected in runtime (Ansible controller)
- ✅ Packages copy correctly between controller and nodes
- ✅ SLURM installs without apt repository errors
- ✅ All SLURM binaries functional
- ✅ PMIx integration working
- ✅ Controller image builds successfully
- ✅ Compute image builds successfully
- ✅ No dependency errors
- ✅ Pattern matches BeeGFS exactly

**Dependencies:**

- **Requires**: TASK-028.2 (SLURM packages must be built first)
- **Blocks**: All HPC cluster deployment
- **Related**: TASK-029, TASK-030 (Packer playbooks), TASK-031 (runtime playbook)
- **Reference**: BeeGFS installation in `ansible/roles/beegfs-client/tasks/install.yml` (proven pattern)

**Notes:**

- **Critical Fix**: Resolves complete blockage of HPC cluster deployment on Trixie
- **Pattern Consistency**: Uses exact same approach as BeeGFS for maintainability
- **Build First**: Users must build SLURM packages before building images
- **Clear Errors**: Helpful error messages guide users to build packages
- **Packer Integration**: File provisioner copies packages before Ansible
- **Runtime Support**: Ansible copies packages from controller when needed

---

## Phase 4: Test Framework Consolidation (Tasks 035-037)

> **📋 COMPREHENSIVE TEST PLAN AVAILABLE**  
> Detailed specifications, consolidation strategy, component matrices, and implementation phases are now
> documented in the **Consolidated Test Plan**:
>
> **Location**: `docs/implementation-plans/task-lists/test-plan/`
>
> **Key Documents**:
>
> - [`README.md`](../test-plan/README.md) - Overview and navigation
> - [`00-test-inventory.md`](../test-plan/00-test-inventory.md) - Current test infrastructure baseline
> - [`01-consolidation-plan.md`](../test-plan/01-consolidation-plan.md) - Detailed consolidation strategy
> - [`02-component-matrix.md`](../test-plan/02-component-matrix.md) - Test coverage mapping
> - [`03-framework-specifications.md`](../test-plan/03-framework-specifications.md) - Complete framework specs
> - [`04-implementation-phases.md`](../test-plan/04-implementation-phases.md) - Implementation roadmap
> - [`05-validation-checklist.md`](../test-plan/05-validation-checklist.md) - Quality assurance criteria
>
> **Purpose**: The test plan provides modular, LLM-friendly documentation that eliminates duplication and serves
> as the single source of truth for test framework consolidation. This section provides task summaries only.

### Task 035: Create Unified HPC Runtime Test Framework

- **ID**: TASK-035
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-031 (unified runtime playbook)
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate-Advanced
- **Status**: ✅ Complete (Implemented 2025-10-27) (Verified 2025-10-20 - test-hpc-runtime-framework.sh NOT created)
- **Priority**: HIGH

**Description:** Create unified test framework for HPC runtime configuration, consolidating 6 specialized
runtime test frameworks into single streamlined framework.

**Current Test Frameworks (15 total):**

- test-cgroup-isolation-framework.sh ✅
- test-gpu-gres-framework.sh ✅
- test-job-scripts-framework.sh ✅
- test-dcgm-monitoring-framework.sh ✅
- test-container-integration-framework.sh ✅
- test-slurm-compute-framework.sh ✅
- (plus 9 others for different components)

**Deliverables:**

- `tests/test-hpc-runtime-framework.sh` - Unified runtime test framework
- `tests/test-infra/configs/test-hpc-runtime.yaml` - Unified test configuration
- Standard CLI: e2e, start-cluster, stop-cluster, deploy-ansible, run-tests, list-tests, run-test, status
- Orchestrates all runtime test suites

**Replaces These Frameworks (6 files):**

1. `test-cgroup-isolation-framework.sh`
2. `test-gpu-gres-framework.sh`
3. `test-job-scripts-framework.sh`
4. `test-dcgm-monitoring-framework.sh`
5. `test-container-integration-framework.sh`
6. `test-slurm-compute-framework.sh`

**Test Suites Orchestrated:**

```bash
1. suites/slurm-compute/run-slurm-compute-tests.sh
2. suites/cgroup-isolation/run-cgroup-isolation-tests.sh
3. suites/gpu-gres/run-gpu-gres-tests.sh [conditional on GPU]
4. suites/dcgm-monitoring/run-dcgm-monitoring-tests.sh [conditional on GPU]
5. suites/job-scripts/run-job-scripts-tests.sh
6. suites/container-integration/run-container-integration-tests.sh
```

**Note:** Test suites remain unchanged - only the framework wrapper is consolidated.

**Test Configuration:**

**File:** `tests/test-infra/configs/test-hpc-runtime.yaml`

```yaml
version: "1.0"
test_name: "HPC Runtime Configuration Test"
description: "Unified test framework for complete HPC cluster runtime configuration"

clusters:
  hpc:
    controller:
      hostname: "test-hpc-runtime-controller"
      ip_address: "192.168.220.10"
      memory: 4096
      cpus: 4
      groups:
        - hpc_controllers
    
    compute_nodes:
      - hostname: "test-hpc-runtime-compute01"
        ip_address: "192.168.220.20"
        memory: 8192
        cpus: 8
        groups:
          - compute_nodes

ansible:
  playbook: "../ansible/playbooks/playbook-hpc-runtime.yml"
  inventory_groups:
    hpc_controllers:
      - test-hpc-runtime-controller
    compute_nodes:
      - test-hpc-runtime-compute01

test_suites:
  - name: "slurm-compute"
    path: "suites/slurm-compute/run-slurm-compute-tests.sh"
    required: true
  - name: "cgroup-isolation"
    path: "suites/cgroup-isolation/run-cgroup-isolation-tests.sh"
    required: true
  - name: "gpu-gres"
    path: "suites/gpu-gres/run-gpu-gres-tests.sh"
    required: false
    condition: "gpu_enabled"
  - name: "dcgm-monitoring"
    path: "suites/dcgm-monitoring/run-dcgm-monitoring-tests.sh"
    required: false
    condition: "gpu_enabled"
  - name: "job-scripts"
    path: "suites/job-scripts/run-job-scripts-tests.sh"
    required: true
  - name: "container-integration"
    path: "suites/container-integration/run-container-integration-tests.sh"
    required: true
```

**Framework CLI:**

```bash
# Standard test framework pattern
./test-hpc-runtime-framework.sh [command]

Commands:
  e2e              - Run complete end-to-end test
  start-cluster    - Start test cluster VMs
  stop-cluster     - Stop and cleanup test cluster
  deploy-ansible   - Deploy Ansible configuration
  run-tests        - Run all test suites
  list-tests       - List available test suites
  run-test <name>  - Run specific test suite
  status           - Show cluster status
  help             - Show this help message
```

**Validation Criteria:**

- [ ] Framework implements standard CLI pattern
- [ ] All 6 test suites execute correctly
- [ ] GPU tests skip gracefully when no GPU present
- [ ] Test results properly aggregated and reported
- [ ] Cluster lifecycle management works
- [ ] Uses playbook-hpc-runtime.yml for deployment
- [ ] Test output clearly shows pass/fail per suite
- [ ] Framework handles errors gracefully

**Test Commands:**

```bash
# Validate example configuration
cd tests
uv run ai-how validate ../config/example-multi-gpu-clusters.yaml

# Test complete workflow with example configuration
./test-hpc-runtime-framework.sh e2e

# Test individual commands
./test-hpc-runtime-framework.sh start-cluster
./test-hpc-runtime-framework.sh deploy-ansible
./test-hpc-runtime-framework.sh run-tests
./test-hpc-runtime-framework.sh status
./test-hpc-runtime-framework.sh stop-cluster
```

**Example Configuration Features:**

- HPC cluster with SLURM controller + 2 GPU compute nodes
- Cloud cluster for dual-stack validation
- Multiple GPU types (different vendor/device IDs)
- Complete networking and hardware configuration
- Monitoring stack configuration
- Perfect for comprehensive runtime validation

---

### Task 036: Create HPC Packer Test Frameworks

- **ID**: TASK-036
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-029, TASK-030 (new Packer playbooks)
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate-Advanced
- **Status**: ✅ Complete (Implemented 2025-10-27) (Verified 2025-10-20 - test-hpc-packer-*-framework.sh NOT created)
- **Priority**: HIGH

**Description:** Create test frameworks for HPC Packer image builds, consolidating 5 component-focused
frameworks into 2 image-focused frameworks.

**Deliverables:**

- `tests/test-hpc-packer-controller-framework.sh` - Controller Packer test framework
- `tests/test-hpc-packer-compute-framework.sh` - Compute Packer test framework
- `tests/test-infra/configs/test-hpc-packer-controller.yaml` - Controller test config
- `tests/test-infra/configs/test-hpc-packer-compute.yaml` - Compute test config
- Standard CLI pattern for both frameworks

**Replaces These Frameworks (5 files):**

1. `test-slurm-controller-framework.sh` - Controller component
2. `test-slurm-accounting-framework.sh` - Controller component
3. `test-monitoring-stack-framework.sh` - Controller component
4. `test-grafana-framework.sh` - Controller component
5. `test-container-runtime-framework.sh` - Shared component

**Controller Framework Test Suites:**

```bash
1. suites/slurm-controller/run-slurm-controller-tests.sh
2. suites/monitoring-stack/run-monitoring-stack-tests.sh
```

**Compute Framework Test Suites:**

```bash
1. suites/container-runtime/run-container-runtime-tests.sh
```

**Test Configurations:**

**File:** `tests/test-infra/configs/test-hpc-packer-controller.yaml`

```yaml
version: "1.0"
test_name: "HPC Packer Controller Test"
description: "Test framework for HPC controller Packer image builds"

clusters:
  hpc:
    controller:
      hostname: "test-packer-controller"
      ip_address: "192.168.220.50"
      memory: 4096
      cpus: 4

ansible:
  playbook: "../ansible/playbooks/playbook-hpc-packer-controller.yml"

test_suites:
  - name: "slurm-controller"
    path: "suites/slurm-controller/run-slurm-controller-tests.sh"
    required: true
  - name: "monitoring-stack"
    path: "suites/monitoring-stack/run-monitoring-stack-tests.sh"
    required: true
```

**File:** `tests/test-infra/configs/test-hpc-packer-compute.yaml`

```yaml
version: "1.0"
test_name: "HPC Packer Compute Test"
description: "Test framework for HPC compute Packer image builds"

clusters:
  hpc:
    compute_nodes:
      - hostname: "test-packer-compute01"
        ip_address: "192.168.220.60"
        memory: 8192
        cpus: 8

ansible:
  playbook: "../ansible/playbooks/playbook-hpc-packer-compute.yml"

test_suites:
  - name: "container-runtime"
    path: "suites/container-runtime/run-container-runtime-tests.sh"
    required: true
```

**Validation Criteria:**

- [ ] Both frameworks implement standard CLI pattern
- [ ] Controller framework tests all controller components
- [ ] Compute framework tests all compute components
- [ ] Test suites execute without errors
- [ ] Proper test reporting and logging
- [ ] Uses new Packer playbooks for image builds
- [ ] Framework output clear and actionable

**Test Commands:**

```bash
# Test controller framework
cd tests
./test-hpc-packer-controller-framework.sh e2e

# Test compute framework
./test-hpc-packer-compute-framework.sh e2e
```

---

### Task 037: Update Test Makefile and Delete Obsolete Tests

- **ID**: TASK-037
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-035, TASK-036 (new test frameworks)
- **Estimated Time**: 2 hours
- **Difficulty**: Intermediate
- **Status**: ✅ Complete (Implemented 2025-10-27) (Verified 2025-10-20 - 15 old frameworks still exist)
- **Priority**: MEDIUM (after validation)

**Description:** Update test Makefile with new consolidated targets and remove obsolete test frameworks,
configs, and helper scripts.

**Current Test Framework Status:**

✅ **Existing Frameworks (15):**

- test-beegfs-framework.sh
- test-cgroup-isolation-framework.sh
- test-container-integration-framework.sh
- test-container-registry-framework.sh
- test-container-runtime-framework.sh
- test-dcgm-monitoring-framework.sh
- test-gpu-gres-framework.sh
- test-grafana-framework.sh
- test-job-scripts-framework.sh
- test-monitoring-stack-framework.sh
- test-pcie-passthrough-framework.sh
- test-slurm-accounting-framework.sh
- test-slurm-compute-framework.sh
- test-slurm-controller-framework.sh
- test-virtio-fs-framework.sh

✅ **Additional Test Scripts:**

- test-grafana.sh
- validate-grafana-implementation.sh
- validate-slurm-pmix-config.sh
- setup-test-environment.sh

✅ **Test Suites (Preserved):**
All test suites in `tests/suites/` are preserved and continue to work.
Frameworks are just orchestration wrappers around these suites.

**Makefile Updates:**

**File:** `tests/Makefile`

**Add new targets:**

```makefile
# HPC Runtime Tests (consolidated)
test-hpc-runtime:
 @./test-hpc-runtime-framework.sh e2e

test-hpc-runtime-start:
 @./test-hpc-runtime-framework.sh start-cluster

test-hpc-runtime-deploy:
 @./test-hpc-runtime-framework.sh deploy-ansible

test-hpc-runtime-tests:
 @./test-hpc-runtime-framework.sh run-tests

test-hpc-runtime-stop:
 @./test-hpc-runtime-framework.sh stop-cluster

# HPC Packer Tests
test-hpc-packer-controller:
 @./test-hpc-packer-controller-framework.sh e2e

test-hpc-packer-compute:
 @./test-hpc-packer-compute-framework.sh e2e
```

**Update main targets:**

```makefile
# Core infrastructure tests (updated)
test: \
  test-integration \
  test-ansible-roles \
  test-hpc-runtime \
  test-container-registry

# Comprehensive test suite (updated)
test-all: \
  test-base-images \
  test-hpc-packer-controller \
  test-hpc-packer-compute \
  test-hpc-runtime \
  test-container-registry \
  test-pcie-passthrough \
  test-beegfs \
  test-virtio-fs \
  test-ansible-roles \
  test-integration
```

**Remove old targets (all variants):**

```makefile
# Delete these targets:
- test-cgroup-isolation*
- test-gpu-gres*
- test-job-scripts*
- test-dcgm-monitoring*
- test-container-integration*
- test-slurm-compute*
- test-slurm-controller*
- test-slurm-accounting*
- test-monitoring-stack*
- test-grafana*
- test-container-runtime*
```

**Files to Delete:**

**Test Frameworks (13 files):**

```bash
tests/test-cgroup-isolation-framework.sh
tests/test-gpu-gres-framework.sh
tests/test-job-scripts-framework.sh
tests/test-dcgm-monitoring-framework.sh
tests/test-container-integration-framework.sh
tests/test-slurm-compute-framework.sh
tests/test-slurm-controller-framework.sh
tests/test-slurm-accounting-framework.sh
tests/test-monitoring-stack-framework.sh
tests/test-grafana-framework.sh
tests/test-container-runtime-framework.sh
tests/test-grafana.sh
tests/validate-grafana-implementation.sh
```

**Test Configs (10 files):**

```bash
tests/test-infra/configs/test-cgroup-isolation.yaml
tests/test-infra/configs/test-gpu-gres.yaml
tests/test-infra/configs/test-job-scripts.yaml
tests/test-infra/configs/test-dcgm-monitoring.yaml
tests/test-infra/configs/test-container-integration.yaml
tests/test-infra/configs/test-slurm-compute.yaml
tests/test-infra/configs/test-slurm-controller.yaml
tests/test-infra/configs/test-slurm-accounting.yaml
tests/test-infra/configs/test-monitoring-stack.yaml
tests/test-infra/configs/test-container-runtime.yaml
```

**Helper Scripts (2 files):**

```bash
tests/validate-slurm-pmix-config.sh
tests/setup-test-environment.sh
```

**Total: 25 files deleted**

**Deletion Commands:**

```bash
cd tests

# Create backup
mkdir -p ../backup/tests-$(date +%Y%m%d)
cp test-cgroup-isolation-framework.sh \
   test-gpu-gres-framework.sh \
   test-job-scripts-framework.sh \
   test-dcgm-monitoring-framework.sh \
   test-container-integration-framework.sh \
   test-slurm-compute-framework.sh \
   test-slurm-controller-framework.sh \
   test-slurm-accounting-framework.sh \
   test-monitoring-stack-framework.sh \
   test-grafana-framework.sh \
   test-container-runtime-framework.sh \
   test-grafana.sh \
   validate-grafana-implementation.sh \
   validate-slurm-pmix-config.sh \
   setup-test-environment.sh \
   ../backup/tests-$(date +%Y%m%d)/ 2>/dev/null || true

# Delete test frameworks
rm -f test-cgroup-isolation-framework.sh
rm -f test-gpu-gres-framework.sh
rm -f test-job-scripts-framework.sh
rm -f test-dcgm-monitoring-framework.sh
rm -f test-container-integration-framework.sh
rm -f test-slurm-compute-framework.sh
rm -f test-slurm-controller-framework.sh
rm -f test-slurm-accounting-framework.sh
rm -f test-monitoring-stack-framework.sh
rm -f test-grafana-framework.sh
rm -f test-container-runtime-framework.sh
rm -f test-grafana.sh
rm -f validate-grafana-implementation.sh

# Delete test configs
rm -f test-infra/configs/test-cgroup-isolation.yaml
rm -f test-infra/configs/test-gpu-gres.yaml
rm -f test-infra/configs/test-job-scripts.yaml
rm -f test-infra/configs/test-dcgm-monitoring.yaml
rm -f test-infra/configs/test-container-integration.yaml
rm -f test-infra/configs/test-slurm-compute.yaml
rm -f test-infra/configs/test-slurm-controller.yaml
rm -f test-infra/configs/test-slurm-accounting.yaml
rm -f test-infra/configs/test-monitoring-stack.yaml
rm -f test-infra/configs/test-container-runtime.yaml

# Delete helper scripts
rm -f validate-slurm-pmix-config.sh
rm -f setup-test-environment.sh

# Verify remaining frameworks
echo "Remaining test frameworks:"
ls -1 test-*-framework.sh
```

**Additional Updates:**

- Update `tests/README.md` with new framework structure
- Remove references to old frameworks in documentation
- Add migration notes for users of old test commands
- Document new unified test structure

**Validation Criteria:**

- [ ] All new Makefile targets work correctly
- [ ] Old targets removed from Makefile
- [ ] All 25 obsolete files deleted
- [ ] Test suites remain intact (suites/ directory unchanged)
- [ ] No broken references to deleted files
- [ ] tests/README.md updated
- [ ] Documentation reflects new structure
- [ ] Migration guide created for users

**Verification Commands:**

```bash
# Test new Makefile targets
cd tests
make test-hpc-runtime
make test-hpc-packer-controller
make test-hpc-packer-compute
make test-all

# Count remaining frameworks (should be 5)
# beegfs, pcie-passthrough, virtio-fs, container-registry, + 3 new
ls -1 test-*-framework.sh | wc -l

# Verify no references to old frameworks
for framework in test-cgroup-isolation test-gpu-gres test-slurm-compute; do
  echo "Checking $framework..."
  grep -r "${framework}-framework" . --exclude-dir=.git || echo "  ✅ Clean"
done

# Verify test suites intact
ls -1 suites/*/run-*.sh | wc -l
```

---

## Phase 4.5: Storage Infrastructure Enhancement (Tasks 038-041)

### Task 038: Consolidate BeeGFS Packer Installation into HPC Playbooks

- **ID**: TASK-038
- **Phase**: 4.5 - Storage Infrastructure Enhancement
- **Dependencies**: TASK-029, TASK-030 (HPC Packer playbooks)
- **Estimated Time**: 1.5 hours
- **Difficulty**: Junior
- **Status**: ✅ Complete (Verified 2025-10-23 - BeeGFS Packer installation consolidated into HPC playbooks)
- **Priority**: MEDIUM

**Description:** Consolidate BeeGFS Packer installation into HPC Packer playbooks, eliminating the
need for a separate BeeGFS Packer playbook. This achieves the final 50% reduction target (14 → 7 playbooks).

**Current State:**

- Separate `playbook-beegfs-packer-install.yml` (59 lines)
- Must be run separately or via additional Packer provisioner
- Adds complexity to build process
- BeeGFS installation is ~10 MB per node, ~23 seconds install time

**Deliverables:**

1. Update `ansible/playbooks/playbook-hpc-packer-controller.yml`:
   - Add `install_beegfs` variable (default: true)
   - Add BeeGFS roles: beegfs-mgmt, beegfs-meta, beegfs-storage, beegfs-client
   - Make roles conditional on `install_beegfs` flag

2. Update `ansible/playbooks/playbook-hpc-packer-compute.yml`:
   - Add `install_beegfs` variable (default: true)
   - Add BeeGFS roles: beegfs-storage, beegfs-client
   - Make roles conditional on `install_beegfs` flag

3. Update Packer templates:
   - Add BeeGFS package file provisioner to both templates
   - Copy packages from `build/packages/beegfs/` to `/tmp/beegfs-packages/`

4. Delete `ansible/playbooks/playbook-beegfs-packer-install.yml`

5. Update documentation:
   - `ansible/playbooks/README.md`
   - `ansible/README-packer-ansible.md`

**Implementation Notes:**

```yaml
# playbook-hpc-packer-controller.yml changes:
vars:
  install_beegfs: true  # NEW: Enable BeeGFS by default
  beegfs_packages_path: "/tmp/beegfs-packages"

roles:
  # ... existing roles ...
  - role: beegfs-mgmt
    when: install_beegfs | default(true)
  - role: beegfs-meta
    when: install_beegfs | default(true)
  - role: beegfs-storage
    when: install_beegfs | default(true)
  - role: beegfs-client
    when: install_beegfs | default(true)
```

**Validation Criteria:**

- [ ] BeeGFS packages installed on controller during Packer build
- [ ] BeeGFS packages installed on compute during Packer build
- [ ] Packer builds complete successfully with BeeGFS
- [ ] Images functional with BeeGFS pre-installed
- [ ] Can disable BeeGFS with `install_beegfs: false`
- [ ] `playbook-beegfs-packer-install.yml` deleted
- [ ] Documentation updated
- [ ] Total playbooks: 7 (50% reduction achieved!)

**Test Commands:**

```bash
# Build images with BeeGFS (default)
packer build packer/hpc-controller/hpc-controller.pkr.hcl
packer build packer/hpc-compute/hpc-compute.pkr.hcl

# Build images without BeeGFS (optional)
packer build -var "install_beegfs=false" packer/hpc-controller/hpc-controller.pkr.hcl

# Verify packages installed
ssh controller "dpkg -l | grep beegfs"

# Count playbooks (should be 7)
ls -1 ansible/playbooks/playbook-*.yml | wc -l
```

**Benefits:**

- ✅ Achieves 50% playbook reduction target (14 → 7)
- ✅ Simpler build process (single Packer command)
- ✅ BeeGFS always available but optional
- ✅ Minimal overhead (~10 MB, ~23 sec per node)
- ✅ Consistent with consolidation pattern

---

### Task 039: Integrate VirtIO-FS Support into Runtime Playbook

- **ID**: TASK-039
- **Phase**: 4.5 - Storage Infrastructure Enhancement
- **Dependencies**: TASK-031 (unified runtime playbook)
- **Estimated Time**: 2 hours
- **Difficulty**: Intermediate
- **Status**: ✅ Complete (Verified 2025-10-23 - VirtIO-FS integrated into playbook-hpc-runtime.yml)
- **Priority**: HIGH

**Description:** Add VirtIO-FS host directory mounting support to the unified runtime playbook,
enabling easy file sharing between host and controller VM for development workflows.

**Current State:**

- Separate `playbook-virtio-fs-runtime-config.yml` exists but not integrated
- `playbook-hpc-runtime.yml` has no VirtIO-FS support
- Users must run separate playbook for host mounts
- Common use case: Mount project repo on controller for easy access

**Deliverables:**

1. Update `ansible/playbooks/playbook-hpc-runtime.yml`:
   - Add VirtIO-FS configuration play after hostname setup
   - Target: hpc_controllers only
   - Conditional execution based on `virtio_fs_mounts` variable
   - Use existing `virtio-fs-mount` role

2. Update cluster configuration schema:
   - Add `virtio_fs_mounts` to controller configuration
   - Document mount configuration structure
   - Provide examples for common use cases

3. Update inventory generation:
   - Pass `virtio_fs_mounts` from cluster config to Ansible inventory
   - Ensure proper variable propagation

4. Update VM launch configuration:
   - Document QEMU virtio-fs configuration requirements
   - Provide examples for libvirt XML and QEMU CLI

**Implementation Notes:**

```yaml
# Add to playbook-hpc-runtime.yml after hostname configuration:

# Configure VirtIO-FS mounts on controller
- name: Configure VirtIO-FS Host Mounts on Controller
  hosts: hpc_controllers
  become: true
  gather_facts: true
  vars:
    packer_build: false
    virtio_fs_perform_mounts: true
  
  tasks:
    - name: Display VirtIO-FS configuration
      debug:
        msg: "Configuring {{ virtio_fs_mounts | length }} VirtIO-FS mounts"
      when:
        - virtio_fs_mounts is defined
        - virtio_fs_mounts | length > 0
    
    - name: Configure VirtIO-FS mounts
      import_role:
        name: virtio-fs-mount
      when:
        - virtio_fs_mounts is defined
        - virtio_fs_mounts | length > 0
      tags:
        - virtio-fs
        - storage
```

**Configuration Example:**

```yaml
# config/example-multi-gpu-clusters.yaml
clusters:
  hpc:
    controller:
      virtio_fs_mounts:
        - tag: "project-repo"
          host_path: "/home/user/Projects/pharos.ai-hyperscaler"
          mount_point: "/mnt/host-repo"
          readonly: false
          owner: "admin"
          group: "admin"
          mode: "0755"
```

**Validation Criteria:**

- [ ] VirtIO-FS mounts configured on controller
- [ ] Mounts accessible and writable (if not readonly)
- [ ] Survives reboot (fstab entries created)
- [ ] No impact if `virtio_fs_mounts` not defined
- [ ] Documentation includes VM launch examples
- [ ] Inventory generation passes mount configuration

**Test Commands:**

```bash
# Deploy with VirtIO-FS mounts
ansible-playbook -i inventory playbooks/playbook-hpc-runtime.yml

# Verify mounts
ssh controller "mount | grep virtiofs"
ssh controller "ls -la /mnt/host-repo"
ssh controller "touch /mnt/host-repo/test.txt"  # Verify write access
```

**Benefits:**

- ✅ Easy host-to-VM file sharing for development
- ✅ Mount project repo for code/config access
- ✅ No need for separate playbook execution
- ✅ Integrated into main deployment workflow

---

### Task 040: Configure Container Registry on BeeGFS

- **ID**: TASK-040
- **Phase**: 4.5 - Storage Infrastructure Enhancement
- **Dependencies**: None (can run independently)
- **Estimated Time**: 1 hour
- **Difficulty**: Junior
- **Status**: ✅ Complete (Implemented 2025-10-27) (Verified 2025-10-20 - Registry uses /opt/containers not /mnt/beegfs)
- **Priority**: MEDIUM

**Description:** Configure container registry to use BeeGFS parallel filesystem instead of local
storage, enabling automatic distribution of container images across all cluster nodes.

**Current State:**

- Container registry uses local storage: `/opt/containers`
- Requires sync script to distribute containers to compute nodes
- Manual process, potential for inconsistency
- Single point of failure (controller disk)

**Proposed State:**

- Container registry on BeeGFS: `/mnt/beegfs/containers`
- Automatic distribution to all nodes via BeeGFS client
- No sync script needed
- Distributed storage with redundancy

**Deliverables:**

1. Update `ansible/roles/container-registry/defaults/main.yml`:
   - Change default path to `/mnt/beegfs/containers`
   - Add variable for storage backend selection
   - Auto-detect BeeGFS availability

2. Update `ansible/playbooks/playbook-container-registry.yml`:
   - Add pre-check for BeeGFS mount
   - Warn if BeeGFS not available
   - Fall back to local storage if needed

3. Update documentation:
   - Explain benefits of BeeGFS-backed registry
   - Provide deployment order instructions
   - Document fallback to local storage

**Implementation Notes:**

```yaml
# ansible/roles/container-registry/defaults/main.yml
# Auto-detect BeeGFS and use if available
container_registry_on_beegfs: true
container_registry_beegfs_path: "/mnt/beegfs/containers"
container_registry_local_path: "/opt/containers"
container_registry_base_path: >-
  {{ container_registry_beegfs_path 
     if (container_registry_on_beegfs and beegfs_mounted | default(false))
     else container_registry_local_path }}
```

**Deployment Order:**

```bash
# 1. Deploy HPC cluster
ansible-playbook playbooks/playbook-hpc-runtime.yml

# 2. Deploy BeeGFS (creates /mnt/beegfs)
ansible-playbook playbooks/playbook-beegfs-runtime-config.yml

# 3. Deploy container registry ON BeeGFS
ansible-playbook playbooks/playbook-container-registry.yml
```

**Validation Criteria:**

- [ ] Registry created at `/mnt/beegfs/containers`
- [ ] All nodes can access registry path
- [ ] Containers immediately visible on all nodes
- [ ] No sync script execution needed
- [ ] Falls back to local storage if BeeGFS unavailable
- [ ] Documentation updated with benefits

**Test Commands:**

```bash
# Deploy container to registry
scp pytorch.sif controller:/mnt/beegfs/containers/ml-frameworks/

# Verify on compute nodes (immediate)
ssh compute01 "ls /mnt/beegfs/containers/ml-frameworks/pytorch.sif"
ssh compute02 "ls /mnt/beegfs/containers/ml-frameworks/pytorch.sif"

# Run job using container
srun --gres=gpu:1 apptainer exec \
  /mnt/beegfs/containers/ml-frameworks/pytorch.sif \
  python train.py
```

**Benefits:**

- ✅ Automatic container distribution across nodes
- ✅ No manual sync required
- ✅ Better performance (parallel I/O)
- ✅ Fault tolerance and redundancy
- ✅ Simpler management workflow

---

### Task 041: Update Cluster Configuration Schema for Storage

- **ID**: TASK-041
- **Phase**: 4.5 - Storage Infrastructure Enhancement
- **Dependencies**: TASK-039 (VirtIO-FS integration)
- **Estimated Time**: 1 hour
- **Difficulty**: Junior
- **Status**: ✅ Complete (Verified 2025-10-23 - virtio_fs_mounts and beegfs_config added to cluster config)
- **Priority**: HIGH

**Description:** Update cluster configuration YAML schema to support VirtIO-FS mounts and storage
backend selection, providing a comprehensive configuration interface for storage infrastructure.

**Current State:**

- No VirtIO-FS configuration in schema
- No storage backend selection options
- Configuration scattered across multiple files
- Example configuration lacks storage examples

**Deliverables:**

1. Update `config/example-multi-gpu-clusters.yaml`:
   - Add `virtio_fs_mounts` section to controller
   - Add example mount configurations
   - Document mount configuration options
   - Add storage backend selection

2. Update inventory generation script:
   - Parse `virtio_fs_mounts` configuration
   - Pass to Ansible inventory
   - Validate mount configuration

3. Update documentation:
   - Document VirtIO-FS configuration schema
   - Provide common use case examples
   - Explain storage backend options

**Implementation:**

```yaml
# config/example-multi-gpu-clusters.yaml additions:

clusters:
  hpc:
    controller:
      cpu_cores: 4
      memory_gb: 8
      ip_address: "192.168.100.10"
      
      # NEW: VirtIO-FS host directory sharing
      virtio_fs_mounts:
        # Mount project repository
        - tag: "project-repo"
          host_path: "/home/user/Projects/pharos.ai-hyperscaler"
          mount_point: "/mnt/host-repo"
          readonly: false
          owner: "admin"
          group: "admin"
          mode: "0755"
          options: "rw,relatime"
        
        # Mount datasets (read-only for safety)
        - tag: "datasets"
          host_path: "/data/ml-datasets"
          mount_point: "/mnt/datasets"
          readonly: true
          owner: "admin"
          group: "admin"
          mode: "0755"
          options: "ro,relatime"
    
    # NEW: Storage backend configuration
    storage:
      backends:
        beegfs:
          enabled: true
          mount_point: "/mnt/beegfs"
        virtio_fs:
          enabled: true  # Controller only
      
      container_registry:
        backend: "beegfs"  # Options: beegfs, local
        path: "/mnt/beegfs/containers"
```

**Validation Criteria:**

- [ ] Schema includes VirtIO-FS mount configuration
- [ ] Example configuration has commented examples
- [ ] Inventory generator parses new fields
- [ ] Configuration validates correctly
- [ ] Documentation explains all options
- [ ] Common use cases documented

**Test Commands:**

```bash
# Validate configuration schema
uv run ai-how validate config/example-multi-gpu-clusters.yaml

# Generate inventory from configuration
./scripts/generate-ansible-inventory.py \
  --config config/example-multi-gpu-clusters.yaml \
  --output ansible/inventories/test/hosts

# Verify VirtIO-FS mounts passed to inventory
grep -A 10 "virtio_fs_mounts" ansible/inventories/test/hosts
```

**Benefits:**

- ✅ Centralized storage configuration
- ✅ Clear documentation of options
- ✅ Validated configuration schema
- ✅ Examples for common use cases

---

### Task 042: Configuration Template Rendering System

- **ID**: TASK-042
- **Phase**: 4.6 - Configuration Management Enhancement
- **Dependencies**: TASK-041 (Cluster configuration schema)
- **Estimated Time**: 2 hours
- **Difficulty**: Intermediate
- **Status**: ✅ Complete (Implemented 2025-10-23)
- **Priority**: HIGH

**Description:** Implement configuration template rendering system with bash-compatible variable
expansion, enabling dynamic configuration generation with environment variables and project-specific paths.

**Deliverables:**

1. **`ai-how render` Command:**
   - Bash-compatible variable expansion (`$VAR`, `${VAR}`, `${VAR:-default}`)
   - Support for special variables (`$TOT`, `$PWD`, `$HOME`, `$USER`)
   - Template validation without rendering (`--validate-only`)
   - Variable detection and reporting (`--show-variables`)

2. **Makefile Integration:**
   - `make config-render` - Render configuration with variable expansion
   - `make config-validate` - Validate template without rendering
   - Cluster state directory management (`output/cluster-state/`)

3. **Python Dependencies:**
   - Added `expandvars>=1.1.2` for variable expansion
   - `ConfigProcessor` class for template processing
   - Error handling for unbound variables

4. **Configuration Schema Updates:**
   - Added `virtio_fs_mounts` to cluster configuration
   - Variable expansion in configuration paths
   - Template-based configuration generation

**Implementation Details:**

```python
# ai-how render command usage:
ai-how render config/example-multi-gpu-clusters.yaml -o output/cluster-state/rendered-config.yaml --show-variables

# Makefile targets:
make config-render    # Renders template with variable expansion
make config-validate  # Validates template syntax and variables
```

**Configuration Template Example:**

```yaml
# config/example-multi-gpu-clusters.yaml
clusters:
  hpc:
    controller:
      base_image_path: "build/packer/hpc-controller/hpc-controller/hpc-controller.qcow2"
      
      # VirtIO-FS host directory sharing (with variable expansion)
      virtio_fs_mounts:
        - tag: "project-repo"
          host_path: "${TOT}"  # Project root directory
          mount_point: "${TOT}"
          readonly: false
          owner: "admin"
          group: "admin"
          mode: "0755"
          options: "rw,relatime"
        
        - tag: "datasets"
          host_path: "${HOME}"  # User home directory
          mount_point: "${HOME}"
          readonly: true
          owner: "admin"
          group: "admin"
          mode: "0755"
          options: "ro,relatime"
```

**Validation Criteria:**

- [x] `ai-how render` command functional with all variable syntax
- [x] `make config-render` and `make config-validate` targets working
- [x] Variable expansion handles all bash-compatible syntax
- [x] Error handling for unbound variables with helpful messages
- [x] VirtIO-FS mount configuration integrated into schema
- [x] Cluster state directory management implemented

**Test Commands:**

```bash
# Render configuration with variable expansion
make config-render

# Validate template without rendering
make config-validate

# Show variables found in template
ai-how render config/example-multi-gpu-clusters.yaml --show-variables

# Render to specific output location
ai-how render config/example-multi-gpu-clusters.yaml -o custom-config.yaml
```

**Benefits:**

- ✅ **Dynamic Configuration**: Environment-specific configuration generation
- ✅ **Variable Safety**: Clear error messages for missing variables
- ✅ **Template Validation**: Syntax checking without rendering
- ✅ **Integration**: Seamless integration with existing workflow
- ✅ **Flexibility**: Support for complex variable expansion patterns

---

### Task 043: Consolidate BeeGFS and VirtIO-FS Runtime Playbooks

- **ID**: TASK-043
- **Phase**: 4.7 - Storage Runtime Consolidation
- **Dependencies**: TASK-039 (VirtIO-FS integration), TASK-041 (storage schema)
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate
- **Status**: ✅ Complete (2025-10-24)
- **Priority**: HIGH

**Description:** Consolidate BeeGFS and VirtIO-FS runtime configuration into the unified HPC runtime playbook,
eliminating the need for separate storage configuration playbooks and achieving better integration with cluster
configuration.

**Current State:**

- ~~`playbook-beegfs-runtime-config.yml`~~ - **DELETED** (functionality integrated into `playbook-hpc-runtime.yml`)
- ~~`playbook-virtio-fs-runtime-config.yml`~~ - **DELETED** (functionality integrated into `playbook-hpc-runtime.yml`)
- BeeGFS has no cluster configuration schema (all hardcoded or inventory-based)
- VirtIO-FS is integrated but standalone playbook still exists
- Users must run 2-3 playbooks for complete HPC+storage deployment

**Deliverables:**

1. **Integrate BeeGFS into `playbook-hpc-runtime.yml`:**
   - Add BeeGFS deployment play after VirtIO-FS configuration
   - Deploy management/metadata services on controller
   - Deploy storage services on compute nodes
   - Deploy client on all nodes
   - Conditional execution based on `beegfs_enabled` variable

2. **Add BeeGFS to cluster configuration schema (`config/example-multi-gpu-clusters.yaml`):**
   - Add `storage.beegfs` section to cluster config
   - Enable/disable flag
   - Mount point configuration
   - Management server selection
   - Storage node selection
   - Client configuration options

3. **Update inventory generation (`scripts/generate-ansible-inventory.py`):**
   - Parse BeeGFS configuration from cluster config
   - Pass to Ansible inventory as variables
   - Auto-detect which nodes should run BeeGFS services

4. **Delete/deprecate standalone playbooks:**
   - ✅ **Deleted:** `playbook-beegfs-runtime-config.yml` (functionality fully integrated)
   - ✅ **Deleted:** `playbook-virtio-fs-runtime-config.yml` (functionality fully integrated)
   - ✅ **Updated:** Documentation to reflect single playbook workflow

**Cluster Configuration Schema:**

```yaml
# config/example-multi-gpu-clusters.yaml
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
          readonly: false
          owner: "admin"
          group: "admin"
          mode: "0755"
```

**Implementation in playbook-hpc-runtime.yml:**

```yaml
# Add after VirtIO-FS configuration (around line 203):

# Deploy BeeGFS Parallel Filesystem (if enabled)
- name: Deploy BeeGFS Management Service
  hosts: hpc_controllers
  become: true
  gather_facts: true
  vars:
    packer_build: false
    install_only: false
  tasks:
    - name: Check if BeeGFS is enabled
      set_fact:
        beegfs_enabled: "{{ beegfs_enabled | default(false) | bool }}"
      
    - name: Deploy BeeGFS management service
      import_role:
        name: beegfs-mgmt
      when: beegfs_enabled | bool
      tags:
        - beegfs
        - storage

- name: Deploy BeeGFS Metadata Service
  hosts: hpc_controllers
  become: true
  gather_facts: true
  vars:
    packer_build: false
    install_only: false
  tasks:
    - name: Deploy BeeGFS metadata service
      import_role:
        name: beegfs-meta
      when: beegfs_enabled | default(false) | bool
      tags:
        - beegfs
        - storage

- name: Deploy BeeGFS Storage Services
  hosts: compute_nodes
  become: true
  gather_facts: true
  vars:
    packer_build: false
    install_only: false
  tasks:
    - name: Deploy BeeGFS storage service
      import_role:
        name: beegfs-storage
      when: beegfs_enabled | default(false) | bool
      tags:
        - beegfs
        - storage

- name: Deploy BeeGFS Client on All Nodes
  hosts: hpc_controllers,compute_nodes
  become: true
  gather_facts: true
  vars:
    packer_build: false
    install_only: false
  tasks:
    - name: Deploy BeeGFS client
      import_role:
        name: beegfs-client
      when: beegfs_enabled | default(false) | bool
      tags:
        - beegfs
        - storage

- name: Verify BeeGFS Cluster Status
  hosts: hpc_controllers
  become: true
  gather_facts: false
  tasks:
    - name: Check BeeGFS cluster status
      command: beegfs-ctl --listnodes --nodetype=all
      register: beegfs_status
      changed_when: false
      failed_when: false
      when: beegfs_enabled | default(false) | bool
      
    - name: Display BeeGFS status
      debug:
        msg: "BeeGFS cluster deployed with {{ beegfs_status.stdout_lines | length }} nodes"
      when: 
        - beegfs_enabled | default(false) | bool
        - beegfs_status.rc == 0
      tags:
        - beegfs
        - storage
```

**Inventory Generation Update (`scripts/generate-ansible-inventory.py`):**

```python
# Add after VirtIO-FS configuration (around line 97):

# Extract BeeGFS configuration from storage section
if 'storage' in cluster and 'beegfs' in cluster['storage']:
    beegfs_config = cluster['storage']['beegfs']
    if beegfs_config.get('enabled', False):
        # Convert to JSON string for Ansible variable
        beegfs_json = json.dumps(beegfs_config, separators=(',', ':'))
        inventory_lines.append(f"beegfs_config={beegfs_json}")
        inventory_lines.append(f"beegfs_enabled=true")
        print(f"✅ BeeGFS enabled with mount point: {beegfs_config.get('mount_point', '/mnt/beegfs')}", 
              file=sys.stderr)
    else:
        inventory_lines.append(f"beegfs_enabled=false")
        print("ℹ️  BeeGFS disabled in cluster configuration", file=sys.stderr)
else:
    inventory_lines.append(f"beegfs_enabled=false")
    print("ℹ️  No BeeGFS configuration found in cluster", file=sys.stderr)
```

**Validation Criteria:**

- [ ] BeeGFS deploys successfully via `playbook-hpc-runtime.yml`
- [ ] BeeGFS configuration in cluster config schema
- [ ] BeeGFS deployment skipped when `beegfs.enabled: false`
- [ ] All BeeGFS services start correctly
- [ ] BeeGFS filesystem mounted on all nodes
- [ ] Standalone BeeGFS playbook deprecated/deleted
- [ ] Standalone VirtIO-FS playbook deleted
- [ ] Single playbook deploys complete HPC + storage stack
- [ ] Inventory generation passes BeeGFS config correctly
- [ ] Documentation updated with new workflow

**Test Commands:**

```bash
# Deploy complete HPC + Storage stack with single command
ansible-playbook -i inventory playbooks/playbook-hpc-runtime.yml

# Verify BeeGFS deployed
ssh controller "beegfs-ctl --listnodes --nodetype=all"
ssh controller "beegfs-df"
ssh controller "mount | grep beegfs"

# Verify VirtIO-FS mounted
ssh controller "mount | grep virtiofs"

# Test BeeGFS write
ssh controller "echo 'test' > /mnt/beegfs/test.txt"
ssh compute01 "cat /mnt/beegfs/test.txt"

# Validate configuration
uv run ai-how validate config/example-multi-gpu-clusters.yaml
```

**Benefits:**

- ✅ Single playbook for complete HPC + storage deployment
- ✅ Centralized configuration via cluster config file
- ✅ Conditional storage deployment (enable/disable via config)
- ✅ Reduced playbook count (7 → 5 playbooks)
- ✅ Simpler deployment workflow
- ✅ Better integration between HPC and storage layers
- ✅ Consistent configuration management

**Playbook Reduction:**

- **Before:** 7 playbooks (3 HPC + 2 storage + 2 infrastructure)
- **After:** 5 playbooks (3 HPC + 0 storage + 2 infrastructure)
- **Deleted:** `playbook-virtio-fs-runtime-config.yml` (functionality fully integrated)
- **Deleted:** `playbook-beegfs-runtime-config.yml` (functionality fully integrated)
- **Reduction:** 64% from original 14 playbooks

**Implementation Notes (2025-10-24):**

✅ **Completed Implementation:**

1. Added BeeGFS deployment plays to `playbook-hpc-runtime.yml`:
   - Management service on controller
   - Metadata service on controller
   - Storage services on compute nodes
   - Client mounts on all nodes
   - Verification and testing tasks

2. Deleted `playbook-virtio-fs-runtime-config.yml` (functionality already integrated in Task 039)

3. Deleted `playbook-beegfs-runtime-config.yml` (functionality fully integrated into runtime playbook)

4. Verified integration:
   - Configuration rendering works with template variables
   - Inventory generation passes BeeGFS config correctly
   - Playbook syntax validated (no linter errors)
   - Test script created and validates successfully

**Achievements:**

- ✅ Single playbook deployment for HPC + Storage
- ✅ 64% playbook reduction from original 14 playbooks (now 5)
- ✅ Complete elimination of standalone storage playbooks
- ✅ Centralized configuration via cluster config file
- ✅ Conditional storage deployment (enable/disable via config)
- ✅ Better integration between HPC and storage layers

**Test Script:** `/tmp/test-task-043-deployment.sh`

---

## Phase 4.8: Ansible Role Consolidation (Tasks 044-048, 046.1)

### Task 044: Create BeeGFS Common Role for Shared Functionality

- **ID**: TASK-044
- **Phase**: 4.8 - Ansible Role Consolidation
- **Dependencies**: None
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate-Advanced
- **Status**: ✅ Complete (Implemented 2025-10-27)
- **Priority**: HIGH

**Description:** Create a shared `beegfs-common` role to consolidate duplicate installation logic, configuration
patterns, and package management across the four BeeGFS roles (mgmt, meta, storage, client).

**Problem Statement:**

All four BeeGFS roles contain nearly identical code for:

- Package checking and installation (200-400 lines per role)
- Remote vs controller package copying logic
- Directory creation and permissions
- Service management patterns
- Configuration file templating
- Error handling

**Current Duplication:**

```yaml
# ansible/roles/beegfs-{mgmt,meta,storage,client}/tasks/install.yml
# Each role has 200-400 lines of similar code:

- name: Check if packages exist on remote
  ansible.builtin.stat:
    path: "{{ beegfs_packages_path }}/..."
  # ... (repeated in all 4 roles)

- name: Check if packages exist on controller
  ansible.builtin.find:
    paths: "{{ beegfs_packages_source_dir }}"
  # ... (repeated in all 4 roles)

- name: Copy packages from controller
  ansible.builtin.copy:
    src: "{{ beegfs_packages_source_dir }}/"
  # ... (repeated in all 4 roles)
```

**Deliverables:**

1. **Create `ansible/roles/beegfs-common/` role:**
   - `tasks/main.yml` - Entry point with conditional imports
   - `tasks/install-packages.yml` - Parameterized package installation
   - `tasks/configure-service.yml` - Generic service configuration
   - `tasks/verify-installation.yml` - Generic verification tasks
   - `defaults/main.yml` - Common default variables
   - `handlers/main.yml` - Shared service handlers

2. **Parameterized Installation Task (`tasks/install-packages.yml`):**

```yaml
---
# BeeGFS Common Package Installation
# Parameterized installation logic used by all BeeGFS roles
#
# Required variables:
#   - beegfs_service_type: mgmt|meta|storage|client
#   - beegfs_required_packages: list of .deb package names

- name: Check if BeeGFS {{ beegfs_service_type }} is already installed
  ansible.builtin.stat:
    path: "{{ beegfs_binary_paths[beegfs_service_type] }}"
  register: beegfs_installed

- name: Check if packages exist on remote (Packer builds)
  ansible.builtin.find:
    paths: "{{ beegfs_packages_path }}"
    patterns: "{{ beegfs_required_packages }}"
  register: remote_packages
  when: not beegfs_installed.stat.exists

- name: Check if packages exist on Ansible controller (runtime)
  ansible.builtin.find:
    paths: "{{ beegfs_packages_source_dir }}"
    patterns: "{{ beegfs_required_packages }}"
  delegate_to: localhost
  become: false
  register: controller_packages
  when:
    - not beegfs_installed.stat.exists
    - remote_packages.matched | default(0) == 0

- name: Copy packages from controller to remote
  ansible.builtin.copy:
    src: "{{ beegfs_packages_source_dir }}/"
    dest: "{{ beegfs_packages_path }}/"
    mode: '0644'
  when:
    - not beegfs_installed.stat.exists
    - remote_packages.matched | default(0) == 0
    - controller_packages.matched | default(0) > 0

- name: Install dependencies
  ansible.builtin.apt:
    name: "{{ beegfs_dependencies }}"
    state: present
    update_cache: true
  when: not beegfs_installed.stat.exists

- name: Find package files on remote
  ansible.builtin.find:
    paths: "{{ beegfs_packages_path }}"
    patterns: "{{ beegfs_required_packages }}"
  register: package_files
  when: not beegfs_installed.stat.exists

- name: Install BeeGFS {{ beegfs_service_type }} packages
  ansible.builtin.apt:
    deb: "{{ item.path }}"
    state: present
  loop: "{{ package_files.files }}"
  when:
    - not beegfs_installed.stat.exists
    - package_files.matched | default(0) > 0

- name: Fail if packages not found
  ansible.builtin.fail:
    msg: >-
      BeeGFS {{ beegfs_service_type }} packages not found.
      Expected: {{ beegfs_required_packages | join(', ') }}
      For Packer: Copy to {{ beegfs_packages_path }}
      For runtime: Build with 'make run-docker COMMAND="cmake --build build --target build-beegfs-packages"'
  when:
    - not beegfs_installed.stat.exists
    - package_files.matched | default(0) == 0
```

1. **Update each BeeGFS role to use common role:**

```yaml
# ansible/roles/beegfs-mgmt/tasks/install.yml (simplified)
---
- name: Install BeeGFS management packages
  import_role:
    name: beegfs-common
    tasks_from: install-packages
  vars:
    beegfs_service_type: "mgmt"
    beegfs_required_packages:
      - "beegfs-mgmtd_{{ beegfs_version }}_*.deb"
      - "beegfs-utils_{{ beegfs_version }}_*.deb"
    beegfs_binary_paths:
      mgmt: "/usr/sbin/beegfs-mgmtd"
    beegfs_dependencies:
      - libssl3
      - libattr1
```

1. **Shared configuration templates in `beegfs-common/templates/`:**
   - Base systemd service template
   - Common configuration snippets
   - Shared environment files

2. **Shared handlers in `beegfs-common/handlers/main.yml`:**

```yaml
---
- name: restart beegfs-mgmtd
  systemd:
    name: beegfs-mgmtd
    state: restarted
    daemon_reload: true
  when: not (packer_build | default(false))

- name: restart beegfs-meta
  systemd:
    name: beegfs-meta
    state: restarted
    daemon_reload: true
  when: not (packer_build | default(false))

# ... etc for storage and client
```

**Validation Criteria:**

- [ ] `beegfs-common` role created with modular tasks
- [ ] All four BeeGFS roles updated to use common role
- [ ] Packer builds complete successfully with new structure
- [ ] Runtime deployments work correctly
- [ ] No duplicate code in BeeGFS roles
- [ ] Installation time unchanged or improved
- [ ] All BeeGFS services start correctly

**Benefits:**

- ✅ Eliminate 600-1200 lines of duplicate code
- ✅ Single source of truth for package installation
- ✅ Easier maintenance and bug fixes
- ✅ Consistent error handling across all roles
- ✅ Reduced testing surface area

**Test Commands:**

```bash
# Test Packer builds with new structure
packer build packer/hpc-controller/hpc-controller.pkr.hcl
packer build packer/hpc-compute/hpc-compute.pkr.hcl

# Test runtime deployment
ansible-playbook playbooks/playbook-hpc-runtime.yml

# Verify BeeGFS services
ssh controller "beegfs-ctl --listnodes --nodetype=all"
ssh controller "beegfs-df"
```

---

### Task 045: Create SLURM Common Role for Shared Functionality

- **ID**: TASK-045
- **Phase**: 4.8 - Ansible Role Consolidation
- **Dependencies**: None
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate
- **Status**: ✅ Complete (Implemented 2025-10-27)
- **Priority**: MEDIUM

**Description:** Create a shared `slurm-common` role to consolidate duplicate MUNGE setup, systemd service
management, and configuration validation across SLURM controller and compute roles.

**Problem Statement:**

Both `slurm-controller` and `slurm-compute` roles contain duplicate code for:

- MUNGE key installation and service management
- SLURM user/group creation
- systemd service configuration patterns
- Configuration file validation
- Directory creation with proper permissions

**Deliverables:**

1. **Create `ansible/roles/slurm-common/` role:**
   - `tasks/main.yml` - Entry point
   - `tasks/setup-munge.yml` - Shared MUNGE configuration
   - `tasks/create-slurm-user.yml` - User/group creation
   - `tasks/setup-directories.yml` - Directory structure creation
   - `tasks/validate-config.yml` - Configuration validation
   - `defaults/main.yml` - Common SLURM variables
   - `handlers/main.yml` - Shared handlers

2. **Shared MUNGE Setup (`tasks/setup-munge.yml`):**

```yaml
---
# SLURM Common - MUNGE Setup
# Used by both controller and compute roles

- name: Create MUNGE group
  ansible.builtin.group:
    name: munge
    state: present
    system: true

- name: Create MUNGE user
  ansible.builtin.user:
    name: munge
    group: munge
    system: true
    shell: /usr/sbin/nologin
    home: /var/lib/munge
    create_home: false

- name: Ensure MUNGE directories exist
  ansible.builtin.file:
    path: "{{ item.path }}"
    state: directory
    owner: "{{ item.owner }}"
    group: "{{ item.group }}"
    mode: "{{ item.mode }}"
  loop:
    - {path: "/etc/munge", owner: "munge", group: "munge", mode: "0700"}
    - {path: "/var/lib/munge", owner: "munge", group: "munge", mode: "0711"}
    - {path: "/var/log/munge", owner: "munge", group: "munge", mode: "0700"}
    - {path: "/run/munge", owner: "munge", group: "munge", mode: "0755"}

- name: Install MUNGE key
  ansible.builtin.copy:
    src: "{{ munge_key_source }}"
    dest: /etc/munge/munge.key
    owner: munge
    group: munge
    mode: '0400'
  notify: restart munge

- name: Enable and start MUNGE service
  ansible.builtin.systemd:
    name: munge
    enabled: true
    state: started
```

1. **Update SLURM roles to use common role:**

```yaml
# ansible/roles/slurm-controller/tasks/configure.yml
---
- name: Setup MUNGE for SLURM
  import_role:
    name: slurm-common
    tasks_from: setup-munge
  vars:
    munge_key_source: "{{ slurm_munge_key_path }}"

- name: Setup SLURM directories
  import_role:
    name: slurm-common
    tasks_from: setup-directories
  vars:
    slurm_node_type: controller
```

**Validation Criteria:**

- [ ] `slurm-common` role created with modular tasks
- [ ] Both SLURM roles updated to use common role
- [ ] MUNGE setup identical across controller and compute
- [ ] No duplicate code in SLURM roles
- [ ] All SLURM services start correctly
- [ ] MUNGE authentication works across cluster

**Benefits:**

- ✅ Eliminate 200-300 lines of duplicate code
- ✅ Consistent MUNGE configuration
- ✅ Easier troubleshooting
- ✅ Single source for common patterns

---

### Task 046: Create Shared Package Management Role

- **ID**: TASK-046
- **Phase**: 4.8 - Ansible Role Consolidation
- **Dependencies**: TASK-044, TASK-045
- **Estimated Time**: 2 hours
- **Difficulty**: Intermediate
- **Status**: ✅ Complete (Implemented 2025-10-27)
- **Priority**: MEDIUM

**Description:** Create a generic `package-manager` role with reusable package checking, copying, and
installation logic that can be used across BeeGFS, SLURM, and other components.

**Problem Statement:**

The package installation pattern is repeated across multiple roles:

1. Check if already installed
2. Check packages on remote host (Packer mode)
3. Check packages on Ansible controller (runtime mode)
4. Copy packages if needed
5. Install from local packages
6. Fail with helpful message if not found

**Deliverables:**

1. **Create `ansible/roles/package-manager/` role:**
   - `tasks/main.yml` - Generic package installation
   - `tasks/check-installation.yml` - Binary existence check
   - `tasks/copy-packages.yml` - Copy from controller
   - `tasks/install-packages.yml` - Install from local path

2. **Generic Package Installation Task:**

```yaml
---
# Generic Package Manager
# Reusable package installation logic
#
# Required variables:
#   - package_name: human-readable name (e.g., "BeeGFS Management")
#   - package_binary_path: path to check (e.g., /usr/sbin/beegfs-mgmtd)
#   - package_files: list of .deb filenames
#   - package_remote_path: /tmp/xxx-packages/
#   - package_source_dir: build/packages/xxx/
#   - package_dependencies: list of apt packages

- name: Check if {{ package_name }} is already installed
  ansible.builtin.stat:
    path: "{{ package_binary_path }}"
  register: package_installed

- name: Include package copy tasks
  include_tasks: copy-packages.yml
  when: not package_installed.stat.exists

- name: Include package installation tasks
  include_tasks: install-packages.yml
  when: not package_installed.stat.exists
```

1. **Usage in BeeGFS role:**

```yaml
# ansible/roles/beegfs-mgmt/tasks/install.yml
---
- name: Install BeeGFS management packages
  import_role:
    name: package-manager
  vars:
    package_name: "BeeGFS Management"
    package_binary_path: "/usr/sbin/beegfs-mgmtd"
    package_files:
      - "beegfs-mgmtd_{{ beegfs_version }}_*.deb"
      - "beegfs-utils_{{ beegfs_version }}_*.deb"
    package_remote_path: "/tmp/beegfs-packages"
    package_source_dir: "build/packages/beegfs"
    package_dependencies:
      - libssl3
      - libattr1
```

**Benefits:**

- ✅ Ultra-DRY package management
- ✅ Consistent error messages
- ✅ Reusable across all components
- ✅ Centralized bug fixes

---

### Task 046.1: Integrate Package Manager into Existing Roles

- **ID**: TASK-046.1
- **Phase**: 4.8 - Ansible Role Consolidation
- **Dependencies**: TASK-046 (package-manager role created)
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate-Advanced
- **Status**: ✅ Complete (Implemented 2025-10-27)
- **Priority**: MEDIUM

**Description:** Refactor BeeGFS and SLURM roles to use the new `package-manager` role, replacing duplicate
package installation logic with the unified approach.

**Problem Statement:**

The package-manager role exists but is not yet used. We need to:

1. Refactor BeeGFS roles (mgmt, meta, storage, client) to use package-manager
2. Refactor SLURM roles (controller, compute) to use package-manager
3. Replace 800-1200 lines of duplicate code with role imports

**Deliverables:**

1. **Refactor BeeGFS Roles:**

**File:** `ansible/roles/beegfs-mgmt/tasks/install.yml`

```yaml
---
# BeeGFS Management Service - Installation Tasks
# Now uses package-manager role for all package operations

- name: Install BeeGFS management packages via package-manager
  ansible.builtin.import_role:
    name: package-manager
  vars:
    package_name: "BeeGFS Management"
    package_binary_path: "/usr/bin/beegfs-mgmtd"
    package_files:
      - "beegfs-mgmtd_{{ beegfs_version }}_*.deb"
      - "beegfs-utils_{{ beegfs_version }}_*.deb"
    package_remote_path: "/tmp/beegfs-packages"
    package_source_dir: "{{ playbook_dir }}/../../build/packages/beegfs"
    package_dependencies:
      - libssl3
      - libattr1
    component_tag: "beegfs-mgmt"
  tags:
    - beegfs
    - beegfs-mgmt
    - install

# ... rest of role-specific tasks (service configuration, directories)
```

**Repeat for:** beegfs-meta, beegfs-storage, beegfs-client

1. **Refactor SLURM Roles:**

**File:** `ansible/roles/slurm-controller/tasks/install.yml`

```yaml
---
# SLURM Controller Package Installation
# Now uses package-manager role

- name: Install SLURM controller packages via package-manager
  ansible.builtin.import_role:
    name: package-manager
  vars:
    package_name: "SLURM Controller"
    package_binary_path: "/usr/sbin/slurmctld"
    package_files:
      - "slurm-wlm_{{ slurm_version }}_*.deb"
      - "slurm-wlm-basic-plugins_{{ slurm_version }}_*.deb"
      - "slurmctld_{{ slurm_version }}_*.deb"
      - "slurmdbd_{{ slurm_version }}_*.deb"
    package_remote_path: "/tmp/slurm-packages"
    package_source_dir: "{{ playbook_dir }}/../../build/packages/slurm"
    package_dependencies:
      - libmunge2
      - munge
      - libmariadb3
      - mariadb-client
      - libpmix2
    component_tag: "slurm-controller"
    use_dpkg_install: true  # Better dependency resolution
  tags:
    - slurm
    - slurm-controller
    - install

# ... rest of role-specific tasks
```

**Repeat for:** slurm-compute

1. **Validation Steps:**

After refactoring each role:

```bash
# Test role validation
cd ansible
make validate-role ROLE=beegfs-mgmt
make validate-role ROLE=slurm-controller

# Test Packer builds
make run-docker COMMAND="cmake --build build --target build-hpc-controller-image"
make run-docker COMMAND="cmake --build build --target build-hpc-compute-image"

# Test runtime deployment
ansible-playbook -i inventories/test playbooks/playbook-hpc-runtime.yml
```

**Validation Criteria:**

- [ ] All BeeGFS roles refactored to use package-manager
- [ ] Both SLURM roles refactored to use package-manager
- [ ] 800-1200 lines of duplicate code eliminated
- [ ] All role validations pass
- [ ] Packer builds complete successfully
- [ ] Runtime deployments work correctly
- [ ] Installation behavior unchanged
- [ ] Error messages still informative

**Benefits:**

- ✅ **Massive code reduction** - 800-1200 lines eliminated
- ✅ **Single source of truth** for all package installation
- ✅ **Consistent behavior** across all components
- ✅ **Easier maintenance** - fix bugs in one place
- ✅ **Proven pattern** - tested in package-manager role

**Deployment Impact:**

⚠️ **Requires Packer image rebuild** after integration

```bash
# Must rebuild after refactoring install tasks
make run-docker COMMAND="cmake --build build --target build-hpc-controller-image"
make run-docker COMMAND="cmake --build build --target build-hpc-compute-image"
```

---

### Task 047: Consolidate Base Package Roles

- **ID**: TASK-047
- **Phase**: 4.8 - Ansible Role Consolidation
- **Dependencies**: None
- **Estimated Time**: 1.5 hours
- **Difficulty**: Junior-Intermediate
- **Status**: ❌ PENDING
- **Priority**: LOW

**Description:** Merge `hpc-base-packages` and `cloud-base-packages` roles into a single `base-packages`
role with variables to control HPC vs Cloud package selection.

**Problem Statement:**

Two separate roles with 80% identical package lists:

- `hpc-base-packages` - 30 packages
- `cloud-base-packages` - 25 packages
- 20 packages are identical between both

**Deliverables:**

1. **Create `ansible/roles/base-packages/` role:**
   - Merge both roles into one
   - Add `package_profile` variable: `hpc`, `cloud`, `minimal`
   - Conditional package installation based on profile

2. **Implementation:**

```yaml
# ansible/roles/base-packages/defaults/main.yml
---
# Base package profiles
package_profile: "hpc"  # Options: hpc, cloud, minimal

# Common packages (all profiles)
base_packages_common:
  - build-essential
  - git
  - wget
  - curl
  # ... (20 shared packages)

# HPC-specific packages
base_packages_hpc:
  - libhwloc-dev
  - libpmix-dev
  - libevent-dev
  # ... (10 HPC packages)

# Cloud-specific packages
base_packages_cloud:
  - cloud-init
  - qemu-guest-agent
  # ... (5 cloud packages)

# Combined package list
base_packages: >-
  {{ base_packages_common +
     (base_packages_hpc if package_profile == 'hpc' else []) +
     (base_packages_cloud if package_profile == 'cloud' else []) }}
```

1. **Update playbooks:**

```yaml
# playbook-hpc-packer-controller.yml
roles:
  - role: base-packages
    vars:
      package_profile: "hpc"

# playbook-cloud.yml
roles:
  - role: base-packages
    vars:
      package_profile: "cloud"
```

**Benefits:**

- ✅ Single role instead of two
- ✅ Easier to maintain shared packages
- ✅ Clear separation of concerns
- ✅ Flexible package selection

---

### Task 048: Create Shared Utilities Role

- **ID**: TASK-048
- **Phase**: 4.8 - Ansible Role Consolidation
- **Dependencies**: None
- **Estimated Time**: 2 hours
- **Difficulty**: Intermediate
- **Status**: ❌ PENDING
- **Priority**: LOW

**Description:** Create a `shared-utilities` role with common validation tasks, health checks, and
service management patterns used across multiple roles.

**Problem Statement:**

Many roles repeat the same patterns for:

- Service health checks
- Configuration validation
- Directory creation
- Permission management
- Log file rotation

**Deliverables:**

1. **Create `ansible/roles/shared-utilities/` role:**
   - `tasks/validate-service.yml` - Generic service health check
   - `tasks/check-ports.yml` - Port availability checking
   - `tasks/setup-logging.yml` - Log directory and rotation
   - `tasks/verify-connectivity.yml` - Network connectivity tests

2. **Generic Service Health Check:**

```yaml
---
# Shared Utilities - Service Health Check
# Required variables:
#   - service_name: systemd service name
#   - service_port: optional port to check
#   - service_check_command: optional command to run

- name: Check if {{ service_name }} is running
  ansible.builtin.systemd:
    name: "{{ service_name }}"
    state: started
  register: service_status
  failed_when: false

- name: Verify {{ service_name }} is active
  ansible.builtin.command: "systemctl is-active {{ service_name }}"
  register: service_active
  changed_when: false
  failed_when: service_active.rc != 0

- name: Check {{ service_name }} port
  ansible.builtin.wait_for:
    port: "{{ service_port }}"
    timeout: 30
  when: service_port is defined

- name: Run service health check
  ansible.builtin.command: "{{ service_check_command }}"
  register: health_check
  changed_when: false
  when: service_check_command is defined
```

**Benefits:**

- ✅ Consistent validation patterns
- ✅ Reusable health checks
- ✅ Standardized troubleshooting

---

## Current Outcomes (As of 2025-10-23 - Status Updated with Template Rendering)

**✅ Phase 4 Core Consolidation Complete (Tasks 029-034.1):**

- **Playbook Consolidation Achieved:**
  - ✅ `playbook-hpc-packer-controller.yml` - EXISTS and functional
  - ✅ `playbook-hpc-packer-compute.yml` - EXISTS and functional
  - ✅ `playbook-hpc-runtime.yml` - EXISTS and functional
  - ✅ 9 obsolete playbooks deleted (verified absent from codebase)
  - ✅ **Current state: 8 playbooks (down from 14 - 43% reduction)**
  - ✅ **Target: 7 playbooks** (Task 038 complete - BeeGFS consolidation achieved)

- **Packer Infrastructure:**
  - ✅ Both controller and compute Packer builds functional (verification needed)
  - ✅ Templates updated to reference new playbooks (verification needed)
  - ✅ BeeGFS Packer installation consolidated into HPC playbooks (Task 038 complete)

- **Technical Improvements:**
  - ✅ SLURM installation using pre-built packages (Task 034.1 - verified in install.yml)
  - ✅ All roles support modular task execution (verified)
  - ✅ Pre-built package pattern consistent across SLURM roles

**📋 Remaining Work:**

**Phase 4 - Test Framework Consolidation (Tasks 035-037): ⚠️ NOT STARTED**

- ❌ **PENDING**: test-hpc-runtime-framework.sh NOT created (Task 035)
- ❌ **PENDING**: test-hpc-packer-*-framework.sh NOT created (Task 036)
- ❌ **PENDING**: 11 old frameworks still exist - need consolidation (Task 037)
- ❌ **PENDING**: 10+ old test configs still exist - need removal (Task 037)
- ❌ **PENDING**: Test Makefile NOT updated with new targets (Task 037)
- **Status:** All 15 old test frameworks verified in codebase - NO consolidation done yet

**Phase 4.5 - Storage Enhancement (Tasks 038-041): ✅ MOSTLY COMPLETE**

- ✅ **COMPLETE**: BeeGFS Packer installation consolidated into HPC playbooks (Task 038)
- ✅ **COMPLETE**: VirtIO-FS integrated into playbook-hpc-runtime.yml (Task 039)
- ❌ **PENDING**: Registry uses /opt/containers not /mnt/beegfs (Task 040)
- ✅ **COMPLETE**: virtio_fs_mounts added to cluster config schema (Task 041)
- **Status:** 3/4 storage tasks complete - BeeGFS consolidation, VirtIO-FS integration, and storage schema achieved

**Phase 4.6 - Configuration Management (Task 042): ✅ COMPLETE**

- ✅ **COMPLETE**: Configuration template rendering system implemented (Task 042)
- **Status:** Template rendering with bash-compatible variable expansion fully operational

**Phase 4.7 - Storage Runtime Consolidation (Task 043): 📋 PLANNED**

- 📋 **PLANNED**: BeeGFS & VirtIO-FS runtime playbook consolidation (Task 043)
- **Status:** Implementation plan complete, ready for development
- **Validation:** Step 7 added to phase-4-validation framework

**Infrastructure Status:**

- ✅ All roles support modular task execution
- ✅ Roles support `packer_build` variable
- ✅ Inventory variables documented
- ✅ SLURM uses pre-built packages (no Debian repo dependency)
- ✅ Rollback procedures in place (backups created)

---

## Migration Guide

### For Configuration Users

**Configuration File Changes:**

```bash
# OLD: Template configuration file
config/template-cluster.yaml

# NEW: Example multi-GPU cluster configuration
config/example-multi-gpu-clusters.yaml

# Migration command:
cp config/example-multi-gpu-clusters.yaml config/cluster.yaml
```

**Key Differences:**

- **Better naming**: `example-multi-gpu-clusters.yaml` clearly indicates it's an example of a multi-GPU setup
- **Same functionality**: All features preserved, just renamed for clarity
- **Better documentation**: Updated README and comments reflect the example nature

### For Playbook Users

**Old → New Mapping:**

```bash
# Packer builds
playbook-hpc-controller.yml → playbook-hpc-packer-controller.yml
playbook-hpc-compute.yml → playbook-hpc-packer-compute.yml

# Runtime configuration (ALL → unified playbook)
playbook-slurm-compute-runtime-config.yml → playbook-hpc-runtime.yml
playbook-cgroup-runtime-config.yml → playbook-hpc-runtime.yml
playbook-gres-runtime-config.yml → playbook-hpc-runtime.yml
playbook-job-scripts-runtime-config.yml → playbook-hpc-runtime.yml
playbook-dcgm-runtime-config.yml → playbook-hpc-runtime.yml
playbook-container-validation-runtime-config.yml → playbook-hpc-runtime.yml
```

**Example Commands:**

```bash
# OLD: Runtime configuration with multiple playbooks
ansible-playbook playbooks/playbook-slurm-compute-runtime-config.yml
ansible-playbook playbooks/playbook-cgroup-runtime-config.yml
ansible-playbook playbooks/playbook-gres-runtime-config.yml
# ... etc

# NEW: Single unified runtime playbook
ansible-playbook playbooks/playbook-hpc-runtime.yml

# Configuration file example:
# cp config/example-multi-gpu-clusters.yaml config/cluster.yaml
```

### For Test Users

**Old → New Mapping:**

```bash
# Runtime tests (ALL → unified framework)
make test-slurm-compute → make test-hpc-runtime
make test-cgroup-isolation → make test-hpc-runtime
make test-gpu-gres → make test-hpc-runtime
make test-job-scripts → make test-hpc-runtime
make test-dcgm-monitoring → make test-hpc-runtime
make test-container-integration → make test-hpc-runtime

# Packer tests (consolidated)
make test-slurm-controller → make test-hpc-packer-controller
make test-monitoring-stack → make test-hpc-packer-controller
make test-container-runtime → make test-hpc-packer-compute
```

---

## Next Phase

→ **TODO**: Create Phase 5: Enhanced Monitoring & Observability - Monitoring and observability phase

→ [Phase 6: Final Validation & Production Readiness](phase-6-validation.md) (if exists)

---

## Related Documentation

- [Reference: Testing Framework Patterns](../reference/testing-framework.md)
- [Reference: Infrastructure Summary](../reference/infrastructure-summary.md)
- **TODO**: Create Reference: Ansible Role Architecture - Ansible role architecture reference
- **TODO**: Create Guide: HPC Cluster Deployment - HPC cluster deployment guide

---

## Rollback Procedures

If consolidation causes issues:

1. **Playbooks:**
   - Restore from `backup/playbooks-YYYYMMDD/`
   - Revert Packer template changes
   - Continue using old playbooks

2. **Tests:**
   - Restore from `backup/tests-YYYYMMDD/`
   - Revert Makefile changes
   - Continue using old test frameworks

3. **Complete Rollback:**

```bash
# Restore playbooks
cp backup/playbooks-YYYYMMDD/* ansible/playbooks/

# Restore tests
cp backup/tests-YYYYMMDD/*.sh tests/
cp backup/tests-YYYYMMDD/test-infra/configs/*.yaml tests/test-infra/configs/

# Restore Makefile
git checkout tests/Makefile

# Verify restoration
make test-slurm-controller
```

---

## 🚧 **Current Status & Next Steps**

### **Phase 4 Core Consolidation: ✅ COMPLETE**

**Achievements:**

- ✅ Tasks 029-034.1 completed (7 tasks)
- ✅ Playbook count reduced from 14 → 8 (43% reduction)
- ✅ 9 obsolete playbooks deleted
- ✅ SLURM installation fixed with pre-built packages
- ✅ Packer builds validated and working
- ✅ Runtime playbook created and deployed

**Next Priorities:**

1. **Phase 4.5 - Storage Enhancement** (Tasks 038-041)
   - BeeGFS Packer consolidation (final playbook reduction)
   - VirtIO-FS runtime integration
   - Container registry on BeeGFS
   - Cluster configuration schema updates

2. **Phase 4 - Test Consolidation** (Tasks 035-037)
   - Unified HPC runtime test framework
   - HPC Packer test frameworks
   - Test Makefile cleanup

**Estimated Time:**

- Phase 4.5: 5-6 hours total
- Phase 4 tests: 8-10 hours total

---

## 📋 **Detailed Next Steps & Subtasks**

### **Phase 4A: Complete Runtime Validation (Tasks 031, 033)**

#### **Subtask 4A.1: Fix Container.conf Syntax Errors**

- **Priority**: HIGH
- **Estimated Time**: 1 hour
- **Status**: Pending
- **Dependencies**: Current cluster deployment

**Actions:**

1. **Locate container.conf template** in slurm-compute role
2. **Fix SPANK plugin syntax** - convert INI format to proper SPANK format
3. **Test job execution** without container.conf warnings
4. **Verify GPU jobs work** with fixed configuration

**Files to Update:**

- `ansible/roles/slurm-compute/templates/container.conf.j2`
- `ansible/roles/slurm-controller/templates/container.conf.j2` (if exists)

**Validation:**

```bash
# Test job execution without warnings
ssh controller "srun -N1 hostname"
ssh controller "srun -N1 -p gpu nvidia-smi"
```

#### **Subtask 4A.2: Complete Job Execution Testing**

- **Priority**: HIGH
- **Estimated Time**: 30 minutes
- **Status**: In Progress
- **Dependencies**: 4A.1

**Actions:**

1. **Test basic job execution** across all nodes
2. **Test GPU job execution** on GPU nodes
3. **Test multi-node jobs** with proper resource allocation
4. **Verify cgroup isolation** is working
5. **Test container runtime** integration

**Test Commands:**

```bash
# Basic functionality
ssh controller "srun -N2 hostname"
ssh controller "srun -N1 -c 4 sleep 10"

# GPU functionality
ssh controller "srun -N1 -p gpu nvidia-smi"
ssh controller "srun -N1 --gres=gpu:1 nvidia-smi"

# Resource isolation
ssh controller "srun -N1 -c 2 --mem=1G sleep 30"
```

#### **Subtask 4A.3: Run Complete Validation Script**

- **Priority**: HIGH
- **Estimated Time**: 1 hour
- **Status**: Pending
- **Dependencies**: 4A.1, 4A.2

**Actions:**

1. **Run phase-4 validation** with all fixes applied
2. **Verify all validation steps pass** (Steps 0-5)
3. **Document any remaining issues** for resolution
4. **Confirm cluster is fully operational**

**Validation Commands:**

```bash
# Run complete validation
./tests/phase-4-validation/step-03-runtime-deployment.sh \
  --validation-folder validation-output/phase-4-validation-$(date +%Y%m%d-%H%M%S)/ \
  --log-level DEBUG

# Verify all steps completed successfully
grep -E "✅|PASSED" validation-output/phase-4-validation-*/03-runtime-playbook/validation-summary.txt
```

### **Phase 4B: Playbook Consolidation (Task 034)**

#### **Subtask 4B.1: Create Backup of Existing Playbooks**

- **Priority**: HIGH
- **Estimated Time**: 15 minutes
- **Status**: Pending
- **Dependencies**: 4A.3 (validation must pass)

**Actions:**

1. **Create backup directory** with timestamp
2. **Copy all 9 obsolete playbooks** to backup
3. **Verify backup integrity** before proceeding
4. **Document backup location** for rollback

**Commands:**

```bash
# Create backup
mkdir -p backup/playbooks-$(date +%Y%m%d-%H%M%S)
cp ansible/playbooks/playbook-hpc.yml \
   ansible/playbooks/playbook-slurm-compute-runtime-config.yml \
   ansible/playbooks/playbook-cgroup-runtime-config.yml \
   ansible/playbooks/playbook-gres-runtime-config.yml \
   ansible/playbooks/playbook-job-scripts-runtime-config.yml \
   ansible/playbooks/playbook-dcgm-runtime-config.yml \
   ansible/playbooks/playbook-container-validation-runtime-config.yml \
   ansible/playbooks/playbook-hpc-controller.yml \
   ansible/playbooks/playbook-hpc-compute.yml \
   backup/playbooks-$(date +%Y%m%d-%H%M%S)/

# Verify backup
ls -la backup/playbooks-$(date +%Y%m%d-%H%M%S)/
```

#### **Subtask 4B.2: Delete Obsolete Playbooks**

- **Priority**: MEDIUM
- **Estimated Time**: 15 minutes
- **Status**: Pending
- **Dependencies**: 4B.1

**Actions:**

1. **Delete 9 obsolete playbooks** as documented
2. **Verify exactly 7 playbooks remain** (3 new + 2 storage + 2 infrastructure)
3. **Check for broken references** in codebase
4. **Update documentation** to reflect new structure

**Commands:**

```bash
# Delete obsolete playbooks
cd ansible/playbooks
rm -f playbook-hpc.yml
rm -f playbook-slurm-compute-runtime-config.yml
rm -f playbook-cgroup-runtime-config.yml
rm -f playbook-gres-runtime-config.yml
rm -f playbook-job-scripts-runtime-config.yml
rm -f playbook-dcgm-runtime-config.yml
rm -f playbook-container-validation-runtime-config.yml
rm -f playbook-hpc-controller.yml
rm -f playbook-hpc-compute.yml

# Verify remaining playbooks (should be 7)
ls -1 playbook-*.yml | wc -l
ls -1 playbook-*.yml
```

#### **Subtask 4B.3: Update Documentation**

- **Priority**: MEDIUM
- **Estimated Time**: 30 minutes
- **Status**: Pending
- **Dependencies**: 4B.2

**Actions:**

1. **Update ansible/README.md** with new 3-playbook structure
2. **Update ansible/README-packer-ansible.md** with new playbook names
3. **Create migration guide** for users of old playbooks
4. **Update any references** in other documentation

**Files to Update:**

- `ansible/README.md`
- `ansible/README-packer-ansible.md`
- `docs/guides/hpc-deployment.md` (if exists)
- Create: `docs/migration/playbook-consolidation.md`

### **Phase 4C: Test Framework Consolidation (Tasks 035-037)**

#### **Subtask 4C.1: Create Unified HPC Runtime Test Framework**

- **Priority**: HIGH
- **Estimated Time**: 2 hours
- **Status**: Pending
- **Dependencies**: 4A.3 (validation complete)

**Actions:**

1. **Create test-hpc-runtime-framework.sh** with standard CLI
2. **Create test-hpc-runtime.yaml** configuration
3. **Implement all 6 test suites** orchestration
4. **Add GPU conditional logic** for GPU tests
5. **Test framework functionality** end-to-end

**Files to Create:**

- `tests/test-hpc-runtime-framework.sh`
- `tests/test-infra/configs/test-hpc-runtime.yaml`

**Test Commands:**

```bash
# Test new framework
cd tests
./test-hpc-runtime-framework.sh e2e
./test-hpc-runtime-framework.sh start-cluster
./test-hpc-runtime-framework.sh deploy-ansible
./test-hpc-runtime-framework.sh run-tests
./test-hpc-runtime-framework.sh stop-cluster
```

#### **Subtask 4C.2: Create HPC Packer Test Frameworks**

- **Priority**: MEDIUM
- **Estimated Time**: 1.5 hours
- **Status**: Pending
- **Dependencies**: 4C.1

**Actions:**

1. **Create test-hpc-packer-controller-framework.sh**
2. **Create test-hpc-packer-compute-framework.sh**
3. **Create corresponding YAML configurations**
4. **Test both frameworks** with Packer builds
5. **Verify all test suites execute** correctly

**Files to Create:**

- `tests/test-hpc-packer-controller-framework.sh`
- `tests/test-hpc-packer-compute-framework.sh`
- `tests/test-infra/configs/test-hpc-packer-controller.yaml`
- `tests/test-infra/configs/test-hpc-packer-compute.yaml`

#### **Subtask 4C.3: Update Test Makefile and Delete Obsolete Tests**

- **Priority**: MEDIUM
- **Estimated Time**: 1 hour
- **Status**: Pending
- **Dependencies**: 4C.1, 4C.2

**Actions:**

1. **Update tests/Makefile** with new targets
2. **Create backup** of obsolete test files
3. **Delete 25 obsolete files** (13 frameworks + 10 configs + 2 helpers)
4. **Verify remaining frameworks** (should be 8 total)
5. **Update tests/README.md** with new structure

**Files to Delete (25 total):**

- 13 test framework files
- 10 test configuration files  
- 2 helper script files

**Verification:**

```bash
# Count remaining frameworks (should be 8)
ls -1 tests/test-*-framework.sh | wc -l

# List remaining frameworks
ls -1 tests/test-*-framework.sh
```

### **Phase 4D: Final Validation & Cleanup**

#### **Subtask 4D.1: Comprehensive Integration Testing**

- **Priority**: HIGH
- **Estimated Time**: 1 hour
- **Status**: Pending
- **Dependencies**: 4B.3, 4C.3

**Actions:**

1. **Test all new playbooks** work correctly
2. **Test all new test frameworks** execute properly
3. **Verify no broken references** in codebase
4. **Run complete test suite** with new structure
5. **Document any issues** found and resolve

**Test Commands:**

```bash
# Test all new functionality
make test-hpc-runtime
make test-hpc-packer-controller
make test-hpc-packer-compute
make test-all

# Verify no broken references
grep -r "playbook-hpc-controller.yml" . --exclude-dir=.git
grep -r "test-slurm-compute-framework" . --exclude-dir=.git
```

#### **Subtask 4D.2: Update Project Documentation**

- **Priority**: MEDIUM
- **Estimated Time**: 45 minutes
- **Status**: Pending
- **Dependencies**: 4D.1

**Actions:**

1. **Update main README.md** with new structure
2. **Create migration guide** for users
3. **Update any references** in other docs
4. **Verify all documentation** is current
5. **Create rollback procedures** documentation

**Files to Update:**

- `README.md` (main project)
- `docs/guides/hpc-deployment.md`
- Create: `docs/migration/phase-4-consolidation.md`

#### **Subtask 4D.3: Final Verification & Sign-off**

- **Priority**: HIGH
- **Estimated Time**: 30 minutes
- **Status**: Pending
- **Dependencies**: 4D.1, 4D.2

**Actions:**

1. **Run complete validation** one final time
2. **Verify all success criteria** met
3. **Document completion status** for each task
4. **Update phase-4-consolidation.md** with final status
5. **Mark Phase 4 as COMPLETE**

**Success Criteria Verification:**

- [ ] 7 playbooks remain (50% reduction from 14)
- [ ] 8 test frameworks remain (47% reduction from 15+)
- [ ] All functionality preserved and working
- [ ] No broken references in codebase
- [ ] Documentation updated and current
- [ ] Migration guide created
- [ ] Rollback procedures documented

---

## 📊 **Progress Tracking**

### **Current Status Summary**

- **Phase 4A (Runtime Validation)**: 0/3 subtasks complete
- **Phase 4B (Playbook Consolidation)**: 0/3 subtasks complete  
- **Phase 4C (Test Framework Consolidation)**: 0/3 subtasks complete
- **Phase 4D (Final Validation & Cleanup)**: 0/3 subtasks complete

### **Estimated Total Time**

- **Phase 4A**: 2.5 hours
- **Phase 4B**: 1 hour
- **Phase 4C**: 4.5 hours
- **Phase 4D**: 2.25 hours
- **Total**: ~10 hours of focused work

### **Critical Path**

1. **4A.1** → **4A.2** → **4A.3** (Runtime validation must complete first)
2. **4B.1** → **4B.2** → **4B.3** (Playbook cleanup)
3. **4C.1** → **4C.2** → **4C.3** (Test framework consolidation)
4. **4D.1** → **4D.2** → **4D.3** (Final validation)

### **Risk Mitigation**

- **Backup everything** before deletion
- **Validate thoroughly** at each step
- **Test rollback procedures** before proceeding
- **Document all changes** for potential reversal

### **Phase Completion Criteria**

**Phase 4 Core (Tasks 029-034.1): ✅ COMPLETE (Verified 2025-10-20)**

- [x] Task 029: ✅ **COMPLETE** - playbook-hpc-packer-controller.yml EXISTS
- [x] Task 030: ✅ **COMPLETE** - playbook-hpc-packer-compute.yml EXISTS
- [x] Task 031: ✅ **COMPLETE** - playbook-hpc-runtime.yml EXISTS
- [x] Task 032: ✅ **COMPLETE** - Packer templates updated (needs verification)
- [x] Task 033: ✅ **COMPLETE** - Packer builds functional
- [x] Task 034: ✅ **COMPLETE** - 9 obsolete playbooks DELETED (verified absent)
- [x] Task 034.1: ✅ **COMPLETE** - SLURM install.yml uses pre-built packages

**Phase 4.5 Storage (Tasks 038-041): ✅ MOSTLY COMPLETE (Verified 2025-10-23)**

- [x] Task 038: ✅ **COMPLETE** - BeeGFS Packer installation consolidated into HPC playbooks
- [x] Task 039: ✅ **COMPLETE** - VirtIO-FS integrated into playbook-hpc-runtime.yml
- [ ] Task 040: ❌ **NOT STARTED** - Registry uses /opt/containers (not BeeGFS)
- [x] Task 041: ✅ **COMPLETE** - virtio_fs_mounts and beegfs_config added to cluster config schema

**Phase 4 Testing (Tasks 035-037): ✅ COMPLETE (Verified 2025-10-28)**

- [x] Task 035: ✅ **COMPLETE** - test-hpc-runtime-framework.sh created in tests/frameworks/
- [x] Task 036: ✅ **COMPLETE** - test-hpc-packer-controller-framework.sh and test-hpc-packer-compute-framework.sh created
- [x] Task 037: ✅ **COMPLETE** - Old frameworks archived/removed, Makefile updated with 42+ unified targets

**Phase 4.8 Role Consolidation (Tasks 044-048, 046.1): 🔄 IN PROGRESS (Added 2025-10-25)**

- [x] Task 044: ✅ **COMPLETE** - BeeGFS common role created and functional
- [x] Task 045: ✅ **COMPLETE** - SLURM common role created with MUNGE, directories, and user management
- [x] Task 046: ✅ **COMPLETE** - Shared package management role created with reusable installation logic
- [x] Task 046.1: ✅ **COMPLETE** - Package-manager integrated into BeeGFS and SLURM roles
- [x] Task 047: ✅ **COMPLETE** - Base package roles consolidated into unified base-packages role
- [x] Task 048: ✅ **COMPLETE** - Shared utilities role created with reusable validation tasks

**Success Metrics (Updated 2025-10-25):**

- ✅ Packer playbooks created: playbook-hpc-packer-{controller,compute}.yml
- ✅ Runtime playbook created: playbook-hpc-runtime.yml
- ✅ All 9 obsolete playbooks deleted (verified absent from codebase)
- ✅ Playbook count: 8 (down from 14, 43% reduction achieved)
- 🎯 Target: 7 playbooks (50% reduction - Task 038 COMPLETE!)
- ❌ 3 new unified test frameworks NOT created (Tasks 035-036)
- ❌ 11 obsolete test frameworks still exist (Task 037 not started)
- ✅ Storage enhancements MOSTLY COMPLETE (Tasks 038-039, 041) - Task 040 pending
- 🔄 Ansible role consolidation IN PROGRESS (Tasks 044-046, 046.1 complete, Tasks 047-048 pending)

**Estimated Code Reduction from Role Consolidation (Tasks 044-048):**

- ✅ Task 044 (BeeGFS common): ~600-1200 lines eliminated - **COMPLETE**
- ✅ Task 045 (SLURM common): ~200-300 lines eliminated - **COMPLETE**
- ✅ Task 046 (Package manager): ~400-600 lines eliminated - **COMPLETE** (role created)
- ✅ Task 046.1 (Package integration): ~800-1200 lines eliminated - **COMPLETE** (integrated into BeeGFS and SLURM)
- ✅ Task 047 (Base packages): ~100-150 lines eliminated - **COMPLETE**
- ✅ Task 048 (Shared utilities): ~150-200 lines eliminated - **COMPLETE**
- **Total estimated reduction: ~1,750-2,650 lines of duplicate code eliminated!**

### **Risk Assessment**

**Current Risk Level:** 🟢 **LOW**

- ✅ Packer functionality validated and working
- ✅ Runtime playbook tested and deployed
- ✅ All obsolete playbooks successfully removed
- ✅ Rollback procedures in place
- ✅ Storage consolidation successful

**Next Steps Strategy:**

- **Priority 1**: Phase 4.8 Ansible role consolidation (Tasks 044-048) - Eliminate 1450+ lines of duplicate code
- **Priority 2**: Phase 4 test framework consolidation (Tasks 035-037) - Streamline testing infrastructure
- **Priority 3**: Phase 4.5 container registry optimization (Task 040) - BeeGFS integration for distributed access

---

**Document Version:** 3.9 (Task 048 Complete - All Role Consolidation Tasks Done)
**Last Review:** 2025-10-27
**Status:**
✅ **Phase 4 Core COMPLETE (8/13 tasks)**
✅ **Phase 4.5-4.8 COMPLETE (10/10 tasks)**
❌ **Phase 4 Testing PENDING (0/3 tasks)**

**Verification Summary:**

- ✅ 8 playbooks exist (verified in ansible/playbooks/)
- ✅ 9 obsolete playbooks deleted (verified absent)
- ✅ SLURM uses pre-built packages (verified in install.yml)
- ✅ 3 new unified test frameworks created (verified in tests/frameworks/)
- ✅ test-hpc-runtime-framework.sh exists and functional
- ✅ test-hpc-packer-controller-framework.sh exists and functional
- ✅ test-hpc-packer-compute-framework.sh exists and functional
- ✅ Old test frameworks properly moved/archived
- ✅ BeeGFS Packer consolidated into HPC playbooks (Task 038 complete)
- ✅ VirtIO-FS integrated into runtime playbook (Task 039 complete)
- ❌ Container registry not on BeeGFS (uses /opt/containers) - Task 040 PENDING
- ✅ BeeGFS common role created (Task 044 complete)
- ✅ SLURM common role created (Task 045 complete)
- ✅ Package manager role created (Task 046 complete)
- ✅ Package manager integrated into BeeGFS and SLURM roles (Task 046.1 complete)
- ✅ Base package roles consolidated (Task 047 complete)
- ✅ Shared utilities role created (Task 048 complete)
- ✅ **ALL Phase 4.8 Role Consolidation Tasks Complete!**

**Verification Summary (UPDATED 2025-10-28):**

- ✅ 8 playbooks exist (verified in ansible/playbooks/)
- ✅ 9 obsolete playbooks deleted (verified absent)
- ✅ SLURM uses pre-built packages (verified in install.yml)
- ✅ 3 new unified test frameworks created (verified in tests/frameworks/)
- ✅ test-hpc-runtime-framework.sh exists and functional
- ✅ test-hpc-packer-controller-framework.sh exists and functional
- ✅ test-hpc-packer-compute-framework.sh exists and functional
- ✅ Old test frameworks properly moved/archived
- ✅ BeeGFS Packer consolidated into HPC playbooks (Task 038 complete)
- ✅ VirtIO-FS integrated into runtime playbook (Task 039 complete)
- ❌ Container registry not on BeeGFS (uses /opt/containers) - Task 040 PENDING
- ✅ BeeGFS common role created (Task 044 complete)
- ✅ SLURM common role created (Task 045 complete)
- ✅ Package manager role created (Task 046 complete)
- ✅ Package manager integrated into BeeGFS and SLURM roles (Task 046.1 complete)
- ✅ Base package roles consolidated (Task 047 complete)
- ✅ Shared utilities role created (Task 048 complete)
- ✅ **ALL Phase 4.8 Role Consolidation Tasks Complete!**
- ✅ **Phase 4 Test Framework Consolidation COMPLETE (Tasks 035-037)**
