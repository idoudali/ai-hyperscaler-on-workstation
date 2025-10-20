# SLURM Compute Role

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This Ansible role configures SLURM compute nodes for HPC cluster deployments. Compute nodes
execute jobs submitted to the SLURM scheduler and report resource availability and utilization
to the controller.

## Purpose

The SLURM compute role provides:

- **SLURM Compute Daemon** (slurmd): Node-level job executor and resource reporter
- **MUNGE Authentication**: Secure communication with controller
- **Job Execution Environment**: Container, GPU, and resource support
- **Cgroup Integration**: Resource isolation and constraint enforcement
- **GPU GRES Setup**: Generic Resource configuration for GPU scheduling
- **Task Affinity**: CPU and memory affinity for performance optimization

## Variables

### Required Variables

- `slurm_cluster_name`: Must match controller cluster name
- `slurm_controller_addr`: IP/hostname of SLURM controller

### Key Configuration Variables

**Basic Configuration:**

- `slurm_version`: SLURM version (default: 21.08)
- `slurm_node_sockets`: Number of CPU sockets (default: 1)
- `slurm_node_cores_per_socket`: Cores per socket (default: 8)
- `slurm_node_threads_per_core`: Threads per core (default: 2)

**GPU Support:**

- `gpu_count`: Number of GPUs on this node
- `gres_types`: Available GRES types (default: gpu)
- `slurm_constrain_devices`: Constrain GPU access (default: yes)

**Resource Constraints:**

- `slurm_constrain_ram_space`: Enforce memory limits (default: yes)
- `slurm_constrain_cores`: Enforce core limits (default: yes)
- `slurm_constrain_swap_space`: Constrain swap (default: no)

**Process Tracking:**

- `slurm_proctrack_type`: Process tracking method (default: proctrack/cgroup)
- `slurm_task_plugin`: Task plugin (default: task/cgroup,task/affinity)
- `slurm_task_plugin_param`: Plugin parameters (default: Sched)

**Container Support:**

- `slurm_container_integration`: Enable container jobs (default: false)
- `container_install_method`: Container runtime installation (default: skip)

**Logging:**

- `slurm_compute_log_file`: Log file path (default: /var/log/slurm/slurmd.log)

## Usage

### Basic Usage

Include the role for all compute nodes:

```yaml
- hosts: hpc_compute
  become: true
  roles:
    - slurm-compute
  vars:
    slurm_cluster_name: "my-hpc-cluster"
    slurm_controller_addr: "10.0.1.10"
```

### Compute Nodes with GPUs

```yaml
- hosts: hpc_compute_gpu
  become: true
  roles:
    - slurm-compute
  vars:
    slurm_cluster_name: "hpc"
    slurm_controller_addr: "10.0.1.10"
    gpu_count: 4
    gres_types: "gpu"
    slurm_constrain_devices: "yes"
```

### High-Performance Compute Nodes

```yaml
- hosts: hpc_compute_hpc
  become: true
  roles:
    - slurm-compute
  vars:
    slurm_cluster_name: "hpc"
    slurm_controller_addr: "10.0.1.10"
    slurm_node_sockets: 2
    slurm_node_cores_per_socket: 16
    slurm_node_threads_per_core: 2
    slurm_task_plugin_param: "Sched"  # Better for MPI jobs
```

### With Container Support

```yaml
- hosts: hpc_compute
  become: true
  roles:
    - slurm-compute
  vars:
    slurm_cluster_name: "hpc"
    slurm_controller_addr: "10.0.1.10"
    slurm_container_integration: true
    container_install_method: "package"
```

## Dependencies

This role requires:

- Debian-based system
- Root privileges
- SLURM controller deployment completed
- Same SLURM version as controller
- Matching MUNGE key from controller

### Pre-requirements

Before deploying this role:

1. Deploy SLURM controller node
2. Ensure compute nodes can reach controller on port 6817-6819
3. Distribute MUNGE key from controller to compute nodes
4. Ensure consistent system configuration across nodes

## What This Role Does

1. **Installs SLURM Client**: SLURM command-line tools and libraries
2. **Installs MUNGE**: Authentication daemon matching controller setup
3. **Distributes MUNGE Key**: Copies authentication key from controller
4. **Configures Slurmd**: Node daemon with resource reporting
5. **Configures Cgroups**: Resource isolation via Linux cgroups
6. **Sets Up GPU GRES**: GPU resource discovery and configuration
7. **Configures Task Plugins**: CPU affinity and memory pinning
8. **Enables Slurmd Service**: Configures systemd for auto-start
9. **Starts Slurmd**: Initializes node daemon to join cluster
10. **Verifies Connectivity**: Tests connection to controller

## Tags

Available Ansible tags:

- `slurm_compute`: All compute node tasks
- `slurm_packages`: Package installation only
- `munge`: MUNGE authentication setup
- `slurmd`: Compute daemon configuration
- `slurm_gpu`: GPU GRES configuration
- `slurm_cgroups`: Cgroup setup
- `slurm_container`: Container integration

### Using Tags

```bash
# Configure GPUs only
ansible-playbook playbook.yml --tags slurm_gpu

# Skip MUNGE setup
ansible-playbook playbook.yml --skip-tags munge
```

## Example Playbook

```yaml
---
- name: Deploy SLURM Compute Nodes
  hosts: hpc_compute
  become: yes
  roles:
    - slurm-compute
  vars:
    slurm_cluster_name: "production-hpc"
    slurm_controller_addr: "controller.hpc.local"
    slurm_node_sockets: 2
    slurm_node_cores_per_socket: 16
    slurm_node_threads_per_core: 2
    slurm_task_plugin_param: "Sched"
    gpu_count: 4
    gres_types: "gpu"
```

## Service Management

```bash
# Check compute node status
systemctl status slurmd

# Restart compute daemon
systemctl restart slurmd

# View compute daemon logs
journalctl -u slurmd -f

# Enable auto-start
systemctl enable slurmd
```

## Verification

After deployment, verify compute node setup:

```bash
# From controller: check node state
sinfo

# Check node details
sinfo -N -l

# View node features
sinfo -o "%N %G"  # Shows GPUs if configured

# Test job submission
srun -n1 hostname  # Should run on a compute node

# Monitor job execution
squeue
```

## Common Configurations

### Standard CPU-Only Compute Node

```yaml
slurm_cluster_name: "hpc"
slurm_controller_addr: "10.0.1.10"
slurm_node_sockets: 1
slurm_node_cores_per_socket: 8
slurm_node_threads_per_core: 2
```

### GPU Compute Node (4x NVIDIA GPU)

```yaml
slurm_cluster_name: "hpc"
slurm_controller_addr: "10.0.1.10"
gpu_count: 4
gres_types: "gpu"
slurm_constrain_devices: "yes"
slurm_node_sockets: 2
slurm_node_cores_per_socket: 16
slurm_node_threads_per_core: 1  # Often 1 for GPU nodes
```

### High-Memory Compute Node

```yaml
slurm_cluster_name: "hpc"
slurm_controller_addr: "10.0.1.10"
slurm_node_sockets: 4
slurm_node_cores_per_socket: 32
slurm_node_threads_per_core: 1
slurm_constrain_ram_space: "yes"
```

### Containerized Workload Node

```yaml
slurm_cluster_name: "hpc"
slurm_controller_addr: "10.0.1.10"
slurm_container_integration: true
container_install_method: "package"
```

## Troubleshooting

### Node Not Appearing in Cluster

1. Verify controller connectivity: `ping controller_addr`
2. Check firewall rules (ports 6817-6819 to controller)
3. Verify MUNGE key matches: `ls -la /etc/munge/munge.key`
4. Check slurmd log: `tail -f /var/log/slurm/slurmd.log`

### GPU Not Recognized

1. Verify GPU drivers: `nvidia-smi`
2. Check GRES configuration: `sinfo -o "%N %G"`
3. Review slurmd log for GRES errors
4. Restart slurmd after GPU configuration

### Jobs Won't Run on Node

1. Check node state: `sinfo -N -l`
2. Verify node is UP: `scontrol show nodes`
3. Check cgroup limits
4. Review slurmd logs for constraint violations

### High CPU Usage in Slurmd

1. Check job count: `squeue | wc -l`
2. Review logging level (reduce verbosity if needed)
3. Check disk I/O (logging to slow storage)
4. Monitor memory usage: `free -h`

## Log Files

Compute nodes generate logs at:

- `/var/log/slurm/slurmd.log` - Compute daemon log
- `/var/log/munge/munged.log` - MUNGE authentication log

View logs:

```bash
# Real-time monitoring
tail -f /var/log/slurm/slurmd.log

# Search for errors
grep ERROR /var/log/slurm/slurmd.log
```

## Performance Tips

1. **Set Correct CPU Topology**: Ensure `slurm_node_sockets`, `cores_per_socket`, and `threads_per_core` match actual hardware
2. **Enable Task Affinity**: Use `task/affinity` plugin for consistent performance
3. **Use Cgroups**: Enforce resource constraints with cgroup plugin
4. **Monitor Slurmd**: Keep logs at reasonable verbosity level
5. **Batch Configuration**: Deploy identical nodes together for consistency

## Integration with Other Components

This role works with:

- **slurm-controller**: Central job scheduler (required)
- **nvidia-gpu-drivers**: GPU support on compute nodes
- **monitoring-stack**: Monitor compute node metrics
- **container-runtime**: Container job support
- **beegfs-client**: Distributed storage access

## See Also

- **[../README.md](../README.md)** - Main Ansible overview
- **[../slurm-controller/README.md](../slurm-controller/README.md)** - Controller configuration
- **[../../docs/architecture/](../../docs/architecture/)** - HPC architecture
- **[SLURM Compute Node Docs](https://slurm.schedmd.com/slurmd.html)** - Official documentation
