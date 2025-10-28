#!/bin/bash
# BeeGFS Test Framework - Refactored to use Phase 2 shared utilities
# Task: TASK-028 - Deploy BeeGFS Parallel Filesystem

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$PROJECT_ROOT/tests"
UTILS_DIR="$TESTS_DIR/test-infra/utils"

export PROJECT_ROOT TESTS_DIR SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa" SSH_USER="admin"

FRAMEWORK_NAME="BeeGFS Test Framework"
FRAMEWORK_DESCRIPTION="Parallel filesystem deployment and validation testing"
# shellcheck disable=SC2034
FRAMEWORK_TASK="TASK-028"
FRAMEWORK_TEST_CONFIG="$TESTS_DIR/test-infra/configs/test-beegfs.yaml"
FRAMEWORK_TEST_SCRIPTS_DIR="$TESTS_DIR/suites/beegfs"
FRAMEWORK_TARGET_VM_PATTERN="hpc"
# shellcheck disable=SC2034
FRAMEWORK_MASTER_TEST_SCRIPT="run-beegfs-tests.sh"
export FRAMEWORK_NAME FRAMEWORK_DESCRIPTION FRAMEWORK_TEST_CONFIG FRAMEWORK_TEST_SCRIPTS_DIR FRAMEWORK_TARGET_VM_PATTERN

# Source utilities
# shellcheck disable=SC1090
for util in log-utils.sh cluster-utils.sh ansible-utils.sh test-framework-utils.sh framework-cli.sh framework-orchestration.sh; do
    [[ -f "$UTILS_DIR/$util" ]] && source "$UTILS_DIR/$util"
done

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "beegfs"

# BeeGFS-specific deployment function
deploy_beegfs_ansible() {
    log "Deploying BeeGFS configuration via Ansible..."

    # Get cluster name from config
    local cluster_name
    if ! cluster_name=$(parse_cluster_name "$FRAMEWORK_TEST_CONFIG" "${LOG_DIR}" "hpc"); then
        log_error "Failed to get cluster name from configuration"
        return 1
    fi

    log "Cluster name: $cluster_name"

    # Generate Ansible inventory using shared utility
    local inventory="$PROJECT_ROOT/build/test-inventory-beegfs.yml"
    if ! generate_ansible_inventory "$inventory" "$cluster_name"; then
        log_error "Failed to generate Ansible inventory"
        return 1
    fi

    # Wait for SSH connectivity on all nodes
    if ! wait_for_inventory_nodes_ssh "$inventory" "all"; then
        log_error "SSH connectivity check failed"
        return 1
    fi

    local playbook="$PROJECT_ROOT/ansible/playbooks/playbook-beegfs-runtime-config.yml"

    if [[ ! -f "$playbook" ]]; then
        log_error "BeeGFS playbook not found: $playbook"
        return 1
    fi

    log "Running BeeGFS deployment playbook..."
    log "Inventory: $inventory"
    log "Playbook: $playbook"

    # Run Ansible playbook using uv (consistent with project pattern)
    if ! uv run ansible-playbook -i "$inventory" "$playbook" -v; then
        log_error "Ansible playbook execution failed"
        return 1
    fi

    log "BeeGFS deployment completed successfully"

    # Wait for services to stabilize
    log "Waiting for BeeGFS services to stabilize..."
    sleep 20

    return 0
}

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
    local compute_ips=()

    for i in "${!VM_IPS[@]}"; do
        local vm_name="${VM_NAMES[$i]}"
        local vm_ip="${VM_IPS[$i]}"

        if [[ "$vm_name" == *"controller"* ]]; then
            controller_ip="$vm_ip"
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

    log "Executing BeeGFS tests..."

    # Build test arguments
    local test_args=(
        --controller "$controller_ip"
    )

    # Add compute nodes if any
    if [[ ${#compute_ips[@]} -gt 0 ]]; then
        local compute_csv
        compute_csv=$(IFS=,; echo "${compute_ips[*]}")
        test_args+=(--compute "$compute_csv")
        log "Compute nodes: $compute_csv"
    else
        log_warn "No compute nodes found in cluster"
    fi

    # Add verbose flag if enabled
    [[ "${FRAMEWORK_VERBOSE:-false}" == "true" ]] && test_args+=(--verbose)

    # Execute test suite
    if ! "$master_test" "${test_args[@]}"; then
        log_error "BeeGFS tests failed"
        return 1
    fi

    log_success "BeeGFS tests completed successfully"
    return 0
}

# Framework-specific tests (required override)
run_framework_specific_tests() {
    log "Running ${FRAMEWORK_NAME}..."

    # Deploy BeeGFS first, then run tests
    if ! deploy_beegfs_ansible; then
        log_error "BeeGFS deployment failed"
        return 1
    fi

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
    "deploy-ansible") deploy_beegfs_ansible ;;
    "run-tests") run_framework_specific_tests ;;
    "status") framework_get_cluster_status ;;
    "list-tests") find "$FRAMEWORK_TEST_SCRIPTS_DIR" -name "*.sh" -type f | head -20 ;;
    "help"|"--help") show_framework_help ;;
    *) run_framework_e2e_workflow ;;
esac
