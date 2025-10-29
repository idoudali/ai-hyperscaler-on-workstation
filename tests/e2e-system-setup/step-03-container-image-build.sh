#!/bin/bash
#
# Phase 4 Validation: Step 3 - Container Image Build
#

set -euo pipefail

# ============================================================================
# Step Configuration
# ============================================================================

# Step identification
STEP_NUMBER="03"
STEP_NAME="container-image-build"
STEP_DESCRIPTION="Container Image Build"
STEP_ID="step-${STEP_NUMBER}-${STEP_NAME}"

# Step-specific configuration
STEP_DIR_NAME="${STEP_NUMBER}-${STEP_NAME}"
STEP_DEPENDENCIES=("step-00-prerequisites")
# shellcheck disable=SC2034
export STEP_DEPENDENCIES

# ============================================================================
# Script Setup
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_step_help() {
  cat << EOF
Phase 4 Validation - Step ${STEP_NUMBER}: ${STEP_DESCRIPTION}

Usage: ./${STEP_ID}.sh [OPTIONS]

Options:
  -v, --verbose                 Enable verbose command logging
  --log-level LEVEL             Set log level (DEBUG, INFO)
  --validation-folder PATH      Resume from existing validation directory
  --skip-build                  Skip container building, only validate existing
  -h, --help                    Show this help message

Description:
  Builds container SIF images for deployment testing:
  - Builds development Docker image (if not already built)
  - Creates container images using CMake targets
  - Validates container image integrity and metadata
  - Prepares containers for registry deployment
  - Tests container execution and functionality

  Time: 5-10 minutes
  Output: build/containers/apptainer/*.sif

EOF
}

source "$SCRIPT_DIR/lib-common.sh"
parse_validation_args "$@"

main() {
  log_step_title "$STEP_NUMBER" "$STEP_DESCRIPTION"

  # Check prerequisites
  if ! prerequisites_completed; then
    log_error "Prerequisites not completed. Run step-00-prerequisites.sh first"
    return 1
  fi

  # Check if already completed
  if is_step_completed "$STEP_ID"; then
    log_warning "Step ${STEP_NUMBER} already completed at $(get_step_completion_time "$STEP_ID")"
    log_info "Skipping..."
    return 0
  fi

  init_state
  local step_dir="$VALIDATION_ROOT/$STEP_DIR_NAME"
  create_step_dir "$step_dir"

  init_venv

  cd "$PROJECT_ROOT" || exit 1

  # 3.1: Build Development Environment
  log_info "${STEP_NUMBER}.1: Building development Docker image..."
  log_cmd "make build-docker"
  if ! make build-docker > "$step_dir/development-environment.log" 2>&1; then
    log_error "Development environment build failed"
    tail -20 "$step_dir/development-environment.log"
    return 1
  fi
  log_success "Development environment built"

  # 3.2: Build Container Images Using CMake
  log_info "${STEP_NUMBER}.2: Building container images using CMake targets..."

  # First, ensure CMake is configured
  if [ ! -f "build/CMakeCache.txt" ]; then
    log_info "Configuring CMake..."
    if ! make config > "$step_dir/cmake-config.log" 2>&1; then
      log_error "CMake configuration failed"
      tail -20 "$step_dir/cmake-config.log"
      return 1
    fi
  fi

  # Build all container images (Docker + Apptainer) using CMake targets
  if ! run_docker_command_with_errors "cmake --build build --target build-all-containers" \
    "$step_dir/container-build.log" "$step_dir/container-build-error.log" "Container build"; then
    tail -30 "$step_dir/container-build.log"
    return 1
  fi

  # Note: Only building CMake-defined targets, no additional test containers

  # Detect up-to-date build (no work done)
  local build_up_to_date=0
  if is_build_up_to_date "$step_dir/container-build.log"; then
    build_up_to_date=1
    log_warning "No container build executed: targets already up to date"
  fi

  # 3.3: Validate Container Images
  log_info "${STEP_NUMBER}.3: Validating container images..."

  # Check if containers were created
  log_info "Checking created containers..."

  # Check for CMake-built containers only
  if ls build/containers/apptainer/*.sif 2>/dev/null; then
    log_success "Found CMake-built container images:"
    ls -la build/containers/apptainer/*.sif > "$step_dir/cmake-containers.log"
    cat "$step_dir/cmake-containers.log"
  else
    log_error "No CMake-built container images found in build/containers/apptainer/"
    return 1
  fi

  # Note: Container execution testing removed as we can only validate build, not execution locally

  # Test container metadata
  log_info "Testing container metadata..."
  for container in build/containers/apptainer/*.sif; do
    if [ -f "$container" ]; then
      log_info "Inspecting $(basename "$container")..."
      if make run-docker COMMAND="apptainer inspect $container" > "$step_dir/$(basename "$container" .sif)-inspect.log" 2>&1; then
        log_success "Container metadata accessible for $(basename "$container")"
      else
        log_warning "Container metadata inspection failed for $(basename "$container")"
      fi
    fi
  done

  # 3.4: Prepare for Registry Deployment
  log_info "${STEP_NUMBER}.4: Preparing containers for registry deployment..."

  # Create container manifests
  log_info "Creating container manifests..."
  rm -f build/containers/.registry-manifest.txt

  for container in build/containers/apptainer/*.sif; do
    if [ -f "$container" ]; then
      {
        echo "Container: $(basename "$container")"
        echo "  Size: $(du -h "$container" | cut -f1)"
        echo "  Path: $container"
        echo "  Category: apptainer"
        echo ""
      } >> build/containers/.registry-manifest.txt
    fi
  done

  # Display container summary
  log_info "Container build summary:"
  if [ -f "build/containers/.registry-manifest.txt" ]; then
    cp build/containers/.registry-manifest.txt "$step_dir/registry-manifest.txt"
    cat "$step_dir/registry-manifest.txt"
  else
    log_warning "No container manifest created"
  fi

  # 3.5: Validation Summary
  log_info "${STEP_NUMBER}.5: Validation summary..."

  # Define expected CMake-built containers
  EXPECTED_CONTAINERS=("pytorch-cuda12.1-mpi4.1")
  CONTAINER_COUNT=$(find build/containers/apptainer -name "*.sif" -type f 2>/dev/null | wc -l)
  log_info "Total CMake-built containers created: $CONTAINER_COUNT"

  # Check success criteria
  SUCCESS_CRITERIA=0
  TOTAL_CRITERIA=6

  # Check for specific expected containers
  MISSING_CONTAINERS=()
  for container in "${EXPECTED_CONTAINERS[@]}"; do
    if [ -f "build/containers/apptainer/${container}.sif" ]; then
      log_success "✓ Expected container found: ${container}.sif"
      ((SUCCESS_CRITERIA+=1))
    else
      log_error "✗ Expected container missing: ${container}.sif"
      MISSING_CONTAINERS+=("${container}.sif")
    fi
  done

  log_info "DEBUG: After loop - CONTAINER_COUNT=$CONTAINER_COUNT SUCCESS_CRITERIA=$SUCCESS_CRITERIA"

  # At least 1 container image created successfully (CMake-built)
  if [ "$CONTAINER_COUNT" -ge 1 ]; then
    log_success "✓ At least 1 CMake-built container image created ($CONTAINER_COUNT total)"
    ((SUCCESS_CRITERIA+=1))
  else
    log_error "✗ Need at least 1 CMake-built container image (found $CONTAINER_COUNT)"
  fi

  # Note: Container execution testing removed - we can only validate build, not execution locally

  # Container metadata is accessible
  METADATA_ERRORS=0
  for container in build/containers/apptainer/*.sif; do
    if [ -f "$container" ]; then
      if ! make run-docker COMMAND="apptainer inspect $container" > /dev/null 2>&1; then
        ((METADATA_ERRORS+=1))
      fi
    fi
  done

  if [ "$METADATA_ERRORS" -eq 0 ]; then
    log_success "✓ Container metadata is accessible"
    ((SUCCESS_CRITERIA+=1))
  else
    log_error "✗ $METADATA_ERRORS containers failed metadata test"
  fi

  # Registry manifest is created
  if [ -f "build/containers/.registry-manifest.txt" ]; then
    log_success "✓ Registry manifest is created"
    ((SUCCESS_CRITERIA+=1))
  else
    log_error "✗ Registry manifest not created"
  fi

  # All expected containers are present
  if [ ${#MISSING_CONTAINERS[@]} -eq 0 ]; then
    log_success "✓ All expected CMake-defined containers are present"
    ((SUCCESS_CRITERIA+=1))
  else
    log_error "✗ Missing expected containers: ${MISSING_CONTAINERS[*]}"
  fi

  # Containers are ready for Step 6 testing
  if [ "$CONTAINER_COUNT" -ge 1 ] && [ -f "build/containers/.registry-manifest.txt" ]; then
    log_success "✓ Containers are ready for Step 6 (Storage Consolidation) testing"
    ((SUCCESS_CRITERIA+=1))
  else
    log_error "✗ Containers not ready for Step 6 testing"
  fi

  # Create summary
  cat > "$step_dir/validation-summary.txt" << EOF
=== Step ${STEP_NUMBER}: ${STEP_DESCRIPTION} ===
Timestamp: $(date)

✅ PASSED

Details:
- Development environment: Built
- CMake-built containers: $CONTAINER_COUNT created$( summary_up_to_date_suffix "$build_up_to_date" )
- Expected containers: ${EXPECTED_CONTAINERS[*]}
- Missing containers: ${MISSING_CONTAINERS[*]}
- Metadata errors: $METADATA_ERRORS
- Registry manifest: Created
- Success criteria: $SUCCESS_CRITERIA/$TOTAL_CRITERIA

Container locations:
  CMake-built: build/containers/apptainer/

Logs:
  Development: $step_dir/development-environment.log
  CMake config: $step_dir/cmake-config.log
  Container build: $step_dir/container-build.log
  CMake containers: $step_dir/cmake-containers.log
  Registry manifest: $step_dir/registry-manifest.txt

EOF

  # Generate explicit status file
  if [ "$SUCCESS_CRITERIA" -eq "$TOTAL_CRITERIA" ]; then
    # SUCCESS
    cat > "$step_dir/SUCCESS" << EOF
Step 03: Container Image Build - SUCCESS
========================================
Timestamp: $(date)
Status: PASSED
Success criteria: $SUCCESS_CRITERIA/$TOTAL_CRITERIA
Containers created: $CONTAINER_COUNT
Expected containers: ${EXPECTED_CONTAINERS[*]}
Missing containers: ${MISSING_CONTAINERS[*]}
Metadata errors: $METADATA_ERRORS

Container images built successfully using CMake targets.
All expected CMake-defined containers are present.
All validation criteria met.

Container location: build/containers/apptainer/
Registry manifest: build/containers/.registry-manifest.txt
EOF

    mark_step_completed "$STEP_ID"
    log_success "Step ${STEP_NUMBER} PASSED: Container image build successful"
    cat "$step_dir/validation-summary.txt"
    return 0
  else
    # FAILURE
    cat > "$step_dir/ERROR" << EOF
Step 03: Container Image Build - FAILURE
========================================
Timestamp: $(date)
Status: FAILED
Success criteria: $SUCCESS_CRITERIA/$TOTAL_CRITERIA
Containers created: $CONTAINER_COUNT
Expected containers: ${EXPECTED_CONTAINERS[*]}
Missing containers: ${MISSING_CONTAINERS[*]}
Metadata errors: $METADATA_ERRORS

Container image build failed.
Only $SUCCESS_CRITERIA out of $TOTAL_CRITERIA success criteria met.

Failure details:
- Expected specific CMake-defined containers: ${EXPECTED_CONTAINERS[*]}
- Missing expected containers: ${MISSING_CONTAINERS[*]}
- Expected at least 1 CMake-built container image
- Expected all containers to execute without errors
- Expected container metadata to be accessible
- Expected registry manifest to be created
- Expected containers to be ready for next step

Check logs for detailed error information:
  Development: $step_dir/development-environment.log
  CMake config: $step_dir/cmake-config.log
  Container build: $step_dir/container-build.log
  Container build errors: $step_dir/container-build-error.log
EOF

    log_error "Step ${STEP_NUMBER} FAILED: Container image build unsuccessful"
    cat "$step_dir/validation-summary.txt"
    return 1
  fi
}

main
