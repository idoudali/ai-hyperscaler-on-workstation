# Ansible Infrastructure for Hyperscaler Project

This directory contains the Ansible automation framework for the hyperscaler project, providing
role-based configuration management for HPC clusters and cloud infrastructure.

## 📋 Quick Navigation

- **[playbooks/README.md](./playbooks/README.md)** - Playbook usage and examples
- **[roles/README.md](./roles/README.md)** - Complete roles index and status
- **[README-packer-ansible.md](./README-packer-ansible.md)** - Packer image build automation

## 🚀 Quick Start

### Validation and Testing

The `ansible/Makefile` provides standardized targets for validating Ansible code:

```bash
cd ansible

# Show all available targets
make help

# Run all validation checks
make validate-all

# Quick check on changed files only
make quick-check

# Validate specific role
make validate-role ROLE=slurm-controller

# Validate specific playbook
make validate-playbook PLAYBOOK=playbook-hpc-runtime.yml

# Test playbook in dry-run mode
make test-playbook-check PLAYBOOK=playbook-hpc-runtime.yml

# List available roles and playbooks
make list-roles
make list-playbooks
```

**Key Targets:**

- `validate-all` - All validation checks (syntax, lint, requirements)
- `quick-check` - Validate Git-changed files only (fast iteration)
- `lint-role ROLE=<name>` - Lint specific role
- `test-playbook-check PLAYBOOK=<name>` - Dry-run test with check mode
- `ci-validate` - Full validation for CI/CD pipelines

**Required Tools:**

- `ansible-playbook` - Ansible CLI (installed via requirements.txt)
- `ansible-lint` - Linting tool (installed via requirements.txt)

## 📁 Directory Structure

```text
ansible/
├── Makefile                           # Validation, testing, linting targets
├── ansible.cfg                        # Ansible configuration and settings
├── requirements.txt                   # Python dependencies for Ansible
├── collections/
│   └── requirements.yml              # Required Ansible collections
├── roles/                             # Ansible roles (see roles/README.md)
│   ├── beegfs-*                      # BeeGFS distributed storage roles
│   ├── slurm-*                       # SLURM cluster scheduler roles
│   ├── nvidia-gpu-drivers/           # NVIDIA GPU driver installation
│   ├── container-*                   # Container runtime and registry roles
│   ├── monitoring-stack/             # Monitoring infrastructure
│   ├── ml-container-images/          # ML container management
│   ├── hpc-base-packages/            # HPC-specific packages
│   ├── cloud-base-packages/          # Cloud base packages
│   ├── virtio-fs-mount/              # Virtio-FS shared storage
│   ├── README.md                     # Roles index and overview
│   └── [role-name]/README.md         # Role-specific documentation
├── playbooks/                         # Ansible playbooks (see playbooks/README.md)
│   ├── playbook-hpc*.yml             # HPC deployment playbooks
│   ├── playbook-cloud.yml            # Cloud infrastructure deployment
│   ├── playbook-container*.yml       # Container deployment playbooks
│   ├── playbook-beegfs*.yml          # BeeGFS runtime configuration
│   ├── playbook-*-runtime*.yml       # Runtime configuration playbooks
│   ├── README.md                     # Playbooks index and usage guide
│   └── (See README.md for complete listing)
├── inventories/
│   ├── generate_inventory.py         # Inventory generator with GPU detection
│   ├── test_inventory_generation.py  # Validation tests
│   ├── hpc/                          # HPC cluster inventory
│   └── cloud/                        # Cloud cluster inventory
├── .ansible-lint                     # Ansible linting rules
├── .gitignore                        # Git ignore rules
├── README-packer-ansible.md          # Packer-specific Ansible usage
├── run-ansible-hpc-cloud.sh          # HPC/Cloud deployment script
└── run-packer-ansible.sh             # Packer build automation script
```

## 📦 Installation

To install Ansible and dependencies in the project virtual environment:

```bash
# Use the integrated installation (recommended)
make venv-install

# Or manually:
source .venv/bin/activate
pip install -r ansible/requirements.txt
ansible-galaxy collection install -r ansible/collections/requirements.yml
```

## ⚙️ Prerequisites

### Third-Party Package Dependencies

Before deploying HPC infrastructure, build required packages from source:

- **SLURM**: Workload manager packages (required for Debian Trixie)
- **BeeGFS**: Parallel filesystem packages (optional, if using BeeGFS storage)

For complete build instructions, see:

- [3rd-Party Dependencies Overview](../3rd-party/README.md)
- [SLURM Build Documentation](../3rd-party/slurm/README.md)
- [BeeGFS Build Documentation](../3rd-party/beegfs/README.md)

**Quick Start:**

```bash
make config
make run-docker COMMAND="cmake --build build --target build-slurm-packages"
make run-docker COMMAND="cmake --build build --target build-beegfs-packages"  # optional
```

## 🎯 Usage

### Pre-installation with Packer

Package pre-installation using Packer builds:

1. **Base packages** - HPC or cloud base images
2. **NVIDIA GPU drivers** - GPU-enabled images

For Packer usage, see [README-packer-ansible.md](./README-packer-ansible.md).

### Post-deployment Configuration

After cluster instantiation, run playbooks to configure deployed systems:

```bash
# Deploy complete HPC cluster runtime configuration
ansible-playbook -i inventories/hpc/hosts.yml playbooks/playbook-hpc-runtime.yml

# Deploy cloud infrastructure
ansible-playbook -i inventories/cloud/hosts.yml playbooks/playbook-cloud.yml
```

## 🔍 Documentation

### Component Documentation

- **[roles/README.md](./roles/README.md)** - All roles, status, and usage
- **[playbooks/README.md](./playbooks/README.md)** - All playbooks and examples
- **[README-packer-ansible.md](./README-packer-ansible.md)** - Packer image building

### Individual Component Docs

Each role includes comprehensive documentation:

- Purpose and capabilities
- Configuration variables
- Usage examples
- Dependencies
- Tags for selective execution
- Troubleshooting guides

### Inventory System

The inventory generator creates comprehensive Ansible inventory from cluster configuration
with advanced GPU detection capabilities.

**Features:**

- Automatic GPU detection
- GRES configuration generation
- Multi-cluster support
- Vendor recognition
- YAML validation

**Usage:**

```bash
cd ansible/inventories
python3 generate_inventory.py /path/to/cluster.yaml
```

See [inventories/README.md](./inventories/README.md) for complete inventory documentation.

## 🔄 Current Implementation Status

### ✅ Implemented Components

- **nvidia-gpu-drivers** role - Full NVIDIA driver installation
- **base-packages** role - HPC package installation
- **HPC playbooks** - NVIDIA drivers with CUDA support
- **Enhanced inventory** - Complete GPU detection and GRES configuration

### 📋 Placeholder/In-Development Components

- **cloud-base-packages** role - Debug messages only
- **cluster setup** roles - Basic structure without functional tasks

## 🎮 Integration

Ansible roles integrate with:

- **Packer** - VM image building
- **Terraform** - Infrastructure provisioning
- **Kubernetes** - Cloud orchestration
- **Docker/Apptainer** - Container runtimes
- **BeeGFS** - Distributed storage
- **SLURM** - HPC job scheduling
- **Prometheus/Grafana** - Infrastructure monitoring

## 🛠️ Common Workflows

### Pattern 1: Complete Cluster Deployment

```bash
ansible-playbook -i inventories/hpc/hosts.yml playbooks/playbook-hpc-runtime.yml
```

Executes full configuration for all HPC nodes.

### Pattern 2: Component-Specific Deployment

```bash
ansible-playbook -i inventories/hpc/hosts.yml playbooks/playbook-container-registry.yml
ansible-playbook -i inventories/hpc/hosts.yml playbooks/playbook-beegfs-runtime-config.yml
```

### Pattern 3: Node-Specific Configuration

```bash
ansible-playbook -i inventories/hpc/hosts.yml playbooks/playbook-hpc-runtime.yml \
  --limit hpc_controllers
```

### Pattern 4: Packer Image Building

```bash
packer build -f packer/hpc-controller/image.pkr.hcl
packer build -f packer/hpc-compute/image.pkr.hcl
```

## 🔗 Best Practices

1. **Always check role documentation** - Each role's README has important details
2. **Test in development** - Validate playbooks before production
3. **Use inventory groups** - Organize hosts by function
4. **Monitor execution** - Use verbose output for tracking
5. **Understand variables** - Review configurable defaults
6. **Validate Ansible code** - Run `make validate-all` before committing
7. **Use Makefile targets** - Provides consistent validation

## 📚 Next Steps

1. ✅ **NVIDIA GPU drivers** - Completed implementation
2. ✅ **Enhanced inventory** - GPU detection and GRES configuration
3. **Cloud playbooks** - Use Kubespray for Kubernetes deployment
4. **Cluster configuration** - Implement cluster setup tasks
5. **CLI orchestrator** - Automated deployment integration
6. **GPU resource configuration** - SLURM and Kubernetes

## 📖 See Also

- **[playbooks/README.md](./playbooks/README.md)** - Playbook documentation
- **[roles/README.md](./roles/README.md)** - Roles documentation
- **[README-packer-ansible.md](./README-packer-ansible.md)** - Packer usage
- **[../3rd-party/README.md](../3rd-party/README.md)** - Package building
- **[../README.md](../README.md)** - Project overview and documentation
