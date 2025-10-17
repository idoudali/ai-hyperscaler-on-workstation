# Phase 4: Infrastructure Consolidation (Tasks 029-037)

**Status**: 0% Complete (0/9 tasks)  
**Last Updated**: 2025-10-17  
**Priority**: HIGH  
**Tasks**: 9 (Ansible: 5, Testing: 3, Cleanup: 1)

## Overview

This phase consolidates the Ansible playbook and test framework infrastructure, reducing complexity while maintaining
all functionality. The goal is to streamline from 14 playbooks to 7 playbooks and 15+ test frameworks to 3 frameworks.

## Current State (As of 2025-10-17)

**Ansible Playbooks:** 14 playbooks

- Core HPC: `playbook-hpc-controller.yml` ✅, `playbook-hpc-compute.yml` ✅, `playbook-hpc.yml` ❌ (obsolete)
- Runtime configs: 6 specialized runtime playbooks ✅
  - `playbook-slurm-compute-runtime-config.yml`
  - `playbook-cgroup-runtime-config.yml`
  - `playbook-gres-runtime-config.yml`
  - `playbook-job-scripts-runtime-config.yml`
  - `playbook-dcgm-runtime-config.yml`
  - `playbook-container-validation-runtime-config.yml`
- Storage: BeeGFS (2), VirtIO-FS (1) ✅
- Infrastructure: `playbook-cloud.yml`, `playbook-container-registry.yml` ✅

**Test Frameworks:** 15 test frameworks

- test-{beegfs,cgroup-isolation,container-{integration,registry,runtime},dcgm-monitoring}-framework.sh
- test-{gpu-gres,grafana,job-scripts,monitoring-stack,pcie-passthrough}-framework.sh
- test-{slurm-{accounting,compute,controller},virtio-fs}-framework.sh

**Test Configs:** 17 YAML configuration files in `tests/test-infra/configs/`

**Ansible Roles:** All roles support modular task execution ✅

- `slurm-compute/tasks/`: configure.yml, cgroup.yml, gres.yml, job-scripts.yml
- `slurm-controller/tasks/`: configure.yml, install.yml, munge.yml, accounting.yml
- `monitoring-stack/tasks/`: prometheus.yml, grafana.yml, node-exporter.yml, dcgm.yml

## Consolidation Goals

1. **Ansible Simplification**: 14 playbooks → 7 focused playbooks (50% reduction)
   - 2 NEW Packer playbooks (controller + compute)
   - 1 NEW unified runtime configuration playbook
   - 2 KEEP storage playbooks (BeeGFS + VirtIO-FS) - optional backends
   - 2 KEEP infrastructure playbooks (cloud + registry)
   - Delete 9 obsolete/consolidated playbooks

2. **Test Framework Cleanup**: 15+ frameworks → 3 streamlined frameworks (80% reduction)
   - Delete 25 obsolete files (13 frameworks + 10 configs + 2 helpers)
   - Unified test execution model
   - All test suites preserved and functional

3. **Maintainability**: Clean architecture with no deprecated code

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
```

### Role Requirements

- All roles must support modular task imports via `tasks_from:` ✅
- Roles must support `packer_build` variable for build vs runtime modes ✅
- Current roles already meet these requirements ✅

---

## Phase 4: Ansible Playbook Consolidation (Tasks 029-034)

### Task 029: Create HPC Packer Controller Playbook

- **ID**: TASK-029
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-010.1, TASK-015, TASK-017
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate
- **Status**: Pending
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
- **Status**: Pending
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
- **Status**: Pending
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
- **Status**: Pending
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
- **Status**: Pending
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
- **Status**: Pending
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
playbook-beegfs-runtime-config.yml  # KEEP - BeeGFS runtime configuration
playbook-virtio-fs-runtime-config.yml  # KEEP - VirtIO-FS shared directories

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

## Phase 4: Test Framework Consolidation (Tasks 035-037)

### Task 035: Create Unified HPC Runtime Test Framework

- **ID**: TASK-035
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-031 (unified runtime playbook)
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate-Advanced
- **Status**: Pending
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
# Test complete workflow
cd tests
./test-hpc-runtime-framework.sh e2e

# Test individual commands
./test-hpc-runtime-framework.sh start-cluster
./test-hpc-runtime-framework.sh deploy-ansible
./test-hpc-runtime-framework.sh run-tests
./test-hpc-runtime-framework.sh status
./test-hpc-runtime-framework.sh stop-cluster
```

---

### Task 036: Create HPC Packer Test Frameworks

- **ID**: TASK-036
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-029, TASK-030 (new Packer playbooks)
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate-Advanced
- **Status**: Pending
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
- **Status**: Pending
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

## Expected Outcomes

**Ansible Playbooks:**

- **Before:** 14 playbooks
- **After:** 7 playbooks (50% reduction)
  - 3 new consolidated playbooks (packer-controller, packer-compute, runtime)
  - 2 storage playbooks (BeeGFS, VirtIO-FS)
  - 2 infrastructure playbooks (cloud, registry)
- Clear distinction: 2 Packer + 1 runtime + 4 optional
- Role modular task inclusion pattern
- GPU-conditional execution
- Preserved validation and troubleshooting

**Test Frameworks:**

- **Before:** 15+ frameworks
- **After:** 8 frameworks (47% reduction)
  - 3 new unified frameworks (runtime, packer-controller, packer-compute)
  - 5 existing frameworks kept (beegfs, virtio-fs, pcie-passthrough, container-registry, + 1 more)
- Standard CLI pattern across all frameworks
- Test suite orchestration
- Updated Makefile targets
- All test suites preserved (suites/ directory unchanged)

**Files Deleted:**

- 9 obsolete Ansible playbooks
- 13 obsolete test frameworks
- 10 obsolete test configurations
- 2 obsolete helper scripts
- **Total: 34 files removed**

**Infrastructure Ready:**

- ✅ All roles support modular task execution
- ✅ Roles support `packer_build` variable
- ✅ Inventory variables documented
- ✅ Migration path clear
- ✅ Rollback procedures in place

---

## Migration Guide

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

→ [Phase 5: Enhanced Monitoring & Observability](phase-5-monitoring.md) (if exists)

→ [Phase 6: Final Validation & Production Readiness](phase-6-validation.md) (if exists)

---

## Related Documentation

- [Reference: Testing Framework Patterns](../reference/testing-framework.md)
- [Reference: Infrastructure Summary](../reference/infrastructure-summary.md)
- [Reference: Ansible Role Architecture](../reference/ansible-roles.md)
- [Guide: HPC Cluster Deployment](../guides/hpc-deployment.md)

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

**Document Version:** 2.0  
**Last Review:** 2025-10-17  
**Status:** Ready for execution after addressing review feedback
