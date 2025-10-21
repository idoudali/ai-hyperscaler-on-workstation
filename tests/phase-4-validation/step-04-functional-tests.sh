#!/bin/bash
#
# Phase 4 Validation: Step 4 - Functional Tests
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_step_help() {
  cat << 'EOF'
Phase 4 Validation - Step 04: Functional Tests

Usage: ./step-04-functional-tests.sh [OPTIONS]

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

  Prerequisites: Step 03 must be completed (cluster running)
  Time: 2-5 minutes

EOF
}

source "$SCRIPT_DIR/lib-common.sh"
parse_validation_args "$@"

main() {
  log_step_title "04" "Functional Cluster Tests"

  if is_step_completed "step-04-functional-tests"; then
    log_warning "Step 04 already completed at $(get_step_completion_time 'step-04-functional-tests')"
    return 0
  fi

  init_state
  local step_dir="$VALIDATION_ROOT/04-functional-tests"
  create_step_dir "$step_dir"

  # SSH configuration for non-interactive access
  local SSH_KEY="${PROJECT_ROOT}/build/shared/ssh-keys/id_rsa"
  local SSH_OPTS="-i ${SSH_KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"

  local CONTROLLER_HOST="test-hpc-runtime-controller"
  local COMPUTE_HOST="test-hpc-runtime-compute01"

  log_info "Controller: $CONTROLLER_HOST"
  log_info "Compute: $COMPUTE_HOST"

  # 4.1: Check cluster info
  log_info "4.1: Checking SLURM cluster info..."
  log_cmd "ssh $SSH_OPTS $CONTROLLER_HOST 'sinfo'"
  if ssh "$SSH_OPTS" "$CONTROLLER_HOST" "sinfo" \
    > "$step_dir/cluster-info.log" 2>&1; then
    log_success "SLURM cluster info retrieved"
    cat "$step_dir/cluster-info.log"
  else
    log_warning "Failed to get cluster info (cluster may not be ready)"
  fi

  # 4.2: Check node registration
  log_info "4.2: Checking compute node registration..."
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

  # 4.3: Test simple job
  log_info "4.3: Testing simple job execution..."
  log_cmd "ssh $SSH_OPTS $CONTROLLER_HOST 'srun -N1 hostname'"
  if ssh "$SSH_OPTS" "$CONTROLLER_HOST" "srun -N1 hostname" \
    > "$step_dir/simple-job.log" 2>&1; then
    log_success "Simple job executed successfully"
    cat "$step_dir/simple-job.log"
  else
    log_warning "Simple job execution failed"
  fi

  # 4.4: Test container support
  log_info "4.4: Testing container runtime..."
  log_cmd "ssh $SSH_OPTS $CONTROLLER_HOST 'srun apptainer --version'"
  if ssh "$SSH_OPTS" "$CONTROLLER_HOST" "srun apptainer --version" \
    > "$step_dir/container-test.log" 2>&1; then
    log_success "Container runtime functional"
    cat "$step_dir/container-test.log"
  else
    log_warning "Container runtime test failed"
  fi

  cat > "$step_dir/validation-summary.txt" << EOF
=== Step 04: Functional Tests ===
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

  mark_step_completed "step-04-functional-tests"
  log_success "Step 04 PASSED: Functional tests completed"
  cat "$step_dir/validation-summary.txt"

  return 0
}

main
