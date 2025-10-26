#!/bin/bash
# Virtio-FS Test Framework - Refactored to use Phase 2 shared utilities
# Task: TASK-027 - Implement Virtio-FS Host Directory Sharing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$PROJECT_ROOT/tests"
UTILS_DIR="$TESTS_DIR/test-infra/utils"

export PROJECT_ROOT TESTS_DIR SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa" SSH_USER="admin"

FRAMEWORK_NAME="Virtio-FS Test Framework"
FRAMEWORK_DESCRIPTION="Host directory sharing and filesystem passthrough validation"
# shellcheck disable=SC2034
FRAMEWORK_TASK="TASK-027"
FRAMEWORK_TEST_CONFIG="$TESTS_DIR/test-infra/configs/test-virtio-fs.yaml"
FRAMEWORK_TEST_SCRIPTS_DIR="$TESTS_DIR/suites/virtio-fs"
FRAMEWORK_TARGET_VM_PATTERN="test-hpc-virtio-fs-controller"
# shellcheck disable=SC2034
FRAMEWORK_MASTER_TEST_SCRIPT="run-virtio-fs-tests.sh"
export FRAMEWORK_NAME FRAMEWORK_DESCRIPTION FRAMEWORK_TEST_CONFIG FRAMEWORK_TEST_SCRIPTS_DIR FRAMEWORK_TARGET_VM_PATTERN

# Source utilities
# shellcheck disable=SC1090
for util in log-utils.sh cluster-utils.sh ansible-utils.sh test-framework-utils.sh framework-cli.sh framework-orchestration.sh; do
    [[ -f "$UTILS_DIR/$util" ]] && source "$UTILS_DIR/$util"
done

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "virtio-fs"

# Virtio-FS-specific deployment
deploy_virtio_fs_ansible() {
    log "Deploying Virtio-FS configuration via Ansible..."

    # Get cluster name from config
    local cluster_name
    if ! cluster_name=$(parse_cluster_name "$FRAMEWORK_TEST_CONFIG" "${LOG_DIR}" "$FRAMEWORK_TARGET_VM_PATTERN"); then
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

    # Wait for SSH connectivity
    if ! wait_for_inventory_nodes_ssh "$inventory" "all"; then
        log_error "SSH connectivity check failed"
        return 1
    fi

    local playbook="$PROJECT_ROOT/ansible/playbooks/playbook-virtio-fs-runtime-config.yml"

    if [[ ! -f "$playbook" ]]; then
        log_error "Virtio-FS playbook not found: $playbook"
        return 1
    fi

    log "Running Virtio-FS deployment playbook..."
    log "Inventory: $inventory"
    log "Playbook: $playbook"

    # Run Ansible playbook
    if ! uv run ansible-playbook -i "$inventory" "$playbook" -v; then
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

    # Use shared utility to get VM IPs
    if ! get_vm_ips_for_cluster "$FRAMEWORK_TEST_CONFIG" "$FRAMEWORK_TARGET_VM_PATTERN"; then
        log_error "Failed to get VM IPs from cluster"
        return 1
    fi

    if [[ ${#VM_IPS[@]} -eq 0 ]]; then
        log_error "No VMs found in cluster"
        return 1
    fi

    log "Found ${#VM_IPS[@]} VM(s) in cluster"

    # Get controller IP
    local controller_ip="${VM_IPS[0]}"
    log "Controller: ${VM_NAMES[0]:-unknown} ($controller_ip)"

    # Run master test script
    local master_test="$FRAMEWORK_TEST_SCRIPTS_DIR/$FRAMEWORK_MASTER_TEST_SCRIPT"

    if [[ ! -f "$master_test" ]]; then
        log_error "Master test script not found: $master_test"
        return 1
    fi

    # Make executable if needed
    if [[ ! -x "$master_test" ]]; then
        chmod +x "$master_test" || {
            log_error "Failed to make test script executable: $master_test"
            return 1
        }
    fi

    log "Executing Virtio-FS tests..."

    # Build test arguments
    local test_args=(
        --controller "$controller_ip"
    )

    # Add verbose flag if enabled
    [[ "${FRAMEWORK_VERBOSE:-false}" == "true" ]] && test_args+=(--verbose)

    # Execute test suite
    if ! "$master_test" "${test_args[@]}"; then
        log_error "Virtio-FS tests failed"
        return 1
    fi

    log_success "Virtio-FS tests completed successfully"
    return 0
}

# Framework-specific tests
run_framework_specific_tests() {
    log "Running ${FRAMEWORK_NAME}..."

    # Deploy Virtio-FS first, then run tests
    if ! deploy_virtio_fs_ansible; then
        log_error "Virtio-FS deployment failed"
        return 1
    fi

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
