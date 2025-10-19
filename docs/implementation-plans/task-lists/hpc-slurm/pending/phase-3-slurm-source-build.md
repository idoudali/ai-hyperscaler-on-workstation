# Phase 3: SLURM Source Package Build (Task 028.2)

**Status**: Pending  
**Last Updated**: 2025-10-19  
**Priority**: HIGH  
**Tasks**: 1

## Overview

Critical bug fix to resolve missing SLURM packages in Debian Trixie repositories. Build SLURM Debian packages from
source following the official SchedMD quickstart guide, similar to the BeeGFS package build infrastructure.

---

- **ID**: TASK-028.2
- **Phase**: 3 - Infrastructure Enhancements
- **Dependencies**: TASK-010.2 (SLURM Controller Installation)
- **Estimated Time**: 8 hours
- **Difficulty**: Advanced
- **Status**: Pending
- **Priority**: HIGH
- **Type**: Bug Fix / Infrastructure Improvement

**Description:** Build SLURM Debian packages from source following the official SchedMD quickstart administrator guide.
Create CMake-based build infrastructure under `3rd-party/slurm/` to automate package building from source, similar to
the existing BeeGFS build system.

**Problem Statement:**

SLURM packages are missing or incomplete in Debian Trixie repositories, preventing proper installation:

```text
Root Cause: Missing SLURM packages in Debian Trixie

Package Issues:
- slurm-wlm packages unavailable or outdated in trixie
- Missing dependencies for slurmdbd and slurm-client
- PMIx integration libraries missing or incompatible
- MariaDB integration packages incomplete

Impact:
- ❌ Cannot install SLURM from Debian repositories
- ❌ HPC controller image build fails during Ansible provisioning
- ❌ Compute node deployment blocked
- ❌ Job accounting and scheduling unavailable
- ❌ Complete HPC cluster deployment blocked
```

**Current Workaround:**

No workaround currently available - SLURM installation is completely blocked.

**Deliverables:**

- `3rd-party/slurm/CMakeLists.txt` - CMake build configuration for SLURM packages
- `3rd-party/slurm/README.md` - Documentation for SLURM package building
- `3rd-party/CMakeLists.txt` - Updated to include SLURM subdirectory
- Built SLURM Debian packages in `build/packages/slurm/`:
  - `slurm-wlm_*.deb` - Core SLURM workload manager
  - `slurm-wlm-doc_*.deb` - Documentation
  - `slurmdbd_*.deb` - Database daemon for accounting
  - `slurm-client_*.deb` - Client tools
  - `libslurm*.deb` - SLURM libraries
  - `slurm-wlm-basic-plugins_*.deb` - Basic plugins
- Updated Ansible roles to use pre-built packages (handled in Phase 4)

**Proposed Solution: Build from Source Following SchedMD Guide**

Build SLURM Debian packages from source following the official quickstart guide at
https://slurm.schedmd.com/quickstart_admin.html#pkg_install

**Implementation Steps:**

### 1. Create SLURM CMake Build Infrastructure

**File:** `3rd-party/slurm/CMakeLists.txt`

```cmake
# SLURM Package Build Configuration
cmake_minimum_required(VERSION 3.18)

# Get processor count for parallel builds
include(ProcessorCount)
ProcessorCount(N_CORES)
if(NOT N_CORES EQUAL 0)
    set(PARALLEL_JOBS ${N_CORES})
else()
    set(PARALLEL_JOBS 4)
endif()

# SLURM version configuration
set(SLURM_VERSION "24.11.0" CACHE STRING "SLURM version to build")
set(SLURM_MAJOR_MINOR "24.11")
set(SLURM_DOWNLOAD_URL "https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2" CACHE STRING "SLURM download URL")

# Build directories
set(SLURM_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/slurm-${SLURM_VERSION}")
set(SLURM_PACKAGE_DIR "${CMAKE_BINARY_DIR}/packages/slurm")
set(SLURM_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/slurm-build")

# Download SLURM source tarball
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/slurm-${SLURM_VERSION}.tar.bz2
    COMMAND wget -O ${CMAKE_CURRENT_BINARY_DIR}/slurm-${SLURM_VERSION}.tar.bz2
        ${SLURM_DOWNLOAD_URL}
    COMMENT "Downloading SLURM ${SLURM_VERSION} source tarball..."
    VERBATIM
)

add_custom_target(download-slurm-source
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/slurm-${SLURM_VERSION}.tar.bz2
)

# Extract SLURM source
add_custom_command(
    OUTPUT ${SLURM_SOURCE_DIR}/configure
    COMMAND rm -rf ${SLURM_SOURCE_DIR}
    COMMAND tar xjf ${CMAKE_CURRENT_BINARY_DIR}/slurm-${SLURM_VERSION}.tar.bz2
        -C ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS download-slurm-source
    COMMENT "Extracting SLURM ${SLURM_VERSION} source..."
    VERBATIM
)

add_custom_target(extract-slurm-source
    DEPENDS ${SLURM_SOURCE_DIR}/configure
)

# Build SLURM Debian packages using official method
# Following: https://slurm.schedmd.com/quickstart_admin.html#debuild
add_custom_command(
    OUTPUT ${SLURM_PACKAGE_DIR}/.build-complete
    COMMAND rm -rf ${SLURM_PACKAGE_DIR}
    COMMAND mkdir -p ${SLURM_PACKAGE_DIR}
    # Clean any previous build state to avoid "source directory already configured" error
    COMMAND cd ${SLURM_SOURCE_DIR} && make distclean || true
    COMMAND cd ${SLURM_SOURCE_DIR} && rm -rf obj-x86_64-linux-gnu || true
    # Build Debian packages using the official SLURM debian/ directory
    # This creates multiple packages: slurm-smd, slurm-smd-client, slurm-smd-slurmd, etc.
    # Build dependencies are pre-installed in the Docker image
    # GPU Support: SLURM 24.11+ includes built-in AutoDetect=nvidia (no libraries required)
    # See: https://slurm.schedmd.com/gres.conf.html#OPT_AutoDetect
    COMMAND cd ${SLURM_SOURCE_DIR} &&
        dpkg-buildpackage -us -uc -b -j${PARALLEL_JOBS}
    # Move generated .deb packages to output directory (dpkg-buildpackage creates them in parent dir)
    COMMAND bash -c "mv ${CMAKE_CURRENT_BINARY_DIR}/*.deb ${SLURM_PACKAGE_DIR}/ 2>/dev/null || true"
    COMMAND ${CMAKE_COMMAND} -E touch ${SLURM_PACKAGE_DIR}/.build-complete
    DEPENDS ${SLURM_SOURCE_DIR}/configure
    COMMENT "Building SLURM ${SLURM_VERSION} Debian packages using dpkg-buildpackage (using ${PARALLEL_JOBS} 
        parallel jobs, this may take 10-15 minutes)..."
    USES_TERMINAL
    VERBATIM
)

add_custom_target(build-slurm-packages
    DEPENDS ${SLURM_PACKAGE_DIR}/.build-complete
)

# List built packages
add_custom_target(list-slurm-packages
    COMMAND ${CMAKE_COMMAND} -E echo "SLURM packages built in: ${SLURM_PACKAGE_DIR}"
    COMMAND ls -lh ${SLURM_PACKAGE_DIR}/*.deb || echo "No packages found yet. Run 'build-slurm-packages' first."
    DEPENDS build-slurm-packages
    VERBATIM
)

# Clean SLURM build artifacts
add_custom_target(clean-slurm
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${SLURM_SOURCE_DIR}
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${SLURM_PACKAGE_DIR}
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${SLURM_BUILD_DIR}
    COMMAND ${CMAKE_COMMAND} -E rm -f ${CMAKE_CURRENT_BINARY_DIR}/slurm-${SLURM_VERSION}.tar.bz2
    COMMENT "Cleaning SLURM build artifacts..."
    VERBATIM
)

# Add informational target
add_custom_target(help-slurm
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
    COMMAND ${CMAKE_COMMAND} -E echo "  SLURM Package Build Targets"
    COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Available targets:"
    COMMAND ${CMAKE_COMMAND} -E echo "  build-slurm-packages   - Build all SLURM Debian packages"
    COMMAND ${CMAKE_COMMAND} -E echo "  list-slurm-packages    - List built SLURM packages"
    COMMAND ${CMAKE_COMMAND} -E echo "  clean-slurm           - Clean SLURM build artifacts"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Configuration:"
    COMMAND ${CMAKE_COMMAND} -E echo "  Version:        ${SLURM_VERSION}"
    COMMAND ${CMAKE_COMMAND} -E echo "  Source Dir:     ${SLURM_SOURCE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E echo "  Package Dir:    ${SLURM_PACKAGE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Usage:"
    COMMAND ${CMAKE_COMMAND} -E echo "  cmake --build build --target build-slurm-packages"
    COMMAND ${CMAKE_COMMAND} -E echo "  make run-docker COMMAND=\"cmake --build build --target build-slurm-packages\""
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Official Guide:"
    COMMAND ${CMAKE_COMMAND} -E echo "  https://slurm.schedmd.com/quickstart_admin.html#pkg_install"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    VERBATIM
)

# Install packages to a staging directory (optional, for testing)
install(
    DIRECTORY ${SLURM_PACKAGE_DIR}/
    DESTINATION share/slurm-packages
    OPTIONAL
    FILES_MATCHING PATTERN "*.deb"
)
```

### 2. Update 3rd-party CMakeLists.txt

**File:** `3rd-party/CMakeLists.txt`

```cmake
# Add SLURM subdirectory
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/slurm/CMakeLists.txt")
    add_subdirectory(slurm)
    message(STATUS "SLURM package build enabled")
else()
    message(STATUS "SLURM package build directory not found (optional)")
endif()
```

### 3. Create SLURM Build Documentation

**File:** `3rd-party/slurm/README.md`

```markdown
# SLURM Package Build from Source

This directory contains CMake configuration to build SLURM Debian packages from source following the official
SchedMD quickstart administrator guide.

## Overview

SLURM packages are missing or incomplete in Debian Trixie repositories. This build system creates Debian packages
from source to enable HPC cluster deployment.

## Prerequisites

Required build dependencies (must be pre-installed in Docker image before building):

**Core Build Tools:**

- build-essential
- fakeroot
- devscripts
- equivs
- wget

**SLURM Dependencies:**

These development libraries are installed in the Dockerfile and are required by `dpkg-buildpackage`:

- libmunge-dev - MUNGE authentication
- libmariadb-dev - MariaDB/MySQL database support
- default-libmysqlclient-dev - MySQL client development files
- libpmix-dev - PMIx MPI integration
- libpam0g-dev - PAM authentication
- libhwloc-dev - Hardware topology support
- liblua5.3-dev - Lua scripting support
- libjson-c-dev - JSON output support
- libhttp-parser-dev - HTTP parser for REST API
- libyaml-dev - YAML configuration support
- libreadline-dev - Interactive command support
- libncurses-dev - Terminal UI support

**Note:** The CMake build does not install these dependencies. They must be pre-installed in the Docker development
image. The `dpkg-buildpackage` command expects these build dependencies to already be present in the environment.

**GPU Autodetection Support:**

SLURM 24.11+ includes built-in `AutoDetect=nvidia` functionality that requires **no additional libraries**!

Reference: [SLURM GRES AutoDetect Documentation](https://slurm.schedmd.com/gres.conf.html#OPT_AutoDetect)

**Built-in AutoDetect Options:**

- ✅ `AutoDetect=nvidia` - **ENABLED** - Built-in NVIDIA GPU detection (no libraries required)
  - Automatically detects NVIDIA GPUs
  - Does not support MIG or NVLink detection
  - Added in SLURM 24.11 - no prerequisites needed

**Advanced GPU Detection (Optional - Requires External Libraries):**

- `AutoDetect=nvml` - Advanced NVIDIA detection with MIG/NVLink support (requires libnvidia-ml-dev)
- `AutoDetect=rsmi` - AMD GPU detection (requires ROCm libraries)
- `AutoDetect=oneapi` - Intel GPU detection (requires oneAPI runtime)

**Note:** GPU autodetection is configured via `gres.conf`, not at build time. The SLURM packages support all
AutoDetect modes; choose which to use when configuring compute nodes.

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

The build uses `dpkg-buildpackage` (not `dpkg-deb`) which leverages the official SLURM `debian/` directory
from the source tarball to generate multiple SchedMD-format packages:

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

**Note:** Package names follow SchedMD convention with `slurm-smd` prefix (not `slurm-wlm`).
The official `debian/` directory in the SLURM source defines the package split and naming.

## Configuration Options

Customize the build by setting CMake variables:

```bash
cmake -G Ninja -S . -B build \
  -DSLURM_VERSION=24.11.0 \
  -DSLURM_DOWNLOAD_URL=https://download.schedmd.com/slurm/slurm-24.11.0.tar.bz2
```

## Build Time

Expected build time: 10-15 minutes (depending on system performance)

## Ansible Integration

After building packages, Ansible roles will be updated to install from the pre-built packages (see Phase 4).

## Cleaning Build Artifacts

```bash
# Clean SLURM build artifacts only
cmake --build build --target clean-slurm

# Full clean (all build artifacts)
rm -rf build/
```

## Official Documentation

- [SLURM Quick Start Administrator Guide](https://slurm.schedmd.com/quickstart_admin.html#pkg_install)
- [Building RPM Packages](https://slurm.schedmd.com/quickstart_admin.html#building-rpms)
- [Building Debian Packages](https://slurm.schedmd.com/quickstart_admin.html#building-debian-packages)

## Troubleshooting

### Missing Dependencies

If build fails due to missing dependencies, ensure they are pre-installed in the Docker image.

The `dpkg-buildpackage` process requires build dependencies to be present before execution:

```bash
# These dependencies must be pre-installed in the Dockerfile
# The CMake build system does NOT install these automatically
apt-get update
apt-get install -y build-essential fakeroot devscripts equivs \
  libmunge-dev libmariadb-dev libpmix-dev libpam0g-dev \
  libhwloc-dev liblua5.3-dev libjson-c-dev libhttp-parser-dev \
  libyaml-dev libcurl4-openssl-dev libssl-dev
```

### Download Failures

If download fails, manually download and place in `3rd-party/slurm/`:

```bash
cd 3rd-party/slurm
wget https://download.schedmd.com/slurm/slurm-24.11.0.tar.bz2
```

### PMIx Integration Issues

Ensure PMIx development libraries are installed:

```bash
apt-get install -y libpmix2 libpmix-dev
```

## Version Information

- **Current Version**: 24.11.0
- **Release Date**: 2024-11-19
- **Architecture**: amd64
- **Debian Target**: Trixie (Debian 13)
- **SLURM Major.Minor**: 24.11
- **New Features**: Built-in AutoDetect=nvidia (no libraries required)

### 4. Build and Test Packages

**Test Commands:**

```bash
# Configure CMake with SLURM build enabled
make config

# Build SLURM packages in development container
make run-docker COMMAND="cmake --build build --target build-slurm-packages"

# Verify packages created
ls -lh build/packages/slurm/

# Expected output (dpkg-buildpackage generates multiple SchedMD packages):
# slurm-smd_24.11.0_amd64.deb
# slurm-smd-client_24.11.0_amd64.deb
# slurm-smd-slurmd_24.11.0_amd64.deb
# slurm-smd-slurmctld_24.11.0_amd64.deb
# slurm-smd-slurmdbd_24.11.0_amd64.deb
# libslurm40_24.11.0_amd64.deb
# slurm-smd-doc_24.11.0_amd64.deb

# Test package installation (in a test VM)
dpkg -i build/packages/slurm/slurm-smd_24.11.0_amd64.deb \
        build/packages/slurm/slurm-smd-slurmctld_24.11.0_amd64.deb
slurmctld -V

# Verify package contents
dpkg -c build/packages/slurm/slurm-smd_24.11.0_amd64.deb | head -20
```

**Validation Criteria:**

- [ ] CMakeLists.txt created for SLURM package building
- [ ] README.md documentation complete
- [ ] SLURM source tarball downloads successfully
- [ ] Source extraction completes without errors
- [ ] Configure script runs with PMIx and MariaDB support
- [ ] SLURM compiles successfully (make completes)
- [ ] Debian packages created in `build/packages/slurm/`
- [ ] Packages install without dependency errors
- [ ] slurmctld binary executes and shows version
- [ ] PMIx integration libraries linked correctly
- [ ] MariaDB client libraries present in packages

**Success Criteria:**

- ✅ All SLURM Debian packages build successfully
- ✅ Packages contain required binaries (slurmctld, slurmdbd, srun, etc.)
- ✅ PMIx integration configured and functional
- ✅ MariaDB/MySQL client libraries linked
- ✅ MUNGE authentication support included
- ✅ PAM module included for node access control
- ✅ Systemd service files present in packages
- ✅ Configuration files in proper locations (/etc/slurm/)
- ✅ Build completes in under 20 minutes
- ✅ Packages install cleanly on Debian Trixie

**SLURM Configure Options (from SchedMD Guide):**

Following https://slurm.schedmd.com/quickstart_admin.html#pkg_install

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

**Key Configuration Options:**

- `--prefix=/usr` - Install in standard system location
- `--sysconfdir=/etc/slurm` - Configuration files location
- `--with-pmix=/usr/lib/x86_64-linux-gnu/pmix2` - PMIx integration for MPI support (Debian-specific path)
- `--with-mariadb_config=/usr/bin/mariadb_config` - MariaDB for job accounting
- `--enable-pam` - PAM module for node access control
- `--enable-multiple-slurmd` - Support multiple slurmd on single host (for testing)
- `--with-munge=/usr` - MUNGE authentication
- `--with-systemdsystemunitdir=/lib/systemd/system` - Systemd integration

**Auto-Detected Features (via pkg-config):**

The following libraries are automatically detected and enabled if present:

- hwloc - Hardware topology support
- json-c - JSON output support
- lua5.3 - Lua scripting support
- readline - Interactive command-line support
- ncurses - Terminal UI support
- http-parser - REST API support
- yaml - YAML configuration support

**Dependencies to Install Before Building:**

From SchedMD guide prerequisites:

```bash
apt-get install -y \
  build-essential \
  fakeroot \
  devscripts \
  equivs \
  libmunge-dev \
  libmariadb-dev \
  libpmix-dev \
  libpam0g-dev \
  libhwloc-dev \
  liblua5.3-dev \
  libjson-c-dev \
  libhttp-parser-dev \
  libyaml-dev \
  libcurl4-openssl-dev \
  libssl-dev
```

**Build Process (from SchedMD Guide):**

1. **Download Source:**

   ```bash
   wget https://download.schedmd.com/slurm/slurm-24.11.0.tar.bz2
   tar xjf slurm-24.11.0.tar.bz2
   cd slurm-24.11.0
   ```

2. **Configure:**

   ```bash
   ./configure <options>
   ```

3. **Build:**

   ```bash
   make -j$(nproc)
   make contrib
   make install DESTDIR=/tmp/slurm-install
   ```

4. **Create Debian Package:**

   ```bash
   fakeroot dpkg-deb --build /tmp/slurm-install .
   ```

**Files Modified:**

- `3rd-party/slurm/CMakeLists.txt` - New file (150 lines)
- `3rd-party/slurm/README.md` - New file (150 lines)
- `3rd-party/CMakeLists.txt` - Updated to include slurm subdirectory

**Integration with Existing Build System:**

```bash
# Top-level Makefile already supports 3rd-party builds
make config                    # Configure CMake (includes 3rd-party)
make run-docker COMMAND="..."  # Run builds in dev container

# New targets available after this task:
cmake --build build --target build-slurm-packages
cmake --build build --target list-slurm-packages
cmake --build build --target clean-slurm
cmake --build build --target help-slurm
```

**Dependencies:**

- **Blocks**: Phase 4 consolidation tasks requiring SLURM installation
- **Blocked By**: None (can be executed immediately)
- **Related**: TASK-010.2 (SLURM Controller Installation) - will be updated in Phase 4

**Estimated Implementation Time:**

- CMakeLists.txt creation: 2 hours
- README.md documentation: 1 hour
- Build testing and validation: 3 hours
- Package verification: 1 hour
- Troubleshooting and fixes: 1 hour
- **Total**: 8 hours

**Notes:**

- **Immediate Action Required**: Missing SLURM packages block HPC cluster deployment
- **Follows SchedMD Official Guide**: Implementation based on official quickstart administrator guide
- **Similar to BeeGFS Build**: Uses same CMake pattern as existing BeeGFS package building
- **Phase 4 Integration**: Ansible roles will be updated to use these packages in Phase 4
- **Version Selection**: SLURM 24.11.0 chosen for latest features (AutoDetect=nvidia) and Debian Trixie compatibility
- **Build Container**: Uses existing dev container for consistent build environment

---

## Related Documentation

- [Official SLURM Quickstart Guide](https://slurm.schedmd.com/quickstart_admin.html#pkg_install)
- [Completed: TASK-010.2 - SLURM Controller Installation](../completed/phase-1-core-infrastructure.md)
- [Pending: Phase 4 - Consolidation](phase-4-consolidation.md) - SLURM installation fix

## Next Steps

After completion, proceed to Phase 4 Task 034.1 to update Ansible roles to use pre-built SLURM packages.
