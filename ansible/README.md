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
│   ├── hpc-cluster-setup/        # HPC cluster configuration
│   │   └── tasks/                # Role tasks
│   └── cloud-cluster-setup/      # Cloud cluster configuration
│       └── tasks/                # Role tasks
├── playbooks/
│   ├── playbook-hpc.yml          # HPC cluster deployment
│   └── playbook-cloud.yml        # Cloud cluster deployment
└── inventories/
    └── generate_inventory.py     # Dynamic inventory generator
```

## Current Status

This is a **minimal skeleton** structure. The following components are placeholders and will be implemented as needed:

- **Role tasks**: Currently contain only debug messages
- **Playbooks**: Basic structure without functional tasks
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

## Next Steps

1. Implement actual package installation tasks in base package roles
2. Implement cluster configuration tasks in cluster setup roles
3. Complete the inventory generator to read from cluster.yaml
4. Integrate with the CLI orchestrator for automated deployment

## Minimal Design Philosophy

This structure follows a minimal design philosophy:

- **Only essential directories** are created
- **Role structure simplified** to just tasks initially
- **Additional directories** (defaults, vars, handlers, templates) added as needed
- **Easy to extend** without unnecessary complexity
