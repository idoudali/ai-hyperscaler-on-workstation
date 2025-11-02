# Matrix Multiply MPI Example
# ===========================
#
# Builds a distributed matrix multiplication program using MPI parallelization.

# Define source and binary paths
set(MATRIX_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/matrix-mult.c")
set(MATRIX_SBATCH "${CMAKE_CURRENT_SOURCE_DIR}/matrix.sbatch")
set(MATRIX_BINARY "${SLURM_JOBS_BUILD_DIR}/matrix-multiply/matrix-mult")
set(MATRIX_SBATCH_OUT "${SLURM_JOBS_BUILD_DIR}/matrix-multiply/matrix.sbatch")

# Build matrix-multiply binary and copy sbatch script
add_custom_command(
    OUTPUT ${MATRIX_BINARY} ${MATRIX_SBATCH_OUT}
    COMMAND ${CMAKE_COMMAND} -E make_directory "${SLURM_JOBS_BUILD_DIR}/matrix-multiply"
    COMMAND ${MPI_C_COMPILER} -O3 -Wall -o ${MATRIX_BINARY} ${MATRIX_SOURCE} -lm
    COMMAND ${CMAKE_COMMAND} -E copy ${MATRIX_SBATCH} ${MATRIX_SBATCH_OUT}
    DEPENDS ${MATRIX_SOURCE} ${MATRIX_SBATCH}
    COMMENT "Building matrix-multiply MPI program and copying sbatch script..."
    VERBATIM
)

# Target for matrix-multiply
add_custom_target(
    build-matrix-multiply
    DEPENDS ${MATRIX_BINARY} ${MATRIX_SBATCH_OUT}
    COMMENT "Build target for matrix-multiply MPI example"
)
