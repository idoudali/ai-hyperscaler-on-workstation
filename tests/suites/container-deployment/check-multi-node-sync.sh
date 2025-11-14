#!/bin/bash
# Test Suite 2: Multi-Node Image Sync Test

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-check-helpers.sh"

TEST_NAME="Multi-Node Image Synchronization"
REGISTRY_PATH="${REGISTRY_PATH:-/opt/containers/ml-frameworks}"

test_image_on_all_nodes() {
  log_test "Checking image exists on all compute nodes"
  local test_image="${TEST_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"
  local nodes; mapfile -t nodes < <(exec_on_node "${TEST_CONTROLLER}" "sinfo -N -h -o '%N'" 2>/dev/null || echo "")
  [[ ${#nodes[@]} -eq 0 ]] && log_pass "No compute nodes (OK for controller-only)" && return 0
  local failed=0
  for node in "${nodes[@]}"; do
    if exec_on_node "${TEST_CONTROLLER}" "ssh $node '[ -f $REGISTRY_PATH/$test_image ]'" 2>/dev/null; then
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
  init_suite_logging "$TEST_NAME"

  if [[ -z "${TEST_CONTROLLER:-}" ]]; then
    log_error "TEST_CONTROLLER environment variable not set"
    exit 1
  fi

  run_test "Image on All Nodes" test_image_on_all_nodes

  print_test_summary "$TEST_NAME"
  exit_with_test_results
}

main "$@"
