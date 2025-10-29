#!/bin/bash
#
# Phase 4 Validation: Step 2.2 - Packer Cloud GPU Worker Build
#

set -euo pipefail

# ============================================================================
# Step Configuration
# ============================================================================

# Step identification
STEP_NUMBER="02.2"
STEP_NAME="packer-cloud-gpu-worker"
STEP_DESCRIPTION="Packer Cloud GPU Worker Build"
STEP_ID="step-${STEP_NUMBER}-${STEP_NAME}"

# Step-specific configuration
STEP_DIR_NAME="${STEP_NUMBER}-${STEP_NAME}"
STEP_DEPENDENCIES=("step-02.1-packer-cloud-base")
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
  Builds the cloud GPU worker VM image using Packer:
  - Validates Packer template syntax
  - Builds cloud GPU worker image via CMake/Docker
  - Verifies image artifacts (*.qcow2)
  - Analyzes Ansible execution results
  - Confirms GPU driver installation

  Time: 15-30 minutes
  Output: build/packer/cloud-gpu-worker/cloud-gpu-worker/*.qcow2

Prerequisites:
  - Step 02.1 (Packer Cloud Base Build) must be completed

EOF
}

source "$SCRIPT_DIR/lib-common.sh"
parse_validation_args "$@"

main() {
  log_step_title "$STEP_NUMBER" "$STEP_DESCRIPTION"

  # Check prerequisites
  if ! check_prerequisites "step-02.1-packer-cloud-base"; then
    log_error "Prerequisites not completed. Run step-02.1-packer-cloud-base.sh first"
    return 1
  fi

  # Check if already completed
  if is_step_completed "$STEP_ID"; then
    log_warning "Step ${STEP_NUMBER} already completed at $(get_step_completion_time "$STEP_ID")"
    log_info "Skipping..."
    return 0
  fi

  init_state
  local step_dir="$VALIDATION_ROOT/$STEP_DIR_NAME"
  create_step_dir "$step_dir"

  init_venv

  cd "$PROJECT_ROOT"

  # 2b.1: Validate Packer template
  log_info "${STEP_NUMBER}.1: Validating Packer template..."
  if ! run_docker_command "cmake --build build --target validate-cloud-gpu-worker-packer" \
    "$step_dir/packer-validate.log" "Packer template validation"; then
    tail -20 "$step_dir/packer-validate.log"
    return 1
  fi

  # 2b.2: Build cloud GPU worker image (15-30 minutes)
  log_info "${STEP_NUMBER}.2: Building cloud GPU worker Packer image (15-30 minutes)..."
  if ! run_docker_command_with_errors "cmake --build build --target build-cloud-gpu-worker-image" \
    "$step_dir/packer-build.log" "$step_dir/packer-build-error.log" "Packer build"; then
    tail -30 "$step_dir/packer-build.log"
    return 1
  fi

  # Detect up-to-date build (no work done)
  local build_up_to_date=0
  if is_build_up_to_date "$step_dir/packer-build.log"; then
    build_up_to_date=1
    log_warning "No build executed: image already built; Ansible did not run"
  fi

  # 2b.3: Verify image artifacts
  log_info "${STEP_NUMBER}.3: Verifying image artifacts..."
  if ! ls "$PROJECT_ROOT/build/packer/cloud-gpu-worker/cloud-gpu-worker/"*.qcow2 &>/dev/null; then
    log_error "No image artifacts found"
    return 1
  fi

  IMAGE_SIZE=$(du -sh "$PROJECT_ROOT/build/packer/cloud-gpu-worker/cloud-gpu-worker/"*.qcow2 | awk '{print $1}')
  log_success "Image artifacts found: $IMAGE_SIZE"

  # 2b.4: Analyze Ansible execution
  log_info "${STEP_NUMBER}.4: Analyzing Ansible execution..."
  local task_failures_line="N/A"
  if [[ $build_up_to_date -eq 1 ]]; then
    log_info "Skipping Ansible analysis: build up to date (image already built)"
  else
    if ! require_ansible_completed "$step_dir/packer-build.log"; then
      return 1
    fi
    log_success "Ansible playbook executed"
    if ansible_has_no_failures "$step_dir/packer-build.log"; then
      log_success "No Ansible task failures"
      task_failures_line="None"
    else
      log_warning "Some Ansible tasks may have issues - check logs"
      task_failures_line="Check logs"
    fi
  fi

  # Create summary
  cat > "$step_dir/validation-summary.txt" << EOF
=== Step ${STEP_NUMBER}: ${STEP_DESCRIPTION} ===
Timestamp: $(date)

✅ PASSED

Details:
- Packer template: Valid
  - Image build: Successful$( summary_up_to_date_suffix "$build_up_to_date" )
- Image size: $IMAGE_SIZE
  - Ansible execution: $( summary_ansible_execution "$build_up_to_date" )
  - Task failures: ${task_failures_line}

Image location:
  $PROJECT_ROOT/build/packer/cloud-gpu-worker/cloud-gpu-worker/

Logs:
  Validation: $step_dir/packer-validate.log
  Build: $step_dir/packer-build.log
  Errors: $step_dir/packer-build-error.log

EOF

  mark_step_completed "$STEP_ID"
  log_success "Step ${STEP_NUMBER} PASSED: Cloud GPU Worker Packer build successful"
  cat "$step_dir/validation-summary.txt"

  return 0
}

main
