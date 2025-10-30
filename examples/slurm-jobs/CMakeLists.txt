# SLURM Job Examples CMake Configuration
# ======================================
#
# This CMakeLists.txt builds MPI example programs for SLURM job submission.
# All binaries are generated in the build directory structure.
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
set(SLURM_JOBS_BUILD_DIR "${CMAKE_BINARY_DIR}/examples/slurm-jobs")
file(MAKE_DIRECTORY ${SLURM_JOBS_BUILD_DIR})

# Set source directory
set(SLURM_JOBS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

# --- Hello World Example ---
set(HELLO_SOURCE "${SLURM_JOBS_SOURCE_DIR}/hello-world/hello.c")
set(HELLO_BINARY "${SLURM_JOBS_BUILD_DIR}/hello-world/hello")

add_custom_command(
    OUTPUT ${HELLO_BINARY}
    COMMAND ${CMAKE_COMMAND} -E make_directory "${SLURM_JOBS_BUILD_DIR}/hello-world"
    COMMAND ${MPI_C_COMPILER} -O2 -Wall -o ${HELLO_BINARY} ${HELLO_SOURCE}
    DEPENDS ${HELLO_SOURCE}
    COMMENT "Building hello-world MPI program..."
    VERBATIM
)

add_custom_target(
    build-hello-world
    DEPENDS ${HELLO_BINARY}
    COMMENT "Build target for hello-world MPI example"
)

# --- Pi Calculation Example ---
set(PI_SOURCE "${SLURM_JOBS_SOURCE_DIR}/pi-calculation/pi-monte-carlo.c")
set(PI_BINARY "${SLURM_JOBS_BUILD_DIR}/pi-calculation/pi-monte-carlo")

add_custom_command(
    OUTPUT ${PI_BINARY}
    COMMAND ${CMAKE_COMMAND} -E make_directory "${SLURM_JOBS_BUILD_DIR}/pi-calculation"
    COMMAND ${MPI_C_COMPILER} -O3 -Wall -o ${PI_BINARY} ${PI_SOURCE} -lm
    DEPENDS ${PI_SOURCE}
    COMMENT "Building pi-calculation MPI program..."
    VERBATIM
)

add_custom_target(
    build-pi-calculation
    DEPENDS ${PI_BINARY}
    COMMENT "Build target for pi-calculation MPI example"
)

# --- Matrix Multiply Example ---
set(MATRIX_SOURCE "${SLURM_JOBS_SOURCE_DIR}/matrix-multiply/matrix-mult.c")
set(MATRIX_BINARY "${SLURM_JOBS_BUILD_DIR}/matrix-multiply/matrix-mult")

add_custom_command(
    OUTPUT ${MATRIX_BINARY}
    COMMAND ${CMAKE_COMMAND} -E make_directory "${SLURM_JOBS_BUILD_DIR}/matrix-multiply"
    COMMAND ${MPI_C_COMPILER} -O3 -Wall -o ${MATRIX_BINARY} ${MATRIX_SOURCE} -lm
    DEPENDS ${MATRIX_SOURCE}
    COMMENT "Building matrix-multiply MPI program..."
    VERBATIM
)

add_custom_target(
    build-matrix-multiply
    DEPENDS ${MATRIX_BINARY}
    COMMENT "Build target for matrix-multiply MPI example"
)

# --- Build All Examples ---
add_custom_target(
    build-slurm-jobs
    DEPENDS
        build-hello-world
        build-pi-calculation
        build-matrix-multiply
    COMMENT "Build all SLURM job example binaries"
)

message(STATUS "SLURM job examples configured. Binaries will be generated in: ${SLURM_JOBS_BUILD_DIR}")
