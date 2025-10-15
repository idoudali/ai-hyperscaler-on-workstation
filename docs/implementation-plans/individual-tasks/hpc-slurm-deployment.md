# HPC SLURM Deployment Implementation Plan

**Objective:** Implement a production-ready SLURM-based HPC cluster with
distributed PyTorch training support, following the architectural guidelines
from `pytorch-slurm-deployment.md` and integrating with the existing Python CLI
orchestrator.

**Status:** Planning Phase - Implementation Ready  
**Updated:** 2025-01-27  
**Dependencies:** Phase 0 Foundation (Complete), Golden Image Creation
(Complete), Python CLI Orchestrator (Complete)

## Overview

This implementation plan details the steps to deploy a fully functional HPC
cluster with SLURM workload manager, optimized for distributed PyTorch training
with GPU support. The implementation leverages existing infrastructure (Python
CLI, VM management, PCIe passthrough) and extends Ansible roles for
comprehensive cluster configuration.

## 1. PyTorch, Oumi, and ScalarLM Requirements

### 1.1 PyTorch Distributed Training Requirements

**Core Dependencies:**

- **PyTorch >= 2.0** with CUDA support and distributed training capabilities
- **NCCL >= 2.18** for optimized GPU communication (automatically included with
  PyTorch CUDA builds)
- **CUDA Toolkit >= 12.1** for GPU acceleration and compute capabilities
- **cuDNN >= 8.8** for optimized deep learning primitives
- **Python 3.9-3.11** with virtual environment support

**Environment Variable Contract (Section 1.1 Reference):**

```bash
# Required for torch.distributed.init_process_group()
export MASTER_ADDR="<controller-node-ip>"
export MASTER_PORT="29500"
export WORLD_SIZE="<total-gpu-count>"
export RANK="<global-process-rank>"
export LOCAL_RANK="<local-gpu-index>"
```

**Communication Backend Requirements:**

- **NCCL Backend:** Primary choice for NVIDIA GPU clusters with
  InfiniBand/Ethernet
- **Gloo Backend:** Fallback for CPU-only or development scenarios
- **Network Configuration:** Proper interface binding via `NCCL_SOCKET_IFNAME`

### 1.2 Oumi.ai Integration Requirements

**Platform Dependencies:**

- **oumi-launcher >= 0.5** Python package for SLURM integration
- **SSH connectivity** from client to SLURM head node
- **Shared filesystem** access for code synchronization and data
- **SLURM client tools** (sbatch, squeue, scancel, scontrol)

**Configuration Requirements:**

```python
# Example oumi client configuration
from oumi.launcher.clusters import SlurmCluster
from oumi.launcher.clients import SlurmClient

slurm_client = SlurmClient(
    hostname="hpc-controller",
    username="admin", 
    ssh_key_path="/path/to/ssh/key"
)

cluster = SlurmCluster(
    client=slurm_client,
    partition="gpu",
    account="default"
)
```

### 1.3 ScalarLM Integration Requirements

**Platform Dependencies:**

- **Megatron-LM framework** for large-scale language model training
- **vLLM >= 0.2** for optimized inference serving
- **ScalarLM API client** for job submission and management
- **Model registry integration** with shared storage backend

**API Integration:**

```python
# ScalarLM simplified interface
import scalarlm as slm

llm = slm.LLM(cluster="hpc")
llm.train(
    dataset="path/to/dataset",
    train_args={
        "gpus": 8,  # Automatically mapped to SLURM resources
        "model_size": "7B",
        "batch_size": 32
    }
)
```

## 2. SLURM and MPI Installation via Ansible

### 2.1 Enhanced Ansible Role Structure

**Extended Directory Structure (Container-Optimized):**

```bash
ansible/roles/
├── hpc-base-packages/          # Basic HPC packages (✅ IMPLEMENTED)
├── container-runtime/          # Singularity/Apptainer container runtime
│   ├── tasks/
│   │   ├── main.yml           # Container runtime setup
│   │   ├── singularity.yml    # Singularity installation
│   │   ├── security.yml       # Container security policies
│   │   └── integration.yml    # SLURM container integration
│   ├── templates/
│   │   ├── singularity.conf.j2 # Singularity configuration
│   │   └── container-hooks.j2  # Container execution hooks
│   └── defaults/
│       └── main.yml           # Runtime preferences
├── slurm-controller/           # SLURM controller configuration
│   ├── tasks/
│   │   ├── main.yml           # Controller setup orchestration
│   │   ├── install.yml        # SLURM package installation
│   │   ├── configure.yml      # Configuration file generation
│   │   ├── database.yml       # Accounting database setup
│   │   ├── containers.yml     # Container integration setup
│   │   └── services.yml       # Systemd service management
│   ├── templates/
│   │   ├── slurm.conf.j2      # Main SLURM configuration (PMIx-enabled)
│   │   ├── gres.conf.j2       # GPU resource configuration
│   │   ├── cgroup.conf.j2     # Resource isolation
│   │   ├── slurmdbd.conf.j2   # Database daemon config
│   │   └── container-template.sbatch.j2 # Container job template
│   ├── handlers/
│   │   └── main.yml           # Service restart handlers
│   ├── defaults/
│   │   └── main.yml           # Default variables
│   └── vars/
│       └── main.yml           # Role-specific variables
├── slurm-compute/              # SLURM compute node configuration
│   ├── tasks/
│   │   ├── main.yml           # Compute node setup
│   │   ├── install.yml        # SLURM daemon installation
│   │   ├── gpu.yml            # GPU resource configuration
│   │   ├── containers.yml     # Container runtime integration
│   │   └── services.yml       # Service management
│   ├── templates/
│   │   ├── gres.conf.j2       # Node-specific GPU config
│   │   ├── cgroup.conf.j2     # Resource limits
│   │   └── container-prolog.sh.j2 # Container setup script
│   └── defaults/
│       └── main.yml           # Compute defaults
└── ml-container-images/        # ML container image management
    ├── tasks/
    │   ├── main.yml           # Container image orchestration
    │   ├── pytorch-mpi.yml    # PyTorch+MPI image build
    │   ├── registry.yml       # Container registry setup
    │   └── deployment.yml     # Image deployment
    ├── templates/
    │   ├── pytorch-mpi.def.j2 # Singularity definition file
    │   └── container-wrapper.sh.j2 # Container execution wrapper
    ├── files/
    │   ├── pytorch-requirements.txt # Python dependencies
    │   └── mpi-test.py        # MPI validation script
    └── defaults/
        └── main.yml           # Container image configuration
```

### 2.2 SLURM Installation Strategy (SLURM Documentation Compliant)

**PMIx-Enabled SLURM Installation:**

```yaml
# slurm-controller/tasks/install.yml
- name: Install SLURM controller packages with PMIx support
  apt:
    name:
      - slurm-wlm                    # Core SLURM workload manager
      - slurm-wlm-doc                # Documentation
      - slurmdbd                     # Database daemon for accounting
      - slurm-client                 # Client tools
      - munge                        # Authentication daemon
      - libmunge-dev                 # Development libraries
      - mariadb-server               # Database backend
      - libmariadb-dev               # Database client libraries
      - libpmix2                     # PMIx for MPI integration
      - libpmix-dev                  # PMIx development headers
    state: present
    update_cache: yes

# slurm-compute/tasks/install.yml  
- name: Install SLURM compute packages with container support
  apt:
    name:
      - slurmd                       # SLURM daemon
      - slurm-client                 # Client tools
      - munge                        # Authentication
      - libmunge2                    # Runtime libraries
      - libpmix2                     # PMIx runtime
      - singularity-container        # Container runtime (if available)
    state: present
```

### 2.3 Container Runtime Integration Strategy

**Singularity/Apptainer for HPC Containers:**

```yaml
# container-runtime/tasks/singularity.yml
- name: Install Singularity/Apptainer container runtime
  block:
    - name: Add Singularity repository
      get_url:
        url: https://github.com/apptainer/apptainer/releases/download/v1.2.5/apptainer_1.2.5_amd64.deb
        dest: /tmp/apptainer.deb
        
    - name: Install Apptainer package
      apt:
        deb: /tmp/apptainer.deb
        state: present
        
    - name: Install container dependencies
      apt:
        name:
          - fuse                     # FUSE filesystem support
          - squashfs-tools           # SquashFS utilities
          - uidmap                   # User namespace mapping
        state: present

# container-runtime/tasks/integration.yml        
- name: Configure SLURM container integration
  lineinfile:
    path: /etc/slurm/plugstack.conf
    line: |
      # Container plugin configuration
      include /etc/slurm/container.conf
    create: yes

- name: Create SLURM container configuration
  template:
    src: container.conf.j2
    dest: /etc/slurm/container.conf
    owner: root
    group: slurm
    mode: '0644'
```

### 2.4 SLURM PMIx Configuration (Standards Compliant)

**PMIx Integration Following SLURM Documentation:**

```yaml
# slurm-controller/tasks/configure.yml
- name: Configure SLURM with PMIx support
  lineinfile:
    path: /etc/slurm/slurm.conf
    regexp: '^MpiDefault='
    line: 'MpiDefault=pmix'
    
- name: Enable PMIx plugins
  lineinfile:
    path: /etc/slurm/slurm.conf
    regexp: '^MpiParams='
    line: 'MpiParams=ports=12000-12999'
    
- name: Configure PMIx communication
  blockinfile:
    path: /etc/slurm/slurm.conf
    marker: "# {mark} PMIx Configuration"
    block: |
      # PMIx Configuration for MPI Jobs
      ProctrackType=proctrack/cgroup
      TaskPlugin=task/affinity,task/cgroup
      # Enable MPI job step tracking
      TaskPluginParam=Sched
```

## 3. Container-Based Package Deployment

### 3.1 Containerization Strategy

**Container-First Approach for ML Workloads:**

- **Host System**: Minimal SLURM + Container Runtime + GPU Drivers
- **ML Containers**: PyTorch + MPI + CUDA Stack + Training Dependencies
- **Job Execution**: SLURM launches containers with `srun --container-image=...`

### 3.2 Host System Preparation (Minimal)

**Phase 3.1: Base HPC Infrastructure**

```yaml
# hpc-base-packages/tasks/main.yml (Updated)
- name: Install minimal HPC system prerequisites  
  apt:
    name:
      # Core system utilities
      - build-essential
      - git
      - vim
      - tmux
      - htop
      - curl
      - wget
      - rsync
      
      # Network and filesystem
      - nfs-common                   # NFS client support
      - ssh
      - openssh-server
      
      # Hardware management
      - hwloc                        # Hardware locality
      - numactl                      # NUMA control utilities
      - pciutils                     # PCIe utilities
    state: present
```

**Phase 3.2: Container Runtime and SLURM**

```yaml
# No GPU software on host - only drivers and runtime
- name: Install container runtime prerequisites
  apt:
    name:
      - fuse                         # FUSE filesystem
      - squashfs-tools               # Container image tools
      - uidmap                       # User namespace mapping
    state: present
```

### 3.3 ML Container Image Definition

**PyTorch + MPI Container Specification:**

```singularity
# ml-container-images/templates/pytorch-mpi.def.j2
Bootstrap: docker
From: nvidia/cuda:12.1-devel-ubuntu22.04

%environment
    # CUDA Environment
    export CUDA_HOME=/usr/local/cuda
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
    
    # MPI Environment  
    export OMPI_ALLOW_RUN_AS_ROOT=1
    export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
    
    # PyTorch Distributed Environment
    export NCCL_DEBUG=INFO
    export NCCL_SOCKET_IFNAME=eth0

%post
    # Update system packages
    apt-get update && apt-get upgrade -y
    
    # Install system dependencies
    apt-get install -y \
        python3.10 python3.10-dev python3-pip \
        build-essential cmake ninja-build \
        libnuma-dev hwloc libhwloc-dev \
        wget curl git vim htop \
        openssh-client rsync
    
    # Install Open MPI {{ mpi_version | default('4.1.4') }}
    cd /tmp
    wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-{{ mpi_version | default('4.1.4') }}.tar.gz
    tar -xzf openmpi-{{ mpi_version | default('4.1.4') }}.tar.gz
    cd openmpi-{{ mpi_version | default('4.1.4') }}
    ./configure --prefix=/usr/local/openmpi \
                --with-cuda=/usr/local/cuda \
                --enable-mpirun-prefix-by-default \
                --with-pmix \
                --disable-getpwuid
    make -j$(nproc) && make install
    
    # Update environment for MPI
    echo 'export PATH=/usr/local/openmpi/bin:$PATH' >> /etc/environment
    echo 'export LD_LIBRARY_PATH=/usr/local/openmpi/lib:$LD_LIBRARY_PATH' >> /etc/environment
    
    # Install Python ML stack
    pip3 install --upgrade pip setuptools wheel
    pip3 install \
        torch>=2.0.0+cu121 torchvision torchaudio \
        --extra-index-url https://download.pytorch.org/whl/cu121
    
    # Install additional ML libraries
    pip3 install \
        transformers>=4.20.0 \
        datasets \
        accelerate \
        wandb \
        mpi4py \
        horovod[pytorch] \
        deepspeed
    
    # Install NCCL (latest)
    apt-get install -y libnccl2 libnccl-dev
    
    # Cleanup
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

%runscript
    # Default container execution
    exec python3 "$@"

%test
    # Container validation tests
    python3 -c "import torch; print(f'PyTorch: {torch.__version__}')"
    python3 -c "import torch; print(f'CUDA Available: {torch.cuda.is_available()}')"
    mpirun --version
    python3 -c "from mpi4py import MPI; print(f'MPI Rank: {MPI.COMM_WORLD.Get_rank()}')"

%labels
    Version {{ container_version | default('1.0.0') }}
    Description PyTorch {{ pytorch_version | default('2.0') }} with MPI {{ mpi_version | default('4.1.4') }} \
                for distributed training
    Author Hyperscaler Project
```

### 3.4 Container Build and Deployment

**Automated Container Image Management:**

```yaml
# ml-container-images/tasks/pytorch-mpi.yml
- name: Create Singularity definition file
  template:
    src: pytorch-mpi.def.j2
    dest: /tmp/pytorch-mpi.def
    
- name: Build PyTorch+MPI container image
  shell: |
    singularity build --fakeroot \
      {{ container_registry_path }}/pytorch-mpi-{{ pytorch_version }}-mpi{{ mpi_version }}.sif \
      /tmp/pytorch-mpi.def
  args:
    creates: "{{ container_registry_path }}/pytorch-mpi-{{ pytorch_version }}-mpi{{ mpi_version }}.sif"
  become: yes
  
- name: Validate container functionality
  shell: |
    singularity exec {{ container_registry_path }}/pytorch-mpi-{{ pytorch_version }}-mpi{{ mpi_version }}.sif \
      python3 -c "import torch; print('PyTorch version:', torch.__version__); print('CUDA available:', torch.cuda.is_available())"
  register: container_validation
  
- name: Display container validation results
  debug:
    msg: "{{ container_validation.stdout }}"

# ml-container-images/tasks/registry.yml
- name: Create shared container registry directory
  file:
    path: "{{ container_registry_path | default('/opt/containers') }}"
    state: directory
    owner: root
    group: slurm
    mode: '0755'
    
- name: Set container registry permissions
  file:
    path: "{{ container_registry_path }}"
    state: directory
    recurse: yes
    owner: root
    group: slurm
    mode: '0755'
```

### 3.5 Container Validation and Testing

**Container Functionality Validation:**

```yaml
# ml-container-images/tasks/testing.yml
- name: Validate PyTorch CUDA availability in container
  shell: |
    singularity exec --nv {{ container_registry_path }}/pytorch-mpi-{{ pytorch_version }}-mpi{{ mpi_version }}.sif \
    python3 -c "
    import torch
    print(f'PyTorch version: {torch.__version__}')
    print(f'CUDA available: {torch.cuda.is_available()}')
    print(f'CUDA devices: {torch.cuda.device_count()}')
    if torch.cuda.is_available():
        print(f'CUDA version: {torch.version.cuda}')
        print(f'cuDNN version: {torch.backends.cudnn.version()}')
    "
  register: container_pytorch_test
  
- name: Validate MPI functionality in container
  shell: |
    singularity exec {{ container_registry_path }}/pytorch-mpi-{{ pytorch_version }}-mpi{{ mpi_version }}.sif \
    python3 -c "
    from mpi4py import MPI
    comm = MPI.COMM_WORLD
    print(f'MPI World Size: {comm.Get_size()}')
    print(f'MPI Rank: {comm.Get_rank()}')
    print(f'Processor: {MPI.Get_processor_name()}')
    "
  register: container_mpi_test
  
- name: Display container validation results
  debug:
    msg: |
      PyTorch Container Test: {{ container_pytorch_test.stdout }}
      MPI Container Test: {{ container_mpi_test.stdout }}
```

## 4. Node Inventory and SLURM Configuration

### 4.1 Dynamic Inventory Generation

**Enhanced Inventory Generator:**

```python
# ansible/inventories/generate_inventory.py - Enhanced Implementation
#!/usr/bin/env python3
"""
Enhanced Ansible inventory generator for HPC SLURM deployment.
Reads cluster.yaml and generates comprehensive SLURM-aware inventory.
"""

import yaml
import json
from typing import Dict, Any, List
from pathlib import Path

class SlurmInventoryGenerator:
    def __init__(self, cluster_config_path: str):
        self.config_path = cluster_config_path
        self.cluster_config = self._load_cluster_config()
        
    def _load_cluster_config(self) -> Dict[str, Any]:
        """Load and validate cluster configuration."""
        with open(self.config_path, 'r') as f:
            return yaml.safe_load(f)
    
    def generate_hpc_inventory(self) -> Dict[str, Any]:
        """Generate comprehensive HPC cluster inventory."""
        hpc_config = self.cluster_config['clusters']['hpc']
        
        inventory = {
            'all': {
                'vars': {
                    'ansible_user': 'admin',
                    'ansible_ssh_private_key_file': '/opt/hyperscaler/ssh/id_ed25519',
                    'ansible_ssh_common_args': '-o StrictHostKeyChecking=no',
                    # SLURM global configuration
                    'slurm_cluster_name': hpc_config['name'],
                    'slurm_control_machine': hpc_config['controller']['ip_address'],
                    'slurm_accounting_database': 'slurm_acct_db',
                }
            },
            'slurm_controller': {
                'hosts': {
                    hpc_config['controller']['ip_address']: {
                        'ansible_host': hpc_config['controller']['ip_address'],
                        'slurm_node_name': 'controller',
                        'slurm_node_addr': hpc_config['controller']['ip_address'],
                        'slurm_cpus': hpc_config['controller']['cpu_cores'],
                        'slurm_real_memory': hpc_config['controller']['memory_gb'] * 1024,
                        'slurm_state': 'UNKNOWN',
                        'slurm_node_type': 'controller'
                    }
                },
                'vars': {
                    'slurm_node_role': 'controller'
                }
            },
            'slurm_compute': {
                'hosts': {},
                'vars': {
                    'slurm_node_role': 'compute'
                }
            },
            'gpu_nodes': {
                'hosts': {},
                'vars': {
                    'has_gpu': True
                }
            }
        }
        
        # Process compute nodes
        for i, node in enumerate(hpc_config['compute_nodes']):
            node_name = f"compute-{i+1:02d}"
            node_ip = node['ip']
            
            # Basic node configuration
            node_config = {
                'ansible_host': node_ip,
                'slurm_node_name': node_name,
                'slurm_node_addr': node_ip,
                'slurm_cpus': node['cpu_cores'],
                'slurm_real_memory': node['memory_gb'] * 1024,
                'slurm_state': 'UNKNOWN'
            }
            
            # GPU configuration if present
            if node.get('pcie_passthrough', {}).get('enabled', False):
                gpu_devices = [dev for dev in node['pcie_passthrough']['devices'] 
                              if dev['device_type'] == 'gpu']
                
                node_config.update({
                    'slurm_gres': f"gpu:{len(gpu_devices)}",
                    'gpu_count': len(gpu_devices),
                    'gpu_devices': gpu_devices,
                    'has_pcie_passthrough': True
                })
                
                # Add to GPU nodes group
                inventory['gpu_nodes']['hosts'][node_ip] = node_config.copy()
            
            # Add to compute nodes group
            inventory['slurm_compute']['hosts'][node_ip] = node_config
            
        return inventory
    
    def write_inventory(self, output_path: str = "inventories/hpc"):
        """Write inventory to file."""
        inventory = self.generate_hpc_inventory()
        
        # Create directory
        Path(output_path).mkdir(parents=True, exist_ok=True)
        
        # Write main inventory
        with open(f"{output_path}/hosts.yml", 'w') as f:
            yaml.dump(inventory, f, default_flow_style=False, indent=2)
            
        # Write group variables
        self._write_group_vars(output_path, inventory)
    
    def _write_group_vars(self, base_path: str, inventory: Dict[str, Any]):
        """Write group-specific variables."""
        group_vars_path = Path(f"{base_path}/group_vars")
        group_vars_path.mkdir(exist_ok=True)
        
        # All hosts variables
        all_vars = inventory['all']['vars']
        with open(group_vars_path / "all.yml", 'w') as f:
            yaml.dump(all_vars, f, indent=2)
            
        # SLURM controller variables  
        controller_vars = {
            'slurm_controller_host': True,
            'slurm_database_host': True,
            'slurm_accounting_enabled': True,
            'slurm_backup_controller': None
        }
        with open(group_vars_path / "slurm_controller.yml", 'w') as f:
            yaml.dump(controller_vars, f, indent=2)
            
        # Compute node variables
        compute_vars = {
            'slurm_compute_host': True,
            'slurm_task_prolog': '/etc/slurm/prolog.sh',
            'slurm_task_epilog': '/etc/slurm/epilog.sh'
        }
        with open(group_vars_path / "slurm_compute.yml", 'w') as f:
            yaml.dump(compute_vars, f, indent=2)

if __name__ == "__main__":
    generator = SlurmInventoryGenerator("../../config/cluster.yaml")
    generator.write_inventory()
```

### 4.2 SLURM Configuration Templates

**Container-Enabled SLURM Configuration Template:**

```jinja2
# slurm-controller/templates/slurm.conf.j2
# SLURM Configuration File with Container Support
# Generated by Ansible for {{ slurm_cluster_name }}

# CONTROL MACHINES
ClusterName={{ slurm_cluster_name | default('hpc-cluster') }}
ControlMachine={{ slurm_control_machine }}
ControlAddr={{ slurm_control_machine }}
{% if slurm_backup_controller is defined %}
BackupController={{ slurm_backup_controller }}
BackupAddr={{ slurm_backup_controller }}
{% endif %}

# AUTHENTICATION
AuthType=auth/munge
CryptoType=crypto/munge
AuthAltTypes=auth/jwt

# SCHEDULING
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core_Memory

# MPI INTEGRATION (PMIx Compliant)
MpiDefault=pmix
MpiParams=ports=12000-12999

# RESOURCE MANAGEMENT
GresTypes=gpu
{% if slurm_accounting_enabled | default(true) %}
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost={{ slurm_control_machine }}
AccountingStoragePort=6819
{% endif %}

# JOB MANAGEMENT
JobCompType=jobcomp/filetxt
JobCompLoc=/var/log/slurm/job_completions.log
ProctrackType=proctrack/cgroup
TaskPlugin=task/cgroup,task/affinity
TaskPluginParam=Sched

# CONTAINER SUPPORT
PluginDir=/usr/lib/x86_64-linux-gnu/slurm-wlm
PlugStackConfig=/etc/slurm/plugstack.conf

# LOGGING
SlurmctldDebug=debug
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdDebug=debug
SlurmdLogFile=/var/log/slurm/slurmd.log

# TIMERS
SlurmctldTimeout=120
SlurmdTimeout=300
InactiveLimit=0
MinJobAge=300
KillWait=30
Waittime=0

# SCHEDULING PARAMETERS
PartitionName=DEFAULT MaxTime=24:00:00 State=UP
{% for partition in slurm_partitions | default(['gpu', 'debug']) %}
PartitionName={{ partition }} Nodes=ALL \
    Default={% if partition == slurm_default_partition | default('gpu') %}YES{% else %}NO{% endif %} \
    MaxTime={{ slurm_max_job_time | default('24:00:00') }} State=UP
{% endfor %}

# NODE DEFINITIONS
{% for host_ip, host_vars in groups['slurm_controller'].items() %}
NodeName={{ host_vars.slurm_node_name }} CPUs={{ host_vars.slurm_cpus }} \
    RealMemory={{ host_vars.slurm_real_memory }} NodeAddr={{ host_vars.slurm_node_addr }} \
    State={{ host_vars.slurm_state | default('UNKNOWN') }}
{% endfor %}

{% for host_ip, host_vars in groups['slurm_compute'].items() %}
NodeName={{ host_vars.slurm_node_name }} CPUs={{ host_vars.slurm_cpus }} \
    RealMemory={{ host_vars.slurm_real_memory }} NodeAddr={{ host_vars.slurm_node_addr }} \
    {% if host_vars.slurm_gres is defined %}Gres={{ host_vars.slurm_gres }} {% endif %}\
    State={{ host_vars.slurm_state | default('UNKNOWN') }}
{% endfor %}
```

**Container Configuration Template:**

```jinja2
# slurm-controller/templates/container.conf.j2
# Container execution configuration for SLURM

# Singularity/Apptainer container plugin
required=/usr/lib/x86_64-linux-gnu/slurm-wlm/container_singularity.so

# Container runtime options
[singularity]
runtime_path=/usr/bin/singularity
enable_overlay=true
enable_underlay=false
enable_gpu={{ enable_gpu_containers | default(true) }}
enable_nv={{ enable_gpu_containers | default(true) }}
mount_home=true
mount_tmp=true

# Container image locations
image_path={{ container_registry_path | default('/opt/containers') }}

# Security settings
allow_suid=false
contain=true
writable=false
```

**GPU Resource Configuration Template:**

```jinja2
# slurm-controller/templates/gres.conf.j2
# Generic Resource (GRES) Configuration for GPU resources

{% for host_ip, host_vars in groups['slurm_compute'].items() %}
{% if host_vars.has_gpu | default(false) %}
# {{ host_vars.slurm_node_name }} GPU Configuration
{% for i in range(host_vars.gpu_count | default(0)) %}
NodeName={{ host_vars.slurm_node_name }} Name=gpu \
    Type={{ host_vars.gpu_devices[i].device_id | default('generic') }} \
    File=/dev/nvidia{{ i }}
{% endfor %}

{% endif %}
{% endfor %}

# Alternative: Auto-detection using NVML
{% for host_ip, host_vars in groups['gpu_nodes'].items() %}
NodeName={{ host_vars.slurm_node_name }} AutoDetect=nvml
{% endfor %}
```

### 4.3 Resource Isolation Configuration

**Cgroup Configuration for Job Isolation:**

```jinja2
# slurm-controller/templates/cgroup.conf.j2
# Cgroup Configuration for SLURM Resource Isolation

CgroupAutomount=yes
CgroupReleaseAgentDir="/etc/slurm/cgroup"

# Memory management
ConstrainCores=yes
ConstrainDevices=yes
ConstrainRAMSpace=yes
ConstrainSwapSpace=no

# Device management for GPU isolation
AllowedDevicesFile="/etc/slurm/cgroup_allowed_devices_file.conf"

# GPU device isolation
TaskAffinity=yes
```

## 5. GPU, CPU, Memory, and Capability Exposure

### 5.1 GPU Resource Management Architecture

**GPU Exposure Strategy:**

```yaml
# Integration with existing PCIe passthrough system
gpu_management_strategy:
  primary: "pcie_passthrough"        # Direct GPU access for maximum performance
  fallback: "mig_slicing"           # MIG instances for multi-tenancy (future)
  validation: "comprehensive"       # Full GPU functionality testing
```

**GPU Detection and Configuration:**

```yaml
# slurm-compute/tasks/gpu.yml
- name: Detect available GPUs via lspci
  shell: lspci | grep -i nvidia | wc -l
  register: gpu_count_detected
  
- name: Validate PCIe passthrough GPU availability
  stat:
    path: "/dev/nvidia{{ item }}"
  register: gpu_device_check
  loop: "{{ range(0, gpu_count | default(0)) | list }}"
  
- name: Configure GPU device permissions
  file:
    path: "/dev/nvidia{{ item }}"
    group: slurm
    mode: '0664'
  loop: "{{ range(0, gpu_count | default(0)) | list }}"
  when: gpu_device_check.results[item].stat.exists

- name: Install GPU monitoring utilities
  apt:
    name:
      - nvidia-ml-py                 # Python bindings for NVML
      - nvidia-dcgm                  # Data Center GPU Manager
      - dcgm-exporter                # Prometheus metrics
    state: present
  when: has_gpu | default(false)
```

### 5.2 Comprehensive Resource Exposure

**CPU Topology and NUMA Awareness:**

```yaml
# slurm-compute/tasks/main.yml - Resource detection
- name: Gather hardware topology information
  setup:
    filter: 
      - ansible_processor*
      - ansible_memtotal*
      - ansible_numa*
    
- name: Install hardware topology utilities
  apt:
    name:
      - hwloc                        # Hardware locality detection
      - numactl                      # NUMA control utilities
      - lstopo                       # Topology visualization
    state: present

- name: Generate CPU affinity mapping
  shell: hwloc-bind --get
  register: cpu_affinity_map
  
- name: Configure NUMA-aware job scheduling
  template:
    src: numa-topology.conf.j2
    dest: /etc/slurm/numa-topology.conf
    owner: root
    group: slurm
    mode: '0644'
  notify: restart slurmd
```

**Memory and Storage Resource Configuration:**

```yaml
# Extended resource detection
- name: Detect system memory configuration
  shell: |
    echo "MemTotal: $(grep MemTotal /proc/meminfo | awk '{print $2}')"
    echo "MemAvailable: $(grep MemAvailable /proc/meminfo | awk '{print $2}')"
    echo "SwapTotal: $(grep SwapTotal /proc/meminfo | awk '{print $2}')"
  register: memory_configuration

- name: Configure memory overcommit protection
  sysctl:
    name: vm.overcommit_memory
    value: '2'                       # Never overcommit
    state: present
    reload: yes
    
- name: Set appropriate memory overcommit ratio
  sysctl:
    name: vm.overcommit_ratio
    value: '80'                      # 80% of RAM for jobs
    state: present
    reload: yes
```

### 5.3 SLURM GRES Integration

**Enhanced GRES Configuration for Multiple Resource Types:**

```jinja2
# slurm-compute/templates/gres.conf.j2 - Enhanced version
# Comprehensive Generic Resource Configuration

{% for host_ip, host_vars in groups['slurm_compute'].items() %}
# Node: {{ host_vars.slurm_node_name }}
{% if host_vars.has_gpu | default(false) %}
# GPU Resources
{% for i in range(host_vars.gpu_count | default(0)) %}
NodeName={{ host_vars.slurm_node_name }} Name=gpu \
    Type={{ host_vars.gpu_devices[i].device_id | default('generic') }} \
    File=/dev/nvidia{{ i }}
{% endfor %}

# GPU MIG instances (future expansion)
{% for mig_instance in host_vars.mig_instances | default([]) %}
NodeName={{ host_vars.slurm_node_name }} Name=gpu Type=mig \
    File=/dev/nvidia{{ mig_instance.parent_gpu }}:{{ mig_instance.instance_id }}
{% endfor %}
{% endif %}

# Network resources (InfiniBand, high-speed Ethernet)
{% if host_vars.high_speed_network | default(false) %}
NodeName={{ host_vars.slurm_node_name }} Name=network Type=ib \
    Bandwidth={{ host_vars.network_bandwidth | default('100G') }}
{% endif %}

# Local storage resources
{% if host_vars.local_storage | default(false) %}
NodeName={{ host_vars.slurm_node_name }} Name=storage Type=nvme Size={{ host_vars.storage_size | default('1TB') }}
{% endif %}

{% endfor %}
```

### 5.4 Resource Monitoring and Metrics

**Comprehensive Resource Monitoring Setup:**

```yaml
# slurm-compute/tasks/monitoring.yml
- name: Install resource monitoring stack
  apt:
    name:
      - prometheus-node-exporter     # System metrics
      - nvidia-dcgm                  # GPU metrics  
      - dcgm-exporter               # GPU Prometheus exporter
      - slurm-prometheus-exporter    # SLURM job metrics
    state: present

- name: Configure node exporter
  template:
    src: node-exporter.service.j2
    dest: /etc/systemd/system/node-exporter.service
  notify:
    - reload systemd
    - restart node-exporter

- name: Configure GPU monitoring service
  template:
    src: dcgm-exporter.service.j2
    dest: /etc/systemd/system/dcgm-exporter.service
  when: has_gpu | default(false)
  notify:
    - reload systemd  
    - restart dcgm-exporter
```

**Resource Utilization Reporting:**

```bash
# Custom SLURM resource reporting script
#!/bin/bash
# /opt/slurm/bin/resource-report.sh

echo "=== SLURM Resource Utilization Report ==="
echo "Generated: $(date)"
echo

echo "=== Node Status ==="
sinfo -N -l

echo
echo "=== GPU Resource Status ==="
sinfo -o "%20N %10c %10m %25f %10G %6t"

echo
echo "=== Active Jobs ==="
squeue -o "%18i %12j %4t %10u %20q %20a %10g %20S %20e %8D %20R"

echo  
echo "=== GPU Utilization (nvidia-smi) ==="
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv
fi
```

### 5.5 System Monitoring and Failure Debugging

System monitoring and failure debugging are **critical** for distributed PyTorch
training on HPC clusters. The containerized environment adds complexity that
requires specialized monitoring approaches.

#### 5.5.1 Multi-Layer Monitoring Architecture

**Infrastructure Monitoring Stack:**

```yaml
# ansible/roles/monitoring-stack/tasks/main.yml
- name: Install Prometheus monitoring stack
  apt:
    name:
      - prometheus                   # Metrics collection server
      - prometheus-node-exporter     # System metrics
      - prometheus-slurm-exporter    # SLURM job metrics
      - grafana                      # Visualization platform
      - alertmanager                 # Alert routing
      - nvidia-dcgm                  # Data Center GPU Manager
      - dcgm-exporter               # GPU Prometheus exporter
    state: present

- name: Configure SLURM job accounting for monitoring
  lineinfile:
    path: /etc/slurm/slurm.conf
    regexp: '^JobAcctGatherType='
    line: 'JobAcctGatherType=jobacct_gather/linux'
    
- name: Enable detailed SLURM profiling
  lineinfile:
    path: /etc/slurm/slurm.conf
    regexp: '^JobAcctGatherParams='
    line: 'JobAcctGatherParams=UsePss,NoOverMemoryKill'
```

#### 5.5.2 Container-Specific Monitoring

**Enhanced Container Images with Monitoring Tools:**

```singularity
# Addition to pytorch-mpi.def.j2
%post
    # Install monitoring and debugging tools in container
    pip3 install \
        tensorboard \
        wandb \
        nvitop \
        py-spy \
        memory-profiler \
        torch-tb-profiler
    
    # System monitoring tools
    apt-get install -y \
        htop iotop nethogs \
        strace gdb tcpdump
```

#### 5.5.3 Failure Detection and Alerting System

**SLURM Epilog Script for Failure Analysis:**

```bash
#!/bin/bash
# /etc/slurm/epilog.sh - Job completion analysis

JOB_ID=$SLURM_JOB_ID
EXIT_CODE=$1
NODE_NAME=$(hostname)

# Collect GPU metrics at job completion
if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_UTILIZATION=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum/NR}')
    MEMORY_USAGE=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum}')
fi

# Log completion metrics
echo "$(date '+%Y-%m-%d %H:%M:%S') JOB_ID=$JOB_ID EXIT_CODE=$EXIT_CODE NODE=$NODE_NAME" \
     " GPU_UTIL=${GPU_UTILIZATION:-0} GPU_MEM=${MEMORY_USAGE:-0}" \
     >> /var/log/slurm/job_metrics.log

# Enhanced failure analysis for distributed training
if [[ $EXIT_CODE -ne 0 ]]; then
    DEBUG_DIR="/var/log/slurm/debug/$JOB_ID"
    mkdir -p "$DEBUG_DIR"
    
    # Capture system state at failure
    nvidia-smi > "$DEBUG_DIR/gpu_state.log" 2>&1
    free -h > "$DEBUG_DIR/memory.log"
    ss -tuln > "$DEBUG_DIR/network.log"
    
    # Container-specific debugging
    if [[ -n "$SINGULARITY_CONTAINER" ]]; then
        echo "Failed container: $SINGULARITY_CONTAINER" > "$DEBUG_DIR/container.log"
        singularity --version >> "$DEBUG_DIR/container.log"
    fi
fi
```

#### 5.5.4 Distributed Training Failure Diagnosis

**Automated Failure Analysis Script:**

```python
#!/usr/bin/env python3
# /opt/slurm/bin/diagnose_training_failure.py
"""
Distributed Training Failure Diagnosis Tool
Analyzes common failure patterns in containerized PyTorch distributed training
"""

import os
import socket
import subprocess
import json
import logging
from typing import Dict, Any

class TrainingFailureDiagnostic:
    def __init__(self):
        self.job_id = os.getenv('SLURM_JOB_ID', 'unknown')
        self.node_name = socket.gethostname()
        
    def check_pytorch_environment(self) -> Dict[str, Any]:
        """Validate PyTorch distributed training environment"""
        env_vars = ['MASTER_ADDR', 'MASTER_PORT', 'WORLD_SIZE', 'RANK', 'LOCAL_RANK']
        env_status = {}
        
        for var in env_vars:
            env_status[var] = os.getenv(var, 'NOT_SET')
        
        # Validate connectivity to master
        master_addr = os.getenv('MASTER_ADDR')
        master_port = os.getenv('MASTER_PORT')
        
        if master_addr and master_port:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5)
                result = sock.connect_ex((master_addr, int(master_port)))
                env_status['master_connectivity'] = result == 0
                sock.close()
            except Exception as e:
                env_status['master_connectivity'] = False
                env_status['connectivity_error'] = str(e)
                
        return env_status
    
    def check_container_health(self) -> Dict[str, Any]:
        """Check container-specific health indicators"""
        container_status = {}
        
        # Check if running in container
        container_status['in_singularity'] = os.path.exists('/.singularity.d')
        
        if container_status['in_singularity']:
            container_status['container_path'] = os.getenv('SINGULARITY_CONTAINER', 'unknown')
            
            # Check container mounts
            try:
                with open('/proc/mounts', 'r') as f:
                    mounts = f.read()
                    container_status['has_data_mount'] = '/data' in mounts
                    container_status['has_work_mount'] = '/work' in mounts
            except Exception as e:
                container_status['mount_check_error'] = str(e)
        
        # Test MPI functionality in container
        try:
            result = subprocess.run([
                'python3', '-c', 
                'from mpi4py import MPI; comm = MPI.COMM_WORLD; '
                'print(f"MPI_RANK={comm.Get_rank()},MPI_SIZE={comm.Get_size()}")'
            ], capture_output=True, text=True, timeout=10)
            
            container_status['mpi_functional'] = result.returncode == 0
            if result.returncode == 0:
                container_status['mpi_info'] = result.stdout.strip()
            else:
                container_status['mpi_error'] = result.stderr.strip()
        except Exception as e:
            container_status['mpi_functional'] = False
            container_status['mpi_error'] = str(e)
            
        return container_status
    
    def check_gpu_resources(self) -> Dict[str, Any]:
        """Check GPU availability and utilization in container"""
        gpu_status = {}
        
        try:
            result = subprocess.run([
                'nvidia-smi', '--query-gpu=index,name,memory.used,memory.total,utilization.gpu,processes.pid',
                '--format=csv,noheader,nounits'
            ], capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                gpu_status['available'] = True
                gpu_status['gpus'] = []
                
                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = [p.strip() for p in line.split(',')]
                        gpu_info = {
                            'index': int(parts[0]),
                            'name': parts[1],
                            'memory_used_mb': int(parts[2]) if parts[2] != '[Not Supported]' else 0,
                            'memory_total_mb': int(parts[3]) if parts[3] != '[Not Supported]' else 0,
                            'utilization_percent': int(parts[4]) if parts[4] != '[Not Supported]' else 0,
                            'processes': parts[5] if len(parts) > 5 else ''
                        }
                        gpu_status['gpus'].append(gpu_info)
            else:
                gpu_status['available'] = False
                gpu_status['error'] = result.stderr.strip()
                
        except Exception as e:
            gpu_status['available'] = False
            gpu_status['error'] = str(e)
            
        return gpu_status
    
    def generate_diagnosis_report(self) -> Dict[str, Any]:
        """Generate comprehensive failure diagnosis report"""
        report = {
            'job_id': self.job_id,
            'node_name': self.node_name,
            'timestamp': subprocess.run(['date', '-Iseconds'], capture_output=True, text=True).stdout.strip(),
            'pytorch_environment': self.check_pytorch_environment(),
            'container_health': self.check_container_health(),
            'gpu_resources': self.check_gpu_resources()
        }
        
        # Analyze common failure patterns
        report['failure_analysis'] = self._analyze_failure_patterns(report)
        
        return report
    
    def _analyze_failure_patterns(self, report: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze report for common failure patterns"""
        analysis = {'issues_found': [], 'recommendations': []}
        
        # Check for missing environment variables
        pytorch_env = report['pytorch_environment']
        for var in ['MASTER_ADDR', 'MASTER_PORT', 'WORLD_SIZE', 'RANK']:
            if pytorch_env.get(var) == 'NOT_SET':
                analysis['issues_found'].append(f"Missing environment variable: {var}")
                analysis['recommendations'].append(f"Ensure SLURM job script sets {var}")
        
        # Check master connectivity
        if not pytorch_env.get('master_connectivity', True):
            analysis['issues_found'].append("Cannot connect to master node")
            analysis['recommendations'].append("Check network connectivity and firewall rules")
        
        # Check GPU availability
        if not report['gpu_resources']['available']:
            analysis['issues_found'].append("GPU resources not accessible")
            analysis['recommendations'].append("Verify GPU drivers and container --nv flag")
        
        # Check MPI functionality
        if not report['container_health'].get('mpi_functional', True):
            analysis['issues_found'].append("MPI not functional in container")
            analysis['recommendations'].append("Check container MPI installation and PMIx configuration")
        
        return analysis

if __name__ == "__main__":
    diagnostic = TrainingFailureDiagnostic()
    report = diagnostic.generate_diagnosis_report()
    
    # Write report to debug directory
    debug_dir = f"/var/log/slurm/debug/{diagnostic.job_id}"
    os.makedirs(debug_dir, exist_ok=True)
    
    with open(f"{debug_dir}/failure_diagnosis.json", 'w') as f:
        json.dump(report, f, indent=2)
    
    # Print summary to stdout
    print(f"Failure diagnosis complete for job {diagnostic.job_id}")
    print(f"Issues found: {len(report['failure_analysis']['issues_found'])}")
    for issue in report['failure_analysis']['issues_found']:
        print(f"  - {issue}")
    
    print(f"Full report saved to: {debug_dir}/failure_diagnosis.json")
```

#### 5.5.5 Performance Monitoring Dashboard

**Grafana Dashboard Configuration:**

```json
{
  "dashboard": {
    "title": "HPC Distributed PyTorch Training",
    "panels": [
      {
        "title": "GPU Utilization by Node",
        "type": "stat",
        "targets": [
          {
            "expr": "avg_over_time(dcgm_gpu_utilization[5m])",
            "legendFormat": "{{instance}}-GPU{{gpu}}"
          }
        ]
      },
      {
        "title": "SLURM Job Queue Status",
        "type": "table",
        "targets": [
          {
            "expr": "slurm_queue_jobs_total",
            "legendFormat": "{{state}}"
          }
        ]
      },
      {
        "title": "Container Resource Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "container_memory_usage_bytes",
            "legendFormat": "Memory-{{container_label_job_id}}"
          },
          {
            "expr": "container_cpu_usage_seconds_total",
            "legendFormat": "CPU-{{container_label_job_id}}"
          }
        ]
      }
    ]
  }
}
```

### 5.6 Containerized Job Submission Integration

**Container-Based PyTorch Training Job Template:**

```bash
#!/bin/bash
# SLURM containerized job template for distributed PyTorch training
# Template: /opt/slurm/templates/pytorch-container.sbatch

#SBATCH --job-name=pytorch_container_job
#SBATCH --nodes={{ nodes | default(2) }}
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-task={{ gpus_per_node | default(1) }}
#SBATCH --cpus-per-task={{ cpus_per_task | default(8) }}
#SBATCH --mem={{ memory_gb | default(32) }}G
#SBATCH --time={{ max_time | default('24:00:00') }}
#SBATCH --partition={{ partition | default('gpu') }}
#SBATCH --output=job-%j.out
#SBATCH --error=job-%j.err

# Container and data paths
CONTAINER_IMAGE="{{ container_registry_path | default('/opt/containers') }}/\
pytorch-mpi-{{ pytorch_version | default('2.0') }}-mpi{{ mpi_version | default('4.1.4') }}.sif"
DATA_PATH="{{ shared_data_path | default('/shared/data') }}"
WORK_DIR="{{ shared_work_path | default('/shared/work') }}"

# PyTorch distributed environment (passed to container)
export MASTER_PORT=$(expr 10000 + $(echo -n $SLURM_JOBID | tail -c 4))
export MASTER_ADDR=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
export WORLD_SIZE=$(($SLURM_NNODES * $SLURM_GPUS_PER_TASK))

# NCCL optimization (container environment)
export NCCL_DEBUG=INFO
export NCCL_SOCKET_IFNAME=eth0
export NCCL_IB_DISABLE=1

# Container bind mounts
BIND_MOUNTS="--bind $DATA_PATH:/data,${WORK_DIR}:/work"
{% if shared_models_path is defined %}
BIND_MOUNTS="$BIND_MOUNTS,{{ shared_models_path }}:/models"
{% endif %}

# Launch distributed training with SLURM+MPI+Container integration
srun --mpi=pmix \
     --container-image="$CONTAINER_IMAGE" \
     --container-mounts="$BIND_MOUNTS" \
     --container-workdir="/work" \
     torchrun \
         --nnodes=$SLURM_NNODES \
         --nproc_per_node=$SLURM_GPUS_ON_NODE \
         --rdzv_id=$SLURM_JOB_ID \
         --rdzv_backend=c10d \
         --rdzv_endpoint=$MASTER_ADDR:$MASTER_PORT \
         {{ training_script }} {{ training_args }}
```

**Alternative MPI-Only Training Job Template:**

```bash
#!/bin/bash
# MPI-based distributed training with containers
# Template: /opt/slurm/templates/mpi-pytorch-container.sbatch

#SBATCH --job-name=mpi_pytorch_job
#SBATCH --nodes={{ nodes | default(2) }}
#SBATCH --ntasks={{ total_tasks | default(4) }}
#SBATCH --gpus-per-task=1
#SBATCH --cpus-per-task={{ cpus_per_task | default(8) }}
#SBATCH --mem={{ memory_gb | default(32) }}G
#SBATCH --time={{ max_time | default('24:00:00') }}
#SBATCH --partition={{ partition | default('gpu') }}
#SBATCH --output=job-%j.out
#SBATCH --error=job-%j.err

CONTAINER_IMAGE="{{ container_registry_path | default('/opt/containers') }}/\
pytorch-mpi-{{ pytorch_version | default('2.0') }}-mpi{{ mpi_version | default('4.1.4') }}.sif"

# MPI with container execution (SLURM manages task distribution)
srun --mpi=pmix \
     --container-image="$CONTAINER_IMAGE" \
     --container-mounts="{{ shared_data_path | default('/shared/data') }}:/data" \
     python3 {{ training_script }} {{ training_args }}
```

**SLURM Configuration Compliance Validation:**

```yaml
# Validation tasks for SLURM compliance
- name: Validate PMIx support in SLURM build
  shell: srun --mpi=list
  register: mpi_support_check
  failed_when: "'pmix' not in mpi_support_check.stdout"
  
- name: Verify container plugin availability  
  stat:
    path: /usr/lib/x86_64-linux-gnu/slurm-wlm/container_singularity.so
  register: container_plugin_check
  failed_when: not container_plugin_check.stat.exists
  
- name: Test MPI communication in container
  shell: |
    srun --nodes=2 --ntasks=4 --mpi=pmix \
         --container-image="{{ container_registry_path }}/pytorch-mpi-{{ pytorch_version }}-mpi{{ mpi_version }}.sif" \
         python3 -c "
from mpi4py import MPI
comm = MPI.COMM_WORLD
print(f'Rank {comm.Get_rank()} of {comm.Get_size()} on {MPI.Get_processor_name()}')
"
  register: mpi_container_test
  when: 
    - slurm_cluster_operational | default(false)
    - container_plugin_check.stat.exists
```

## SLURM Documentation Compliance Validation

### SLURM MPI Integration Standards Compliance

**1. PMIx Integration (Section 1.1 Reference - MPI Support):**

- **✅ Requirement**: SLURM supports PMI2/PMIx APIs for modern MPI
  implementations
- **✅ Implementation**:
  - `MpiDefault=pmix` in slurm.conf
  - `MpiParams=ports=12000-12999` for PMIx communication
  - PMIx libraries installed (`libpmix2`, `libpmix-dev`)
  - Validation: `srun --mpi=list` confirms PMIx support

**2. MPI Launch Methods (Section 4.1 Reference - Launcher Architecture):**

- **✅ Method 1 (Implemented)**: SLURM directly launches tasks via PMIx APIs

  ```bash
  srun --mpi=pmix --ntasks=4 python3 training_script.py
  ```

- **✅ Method 2 (Alternative)**: SLURM creates allocation, mpirun uses SLURM
  infrastructure

  ```bash
  srun mpirun -n 4 python3 training_script.py
  ```

- **❌ Method 3 (Not Recommended)**: SSH/RSH based - explicitly avoided

**3. Resource Management (Section 4.2 Reference - GPU Configuration):**

- **✅ GRES Configuration**: `GresTypes=gpu` with proper device file mapping
- **✅ Cgroup Isolation**: `ConstrainDevices=yes` for GPU isolation
- **✅ Resource Tracking**: `SelectType=select/cons_tres` for fine-grained
  resource management

**4. Container Integration Standards:**

- **✅ Container Plugin Support**: Singularity/Apptainer plugin configuration
- **✅ Container GPU Access**: `--nv` flag support for GPU passthrough to
  containers
- **✅ Container MPI**: MPI libraries in containers communicate with SLURM PMIx

**5. Environment Variable Contract (Section 1.1 Reference):**

```bash
# SLURM automatically provides these variables to jobs:
SLURM_JOB_NODELIST    → Used to determine MASTER_ADDR
SLURM_NNODES          → Used for WORLD_SIZE calculation  
SLURM_PROCID          → Maps to RANK
SLURM_LOCALID         → Maps to LOCAL_RANK
SLURM_GPUS_ON_NODE    → Used for --nproc_per_node

# Our templates correctly translate these per Table 1 in documentation
```

### Container Standards Compliance

**1. HPC Container Best Practices:**

- **✅ Singularity/Apptainer**: Industry standard for HPC containers
- **✅ GPU Support**: Native CUDA/GPU passthrough with `--nv` flag
- **✅ MPI Integration**: Container MPI libraries compatible with host SLURM
- **✅ Shared Storage**: Bind mounts for data, work, and model directories

**2. Security and Isolation:**

- **✅ No Privilege Escalation**: `allow_suid=false` in container config
- **✅ Resource Isolation**: SLURM cgroups limit container resource access
- **✅ Network Security**: Container networking controlled by SLURM

**3. PyTorch Distributed Training Integration:**

- **✅ NCCL Backend**: Optimized GPU communication within containers
- **✅ Environment Passing**: SLURM variables available inside containers
- **✅ Multi-Node Coordination**: Container processes participate in distributed
  rendezvous

### Performance and Scalability Validation

**1. Communication Optimization (Section 6.1 Reference - Network
Configuration):**

- **✅ NCCL Interface Binding**: `NCCL_SOCKET_IFNAME` for optimal network
  interface selection
- **✅ PMIx Communication**: Dedicated port range (12000-12999) for MPI
  coordination
- **✅ GPU Memory Access**: Direct GPU access via PCIe passthrough (no
  virtualization overhead)

**2. Resource Utilization:**

- **✅ CPU Affinity**: `TaskPlugin=task/affinity` for optimal CPU binding
- **✅ Memory Management**: `ConstrainRAMSpace=yes` prevents memory
  oversubscription
- **✅ GPU Scheduling**: GRES ensures exclusive GPU allocation to jobs

## Implementation Timeline

### Phase 1: Core Infrastructure and Container Runtime (Weeks 1-2)

- [ ] Extend Ansible role structure for container support
- [ ] Implement Singularity/Apptainer container runtime installation
- [ ] Create SLURM controller configuration with PMIx and container support
- [ ] Set up MUNGE authentication and container security policies
- [ ] Implement enhanced inventory generator with container-aware variables
- [ ] **Deploy monitoring infrastructure** (Prometheus, Grafana, AlertManager)
- [ ] **Configure SLURM job accounting** for comprehensive metrics collection

### Phase 2: Container Images and Compute Integration (Weeks 3-4)  

- [ ] Build PyTorch+MPI container images using Singularity (with monitoring
  tools)
- [ ] Deploy SLURM compute node configuration with container integration
- [ ] Configure container registry and image distribution
- [ ] Integrate PCIe passthrough GPU detection for containers
- [ ] Configure cgroups for container resource isolation
- [ ] **Set up GPU monitoring** (DCGM exporter, node exporters)
- [ ] **Deploy failure detection scripts** (SLURM epilog, prolog scripts)

### Phase 3: Container Validation and Testing (Week 5)

- [ ] Deploy containerized PyTorch distributed training jobs
- [ ] Validate GPU access and scheduling within containers
- [ ] Test MPI communication across containerized processes
- [ ] Performance benchmarking: container vs native performance
- [ ] Integration testing with Python CLI orchestrator
- [ ] **Validate monitoring stack** (metrics collection, alerting)
- [ ] **Test failure diagnosis tools** on simulated training failures
- [ ] **Configure Grafana dashboards** for distributed training visibility

### Phase 4: MLOps Integration and Production (Week 6)

- [ ] Configure Oumi.ai for containerized job submission
- [ ] Prepare ScalarLM integration with container workflows
- [ ] Implement container image versioning and management
- [ ] Create containerized workflow templates and documentation
- [ ] **Deploy production alerting rules** for training job failures
- [ ] **Set up automated failure analysis** and notification systems
- [ ] **Performance baseline establishment** and optimization guidelines
- [ ] Comprehensive end-to-end validation and troubleshooting guides

## Success Criteria

### Technical Validation

- [ ] **SLURM cluster operational** with all nodes in active state and container
  support
- [ ] **Container runtime functional** with Singularity/Apptainer integration
- [ ] **GPU resources properly scheduled** and accessible within containers
- [ ] **Containerized distributed PyTorch training** successfully executes
  across multiple nodes
- [ ] **Container image registry** operational with versioned ML images
- [ ] **MPI communication** functional between containerized processes
- [ ] **Resource utilization metrics** collected from both host and containers
- [ ] **Monitoring stack operational** (Prometheus, Grafana, AlertManager)
- [ ] **Failure detection and analysis** automated for distributed training jobs
- [ ] **Performance profiling tools** integrated and functional

### Performance Benchmarks

- [ ] **Containerized GPU utilization >90%** during compute-intensive workloads  
- [ ] **Container startup overhead <30s** for PyTorch+MPI images
- [ ] **MPI latency <5ms** between containerized processes on same node
- [ ] **Network performance** maintains >80% of native performance in containers
- [ ] **Job queue throughput** supports concurrent containerized multi-node
  training
- [ ] **Resource isolation** prevents container job interference and GPU
  conflicts
- [ ] **Monitoring overhead <5%** system resource impact during training
- [ ] **Failure detection time <60s** for distributed training job failures
- [ ] **Alert response time <30s** for critical system issues

### Container Integration Requirements

- [ ] **Python CLI orchestrator** can deploy containerized HPC cluster lifecycle
- [ ] **Container image building** automated via Ansible during cluster setup
- [ ] **Oumi.ai integration** can submit containerized distributed training jobs  
- [ ] **GPU passthrough** functional within containers (PCIe devices accessible)
- [ ] **Shared storage** properly mounted and accessible from containers
- [ ] **Environment variable passing** from SLURM to containers working
  correctly
- [ ] **Container security policies** prevent privilege escalation and resource
  leaks

This implementation plan provides a comprehensive roadmap for deploying a
production-ready HPC SLURM cluster optimized for distributed PyTorch training,
building upon the existing project infrastructure while adding the specialized
components required for high-performance machine learning workloads.
