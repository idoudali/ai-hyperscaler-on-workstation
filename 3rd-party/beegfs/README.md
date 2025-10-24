# BeeGFS Package Build

**Status:** Production
**Created:** 2025-01-20
**Last Updated:** 2025-10-24

## Overview

This component builds BeeGFS parallel filesystem packages from source for use in HPC infrastructure
images. BeeGFS is a high-performance distributed file system designed for cluster computing
environments.

## Build Process

### Quick Start

```bash
# Build BeeGFS packages
cmake --build build --target build-beegfs-packages

# List built packages
cmake --build build --target list-beegfs-packages

# Clean build artifacts
cmake --build build --target clean-beegfs
```

### Prerequisites

The following dependencies must be present in the build environment:

- build-essential (GCC, make, etc.)
- libevent-dev (event processing)
- pkg-config (dependency configuration)
- zlib1g-dev (compression library)
- gzip (compression)
- tar (archiving)
- wget (downloading sources)

The Docker development environment includes all required dependencies.

### Build Steps

1. **Source Download**: Retrieve BeeGFS source tarball from official repository
2. **Configuration**: Configure build for Debian/Ubuntu target
3. **Compilation**: Build BeeGFS components (client, server, utilities)
4. **Packaging**: Create Debian packages from built components
5. **Output**: Generated packages available in `build/packages/beegfs/`

### Configuration Options

Build configuration can be customized through CMake variables:

```bash
cmake -G Ninja -S . -B build \
  -DBEEGFS_VERSION=7.4.10 \
  -DBEEGFS_DOWNLOAD_URL=https://www.beegfs.io/release/beegfs_7.4.10/source/beegfs-7.4.10.tar.gz
```

**Key Variables:**

- `BEEGFS_VERSION`: Version to build (default: 7.4.10)
- `BEEGFS_DOWNLOAD_URL`: Source tarball location
- `BEEGFS_BUILD_PATH`: Output directory (default: build/packages/beegfs/)

## Build Output

Packages are created in `build/packages/beegfs/`:

```text
beegfs-client_7.4.10_amd64.deb       - Client software for accessing BeeGFS
beegfs-server_7.4.10_amd64.deb       - Storage server software
beegfs-admon_7.4.10_amd64.deb        - Admin/monitoring tools
beegfs-utils_7.4.10_amd64.deb        - Utility programs
libbeegfs-ib_7.4.10_amd64.deb        - InfiniBand transport library
```

## Installation and Configuration

### Installing Packages

```bash
# Install storage server
dpkg -i build/packages/beegfs/beegfs-server_7.4.10_amd64.deb

# Install client software
dpkg -i build/packages/beegfs/beegfs-client_7.4.10_amd64.deb

# Install admin tools
dpkg -i build/packages/beegfs/beegfs-admon_7.4.10_amd64.deb
```

### Configuration Files

BeeGFS configuration is managed through text-based config files:

**Server Configuration** (`/etc/beegfs/beegfs-server.conf`):

```bash
# Example: Configure storage server
sysMgmtdHost = 192.168.1.10          # Management node IP
storeStorageDirectory = /mnt/beegfs  # Storage location
connInterfaceFile = /etc/beegfs/connInterfaceFile.conf
```

**Client Mount** (`/etc/beegfs/beegfs-client.conf`):

```bash
# Example: Configure client mount
sysMgmtdHost = 192.168.1.10
connInterfaceFile = /etc/beegfs/connInterfaceFile.conf
```

## Integration with Packer Images

BeeGFS packages are integrated into Packer images through:

1. **Build Stage**: CMake target builds packages during image preparation
2. **Package Cache**: Packages stored in build directory
3. **Ansible Provisioning**: Playbooks copy and install packages on target VMs

See `packer/README.md` and `ansible/README.md` for integration details.

## Performance Optimization

### Build Optimization

- **Parallel Compilation**: Use multiple CPU cores during build

  ```bash
  export MAKEFLAGS=-j$(nproc)  # Use all available CPU cores
  ```

- **Incremental Builds**: CMake caches build artifacts for faster rebuilds

### Runtime Optimization

- **Network Optimization**: Configure network interfaces for optimal throughput
- **Storage Tuning**: Adjust BeeGFS parameters for storage device characteristics
- **Client Caching**: Enable client-side caching for read-heavy workloads

## Troubleshooting

### Build Fails with Missing Dependencies

**Error**: "Package xxx-dev not found"

**Solution**:

```bash
# Install missing dependencies
apt-get update
apt-get install -y build-essential libevent-dev pkg-config zlib1g-dev

# Re-run build
cmake --build build --target build-beegfs-packages
```

### Download Failures

**Error**: "Failed to download BeeGFS source"

**Solution**:

```bash
# Manually download and place in build directory
cd 3rd-party/beegfs
wget https://www.beegfs.io/release/beegfs_7.4.10/source/beegfs-7.4.10.tar.gz

# Re-run build
cmake --build build --target build-beegfs-packages
```

### Compilation Errors

**Error**: "gcc: error: ...compilation terminated"

**Solution**:

```bash
# Check build log for specific errors
cat build/3rd-party/beegfs/beegfs-7.4.10/build.log | grep -i error

# Common cause: Kernel headers missing (if building kernel modules)
# For pre-built packages, this is not required
```

## Security Updates

### Updating to New BeeGFS Version

1. **Check Latest Version**: Visit https://www.beegfs.io/release/
2. **Update CMake Configuration**: Modify `BEEGFS_VERSION` variable
3. **Rebuild Packages**: Run build command
4. **Test in Non-Production**: Verify packages work before production deployment
5. **Update Ansible Playbooks**: Reference new package versions

### Security Considerations

- Verify package checksums from official BeeGFS release
- Review security advisories at https://www.beegfs.io/wiki/
- Keep packages synchronized with kernel version (for DKMS modules)
- Test network security settings (firewall, VLAN isolation)

## Customization Guide

### Patching BeeGFS Source

If modifications to BeeGFS source are needed:

1. **Extract Source**: After download, extract tarball to `build/3rd-party/beegfs/`
2. **Apply Patches**: Use `patch` command or manual editing
3. **Rebuild**: Run CMake build target
4. **Document Changes**: Add notes to this file about modifications

Example:

```bash
cd build/3rd-party/beegfs/beegfs-7.4.10
patch -p1 < /path/to/custom.patch
cd ../../../
cmake --build build --target build-beegfs-packages
```

### Adding Custom Modules

To include custom kernel modules or extensions:

1. Modify `CMakeLists.txt` in `3rd-party/beegfs/` directory
2. Add custom build steps before packaging
3. Ensure custom code is licensed appropriately
4. Document new build parameters

## Testing Built Packages

### Verify Package Contents

```bash
# List package contents
dpkg -c build/packages/beegfs/beegfs-client_7.4.10_amd64.deb | head -20

# View package metadata
dpkg-deb -I build/packages/beegfs/beegfs-client_7.4.10_amd64.deb
```

### Test Installation

```bash
# In a test VM or container
dpkg -i build/packages/beegfs/beegfs-client_7.4.10_amd64.deb

# Verify installation
beegfs-ctl --help
```

## Related Documentation

- **Build System Architecture**: `docs/architecture/build-system.md`
- **Dependency Management**: `3rd-party/dependency-management.md`
- **Custom Builds Guide**: `3rd-party/custom-builds.md`
- **Packer Images**: `packer/README.md`
- **Ansible Roles**: `ansible/README.md`

## Version Information

- **Current Version**: 7.4.10
- **Release Date**: January 2024
- **Architecture**: amd64
- **Target Distribution**: Debian/Ubuntu (Trixie/Jammy)

## References

- [BeeGFS Official Website](https://www.beegfs.io/)
- [BeeGFS Installation Guide](https://www.beegfs.io/wiki/Debian)
- [BeeGFS Administration Guide](https://www.beegfs.io/wiki/Administration)
