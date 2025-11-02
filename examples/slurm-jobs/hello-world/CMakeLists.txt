# Hello World MPI Example
# =======================
#
# Builds a simple MPI hello world program for SLURM job testing.

# Define source and binary paths
set(HELLO_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/hello.c")
set(HELLO_SBATCH "${CMAKE_CURRENT_SOURCE_DIR}/hello.sbatch")
set(HELLO_BINARY "${SLURM_JOBS_BUILD_DIR}/hello-world/hello")
set(HELLO_SBATCH_OUT "${SLURM_JOBS_BUILD_DIR}/hello-world/hello.sbatch")

# Build hello world binary and copy sbatch script
add_custom_command(
    OUTPUT ${HELLO_BINARY} ${HELLO_SBATCH_OUT}
    COMMAND ${CMAKE_COMMAND} -E make_directory "${SLURM_JOBS_BUILD_DIR}/hello-world"
    COMMAND ${MPI_C_COMPILER} -O2 -Wall -o ${HELLO_BINARY} ${HELLO_SOURCE}
    COMMAND ${CMAKE_COMMAND} -E copy ${HELLO_SBATCH} ${HELLO_SBATCH_OUT}
    DEPENDS ${HELLO_SOURCE} ${HELLO_SBATCH}
    COMMENT "Building hello-world MPI program and copying sbatch script..."
    VERBATIM
)

# Target for hello-world
add_custom_target(
    build-hello-world
    DEPENDS ${HELLO_BINARY} ${HELLO_SBATCH_OUT}
    COMMENT "Build target for hello-world MPI example"
)
