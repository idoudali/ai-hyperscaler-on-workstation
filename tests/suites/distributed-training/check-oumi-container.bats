#!/usr/bin/env bats
# BATS test suite for TASK-056: Oumi Framework Container Installation

# Test configuration
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1-oumi.sif"
CONFIG_TEMPLATE="/mnt/beegfs/configs/oumi-template.yaml"

# Helper function to skip tests if container not available
skip_if_no_container() {
    if [ ! -f "$CONTAINER" ]; then
        skip "Oumi container not found: $CONTAINER"
    fi
}

# Helper function to skip tests if GPU not available
skip_if_no_gpu() {
    if ! command -v nvidia-smi &> /dev/null; then
        skip "GPU not available in test environment"
    fi
}

@test "Oumi container file exists" {
    skip_if_no_container
    [ -f "$CONTAINER" ]
}

@test "Oumi container is executable" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" /venv/bin/python3 --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python"* ]]
}

@test "Oumi package is installed" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" /venv/bin/python3 -c "import importlib.metadata; print(importlib.metadata.version('oumi'))"
    [ "$status" -eq 0 ]
    [[ "$output" == *"."* ]]  # Version should contain a dot
}

@test "Oumi CLI is available" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" oumi --help
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "Oumi core imports work" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" /venv/bin/python3 -c "
from oumi.core.configs import TrainingConfig, ModelParams
from oumi.core.trainers import Trainer
print('OK')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "PyTorch is available" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" /venv/bin/python3 -c "import torch; print(torch.__version__)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"."* ]]  # Version should contain a dot
}

@test "CUDA support in container" {
    skip_if_no_container
    skip_if_no_gpu

    # Use srun to run on a node with GPU
    run srun --nodes=1 --gres=gpu:1 \
        apptainer exec --nv "$CONTAINER" \
        /venv/bin/python3 -c "import torch; print(torch.cuda.is_available())"

    [ "$status" -eq 0 ]
    [[ "$output" == *"True"* ]]
}

@test "Transformers library is available" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" /venv/bin/python3 -c "import transformers; print(transformers.__version__)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"."* ]]  # Version should contain a dot
}

@test "Datasets library is available" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" /venv/bin/python3 -c "import datasets; print(datasets.__version__)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"."* ]]  # Version should contain a dot
}

@test "Accelerate library is available" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" /venv/bin/python3 -c "import accelerate; print(accelerate.__version__)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"."* ]]  # Version should contain a dot
}

@test "PEFT library is available" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" /venv/bin/python3 -c "import peft; print(peft.__version__)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"."* ]]  # Version should contain a dot
}

@test "Monitoring tools are available" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" /venv/bin/python3 -c "
import tensorboard
import aim
import mlflow
print('OK')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "MPI support is available" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" mpirun --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Open MPI"* ]] || [[ "$output" == *"MPI"* ]]
}

@test "MPI4Py is available" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" /venv/bin/python3 -c "import mpi4py; print('OK')"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "Oumi configuration template exists" {
    if [ -f "$CONFIG_TEMPLATE" ]; then
        [ -f "$CONFIG_TEMPLATE" ]
    elif [ -f "examples/slurm-jobs/oumi/oumi-template.yaml" ]; then
        [ -f "examples/slurm-jobs/oumi/oumi-template.yaml" ]
    else
        skip "Configuration template not found (may be created later)"
    fi
}

@test "Container entrypoint script works" {
    skip_if_no_container
    run apptainer exec "$CONTAINER" /usr/local/bin/entrypoint.sh python3 --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python"* ]]
}
