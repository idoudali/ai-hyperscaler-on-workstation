#!/bin/bash
# Test Suite 2: Registry Catalog Test

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

TEST_NAME="Registry Catalog Test"

test_catalog_exists() {
  if exec_on_node "${TEST_CONTROLLER}" "[ -f /opt/containers/.registry/catalog.yaml ]"; then
    log_pass "Catalog file exists"
    return 0
  else
    log_fail "Catalog file not found"
    return 1
  fi
}

main() {
  init_suite_logging "$TEST_NAME"

  if [[ -z "${TEST_CONTROLLER:-}" ]]; then
    log_error "TEST_CONTROLLER environment variable not set"
    exit 1
  fi

  run_test "Catalog File Exists" test_catalog_exists

  print_test_summary "$TEST_NAME"
  exit_with_test_results
}

main "$@"
