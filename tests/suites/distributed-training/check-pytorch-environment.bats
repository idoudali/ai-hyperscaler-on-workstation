#!/usr/bin/env bats
#
# Phase 5: PyTorch Environment and Container Test (BATS)
# Tests PyTorch container deployment and accessibility
#

# Load helper functions
load helpers/container-helpers

# Test configuration
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"

# Setup: Run before each test
setup() {
    TEST_TEMP_DIR=$(mktemp -d)
    export TEST_TEMP_DIR
}

# Teardown: Run after each test
teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "Container image exists on BeeGFS" {
    [ -f "$CONTAINER" ]
    [ -r "$CONTAINER" ]
}

@test "Container is executable with Python" {
    skip_if_no_apptainer

    run apptainer exec "$CONTAINER" python3 --version
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "PyTorch is installed in container" {
    skip_if_no_apptainer

    run apptainer exec "$CONTAINER" python3 -c "import torch; print(torch.__version__)"
    [ "$status" -eq 0 ]
    [ -n "$output" ]

    # Verify version format (x.y.z)
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "CUDA is available in container with GPU" {
    skip_if_no_apptainer
    skip_if_no_gpu

    run srun --nodes=1 --gres=gpu:1 \
        apptainer exec --nv "$CONTAINER" \
        python3 -c "import torch; print(torch.cuda.is_available())"

    [ "$status" -eq 0 ]
    [[ "$output" == *"True"* ]]
}

@test "MPI is installed in container" {
    skip_if_no_apptainer

    run apptainer exec "$CONTAINER" mpirun --version
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "Container is accessible from multiple nodes" {
    skip_if_no_apptainer
    skip_if_single_node

    # Use --chdir=/tmp to avoid chdir errors on compute nodes
    # The test directory may not exist on compute nodes
    run srun --nodes=2 --ntasks=2 --gres=gpu:1 --chdir=/tmp \
        apptainer exec --nv "$CONTAINER" \
        python3 -c "import socket; print(socket.gethostname())"

    [ "$status" -eq 0 ]
    # Should have output from 2 nodes (filter to only lines with compute node names)
    local node_count
    node_count=$(echo "$output" | grep -c "compute-" || true)
    [ "$node_count" -eq 2 ]
}

@test "NCCL backend is available" {
    skip_if_no_apptainer
    skip_if_no_gpu

    # Must run with GPU access (--nv flag and via srun with gres) to check NCCL
    run srun --nodes=1 --gres=gpu:1 --chdir=/tmp \
        apptainer exec --nv "$CONTAINER" python3 -c \
        "import torch; print(torch.distributed.is_nccl_available())"

    [ "$status" -eq 0 ]
    [[ "$output" == *"True"* ]]
}
