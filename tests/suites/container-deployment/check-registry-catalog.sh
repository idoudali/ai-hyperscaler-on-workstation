#!/bin/bash
# Test Suite 2: Registry Catalog Test
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
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0

test_catalog_exists() {
  ((TESTS_RUN++))
  if $SSH_CMD "${TEST_CONTROLLER}" "[ -f /opt/containers/.registry/catalog.yaml ]"; then
    ((TESTS_PASSED++)); echo -e "${GREEN}[PASS]${NC} Catalog file exists"; return 0
  else
    ((TESTS_FAILED++)); echo -e "${RED}[FAIL]${NC} Catalog file not found"; return 1
  fi
}

main() {
  echo "  Registry Catalog Test"
  [[ -z "${TEST_CONTROLLER:-}" ]] && echo -e "${RED}ERROR: TEST_CONTROLLER not set${NC}" && exit 1
  test_catalog_exists || true
  echo "Tests: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
  [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}
main "$@"
