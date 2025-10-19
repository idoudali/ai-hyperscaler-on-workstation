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
set(SLURM_DOWNLOAD_URL "https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2" CACHE STRING "SLURM download URL")
set(SLURM_TARBALL_SHA256 "39ebeeeeb5d874e090b7f2629bd319bfe7c41510931ff2244f85e961bdc69056" CACHE STRING "SHA256 checksum of SLURM tarball")

# Build directories
set(SLURM_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/slurm-${SLURM_VERSION}")
set(SLURM_PACKAGE_DIR "${CMAKE_BINARY_DIR}/packages/slurm")
set(SLURM_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/slurm-build")

# Download SLURM source tarball
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/slurm-${SLURM_VERSION}.tar.bz2
    COMMAND wget -O ${CMAKE_CURRENT_BINARY_DIR}/slurm-${SLURM_VERSION}.tar.bz2
        ${SLURM_DOWNLOAD_URL}
    COMMAND echo "${SLURM_TARBALL_SHA256}  ${CMAKE_CURRENT_BINARY_DIR}/slurm-${SLURM_VERSION}.tar.bz2" > ${CMAKE_CURRENT_BINARY_DIR}/slurm-${SLURM_VERSION}.tar.bz2.sha256
    COMMAND sha256sum -c ${CMAKE_CURRENT_BINARY_DIR}/slurm-${SLURM_VERSION}.tar.bz2.sha256
    COMMENT "Downloading and verifying SLURM ${SLURM_VERSION} source tarball..."
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
    COMMENT "Building SLURM ${SLURM_VERSION} Debian packages using dpkg-buildpackage (using ${PARALLEL_JOBS} parallel jobs, this may take 10-15 minutes)..."
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
