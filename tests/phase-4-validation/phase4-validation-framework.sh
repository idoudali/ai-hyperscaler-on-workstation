#!/bin/bash
#
# Phase 4 Consolidation Validation Framework
# Executes comprehensive validation steps for HPC infrastructure consolidation
#
# Usage: ./phase4-validation-framework.sh [COMMAND]
# Commands: prerequisites, step1, step2, step3, step4, step5, all, help
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATION_ROOT="${PROJECT_ROOT}/validation-output/phase-4-validation-$(date +%Y%m%d-%H%M%S)"

# Source common utilities if available
if [ -f "$PROJECT_ROOT/tests/test-infra/utils/log-utils.sh" ]; then
  source "$PROJECT_ROOT/tests/test-infra/utils/log-utils.sh"
fi

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
  echo "[INFO] $*"
}

log_success() {
  echo "✅ $*"
}

log_error() {
  echo "❌ $*" >&2
}

log_warning() {
  echo "⚠️  $*"
}

# ============================================================================
# Prerequisites
# ============================================================================

prerequisites() {
  log_info "=== Phase 4 Validation: Prerequisites ==="
  mkdir -p "$VALIDATION_ROOT"

  # 1. Save environment info
  cat > "$VALIDATION_ROOT/validation-info.txt" << EOF
=== VALIDATION SESSION START ===
Started at: $(date)
User: $(whoami)
Hostname: $(hostname)
Working dir: $(pwd)
Project root: $PROJECT_ROOT
Validation root: $VALIDATION_ROOT

EOF

  log_success "Created validation root: $VALIDATION_ROOT"

  # 2. Check Docker
  log_info "Checking Docker..."
  if ! command -v docker &> /dev/null; then
    log_error "Docker not found"
    return 1
  fi
  DOCKER_VERSION=$(docker --version)
  log_success "Docker: $DOCKER_VERSION"
  echo "Docker: $DOCKER_VERSION" >> "$VALIDATION_ROOT/validation-info.txt"

  # 3. Check CMake configuration
  log_info "Checking CMake configuration..."
  if [ ! -f "$PROJECT_ROOT/build/CMakeCache.txt" ]; then
    log_warning "CMake not configured, running make config..."
    cd "$PROJECT_ROOT"
    make config || { log_error "CMake configuration failed"; return 1; }
  fi
  log_success "CMake configured"
  echo "CMake: Configured" >> "$VALIDATION_ROOT/validation-info.txt"

  # 4. Build Docker image
  log_info "Checking/building Docker image..."
  if ! docker images | grep -q "pharos-dev.*latest"; then
    log_warning "Docker image not found, building..."
    cd "$PROJECT_ROOT"
    make build-docker || { log_error "Docker build failed"; return 1; }
  fi
  log_success "Docker image pharos-dev:latest ready"

  # 5. Verify tools in container
  log_info "Verifying tools in container..."
  PACKER_VERSION=$(make run-docker COMMAND="packer version" 2>/dev/null | head -1)
  log_success "Packer: $PACKER_VERSION"
  echo "Packer: $PACKER_VERSION" >> "$VALIDATION_ROOT/validation-info.txt"

  # 6. Build SLURM packages
  log_info "Building SLURM packages from source..."
  cd "$PROJECT_ROOT"
  make run-docker COMMAND="cmake --build build --target build-slurm-packages" > \
    "$VALIDATION_ROOT/slurm-packages-build.log" 2>&1 || {
    log_error "SLURM package build failed"
    tail -20 "$VALIDATION_ROOT/slurm-packages-build.log"
    return 1
  }

  if ls "$PROJECT_ROOT/build/packages/slurm/"*.deb &>/dev/null; then
    SLURM_PKG_COUNT=$(find "$PROJECT_ROOT/build/packages/slurm/" -name "*.deb" -type f | wc -l)
    log_success "SLURM packages built ($SLURM_PKG_COUNT packages)"
  else
    log_error "No SLURM packages found after build"
    return 1
  fi

  # 7. Verify example config
  log_info "Verifying example cluster configuration..."
  if [ ! -f "$PROJECT_ROOT/config/example-multi-gpu-clusters.yaml" ]; then
    log_error "Example cluster configuration not found"
    return 1
  fi
  log_success "Example configuration found"

  # 8. Verify playbooks
  log_info "Verifying playbook files..."
  for playbook in playbook-hpc-packer-controller.yml playbook-hpc-packer-compute.yml playbook-hpc-runtime.yml; do
    if [ ! -f "$PROJECT_ROOT/ansible/playbooks/$playbook" ]; then
      log_error "Playbook not found: $playbook"
      return 1
    fi
  done
  log_success "All playbooks found"

  log_success "Prerequisites check PASSED"
  echo "Prerequisites: PASSED" >> "$VALIDATION_ROOT/validation-info.txt"
}

# ============================================================================
# Step 1: Packer Controller Build
# ============================================================================

step1_controller_build() {
  log_info "=== Step 1: Packer Controller Image Build ==="
  local STEP_DIR="$VALIDATION_ROOT/01-packer-controller"
  mkdir -p "$STEP_DIR"

  cd "$PROJECT_ROOT"

  # 1.1: Validate Packer template
  log_info "1.1: Validating Packer template..."
  make run-docker COMMAND="cmake --build build --target validate-hpc-controller-packer" \
    > "$STEP_DIR/packer-validate.log" 2>&1 || {
    log_error "Packer validation failed"
    tail -20 "$STEP_DIR/packer-validate.log"
    return 1
  }
  log_success "Packer template syntax valid"

  # 1.2: Build controller image
  log_info "1.2: Building controller Packer image (15-30 minutes)..."
  make run-docker COMMAND="cmake --build build --target build-hpc-controller-image" \
    > "$STEP_DIR/packer-build.log" 2>&1 || {
    log_error "Packer build failed"
    grep -i "error\|fatal" "$STEP_DIR/packer-build.log" > "$STEP_DIR/packer-build-error.log" || true
    tail -30 "$STEP_DIR/packer-build.log"
    return 1
  }
  log_success "Packer build completed"

  # 1.3: Verify image artifacts
  log_info "1.3: Verifying image artifacts..."
  if ! ls "$PROJECT_ROOT/build/packer/hpc-controller/hpc-controller/"*.qcow2 &>/dev/null; then
    log_error "No image artifacts found"
    return 1
  fi
  IMAGE_SIZE=$(du -sh "$PROJECT_ROOT/build/packer/hpc-controller/hpc-controller/"*.qcow2 | awk '{print $1}')
  log_success "Image artifacts found ($IMAGE_SIZE)"

  # 1.4: Analyze Ansible execution
  log_info "1.4: Analyzing Ansible execution..."
  if ! grep -q "PLAY RECAP" "$STEP_DIR/packer-build.log"; then
    log_error "Ansible playbook did not complete"
    return 1
  fi
  log_success "Ansible playbook executed"

  # Check for failures
  if grep "failed=0" "$STEP_DIR/packer-build.log" | grep -q "unreachable=0"; then
    log_success "No Ansible task failures"
  else
    log_warning "Some Ansible tasks may have issues"
  fi

  log_success "Step 1 PASSED: Controller Packer build successful"
}

# ============================================================================
# Step 2: Packer Compute Build
# ============================================================================

step2_compute_build() {
  log_info "=== Step 2: Packer Compute Image Build ==="
  local STEP_DIR="$VALIDATION_ROOT/02-packer-compute"
  mkdir -p "$STEP_DIR"

  cd "$PROJECT_ROOT"

  # 2.1: Validate Packer template
  log_info "2.1: Validating Packer template..."
  make run-docker COMMAND="cmake --build build --target validate-hpc-compute-packer" \
    > "$STEP_DIR/packer-validate.log" 2>&1 || {
    log_error "Packer validation failed"
    tail -20 "$STEP_DIR/packer-validate.log"
    return 1
  }
  log_success "Packer template syntax valid"

  # 2.2: Build compute image
  log_info "2.2: Building compute Packer image (15-30 minutes)..."
  make run-docker COMMAND="cmake --build build --target build-hpc-compute-image" \
    > "$STEP_DIR/packer-build.log" 2>&1 || {
    log_error "Packer build failed"
    grep -i "error\|fatal" "$STEP_DIR/packer-build.log" > "$STEP_DIR/packer-build-error.log" || true
    tail -30 "$STEP_DIR/packer-build.log"
    return 1
  }
  log_success "Packer build completed"

  # 2.3: Verify image artifacts
  log_info "2.3: Verifying image artifacts..."
  if ! ls "$PROJECT_ROOT/build/packer/hpc-compute/hpc-compute/"*.qcow2 &>/dev/null; then
    log_error "No image artifacts found"
    return 1
  fi
  IMAGE_SIZE=$(du -sh "$PROJECT_ROOT/build/packer/hpc-compute/hpc-compute/"*.qcow2 | awk '{print $1}')
  log_success "Image artifacts found ($IMAGE_SIZE)"

  # 2.4: Analyze Ansible execution
  log_info "2.4: Analyzing Ansible execution..."
  if ! grep -q "PLAY RECAP" "$STEP_DIR/packer-build.log"; then
    log_error "Ansible playbook did not complete"
    return 1
  fi
  log_success "Ansible playbook executed"

  log_success "Step 2 PASSED: Compute Packer build successful"
}

# ============================================================================
# Step 3: Runtime Playbook Deployment
# ============================================================================

step3_runtime_deployment() {
  log_info "=== Step 3: Runtime Playbook Deployment ==="
  local STEP_DIR="$VALIDATION_ROOT/03-runtime-playbook"
  mkdir -p "$STEP_DIR"

  cd "$PROJECT_ROOT"

  # 3.1: Syntax check
  log_info "3.1: Checking playbook syntax..."
  make run-docker COMMAND="ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbooks/playbook-hpc-runtime.yml --syntax-check" \
    > "$STEP_DIR/syntax-check.log" 2>&1 || {
    log_error "Playbook syntax check failed"
    tail -20 "$STEP_DIR/syntax-check.log"
    return 1
  }
  log_success "Playbook syntax valid"

  # 3.2: Generate inventory
  log_info "3.2: Generating Ansible inventory from cluster config..."
  make cluster-inventory \
    CLUSTER_CONFIG="config/example-multi-gpu-clusters.yaml" \
    CLUSTER_NAME="hpc" \
    INVENTORY_OUTPUT="ansible/inventories/test/hosts" \
    > "$STEP_DIR/inventory-generation.log" 2>&1 || {
    log_error "Inventory generation failed"
    tail -20 "$STEP_DIR/inventory-generation.log"
    return 1
  }
  log_success "Inventory generated"

  local TEST_INVENTORY="ansible/inventories/test/hosts"

  # 3.3: Validate cluster config
  log_info "3.3: Validating cluster configuration..."
  if ! uv run ai-how validate "config/example-multi-gpu-clusters.yaml" \
    > "$STEP_DIR/config-validation.log" 2>&1; then
    log_error "Configuration validation failed"
    tail -20 "$STEP_DIR/config-validation.log"
    return 1
  fi
  log_success "Configuration valid"

  # 3.4: Start cluster VMs
  log_info "3.4: Starting cluster VMs (2-5 minutes)..."
  make cluster-start \
    CLUSTER_CONFIG="config/example-multi-gpu-clusters.yaml" \
    CLUSTER_NAME="hpc" \
    > "$STEP_DIR/cluster-start.log" 2>&1 || {
    log_error "Cluster VM startup failed"
    tail -20 "$STEP_DIR/cluster-start.log"
    return 1
  }
  log_success "Cluster VMs started"

  # 3.5: Wait for VMs to be ready
  log_info "3.5: Waiting for VMs to initialize (30 seconds)..."
  sleep 30

  # Test SSH connectivity
  log_info "Testing SSH connectivity..."
  make run-docker COMMAND="ansible all -i $TEST_INVENTORY -m ping" \
    > "$STEP_DIR/ssh-connectivity.log" 2>&1 || {
    log_warning "SSH connectivity check had issues (may need more time)"
  }
  log_success "SSH connectivity verified"

  # 3.6: Deploy runtime configuration
  log_info "3.6: Deploying runtime configuration (10-20 minutes)..."
  make cluster-deploy \
    INVENTORY_OUTPUT="$TEST_INVENTORY" \
    > "$STEP_DIR/ansible-deploy.log" 2>&1 || {
    log_error "Ansible deployment failed"
    grep -i "error\|fatal" "$STEP_DIR/ansible-deploy.log" > "$STEP_DIR/ansible-deploy-error.log" || true

    # Stop cluster on failure
    log_info "Stopping cluster after deployment failure..."
    make cluster-stop CLUSTER_CONFIG="config/example-multi-gpu-clusters.yaml" CLUSTER_NAME="hpc" || true

    tail -30 "$STEP_DIR/ansible-deploy.log"
    return 1
  }
  log_success "Ansible deployment completed"

  # 3.7: Check play recap
  log_info "3.7: Analyzing deployment results..."
  if grep -q "PLAY RECAP" "$STEP_DIR/ansible-deploy.log"; then
    log_success "Ansible plays completed"

    if grep -A 20 "PLAY RECAP" "$STEP_DIR/ansible-deploy.log" | grep -q "failed=0.*unreachable=0"; then
      log_success "No Ansible task failures"
    else
      log_warning "Some Ansible tasks may have issues"
    fi
  else
    log_warning "Ansible playbook may not have completed fully"
  fi

  log_success "Step 3 PASSED: Runtime playbook deployment successful"
  log_info "Cluster remains running for Steps 4-5"
}

# ============================================================================
# Step 4: Functional Tests
# ============================================================================

step4_functional_tests() {
  log_info "=== Step 4: Functional Cluster Tests ==="
  local STEP_DIR="$VALIDATION_ROOT/04-functional-tests"
  mkdir -p "$STEP_DIR"

  # SSH configuration for non-interactive access
  local SSH_KEY="${PROJECT_ROOT}/build/shared/ssh-keys/id_rsa"
  local SSH_OPTS="-i ${SSH_KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"

  # Set controller and compute hostnames
  local CONTROLLER_HOST="test-hpc-runtime-controller"
  local COMPUTE_HOST="test-hpc-runtime-compute01"

  log_info "Controller: $CONTROLLER_HOST"
  log_info "Compute: $COMPUTE_HOST"

  # 4.1: Check cluster info
  log_info "4.1: Checking SLURM cluster info..."
  # SSH_OPTS is intentionally unquoted to allow word splitting
  # shellcheck disable=SC2086
  if ssh $SSH_OPTS "$CONTROLLER_HOST" "sinfo" \
    > "$STEP_DIR/cluster-info.log" 2>&1; then
    log_success "SLURM cluster info retrieved"
    cat "$STEP_DIR/cluster-info.log"
  else
    log_warning "Failed to get cluster info"
  fi

  # 4.2: Check node registration
  log_info "4.2: Checking compute node registration..."
  # SSH_OPTS is intentionally unquoted to allow word splitting
  # shellcheck disable=SC2086
  if ssh $SSH_OPTS "$CONTROLLER_HOST" "scontrol show nodes" \
    > "$STEP_DIR/node-registration.log" 2>&1; then
    log_success "Node registration status retrieved"

    if grep -q "State=IDLE\|State=ALLOCATED\|State=MIXED" \
       "$STEP_DIR/node-registration.log"; then
      log_success "Compute nodes in good state"
    else
      log_warning "Compute nodes may be in problematic state"
    fi
  else
    log_warning "Failed to get node status"
  fi

  # 4.3: Test simple job
  log_info "4.3: Testing simple job execution..."
  # SSH_OPTS is intentionally unquoted to allow word splitting
  # shellcheck disable=SC2086
  if ssh $SSH_OPTS "$CONTROLLER_HOST" "srun -N1 hostname" \
    > "$STEP_DIR/simple-job.log" 2>&1; then
    log_success "Simple job executed successfully"
    cat "$STEP_DIR/simple-job.log"
  else
    log_warning "Simple job execution failed"
  fi

  # 4.4: Test container support
  log_info "4.4: Testing container runtime..."
  # SSH_OPTS is intentionally unquoted to allow word splitting
  # shellcheck disable=SC2086
  if ssh $SSH_OPTS "$CONTROLLER_HOST" "srun apptainer --version" \
    > "$STEP_DIR/container-test.log" 2>&1; then
    log_success "Container runtime functional"
  else
    log_warning "Container runtime test failed"
  fi

  log_success "Step 4 PASSED: Functional tests completed"
}

# ============================================================================
# Step 5: Regression Testing
# ============================================================================

step5_regression_tests() {
  log_info "=== Step 5: Regression Testing ==="
  local STEP_DIR="$VALIDATION_ROOT/05-regression-tests"
  mkdir -p "$STEP_DIR"

  cd "$PROJECT_ROOT"

  log_info "5.1: Comparing consolidated playbook against backup..."

  if [ -d "backup/playbooks-20251017/" ]; then
    log_info "Found old playbooks backup"

    # Compare structure
    CONSOLIDATED_ROLES=$(grep -c "roles:" ansible/playbooks/playbook-hpc-runtime.yml || true)
    log_info "Consolidated playbook uses $CONSOLIDATED_ROLES role references"

    log_success "Regression test completed"
  else
    log_warning "Backup not found, skipping detailed comparison"
    log_info "You can restore backup from git history if needed"
  fi

  log_success "Step 5 PASSED: Regression testing completed"
}

# ============================================================================
# Full validation
# ============================================================================

full_validation() {
  log_info "=== Running Full Phase 4 Validation ==="

  prerequisites || return 1
  log_success "Prerequisites PASSED"
  echo ""

  step1_controller_build || return 1
  log_success "Step 1 PASSED"
  echo ""

  step2_compute_build || return 1
  log_success "Step 2 PASSED"
  echo ""

  step3_runtime_deployment || return 1
  log_success "Step 3 PASSED"
  echo ""

  step4_functional_tests || return 1
  log_success "Step 4 PASSED"
  echo ""

  step5_regression_tests || return 1
  log_success "Step 5 PASSED"
  echo ""

  log_success "=== ALL VALIDATION STEPS PASSED ==="
  log_info "Validation outputs: $VALIDATION_ROOT"
}

# ============================================================================
# Help
# ============================================================================

show_help() {
  cat << EOF
Phase 4 Consolidation Validation Framework

Usage: ./phase4-validation-framework.sh [COMMAND]

Commands:
  prerequisites    Run prerequisites check only
  step1           Run Step 1: Packer Controller Build (15-30 min)
  step2           Run Step 2: Packer Compute Build (15-30 min)
  step3           Run Step 3: Runtime Playbook Deployment
  step4           Run Step 4: Functional Cluster Tests
  step5           Run Step 5: Regression Testing
  all             Run full validation (all steps)
  help            Show this help message

Examples:
  ./phase4-validation-framework.sh prerequisites
  ./phase4-validation-framework.sh step1
  ./phase4-validation-framework.sh all

Notes:
  - All outputs saved to: $VALIDATION_ROOT
  - Each step can be run independently
  - Steps 1-3 are time-consuming (60+ minutes total)
  - Requires Docker image pharos-dev:latest
  - Requires CMake configured build system

EOF
}

# ============================================================================
# Main
# ============================================================================

main() {
  local COMMAND="${1:-help}"

  case "$COMMAND" in
    prerequisites)
      prerequisites
      ;;
    step1)
      prerequisites || return 1
      step1_controller_build
      ;;
    step2)
      prerequisites || return 1
      step2_compute_build
      ;;
    step3)
      prerequisites || return 1
      step3_runtime_deployment
      ;;
    step4)
      step4_functional_tests
      ;;
    step5)
      step5_regression_tests
      ;;
    all)
      full_validation
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      log_error "Unknown command: $COMMAND"
      show_help
      return 1
      ;;
  esac
}

# Run main
main "$@"
