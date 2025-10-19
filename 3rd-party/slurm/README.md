# SLURM Package Build from Source

This directory contains CMake configuration to build SLURM Debian packages from source following the official
SchedMD quickstart administrator guide.

## Overview

SLURM packages are missing or incomplete in Debian Trixie repositories. This build system creates Debian packages
from source to enable HPC cluster deployment.

## Prerequisites

The following build dependencies must be present in the build environment (e.g., the development Docker image) before building:

- build-essential
- fakeroot
- devscripts
- equivs
- libmunge-dev
- libmariadb-dev (or libmysqlclient-dev)
- libpmix-dev
- libpam0g-dev
- libhwloc-dev
- liblua5.3-dev
- libjson-c-dev
- libhttp-parser-dev
- libyaml-dev
- libcurl4-openssl-dev
- libssl-dev
- wget

## Building Packages

### Using Docker Container (Recommended)

```bash
# Configure CMake
make config

# Build SLURM packages in dev container
make run-docker COMMAND="cmake --build build --target build-slurm-packages"

# List built packages
make run-docker COMMAND="cmake --build build --target list-slurm-packages"
```

### Building Directly

```bash
# Configure CMake
cmake -G Ninja -S . -B build

# Build SLURM packages
cmake --build build --target build-slurm-packages

# List built packages
cmake --build build --target list-slurm-packages
```

## Build Output

Packages are created in `build/packages/slurm/`:

The build process using `dpkg-buildpackage` generates multiple SchedMD packages:

```text
slurm-smd_24.11.0_amd64.deb              - Meta package for complete SLURM installation
slurm-smd-client_24.11.0_amd64.deb       - Client tools (srun, squeue, scontrol, sacct, etc.)
slurm-smd-slurmd_24.11.0_amd64.deb       - Compute node daemon (slurmd)
slurm-smd-slurmctld_24.11.0_amd64.deb    - Controller daemon (slurmctld)
slurm-smd-slurmdbd_24.11.0_amd64.deb     - Database daemon (slurmdbd)
libslurm40_24.11.0_amd64.deb             - SLURM runtime libraries
libslurm-dev_24.11.0_amd64.deb           - SLURM development libraries
slurm-smd-doc_24.11.0_amd64.deb          - Documentation and man pages
```

**Note:** Package names follow SchedMD convention with `slurm-smd` prefix (not `slurm-wlm`)

## Configuration Options

Customize the build by setting CMake variables:

```bash
cmake -G Ninja -S . -B build \
  -DSLURM_VERSION=24.11.0 \
  -DSLURM_DOWNLOAD_URL=https://download.schedmd.com/slurm/slurm-24.11.0.tar.bz2
```

## SLURM Configure Options

The build uses these configure options (from SchedMD guide):

```bash
./configure \
  --prefix=/usr \
  --sysconfdir=/etc/slurm \
  --with-pmix=/usr/lib/x86_64-linux-gnu/pmix2 \
  --with-mariadb_config=/usr/bin/mariadb_config \
  --enable-pam \
  --enable-multiple-slurmd \
  --with-munge=/usr \
  --with-systemdsystemunitdir=/lib/systemd/system
```

**Key Features Enabled:**

- PMIx integration for MPI support (explicit path for Debian)
- MariaDB/MySQL support for job accounting
- PAM module for node access control
- MUNGE authentication
- Systemd service integration

**Auto-Detected Features:**

The following libraries are automatically detected via pkg-config:

- Hardware topology support (hwloc)
- JSON output support (json-c)
- Lua scripting support (lua5.3)
- Readline for interactive CLI
- Ncurses for terminal UI
- HTTP parser for REST API
- YAML configuration support

## GPU Autodetection Support

SLURM 24.11+ includes **built-in NVIDIA GPU autodetection** that requires no additional libraries!

**Reference**: [SLURM GRES AutoDetect Documentation](https://slurm.schedmd.com/gres.conf.html#OPT_AutoDetect)

### Built-in AutoDetect (Enabled)

- ✅ **`AutoDetect=nvidia`** - Built-in NVIDIA GPU detection
  - **No libraries required** - works out of the box
  - Automatically detects NVIDIA GPUs
  - Does not support MIG or NVLink detection
  - Configured in `gres.conf` on compute nodes

### Configuration Example

Add to `/etc/slurm/gres.conf` on compute nodes:

```bash
# Automatically detect NVIDIA GPUs (no libraries needed)
AutoDetect=nvidia
```

SLURM will automatically:

- Detect all NVIDIA GPU devices
- Configure device files (`/dev/nvidia*`)
- Set up resource tracking
- Enable `nvidia_gpu_env` (sets `CUDA_VISIBLE_DEVICES`)

### Advanced GPU Detection (Optional)

For advanced features, install vendor-specific libraries:

| AutoDetect Mode | Hardware | Requirements |
|-----------------|----------|--------------|
| `nvml` | NVIDIA (MIG/NVLink) | libnvidia-ml-dev |
| `rsmi` | AMD GPUs | ROCm libraries |
| `oneapi` | Intel GPUs | oneAPI runtime |

**Note**: These libraries are **not included** in the Docker build environment. They must be installed on target
compute nodes if advanced GPU detection is needed.

## Build Time

Expected build time: 10-15 minutes (depending on system performance and number of CPU cores)

## Ansible Integration

After building packages, update Ansible roles to install from the pre-built packages:

```yaml
# ansible/roles/slurm-controller/tasks/install.yml
- name: Copy SLURM packages to target
  copy:
    src: "{{ playbook_dir }}/../build/packages/slurm/"
    dest: "/tmp/slurm-packages/"

- name: Install SLURM controller packages
  apt:
    deb: "{{ item }}"
  loop:
    - "/tmp/slurm-packages/slurm-smd_24.11.0_amd64.deb"
    - "/tmp/slurm-packages/slurm-smd-slurmctld_24.11.0_amd64.deb"
    - "/tmp/slurm-packages/slurm-smd-slurmdbd_24.11.0_amd64.deb"
```

## Cleaning Build Artifacts

```bash
# Clean SLURM build artifacts only
cmake --build build --target clean-slurm

# Full clean (all build artifacts)
rm -rf build/
```

## Verifying Built Package

```bash
# List all built packages
ls -lh build/packages/slurm/*.deb

# Check meta package contents
dpkg -c build/packages/slurm/slurm-smd_24.11.0_amd64.deb | less

# Check package info
dpkg-deb -I build/packages/slurm/slurm-smd_24.11.0_amd64.deb

# Test installation (in a VM or container)
dpkg -i build/packages/slurm/slurm-smd_24.11.0_amd64.deb \
        build/packages/slurm/slurm-smd-slurmctld_24.11.0_amd64.deb
slurmctld -V
```

## Official Documentation

- [SLURM Quick Start Administrator Guide](https://slurm.schedmd.com/quickstart_admin.html#pkg_install)
- [Building Debian Packages](https://slurm.schedmd.com/quickstart_admin.html#building-debian-packages)
- [SLURM Download](https://www.schedmd.com/downloads.php)

## Troubleshooting

### Missing Dependencies

If build fails due to missing dependencies:

```bash
# Install build dependencies manually
apt-get update
apt-get install -y build-essential fakeroot devscripts equivs \
  libmunge-dev libmariadb-dev libpmix-dev libpam0g-dev \
  libhwloc-dev liblua5.3-dev libjson-c-dev libhttp-parser-dev \
  libyaml-dev libcurl4-openssl-dev libssl-dev
```

### Download Failures

If download fails, manually download and place in build directory:

```bash
cd 3rd-party/slurm
wget https://download.schedmd.com/slurm/slurm-24.11.0.tar.bz2
```

### PMIx Integration Issues

Ensure PMIx development libraries are installed:

```bash
apt-get install -y libpmix2 libpmix-dev
```

### MariaDB/MySQL Client Issues

Ensure MariaDB/MySQL client libraries are installed:

```bash
apt-get install -y libmariadb-dev default-libmysqlclient-dev
```

### Build Errors

Check configure log for missing dependencies:

```bash
cat build/3rd-party/slurm/slurm-24.11.0/config.log | grep -A 5 "ERROR"
```

## Version Information

- **Current Version**: 24.11.0
- **Release Date**: 2024-11-19
- **Architecture**: amd64
- **Debian Target**: Trixie (Debian 13)
- **SLURM Major.Minor**: 24.11
- **New Features**: Built-in AutoDetect=nvidia (no libraries required)

## Related Tasks

- **TASK-028.2**: Build SLURM from source (this implementation)
- **TASK-034.1**: Update Ansible roles to use pre-built packages (Phase 4)
- **TASK-010.2**: Original SLURM controller installation (needs update)
