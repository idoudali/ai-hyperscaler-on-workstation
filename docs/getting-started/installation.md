# Installation

**Status:** Complete  
**Last Updated:** 2025-01-21

## Overview

This guide provides step-by-step instructions for installing the Hyperscaler on Workstation development
environment. The installation process automates most dependency installation, but manual steps are documented
where necessary.

**Prerequisites:** Ensure you have reviewed and met all requirements in the
[Prerequisites Guide](prerequisites.md) before proceeding.

---

## Installation Methods

### Automated Installation (Recommended)

The project provides an automated setup script that installs all required dependencies on Ubuntu/Debian systems.

### Manual Installation

For non-Ubuntu/Debian systems or custom configurations, manual installation steps are provided.

---

## Automated Installation (Ubuntu/Debian)

### Step 1: Clone the Repository

```bash
# Clone the repository
git clone <repository-url>
cd ai-hyperscaler-on-workskation

# Verify you're in the correct directory
ls -la
```

### Step 2: Run Automated Setup Script

The `setup-host-dependencies.sh` script installs all required system dependencies:

```bash
# Make script executable
chmod +x scripts/setup-host-dependencies.sh

# Install all dependencies
./scripts/setup-host-dependencies.sh

# Or show help for selective installation
./scripts/setup-host-dependencies.sh --help
```

**What the Script Installs:**

- Build tools (CMake, Ninja, Make, GCC)
- Python development environment (Python 3.11+, pip, venv)
- Docker CE (latest stable)
- Virtualization tools (libvirt, QEMU)
- Modern Python tooling (uv package manager)
- System utilities (curl, wget, git)

**Selective Installation:**

```bash
# Install only system packages
./scripts/setup-host-dependencies.sh --packages

# Install only Docker CE
./scripts/setup-host-dependencies.sh --docker

# Install only uv
./scripts/setup-host-dependencies.sh --uv

# Check installation status
./scripts/setup-host-dependencies.sh --check
```

### Step 3: Verify Installation

```bash
# Verify system packages
cmake --version
ninja --version
python3 --version
docker --version

# Verify virtualization support
lsmod | grep kvm
ls -l /dev/kvm

# Verify user groups
groups | grep -E 'docker|kvm|libvirt'
```

**Note:** If user groups were added, log out and log back in for changes to take effect.

### Step 4: Build Development Container

The project uses a Docker-based development environment for consistent builds:

```bash
# Build the development Docker image
make build-docker

# This may take 10-15 minutes on first build
# Subsequent builds use cached layers
```

**What's Included in the Container:**

- All build tools (CMake, Ninja, Packer, Terraform, Ansible)
- Python development environment
- Container runtime tools (Apptainer)
- SLURM build dependencies
- All required system libraries

### Step 5: Create Python Virtual Environment

```bash
# Create virtual environment and install dependencies
make venv-create

# This installs:
# - MkDocs and documentation plugins
# - AI-HOW Python CLI package
# - Ansible and collections
# - Development tools
```

### Step 6: Install Development Tools

**Pre-commit Hooks:**

```bash
# Install pre-commit hooks
make pre-commit-install

# Verify installation
pre-commit --version
```

**Commitizen (Optional):**

```bash
# Setup commitizen for conventional commits
./scripts/setup-commitizen.sh

# Test interactive commit
cz commit
```

**Shellcheck and Hadolint:**

These are installed as part of the pre-commit hooks setup. Verify:

```bash
shellcheck --version
hadolint --version
```

### Step 7: Verify Complete Installation

```bash
# Check all Makefile targets
make help

# Verify development container
make shell-docker
# Inside container:
make config
exit

# Verify Python CLI
source .venv/bin/activate
ai-how --help
```

---

## Manual Installation

For systems not supported by the automated script, you can manually execute the steps from the setup script.

### Reference Implementation

The automated setup script contains all package lists and installation logic:

- **Script:** [`scripts/setup-host-dependencies.sh`](../../scripts/setup-host-dependencies.sh)
- **Docker Build:** [`docker/Dockerfile`](../../docker/Dockerfile) for container dependencies
- **Python Dependencies:** [`python/ai_how/pyproject.toml`](../../python/ai_how/pyproject.toml)
- **Ansible Requirements:** [`ansible/requirements.txt`](../../ansible/requirements.txt)

### Manual Installation Overview

**Step 1: Install System Packages**

For Ubuntu/Debian package lists, see:

- `scripts/setup-host-dependencies.sh` → `install_debian_packages()` function (lines 106-139)

Key packages: `build-essential`, `cmake`, `ninja-build`, `python3-dev`, `libvirt-dev`, `qemu-system-x86`, `qemu-utils`, `virtiofsd`

```bash
# Extract package list from script
grep "apt-get install" scripts/setup-host-dependencies.sh
```

**Step 2: Install Docker CE**

For Docker installation commands, see:

- `scripts/setup-host-dependencies.sh` → `install_docker()` function (lines 141-224)

```bash
# View Docker installation steps
sed -n '/^install_docker()/,/^}/p' scripts/setup-host-dependencies.sh
```

**Step 3: Install uv (Python Package Manager)**

For uv installation, see:

- `scripts/setup-host-dependencies.sh` → `install_uv()` function (lines 226-256)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Step 4: Configure Virtualization**

```bash
# Add user to required groups
sudo usermod -aG kvm $USER
sudo usermod -aG libvirt $USER
sudo usermod -aG docker $USER

# Start libvirtd
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

# Log out and back in for group changes
```

**Step 5: Build Development Container**

For container build details, see:

- `docker/Dockerfile` - complete build specification
- `Makefile` → `build-docker` target (line 69-71)

```bash
make build-docker
```

**Step 6: Setup Python Environment**

For Python dependency details, see:

- `Makefile` → `venv-create` target (lines 118-126)
- `python/ai_how/pyproject.toml` - Python package dependencies
- `ansible/requirements.txt` - Ansible dependencies

```bash
# Use the Makefile target (recommended)
make venv-create

# This installs:
# - MkDocs and plugins (from Makefile)
# - AI-HOW package (from python/ai_how)
# - Ansible (from ansible/requirements.txt)
# - Ansible collections (from ansible/collections/requirements.yml)
```

**Step 7: Install Development Tools**

```bash
# Install pre-commit hooks
make pre-commit-install

# Optional: Setup commitizen
./scripts/setup-commitizen.sh
```

### Implementation Notes

**Why Use the Makefile?**

The Makefile provides tested, consistent commands that handle:

- Virtual environment creation with `uv`
- Correct dependency installation order
- Environment variable setup
- Error handling

**For Other Distributions:**

1. Consult your distribution's package manager for equivalent packages
2. Review `docker/Dockerfile` for build tool requirements
3. Ensure Python 3.11+ and modern build tools are available

---

## Post-Installation Verification

### System Checks

Run the comprehensive prerequisite checker:

```bash
# Run all checks
./scripts/system-checks/check_prereqs.sh all

# Or check specific components
./scripts/system-checks/check_prereqs.sh cpu
./scripts/system-checks/check_prereqs.sh kvm
./scripts/system-checks/check_prereqs.sh gpu
./scripts/system-checks/check_prereqs.sh packages
./scripts/system-checks/check_prereqs.sh resources
```

### Development Environment Checks

```bash
# Verify Makefile targets
make help

# Verify Docker container
make shell-docker
# Inside container: exit when done
exit

# Verify Python CLI
source .venv/bin/activate
ai-how --help
ai-how validate --help

# Verify CMake configuration
make config
ls -la build/
```

### GPU Verification (if applicable)

```bash
# Check GPU detection
lspci | grep -i nvidia

# Check NVIDIA driver
nvidia-smi

# Check CUDA (if installed)
nvcc --version

# Check IOMMU groups (for passthrough)
find /sys/kernel/iommu_groups/ -type l | head
```

---

## Common Installation Issues

### Issue: Docker Permission Denied

**Symptoms:**

```bash
docker: Got permission denied while trying to connect to the Docker daemon socket
```

**Solution:**

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or:
newgrp docker

# Verify
docker ps
```

### Issue: KVM Not Available

**Symptoms:**

```bash
# KVM module not loaded
lsmod | grep kvm  # No output
```

**Solution:**

```bash
# Check virtualization support in BIOS/UEFI
# Enable "Virtualization Technology" or "VT-x/AMD-V"

# After BIOS change, verify:
grep -E 'vmx|svm' /proc/cpuinfo

# Load KVM module
sudo modprobe kvm
sudo modprobe kvm_intel  # Intel
# or
sudo modprobe kvm_amd    # AMD
```

### Issue: Insufficient Disk Space

**Symptoms:**

```bash
# Build fails with "No space left on device"
df -h /
```

**Solution:**

```bash
# Check disk usage
du -sh build/
du -sh ~/.docker/

# Clean Docker system
docker system prune -a

# Clean build artifacts
make clean-docker
rm -rf build/

# Free additional space if needed
sudo apt-get autoremove
sudo apt-get autoclean
```

### Issue: Python Virtual Environment Issues

**Symptoms:**

```bash
# Module not found errors
python3 -m ai_how.cli  # ModuleNotFoundError
```

**Solution:**

```bash
# Recreate virtual environment
rm -rf .venv
make venv-create

# Activate and verify
source .venv/bin/activate
ai-how --help
```

### Issue: LibVirt Connection Failed

**Symptoms:**

```bash
# virsh commands fail
virsh list  # Error: failed to connect to hypervisor
```

**Solution:**

```bash
# Start libvirtd service
sudo systemctl start libvirtd
sudo systemctl enable libvirtd

# Check status
sudo systemctl status libvirtd

# Verify user is in libvirt group
groups | grep libvirt

# If not, add and relogin:
sudo usermod -aG libvirt $USER
```

### Issue: CMake Configuration Fails

**Symptoms:**

```bash
# make config fails
CMake Error: Could not find ...
```

**Solution:**

```bash
# Ensure you're running in the development container
make shell-docker

# Inside container:
make config

# Or run directly:
make run-docker COMMAND="cmake -G Ninja -S . -B build"
```

---

## Installation Verification Checklist

After installation, verify all components:

- [ ] System packages installed (CMake, Ninja, Python, Git)
- [ ] Docker CE installed and running
- [ ] User in docker, kvm, libvirt groups
- [ ] Development container built (`make build-docker`)
- [ ] Python virtual environment created (`make venv-create`)
- [ ] Pre-commit hooks installed (`make pre-commit-install`)
- [ ] CMake configuration successful (`make config`)
- [ ] AI-HOW CLI functional (`ai-how --help`)
- [ ] Prerequisite checker passes (`./scripts/system-checks/check_prereqs.sh all`)
- [ ] GPU detected (if using GPU features) (`nvidia-smi`)
- [ ] KVM available (`lsmod | grep kvm`)

---

## Next Steps

After successful installation:

1. **Configure Your First Cluster:** See [Cluster Deployment Quickstart](quickstart-cluster.md)
2. **Run a 5-Minute Quickstart:** See [5-Minute Quickstart](quickstart-5min.md)
3. **Tutorial - First Cluster:** See [Tutorial: Your First Cluster](../tutorials/01-first-cluster.md)

---

## Additional Resources

- **Development Workflow:** See [Development Guide](../development/python-dependencies-setup.md)
- **Architecture Overview:** See [Architecture Documentation](../architecture/overview.md)
- **Troubleshooting:** See [Troubleshooting Guide](../troubleshooting/common-issues.md)
- **Project README:** See [README.md](../README.md)

---

## Support

If you encounter issues not covered in this guide:

1. Check the [Troubleshooting Guide](../troubleshooting/common-issues.md)
2. Review [Common Issues](prerequisites.md#troubleshooting)
3. Check project issues and documentation
4. Run prerequisite checker: `./scripts/system-checks/check_prereqs.sh all`
