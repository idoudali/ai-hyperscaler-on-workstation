# Examples CMake Configuration
# ===========================
#
# This CMakeLists.txt includes example programs and test applications.
# Currently includes SLURM job examples for MPI testing.
#

cmake_minimum_required(VERSION 3.18)

# Add SLURM job examples subdirectory
add_subdirectory(slurm-jobs)
