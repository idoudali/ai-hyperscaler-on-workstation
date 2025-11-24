#!/bin/bash
# Distributed Training Test Framework - Phase 5
# Task: TASK-053 - Container Build and Deployment & Distributed Training Validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
UTILS_DIR="$TESTS_DIR/test-infra/utils"

export PROJECT_ROOT TESTS_DIR SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa" SSH_USER="admin"

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
    local remote_dirs=(
        "/mnt/beegfs/containers"
        "/mnt/beegfs/training/scripts"
        "/mnt/beegfs/training/templates"
        "/mnt/beegfs/scripts"
        "/mnt/beegfs/jobs"
        "/mnt/beegfs/logs"
        "/mnt/beegfs/data"
    )

    for dir in "${remote_dirs[@]}"; do
        if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            "${SSH_USER}@${controller_ip}" "mkdir -p \"$dir\""; then
            log_error "Failed to create directory: $dir"
            return 1
        fi
    done

    # 4. Upload Container
    log "Uploading container to BeeGFS (this may take a while)..."
    # Check if container already exists on remote to save time?
    # For now, just overwrite to ensure latest version
    if ! scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$container_sif" "${SSH_USER}@${controller_ip}:/mnt/beegfs/containers/"; then
        log_error "Failed to upload container"
        return 1
    fi

    # 4b. Upload MNIST DDP Job Files
    log "Uploading MNIST DDP job files to BeeGFS..."
    local mnist_source_dir="$PROJECT_ROOT/examples/slurm-jobs/mnist-ddp"

    # Upload training script
    if ! scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$mnist_source_dir/mnist_ddp.py" "${SSH_USER}@${controller_ip}:/mnt/beegfs/training/scripts/"; then
        log_error "Failed to upload MNIST training script"
        return 1
    fi

    # Upload job script (keep .sbatch extension for consistency)
    if ! scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$mnist_source_dir/mnist-ddp.sbatch" "${SSH_USER}@${controller_ip}:/mnt/beegfs/jobs/mnist-ddp.sbatch"; then
        log_error "Failed to upload MNIST job script"
        return 1
    fi

    # 5. Verify Templates and Scripts exist on remote (mounted via virtio)
    log "Verifying templates and scripts exist on remote server (mounted via virtio)..."

    if [[ -d "$PROJECT_ROOT/examples/slurm-jobs/templates" ]]; then
        local missing_files=()

        # Check Python script templates
        for py_file in "$PROJECT_ROOT/examples/slurm-jobs/templates"/*.py; do
            [[ ! -f "$py_file" ]] && continue
            local basename_py
            basename_py=$(basename "$py_file")
            if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                "${SSH_USER}@${controller_ip}" "test -f \"/mnt/beegfs/training/scripts/$basename_py\"" 2>/dev/null; then
                missing_files+=("/mnt/beegfs/training/scripts/$basename_py")
            fi
        done

        # Check shell script templates
        for sh_file in "$PROJECT_ROOT/examples/slurm-jobs/templates"/*.sh; do
            [[ ! -f "$sh_file" ]] && continue
            local basename_sh
            basename_sh=$(basename "$sh_file")
            if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                "${SSH_USER}@${controller_ip}" "test -f \"/mnt/beegfs/training/templates/$basename_sh\"" 2>/dev/null; then
                missing_files+=("/mnt/beegfs/training/templates/$basename_sh")
            fi
        done

        # Fail if any files are missing
        if [[ ${#missing_files[@]} -gt 0 ]]; then
            log_error "Required files missing on remote server (expected to be mounted via virtio):"
            for file in "${missing_files[@]}"; do
                log_error "  - $file"
            done
            return 1
        fi

        log "All required template files found on remote server"
    fi

    # Helper Scripts
    if [[ -f "$PROJECT_ROOT/tests/suites/distributed-training/check-container-env.sh" ]]; then
        if ! scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            "$PROJECT_ROOT/tests/suites/distributed-training/check-container-env.sh" \
            "${SSH_USER}@${controller_ip}:/mnt/beegfs/scripts/"; then
            log_error "Failed to upload validation script"
            return 1
        fi
    fi

    # Make scripts executable
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "${SSH_USER}@${controller_ip}" "chmod +x /mnt/beegfs/scripts/*.sh 2>/dev/null || true"

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

    # Upload Test Suite
    # Calculate intended remote directory (maintain project structure)
    local project_basename
    project_basename="$(basename "$PROJECT_ROOT")"
    local suite_relative
    suite_relative="${FRAMEWORK_TEST_SCRIPTS_DIR#"$PROJECT_ROOT"/}"
    # shellcheck disable=SC2088
    local intended_remote_dir="~/$project_basename/$suite_relative"

    log "Uploading Distributed Training test suite to controller..."
    if ! upload_scripts_to_vm "$controller_ip" "$controller_name" "$FRAMEWORK_TEST_SCRIPTS_DIR" "$intended_remote_dir"; then
        log_error "Failed to upload test scripts to controller"
        return 1
    fi

    local actual_suite_dir="$ACTUAL_REMOTE_DIR"
    log "Scripts uploaded to: $actual_suite_dir"

    # Upload helpers explicitly if needed, but upload_scripts_to_vm should recursive copy
    # (test-framework-utils.sh implementation of upload_scripts_to_vm usually uses scp -r)

    # Prepare test arguments
    local test_args=""
    [[ "${FRAMEWORK_VERBOSE:-false}" == "true" ]] && test_args="--verbose"

    # Execute Master Test Runner
    log "Executing validation tests on controller..."
    local master_script_basename
    master_script_basename=$(basename "$FRAMEWORK_MASTER_TEST_SCRIPT")

    # Also run the simple environment check script first as a sanity check
    cmd="/mnt/beegfs/scripts/check-container-env.sh"
    log "Running basic environment check: $cmd"
    local env_check_rc=0
    output=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "${SSH_USER}@${controller_ip}" "bash $cmd" 2>&1) || env_check_rc=$?

    # Always print output for visual debugging
    echo "=== Environment Check Output ==="
    echo "$output"
    echo "=== End Environment Check Output ==="

    if [[ $env_check_rc -ne 0 ]]; then
        log_warning "Basic environment check failed (exit code: $env_check_rc). Proceeding with BATS suite for detailed report..."
    else
        log_success "Basic environment check passed"
    fi

    if ! execute_script_on_vm "$controller_ip" "$controller_name" "$master_script_basename" "$actual_suite_dir" "$test_args"; then
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
