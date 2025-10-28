# SLURM Controller Role

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This Ansible role configures SLURM controller nodes (head nodes) for HPC cluster management.
The SLURM controller is the central component that manages job scheduling, resource allocation,
and cluster-wide policies.

## Purpose

The SLURM controller role provides:

- **SLURM Controller Daemon** (slurmctld): Central job scheduler and resource manager
- **Slurmdbd Daemon**: Database backend for job accounting and statistics
- **MUNGE Authentication**: Secure communication between cluster nodes
- **Job Accounting**: Detailed tracking of job execution and resource usage
- **PMIx Integration**: Support for advanced MPI implementations
- **GPU Resource Management**: GRES configuration for GPU scheduling
- **Container Integration**: Support for containerized workloads

## Variables

### Required Variables

- `slurm_cluster_name`: Name of the SLURM cluster
- `slurm_controller_addr`: IP address/hostname of controller for node communication

### Key Configuration Variables

**Database Configuration:**

- `slurm_database_host`: Accounting database host (default: localhost)
- `slurm_database_port`: Database port (default: 3306)
- `slurm_database_name`: Database name (default: slurm_acct_db)
- `slurm_database_user`: Database user (default: slurm)
- `slurm_database_password`: Database password (default: slurm)

**SLURM Core:**

- `slurm_version`: SLURM version (default: 21.08)
- `slurm_default_partition`: Default partition name (default: compute)
- `slurm_compute_nodes`: Compute node names/pattern (default: compute-[01-99])

**Accounting:**

- `slurm_accounting_storage_type`: Accounting storage backend (default: accounting_storage/slurmdbd)
- `slurm_job_acct_gather_type`: Job accounting method (default: jobacct_gather/linux)
- `slurm_job_acct_gather_frequency`: Accounting sample interval in seconds (default: 30)

**GPU Support:**

- `gres_types`: Available GRES types (default: gpu)
- `slurm_gpu_partition`: GPU partition name (default: gpu)
- `slurm_gpu_nodes`: GPU node names/pattern

**Scheduler:**

- `slurm_scheduler_type`: Scheduler plugin (default: sched/backfill)
- `slurm_scheduler_params`: Backfill parameters

**MPI/PMIx:**

- `pmix_enabled`: Enable PMIx support (default: true)
- `slurm_mpi_default`: Default MPI implementation (default: pmix)

**Container Support:**

- `slurm_container_integration`: Enable container job support (default: false)
- `container_install_method`: How to install container runtime (default: skip)

**Security:**

- `slurm_auth_type`: Authentication method (default: auth/munge)
- `munge_credential_ttl`: MUNGE credential time-to-live (default: 300 seconds)
- `munge_force_regenerate_key`: Regenerate MUNGE key (default: false)

### Optional Variables

See `defaults/main.yml` for complete variable list including:

- Job limits (max_job_count, max_array_size, etc.)
- Timeout configurations
- Logging and debug parameters
- Checkpoint configuration
- Power management settings

## Usage

### Basic Usage

Include the role in your playbook for controller nodes:

```yaml
- hosts: hpc_controllers
  become: true
  roles:
    - slurm-controller
  vars:
    slurm_cluster_name: "my-hpc-cluster"
    slurm_controller_addr: "10.0.1.10"
```

### With GPU Support

```yaml
- hosts: hpc_controllers
  become: true
  roles:
    - slurm-controller
  vars:
    slurm_cluster_name: "gpu-hpc"
    slurm_controller_addr: "10.0.1.10"
    gres_types: "gpu"
    slurm_gpu_partition: "gpu"
    slurm_gpu_nodes: "compute-gpu-[01-10]"
```

### With Custom Database

```yaml
- hosts: hpc_controllers
  become: true
  roles:
    - slurm-controller
  vars:
    slurm_cluster_name: "hpc"
    slurm_controller_addr: "10.0.1.10"
    slurm_database_host: "db.example.com"
    slurm_database_port: 3306
    slurm_database_name: "slurm_accounting"
    slurm_database_user: "slurm_user"
    slurm_database_password: "secure_password"
```

### With Container Support

```yaml
- hosts: hpc_controllers
  become: true
  roles:
    - slurm-controller
  vars:
    slurm_cluster_name: "hpc-containers"
    slurm_controller_addr: "10.0.1.10"
    slurm_container_integration: true
    container_install_method: "package"
```

## Dependencies

This role has no external role dependencies but requires:

- Debian-based system (Debian 11+)
- Root privileges (`become: true`)
- MariaDB or MySQL server (for accounting database)
- MUNGE authentication service
- Internet connectivity for package downloads

## What This Role Does

1. **Installs SLURM Packages**: Core SLURM WLM, slurmdbd, client tools
2. **Installs MUNGE**: Authentication daemon and libraries
3. **Configures MUNGE Key**: Sets up cluster-wide authentication key
4. **Installs Database**: MariaDB/MySQL for accounting
5. **Configures Slurmdbd**: Database daemon for job accounting
6. **Configures Slurmctld**: Main controller daemon with cluster settings
7. **Sets Partition Configuration**: Defines compute and GPU partitions
8. **Configures Job Accounting**: Enables detailed job tracking
9. **Enables PMIx**: MPI runtime integration if enabled
10. **Configures Container Support**: Installs container runtime if enabled
11. **Starts Services**: Enables and starts slurmctld and slurmdbd

## Tags

Available Ansible tags for selective execution:

- `slurm_controller`: All SLURM controller tasks
- `slurm_packages`: Package installation
- `munge`: MUNGE authentication setup
- `slurmdbd`: Database daemon configuration
- `slurmctld`: Controller daemon configuration
- `slurm_gpu`: GPU GRES configuration
- `slurm_container`: Container integration setup

### Using Tags

```bash
# Only install packages
ansible-playbook playbook.yml --tags slurm_packages

# Configure GPU support only
ansible-playbook playbook.yml --tags slurm_gpu

# Skip MUNGE setup
ansible-playbook playbook.yml --skip-tags munge
```

## Example Playbook

```yaml
---
- name: Deploy SLURM Controller
  hosts: hpc_controllers
  become: yes
  roles:
    - slurm-controller
  vars:
    slurm_cluster_name: "production-hpc"
    slurm_controller_addr: "controller.hpc.local"
    slurm_database_host: "db.hpc.local"
    slurm_database_password: "{{ vault_slurm_db_password }}"
    slurm_compute_nodes: "compute-[001-256]"
    slurm_gpu_nodes: "gpu-[001-032]"
    pmix_enabled: true
    slurm_container_integration: true
```

## Service Management

The role creates systemd services for SLURM daemons:

```bash
# Check status
systemctl status slurmctld
systemctl status slurmdbd

# Restart services
systemctl restart slurmctld
systemctl restart slurmdbd

# View logs
journalctl -u slurmctld -f
journalctl -u slurmdbd -f
```

## Verification

After deployment, verify SLURM controller operation:

```bash
# Check SLURM configuration
sinfo -l

# List available partitions
sinfo -s

# View cluster info
sinfo --summarize

# Check database connection
saccept show associations

# Verify job accounting
sacctmgr show clusters

# Test MUNGE authentication
munge -n | unmunge

# View running daemons
systemctl status slurmctld slurmdbd
```

## Log Files

SLURM controller generates logs in:

- `/var/log/slurm/slurmctld.log` - Main controller log
- `/var/log/slurm/slurmdbd.log` - Database daemon log
- `/var/log/munge/munged.log` - MUNGE authentication log

View logs with:

```bash
# Monitor controller in real-time
tail -f /var/log/slurm/slurmctld.log

# View database events
tail -f /var/log/slurm/slurmdbd.log
```

## Troubleshooting

### SLURM Services Won't Start

1. Check MUNGE service: `systemctl status munge`
2. Verify MUNGE key is present: `ls -la /etc/munge/munge.key`
3. Check database connectivity: `mysql -h $DB_HOST -u $DB_USER -p`
4. Review slurmctld logs: `tail -f /var/log/slurm/slurmctld.log`

### Nodes Not Registering

1. Ensure compute nodes have matching MUNGE key
2. Verify network connectivity between controller and compute nodes
3. Check firewall rules (SLURM uses ports 6817-6819)
4. Verify node state: `sinfo -N`

### Job Accounting Errors

1. Check database is running: `systemctl status mariadb`
2. Verify slurmdbd service: `systemctl status slurmdbd`
3. Check database user permissions
4. Review slurmdbd logs for errors

### GPU Not Detected in SLURM

1. Verify GPU GRES configuration in slurm.conf
2. Ensure NVIDIA drivers installed on compute nodes
3. Run `nvidia-smi` on compute nodes to verify GPU access
4. Check GRES configuration: `sinfo -o "%N %G"`

## Typical Deployment Sequence

1. Deploy `base-packages` role on controller
2. Deploy `slurm-controller` role on controller node
3. Deploy `slurm-compute` role on all compute nodes
4. Verify cluster with `sinfo` and `snode`
5. Submit test job: `sbatch test_job.sh`
6. Monitor job: `squeue` or `sacct`

## Performance Tuning

For large clusters, consider these optimizations:

**Scheduler Parameters:**

```yaml
slurm_scheduler_params: "bf_interval=5,bf_max_job_test=10000,bf_window=7200"
```

**Database Tuning:**

```yaml
slurm_job_acct_gather_frequency: 60  # Reduce sampling frequency
slurm_accounting_purge_job_after: 12  # Purge old records
```

**Job Limits:**

```yaml
slurm_max_job_count: 100000  # Increase for busy systems
slurm_max_array_size: 10000000  # Array job limit
```

## See Also

- **[../README.md](../README.md)** - Main Ansible overview
- **[../slurm-compute/README.md](../slurm-compute/README.md)** - Compute node configuration
- **TODO**: **HPC Architecture Documentation** - Create docs/architecture/ directory with HPC architecture documentation
- **[SLURM Official Docs](https://slurm.schedmd.com/)** - SLURM documentation
