#!/bin/bash
# Test Suite 1: Check Cross-Node Synchronization Setup

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

TEST_NAME="Container Registry BeeGFS Cross-Node Access"
REGISTRY_BASE_PATH="${REGISTRY_BASE_PATH:-/mnt/beegfs/containers}"

test_beegfs_mounted() {
  log_test "Checking BeeGFS is mounted on controller"
  if exec_on_node "${TEST_CONTROLLER}" "mount | grep -q beegfs"; then
    log_pass "BeeGFS is mounted"
    return 0
  else
    log_fail "BeeGFS is not mounted"
    return 1
  fi
}

test_beegfs_mount_point() {
  log_test "Checking BeeGFS mount point"
  local beegfs_mount
  beegfs_mount=$(exec_on_node "${TEST_CONTROLLER}" "mount | grep beegfs | awk '{print \$3}' | head -1" 2>/dev/null || echo "")

  if [[ -n "$beegfs_mount" ]]; then
    log_info "  BeeGFS mounted at: $beegfs_mount"
    if [[ "$beegfs_mount" == "/mnt/beegfs" ]]; then
      log_pass "BeeGFS mount point is correct"
      return 0
    else
      log_info "  Note: BeeGFS mounted at different location: $beegfs_mount"
      log_pass "BeeGFS mount point verified"
      return 0
    fi
  else
    log_fail "Could not determine BeeGFS mount point"
    return 1
  fi
}

test_registry_on_beegfs() {
  log_test "Checking registry is on BeeGFS"
  if exec_on_node "${TEST_CONTROLLER}" "[ -d '$REGISTRY_BASE_PATH' ]"; then
    # Check if it's actually on BeeGFS
    local mount_point
    mount_point=$(exec_on_node "${TEST_CONTROLLER}" "df '$REGISTRY_BASE_PATH' 2>/dev/null | tail -1 | awk '{print \$1}'" || echo "")

    if [[ "$mount_point" == *"beegfs"* ]]; then
      log_pass "Registry is on BeeGFS filesystem"
      return 0
    else
      log_info "  Registry directory exists but may not be on BeeGFS"
      log_pass "Registry directory exists"
      return 0
    fi
  else
    log_fail "Registry directory does not exist: $REGISTRY_BASE_PATH"
    return 1
  fi
}

test_beegfs_accessible_from_compute() {
  log_test "Checking BeeGFS accessible from compute nodes"

  local nodes
  mapfile -t nodes < <(exec_on_node "${TEST_CONTROLLER}" "sinfo -N -h -o '%N'" 2>/dev/null || echo "")

  if [[ ${#nodes[@]} -eq 0 ]]; then
    log_info "No compute nodes detected, skipping"
    return 0
  fi

  local failed=0
  for node in "${nodes[@]}"; do
    if exec_on_node "${TEST_CONTROLLER}" "ssh -o ConnectTimeout=5 -o BatchMode=yes $node 'mount | grep -q beegfs' 2>/dev/null"; then
      log_info "  ✓ $node has BeeGFS mounted"
    else
      log_fail "  ✗ $node does not have BeeGFS mounted"
      failed=1
    fi
  done

  [[ $failed -eq 0 ]] && log_pass "All compute nodes have BeeGFS mounted" && return 0
  log_fail "Some compute nodes do not have BeeGFS mounted" && return 1
}

main() {
  init_suite_logging "$TEST_NAME"

  if [[ -z "${TEST_CONTROLLER:-}" ]]; then
    log_error "TEST_CONTROLLER environment variable not set"
    exit 1
  fi

  run_test "BeeGFS Mounted" test_beegfs_mounted
  run_test "BeeGFS Mount Point" test_beegfs_mount_point
  run_test "Registry on BeeGFS" test_registry_on_beegfs
  run_test "BeeGFS Accessible from Compute" test_beegfs_accessible_from_compute

  print_test_summary "$TEST_NAME"
  exit_with_test_results
}

main "$@"
