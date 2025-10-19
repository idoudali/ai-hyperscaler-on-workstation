#!/bin/bash
#
# Phase 4 Validation: Step 3 - Runtime Deployment
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_step_help() {
  cat << 'EOF'
Phase 4 Validation - Step 03: Runtime Deployment

Usage: ./step-03-runtime-deployment.sh [OPTIONS]

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
  log_step_title "03" "Runtime Playbook Deployment"

  if ! prerequisites_completed; then
    log_error "Prerequisites not completed"
    return 1
  fi

  if is_step_completed "step-03-runtime-deployment"; then
    log_warning "Step 03 already completed at $(get_step_completion_time 'step-03-runtime-deployment')"
    return 0
  fi

  init_state
  local step_dir="$VALIDATION_ROOT/03-runtime-playbook"
  create_step_dir "$step_dir"

  cd "$PROJECT_ROOT"

  log_info "3.1: Checking playbook syntax..."
  log_cmd "make run-docker COMMAND='ansible-playbook ansible/playbooks/playbook-hpc-runtime.yml --syntax-check'"
  if ! make run-docker COMMAND="ansible-playbook ansible/playbooks/playbook-hpc-runtime.yml --syntax-check" \
    > "$step_dir/syntax-check.log" 2>&1; then
    log_error "Playbook syntax check failed"
    tail -20 "$step_dir/syntax-check.log"
    return 1
  fi
  log_success "Playbook syntax valid"

  log_info "3.2: Generating Ansible inventory..."
  log_cmd "make cluster-inventory CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml CLUSTER_NAME=hpc"
  if ! make cluster-inventory \
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

  log_info "3.3: Validating cluster configuration..."
  log_cmd "uv run ai-how validate config/example-multi-gpu-clusters.yaml"
  if ! uv run ai-how validate "config/example-multi-gpu-clusters.yaml" \
    > "$step_dir/config-validation.log" 2>&1; then
    log_error "Configuration validation failed"
    tail -20 "$step_dir/config-validation.log"
    return 1
  fi
  log_success "Configuration valid"

  log_info "3.4: Starting cluster VMs (2-5 minutes)..."
  log_cmd "make cluster-start CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml CLUSTER_NAME=hpc"
  if ! make cluster-start \
    CLUSTER_CONFIG="config/example-multi-gpu-clusters.yaml" \
    CLUSTER_NAME="hpc" \
    > "$step_dir/cluster-start.log" 2>&1; then
    log_error "Cluster VM startup failed"
    tail -20 "$step_dir/cluster-start.log"
    return 1
  fi
  log_success "Cluster VMs started"

  log_info "3.5: Waiting for VMs to initialize (30 seconds)..."
  sleep 30

  log_info "Testing SSH connectivity..."
  log_cmd "make run-docker COMMAND='ansible all -i $TEST_INVENTORY -m ping'"
  make run-docker COMMAND="ansible all -i $TEST_INVENTORY -m ping" \
    > "$step_dir/ssh-connectivity.log" 2>&1 || {
    log_warning "SSH connectivity may need more time"
  }

  log_info "3.6: Deploying runtime configuration (10-20 minutes)..."
  log_cmd "make cluster-deploy INVENTORY_OUTPUT=$TEST_INVENTORY"
  if ! make cluster-deploy \
    INVENTORY_OUTPUT="$TEST_INVENTORY" \
    > "$step_dir/ansible-deploy.log" 2>&1; then
    log_error "Ansible deployment failed"
    grep -i "error\|fatal" "$step_dir/ansible-deploy.log" > "$step_dir/ansible-deploy-error.log" 2>/dev/null || true

    log_info "Stopping cluster after deployment failure..."
    log_cmd "make cluster-stop CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml CLUSTER_NAME=hpc"
    make cluster-stop CLUSTER_CONFIG="config/example-multi-gpu-clusters.yaml" CLUSTER_NAME="hpc" || true

    tail -30 "$step_dir/ansible-deploy.log"
    return 1
  fi
  log_success "Ansible deployment completed"

  log_info "3.7: Analyzing deployment results..."
  if grep -q "PLAY RECAP" "$step_dir/ansible-deploy.log"; then
    log_success "Ansible plays completed"

    if grep -A 20 "PLAY RECAP" "$step_dir/ansible-deploy.log" | grep -q "failed=0.*unreachable=0"; then
      log_success "No Ansible task failures"
    else
      log_warning "Some tasks may have issues - check logs"
    fi
  fi

  cat > "$step_dir/validation-summary.txt" << EOF
=== Step 03: Runtime Deployment ===
Timestamp: $(date)

✅ PASSED

Details:
- Playbook syntax: Valid
- Inventory: Generated
- Configuration: Valid
- VMs: Started
- Deployment: Successful

Cluster Status: Running (for Steps 4-5)

To stop cluster:
  make cluster-stop CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml CLUSTER_NAME=hpc

EOF

  mark_step_completed "step-03-runtime-deployment"
  log_success "Step 03 PASSED: Runtime deployment successful"
  cat "$step_dir/validation-summary.txt"

  return 0
}

main
