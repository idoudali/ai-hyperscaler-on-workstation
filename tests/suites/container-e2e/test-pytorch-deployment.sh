#!/bin/bash
# Test Suite 3: PyTorch E2E Deployment Test
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

test_pytorch_e2e() {
  echo "Testing PyTorch container E2E workflow..."
  local test_image="pytorch-cuda12.1-mpi4.1.sif"
  local registry_path="/opt/containers/ml-frameworks"

  if $SSH_CMD "${TEST_CONTROLLER}" "apptainer exec $registry_path/$test_image python3 -c 'import torch; print(torch.__version__)' 2>&1"; then
    ((TESTS_PASSED++)); echo -e "${GREEN}✓ PyTorch E2E test passed${NC}"; return 0
  else
    ((TESTS_FAILED++)); echo -e "${RED}✗ PyTorch E2E test failed${NC}"; return 1
  fi
}

main() {
  echo "  E2E: PyTorch Deployment Test"
  [[ -z "${TEST_CONTROLLER:-}" ]] && echo -e "${RED}ERROR: TEST_CONTROLLER not set${NC}" && exit 1
  test_pytorch_e2e || true
  echo "Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
  [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}
main "$@"
