#!/bin/bash
# Test Suite 2: Single Image Deployment Test
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

TEST_NAME="Single Image Deployment"
REGISTRY_PATH="${REGISTRY_PATH:-/opt/containers/ml-frameworks}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0

log_test() { echo -e "${YELLOW}[TEST]${NC} $*"; }
log_pass() { ((TESTS_PASSED++)); echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() { ((TESTS_FAILED++)); echo -e "${RED}[FAIL]${NC} $*"; }

test_image_deployed() {
  ((TESTS_RUN++))
  log_test "Checking if test image is deployed"
  local test_image="${TEST_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"
  if $SSH_CMD "${TEST_CONTROLLER}" "[ -f $REGISTRY_PATH/$test_image ]"; then
    log_pass "Image deployed: $test_image"
    return 0
  else
    log_fail "Image not found: $test_image"
    echo ""
    echo -e "${YELLOW}Expected location: $REGISTRY_PATH/$test_image${NC}"
    echo ""
    echo "This test requires container images to be built and deployed."
    echo ""
    echo -e "${YELLOW}To build and deploy container images:${NC}"
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
    echo -e "${YELLOW}Currently available images in registry:${NC}"
    local available_images
    available_images=$($SSH_CMD "${TEST_CONTROLLER}" "ls -lh $REGISTRY_PATH/*.sif 2>/dev/null || echo 'No .sif files found'")
    # Add leading spaces to each line
    while IFS= read -r line; do echo "  $line"; done <<< "$available_images"
    echo ""

    return 1
  fi
}

test_image_readable() {
  ((TESTS_RUN++))
  log_test "Checking if image is readable"
  local test_image="${TEST_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"
  if $SSH_CMD "${TEST_CONTROLLER}" "[ -r $REGISTRY_PATH/$test_image ]"; then
    log_pass "Image is readable"
    return 0
  else
    log_fail "Image is not readable"
    return 1
  fi
}

test_image_size() {
  ((TESTS_RUN++))
  log_test "Checking image size"
  local test_image="${TEST_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"
  local size
  size=$($SSH_CMD "${TEST_CONTROLLER}" "stat -c%s $REGISTRY_PATH/$test_image 2>/dev/null || echo 0")
  if [[ $size -gt 1000000 ]]; then  # At least 1MB
    log_pass "Image size OK: $(( size / 1024 / 1024 )) MB"
    return 0
  else
    log_fail "Image too small or not found"
    return 1
  fi
}

main() {
  echo ""; echo "═══════════════════════════════════════════════════════════"; echo "  $TEST_NAME"; echo "═══════════════════════════════════════════════════════════"; echo ""
  [[ -z "${TEST_CONTROLLER:-}" ]] && echo -e "${RED}ERROR: TEST_CONTROLLER not set${NC}" && exit 1

  test_image_deployed || true
  test_image_readable || true
  test_image_size || true

  echo ""; echo "Tests: $TESTS_RUN | Passed: ${GREEN}$TESTS_PASSED${NC} | Failed: ${RED}$TESTS_FAILED${NC}"; echo ""
  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed${NC}"
    exit 0
  else
    echo -e "${RED}✗ Tests failed${NC}"
    exit 1
  fi
}

main "$@"
