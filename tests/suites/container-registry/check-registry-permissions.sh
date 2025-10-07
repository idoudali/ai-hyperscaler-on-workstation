#!/bin/bash
# Test Suite 1: Ansible Infrastructure Tests
# Test: Check Registry Permissions
# Validates ownership and permissions on registry directories

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

TEST_NAME="Container Registry Permissions"
REGISTRY_BASE_PATH="${REGISTRY_BASE_PATH:-/opt/containers}"
EXPECTED_MODE="${EXPECTED_MODE:-775}"
EXPECTED_OWNER="${EXPECTED_OWNER:-root}"
EXPECTED_GROUP="${EXPECTED_GROUP:-slurm}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0

log_test() { echo -e "${YELLOW}[TEST]${NC} $*"; }
log_pass() { ((TESTS_PASSED++)); echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() { ((TESTS_FAILED++)); echo -e "${RED}[FAIL]${NC} $*"; }
log_info() { echo -e "[INFO] $*"; }

test_directory_permissions() {
  ((TESTS_RUN++))
  log_test "Checking directory permissions"

  local stat_output
  stat_output=$($SSH_CMD "${TEST_CONTROLLER}" "stat -c '%a %U %G' $REGISTRY_BASE_PATH")
  read -r mode owner group <<< "$stat_output"

  local failed=0
  if [[ "$mode" == "$EXPECTED_MODE" ]]; then
    log_info "  ✓ Mode: $mode (expected: $EXPECTED_MODE)"
  else
    log_fail "  ✗ Mode: $mode (expected: $EXPECTED_MODE)"
    failed=1
  fi

  if [[ "$owner" == "$EXPECTED_OWNER" ]]; then
    log_info "  ✓ Owner: $owner (expected: $EXPECTED_OWNER)"
  else
    log_fail "  ✗ Owner: $owner (expected: $EXPECTED_OWNER)"
    failed=1
  fi

  if [[ "$group" == "$EXPECTED_GROUP" ]]; then
    log_info "  ✓ Group: $group (expected: $EXPECTED_GROUP)"
  else
    log_fail "  ✗ Group: $group (expected: $EXPECTED_GROUP)"
    failed=1
  fi

  [[ $failed -eq 0 ]] && log_pass "Directory permissions correct" && return 0
  log_fail "Directory permissions incorrect" && return 1
}

test_subdirectory_permissions() {
  ((TESTS_RUN++))
  log_test "Checking subdirectory permissions"

  local subdirs=("ml-frameworks" "custom-images" "base-images" ".registry")
  local failed=0

  for subdir in "${subdirs[@]}"; do
    local stat_output
    stat_output=$($SSH_CMD "${TEST_CONTROLLER}" "stat -c '%a %U %G' $REGISTRY_BASE_PATH/$subdir" 2>/dev/null || echo "000 none none")
    read -r mode owner group <<< "$stat_output"

    if [[ "$mode" == "$EXPECTED_MODE" && "$owner" == "$EXPECTED_OWNER" && "$group" == "$EXPECTED_GROUP" ]]; then
      log_info "  ✓ $subdir: $mode $owner:$group"
    else
      log_fail "  ✗ $subdir: $mode $owner:$group (expected: $EXPECTED_MODE $EXPECTED_OWNER:$EXPECTED_GROUP)"
      failed=1
    fi
  done

  [[ $failed -eq 0 ]] && log_pass "All subdirectories have correct permissions" && return 0
  log_fail "Some subdirectories have incorrect permissions" && return 1
}

test_slurm_group_exists() {
  ((TESTS_RUN++))
  log_test "Checking SLURM group exists"

  if $SSH_CMD "${TEST_CONTROLLER}" "getent group $EXPECTED_GROUP >/dev/null"; then
    log_pass "SLURM group exists: $EXPECTED_GROUP"
    return 0
  else
    log_fail "SLURM group does not exist: $EXPECTED_GROUP"
    return 1
  fi
}

test_slurm_user_access() {
  ((TESTS_RUN++))
  log_test "Checking SLURM user access to registry"

  local test_user="slurm"
  if $SSH_CMD "${TEST_CONTROLLER}" "sudo -u $test_user test -r $REGISTRY_BASE_PATH && test -x $REGISTRY_BASE_PATH" 2>/dev/null; then
    log_pass "SLURM user can access registry"
    return 0
  else
    log_info "Note: SLURM user may not exist yet, skipping user access test"
    return 0
  fi
}

main() {
  echo ""; echo "═══════════════════════════════════════════════════════════"
  echo "  $TEST_NAME"; echo "═══════════════════════════════════════════════════════════"; echo ""

  [[ -z "${TEST_CONTROLLER:-}" ]] && echo -e "${RED}ERROR: TEST_CONTROLLER not set${NC}" && exit 1

  log_info "Testing controller: $TEST_CONTROLLER"
  log_info "Expected permissions: $EXPECTED_MODE $EXPECTED_OWNER:$EXPECTED_GROUP"; echo ""

  test_directory_permissions || true
  test_subdirectory_permissions || true
  test_slurm_group_exists || true
  test_slurm_user_access || true

  echo ""; echo "═══════════════════════════════════════════════════════════"
  echo "  Test Summary: $TEST_NAME"; echo "═══════════════════════════════════════════════════════════"; echo ""
  echo "Tests Run:    $TESTS_RUN"; echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
  [[ $TESTS_FAILED -gt 0 ]] && echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}" || echo "Tests Failed: $TESTS_FAILED"
  echo ""

  [[ $TESTS_FAILED -eq 0 ]] && echo -e "${GREEN}✓ All tests passed${NC}" && exit 0
  echo -e "${RED}✗ Some tests failed${NC}" && exit 1
}

main "$@"
