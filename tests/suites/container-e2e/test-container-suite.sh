#!/bin/bash
#
# Test Suite: Container E2E Tests (Merged)
# Tests: Container execution, PyTorch deployment, and multi-image deployment
# Validates container execution, PyTorch E2E workflow, and registry deployment
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Source shared utilities
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-check-helpers.sh"

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="test-container-suite.sh"
# shellcheck disable=SC2034
TEST_NAME="Container E2E Suite"

# Test configuration
CONTAINER_IMAGE="${CONTAINER_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"
REGISTRY_PATH="${REGISTRY_PATH:-/mnt/beegfs/containers/apptainer}"

# Log command for debugging - uses framework's log_debug when available
log_command() {
  local cmd="$1"
  if command -v log_debug >/dev/null 2>&1; then
    log_debug "Executing: $cmd"
  fi
}

# Helper function to check if container image exists
check_container_exists() {
  local image_path="$1"
  if [[ -f "$image_path" ]]; then
    return 0
  else
    return 1
  fi
}

# Helper function to execute container command with better error handling
run_container_cmd() {
  local image_path="$1"
  local python_cmd="$2"
  local timeout=30

  if ! check_container_exists "$image_path"; then
    log_fail "Container image not found: $image_path"
    return 1
  fi

  local full_cmd="apptainer run '$image_path' python3 -c \"$python_cmd\""
  log_command "$full_cmd"

  local output
  local exit_code

  # Run command with timeout and capture both output and exit code
  if output=$(timeout "$timeout" bash -c "apptainer run '$image_path' python3 -c \"$python_cmd\"" 2>&1); then
    exit_code=0
  else
    exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
      log_fail "Command timed out after ${timeout}s"
      return 1
    fi
  fi

  if [[ -n "$output" ]]; then
    echo "$output"
    return 0
  else
    log_fail "No output from container command"
    return 1
  fi
}

# Test 1: Basic container job execution
test_job_execution() {
  ((TESTS_RUN++))
  log_test "Testing container job execution"

  local test_image_path="$REGISTRY_PATH/$CONTAINER_IMAGE"
  local python_cmd="print('Job executed successfully')"

  local output
  if output=$(run_container_cmd "$test_image_path" "$python_cmd"); then
    if echo "$output" | grep -q 'Job executed successfully'; then
      log_pass "Container job execution passed"
      ((TESTS_PASSED++))
      return 0
    else
      log_fail "Container job execution did not produce expected output: $output"
      ((TESTS_FAILED++))
      return 1
    fi
  else
    log_fail "Container job execution failed: $output"
    ((TESTS_FAILED++))
    return 1
  fi
}

# Test 2: PyTorch E2E deployment
test_pytorch_e2e() {
  ((TESTS_RUN++))
  log_test "Testing PyTorch container E2E workflow"

  local test_image_path="$REGISTRY_PATH/$CONTAINER_IMAGE"
  local python_cmd="import torch; print('PyTorch Version:', torch.__version__)"

  local output
  if output=$(run_container_cmd "$test_image_path" "$python_cmd"); then
    if echo "$output" | grep -qE '(PyTorch Version:|[0-9]+\.[0-9]+)'; then
      log_pass "PyTorch E2E test passed: $output"
      ((TESTS_PASSED++))
      return 0
    else
      log_fail "PyTorch E2E test did not produce version output: $output"
      ((TESTS_FAILED++))
      return 1
    fi
  else
    log_fail "PyTorch E2E test failed: $output"
    ((TESTS_FAILED++))
    return 1
  fi
}

# Test 3: Multi-image deployment validation
test_multi_image() {
  ((TESTS_RUN++))
  log_test "Testing multiple images deployed in registry"

  if [[ ! -d "$REGISTRY_PATH" ]]; then
    log_fail "Registry path does not exist: $REGISTRY_PATH"
    ((TESTS_FAILED++))
    return 1
  fi

  local cmd="find '$REGISTRY_PATH' -name '*.sif' 2>/dev/null | wc -l"
  log_command "$cmd"

  local count
  if count=$(eval "$cmd"); then
    if [[ -z "$count" ]]; then
      count=0
    fi

    if [[ $count -ge 1 ]]; then
      log_pass "Found $count container image(s) in registry"
      ((TESTS_PASSED++))
      return 0
    else
      log_fail "No container images found in registry: $REGISTRY_PATH"
      ((TESTS_FAILED++))
      return 1
    fi
  else
    log_fail "Failed to check registry for images"
    ((TESTS_FAILED++))
    return 1
  fi
}

# Main execution
main() {
  # Initialize test tracking
  init_test_tracking

  log_info "Starting $TEST_NAME test suite..."
  log_info "Container Image: $CONTAINER_IMAGE"
  log_info "Registry Path: $REGISTRY_PATH"
  log_info ""

  # Run all tests
  test_multi_image || true
  test_job_execution || true
  test_pytorch_e2e || true

  log_info ""

  # Output summary lines in format expected by test runner
  echo ""
  echo "========================================"
  echo "  Test Execution Summary"
  echo "========================================"
  echo ""
  echo "Tests Run:    $TESTS_RUN"
  echo "Tests Passed: $TESTS_PASSED"
  echo "Tests Failed: $TESTS_FAILED"
  echo "Duration:     ${DURATION:-1}s"
  echo ""

  # Exit with appropriate code
  if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
  else
    exit 0
  fi
}

# Execute main function
main "$@"
