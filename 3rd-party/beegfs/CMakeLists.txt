# BeeGFS Package Build Configuration
cmake_minimum_required(VERSION 3.18)

# Get processor count for parallel builds
include(ProcessorCount)
ProcessorCount(N_CORES)
if(NOT N_CORES EQUAL 0)
    set(PARALLEL_JOBS ${N_CORES})
else()
    set(PARALLEL_JOBS 4)
endif()

# BeeGFS version configuration
set(BEEGFS_VERSION "7.4.4" CACHE STRING "BeeGFS version to build")
set(BEEGFS_GIT_REPO "https://github.com/ThinkParQ/beegfs.git" CACHE STRING "BeeGFS Git repository URL")

# Build directories
set(BEEGFS_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/beegfs-src")
set(BEEGFS_PACKAGE_DIR "${CMAKE_BINARY_DIR}/packages/beegfs")

# Note: PACKAGE_DIR must NOT exist before running make package-deb
# BeeGFS Makefile will create it and fails if it already exists

# Clone BeeGFS source repository
add_custom_command(
    OUTPUT ${BEEGFS_SOURCE_DIR}/.git/config
    COMMAND rm -rf ${BEEGFS_SOURCE_DIR}
    COMMAND git clone ${BEEGFS_GIT_REPO} ${BEEGFS_SOURCE_DIR}
    COMMAND cd ${BEEGFS_SOURCE_DIR} && git checkout ${BEEGFS_VERSION}
    COMMENT "Cloning BeeGFS source repository (version ${BEEGFS_VERSION})..."
    VERBATIM
)

add_custom_target(clone-beegfs-source
    DEPENDS ${BEEGFS_SOURCE_DIR}/.git/config
)

# Build BeeGFS Debian packages
# Important: Remove PACKAGE_DIR before building (BeeGFS Makefile requires it to not exist)
add_custom_command(
    OUTPUT ${BEEGFS_PACKAGE_DIR}/.build-complete
    COMMAND rm -rf ${BEEGFS_PACKAGE_DIR}
    COMMAND make -C ${BEEGFS_SOURCE_DIR} package-deb
        PACKAGE_DIR=${BEEGFS_PACKAGE_DIR}
        DEBUILD_OPTS="-j${PARALLEL_JOBS}"
        BEEGFS_VERSION=${BEEGFS_VERSION}
    COMMAND ${CMAKE_COMMAND} -E touch ${BEEGFS_PACKAGE_DIR}/.build-complete
    DEPENDS clone-beegfs-source
    COMMENT "Building BeeGFS Debian packages (version ${BEEGFS_VERSION}, using ${PARALLEL_JOBS} parallel jobs, this may take 5-10 minutes)..."
    USES_TERMINAL
    VERBATIM
)

add_custom_target(build-beegfs-packages
    DEPENDS ${BEEGFS_PACKAGE_DIR}/.build-complete
)

# List built packages
add_custom_target(list-beegfs-packages
    COMMAND ${CMAKE_COMMAND} -E echo "BeeGFS packages built in: ${BEEGFS_PACKAGE_DIR}"
    COMMAND ls -lh ${BEEGFS_PACKAGE_DIR}/*.deb || echo "No packages found yet. Run 'build-beegfs-packages' first."
    DEPENDS build-beegfs-packages
    VERBATIM
)

# Clean BeeGFS build artifacts
add_custom_target(clean-beegfs
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${BEEGFS_SOURCE_DIR}
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${BEEGFS_PACKAGE_DIR}
    COMMENT "Cleaning BeeGFS build artifacts..."
    VERBATIM
)

# Add informational target
add_custom_target(help-beegfs
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
    COMMAND ${CMAKE_COMMAND} -E echo "  BeeGFS Package Build Targets"
    COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Available targets:"
    COMMAND ${CMAKE_COMMAND} -E echo "  build-beegfs-packages   - Build all BeeGFS Debian packages"
    COMMAND ${CMAKE_COMMAND} -E echo "  list-beegfs-packages    - List built BeeGFS packages"
    COMMAND ${CMAKE_COMMAND} -E echo "  clean-beegfs           - Clean BeeGFS build artifacts"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Configuration:"
    COMMAND ${CMAKE_COMMAND} -E echo "  Version:        ${BEEGFS_VERSION}"
    COMMAND ${CMAKE_COMMAND} -E echo "  Source Dir:     ${BEEGFS_SOURCE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E echo "  Package Dir:    ${BEEGFS_PACKAGE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Usage:"
    COMMAND ${CMAKE_COMMAND} -E echo "  cmake --build build --target build-beegfs-packages"
    COMMAND ${CMAKE_COMMAND} -E echo "  make run-docker COMMAND=\"cmake --build build --target build-beegfs-packages\""
    COMMAND ${CMAKE_COMMAND} -E echo ""
    VERBATIM
)

# Install packages to a staging directory (optional, for testing)
install(
    DIRECTORY ${BEEGFS_PACKAGE_DIR}/
    DESTINATION share/beegfs-packages
    OPTIONAL
    FILES_MATCHING PATTERN "*.deb"
)
