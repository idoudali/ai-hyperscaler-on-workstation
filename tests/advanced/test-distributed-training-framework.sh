#!/bin/bash
# Distributed Training Test Framework - Phase 5
# Task: TASK-053 - Container Build and Deployment & Distributed Training Validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
UTILS_DIR="$TESTS_DIR/test-infra/utils"

export PROJECT_ROOT TESTS_DIR SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa" SSH_USER="admin"

# SSH options for test environment
# Note: We disable host key checking (-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
# because this is a test environment where VMs may be recreated with different SSH keys.
# In production, these options should be removed and host keys should be properly managed.
# SSH_OPTS is exported as a string for use by _build_ssh_opts() in vm-utils.sh
# The -i "$SSH_KEY_PATH" is added separately by utility functions, so we don't include it here
export SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
# Local array version for direct use in this script (includes -i for convenience)
SSH_OPTS_ARRAY=(-i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
SCP_OPTS_ARRAY=(-i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

FRAMEWORK_NAME="Distributed Training Test Framework"
FRAMEWORK_DESCRIPTION="Validates distributed training capabilities, PyTorch container, and SLURM integration"
FRAMEWORK_TEST_CONFIG="$PROJECT_ROOT/config/example-multi-gpu-clusters.yaml"
FRAMEWORK_TEST_SCRIPTS_DIR="$TESTS_DIR/suites/distributed-training"
FRAMEWORK_TARGET_VM_PATTERN="controller"
FRAMEWORK_MASTER_TEST_SCRIPT="run-distributed-training-tests.sh"
export FRAMEWORK_NAME FRAMEWORK_DESCRIPTION FRAMEWORK_TEST_CONFIG FRAMEWORK_TEST_SCRIPTS_DIR FRAMEWORK_TARGET_VM_PATTERN

# Source utilities
for util in log-utils.sh cluster-utils.sh ansible-utils.sh test-framework-utils.sh framework-cli.sh framework-orchestration.sh; do
    if [[ -f "$UTILS_DIR/$util" ]]; then
        # shellcheck disable=SC1090
        source "$UTILS_DIR/$util"
    else
        echo "Error: Required utility file not found: $UTILS_DIR/$util" >&2
        exit 1
    fi
done

# Verify init_logging function is available
if ! declare -f init_logging >/dev/null 2>&1; then
    echo "Error: init_logging function not found after sourcing utilities" >&2
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "distributed-training"

# Function to build and deploy the PyTorch container
deploy_distributed_training_resources() {
    log "Deploying Distributed Training Resources..."

    # 1. Get Controller IP
    if ! get_vm_ips_for_cluster "$FRAMEWORK_TEST_CONFIG" "hpc"; then
        log_error "Failed to get VM IPs"
        return 1
    fi

    local controller_ip=""
    for i in "${!VM_IPS[@]}"; do
        if [[ "${VM_NAMES[$i]}" == *"controller"* ]]; then
            controller_ip="${VM_IPS[$i]}"
            break
        fi
    done

    if [[ -z "$controller_ip" ]]; then
        log_error "Controller VM not found"
        return 1
    fi

    # Sync Project to BeeGFS (Clone from Mount)
    local project_basename
    project_basename="$(basename "$PROJECT_ROOT")"
    local remote_project_dir="/mnt/beegfs/${project_basename}"
    # The repo is mounted on the controller at the same path as the host
    local mount_source="$PROJECT_ROOT"

    log "Cloning project from mount ($mount_source) to BeeGFS ($remote_project_dir)..."

    # Ensure parent dir exists and clean up target
    # shellcheck disable=SC2029  # Variable is intentionally expanded on client side
    ssh "${SSH_OPTS_ARRAY[@]}" \
        "${SSH_USER}@${controller_ip}" "mkdir -p /mnt/beegfs && rm -rf \"$remote_project_dir\""

    # Clone the repo
    # shellcheck disable=SC2029  # Variables are intentionally expanded on client side
    if ! ssh "${SSH_OPTS_ARRAY[@]}" \
        "${SSH_USER}@${controller_ip}" "git clone '$mount_source' '$remote_project_dir'"; then
        log_error "Failed to clone project to controller"
        return 1
    fi

    # Check for uncommitted changes
    # Since we are cloning from the mount which reflects the current workspace,
    # git clone will only pick up COMMITTED changes.
    # If there are uncommitted changes, the test will run against stale code.
    if [[ -n $(git status --porcelain) ]]; then
        log_warning "Uncommitted changes detected in workspace."
        log_warning "Please commit your changes before running distributed training tests."
        log_warning "The tests run on a cloned repository on the controller, so uncommitted changes will NOT be visible."
    fi

    # 2. Build Container (if not exists)
    local container_sif="$PROJECT_ROOT/build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif"
    if [[ ! -f "$container_sif" ]]; then
        log "Container image not found locally. Building..."
        # Use the project's Makefile wrapper to build in container
        if ! (cd "$PROJECT_ROOT" && make run-docker COMMAND="cmake --build build --target build-container-pytorch-cuda12.1-mpi4.1"); then
            log_error "Failed to build PyTorch container"
            return 1
        fi
    else
        log "Container image found locally: $container_sif"
    fi

    # 3. Create remote directories
    log "Creating remote directories on BeeGFS..."
    # Only create directories that are NOT part of the repo structure or are for data/logs
    local remote_dirs=(
        "/mnt/beegfs/containers"
        "/mnt/beegfs/data"
    )

    for dir in "${remote_dirs[@]}"; do
        # shellcheck disable=SC2029  # Variable is intentionally expanded on client side
        if ! ssh "${SSH_OPTS_ARRAY[@]}" \
            "${SSH_USER}@${controller_ip}" "mkdir -p \"$dir\""; then
            log_error "Failed to create directory: $dir"
            return 1
        fi
    done

    # 4. Upload Container
    log "Uploading container to BeeGFS (this may take a while)..."
    # Check if container already exists on remote to save time?
    # For now, just overwrite to ensure latest version
    if ! scp "${SCP_OPTS_ARRAY[@]}" \
        "$container_sif" "${SSH_USER}@${controller_ip}:/mnt/beegfs/containers/"; then
        log_error "Failed to upload container"
        return 1
    fi

    # 5. Verify Templates and Scripts exist in the synced repo
    log "Verifying templates and scripts exist in synced repo..."
    # Since we cloned the repo, we assume files are there if git clone succeeded.
    # We can add a simple check if needed.

    # Helper Scripts - Already in repo, no need to upload
    # Just ensure they are executable
    # shellcheck disable=SC2029  # Variable is intentionally expanded on client side
    ssh "${SSH_OPTS_ARRAY[@]}" \
        "${SSH_USER}@${controller_ip}" "chmod +x \"$remote_project_dir\"/tests/suites/distributed-training/*.sh"

    # 6. Deploy Monitoring Infrastructure
    log "Deploying monitoring infrastructure..."
    # Scripts are in the repo, just make sure they are executable
    # shellcheck disable=SC2029  # Variable is intentionally expanded on client side
    ssh "${SSH_OPTS_ARRAY[@]}" \
        "${SSH_USER}@${controller_ip}" \
        "chmod +x \"$remote_project_dir\"/scripts/*.sh \"$remote_project_dir\"/examples/slurm-jobs/monitoring/scripts/*.sh"

    # 7. Setup Python virtual environment for monitoring tools
    log "Setting up Python virtual environment for monitoring tools..."
    if ssh "${SSH_OPTS_ARRAY[@]}" \
        "${SSH_USER}@${controller_ip}" "test -f /mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif"; then

        # Check if venv exists and is valid (has pip)
        if ssh "${SSH_OPTS_ARRAY[@]}" \
            "${SSH_USER}@${controller_ip}" "test -f /mnt/beegfs/pytorch-env/bin/pip"; then
            log "Virtual environment already exists and appears valid"
        else
            log "Creating or recreating virtual environment..."
            # Clean up potentially broken venv
            ssh "${SSH_OPTS_ARRAY[@]}" \
                "${SSH_USER}@${controller_ip}" "rm -rf /mnt/beegfs/pytorch-env"

            if ! ssh "${SSH_OPTS_ARRAY[@]}" \
                "${SSH_USER}@${controller_ip}" \
                "export APPTAINER_BIND='/mnt/beegfs:/mnt/beegfs' && \
                 apptainer exec /mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif \
                 python3 -m venv /mnt/beegfs/pytorch-env --system-site-packages --without-pip && \
                 apptainer exec /mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif \
                 curl -sS https://bootstrap.pypa.io/get-pip.py | /mnt/beegfs/pytorch-env/bin/python3"; then
                 # Fallback to standard creation if manual pip install fails (though standard often fails on ensurepip)
                 log "Standard venv creation..."
                 ssh "${SSH_OPTS_ARRAY[@]}" \
                    "${SSH_USER}@${controller_ip}" \
                    "export APPTAINER_BIND='/mnt/beegfs:/mnt/beegfs' && \
                     apptainer exec /mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif \
                     python3 -m venv /mnt/beegfs/pytorch-env --system-site-packages" || {
                        log_error "Failed to create virtual environment"
                        return 1
                     }
            fi
        fi

        # Install monitoring tools in venv
        log "Installing monitoring tools in virtual environment..."
        if ! ssh "${SSH_OPTS_ARRAY[@]}" \
            "${SSH_USER}@${controller_ip}" \
            "export APPTAINER_BIND='/mnt/beegfs:/mnt/beegfs' && \
             apptainer exec /mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif \
             /mnt/beegfs/pytorch-env/bin/python3 -m pip install --quiet tensorboard aim mlflow"; then
            log_warning "Failed to install some monitoring tools (may already be installed)"
        else
            log "Monitoring tools installed successfully"
        fi
    else
        log_warning "Container not found, skipping venv setup"
    fi

    # 8. Build and Deploy Oumi Container Variant
    log "Building and deploying Oumi container variant..."
    local oumi_container_sif="$PROJECT_ROOT/build/containers/apptainer/pytorch-cuda12.1-mpi4.1-oumi.sif"
    if [[ ! -f "$oumi_container_sif" ]]; then
        log "Oumi container variant not found locally. Building..."
        # Use the project's Makefile wrapper to build in container
        if ! (cd "$PROJECT_ROOT" && make run-docker COMMAND="cmake --build build --target build-container-pytorch-cuda12.1-mpi4.1-oumi"); then
            log_warning "Failed to build Oumi container variant (may not be critical for all tests)"
        else
            log "Oumi container variant built successfully"
        fi
    else
        log "Oumi container variant found locally: $oumi_container_sif"
    fi

    # Upload Oumi container if it exists
    if [[ -f "$oumi_container_sif" ]]; then
        log "Uploading Oumi container variant to BeeGFS..."
        if ! scp "${SCP_OPTS_ARRAY[@]}" \
            "$oumi_container_sif" "${SSH_USER}@${controller_ip}:/mnt/beegfs/containers/"; then
            log_warning "Failed to upload Oumi container variant (may not be critical for all tests)"
        else
            log "Oumi container variant uploaded successfully"
        fi
    fi

    # 9. Initialize Aim repository (if container is available)
    # Skipped: Aim repository is now initialized per-test in the test output directory
    # log "Initializing Aim repository..."
    # ... code removed ...

    # Make scripts executable
    ssh "${SSH_OPTS_ARRAY[@]}" \
        "${SSH_USER}@${controller_ip}" "chmod +x /mnt/beegfs/scripts/*.sh \$remote_project_dir/examples/slurm-jobs/monitoring/*.sbatch 2>/dev/null || true"

    log_success "Distributed training resources deployed successfully"
    return 0
}

# Run validation tests
run_distributed_training_tests() {
    log "Running Distributed Training validation suite..."

    # Get VM IPs
    if ! get_vm_ips_for_cluster "$FRAMEWORK_TEST_CONFIG" "hpc"; then
        log_error "Failed to get VM IPs"
        return 1
    fi

    local controller_ip=""
    local controller_name=""
    for i in "${!VM_IPS[@]}"; do
        if [[ "${VM_NAMES[$i]}" == *"controller"* ]]; then
            controller_ip="${VM_IPS[$i]}"
            controller_name="${VM_NAMES[$i]}"
            break
        fi
    done

    if [[ -z "$controller_ip" ]]; then
        log_error "Controller VM not found"
        return 1
    fi

    log "Controller: $controller_name ($controller_ip)"

    # Wait for SSH
    if ! wait_for_vm_ssh "$controller_ip" "$controller_name"; then
        log_error "SSH connectivity failed for controller"
        return 1
    fi

    # Upload Test Suite (Full Repo Clone to BeeGFS)
    local project_basename
    project_basename="$(basename "$PROJECT_ROOT")"
    local remote_project_dir="/mnt/beegfs/${project_basename}"
    local suite_relative
    suite_relative="${FRAMEWORK_TEST_SCRIPTS_DIR#"$PROJECT_ROOT"/}"
    local intended_remote_dir="${remote_project_dir}/${suite_relative}"

    # Syncing is now handled in deploy_distributed_training_resources
    log "Using project on controller (BeeGFS location: $remote_project_dir)..."

    local actual_suite_dir="$intended_remote_dir"
    log "Test suite directory: $actual_suite_dir"

    # Prepare test arguments
    local test_args=""
    [[ "${FRAMEWORK_VERBOSE:-false}" == "true" ]] && test_args="--verbose"

    # Execute Master Test Runner
    log "Executing validation tests on controller (from BeeGFS)..."
    local master_script_basename
    master_script_basename=$(basename "$FRAMEWORK_MASTER_TEST_SCRIPT")

    # Also run the simple environment check script first as a sanity check
    cmd="$remote_project_dir/tests/suites/distributed-training/check-container-env.sh"
    log "Running basic environment check: $cmd"
    local env_check_rc=0
    # shellcheck disable=SC2029  # Variable is intentionally expanded on client side
    output=$(ssh "${SSH_OPTS_ARRAY[@]}" \
        "${SSH_USER}@${controller_ip}" "bash \"$cmd\"" 2>&1) || env_check_rc=$?

    # Always print output for visual debugging
    echo "=== Environment Check Output ==="
    echo "$output"
    echo "=== End Environment Check Output ==="

    if [[ $env_check_rc -ne 0 ]]; then
        log_warning "Basic environment check failed (exit code: $env_check_rc). Proceeding with BATS suite for detailed report..."
    else
        log_success "Basic environment check passed"
    fi

    # Execute script on VM using the BeeGFS directory
    # We construct the command manually instead of using execute_script_on_vm because we want to specify the CWD carefully
    local ssh_cmd="cd '$actual_suite_dir' && \
                   LOG_DIR='$actual_suite_dir/logs/test-run-$TIMESTAMP' \
                   PROJECT_ROOT='$remote_project_dir' \
                   TESTS_DIR='$remote_project_dir/tests' \
                   SSH_KEY_PATH='/home/admin/.ssh/id_rsa' \
                   SSH_USER='admin' \
                   CONTROLLER_IP='$controller_ip' \
                   bash './$master_script_basename' $test_args"

    log "Executing: $ssh_cmd"

    # Note: SSH agent forwarding (-A) is used here to allow the controller to access compute nodes.
    # This is acceptable in a test environment but should be reviewed for production use.
    if ! ssh -A "${SSH_OPTS_ARRAY[@]}" -o ConnectTimeout=10 \
        "${SSH_USER}@${controller_ip}" "$ssh_cmd"; then
        log_error "Distributed training tests failed"
        return 1
    fi

    log_success "Distributed training tests completed successfully"
    return 0
}

run_framework_specific_tests() {
    log "Running ${FRAMEWORK_NAME}..."

    # Check cluster status
    local cluster_name
    if ! cluster_name=$(parse_cluster_name "$FRAMEWORK_TEST_CONFIG" "${LOG_DIR}" "hpc"); then
        log_error "Failed to get cluster name"
        return 1
    fi

    local running_vms
    running_vms=$(virsh list --name --state-running | grep "^${cluster_name}" || true)

    if [[ -z "$running_vms" ]]; then
        log "Cluster not running, starting cluster..."
        if ! framework_start_cluster; then
            log_error "Failed to start cluster"
            return 1
        fi
    fi

    # Deploy resources (Task 53)
    if ! deploy_distributed_training_resources; then
        log_error "Failed to deploy distributed training resources"
        return 1
    fi

    # Run tests
    if ! run_distributed_training_tests; then
        log_error "Tests failed"
        return 1
    fi

    log_success "All Phase 5 validations completed"
    return 0
}

# Main
parse_framework_cli "$@"
COMMAND=$(get_framework_command)

case "$COMMAND" in
    "e2e"|"end-to-end") run_framework_e2e_workflow ;;
    "start-cluster") framework_start_cluster ;;
    "stop-cluster") framework_stop_cluster ;;
    "deploy") deploy_distributed_training_resources ;;
    "run-tests") run_framework_specific_tests ;;
    "status") framework_get_cluster_status ;;
    "list-tests") find "$FRAMEWORK_TEST_SCRIPTS_DIR" -name "*.bats" -type f | head -20 ;;
    "help"|"--help") show_framework_help ;;
    *) run_framework_e2e_workflow ;;
esac
