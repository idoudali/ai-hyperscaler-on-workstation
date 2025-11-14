#!/bin/bash
# Test Suite 1: Check Registry Cross-Node Access

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

TEST_NAME="Container Registry Cross-Node Access"
REGISTRY_BASE_PATH="${REGISTRY_BASE_PATH:-/mnt/beegfs/containers}"

test_controller_access() {
  log_test "Checking controller access to registry"
  if exec_on_node "${TEST_CONTROLLER}" "ls -la $REGISTRY_BASE_PATH" >/dev/null 2>&1; then
    log_pass "Controller can access registry"
    return 0
  else
    log_fail "Controller cannot access registry"
    return 1
  fi
}

test_compute_nodes_access() {
  log_test "Checking compute nodes access to registry"

  local nodes
  mapfile -t nodes < <(exec_on_node "${TEST_CONTROLLER}" "sinfo -N -h -o '%N'" 2>/dev/null || echo "")

  if [[ ${#nodes[@]} -eq 0 ]]; then
    log_info "No compute nodes detected, skipping"
    return 0
  fi

  local failed=0
  for node in "${nodes[@]}"; do
    if exec_on_node "${TEST_CONTROLLER}" "ssh $node 'ls -la $REGISTRY_BASE_PATH' 2>/dev/null" >/dev/null; then
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
  log_test "Checking SSH connectivity between nodes"

  local nodes
  mapfile -t nodes < <(exec_on_node "${TEST_CONTROLLER}" "sinfo -N -h -o '%N'" 2>/dev/null || echo "")

  if [[ ${#nodes[@]} -eq 0 ]]; then
    log_info "No compute nodes, skipping"; return 0
  fi

  local failed=0
  for node in "${nodes[@]}"; do
    if exec_on_node "${TEST_CONTROLLER}" "ssh -o ConnectTimeout=5 -o BatchMode=yes $node hostname 2>/dev/null" >/dev/null; then
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
  init_suite_logging "$TEST_NAME"

  if [[ -z "${TEST_CONTROLLER:-}" ]]; then
    log_error "TEST_CONTROLLER environment variable not set"
    exit 1
  fi

  run_test "Controller Access" test_controller_access
  run_test "Compute Nodes Access" test_compute_nodes_access
  run_test "SSH Connectivity" test_ssh_connectivity

  print_test_summary "$TEST_NAME"
  exit_with_test_results
}

main "$@"
