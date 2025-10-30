# Category 2: Distributed Training Validation

**Category Overview:** Validate multi-GPU training with SLURM GRES scheduling and GPU communication.

**Tasks:** MLOPS-2.1, MLOPS-2.2  
**Total Duration:** 4 days  
**Target Infrastructure:** HPC Cluster (SLURM multi-GPU, NCCL, PyTorch DDP)

---

## MLOPS-2.1: Multi-GPU Data Parallel Training

**Duration:** 2 days  
**Priority:** HIGH  
**Dependencies:** MLOPS-1.1  
**Validation Target:** Multi-GPU training, SLURM GRES allocation, GPU communication

### Objective

Train CIFAR-10 classifier using 2 GPUs with PyTorch DistributedDataParallel to validate multi-GPU infrastructure.

### Implementation

**Training Script:** `scripts/mlops/cifar10_multi_gpu.py`

Key components:

- PyTorch DistributedDataParallel (DDP) with NCCL backend
- ResNet-18 model for CIFAR-10 classification
- DistributedSampler for data distribution
- 3 epochs, batch size 128 per GPU

Distributed setup:

- NCCL backend for GPU-to-GPU communication
- Environment variables: `LOCAL_RANK`, `WORLD_SIZE`
- Main process handles model saving and metrics

See lines 352-460 in original file for full implementation.

**SLURM Job Script:** `scripts/mlops/cifar10_multi_gpu.sbatch`

SLURM configuration:

- `--gres=gpu:2` for 2 GPUs on single node
- `--ntasks-per-node=2` for 2 processes
- 4 CPUs per task, 32GB total memory
- 20-minute time limit

Distributed training setup:

- `torchrun` with `--nproc_per_node=2`
- Master address/port configuration
- Environment variables for distributed coordination

See lines 462-502 in original file for SLURM script.

### Validation Steps

```bash
# 1. Deploy scripts to BeeGFS
sudo cp scripts/mlops/cifar10_multi_gpu.py /mnt/beegfs/scripts/

# 2. Submit multi-GPU job
sbatch scripts/mlops/cifar10_multi_gpu.sbatch

# 3. Monitor GPU allocation
squeue -u admin -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R %b"

# 4. Watch training progress
tail -f /mnt/beegfs/jobs/cifar10-multi-gpu-*.out

# 5. Verify both GPUs are utilized
ssh compute01 "watch -n 1 nvidia-smi"

# 6. Check results
ls -lh /mnt/beegfs/models/cifar10/
cat /mnt/beegfs/models/cifar10/metrics.json
```

### Success Criteria

- [ ] Both GPUs allocated via SLURM GRES
- [ ] DDP initializes successfully
- [ ] Training completes in <15 minutes
- [ ] GPU utilization >70% on both GPUs
- [ ] Model achieves >60% accuracy
- [ ] No inter-GPU communication errors
- [ ] Speedup ~1.7-1.9x vs single GPU (MLOPS-1.1)

### Expected Performance

**Single GPU baseline (MLOPS-1.1):**

- MNIST training: ~2-3 minutes

**Multi-GPU (this task):**

- CIFAR-10 training: ~10-12 minutes
- Expected speedup: 1.7-1.9x (not perfect 2x due to communication overhead)
- GPU utilization: 70-85% per GPU

---

## MLOPS-2.2: Multi-GPU LLM Training (Oumi)

**Duration:** 2 days  
**Priority:** HIGH  
**Dependencies:** MLOPS-1.2  
**Validation Target:** Oumi multi-GPU training, FSDP/DeepSpeed

### Objective

Fine-tune SmolLM-135M using 2 GPUs with Oumi's multi-GPU support.

### Implementation

**Oumi Configuration:** `configs/mlops/smollm_multi_gpu.yaml`

Key settings:

- Model: HuggingFaceTB/SmolLM-135M
- Dataset: HuggingFaceH4/no_robots (5000 samples for multi-GPU)
- Training: 2 epochs, batch size 8 per device, gradient accumulation 2
- Multi-GPU: DDP strategy with gradient checkpointing
- Output: `/mnt/beegfs/models/smollm-multi-gpu`

Configuration highlights:

- `compute.devices: 2` for 2 GPUs
- `compute.strategy: "ddp"` for DistributedDataParallel
- `gradient_checkpointing: true` to reduce memory
- `ddp_find_unused_parameters: false` for efficiency

See lines 528-554 in original file for full configuration.

**SLURM Job Script:** `scripts/mlops/smollm_multi_gpu.sbatch`

Configuration:

- `--gres=gpu:2` for 2 GPUs
- `--ntasks-per-node=2` for 2 processes
- 40-minute time limit, 32GB memory

Oumi handles:

- Distributed process initialization
- Data distribution across GPUs
- Gradient synchronization
- Checkpoint management

See lines 556-579 in original file for SLURM script.

### Validation Steps

```bash
# 1. Deploy multi-GPU config
sudo cp configs/mlops/smollm_multi_gpu.yaml /mnt/beegfs/configs/

# 2. Submit job
sbatch scripts/mlops/smollm_multi_gpu.sbatch

# 3. Monitor training
tail -f /mnt/beegfs/jobs/smollm-multi-gpu-*.out

# 4. Check GPU utilization
ssh compute01 "nvidia-smi dmon -s u -c 60"

# 5. Verify checkpoints
ls -lh /mnt/beegfs/models/smollm-multi-gpu/

# 6. Compare to single-GPU training time
# Single GPU (MLOPS-1.2): ~15-20 minutes
# Multi GPU (this task): expected ~10-12 minutes
```

### Success Criteria

- [ ] Oumi successfully uses 2 GPUs
- [ ] Training faster than single GPU (MLOPS-1.2)
- [ ] Both GPUs show high utilization (>60%)
- [ ] Model quality preserved (vs single GPU baseline)
- [ ] No OOM errors with gradient checkpointing
- [ ] Final loss comparable to single-GPU training

### Multi-GPU Strategy Notes

**DDP (DistributedDataParallel):**

- Best for models that fit in single GPU memory
- Replicates model on each GPU
- Synchronizes gradients across GPUs
- Good for SmolLM-135M size

**FSDP (Fully Sharded Data Parallel):**

- Alternative for larger models
- Shards model parameters across GPUs
- Useful for models >1B parameters
- Not needed for SmolLM-135M but available in Oumi

**Gradient Checkpointing:**

- Trades compute for memory
- Recomputes activations during backward pass
- Reduces memory by ~30-40%
- Minimal performance impact (<10% slower)

---

## Category Summary

This category validates multi-GPU training infrastructure:

**MLOPS-2.1** establishes:

- SLURM can allocate multiple GPUs (`--gres=gpu:2`)
- PyTorch DDP functions correctly with NCCL backend
- Inter-GPU communication works (no hangs or errors)
- Training speedup achieved (~1.7-1.9x)

**MLOPS-2.2** extends to:

- Oumi framework multi-GPU support
- LLM distributed training workflows
- Gradient checkpointing for memory efficiency
- Production-ready distributed training patterns

**Performance Expectations:**

- Multi-GPU speedup: 1.7-1.9x (not 2x due to communication overhead)
- GPU utilization: 70-85% per GPU
- Memory usage: 60-80% per GPU with gradient checkpointing

**Next Steps:** Proceed to [Category 3: Oumi Integration](./category-3-oumi-integration.md) to validate Oumi cluster configuration.

---

**Related Documentation:**

- [Prerequisites](./reference/prerequisites.md) - Multi-GPU requirements
- [Troubleshooting Guide](./reference/troubleshooting.md) - DDP and NCCL issues
