#!/bin/bash
#
# Phase 4 Validation: Step 5.1 - Cloud Cluster Deployment
#

set -euo pipefail

# ============================================================================
# Step Configuration
# ============================================================================

# Step identification
STEP_NUMBER="05.1"
STEP_NAME="cloud-cluster-deployment"
STEP_DESCRIPTION="Cloud Cluster Deployment"
STEP_ID="step-${STEP_NUMBER}-${STEP_NAME}"

# Step-specific configuration
STEP_DIR_NAME="${STEP_NUMBER}-${STEP_NAME}"
STEP_DEPENDENCIES=("step-05-runtime-deployment")
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
  Deploys and validates the Cloud cluster Kubernetes deployment:
  - Checks playbook syntax
  - Generates Ansible inventory for cloud cluster
  - Validates cluster configuration
  - Verifies cloud cluster VMs exist (no start)
  - Tests SSH connectivity
  - Deploys Kubernetes using Kubespray
  - Analyzes deployment results

  Time: 15-30 minutes
  Cluster: Remains running for subsequent steps

Prerequisites:
  - Step 05 (HPC Runtime Deployment) must be completed

EOF
}

source "$SCRIPT_DIR/lib-common.sh"
parse_validation_args "$@"

main() {
  log_step_title "$STEP_NUMBER" "$STEP_DESCRIPTION"

  if ! check_prerequisites "step-05-runtime-deployment"; then
    log_error "Prerequisites not completed. Run step-05-runtime-deployment.sh first"
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

  log_info "${STEP_NUMBER}.0: Ensuring Kubespray is available (CMake target: install-kubespray)..."
  log_cmd "make run-docker COMMAND=\"cmake --build build --target install-kubespray\""
  if make run-docker COMMAND="cmake --build build --target install-kubespray" \
    > "$step_dir/install-kubespray.log" 2>&1; then
    if grep -qi "no work to do" "$step_dir/install-kubespray.log"; then
      log_success "Kubespray already installed (no work to do)"
    else
      log_success "Kubespray installed/downloaded"
    fi
  else
    log_error "Failed to run CMake target install-kubespray"
    tail -30 "$step_dir/install-kubespray.log" || true
    return 1
  fi

  log_info "${STEP_NUMBER}.1: Checking playbook syntax..."
  if ! run_docker_command "ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbooks/playbook-cloud-runtime.yml --syntax-check" \
    "$step_dir/syntax-check.log" "Playbook syntax check"; then
    tail -20 "$step_dir/syntax-check.log"
    return 1
  fi

  log_info "${STEP_NUMBER}.2: Generating Ansible inventory for cloud cluster..."
  log_cmd "make cloud-cluster-inventory CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml CLOUD_CLUSTER_NAME=cloud INVENTORY_OUTPUT=ansible/inventories/test/cloud-hosts"
  if ! make cloud-cluster-inventory \
    CLUSTER_CONFIG="config/example-multi-gpu-clusters.yaml" \
    CLOUD_CLUSTER_NAME="cloud" \
    INVENTORY_OUTPUT="ansible/inventories/test/cloud-hosts" \
    > "$step_dir/inventory-generation.log" 2>&1; then
    log_error "Cloud cluster inventory generation failed"
    tail -20 "$step_dir/inventory-generation.log"
    return 1
  fi
  log_success "Cloud cluster inventory generated"

  local CLOUD_TEST_INVENTORY="ansible/inventories/test/cloud-hosts"

  log_info "${STEP_NUMBER}.3: Validating cloud cluster configuration..."
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

  log_info "${STEP_NUMBER}.4: Verifying cloud cluster VMs exist (no start) ..."
  log_cmd "make cloud-cluster-status CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml"
  if ! make cloud-cluster-status \
    CLUSTER_CONFIG="config/example-multi-gpu-clusters.yaml" \
    > "$step_dir/cloud-cluster-status.log" 2>&1; then
    log_error "Cloud cluster not found or VMs not created"
    tail -20 "$step_dir/cloud-cluster-status.log" || true
    return 1
  fi
  log_success "Cloud cluster VMs detected (GPU VM may be stopped, which is OK)"

  log_info "${STEP_NUMBER}.5: Waiting for VMs to initialize (30 seconds)..."
  sleep 30

  log_info "Testing SSH connectivity..."
  if ! run_docker_command "ansible all -i $CLOUD_TEST_INVENTORY -m ping" \
    "$step_dir/ssh-connectivity.log" "SSH connectivity test"; then
    log_warning "SSH connectivity may need more time"
  fi

  log_info "${STEP_NUMBER}.6: Deploying Kubernetes to cloud cluster (15-30 minutes)..."
  log_cmd "make cloud-cluster-deploy CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml INVENTORY_OUTPUT=$CLOUD_TEST_INVENTORY"
  if ! make cloud-cluster-deploy \
    CLUSTER_CONFIG="config/example-multi-gpu-clusters.yaml" \
    INVENTORY_OUTPUT="$CLOUD_TEST_INVENTORY" \
    > "$step_dir/kubespray-deploy.log" 2>&1; then
    log_error "Kubernetes deployment failed"
    grep -i "error\|fatal" "$step_dir/kubespray-deploy.log" > "$step_dir/kubespray-deploy-error.log" 2>/dev/null || true

    log_error "======================================================================"
    log_error "Kubernetes deployment failed - Cloud cluster left running for debugging"
    log_error "======================================================================"
    log_error ""
    log_error "Error summary:"
    tail -30 "$step_dir/kubespray-deploy.log"
    log_error ""
    log_error "Log files saved to: $step_dir/"
    log_error "  - Full deployment log: kubespray-deploy.log"
    log_error "  - Error summary: kubespray-deploy-error.log"
    log_error ""
    log_error "To inspect the failed deployment:"
    log_error "  1. Review logs: tail -100 $step_dir/kubespray-deploy.log"
    log_error "  2. Connect to cluster: ssh <node-name>"
    log_error "  3. Re-run specific tasks for debugging"
    log_error ""
    log_error "To stop the cloud cluster when done debugging:"
    log_error "  make cloud-cluster-stop CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml"
    log_error ""

    return 1
  fi
  log_success "Kubernetes deployment completed"

  log_info "${STEP_NUMBER}.7: Analyzing deployment results..."
  if grep -q "PLAY RECAP" "$step_dir/kubespray-deploy.log"; then
    log_success "Ansible plays completed"

    if grep -A 20 "PLAY RECAP" "$step_dir/kubespray-deploy.log" | grep -q "failed=0.*unreachable=0"; then
      log_success "No Ansible task failures"
    else
      log_warning "Some tasks may have issues - check logs"
    fi
  fi

  cat > "$step_dir/validation-summary.txt" << EOF
=== Step ${STEP_NUMBER}: ${STEP_DESCRIPTION} ===
Timestamp: $(date)

✅ PASSED

Details:
- Playbook syntax: Valid
- Inventory: Generated
- Configuration: Valid
- VMs: Present (cloud VMs detected)
- Kubernetes deployment: Successful

Cluster Status: Running (for subsequent steps)

To stop cloud cluster:
  make cloud-cluster-stop CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml

EOF

  mark_step_completed "$STEP_ID"
  log_success "Step ${STEP_NUMBER} PASSED: Cloud cluster deployment successful"
  cat "$step_dir/validation-summary.txt"

  return 0
}

main
