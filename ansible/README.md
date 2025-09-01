# Ansible Infrastructure for Hyperscaler Project

This directory contains the Ansible automation framework for the hyperscaler project.

## Structure

```text
ansible/
├── ansible.cfg                    # Ansible configuration
├── requirements.txt               # Python dependencies for Ansible
├── collections/
│   └── requirements.yml          # Required Ansible collections
├── roles/
│   ├── hpc-base-packages/        # HPC base package installation
│   │   └── tasks/                # Role tasks
│   ├── cloud-base-packages/      # Cloud base package installation
│   │   └── tasks/                # Role tasks
│   ├── nvidia-gpu-drivers/       # NVIDIA GPU driver installation
│   │   ├── tasks/                # Role tasks
│   │   ├── handlers/             # Role handlers
│   │   ├── defaults/             # Default variables
│   │   └── README.md             # Role documentation
│   ├── hpc-cluster-setup/        # HPC cluster configuration
│   │   └── tasks/                # Role tasks
│   └── cloud-cluster-setup/      # Cloud cluster configuration
│       └── tasks/                # Role tasks
├── playbooks/
│   ├── playbook-hpc.yml          # HPC cluster deployment
│   ├── playbook-cloud.yml        # Cloud cluster deployment
│   ├── playbook-hpc-packer.yml   # HPC Packer image build
│   └── playbook-cloud-packer.yml # Cloud Packer image build
└── inventories/
    └── generate_inventory.py     # Dynamic inventory generator
```

## Current Status

The Ansible infrastructure includes both implemented and placeholder components:

### Implemented Components

- **nvidia-gpu-drivers role**: Fully functional NVIDIA GPU driver installation following [Debian wiki guidelines](https://wiki.debian.org/NvidiaGraphicsDrivers)
- **hpc-base-packages role**: Basic HPC package installation (tmux, htop, vim, etc.)
- **HPC playbook**: Includes NVIDIA drivers with CUDA support for GPU-accelerated computing

### Placeholder Components

- **cloud-base-packages role**: Currently contains only debug messages  
- **cluster setup roles**: Basic structure without functional tasks
- **Inventory generator**: Basic Python script structure

## Installation

To install Ansible and dependencies in the project virtual environment:

```bash
# Use the integrated installation (recommended)
make venv-install

# Or manually:
# Activate the virtual environment
source .venv/bin/activate

# Install Ansible requirements
pip install -r ansible/requirements.txt

# Install Ansible collections
ansible-galaxy collection install -r ansible/collections/requirements.yml
```

## Usage

The Ansible infrastructure supports both package pre-installation and post-deployment configuration:

### Pre-installation (with Packer)

1. **Base packages** using `hpc-base-packages` and `cloud-base-packages` roles
2. **NVIDIA GPU drivers** using `nvidia-gpu-drivers` role for GPU-enabled images

### Post-deployment Configuration

1. **Cluster setup** using cluster setup roles (to be implemented)
2. **GPU workload configuration** for CUDA and OpenGL applications

### NVIDIA GPU Driver Support

The `nvidia-gpu-drivers` role provides:

- **Automatic GPU detection** and driver selection
- **Support for multiple Debian versions** (Trixie, Bookworm, Bullseye)
- **CUDA toolkit installation** for HPC and ML workloads
- **Tesla driver support** for datacenter GPUs

#### Example: Running GPU-enabled HPC playbook

```bash
# Run HPC deployment with NVIDIA drivers and CUDA
ansible-playbook -i inventories/ playbooks/playbook-hpc.yml

# Run cloud deployment with NVIDIA drivers
ansible-playbook -i inventories/ playbooks/playbook-cloud.yml
```

#### GPU Driver Configuration Variables

```yaml
# Enable CUDA toolkit installation (default for HPC)
nvidia_install_cuda: true

# Enable Packer build mode (suppresses reboot warnings during image creation)
nvidia_packer_build: true  # Set to false for runtime deployments
```

**Important**:

- **For runtime deployments**: A system reboot is required for drivers to become active
- **For Packer builds**: Drivers are pre-installed and will be available after image deployment

## Next Steps

1. ✅ **NVIDIA GPU drivers**: Completed - Full implementation with Debian wiki compliance
2. Implement cloud-base-packages role tasks for Kubernetes workloads
3. Implement cluster configuration tasks in cluster setup roles
4. Complete the inventory generator to read from cluster.yaml
5. Integrate with the CLI orchestrator for automated deployment
6. Add GPU resource configuration for SLURM and Kubernetes

## Minimal Design Philosophy

This structure follows a minimal design philosophy:

- **Only essential directories** are created
- **Role structure simplified** to just tasks initially
- **Additional directories** (defaults, vars, handlers, templates) added as needed
- **Easy to extend** without unnecessary complexity
