# Tutorial 11: SLURM Debugging - Tips, Tricks, and Troubleshooting

**Level:** All Levels  
**Prerequisites:** Tutorial 08 (SLURM Basics)  
**Duration:** Reference Guide  
**Goal:** Master SLURM debugging and troubleshooting techniques

---

## Overview

This guide provides practical debugging techniques for common SLURM issues:

1. Job status investigation and queue analysis
2. Node state debugging and recovery
3. Communication issues between controller and compute nodes
4. Stuck jobs and cleanup problems
5. Resource allocation debugging
6. Performance and scheduling issues
7. Log file analysis

Use this as a reference when jobs aren't running as expected.

---

## Quick Debugging Checklist

When a job isn't working, run these commands in order:

```bash
# 1. Check job status
squeue -j <job_id>

# 2. Check detailed job info
scontrol show job <job_id>

# 3. Check node states
sinfo -Nel

# 4. Check partition info
scontrol show partition

# 5. Check controller logs
sudo journalctl -u slurmctld -n 50

# 6. Check compute node logs (on compute node)
sudo journalctl -u slurmd -n 50
```

---

## Common Issues and Solutions

### Issue 1: Job Stuck in Pending (PD) State

**Symptoms:**

```bash
$ squeue
JOBID PARTITION NAME     USER ST TIME  NODES NODELIST(REASON)
   42   compute  myjob    admin PD 0:00  2     (Resources)
```

**Diagnosis:**

```bash
# Check why job is pending
squeue -j 42 -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R"

# Common reasons shown in %R column:
# - (Resources)        : No nodes available
# - (Priority)         : Other jobs have higher priority
# - (ReqNodeNotAvail)  : Requested nodes down/drained
# - (Dependency)       : Waiting for another job
# - (QOSMaxJobsLimit)  : Hit job limit for QOS
```

**Solutions:**

```bash
# Check node availability
sinfo -Nel

# Check if nodes are idle, allocated, or down
# States: idle, allocated, mix, down, drain, completing

# If nodes are completing (stuck), see Issue 2 below

# Check partition limits
scontrol show partition compute

# Reduce resource request if too high
scontrol update job 42 NumNodes=1
```

---

### Issue 2: Nodes Stuck in "Completing" State

**Symptoms:**

```bash
$ sinfo
PARTITION AVAIL TIMELIMIT NODES STATE  NODELIST
compute*     up  infinite     2  comp   compute-[01-02]

$ squeue
JOBID PARTITION NAME     USER ST TIME  NODES NODELIST(REASON)
   41   compute  oldjob   admin CG 1:23  2     compute-[01-02]
   42   compute  newjob   admin PD 0:00  2     (Resources)
```

**What's happening:**
Job 41 was cancelled but nodes are stuck cleaning up, blocking new jobs.

**Diagnosis:**

```bash
# Check the completing job details
scontrol show job 41

# Check node daemon communication
ssh compute-01 "sudo systemctl status slurmd"
ssh compute-02 "sudo systemctl status slurmd"

# Look for errors like:
# "Unable to contact slurm controller"
# "Unable to register"
```

**Solutions:**

**Solution 1: Wait (Recommended)**

```bash
# Usually resolves in 1-2 minutes
watch -n 2 'squeue && echo && sinfo'
```

**Solution 2: Restart slurmd on compute nodes**

```bash
# If nodes stuck > 5 minutes, restart the daemon
ssh compute-01 "sudo systemctl restart slurmd"
ssh compute-02 "sudo systemctl restart slurmd"

# Verify nodes return to idle
sleep 5
sinfo -Nel
```

**Solution 3: Force node resume (use with caution)**

```bash
# Only if restart didn't work
sudo scontrol update nodename=compute-[01-02] state=resume

# Note: This may not work if jobs are actually completing
```

**Solution 4: Reconfigure SLURM**

```bash
# If all else fails, reconfigure the controller
sudo scontrol reconfigure

# Check if nodes come back
sinfo -Nel
```

---

### Issue 2b: Nodes in "Invalid" State - CPU Topology Mismatch

**Symptoms:**

```bash
$ sinfo -Nel
NODELIST    NODES PARTITION       STATE CPUS    S:C:T MEMORY TMP_DISK WEIGHT AVAIL_FE REASON              
compute-01      1       gpu       inval 16      1:8:2      1        0      1   (null) Low socket*core*thre
compute-01      1  compute*       inval 16      1:8:2      1        0      1   (null) Low socket*core*thre
compute-02      1       gpu       inval 16      1:8:2      1        0      1   (null) Low socket*core*thre
compute-02      1  compute*       inval 16      1:8:2      1        0      1   (null) Low socket*core*thre
```

**What's happening:**
The configured CPU topology (Sockets:Cores:Threads) in `slurm.conf` doesn't match the actual VM hardware.  
In this example, SLURM is configured with `1:8:2` (1 socket, 8 cores/socket, 2 threads/core = 16 CPUs),  
but the actual VM has `1:8:1` topology (1 socket, 8 cores/socket, 1 thread/core = 8 CPUs total).

**Diagnosis:**

```bash
# 1. Check actual VM hardware topology
lscpu | grep -E "Socket|Thread|Core|^CPU\(s\)"

# Example output for 8 vCPU VM:
# CPU(s):                  8
# Thread(s) per core:      1
# Core(s) per socket:      8
# Socket(s):               1

# 2. For VMs, also check libvirt XML configuration
virsh dumpxml <vm-name> | grep -A 5 '<topology'

# Example output:
# <topology sockets='1' dies='1' cores='8' threads='1'/>

# 3. Check what SLURM thinks the topology should be
scontrol show node compute-01 | grep -E "Sockets|CoresPerSocket|ThreadsPerCore|CPUTot"

# 4. Compare all three - they must match!
```

**Root Cause:**

- The Ansible role defaults had incorrect thread count (2 threads instead of 1)
- This caused SLURM to expect 16 CPUs (1×8×2) when VMs only have 8 CPUs (1×8×1)
- SLURM validation detected the mismatch and marked nodes as invalid

**Solutions:**

**Solution 1: Ansible Auto-Detection (Recommended)**

**NEW**: The SLURM roles now automatically detect CPU topology from Ansible facts!

The roles use these auto-detected facts:

- `ansible_processor_count` → Sockets
- `ansible_processor_cores` → Cores per socket
- `ansible_processor_threads_per_core` → Threads per core
- `ansible_processor_vcpus` → Total CPUs

No manual configuration needed! Just redeploy:

```bash
# 1. Navigate to ansible directory
cd ansible

# 2. Redeploy SLURM configuration (topology auto-detected)
ansible-playbook -i inventories/inventories/hpc/hosts.yml \
  playbooks/deploy-slurm-cluster.yml

# 3. Restart SLURM services
ansible -i inventories/inventories/hpc/hosts.yml hpc_controllers \
  -m systemd -a "name=slurmctld state=restarted" --become

ansible -i inventories/inventories/hpc/hosts.yml hpc_compute_nodes \
  -m systemd -a "name=slurmd state=restarted" --become

# 4. Verify nodes are now valid
sinfo -Nel
```

**How it works:**

- Ansible gathers facts from each node at runtime
- SLURM roles use these facts to configure the correct topology
- Works with any VM configuration automatically
- No need to update inventory when VM specs change

**Solution 2: Manual Fix (Temporary)**

If you need a quick fix without redeploying:

```bash
# 1. On the controller, edit slurm.conf
sudo nano /etc/slurm/slurm.conf

# 2. Find the NodeName lines and update the topology:
#    OLD: ThreadsPerCore=2 (incorrect - VMs use 1 thread per core)
#    NEW: ThreadsPerCore=1 (correct for VMs)
NodeName=compute-01 NodeAddr=192.168.190.131 Sockets=1 CoresPerSocket=8 ThreadsPerCore=1 State=UNKNOWN
NodeName=compute-02 NodeAddr=192.168.190.143 Sockets=1 CoresPerSocket=8 ThreadsPerCore=1 State=UNKNOWN

# 3. Copy updated config to compute nodes
for node in compute-01 compute-02; do
  scp /etc/slurm/slurm.conf $node:/tmp/slurm.conf
  ssh $node "sudo cp /tmp/slurm.conf /etc/slurm/slurm.conf"
done

# 4. Restart controller
sudo systemctl restart slurmctld

# 5. Restart compute nodes
for node in compute-01 compute-02; do
  ssh $node "sudo systemctl restart slurmd"
done

# 6. Verify nodes are now idle
sleep 5
sinfo -Nel
```

**Solution 3: Reset Node State**

After fixing the configuration, you may need to reset the node state:

```bash
# Update node state to IDLE
sudo scontrol update nodename=compute-[01-02] state=idle

# Verify
sinfo -Nel
```

**Important Notes:**

1. **Auto-detection is enabled**: SLURM roles now auto-detect CPU topology from Ansible facts
2. **No manual configuration needed**: Topology is detected at runtime from actual hardware
3. **Override if needed**: You can still override auto-detection by setting variables in inventory
4. **VMs typically use 1 thread per core**: Unlike physical hardware, VMs usually don't expose SMT/hyperthreading
5. **Verify detection**: Check Ansible facts with `ansible <host> -m setup | grep processor`
6. **Test before production**: Verify the configuration works in a test environment first

**To verify auto-detection:**

```bash
# Check what Ansible detects
ansible compute-01 -m setup -a 'filter=ansible_processor*' | grep -E 'processor_count|processor_cores|processor_threads|processor_vcpus'
```

---

### Issue 3: Communication Errors Between Controller and Nodes

**Symptoms:**

```bash
# On compute node
$ sudo journalctl -u slurmd -n 20
slurmd: error: Unable to register: Unable to contact slurm controller (connect failure)
slurmd: error: Unable to contact slurm controller (connect failure)
```

**Diagnosis:**

```bash
# 1. Test network connectivity
ping controller
ping 192.168.100.10  # controller IP

# 2. Check slurmctld is running on controller
ssh controller "sudo systemctl status slurmctld"

# 3. Check firewall rules
ssh controller "sudo iptables -L | grep 6817"  # slurmctld port
ssh controller "sudo iptables -L | grep 6818"  # slurmd port

# 4. Check DNS/hostname resolution
ssh compute-01 "getent hosts controller"
ssh controller "getent hosts compute-01"

# 5. Verify SLURM configuration
ssh compute-01 "grep ControlMachine /etc/slurm/slurm.conf"
ssh controller "grep ControlMachine /etc/slurm/slurm.conf"
```

**Solutions:**

**Solution 1: Restart daemons**

```bash
# Restart controller first
ssh controller "sudo systemctl restart slurmctld"

# Then restart compute nodes
ssh compute-01 "sudo systemctl restart slurmd"
ssh compute-02 "sudo systemctl restart slurmd"

# Verify nodes registered
sinfo -Nel
```

**Solution 2: Fix configuration mismatch**

```bash
# Ensure same slurm.conf on all nodes
ssh controller "md5sum /etc/slurm/slurm.conf"
ssh compute-01 "md5sum /etc/slurm/slurm.conf"
ssh compute-02 "md5sum /etc/slurm/slurm.conf"

# If different, reconfigure nodes
# (see ansible deployment)
```

**Solution 3: Check MUNGE authentication**

```bash
# MUNGE provides authentication between nodes
# Check MUNGE is running
ssh compute-01 "sudo systemctl status munge"
ssh controller "sudo systemctl status munge"

# Test MUNGE authentication
ssh compute-01 "munge -n | ssh controller unmunge"

# Should output: "STATUS: Success (0)"

# If failed, check MUNGE keys match
ssh controller "sudo md5sum /etc/munge/munge.key"
ssh compute-01 "sudo md5sum /etc/munge/munge.key"
ssh compute-02 "sudo md5sum /etc/munge/munge.key"
```

---

### Issue 4: Job Failed with Exit Code

**Symptoms:**

```bash
$ squeue
# Job disappeared from queue

$ sacct -j 42
JobID    State      ExitCode 
42       FAILED     1:0
```

**Diagnosis:**

```bash
# Check job details
sacct -j 42 --format=JobID,JobName,State,ExitCode,Reason,Start,End,Elapsed

# Check job output files
ls -la slurm-42.out

# Read output
cat slurm-42.out

# Check for common issues:
# - Module not loaded
# - Path not found
# - Permission denied
# - Memory exceeded
# - Time limit exceeded
```

**Solutions:**

```bash
# For memory issues
#SBATCH --mem=8G  # Request more memory

# For time issues
#SBATCH --time=02:00:00  # Request more time

# For module issues
module load required-module
```

---

### Issue 5: Job Killed Due to Memory/Time Limits

**Symptoms:**

```bash
$ sacct -j 42 --format=JobID,State,ExitCode,MaxRSS,Elapsed,TimeLimit
JobID    State      ExitCode MaxRSS    Elapsed  TimeLimit
42       OUT_OF_ME+ 0:9      8192K     00:05:00 00:10:00
```

**Diagnosis:**

```bash
# Check actual resource usage
sacct -j 42 --format=JobID,MaxRSS,MaxVMSize,AveRSS,AveCPU

# MaxRSS: Maximum resident set size (memory used)
# MaxVMSize: Maximum virtual memory
# AveRSS: Average RSS
# AveCPU: Average CPU time
```

**Solutions:**

```bash
# Increase memory allocation
#SBATCH --mem=16G  # or --mem-per-cpu=4G

# Increase time limit
#SBATCH --time=01:00:00

# For time limit exceeded, increase time
# For memory exceeded, increase memory or optimize code
```

---

### Issue 6: Node Marked as DOWN or DRAIN

**Symptoms:**

```bash
$ sinfo -Nel
NODELIST    STATE      REASON
compute-01  down       Not responding
compute-02  drain      Memory error
```

**Diagnosis:**

```bash
# Check node details
scontrol show node compute-01

# Check why node went down
# Look at "Reason" field

# Check node logs
ssh compute-01 "sudo journalctl -u slurmd -n 100"

# Common reasons:
# - Not responding: Network or daemon issue
# - Memory error: Hardware or configuration issue
# - Kill task failed: Process cleanup issue
```

**Solutions:**

**For "Not responding" nodes:**

```bash
# 1. Check if node is reachable
ping compute-01

# 2. Check slurmd is running
ssh compute-01 "sudo systemctl status slurmd"

# 3. Restart slurmd if needed
ssh compute-01 "sudo systemctl restart slurmd"

# 4. Resume node
sudo scontrol update nodename=compute-01 state=resume

# 5. Verify node is idle
sinfo -Nel
```

**For "DRAIN" nodes:**

```bash
# Check drain reason
scontrol show node compute-02

# If false alarm, resume node
sudo scontrol update nodename=compute-02 state=resume

# If real hardware issue, investigate:
# - Memory errors: Check dmesg, memtest
# - Disk errors: Check /var/log/syslog
# - GPU errors: Check nvidia-smi, dmesg
```

---

## Essential SLURM Commands Reference

### Job Management

```bash
# Submit job
sbatch job-script.sh

# Submit interactive job
srun --nodes=1 --ntasks=1 --pty bash

# Cancel job
scancel <job_id>

# Cancel all your jobs
scancel -u $USER

# Hold job (prevent from running)
scontrol hold <job_id>

# Release held job
scontrol release <job_id>

# Update job parameters
scontrol update job <job_id> TimeLimit=01:00:00
scontrol update job <job_id> NumNodes=2
```

### Job Status and History

```bash
# Show queue
squeue

# Show only your jobs
squeue -u $USER

# Show specific job
squeue -j <job_id>

# Detailed job info (running/pending jobs)
scontrol show job <job_id>

# Historical job info
sacct -j <job_id>

# Detailed historical info
sacct -j <job_id> --format=JobID,JobName,State,ExitCode,Start,End,Elapsed,AllocCPUS,MaxRSS

# Show jobs from last 7 days
sacct --starttime $(date -d '7 days ago' +%Y-%m-%d)
```

### Node Information

```bash
# Show partition summary
sinfo

# Show detailed node list
sinfo -Nel

# Show specific node
scontrol show node <node_name>

# Show only idle nodes
sinfo -t idle

# Show only down nodes
sinfo -t down,drain,draining

# Show node features/GRES
sinfo -o "%N %f %G"
```

### Partition Information

```bash
# Show partitions
scontrol show partition

# Show specific partition
scontrol show partition compute

# Show partition with formatting
sinfo -o "%P %.5a %.10l %.6D %.6t %N"
```

---

## Advanced Debugging Techniques

### 1. Real-time Job Monitoring

```bash
# Watch queue in real-time
watch -n 2 'squeue'

# Watch specific job
watch -n 2 'squeue -j <job_id> && sacct -j <job_id> --format=JobID,State,Elapsed,MaxRSS'

# Monitor node states
watch -n 2 'sinfo -Nel'

# Tail job output while running
tail -f slurm-<job_id>.out
```

### 2. Debugging MPI Jobs

```bash
# Run with verbose output
srun -v hostname

# Run with debug output
srun --debug=verbose hostname

# Check MPI can see all nodes
srun hostname | sort

# Test MPI communication
mpirun -np 4 --map-by node hostname

# Enable SLURM debug flags
export SLURM_DEBUG=3
srun hostname
```

### 3. Debugging GPU Jobs

```bash
# Verify GPU visibility
srun --gres=gpu:1 nvidia-smi

# Check GPU allocation
squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %b %N"
# %b shows GRES (GPU) allocation

# Detailed GPU info on node
scontrol show node compute-01 | grep Gres

# Test GPU from job
srun --gres=gpu:1 bash -c 'echo $CUDA_VISIBLE_DEVICES'
```

### 4. Network and Communication Testing

```bash
# Test connectivity between nodes
srun --nodes=2 --ntasks-per-node=1 hostname

# Test inter-node communication
srun --nodes=2 --ntasks-per-node=1 ping -c 3 compute-01

# Check SLURM ports are open
# Controller: 6817 (slurmctld)
# Compute: 6818 (slurmd)
ssh controller "sudo netstat -tlnp | grep slurm"

# Test MUNGE between nodes
ssh compute-01 "munge -n | ssh controller unmunge"
```

### 5. Log Analysis

```bash
# Controller logs
ssh controller "sudo journalctl -u slurmctld -f"  # Follow
ssh controller "sudo journalctl -u slurmctld -n 100"  # Last 100 lines
ssh controller "sudo journalctl -u slurmctld --since '10 minutes ago'"

# Compute node logs
ssh compute-01 "sudo journalctl -u slurmd -f"
ssh compute-01 "sudo journalctl -u slurmd --since '1 hour ago'"

# SLURM log files (if file logging enabled)
sudo tail -f /var/log/slurm/slurmctld.log    # Controller
sudo tail -f /var/log/slurm/slurmd.log       # Compute node
sudo tail -f /var/log/slurm/slurmdbd.log     # Database

# Search for errors
ssh controller "sudo journalctl -u slurmctld | grep -i error"
ssh compute-01 "sudo journalctl -u slurmd | grep -i 'error\|failed\|fatal'"
```

### 6. Performance Debugging

```bash
# Check scheduling latency
squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.19S %.19V %.6D"
# %S = Start time
# %V = Submit time

# Check backfill statistics
scontrol show bbstat

# Check fair-share info
sshare -l

# Show job priorities
sprio

# Show detailed resource usage
sacct -j <job_id> --format=ALL
```

---

## Preventive Measures

### Best Practices to Avoid Issues

1. **Always specify resources explicitly:**

```bash
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=01:00:00
```

1. **Use proper output/error files:**

```bash
#SBATCH --output=logs/job-%j.out
#SBATCH --error=logs/job-%j.err
```

1. **Test jobs interactively first:**

```bash
# Request interactive session
srun --nodes=1 --ntasks=1 --pty bash

# Test your commands
./my-program

# Exit when done
exit
```

1. **Start small, scale up:**

```bash
# Test with 1 node first
sbatch --nodes=1 job.sh

# Then scale to multiple nodes
sbatch --nodes=4 job.sh
```

1. **Monitor job progress:**

```bash
# Add progress indicators to your script
echo "Stage 1: Loading data..."
# commands
echo "Stage 2: Processing..."
# commands
echo "Stage 3: Complete"
```

---

## Emergency Procedures

### When Nothing Works

If you encounter persistent issues:

**1. Check cluster health:**

```bash
# On controller
sudo scontrol ping
sudo scontrol show config | grep -i slurm_version

# Verify daemons running
sudo systemctl status slurmctld
ssh compute-01 "sudo systemctl status slurmd"
```

**2. Full service restart (last resort):**

```bash
# Stop all compute nodes first
ssh compute-01 "sudo systemctl stop slurmd"
ssh compute-02 "sudo systemctl stop slurmd"

# Stop controller
ssh controller "sudo systemctl stop slurmctld"

# Start controller first
ssh controller "sudo systemctl start slurmctld"

# Wait a few seconds
sleep 5

# Start compute nodes
ssh compute-01 "sudo systemctl start slurmd"
ssh compute-02 "sudo systemctl start slurmd"

# Check cluster status
sinfo -Nel
squeue
```

**3. Check configuration consistency:**

```bash
# Verify all nodes have same config
for node in controller compute-01 compute-02; do
    echo "=== $node ==="
    ssh $node "md5sum /etc/slurm/slurm.conf"
done

# Should all match
```

**4. Reconfigure cluster:**

```bash
# On controller
sudo scontrol reconfigure

# Verify
scontrol show config | head -20
```

---

## Common Error Messages

| Error Message | Meaning | Solution |
|---------------|---------|----------|
| `Unable to contact slurm controller` | Network/daemon issue | Check slurmctld, restart slurmd |
| `Invalid job id specified` | Job doesn't exist | Check job ID with `squeue` or `sacct` |
| `Job violates accounting/QOS policy` | Resource limits exceeded | Reduce resource request |
| `Socket timed out on send/recv` | Network timeout | Check network, firewall rules |
| `Node not responding` | Node down or hung | Check node, restart slurmd |
| `Unable to allocate resources` | Not enough resources | Wait or reduce resource request |
| `Authentication credential error` | MUNGE issue | Check MUNGE is running and keys match |
| `Job launch failed: timeout` | Node not responding | Check slurmd on node |

---

## Debugging Scripts

### Quick Health Check Script

Save as `slurm-health-check.sh`:

```bash
#!/bin/bash
# Quick SLURM cluster health check

echo "=== SLURM Health Check ==="
echo

echo "1. Controller Status:"
ssh controller "sudo systemctl status slurmctld | grep Active"
echo

echo "2. Compute Node Status:"
for node in compute-01 compute-02; do
    echo "  $node:"
    ssh $node "sudo systemctl status slurmd | grep Active"
done
echo

echo "3. Node States:"
sinfo -Nel
echo

echo "4. Queue:"
squeue
echo

echo "5. Recent Errors (Controller):"
ssh controller "sudo journalctl -u slurmctld --since '5 minutes ago' | grep -i error | tail -5"
echo

echo "=== Health Check Complete ==="
```

### Node Recovery Script

Save as `recover-node.sh`:

```bash
#!/bin/bash
# Recover a stuck or down node

NODE=${1:-compute-01}

echo "=== Recovering node: $NODE ==="

echo "1. Checking connectivity..."
ping -c 2 $NODE || { echo "Cannot reach $NODE"; exit 1; }

echo "2. Restarting slurmd..."
ssh $NODE "sudo systemctl restart slurmd"
sleep 3

echo "3. Resuming node in SLURM..."
sudo scontrol update nodename=$NODE state=resume

echo "4. Checking node state..."
scontrol show node $NODE | grep State

echo "=== Recovery complete ==="
```

---

## Additional Resources

### Official SLURM Documentation

- [SLURM Troubleshooting Guide](https://slurm.schedmd.com/troubleshoot.html)
- [scontrol Manual](https://slurm.schedmd.com/scontrol.html)
- [sacct Manual](https://slurm.schedmd.com/sacct.html)
- [Job Reason Codes](https://slurm.schedmd.com/job_reason_codes.html)

### Related Tutorials

- **Tutorial 08:** SLURM Basics
- **Tutorial 09:** SLURM Intermediate
- **Tutorial 10:** SLURM Advanced

### Getting Help

When asking for help, include:

```bash
# Cluster info
scontrol show config | head -20

# Job details
scontrol show job <job_id>
sacct -j <job_id> --format=ALL

# Node details
scontrol show node <node_name>

# Recent logs
sudo journalctl -u slurmctld -n 50
sudo journalctl -u slurmd -n 50
```

---

## Summary

**Key Debugging Steps:**

1. ✅ Check job status: `squeue -j <job_id>`
2. ✅ Check node states: `sinfo -Nel`
3. ✅ Check detailed info: `scontrol show job/node`
4. ✅ Check logs: `journalctl -u slurmctld/slurmd`
5. ✅ Test connectivity and MUNGE
6. ✅ Restart services if needed
7. ✅ Resume nodes if down/drained

**Remember:**

- Most issues are network or configuration related
- Always check logs for specific errors
- Start simple (ping, systemctl status) before complex solutions
- When in doubt, restart the affected service
- Document what worked for future reference

---

*Created: 2025-10-31*  
*Based on real-world troubleshooting experience*
