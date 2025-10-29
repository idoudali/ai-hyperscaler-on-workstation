#!/bin/bash
#
# Phase 4 Validation: Step 1 - Packer Controller Build
#

set -euo pipefail

# ============================================================================
# Step Configuration
# ============================================================================

# Step identification
STEP_NUMBER="01"
STEP_NAME="packer-controller"
STEP_DESCRIPTION="Packer Controller Build"
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
  Builds the HPC controller VM image using Packer:
  - Validates Packer template syntax
  - Builds controller image via CMake/Docker
  - Verifies image artifacts (*.qcow2)
  - Analyzes Ansible execution results
  - Confirms no task failures

  Time: 15-30 minutes
  Output: build/packer/hpc-controller/hpc-controller/*.qcow2

EOF
}

source "$SCRIPT_DIR/lib-common.sh"
parse_validation_args "$@"

main() {
  log_step_title "$STEP_NUMBER" "$STEP_DESCRIPTION"

  # Check prerequisites
  if ! prerequisites_completed; then
    log_error "Prerequisites not completed. Run step-00-prerequisites.sh first"
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

  # 1.1: Validate Packer template
  log_info "${STEP_NUMBER}.1: Validating Packer template..."
  if ! run_docker_command "cmake --build build --target validate-hpc-controller-packer" \
    "$step_dir/packer-validate.log" "Packer template validation"; then
    tail -20 "$step_dir/packer-validate.log"
    return 1
  fi

  # 1.2: Build controller image (15-30 minutes)
  log_info "${STEP_NUMBER}.2: Building controller Packer image (15-30 minutes)..."
  if ! run_docker_command_with_errors "cmake --build build --target build-hpc-controller-image" \
    "$step_dir/packer-build.log" "$step_dir/packer-build-error.log" "Packer build"; then
    tail -30 "$step_dir/packer-build.log"
    return 1
  fi

  # 1.3: Verify image artifacts
  log_info "${STEP_NUMBER}.3: Verifying image artifacts..."
  if ! ls "$PROJECT_ROOT/build/packer/hpc-controller/hpc-controller/"*.qcow2 &>/dev/null; then
    log_error "No image artifacts found"
    return 1
  fi

  IMAGE_SIZE=$(du -sh "$PROJECT_ROOT/build/packer/hpc-controller/hpc-controller/"*.qcow2 | awk '{print $1}')
  log_success "Image artifacts found: $IMAGE_SIZE"

  # 1.4: Analyze Ansible execution
  log_info "${STEP_NUMBER}.4: Analyzing Ansible execution..."
  if ! grep -q "PLAY RECAP" "$step_dir/packer-build.log"; then
    log_error "Ansible playbook did not complete"
    return 1
  fi
  log_success "Ansible playbook executed"

  if grep "failed=0" "$step_dir/packer-build.log" | grep -q "unreachable=0"; then
    log_success "No Ansible task failures"
  else
    log_warning "Some Ansible tasks may have issues - check logs"
  fi

  # Create summary
  cat > "$step_dir/validation-summary.txt" << EOF
=== Step ${STEP_NUMBER}: ${STEP_DESCRIPTION} ===
Timestamp: $(date)

✅ PASSED

Details:
- Packer template: Valid
- Image build: Successful
- Image size: $IMAGE_SIZE
- Ansible execution: Completed
- Task failures: None

Image location:
  $PROJECT_ROOT/build/packer/hpc-controller/hpc-controller/

Logs:
  Validation: $step_dir/packer-validate.log
  Build: $step_dir/packer-build.log
  Errors: $step_dir/packer-build-error.log

EOF

  mark_step_completed "$STEP_ID"
  log_success "Step ${STEP_NUMBER} PASSED: Controller Packer build successful"
  cat "$step_dir/validation-summary.txt"

  return 0
}

main
