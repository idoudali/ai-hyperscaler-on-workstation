# Packer Ansible Replication Script

This directory contains a helper script that replicates the Ansible execution
that happens during Packer builds for the HPC base image.

> **⚠️ IMPORTANT**: This script requires the project's virtual environment to be
> activated before running. Always run `source .venv/bin/activate` before using
> this script.

## Quick Start

**Important**: Always activate the virtual environment before running the
script.

```bash
# 1. Set up the environment (if not already done)
make venv-install

# 2. Activate the virtual environment
source .venv/bin/activate

# 3. Navigate to ansible directory
cd ansible

# 4. Run on localhost (most common for VM testing)
./run-packer-ansible.sh

# Run on specific host
./run-packer-ansible.sh 192.168.1.100

# Use different SSH user
SSH_USERNAME=ubuntu ./run-packer-ansible.sh localhost

# Use custom SSH port (e.g., for VM with port forwarding)
SSH_PORT=2222 ./run-packer-ansible.sh localhost

# Use custom SSH key
SSH_KEY=/path/to/your/key ./run-packer-ansible.sh localhost
```

## What This Script Does

The `run-packer-ansible.sh` script replicates the exact Ansible execution that
happens during Packer builds:

1. **HPC Base Packages**: Installs tmux, htop, vim, curl, wget
2. **Container Runtime**: Installs Apptainer (successor to Singularity)
3. **NVIDIA GPU Drivers**: Installs NVIDIA drivers (without CUDA by default)
4. **Configuration**: Applies the same configuration as Packer builds

## Usage Scenarios

### Testing Before Packer Rebuild

```bash
# Set up environment and activate virtual environment
make venv-install
source .venv/bin/activate
cd ansible

# Test changes on a VM before rebuilding Packer image
./run-packer-ansible.sh localhost

# Test on VM with custom SSH port (e.g., QEMU port forwarding)
SSH_PORT=2222 ./run-packer-ansible.sh localhost
```

### Updating Existing VMs

```bash
# Set up environment and activate virtual environment
make venv-install
source .venv/bin/activate
cd ansible

# Apply same packages to existing VMs
./run-packer-ansible.sh vm-hostname

# Use custom SSH port for VM access
SSH_PORT=2222 SSH_USERNAME=ubuntu ./run-packer-ansible.sh vm-hostname
```

### Debugging Ansible Issues

```bash
# Set up environment and activate virtual environment
make venv-install
source .venv/bin/activate
cd ansible

# Run with verbose output to debug issues
VERBOSE=true ./run-packer-ansible.sh localhost

# Debug with custom SSH configuration
VERBOSE=true SSH_PORT=2222 SSH_USERNAME=ubuntu ./run-packer-ansible.sh localhost
```

## Configuration

The script uses the same configuration as Packer:

- **Playbook**: `playbooks/playbook-hpc.yml`
- **Roles**: `hpc-base-packages`, `container-runtime`, `nvidia-gpu-drivers`
- **Variables**: `packer_build=true`, `nvidia_install_cuda=false`
- **Environment**: Same Ansible environment variables as Packer

## Requirements

- **Virtual environment activated** (required - see Quick Start above)
- Ansible installed in the virtual environment
- SSH access to target host
- SSH key for authentication (defaults to `build/shared/ssh-keys/id_rsa`)
- Target host must have Python 3 installed
- Sudo access on target host

### Setting Up the Environment

If you haven't set up the virtual environment yet, use the project's Makefile:

```bash
# Navigate to project root
cd /home/doudalis/Projects/pharos.ai-hyperscaler-on-workskation

# Install virtual environment and all dependencies (including Ansible)
make venv-install

# Activate virtual environment
source .venv/bin/activate

# Navigate to ansible directory
cd ansible
```

## Examples

```bash
# Always start by setting up and activating the virtual environment
make venv-install
source .venv/bin/activate
cd ansible

# Basic usage
./run-packer-ansible.sh

# Run on specific IP with different user
SSH_USERNAME=ubuntu ./run-packer-ansible.sh 192.168.1.100

# Use custom SSH port (e.g., for QEMU VM with port forwarding)
SSH_PORT=2222 ./run-packer-ansible.sh localhost

# Use custom SSH key
SSH_KEY=/path/to/your/key ./run-packer-ansible.sh localhost

# Combine custom user, port, and key
SSH_USERNAME=ubuntu SSH_PORT=2222 SSH_KEY=/path/to/your/key ./run-packer-ansible.sh 192.168.1.100

# Disable verbose output
VERBOSE=false ./run-packer-ansible.sh localhost

# Show help
./run-packer-ansible.sh --help
```

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connection first
ssh debian@localhost

# Test SSH connection with custom port
ssh -p 2222 debian@localhost

# Use different SSH user if needed
SSH_USERNAME=ubuntu ./run-packer-ansible.sh localhost

# Use custom SSH port if needed
SSH_PORT=2222 ./run-packer-ansible.sh localhost
```

### Ansible Not Found / ModuleNotFoundError

```bash
# Most common solution: Use Makefile to set up environment
make venv-install
source .venv/bin/activate
cd ansible
./run-packer-ansible.sh

# If virtual environment is corrupted, reset everything
make venv-reset
source .venv/bin/activate
cd ansible
./run-packer-ansible.sh

# Alternative: Install Ansible globally (not recommended)
pip install ansible
```

### Permission Issues

```bash
# Ensure script is executable
chmod +x run-packer-ansible.sh

# Check sudo access on target host
ssh debian@localhost sudo -l
```

## VM Port Forwarding

When working with VMs that use port forwarding (like QEMU VMs), you'll need to
specify the forwarded SSH port:

```bash
# Set up environment and activate virtual environment
make venv-install
source .venv/bin/activate
cd ansible

# For QEMU VM with SSH port forwarded to 2222
SSH_PORT=2222 ./run-packer-ansible.sh localhost

# For VM with different user and port
SSH_USERNAME=ubuntu SSH_PORT=2222 ./run-packer-ansible.sh localhost
```

Common VM port forwarding configurations:

- **QEMU**: `-netdev user,id=net0,hostfwd=tcp::2222-:22`
- **VirtualBox**: Port forwarding rule: Host 2222 → Guest 22
- **VMware**: NAT port forwarding: 2222 → 22

## SSH Key Configuration

The script uses SSH key authentication by default. The SSH key path can be
configured:

### Default SSH Key

```bash
# Uses default key: build/shared/ssh-keys/id_rsa
./run-packer-ansible.sh localhost
```

### Custom SSH Key

```bash
# Use a different SSH key
SSH_KEY=/path/to/your/private/key ./run-packer-ansible.sh localhost

# Use SSH key with custom user and port
SSH_USERNAME=ubuntu SSH_PORT=2222 SSH_KEY=/path/to/your/key ./run-packer-ansible.sh localhost
```

### SSH Key Requirements

- The SSH key must exist and be readable
- The corresponding public key must be installed on the target host
- The key should have appropriate permissions (typically 600)

## Notes

- The script creates a temporary inventory file that is cleaned up automatically
- NVIDIA drivers may require a reboot to become active
- The script uses the same environment variables and configuration as Packer
- All Ansible roles and playbooks are executed in the same order as Packer
  builds
- SSH port 22 is used by default, but can be overridden with `SSH_PORT`
  environment variable
