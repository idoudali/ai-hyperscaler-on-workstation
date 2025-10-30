# Category 3: Oumi Framework Integration

**Category Overview:** Validate Oumi framework on custom HPC cluster and cloud deployment.

**Tasks:** MLOPS-3.1, MLOPS-3.2  
**Total Duration:** 3 days  
**Target Infrastructure:** Oumi framework, custom SLURM cluster, remote job management

---

## MLOPS-3.1: Oumi Custom Cluster Configuration

**Duration:** 2 days  
**Priority:** CRITICAL  
**Dependencies:** HPC cluster operational  
**Validation Target:** Oumi integration with custom SLURM cluster

### Objective

Configure Oumi to launch training jobs on custom AI-HOW HPC cluster.

### Implementation

**Oumi Cluster Configuration:** `configs/mlops/ai_how_cluster.yaml`

Key configuration sections:

- **Cluster**: SLURM connection details (host, SSH key)
- **Resources**: Partitions, GPUs per node, GPU types
- **Storage**: BeeGFS paths for models, datasets, shared filesystem
- **Containers**: Apptainer runtime, image directory
- **Environment**: HuggingFace cache locations

Cluster settings:

- Name: `ai-how-hpc`
- Type: `slurm`
- Connection: SSH to 192.168.100.10
- GPUs: 2 per node (NVIDIA type)
- Shared storage: `/mnt/beegfs`

See lines 606-640 in original file for full cluster configuration.

**Test Job Configuration:** `configs/mlops/oumi_cluster_test.yaml`

Minimal test job:

- Model: GPT-2 (smallest model for quick test)
- Dataset: WikiText (100 samples)
- Training: 10 steps maximum
- Resources: 1 GPU, 2 CPUs, 8GB memory, 10-minute limit

Purpose: Verify Oumi can connect, submit, monitor, and retrieve results.

See lines 642-669 in original file for test job configuration.

### Validation Steps

```bash
# 1. Install Oumi on local machine (workstation)
pip install oumi[gpu]

# 2. Configure cluster connection
oumi cluster add ai-how-hpc --config configs/mlops/ai_how_cluster.yaml

# 3. Test cluster connection
oumi cluster test ai-how-hpc

# 4. Launch test job
oumi launch -c configs/mlops/oumi_cluster_test.yaml

# 5. Monitor job status
oumi status
watch -n 5 'oumi status'

# 6. Check results on cluster
ssh admin@192.168.100.10 "ls -lh /mnt/beegfs/models/oumi-cluster-test/"

# 7. Verify Oumi can download results
oumi results <job-id> --download ./oumi-test-results/
```

### Success Criteria

- [ ] Oumi connects to HPC cluster via SSH
- [ ] Job submission works through Oumi CLI
- [ ] SLURM job created and runs successfully
- [ ] Oumi monitors job status remotely
- [ ] Model artifacts saved to BeeGFS
- [ ] Oumi downloads results successfully

### Configuration Notes

**SSH Setup:**

- Ensure SSH key is configured: `~/.ssh/ai_how_cluster_key`
- Test manual SSH connection first: `ssh -i ~/.ssh/ai_how_cluster_key admin@192.168.100.10`
- Add to `~/.ssh/config` for convenience

**Container Runtime:**

- Oumi must know to use Apptainer (not Docker)
- Specify container image path on BeeGFS
- Ensure Oumi container has necessary dependencies

**Storage Paths:**

- All paths must be absolute on HPC cluster
- Model cache: `/mnt/beegfs/models`
- Dataset cache: `/mnt/beegfs/datasets`
- HuggingFace cache: `/mnt/beegfs/huggingface`

---

## MLOPS-3.2: Oumi Evaluation and Benchmarking

**Duration:** 1 day  
**Priority:** MEDIUM  
**Dependencies:** MLOPS-1.2 or MLOPS-2.2  
**Validation Target:** Oumi evaluation framework, model quality metrics

### Objective

Evaluate fine-tuned models using Oumi's evaluation framework.

### Implementation

**Evaluation Configuration:** `configs/mlops/smollm_eval.yaml`

Evaluation tasks:

1. **Perplexity**: WikiText test set (1000 samples)
2. **Text Generation**: 3 sample prompts with quality assessment
3. **Metrics**: Perplexity, BLEU, ROUGE scores

Configuration:

- Model path: `/mnt/beegfs/models/smollm-135m-sft` (from MLOPS-1.2)
- Output: `/mnt/beegfs/evaluations/smollm-135m`
- Resources: 1 GPU, 15-minute limit

Evaluation prompts:

- "Write a short story about"
- "Explain quantum computing in simple terms"
- "Create a haiku about nature"

See lines 717-743 in original file for evaluation configuration.

**SLURM Job Script:** `scripts/mlops/smollm_eval.sbatch`

Simple evaluation job:

- 1 GPU allocation
- 15-minute time limit
- Runs `oumi evaluate` in Apptainer container

See lines 745-757 in original file for SLURM script.

### Validation Steps

```bash
# 1. Ensure trained model exists
ls -lh /mnt/beegfs/models/smollm-135m-sft/

# 2. Deploy evaluation config
sudo cp configs/mlops/smollm_eval.yaml /mnt/beegfs/configs/

# 3. Submit evaluation job
sbatch scripts/mlops/smollm_eval.sbatch

# 4. Monitor evaluation
tail -f /mnt/beegfs/jobs/smollm-eval-*.out

# 5. Check results
ls -lh /mnt/beegfs/evaluations/smollm-135m/
cat /mnt/beegfs/evaluations/smollm-135m/results.json

# 6. Review generated text samples
cat /mnt/beegfs/evaluations/smollm-135m/generations.txt
```

### Success Criteria

- [ ] Evaluation completes successfully
- [ ] Perplexity calculated and saved
- [ ] Text generation produces coherent output
- [ ] Metrics saved to evaluation directory
- [ ] Results comparable to baseline (if available)

### Evaluation Metrics

**Perplexity:**

- Measures how well model predicts text
- Lower is better (typical range: 10-50 for fine-tuned small models)
- Baseline SmolLM-135M: ~15-20 on WikiText

**BLEU Score:**

- Translation/generation quality (0-1)
- Compares generated text to reference
- >0.3 indicates reasonable quality

**ROUGE Score:**

- Summarization quality metric
- Measures overlap with reference
- ROUGE-L >0.4 indicates good overlap

### Optional: Comparison to Base Model

Compare fine-tuned model to base SmolLM-135M:

```bash
# Evaluate base model
oumi evaluate \
  --model HuggingFaceTB/SmolLM-135M \
  --output /mnt/beegfs/evaluations/smollm-135m-base \
  -c configs/mlops/smollm_eval.yaml

# Compare metrics
diff /mnt/beegfs/evaluations/smollm-135m/results.json \
     /mnt/beegfs/evaluations/smollm-135m-base/results.json
```

---

## Category Summary

This category validates Oumi framework integration with custom infrastructure:

**MLOPS-3.1** establishes:

- Oumi can connect to custom SLURM cluster
- Remote job submission via Oumi CLI
- Job monitoring from local workstation
- Result retrieval after training completes

**MLOPS-3.2** extends to:

- Model evaluation capabilities
- Quality metrics calculation (perplexity, BLEU, ROUGE)
- Text generation assessment
- Baseline comparisons

**Benefits of Oumi Integration:**

- Unified interface for training and evaluation
- Remote cluster management from workstation
- Experiment tracking and result organization
- Reproducible training configurations

**Next Steps:** Proceed to [Category 4: Inference Deployment](./category-4-inference.md) to validate model serving on cloud cluster.

---

**Related Documentation:**

- [Prerequisites](./reference/prerequisites.md) - Oumi installation and setup
- [Troubleshooting Guide](./reference/troubleshooting.md) - Oumi connection issues
- **Oumi Documentation**: https://oumi.ai/docs/
- **Oumi GitHub**: https://github.com/oumi-ai/oumi
