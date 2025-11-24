# MNIST DDP Training Example
# ===========================
#
# Builds MNIST distributed training example for SLURM job testing.
# Uses PyTorch container from TASK-053 for execution.

# Define source and script paths
set(MNIST_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/mnist_ddp.py")
set(MNIST_SBATCH "${CMAKE_CURRENT_SOURCE_DIR}/mnist-ddp.sbatch")
set(MNIST_SCRIPT_OUT "${SLURM_JOBS_BUILD_DIR}/mnist-ddp/mnist_ddp.py")
set(MNIST_SBATCH_OUT "${SLURM_JOBS_BUILD_DIR}/mnist-ddp/mnist-ddp.sbatch")

# Copy MNIST training script and sbatch file to build directory
# Create output directory
file(MAKE_DIRECTORY "${SLURM_JOBS_BUILD_DIR}/mnist-ddp")

# Copy files using configure_file (preserves permissions)
configure_file(${MNIST_SOURCE} ${MNIST_SCRIPT_OUT} COPYONLY)
configure_file(${MNIST_SBATCH} ${MNIST_SBATCH_OUT} COPYONLY)
