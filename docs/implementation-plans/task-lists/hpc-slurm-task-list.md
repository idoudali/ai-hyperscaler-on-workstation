# HPC SLURM Deployment - Individual Task List

**Objective:** Break down HPC SLURM deployment into granular, self-contained tasks for individual execution and testing.

**Status:** Task Breakdown Complete  
**Updated:** 2025-01-27  
**Total Tasks:** 20 individual tasks across 4 phases

## Overview

This document provides a detailed breakdown of the HPC SLURM deployment implementation plan into individual,
testable tasks that can be executed independently by junior software engineers or coding agents. Each task
includes specific deliverables, validation criteria, and clear dependencies.

## Task Execution Principles

- **Self-Contained**: Each task can be developed and tested independently
- **Clear Dependencies**: Explicit prerequisite relationships between tasks
- **Testable Outcomes**: Specific validation criteria and test commands
- **Incremental Progress**: System functionality builds progressively
- **Rollback Safety**: Failed tasks don't break previous working components

## Phase 1: Core Infrastructure Setup (Tasks 001-012)

### Container Runtime Foundation

#### Task 001: Extend Ansible Role Structure for Container Support

- **ID**: TASK-001
- **Phase**: 1 - Infrastructure
- **Dependencies**: None
- **Estimated Time**: 2 hours
- **Difficulty**: Junior

**Description:**
Create the extended Ansible role directory structure to support container-based HPC deployment.

**Deliverables:**

- `ansible/roles/container-runtime/` directory structure
- `ansible/roles/slurm-controller/` directory structure  
- `ansible/roles/slurm-compute/` directory structure
- `ansible/roles/ml-container-images/` directory structure
- Proper subdirectories: `tasks/`, `templates/`, `defaults/`, `handlers/`, `vars/`, `files/`

**Validation Criteria:**

- [ ] All required role directories exist
- [ ] Each role has proper subdirectory structure
- [ ] Directory permissions are correct (755 for directories)
- [ ] Initial placeholder files created (main.yml in tasks/ and defaults/)

**Test Commands:**

```bash
# Verify directory structure
find ansible/roles -type d -name "container-runtime" -o -name "slurm-controller" -o -name "slurm-compute" -o -name "ml-container-images"

# Check subdirectory structure
for role in container-runtime slurm-controller slurm-compute ml-container-images; do
  ls -la ansible/roles/$role/
done

# Validate main.yml files exist
find ansible/roles -name "main.yml" | grep -E "(tasks|defaults)"
```

**Success Criteria:**

- Directory structure matches the specification in hpc-slurm-deployment.md section 2.1
- All placeholder files are syntactically valid YAML
- Ansible can discover and list the new roles

---

#### Task 002: Create Container Runtime Ansible Role

- **ID**: TASK-002
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-001
- **Estimated Time**: 4 hours
- **Difficulty**: Junior-Intermediate

**Description:**
Implement Singularity/Apptainer container runtime installation with proper dependency management.

**Deliverables:**

- `ansible/roles/container-runtime/tasks/main.yml` - Main orchestration
- `ansible/roles/container-runtime/tasks/singularity.yml` - Singularity installation
- `ansible/roles/container-runtime/tasks/security.yml` - Security policies
- `ansible/roles/container-runtime/defaults/main.yml` - Default variables

**Implementation Details:**

```yaml
# Key packages to install
required_packages:
  - fuse                    # FUSE filesystem support
  - squashfs-tools         # SquashFS utilities
  - uidmap                 # User namespace mapping
  - wget                   # Download utilities
  - build-essential        # Compilation tools
```

**Validation Criteria:**

- [ ] Singularity/Apptainer binary installed and functional
- [ ] All dependencies (fuse, squashfs-tools, uidmap) installed
- [ ] Container can execute simple commands
- [ ] Version check returns expected output

**Test Commands:**

```bash
# Check installation
singularity --version
apptainer --version

# Test basic functionality
singularity exec docker://hello-world echo "Container runtime working"

# Verify dependencies
dpkg -l | grep -E "(fuse|squashfs-tools|uidmap)"
```

**Success Criteria:**

- Singularity/Apptainer version >= 1.2.0
- Can pull and execute Docker containers
- No permission errors during container execution

---

#### Task 003: Configure Container Security Policies

- **ID**: TASK-003
- **Phase**: 1 - Infrastructure  
- **Dependencies**: TASK-002
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate

**Description:**
Create and deploy container security configuration to prevent privilege escalation and ensure proper isolation.

**Deliverables:**

- `ansible/roles/container-runtime/templates/singularity.conf.j2`
- `ansible/roles/container-runtime/tasks/security.yml`
- Security policy validation tests

**Security Configuration:**

```ini
# Key security settings
allow suid = no
allow pid ns = yes
config passwd = yes
config group = yes
config resolv_conf = yes
mount proc = yes
mount sys = yes
mount dev = yes
mount home = yes
mount tmp = yes
mount hostfs = no
bind path = /etc/localtime
bind path = /etc/hosts
user bind control = yes
enable overlay = yes
enable underlay = no
mount slave = yes
sessiondir max size = 16
allow container squashfs = yes
allow container extfs = yes
allow container dir = yes
limit container owners = null
limit container groups = null
allow container encrypted = yes
allow net users = null
allow net groups = null
allow net networks = null
always use nv = no
root default capabilities = full
```

**Validation Criteria:**

- [ ] Configuration file deployed to `/etc/singularity/singularity.conf`
- [ ] Security policies prevent SUID execution
- [ ] Container cannot access host root filesystem
- [ ] User namespace isolation working

**Test Commands:**

```bash
# Test security policies
singularity exec docker://ubuntu:20.04 whoami
singularity exec docker://ubuntu:20.04 ls /root  # Should fail
singularity exec docker://ubuntu:20.04 mount     # Should show limited mounts

# Verify configuration
cat /etc/singularity/singularity.conf | grep -E "(allow suid|mount hostfs)"
```

**Success Criteria:**

- Container cannot escalate privileges
- Host filesystem properly isolated
- Configuration passes security audit

---

### SLURM Controller Foundation

#### Task 004: Create SLURM Controller Installation Task

- **ID**: TASK-004
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-001
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate

**Description:**
Install SLURM controller packages with PMIx support and all required dependencies.

**Deliverables:**

- `ansible/roles/slurm-controller/tasks/install.yml`
- `ansible/roles/slurm-controller/defaults/main.yml`
- Package installation validation

**Required Packages:**

```yaml
slurm_controller_packages:
  - slurm-wlm              # Core SLURM workload manager
  - slurm-wlm-doc          # Documentation
  - slurmdbd               # Database daemon for accounting
  - slurm-client           # Client tools
  - munge                  # Authentication daemon
  - libmunge-dev           # Development libraries
  - mariadb-server         # Database backend
  - libmariadb-dev         # Database client libraries
  - libpmix2               # PMIx for MPI integration
  - libpmix-dev            # PMIx development headers
```

**Validation Criteria:**

- [ ] All SLURM packages installed successfully
- [ ] PMIx libraries available
- [ ] MariaDB server installed and running
- [ ] MUNGE authentication service available

**Test Commands:**

```bash
# Verify SLURM installation
slurmctld -V
slurmdbd -V
sinfo --version

# Check PMIx support
ls /usr/lib/x86_64-linux-gnu/libpmix*

# Verify database
systemctl status mariadb
mysql --version

# Check MUNGE
systemctl status munge
mungekey --version
```

**Success Criteria:**

- SLURM version >= 21.08
- PMIx libraries version >= 2.0
- MariaDB service active and running
- All package dependencies resolved

---

#### Task 005: Configure SLURM PMIx Integration

- **ID**: TASK-005
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-004
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate-Advanced

**Description:**
Create SLURM configuration template with PMIx integration and MPI support.

**Deliverables:**

- `ansible/roles/slurm-controller/templates/slurm.conf.j2`
- PMIx configuration parameters
- MPI integration validation

**Key Configuration Settings:**

```ini
# MPI Integration (PMIx Compliant)
MpiDefault=pmix
MpiParams=ports=12000-12999

# Resource Management
GresTypes=gpu
SelectType=select/cons_tres
SelectTypeParameters=CR_Core_Memory

# Process Tracking
ProctrackType=proctrack/cgroup
TaskPlugin=task/cgroup,task/affinity
TaskPluginParam=Sched
```

**Validation Criteria:**

- [ ] slurm.conf contains PMIx configuration
- [ ] MPI port range properly configured
- [ ] Resource management settings correct
- [ ] Configuration syntax valid

**Test Commands:**

```bash
# Validate configuration syntax
slurmctld -D -vvv  # Dry run with verbose output

# Check PMIx support
srun --mpi=list | grep pmix

# Verify configuration values
grep -E "(MpiDefault|MpiParams|GresTypes)" /etc/slurm/slurm.conf
```

**Success Criteria:**

- SLURM accepts configuration without errors
- PMIx listed as available MPI implementation
- Port range 12000-12999 reserved for MPI

---

#### Task 006: Set Up MUNGE Authentication

- **ID**: TASK-006
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-004
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate

**Description:**
Configure MUNGE authentication system for secure SLURM communication across cluster nodes.

**Deliverables:**

- `ansible/roles/slurm-controller/tasks/munge.yml`
- MUNGE key generation and distribution
- Service configuration and startup

**Implementation Steps:**

1. Generate MUNGE key on controller
2. Distribute key to all cluster nodes
3. Configure MUNGE service
4. Start and enable MUNGE daemon

**Validation Criteria:**

- [ ] MUNGE key generated and distributed
- [ ] MUNGE service running on all nodes
- [ ] Authentication working between nodes
- [ ] Proper file permissions (600 for munge.key)

**Test Commands:**

```bash
# Check MUNGE service
systemctl status munge

# Test authentication
munge -n | unmunge
echo "test" | munge | ssh compute-node unmunge

# Verify key permissions
ls -la /etc/munge/munge.key
```

**Success Criteria:**

- MUNGE service active on all nodes
- Cross-node authentication successful
- Key file has correct ownership (munge:munge) and permissions (600)

---

#### Task 007: Configure SLURM Container Plugin

- **ID**: TASK-007
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-003, TASK-005
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate-Advanced

**Description:**
Set up SLURM container plugin integration for Singularity/Apptainer container execution.

**Deliverables:**

- `ansible/roles/slurm-controller/templates/plugstack.conf.j2`
- `ansible/roles/slurm-controller/templates/container.conf.j2`
- Container plugin validation

**Configuration Files:**

```ini
# plugstack.conf
include /etc/slurm/container.conf

# container.conf
required=/usr/lib/x86_64-linux-gnu/slurm-wlm/container_singularity.so

[singularity]
runtime_path=/usr/bin/singularity
enable_overlay=true
enable_gpu=true
enable_nv=true
mount_home=true
mount_tmp=true
image_path=/opt/containers
allow_suid=false
contain=true
writable=false
```

**Validation Criteria:**

- [ ] Container plugin configuration files created
- [ ] Singularity plugin library exists
- [ ] SLURM can load container plugin
- [ ] Container execution parameters correct

**Test Commands:**

```bash
# Verify plugin library
ls -la /usr/lib/x86_64-linux-gnu/slurm-wlm/container_singularity.so

# Check configuration syntax
slurmctld -D -vvv | grep -i container

# Test container plugin loading
grep -i "container" /var/log/slurm/slurmctld.log
```

**Success Criteria:**

- Container plugin loads without errors
- SLURM recognizes container execution capabilities
- Configuration passes validation checks

---

### Infrastructure Enhancement

#### Task 008: Enhance Inventory Generator for GPU Detection

- **ID**: TASK-008
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-001
- **Estimated Time**: 6 hours
- **Difficulty**: Intermediate-Advanced

**Description:**
Extend the Python inventory generator to detect PCIe passthrough GPUs and generate proper SLURM GRES configuration.

**Deliverables:**

- Enhanced `ansible/inventories/generate_inventory.py`
- GPU detection and mapping logic
- GRES configuration generation
- Validation tests for inventory generation

**Key Enhancements:**

```python
def detect_gpu_resources(self, node_config):
    """Detect GPU resources via PCIe passthrough configuration"""
    gpu_devices = []
    if node_config.get('pcie_passthrough', {}).get('enabled', False):
        for device in node_config['pcie_passthrough']['devices']:
            if device['device_type'] == 'gpu':
                gpu_devices.append({
                    'device_id': device['device_id'],
                    'vendor': device.get('vendor', 'nvidia'),
                    'memory': device.get('memory', 'unknown')
                })
    return gpu_devices

def generate_gres_config(self, gpu_devices, node_name):
    """Generate GRES configuration for GPU resources"""
    gres_config = []
    for i, gpu in enumerate(gpu_devices):
        gres_config.append(f"NodeName={node_name} Name=gpu Type={gpu['device_id']} File=/dev/nvidia{i}")
    return gres_config
```

**Validation Criteria:**

- [ ] Script detects GPU devices from cluster.yaml
- [ ] GRES configuration generated correctly
- [ ] Inventory includes GPU-specific variables
- [ ] Output validates against SLURM configuration requirements

**Test Commands:**

```bash
# Run inventory generator
cd ansible/inventories
python3 generate_inventory.py

# Verify GPU detection
grep -A5 -B5 "gpu" inventories/hpc/hosts.yml

# Check GRES configuration
grep "slurm_gres" inventories/hpc/hosts.yml

# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('inventories/hpc/hosts.yml'))"
```

**Success Criteria:**

- GPU nodes correctly identified in inventory
- GRES configuration matches PCIe passthrough setup
- Inventory passes YAML validation
- Generated configuration compatible with SLURM

---

### Monitoring Infrastructure

#### Task 009: Install Prometheus Monitoring Stack

- **ID**: TASK-009
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-001
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate

**Description:**
Install and configure Prometheus monitoring system for HPC cluster metrics collection.

**Deliverables:**

- `ansible/roles/monitoring-stack/tasks/prometheus.yml`
- Prometheus configuration template
- Node exporter installation
- Basic monitoring setup

**Required Components:**

```yaml
prometheus_packages:
  - prometheus              # Metrics collection server
  - prometheus-node-exporter # System metrics
  - alertmanager           # Alert routing
```

**Validation Criteria:**

- [ ] Prometheus server installed and running
- [ ] Node exporters running on all nodes
- [ ] Basic system metrics being collected
- [ ] Prometheus web UI accessible

**Test Commands:**

```bash
# Check Prometheus service
systemctl status prometheus
curl http://localhost:9090/api/v1/query?query=up

# Verify node exporters
systemctl status prometheus-node-exporter
curl http://localhost:9100/metrics | head -20

# Test metrics collection
curl http://localhost:9090/api/v1/query?query=node_cpu_seconds_total
```

**Success Criteria:**

- Prometheus service active and healthy
- Node metrics visible in Prometheus UI
- All cluster nodes reporting metrics
- No configuration errors in logs

---

#### Task 010: Set Up Grafana Dashboard Platform

- **ID**: TASK-010
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-009
- **Estimated Time**: 3 hours
- **Difficulty**: Intermediate

**Description:**
Install Grafana and create basic system monitoring dashboard for HPC cluster visualization.

**Deliverables:**

- Grafana installation and configuration
- Prometheus data source configuration
- Basic system dashboard
- Dashboard access and security

**Dashboard Components:**

- CPU utilization by node
- Memory usage statistics
- Network I/O metrics
- System load averages
- Node availability status

**Validation Criteria:**

- [ ] Grafana service running and accessible
- [ ] Prometheus data source configured
- [ ] Basic dashboard displaying metrics
- [ ] Authentication working properly

**Test Commands:**

```bash
# Check Grafana service
systemctl status grafana-server
curl http://localhost:3000/api/health

# Test data source connection
curl -u admin:admin http://localhost:3000/api/datasources

# Verify dashboard
curl -u admin:admin http://localhost:3000/api/dashboards/home
```

**Success Criteria:**

- Grafana UI accessible on port 3000
- Prometheus data source connected and working
- System metrics visible in dashboard
- No authentication or connection errors

---

#### Task 011: Configure SLURM Job Accounting

- **ID**: TASK-011
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-004, TASK-006
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate-Advanced

**Description:**
Set up SLURM job accounting with MariaDB backend for comprehensive job metrics and resource usage tracking.

**Deliverables:**

- `ansible/roles/slurm-controller/tasks/accounting.yml`
- MariaDB database setup for SLURM accounting
- slurmdbd configuration
- Job accounting validation

**Configuration Components:**

```ini
# slurm.conf additions
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost=controller
AccountingStoragePort=6819
JobAcctGatherType=jobacct_gather/linux
JobAcctGatherParams=UsePss,NoOverMemoryKill
```

**Database Setup:**

- Create `slurm_acct_db` database
- Configure slurmdbd user and permissions
- Set up accounting tables

**Validation Criteria:**

- [ ] MariaDB configured for SLURM accounting
- [ ] slurmdbd service running and connected
- [ ] Job accounting data being collected
- [ ] sacct command returns job information

**Test Commands:**

```bash
# Check slurmdbd service
systemctl status slurmdbd

# Test database connection
mysql -u slurm -p slurm_acct_db -e "SHOW TABLES;"

# Verify job accounting
sacct --format=JobID,JobName,Partition,Account,AllocCPUS,State,ExitCode
squeue -o "%18i %12j %4t %10u %20q %20a %10g %20S %20e %8D %20R"

# Check accounting configuration
scontrol show config | grep -i accounting
```

**Success Criteria:**

- slurmdbd connects to MariaDB successfully
- Job submission creates accounting records
- sacct shows historical job information
- Resource usage metrics collected

---

#### Task 012: Deploy DCGM GPU Monitoring

- **ID**: TASK-012
- **Phase**: 1 - Infrastructure
- **Dependencies**: TASK-009
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate

**Description:**
Install and configure NVIDIA DCGM (Data Center GPU Manager) for GPU metrics collection and Prometheus integration.

**Deliverables:**

- `ansible/roles/monitoring-stack/tasks/dcgm.yml`
- DCGM exporter configuration
- GPU metrics collection setup
- Prometheus GPU metrics integration

**Required Components:**

```yaml
dcgm_packages:
  - nvidia-dcgm            # Data Center GPU Manager
  - dcgm-exporter         # GPU Prometheus exporter
```

**Validation Criteria:**

- [ ] DCGM service running on GPU nodes
- [ ] GPU metrics exported to Prometheus
- [ ] GPU utilization and memory metrics visible
- [ ] No GPU monitoring errors

**Test Commands:**

```bash
# Check DCGM service
systemctl status nvidia-dcgm
dcgmi discovery -l

# Verify GPU metrics export
curl http://localhost:9400/metrics | grep -i gpu

# Test GPU monitoring
nvidia-smi
dcgmi dmon -e 155,204,1001,1002,1003,1004,1005,1006,1007,1008,1009,1010

# Check Prometheus integration
curl http://localhost:9090/api/v1/query?query=dcgm_gpu_utilization
```

**Success Criteria:**

- DCGM discovers all GPU devices
- GPU metrics available in Prometheus
- Utilization and memory metrics accurate
- No GPU communication errors

---

## Phase 2: Container Images & Compute Integration (Tasks 013-020)

### Container Image Development

#### Task 013: Create PyTorch Container Definition

- **ID**: TASK-013
- **Phase**: 2 - Container Development
- **Dependencies**: TASK-003
- **Estimated Time**: 6 hours
- **Difficulty**: Intermediate-Advanced

**Description:**
Write Singularity definition file for PyTorch+MPI container with CUDA support and monitoring tools.

**Deliverables:**

- `ansible/roles/ml-container-images/templates/pytorch-mpi.def.j2`
- Container requirements specification
- Build environment configuration
- Container validation tests

**Container Components:**

- NVIDIA CUDA 12.1 base image
- Python 3.10 with PyTorch >= 2.0
- Open MPI 4.1.4 with PMIx support
- Monitoring tools (tensorboard, wandb, nvitop)
- Development and debugging tools

**Key Software Stack:**

```bash
# Base: nvidia/cuda:12.1-devel-ubuntu22.04
# PyTorch: torch>=2.0.0+cu121
# MPI: OpenMPI 4.1.4 with CUDA and PMIx support
# Tools: tensorboard, wandb, nvitop, py-spy, memory-profiler
```

**Validation Criteria:**

- [ ] Singularity definition file syntactically correct
- [ ] All required software components included
- [ ] CUDA and PyTorch integration working
- [ ] MPI functionality validated

**Test Commands:**

```bash
# Validate definition syntax
singularity build --dry-run pytorch-test.sif pytorch-mpi.def

# Check template rendering
ansible-playbook -i localhost, --check --diff test-container-template.yml

# Verify required components listed
grep -E "(pytorch|openmpi|cuda)" pytorch-mpi.def
```

**Success Criteria:**

- Definition file passes Singularity syntax validation
- Template variables properly configured
- All required dependencies specified
- Build instructions complete and accurate

---

#### Task 014: Automate Container Image Building

- **ID**: TASK-014
- **Phase**: 2 - Container Development
- **Dependencies**: TASK-013
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate

**Description:**
Create Ansible tasks to automatically build Singularity container images from definition files with validation.

**Deliverables:**

- `ansible/roles/ml-container-images/tasks/pytorch-mpi.yml`
- Container build automation
- Image validation tests
- Build artifact management

**Build Process:**

1. Render Singularity definition from template
2. Execute container build with proper permissions
3. Validate container functionality
4. Store image in registry location

**Validation Criteria:**

- [ ] Container builds successfully without errors
- [ ] Built image passes functionality tests
- [ ] Image stored in correct registry location
- [ ] Build process is repeatable

**Test Commands:**

```bash
# Test build process
ansible-playbook -i inventories/hpc/hosts.yml build-containers.yml --limit controller

# Verify built image
ls -la /opt/containers/pytorch-mpi-*.sif

# Test container functionality
singularity exec /opt/containers/pytorch-mpi-*.sif python3 -c "import torch; print(torch.__version__)"
singularity exec /opt/containers/pytorch-mpi-*.sif mpirun --version
```

**Success Criteria:**

- Container builds without compilation errors
- PyTorch and CUDA functional in container
- MPI communication working
- Image size reasonable (<5GB for base image)

---

#### Task 015: Set Up Container Image Registry

- **ID**: TASK-015
- **Phase**: 2 - Container Development
- **Dependencies**: TASK-014
- **Estimated Time**: 3 hours
- **Difficulty**: Junior-Intermediate

**Description:**
Create shared directory structure and permissions system for container image distribution across cluster.

**Deliverables:**

- Container registry directory structure
- Proper permissions and ownership
- Image distribution mechanism
- Registry management tools

**Registry Structure:**

```text
/opt/containers/
├── pytorch-mpi-2.0-mpi4.1.4.sif
├── pytorch-mpi-2.1-mpi4.1.4.sif
├── base-images/
├── custom-images/
└── registry.yaml (metadata)
```

**Validation Criteria:**

- [ ] Registry directory created with correct permissions
- [ ] All cluster nodes can access registry
- [ ] Image metadata tracking working
- [ ] Version management functional

**Test Commands:**

```bash
# Check registry structure
ls -la /opt/containers/

# Verify permissions
stat -c "%a %U:%G" /opt/containers/

# Test access from compute nodes
ansible slurm_compute -i inventories/hpc/hosts.yml -m shell -a "ls /opt/containers/"

# Validate image accessibility
singularity exec /opt/containers/pytorch-mpi-*.sif echo "Registry access working"
```

**Success Criteria:**

- All nodes can read from registry
- Proper ownership (root:slurm) and permissions (755)
- Images accessible for container execution
- Registry structure supports versioning

---

### Compute Node Integration

#### Task 016: Create SLURM Compute Node Installation

- **ID**: TASK-016
- **Phase**: 2 - Compute Integration
- **Dependencies**: TASK-002, TASK-006
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate

**Description:**
Install SLURM compute node components with container runtime integration.

**Deliverables:**

- `ansible/roles/slurm-compute/tasks/install.yml`
- Compute node package installation
- Service configuration
- Node registration with controller

**Required Packages:**

```yaml
slurm_compute_packages:
  - slurmd                 # SLURM daemon
  - slurm-client          # Client tools
  - munge                 # Authentication
  - libmunge2             # Runtime libraries
  - libpmix2              # PMIx runtime
  - singularity-container # Container runtime (if available)
```

**Validation Criteria:**

- [ ] All compute packages installed successfully
- [ ] slurmd service configured and running
- [ ] Node communicates with controller
- [ ] Container runtime available

**Test Commands:**

```bash
# Check slurmd service
systemctl status slurmd

# Verify node registration
sinfo -N -l | grep compute

# Test SLURM communication
srun --nodes=1 --ntasks=1 hostname

# Verify container availability
singularity --version
```

**Success Criteria:**

- slurmd service active on all compute nodes
- Nodes show as available in sinfo output
- Can execute simple jobs on compute nodes
- Container runtime functional

---

#### Task 017: Configure GPU Resources (GRES)

- **ID**: TASK-017
- **Phase**: 2 - Compute Integration
- **Dependencies**: TASK-008, TASK-016
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate-Advanced

**Description:**
Create GRES configuration for GPU resource management and scheduling in SLURM.

**Deliverables:**

- `ansible/roles/slurm-compute/templates/gres.conf.j2`
- GPU device mapping configuration
- NVML auto-detection setup
- GPU resource validation

**GRES Configuration Example:**

```ini
# Manual GPU configuration
NodeName=compute-01 Name=gpu Type=rtx4090 File=/dev/nvidia0
NodeName=compute-01 Name=gpu Type=rtx4090 File=/dev/nvidia1

# Auto-detection alternative
NodeName=compute-01 AutoDetect=nvml
```

**Validation Criteria:**

- [ ] GRES configuration deployed to compute nodes
- [ ] GPU devices properly mapped
- [ ] SLURM recognizes GPU resources
- [ ] GPU scheduling functional

**Test Commands:**

```bash
# Check GRES configuration
cat /etc/slurm/gres.conf

# Verify GPU detection
sinfo -o "%20N %10c %10m %25f %10G %6t"

# Test GPU job submission
srun --gres=gpu:1 nvidia-smi

# Validate resource allocation
scontrol show node compute-01 | grep -i gres
```

**Success Criteria:**

- GPU resources visible in sinfo output
- Can submit jobs requesting GPU resources
- GPU allocation prevents conflicts
- Resource counts match physical hardware

---

#### Task 018: Set Up Cgroup Resource Isolation

- **ID**: TASK-018
- **Phase**: 2 - Compute Integration
- **Dependencies**: TASK-016
- **Estimated Time**: 4 hours
- **Difficulty**: Intermediate-Advanced

**Description:**
Configure cgroup-based resource isolation for CPU, memory, and GPU device access control.

**Deliverables:**

- `ansible/roles/slurm-compute/templates/cgroup.conf.j2`
- Cgroup hierarchy setup
- Resource limit enforcement
- Device isolation configuration

**Cgroup Configuration:**

```ini
CgroupAutomount=yes
CgroupReleaseAgentDir="/etc/slurm/cgroup"
ConstrainCores=yes
ConstrainDevices=yes
ConstrainRAMSpace=yes
ConstrainSwapSpace=no
TaskAffinity=yes
AllowedDevicesFile="/etc/slurm/cgroup_allowed_devices_file.conf"
```

**Validation Criteria:**

- [ ] Cgroup configuration deployed and active
- [ ] Resource constraints enforced
- [ ] GPU device isolation working
- [ ] Jobs cannot exceed allocated resources

**Test Commands:**

```bash
# Check cgroup configuration
cat /etc/slurm/cgroup.conf

# Verify cgroup mounting
mount | grep cgroup

# Test resource isolation
srun --mem=1G --cpus-per-task=1 stress --vm 1 --vm-bytes 2G --timeout 10s  # Should fail

# Check device constraints
srun --gres=gpu:1 nvidia-smi -L | wc -l  # Should show 1 GPU
```

**Success Criteria:**

- Jobs respect memory and CPU limits
- GPU access properly isolated
- Resource oversubscription prevented
- Cgroup hierarchy properly structured

---

#### Task 019: Create Failure Detection Scripts

- **ID**: TASK-019
- **Phase**: 2 - Compute Integration
- **Dependencies**: TASK-011
- **Estimated Time**: 6 hours
- **Difficulty**: Advanced

**Description:**
Implement SLURM epilog/prolog scripts for job completion analysis and distributed training failure debugging.

**Deliverables:**

- `/etc/slurm/epilog.sh` - Job completion analysis
- `/etc/slurm/prolog.sh` - Job initialization checks
- `/opt/slurm/bin/diagnose_training_failure.py` - Failure diagnosis tool
- Failure analysis automation

**Script Functionality:**

- GPU utilization tracking at job completion
- Container execution validation
- MPI communication health checks
- Distributed training environment validation
- Automated failure pattern detection

**Validation Criteria:**

- [ ] Epilog/prolog scripts execute on job events
- [ ] Failure diagnosis captures relevant information
- [ ] Debug information stored in structured format
- [ ] Common failure patterns detected automatically

**Test Commands:**

```bash
# Test epilog execution
srun --job-name=test-epilog echo "Testing epilog"
grep "test-epilog" /var/log/slurm/job_metrics.log

# Verify prolog execution
srun --job-name=test-prolog echo "Testing prolog"

# Test failure diagnosis
python3 /opt/slurm/bin/diagnose_training_failure.py

# Check debug directory creation
ls -la /var/log/slurm/debug/
```

**Success Criteria:**

- Scripts execute without errors on job events
- Failure diagnosis captures comprehensive system state
- Debug information helps identify common issues
- Automation reduces manual debugging time

---

#### Task 020: Create Container Validation Tests

- **ID**: TASK-020
- **Phase**: 2 - Integration Validation
- **Dependencies**: TASK-015, TASK-017, TASK-018
- **Estimated Time**: 5 hours
- **Difficulty**: Intermediate-Advanced

**Description:**
Implement comprehensive validation tests for PyTorch CUDA, MPI functionality, and GPU access within containers.

**Deliverables:**

- Container functionality test suite
- PyTorch distributed training validation
- GPU access and utilization tests
- MPI communication verification

**Test Categories:**

1. **Basic Container Functionality**
   - Container execution and environment
   - Python and package availability
   - File system access and permissions

2. **PyTorch and CUDA Validation**
   - PyTorch installation and version
   - CUDA availability and device detection
   - GPU memory allocation and computation

3. **MPI Communication Tests**
   - MPI library functionality
   - Multi-process communication
   - PMIx integration validation

4. **Distributed Training Simulation**
   - Multi-node container coordination
   - Environment variable propagation
   - NCCL backend functionality

**Validation Criteria:**

- [ ] All container functionality tests pass
- [ ] PyTorch can utilize GPUs within containers
- [ ] MPI communication works across container instances
- [ ] Distributed training environment properly configured

**Test Commands:**

```bash
# Run comprehensive validation
ansible-playbook -i inventories/hpc/hosts.yml validate-containers.yml

# Test PyTorch CUDA in container
srun --gres=gpu:1 --container-image=/opt/containers/pytorch-mpi-*.sif \
  python3 -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"

# Test MPI across nodes
srun --nodes=2 --ntasks=4 --container-image=/opt/containers/pytorch-mpi-*.sif \
  python3 -c "from mpi4py import MPI; print(f'Rank {MPI.COMM_WORLD.Get_rank()}')"

# Validate distributed training setup
srun --nodes=2 --ntasks-per-node=1 --gres=gpu:1 \
  --container-image=/opt/containers/pytorch-mpi-*.sif \
  python3 /opt/test-scripts/validate_distributed_pytorch.py
```

**Success Criteria:**

- Container tests pass on all node types
- PyTorch detects and utilizes GPUs correctly
- MPI processes communicate across nodes
- Distributed training environment variables set correctly
- No container execution or permission errors

---

## Task Dependencies and Execution Order

### Phase 1 Execution Flow

```text
TASK-001 → TASK-002 → TASK-003
    ↓         ↓
TASK-004 → TASK-005 → TASK-006 → TASK-007
    ↓
TASK-008
    ↓
TASK-009 → TASK-010
    ↓         ↓
TASK-011   TASK-012
```

### Phase 2 Execution Flow

```text
TASK-013 → TASK-014 → TASK-015
    ↓
TASK-016 → TASK-017 → TASK-018 → TASK-019
    ↓                     ↓         ↓
TASK-020 ←←←←←←←←←←←←←←←←←←←←←←←←←
```

## Success Metrics

### Individual Task Success

- **Technical Validation**: All test commands pass
- **Integration Testing**: Task output works with dependent tasks
- **Documentation**: Deliverables match specifications
- **Repeatability**: Task can be executed multiple times safely

### Overall Implementation Success

- **Functional SLURM Cluster**: All nodes active and job scheduling working
- **Container Integration**: Containerized jobs execute successfully
- **GPU Scheduling**: GPU resources properly allocated and utilized
- **Monitoring Active**: Metrics collection and alerting functional
- **Failure Detection**: Automated debugging and analysis working

## Testing Framework

Each task includes:

- **Unit Tests**: Individual component validation
- **Integration Tests**: Cross-component functionality
- **System Tests**: End-to-end workflow validation
- **Performance Tests**: Resource utilization and scaling

## Documentation and Handoff

For each completed task:

- **Implementation Notes**: Decisions made and alternatives considered
- **Configuration Files**: All templates and configuration artifacts
- **Test Results**: Validation output and performance metrics
- **Troubleshooting Guide**: Common issues and resolution steps
- **Next Steps**: Recommendations for dependent tasks

This task breakdown provides a comprehensive roadmap for implementing the HPC SLURM deployment with clear,
testable milestones that can be executed independently by junior engineers or automated systems.
