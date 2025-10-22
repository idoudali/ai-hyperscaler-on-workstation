# Ansible Playbooks Index

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This directory contains Ansible playbooks for deploying and configuring HPC infrastructure components. Playbooks
orchestrate multiple roles to achieve complete system configurations for both HPC (SLURM-based) and cloud
(Kubernetes-based) deployments.

## Playbook Categories

### 1. Core Infrastructure Playbooks

Complete cluster deployment playbooks that orchestrate multiple roles for full infrastructure setup.

| Playbook | Purpose | Scope | Typical Use |
|----------|---------|-------|------------|
| **playbook-hpc-runtime.yml** | Complete HPC cluster runtime configuration | All HPC components | Runtime cluster deployment |
| **playbook-cloud.yml** | Cloud infrastructure setup | Cloud platform base | Cloud environment setup |

**Typical Deployment Flow:**

1. Prepare infrastructure (networks, storage, compute instances)
2. Configure inventory with host groups and variables
3. Run appropriate infrastructure playbook
4. Monitor playbook execution and verify deployment

**Important Prerequisites:**

Before running HPC playbooks, you **MUST** build required third-party packages from source.
See [3rd-Party Dependencies](../../3rd-party/README.md) for complete build instructions:

- **SLURM packages** (required) - [Build Documentation](../../3rd-party/slurm/README.md)
- **BeeGFS packages** (optional) - [Build Documentation](../../3rd-party/beegfs/README.md)

### 2. Component-Specific Playbooks

Targeted playbooks for deploying individual infrastructure components.

| Playbook | Component | Purpose | Use Case |
|----------|-----------|---------|----------|
| **playbook-container-registry.yml** | Container Registry | Container registry deployment | Image distribution setup |
| **playbook-beegfs-runtime-config.yml** | BeeGFS (Runtime) | BeeGFS post-deployment configuration | Production cluster BeeGFS setup |
| **playbook-virtio-fs-runtime-config.yml** | Virtio-FS Storage | Virtio-FS shared storage configuration | VM-based shared storage |

### 3. Packer Image Build Playbooks

Playbooks specifically designed for use during Packer image builds to pre-install software.

| Playbook | Component | Purpose | Use Case |
|----------|-----------|---------|----------|
| **playbook-hpc-packer-controller.yml** | HPC Controller (Packer) | Controller image preparation with BeeGFS | Controller image building |
| **playbook-hpc-packer-compute.yml** | HPC Compute (Packer) | Compute node image preparation with BeeGFS | Compute image building |

**Note:** BeeGFS installation is now integrated into the HPC Packer playbooks. The separate `playbook-beegfs-packer-install.yml`
has been consolidated for simplicity.

## Quick Start Usage

### Basic Commands

```bash
# Deploy complete HPC cluster runtime configuration
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml

# Deploy cloud infrastructure
ansible-playbook -i inventories/cloud/hosts.yml playbook-cloud.yml

# Configure specific component
ansible-playbook -i inventories/hpc/hosts.yml playbook-container-registry.yml

# Configure BeeGFS storage
ansible-playbook -i inventories/hpc/hosts.yml playbook-beegfs-runtime-config.yml

# Build HPC images with Packer (requires SLURM packages built first)
packer build packer/hpc-controller/hpc-controller.pkr.hcl
packer build packer/hpc-compute/hpc-compute.pkr.hcl

# Run with verbose output
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml -v

# Run with extra debug output
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml -vvv
```

### Executing Specific Plays

Most playbooks contain plays targeting different host groups. You can execute specific plays:

```bash
# Run only controller configuration
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml --limit hpc_controllers

# Run only compute node configuration
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml --limit compute_nodes

# Run with specific tags (if defined in playbook)
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml --tags slurm
```

### Running Playbooks with Custom Variables

```bash
# Override default variables
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml \
  -e slurm_version=24.11.0

# Load variables from file
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml \
  -e @/path/to/vars.yml
```

## Inventory Requirements

Playbooks require properly configured inventory with:

1. **Host Groups**: Hosts organized by function (controllers, compute, storage, etc.)
2. **Host Variables**: Configuration variables for each host or group
3. **Group Variables**: Shared variables for groups of hosts

### Typical Inventory Structure

```yaml
hpc_cluster:
  children:
    hpc_controllers:
      hosts:
        hpc-controller:
          ansible_host: 10.0.1.10
          slurm_node_type: controller
    hpc_compute:
      hosts:
        hpc-compute-01:
          ansible_host: 10.0.2.11
          gpu_count: 4
        hpc-compute-02:
          ansible_host: 10.0.2.12
    hpc_storage:
      hosts:
        hpc-storage-01:
          ansible_host: 10.0.3.10
  vars:
    slurm_cluster_name: hpc-cluster
    beegfs_fs_name: beegfs_fs
```

See `inventories/` directory for complete inventory examples.

## Playbook Execution Workflow

### Pre-Deployment Phase

1. **Prepare Inventory**: Create/update inventory with target hosts
2. **Verify Connectivity**: Ensure SSH access to all hosts
3. **Check Variables**: Verify all required variables are set

### Deployment Phase

1. **Run Infrastructure Playbook**: Execute appropriate cluster playbook
2. **Monitor Progress**: Observe playbook execution for errors
3. **Handle Failures**: Investigate and resolve any task failures

### Post-Deployment Phase

1. **Run Runtime Configuration**: Execute runtime playbooks if needed
2. **Verify Deployment**: Test cluster functionality
3. **Collect Logs**: Archive deployment logs

## Common Playbook Patterns

### Pattern 1: Complete Cluster Deployment

```bash
# Deploy entire HPC cluster runtime configuration
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml
```

This executes all configurations for all host types:

- SLURM controller and compute services
- Cgroup resource isolation
- GPU GRES configuration
- Job scripts deployment
- Monitoring stack (Prometheus, Grafana, DCGM)
- Container runtime validation

### Pattern 2: Component-Specific Deployment

```bash
# Add container registry to existing cluster
ansible-playbook -i inventories/hpc/hosts.yml playbook-container-registry.yml

# Configure BeeGFS storage
ansible-playbook -i inventories/hpc/hosts.yml playbook-beegfs-runtime-config.yml

# Configure shared storage with Virtio-FS
ansible-playbook -i inventories/hpc/hosts.yml playbook-virtio-fs-runtime-config.yml
```

### Pattern 3: Node-Specific Configuration

```bash
# Configure only controller nodes
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml --limit hpc_controllers

# Configure only compute nodes
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml --limit compute_nodes
```

### Pattern 4: Packer Image Building

```bash
# Build HPC controller image with pre-installed packages
packer build -var 'packer_build=true' packer/hpc-controller/hpc-controller.pkr.hcl

# Build HPC compute image with pre-installed packages
packer build -var 'packer_build=true' packer/hpc-compute/hpc-compute.pkr.hcl
```

## Playbook Variables

Each playbook supports configuration variables that can be specified in:

1. **Inventory Files**: Host or group variables in `inventories/`
2. **Command Line**: Using `-e` flag with `ansible-playbook`
3. **Variable Files**: Using `-e @filename` with variable definitions
4. **Role Defaults**: Default variables in role `defaults/main.yml`

### How to Identify Playbook Variables

To understand what variables a playbook accepts, follow these steps:

#### Method 1: Read the Playbook File Header

Each playbook includes documentation at the top of the file:

```bash
# View playbook header documentation
head -n 30 playbooks/playbook-hpc-runtime.yml
```

Look for:

- Usage examples in comments
- Variable references in task names
- Configuration blocks in the header

#### Method 2: Search for Variable Definitions in Playbook

Variables can be defined in multiple places within a playbook:

```bash
# Find all vars: blocks in the playbook
grep -A 10 "vars:" playbooks/playbook-hpc-runtime.yml

# Find all variable references ({{ variable_name }})
grep -o "{{[^}]*}}" playbooks/playbook-hpc-runtime.yml | sort -u

# Find all -e command line examples
grep "\-e " playbooks/playbook-hpc-runtime.yml
```

**Example output interpretation:**

```yaml
vars:
  slurm_version: "24.11.0"                      # ← Playbook-level variable
  slurm_packages_source_dir: "{{ playbook_dir }}/../../build/packages/slurm"
```

#### Method 3: Check Role Variables

Playbooks use roles, which have their own variables. To find role variables:

```bash
# List all roles used in a playbook
grep -E "roles:|role:" playbooks/playbook-hpc-runtime.yml

# View role default variables
cat roles/slurm-controller/defaults/main.yml

# Find all role documentation
find roles/ -name "README.md" -exec echo "=== {} ===" \; -exec cat {} \;
```

**See role documentation:** [roles/README.md](../roles/README.md)

#### Method 4: Check Inventory Requirements

Playbooks may expect certain inventory variables:

```bash
# Find inventory variable references
grep -E "hostvars|groups\[|inventory_hostname" playbooks/playbook-hpc-runtime.yml

# View inventory structure for examples
cat inventories/hpc/hosts.yml
```

Common inventory variables used by playbooks:

- `ansible_host`: Target host IP/hostname
- `slurm_node_name`: SLURM node name
- `gpu_count`: Number of GPUs on node
- `has_gpu`: Whether node has GPUs

#### Method 5: Use Ansible's Built-in Tools

```bash
# Check playbook syntax and see variable usage
ansible-playbook playbooks/playbook-hpc-runtime.yml --syntax-check

# See all variables that would be used (requires valid inventory)
ansible-playbook -i inventories/hpc/hosts.yml playbooks/playbook-hpc-runtime.yml --list-tasks -vv

# View all tags (indicates configurable sections)
ansible-playbook -i inventories/hpc/hosts.yml playbooks/playbook-hpc-runtime.yml --list-tags
```

#### Method 6: Look for Conditional Statements

Conditionals reveal optional variables:

```bash
# Find when: conditions that check variables
grep -A 2 "when:" playbooks/playbook-hpc-runtime.yml

# Find default() filters that show optional variables
grep "default(" playbooks/playbook-hpc-runtime.yml
```

**Example interpretation:**

```yaml
when: not ((packer_build | default(false)) | bool)
# ← This shows packer_build is optional, defaults to false
```

### Variable Discovery Example

Let's discover variables for `playbook-hpc-runtime.yml`:

```bash
# Step 1: Read header documentation
head -n 20 playbooks/playbook-hpc-runtime.yml

# Step 2: Find all vars: blocks
grep -B 2 -A 10 "vars:" playbooks/playbook-hpc-runtime.yml

# Step 3: Find variable references
grep -o "{{[^}]*}}" playbooks/playbook-hpc-runtime.yml | \
  sed 's/[{} ]//g' | sort -u

# Step 4: Check for conditionals
grep "| default(" playbooks/playbook-hpc-runtime.yml
```

**Key variables identified:**

- `packer_build`: Controls Packer vs runtime mode (default: false)
- `slurm_version`: SLURM version to use (default: "24.11.0")
- `slurm_packages_source_dir`: Location of SLURM packages
- `slurm_packages_dest_dir`: Destination for packages on nodes

### Common Variables by Playbook

**playbook-hpc-runtime.yml:**

- `packer_build`: false (must be false for runtime)
- `slurm_version`: "24.11.0"
- `slurm_packages_source_dir`: Path to built SLURM packages
- Uses inventory groups: `hpc_controllers`, `compute_nodes`

**playbook-hpc-packer-controller.yml / playbook-hpc-packer-compute.yml:**

- `packer_build`: true (must be true for Packer builds)
- Same SLURM variables as runtime playbook

**playbook-beegfs-runtime-config.yml:**

- See [BeeGFS role documentation](../roles/beegfs-mgmt/README.md)

**playbook-container-registry.yml:**

- See [Container Registry role documentation](../roles/container-registry/README.md)

See individual role documentation at [roles/](../roles/README.md) for complete variable listings.

## Troubleshooting Playbook Execution

### Playbook Fails with Connection Error

```bash
# Verify SSH connectivity
ssh -i your_key.pem user@host

# Check Ansible inventory
ansible -i inventories/hpc/hosts.yml all --list-hosts

# Test connectivity with ping module
ansible -i inventories/hpc/hosts.yml all -m ping
```

### Specific Tasks Fail

```bash
# Run with maximum verbosity for debugging
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml -vvv

# Run specific plays/tasks
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml \
  --limit hpc_controllers --start-at-task "Install SLURM packages"
```

### Playbook Takes Too Long

```bash
# Reduce scope with limits
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml \
  --limit hpc_controllers

# Run specific tags if defined
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml \
  --tags slurm

# Check for long-running tasks
ansible-playbook -i inventories/hpc/hosts.yml playbook-hpc-runtime.yml \
  -vvv 2>&1 | grep -i "time\|duration"
```

## Playbook Dependencies

Playbooks may depend on:

1. **Inventory Setup**: Proper inventory configuration required
2. **Network Access**: SSH access to all target hosts
3. **Ansible Collections**: Collections specified in `requirements.yml`
4. **Roles**: All referenced roles must be present in `roles/` directory

Verify dependencies before running:

```bash
# Install Ansible requirements
ansible-galaxy install -r requirements.yml

# Verify role availability
ls -la roles/ | grep -E "beegfs|slurm|nvidia"

# Check inventory and playbook syntax
ansible-playbook -i inventories/hpc/hosts.yml playbooks/playbook-hpc-runtime.yml --syntax-check
```

## Best Practices

1. **Always run syntax check first**: `ansible-playbook --syntax-check playbook.yml`
2. **Use inventory groups**: Organize hosts by function rather than individual hosts
3. **Test in development**: Validate playbooks in non-production environments
4. **Monitor execution**: Use verbose output and logs to track progress
5. **Document variables**: Update playbook documentation when adding new variables
6. **Idempotent tasks**: Ensure tasks can be run multiple times safely
7. **Use conditionals**: Handle different environments and configurations
8. **Keep playbooks focused**: Each playbook should have a clear, single purpose

## See Also

- **[../README.md](../README.md)** - Main Ansible overview
- **[../roles/README.md](../roles/README.md)** - Roles index and documentation
- **TODO**: **Inventory Examples and Generator** - Create inventories/ directory with inventory examples and generator
- **[../README-packer-ansible.md](../README-packer-ansible.md)** - Packer-specific usage
