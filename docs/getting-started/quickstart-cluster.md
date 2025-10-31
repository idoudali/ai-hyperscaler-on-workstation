# Cluster Deployment Quickstart

**Status:** Production  
**Last Updated:** 2025-10-31  
**Target Time:** 15-20 minutes  
**Prerequisites:** [5-Minute Quickstart](quickstart-5min.md) completed

## Overview

Deploy a complete HPC cluster with SLURM orchestration in 15-20 minutes. This quickstart walks you through building
Packer images, deploying VMs, and running your first SLURM job.

**What You'll Deploy:**

- SLURM Controller Node (slurmctld)
- SLURM Compute Node (slurmd)
- Shared network configuration
- Complete SLURM cluster with job scheduling

**What You'll Learn:**

- Build controller and compute images with Packer
- Deploy VMs using the Python CLI
- Submit and monitor SLURM jobs
- View job results and logs

## Prerequisites Check

Before starting, ensure you've completed the [5-Minute Quickstart](quickstart-5min.md):

```bash
# Verify build system is configured
ls build/build.ninja

# Verify Python CLI is available
source .venv/bin/activate
ai-how --version
```

## Step 1: Build Packer Images (8-10 minutes)

Build the required images for controller and compute nodes:

```bash
# Navigate to build directory
cd build

# Build HPC base image (foundation for all nodes)
ninja build-hpc-base-image

# Build HPC controller image (SLURM controller + database)
ninja build-hpc-controller-image

# Build HPC compute image (SLURM compute daemon)
ninja build-hpc-compute-image
```

**Expected Output:**

```text
Building HPC base image... ✓
Building HPC controller image... ✓
Building HPC compute image... ✓
All images built successfully
```

**Note:** Image builds take 8-10 minutes total. They install and configure:

- **Base:** Ubuntu 22.04, system packages, networking
- **Controller:** SLURM controller, slurmctld, MariaDB, MUNGE
- **Compute:** SLURM compute daemon, slurmd, MUNGE, PMIx

## Step 2: Verify Images (30 seconds)

```bash
# List built images
ls -lh packer/hpc-base/output/
ls -lh packer/hpc-controller/output/
ls -lh packer/hpc-compute/output/

# You should see .qcow2 image files
```

**Expected Files:**

```text
packer/hpc-base/output/hpc-base.qcow2
packer/hpc-controller/output/hpc-controller.qcow2
packer/hpc-compute/output/hpc-compute.qcow2
```

## Step 3: Configure Cluster (1 minute)

Create a cluster configuration file:

```bash
# Return to project root
cd ..

# Create config directory if it doesn't exist
mkdir -p config/clusters

# Create cluster configuration
cat > config/clusters/quickstart-cluster.yml << 'EOF'
clusters:
  hpc:
    name: quickstart-hpc
    controller:
      name: hpc-controller
      ip_address: 192.168.190.10
      cpu_cores: 2
      memory_gb: 4
      disk_gb: 20
    compute_nodes:
      - name: hpc-compute-01
        ip_address: 192.168.190.131
        cpu_cores: 4
        memory_gb: 8
        disk_gb: 30
        has_gpu: false
    network:
      name: quickstart-net
      bridge: virbr-quickstart
      subnet: 192.168.190.0/24
      dhcp_range:
        start: 192.168.190.100
        end: 192.168.190.200
EOF
```

## Step 4: Deploy Cluster (3-5 minutes)

Deploy the cluster using the Python CLI:

```bash
# Activate Python environment
source .venv/bin/activate

# Deploy network
ai-how network create --config config/clusters/quickstart-cluster.yml

# Deploy controller VM
ai-how vm deploy hpc-controller \
    --config config/clusters/quickstart-cluster.yml \
    --image build/packer/hpc-controller/output/hpc-controller.qcow2

# Deploy compute VM
ai-how vm deploy hpc-compute-01 \
    --config config/clusters/quickstart-cluster.yml \
    --image build/packer/hpc-compute/output/hpc-compute.qcow2

# Wait for VMs to boot (typically 60-90 seconds)
sleep 90
```

**Expected Output:**

```text
Network 'quickstart-net' created successfully
VM 'hpc-controller' deployed and starting
VM 'hpc-compute-01' deployed and starting
VMs booting...
```

## Step 5: Verify Cluster (1 minute)

Check that all VMs are running:

```bash
# List VMs
ai-how vm list

# Check VM status
virsh list --all

# Verify network connectivity
ping -c 2 192.168.190.10     # Controller
ping -c 2 192.168.190.131    # Compute node
```

**Expected Output:**

```text
 Id   Name              State
----------------------------------
 1    hpc-controller    running
 2    hpc-compute-01    running

Both nodes reachable via ping
```

## Step 6: Access Controller (30 seconds)

SSH into the controller to verify SLURM:

```bash
# SSH to controller (default password: admin or use SSH key)
ssh admin@192.168.190.10

# Check SLURM status
sinfo
squeue
scontrol show nodes
```

**Expected Output:**

```text
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
compute*     up   infinite      1   idle hpc-compute-01
```

## Step 7: Submit Your First Job (1 minute)

Run a simple test job on the cluster:

```bash
# From the controller node

# Create a test job script
cat > test-job.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=quickstart-test
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:01:00
#SBATCH --output=quickstart-test-%j.out

echo "Hello from SLURM!"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "CPUs: $SLURM_CPUS_ON_NODE"
hostname
date
sleep 5
echo "Job completed successfully"
EOF

# Submit the job
sbatch test-job.sh

# Check job status
squeue

# Wait for job to complete
sleep 10
```

**Expected Output:**

```text
Submitted batch job 1
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST
    1   compute quicksta    admin  R       0:01      1 hpc-compute-01
```

## Step 8: View Results (30 seconds)

```bash
# List output files
ls -lh quickstart-test-*.out

# View job output
cat quickstart-test-1.out
```

**Expected Output:**

```text
Hello from SLURM!
Job ID: 1
Node: hpc-compute-01
CPUs: 4
hpc-compute-01
Thu Oct 31 12:34:56 UTC 2025
Job completed successfully
```

## ✅ Success!

You now have a fully functional HPC cluster with:

- ✅ SLURM controller managing the cluster
- ✅ Compute node registered and available
- ✅ Job submission and execution working
- ✅ Results captured in output files

## Next Steps

### Run More Jobs

```bash
# Submit multiple jobs
for i in {1..5}; do
    sbatch test-job.sh
done

# Monitor job queue
watch squeue

# View all job history
sacct
```

### Explore SLURM Features

```bash
# View node details
scontrol show node hpc-compute-01

# Check partition information
scontrol show partition compute

# View cluster configuration
scontrol show config | head -30
```

### Add More Compute Nodes

Edit `config/clusters/quickstart-cluster.yml` and add more compute nodes:

```yaml
compute_nodes:
  - name: hpc-compute-01
    ip_address: 192.168.190.131
    # ... existing config
  - name: hpc-compute-02    # New node
    ip_address: 192.168.190.132
    cpu_cores: 4
    memory_gb: 8
    disk_gb: 30
    has_gpu: false
```

Then deploy the new node:

```bash
ai-how vm deploy hpc-compute-02 \
    --config config/clusters/quickstart-cluster.yml \
    --image build/packer/hpc-compute/output/hpc-compute.qcow2
```

### Try GPU Workloads

See [GPU Quickstart](quickstart-gpu.md) to:

- Configure GPU passthrough
- Deploy GPU-enabled compute nodes
- Run GPU-accelerated jobs

### Deploy Containers

See [Container Quickstart](quickstart-containers.md) to:

- Build container images
- Run containerized workloads on SLURM
- Use Apptainer/Singularity containers

### Set Up Monitoring

See [Monitoring Quickstart](quickstart-monitoring.md) to:

- Deploy Prometheus and Grafana
- Monitor cluster resources
- View job metrics and logs

## Cluster Management

### Check Cluster Health

```bash
# From controller node

# Node status
sinfo -Nel

# Service status
systemctl status slurmctld
systemctl status slurmdbd

# View logs
journalctl -u slurmctld -n 50
```

### Stop/Start Cluster

```bash
# From host system

# Stop VMs gracefully
ai-how vm stop hpc-compute-01
ai-how vm stop hpc-controller

# Start VMs
ai-how vm start hpc-controller
sleep 30  # Wait for controller to fully start
ai-how vm start hpc-compute-01
```

### Remove Cluster

```bash
# Stop and remove VMs
ai-how vm destroy hpc-compute-01 --force
ai-how vm destroy hpc-controller --force

# Remove network
ai-how network destroy quickstart-net
```

## Troubleshooting

### VMs Don't Start

**Issue:** VM deployment fails or VMs don't boot

**Solution:**

```bash
# Check libvirt status
sudo systemctl status libvirtd

# Check VM logs
virsh console hpc-controller  # Press Ctrl+] to exit

# Verify images exist
ls -lh build/packer/*/output/*.qcow2
```

### SLURM Nodes Not Responding

**Issue:** `sinfo` shows nodes in `down` state

**Solution:**

```bash
# From controller, check node status
scontrol show node hpc-compute-01

# Update node state if needed
scontrol update nodename=hpc-compute-01 state=resume

# Check slurmd on compute node
ssh admin@192.168.190.131
systemctl status slurmd
journalctl -u slurmd -n 50
```

### Jobs Stay in Pending State

**Issue:** Jobs don't start, remain in `PD` (pending) state

**Solution:**

```bash
# Check why job is pending
squeue --start

# Check partition and node availability
sinfo -Nel

# Verify resources requested match available
scontrol show partition compute
```

For more troubleshooting, see:

- [Common Issues Guide](../troubleshooting/common-issues.md)
- [Debugging Guide](../troubleshooting/debugging-guide.md)
- [SLURM Workflow Documentation](../workflows/SLURM-COMPUTE-WORKFLOW.md)

## What's Next?

**Continue your learning journey:**

- **[First Cluster Tutorial](../tutorials/01-first-cluster.md)** - Deep dive into cluster setup
- **[GPU Quickstart](quickstart-gpu.md)** - Add GPU capabilities (10 min)
- **[Container Quickstart](quickstart-containers.md)** - Run containerized workloads (10 min)
- **[Distributed Training Tutorial](../tutorials/02-distributed-training.md)** - Multi-node ML training

**Understand the architecture:**

- **[SLURM Architecture](../architecture/slurm.md)** - How SLURM scheduling works
- **[Network Architecture](../architecture/network.md)** - Cluster networking design
- **[Storage Architecture](../architecture/storage.md)** - Storage configuration

## Summary

In 15-20 minutes, you've:

1. ✅ Built Packer images for controller and compute nodes
2. ✅ Deployed a complete HPC cluster with SLURM
3. ✅ Submitted and ran your first SLURM job
4. ✅ Verified job execution and viewed results

**Congratulations!** You now have a fully functional HPC cluster running on your workstation, ready for distributed
computing, ML training, and scientific workloads.
