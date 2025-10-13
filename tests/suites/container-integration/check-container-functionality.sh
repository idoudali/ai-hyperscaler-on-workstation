#!/bin/bash
# Test Suite: Container Integration Tests
# Test: Check Container Functionality
# Validates basic container execution, environment, and file system access

set -euo pipefail

# Test configuration
TEST_NAME="Container Functionality"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-/opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-apptainer}"

# SSH configuration
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes -o ConnectTimeout=10"

# Build SSH command with key if available
if [[ -f "$SSH_KEY_PATH" ]]; then
  SSH_CMD="ssh -i $SSH_KEY_PATH $SSH_OPTS"
else
  SSH_CMD="ssh $SSH_OPTS"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_test() {
  echo -e "${YELLOW}[TEST]${NC} $*"
}

log_pass() {
  ((TESTS_PASSED++))
  echo -e "${GREEN}[PASS]${NC} $*"
}

log_fail() {
  ((TESTS_FAILED++))
  echo -e "${RED}[FAIL]${NC} $*"
}

log_info() {
  echo -e "[INFO] $*"
}

# Test functions
test_container_image_exists() {
  ((TESTS_RUN++))
  log_test "Checking container image exists: $CONTAINER_IMAGE"

  if $SSH_CMD "${TEST_CONTROLLER}" "[ -f '$CONTAINER_IMAGE' ]"; then
    log_pass "Container image exists"
    return 0
  else
    log_fail "Container image does not exist: $CONTAINER_IMAGE"
    log_info "Container image must be deployed before running integration tests"
    log_info "Deploy with: make test-container-registry-deploy"
    return 1
  fi
}

test_container_runtime_available() {
  ((TESTS_RUN++))
  log_test "Checking container runtime availability: $CONTAINER_RUNTIME"

  local runtime_check
  runtime_check=$($SSH_CMD "${TEST_CONTROLLER}" "which $CONTAINER_RUNTIME 2>/dev/null || echo 'NOT_FOUND'")

  if [[ "$runtime_check" != "NOT_FOUND" ]]; then
    log_pass "Container runtime available: $runtime_check"
    return 0
  else
    log_fail "Container runtime not available: $CONTAINER_RUNTIME"
    return 1
  fi
}

test_container_execution() {
  ((TESTS_RUN++))
  log_test "Testing basic container execution"

  local exec_result
  exec_result=$($SSH_CMD "${TEST_CONTROLLER}" "$CONTAINER_RUNTIME exec $CONTAINER_IMAGE echo 'Container execution successful' 2>&1" || echo "FAILED")

  if [[ "$exec_result" == *"Container execution successful"* ]]; then
    log_pass "Container executes successfully"
    return 0
  else
    log_fail "Container execution failed"
    log_info "Output: $exec_result"
    return 1
  fi
}

test_python_availability() {
  ((TESTS_RUN++))
  log_test "Checking Python availability in container"

  local python_version
  python_version=$($SSH_CMD "${TEST_CONTROLLER}" "$CONTAINER_RUNTIME exec $CONTAINER_IMAGE python3 --version 2>&1" || echo "FAILED")

  if [[ "$python_version" == *"Python"* ]]; then
    log_pass "Python available: $python_version"
    return 0
  else
    log_fail "Python not available in container"
    log_info "Output: $python_version"
    return 1
  fi
}

test_pytorch_import() {
  ((TESTS_RUN++))
  log_test "Testing PyTorch import in container"

  local pytorch_test
  pytorch_test=$($SSH_CMD "${TEST_CONTROLLER}" "$CONTAINER_RUNTIME exec $CONTAINER_IMAGE python3 -c 'import torch; print(torch.__version__)' 2>&1" || echo "IMPORT_FAILED")

  if [[ "$pytorch_test" != *"IMPORT_FAILED"* ]] && [[ "$pytorch_test" != *"ModuleNotFoundError"* ]]; then
    log_pass "PyTorch imports successfully: $pytorch_test"
    return 0
  else
    log_fail "PyTorch import failed"
    log_info "Output: $pytorch_test"
    return 1
  fi
}

test_filesystem_access() {
  ((TESTS_RUN++))
  log_test "Testing file system access from container"

  # Create test file on controller
  local test_file="/tmp/container-test-$RANDOM.txt"
  $SSH_CMD "${TEST_CONTROLLER}" "echo 'Container file system test' > $test_file"

  # Try to read file from container
  local file_content
  file_content=$($SSH_CMD "${TEST_CONTROLLER}" "$CONTAINER_RUNTIME exec $CONTAINER_IMAGE cat $test_file 2>&1" || echo "READ_FAILED")

  # Clean up test file
  $SSH_CMD "${TEST_CONTROLLER}" "rm -f $test_file"

  if [[ "$file_content" == *"Container file system test"* ]]; then
    log_pass "File system access works from container"
    return 0
  else
    log_fail "File system access failed from container"
    log_info "Output: $file_content"
    return 1
  fi
}

test_environment_variables() {
  ((TESTS_RUN++))
  log_test "Testing environment variable access in container"

  local env_test
  env_test=$($SSH_CMD "${TEST_CONTROLLER}" "TEST_VAR='container_test' $CONTAINER_RUNTIME exec $CONTAINER_IMAGE bash -c 'echo \$TEST_VAR' 2>&1" || echo "ENV_FAILED")

  if [[ "$env_test" == *"container_test"* ]]; then
    log_pass "Environment variables accessible in container"
    return 0
  else
    log_fail "Environment variable access failed"
    log_info "Output: $env_test"
    return 1
  fi
}

test_container_on_compute_nodes() {
  ((TESTS_RUN++))
  log_test "Testing container availability on compute nodes"

  # Check if SLURM is available
  local slurm_check
  slurm_check=$($SSH_CMD "${TEST_CONTROLLER}" "sinfo --version 2>/dev/null || echo 'NOT_AVAILABLE'")

  if [[ "$slurm_check" == "NOT_AVAILABLE" ]]; then
    log_info "SLURM not available, skipping compute node check"
    log_pass "Test skipped (SLURM not running)"
    return 0
  fi

  # Get compute nodes from SLURM
  local compute_nodes_output
  compute_nodes_output=$($SSH_CMD "${TEST_CONTROLLER}" "sinfo -N -h -o '%N' 2>&1")
  local cmd_exit_code=$?

  # Check if command succeeded
  if [[ $cmd_exit_code -ne 0 ]] || [[ "$compute_nodes_output" == *"Unable to contact"* ]]; then
    log_info "Cannot contact SLURM controller, skipping compute node check"
    log_pass "Test skipped (SLURM not responding)"
    return 0
  fi

  # Parse nodes, filtering out empty lines
  local compute_nodes
  mapfile -t compute_nodes < <(echo "$compute_nodes_output" | grep -v '^$' | sort -u)

  if [[ ${#compute_nodes[@]} -eq 0 ]]; then
    log_info "No compute nodes detected in SLURM, skipping"
    log_pass "Test skipped (no compute nodes)"
    return 0
  fi

  log_info "Found ${#compute_nodes[@]} compute node(s): ${compute_nodes[*]}"

  local failed=0
  for node in "${compute_nodes[@]}"; do
    [[ -z "$node" ]] && continue  # Skip empty nodes

    log_info "Checking container on node: $node"
    local node_check
    node_check=$($SSH_CMD "${TEST_CONTROLLER}" "ssh -o StrictHostKeyChecking=no $node '[ -f $CONTAINER_IMAGE ] && echo OK' 2>/dev/null" || echo "FAILED")

    if [[ "$node_check" == "OK" ]]; then
      log_info "  ✓ $node has container image"
    else
      log_fail "  ✗ $node missing container image"
      failed=1
    fi
  done

  if [[ $failed -eq 0 ]]; then
    log_pass "Container image available on all compute nodes"
    return 0
  else
    log_fail "Container image missing on some compute nodes"
    return 1
  fi
}

# Main execution
main() {
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  $TEST_NAME"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Validate environment
  if [[ -z "${TEST_CONTROLLER:-}" ]]; then
    echo -e "${RED}ERROR: TEST_CONTROLLER environment variable not set${NC}"
    exit 1
  fi

  log_info "Testing controller: $TEST_CONTROLLER"
  log_info "Container image: $CONTAINER_IMAGE"
  log_info "Container runtime: $CONTAINER_RUNTIME"
  echo ""

  # Run tests
  test_container_image_exists || true
  test_container_runtime_available || true
  test_container_execution || true
  test_python_availability || true
  test_pytorch_import || true
  test_filesystem_access || true
  test_environment_variables || true
  test_container_on_compute_nodes || true

  # Summary
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  Test Summary: $TEST_NAME"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "Tests Run:    $TESTS_RUN"
  echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
  else
    echo -e "Tests Failed: $TESTS_FAILED"
  fi
  echo ""

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed${NC}"
    exit 0
  else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
  fi
}

# Run main function
main "$@"
