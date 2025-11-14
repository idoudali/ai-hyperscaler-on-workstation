#!/bin/bash
# BeeGFS Test Framework - Refactored to use Phase 2 shared utilities
# Task: TASK-028 - Deploy BeeGFS Parallel Filesystem

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
UTILS_DIR="$TESTS_DIR/test-infra/utils"

export PROJECT_ROOT TESTS_DIR SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa" SSH_USER="admin"

FRAMEWORK_NAME="BeeGFS Test Framework"
FRAMEWORK_DESCRIPTION="Parallel filesystem deployment and validation testing"
# shellcheck disable=SC2034
FRAMEWORK_TASK="TASK-028"
FRAMEWORK_TEST_CONFIG="$PROJECT_ROOT/config/example-multi-gpu-clusters.yaml"
FRAMEWORK_TEST_SCRIPTS_DIR="$TESTS_DIR/suites/beegfs"
FRAMEWORK_TARGET_VM_PATTERN="hpc"
# shellcheck disable=SC2034
FRAMEWORK_MASTER_TEST_SCRIPT="run-beegfs-tests.sh"
export FRAMEWORK_NAME FRAMEWORK_DESCRIPTION FRAMEWORK_TEST_CONFIG FRAMEWORK_TEST_SCRIPTS_DIR FRAMEWORK_TARGET_VM_PATTERN

# Source utilities
# shellcheck disable=SC1090
for util in log-utils.sh cluster-utils.sh ansible-utils.sh test-framework-utils.sh framework-cli.sh framework-orchestration.sh; do
    if [[ -f "$UTILS_DIR/$util" ]]; then
        if ! source "$UTILS_DIR/$util"; then
            echo "Error: Failed to source $UTILS_DIR/$util" >&2
            exit 1
        fi
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
init_logging "$TIMESTAMP" "logs" "beegfs"

# BeeGFS-specific test execution
run_beegfs_tests() {
    log "Running BeeGFS test suite..."

    # Use shared utility to get VM IPs from the cluster
    if ! get_vm_ips_for_cluster "$FRAMEWORK_TEST_CONFIG" "hpc"; then
        log_error "Failed to get VM IPs from cluster"
        return 1
    fi

    # VM_IPS and VM_NAMES arrays are now populated
    if [[ ${#VM_IPS[@]} -eq 0 ]]; then
        log_error "No VMs found in cluster"
        return 1
    fi

    log "Found ${#VM_IPS[@]} VM(s) in cluster"

    # Separate controller and compute node IPs
    local controller_ip=""
    local controller_name=""
    local compute_ips=()

    for i in "${!VM_IPS[@]}"; do
        local vm_name="${VM_NAMES[$i]}"
        local vm_ip="${VM_IPS[$i]}"

        if [[ "$vm_name" == *"controller"* ]]; then
            controller_ip="$vm_ip"
            controller_name="$vm_name"
            log "Controller: $vm_name ($vm_ip)"
        elif [[ "$vm_name" == *"compute"* ]]; then
            compute_ips+=("$vm_ip")
            log "Compute node: $vm_name ($vm_ip)"
        fi
    done

    if [[ -z "$controller_ip" ]]; then
        log_error "No controller VM found in cluster"
        return 1
    fi

    # Wait for SSH connectivity on controller
    log "Waiting for SSH connectivity on controller..."
    if ! wait_for_vm_ssh "$controller_ip" "$controller_name"; then
        log_error "SSH connectivity failed for controller"
        return 1
    fi

    # Calculate intended remote directory (maintain project structure)
    local project_basename
    project_basename="$(basename "$PROJECT_ROOT")"
    local suite_relative
    suite_relative="${FRAMEWORK_TEST_SCRIPTS_DIR#"$PROJECT_ROOT"/}"
    # shellcheck disable=SC2088
    local intended_remote_dir="~/$project_basename/$suite_relative"

    # Upload test scripts to controller (with fallback to /tmp if needed)
    log "Uploading BeeGFS test scripts to controller..."
    if ! upload_scripts_to_vm "$controller_ip" "$controller_name" "$FRAMEWORK_TEST_SCRIPTS_DIR" "$intended_remote_dir"; then
        log_error "Failed to upload test scripts to controller"
        return 1
    fi

    # Get actual directory used (might be /tmp fallback)
    local actual_suite_dir="$ACTUAL_REMOTE_DIR"
    log "Scripts uploaded to: $actual_suite_dir"

    # Copy SSH key to controller for inter-node SSH access
    log "Copying SSH key to controller for inter-node access..."
    local remote_ssh_dir="$actual_suite_dir/../.ssh"
    if ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        -i "$SSH_KEY_PATH" "$SSH_USER@$controller_ip" \
        "mkdir -p $remote_ssh_dir && chmod 700 $remote_ssh_dir" 2>/dev/null; then
        log_warn "Failed to create .ssh directory on controller, tests may fail if passwordless SSH not configured"
    else
        if ! scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
            -i "$SSH_KEY_PATH" "$SSH_KEY_PATH" "$SSH_USER@$controller_ip:$remote_ssh_dir/id_rsa" 2>/dev/null; then
            log_warn "Failed to copy SSH key to controller, tests may fail if passwordless SSH not configured"
        else
            # Set proper permissions on the copied key
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
                -i "$SSH_KEY_PATH" "$SSH_USER@$controller_ip" \
                "chmod 600 $remote_ssh_dir/id_rsa" 2>/dev/null || true
            log_success "SSH key copied to controller"
        fi
    fi

    # Build test arguments as a string
    local test_args="--controller $controller_ip"

    # Add compute nodes if any
    if [[ ${#compute_ips[@]} -gt 0 ]]; then
        local compute_csv
        compute_csv=$(IFS=,; echo "${compute_ips[*]}")
        test_args="$test_args --compute $compute_csv"
        log "Compute nodes: $compute_csv"
    else
        log_warn "No compute nodes found in cluster"
    fi

    # Add verbose flag if enabled
    [[ "${FRAMEWORK_VERBOSE:-false}" == "true" ]] && test_args="$test_args --verbose"

    # Execute master test script on controller from uploaded location
    log "Executing BeeGFS tests on controller..."
    local master_script_basename
    master_script_basename=$(basename "$FRAMEWORK_MASTER_TEST_SCRIPT")

    # Set SSH_KEY_PATH to the copied key location on the controller for inter-node SSH
    # Note: We keep the original SSH_KEY_PATH for connecting to the controller,
    # but pass the remote key path in the environment for the script to use
    local remote_ssh_key="$actual_suite_dir/../.ssh/id_rsa"

    # Pass the remote SSH key path as an environment variable
    # The test scripts will check for REMOTE_SSH_KEY_PATH first, then fall back to SSH_KEY_PATH
    export REMOTE_SSH_KEY_PATH="$remote_ssh_key"

    if ! execute_script_on_vm "$controller_ip" "$controller_name" "$master_script_basename" "$actual_suite_dir" "$test_args"; then
        unset REMOTE_SSH_KEY_PATH
        log_error "BeeGFS tests failed"
        return 1
    fi

    unset REMOTE_SSH_KEY_PATH

    log_success "BeeGFS tests completed successfully"
    return 0
}

# Framework-specific tests (required override)
run_framework_specific_tests() {
    log "Running ${FRAMEWORK_NAME}..."

    # Check if cluster is running, start if needed
    local cluster_name
    if ! cluster_name=$(parse_cluster_name "$FRAMEWORK_TEST_CONFIG" "${LOG_DIR}" "hpc"); then
        log_error "Failed to get cluster name from configuration"
        return 1
    fi

    # Check if cluster VMs are running
    local running_vms
    running_vms=$(virsh list --name --state-running | grep "^${cluster_name}" || true)

    if [[ -z "$running_vms" ]]; then
        log "Cluster not running, starting cluster..."
        if ! framework_start_cluster; then
            log_error "Failed to start cluster"
            return 1
        fi
        log_success "Cluster started successfully"
    else
        log "Cluster is already running"
    fi

    # Note: run-tests assumes cluster is already deployed
    # Use 'deploy-ansible' or 'e2e' commands to deploy configuration
    log "Skipping deployment (run-tests assumes cluster is already deployed)"
    log "Use 'deploy-ansible' command to deploy configuration if needed"

    # Run BeeGFS tests
    if ! run_beegfs_tests; then
        log_error "BeeGFS tests failed"
        return 1
    fi

    log_success "BeeGFS testing completed successfully"
    return 0
}

# Main
parse_framework_cli "$@"
COMMAND=$(get_framework_command)

case "$COMMAND" in
    "e2e"|"end-to-end") run_framework_e2e_workflow ;;
    "start-cluster") framework_start_cluster ;;
    "stop-cluster") framework_stop_cluster ;;
    "deploy-ansible")
        log "Deploying HPC cluster configuration via Makefile..."
        cd "$PROJECT_ROOT" && make hpc-cluster-deploy CLUSTER_CONFIG="$FRAMEWORK_TEST_CONFIG" ;;
    "run-tests") run_framework_specific_tests ;;
    "status") framework_get_cluster_status ;;
    "list-tests") find "$FRAMEWORK_TEST_SCRIPTS_DIR" -name "*.sh" -type f | head -20 ;;
    "help"|"--help") show_framework_help ;;
    *) run_framework_e2e_workflow ;;
esac
