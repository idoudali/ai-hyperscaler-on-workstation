#!/bin/bash
#
# Ansible Utilities
# Shared functions for Ansible and virtual environment management
#
# This utility provides common functions for:
# - Virtual environment setup and validation
# - Ansible installation and verification
# - Ansible deployment on clusters
#

# Prevent multiple sourcing
if [[ -n "${ANSIBLE_UTILS_SOURCED:-}" ]]; then
    return 0
fi
readonly ANSIBLE_UTILS_SOURCED=1

# =============================================================================
# Virtual Environment Management
# =============================================================================

# Check if virtual environment exists
check_venv_exists() {
    [[ -f "$PROJECT_ROOT/.venv/bin/activate" ]]
}

# Check if Ansible is properly installed in virtual environment
check_ansible_in_venv() {
    if ! check_venv_exists; then
        return 1
    fi

    # Temporarily activate venv and check for Ansible
    (
        # shellcheck source=/dev/null
        source "$PROJECT_ROOT/.venv/bin/activate" 2>/dev/null && \
        python3 -c "from ansible.cli.playbook import main" 2>/dev/null
    )
}

# Create virtual environment with all dependencies
create_virtual_environment() {
    log "Creating virtual environment with all dependencies..."

    if (cd "$PROJECT_ROOT" && make venv-create 2>&1 | tee -a "$LOG_DIR/venv-create.log"); then
        return 0
    else
        return 1
    fi
}

# Setup virtual environment for Ansible
# This is the main function that frameworks should call
setup_virtual_environment() {
    log "Setting up virtual environment for Ansible dependencies..."

    # Check if virtual environment exists and has Ansible
    if check_venv_exists; then
        log "Virtual environment exists, checking Ansible availability..."
        if check_ansible_in_venv; then
            log_success "Virtual environment with Ansible is ready"
            return 0
        else
            log_warning "Virtual environment exists but Ansible is not properly installed"
        fi
    fi

    # Create virtual environment with Ansible
    if create_virtual_environment; then
        log_success "Virtual environment created successfully"

        # Verify Ansible is now available
        if check_ansible_in_venv; then
            log_success "Ansible is now available in virtual environment"
            return 0
        else
            log_error "Ansible not found after virtual environment creation"
            return 1
        fi
    else
        log_error "Failed to create virtual environment"
        return 1
    fi
}

# Activate virtual environment and export paths
activate_virtual_environment() {
    if ! check_venv_exists; then
        log_error "Virtual environment does not exist. Run setup_virtual_environment first."
        return 1
    fi

    export VIRTUAL_ENV_PATH="$PROJECT_ROOT/.venv"
    export PATH="$VIRTUAL_ENV_PATH/bin:$PATH"

    # shellcheck source=/dev/null
    source "$VIRTUAL_ENV_PATH/bin/activate"

    log "Virtual environment activated: $VIRTUAL_ENV_PATH"
    return 0
}

# =============================================================================
# Ansible Deployment Functions
# =============================================================================

# Wait for cluster to be ready for Ansible deployment
wait_for_cluster_ready_ansible() {
    local config="$1"
    local vm_pattern="${2:-}"

    log "Waiting for cluster VMs to be accessible..."

    # Use existing wait_for_cluster_ready from cluster-utils if available
    if declare -f wait_for_cluster_ready >/dev/null 2>&1; then
        wait_for_cluster_ready "$config" "$vm_pattern"
    else
        log_error "wait_for_cluster_ready function not available. Source cluster-utils.sh first."
        return 1
    fi
}

# Deploy Ansible on running cluster
# Generic function that can be customized per framework
deploy_ansible_on_cluster() {
    local config="$1"

    log "Deploying via Ansible on running cluster..."

    # Setup virtual environment if not already done
    if ! check_ansible_in_venv; then
        if ! setup_virtual_environment; then
            log_error "Failed to setup virtual environment"
            return 1
        fi
    fi

    # Activate virtual environment
    if ! activate_virtual_environment; then
        log_error "Failed to activate virtual environment"
        return 1
    fi

    # Validate configuration file exists
    if [[ ! -f "$config" ]]; then
        log_error "Configuration file not found: $config"
        return 1
    fi

    # Use existing run_ansible_on_cluster if available
    if declare -f run_ansible_on_cluster >/dev/null 2>&1; then
        log "Running Ansible deployment..."
        run_ansible_on_cluster "$config"
    else
        log_error "run_ansible_on_cluster function not available. Source test-framework-utils.sh first."
        return 1
    fi
}

# Full Ansible deployment workflow
# Combines waiting for cluster + deploying Ansible
deploy_ansible_full_workflow() {
    local config="$1"
    local vm_pattern="${2:-}"

    log "Starting full Ansible deployment workflow..."

    # Wait for cluster to be ready
    if ! wait_for_cluster_ready_ansible "$config" "$vm_pattern"; then
        log_error "Cluster not ready for Ansible deployment"
        return 1
    fi

    # Deploy Ansible
    if ! deploy_ansible_on_cluster "$config"; then
        log_error "Ansible deployment failed"
        return 1
    fi

    log_success "Ansible deployment completed successfully"
    return 0
}

# =============================================================================
# Ansible Validation Functions
# =============================================================================

# Check if Ansible is available in current environment
check_ansible_available() {
    if command -v ansible-playbook >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get Ansible version
get_ansible_version() {
    if check_ansible_available; then
        ansible-playbook --version | head -1
    else
        echo "Ansible not found"
        return 1
    fi
}

# Validate Ansible installation
validate_ansible_installation() {
    log "Validating Ansible installation..."

    if ! check_ansible_available; then
        log_error "Ansible not found in PATH"
        return 1
    fi

    local version
    version=$(get_ansible_version)
    log_success "Ansible found: $version"

    return 0
}

# =============================================================================
# Utility Functions
# =============================================================================

# Clean up virtual environment
cleanup_virtual_environment() {
    if check_venv_exists; then
        log "Removing virtual environment..."
        rm -rf "$PROJECT_ROOT/.venv"
        log_success "Virtual environment removed"
    else
        log "No virtual environment found to clean up"
    fi
}

# Show virtual environment status
show_venv_status() {
    echo ""
    echo "Virtual Environment Status:"
    echo "============================"

    if check_venv_exists; then
        echo "  Status: EXISTS"
        echo "  Path: $PROJECT_ROOT/.venv"

        if check_ansible_in_venv; then
            echo "  Ansible: INSTALLED"
            local version
            version=$(cd "$PROJECT_ROOT" && source .venv/bin/activate && ansible-playbook --version | head -1)
            echo "  Version: $version"
        else
            echo "  Ansible: NOT INSTALLED"
        fi
    else
        echo "  Status: NOT FOUND"
        echo "  Run 'setup_virtual_environment' to create"
    fi

    echo ""
}

# Export functions for use in other scripts
export -f check_venv_exists
export -f check_ansible_in_venv
export -f create_virtual_environment
export -f setup_virtual_environment
export -f activate_virtual_environment
export -f wait_for_cluster_ready_ansible
export -f deploy_ansible_on_cluster
export -f deploy_ansible_full_workflow
export -f check_ansible_available
export -f get_ansible_version
export -f validate_ansible_installation
export -f cleanup_virtual_environment
export -f show_venv_status
