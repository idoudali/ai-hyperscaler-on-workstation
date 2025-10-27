#!/bin/bash
#
# Phase 4 Validation: Step 5 - Runtime Deployment
#

set -euo pipefail

# ============================================================================
# Step Configuration
# ============================================================================

# Step identification
STEP_NUMBER="05"
STEP_NAME="runtime-deployment"
STEP_DESCRIPTION="Runtime Deployment"
STEP_ID="step-${STEP_NUMBER}-${STEP_NAME}"

# Step-specific configuration
STEP_DIR_NAME="${STEP_NUMBER}-${STEP_NAME}"
STEP_DEPENDENCIES=("step-00-prerequisites")
# shellcheck disable=SC2034
export STEP_DEPENDENCIES

# ============================================================================
# Script Setup
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_step_help() {
  cat << EOF
Phase 4 Validation - Step ${STEP_NUMBER}: ${STEP_DESCRIPTION}

Usage: ./${STEP_ID}.sh [OPTIONS]

Options:
  -v, --verbose                 Enable verbose command logging
  --log-level LEVEL             Set log level (DEBUG, INFO)
  --validation-folder PATH      Resume from existing validation directory
  -h, --help                    Show this help message

Description:
  Deploys and validates the HPC runtime configuration:
  - Checks playbook syntax
  - Generates Ansible inventory
  - Validates cluster configuration
  - Starts cluster VMs
  - Tests SSH connectivity
  - Deploys runtime configuration
  - Analyzes deployment results

  Time: 10-20 minutes
  Cluster: Remains running for Steps 4-5

EOF
}

source "$SCRIPT_DIR/lib-common.sh"
parse_validation_args "$@"

main() {
  log_step_title "$STEP_NUMBER" "$STEP_DESCRIPTION"

  if ! prerequisites_completed; then
    log_error "Prerequisites not completed"
    return 1
  fi

  if is_step_completed "$STEP_ID"; then
    log_warning "Step ${STEP_NUMBER} already completed at $(get_step_completion_time "$STEP_ID")"
    return 0
  fi

  init_state
  local step_dir="$VALIDATION_ROOT/$STEP_DIR_NAME"
  create_step_dir "$step_dir"

  init_venv

  cd "$PROJECT_ROOT"

  log_info "${STEP_NUMBER}.1: Checking playbook syntax..."
  if ! run_docker_command "ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbooks/playbook-hpc-runtime.yml --syntax-check" \
    "$step_dir/syntax-check.log" "Playbook syntax check"; then
    tail -20 "$step_dir/syntax-check.log"
    return 1
  fi

  log_info "${STEP_NUMBER}.2: Generating Ansible inventory..."
  log_cmd "make hpc-cluster-inventory CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml CLUSTER_NAME=hpc"
  if ! make hpc-cluster-inventory \
    CLUSTER_CONFIG="config/example-multi-gpu-clusters.yaml" \
    CLUSTER_NAME="hpc" \
    INVENTORY_OUTPUT="ansible/inventories/test/hosts" \
    > "$step_dir/inventory-generation.log" 2>&1; then
    log_error "Inventory generation failed"
    tail -20 "$step_dir/inventory-generation.log"
    return 1
  fi
  log_success "Inventory generated"

  local TEST_INVENTORY="ansible/inventories/test/hosts"

  log_info "${STEP_NUMBER}.3: Validating cluster configuration..."
  local rendered_config="$VALIDATION_ROOT/04-config-rendering/rendered-config.yaml"
  if [[ ! -f "$rendered_config" ]]; then
    log_error "Rendered configuration not found at $rendered_config"
    return 1
  fi
  log_cmd "uv run ai-how validate $rendered_config"
  if ! uv run ai-how validate "$rendered_config" \
    > "$step_dir/config-validation.log" 2>&1; then
    log_error "Configuration validation failed"
    tail -20 "$step_dir/config-validation.log"
    return 1
  fi
  log_success "Configuration valid"

  log_info "${STEP_NUMBER}.4: Starting cluster VMs (2-5 minutes)..."
  log_cmd "make system-start CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml"
  if ! make system-start \
    CLUSTER_CONFIG="config/example-multi-gpu-clusters.yaml" \
    > "$step_dir/cluster-start.log" 2>&1; then
    log_error "Cluster VM startup failed"
    tail -20 "$step_dir/cluster-start.log"
    return 1
  fi
  log_success "Cluster VMs started"

  log_info "${STEP_NUMBER}.5: Waiting for VMs to initialize (30 seconds)..."
  sleep 30

  log_info "Testing SSH connectivity..."
  if ! run_docker_command "ansible all -i $TEST_INVENTORY -m ping" \
    "$step_dir/ssh-connectivity.log" "SSH connectivity test"; then
    log_warning "SSH connectivity may need more time"
  fi

  log_info "${STEP_NUMBER}.6: Deploying runtime configuration (10-20 minutes)..."
  log_cmd "make hpc-cluster-deploy INVENTORY_OUTPUT=$TEST_INVENTORY"
  if ! make hpc-cluster-deploy \
    INVENTORY_OUTPUT="$TEST_INVENTORY" \
    > "$step_dir/ansible-deploy.log" 2>&1; then
    log_error "Ansible deployment failed"
    grep -i "error\|fatal" "$step_dir/ansible-deploy.log" > "$step_dir/ansible-deploy-error.log" 2>/dev/null || true

    log_error "======================================================================"
    log_error "Ansible deployment failed - Cluster left running for debugging"
    log_error "======================================================================"
    log_error ""
    log_error "Error summary:"
    tail -30 "$step_dir/ansible-deploy.log"
    log_error ""
    log_error "Log files saved to: $step_dir/"
    log_error "  - Full deployment log: ansible-deploy.log"
    log_error "  - Error summary: ansible-deploy-error.log"
    log_error ""
    log_error "To inspect the failed deployment:"
    log_error "  1. Review logs: tail -100 $step_dir/ansible-deploy.log"
    log_error "  2. Connect to cluster: ssh <node-name>"
    log_error "  3. Re-run specific tasks for debugging"
    log_error ""
    log_error "To destroy the cluster when done debugging:"
    log_error "  make system-stop CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml"
    log_error ""

    return 1
  fi
  log_success "Ansible deployment completed"

  log_info "${STEP_NUMBER}.7: Analyzing deployment results..."
  if grep -q "PLAY RECAP" "$step_dir/ansible-deploy.log"; then
    log_success "Ansible plays completed"

    if grep -A 20 "PLAY RECAP" "$step_dir/ansible-deploy.log" | grep -q "failed=0.*unreachable=0"; then
      log_success "No Ansible task failures"
    else
      log_warning "Some tasks may have issues - check logs"
    fi
  fi

  cat > "$step_dir/validation-summary.txt" << EOF
=== Step 05: Runtime Deployment ===
Timestamp: $(date)

✅ PASSED

Details:
- Playbook syntax: Valid
- Inventory: Generated
- Configuration: Valid
- VMs: Started
- Deployment: Successful

Cluster Status: Running (for Steps 5-7)

To stop cluster:
  make system-stop CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml

EOF

  mark_step_completed "$STEP_ID"
  log_success "Step ${STEP_NUMBER} PASSED: Runtime deployment successful"
  cat "$step_dir/validation-summary.txt"

  return 0
}

main
