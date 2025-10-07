#!/bin/bash
# Test Suite 1: Check Cross-Node Synchronization Setup

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

TEST_NAME="Container Registry Cross-Node Sync Setup"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0

log_test() { echo -e "${YELLOW}[TEST]${NC} $*"; }
log_pass() { ((TESTS_PASSED++)); echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() { ((TESTS_FAILED++)); echo -e "${RED}[FAIL]${NC} $*"; }
log_info() { echo -e "[INFO] $*"; }

test_sync_script_exists() {
  ((TESTS_RUN++))
  log_test "Checking sync script exists on controller"
  if $SSH_CMD "${TEST_CONTROLLER}" "[ -f /usr/local/bin/registry-sync-to-nodes.sh ]"; then
    log_pass "Sync script exists"
    return 0
  else
    log_fail "Sync script not found"
    return 1
  fi
}

test_sync_script_executable() {
  ((TESTS_RUN++))
  log_test "Checking sync script is executable"
  if $SSH_CMD "${TEST_CONTROLLER}" "[ -x /usr/local/bin/registry-sync-to-nodes.sh ]"; then
    log_pass "Sync script is executable"
    return 0
  else
    log_fail "Sync script not executable"
    return 1
  fi
}

test_rsync_available() {
  ((TESTS_RUN++))
  log_test "Checking rsync is installed"
  if $SSH_CMD "${TEST_CONTROLLER}" "which rsync >/dev/null 2>&1"; then
    log_pass "rsync is available"
    return 0
  else
    log_fail "rsync not found"
    return 1
  fi
}

test_ssh_key_exists() {
  ((TESTS_RUN++))
  log_test "Checking registry sync SSH key exists"
  if $SSH_CMD "${TEST_CONTROLLER}" "[ -f /root/.ssh/id_rsa_registry_sync ]"; then
    log_pass "Registry sync SSH key exists"
    return 0
  else
    log_info "Registry sync SSH key not found (may not be configured yet)"
    return 0
  fi
}

test_sync_wrapper_exists() {
  ((TESTS_RUN++))
  log_test "Checking sync wrapper script exists"
  if $SSH_CMD "${TEST_CONTROLLER}" "[ -f /usr/local/bin/registry-sync-wrapper.sh ]"; then
    log_pass "Sync wrapper script exists"
    return 0
  else
    log_fail "Sync wrapper script not found"
    return 1
  fi
}

main() {
  echo ""; echo "═══════════════════════════════════════════════════════════"
  echo "  $TEST_NAME"; echo "═══════════════════════════════════════════════════════════"; echo ""
  [[ -z "${TEST_CONTROLLER:-}" ]] && echo -e "${RED}ERROR: TEST_CONTROLLER not set${NC}" && exit 1

  test_sync_script_exists || true
  test_sync_script_executable || true
  test_rsync_available || true
  test_ssh_key_exists || true
  test_sync_wrapper_exists || true

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
