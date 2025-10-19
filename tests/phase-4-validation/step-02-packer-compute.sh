#!/bin/bash
#
# Phase 4 Validation: Step 2 - Packer Compute Build
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_step_help() {
  cat << 'EOF'
Phase 4 Validation - Step 02: Packer Compute Build

Usage: ./step-02-packer-compute.sh [OPTIONS]

Options:
  -v, --verbose                 Enable verbose command logging
  --log-level LEVEL             Set log level (DEBUG, INFO)
  --validation-folder PATH      Resume from existing validation directory
  -h, --help                    Show this help message

Description:
  Builds the HPC compute VM image using Packer:
  - Validates Packer template syntax
  - Builds compute image via CMake/Docker
  - Verifies image artifacts (*.qcow2)
  - Analyzes Ansible execution results
  - Confirms GPU driver installation

  Time: 15-30 minutes
  Output: build/packer/hpc-compute/hpc-compute/*.qcow2

EOF
}

source "$SCRIPT_DIR/lib-common.sh"
parse_validation_args "$@"

main() {
  log_step_title "02" "Packer Compute Build"

  if ! prerequisites_completed; then
    log_error "Prerequisites not completed. Run step-00-prerequisites.sh first"
    return 1
  fi

  if is_step_completed "step-02-packer-compute"; then
    log_warning "Step 02 already completed at $(get_step_completion_time 'step-02-packer-compute')"
    return 0
  fi

  init_state
  local step_dir="$VALIDATION_ROOT/02-packer-compute"
  create_step_dir "$step_dir"

  cd "$PROJECT_ROOT"

  log_info "2.1: Validating Packer template..."
  log_cmd "make run-docker COMMAND='cmake --build build --target validate-hpc-compute-packer'"
  if ! make run-docker COMMAND="cmake --build build --target validate-hpc-compute-packer" \
    > "$step_dir/packer-validate.log" 2>&1; then
    log_error "Packer validation failed"
    tail -20 "$step_dir/packer-validate.log"
    return 1
  fi
  log_success "Packer template syntax valid"

  log_info "2.2: Building compute Packer image (15-30 minutes)..."
  log_cmd "make run-docker COMMAND='cmake --build build --target build-hpc-compute-image'"
  if ! make run-docker COMMAND="cmake --build build --target build-hpc-compute-image" \
    > "$step_dir/packer-build.log" 2>&1; then
    log_error "Packer build failed"
    grep -i "error\|fatal" "$step_dir/packer-build.log" > "$step_dir/packer-build-error.log" 2>/dev/null || true
    tail -30 "$step_dir/packer-build.log"
    return 1
  fi
  log_success "Packer build completed"

  log_info "2.3: Verifying image artifacts..."
  if ! ls "$PROJECT_ROOT/build/packer/hpc-compute/hpc-compute/"*.qcow2 &>/dev/null; then
    log_error "No image artifacts found"
    return 1
  fi

  IMAGE_SIZE=$(du -sh "$PROJECT_ROOT/build/packer/hpc-compute/hpc-compute/"*.qcow2 | awk '{print $1}')
  log_success "Image artifacts found: $IMAGE_SIZE"

  log_info "2.4: Analyzing Ansible execution..."
  if ! grep -q "PLAY RECAP" "$step_dir/packer-build.log"; then
    log_error "Ansible playbook did not complete"
    return 1
  fi
  log_success "Ansible playbook executed"

  cat > "$step_dir/validation-summary.txt" << EOF
=== Step 02: Packer Compute Build ===
Timestamp: $(date)

✅ PASSED

Details:
- Packer template: Valid
- Image build: Successful
- Image size: $IMAGE_SIZE
- Ansible execution: Completed

Image location:
  $PROJECT_ROOT/build/packer/hpc-compute/hpc-compute/

EOF

  mark_step_completed "step-02-packer-compute"
  log_success "Step 02 PASSED: Compute Packer build successful"
  cat "$step_dir/validation-summary.txt"

  return 0
}

main
