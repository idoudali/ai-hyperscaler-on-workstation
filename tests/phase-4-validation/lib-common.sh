#!/bin/bash
#
# Common utilities for Phase 4 validation framework
# Provides logging, state management, and utility functions
#

# ============================================================================
# Configuration
# ============================================================================

# Project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Logging level (default: INFO)
# Set VALIDATION_VERBOSE=1 or VALIDATION_LOG_LEVEL=DEBUG to see command execution
VALIDATION_LOG_LEVEL="${VALIDATION_LOG_LEVEL:-INFO}"
VALIDATION_VERBOSE="${VALIDATION_VERBOSE:-0}"

# Validation output root (set after argument parsing)
# Will be initialized by init_validation_root() after parse_validation_args()
VALIDATION_ROOT="${VALIDATION_ROOT:-}"
STATE_DIR=""

# ============================================================================
# Command-Line Argument Parsing
# ============================================================================

# Initialize validation root directory
init_validation_root() {
  local is_resume=0

  # If VALIDATION_ROOT not set, create new timestamped directory
  if [ -z "${VALIDATION_ROOT}" ]; then
    VALIDATION_ROOT="${PROJECT_ROOT}/validation-output/phase-4-validation-$(date +%Y%m%d-%H%M%S)"
  else
    # Remove trailing slash if present
    VALIDATION_ROOT="${VALIDATION_ROOT%/}"
    is_resume=1
  fi

  # Set state directory
  STATE_DIR="${VALIDATION_ROOT}/.state"

  # Export for use by other scripts
  export VALIDATION_ROOT
  export STATE_DIR

  # If resuming, validate the directory
  if [ "$is_resume" = "1" ]; then
    validate_resume_directory
  fi
}

# Parse common validation arguments
parse_validation_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v|--verbose)
        export VALIDATION_VERBOSE=1
        shift
        ;;
      --log-level)
        export VALIDATION_LOG_LEVEL="$2"
        shift 2
        ;;
      --log-level=*)
        export VALIDATION_LOG_LEVEL="${1#*=}"
        shift
        ;;
      --validation-folder)
        export VALIDATION_ROOT="$2"
        shift 2
        ;;
      --validation-folder=*)
        export VALIDATION_ROOT="${1#*=}"
        shift
        ;;
      -h|--help)
        if type show_step_help &>/dev/null; then
          show_step_help
        else
          echo "Help not available for this script"
        fi
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        if type show_step_help &>/dev/null; then
          show_step_help
        fi
        exit 1
        ;;
    esac
  done

  # Initialize validation root (after parsing arguments)
  # This will automatically detect resume mode if VALIDATION_ROOT was set
  init_validation_root
}

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

log_debug() {
  if [ "$VALIDATION_VERBOSE" = "1" ] || [ "$VALIDATION_LOG_LEVEL" = "DEBUG" ]; then
    echo "[DEBUG] $*"
  fi
}

log_cmd() {
  if [ "$VALIDATION_VERBOSE" = "1" ] || [ "$VALIDATION_LOG_LEVEL" = "DEBUG" ]; then
    echo "[CMD] $*" | sed 's/^/  → /'
  fi
}

log_step_title() {
  local step_num="$1"
  local step_name="$2"
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║ Step $step_num: $step_name"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
}

# ============================================================================
# State Management
# ============================================================================

# Validate resume directory
validate_resume_directory() {
  if [ ! -d "$VALIDATION_ROOT" ]; then
    log_error "Validation directory does not exist: $VALIDATION_ROOT"
    exit 1
  fi

  if [ ! -d "$STATE_DIR" ]; then
    log_error "State directory not found: $STATE_DIR"
    log_error "This does not appear to be a valid validation directory"
    exit 1
  fi

  log_info "Resuming from existing validation: $VALIDATION_ROOT"

  # Show completed steps
  local completed_steps
  completed_steps=$(list_completed_steps)

  if [ -n "$completed_steps" ]; then
    log_info "Previously completed steps:"
    echo "$completed_steps" | while read -r step; do
      local timestamp
      timestamp=$(get_step_completion_time "$step")
      log_success "  $step (completed at: $timestamp)"
    done
  else
    log_warning "No completed steps found in this validation directory"
  fi
  echo ""
}

# Initialize state directory
init_state() {
  mkdir -p "$STATE_DIR"
}

# Initialise the venv
init_venv() {
  log_info "Initialising the venv"
  make venv-create
}

# Mark a step as completed
mark_step_completed() {
  local step_id="$1"
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "$timestamp" > "$STATE_DIR/$step_id.completed"
  log_success "State saved: Step $step_id completed"
}

# Check if a step was already completed
is_step_completed() {
  local step_id="$1"
  [ -f "$STATE_DIR/$step_id.completed" ]
}

# Get completion timestamp for a step
get_step_completion_time() {
  local step_id="$1"
  if is_step_completed "$step_id"; then
    cat "$STATE_DIR/$step_id.completed"
  else
    echo "not-completed"
  fi
}

# List all completed steps
list_completed_steps() {
  if [ -d "$STATE_DIR" ]; then
    find "$STATE_DIR" -name "*.completed" -type f -print0 2>/dev/null | \
      xargs -0 -I {} basename {} .completed | \
      sort
  fi
}

# Check if all prerequisites are completed
prerequisites_completed() {
  is_step_completed "step-00-prerequisites"
}

# ============================================================================
# Process Tracking
# ============================================================================

# Log command execution
log_command() {
  local cmd="$1"
  local log_file="$2"

  {
    echo "Command: $cmd"
    echo "Started at: $(date)"
    echo "---"
  } >> "$log_file"
}

# Log command completion
log_command_completed() {
  local exit_code="$1"
  local log_file="$2"

  {
    echo "---"
    echo "Exit code: $exit_code"
    echo "Completed at: $(date)"
  } >> "$log_file"
}

# ============================================================================
# Utility Functions
# ============================================================================

# Create output directory for a step
create_step_dir() {
  local step_dir="$1"
  mkdir -p "$step_dir"
  init_state
}

# Run command with logging
run_logged_command() {
  local cmd="$1"
  local log_file="$2"

  mkdir -p "$(dirname "$log_file")"
  log_command "$cmd" "$log_file"
  log_cmd "$cmd"  # Also log to stdout if verbose

  if eval "$cmd" >> "$log_file" 2>&1; then
    log_command_completed 0 "$log_file"
    return 0
  else
    local exit_code=$?
    log_command_completed $exit_code "$log_file"
    return $exit_code
  fi
}

# Check if tool exists in Docker container
check_tool_in_container() {
  local tool="$1"
  local version_cmd="${2:-$tool --version}"

  cd "$PROJECT_ROOT" || return 1
  if make run-docker COMMAND="which $tool" &>/dev/null; then
    log_success "$tool found in container"
    make run-docker COMMAND="$version_cmd" 2>/dev/null | head -1 || true
    return 0
  else
    log_error "$tool not found in Docker container"
    return 1
  fi
}

# Check prerequisites
verify_docker_image() {
  if ! docker images | grep -q "pharos-dev.*latest"; then
    log_error "Docker image 'pharos-dev:latest' not found"
    return 1
  fi
  log_success "Docker image verified"
  return 0
}

verify_cmake_configured() {
  if [ ! -f "$PROJECT_ROOT/build/CMakeCache.txt" ]; then
    log_warning "CMake not configured"
    return 1
  fi
  log_success "CMake configured"
  return 0
}

verify_slurm_packages() {
  if ls "$PROJECT_ROOT/build/packages/slurm/"*.deb &>/dev/null; then
    local pkg_count
    pkg_count=$(find "$PROJECT_ROOT/build/packages/slurm/" -name "*.deb" -type f | wc -l)
    log_success "SLURM packages available ($pkg_count packages)"
    return 0
  else
    log_error "No SLURM packages found"
    return 1
  fi
}

verify_example_config() {
  if [ -f "$PROJECT_ROOT/config/example-multi-gpu-clusters.yaml" ]; then
    log_success "Example cluster configuration found"
    return 0
  else
    log_error "Example cluster configuration not found"
    return 1
  fi
}

verify_playbooks() {
  local missing_playbooks=0
  local playbooks_dir="$PROJECT_ROOT/ansible/playbooks"

  # Check if playbooks directory exists
  if [ ! -d "$playbooks_dir" ]; then
    log_warning "Playbooks directory not found: $playbooks_dir"
    log_warning "Playbooks will need to be created before running Packer/runtime validation"
    return 1  # Return 1 to indicate missing, but caller should handle gracefully
  fi

  for playbook in playbook-hpc-packer-controller.yml playbook-hpc-packer-compute.yml playbook-hpc-runtime.yml; do
    if [ ! -f "$playbooks_dir/$playbook" ]; then
      log_warning "Playbook not found: $playbook (will be needed for Packer/runtime steps)"
      missing_playbooks=$((missing_playbooks + 1))
    else
      log_success "Found: $playbook"
    fi
  done

  if [ $missing_playbooks -eq 0 ]; then
    log_success "All playbooks found"
    return 0
  else
    log_warning "Some playbooks are missing - they will be needed for later validation steps"
    return 1  # Return 1 to indicate missing, but caller should handle gracefully
  fi
}

# ============================================================================
# Summary Functions
# ============================================================================

print_validation_summary() {
  local status="$1"
  local start_time="$2"

  local duration=$(($(date +%s) - start_time))
  local minutes=$((duration / 60))
  local seconds=$((duration % 60))

  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "Validation Summary"
  echo "════════════════════════════════════════════════════════════"
  echo "Status: $status"
  echo "Duration: ${minutes}m ${seconds}s"
  echo "Logs: $VALIDATION_ROOT"
  echo "════════════════════════════════════════════════════════════"
  echo ""
}

print_step_result() {
  local step_id="$1"
  local step_name="$2"
  local status="$3"

  if [ "$status" = "PASSED" ]; then
    log_success "$step_id: $step_name - PASSED"
  else
    log_error "$step_id: $step_name - FAILED"
  fi
}

# ============================================================================
# Step Management Functions
# ============================================================================

# Log step start
log_step_start() {
  local step_name="$1"
  local step_description="$2"
  log_step_title "$step_name" "$step_description"
}

# Log step success
log_step_success() {
  local step_name="$1"
  local step_description="$2"
  log_success "Step $step_name PASSED: $step_description"
}

# Check prerequisites for a step
check_prerequisites() {
  local required_step="$1"
  if ! is_step_completed "$required_step"; then
    log_error "Prerequisites not met: $required_step must be completed first"
    return 1
  fi
  return 0
}

# ============================================================================
# SSH Configuration
# ============================================================================

# Setup SSH configuration for cluster access
setup_ssh_config() {
  SSH_KEY="${PROJECT_ROOT}/build/shared/ssh-keys/id_rsa"
  SSH_OPTS="-i ${SSH_KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"

  # Export for use in other scripts
  export SSH_KEY
  export SSH_OPTS
}

# ============================================================================
# Cluster Host Configuration
# ============================================================================

# Setup cluster hostnames
setup_cluster_hosts() {
  CONTROLLER_HOST="test-hpc-runtime-controller"
  COMPUTE_HOSTS=("test-hpc-runtime-compute01" "test-hpc-runtime-compute02")

  # Export for use in other scripts
  export CONTROLLER_HOST
  export COMPUTE_HOSTS
}

# Execute command on target host via SSH
# Usage: run_in_target <host> <command> [log_file] [suppress_stderr]
# Returns: Exit code of SSH command
run_in_target() {
  local host="$1"
  local command="$2"
  local log_file="${3:-}"
  local suppress_stderr="${4:-false}"

  # SSH_OPTS is intentionally unquoted to allow word splitting
  # shellcheck disable=SC2086,SC2029

  if [[ -n "$log_file" ]]; then
    if [[ "$suppress_stderr" = "true" ]]; then
      ssh $SSH_OPTS "$host" "$command" > "$log_file" 2>/dev/null
    else
      ssh $SSH_OPTS "$host" "$command" > "$log_file" 2>&1
    fi
  else
    if [[ "$suppress_stderr" = "true" ]]; then
      ssh $SSH_OPTS "$host" "$command" 2>/dev/null
    else
      ssh $SSH_OPTS "$host" "$command"
    fi
  fi
}

# Execute command on target host via SSH and capture output
# Usage: capture_from_target <host> <command> [suppress_stderr]
# Returns: Command output via stdout
capture_from_target() {
  local host="$1"
  local command="$2"
  local suppress_stderr="${3:-false}"

  log_cmd "ssh $SSH_OPTS $host '$command'"

  # SSH_OPTS is intentionally unquoted to allow word splitting
  # shellcheck disable=SC2086,SC2029
  if [[ "$suppress_stderr" = "true" ]]; then
    ssh $SSH_OPTS "$host" "$command" 2>/dev/null
  else
    ssh $SSH_OPTS "$host" "$command"
  fi
}

# Copy file to target host via SCP
# Usage: scp_to_target <src_path> <dest_host:dest_path>
# Returns: Exit code of SCP command
scp_to_target() {
  local src_path="$1"
  local dest="$2"

  # SSH_OPTS is intentionally unquoted to allow word splitting
  # shellcheck disable=SC2086
  scp $SSH_OPTS "$src_path" "$dest"
}

# ============================================================================
# Docker Command Helpers
# ============================================================================

# Run Docker command with logging
run_docker_command() {
  local cmd="$1"
  local log_file="$2"
  local description="${3:-Docker command}"

  log_cmd "make run-docker COMMAND='$cmd'"
  if make run-docker COMMAND="$cmd" > "$log_file" 2>&1; then
    log_success "$description completed"
    return 0
  else
    log_error "$description failed"
    return 1
  fi
}

# Run Docker command with error extraction
run_docker_command_with_errors() {
  local cmd="$1"
  local log_file="$2"
  local error_file="$3"
  local description="${4:-Docker command}"

  log_cmd "make run-docker COMMAND='$cmd'"
  if make run-docker COMMAND="$cmd" > "$log_file" 2>&1; then
    log_success "$description completed"
    return 0
  else
    log_error "$description failed"
    # Extract errors to separate file
    grep -i "error\|fatal" "$log_file" > "$error_file" 2>/dev/null || true
    return 1
  fi
}

# ============================================================================
# Step Execution Patterns
# ============================================================================

# Common step initialization pattern
init_step() {
  local step_id="$1"
  local step_description="$2"

  log_step_title "$STEP_NUMBER" "$step_description"

  # Check if already completed
  if is_step_completed "$step_id"; then
    log_warning "Step ${STEP_NUMBER} already completed at $(get_step_completion_time "$step_id")"
    log_info "Skipping..."
    return 0
  fi

  # Check prerequisites
  if ! prerequisites_completed; then
    log_error "Prerequisites not completed. Run step-00-prerequisites.sh first"
    return 1
  fi

  init_state
  local step_dir="$VALIDATION_ROOT/$STEP_DIR_NAME"
  create_step_dir "$step_dir"

  return 2  # Continue execution
}

# Common step completion pattern
complete_step() {
  local step_id="$1"
  local step_description="$2"
  local step_dir="$3"

  mark_step_completed "$step_id"
  log_success "Step ${STEP_NUMBER} PASSED: $step_description"

  # Show validation summary if it exists
  if [ -f "$step_dir/validation-summary.txt" ]; then
    cat "$step_dir/validation-summary.txt"
  fi

  return 0
}

# ============================================================================
# Validation Summary Generation
# ============================================================================

# Create validation summary
create_validation_summary() {
  local step_dir="$1"
  local status="$2"
  local details="$3"
  local logs="$4"

  cat > "$step_dir/validation-summary.txt" << EOF
=== Step ${STEP_NUMBER}: ${step_description} ===
Timestamp: $(date)

${status}

${details}

Logs:
${logs}

EOF
}

# ============================================================================
# Cluster Management
# ============================================================================

# Check cluster status
check_cluster_status() {
  local step_dir="$1"

  log_info "${STEP_NUMBER}.1: Checking cluster status..."
  if make system-status CLUSTER_CONFIG="config/example-multi-gpu-clusters.yaml" \
    > "$step_dir/cluster-status.log" 2>&1; then
    log_success "Cluster is running"
    return 0
  else
    log_warning "Cluster may not be running"
    return 1
  fi
}

# Start cluster if needed
ensure_cluster_running() {
  local step_dir="$1"

  if ! check_cluster_status "$step_dir"; then
    log_info "Starting cluster VMs..."
    if make system-start CLUSTER_CONFIG="config/example-multi-gpu-clusters.yaml" \
      >> "$step_dir/cluster-status.log" 2>&1; then
      log_success "Cluster started"
      return 0
    else
      log_error "Failed to start cluster"
      return 1
    fi
  fi
  return 0
}

# ============================================================================
# Export variables for use in other scripts
# ============================================================================

export SCRIPT_DIR
export PROJECT_ROOT
export VALIDATION_ROOT
export STATE_DIR
