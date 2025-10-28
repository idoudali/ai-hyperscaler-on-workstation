#!/bin/bash
# Quick script to deploy container images to compute nodes
# This addresses the container availability issue found in test-container-functionality.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Show help
show_help() {
  cat << EOF
${BLUE}═══════════════════════════════════════════════════════════${NC}
${BLUE}  Deploy Containers to Compute Nodes${NC}
${BLUE}═══════════════════════════════════════════════════════════${NC}

${YELLOW}USAGE:${NC}
  $0 [OPTIONS] [CONTROLLER] [CONTAINER_IMAGE]

${YELLOW}DESCRIPTION:${NC}
  Deploys container images from the controller to all compute nodes
  discovered via SLURM. Validates deployment and provides detailed
  progress reporting.

${YELLOW}ARGUMENTS:${NC}
  CONTROLLER        Controller SSH connection string (default: admin@192.168.220.10)
  CONTAINER_IMAGE   Full path to container image (default: /opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif)

${YELLOW}OPTIONS:${NC}
  -h, --help        Show this help message
  -v, --verbose     Enable verbose logging
  -d, --debug       Enable debug mode (very verbose)
  --dry-run         Show what would be done without making changes
  --force           Force redeployment even if containers exist

${YELLOW}ENVIRONMENT VARIABLES:${NC}
  SSH_KEY           Path to SSH private key
                    Priority: 1) SSH_KEY env var 2) build/shared/ssh-keys/id_rsa
                              3) ~/.ssh/id_rsa
  DEBUG             Set to 1 to enable debug logging

${YELLOW}EXAMPLES:${NC}
  # Deploy to default cluster
  $0

  # Deploy to specific controller
  $0 admin@192.168.220.10

  # Deploy specific container image
  $0 admin@192.168.220.10 /opt/containers/ml-frameworks/custom.sif

  # Verbose mode
  $0 --verbose

  # Debug mode
  $0 --debug

  # Dry run (show what would be done)
  $0 --dry-run

${YELLOW}PREREQUISITES:${NC}
  1. Container must exist on controller
  2. SLURM must be running on controller
  3. SSH access to controller and compute nodes
  4. Sufficient disk space on compute nodes

${YELLOW}WORKFLOW:${NC}
  [1/5] Check container exists on controller
  [2/5] Discover compute nodes via SLURM
  [3/5] Check which nodes need the container
  [4/5] Deploy to nodes needing the container
  [5/5] Verify deployment on all nodes

${YELLOW}TROUBLESHOOTING:${NC}
  If deployment fails, check:
  - SSH connectivity: ssh -i ~/.ssh/id_rsa admin@192.168.220.10
  - SLURM status: ssh admin@192.168.220.10 "sinfo"
  - Disk space: ssh admin@192.168.220.10 "df -h /opt/containers"
  - Container size: ls -lh build/containers/apptainer/*.sif

EOF
  exit 0
}

# Logging functions
log_debug() {
  if [[ "${DEBUG:-0}" == "1" ]]; then
    echo -e "${CYAN}[DEBUG]${NC} $*" >&2
  fi
}

log_info() {
  if [[ "${VERBOSE:-0}" == "1" ]] || [[ "${DEBUG:-0}" == "1" ]]; then
    echo -e "${BLUE}[INFO]${NC} $*"
  fi
}

log_step() {
  echo -e "${YELLOW}$*${NC}"
}

log_success() {
  echo -e "${GREEN}✓${NC} $*"
}

log_error() {
  echo -e "${RED}✗${NC} $*" >&2
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $*"
}

# Parse command line arguments
DRY_RUN=0
FORCE=0
CONTROLLER=""
CONTAINER_IMAGE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      ;;
    -v|--verbose)
      export VERBOSE=1
      log_info "Verbose mode enabled"
      shift
      ;;
    -d|--debug)
      export DEBUG=1
      export VERBOSE=1
      log_debug "Debug mode enabled"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      log_warning "Dry run mode - no changes will be made"
      shift
      ;;
    --force)
      FORCE=1
      log_info "Force mode enabled - will redeploy even if containers exist"
      shift
      ;;
    -*)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
    *)
      if [[ -z "$CONTROLLER" ]]; then
        CONTROLLER="$1"
      elif [[ -z "$CONTAINER_IMAGE" ]]; then
        CONTAINER_IMAGE="$1"
      else
        echo -e "${RED}Too many arguments${NC}"
        echo "Use --help for usage information"
        exit 1
      fi
      shift
      ;;
  esac
done

# Set defaults if not provided
CONTROLLER="${CONTROLLER:-admin@192.168.220.10}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-/opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif}"

# Determine SSH key location
# Priority: 1) Environment variable 2) Project build folder 3) User's home directory
if [[ -n "${SSH_KEY:-}" ]]; then
  # Use provided SSH_KEY
  :
elif [[ -f "build/shared/ssh-keys/id_rsa" ]]; then
  SSH_KEY="build/shared/ssh-keys/id_rsa"
elif [[ -f "../build/shared/ssh-keys/id_rsa" ]]; then
  SSH_KEY="../build/shared/ssh-keys/id_rsa"
elif [[ -f "$HOME/.ssh/id_rsa" ]]; then
  SSH_KEY="$HOME/.ssh/id_rsa"
else
  SSH_KEY="$HOME/.ssh/id_rsa"  # Default fallback even if doesn't exist
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

log_debug "Configuration:"
log_debug "  CONTROLLER=$CONTROLLER"
log_debug "  CONTAINER_IMAGE=$CONTAINER_IMAGE"
log_debug "  SSH_KEY=$SSH_KEY"
log_debug "  DRY_RUN=$DRY_RUN"
log_debug "  FORCE=$FORCE"

# Build SSH command
if [[ -f "$SSH_KEY" ]]; then
  SSH_CMD="ssh -i $SSH_KEY $SSH_OPTS"
  SCP_CMD="scp -i $SSH_KEY $SSH_OPTS"
  log_debug "Using SSH key: $SSH_KEY"

  # Check key permissions
  key_perms=$(stat -c "%a" "$SSH_KEY" 2>/dev/null || stat -f "%Op" "$SSH_KEY" 2>/dev/null | cut -c 4-6 || echo "unknown")
  if [[ "$key_perms" != "600" ]] && [[ "$key_perms" != "400" ]] && [[ "$key_perms" != "unknown" ]]; then
    log_warning "SSH key has permissions $key_perms (should be 600 or 400)"
    log_info "Fix with: chmod 600 $SSH_KEY"
  else
    log_debug "SSH key permissions: $key_perms"
  fi
else
  SSH_CMD="ssh $SSH_OPTS"
  SCP_CMD="scp $SSH_OPTS"
  log_warning "SSH key not found at: $SSH_KEY"
  log_info "Will attempt SSH without explicit key (using ssh-agent or default keys)"
fi

log_debug "SSH command configured: $SSH_CMD"
log_debug "SCP command configured: $SCP_CMD"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Deploy Containers to Compute Nodes${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Controller:      $CONTROLLER"
echo "Container Image: $CONTAINER_IMAGE"
echo "SSH Key:         ${SSH_KEY}"
if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "Mode:            ${YELLOW}DRY RUN${NC} (no changes will be made)"
fi
if [[ $FORCE -eq 1 ]]; then
  echo -e "Force Mode:      ${YELLOW}ENABLED${NC} (will redeploy existing containers)"
fi
echo ""

# Pre-flight SSH check
log_step "[0/5] Running pre-flight checks..."
log_info "Testing SSH connectivity to controller..."
log_debug "Executing: $SSH_CMD $CONTROLLER 'echo SSH_OK'"

if ! $SSH_CMD "$CONTROLLER" "echo 'SSH_OK'" 2>/dev/null | grep -q "SSH_OK"; then
  log_error "Cannot connect to controller via SSH"
  log_error "Controller: $CONTROLLER"
  log_error "SSH key: $SSH_KEY"
  echo ""
  echo "Troubleshooting steps:"
  echo "  1. Check if controller is reachable: ping ${CONTROLLER#*@}"
  echo "  2. Verify SSH key exists: ls -la $SSH_KEY"
  echo "  3. Test SSH manually: ssh -i $SSH_KEY $CONTROLLER 'echo OK'"
  echo "  4. Check firewall settings"
  exit 1
fi
log_success "SSH connectivity verified"
log_info "Pre-flight checks complete"
echo ""

# Check if container exists on controller
log_step "[1/5] Checking container on controller..."
log_debug "Container path: $CONTAINER_IMAGE"
log_debug "Executing: $SSH_CMD $CONTROLLER [ -f '$CONTAINER_IMAGE' ]"

if ! $SSH_CMD "$CONTROLLER" "[ -f '$CONTAINER_IMAGE' ]" 2>/dev/null; then
  log_error "Container not found on controller: $CONTAINER_IMAGE"
  echo ""

  # Additional diagnostics
  log_info "Running diagnostics..."
  container_dir=$(dirname "$CONTAINER_IMAGE")
  log_debug "Checking directory: $container_dir"

  dir_check=$($SSH_CMD "$CONTROLLER" "ls -ld $container_dir 2>&1" || echo "DIR_NOT_FOUND")
  if [[ "$dir_check" == *"DIR_NOT_FOUND"* ]] || [[ "$dir_check" == *"No such file"* ]]; then
    log_error "Container directory does not exist: $container_dir"
  else
    log_info "Directory exists: $container_dir"
    log_debug "Directory listing: $dir_check"

    # Check what's in the directory
    dir_contents=$($SSH_CMD "$CONTROLLER" "ls -lh $container_dir 2>&1" || echo "Cannot list")
    log_info "Directory contents:"
    echo "$dir_contents" | head -10 | while IFS= read -r line; do
      echo "       $line"
    done
  fi

  # Check for local build
  log_info "Checking for local build artifacts..."
  if [[ -f "build/containers/apptainer/$(basename "$CONTAINER_IMAGE")" ]]; then
    local_size=$(du -h "build/containers/apptainer/$(basename "$CONTAINER_IMAGE")" | awk '{print $1}')
    log_success "Container found locally: build/containers/apptainer/$(basename "$CONTAINER_IMAGE")"
    log_info "Local container size: $local_size"
  else
    log_warning "Container not found in local build directory"
    log_info "You may need to build the container first"
  fi

  echo ""
  echo "To fix this issue:"
  echo ""
  echo "  ${GREEN}Recommended:${NC} Use the automated deployment"
  echo "    cd tests && make test-container-registry-deploy"
  echo ""
  echo "  ${YELLOW}Alternative:${NC} Manual deployment"
  echo "    scp build/containers/apptainer/$(basename "$CONTAINER_IMAGE") $CONTROLLER:/tmp/"
  echo "    ssh $CONTROLLER 'sudo mkdir -p $container_dir && \\"
  echo "                     sudo mv /tmp/$(basename "$CONTAINER_IMAGE") $container_dir/'"
  echo ""
  exit 1
fi

# Get container info
log_debug "Getting container information..."
container_info=$($SSH_CMD "$CONTROLLER" "ls -lh '$CONTAINER_IMAGE'" 2>/dev/null)
container_size=$(echo "$container_info" | awk '{print $5}')
container_perms=$(echo "$container_info" | awk '{print $1}')

log_success "Container exists on controller"
log_info "Path: $CONTAINER_IMAGE"
log_info "Size: $container_size"
log_info "Permissions: $container_perms"
log_debug "Full info: $container_info"
echo ""

# Get compute nodes from SLURM
log_step "[2/5] Discovering compute nodes..."
log_info "Querying SLURM for compute nodes..."
log_debug "Executing: $SSH_CMD $CONTROLLER 'sinfo -N -h -o %N'"

COMPUTE_NODES_OUTPUT=$($SSH_CMD "$CONTROLLER" "sinfo -N -h -o '%N' 2>&1" || true)
log_debug "sinfo output length: ${#COMPUTE_NODES_OUTPUT} characters"

if [[ "$COMPUTE_NODES_OUTPUT" == *"Unable to contact"* ]]; then
  log_error "Cannot contact SLURM controller"
  log_debug "Output: $COMPUTE_NODES_OUTPUT"
  echo ""
  echo "Please ensure SLURM is running on the controller"
  echo "Check with:"
  echo "  ssh $CONTROLLER 'systemctl status slurmctld'"
  echo "  ssh $CONTROLLER 'sinfo'"
  exit 1
fi

# Parse nodes, filtering empty lines
log_debug "Parsing compute node list..."
mapfile -t COMPUTE_NODES < <(echo "$COMPUTE_NODES_OUTPUT" | grep -v '^$' | sort -u)
log_debug "Found ${#COMPUTE_NODES[@]} unique compute node(s)"

if [[ ${#COMPUTE_NODES[@]} -eq 0 ]]; then
  log_error "No compute nodes found"
  log_debug "sinfo output was: $COMPUTE_NODES_OUTPUT"
  echo ""
  echo "SLURM may not be configured or no compute nodes registered"
  echo "Verify with:"
  echo "  ssh $CONTROLLER 'sinfo -Nel'"
  exit 1
fi

log_success "Found ${#COMPUTE_NODES[@]} compute node(s):"
for node in "${COMPUTE_NODES[@]}"; do
  log_info "  - $node"
done
echo ""

# Check which nodes need the container
log_step "[3/5] Checking container availability on compute nodes..."
log_info "Testing container access on each node..."
NODES_NEEDING_DEPLOYMENT=()

for node in "${COMPUTE_NODES[@]}"; do
  [[ -z "$node" ]] && continue

  log_debug "Checking node: $node"
  echo -n "  Checking $node... "
  log_debug "Executing: ssh $node [ -f $CONTAINER_IMAGE ]"

  if $SSH_CMD "$CONTROLLER" "ssh -o ConnectTimeout=5 $node '[ -f $CONTAINER_IMAGE ]' 2>/dev/null" 2>/dev/null; then
    if [[ $FORCE -eq 1 ]]; then
      echo -e "${YELLOW}has container (will redeploy due to --force)${NC}"
      log_debug "Force mode: will redeploy to $node"
      NODES_NEEDING_DEPLOYMENT+=("$node")
    else
      echo -e "${GREEN}✓ already has container${NC}"
      log_debug "Container exists on $node, skipping"
    fi
  else
    echo -e "${YELLOW}needs deployment${NC}"
    log_debug "Container missing on $node, adding to deployment list"
    NODES_NEEDING_DEPLOYMENT+=("$node")
  fi
done
echo ""

if [[ ${#NODES_NEEDING_DEPLOYMENT[@]} -eq 0 ]]; then
  log_success "All compute nodes already have the container"
  log_info "No deployment needed"
  echo ""
  echo "All nodes are up to date!"
  echo ""
  echo "To force redeployment, use: $0 --force"
  exit 0
fi

log_info "Nodes needing deployment: ${#NODES_NEEDING_DEPLOYMENT[@]}"
for node in "${NODES_NEEDING_DEPLOYMENT[@]}"; do
  log_info "  - $node"
done
echo ""

if [[ $DRY_RUN -eq 1 ]]; then
  log_warning "DRY RUN MODE: Would deploy to ${#NODES_NEEDING_DEPLOYMENT[@]} node(s)"
  for node in "${NODES_NEEDING_DEPLOYMENT[@]}"; do
    echo "  Would deploy to: $node"
  done
  echo ""
  echo "To actually deploy, run without --dry-run"
  exit 0
fi

# Deploy to nodes
log_step "[4/5] Deploying container to compute nodes..."
log_info "Starting deployment to ${#NODES_NEEDING_DEPLOYMENT[@]} node(s)..."
log_info "Container size: $container_size (this may take several minutes per node)"
echo ""
FAILED_NODES=()

for node in "${NODES_NEEDING_DEPLOYMENT[@]}"; do
  echo ""
  echo -e "${BLUE}Deploying to $node...${NC}"
  start_time=$(date +%s)
  log_debug "Starting deployment to $node at $(date)"

  # Create directory
  log_info "Creating directory structure on $node..."
  log_debug "Executing: ssh $node 'sudo mkdir -p /opt/containers/ml-frameworks'"

  mkdir_output=$($SSH_CMD "$CONTROLLER" "ssh -o ConnectTimeout=10 $node 'sudo mkdir -p /opt/containers/ml-frameworks' 2>&1")
  mkdir_exit=$?

  if [[ $mkdir_exit -ne 0 ]]; then
    log_error "Failed to create directory on $node"
    log_debug "mkdir exit code: $mkdir_exit"
    log_debug "mkdir output: $mkdir_output"
    FAILED_NODES+=("$node (mkdir failed)")
    continue
  fi
  log_debug "Directory created successfully"
  log_success "Directory ready"

  # Copy container
  log_info "Copying container to $node:/tmp/ (size: $container_size)..."
  log_info "This may take several minutes depending on network speed..."
  log_debug "Executing: scp $CONTAINER_IMAGE $node:/tmp/"

  copy_start=$(date +%s)
  scp_output=$($SSH_CMD "$CONTROLLER" "scp -o ConnectTimeout=30 $CONTAINER_IMAGE $node:/tmp/ 2>&1")
  scp_exit=$?
  copy_duration=$(($(date +%s) - copy_start))

  if [[ $scp_exit -ne 0 ]]; then
    log_error "Failed to copy container to $node"
    log_debug "scp exit code: $scp_exit"
    log_debug "scp output: $scp_output"
    log_debug "Copy duration: ${copy_duration}s before failure"
    FAILED_NODES+=("$node (scp failed)")
    continue
  fi
  log_debug "Copy completed in ${copy_duration}s"
  log_success "Container copied (took ${copy_duration}s)"

  # Move to final location
  log_info "Moving to final location and setting permissions..."
  filename=$(basename "$CONTAINER_IMAGE")
  log_debug "Filename: $filename"
  log_debug "Executing: ssh $node 'sudo mv /tmp/$filename /opt/containers/ml-frameworks/'"

  move_output=$($SSH_CMD "$CONTROLLER" "ssh -o ConnectTimeout=10 $node 'sudo mv /tmp/$filename /opt/containers/ml-frameworks/ && sudo chown root:root /opt/containers/ml-frameworks/$filename && sudo chmod 755 /opt/containers/ml-frameworks/$filename' 2>&1")
  move_exit=$?

  if [[ $move_exit -ne 0 ]]; then
    log_error "Failed to move container on $node"
    log_debug "move exit code: $move_exit"
    log_debug "move output: $move_output"
    log_warning "Container may be left in /tmp/$filename on $node"
    FAILED_NODES+=("$node (move failed)")
    continue
  fi
  log_debug "Container moved and permissions set"
  log_success "Permissions set"

  total_duration=$(($(date +%s) - start_time))
  log_success "Successfully deployed to $node (total time: ${total_duration}s)"
  log_debug "Deployment to $node completed at $(date)"
done
echo ""

# Verification
log_step "[5/5] Verifying deployment..."
log_info "Checking container accessibility on all deployed nodes..."
echo ""
VERIFICATION_FAILED=()

for node in "${NODES_NEEDING_DEPLOYMENT[@]}"; do
  log_debug "Verifying node: $node"
  echo -n "  Verifying $node... "

  log_debug "Executing: ssh $node [ -f $CONTAINER_IMAGE ] && ls -lh $CONTAINER_IMAGE"
  verify_output=$($SSH_CMD "$CONTROLLER" "ssh -o ConnectTimeout=5 $node '[ -f $CONTAINER_IMAGE ] && ls -lh $CONTAINER_IMAGE' 2>&1")
  verify_exit=$?

  if [[ $verify_exit -eq 0 ]]; then
    echo -e "${GREEN}✓${NC}"
    log_debug "Verification successful for $node"
    log_debug "Container info: $verify_output"

    # Extract size to confirm
    deployed_size=$(echo "$verify_output" | awk '{print $5}')
    if [[ -n "$deployed_size" ]]; then
      log_debug "Deployed size on $node: $deployed_size"
    fi
  else
    echo -e "${RED}✗ verification failed${NC}"
    log_error "Verification failed for $node"
    log_debug "verify exit code: $verify_exit"
    log_debug "verify output: $verify_output"
    VERIFICATION_FAILED+=("$node")
  fi
done
echo ""

# Summary
log_debug "Generating deployment summary..."

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Deployment Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

successful_deployments=$((${#NODES_NEEDING_DEPLOYMENT[@]} - ${#FAILED_NODES[@]} - ${#VERIFICATION_FAILED[@]}))

echo "Total compute nodes discovered:  ${#COMPUTE_NODES[@]}"
echo "Nodes requiring deployment:      ${#NODES_NEEDING_DEPLOYMENT[@]}"
echo -e "Successfully deployed & verified: ${GREEN}${successful_deployments}${NC}"

if [[ ${#FAILED_NODES[@]} -gt 0 ]]; then
  echo -e "Failed deployments:              ${RED}${#FAILED_NODES[@]}${NC}"
  log_debug "Failed nodes list: ${FAILED_NODES[*]}"
  for node in "${FAILED_NODES[@]}"; do
    log_error "  ✗ $node"
  done
fi

if [[ ${#VERIFICATION_FAILED[@]} -gt 0 ]]; then
  echo -e "Failed verification:             ${RED}${#VERIFICATION_FAILED[@]}${NC}"
  log_debug "Verification failed list: ${VERIFICATION_FAILED[*]}"
  for node in "${VERIFICATION_FAILED[@]}"; do
    log_error "  ✗ $node"
  done
fi
echo ""

log_debug "Deployment statistics:"
log_debug "  Total nodes: ${#COMPUTE_NODES[@]}"
log_debug "  Deployment targets: ${#NODES_NEEDING_DEPLOYMENT[@]}"
log_debug "  Successful: $successful_deployments"
log_debug "  Failed: ${#FAILED_NODES[@]}"
log_debug "  Verification failed: ${#VERIFICATION_FAILED[@]}"

if [[ ${#FAILED_NODES[@]} -eq 0 ]] && [[ ${#VERIFICATION_FAILED[@]} -eq 0 ]]; then
  log_success "All containers deployed successfully ✓✓✓"
  echo ""
  log_info "Container deployment complete"
  log_info "All compute nodes now have access to: $CONTAINER_IMAGE"
  echo ""
  echo "Next steps:"
  echo ""
  echo "  ${GREEN}1.${NC} Verify container functionality:"
  echo "     ssh $CONTROLLER 'srun ls -lh $CONTAINER_IMAGE'"
  echo ""
  echo "  ${GREEN}2.${NC} Run container integration tests:"
  echo "     ./tests/test-container-integration-framework.sh run-tests"
  echo ""
  echo "  ${GREEN}3.${NC} Test container execution via SLURM:"
  echo "     ssh $CONTROLLER 'srun apptainer exec $CONTAINER_IMAGE python3 --version'"
  echo ""

  log_debug "Deployment completed successfully at $(date)"
  exit 0
else
  log_error "Some deployments failed ✗"
  echo ""

  total_failures=$((${#FAILED_NODES[@]} + ${#VERIFICATION_FAILED[@]}))
  log_warning "Failed on $total_failures out of ${#NODES_NEEDING_DEPLOYMENT[@]} nodes"

  echo "Common issues and solutions:"
  echo ""
  echo "  ${YELLOW}SSH connectivity:${NC}"
  echo "    Test: ssh $CONTROLLER 'ssh <node> hostname'"
  echo "    Fix:  Configure SSH keys and authorized_keys"
  echo ""
  echo "  ${YELLOW}Insufficient permissions:${NC}"
  echo "    Test: ssh $CONTROLLER 'ssh <node> sudo -n true'"
  echo "    Fix:  Configure passwordless sudo for deployment user"
  echo ""
  echo "  ${YELLOW}Disk space:${NC}"
  echo "    Test: ssh $CONTROLLER 'ssh <node> df -h /opt/containers'"
  echo "    Fix:  Free up space or use different mount point"
  echo ""
  echo "  ${YELLOW}Firewall/Network:${NC}"
  echo "    Test: ssh $CONTROLLER 'ping -c 2 <node>'"
  echo "    Fix:  Check firewall rules and network configuration"
  echo ""
  echo "Manual deployment command for failed nodes:"
  echo "  ssh $CONTROLLER"
  echo "  scp $CONTAINER_IMAGE <node>:/tmp/"
  echo "  ssh <node> 'sudo mv /tmp/$(basename "$CONTAINER_IMAGE") /opt/containers/ml-frameworks/'"
  echo ""

  log_debug "Deployment failed at $(date)"
  log_debug "Failed nodes: ${FAILED_NODES[*]} ${VERIFICATION_FAILED[*]}"
  exit 1
fi
