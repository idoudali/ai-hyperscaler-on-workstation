# Packer Image Build System

This directory contains Packer templates for building specialized VM images for
the HPC and Cloud clusters.

## Image Types

### HPC Images

- **hpc-controller**: Standard HPC base packages + container runtime (no NVIDIA
  GPU drivers)
- **hpc-compute**: Standard HPC base packages + container runtime + NVIDIA GPU
  drivers

### Cloud Images

- **cloud-base**: General-purpose cloud image for Kubernetes nodes

## Prerequisites

### Required Software

1. **Packer** (>= 1.9.0)

   ```bash
   curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
   sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
   sudo apt-get update && sudo apt-get install packer
   ```

2. **QEMU/KVM** (for virtualization)

   ```bash
   sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
   sudo usermod -aG libvirt $USER
   sudo usermod -aG kvm $USER
   ```

3. **Ansible** (for provisioning)

   ```bash
   sudo apt-get install ansible
   ```

4. **CMake** (>= 3.18, for build system)

   ```bash
   sudo apt-get install cmake
   ```

### System Requirements

- **Disk Space**: At least 10GB free space for image building
- **Memory**: Minimum 8GB RAM (16GB recommended)
- **Network**: Internet connection for downloading base images and packages

## Build System

The build system uses CMake to coordinate Packer builds with shared resources
(SSH keys, checksums) and proper dependency management. All builds run inside
a Docker development container for consistency.

### Base Image Configuration

All HPC images are built from:

- **Base OS**: Debian 13 (Trixie) Cloud Image
- **Release**: 20250806-2196
- **Source**: <https://cloud.debian.org/images/cloud/trixie/>
- **Checksum**: Automatically downloaded and verified via CMake

The CMake build system automatically:

- Downloads Debian cloud image SHA512 checksums
- Generates shared SSH keys for all images
- Manages build dependencies and output directories
- Copies BeeGFS packages to build VMs

### Quick Start

From the project root directory:

```bash
# 1. Build the development container (first time only)
make build-docker

# 2. Configure the build system
make config

# 3. Build all images
make run-docker COMMAND="cmake --build build --target build-packer-images"
```

**Alternative: Interactive Container Shell**

```bash
# Enter the container
make shell-docker

# Inside container, run builds directly
cmake --build build --target build-packer-images
```

### Individual Image Builds

#### HPC Controller Image

```bash
# Using Docker wrapper
make run-docker COMMAND="cmake --build build --target init-hpc-controller-packer"
make run-docker COMMAND="cmake --build build --target validate-hpc-controller-packer"
make run-docker COMMAND="cmake --build build --target build-hpc-controller-image"

# Or from inside container
cmake --build build --target build-hpc-controller-image
```

#### HPC Compute Image

```bash
# Using Docker wrapper
make run-docker COMMAND="cmake --build build --target init-hpc-compute-packer"
make run-docker COMMAND="cmake --build build --target validate-hpc-compute-packer"
make run-docker COMMAND="cmake --build build --target build-hpc-compute-image"

# Or from inside container
cmake --build build --target build-hpc-compute-image
```

#### Cloud Base Image

```bash
# Using Docker wrapper
make run-docker COMMAND="cmake --build build --target init-cloud-packer"
make run-docker COMMAND="cmake --build build --target validate-cloud-packer"
make run-docker COMMAND="cmake --build build --target build-cloud-image"

# Or from inside container
cmake --build build --target build-cloud-image
```

### Aggregate Targets

#### Build All HPC Images

```bash
# Using Docker wrapper
make run-docker COMMAND="cmake --build build --target build-hpc-images"

# Or from inside container
cmake --build build --target build-hpc-images
```

#### Build All Images

```bash
# Using Docker wrapper
make run-docker COMMAND="cmake --build build --target build-packer-images"

# Or from inside container
cmake --build build --target build-packer-images
```

## Build Output

Images are built to the following locations:

```text
build/
├── packer/
│   ├── hpc-controller/
│   │   ├── hpc-controller/
│   │   │   ├── hpc-controller.qcow2
│   │   │   ├── build_timestamp.txt
│   │   │   ├── image_type.txt
│   │   │   └── contents.txt
│   │   ├── cloud-init/
│   │   │   ├── user-data
│   │   │   └── meta-data
│   │   ├── hpc-controller.pkrvars.hcl
│   │   └── qemu-serial.log
│   ├── hpc-compute/
│   │   ├── hpc-compute/
│   │   │   ├── hpc-compute.qcow2
│   │   │   ├── build_timestamp.txt
│   │   │   ├── image_type.txt
│   │   │   └── contents.txt
│   │   ├── cloud-init/
│   │   │   ├── user-data
│   │   │   └── meta-data
│   │   ├── hpc-compute.pkrvars.hcl
│   │   └── qemu-serial.log
│   └── cloud-base/
│       ├── cloud-base/
│       │   ├── cloud-base.qcow2
│       │   ├── build_timestamp.txt
│       │   ├── image_type.txt
│       │   └── contents.txt
│       ├── cloud-init/
│       │   ├── user-data
│       │   └── meta-data
│       ├── cloud-base.pkrvars.hcl
│       └── qemu-serial.log
├── shared/
│   └── ssh-keys/
│       ├── id_rsa
│       └── id_rsa.pub
└── packages/
    └── beegfs/
        └── *.deb
```

## Common Build Process

All Packer images follow a standardized build process with the following steps:

### 1. Cloud-Init Initialization

```text
Start Debian cloud image → Cloud-init configuration → SSH key setup
```

The build begins with a Debian 13 cloud image and configures it using cloud-init
for initial setup (user creation, SSH keys, network configuration).

### 2. BeeGFS Package Installation

```text
Copy pre-built BeeGFS packages → Install via ansible-local
```

Pre-built BeeGFS `.deb` packages are copied into the build VM and installed.
BeeGFS components vary by image type (management/metadata/storage for controller,
client-only for compute nodes).

### 3. System Preparation

```text
Run setup script:
- Install essential packages (acl, curl, vim, htop)
- Configure NetworkManager for DHCP
- Create default network connection
- Prepare GPU infrastructure (compute nodes only)
```

### 4. Ansible Provisioning

```text
Apply image-specific playbook:
- hpc-base-packages: Core HPC packages and libraries
- container-runtime: Apptainer installation
- monitoring-stack: Prometheus/Node Exporter
- Image-specific roles (SLURM, GPU drivers, etc.)
```

### 5. Cleanup and Optimization

```text
- Remove package caches and temporary files
- Clear logs and histories
- Remove SSH host keys (regenerated on first boot)
- Clean cloud-init state
- Zero-fill free space for compression
```

### 6. Post-Processing

```text
- Compress image with qemu-img convert
- Create build metadata files
- Verify image integrity
```

## Build Variables

All images support both required and optional build variables:

### Common Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `repo_tot_dir` | Repository root path | `/home/user/ai-hyperscaler-on-workskation` |
| `source_directory` | Source directory path | `${repo_tot_dir}/packer/<image-type>` |
| `build_directory` | Build output directory | `${CMAKE_BINARY_DIR}/images/<image-type>` |
| `ssh_keys_dir` | SSH keys directory | `${CMAKE_BINARY_DIR}/shared/ssh-keys` |
| `cloud_init_dir` | Cloud-init config dir | `${repo_tot_dir}/packer/common/cloud-init` |

### Common Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `disk_size` | 20G-30G | Virtual disk size (varies by image) |
| `memory` | 2048-8192 | Build VM memory in MB |
| `cpus` | 2-8 | Build VM CPU cores |
| `ssh_username` | admin | SSH/cloud-init user |

Image-specific variables are documented in each image's README.

## Image Specifications

### HPC Controller Image

**Purpose**: SLURM controller and cluster management node

**Components**:

- **SLURM Controller**: Job scheduling (slurmctld, slurmdbd)
- **BeeGFS Services**: Management, metadata, storage, and client
- **Monitoring Stack**: Prometheus server + Node Exporter
- **Container Runtime**: Apptainer 1.4.2
- **Base Packages**: HPC development tools, networking, system utilities

**Size**: ~1.8GB compressed

**Use Case**: Cluster controller, job scheduler, shared storage manager, monitoring server

**Documentation**: See [hpc-controller/README.md](hpc-controller/README.md) for detailed information

### HPC Compute Image

**Purpose**: SLURM compute node with GPU support

**Components**:

- **SLURM Compute**: Job execution (slurmd)
- **GPU Support**: NVIDIA drivers (no CUDA - use containers)
- **MIG Support**: Multi-Instance GPU for A100/H100
- **Container Runtime**: Apptainer 1.4.2 with GPU integration
- **BeeGFS Client**: Parallel file system access
- **MPI Libraries**: OpenMPI for distributed computing
- **Monitoring**: Node Exporter + GPU metrics

**Size**: ~2.2GB compressed

**Use Case**: GPU compute nodes, ML/AI workloads, multi-node MPI jobs

**Documentation**: See [hpc-compute/README.md](hpc-compute/README.md) for detailed information

### HPC Base Architecture

**Note**: The project uses a **shared role-based approach** rather than a separate base image. All HPC
images start from Debian 13 cloud image and apply shared Ansible roles for common functionality.

**Shared Components**:

- Debian 13 (Trixie) base OS
- HPC development tools and libraries
- Container runtime (Apptainer)
- Monitoring (Node Exporter)
- Storage support (BeeGFS, NFS)

**Documentation**: See [hpc-base/README.md](hpc-base/README.md) for architecture details

### Cloud Base Image

**Purpose**: Kubernetes cluster nodes

**Components**:

- Docker/containerd runtime
- Kubernetes node components
- Cloud-native networking tools
- Basic system utilities

**Size**: ~1.5GB compressed

**Use Case**: Control plane and worker nodes in Kubernetes clusters

## Advanced Usage

### Custom Build Variables

You can customize builds by setting CMake variables during configuration:

```bash
# Configure with custom variables
make run-docker COMMAND="cmake -G Ninja -S . -B build -DSSH_USERNAME=myuser"
```

### Development and Testing

#### Format Templates

```bash
# Using Docker wrapper
make run-docker COMMAND="cmake --build build --target format-packer"

# Or from inside container
cmake --build build --target format-packer
```

#### Validate Templates

```bash
# Using Docker wrapper
make run-docker COMMAND="cmake --build build --target validate-packer"

# Or from inside container
cmake --build build --target validate-packer
```

#### Debug Builds

Set `PACKER_LOG=1` for verbose output:

```bash
# Using Docker wrapper
make run-docker COMMAND="PACKER_LOG=1 cmake --build build --target build-hpc-controller-image"

# Or from inside container
PACKER_LOG=1 cmake --build build --target build-hpc-controller-image
```

#### Preserve Failed Builds

Edit the appropriate `packer/<image-type>/CMakeLists.txt` and uncomment the debug args:

```cmake
set(PACKER_BUILD_DEBUG_ARGS -on-error=ask)
```

### Cloud-Init Customization

Each image type has its own cloud-init configuration in `common/cloud-init/`:

- `hpc-controller-user-data.yml` / `hpc-controller-meta-data.yml`
- `hpc-compute-user-data.yml` / `hpc-compute-meta-data.yml`
- `cloud-base-user-data.yml` / `cloud-base-meta-data.yml`

## Common Troubleshooting

This section covers issues common to all Packer image builds. For image-specific
troubleshooting, see the individual image README files.

### Build Environment Issues

#### Docker Container Not Available

**Symptom**: Commands fail with "docker: command not found"

**Solution**:

```bash
# Install Docker
sudo apt-get update
sudo apt-get install docker.io

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in

# Build development container
make build-docker
```

#### CMake Not Configured

**Symptom**: "No such file or directory: build"

**Solution**:

```bash
# Run configuration first
make config
```

### Common Build Issues

1. **Permission Denied Errors**

   ```bash
   sudo usermod -aG kvm $USER
   sudo usermod -aG libvirt $USER
   # Log out and log back in
   ```

2. **Network Connectivity Issues**

   ```bash
   # Check if libvirt default network is active
   sudo virsh net-list --all
   sudo virsh net-start default
   ```

3. **Disk Space Issues**

   ```bash
   # Clean up build artifacts
   make clean
   # Remove old QEMU images
   sudo virsh vol-list default
   sudo virsh vol-delete <volume-name> default
   ```

4. **Build Hangs or Fails**

   ```bash
   # Kill any stuck QEMU processes
   pkill -f qemu
   # Clean and retry
   rm -rf build/packer/
   make run-docker COMMAND="cmake --build build --target build-<target>-image"
   ```

### Log Files

Build logs are available at:

- `build/packer/<image-type>/qemu-serial.log` - QEMU serial console output
- Packer output in terminal (use `PACKER_LOG=1` for detailed logging)

## Performance Tuning

### Speed Up Builds

1. **Increase Build VM Resources**: Configure more memory and CPUs for faster builds

   ```bash
   # Edit image-specific CMakeLists.txt
   vim packer/<image-type>/CMakeLists.txt
   # Increase MEMORY and CPUS variables
   ```

2. **Use SSD Storage**: Build on SSD for faster I/O operations

3. **Disable Unused Services**: Customize Ansible playbooks to skip unnecessary components

   ```bash
   # Edit image playbook
   vim ansible/playbooks/playbook-<image-type>.yml
   # Comment out unnecessary roles
   ```

### Reduce Image Size

1. **Minimize Packages**: Edit Ansible roles to install only required packages

   ```bash
   vim ansible/roles/hpc-base-packages/defaults/main.yml
   ```

2. **Reduce Disk Size**: Configure smaller base disk

   ```bash
   # Edit image-specific CMakeLists.txt
   vim packer/<image-type>/CMakeLists.txt
   # Reduce DISK_SIZE variable
   ```

3. **Optimize Cleanup**: Templates already include comprehensive cleanup and compression

## Common Usage Patterns

### Image Verification

After building any image, verify its integrity:

```bash
# Check image info
qemu-img info build/packer/<image-type>/<image-type>/<image-type>.qcow2

# Check image integrity
qemu-img check build/packer/<image-type>/<image-type>/<image-type>.qcow2

# View build logs
less build/packer/<image-type>/qemu-serial.log
```

### Manual VM Creation

You can quickly test a built `.qcow2` image using the provided script:

```bash
# Using the helper script to launch a VM for quick testing
./scripts/experiments/start-test-vm.sh
```

This script is pre-configured for passthrough testing and rapid validation of the image. For details on advanced use
(CPU, RAM, passthrough options), see the script comments.

### Common Runtime Tasks

#### BeeGFS Client Configuration

All HPC images include BeeGFS client capabilities. For detailed configuration:

- [BeeGFS Setup Guide](../../docs/beegfs-setup.md) <!-- TODO: Create this guide -->
- [BeeGFS Ansible Role](../../ansible/roles/beegfs/README.md) <!-- TODO: Verify path -->

#### Container Runtime Usage

All images include Apptainer for containerized workloads. For detailed usage:

- [Container Runtime Role](../../ansible/roles/container-runtime/README.md)
- [Apptainer User Guide](../../docs/apptainer-usage.md) <!-- TODO: Create this guide -->

## Integration with ai-how CLI

The built images are automatically discovered by the ai-how CLI when placed in
the expected locations:

```yaml
# In cluster configuration
clusters:
  hpc:
    controller:
      base_image_path: "build/packer/hpc-controller/hpc-controller/hpc-controller.qcow2"
    compute_nodes:
      - base_image_path: "build/packer/hpc-compute/hpc-compute/hpc-compute.qcow2"
```

The schema now supports specifying different images at multiple levels:

- Cluster level (default for all nodes)
- Node type level (controller/compute nodes)
- Individual node level (per-VM override)

For more information on the schema and configuration options, see the [Schema
Documentation](../python/ai_how/src/ai_how/schemas/README.md).

## Detailed Documentation

For comprehensive information about each image type, see:

### Image Documentation

- **[HPC Base Architecture](hpc-base/README.md)** - Shared role-based architecture and design rationale
- **[HPC Controller Image](hpc-controller/README.md)** - Controller node detailed documentation
  - Build process and provisioning steps
  - SLURM controller configuration
  - BeeGFS management services
  - Monitoring stack setup
  - Runtime configuration and customization
  - Troubleshooting guide
- **[HPC Compute Image](hpc-compute/README.md)** - Compute node detailed documentation
  - Build process and GPU driver installation
  - SLURM compute daemon configuration
  - GPU passthrough and MIG setup
  - Container runtime with GPU integration
  - GPU workload examples
  - Performance tuning and optimization
  - Comprehensive troubleshooting

### Related Documentation

- **[Ansible Roles](../ansible/roles/README.md)** - Role-based provisioning documentation
- **[SLURM Configuration](../ansible/roles/slurm-controller/README.md)** - SLURM setup and configuration
- **[GPU Drivers](../ansible/roles/nvidia-gpu-drivers/README.md)** - NVIDIA driver installation and configuration
- **[Container Runtime](../ansible/roles/container-runtime/README.md)** - Apptainer setup and usage
- **[Monitoring Stack](../ansible/roles/monitoring-stack/README.md)** - Prometheus and monitoring configuration
- **[ai-how CLI](../python/ai_how/README.md)** - Deployment and management CLI

Each image-specific README provides:

- Detailed component specifications
- Step-by-step build instructions
- Build variable reference
- Usage examples and deployment guides
- Runtime configuration procedures
- Customization instructions
- Comprehensive troubleshooting
- Design decisions and rationale
