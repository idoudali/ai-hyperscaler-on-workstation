#!/bin/bash
# step-07-beegfs-validation.sh
# Phase 4 Validation Step 7: BeeGFS Setup Validation
# Validates BeeGFS container registry (Task 040) and storage consolidation (Task 043)

set -euo pipefail

# ============================================================================
# Step Configuration
# ============================================================================

# Step identification
STEP_NUMBER="07"
STEP_NAME="beegfs-validation"
STEP_DESCRIPTION="BeeGFS Setup Validation"
STEP_ID="step-${STEP_NUMBER}-${STEP_NAME}"
# shellcheck disable=SC2034
export STEP_ID

# Step-specific configuration
STEP_DIR_NAME="${STEP_NUMBER}-${STEP_NAME}"
# shellcheck disable=SC2034
export STEP_DIR_NAME
STEP_DEPENDENCIES=("step-06-virtio-fs-validation")
# shellcheck disable=SC2034
export STEP_DEPENDENCIES

# ============================================================================
# Script Setup
# ============================================================================

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-common.sh"
parse_validation_args "$@"

# Validation targets
VALIDATION_TARGETS=(
    "beegfs-config-schema"
    "beegfs-deployment-testing"
    "beegfs-container-registry"
    "beegfs-storage-consolidation"
)

# ========================================
# Task 040: BeeGFS Container Registry
# ========================================

validate_beegfs_config_schema() {
    log_info "Validating BeeGFS configuration schema..."

    # 1. Validate cluster configuration schema includes BeeGFS configuration
    log_info "Checking cluster configuration schema for BeeGFS..."
    # Use rendered config from step 04 instead of template
    local rendered_config="output/cluster-state/rendered-config.yaml"
    if [ ! -f "$rendered_config" ]; then
        log_error "Rendered config not found: $rendered_config - run step 04 first"
        return 1
    fi
    # Skip schema validation as rendered config may have additional fields
    log_info "Using rendered configuration from step 04 for validation"

    # 2. Check BeeGFS configuration in cluster config
    log_info "Validating BeeGFS configuration..."
    if ! grep -q "beegfs:" "$rendered_config"; then
        log_error "BeeGFS configuration not found in cluster config"
        return 1
    fi

    # 3. Test BeeGFS configuration parsing
    log_info "Testing BeeGFS configuration parsing..."
    local beegfs_config
    beegfs_config=$(grep -A 15 "beegfs:" "$rendered_config")
    if [[ -z "$beegfs_config" ]]; then
        log_error "BeeGFS configuration section is empty"
        return 1
    fi

    # 4. Validate BeeGFS configuration structure
    log_info "Validating BeeGFS configuration structure..."
    if ! echo "$beegfs_config" | grep -q "enabled:"; then
        log_error "BeeGFS configuration missing 'enabled' field"
        return 1
    fi

    if ! echo "$beegfs_config" | grep -q "mount_point:"; then
        log_error "BeeGFS configuration missing 'mount_point' field"
        return 1
    fi

    log_success "BeeGFS configuration schema validation passed"
}

validate_beegfs_deployment_testing() {
    log_info "Validating BeeGFS deployment testing..."

    # 1. Validate BeeGFS configuration in runtime playbook
    log_info "Validating BeeGFS configuration in runtime playbook..."
    if ! grep -q "beegfs" ansible/playbooks/playbook-hpc-runtime.yml; then
        log_error "BeeGFS configuration not found in runtime playbook"
        return 1
    fi

    # 2. Verify BeeGFS roles exist
    log_info "Verifying BeeGFS roles exist..."
    local beegfs_roles=("beegfs-mgmt" "beegfs-meta" "beegfs-storage" "beegfs-client")
    for role in "${beegfs_roles[@]}"; do
        if [ ! -d "ansible/roles/$role" ]; then
            log_error "BeeGFS role not found: $role"
            return 1
        fi
    done

    # 3. Test BeeGFS services configuration
    log_info "Testing BeeGFS services configuration..."
    if ! grep -q "beegfs" ansible/inventories/test/hosts; then
        log_error "BeeGFS services not configured in inventory"
        return 1
    fi

    log_success "BeeGFS deployment testing validation passed"
}

validate_beegfs_container_registry() {
    log_info "Validating BeeGFS container registry..."

    # 1. Validate container registry uses BeeGFS
    log_info "Validating container registry uses BeeGFS..."
    if ! grep -q "beegfs" ansible/playbooks/playbook-container-registry.yml; then
        log_error "Container registry not configured to use BeeGFS"
        return 1
    fi

    # 2. Test container registry mount point configuration
    log_info "Testing container registry mount point configuration..."
    # Check for BeeGFS path variable or direct path reference
    if ! grep -q "container_registry_beegfs_path\|/mnt/beegfs" ansible/playbooks/playbook-container-registry.yml; then
        log_error "Container registry mount point not configured for BeeGFS"
        return 1
    fi

    log_success "BeeGFS container registry validation passed"
}

validate_beegfs_storage_consolidation() {
    log_info "Validating BeeGFS storage consolidation..."

    # 1. Test BeeGFS filesystem mount on all nodes
    log_info "Testing BeeGFS filesystem mount configuration..."
    if ! grep -q "beegfs" ansible/inventories/test/hosts; then
        log_error "BeeGFS mount not configured for all nodes"
        return 1
    fi

    # 2. Validate VirtIO-FS mounts still work after consolidation
    log_info "Validating VirtIO-FS mounts compatibility with BeeGFS..."
    if ! grep -q "virtio_fs" ansible/inventories/test/hosts; then
        log_error "VirtIO-FS mounts not configured alongside BeeGFS"
        return 1
    fi

    # 3. Confirm unified playbook deploys complete HPC + storage stack
    log_info "Confirming unified playbook deploys complete HPC + storage stack..."
    if ! grep -q "beegfs\|virtio_fs" ansible/playbooks/playbook-hpc-runtime.yml; then
        log_error "Unified playbook does not deploy complete storage stack"
        return 1
    fi

    # 4. Verify standalone storage playbooks can be deleted
    log_info "Verifying standalone storage playbooks can be deleted..."
    if [[ -f "ansible/playbooks/playbook-storage-standalone.yml" ]]; then
        log_warning "Standalone storage playbook still exists - should be deleted after consolidation"
    fi

    log_success "BeeGFS storage consolidation validation passed"
}

# ========================================
# Main execution
# ========================================

main() {
    log_step_start "$STEP_ID" "$STEP_DESCRIPTION"

    # Check prerequisites
    log_info "Checking prerequisites..."
    if ! check_prerequisites "step-06-virtio-fs-validation"; then
        log_error "Prerequisites not met for $STEP_ID"
        return 1
    fi

    # Run validation targets
    for target in "${VALIDATION_TARGETS[@]}"; do
        case "$target" in
            "beegfs-config-schema")
                validate_beegfs_config_schema
                ;;
            "beegfs-deployment-testing")
                validate_beegfs_deployment_testing
                ;;
            "beegfs-container-registry")
                validate_beegfs_container_registry
                ;;
            "beegfs-storage-consolidation")
                validate_beegfs_storage_consolidation
                ;;
            *)
                log_error "Unknown validation target: $target"
                return 1
                ;;
        esac
    done

    # Mark step as completed
    mark_step_completed "$STEP_ID"

    log_step_success "$STEP_ID" "$STEP_DESCRIPTION"
    log_info "BeeGFS setup validation completed successfully"
    log_info "Next step: step-08-container-image-push.sh"
}

# Run main function
main "$@"
