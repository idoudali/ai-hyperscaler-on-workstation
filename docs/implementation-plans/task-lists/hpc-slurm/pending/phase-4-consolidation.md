# Phase 4: Infrastructure Consolidation (Tasks 029-040)

**Status**: 0% Complete (0/12 tasks)  
**Last Updated**: 2025-10-17  
**Priority**: HIGH  
**Tasks**: 12

## Overview

This phase consolidates the Ansible playbook and test framework infrastructure, reducing complexity while maintaining
all functionality. The goal is to streamline from 10+ playbooks to 3 playbooks and 15+ test frameworks to 3 frameworks.

## Consolidation Goals

1. **Ansible Simplification**: 10+ playbooks → 3 focused playbooks (70% reduction)
   - 2 Packer playbooks (controller + compute)
   - 1 unified runtime configuration playbook

2. **Test Framework Cleanup**: 15+ frameworks → 3 streamlined frameworks (80% reduction)
   - Delete 25 obsolete files (13 frameworks + 10 configs + 2 helpers)
   - Unified test execution model
   - All test suites preserved and functional

3. **Maintainability**: Clean architecture with no deprecated code

---

## Phase 4: Infrastructure Consolidation & Cleanup (Tasks 029-036)

**Priority:** HIGH - Execute these tasks AFTER storage infrastructure is deployed

**Objective:** Consolidate Ansible playbooks and test frameworks into streamlined, maintainable structure

**Estimated Duration:** 2-3 weeks

### Consolidation Goals

1. **Ansible Simplification**: 10+ playbooks → 3 focused playbooks (70% reduction)
   - 2 Packer playbooks (controller + compute)
   - 1 unified runtime configuration playbook

2. **Test Framework Cleanup**: 15+ frameworks → 3 streamlined frameworks (80% reduction)
   - Delete 25 obsolete files (13 frameworks + 10 configs + 2 helpers)
   - Unified test execution model
   - All test suites preserved and functional

3. **Maintainability**: Clean architecture with no deprecated code

### Ansible Playbook Consolidation

#### Task 029: Create HPC Packer Controller Playbook

- **ID**: TASK-029
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-010.1, TASK-015, TASK-017
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate
- **Status**: Pending
- **Priority**: HIGH

**Description:** Create unified Packer build playbook for HPC controller images, consolidating multiple
component playbooks into single streamlined build process.

**Deliverables:**

- `ansible/playbooks/playbook-hpc-packer-controller.yml` - Unified controller Packer playbook
- Consolidates roles: slurm-controller, monitoring-stack, hpc-base-packages, nvidia-gpu-drivers
- Supports `packer_build=true` mode for install-only operations
- Replaces `playbook-hpc-controller.yml` during Packer builds

**Playbook Structure:**

```yaml
---
- name: HPC Controller Packer Build
  hosts: all
  become: true
  vars:
    packer_build: true
  roles:
    - role: hpc-base-packages
    - role: slurm-controller
      vars:
        install_only: true
    - role: monitoring-stack
      vars:
        install_only: true
```

**Validation Criteria:**

- [ ] Playbook creates functional controller image
- [ ] All roles execute without errors
- [ ] SLURM controller components installed
- [ ] Monitoring stack (Prometheus, Grafana, Node Exporter) installed
- [ ] Image size reasonable and optimized
- [ ] No runtime services started during build

**Test Commands:**

```bash
# Test playbook with Packer
cd packer/hpc-controller
packer build hpc-controller.pkr.hcl

# Verify image built successfully
ls -lh ../../build/packer/hpc-controller/
```

---

#### Task 030: Create HPC Packer Compute Playbook

- **ID**: TASK-030
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-008, TASK-022
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate
- **Status**: Pending
- **Priority**: HIGH

**Description:** Create unified Packer build playbook for HPC compute images, consolidating compute node
components into single streamlined build process.

**Deliverables:**

- `ansible/playbooks/playbook-hpc-packer-compute.yml` - Unified compute Packer playbook
- Consolidates roles: slurm-compute, container-runtime, monitoring-stack, nvidia-gpu-drivers
- Supports `packer_build=true` mode for install-only operations
- Replaces `playbook-hpc-compute.yml` during Packer builds

**Playbook Structure:**

```yaml
---
- name: HPC Compute Packer Build
  hosts: all
  become: true
  vars:
    packer_build: true
  roles:
    - role: hpc-base-packages
    - role: nvidia-gpu-drivers
      when: gpu_enabled | default(false)
    - role: container-runtime
    - role: slurm-compute
      vars:
        install_only: true
    - role: monitoring-stack
      vars:
        install_only: true
        node_exporter_only: true
```

**Validation Criteria:**

- [ ] Playbook creates functional compute image
- [ ] All roles execute without errors
- [ ] SLURM compute components installed
- [ ] Apptainer/Singularity installed
- [ ] Node Exporter installed
- [ ] GPU drivers installed (if enabled)
- [ ] No runtime services started during build

**Test Commands:**

```bash
# Test playbook with Packer
cd packer/hpc-compute
packer build hpc-compute.pkr.hcl

# Verify image built successfully
ls -lh ../../build/packer/hpc-compute/
```

---

#### Task 031: Create Unified Runtime Configuration Playbook

- **ID**: TASK-031
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-022, TASK-023, TASK-024, TASK-025
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate-Advanced
- **Status**: Pending
- **Priority**: HIGH

**Description:** Create single unified playbook for complete HPC cluster runtime configuration,
consolidating 6 specialized runtime playbooks into one maintainable file.

**Deliverables:**

- `ansible/playbooks/playbook-hpc-runtime.yml` - Unified runtime configuration playbook
- Consolidates all runtime configuration tasks
- Supports controller and compute node configuration
- GPU-conditional tasks for GRES and DCGM
- Replaces 6 runtime-specific playbooks

**Consolidates These Playbooks:**

1. `playbook-slurm-compute-runtime-config.yml`
2. `playbook-cgroup-runtime-config.yml`
3. `playbook-gres-runtime-config.yml`
4. `playbook-job-scripts-runtime-config.yml`
5. `playbook-dcgm-runtime-config.yml`
6. `playbook-container-validation-runtime-config.yml`

**Playbook Structure:**

```yaml
---
- name: HPC Runtime Configuration
  hosts: all
  become: true
  vars:
    packer_build: false
  tasks:
    # Controller configuration
    - name: Configure SLURM controller services
      import_role:
        name: slurm-controller
        tasks_from: configure
      when: inventory_hostname in groups['hpc_controllers']

    # Compute node configuration
    - name: Configure SLURM compute services
      import_role:
        name: slurm-compute
        tasks_from: configure
      when: inventory_hostname in groups['compute_nodes']

    - name: Configure cgroup isolation
      import_role:
        name: slurm-compute
        tasks_from: cgroup
      when: inventory_hostname in groups['compute_nodes']

    - name: Configure GPU GRES
      import_role:
        name: slurm-compute
        tasks_from: gres
      when:
        - inventory_hostname in groups['compute_nodes']
        - gpu_enabled | default(false)
```

**Validation Criteria:**

- [ ] Playbook configures complete cluster successfully
- [ ] Controller services start and run correctly
- [ ] Compute nodes register with controller
- [ ] Cgroup isolation configured properly
- [ ] GPU GRES configured (if GPUs present)
- [ ] Job scripts deployed and functional
- [ ] DCGM monitoring active (if GPUs present)
- [ ] All original functionality preserved

**Test Commands:**

```bash
# Test runtime configuration
cd ansible
ansible-playbook -i inventories/test playbooks/playbook-hpc-runtime.yml

# Verify cluster operational
ssh controller "sinfo"
ssh controller "scontrol show config | grep ProctrackType"
```

---

#### Task 032: Update Packer Templates for New Playbooks

- **ID**: TASK-032
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-029, TASK-030
- **Estimated Time**: 1 hour
- **Difficulty**: Junior
- **Status**: Pending
- **Priority**: HIGH

**Description:** Update Packer HCL templates to reference new consolidated playbooks instead of old playbook names.

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

- [ ] Controller Packer build completes successfully
- [ ] Compute Packer build completes successfully
- [ ] Images are functionally identical to previous builds
- [ ] No Ansible errors during provisioning

**Test Commands:**

```bash
# Build controller image
cd packer/hpc-controller
packer build hpc-controller.pkr.hcl

# Build compute image
cd ../hpc-compute
packer build hpc-compute.pkr.hcl
```

---

#### Task 033: Delete Obsolete Ansible Playbooks

- **ID**: TASK-033
- **Phase**: 4 - Infrastructure Consolidation
- **Dependencies**: TASK-029, TASK-030, TASK-031, TASK-032
- **Estimated Time**: 1 hour
- **Difficulty**: Junior
- **Status**: Pending
- **Priority**: MEDIUM (after validation)

**Description:** Remove obsolete Ansible playbooks after confirming new consolidated playbooks work correctly.

**Deliverables:**

- `ansible/playbooks/playbook-hpc-packer-controller.yml` - Unified controller Packer playbook
- Consolidates roles: slurm-controller, monitoring-stack, hpc-base-packages, nvidia-gpu-drivers
- Supports `packer_build=true` mode for install-only operations
- Replaces `playbook-hpc-controller.yml` during Packer builds

**Playbook Structure:**

```yaml
---
- name: HPC Controller Packer Build
  hosts: all
  become: true
  vars:
    packer_build: true
  roles:
    - role: hpc-base-packages
    - role: slurm-controller
      vars:
        install_only: true
    - role: monitoring-stack
      vars:
        install_only: true
```

**Validation Criteria:**

- [ ] Playbook creates functional controller image
- [ ] All roles execute without errors
- [ ] SLURM controller components installed
- [ ] Monitoring stack (Prometheus, Grafana, Node Exporter) installed
- [ ] Image size reasonable and optimized
- [ ] No runtime services started during build

**Test Commands:**

```bash
# Test playbook with Packer
cd packer/hpc-controller
packer build hpc-controller.pkr.hcl

# Verify image built successfully
ls -lh ../../build/packer/hpc-controller/
```

---

#### Task 034: Create HPC Packer Compute Playbook

- **ID**: TASK-034
- **Phase**: 5 - Infrastructure Consolidation
- **Dependencies**: TASK-008, TASK-022
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate
- **Status**: Pending
- **Priority**: HIGH

**Description:** Create unified Packer build playbook for HPC compute images, consolidating compute node
components into single streamlined build process.

**Deliverables:**

- `ansible/playbooks/playbook-hpc-packer-compute.yml` - Unified compute Packer playbook
- Consolidates roles: slurm-compute, container-runtime, monitoring-stack, nvidia-gpu-drivers
- Supports `packer_build=true` mode for install-only operations
- Replaces `playbook-hpc-compute.yml` during Packer builds

**Playbook Structure:**

```yaml
---
- name: HPC Compute Packer Build
  hosts: all
  become: true
  vars:
    packer_build: true
  roles:
    - role: hpc-base-packages
    - role: nvidia-gpu-drivers
      when: gpu_enabled | default(false)
    - role: container-runtime
    - role: slurm-compute
      vars:
        install_only: true
    - role: monitoring-stack
      vars:
        install_only: true
        node_exporter_only: true
```

**Validation Criteria:**

- [ ] Playbook creates functional compute image
- [ ] All roles execute without errors
- [ ] SLURM compute components installed
- [ ] Apptainer/Singularity installed
- [ ] Node Exporter installed
- [ ] GPU drivers installed (if enabled)
- [ ] No runtime services started during build

**Test Commands:**

```bash
# Test playbook with Packer
cd packer/hpc-compute
packer build hpc-compute.pkr.hcl

# Verify image built successfully
ls -lh ../../build/packer/hpc-compute/
```

---

#### Task 035: Create Unified Runtime Configuration Playbook

- **ID**: TASK-035
- **Phase**: 5 - Infrastructure Consolidation
- **Dependencies**: TASK-022, TASK-023, TASK-024, TASK-025
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate-Advanced
- **Status**: Pending
- **Priority**: HIGH

**Description:** Create single unified playbook for complete HPC cluster runtime configuration,
consolidating 6 specialized runtime playbooks into one maintainable file.

**Deliverables:**

- `ansible/playbooks/playbook-hpc-runtime.yml` - Unified runtime configuration playbook
- Consolidates all runtime configuration tasks
- Supports controller and compute node configuration
- GPU-conditional tasks for GRES and DCGM
- Replaces 6 runtime-specific playbooks

**Consolidates These Playbooks:**

1. `playbook-slurm-compute-runtime-config.yml`
2. `playbook-cgroup-runtime-config.yml`
3. `playbook-gres-runtime-config.yml`
4. `playbook-job-scripts-runtime-config.yml`
5. `playbook-dcgm-runtime-config.yml`
6. `playbook-container-validation-runtime-config.yml`

**Playbook Structure:**

```yaml
---
- name: HPC Runtime Configuration
  hosts: all
  become: true
  vars:
    packer_build: false
  tasks:
    # Controller configuration
    - name: Configure SLURM controller services
      import_role:
        name: slurm-controller
        tasks_from: configure
      when: inventory_hostname in groups['hpc_controllers']

    - name: Start monitoring stack
      import_role:
        name: monitoring-stack
        tasks_from: configure
      when: inventory_hostname in groups['hpc_controllers']

    # Compute node configuration
    - name: Configure SLURM compute services
      import_role:
        name: slurm-compute
        tasks_from: configure
      when: inventory_hostname in groups['compute_nodes']

    - name: Configure cgroup isolation
      import_role:
        name: slurm-compute
        tasks_from: cgroup
      when: inventory_hostname in groups['compute_nodes']

    - name: Configure GPU GRES
      import_role:
        name: slurm-compute
        tasks_from: gres
      when:
        - inventory_hostname in groups['compute_nodes']
        - gpu_enabled | default(false)

    - name: Deploy job scripts
      import_role:
        name: slurm-compute
        tasks_from: job-scripts
      when: inventory_hostname in groups['compute_nodes']

    - name: Configure DCGM monitoring
      import_role:
        name: monitoring-stack
        tasks_from: dcgm
      when:
        - inventory_hostname in groups['compute_nodes']
        - gpu_enabled | default(false)
```

**Validation Criteria:**

- [ ] Playbook configures complete cluster successfully
- [ ] Controller services start and run correctly
- [ ] Compute nodes register with controller
- [ ] Cgroup isolation configured properly
- [ ] GPU GRES configured (if GPUs present)
- [ ] Job scripts deployed and functional
- [ ] DCGM monitoring active (if GPUs present)
- [ ] All original functionality preserved

**Test Commands:**

```bash
# Test runtime configuration
cd ansible
ansible-playbook -i inventories/test playbooks/playbook-hpc-runtime.yml

# Verify cluster operational
ssh controller "sinfo"
ssh controller "scontrol show config | grep ProctrackType"
```

---

#### Task 036: Update Packer Templates for New Playbooks

- **ID**: TASK-036
- **Phase**: 5 - Infrastructure Consolidation
- **Dependencies**: TASK-033, TASK-034
- **Estimated Time**: 1 hour
- **Difficulty**: Junior
- **Status**: Pending
- **Priority**: HIGH

**Description:** Update Packer HCL templates to reference new consolidated playbooks instead of old playbook names.

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

- [ ] Controller Packer build completes successfully
- [ ] Compute Packer build completes successfully
- [ ] Images are functionally identical to previous builds
- [ ] No Ansible errors during provisioning

**Test Commands:**

```bash
# Build controller image
cd packer/hpc-controller
packer build hpc-controller.pkr.hcl

# Build compute image
cd ../hpc-compute
packer build hpc-compute.pkr.hcl
```

---

#### Task 037: Delete Obsolete Ansible Playbooks

- **ID**: TASK-037
- **Phase**: 5 - Infrastructure Consolidation
- **Dependencies**: TASK-033, TASK-034, TASK-035, TASK-036
- **Estimated Time**: 1 hour
- **Difficulty**: Junior
- **Status**: Pending
- **Priority**: MEDIUM (after validation)

**Description:** Remove obsolete Ansible playbooks after confirming new consolidated playbooks work correctly.

**Files to Delete (9 playbooks):**

1. `ansible/playbooks/playbook-hpc.yml` - Generic, outdated
2. `ansible/playbooks/playbook-slurm-compute-runtime-config.yml` - Consolidated into runtime playbook
3. `ansible/playbooks/playbook-cgroup-runtime-config.yml` - Consolidated into runtime playbook
4. `ansible/playbooks/playbook-gres-runtime-config.yml` - Consolidated into runtime playbook
5. `ansible/playbooks/playbook-job-scripts-runtime-config.yml` - Consolidated into runtime playbook
6. `ansible/playbooks/playbook-dcgm-runtime-config.yml` - Consolidated into runtime playbook
7. `ansible/playbooks/playbook-container-validation-runtime-config.yml` - Consolidated into runtime playbook
8. `ansible/playbooks/playbook-hpc-controller.yml` - Replaced by packer-controller playbook
9. `ansible/playbooks/playbook-hpc-compute.yml` - Replaced by packer-compute playbook

**Keep These Playbooks:**

- `playbook-cloud.yml` - Separate Kubernetes infrastructure
- `playbook-container-registry.yml` - Optional infrastructure component
- `playbook-hpc-packer-controller.yml` - NEW
- `playbook-hpc-packer-compute.yml` - NEW
- `playbook-hpc-runtime.yml` - NEW

**Additional Updates:**

- Update `ansible/README.md` to document new playbook structure
- Remove references to old playbooks in documentation
- Verify no scripts reference deleted playbooks

**Validation Criteria:**

- [ ] All 9 obsolete playbooks deleted
- [ ] No broken references in codebase
- [ ] ansible/README.md updated
- [ ] Documentation reflects new structure
- [ ] Grep confirms no remaining references

**Test Commands:**

```bash
# Verify no references to old playbooks
cd ansible
grep -r "playbook-hpc-controller.yml" . --exclude-dir=.git
grep -r "playbook-cgroup-runtime-config.yml" . --exclude-dir=.git

# Verify README updated
cat README.md | grep -i "playbook"
```

---

### Test Framework Consolidation

#### Task 038: Create Unified HPC Runtime Test Framework

- **ID**: TASK-038
- **Phase**: 5 - Infrastructure Consolidation
- **Dependencies**: TASK-035
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate-Advanced
- **Status**: Pending
- **Priority**: HIGH

**Description:** Create unified test framework for HPC runtime configuration, consolidating 6 specialized
runtime test frameworks into single streamlined framework.

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

**Test Configuration:**

**File:** `tests/test-infra/configs/test-hpc-runtime.yaml`

```yaml
version: "1.0"
clusters:
  hpc:
    controller:
      hostname: "test-hpc-runtime-controller"
      ip_address: "192.168.220.10"
      memory: 4096
      cpus: 4
    compute_nodes:
      - hostname: "test-hpc-runtime-compute01"
        ip_address: "192.168.220.20"
        memory: 8192
        cpus: 8
```

**Validation Criteria:**

- [ ] Framework implements standard CLI pattern
- [ ] All 6 test suites execute correctly
- [ ] GPU tests skip gracefully when no GPU present
- [ ] Test results properly aggregated and reported
- [ ] Cluster lifecycle management works
- [ ] Uses playbook-hpc-runtime.yml for deployment

**Test Commands:**

```bash
# Test complete workflow
cd tests
./test-hpc-runtime-framework.sh e2e

# Test individual commands
./test-hpc-runtime-framework.sh start-cluster
./test-hpc-runtime-framework.sh deploy-ansible
./test-hpc-runtime-framework.sh run-tests
./test-hpc-runtime-framework.sh stop-cluster
```

---

#### Task 039: Create HPC Packer Test Frameworks

- **ID**: TASK-039
- **Phase**: 5 - Infrastructure Consolidation
- **Dependencies**: TASK-033, TASK-034
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
5. `test-container-runtime-framework.sh` - Compute component

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
clusters:
  hpc:
    controller:
      hostname: "test-packer-controller"
      ip_address: "192.168.220.50"
      memory: 4096
      cpus: 4
```

**File:** `tests/test-infra/configs/test-hpc-packer-compute.yaml`

```yaml
version: "1.0"
clusters:
  hpc:
    compute_nodes:
      - hostname: "test-packer-compute01"
        ip_address: "192.168.220.60"
        memory: 8192
        cpus: 8
```

**Validation Criteria:**

- [ ] Both frameworks implement standard CLI pattern
- [ ] Controller framework tests all controller components
- [ ] Compute framework tests all compute components
- [ ] Test suites execute without errors
- [ ] Proper test reporting and logging
- [ ] Uses new Packer playbooks for image builds

**Test Commands:**

```bash
# Test controller framework
cd tests
./test-hpc-packer-controller-framework.sh e2e

# Test compute framework
./test-hpc-packer-compute-framework.sh e2e
```

---

#### Task 040: Update Test Makefile and Delete Obsolete Tests

- **ID**: TASK-040
- **Phase**: 5 - Infrastructure Consolidation
- **Dependencies**: TASK-038, TASK-039
- **Estimated Time**: 2 hours
- **Difficulty**: Intermediate
- **Status**: Pending
- **Priority**: MEDIUM (after validation)

**Description:** Update test Makefile with new consolidated targets and remove obsolete test frameworks,
configs, and helper scripts.

**Makefile Updates:**

**File:** `tests/Makefile`

**Add new targets:**

```makefile
# HPC Runtime Tests (consolidated)
test-hpc-runtime:
 @./test-hpc-runtime-framework.sh

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
 @./test-hpc-packer-controller-framework.sh

test-hpc-packer-compute:
 @./test-hpc-packer-compute-framework.sh
```

**Update main targets:**

```makefile
test: \
  test-integration \
  test-ansible-roles \
  test-hpc-runtime \
  test-container-registry

test-all: \
  test-base-images \
  test-hpc-packer-controller \
  test-hpc-packer-compute \
  test-hpc-runtime \
  test-container-registry \
  test-pcie-passthrough \
  test-ansible-roles \
  test-integration
```

**Remove old targets (all variants):**

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

**Additional Updates:**

- Update `tests/README.md` with new framework structure
- Remove references to old frameworks in documentation
- Add migration notes for users of old test commands

**Validation Criteria:**

- [ ] All new Makefile targets work correctly
- [ ] Old targets removed from Makefile
- [ ] All 25 obsolete files deleted
- [ ] No broken references to deleted files
- [ ] tests/README.md updated
- [ ] Documentation reflects new structure

**Test Commands:**

```bash
# Test new Makefile targets
cd tests
make test-hpc-runtime
make test-hpc-packer-controller
make test-hpc-packer-compute
make test-all

# Verify no references to old frameworks
grep -r "test-cgroup-isolation-framework" . --exclude-dir=.git
grep -r "test-gpu-gres-framework" . --exclude-dir=.git
```

---

---

## Expected Outcomes

**Ansible Playbooks:**

- 3 playbooks replace 10+ old playbooks
- Clear distinction: 2 Packer + 1 runtime
- Role modular task inclusion
- GPU-conditional execution

**Test Frameworks:**

- 3 frameworks replace 15+ old frameworks
- Standard CLI pattern
- Test suite orchestration
- Makefile targets

**Files Deleted:**

- 9 obsolete Ansible playbooks
- 13 obsolete test frameworks
- 10 obsolete test configurations
- 2 obsolete helper scripts
- **Total: 34 files removed**

## Next Phase

→ [Phase 6: Final Validation](phase-6-validation.md)

## Related Documentation

- [Reference: Testing Framework Patterns](../reference/testing-framework.md)
- [Reference: Infrastructure Summary](../reference/infrastructure-summary.md)
