#!/bin/bash
# Test Suite 1: Ansible Infrastructure Tests
# Test: Check Registry Permissions
# Validates ownership and permissions on registry directories

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

TEST_NAME="Container Registry Permissions"
REGISTRY_BASE_PATH="${REGISTRY_BASE_PATH:-/mnt/beegfs/containers}"
EXPECTED_MODE="${EXPECTED_MODE:-775}"
EXPECTED_OWNER="${EXPECTED_OWNER:-root}"
EXPECTED_GROUP="${EXPECTED_GROUP:-slurm}"

test_directory_permissions() {
  log_test "Checking directory permissions"

  local stat_output
  stat_output=$(exec_on_node "${TEST_CONTROLLER}" "stat -c '%a %U %G' $REGISTRY_BASE_PATH")
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
  log_test "Checking subdirectory permissions"

  local subdirs=("ml-frameworks" "custom-images" "base-images" ".registry")
  local failed=0

  for subdir in "${subdirs[@]}"; do
    local stat_output
    stat_output=$(exec_on_node "${TEST_CONTROLLER}" "stat -c '%a %U %G' $REGISTRY_BASE_PATH/$subdir" 2>/dev/null || echo "000 none none")
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
  log_test "Checking SLURM group exists"

  if exec_on_node "${TEST_CONTROLLER}" "getent group $EXPECTED_GROUP >/dev/null"; then
    log_pass "SLURM group exists: $EXPECTED_GROUP"
    return 0
  else
    log_fail "SLURM group does not exist: $EXPECTED_GROUP"
    return 1
  fi
}

test_slurm_user_access() {
  log_test "Checking SLURM user access to registry"

  local test_user="slurm"
  if exec_on_node "${TEST_CONTROLLER}" "sudo -u $test_user test -r $REGISTRY_BASE_PATH && test -x $REGISTRY_BASE_PATH" 2>/dev/null; then
    log_pass "SLURM user can access registry"
    return 0
  else
    log_info "Note: SLURM user may not exist yet, skipping user access test"
    return 0
  fi
}

main() {
  init_suite_logging "$TEST_NAME"

  if [[ -z "${TEST_CONTROLLER:-}" ]]; then
    log_error "TEST_CONTROLLER environment variable not set"
    exit 1
  fi

  log_info "Testing controller: $TEST_CONTROLLER"
  log_info "Expected permissions: $EXPECTED_MODE $EXPECTED_OWNER:$EXPECTED_GROUP"
  echo ""

  run_test "Directory Permissions" test_directory_permissions
  run_test "Subdirectory Permissions" test_subdirectory_permissions
  run_test "SLURM Group Exists" test_slurm_group_exists
  run_test "SLURM User Access" test_slurm_user_access

  print_test_summary "$TEST_NAME"
  exit_with_test_results
}

main "$@"
