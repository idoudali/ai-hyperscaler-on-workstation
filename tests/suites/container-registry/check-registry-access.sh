#!/bin/bash
# Test Suite 1: Check Registry Cross-Node Access

set -euo pipefail

# SSH configuration
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes -o ConnectTimeout=10"

# Build SSH command with key if available
if [[ -f "$SSH_KEY_PATH" ]]; then
  SSH_CMD="ssh -i $SSH_KEY_PATH $SSH_OPTS"
else
  SSH_CMD="ssh $SSH_OPTS"
fi

TEST_NAME="Container Registry Cross-Node Access"
REGISTRY_BASE_PATH="${REGISTRY_BASE_PATH:-/opt/containers}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0

log_test() { echo -e "${YELLOW}[TEST]${NC} $*"; }
log_pass() { ((TESTS_PASSED++)); echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() { ((TESTS_FAILED++)); echo -e "${RED}[FAIL]${NC} $*"; }
log_info() { echo -e "[INFO] $*"; }

test_controller_access() {
  ((TESTS_RUN++))
  log_test "Checking controller access to registry"
  if $SSH_CMD "${TEST_CONTROLLER}" "ls -la $REGISTRY_BASE_PATH" >/dev/null 2>&1; then
    log_pass "Controller can access registry"
    return 0
  else
    log_fail "Controller cannot access registry"
    return 1
  fi
}

test_compute_nodes_access() {
  ((TESTS_RUN++))
  log_test "Checking compute nodes access to registry"

  local nodes
  mapfile -t nodes < <($SSH_CMD "${TEST_CONTROLLER}" "sinfo -N -h -o '%N'" 2>/dev/null || echo "")

  if [[ ${#nodes[@]} -eq 0 ]]; then
    log_info "No compute nodes detected, skipping"
    return 0
  fi

  local failed=0
  for node in "${nodes[@]}"; do
    if $SSH_CMD "${TEST_CONTROLLER}" "ssh $node 'ls -la $REGISTRY_BASE_PATH' 2>/dev/null" >/dev/null; then
      log_info "  ✓ $node can access registry"
    else
      log_fail "  ✗ $node cannot access registry"
      failed=1
    fi
  done

  [[ $failed -eq 0 ]] && log_pass "All compute nodes can access registry" && return 0
  log_fail "Some nodes cannot access registry" && return 1
}

test_ssh_connectivity() {
  ((TESTS_RUN++))
  log_test "Checking SSH connectivity between nodes"

  local nodes
  mapfile -t nodes < <($SSH_CMD "${TEST_CONTROLLER}" "sinfo -N -h -o '%N'" 2>/dev/null || echo "")

  if [[ ${#nodes[@]} -eq 0 ]]; then
    log_info "No compute nodes, skipping"; return 0
  fi

  local failed=0
  for node in "${nodes[@]}"; do
    if $SSH_CMD "${TEST_CONTROLLER}" "ssh -o ConnectTimeout=5 -o BatchMode=yes $node hostname 2>/dev/null" >/dev/null; then
      log_info "  ✓ SSH to $node working"
    else
      log_fail "  ✗ SSH to $node failed"
      failed=1
    fi
  done

  [[ $failed -eq 0 ]] && log_pass "SSH connectivity verified" && return 0
  log_fail "SSH connectivity issues detected" && return 1
}

main() {
  echo ""; echo "═══════════════════════════════════════════════════════════"
  echo "  $TEST_NAME"; echo "═══════════════════════════════════════════════════════════"; echo ""
  [[ -z "${TEST_CONTROLLER:-}" ]] && echo -e "${RED}ERROR: TEST_CONTROLLER not set${NC}" && exit 1

  test_controller_access || true
  test_compute_nodes_access || true
  test_ssh_connectivity || true

  echo ""; echo "═══════════════════════════════════════════════════════════"
  echo "  Test Summary"; echo "═══════════════════════════════════════════════════════════"; echo ""
  echo "Tests Run: $TESTS_RUN"; echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"; echo -e "Failed: ${RED}$TESTS_FAILED${NC}"; echo ""
  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed${NC}"
    exit 0
  else
    echo -e "${RED}✗ Tests failed${NC}"
    exit 1
  fi
}

main "$@"
