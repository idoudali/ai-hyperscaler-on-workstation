# SLURM Compute Node Workflow Documentation

## Overview

This document describes the workflow for deploying and testing SLURM compute nodes as implemented in Task 022.
The SLURM compute node deployment follows a two-phase approach: build-time installation and runtime configuration.

## Architecture

### Components

- **SLURM Compute Daemon (slurmd)**: Main daemon running on compute nodes to execute jobs
- **SLURM Client Tools**: Tools for job submission and monitoring (srun, squeue, scancel, etc.)
- **MUNGE Authentication**: Provides authentication between compute nodes and controller
- **PMIx Runtime**: Process Management Interface for MPI applications
- **Container Runtime**: Apptainer/Singularity for containerized workloads

### Node Communication Flow

```text
┌──────────────────┐
│ SLURM Controller │
│   (slurmctld)    │
└────────┬─────────┘
         │
         │ MUNGE Auth + SLURM Protocol
         │
    ┌────┴─────┬──────────────┐
    │          │              │
┌───▼────┐ ┌──▼─────┐ ┌──────▼───┐
│Compute1│ │Compute2│ │ Compute3 │
│(slurmd)│ │(slurmd)│ │ (slurmd) │
└────────┘ └────────┘ └──────────┘
```

## Deployment Phases

### Phase 1: Build-Time Installation (Packer)

Runs during Packer image creation with `packer_build=true`:

1. **Package Installation**
   - Core SLURM packages: slurmd, slurm-client
   - Authentication: munge, libmunge2
   - MPI support: libpmix2
   - Container support: squashfs-tools, cryptsetup-bin, fuse

2. **Configuration Setup**
   - Create directory structure (/etc/slurm, /var/log/slurm, /var/spool/slurmd)
   - Deploy configuration templates (slurm.conf, cgroup.conf)
   - Enable services for auto-start

3. **What is NOT Done**
   - Services are NOT started
   - Node is NOT registered with controller
   - MUNGE key is NOT configured (node-specific)

**Purpose**: Create a reusable base image with all software pre-installed

### Phase 2: Runtime Configuration

Runs during VM deployment with `packer_build=false`:

1. **MUNGE Setup**
   - Copy MUNGE key from controller
   - Set correct permissions (400, munge:munge)
   - Start MUNGE service

2. **Service Startup**
   - Start slurmd daemon
   - Verify service is running

3. **Node Registration**
   - Wait for controller to recognize node
   - Verify node appears in cluster
   - Check node state (IDLE, ALLOCATED, etc.)

4. **Validation**
   - Test MUNGE authentication
   - Verify controller communication
   - Test simple job execution
   - Validate container runtime availability

**Purpose**: Configure node-specific settings and integrate with running cluster

## Ansible Role Structure

### Directory Layout

```text
ansible/roles/slurm-compute/
├── defaults/
│   └── main.yml              # Default variables and package lists
├── tasks/
│   ├── main.yml              # Main orchestration
│   ├── install.yml           # Package installation
│   └── configure.yml         # Service configuration
├── handlers/
│   └── main.yml              # Service restart handlers
└── templates/
    ├── slurm.conf.j2         # SLURM configuration template
    └── cgroup.conf.j2        # Cgroup configuration template
```

### Key Files

#### `tasks/install.yml`

- Installs SLURM compute packages
- Installs container runtime support packages
- Verifies binary availability
- Checks PMIx libraries
- Validates MUNGE installation

#### `tasks/configure.yml`

- Creates directory structure
- Deploys configuration files
- Manages MUNGE key distribution
- Enables and starts services (runtime only)
- Verifies node registration
- Tests controller communication

#### `defaults/main.yml`

Defines package lists and configuration variables:

```yaml
slurm_compute_packages:
  - slurmd
  - slurm-client
  - munge
  - libmunge2
  - libpmix2

slurm_compute_container_packages:
  - squashfs-tools
  - cryptsetup-bin
  - fuse
```

## Playbooks

### Runtime Configuration Playbook

**File**: `ansible/playbooks/playbook-slurm-compute-runtime-config.yml`

**Purpose**: Deploy SLURM compute configuration at runtime

**Usage**:

```bash
ansible-playbook -i inventory playbook-slurm-compute-runtime-config.yml
```

**What it does**:

1. Verifies runtime mode (not Packer build)
2. Checks if slurmd is installed
3. Runs slurm-compute role with `packer_build=false`
4. Validates node registration
5. Tests job submission
6. Verifies container runtime

## Testing Framework

### Test Structure

```text
tests/
├── test-slurm-compute-framework.sh    # Main test framework
├── test-infra/
│   └── configs/
│       └── test-slurm-compute.yaml    # Test configuration
└── suites/
    └── slurm-compute/
        ├── check-compute-installation.sh
        ├── check-compute-registration.sh
        ├── check-multi-node-communication.sh
        ├── check-distributed-jobs.sh
        └── run-slurm-compute-tests.sh
```

### Test Workflow

The test framework follows the Standard Test Framework Pattern:

```bash
# Full workflow (default - create + deploy + test)
cd tests && make test-slurm-compute

# Phased workflow (for debugging)
make test-slurm-compute-start   # Start cluster
make test-slurm-compute-deploy  # Deploy Ansible config
make test-slurm-compute-tests   # Run tests
make test-slurm-compute-stop    # Stop cluster

# Check status
make test-slurm-compute-status

# Direct commands
./test-slurm-compute-framework.sh start-cluster
./test-slurm-compute-framework.sh deploy-ansible
./test-slurm-compute-framework.sh run-tests
./test-slurm-compute-framework.sh stop-cluster
```

### Test Categories

#### 1. Installation Validation (`check-compute-installation.sh`)

Tests:

- SLURM packages installed (slurmd, slurm-client, munge, libpmix2)
- Container support packages installed
- SLURM binaries available
- PMIx libraries present
- MUNGE installation correct
- Container runtime available (apptainer/singularity)

#### 2. Node Registration (`check-compute-registration.sh`)

Tests:

- slurmd service running
- Node visible in SLURM cluster
- Node state appropriate (IDLE, ALLOCATED, etc.)
- MUNGE authentication working
- Controller connectivity
- Node resources configured
- No excessive errors in logs

#### 3. Multi-Node Communication (`check-multi-node-communication.sh`)

Tests:

- All cluster nodes listed
- Partition configuration
- MUNGE authentication across nodes
- Node-to-node connectivity
- SLURM communication ports
- Compute-to-controller communication
- Inter-node job submission

#### 4. Distributed Job Execution (`check-distributed-jobs.sh`)

Tests:

- Simple job execution (hostname)
- Multi-task jobs (srun -n4)
- Job output capture
- Job environment variables
- Job time limit enforcement
- Job queue functionality
- Job cancellation
- Compute node resources

## Common Workflows

### Deploy New Compute Node

```bash
# 1. Build compute image (if not already built)
cd packer && make build-hpc-compute-image

# 2. Create VM from image using terraform/libvirt
terraform apply

# 3. Deploy runtime configuration
cd ansible
ansible-playbook -i inventory playbooks/playbook-slurm-compute-runtime-config.yml

# 4. Verify node registration
scontrol show node compute-01
```

### Test Compute Node

```bash
# Run full test suite
cd tests && make test-slurm-compute

# Or test specific components
cd tests/suites/slurm-compute
./check-compute-installation.sh
./check-compute-registration.sh
./check-multi-node-communication.sh
./check-distributed-jobs.sh
```

### Troubleshoot Compute Node

```bash
# Check slurmd service
systemctl status slurmd
journalctl -u slurmd -f

# Check slurmd logs
tail -f /var/log/slurm/slurmd.log

# Check MUNGE authentication
systemctl status munge
echo "test" | munge | unmunge

# Check node status from controller
scontrol show node compute-01
sinfo -N

# Test simple job
srun -N1 hostname

# Check network connectivity
ping controller
telnet controller 6817
```

## Configuration Variables

### Required Variables

- `slurm_controller_host`: Hostname or IP of SLURM controller
- `slurm_controller_port`: SLURM controller port (default: 6817)
- `slurm_compute_node_name`: Name of compute node (default: inventory_hostname)

### Optional Variables

- `slurm_container_enabled`: Enable container runtime support (default: true)
- `slurm_cgroup_enabled`: Enable cgroup resource isolation (default: true)
- `munge_controller_key_source`: Source path for MUNGE key (if not using default)
- `container_install_method`: Container runtime installation method (default: "skip")

### Resource Configuration

```yaml
slurm_cpu_cores: 4
slurm_memory_gb: 8
slurm_disk_gb: 50
slurm_gpu_enabled: false
slurm_gpu_type: "nvidia"
slurm_gpu_count: 0
```

## MUNGE Key Distribution

MUNGE requires the same key on all nodes for authentication. There are multiple approaches:

### Option 1: Pre-generate and distribute

```bash
# On controller
dd if=/dev/urandom of=/etc/munge/munge.key bs=1 count=1024
chown munge:munge /etc/munge/munge.key
chmod 400 /etc/munge/munge.key

# Copy to compute nodes
scp /etc/munge/munge.key compute-01:/etc/munge/munge.key
ssh compute-01 'chown munge:munge /etc/munge/munge.key && chmod 400 /etc/munge/munge.key'
ssh compute-01 'systemctl restart munge'
```

### Option 2: Ansible distribution

Set in playbook or inventory:

```yaml
munge_controller_key_source: "/path/to/munge.key"
```

The configure.yml task will copy and set correct permissions.

### Option 3: Shared filesystem

Mount /etc/munge from shared storage (NFS, Lustre) across all nodes.

## Success Criteria

A successful SLURM compute deployment meets these criteria:

- ✅ All compute packages installed successfully
- ✅ slurmd service configured and running
- ✅ Node communicates with controller
- ✅ Container runtime available (if enabled)
- ✅ Multi-node communication functional
- ✅ Proper separation of build-time and runtime tasks
- ✅ slurmd service active on all compute nodes
- ✅ Nodes show as available in sinfo output
- ✅ Can execute simple jobs on compute nodes
- ✅ Multi-node job execution working
- ✅ Unified test framework validates all components

## References

- [SLURM Documentation](https://slurm.schedmd.com/documentation.html)
- [SLURM Configuration](https://slurm.schedmd.com/slurm.conf.html)
- [MUNGE Authentication](https://dun.github.io/munge/)
- [PMIx Documentation](https://pmix.github.io/)
- Task 010: SLURM Controller Installation
- Task 012: MUNGE Authentication System
- Task 013: Container Plugin Configuration
