#!/bin/bash
# Test Suite 3: SLURM Job Container Execution Test
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

test_job_execution() {
  echo "Testing SLURM job with container..."
  local test_image="/opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif"
  if $SSH_CMD "${TEST_CONTROLLER}" "srun --container=$test_image python3 -c 'print(\"Job executed successfully\")' 2>&1 | grep -q 'Job executed successfully'"; then
    ((TESTS_PASSED++)); echo -e "${GREEN}✓ SLURM job execution passed${NC}"; return 0
  else
    ((TESTS_FAILED++)); echo -e "${RED}✗ SLURM job execution failed${NC}"; return 1
  fi
}

main() {
  echo "  E2E: SLURM Job Container Execution Test"
  [[ -z "${TEST_CONTROLLER:-}" ]] && echo -e "${RED}ERROR: TEST_CONTROLLER not set${NC}" && exit 1
  test_job_execution || true
  echo "Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
  [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}
main "$@"
