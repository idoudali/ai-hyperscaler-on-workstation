# Pi Calculation MPI Example
# ==========================
#
# Builds a Monte Carlo pi estimation program using MPI parallelization.

# Define source and binary paths
set(PI_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/pi-monte-carlo.c")
set(PI_SBATCH "${CMAKE_CURRENT_SOURCE_DIR}/pi.sbatch")
set(PI_BINARY "${SLURM_JOBS_BUILD_DIR}/pi-calculation/pi-monte-carlo")
set(PI_SBATCH_OUT "${SLURM_JOBS_BUILD_DIR}/pi-calculation/pi.sbatch")

# Build pi-calculation binary and copy sbatch script
add_custom_command(
    OUTPUT ${PI_BINARY} ${PI_SBATCH_OUT}
    COMMAND ${CMAKE_COMMAND} -E make_directory "${SLURM_JOBS_BUILD_DIR}/pi-calculation"
    COMMAND ${MPI_C_COMPILER} -O3 -Wall -o ${PI_BINARY} ${PI_SOURCE} -lm
    COMMAND ${CMAKE_COMMAND} -E copy ${PI_SBATCH} ${PI_SBATCH_OUT}
    DEPENDS ${PI_SOURCE} ${PI_SBATCH}
    COMMENT "Building pi-calculation MPI program and copying sbatch script..."
    VERBATIM
)

# Target for pi-calculation
add_custom_target(
    build-pi-calculation
    DEPENDS ${PI_BINARY} ${PI_SBATCH_OUT}
    COMMENT "Build target for pi-calculation MPI example"
)
