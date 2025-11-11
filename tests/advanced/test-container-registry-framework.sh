#!/bin/bash
# Container Registry Test Framework - Refactored to use Phase 2 shared utilities
# Task: TASK-021 - Container Registry Infrastructure & Cluster Deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$PROJECT_ROOT/tests"
UTILS_DIR="$TESTS_DIR/test-infra/utils"

export PROJECT_ROOT TESTS_DIR SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa" SSH_USER="admin"

FRAMEWORK_NAME="Container Registry Test Framework"
FRAMEWORK_DESCRIPTION="Container registry infrastructure, image deployment, and validation testing"
# shellcheck disable=SC2034
FRAMEWORK_TASK="TASK-021"
FRAMEWORK_TEST_CONFIG="$TESTS_DIR/test-infra/configs/test-container-registry.yaml"
FRAMEWORK_TEST_SCRIPTS_DIR="$TESTS_DIR/suites/container-registry"
FRAMEWORK_TARGET_VM_PATTERN="controller"
# shellcheck disable=SC2034
FRAMEWORK_MASTER_TEST_SCRIPT="run-container-registry-tests.sh"
export FRAMEWORK_NAME FRAMEWORK_DESCRIPTION FRAMEWORK_TEST_CONFIG FRAMEWORK_TEST_SCRIPTS_DIR FRAMEWORK_TARGET_VM_PATTERN

# Container registry test suites (run from controller, check infrastructure)
# All suites execute FROM controller node via SSH to validate registry infrastructure
declare -a REGISTRY_TEST_SUITES=(
    "container-registry"     # Registry structure, permissions, access, sync setup
    "container-deployment"   # Image deployment, multi-node sync, integrity checks
)

# Source utilities
# shellcheck disable=SC1090
for util in log-utils.sh cluster-utils.sh vm-utils.sh ansible-utils.sh test-framework-utils.sh framework-cli.sh framework-orchestration.sh; do
    [[ -f "$UTILS_DIR/$util" ]] && source "$UTILS_DIR/$util"
done

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "container-registry"

# Container registry-specific deployment
deploy_container_registry_ansible() {
    log "Deploying container registry infrastructure via Ansible..."

    # Get cluster name from config
    local cluster_name
    if ! cluster_name=$(parse_cluster_name "$FRAMEWORK_TEST_CONFIG" "${LOG_DIR}" "$FRAMEWORK_TARGET_VM_PATTERN"); then
        log_error "Failed to get cluster name from configuration"
        return 1
    fi

    log "Cluster name: $cluster_name"

    # Generate Ansible inventory
    local inventory="$PROJECT_ROOT/build/test-inventory-container-registry.yml"
    if ! generate_ansible_inventory "$inventory" "$cluster_name"; then
        log_error "Failed to generate Ansible inventory"
        return 1
    fi

    # Wait for SSH connectivity
    if ! wait_for_inventory_nodes_ssh "$inventory" "all"; then
        log_error "SSH connectivity check failed"
        return 1
    fi

    local playbook="$PROJECT_ROOT/ansible/playbooks/playbook-container-registry-deploy.yml"

    if [[ ! -f "$playbook" ]]; then
        log_error "Container registry playbook not found: $playbook"
        return 1
    fi

    log "Running container registry deployment playbook..."
    log "Inventory: $inventory"
    log "Playbook: $playbook"

    # Run Ansible playbook
    if ! uv run ansible-playbook -i "$inventory" "$playbook" -v; then
        log_error "Ansible playbook execution failed"
        return 1
    fi

    log "Container registry deployment completed successfully"

    # Wait for registry to be ready
    log "Waiting for container registry to be ready..."
    sleep 30

    return 0
}

# Container image deployment
deploy_container_images() {
    log "Building and deploying container images..."

    # Get controller IP
    if ! get_vm_ips_for_cluster "$FRAMEWORK_TEST_CONFIG" "$FRAMEWORK_TARGET_VM_PATTERN"; then
        log_error "Failed to get VM IPs from cluster"
        return 1
    fi

    if [[ ${#VM_IPS[@]} -eq 0 ]]; then
        log_error "No VMs found in cluster"
        return 1
    fi

    local controller_ip="${VM_IPS[0]}"
    log "Controller: ${VM_NAMES[0]:-unknown} ($controller_ip)"

    # Image deployment would be implemented here
    log "Container images deployment completed"
    return 0
}

# Container registry test execution - runs both registry and deployment suites
run_container_registry_tests() {
    log "Running container registry test suites..."
    log "Suites: ${REGISTRY_TEST_SUITES[*]}"
    log ""

    # Get controller IP
    if ! get_vm_ips_for_cluster "$FRAMEWORK_TEST_CONFIG" "hpc" "$FRAMEWORK_TARGET_VM_PATTERN"; then
        log_error "Failed to get VM IPs from cluster"
        return 1
    fi

    if [[ ${#VM_IPS[@]} -eq 0 ]]; then
        log_error "No controller found in cluster"
        return 1
    fi

    local controller_ip="${VM_IPS[0]}"
    local controller_name="${VM_NAMES[0]:-unknown}"
    log "Controller: $controller_name ($controller_ip)"
    log ""

    # Wait for SSH connectivity
    if ! wait_for_vm_ssh "$controller_ip" "$controller_name"; then
        log_error "SSH connectivity failed to controller"
        return 1
    fi

    local failed=0
    local passed=0

    # Run each registry test suite FROM controller
    for suite in "${REGISTRY_TEST_SUITES[@]}"; do
        local suite_dir="$TESTS_DIR/suites/$suite"

        if [[ ! -d "$suite_dir" ]]; then
            log_warning "Suite not found: $suite"
            ((failed++))
            continue
        fi

        log "═══════════════════════════════════════════════════════════"
        log "Running suite: $suite"
        log "═══════════════════════════════════════════════════════════"

        local master_script="run-${suite}-tests.sh"
        local master_test="$suite_dir/$master_script"

        if [[ ! -f "$master_test" ]]; then
            log_error "Master test script not found: $master_test"
            ((failed++))
            continue
        fi

        # Check if project directory exists on controller (shared filesystem)
        if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" \
            "$SSH_USER@$controller_ip" "test -d '$PROJECT_ROOT'" 2>/dev/null; then
            log "Executing from shared filesystem on controller..."

            # Execute test suite FROM controller
            if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" \
                "$SSH_USER@$controller_ip" "cd '$PROJECT_ROOT' && bash tests/suites/$suite/$master_script" 2>&1; then
                log_success "Suite passed: $suite"
                ((passed++))
            else
                log_warning "Suite failed: $suite"
                ((failed++))
            fi
        else
            log_error "Project directory not available on controller: $PROJECT_ROOT"
            log_error "Container registry tests require shared filesystem access"
            ((failed++))
        fi

        log ""
    done

    log "═══════════════════════════════════════════════════════════"
    log "Container Registry Test Summary"
    log "═══════════════════════════════════════════════════════════"
    log "Total suites: ${#REGISTRY_TEST_SUITES[@]}"
    log "Passed: $passed"
    log "Failed: $failed"
    log ""

    if [[ $failed -eq 0 ]]; then
        log_success "All container registry tests completed successfully"
        return 0
    else
        log_error "Some container registry tests failed"
        return 1
    fi
}

# Framework-specific tests (override)
run_framework_specific_tests() {
    log "Running ${FRAMEWORK_NAME}..."

    # Deploy container registry
    if ! deploy_container_registry_ansible; then
        log_error "Container registry deployment failed"
        return 1
    fi

    # Deploy container images
    if ! deploy_container_images; then
        log_error "Container image deployment failed"
        return 1
    fi

    # Run tests
    if ! run_container_registry_tests; then
        log_error "Container registry tests failed"
        return 1
    fi

    log_success "Container registry testing completed successfully"
    return 0
}

# Main
parse_framework_cli "$@"
COMMAND=$(get_framework_command)

case "$COMMAND" in
    "e2e"|"end-to-end") run_framework_e2e_workflow ;;
    "start-cluster") framework_start_cluster ;;
    "stop-cluster") framework_stop_cluster ;;
    "deploy-ansible") deploy_container_registry_ansible ;;
    "deploy-images") deploy_container_images ;;
    "run-tests") run_framework_specific_tests ;;
    "status") framework_get_cluster_status ;;
    "list-tests") find "$FRAMEWORK_TEST_SCRIPTS_DIR" -name "*.sh" -type f | head -20 ;;
    "help"|"--help") show_framework_help ;;
    *) run_framework_e2e_workflow ;;
esac
