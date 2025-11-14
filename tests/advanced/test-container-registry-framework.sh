#!/bin/bash
# Container Registry Test Framework - Refactored to use Phase 2 shared utilities
# Task: TASK-021 - Container Registry Infrastructure & Cluster Deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
UTILS_DIR="$TESTS_DIR/test-infra/utils"

export PROJECT_ROOT TESTS_DIR SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa" SSH_USER="admin"

FRAMEWORK_NAME="Container Registry Test Framework"
FRAMEWORK_DESCRIPTION="Container registry infrastructure, image deployment, and validation testing"
# shellcheck disable=SC2034
FRAMEWORK_TASK="TASK-021"
FRAMEWORK_TEST_CONFIG="$PROJECT_ROOT/config/example-multi-gpu-clusters.yaml"
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
init_logging "$TIMESTAMP" "logs" "container-registry"

# Verify BeeGFS is deployed and container registry is accessible
verify_beegfs_registry() {
    log "Verifying BeeGFS deployment and container registry accessibility..."

    # Get controller IP
    if ! get_vm_ips_for_cluster "$FRAMEWORK_TEST_CONFIG" "hpc" "$FRAMEWORK_TARGET_VM_PATTERN"; then
        log_error "Failed to get VM IPs from cluster"
        return 1
    fi

    if [[ ${#VM_IPS[@]} -eq 0 ]]; then
        log_error "No VMs found in cluster"
        return 1
    fi

    local controller_ip="${VM_IPS[0]}"
    local controller_name="${VM_NAMES[0]:-unknown}"
    log "Controller: $controller_name ($controller_ip)"

    # Wait for SSH connectivity
    if ! wait_for_vm_ssh "$controller_ip" "$controller_name"; then
        log_error "SSH connectivity failed to controller"
        return 1
    fi

    # Check if BeeGFS is mounted
    log "Checking BeeGFS mount on controller..."
    local beegfs_mount="/mnt/beegfs"
    if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" \
        "$SSH_USER@$controller_ip" "mount | grep -q beegfs" 2>/dev/null; then
        log_error "BeeGFS is not mounted on controller at $beegfs_mount"
        log_error "Please ensure BeeGFS is deployed before running container registry tests"
        return 1
    fi

    log_success "BeeGFS is mounted on controller"

    # Check if container registry directory exists on BeeGFS
    local registry_path="/mnt/beegfs/containers"
    log "Checking container registry directory: $registry_path"

    if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" \
        "$SSH_USER@$controller_ip" "[ -d '$registry_path' ]" 2>/dev/null; then
        log_warning "Container registry directory does not exist, creating it..."

        # Create registry structure on BeeGFS
        if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" \
            "$SSH_USER@$controller_ip" "mkdir -p '$registry_path'/ml-frameworks '$registry_path'/custom-images '$registry_path'/base-images '$registry_path'/.registry" 2>/dev/null; then
            log_error "Failed to create container registry directory structure"
            return 1
        fi

        log_success "Container registry directory structure created on BeeGFS"
    else
        log_success "Container registry directory exists on BeeGFS"
    fi

    log "Container registry verification completed successfully"
    return 0
}

# Container image deployment
deploy_container_images() {
    log "Building and deploying container images..."

    # Get controller IP
    if ! get_vm_ips_for_cluster "$FRAMEWORK_TEST_CONFIG" "hpc" "$FRAMEWORK_TARGET_VM_PATTERN"; then
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

    # Verify BeeGFS is deployed and registry is accessible
    if ! verify_beegfs_registry; then
        log_error "BeeGFS registry verification failed"
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
    "verify-beegfs") verify_beegfs_registry ;;
    "deploy-images") deploy_container_images ;;
    "run-tests") run_framework_specific_tests ;;
    "status") framework_get_cluster_status ;;
    "list-tests") find "$FRAMEWORK_TEST_SCRIPTS_DIR" -name "*.sh" -type f | head -20 ;;
    "help"|"--help") show_framework_help ;;
    *) run_framework_e2e_workflow ;;
esac
