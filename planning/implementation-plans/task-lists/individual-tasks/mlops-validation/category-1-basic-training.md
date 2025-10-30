# Category 1: Basic Training Validation

**Category Overview:** Validate GPU training capabilities using simple models that complete in minutes.

**Tasks:** MLOPS-1.1, MLOPS-1.2  
**Total Duration:** 3 days  
**Target Infrastructure:** HPC Cluster (SLURM, BeeGFS, Apptainer, GPUs)

---

## MLOPS-1.1: Single GPU MNIST Training

**Duration:** 1 day  
**Priority:** CRITICAL  
**Dependencies:** HPC cluster operational  
**Validation Target:** Single GPU training, BeeGFS storage, SLURM job submission

### Objective

Train a simple CNN on MNIST dataset using a single GPU to validate basic training infrastructure.

### Implementation

**Training Script:** `scripts/mlops/mnist_single_gpu.py`

Key components:

- SimpleCNN model (Conv2D → Conv2D → FC layers)
- MNIST dataset loading from BeeGFS
- 5 epochs, batch size 128
- Model and metrics saved to BeeGFS

**SLURM Job Script:** `scripts/mlops/mnist_single_gpu.sbatch`

SLURM configuration:

- 1 node, 1 task, 4 CPUs
- `--gres=gpu:1` for single GPU allocation
- 10-minute time limit, 8GB memory
- Output to BeeGFS: `/mnt/beegfs/jobs/`

See lines 64-171 in `scripts/mlops/mnist_single_gpu.py` for full training implementation.
See lines 175-205 in `scripts/mlops/mnist_single_gpu.sbatch` for SLURM configuration.

### Validation Steps

```bash
# 1. Deploy training script to BeeGFS
ssh admin@192.168.100.10  # HPC controller
sudo mkdir -p /mnt/beegfs/scripts
sudo cp scripts/mlops/mnist_single_gpu.py /mnt/beegfs/scripts/

# 2. Submit SLURM job
sbatch scripts/mlops/mnist_single_gpu.sbatch

# 3. Monitor job
squeue -u admin
watch -n 5 'squeue -u admin'

# 4. Check job output
tail -f /mnt/beegfs/jobs/mnist-single-gpu-*.out

# 5. Validate results
ls -lh /mnt/beegfs/models/mnist/job-*/
cat /mnt/beegfs/models/mnist/job-*/metrics.json
```

### Success Criteria

- [ ] Job submits successfully to SLURM
- [ ] GPU is allocated via GRES
- [ ] Training completes in <3 minutes
- [ ] Model achieves >95% accuracy
- [ ] Model file saved to BeeGFS
- [ ] Metrics JSON contains expected fields
- [ ] No CUDA errors or warnings

---

## MLOPS-1.2: Single GPU Language Model Fine-tuning (Oumi)

**Duration:** 2 days  
**Priority:** HIGH  
**Dependencies:** MLOPS-1.1, Oumi installed  
**Validation Target:** Oumi framework, small LLM fine-tuning, HuggingFace integration

### Objective

Fine-tune SmolLM-135M model using Oumi framework to validate LLM training pipeline.

### Implementation

**Oumi Configuration:** `configs/mlops/smollm_sft_single_gpu.yaml`

Key settings:

- Model: HuggingFaceTB/SmolLM-135M
- Dataset: HuggingFaceH4/no_robots (1000 samples)
- Training: 1 epoch, batch size 4, gradient accumulation 4
- Output: `/mnt/beegfs/models/smollm-135m-sft`
- Resources: 1 GPU, 4 CPUs, 16GB memory, 30-minute time limit

See lines 255-288 in original file for full configuration.

**SLURM Job Script:** `scripts/mlops/smollm_sft_single_gpu.sbatch`

Configuration:

- 1 GPU via `--gres=gpu:1`
- HuggingFace cache on BeeGFS
- Oumi training via Apptainer container

Key environment variables:

- `HF_HOME=/mnt/beegfs/huggingface`
- `TRANSFORMERS_CACHE=/mnt/beegfs/huggingface/transformers`
- `HF_DATASETS_CACHE=/mnt/beegfs/huggingface/datasets`

See lines 290-322 in original file for SLURM script.

### Validation Steps

```bash
# 1. Ensure Oumi container is available
ls -lh /mnt/beegfs/containers/oumi_latest.sif

# 2. Deploy config to BeeGFS
sudo cp configs/mlops/smollm_sft_single_gpu.yaml /mnt/beegfs/configs/

# 3. Submit training job
sbatch scripts/mlops/smollm_sft_single_gpu.sbatch

# 4. Monitor training
tail -f /mnt/beegfs/jobs/smollm-sft-*.out

# 5. Verify checkpoints
ls -lh /mnt/beegfs/models/smollm-135m-sft/

# 6. Check training logs
cat /mnt/beegfs/models/smollm-135m-sft/trainer_state.json
```

### Success Criteria

- [ ] Oumi trains SmolLM-135M successfully
- [ ] Training completes in <20 minutes
- [ ] Model checkpoints saved to BeeGFS
- [ ] Training logs show decreasing loss
- [ ] No OOM errors
- [ ] Model can be loaded for inference

### Notes

**HuggingFace Integration:**

- Datasets and models are cached on BeeGFS for faster subsequent runs
- First run may take longer due to downloads (~500 MB for SmolLM-135M + ~500 MB for dataset)
- Ensure internet access from compute nodes for initial downloads

**Oumi Container:**

- Must be pre-built or downloaded to `/mnt/beegfs/containers/`
- Container includes PyTorch, Transformers, and Oumi framework
- Alternative: Install Oumi via pip in PyTorch container

---

## Category Summary

This category validates the foundational single-GPU training infrastructure:

**MLOPS-1.1** establishes:

- SLURM job submission works
- GPU allocation via GRES functions
- BeeGFS storage accessible from compute nodes
- Apptainer container execution
- Basic PyTorch training pipeline

**MLOPS-1.2** extends to:

- Oumi framework integration
- HuggingFace model/dataset handling
- LLM fine-tuning workflows
- Longer-running GPU workloads

**Next Steps:** Proceed to [Category 2: Distributed Training](./category-2-distributed-training.md) to validate multi-GPU capabilities.

---

**Related Documentation:**

- [Prerequisites](./reference/prerequisites.md) - Software and data requirements
- [Troubleshooting Guide](./reference/troubleshooting.md) - Common SLURM and GPU issues
