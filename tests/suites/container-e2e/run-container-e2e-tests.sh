#!/bin/bash
# Test Suite 3 Master Runner: E2E Integration Tests
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'

# Source test framework utilities (save SCRIPT_DIR first as utils will overwrite it)
UTILS_DIR="$PROJECT_ROOT/tests/test-infra/utils"
SUITE_SCRIPT_DIR="$SCRIPT_DIR"
# shellcheck source=../../test-infra/utils/log-utils.sh
source "$UTILS_DIR/log-utils.sh"
# shellcheck source=../../test-infra/utils/vm-utils.sh
source "$UTILS_DIR/vm-utils.sh"
# Restore SCRIPT_DIR to point to this suite directory
SCRIPT_DIR="$SUITE_SCRIPT_DIR"

# Test configuration
TEST_CONFIG="${TEST_CONFIG:-$PROJECT_ROOT/tests/test-infra/configs/test-container-registry.yaml}"
ANSIBLE_INVENTORY="$PROJECT_ROOT/tests/test-infra/inventory/suite3-e2e-inventory.ini"
SSH_KEY_PATH="${SSH_KEY_PATH:-$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
SSH_USER="${SSH_USER:-admin}"

# Discover and validate controller, generating Ansible inventory
discover_and_validate_controller() {
    local test_config="$1"
    local inventory_file="$2"

    [[ -z "$test_config" ]] && echo -e "${RED}ERROR: test_config parameter required${NC}" && return 1
    [[ -z "$inventory_file" ]] && echo -e "${RED}ERROR: inventory_file parameter required${NC}" && return 1

    echo "Extracting controller information from: $test_config"

    local controller_ip
    if ! controller_ip=$(yq eval '.clusters.hpc.controller.ip_address' "$test_config" 2>/dev/null); then
        echo -e "${RED}ERROR: Failed to extract controller IP from config${NC}"
        return 1
    fi

    if [[ -z "$controller_ip" || "$controller_ip" == "null" ]]; then
        echo -e "${RED}ERROR: Controller IP not found in config${NC}"
        return 1
    fi

    echo "Controller IP from config: $controller_ip"

    if ! wait_for_vm_ssh "$controller_ip" "controller" "30"; then
        echo -e "${RED}ERROR: SSH connectivity failed to controller: $controller_ip${NC}"
        return 1
    fi

    TEST_CONTROLLER="${SSH_USER}@${controller_ip}"
    export TEST_CONTROLLER
    export SSH_KEY_PATH

    echo -e "${GREEN}✓ Controller validated: $controller_ip${NC}"

    mkdir -p "$(dirname "$inventory_file")"

    cat > "$inventory_file" << EOF
[hpc_controllers]
controller ansible_host=${controller_ip} ansible_user=${SSH_USER}

[all:vars]
ansible_ssh_private_key_file=${SSH_KEY_PATH}
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

    echo -e "${GREEN}✓ Ansible inventory created: $inventory_file${NC}"
    return 0
}

TEST_SCRIPTS=("test-pytorch-deployment.sh" "test-tensorflow-deployment.sh" "test-multi-image-deploy.sh" "test-job-container-execution.sh")
TESTS_PASSED=0; TESTS_FAILED=0

main() {
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Test Suite 3: End-to-End Integration Tests${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"; echo ""

  echo -e "${BLUE}Pre-flight Checks:${NC}"
  echo ""

  # Discover and validate controller (generates inventory file)
  echo "• Discovering controller and generating Ansible inventory..."
  if ! discover_and_validate_controller "$TEST_CONFIG" "$ANSIBLE_INVENTORY"; then
    echo -e "${RED}ERROR: Failed to discover or validate controller${NC}"
    echo ""
    echo "Please ensure:"
    echo "  1. Test config exists: $TEST_CONFIG"
    echo "  2. Cluster VMs are running and accessible"
    echo "  3. Controller IP is correctly configured in: $TEST_CONFIG"
    exit 1
  fi
  echo ""

  echo "Test Controller: $TEST_CONTROLLER"
  echo "Ansible Inventory: $ANSIBLE_INVENTORY"
  echo ""

  # Pre-flight checks
  local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes"
  local registry_path="${REGISTRY_PATH:-/opt/containers/ml-frameworks}"
  local test_image="${TEST_IMAGE:-pytorch-cuda12.1-mpi4.1.sif}"

  # Check registry path
  echo "• Checking registry path exists..."
  if ssh -i "$SSH_KEY_PATH" "$ssh_opts" "$TEST_CONTROLLER" "[ -d '$registry_path' ]" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Registry path exists: $registry_path"
  else
    echo -e "  ${RED}✗${NC} Registry path not found: $registry_path"
  fi

  # Check if test image exists
  echo "• Checking test image availability..."
  if ssh -i "$SSH_KEY_PATH" "$ssh_opts" "$TEST_CONTROLLER" "[ -f '$registry_path/$test_image' ]" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Test image available: $test_image"
  else
    echo -e "  ${RED}✗${NC} Test image not found: $test_image"
    echo ""
    echo -e "${RED}WARNING: Required container images are not deployed${NC}"
    echo "E2E tests require container images to be built and deployed."
    echo "See Test Suite 2 output for deployment instructions."
    echo ""
  fi

  # Check Apptainer
  echo "• Checking Apptainer availability..."
  if ssh -i "$SSH_KEY_PATH" "$ssh_opts" "$TEST_CONTROLLER" "command -v apptainer >/dev/null 2>&1"; then
    local apptainer_version
    apptainer_version=$(ssh -i "$SSH_KEY_PATH" "$ssh_opts" "$TEST_CONTROLLER" "apptainer --version 2>&1" || echo "unknown")
    echo -e "  ${GREEN}✓${NC} Apptainer available: $apptainer_version"
  else
    echo -e "  ${RED}✗${NC} Apptainer not found"
  fi

  echo ""
  echo -e "${GREEN}Pre-flight checks complete. Starting E2E tests...${NC}"
  echo ""

  for script in "${TEST_SCRIPTS[@]}"; do
    local script_path="$SCRIPT_DIR/$script"
    [[ ! -x "$script_path" ]] && chmod +x "$script_path"

    echo -e "${BLUE}Running: $script${NC}"

    # Export required environment variables for test scripts
    export TEST_CONTROLLER
    export SSH_KEY_PATH
    export REGISTRY_BASE_PATH
    export REGISTRY_PATH
    export TEST_IMAGE

    # Capture output to a temporary file
    local temp_output
    temp_output=$(mktemp)
    set +e
    "$script_path" > "$temp_output" 2>&1
    local exit_code=$?
    set -e

    # Display output
    cat "$temp_output"
    rm -f "$temp_output"

    if [[ $exit_code -eq 0 ]]; then
      TESTS_PASSED=$((TESTS_PASSED + 1))
      echo -e "${GREEN}✓ $script PASSED${NC}"; echo ""
    else
      TESTS_FAILED=$((TESTS_FAILED + 1))
      echo -e "${RED}✗ $script FAILED${NC}"; echo ""
    fi
  done

  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Final Summary: Test Suite 3${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "Total Tests: ${#TEST_SCRIPTS[@]}"
  echo "Passed: ${GREEN}$TESTS_PASSED${NC}"
  echo "Failed: ${RED}$TESTS_FAILED${NC}"
  echo ""

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓✓✓ All E2E integration tests passed ✓✓✓${NC}"
    exit 0
  else
    echo -e "${RED}✗✗✗ Some E2E integration tests failed ✗✗✗${NC}"
    echo ""
    echo -e "${YELLOW}Common reasons for E2E test failures:${NC}"
    echo "  1. Container images not deployed (see Test Suite 2)"
    echo "  2. SLURM not running or configured correctly"
    echo "  3. Container runtime (Apptainer) issues"
    echo "  4. Network or resource constraints"
    echo ""
    echo "Review the individual test output above for specific error details."
    exit 1
  fi
}
main "$@"
