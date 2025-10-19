#!/bin/bash
#
# Phase 4 Validation: Prerequisites
# Setup environment and verify all dependencies
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Help
# ============================================================================

show_step_help() {
  cat << 'EOF'
Phase 4 Validation - Step 00: Prerequisites

Usage: ./step-00-prerequisites.sh [OPTIONS]

Options:
  -v, --verbose                 Enable verbose command logging
  --log-level LEVEL             Set log level (DEBUG, INFO)
  --validation-folder PATH      Resume from existing validation directory
  -h, --help                    Show this help message

Description:
  Verifies all prerequisites for Phase 4 validation:
  - Docker installation and version
  - CMake configuration
  - pharos-dev Docker image
  - Container tools (Packer, Ansible, CMake)
  - SLURM packages (builds from source)
  - Cluster configuration files
  - Ansible playbooks

  Time: 5-10 minutes (first run with SLURM package build)

EOF
}

# Parse arguments before sourcing full lib-common.sh
source "$SCRIPT_DIR/lib-common.sh"
parse_validation_args "$@"

# ============================================================================
# Main
# ============================================================================

main() {
  log_step_title "00" "Prerequisites"

  # Check if already completed
  if is_step_completed "step-00-prerequisites"; then
    log_warning "Prerequisites already completed at $(get_step_completion_time 'step-00-prerequisites')"
    log_info "Skipping..."
    return 0
  fi

  init_state
  local step_dir="$VALIDATION_ROOT/00-prerequisites"
  create_step_dir "$step_dir"

  # Save environment info
  cat > "$VALIDATION_ROOT/validation-info.txt" << EOF
=== PHASE 4 VALIDATION SESSION ===
Started at: $(date)
User: $(whoami)
Hostname: $(hostname)
Working directory: $(pwd)
Project root: $PROJECT_ROOT
Validation root: $VALIDATION_ROOT

Prerequisites:
EOF

  # 1. Check Docker
  log_info "1. Checking Docker..."
  if ! command -v docker &> /dev/null; then
    log_error "Docker not found"
    return 1
  fi
  DOCKER_VERSION=$(docker --version)
  log_success "Docker: $DOCKER_VERSION"
  echo "  Docker: $DOCKER_VERSION" >> "$VALIDATION_ROOT/validation-info.txt"

  # 2. Check/configure CMake
  log_info "2. Checking CMake..."
  if ! verify_cmake_configured; then
    log_warning "CMake not configured, configuring now..."
    cd "$PROJECT_ROOT"
    log_cmd "make config"
    if ! make config > "$step_dir/cmake-config.log" 2>&1; then
      log_error "CMake configuration failed"
      tail -20 "$step_dir/cmake-config.log"
      return 1
    fi
    log_success "CMake configured"
  fi
  echo "  CMake: Configured" >> "$VALIDATION_ROOT/validation-info.txt"

  # 3. Build/verify Docker image
  log_info "3. Checking Docker image pharos-dev:latest..."
  if ! verify_docker_image; then
    log_warning "Docker image not found, building..."
    cd "$PROJECT_ROOT"
    log_cmd "make build-docker"
    if ! make build-docker > "$step_dir/docker-build.log" 2>&1; then
      log_error "Docker build failed"
      tail -30 "$step_dir/docker-build.log"
      return 1
    fi
    log_success "Docker image built"
  fi
  echo "  Docker Image: pharos-dev:latest" >> "$VALIDATION_ROOT/validation-info.txt"

  # 4. Verify tools in container
  log_info "4. Verifying tools in container..."
  check_tool_in_container "packer"
  check_tool_in_container "ansible" "ansible --version"
  check_tool_in_container "cmake"
  echo "  Container Tools: Verified" >> "$VALIDATION_ROOT/validation-info.txt"

  # 5. Build SLURM packages
  log_info "5. Building SLURM packages from source..."
  cd "$PROJECT_ROOT"
  log_cmd "make run-docker COMMAND='cmake --build build --target build-slurm-packages'"
  if ! make run-docker COMMAND="cmake --build build --target build-slurm-packages" \
    > "$step_dir/slurm-packages-build.log" 2>&1; then
    log_error "SLURM package build failed"
    tail -20 "$step_dir/slurm-packages-build.log"
    return 1
  fi

  if ! verify_slurm_packages; then
    log_error "SLURM packages not found after build"
    return 1
  fi
  echo "  SLURM Packages: Built and Verified" >> "$VALIDATION_ROOT/validation-info.txt"

  # 6. Verify configurations and playbooks
  log_info "6. Verifying configurations and playbooks..."
  verify_example_config || return 1

  # Check playbooks (non-fatal)
  if verify_playbooks; then
    echo "  Playbooks: Verified" >> "$VALIDATION_ROOT/validation-info.txt"
    local playbook_status="All present"
  else
    echo "  Playbooks: Missing (warnings logged)" >> "$VALIDATION_ROOT/validation-info.txt"
    local playbook_status="Some missing (see warnings)"
  fi
  echo "  Configurations: Verified" >> "$VALIDATION_ROOT/validation-info.txt"

  # Create summary
  cat > "$step_dir/validation-summary.txt" << EOF
=== Step 00: Prerequisites Validation ===
Timestamp: $(date)

✅ PASSED

Details:
- Docker: Verified
- CMake: Configured
- Docker Image: pharos-dev:latest
- Container Tools: Packer, Ansible, CMake available
- SLURM Packages: Built from source
- Example Configuration: Found
- Playbooks: $playbook_status

EOF

  mark_step_completed "step-00-prerequisites"
  log_success "Step 00 PASSED: Prerequisites validation complete"
  cat "$step_dir/validation-summary.txt"

  return 0
}

# Run main (arguments already parsed)
main
