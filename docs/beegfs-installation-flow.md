# BeeGFS Installation Flow

## Overview

The BeeGFS installation system supports two deployment modes:

1. **Packer Build Time**: Packages are pre-installed in VM images
2. **Runtime Deployment**: Packages are installed on-demand via Ansible

Both modes work seamlessly and automatically detect what's already installed.

## Installation Modes

### Mode 1: Packer Build Time Installation

During VM image creation with Packer, BeeGFS packages are:

1. **Copied** from `build/packages/beegfs/` to `/tmp/beegfs-packages/` inside the VM
2. **Installed** using `ansible-local` provisioner running `playbook-beegfs-packer-install.yml`

**Controller Image** installs:

- `beegfs-mgmt` (Management service)
- `beegfs-meta` (Metadata service)
- `beegfs-storage` (Storage service)
- `beegfs-client` (Client)

**Compute Image** installs:

- `beegfs-storage` (Storage service)
- `beegfs-client` (Client)

**Result**: VMs boot with BeeGFS already installed, ready for configuration.

### Mode 2: Runtime Deployment

When deploying to existing VMs (like test clusters), Ansible:

1. **Checks** if BeeGFS binaries already exist
   - `/usr/bin/beegfs-mgmtd` for management
   - `/usr/bin/beegfs-meta` for metadata
   - `/usr/bin/beegfs-storage` for storage
   - `/opt/beegfs/sbin/beegfs-client` for client

2. **Skips** if already installed (from Packer)

3. **Installs** if not present:
   - Checks if packages exist at `/tmp/beegfs-packages/` (from Packer copy)
   - If not, checks `build/packages/beegfs/` on Ansible controller
   - Copies packages from controller to VM if needed
   - Installs packages using `apt`

**Result**: VMs get BeeGFS installed regardless of image state.

## File Organization

### Ansible Playbooks

- **`playbook-beegfs-packer-install.yml`**: Used by Packer during image build
  - Sets `packer_build=true` and `install_only=true`
  - Runs on `localhost` with `connection: local`
  - Installs all BeeGFS roles appropriate for the node type

- **`playbook-beegfs-runtime-config.yml`**: Used at runtime for full deployment
  - Installs (if needed) AND configures services
  - Starts and enables systemd services
  - Used by test framework and production deployments

### Ansible Roles

All four roles (`beegfs-mgmt`, `beegfs-meta`, `beegfs-storage`, `beegfs-client`) follow the same pattern:

#### `tasks/install.yml`

1. Check if service binary already exists
2. Skip all installation if already installed
3. Look for packages in `/tmp/beegfs-packages/` (Packer)
4. Look for packages in `build/packages/beegfs/` (controller)
5. Copy from controller if found
6. Install using `apt` with architecture-aware wildcards
7. Create necessary directories

#### Variables (in `defaults/main.yml`)

```yaml
beegfs_version: "7.4.4"
beegfs_packages_path: "/tmp/beegfs-packages"          # Path on VMs
beegfs_packages_source_dir: "build/packages/beegfs"  # Path on controller
```

### Packer Templates

#### `hpc-controller/hpc-controller.pkr.hcl`

```hcl
# 1. Copy packages
provisioner "file" {
  source = "${var.beegfs_packages_dir}/"
  destination = "/tmp/beegfs-packages"
}

# 2. Install packages
provisioner "ansible-local" {
  playbook_file = "playbook-beegfs-packer-install.yml"
  extra_arguments = [
    "--extra-vars", "packer_build=true",
    "--extra-vars", "install_only=true",
  ]
}
```

#### `hpc-compute/hpc-compute.pkr.hcl`

Same pattern, but with `--tags beegfs-storage,beegfs-client`

## Installation Detection

Each role checks for its specific binary:

| Role | Binary Path | Purpose |
|------|-------------|---------|
| `beegfs-mgmt` | `/usr/bin/beegfs-mgmtd` | Management daemon |
| `beegfs-meta` | `/usr/bin/beegfs-meta` | Metadata daemon |
| `beegfs-storage` | `/usr/bin/beegfs-storage` | Storage daemon |
| `beegfs-client` | `/opt/beegfs/sbin/beegfs-client` | Client binary |

**Idempotency**: If the binary exists, all installation tasks are skipped.

## Package Naming

BeeGFS packages include architecture suffixes:

- `beegfs-common_7.4.4_amd64.deb`
- `beegfs-mgmtd_7.4.4_amd64.deb`
- `beegfs-client_7.4.4_all.deb`

Ansible uses wildcards to handle this:

```yaml
patterns: "beegfs-common_{{ beegfs_version }}_*.deb"
```

## Workflow Examples

### Example 1: Building New Images

```bash
# Build BeeGFS packages
make run-docker COMMAND="cmake --build build --target build-beegfs-packages"

# Build Packer images (BeeGFS installed automatically)
make run-docker COMMAND="cmake --build build --target build-hpc-controller-image"
make run-docker COMMAND="cmake --build build --target build-hpc-compute-image"
```

**Result**: Images contain pre-installed BeeGFS packages.

### Example 2: Runtime Test Deployment

```bash
# Start test cluster (using images with BeeGFS pre-installed)
./tests/test-beegfs-framework.sh start-cluster

# Deploy configuration (skips installation, only configures)
./tests/test-beegfs-framework.sh deploy-ansible
```

**Result**: Ansible detects BeeGFS is already installed and only configures services.

### Example 3: Fresh VM Deployment

```bash
# Deploy to VMs without BeeGFS
ansible-playbook -i inventory.yml playbook-beegfs-runtime-config.yml
```

**Result**: Ansible detects BeeGFS is not installed, copies packages from controller, and installs them.

## Benefits

1. **Faster Cluster Startup**: Images with pre-installed packages boot faster
2. **Flexibility**: Works with any VM, pre-installed or not
3. **No Duplication**: Installation logic is reused between Packer and runtime
4. **Idempotency**: Safe to run multiple times, only installs when needed
5. **No Repository Dependencies**: All packages are locally built and managed

## Dependencies

- **Packer**: Requires `build-beegfs-packages` to run before image builds
- **Ansible Controller**: Requires packages in `build/packages/beegfs/` for runtime deployments
- **Both**: No internet connection or external repository access required

## Configuration vs Installation

- **Installation** (`install_only=true`): Only installs packages, creates directories
- **Configuration**: Updates config files, initializes services, starts daemons
- **Packer**: Does installation only
- **Runtime**: Does both (installation if needed, always configuration)
