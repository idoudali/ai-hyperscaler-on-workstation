#!/bin/bash
# Test Suite 2: Single Image Deployment Test

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

TEST_NAME="Single Image Deployment"
REGISTRY_PATH="${REGISTRY_PATH:-/opt/containers/ml-frameworks}"

test_image_deployed() {
  log_test "Checking if test image is deployed"
  local test_image="${TEST_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"
  if exec_on_node "${TEST_CONTROLLER}" "[ -f $REGISTRY_PATH/$test_image ]"; then
    log_pass "Image deployed: $test_image"
    return 0
  else
    log_fail "Image not found: $test_image"
    echo ""
    log_warn "Expected location: $REGISTRY_PATH/$test_image"
    echo ""
    echo "This test requires container images to be built and deployed."
    echo ""
    log_warn "To build and deploy container images:"
    echo ""
    echo "1. Build containers locally:"
    echo "   cd containers/"
    echo "   make config"
    echo "   make run-docker COMMAND='cmake --build build --target all'"
    echo ""
    echo "2. Convert Docker images to Apptainer SIF format:"
    echo "   cd containers/"
    echo "   ./scripts/convert-all.sh"
    echo ""
    echo "3. Deploy converted images to the cluster:"
    echo "   cd containers/"
    echo "   ./scripts/deploy-to-cluster.sh --controller $TEST_CONTROLLER --registry-path $REGISTRY_PATH"
    echo ""
    echo "OR use the automated deployment command:"
    echo "   cd containers/ && make deploy-to-cluster CONTROLLER=$TEST_CONTROLLER REGISTRY_PATH=$REGISTRY_PATH"
    echo ""

    # Check what images are actually available
    log_warn "Currently available images in registry:"
    local available_images
    available_images=$(exec_on_node "${TEST_CONTROLLER}" "ls -lh $REGISTRY_PATH/*.sif 2>/dev/null || echo 'No .sif files found'")
    # Add leading spaces to each line
    while IFS= read -r line; do echo "  $line"; done <<< "$available_images"
    echo ""

    return 1
  fi
}

test_image_readable() {
  log_test "Checking if image is readable"
  local test_image="${TEST_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"
  if exec_on_node "${TEST_CONTROLLER}" "[ -r $REGISTRY_PATH/$test_image ]"; then
    log_pass "Image is readable"
    return 0
  else
    log_fail "Image is not readable"
    return 1
  fi
}

test_image_size() {
  log_test "Checking image size"
  local test_image="${TEST_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"
  local size
  size=$(exec_on_node "${TEST_CONTROLLER}" "stat -c%s $REGISTRY_PATH/$test_image 2>/dev/null || echo 0")
  if [[ $size -gt 1000000 ]]; then  # At least 1MB
    log_pass "Image size OK: $(( size / 1024 / 1024 )) MB"
    return 0
  else
    log_fail "Image too small or not found"
    return 1
  fi
}

main() {
  init_suite_logging "$TEST_NAME"

  if [[ -z "${TEST_CONTROLLER:-}" ]]; then
    log_error "TEST_CONTROLLER environment variable not set"
    exit 1
  fi

  run_test "Image Deployed" test_image_deployed
  run_test "Image Readable" test_image_readable
  run_test "Image Size" test_image_size

  print_test_summary "$TEST_NAME"
  exit_with_test_results
}

main "$@"
