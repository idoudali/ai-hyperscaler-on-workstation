# Custom Builds and Modifications Guide

**Status:** Production
**Created:** 2025-10-24
**Last Updated:** 2025-10-24

## Overview

This guide explains how to customize third-party components, apply patches, and build modified
versions of BeeGFS, SLURM, and other dependencies.

## General Customization Workflow

### Step 1: Prepare Build Environment

Ensure your build environment has all dependencies:

```bash
# Update package lists
apt-get update

# Install build tools
apt-get install -y build-essential fakeroot devscripts equivs \
  pkg-config wget curl git patch

# For Docker builds (recommended)
make build-docker
```

### Step 2: Extract Source

```bash
# Download and extract if not already present
cd 3rd-party/<component>
wget <source-url>  # e.g., BeeGFS, SLURM tarball
tar -xzf <tarball>  # or tar -xjf for .tar.bz2

# Navigate to extracted directory
cd <component-version>
```

### Step 3: Apply Modifications

Make your changes using one of the following methods:

1. **Direct Editing**: Edit source files directly
2. **Patch Files**: Apply .patch files with `patch` command
3. **CMake Configuration**: Modify `CMakeLists.txt` for build options

### Step 4: Rebuild

```bash
# From project root
cmake --build build --target build-<component>-packages

# Or full rebuild if major changes
rm -rf build && make build-docker && cmake --build build --target build-<component>-packages
```

### Step 5: Test and Validate

Run comprehensive tests before deploying:

```bash
# Install in test environment
dpkg -i build/packages/<component>/*.deb

# Run component tests
<component>-<command> --version

# Verify functionality
# [Component-specific verification]
```

## BeeGFS Customization

### Common Customizations

#### 1. Build with InfiniBand Support

To add InfiniBand (RDMA) transport support:

```bash
cd build/3rd-party/beegfs/beegfs-7.4.10

# Modify CMakeLists.txt or build script
# Add: -DBEEGFS_ENABLE_IB=ON

# Or manually configure
./configure --enable-infiniband

# Rebuild
cmake --build build --target build-beegfs-packages
```

#### 2. Enable Advanced Caching

For environments with high memory availability:

```bash
cd build/3rd-party/beegfs/beegfs-7.4.10

# Edit configuration headers
# Increase cache buffer sizes
# Modify: #define CACHE_BUFFER_SIZE

cmake --build build --target build-beegfs-packages
```

#### 3. Custom Metadata Server Configuration

To tune metadata server for specific workloads:

```bash
# After installation, edit:
/etc/beegfs/beegfs-meta.conf

# Key parameters:
tuneNumWorkers=12              # Worker threads
tuneNumNetStripes=4            # Network parallelism
tuneNumBuddyResyncThreads=4   # Resync threads
```

#### 4. Add Custom Performance Patches

If upstream hasn't released a needed fix:

```bash
cd build/3rd-party/beegfs/beegfs-7.4.10

# Create patch file
git diff > /tmp/custom-optimization.patch

# Or download from external source
wget https://github.com/beegfs/beegfs/pull/xyz.patch

# Apply patch
patch -p1 < /tmp/custom-optimization.patch

# Rebuild
cmake --build build --target build-beegfs-packages
```

### Creating BeeGFS Patch Files

To create your own patches for sharing:

```bash
cd build/3rd-party/beegfs/beegfs-7.4.10

# Make your modifications
vim src/components/storage/StorageDirectory.cpp

# Create patch file
git diff > /tmp/beegfs-custom.patch

# View patch
cat /tmp/beegfs-custom.patch

# Store for future use
cp /tmp/beegfs-custom.patch 3rd-party/beegfs/patches/custom-optimization.patch
```

## SLURM Customization

### Common Customizations

#### 1. Build with Advanced GPU Support

To add advanced GPU features:

```bash
cd build/3rd-party/slurm/slurm-24.11.0

# Modify configure options
./configure \
  --prefix=/usr \
  --enable-nvml \
  --enable-gpu-autodetect \
  --with-nvidia-libs=/usr/lib/x86_64-linux-gnu

# Rebuild packages
cmake --build build --target build-slurm-packages
```

#### 2. Enable Advanced Accounting

For detailed job accounting and auditing:

```bash
cd build/3rd-party/slurm/slurm-24.11.0

./configure \
  --prefix=/usr \
  --with-mariadb_config=/usr/bin/mariadb_config \
  --enable-slurmctld-debug \
  --enable-accounting

cmake --build build --target build-slurm-packages
```

#### 3. Add Custom Job Scheduling Plugin

To integrate custom scheduling logic:

```bash
cd build/3rd-party/slurm/slurm-24.11.0

# Create custom plugin directory
mkdir -p contribs/my_plugin

# Implement plugin interface
# See: https://slurm.schedmd.com/plugin_sched.html

# Include in build
./configure --with-pmix=/usr --enable-plugins=my_plugin

cmake --build build --target build-slurm-packages
```

#### 4. Performance Tuning Patches

For SLURM performance optimization:

```bash
cd build/3rd-party/slurm/slurm-24.11.0

# Apply official patches from SchedMD
wget https://github.com/SchedMD/slurm/commit/abc123.patch
patch -p1 < abc123.patch

cmake --build build --target build-slurm-packages
```

### Creating SLURM Patch Files

```bash
cd build/3rd-party/slurm/slurm-24.11.0

# Make your modifications to scheduler or config
vim src/slurmctld/proc_mgr.c

# Create patch for distribution
git diff > /tmp/slurm-custom.patch

# Apply to fresh source
cd /tmp
tar -xjf slurm-24.11.0.tar.bz2
cd slurm-24.11.0
patch -p1 < /tmp/slurm-custom.patch
```

## Python Package Customization

### Installing Forked/Modified Packages

When a Python package needs modifications:

```toml
# In python/ai_how/pyproject.toml

[project.optional-dependencies]
dev = [
    # Use forked version with custom patches
    {git = "https://github.com/myorg/pytest-fork.git", rev = "custom-branch"},
    # Use local development version
    "pytest @ file:///path/to/local/pytest",
]
```

### Local Development Without Installation

For quick testing of modifications:

```bash
# Use editable install
cd /path/to/modified/package
pip install -e .

# Or in the project directory
cd python/ai_how
uv pip install -e /path/to/modified/package
```

## Integrated Build Modifications

### Modifying CMakeLists.txt

To customize how components are built:

```cmake
# In 3rd-party/CMakeLists.txt

# Add custom compilation flags
add_compile_options(-march=native -O3)

# Enable specific features
set(BEEGFS_ENABLE_RDMA ON)
set(SLURM_ENABLE_GPU ON)

# Customize installation paths
set(INSTALL_PREFIX /opt/custom)
```

### Custom Build Targets

Create reusable build targets for your customizations:

```cmake
# Add custom target
add_custom_target(build-custom-slurm
  COMMAND cmake --build ${CMAKE_BINARY_DIR} --target build-slurm-packages
  COMMAND cmake --build ${CMAKE_BINARY_DIR} --target apply-slurm-patches
  COMMAND ${CMAKE_COMMAND} -E echo "Custom SLURM build complete"
)
```

## Container-Based Customization

### Docker Build with Custom Changes

```dockerfile
# In docker/Dockerfile

# After base image setup
RUN apt-get update && apt-get install -y build-essential

# Copy custom patches
COPY 3rd-party/patches/ /src/patches/

# Build with patches
WORKDIR /src/3rd-party/beegfs
RUN patch -p1 < /src/patches/custom-optimization.patch && \
    cmake --build /build --target build-beegfs-packages
```

### Using Docker for Isolated Builds

```bash
# Build only in Docker, not on host
make run-docker COMMAND="cd 3rd-party/beegfs && \
  patch -p1 < patches/custom.patch && \
  cmake --build /build --target build-beegfs-packages"
```

## Testing Custom Builds

### Unit Tests

```bash
# BeeGFS tests
cd build/3rd-party/beegfs/beegfs-7.4.10
make check  # if available

# SLURM tests
cd build/3rd-party/slurm/slurm-24.11.0
make -j 4   # Parallel build and test
```

### Integration Tests

```bash
# Install in test environment
dpkg -i build/packages/<component>/*.deb

# Verify against test infrastructure
make test-slurm-controller
make test-beegfs-integration
```

### Performance Benchmarks

```bash
# For BeeGFS
beegfs-ctl --getentryinfo /mnt/beegfs
# Measure throughput and latency

# For SLURM
sinfo  # Check cluster status
sbatch --benchmark /path/to/test/job.sh  # Submit benchmark job
```

## Patch Management

### Organizing Patches

```bash
3rd-party/
├── beegfs/
│   └── patches/
│       ├── 0001-performance.patch
│       ├── 0002-gpu-support.patch
│       └── README.md  # Document each patch
├── slurm/
│   └── patches/
│       ├── 0001-accounting.patch
│       └── README.md
```

### Patch Numbering Convention

```bash
0001-short-description.patch   # First patch
0002-another-fix.patch         # Second patch
0099-experimental.patch        # Not applied by default
```

### Patch Application Order

Document the order patches should be applied:

```bash
# In 3rd-party/<component>/patches/README.md

1. 0001-performance.patch - Improves I/O throughput
2. 0002-gpu-support.patch - Adds GPU detection (depends on 0001)
3. 0003-security-fix.patch - Fixes CVE-XXXX (independent)
```

## Rollback Procedures

### Reverting to Unmodified Build

```bash
# Clean all artifacts
rm -rf build/

# Rebuild without patches
# (Patches are not applied automatically)
cmake --build build --target build-beegfs-packages
```

### Removing a Specific Patch

```bash
cd build/3rd-party/beegfs/beegfs-7.4.10

# Reverse the patch
patch -R -p1 < /path/to/problematic.patch

# Rebuild
cmake --build build --target build-beegfs-packages
```

## Documentation Requirements

When creating custom builds:

1. **Document Purpose**: Why is this customization needed?
2. **Note Impact**: What functionality does it affect?
3. **List Dependencies**: Does it require other changes?
4. **Provide Instructions**: How should others apply it?
5. **Include Tests**: How to verify it works?

### Custom Build Documentation Template

```markdown
# Custom: [Brief Description]

## Purpose

[Why this customization is needed]

## Changes Made

- [List of modifications]

## Impact

- [Affected components]
- [Performance implications]
- [Compatibility notes]

## Dependencies

- [Required patches]
- [Required system packages]

## Testing

[How to verify the customization works]

## Known Issues

[Any limitations or edge cases]

## Maintainer

[Who maintains this patch]
```

## Upstream Contribution

### Contributing Patches Back

If your customization is valuable for others:

1. **Clean up patch**: Remove debugging code, ensure quality
2. **Document thoroughly**: Explain rationale and benefits
3. **Test extensively**: Verify on multiple configurations
4. **Submit to upstream**: Create pull request with project
5. **Update locally**: Once merged, use official release

### Submitting to BeeGFS

1. Visit https://github.com/beegfs/beegfs/
2. Fork repository
3. Apply changes and commit
4. Create pull request with clear description
5. Engage with maintainers on feedback

### Submitting to SLURM

1. Visit https://github.com/SchedMD/slurm/
2. Review contribution guidelines
3. Create bugzilla account for formal submission
4. Submit patch with detailed description
5. Work with SLURM development team

## Related Documentation

- **Dependency Management**: `3rd-party/DEPENDENCY-MANAGEMENT.md`
- **BeeGFS Build**: `3rd-party/beegfs/README.md`
- **SLURM Build**: `3rd-party/slurm/README.md`
- **Build System**: `docs/architecture/build-system.md`
- **Docker Environment**: `docker/README.md`

## Troubleshooting Custom Builds

### Patch Fails to Apply

```bash
# Check patch context
patch -p1 --dry-run < custom.patch

# If not applicable, check line endings
dos2unix source_file

# Try different patch level
patch -p0 < custom.patch  # Or -p2, -p3
```

### Build Fails After Modifications

```bash
# Check build log
tail -100 build/build.log

# Clean and rebuild
rm -rf build
cmake -S . -B build
cmake --build build --target build-<component>-packages
```

### Package Installation Issues

```bash
# Check dependencies
dpkg-deb -I build/packages/<component>/*.deb

# Install with dependencies
apt-get install -y ./build/packages/<component>/*.deb

# Check installation
dpkg -l | grep <component>
```

## Best Practices

1. **Keep Patches Minimal**: Only change what's necessary
2. **Document Everything**: Future you will thank present you
3. **Test Thoroughly**: Custom builds have unique risks
4. **Version Control**: Track patches in git
5. **Plan for Updates**: How will you handle upstream updates?
6. **Contribute Back**: Share improvements with community
7. **Separate Concerns**: Different patches for different purposes
8. **Use Conditionals**: CMake conditionals for optional features
