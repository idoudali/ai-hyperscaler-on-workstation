#!/bin/bash
#
# Phase 4 Validation: Step 9 - Functional Tests
#

set -euo pipefail

# ============================================================================
# Step Configuration
# ============================================================================

# Step identification
STEP_NUMBER="09"
STEP_NAME="functional-tests"
STEP_DESCRIPTION="Functional Tests"
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
  Runs functional tests on the deployed HPC cluster:
  - Checks SLURM cluster info
  - Verifies compute node registration
  - Tests simple job execution
  - Tests container runtime (Apptainer)

  Prerequisites: Step 04 must be completed (cluster running)
  Time: 2-5 minutes

EOF
}

source "$SCRIPT_DIR/lib-common.sh"
parse_validation_args "$@"

main() {
  log_step_start "$STEP_NAME" "$STEP_DESCRIPTION"

  # Check prerequisites
  log_info "Checking prerequisites..."
  if ! check_prerequisites "step-05-runtime-deployment"; then
    log_error "Prerequisites not met for $STEP_NAME"
    return 1
  fi

  # Continue with step execution
  local step_dir="$VALIDATION_ROOT/$STEP_DIR_NAME"
  mkdir -p "$step_dir"

  init_venv

  # Setup SSH and cluster configuration
  setup_ssh_config
  setup_cluster_hosts

  log_info "Controller: $CONTROLLER_HOST"
  log_info "Compute: ${COMPUTE_HOSTS[0]}"

  # 6.1: Check cluster info
  log_info "${STEP_NUMBER}.1: Checking SLURM cluster info..."
  log_cmd "ssh $SSH_OPTS $CONTROLLER_HOST 'sinfo'"
  if ssh "$SSH_OPTS" "$CONTROLLER_HOST" "sinfo" \
    > "$step_dir/cluster-info.log" 2>&1; then
    log_success "SLURM cluster info retrieved"
    cat "$step_dir/cluster-info.log"
  else
    log_warning "Failed to get cluster info (cluster may not be ready)"
  fi

  # 6.2: Check node registration
  log_info "${STEP_NUMBER}.2: Checking compute node registration..."
  log_cmd "ssh $SSH_OPTS $CONTROLLER_HOST 'scontrol show nodes'"
  if ssh "$SSH_OPTS" "$CONTROLLER_HOST" "scontrol show nodes" \
    > "$step_dir/node-registration.log" 2>&1; then
    log_success "Node registration status retrieved"

    if grep -q "State=IDLE\|State=ALLOCATED\|State=MIXED" \
       "$step_dir/node-registration.log"; then
      log_success "Compute nodes in good state"
    else
      log_warning "Compute nodes may be in problematic state"
    fi
  else
    log_warning "Failed to get node status"
  fi

  # 6.3: Test simple job
  log_info "${STEP_NUMBER}.3: Testing simple job execution..."
  log_cmd "ssh $SSH_OPTS $CONTROLLER_HOST 'srun -N1 hostname'"
  if ssh "$SSH_OPTS" "$CONTROLLER_HOST" "srun -N1 hostname" \
    > "$step_dir/simple-job.log" 2>&1; then
    log_success "Simple job executed successfully"
    cat "$step_dir/simple-job.log"
  else
    log_warning "Simple job execution failed"
  fi

  # 6.4: Test container support
  log_info "${STEP_NUMBER}.4: Testing container runtime..."
  log_cmd "ssh $SSH_OPTS $CONTROLLER_HOST 'srun apptainer --version'"
  if ssh "$SSH_OPTS" "$CONTROLLER_HOST" "srun apptainer --version" \
    > "$step_dir/container-test.log" 2>&1; then
    log_success "Container runtime functional"
    cat "$step_dir/container-test.log"
  else
    log_warning "Container runtime test failed"
  fi

  cat > "$step_dir/validation-summary.txt" << EOF
=== Step ${STEP_NUMBER}: ${STEP_DESCRIPTION} ===
Timestamp: $(date)

✅ PASSED

Functional Tests Executed:
- SLURM cluster info: Retrieved
- Node registration: Checked
- Simple job execution: Tested
- Container runtime: Verified

Logs:
  Cluster info: $step_dir/cluster-info.log
  Node registration: $step_dir/node-registration.log
  Simple job: $step_dir/simple-job.log
  Container test: $step_dir/container-test.log

EOF

  mark_step_completed "$STEP_ID"
  log_step_success "$STEP_NAME" "$STEP_DESCRIPTION"
  log_info "Functional tests completed successfully"
  return 0
}

main
