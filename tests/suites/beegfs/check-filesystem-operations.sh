#!/usr/bin/env bash
# BeeGFS Filesystem Operations Tests
#
# This script validates BeeGFS filesystem operations:
# - Mount point existence and accessibility
# - Basic file operations (create, read, write, delete)
# - Directory operations
# - Permission and ownership
# - Cross-node accessibility
#
# Usage:
#   ./check-filesystem-operations.sh [OPTIONS]
#
# Options:
#   --controller <ip>        Controller node IP address
#   --compute <ip1,ip2,...>  Compute node IP addresses (comma-separated)
#   --mount-point <path>     BeeGFS mount point (default: /mnt/beegfs)
#   --verbose               Enable verbose output
#   --help                  Show this help message

set -euo pipefail

# Default configuration
CONTROLLER_IP="${CONTROLLER_IP:-}"
COMPUTE_IPS="${COMPUTE_IPS:-}"
BEEGFS_MOUNT_POINT="${BEEGFS_MOUNT_POINT:-/mnt/beegfs}"
VERBOSE="${VERBOSE:-false}"

# SSH configuration
SSH_USER="${SSH_USER:-admin}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
TEST_DIR="beegfs-test-$(date +%Y%m%d-%H%M%S)"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#######################################
# Print colored output
#######################################
print_color() {
  local color=$1
  shift
  echo -e "${color}$*${NC}"
}

info() { print_color "$BLUE" "[INFO] $*"; }
success() { print_color "$GREEN" "[PASS] $*"; }
error() { print_color "$RED" "[FAIL] $*"; }
warning() { print_color "$YELLOW" "[WARN] $*"; }
skip() { print_color "$YELLOW" "[SKIP] $*"; }

#######################################
# Print usage information
#######################################
usage() {
  cat << EOF
Usage: $0 [OPTIONS]

BeeGFS Filesystem Operations Tests

Options:
  --controller <ip>        Controller node IP address
  --compute <ip1,ip2,...>  Compute node IP addresses (comma-separated)
  --mount-point <path>     BeeGFS mount point (default: /mnt/beegfs)
  --verbose               Enable verbose output
  --help                  Show this help message

EOF
}

#######################################
# Parse command line arguments
#######################################
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --controller) CONTROLLER_IP="$2"; shift 2 ;;
      --compute) COMPUTE_IPS="$2"; shift 2 ;;
      --mount-point) BEEGFS_MOUNT_POINT="$2"; shift 2 ;;
      --verbose) VERBOSE=true; shift ;;
      --help) usage; exit 0 ;;
      *) error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done
}

#######################################
# Execute command on remote node
#######################################
exec_on_node() {
  local node_ip=$1
  local cmd=$2

  if [[ "$VERBOSE" == "true" ]]; then
    info "Executing on $node_ip: $cmd"
  fi

  # shellcheck disable=SC2086
  ssh $SSH_OPTS -i "$SSH_KEY_PATH" "$SSH_USER@$node_ip" "$cmd" 2>&1
}

#######################################
# Test: Mount point existence and accessibility
#######################################
test_mount_point() {
  info "Testing BeeGFS mount point..."

  if [[ -z "$CONTROLLER_IP" ]]; then
    skip "Controller IP not provided, skipping mount point test"
    ((TESTS_SKIPPED++))
    return
  fi

  # Check if mount point exists
  if exec_on_node "$CONTROLLER_IP" "test -d $BEEGFS_MOUNT_POINT"; then
    success "Mount point $BEEGFS_MOUNT_POINT exists on controller"
    ((TESTS_PASSED++))
  else
    error "Mount point $BEEGFS_MOUNT_POINT does not exist on controller"
    ((TESTS_FAILED++))
    return
  fi

  # Check if mount point is a BeeGFS mount
  if exec_on_node "$CONTROLLER_IP" "mount | grep -q '$BEEGFS_MOUNT_POINT.*beegfs'"; then
    success "Mount point $BEEGFS_MOUNT_POINT is a BeeGFS filesystem"
    ((TESTS_PASSED++))
  else
    error "Mount point $BEEGFS_MOUNT_POINT is not a BeeGFS filesystem"
    ((TESTS_FAILED++))
  fi

  # Check if mount point is accessible
  if exec_on_node "$CONTROLLER_IP" "test -r $BEEGFS_MOUNT_POINT && test -w $BEEGFS_MOUNT_POINT"; then
    success "Mount point $BEEGFS_MOUNT_POINT is readable and writable"
    ((TESTS_PASSED++))
  else
    error "Mount point $BEEGFS_MOUNT_POINT is not accessible"
    ((TESTS_FAILED++))
  fi
}

#######################################
# Test: Basic file operations
#######################################
test_file_operations() {
  info "Testing basic file operations..."

  if [[ -z "$CONTROLLER_IP" ]]; then
    skip "Controller IP not provided, skipping file operations test"
    ((TESTS_SKIPPED++))
    return
  fi

  local test_file="$BEEGFS_MOUNT_POINT/$TEST_DIR/test-file.txt"
  local test_content
  test_content="BeeGFS test file - $(date)"

  # Create test directory
  if exec_on_node "$CONTROLLER_IP" "mkdir -p $BEEGFS_MOUNT_POINT/$TEST_DIR"; then
    success "Created test directory"
    ((TESTS_PASSED++))
  else
    error "Failed to create test directory"
    if [[ "$VERBOSE" == "true" ]]; then
      local mount_info
      mount_info=$(exec_on_node "$CONTROLLER_IP" "mount | grep '$BEEGFS_MOUNT_POINT'" 2>/dev/null || echo "Mount info unavailable")
      warning "Mount information for $BEEGFS_MOUNT_POINT:"
      while IFS= read -r line; do echo "  $line"; done <<< "$mount_info"
      local disk_space
      disk_space=$(exec_on_node "$CONTROLLER_IP" "df -h $BEEGFS_MOUNT_POINT" 2>/dev/null || echo "Disk space info unavailable")
      warning "Disk space for $BEEGFS_MOUNT_POINT:"
      while IFS= read -r line; do echo "  $line"; done <<< "$disk_space"
    fi
    ((TESTS_FAILED++))
    return
  fi

  # Create and write file
  if exec_on_node "$CONTROLLER_IP" "echo '$test_content' > $test_file"; then
    success "Created and wrote to test file"
    ((TESTS_PASSED++))
  else
    error "Failed to create test file"
    if [[ "$VERBOSE" == "true" ]]; then
      local file_perms
      file_perms=$(exec_on_node "$CONTROLLER_IP" "ls -la $BEEGFS_MOUNT_POINT/$TEST_DIR/" 2>/dev/null || echo "Directory listing unavailable")
      warning "Directory permissions for $BEEGFS_MOUNT_POINT/$TEST_DIR:"
      while IFS= read -r line; do echo "  $line"; done <<< "$file_perms"
    fi
    ((TESTS_FAILED++))
    return
  fi

  # Read file
  local read_content
  if read_content=$(exec_on_node "$CONTROLLER_IP" "cat $test_file"); then
    success "Read test file successfully"
    ((TESTS_PASSED++))

    # Verify content
    if echo "$read_content" | grep -q "BeeGFS test file"; then
      success "File content is correct"
      ((TESTS_PASSED++))
    else
      error "File content is incorrect"
      ((TESTS_FAILED++))
    fi
  else
    error "Failed to read test file"
    ((TESTS_FAILED++))
  fi

  # Append to file
  if exec_on_node "$CONTROLLER_IP" "echo 'Appended line' >> $test_file"; then
    success "Appended to test file successfully"
    ((TESTS_PASSED++))
  else
    error "Failed to append to test file"
    ((TESTS_FAILED++))
  fi

  # Delete file
  if exec_on_node "$CONTROLLER_IP" "rm -f $test_file"; then
    success "Deleted test file successfully"
    ((TESTS_PASSED++))
  else
    error "Failed to delete test file"
    ((TESTS_FAILED++))
  fi
}

#######################################
# Test: Directory operations
#######################################
test_directory_operations() {
  info "Testing directory operations..."

  if [[ -z "$CONTROLLER_IP" ]]; then
    skip "Controller IP not provided, skipping directory operations test"
    ((TESTS_SKIPPED++))
    return
  fi

  local test_subdir="$BEEGFS_MOUNT_POINT/$TEST_DIR/subdir"

  # Create nested directory
  if exec_on_node "$CONTROLLER_IP" "mkdir -p $test_subdir/nested/deep"; then
    success "Created nested directories"
    ((TESTS_PASSED++))
  else
    error "Failed to create nested directories"
    ((TESTS_FAILED++))
    return
  fi

  # List directory
  if exec_on_node "$CONTROLLER_IP" "ls -la $test_subdir >/dev/null"; then
    success "Listed directory successfully"
    ((TESTS_PASSED++))
  else
    error "Failed to list directory"
    ((TESTS_FAILED++))
  fi

  # Remove empty directory
  if exec_on_node "$CONTROLLER_IP" "rmdir $test_subdir/nested/deep"; then
    success "Removed empty directory successfully"
    ((TESTS_PASSED++))
  else
    error "Failed to remove empty directory"
    ((TESTS_FAILED++))
  fi

  # Remove directory tree
  if exec_on_node "$CONTROLLER_IP" "rm -rf $test_subdir"; then
    success "Removed directory tree successfully"
    ((TESTS_PASSED++))
  else
    error "Failed to remove directory tree"
    ((TESTS_FAILED++))
  fi
}

#######################################
# Test: Permission and ownership
#######################################
test_permissions() {
  info "Testing permission and ownership..."

  if [[ -z "$CONTROLLER_IP" ]]; then
    skip "Controller IP not provided, skipping permission test"
    ((TESTS_SKIPPED++))
    return
  fi

  local test_file="$BEEGFS_MOUNT_POINT/$TEST_DIR/permission-test.txt"

  # Create test file
  if ! exec_on_node "$CONTROLLER_IP" "echo 'test' > $test_file"; then
    error "Failed to create test file for permission test"
    ((TESTS_FAILED++))
    return
  fi

  # Change permissions
  if exec_on_node "$CONTROLLER_IP" "chmod 644 $test_file"; then
    success "Changed file permissions successfully"
    ((TESTS_PASSED++))
  else
    error "Failed to change file permissions"
    ((TESTS_FAILED++))
  fi

  # Verify permissions
  local perms
  if perms=$(exec_on_node "$CONTROLLER_IP" "stat -c '%a' $test_file"); then
    if [[ "$perms" == "644" ]]; then
      success "File permissions are correct (644)"
      ((TESTS_PASSED++))
    else
      error "File permissions are incorrect (expected 644, got $perms)"
      ((TESTS_FAILED++))
    fi
  else
    error "Failed to verify file permissions"
    ((TESTS_FAILED++))
  fi

  # Clean up
  exec_on_node "$CONTROLLER_IP" "rm -f $test_file" >/dev/null 2>&1 || true
}

#######################################
# Test: Cross-node accessibility
#######################################
test_cross_node_access() {
  info "Testing cross-node accessibility..."

  if [[ -z "$CONTROLLER_IP" ]] || [[ -z "$COMPUTE_IPS" ]]; then
    skip "Not enough nodes provided, skipping cross-node test"
    ((TESTS_SKIPPED++))
    return
  fi

  local test_file="$BEEGFS_MOUNT_POINT/$TEST_DIR/cross-node-test.txt"
  local test_content
  test_content="Cross-node test - $(date)"

  # Create file on controller
  if ! exec_on_node "$CONTROLLER_IP" "echo '$test_content' > $test_file"; then
    error "Failed to create test file on controller"
    ((TESTS_FAILED++))
    return
  fi
  success "Created test file on controller"
  ((TESTS_PASSED++))

  # Read file from compute nodes
  IFS=',' read -ra NODES <<< "$COMPUTE_IPS"
  for node_ip in "${NODES[@]}"; do
    info "Testing file access from compute node $node_ip..."

    local read_content
    if read_content=$(exec_on_node "$node_ip" "cat $test_file 2>&1"); then
      success "Read test file from compute node $node_ip"
      ((TESTS_PASSED++))

      # Verify content
      if echo "$read_content" | grep -q "Cross-node test"; then
        success "File content is correct on compute node $node_ip"
        ((TESTS_PASSED++))
      else
        error "File content is incorrect on compute node $node_ip"
        ((TESTS_FAILED++))
      fi
    else
      error "Failed to read test file from compute node $node_ip"
      ((TESTS_FAILED++))
    fi

    # Write from compute node
    if exec_on_node "$node_ip" "echo 'Written from $node_ip' >> $test_file"; then
      success "Wrote to test file from compute node $node_ip"
      ((TESTS_PASSED++))
    else
      error "Failed to write to test file from compute node $node_ip"
      ((TESTS_FAILED++))
    fi
  done

  # Verify all writes on controller
  local final_content
  if final_content=$(exec_on_node "$CONTROLLER_IP" "cat $test_file"); then
    success "Read combined file content from controller"
    ((TESTS_PASSED++))

    if [[ "$VERBOSE" == "true" ]]; then
      info "Final file content:"
      while IFS= read -r line; do echo "  $line"; done <<< "$final_content"
    fi
  else
    error "Failed to read combined file content"
    ((TESTS_FAILED++))
  fi

  # Clean up
  exec_on_node "$CONTROLLER_IP" "rm -f $test_file" >/dev/null 2>&1 || true
}

#######################################
# Clean up test directory
#######################################
cleanup() {
  if [[ -n "$CONTROLLER_IP" ]]; then
    info "Cleaning up test directory..."
    exec_on_node "$CONTROLLER_IP" "rm -rf $BEEGFS_MOUNT_POINT/$TEST_DIR" >/dev/null 2>&1 || true
  fi
}

#######################################
# Print test summary
#######################################
print_summary() {
  echo ""
  print_color "$BLUE" "========================================"
  print_color "$BLUE" "BeeGFS Filesystem Operations Test Summary"
  print_color "$BLUE" "========================================"
  echo ""
  print_color "$GREEN" "Tests Passed:  $TESTS_PASSED"
  print_color "$RED" "Tests Failed:  $TESTS_FAILED"
  print_color "$YELLOW" "Tests Skipped: $TESTS_SKIPPED"
  echo ""

  if [[ $TESTS_FAILED -eq 0 ]]; then
    print_color "$GREEN" "✓ All tests passed successfully!"
    return 0
  else
    print_color "$RED" "✗ Some tests failed. Please review the output above."
    return 1
  fi
}

#######################################
# Main function
#######################################
main() {
  parse_args "$@"

  print_color "$BLUE" "========================================"
  print_color "$BLUE" "BeeGFS Filesystem Operations Tests"
  print_color "$BLUE" "========================================"
  echo ""
  info "Controller: ${CONTROLLER_IP:-not set}"
  info "Compute Nodes: ${COMPUTE_IPS:-not set}"
  info "Mount Point: $BEEGFS_MOUNT_POINT"
  echo ""

  # Set up cleanup trap
  trap cleanup EXIT

  # Run tests
  test_mount_point
  test_file_operations
  test_directory_operations
  test_permissions
  test_cross_node_access

  # Print summary
  print_summary
}

# Execute main function
main "$@"
