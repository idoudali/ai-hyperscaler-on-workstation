# Hyperscaler on Workstation

An automated approach to emulating advanced AI infrastructure on a single
workstation using KVM, GPU partitioning, and dual-stack orchestration.

## What This Project Is

This project is an educational playground where I try to cover (and educate
myself about) the software stack being used today for training in a distributed HPC
system, and for running inference in a Cloud.

It is a "poor-man's" solution to this problem where if you find yourself with a
machine with enough cores and more than 1 GPU then you can try to "emulate" an
HPC or a cloud cluster using multiple VMs and assigning our GPUs at will to the
different VMs.

This project is also a vibe-coding experiment (for better or worse)
where I am experimenting with the quality of the different coding assistance
tools and agents.

## What This Project Is Not

This project is not meant for production :). Use it at your own risk :). Yet, it can
be a really nice playground to learn from others' mistakes.

## High Level Overview

This project transforms a single workstation with multiple GPUs into a complete dual-stack AI infrastructure using
KVM virtualization, automated provisioning, and GPU passthrough.

![System Architecture](architecture/architecture-diagram.drawio.png)

### What It Creates

The system deploys **two isolated virtual clusters** on your workstation:

#### 1. HPC Cluster (Training) - Network: 192.168.100.0/24

A traditional high-performance computing environment for distributed ML training:

- **SLURM Controller** - Job scheduling, user management, cluster orchestration
- **Compute Nodes** (2x) - GPU-accelerated training with PCIe passthrough (RTX 3090 Ti, RTX 4070)
- **BeeGFS Parallel Filesystem** - High-performance distributed storage for datasets and checkpoints
- **Container Runtime** - Docker and Apptainer for reproducible training environments

#### 2. Cloud Cluster (Inference) - Network: 192.168.200.0/24

A Kubernetes-based cloud platform for MLOps and model serving:

- **Kubernetes Control Plane** - API server, scheduler, etcd for orchestration
- **CPU Worker Node** - Hosts MLOps services (MinIO, MLflow, Kubeflow Pipelines)
- **GPU Worker Node** - Inference server with RTX 4060 for model serving (KServe, vLLM)
- **MLOps Platform** - Model registry, experiment tracking, and deployment pipelines

### Automation & Orchestration

The entire infrastructure is deployed and managed through:

- **Packer** - Builds reproducible VM images for all node types
- **Ansible** - Configures SLURM, Kubernetes, BeeGFS, and all services
- **Terraform** - Provisions infrastructure as code (optional)
- **CMake** - Orchestrates the entire build pipeline
- **Oumi** - Unified ML orchestrator that bridges HPC training and K8s inference

### Key Features

- **GPU Passthrough** - Physical GPUs assigned directly to VMs for native performance
- **Network Isolation** - Separate virtual networks for HPC and Cloud with controlled connectivity
- **Full Automation** - End-to-end deployment from bare metal to running clusters
- **Production-like Stack** - Real SLURM, Kubernetes, BeeGFS, not toy simulations
- **Flexible GPU Assignment** - Move GPUs between clusters as needed for different workloads

---

## Getting Started

**New to the project?** Follow these guides in order:

### Prerequisites and Installation

1. **[Prerequisites](getting-started/prerequisites.md)** - System requirements and verification scripts
2. **[Installation Guide](getting-started/installation.md)** - Complete installation instructions

**Quick Summary:** 8+ cores, 32+ GB RAM, 500+ GB disk, Ubuntu 22.04+ or Debian 13+

### Quickstart Guides

Once installation is complete, follow these quickstart guides to deploy your cluster:

1. **[5-Minute Quickstart](getting-started/quickstart-5min.md)** - Verify setup and build first Packer image
2. **[Cluster Deployment](getting-started/quickstart-cluster.md)** - Deploy complete HPC cluster with SLURM
3. **[GPU Configuration](getting-started/quickstart-gpu.md)** - Configure GPU passthrough and run GPU workloads
4. **[Container Workflows](getting-started/quickstart-containers.md)** - Build and deploy containerized applications
5. **[Monitoring Setup](getting-started/quickstart-monitoring.md)** - Deploy Prometheus and Grafana dashboards

**Total Time:** ~1 hour from installation to fully monitored cluster

---

## Contributing to the Project

**For developers contributing to this project**, comprehensive development documentation is available in the
[`development/`](development/) folder.

### Quick Start for Contributors

```bash
# Setup development environment
make venv-create && source .venv/bin/activate
pre-commit install

# Before committing
make pre-commit-run    # Run code quality checks
make test-ai-how       # Run Python tests

# Commit changes
cz commit              # Interactive commit (recommended)
```

### Development Documentation

- **[Development Workflow Guide](development/development-workflow.md)** - Complete workflow, commit conventions,
  and best practices
- **[Code Quality & Linters](development/code-quality-linters.md)** - Pre-commit hooks, linting tools, and
  configuration
- **[CI/CD Pipeline](development/ci-cd-pipeline.md)** - GitHub Actions workflow and pipeline architecture
- **[Python Dependencies Setup](development/python-dependencies-setup.md)** - Installing and troubleshooting
  Python dependencies
- **[GitHub Actions Guide](development/github-actions-guide.md)** - Detailed CI/CD workflow documentation
- **[Cursor Agent Setup](development/cursor-agent-setup.md)** - AI-assisted development configuration

### Essential Commands

**Python Development:**

```bash
make venv-create       # Create virtual environment
make test-ai-how       # Run tests
make lint-ai-how       # Run linting
make format-ai-how     # Format code
```

**Docker Development:**

```bash
make build-docker      # Build development container
make shell-docker      # Interactive shell
make run-docker COMMAND="..."  # Run command in container
```

**Code Quality:**

```bash
make pre-commit-run    # Run hooks on staged files
cz commit              # Interactive commit message builder
```

**Testing:**

```bash
cd tests/ && make test         # Core infrastructure tests
cd tests/ && make test-all     # Comprehensive test suite
```

### Additional Resources

For complete development documentation including commit conventions, testing guidelines, and contributor best practices:

**📖 See the [Development Workflow Guide](development/development-workflow.md)**

This guide covers:

- Commit message format and conventions
- Test suite organization and writing tests
- Code quality standards and best practices
- Python package development
- Docker development environment
- CI/CD pipeline details

---

## Project Structure

Understanding the project layout helps navigate the codebase effectively. Each major directory has its own README with
detailed information.

### Core Directories

- **[`ansible/`](ansible/README.md)** - Ansible playbooks and roles for
  infrastructure automation

  - [`roles/`](ansible/roles/README.md) - Custom roles for SLURM, GPU, containers, monitoring
  - [`playbooks/`](ansible/playbooks/README.md) - Infrastructure deployment playbooks
  - [`inventories/`](ansible/inventories/README.md) - Inventory configurations

- **[`packer/`](packer/README.md)** - VM image building with Packer

  - [`hpc-base/`](packer/hpc-base/README.md) - Base HPC image templates
  - [`hpc-controller/`](packer/hpc-controller/README.md) - SLURM controller image
  - [`hpc-compute/`](packer/hpc-compute/README.md) - SLURM compute node image

- **[`docker/`](docker/README.md)** - Development environment container

  - Multi-stage Dockerfile for consistent builds
  - Container entrypoint and dependency management

- **[`scripts/`](scripts/README.md)** - Utility and automation scripts

  - [`system-checks/`](scripts/system-checks/README.md) - System validation and GPU inventory

- **[`tests/`](tests/README.md)** - Comprehensive testing framework

  - Foundation, frameworks, and advanced test suites
  - Test infrastructure and shared utilities

- **[`python/ai_how/`](python/ai_how/README.md)** - Python CLI package

  - HPC cluster management commands
  - PCIe passthrough configuration
  - Configuration validation

- **`docs/`** - Project documentation

  - [`getting-started/`](getting-started/prerequisites.md) - Prerequisites, installation, quickstarts
  - [`architecture/`](architecture/overview.md) - System design and architecture docs
  - [`tutorials/`](tutorials/01-first-cluster.md) - In-depth learning guides
  - [`components/`](components/README.md) - Component-specific documentation

- **[`config/`](config/README.md)** - Cluster configuration files

  - Example configurations for various deployment scenarios

- **[`containers/`](containers/README.md)** - Container image definitions

  - ML framework images (PyTorch, TensorFlow, etc.)

### Key Files

- **`Makefile`** - Main development workflow automation
- **`.pre-commit-config.yaml`** - Code quality and linting rules
- **`pyproject.toml`** - Python package configuration with commitizen settings
