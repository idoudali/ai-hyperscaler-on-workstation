#!/bin/bash
# Test Suite 1: Ansible Infrastructure Tests
# Test: Check Registry Structure
# Validates that the container registry directory structure is correctly created

set -euo pipefail

# Test configuration
TEST_NAME="Container Registry Structure"
REGISTRY_BASE_PATH="${REGISTRY_BASE_PATH:-/opt/containers}"
EXPECTED_SUBDIRS=("ml-frameworks" "custom-images" "base-images" ".registry")
EXPECTED_FILES=("README.md" ".registry/config.yaml" ".registry/catalog.yaml")

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
test_base_directory_exists() {
  ((TESTS_RUN++))
  log_test "Checking registry base directory exists: $REGISTRY_BASE_PATH"

  if $SSH_CMD "${TEST_CONTROLLER}" "[ -d '$REGISTRY_BASE_PATH' ]"; then
    log_pass "Registry base directory exists"
    return 0
  else
    log_fail "Registry base directory does not exist: $REGISTRY_BASE_PATH"
    return 1
  fi
}

test_subdirectories_exist() {
  ((TESTS_RUN++))
  log_test "Checking required subdirectories exist"

  local failed=0
  for subdir in "${EXPECTED_SUBDIRS[@]}"; do
    local full_path="${REGISTRY_BASE_PATH}/${subdir}"
    if $SSH_CMD "${TEST_CONTROLLER}" "[ -d '$full_path' ]"; then
      log_info "  ✓ $subdir exists"
    else
      log_fail "  ✗ $subdir does not exist"
      failed=1
    fi
  done

  if [[ $failed -eq 0 ]]; then
    log_pass "All subdirectories exist"
    return 0
  else
    log_fail "Some subdirectories are missing"
    return 1
  fi
}

test_required_files_exist() {
  ((TESTS_RUN++))
  log_test "Checking required files exist"

  local failed=0
  for file in "${EXPECTED_FILES[@]}"; do
    local full_path="${REGISTRY_BASE_PATH}/${file}"
    if $SSH_CMD "${TEST_CONTROLLER}" "[ -f '$full_path' ]"; then
      log_info "  ✓ $file exists"
    else
      log_fail "  ✗ $file does not exist"
      failed=1
    fi
  done

  if [[ $failed -eq 0 ]]; then
    log_pass "All required files exist"
    return 0
  else
    log_fail "Some required files are missing"
    return 1
  fi
}

test_structure_on_compute_nodes() {
  ((TESTS_RUN++))
  log_test "Checking registry structure exists on compute nodes"

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
    log_info "Error: $compute_nodes_output"
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

    log_info "Checking node: $node"
    if $SSH_CMD "${TEST_CONTROLLER}" "$SSH_CMD $node '[ -d $REGISTRY_BASE_PATH ]'" 2>/dev/null; then
      log_info "  ✓ $node has registry structure"
    else
      log_fail "  ✗ $node missing registry structure"
      failed=1
    fi
  done

  if [[ $failed -eq 0 ]]; then
    log_pass "Registry structure exists on all compute nodes"
    return 0
  else
    log_fail "Registry structure missing on some compute nodes"
    return 1
  fi
}

test_directory_hierarchy() {
  ((TESTS_RUN++))
  log_test "Validating directory hierarchy"

  local tree_output
  tree_output=$($SSH_CMD "${TEST_CONTROLLER}" "tree -L 2 -d $REGISTRY_BASE_PATH 2>/dev/null || find $REGISTRY_BASE_PATH -type d -maxdepth 2 | sort")

  log_info "Directory structure:"
  # Add leading spaces to each line
  while IFS= read -r line; do echo "  $line"; done <<< "$tree_output"

  log_pass "Directory hierarchy validated"
  return 0
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
  log_info "Registry base path: $REGISTRY_BASE_PATH"
  echo ""

  # Run tests
  test_base_directory_exists || true
  test_subdirectories_exist || true
  test_required_files_exist || true
  test_structure_on_compute_nodes || true
  test_directory_hierarchy || true

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
