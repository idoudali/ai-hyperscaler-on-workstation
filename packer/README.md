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
(SSH keys, checksums)  and proper dependency management.

### Quick Start

From the project root directory:

```bash
# Configure the build
mkdir -p build
cd build
cmake ..

# Build all images
make build-packer-images
```

### Individual Image Builds

#### HPC Controller Image

```bash
# Initialize, validate, and build
make init-hpc-controller-packer
make validate-hpc-controller-packer
make build-hpc-controller-image
```

#### HPC Compute Image

```bash
# Initialize, validate, and build
make init-hpc-compute-packer
make validate-hpc-compute-packer
make build-hpc-compute-image
```

#### Cloud Base Image

```bash
# Initialize, validate, and build
make init-cloud-packer
make validate-cloud-packer
make build-cloud-image
```

### Aggregate Targets

#### Build All HPC Images

```bash
make build-hpc-images
```

#### Build All Images

```bash
make build-packer-images
```

## Build Output

Images are built to the following locations:

```text
build/
├── packer/
│   ├── hpc-controller/
│   │   └── hpc-controller.qcow2
│   ├── hpc-compute/
│   │   └── hpc-compute.qcow2
│   └── cloud-base/
│       └── cloud-base.qcow2
└── shared/
    └── ssh-keys/
        ├── id_rsa
        └── id_rsa.pub
```

## Image Specifications

### HPC Controller Image

**Purpose**: Standard HPC node without GPU support

**Components**:

- HPC base packages (development tools, networking, system utilities)
- Apptainer container runtime
- Standard system libraries and tools

**Size**: ~1.8GB compressed

**Use Case**: Controller nodes, CPU-only compute nodes, or any HPC node without
GPU requirements

### HPC Compute Image

**Purpose**: HPC node with GPU support

**Components**:

- HPC base packages (same as controller image)
- Apptainer container runtime (same as controller image)
- NVIDIA GPU drivers and CUDA libraries
- GPU monitoring tools (nvidia-smi, etc.)

**Size**: ~2.2GB compressed

**Use Case**: Compute nodes with GPU hardware, ML/AI workload nodes

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

You can customize builds by setting CMake variables:

```bash
cmake -DSSH_USERNAME=myuser -DDISK_SIZE=30G ..
```

### Development and Testing

#### Format Templates

```bash
make format-packer
```

#### Validate Templates

```bash
make validate-packer
```

#### Debug Builds

Set `PACKER_LOG=1` for verbose output:

```bash
PACKER_LOG=1 make build-hpc-controller-image
```

#### Preserve Failed Builds

Edit the CMakeLists.txt and uncomment the debug args:

```cmake
set(PACKER_BUILD_DEBUG_ARGS -on-error=ask)
```

### Cloud-Init Customization

Each image type has its own cloud-init configuration in `common/cloud-init/`:

- `hpc-controller-user-data.yml` / `hpc-controller-meta-data.yml`
- `hpc-compute-user-data.yml` / `hpc-compute-meta-data.yml`
- `cloud-base-user-data.yml` / `cloud-base-meta-data.yml`

## Troubleshooting

### Common Issues

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
   make build-<target>-image
   ```

### Log Files

Build logs are available at:

- `build/packer/<image-type>/qemu-serial.log` - QEMU serial console output
- Packer output in terminal (use `PACKER_LOG=1` for detailed logging)

### Performance Tuning

#### Speed Up Builds

1. **Increase Memory**: Edit CMakeLists.txt to increase `MEMORY` variable
2. **Use SSD Storage**: Build on SSD for faster I/O
3. **Disable Unused Services**: Customize Ansible playbooks to skip unnecessary
   components

#### Reduce Image Size

1. **Minimize Packages**: Edit Ansible roles to install only required packages
2. **Clean Up**: The templates include comprehensive cleanup steps
3. **Compress Images**: Images are automatically compressed during build

## Integration with ai-how CLI

The built images are automatically discovered by the ai-how CLI when placed in
the expected locations:

```yaml
# In cluster configuration
clusters:
  hpc:
    controller:
      base_image_path: "build/packer/hpc-controller/hpc-controller.qcow2"
    compute_nodes:
      - base_image_path: "build/packer/hpc-compute/hpc-compute.qcow2"
```

The schema now supports specifying different images at multiple levels:

- Cluster level (default for all nodes)
- Node type level (controller/compute nodes)
- Individual node level (per-VM override)

For more information on the schema and configuration options, see the [Schema
Documentation](../python/ai_how/src/ai_how/schemas/README.md).
