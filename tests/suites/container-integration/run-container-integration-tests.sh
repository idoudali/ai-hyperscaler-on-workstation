#!/bin/bash
# Container Integration Test Suite Master Runner
# Runs all container integration validation tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

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
TEST_CONFIG="${TEST_CONFIG:-$PROJECT_ROOT/tests/test-infra/configs/test-container-integration.yaml}"
ANSIBLE_INVENTORY="$PROJECT_ROOT/tests/test-infra/inventory/container-integration-inventory.ini"
SSH_KEY_PATH="${SSH_KEY_PATH:-$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
SSH_USER="${SSH_USER:-admin}"

# Container configuration
export CONTAINER_IMAGE="${CONTAINER_IMAGE:-/opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif}"
export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-apptainer}"

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
  "check-container-functionality.sh"
  "check-pytorch-cuda-integration.sh"
  "check-mpi-communication.sh"
  "check-distributed-training.sh"
  "check-container-slurm-integration.sh"
)

# Counters
TESTS_EXECUTED=0
TESTS_PASSED=0
TESTS_FAILED=0
declare -a FAILED_TESTS=()

# Main execution
main() {
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Container Integration Test Suite${NC}"
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
    echo ""
    echo "Required infrastructure must be deployed:"
    echo "  - TASK-019: PyTorch Container built"
    echo "  - TASK-020: Container converted to Apptainer"
    echo "  - TASK-021: Container Registry deployed"
    echo "  - TASK-022: SLURM Compute Nodes installed"
    echo "  - TASK-023: GPU GRES configured"
    echo "  - TASK-024: Cgroup isolation active"
    exit 1
  fi
  echo ""

  echo "Test Controller: $TEST_CONTROLLER"
  echo "Container Image: $CONTAINER_IMAGE"
  echo "Container Runtime: $CONTAINER_RUNTIME"
  echo "Ansible Inventory: $ANSIBLE_INVENTORY"
  echo "Test Scripts: ${#TEST_SCRIPTS[@]}"
  echo ""

  # Check if container image exists
  echo "• Checking container image availability..."
  local ssh_opts=(-o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes)

  if [[ -f "$SSH_KEY_PATH" ]]; then
    if ssh -i "$SSH_KEY_PATH" "${ssh_opts[@]}" "$TEST_CONTROLLER" "[ -f '$CONTAINER_IMAGE' ]" 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} Container image exists: $CONTAINER_IMAGE"
    else
      echo -e "  ${RED}✗${NC} Container image not found: $CONTAINER_IMAGE"
      echo ""
      echo -e "${RED}ERROR: Container image must be deployed before running integration tests${NC}"
      echo ""
      echo "Quick deployment (recommended):"
      echo "  cd tests && make test-container-registry-deploy"
      echo ""
      echo "This will automatically:"
      echo "  1. Build Docker container images"
      echo "  2. Convert to Apptainer SIF format"
      echo "  3. Deploy to cluster via SSH/rsync"
      echo ""
      echo "Manual deployment workflow (if needed):"
      echo "  1. Build: make run-docker COMMAND='cmake --build build --target build-docker-pytorch-cuda12.1-mpi4.1'"
      echo "  2. Convert: make run-docker COMMAND='cmake --build build --target convert-to-apptainer-pytorch-cuda12.1-mpi4.1'"
      echo "  3. Deploy: rsync -avz build/containers/apptainer/*.sif admin@192.168.220.10:/opt/containers/ml-frameworks/"
      echo ""
      exit 1
    fi
  else
    echo -e "  ${RED}✗${NC} SSH key not found: $SSH_KEY_PATH"
    exit 1
  fi

  # Check if SLURM is running
  echo "• Checking SLURM availability..."
  if ssh -i "$SSH_KEY_PATH" "${ssh_opts[@]}" "$TEST_CONTROLLER" "sinfo --version >/dev/null 2>&1" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} SLURM is running"
  else
    echo -e "  ${RED}✗${NC} SLURM is not running or not accessible"
    echo ""
    echo -e "${YELLOW}WARNING: Some integration tests may fail without SLURM${NC}"
    echo "SLURM deployment:"
    echo "  1. Deploy controller: cd tests && make test-slurm-controller-deploy"
    echo "  2. Deploy compute nodes: cd tests && make test-slurm-compute-deploy"
    echo ""
    echo "Continuing with tests (some may be skipped)..."
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
    export CONTAINER_IMAGE
    export CONTAINER_RUNTIME

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
  echo -e "${BLUE}  Final Summary: Container Integration Test Suite${NC}"
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
    echo ""
    echo "Common issues:"
    echo "  - Container image not deployed"
    echo "  - SLURM not running or misconfigured"
    echo "  - GPU GRES not configured"
    echo "  - Cgroup isolation not active"
    echo "  - Network connectivity issues"
  else
    echo "Failed:             $TESTS_FAILED"
  fi

  echo ""

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓✓✓ All container integration tests passed ✓✓✓${NC}"
    echo ""
    echo "Container integration validation complete:"
    echo "  ✓ Container functionality validated"
    echo "  ✓ PyTorch + CUDA integration confirmed"
    echo "  ✓ MPI communication functional"
    echo "  ✓ Distributed training environment ready"
    echo "  ✓ SLURM + container integration validated"
    exit 0
  else
    echo -e "${RED}✗✗✗ Some container integration tests failed ✗✗✗${NC}"
    exit 1
  fi
}

main "$@"
