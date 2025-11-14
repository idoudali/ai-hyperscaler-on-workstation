#!/bin/bash
# Test Suite 1 Master Runner: Ansible Infrastructure Tests
# Runs all infrastructure validation tests for container registry

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-check-helpers.sh"

# Also source test framework utilities for cluster management
UTILS_DIR="$PROJECT_ROOT/tests/test-infra/utils"
# shellcheck source=../../test-infra/utils/vm-utils.sh
source "$UTILS_DIR/vm-utils.sh"

# Test configuration
TEST_CONFIG="${TEST_CONFIG:-$PROJECT_ROOT/config/example-multi-gpu-clusters.yaml}"
ANSIBLE_INVENTORY="$PROJECT_ROOT/tests/test-infra/inventory/suite1-infrastructure-inventory.ini"
SSH_KEY_PATH="${SSH_KEY_PATH:-$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
SSH_USER="${SSH_USER:-admin}"

# Discover and validate controller, generating Ansible inventory
# Parameters: test_config, inventory_file
discover_and_validate_controller() {
    local test_config="$1"
    local inventory_file="$2"

    [[ -z "$test_config" ]] && echo -e "${RED}ERROR: test_config parameter required${NC}" && return 1
    [[ -z "$inventory_file" ]] && echo -e "${RED}ERROR: inventory_file parameter required${NC}" && return 1

    echo "Extracting controller information from: $test_config"

    # Extract controller IP from YAML config using yq
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

    # Validate SSH connectivity
    if ! wait_for_vm_ssh "$controller_ip" "controller" "30"; then
        echo -e "${RED}ERROR: SSH connectivity failed to controller: $controller_ip${NC}"
        return 1
    fi

    # Set environment variables
    TEST_CONTROLLER="${SSH_USER}@${controller_ip}"
    export TEST_CONTROLLER
    export SSH_KEY_PATH

    echo -e "${GREEN}✓ Controller validated: $controller_ip${NC}"

    # Generate Ansible inventory file
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

# Test scripts in order
TEST_SCRIPTS=(
  "check-registry-structure.sh"
  "check-registry-permissions.sh"
  "check-registry-access.sh"
  "check-cross-node-sync.sh"
)

# Counters
TESTS_EXECUTED=0
TESTS_PASSED=0
TESTS_FAILED=0
declare -a FAILED_TESTS=()

# Main execution
main() {
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Test Suite 1: Ansible Infrastructure Tests${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo ""

  # Pre-flight checks before running tests
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
  echo "Test Scripts: ${#TEST_SCRIPTS[@]}"
  echo ""

  # Check if BeeGFS is mounted and registry exists
  echo "• Checking BeeGFS mount and container registry..."
  local beegfs_mount="/mnt/beegfs"
  local registry_base="${REGISTRY_BASE_PATH:-/mnt/beegfs/containers}"
  local ssh_opts="-o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes"

  if [[ -f "$SSH_KEY_PATH" ]]; then
    # Check BeeGFS mount
    if ssh -i "$SSH_KEY_PATH" "$ssh_opts" "$TEST_CONTROLLER" "mount | grep -q beegfs" 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} BeeGFS is mounted"

      # Check registry directory
      if ssh -i "$SSH_KEY_PATH" "$ssh_opts" "$TEST_CONTROLLER" "[ -d '$registry_base' ]" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Container registry directory exists: $registry_base"
      else
        echo -e "  ${YELLOW}⚠${NC} Container registry directory not found: $registry_base"
        echo "  It will be created automatically during tests if needed"
      fi
    else
      echo -e "  ${RED}✗${NC} BeeGFS is not mounted at $beegfs_mount"
      echo ""
      echo -e "${RED}WARNING: BeeGFS must be deployed before container registry tests${NC}"
      echo "Deploy BeeGFS first with: ./test-beegfs-framework.sh deploy-ansible"
      echo ""
      echo "Continuing with tests (some may fail)..."
    fi
  fi

  echo ""
  echo -e "${GREEN}Pre-flight checks complete. Starting tests...${NC}"
  echo ""

  # Run each test script
  for script in "${TEST_SCRIPTS[@]}"; do
    local script_path="$SCRIPT_DIR/$script"

    if [[ ! -f "$script_path" ]]; then
      echo -e "${RED}ERROR: Test script not found: $script${NC}"
      continue
    fi

    if [[ ! -x "$script_path" ]]; then
      chmod +x "$script_path"
    fi

    echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}Running: $script${NC}"
    echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
    echo ""

    TESTS_EXECUTED=$((TESTS_EXECUTED + 1))

    # Create a temporary file to capture output
    local temp_output
    temp_output=$(mktemp)

    # Export required environment variables for test scripts
    export TEST_CONTROLLER
    export SSH_KEY_PATH
    export REGISTRY_BASE_PATH
    export REGISTRY_PATH
    export TEST_IMAGE

    # Run test and capture output
    set +e
    if bash "$script_path" > "$temp_output" 2>&1; then
      local exit_code=0
    else
      local exit_code=$?
    fi
    set -e

    # Display output
    cat "$temp_output"

    # Check if output was empty (indicates early failure)
    if [[ ! -s "$temp_output" ]]; then
      echo -e "${RED}ERROR: Test script produced no output (possible early failure)${NC}"
      echo "This usually means:"
      echo "  1. SSH command failed silently"
      echo "  2. Script syntax error"
      echo "  3. Missing environment variable"
      echo ""
      echo "Debug information:"
      echo "  Script: $script_path"
      echo "  Controller: $TEST_CONTROLLER"
      echo "  SSH Key: ${SSH_KEY_PATH:-not set}"
      echo ""
      exit_code=1
    fi

    rm -f "$temp_output"

    echo ""

    # Record result
    if [[ $exit_code -eq 0 ]]; then
      TESTS_PASSED=$((TESTS_PASSED + 1))
      echo -e "${GREEN}✓ $script PASSED${NC}"
    else
      TESTS_FAILED=$((TESTS_FAILED + 1))
      FAILED_TESTS+=("$script (exit code: $exit_code)")
      echo -e "${RED}✗ $script FAILED (exit code: $exit_code)${NC}"
    fi

    echo ""
  done

  # Final summary
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Final Summary: Test Suite 1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "Total Test Scripts: $TESTS_EXECUTED"
  echo -e "Passed:             ${GREEN}$TESTS_PASSED${NC}"

  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "Failed:             ${RED}$TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}Failed Tests:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
      echo -e "  ${RED}✗ $test${NC}"
    done
  else
    echo "Failed:             $TESTS_FAILED"
  fi

  echo ""

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓✓✓ All Ansible infrastructure tests passed ✓✓✓${NC}"
    exit 0
  else
    echo -e "${RED}✗✗✗ Some Ansible infrastructure tests failed ✗✗✗${NC}"
    exit 1
  fi
}

main "$@"
