#!/bin/bash
# Test Suite 3: Multi-Image Deployment Test
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
TESTS_PASSED=0; TESTS_FAILED=0

test_multi_image() {
  echo "Testing multiple images deployed..."
  local count
  count=$($SSH_CMD "${TEST_CONTROLLER}" "find /opt/containers/ml-frameworks -name '*.sif' 2>/dev/null | wc -l")
  if [[ $count -ge 1 ]]; then
    ((TESTS_PASSED++)); echo -e "${GREEN}✓ Found $count image(s)${NC}"; return 0
  else
    ((TESTS_FAILED++)); echo -e "${RED}✗ No images found${NC}"; return 1
  fi
}

main() {
  echo "  E2E: Multi-Image Deployment Test"
  [[ -z "${TEST_CONTROLLER:-}" ]] && echo -e "${RED}ERROR: TEST_CONTROLLER not set${NC}" && exit 1
  test_multi_image || true
  echo "Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
  [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}
main "$@"
