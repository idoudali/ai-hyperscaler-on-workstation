#!/bin/bash
#
# Phase 4 Validation: Main Orchestrator
# Runs all validation steps in sequence
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Parse command-line arguments
# ============================================================================

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v|--verbose)
        export VALIDATION_VERBOSE=1
        shift
        ;;
      --log-level)
        export VALIDATION_LOG_LEVEL="$2"
        shift 2
        ;;
      --log-level=*)
        export VALIDATION_LOG_LEVEL="${1#*=}"
        shift
        ;;
      --validation-folder)
        export VALIDATION_ROOT="$2"
        shift 2
        ;;
      --validation-folder=*)
        export VALIDATION_ROOT="${1#*=}"
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        show_help
        exit 1
        ;;
    esac
  done
}

show_help() {
  cat << 'EOF'
Phase 4 Validation Framework - Main Orchestrator

Usage: ./run-all-steps.sh [OPTIONS]

Options:
  -v, --verbose                 Enable verbose command logging (shows all commands)
  --log-level LEVEL             Set log level (DEBUG, INFO)
  --log-level=LEVEL             Alternative syntax for setting log level
  --validation-folder PATH      Resume from existing validation directory
  --validation-folder=PATH      Alternative syntax
  -h, --help                    Show this help message

Environment Variables:
  VALIDATION_VERBOSE            Set to 1 to enable verbose logging
  VALIDATION_LOG_LEVEL          Set to DEBUG or INFO
  VALIDATION_ROOT               Path to existing validation directory (for resume)

Examples:
  # Run new validation with verbose logging
  ./run-all-steps.sh --verbose
  ./run-all-steps.sh -v

  # Run with specific log level
  ./run-all-steps.sh --log-level DEBUG
  ./run-all-steps.sh --log-level=INFO

  # Resume from existing validation directory (completed steps will be skipped)
  ./run-all-steps.sh --validation-folder validation-output/phase-4-validation-20251019-143022
  ./run-all-steps.sh --validation-folder=validation-output/phase-4-validation-20251019-143022

  # Using environment variable
  VALIDATION_VERBOSE=1 ./run-all-steps.sh
  VALIDATION_ROOT=validation-output/phase-4-validation-20251019-143022 ./run-all-steps.sh

Description:
  Runs all Phase 4 validation steps in sequence:
  - Step 00: Prerequisites
  - Step 01: Packer Controller Build
  - Step 02: Packer Compute Build
  - Step 03: Runtime Deployment
  - Step 04: Functional Tests
  - Step 05: Regression Tests

  All outputs are saved to: validation-output/phase-4-validation-TIMESTAMP/

  Resume Mode:
  When --validation-folder is provided, the framework automatically resumes from that
  directory, skipping any completed steps. This is useful if validation was interrupted
  or a step failed and you want to continue from where you left off.

EOF
}

# Parse arguments before sourcing lib-common.sh
parse_args "$@"

source "$SCRIPT_DIR/lib-common.sh"

# Initialize validation root after sourcing lib-common.sh
# This will automatically validate if resuming from existing directory
init_validation_root

# ============================================================================
# Main
# ============================================================================

main() {
  local start_time
  start_time=$(date +%s)

  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  Phase 4 Consolidation Validation Framework               ║"
  echo "║  Full Validation (All Steps)                              ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "Validation outputs: $VALIDATION_ROOT"
  echo ""

  if [ "$VALIDATION_VERBOSE" = "1" ] || [ "$VALIDATION_LOG_LEVEL" = "DEBUG" ]; then
    log_info "✓ Verbose logging enabled - commands will be displayed"
  else
    log_info "To see command execution, use: --verbose or -v"
  fi
  echo ""

  init_state

  # Step 0: Prerequisites
  log_info "Running Step 00: Prerequisites..."
  if ! bash "$SCRIPT_DIR/step-00-prerequisites.sh"; then
    log_error "Step 00 FAILED"
    return 1
  fi
  echo ""

  # Step 1: Packer Controller
  log_info "Running Step 01: Packer Controller Build..."
  if ! bash "$SCRIPT_DIR/step-01-packer-controller.sh"; then
    log_error "Step 01 FAILED"
    return 1
  fi
  echo ""

  # Step 2: Packer Compute
  log_info "Running Step 02: Packer Compute Build..."
  if ! bash "$SCRIPT_DIR/step-02-packer-compute.sh"; then
    log_error "Step 02 FAILED"
    return 1
  fi
  echo ""

  # Step 3: Runtime Deployment
  log_info "Running Step 03: Runtime Deployment..."
  if ! bash "$SCRIPT_DIR/step-03-runtime-deployment.sh"; then
    log_error "Step 03 FAILED"
    return 1
  fi
  echo ""

  # Step 4: Functional Tests
  log_info "Running Step 04: Functional Tests..."
  if ! bash "$SCRIPT_DIR/step-04-functional-tests.sh"; then
    log_error "Step 04 FAILED"
    return 1
  fi
  echo ""

  # Step 5: Regression Tests
  log_info "Running Step 05: Regression Tests..."
  if ! bash "$SCRIPT_DIR/step-05-regression-tests.sh"; then
    log_error "Step 05 FAILED"
    return 1
  fi
  echo ""

  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))
  local hours=$((duration / 3600))
  local minutes=$(((duration % 3600) / 60))
  local seconds=$((duration % 60))

  # Print summary
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  ✅ ALL VALIDATION STEPS PASSED                           ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "Completed Steps:"
  bash "$SCRIPT_DIR/lib-common.sh" 2>/dev/null | grep -o "step-.*" || {
    for step in $(list_completed_steps); do
      echo "  ✅ $step"
    done
  }
  echo ""
  echo "Duration: ${hours}h ${minutes}m ${seconds}s"
  echo "Validation logs: $VALIDATION_ROOT"
  echo ""
  echo "To view results:"
  echo "  cat '$VALIDATION_ROOT/*/validation-summary.txt'"
  echo ""
  echo "To stop the cluster:"
  echo "  make cluster-stop CLUSTER_CONFIG=config/example-multi-gpu-clusters.yaml CLUSTER_NAME=hpc"
  echo ""

  return 0
}

# Run main (arguments already parsed)
main
