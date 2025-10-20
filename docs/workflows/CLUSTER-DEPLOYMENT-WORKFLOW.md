# Container Registry & Cluster Deployment Workflow

**Document Version:** 1.0
**Last Updated:** 2025-10-07
**Status:** Production Ready

## Overview

This document describes the complete workflow for deploying and managing container images on the HPC cluster using the
container registry infrastructure.

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Phase 1: Registry Infrastructure Setup](#phase-1-registry-infrastructure-setup)
- [Phase 2: Container Image Deployment](#phase-2-container-image-deployment)
- [Phase 3: Verification and Testing](#phase-3-verification-and-testing)
- [Operational Workflows](#operational-workflows)
- [Troubleshooting](#troubleshooting)

## Architecture

### Container Registry Structure

```text
/opt/containers/                       # Main registry directory
├── ml-frameworks/                     # Production ML frameworks
│   ├── pytorch-cuda12.1-mpi4.1.sif
│   └── tensorflow-cuda12.1.sif
├── custom-images/                     # User custom containers
├── base-images/                       # Base/template images
└── .registry/                         # Registry metadata
    ├── config.yaml
    └── catalog.yaml
```

### Deployment Architecture

```text
┌─────────────────┐
│  Local Machine  │
│                 │
│  Build Docker   │
│  Convert to SIF │
└────────┬────────┘
         │
         │ Deploy via CLI/Script
         ▼
┌─────────────────────────────────────────────────────────┐
│  HPC Controller                                         │
│  ┌───────────────────────┐                             │
│  │ /opt/containers/      │                             │
│  │  ml-frameworks/       │                             │
│  └──────────┬────────────┘                             │
│             │                                           │
│             │ Sync via rsync/SSH                       │
│             ▼                                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │  registry-sync-to-nodes.sh                       │  │
│  └──────────┬───────────────────────────────────────┘  │
└─────────────┼──────────────────────────────────────────┘
              │
              │ SSH + rsync
              ▼
┌─────────────────────────────────────────────────────────┐
│  Compute Nodes                                          │
│  ┌───────────────────────┐  ┌───────────────────────┐  │
│  │ Node 1                │  │ Node 2                │  │
│  │ /opt/containers/      │  │ /opt/containers/      │  │
│  │  ml-frameworks/       │  │  ml-frameworks/       │  │
│  └───────────────────────┘  └───────────────────────┘  │
│                                                         │
│  SLURM jobs can access containers via:                 │
│  - srun --container=/opt/containers/ml-frameworks/...  │
│  - apptainer exec /opt/containers/ml-frameworks/...    │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

### Infrastructure

- HPC cluster deployed with controller and compute nodes
- SLURM installed and configured on all nodes
- Apptainer/Singularity installed on all nodes
- SSH access between controller and compute nodes
- Ansible configured for cluster management

### Build Environment

- Docker or compatible container runtime (for building images)
- Apptainer/Singularity (for converting images)
- Python 3.8+ with virtual environment
- CMake and build tools

### Software Components

```bash
# Install HPC container manager CLI
cd /path/to/ai-hyperscaler-on-workskation
make config
make run-docker COMMAND='cmake --build build --target hpc-container-manager'
```

## Phase 1: Registry Infrastructure Setup

### Step 1.1: Verify Packer Builds Skip Registry Setup

**CRITICAL:** The container-registry role MUST NOT execute during Packer builds.

```bash
# When building base images, verify packer_build=true is set
# This ensures registry setup is skipped

# Check Packer ansible provisioner configuration
grep -r "packer_build" packer/
```

**Expected Result:** `packer_build: true` in Packer provisioner extra_arguments.

### Step 1.2: Deploy Registry Infrastructure via Ansible

Deploy the container registry on live cluster (NOT during Packer builds):

```bash
# From project root
ansible-playbook ansible/playbooks/playbook-container-registry.yml

# Dry run first (recommended)
ansible-playbook ansible/playbooks/playbook-container-registry.yml --check
```

**Expected Output:**

```text
PLAY [Deploy Container Registry Infrastructure on HPC Cluster] ****************

TASK [Verify not running in Packer build mode] ********************************
ok: [hpc-controller] => {
    "changed": false,
    "msg": "Running in live VM deployment mode (packer_build=false) ✓"
}

PLAY RECAP *********************************************************************
hpc-controller             : ok=15   changed=8    unreachable=0    failed=0
```

### Step 1.3: Verify Registry Infrastructure

```bash
# Run Test Suite 1: Ansible Infrastructure Tests
export TEST_CONTROLLER=hpc-controller
tests/test-container-registry-framework.sh --phase infrastructure

# Or run directly
tests/suites/container-registry/run-ansible-infrastructure-tests.sh
```

**Success Criteria:**

- ✅ Registry directory structure created on all nodes
- ✅ Correct permissions (755) and ownership (root:slurm)
- ✅ Registry configuration deployed
- ✅ Cross-node access configured
- ✅ Sync scripts available on controller

## Phase 2: Container Image Deployment

### Step 2.1: Build Docker Image (Local)

```bash
# Build Docker image for specific ML framework
cd containers
docker build -t pytorch-cuda12.1-mpi4.1:latest images/pytorch/
```

### Step 2.2: Convert Docker to Apptainer (Local)

```bash
# Using the CLI tool
hpc-container-manager convert to-apptainer \
  pytorch-cuda12.1-mpi4.1:latest \
  build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif

# Or using the conversion script
containers/scripts/convert-single.sh \
  pytorch-cuda12.1-mpi4.1:latest \
  build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif
```

**Expected Output:**

```text
Converting Docker image to Apptainer format...
INFO:    Starting build...
✓ Successfully converted to build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif
```

### Step 2.3: Deploy Single Image to Cluster

```bash
# Deploy using wrapper script (recommended for beginners)
containers/scripts/deploy-single.sh \
  -s \
  -v \
  build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif

# Or deploy using CLI directly
hpc-container-manager deploy to-cluster \
  build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif \
  /opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif \
  --controller hpc-controller \
  --sync-nodes \
  --verify
```

**Options:**

- `-s, --sync-nodes`: Automatically sync image to all compute nodes
- `-v, --verify`: Verify deployment on all nodes
- `-r, --registry-path`: Custom registry path (default: /opt/containers/ml-frameworks)

### Step 2.4: Deploy Multiple Images

```bash
# Deploy all built images
containers/scripts/deploy-all.sh --sync-nodes --verify

# Dry run first
containers/scripts/deploy-all.sh --dry-run
```

### Step 2.5: Verify Image Deployment

```bash
# Run Test Suite 2: Image Deployment Tests
export TEST_CONTROLLER=hpc-controller
export TEST_IMAGE=pytorch-cuda12.1-mpi4.1.sif
tests/test-container-registry-framework.sh --phase deployment
```

**Success Criteria:**

- ✅ Image deployed to controller
- ✅ Image synced to all compute nodes
- ✅ Image integrity verified
- ✅ Registry catalog updated
- ✅ SLURM can execute container

## Phase 3: Verification and Testing

### Step 3.1: Run End-to-End Tests

```bash
# Run all E2E integration tests
export TEST_CONTROLLER=hpc-controller
tests/test-container-registry-framework.sh --phase e2e
```

### Step 3.2: Manual Verification

```bash
# SSH to controller
ssh hpc-controller

# Check image exists
ls -lh /opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif

# Inspect image
apptainer inspect /opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif

# Test execution directly
apptainer exec /opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif \
  python3 -c 'import torch; print(f"PyTorch: {torch.__version__}")'

# Test with SLURM
srun --container=/opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif \
  python3 -c 'import torch; print(f"PyTorch: {torch.__version__}")'
```

### Step 3.3: Run Full Test Suite

```bash
# Run all three test suites
export TEST_CONTROLLER=hpc-controller
tests/test-container-registry-framework.sh --all
```

**Expected Output:**

```text
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║  ✓✓✓ ALL CONTAINER REGISTRY TESTS PASSED ✓✓✓             ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

## Operational Workflows

### Workflow 1: Deploy New Container

```bash
# 1. Build Docker image (if not already built)
docker build -t my-custom-image:latest images/my-custom/

# 2. Convert to Apptainer
hpc-container-manager convert to-apptainer \
  my-custom-image:latest \
  build/containers/apptainer/my-custom-image.sif

# 3. Deploy to cluster
containers/scripts/deploy-single.sh \
  -s -v \
  build/containers/apptainer/my-custom-image.sif

# 4. Verify on cluster
ssh hpc-controller "apptainer exec /opt/containers/ml-frameworks/my-custom-image.sif python3 --version"
```

### Workflow 2: Update Existing Container

```bash
# 1. Rebuild Docker image with updates
docker build -t pytorch-cuda12.1-mpi4.1:latest images/pytorch/

# 2. Convert to Apptainer (overwrites existing)
hpc-container-manager convert to-apptainer \
  pytorch-cuda12.1-mpi4.1:latest \
  build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif \
  --force

# 3. Redeploy to cluster (overwrites existing)
containers/scripts/deploy-single.sh \
  -s -v \
  build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif

# 4. Verify update
ssh hpc-controller "apptainer exec /opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif python3 -c 'import torch; print(torch.__version__)'"
```

### Workflow 3: Manual Cross-Node Sync

```bash
# SSH to controller
ssh hpc-controller

# Sync all images to all nodes
/usr/local/bin/registry-sync-to-nodes.sh

# Sync specific subdirectory
/usr/local/bin/registry-sync-to-nodes.sh ml-frameworks

# Check sync log
tail -f /var/log/container-registry-sync.log
```

### Workflow 4: Run Distributed Training Job

```bash
# Create SLURM job script
cat > distributed_training.sh <<'EOF'
#!/bin/bash
#SBATCH --job-name=pytorch-distributed
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --gres=gpu:4
#SBATCH --container=/opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif

# Your training script
python3 train.py --distributed
EOF

# Submit job
sbatch distributed_training.sh

# Monitor job
squeue
```

## Troubleshooting

### Issue: Registry not deployed during Ansible run

**Symptoms:**

- Registry directory not created
- Ansible playbook succeeds but no changes made

**Cause:** `packer_build=true` is set (role is skipped)

**Solution:**

```bash
# Explicitly set packer_build=false
ansible-playbook ansible/playbooks/playbook-container-registry.yml \
  -e "packer_build=false"
```

### Issue: Image sync fails to compute nodes

**Symptoms:**

- Image exists on controller but not on compute nodes
- SSH connection errors in sync logs

**Diagnosis:**

```bash
# Check SSH connectivity from controller to nodes
ssh hpc-controller "
  for node in \$(sinfo -N -h -o '%N'); do
    echo \"Testing \$node...\"
    ssh -o ConnectTimeout=5 \$node hostname || echo \"FAILED: \$node\"
  done
"
```

**Solution:**

```bash
# Verify SSH keys are configured
ssh hpc-controller "ls -la /root/.ssh/id_rsa_registry_sync*"

# Manually sync to test
ssh hpc-controller "/usr/local/bin/registry-sync-to-nodes.sh"
```

### Issue: SLURM cannot execute container

**Symptoms:**

- `srun --container=...` fails
- Error: "Container not found" or permission denied

**Diagnosis:**

```bash
# Check image exists and is readable
ssh hpc-controller "ls -l /opt/containers/ml-frameworks/*.sif"

# Check SLURM configuration
ssh hpc-controller "scontrol show config | grep -i container"

# Test direct execution
ssh hpc-controller "apptainer exec /opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif python3 --version"
```

**Solution:**

```bash
# Ensure proper permissions
ssh hpc-controller "chmod 755 /opt/containers/ml-frameworks/*.sif"

# Verify SLURM has container support
ssh hpc-controller "srun apptainer version"
```

### Issue: Image integrity check fails

**Symptoms:**

- `apptainer inspect` fails
- Corrupted or incomplete image

**Solution:**

```bash
# Remove corrupted image
ssh hpc-controller "rm /opt/containers/ml-frameworks/corrupted-image.sif"

# Redeploy from local build
containers/scripts/deploy-single.sh -s -v build/containers/apptainer/image.sif

# Verify checksum matches (optional)
sha256sum build/containers/apptainer/image.sif
ssh hpc-controller "sha256sum /opt/containers/ml-frameworks/image.sif"
```

## Best Practices

### Security

1. **SSH Key Management:** Use dedicated SSH keys for registry sync with restricted permissions
2. **Image Scanning:** Scan Docker images for vulnerabilities before deploying
3. **Access Control:** Maintain proper ownership (root:slurm) and permissions (755)

### Performance

1. **Parallel Deployment:** For multiple images, consider parallel deployment (experimental)
2. **Network Optimization:** Use dedicated network for image sync if available
3. **Caching:** Leverage Apptainer's cache for faster repeated builds

### Maintenance

1. **Regular Testing:** Run test suites after infrastructure changes
2. **Catalog Updates:** Keep registry catalog.yaml updated (automated by deployment tools)
3. **Log Monitoring:** Check `/var/log/container-registry-sync.log` for sync issues
4. **Version Control:** Track image versions in deployment scripts or CI/CD

## References

- [Apptainer Documentation](https://apptainer.org/docs/)
- [SLURM Container Support](https://slurm.schedmd.com/containers.html)
- [Project Architecture Documentation](../README.md)
