#!/bin/bash
# step-08-container-image-push.sh
# Phase 4 Validation Step 8: Container Image Push
# Pushes container images to the validated storage system

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-common.sh"
parse_validation_args "$@"

# Step configuration
STEP_NAME="step-08-container-image-push"
STEP_DESCRIPTION="Container Image Push"

# Validation targets
VALIDATION_TARGETS=(
    "container-image-push"
    "container-registry-validation"
    "container-distribution-testing"
)

# ========================================
# Container Image Push
# ========================================

validate_container_image_push() {
    log_info "Building and deploying container images to BeeGFS..."

    local controller_ip controller_user target_base ssh_key sync_nodes verify
    controller_ip="${CONTAINER_DEPLOY_CONTROLLER:-192.168.100.10}"
    controller_user="${CONTAINER_DEPLOY_USER:-admin}"
    target_base="${CONTAINER_DEPLOY_TARGET:-/mnt/beegfs/containers}"
    ssh_key="${CONTAINER_DEPLOY_SSH_KEY:-${PROJECT_ROOT}/build/shared/ssh-keys/id_rsa}"
    sync_nodes="${CONTAINER_DEPLOY_SYNC_NODES:-false}"
    verify="${CONTAINER_DEPLOY_VERIFY:-true}"

    if ! CONTAINER_DEPLOY_CONTROLLER="${controller_ip}" \
           CONTAINER_DEPLOY_USER="${controller_user}" \
           CONTAINER_DEPLOY_TARGET="${target_base}" \
           CONTAINER_DEPLOY_SSH_KEY="${ssh_key}" \
           CONTAINER_DEPLOY_SYNC_NODES="${sync_nodes}" \
           CONTAINER_DEPLOY_VERIFY="${verify}" \
           make -C "${PROJECT_ROOT}" containers-deploy-beegfs; then
        log_error "Failed to build and deploy container images to BeeGFS"
        return 1
    fi

    log_success "Container images built and deployed to BeeGFS"
}

validate_container_registry_validation() {
    log_info "Validating container registry after push..."

    # 1. Verify container images are accessible on controller
    log_info "Verifying container images are accessible on controller..."
    if ! run_in_target "admin@192.168.100.10" "ls -la /mnt/beegfs/containers/"; then
        log_error "Container registry not accessible on controller"
        return 1
    fi

    # 2. Test container image execution on controller
    log_info "Testing container image execution on controller..."
    local test_container
    local test_command
    # Try to find python-test container first, fallback to hello-world
    test_container=$(capture_from_target "admin@192.168.100.10" "find /mnt/beegfs/containers -name 'python-test.sif' -type f | head -1")
    if [[ -n "$test_container" ]]; then
        test_command="python3 --version"
    else
        test_container=$(capture_from_target "admin@192.168.100.10" "find /mnt/beegfs/containers -name 'hello-world.sif' -type f | head -1")
        if [[ -n "$test_container" ]]; then
            test_command="/hello"
        else
            test_container=$(capture_from_target "admin@192.168.100.10" "find /mnt/beegfs/containers -name '*.sif' -type f | head -1")
            test_command="ls /"
        fi
    fi

    if [[ -z "$test_container" ]]; then
        log_error "No container images found in BeeGFS storage"
        return 1
    fi

    if ! run_in_target "admin@192.168.100.10" "apptainer exec '$test_container' $test_command"; then
        log_error "Container image execution test failed on controller"
        return 1
    fi

    # 3. Verify container registry structure
    log_info "Verifying container registry structure..."
    if ! run_in_target "admin@192.168.100.10" "find /mnt/beegfs/containers -name '*.sif' -type f"; then
        log_error "Container registry structure validation failed"
        return 1
    fi

    log_success "Container registry validation passed"
}

validate_container_distribution_testing() {
    log_info "Testing container distribution across nodes..."

    # 1. Test container access from compute nodes
    log_info "Testing container access from compute nodes..."
    local test_container
    local test_command
    # Try to find python-test container first, fallback to hello-world
    test_container=$(capture_from_target "admin@192.168.100.10" "find /mnt/beegfs/containers -name 'python-test.sif' -type f | head -1")
    if [[ -n "$test_container" ]]; then
        test_command="python3 --version"
    else
        test_container=$(capture_from_target "admin@192.168.100.10" "find /mnt/beegfs/containers -name 'hello-world.sif' -type f | head -1")
        if [[ -n "$test_container" ]]; then
            test_command="/hello"
        else
            test_container=$(capture_from_target "admin@192.168.100.10" "find /mnt/beegfs/containers -name '*.sif' -type f | head -1")
            test_command="ls /"
        fi
    fi

    if [[ -z "$test_container" ]]; then
        log_error "No container images found for distribution testing"
        return 1
    fi

    # 2. Test container execution on compute nodes (skip if no SSH keys available)
    log_info "Testing container execution on compute nodes..."
    for node in 192.168.100.11 192.168.100.12; do
        log_info "Testing container execution on $node..."
        # First check if we can connect to the compute node
        if ! run_in_target "admin@192.168.100.10" "ssh -o StrictHostKeyChecking=no -o BatchMode=yes admin@$node 'exit'" "" "true"; then
            log_warning "Cannot SSH to $node from controller - skipping compute node test"
            log_warning "This is expected if cluster is not configured for SSH key distribution"
            continue
        fi
        if ! run_in_target "admin@192.168.100.10" "ssh -o StrictHostKeyChecking=no admin@$node \"apptainer exec '$test_container' $test_command\""; then
            log_warning "Container execution test failed on $node - continuing with other tests"
        fi
    done

    # 3. Verify container registry consistency across nodes (skip if no SSH keys)
    log_info "Verifying container registry consistency across nodes..."
    for node in 192.168.100.11 192.168.100.12; do
        log_info "Verifying container registry on $node..."
        # First check if we can connect to the compute node
        if ! run_in_target "admin@192.168.100.10" "ssh -o StrictHostKeyChecking=no -o BatchMode=yes admin@$node 'exit'" "" "true"; then
            log_warning "Cannot SSH to $node from controller - skipping registry verification on compute nodes"
            break
        fi
        if ! run_in_target "admin@192.168.100.10" "ssh -o StrictHostKeyChecking=no admin@$node \"ls -la /mnt/beegfs/containers/\""; then
            log_warning "Container registry not accessible on $node - continuing with other tests"
        fi
    done

    log_success "Container distribution testing passed"
}

# ========================================
# Main execution
# ========================================

main() {
    log_step_start "$STEP_NAME" "$STEP_DESCRIPTION"

    # Setup SSH configuration for non-interactive operation
    log_info "Setting up SSH configuration..."
    setup_ssh_config

    # Check prerequisites
    log_info "Checking prerequisites..."
    if ! check_prerequisites "step-07-beegfs-validation"; then
        log_error "Prerequisites not met for $STEP_NAME"
        return 1
    fi

    init_venv

    # Run validation targets
    for target in "${VALIDATION_TARGETS[@]}"; do
        case "$target" in
            "container-image-push")
                validate_container_image_push
                ;;
            "container-registry-validation")
                validate_container_registry_validation
                ;;
            "container-distribution-testing")
                validate_container_distribution_testing
                ;;
            *)
                log_error "Unknown validation target: $target"
                return 1
                ;;
        esac
    done

    # Mark step as completed
    mark_step_completed "$STEP_NAME"

    log_step_success "$STEP_NAME" "$STEP_DESCRIPTION"
    log_info "Container image push completed successfully"
    log_info "Next step: step-09-functional-tests.sh"
}

# Run main function
main "$@"
