# GPU GRES Workflow Documentation

## Overview

This document describes the workflow for deploying and testing GPU resources (GRES - Generic Resource Scheduling)
configuration in SLURM as implemented in Task 023. The GPU GRES deployment follows a two-phase approach:
build-time preparation and runtime configuration.

## Architecture

### Components

- **GRES Configuration**: Defines GPU resources available on compute nodes (`/etc/slurm/gres.conf`)
- **SLURM Configuration**: References GRES types in main SLURM config (`/etc/slurm/slurm.conf`)
- **GPU Detection**: Utilities for detecting and mapping GPU devices (lspci, nvidia-smi)
- **Resource Scheduling**: SLURM scheduler manages GPU allocation to jobs
- **Device Isolation**: Cgroup integration ensures exclusive GPU access per job

### GPU Resource Flow

```text
┌──────────────────┐
│ SLURM Controller │
│   (slurmctld)    │
└────────┬─────────┘
         │
         │ GPU Resource Requests
         │ (--gres=gpu:1)
         │
    ┌────┴─────┬──────────────┐
    │          │              │
┌───▼────┐ ┌──▼─────┐ ┌──────▼───┐
│Compute1│ │Compute2│ │ Compute3 │
│ 2 GPUs │ │ 4 GPUs │ │  1 GPU   │
│(slurmd)│ │(slurmd)│ │ (slurmd) │
└────────┘ └────────┘ └──────────┘
```

## Deployment Phases

### Phase 1: Build-Time Preparation (Packer)

Runs during Packer image creation with `packer_build=true`:

1. **Directory Structure**
   - Create `/etc/slurm` directory
   - Set up proper permissions

2. **Utility Installation**
   - Install GPU detection utilities (pciutils, lshw)
   - Prepare GRES configuration templates

3. **What is NOT Done**
   - GPU devices are NOT configured
   - GRES configuration is NOT deployed
   - GPU detection is NOT performed
   - Services are NOT configured with GRES

**Purpose**: Prepare the image with tools and directory structure for GRES configuration

### Phase 2: Runtime Configuration

Runs during VM deployment with `packer_build=false`:

1. **GPU Detection**
   - Detect available GPU devices via lspci
   - Map GPU devices to device files (/dev/nvidia*)
   - Determine GPU types and counts

2. **GRES Configuration Deployment**
   - Generate gres.conf from inventory variables
   - Deploy configuration to /etc/slurm/gres.conf
   - Configure auto-detection (if enabled)

3. **Service Configuration**
   - Update slurm.conf with GresTypes
   - Restart slurmd with GRES support
   - Verify GRES configuration

4. **Validation**
   - Check GPU visibility in SLURM
   - Verify resource counts match hardware
   - Test GPU allocation capability
   - Validate GPU scheduling

**Purpose**: Configure node-specific GPU resources and integrate with SLURM scheduler

## GRES Configuration

### Manual GPU Configuration

Example `/etc/slurm/gres.conf` for manual GPU configuration:

```ini
# Manual GPU configuration
NodeName=compute-01 Name=gpu Type=rtx4090 File=/dev/nvidia0
NodeName=compute-01 Name=gpu Type=rtx4090 File=/dev/nvidia1
NodeName=compute-02 Name=gpu Type=a100 File=/dev/nvidia0
NodeName=compute-02 Name=gpu Type=a100 File=/dev/nvidia1
NodeName=compute-02 Name=gpu Type=a100 File=/dev/nvidia2
NodeName=compute-02 Name=gpu Type=a100 File=/dev/nvidia3

# Shared mode configuration (optional)
Shared=no  # Exclusive GPU access (default)
# Shared=yes  # Allow GPU sharing between jobs
```

### Auto-Detection Configuration

Example `/etc/slurm/gres.conf` using NVML auto-detection:

```ini
# Auto-detection mode using NVML (NVIDIA Management Library)
AutoDetect=nvml

# This requires:
# - NVIDIA drivers installed
# - nvidia-smi available
# - CUDA toolkit (for NVML)
```

### SLURM Main Configuration

Update `/etc/slurm/slurm.conf` to enable GRES:

```ini
# Enable GRES support
GresTypes=gpu

# Node configuration with GRES
NodeName=compute-01 Gres=gpu:rtx4090:2 CPUs=32 RealMemory=128000
NodeName=compute-02 Gres=gpu:a100:4 CPUs=64 RealMemory=256000

# Partition configuration
PartitionName=gpu Nodes=compute-[01-02] Default=YES MaxTime=INFINITE State=UP
```

## Ansible Role Structure

### Directory Layout

```text
ansible/roles/slurm-compute/
├── tasks/
│   ├── main.yml              # Main orchestration
│   ├── install.yml           # Package installation
│   ├── configure.yml         # Service configuration
│   └── gres.yml              # GRES configuration (Task 023)
├── templates/
│   ├── slurm.conf.j2         # SLURM main configuration
│   ├── cgroup.conf.j2        # Cgroup configuration
│   └── gres.conf.j2          # GRES configuration (Task 023)
└── handlers/
    └── main.yml              # Service restart handlers
```

### Variables

Key variables for GRES configuration:

```yaml
# Enable GRES configuration
slurm_gres_enabled: true

# Auto-detection settings
slurm_gres_autodetect: false  # Set to true for NVML auto-detection
slurm_gres_gpu_type: "gpu"
slurm_gres_shared: false

# Manual GPU device configuration
slurm_gres_gpu_devices:
  - device_file: /dev/nvidia0
    type: rtx4090
  - device_file: /dev/nvidia1
    type: rtx4090

# Node name for GRES configuration
slurm_compute_node_name: "{{ inventory_hostname }}"
```

## Test Framework

### Test Structure

```text
tests/
├── test-gpu-gres-framework.sh         # Main test framework
├── test-infra/
│   └── configs/
│       └── test-gpu-gres.yaml         # Test cluster configuration
└── suites/
    └── gpu-gres/
        ├── check-gres-configuration.sh # GRES config validation
        ├── check-gpu-detection.sh      # GPU detection tests
        ├── check-gpu-scheduling.sh     # GPU scheduling tests
        └── run-gpu-gres-tests.sh       # Master test runner
```

### Test Categories

1. **GRES Configuration Tests** (`check-gres-configuration.sh`)
   - GRES configuration file exists and is readable
   - Configuration syntax is valid
   - Required directories exist
   - SLURM integration configured

2. **GPU Detection Tests** (`check-gpu-detection.sh`)
   - PCI GPU devices detection
   - NVIDIA device files present
   - nvidia-smi availability
   - slurmd GPU detection
   - GRES device file validation

3. **GPU Scheduling Tests** (`check-gpu-scheduling.sh`)
   - Node information includes GRES
   - GPU resources visible in sinfo
   - GRES types configured
   - GPU job submission capability
   - Configuration consistency

### Running Tests

#### Complete End-to-End Test

```bash
# Run full test with automatic cluster creation and cleanup
cd tests
./test-gpu-gres-framework.sh e2e

# With verbose output
./test-gpu-gres-framework.sh --verbose e2e

# Keep cluster running after test (for debugging)
./test-gpu-gres-framework.sh --no-cleanup e2e
```

#### Modular Testing Workflow

```bash
# Start cluster once
./test-gpu-gres-framework.sh start-cluster

# Deploy GRES configuration
./test-gpu-gres-framework.sh deploy-ansible

# Run all tests (can repeat)
./test-gpu-gres-framework.sh run-tests

# List available individual tests
./test-gpu-gres-framework.sh list-tests

# Run specific test
./test-gpu-gres-framework.sh run-test check-gres-configuration.sh

# Check cluster status
./test-gpu-gres-framework.sh status

# Clean up when done
./test-gpu-gres-framework.sh stop-cluster
```

#### Makefile Targets

```bash
# Option 1: Full workflow (default - create + deploy + test)
make test-gpu-gres

# Option 2: Phased workflow (for debugging)
make test-gpu-gres-start   # Start cluster
make test-gpu-gres-deploy  # Deploy Ansible config
make test-gpu-gres-tests   # Run tests
make test-gpu-gres-stop    # Stop cluster

# Option 3: Check status
make test-gpu-gres-status
```

## GPU Job Submission

### Basic GPU Job

```bash
# Request single GPU
srun --gres=gpu:1 hostname

# Request specific GPU type
srun --gres=gpu:rtx4090:1 nvidia-smi

# Request multiple GPUs
srun --gres=gpu:2 nvidia-smi
```

### Batch Job with GPU

```bash
#!/bin/bash
#SBATCH --job-name=gpu_test
#SBATCH --gres=gpu:1
#SBATCH --time=00:10:00

# Your GPU workload
nvidia-smi
python train_model.py
```

### GPU Allocation Verification

```bash
# Check GPU allocation
squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %b"

# Show node GPU status
sinfo -o "%N %G %C %m"

# Check specific node details
scontrol show node compute-01
```

## Monitoring and Debugging

### Check GRES Configuration

```bash
# View GRES configuration
cat /etc/slurm/gres.conf

# Check slurmd configuration
slurmd -C

# View SLURM configuration
grep -i gres /etc/slurm/slurm.conf
```

### GPU Detection

```bash
# List PCI GPU devices
lspci | grep -i vga

# Check NVIDIA devices
ls -la /dev/nvidia*

# Run nvidia-smi
nvidia-smi

# Check GPU driver version
nvidia-smi --query-gpu=driver_version --format=csv,noheader
```

### SLURM GRES Status

```bash
# Check node GRES configuration
scontrol show node <nodename>

# View GRES resources
sinfo -o "%N %G"

# Check GPU allocation
squeue --Format=JobID,Partition,Name,UserName,State,Tres
```

### Common Issues

#### Issue: GPUs not visible in SLURM

**Diagnosis:**

```bash
# Check if GRES is configured
grep GresTypes /etc/slurm/slurm.conf
cat /etc/slurm/gres.conf

# Check slurmd configuration
slurmd -C | grep -i gres

# Verify GPU devices exist
ls -la /dev/nvidia*
```

**Solution:**

- Ensure GresTypes is set in slurm.conf
- Verify gres.conf has correct device paths
- Restart slurmd: `systemctl restart slurmd`
- Check slurmd logs: `journalctl -u slurmd`

#### Issue: nvidia-smi not found

**Diagnosis:**

```bash
# Check if NVIDIA drivers are installed
dpkg -l | grep nvidia

# Check driver status
modprobe -l | grep nvidia
lsmod | grep nvidia
```

**Solution:**

- Install NVIDIA drivers
- Load nvidia kernel module
- Verify GPU is visible: `lspci | grep -i nvidia`

#### Issue: GPU allocation fails

**Diagnosis:**

```bash
# Check node state
scontrol show node <nodename>

# Check SLURM logs
tail -f /var/log/slurm/slurmd.log

# Verify job submission
srun --gres=gpu:1 --pty bash
```

**Solution:**

- Ensure node is in IDLE state
- Verify GRES counts match hardware
- Check cgroup configuration for device isolation
- Restart slurmd service

## Integration with Cgroups

GRES works with cgroups to enforce GPU isolation:

```ini
# /etc/slurm/cgroup.conf
ConstrainDevices=yes
AllowedDevicesFile=/etc/slurm/cgroup_allowed_devices_file.conf
```

```ini
# /etc/slurm/cgroup_allowed_devices_file.conf
/dev/nvidia* # Allow NVIDIA devices
/dev/nvidiactl
/dev/nvidia-uvm
```

## Best Practices

### Configuration

1. **Use Auto-Detection**: Enable `AutoDetect=nvml` for dynamic GPU configuration
2. **Match Hardware**: Ensure GRES counts match actual GPU hardware
3. **Consistent Naming**: Use consistent GPU type names across cluster
4. **Test Changes**: Always test GRES configuration changes before production deployment

### Deployment

1. **Packer Separation**: Don't configure actual GPUs during Packer build
2. **Runtime Configuration**: Deploy GRES configuration at runtime with actual hardware
3. **Service Restart**: Always restart slurmd after GRES configuration changes
4. **Validation**: Run validation tests after deployment

### Monitoring

1. **Regular Checks**: Monitor GPU utilization and allocation
2. **Log Monitoring**: Watch slurmd logs for GRES-related errors
3. **Resource Tracking**: Track GPU resource usage via sacct
4. **Health Checks**: Implement periodic GPU health checks

## References

- SLURM GRES Documentation: <https://slurm.schedmd.com/gres.html>
- NVIDIA Management Library: <https://developer.nvidia.com/nvidia-management-library-nvml>
- Task 023 Implementation: `docs/implementation-plans/task-lists/hpc-slurm-task-list.md`
