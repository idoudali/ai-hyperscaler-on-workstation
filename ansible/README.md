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
│   ├── hpc-base-packages/        # Essential HPC packages + NVIDIA drivers
│   │   ├── tasks/                # Role tasks
│   │   └── handlers/             # Service restart handlers
│   ├── cloud-base-packages/      # Cloud base package installation
│   │   └── tasks/                # Role tasks
│   ├── hpc-cluster-setup/        # HPC cluster configuration
│   │   └── tasks/                # Role tasks
│   └── cloud-cluster-setup/      # Cloud cluster configuration
│       └── tasks/                # Role tasks
├── playbooks/
│   ├── playbook-hpc-packer.yml   # HPC base image for Packer
│   ├── playbook-hpc.yml          # HPC cluster deployment
│   └── playbook-cloud.yml        # Cloud cluster deployment
└── inventories/
    ├── localhost                  # Static inventory for localhost
    └── generate_inventory.py     # Dynamic inventory generator
```

## Current Status

This is a **minimal skeleton** structure. The following components are placeholders and will be implemented as needed:

- **Role tasks**: Currently contain only debug messages (except hpc-base-packages which is fully implemented)
- **Playbooks**: Basic structure without functional tasks (except playbook-hpc-packer.yml)
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

**Note:** The Packer template currently uses shell provisioners to install and run Ansible, as the native `ansible` provisioner
plugin is not available in the current environment. This approach provides the same functionality while maintaining compatibility.

## Usage

The Ansible infrastructure will be used by the CLI orchestrator to:

1. **Pre-install packages** using Packer with the base package roles
2. **Configure clusters** after deployment using the cluster setup roles

## Implemented Components

### **HPC Base Packages Role** (`roles/hpc-base-packages/`)

- **Essential system packages**: Configurable package list via variables
- **NVIDIA GPU drivers**: Configurable driver version (default: 535) and CUDA toolkit (default: 12-4)
- **NVIDIA container runtime**: Support for GPU-accelerated containers
- **Debian 13 compatibility**: Optimized for Debian 13 (trixie) cloud images
- **Idempotent modules**: Uses proper Ansible modules instead of shell commands
- **Configurable variables**: All versions and URLs configurable via defaults
- **Debug tags**: Debug output can be controlled with `--skip-tags debug`

### **Packer Integration** (`playbooks/playbook-hpc-packer.yml`)

- **Packer-specific playbook** for building HPC base images
- **Shell provisioner integration** with Packer (Ansible provisioner plugin not available)
- **Verification tasks** for NVIDIA drivers, CUDA, and essential packages
- **Local connection** configuration for Packer environment
- **Debug tag support** for controlling output verbosity

### **Hybrid Provisioning Approach**

The HPC base image uses a **hybrid provisioning approach**:

1. **Shell Script (`setup-hpc-base.sh`)**: Handles basic system setup, networking, and debugging tools
2. **Shell Provisioner**: Installs Ansible in virtual environment and executes playbooks
3. **Ansible Role**: Installs essential packages and NVIDIA drivers with proper configuration
4. **Combined Benefits**:
   - Shell script for system-level operations and networking
   - Shell provisioner for Ansible installation and execution
   - Ansible for package management and configuration
   - Best of both worlds: speed, reliability, and maintainability

## Configuration

### **Role Variables** (`roles/hpc-base-packages/defaults/main.yml`)

The HPC base packages role is fully configurable through variables:

```yaml
# NVIDIA Driver and CUDA Configuration
nvidia_driver_version: "535"
cuda_version: "12-4"

# Repository Configuration
nvidia_repository_url: "https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/"
nvidia_gpg_key_url: "https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub"

# Package Lists
essential_packages: [git, wget, curl, vim, htop, ...]
nvidia_driver_packages: [nvidia-driver-535, nvidia-utils-535, ...]
nvidia_container_packages: [nvidia-container-toolkit, nvidia-container-runtime]
```

### **Debug Output Control**

Debug output can be controlled using Ansible tags:

```bash
# Run with debug output (default)
ansible-playbook playbooks/playbook-hpc-packer.yml

# Run without debug output
ansible-playbook playbooks/playbook-hpc-packer.yml --skip-tags debug
```

## Next Steps

1. **Implement cloud base packages role** for cloud-native workloads
2. **Implement cluster setup roles** for post-deployment configuration
3. **Complete the inventory generator** to read from cluster.yaml
4. **Integrate with the CLI orchestrator** for automated deployment

## Minimal Design Philosophy

This structure follows a minimal design philosophy:

- **Only essential directories** are created
- **Role structure simplified** to just tasks initially
- **Additional directories** (defaults, vars, handlers, templates) added as needed
- **Easy to extend** without unnecessary complexity
- **Focus on core functionality** - essential packages and NVIDIA support first
- **Hybrid approach** - use the right tool for the right job

## Testing

To test the HPC role:

```bash
cd ansible
./test-hpc-role.sh
```

This will run syntax checks and dry-run tests to verify the role is properly configured.
