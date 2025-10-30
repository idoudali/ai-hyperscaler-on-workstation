# MLOps Validation Task List

**Status:** Planning - Not Started  
**Created:** 2025-10-27  
**Priority:** HIGH - System validation and workflow testing  
**Total Tasks:** 10 tasks across 5 categories  
**Estimated Duration:** 3-4 weeks (18 days)

## Overview

This task list defines MLOps validation tasks to test and validate the complete AI-HOW infrastructure:

- **HPC Cluster**: Training workloads (SLURM, BeeGFS, GPU scheduling)
- **Cloud Cluster**: Inference workloads (Kubernetes, KServe, MLflow)
- **Oumi Framework**: End-to-end ML workflow integration
- **MLOps Stack**: Model tracking, registry, and serving

These tasks use **small, fast-running models** (SmolLM-135M, GPT-2, simple CNNs) to validate infrastructure
without requiring hours of training time.

## Task Categories

### Category 1: Basic Training Validation (HPC Cluster)

Validate GPU training capabilities using simple models that complete in minutes.

- **MLOPS-1.1**: Single GPU MNIST Training (1 day, CRITICAL)
- **MLOPS-1.2**: Single GPU Language Model Fine-tuning with Oumi (2 days, HIGH)

[Details: category-1-basic-training.md](./category-1-basic-training.md)

### Category 2: Distributed Training Validation (HPC Cluster)

Validate multi-GPU training with SLURM GRES scheduling and GPU communication.

- **MLOPS-2.1**: Multi-GPU Data Parallel Training (2 days, HIGH)
- **MLOPS-2.2**: Multi-GPU LLM Training with Oumi (2 days, HIGH)

[Details: category-2-distributed-training.md](./category-2-distributed-training.md)

### Category 3: Oumi Framework Integration (HPC Cluster)

Validate Oumi framework on custom HPC cluster and cloud deployment.

- **MLOPS-3.1**: Oumi Custom Cluster Configuration (2 days, CRITICAL)
- **MLOPS-3.2**: Oumi Evaluation and Benchmarking (1 day, MEDIUM)

[Details: category-3-oumi-integration.md](./category-3-oumi-integration.md)

### Category 4: Inference Deployment (Cloud Cluster)

Validate model serving, inference APIs, and autoscaling on Kubernetes.

- **MLOPS-4.1**: Simple Model Inference on CPU (1 day, HIGH)
- **MLOPS-4.2**: GPU Model Inference (2 days, HIGH)

[Details: category-4-inference.md](./category-4-inference.md)

### Category 5: End-to-End MLOps Workflow (Both Clusters)

Validate complete workflow: train on HPC → register in MLflow → deploy on cloud → serve inference.

- **MLOPS-5.1**: Complete Training-to-Inference Pipeline (3 days, CRITICAL)
- **MLOPS-5.2**: MLOps Pipeline Automation (2 days, MEDIUM)

[Details: category-5-e2e-workflow.md](./category-5-e2e-workflow.md)

## Task Summary Table

| Task ID | Task Name | Duration | Priority | Cluster | Category |
|---------|-----------|----------|----------|---------|----------|
| MLOPS-1.1 | Single GPU MNIST Training | 1 day | CRITICAL | HPC | Basic Training |
| MLOPS-1.2 | Single GPU LLM Fine-tuning | 2 days | HIGH | HPC | Basic Training |
| MLOPS-2.1 | Multi-GPU Data Parallel Training | 2 days | HIGH | HPC | Distributed Training |
| MLOPS-2.2 | Multi-GPU LLM Training | 2 days | HIGH | HPC | Distributed Training |
| MLOPS-3.1 | Oumi Custom Cluster Config | 2 days | CRITICAL | HPC | Oumi Integration |
| MLOPS-3.2 | Oumi Evaluation | 1 day | MEDIUM | HPC | Oumi Integration |
| MLOPS-4.1 | CPU Model Inference | 1 day | HIGH | Cloud | Inference |
| MLOPS-4.2 | GPU Model Inference | 2 days | HIGH | Cloud | Inference |
| MLOPS-5.1 | End-to-End Pipeline | 3 days | CRITICAL | Both | E2E Workflow |
| MLOPS-5.2 | Pipeline Automation | 2 days | MEDIUM | Both | E2E Workflow |

**Total Duration:** 18 days (3.6 weeks)

## Reference Documentation

- [Prerequisites](./reference/prerequisites.md) - Software, data, and network requirements
- [Troubleshooting Guide](./reference/troubleshooting.md) - Common issues and solutions
- [Validation Matrix](./reference/validation-matrix.md) - Infrastructure coverage and success metrics

## Related Documentation

- **HPC Task List**: `../hpc-slurm/README.md`
- **Cloud Cluster Plan**: `../cloud-cluster/README.md`
- **Design Document**: `../../../docs/design-docs/cloud-cluster-oumi-inference.md`
- **Main Project Plan**: `../../../docs/design-docs/project-plan.md`

## Quick Start

1. Review [Prerequisites](./reference/prerequisites.md) to ensure all dependencies are met
2. Start with Category 1 (Basic Training) to validate HPC infrastructure
3. Progress through categories sequentially as dependencies allow
4. Refer to [Troubleshooting Guide](./reference/troubleshooting.md) for common issues

---

**Document Version:** 2.0  
**Last Updated:** 2025-10-30  
**Format:** Restructured for LLM-friendly atomic task files
