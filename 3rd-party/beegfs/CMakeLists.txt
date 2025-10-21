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
set(BEEGFS_VERSION "8.1.0" CACHE STRING "BeeGFS version to build" FORCE)
set(BEEGFS_GIT_REPO "https://github.com/ThinkParQ/beegfs.git" CACHE STRING "BeeGFS Git repository URL")
set(BEEGFS_RUST_GIT_REPO "https://github.com/ThinkParQ/beegfs-rust.git" CACHE STRING "BeeGFS Rust repository URL")

# Build directories
set(BEEGFS_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/beegfs-src")
set(BEEGFS_RUST_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/beegfs-rust-src")
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

# Clone BeeGFS Rust source repository (Management service in BeeGFS 8.x)
# Note: beegfs-rust uses 'v' prefix for tags (e.g., v8.1.0)
add_custom_command(
    OUTPUT ${BEEGFS_RUST_SOURCE_DIR}/.git/config
    COMMAND rm -rf ${BEEGFS_RUST_SOURCE_DIR}
    COMMAND git clone ${BEEGFS_RUST_GIT_REPO} ${BEEGFS_RUST_SOURCE_DIR}
    COMMAND cd ${BEEGFS_RUST_SOURCE_DIR} && git checkout v${BEEGFS_VERSION}
    COMMENT "Cloning BeeGFS Rust source repository for Management service (version ${BEEGFS_VERSION})..."
)

add_custom_target(clone-beegfs-rust-source
    DEPENDS ${BEEGFS_RUST_SOURCE_DIR}/.git/config
)

# Build BeeGFS Debian packages (C/C++ components)
# Important: Remove PACKAGE_DIR before building (BeeGFS Makefile requires it to not exist)
add_custom_command(
    OUTPUT ${BEEGFS_PACKAGE_DIR}/.build-cpp-complete
    COMMAND rm -rf ${BEEGFS_PACKAGE_DIR}
    COMMAND make -C ${BEEGFS_SOURCE_DIR} package-deb
        PACKAGE_DIR=${BEEGFS_PACKAGE_DIR}
        DEBUILD_OPTS="-j${PARALLEL_JOBS}"
        BEEGFS_VERSION=${BEEGFS_VERSION}
    COMMAND ${CMAKE_COMMAND} -E touch ${BEEGFS_PACKAGE_DIR}/.build-cpp-complete
    DEPENDS clone-beegfs-source
    COMMENT "Building BeeGFS C/C++ Debian packages (version ${BEEGFS_VERSION}, using ${PARALLEL_JOBS} parallel jobs)..."
    USES_TERMINAL
    VERBATIM
)

add_custom_target(build-beegfs-cpp-packages
    DEPENDS ${BEEGFS_PACKAGE_DIR}/.build-cpp-complete
)

# Build BeeGFS Rust packages (Management service)
# Note: Uses custom build script (build-rust-packages.sh) that builds only Debian packages
# The script replicates the Debian packaging logic from the upstream Makefile:
# https://github.com/ThinkParQ/beegfs-rust/blob/main/Makefile
add_custom_command(
    OUTPUT ${BEEGFS_PACKAGE_DIR}/.build-rust-complete
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/build-rust-packages.sh
        ${BEEGFS_RUST_SOURCE_DIR}/target/package
        ${BEEGFS_VERSION}
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${BEEGFS_RUST_SOURCE_DIR}/target/package
        ${BEEGFS_PACKAGE_DIR}
    COMMAND ${CMAKE_COMMAND} -E touch ${BEEGFS_PACKAGE_DIR}/.build-rust-complete
    WORKING_DIRECTORY ${BEEGFS_RUST_SOURCE_DIR}
    DEPENDS clone-beegfs-rust-source build-beegfs-cpp-packages
    COMMENT "Building BeeGFS Rust Debian packages (Management service, version ${BEEGFS_VERSION})..."
    USES_TERMINAL
    VERBATIM
)

add_custom_target(build-beegfs-rust-packages
    DEPENDS ${BEEGFS_PACKAGE_DIR}/.build-rust-complete
)

# Build all BeeGFS packages (C/C++ + Rust)
add_custom_target(build-beegfs-packages
    DEPENDS build-beegfs-cpp-packages build-beegfs-rust-packages
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
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${BEEGFS_RUST_SOURCE_DIR}
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
    COMMAND ${CMAKE_COMMAND} -E echo "  build-beegfs-packages      - Build all BeeGFS Debian packages (C/C++ + Rust)"
    COMMAND ${CMAKE_COMMAND} -E echo "  build-beegfs-cpp-packages  - Build only C/C++ packages (meta, storage, client)"
    COMMAND ${CMAKE_COMMAND} -E echo "  build-beegfs-rust-packages - Build only Rust packages (management service)"
    COMMAND ${CMAKE_COMMAND} -E echo "  list-beegfs-packages       - List built BeeGFS packages"
    COMMAND ${CMAKE_COMMAND} -E echo "  clean-beegfs              - Clean BeeGFS build artifacts"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Configuration:"
    COMMAND ${CMAKE_COMMAND} -E echo "  Version:          ${BEEGFS_VERSION}"
    COMMAND ${CMAKE_COMMAND} -E echo "  C/C++ Source:     ${BEEGFS_SOURCE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E echo "  Rust Source:      ${BEEGFS_RUST_SOURCE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E echo "  Package Dir:      ${BEEGFS_PACKAGE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Note: BeeGFS 8.x split into multiple repos:"
    COMMAND ${CMAKE_COMMAND} -E echo "  - beegfs (C/C++): metadata, storage, client kernel module"
    COMMAND ${CMAKE_COMMAND} -E echo "  - beegfs-rust: management service (requires Rust toolchain)"
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
