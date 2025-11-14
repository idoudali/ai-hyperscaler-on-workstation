#!/bin/bash
# Test Suite 2: Image Integrity Test

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

TEST_NAME="Image Integrity Test"
REGISTRY_PATH="${REGISTRY_PATH:-/opt/containers/ml-frameworks}"

test_apptainer_inspect() {
  local test_image="${TEST_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"
  if exec_on_node "${TEST_CONTROLLER}" "apptainer inspect $REGISTRY_PATH/$test_image >/dev/null 2>&1"; then
    log_pass "Image integrity OK"
    return 0
  else
    log_fail "Image integrity check failed"
    return 1
  fi
}

main() {
  init_suite_logging "$TEST_NAME"

  if [[ -z "${TEST_CONTROLLER:-}" ]]; then
    log_error "TEST_CONTROLLER environment variable not set"
    exit 1
  fi

  run_test "Apptainer Inspect" test_apptainer_inspect

  print_test_summary "$TEST_NAME"
  exit_with_test_results
}

main "$@"
