#!/bin/bash
# Test Suite 3: TensorFlow E2E Deployment Test
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

test_tensorflow_e2e() {
  echo "Testing TensorFlow container E2E workflow..."
  local test_image="tensorflow-cuda12.1.sif"
  local registry_path="/opt/containers/ml-frameworks"

  if $SSH_CMD "${TEST_CONTROLLER}" "[ -f $registry_path/$test_image ]" 2>/dev/null; then
    if $SSH_CMD "${TEST_CONTROLLER}" "apptainer exec $registry_path/$test_image python3 -c 'import tensorflow as tf; print(tf.__version__)' 2>&1"; then
      ((TESTS_PASSED++)); echo -e "${GREEN}✓ TensorFlow E2E test passed${NC}"; return 0
    fi
  fi
  ((TESTS_FAILED++)); echo -e "${RED}✗ TensorFlow E2E test failed/skipped${NC}"; return 1
}

main() {
  echo "  E2E: TensorFlow Deployment Test"
  [[ -z "${TEST_CONTROLLER:-}" ]] && echo -e "${RED}ERROR: TEST_CONTROLLER not set${NC}" && exit 1
  test_tensorflow_e2e || true
  echo "Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
  [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}
main "$@"
