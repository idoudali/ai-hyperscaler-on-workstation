# HPC Cluster Tutorials

Step-by-step guides for using and managing your HPC cluster.

## Getting Started

### Tutorial 01: First Cluster

**Status:** ✅ Available  
**Level:** Beginner  
**File:** `01-first-cluster.md`

Deploy your first HPC cluster from scratch.

**Topics:**

- Initial cluster deployment
- Verifying installation
- Basic cluster management
- SSH access and connectivity

**Prerequisites:** None

---

## SLURM Workload Management

### Tutorial 08: SLURM Basics - Your First Distributed Jobs

**Status:** ✅ Available  
**Level:** Beginner  
**File:** `slurm/08-slurm-basics.md`

Learn to submit and manage jobs on your SLURM cluster.

**Topics:**

- SLURM architecture and terminology
- Submitting interactive and batch jobs
- Resource requests and allocation
- Monitoring and managing jobs
- Running parallel MPI programs
- Debugging common failures

**Prerequisites:** Tutorial 01

**Hands-on examples:**

- Hello World MPI job
- Monte Carlo Pi calculation
- Matrix multiplication

---

### Tutorial 09: SLURM Intermediate - Job Arrays and Dependencies

**Status:** 🚧 Coming Soon  
**Level:** Intermediate  
**File:** `slurm/09-slurm-intermediate.md`

Advanced job management and workflow orchestration.

**Planned topics:**

- Job arrays for parameter sweeps
- Job dependencies and chains
- Advanced resource management
- Job profiling and optimization

**Prerequisites:** Tutorial 08

---

### Tutorial 10: SLURM Advanced - GPUs and Container Integration

**Status:** 🚧 Coming Soon  
**Level:** Advanced  
**File:** `slurm/10-slurm-advanced.md`

GPU scheduling and container-based workflows.

**Planned topics:**

- GPU job scheduling with GRES
- MIG (Multi-Instance GPU) support
- Container integration (Enroot/Pyxis)
- Advanced scheduling features
- Performance optimization

**Prerequisites:** Tutorials 08-09

---

### Tutorial 11: SLURM Debugging - Tips, Tricks, and Troubleshooting

**Status:** ✅ Available  
**Level:** All Levels  
**File:** `slurm/11-slurm-debugging.md`

Comprehensive guide for debugging SLURM issues.

**Topics:**

- Job status investigation and queue analysis
- Node state debugging and recovery
- Communication issues between controller and nodes
- Stuck jobs and cleanup problems
- Resource allocation debugging
- Log analysis and error messages
- Emergency procedures and health checks

**Prerequisites:** Tutorial 08

**Use this as a reference guide when encountering SLURM issues.**

---

## Machine Learning and AI

### Tutorial 02: Distributed Training

**Status:** ✅ Available  
**Level:** Intermediate  
**File:** `02-distributed-training.md`

Run distributed machine learning workloads.

**Topics:**

- Setting up distributed training
- Data parallelism across GPUs
- Model parallelism strategies
- Integration with SLURM

**Prerequisites:** Tutorial 01, Tutorial 08 (recommended)

---

### Tutorial 03: GPU Partitioning

**Status:** ✅ Available  
**Level:** Intermediate  
**File:** `03-gpu-partitioning.md`

Use MIG (Multi-Instance GPU) for GPU sharing.

**Topics:**

- MIG configuration
- GPU resource allocation
- Multi-tenant GPU usage
- Performance considerations

**Prerequisites:** Tutorial 01

---

## Containerization

### Tutorial 04: Container Management

**Status:** ✅ Available  
**Level:** Intermediate  
**File:** `04-container-management.md`

Manage containers in your HPC cluster.

**Topics:**

- Container runtime setup (Enroot, Docker)
- Pulling and running containers
- Container lifecycle management
- Integration with SLURM

**Prerequisites:** Tutorial 01

---

### Tutorial 05: Custom Images

**Status:** ✅ Available  
**Level:** Advanced  
**File:** `05-custom-images.md`

Build custom images for your cluster.

**Topics:**

- Packer image building
- Custom OS configurations
- Image versioning
- Deployment workflows

**Prerequisites:** Tutorial 01

---

## Monitoring and Debugging

### Tutorial 06: Monitoring Setup

**Status:** ✅ Available  
**Level:** Intermediate  
**File:** `06-monitoring-setup.md`

Set up cluster monitoring and observability.

**Topics:**

- Metrics collection (Prometheus)
- GPU monitoring (DCGM)
- Log aggregation
- Alerting configuration

**Prerequisites:** Tutorial 01

---

### Tutorial 07: Job Debugging

**Status:** ✅ Available  
**Level:** Intermediate  
**File:** `07-job-debugging.md`

Debug issues with cluster jobs.

**Topics:**

- Common failure modes
- Debugging techniques
- Performance troubleshooting
- Log analysis

**Prerequisites:** Tutorial 01, Tutorial 08 (for SLURM jobs)

---

## Learning Paths

### Path 1: HPC Administrator

1. Tutorial 01: First Cluster
2. Tutorial 05: Custom Images
3. Tutorial 06: Monitoring Setup
4. Tutorial 08: SLURM Basics
5. Tutorial 11: SLURM Debugging (reference guide)
6. Tutorial 09: SLURM Intermediate (when available)

### Path 2: Machine Learning Researcher

1. Tutorial 01: First Cluster
2. Tutorial 08: SLURM Basics
3. Tutorial 02: Distributed Training
4. Tutorial 03: GPU Partitioning
5. Tutorial 04: Container Management
6. Tutorial 11: SLURM Debugging (as needed)

### Path 3: HPC Application Developer

1. Tutorial 01: First Cluster
2. Tutorial 08: SLURM Basics
3. Tutorial 09: SLURM Intermediate (when available)
4. Tutorial 10: SLURM Advanced (when available)
5. Tutorial 07: Job Debugging
6. Tutorial 11: SLURM Debugging (reference guide)

---

## Quick Reference

| Tutorial | Level | Status | Main Focus |
|----------|-------|--------|------------|
| 01 - First Cluster | Beginner | ✅ | Initial deployment |
| 02 - Distributed Training | Intermediate | ✅ | ML workloads |
| 03 - GPU Partitioning | Intermediate | ✅ | MIG configuration |
| 04 - Container Management | Intermediate | ✅ | Containers |
| 05 - Custom Images | Advanced | ✅ | Image building |
| 06 - Monitoring Setup | Intermediate | ✅ | Observability |
| 07 - Job Debugging | Intermediate | ✅ | Troubleshooting |
| 08 - SLURM Basics | Beginner | ✅ | Job submission |
| 09 - SLURM Intermediate | Intermediate | 🚧 | Job arrays |
| 10 - SLURM Advanced | Advanced | 🚧 | GPUs + containers |

---

## Additional Resources

### Quick Start Commands

```bash
# Deploy cluster
make hpc-cluster-start
make hpc-cluster-deploy

# Validate SLURM
cd tests
make validate-slurm

# Run examples
ssh admin@<controller-ip>
cd ~/slurm-jobs/hello-world
bash compile.sh
sbatch hello.sbatch
```

### Documentation

- **Design Docs:** `docs/design-docs/`
- **Workflows:** `docs/workflows/`
- **Troubleshooting:** `docs/TROUBLESHOOTING.md`
- **Testing Guide:** `docs/TESTING-GUIDE.md`

### Example Code

- **SLURM Jobs:** `examples/slurm-jobs/`
- **MPI Programs:** `examples/slurm-jobs/{hello-world,pi-calculation,matrix-multiply}/`

---

## Contributing

Found an issue or have a suggestion? Please:

1. Check existing documentation and tutorials
2. Review troubleshooting guide
3. Open an issue with details

For tutorial improvements, ensure:

- Examples are tested on deployed clusters
- Commands include expected output
- Prerequisites are clearly listed
- Difficulty level is appropriate

---

*Last updated: 2025-01-30*
