#!/bin/bash
# Virtio-FS Test Framework - Refactored to use Phase 2 shared utilities
# Task: TASK-027 - Implement Virtio-FS Host Directory Sharing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
UTILS_DIR="$TESTS_DIR/test-infra/utils"

export PROJECT_ROOT TESTS_DIR SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa" SSH_USER="admin"

FRAMEWORK_NAME="Virtio-FS Test Framework"
FRAMEWORK_DESCRIPTION="Host directory sharing and filesystem passthrough validation"
# shellcheck disable=SC2034
FRAMEWORK_TASK="TASK-027"
FRAMEWORK_TEST_CONFIG="$PROJECT_ROOT/config/example-multi-gpu-clusters.yaml"
FRAMEWORK_TEST_SCRIPTS_DIR="$TESTS_DIR/suites/virtio-fs"
FRAMEWORK_TARGET_VM_PATTERN="controller"
# shellcheck disable=SC2034
FRAMEWORK_MASTER_TEST_SCRIPT="run-virtio-fs-tests.sh"
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
init_logging "$TIMESTAMP" "logs" "virtio-fs"

# Virtio-FS-specific deployment
deploy_virtio_fs_ansible() {
    log "Deploying Virtio-FS configuration via Ansible..."

    # Get cluster name from config
    local cluster_name
    if ! cluster_name=$(parse_cluster_name "$FRAMEWORK_TEST_CONFIG" "${LOG_DIR}" "hpc"); then
        log_error "Failed to get cluster name from configuration"
        return 1
    fi

    log "Cluster name: $cluster_name"

    # Generate Ansible inventory
    local inventory="$PROJECT_ROOT/build/test-inventory-virtio-fs.yml"
    if ! generate_ansible_inventory "$inventory" "$cluster_name"; then
        log_error "Failed to generate Ansible inventory"
        return 1
    fi

    # Wait for SSH connectivity on controller (primary target for virtio-fs)
    if ! wait_for_inventory_nodes_ssh "$inventory" "controller"; then
        log_error "SSH connectivity check failed for controller"
        return 1
    fi

    local playbook="$PROJECT_ROOT/ansible/playbooks/playbook-hpc-runtime.yml"

    if [[ ! -f "$playbook" ]]; then
        log_error "Virtio-FS playbook not found: $playbook"
        return 1
    fi

    log "Running Virtio-FS deployment playbook..."
    log "Inventory: $inventory"
    log "Playbook: $playbook"

    # Run Ansible playbook from ansible directory to use ansible.cfg
    # This ensures roles_path is correctly set
    local ansible_dir="$PROJECT_ROOT/ansible"
    local playbook_relative="playbooks/playbook-hpc-runtime.yml"
    if ! (cd "$ansible_dir" && uv run ansible-playbook -i "$inventory" "$playbook_relative" -v --limit controller); then
        log_error "Ansible playbook execution failed"
        return 1
    fi

    log "Virtio-FS deployment completed successfully"

    # Wait for services to stabilize
    log "Waiting for Virtio-FS services to stabilize..."
    sleep 15

    return 0
}

# Virtio-FS-specific test execution
run_virtio_fs_tests() {
    log "Running Virtio-FS test suite..."

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

    # Find controller IP
    local controller_ip=""
    local controller_name=""

    for i in "${!VM_IPS[@]}"; do
        local vm_name="${VM_NAMES[$i]}"
        local vm_ip="${VM_IPS[$i]}"

        if [[ "$vm_name" == *"controller"* ]]; then
            controller_ip="$vm_ip"
            controller_name="$vm_name"
            log "Controller: $vm_name ($vm_ip)"
            break
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
    log "Uploading Virtio-FS test scripts to controller..."
    if ! upload_scripts_to_vm "$controller_ip" "$controller_name" "$FRAMEWORK_TEST_SCRIPTS_DIR" "$intended_remote_dir"; then
        log_error "Failed to upload test scripts to controller"
        return 1
    fi

    # Get actual directory used (might be /tmp fallback)
    local actual_suite_dir="$ACTUAL_REMOTE_DIR"
    log "Scripts uploaded to: $actual_suite_dir"

    # Build test arguments (virtio-fs test script doesn't accept --controller)
    local test_args=""

    # Add verbose flag if enabled
    [[ "${FRAMEWORK_VERBOSE:-false}" == "true" ]] && test_args="--verbose"

    # Execute master test script on controller from uploaded location
    log "Executing Virtio-FS tests on controller..."
    local master_script_basename
    master_script_basename=$(basename "$FRAMEWORK_MASTER_TEST_SCRIPT")

    if ! execute_script_on_vm "$controller_ip" "$controller_name" "$master_script_basename" "$actual_suite_dir" "$test_args"; then
        log_error "Virtio-FS tests failed"
        return 1
    fi

    log_success "Virtio-FS tests completed successfully"
    return 0
}

# Framework-specific tests
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

    # Run Virtio-FS tests
    if ! run_virtio_fs_tests; then
        log_error "Virtio-FS tests failed"
        return 1
    fi

    log_success "Virtio-FS testing completed successfully"
    return 0
}

# Main
parse_framework_cli "$@"
COMMAND=$(get_framework_command)

case "$COMMAND" in
    "e2e"|"end-to-end") run_framework_e2e_workflow ;;
    "start-cluster") framework_start_cluster ;;
    "stop-cluster") framework_stop_cluster ;;
    "deploy-ansible") deploy_virtio_fs_ansible ;;
    "run-tests") run_framework_specific_tests ;;
    "status") framework_get_cluster_status ;;
    "list-tests") find "$FRAMEWORK_TEST_SCRIPTS_DIR" -name "*.sh" -type f | head -20 ;;
    "help"|"--help") show_framework_help ;;
    *) run_framework_e2e_workflow ;;
esac
