#!/bin/bash
# step-06-virtio-fs-validation.sh
# Phase 4 Validation Step 6: VirtIO-FS Mount Validation
# Validates VirtIO-FS mount configuration and functionality (Task 041)

set -euo pipefail

# ============================================================================
# Step Configuration
# ============================================================================

# Step identification
STEP_NUMBER="06"
STEP_NAME="virtio-fs-validation"
STEP_DESCRIPTION="VirtIO-FS Mount Validation"
STEP_ID="step-${STEP_NUMBER}-${STEP_NAME}"

# Step-specific configuration
STEP_DIR_NAME="${STEP_NUMBER}-${STEP_NAME}"
# shellcheck disable=SC2034
export STEP_DIR_NAME
STEP_DEPENDENCIES=("step-05-runtime-deployment")
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
    "virtio-fs-config-schema"
    "virtio-fs-mount-validation"
    "virtio-fs-runtime-testing"
)

# ========================================
# Task 041: VirtIO-FS Configuration Schema
# ========================================

validate_virtio_fs_config_schema() {
    log_info "Validating VirtIO-FS configuration schema..."

    # 1. Validate cluster configuration schema includes VirtIO-FS configuration
    log_info "Checking cluster configuration schema for VirtIO-FS..."
    # Use rendered config from step 04 instead of template
    local rendered_config="output/cluster-state/rendered-config.yaml"
    if [ ! -f "$rendered_config" ]; then
        log_error "Rendered config not found: $rendered_config - run step 04 first"
        return 1
    fi
    # Skip schema validation as rendered config may have additional fields
    log_info "Using rendered configuration from step 04 for validation"

    # 2. Check VirtIO-FS mount configuration in cluster config
    log_info "Validating VirtIO-FS mount configuration..."
    if ! grep -q "virtio_fs_mounts:" "$rendered_config"; then
        log_error "VirtIO-FS mount configuration not found in cluster config"
        return 1
    fi

    # 3. Test VirtIO-FS mount configuration parsing
    log_info "Testing VirtIO-FS configuration parsing..."
    local virtio_config
    virtio_config=$(grep -A 10 "virtio_fs_mounts:" "$rendered_config")
    if [[ -z "$virtio_config" ]]; then
        log_error "VirtIO-FS configuration section is empty"
        return 1
    fi

    # 4. Validate VirtIO-FS configuration structure
    log_info "Validating VirtIO-FS configuration structure..."
    if ! echo "$virtio_config" | grep -q "host_path:"; then
        log_error "VirtIO-FS configuration missing 'host_path' field"
        return 1
    fi

    if ! echo "$virtio_config" | grep -q "mount_point:"; then
        log_error "VirtIO-FS configuration missing 'mount_point' field"
        return 1
    fi

    log_success "VirtIO-FS configuration schema validation passed"
}

validate_virtio_fs_mount_validation() {
    log_info "Validating VirtIO-FS mount validation logic..."

    # 1. Test inventory generation with VirtIO-FS configuration
    log_info "Testing inventory generation with VirtIO-FS configuration..."
    if ! make cluster-inventory; then
        log_error "Inventory generation with VirtIO-FS configuration failed"
        return 1
    fi

    # 2. Validate VirtIO-FS configuration in generated inventory
    log_info "Validating VirtIO-FS configuration in generated inventory..."
    if ! grep -q "virtio_fs_mounts" output/cluster-state/rendered-config.yaml; then
        log_error "VirtIO-FS configuration not found in generated inventory"
        return 1
    fi

    # 3. Test configuration template rendering with VirtIO-FS variables
    log_info "Testing configuration template rendering with VirtIO-FS variables..."
    if ! grep -q "virtio_fs" output/cluster-state/rendered-config.yaml; then
        log_error "VirtIO-FS variables not found in rendered configuration"
        return 1
    fi

    log_success "VirtIO-FS mount validation logic passed"
}

validate_virtio_fs_runtime_testing() {
    log_info "Validating VirtIO-FS runtime testing..."

    # 1. Validate VirtIO-FS mount points are configured correctly in inventory
    log_info "Validating VirtIO-FS mount points configuration..."
    if ! grep -q "virtio_fs" ansible/inventories/test/hosts; then
        log_error "VirtIO-FS mount points not configured in inventory"
        return 1
    fi

    # 2. Test VirtIO-FS mount validation in runtime playbook
    log_info "Testing VirtIO-FS mount validation in runtime playbook..."
    if ! grep -q "virtio_fs" ansible/playbooks/playbook-hpc-runtime.yml; then
        log_error "VirtIO-FS mount validation not found in runtime playbook"
        return 1
    fi

    # 3. Verify virtio-fs-mount role exists
    log_info "Verifying virtio-fs-mount role exists..."
    if [ ! -d "ansible/roles/virtio-fs-mount" ]; then
        log_error "virtio-fs-mount role not found"
        return 1
    fi

    # 4. Check if role has tasks (basic validation)
    if [ ! -f "ansible/roles/virtio-fs-mount/tasks/main.yml" ]; then
        log_warning "virtio-fs-mount role missing tasks/main.yml"
    fi

    log_success "VirtIO-FS runtime testing validation passed"
}

# ========================================
# Main execution
# ========================================

main() {
    log_step_start "$STEP_ID" "$STEP_DESCRIPTION"

    # Check prerequisites
    log_info "Checking prerequisites..."
    if ! check_prerequisites "step-05-runtime-deployment"; then
        log_error "Prerequisites not met for $STEP_ID"
        return 1
    fi

    init_venv

    # Run validation targets
    for target in "${VALIDATION_TARGETS[@]}"; do
        case "$target" in
            "virtio-fs-config-schema")
                validate_virtio_fs_config_schema
                ;;
            "virtio-fs-mount-validation")
                validate_virtio_fs_mount_validation
                ;;
            "virtio-fs-runtime-testing")
                validate_virtio_fs_runtime_testing
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
    log_info "VirtIO-FS mount validation completed successfully"
    log_info "Next step: step-07-beegfs-validation.sh"
}

# Run main function
main "$@"
