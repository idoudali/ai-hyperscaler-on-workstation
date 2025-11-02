# SLURM Job Examples CMake Configuration
# ======================================
#
# This CMakeLists.txt configures shared settings for all MPI example programs.
# Each example has its own CMakeLists.txt in its subdirectory.
#
# Available Targets:
#   - build-slurm-jobs: Build all SLURM job example binaries
#   - build-hello-world: Build hello-world MPI program
#   - build-pi-calculation: Build pi-calculation MPI program
#   - build-matrix-multiply: Build matrix-multiply MPI program

cmake_minimum_required(VERSION 3.18)

# Enable C language support for MPI programs
enable_language(C)

# Find MPI (required for all examples)
find_package(MPI REQUIRED COMPONENTS C)

if(NOT MPI_FOUND)
    message(FATAL_ERROR "MPI not found. Please install OpenMPI or MPICH development packages.")
endif()

message(STATUS "Found MPI: ${MPI_C_FOUND}")
message(STATUS "MPI C Compiler: ${MPI_C_COMPILER}")
message(STATUS "MPI C Include Paths: ${MPI_C_INCLUDE_PATH}")
message(STATUS "MPI C Libraries: ${MPI_C_LIBRARIES}")

# Create build output directory for slurm-jobs binaries
set(SLURM_JOBS_BUILD_DIR "${CMAKE_BINARY_DIR}/examples/slurm-jobs" CACHE PATH "SLURM jobs build directory")
file(MAKE_DIRECTORY ${SLURM_JOBS_BUILD_DIR})

# Set source directory
set(SLURM_JOBS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" CACHE PATH "SLURM jobs source directory")

message(STATUS "SLURM job examples configured. Binaries will be generated in: ${SLURM_JOBS_BUILD_DIR}")

# Add subdirectories for each example
add_subdirectory(hello-world)
add_subdirectory(pi-calculation)
add_subdirectory(matrix-multiply)

# --- Build All Examples ---
add_custom_target(
    build-slurm-jobs
    DEPENDS
        build-hello-world
        build-pi-calculation
        build-matrix-multiply
    COMMENT "Build all SLURM job example binaries"
)
