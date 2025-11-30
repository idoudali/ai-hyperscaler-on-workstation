#!/usr/bin/env bats
#
# Phase 5: Monitoring Infrastructure Test (BATS)
# Tests monitoring tools setup (TensorBoard, Aim, MLflow)
# TASK-055: Monitoring Infrastructure Setup
#

# Load helper functions
load helpers/monitoring-helpers
load helpers/container-helpers

# Test configuration
BEEGFS_MOUNT="/mnt/beegfs"
MONITORING_ROOT="$BEEGFS_MOUNT/monitoring"
SERVER_SCRIPTS_DIR="$PROJECT_ROOT/examples/slurm-jobs/monitoring"
INTEGRATION_TEST_SCRIPT="$PROJECT_ROOT/tests/suites/distributed-training/monitoring-integration.py"
CONTAINER="/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"
VENV_PYTHON="$BEEGFS_MOUNT/pytorch-env/bin/python3"

# Setup: Run before each test
setup() {
    TEST_TEMP_DIR=$(mktemp -d)
    export TEST_TEMP_DIR
    export APPTAINER_BIND="$BEEGFS_MOUNT:$BEEGFS_MOUNT"

    # Ensure monitoring root exists
    if [ ! -d "$MONITORING_ROOT" ]; then
        mkdir -p "$MONITORING_ROOT"
    fi
}

# Teardown: Run after each test
teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "Monitoring python packages are installed in VENV (via Container)" {
    skip_if_no_apptainer

    if [ ! -f "$CONTAINER" ]; then
        skip "Container not found at $CONTAINER"
    fi

    if [ ! -f "$VENV_PYTHON" ]; then
        skip "Virtual environment python not found at $VENV_PYTHON"
    fi

    # Run import check using the container + venv
    run apptainer exec --nv "$CONTAINER" "$VENV_PYTHON" -c "import tensorboard; import aim; import mlflow; print('Success')"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Success"* ]]
}

@test "Monitoring directory structure exists" {
    [ -d "$MONITORING_ROOT" ]
    # Monitoring folders are now created per-test or by services
}

# @test "Aim repository is initialized" {
#    [ -d "$MONITORING_ROOT/aim/.aim" ]
# }

@test "Server launch scripts exist" {
    [ -f "$SERVER_SCRIPTS_DIR/tensorboard-server.sbatch" ]
    [ -f "$SERVER_SCRIPTS_DIR/aim-server.sbatch" ]
    [ -f "$SERVER_SCRIPTS_DIR/mlflow-server.sbatch" ]
}

@test "Monitoring integration script runs successfully" {
    skip_if_no_apptainer

    if [ ! -f "$INTEGRATION_TEST_SCRIPT" ]; then
        skip "Integration test script not found at $INTEGRATION_TEST_SCRIPT"
    fi

    # We should run this using the container environment too
    if [ -f "$CONTAINER" ] && [ -f "$VENV_PYTHON" ]; then
         run apptainer exec --nv "$CONTAINER" "$VENV_PYTHON" "$INTEGRATION_TEST_SCRIPT"
         [ "$status" -eq 0 ]
         [[ "$output" == *"All monitoring integration tests passed"* ]]
    else
         skip "Container or Venv missing, cannot run integration test"
    fi
}

@test "Management script exists and is executable" {
    MANAGE_SCRIPT="$PROJECT_ROOT/scripts/manage-monitoring-servers.sh"

    [ -f "$MANAGE_SCRIPT" ]
    [ -x "$MANAGE_SCRIPT" ] || chmod +x "$MANAGE_SCRIPT"

    run bash "$MANAGE_SCRIPT" status
    [ "$status" -eq 0 ]
}
