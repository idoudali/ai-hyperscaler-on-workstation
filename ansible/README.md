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
    ├── generate_inventory.py         # Enhanced inventory generator with GPU detection
    └── test_inventory_generation.py  # Validation tests for inventory generation
```

## Current Status

The Ansible infrastructure includes both implemented and placeholder components:

### Implemented Components

- **nvidia-gpu-drivers role**: Fully functional NVIDIA GPU driver installation following [Debian wiki guidelines](https://wiki.debian.org/NvidiaGraphicsDrivers)
- **hpc-base-packages role**: Basic HPC package installation (tmux, htop, vim, etc.)
- **HPC playbook**: Includes NVIDIA drivers with CUDA support for GPU-accelerated computing
- **Enhanced inventory generator**: Complete GPU detection and GRES configuration generation from cluster.yaml

### Placeholder Components

- **cloud-base-packages role**: Currently contains only debug messages  
- **cluster setup roles**: Basic structure without functional tasks

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

### Enhanced Inventory Generator

The inventory generator creates comprehensive Ansible inventory from cluster configuration with advanced GPU detection capabilities.

#### Features

- **Automatic GPU Detection**: Identifies GPU devices from PCIe passthrough configuration
- **GRES Configuration**: Generates SLURM Generic Resource (GRES) configuration for GPU scheduling
- **Multi-Cluster Support**: Supports both HPC (SLURM) and Cloud (Kubernetes) clusters
- **Vendor Recognition**: Automatically maps GPU vendors (NVIDIA, AMD, Intel)
- **Validation**: Built-in inventory validation and YAML syntax checking

#### Usage

```bash
# Generate inventory from default cluster configuration
cd ansible/inventories
python3 generate_inventory.py

# Generate inventory from specific cluster configuration
python3 generate_inventory.py /path/to/cluster.yaml

# Run validation tests
python3 test_inventory_generation.py
```

#### Example Output

The generator detects GPU nodes and creates appropriate inventory groups:

```yaml
# HPC Cluster with GPU Detection
hpc_cluster:
  children:
    hpc_controllers:
      hosts:
        hpc-controller: ...
    hpc_gpu_nodes:
      hosts:
        hpc-compute-01:
          gpu_devices:
            - device_id: "2805"
              vendor: nvidia
              pci_address: "0000:01:00.0"
          gpu_count: 1
          has_gpu: true
          slurm_gres:
            - "NodeName=hpc-compute-01 Name=gpu Type=nvidia_2805 File=/dev/nvidia0"
  vars:
    slurm_gres_conf:
      - "NodeName=hpc-compute-01 Name=gpu Type=nvidia_2805 File=/dev/nvidia0"
```

#### GPU Detection Process

1. **PCIe Passthrough Parsing**: Reads `pcie_passthrough.devices` from cluster configuration
2. **GPU Identification**: Filters devices by `device_type: gpu`
3. **Resource Mapping**: Creates SLURM GRES entries for GPU scheduling
4. **Inventory Organization**: Separates GPU nodes into dedicated inventory groups

#### Validation Commands

```bash
# Verify GPU detection
grep -A5 -B5 "gpu" inventories/hpc/hosts.yml

# Check GRES configuration
grep "slurm_gres" inventories/hpc/hosts.yml

# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('inventories/hpc/hosts.yml'))"
```

#### Testing

The inventory generator includes a comprehensive test suite with 9 validation tests:

```bash
# Run all validation tests
cd ansible/inventories
python3 test_inventory_generation.py

# Expected output:
# ✅ All validation tests passed!
# 📊 Ran 9 tests successfully
```

Test coverage includes:

- GPU detection from PCIe passthrough configuration
- GRES configuration generation for single and multiple GPUs
- Complete inventory structure validation for both HPC and Cloud clusters
- Edge cases (no GPU nodes, vendor mapping, YAML validation)

## Next Steps

1. ✅ **NVIDIA GPU drivers**: Completed - Full implementation with Debian wiki compliance
2. ✅ **Enhanced inventory generator**: Completed - Full GPU detection and GRES configuration
3. Implement cloud-base-packages role tasks for Kubernetes workloads
4. Implement cluster configuration tasks in cluster setup roles
5. Integrate with the CLI orchestrator for automated deployment
6. Add GPU resource configuration for SLURM and Kubernetes

## Minimal Design Philosophy

This structure follows a minimal design philosophy:

- **Only essential directories** are created
- **Role structure simplified** to just tasks initially
- **Additional directories** (defaults, vars, handlers, templates) added as needed
- **Easy to extend** without unnecessary complexity
