#!/bin/bash
# Test Suite 2: Multi-Node Image Sync Test
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
TEST_NAME="Multi-Node Image Synchronization"
REGISTRY_PATH="${REGISTRY_PATH:-/opt/containers/ml-frameworks}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0
log_test() { echo -e "${YELLOW}[TEST]${NC} $*"; }
log_pass() { ((TESTS_PASSED++)); echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() { ((TESTS_FAILED++)); echo -e "${RED}[FAIL]${NC} $*"; }

test_image_on_all_nodes() {
  ((TESTS_RUN++))
  log_test "Checking image exists on all compute nodes"
  local test_image="${TEST_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"
  local nodes; mapfile -t nodes < <($SSH_CMD "${TEST_CONTROLLER}" "sinfo -N -h -o '%N'" 2>/dev/null || echo "")
  [[ ${#nodes[@]} -eq 0 ]] && log_pass "No compute nodes (OK for controller-only)" && return 0
  local failed=0
  for node in "${nodes[@]}"; do
    if $SSH_CMD "${TEST_CONTROLLER}" "ssh $node '[ -f $REGISTRY_PATH/$test_image ]'" 2>/dev/null; then
      echo "  ✓ $node has image"
    else
      echo "  ✗ $node missing image"
      failed=1
    fi
  done
  [[ $failed -eq 0 ]] && log_pass "Image on all nodes" && return 0
  log_fail "Image missing on some nodes" && return 1
}

main() {
  echo ""; echo "═══════════════════════════════════════════════════════════"; echo "  $TEST_NAME"; echo "═══════════════════════════════════════════════════════════"; echo ""
  [[ -z "${TEST_CONTROLLER:-}" ]] && echo -e "${RED}ERROR: TEST_CONTROLLER not set${NC}" && exit 1
  test_image_on_all_nodes || true
  echo ""; echo "Tests: $TESTS_RUN | Passed: ${GREEN}$TESTS_PASSED${NC} | Failed: ${RED}$TESTS_FAILED${NC}"; echo ""
  [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}
main "$@"
