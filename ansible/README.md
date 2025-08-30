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

## Usage

The Ansible infrastructure will be used by the CLI orchestrator to:

1. **Pre-install packages** using Packer with the base package roles
2. **Configure clusters** after deployment using the cluster setup roles

## Implemented Components

### **HPC Base Packages Role** (`roles/hpc-base-packages/`)

- **Essential system packages**: git, wget, curl, vim, htop, build-essential
- **NVIDIA GPU drivers**: Latest drivers (535 series) and CUDA toolkit 12.3
- **NVIDIA container runtime**: Support for GPU-accelerated containers

### **Packer Integration** (`playbooks/playbook-hpc-packer.yml`)

- **Packer-specific playbook** for building HPC base images
- **Verification tasks** for NVIDIA drivers, CUDA, and essential packages
- **Local connection** configuration for Packer environment

### **Hybrid Provisioning Approach**

The HPC base image uses a **hybrid provisioning approach**:

1. **Shell Script (`setup-hpc-base.sh`)**: Handles basic system setup, networking, and debugging tools
2. **Ansible Role**: Installs essential packages and NVIDIA drivers with proper configuration
3. **Combined Benefits**:
   - Shell script for system-level operations and networking
   - Ansible for package management and configuration
   - Best of both worlds: speed and reliability

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
