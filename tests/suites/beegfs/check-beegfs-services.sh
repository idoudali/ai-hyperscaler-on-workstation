#!/usr/bin/env bash
# BeeGFS Service Validation Tests
#
# This script validates BeeGFS services across the HPC cluster:
# - Management service on controller
# - Metadata service on controller
# - Storage services on compute nodes
# - Client services on all nodes
# - Helperd service on all nodes
#
# Usage:
#   ./check-beegfs-services.sh [OPTIONS]
#
# Options:
#   --controller <ip>        Controller node IP address
#   --compute <ip1,ip2,...>  Compute node IP addresses (comma-separated)
#   --verbose               Enable verbose output
#   --help                  Show this help message

set -uo pipefail

# Default configuration
CONTROLLER_IP="${CONTROLLER_IP:-}"
COMPUTE_IPS="${COMPUTE_IPS:-}"
VERBOSE="${VERBOSE:-false}"

# SSH configuration
SSH_USER="${SSH_USER:-admin}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

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
# Arguments:
#   $1 - Color code
#   $2 - Message
#######################################
print_color() {
  local color=$1
  shift
  echo -e "${color}$*${NC}"
}

#######################################
# Print info message
#######################################
info() {
  print_color "$BLUE" "[INFO] $*"
}

#######################################
# Print success message
#######################################
success() {
  print_color "$GREEN" "[PASS] $*"
}

#######################################
# Print error message
#######################################
error() {
  print_color "$RED" "[FAIL] $*"
}

#######################################
# Print warning message
#######################################
warning() {
  print_color "$YELLOW" "[WARN] $*"
}

#######################################
# Print skip message
#######################################
skip() {
  print_color "$YELLOW" "[SKIP] $*"
}

#######################################
# Print usage information
#######################################
usage() {
  cat << EOF
Usage: $0 [OPTIONS]

BeeGFS Service Validation Tests

Options:
  --controller <ip>        Controller node IP address
  --compute <ip1,ip2,...>  Compute node IP addresses (comma-separated)
  --verbose               Enable verbose output
  --help                  Show this help message

Environment Variables:
  CONTROLLER_IP           Controller node IP address
  COMPUTE_IPS             Compute node IP addresses (comma-separated)

Example:
  $0 --controller 192.168.122.10 --compute 192.168.122.11,192.168.122.12

EOF
}

#######################################
# Parse command line arguments
#######################################
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --controller)
        CONTROLLER_IP="$2"
        shift 2
        ;;
      --compute)
        COMPUTE_IPS="$2"
        shift 2
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

#######################################
# Execute command on remote node
# Arguments:
#   $1 - Node IP
#   $2 - Command to execute
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
# Check if service is running on node
# Arguments:
#   $1 - Node IP
#   $2 - Service name
#######################################
check_service_running() {
  local node_ip=$1
  local service=$2

  # First check if service is active
  if exec_on_node "$node_ip" "systemctl is-active --quiet $service" 2>/dev/null; then
    return 0
  else
    # Service is not active, check if it exists and get more info
    if [[ "$VERBOSE" == "true" ]]; then
      local service_status
      service_status=$(exec_on_node "$node_ip" "systemctl status $service --no-pager -l" 2>/dev/null || echo "Service status unavailable")
      warning "Service $service status on $node_ip:"
      while IFS= read -r line; do echo "  $line"; done <<< "$service_status"
    fi
    return 1
  fi
}

#######################################
# Check if service is enabled on node
# Arguments:
#   $1 - Node IP
#   $2 - Service name
#######################################
check_service_enabled() {
  local node_ip=$1
  local service=$2

  if exec_on_node "$node_ip" "systemctl is-enabled --quiet $service"; then
    return 0
  else
    return 1
  fi
}

#######################################
# Test: BeeGFS management service on controller
#######################################
test_mgmt_service() {
  info "Testing BeeGFS management service..."

  if [[ -z "$CONTROLLER_IP" ]]; then
    skip "Controller IP not provided, skipping management service test"
    ((TESTS_SKIPPED++))
    return
  fi

  # Check if service is running
  if check_service_running "$CONTROLLER_IP" "beegfs-mgmtd"; then
    success "Management service is running on controller"
    ((TESTS_PASSED++))
  else
    error "Management service is not running on controller"
    ((TESTS_FAILED++))
    return
  fi

  # Check if service is enabled
  if check_service_enabled "$CONTROLLER_IP" "beegfs-mgmtd"; then
    success "Management service is enabled on controller"
    ((TESTS_PASSED++))
  else
    warning "Management service is not enabled on controller"
    ((TESTS_FAILED++))
  fi

  # Check if management service port is listening
  if exec_on_node "$CONTROLLER_IP" "ss -tuln | grep -q ':8008'"; then
    success "Management service is listening on port 8008"
    ((TESTS_PASSED++))
  else
    error "Management service is not listening on port 8008"
    if [[ "$VERBOSE" == "true" ]]; then
      local netstat_output
      netstat_output=$(exec_on_node "$CONTROLLER_IP" "ss -tuln" 2>/dev/null || echo "Network status unavailable")
      warning "Network connections on controller:"
      while IFS= read -r line; do echo "  $line"; done <<< "$netstat_output"
    fi
    ((TESTS_FAILED++))
  fi
}

#######################################
# Test: BeeGFS metadata service on controller
#######################################
test_meta_service() {
  info "Testing BeeGFS metadata service..."

  if [[ -z "$CONTROLLER_IP" ]]; then
    skip "Controller IP not provided, skipping metadata service test"
    ((TESTS_SKIPPED++))
    return
  fi

  # Check if service is running
  if check_service_running "$CONTROLLER_IP" "beegfs-meta"; then
    success "Metadata service is running on controller"
    ((TESTS_PASSED++))
  else
    error "Metadata service is not running on controller"
    ((TESTS_FAILED++))
    return
  fi

  # Check if service is enabled
  if check_service_enabled "$CONTROLLER_IP" "beegfs-meta"; then
    success "Metadata service is enabled on controller"
    ((TESTS_PASSED++))
  else
    warning "Metadata service is not enabled on controller"
    ((TESTS_FAILED++))
  fi

  # Check if metadata service port is listening
  if exec_on_node "$CONTROLLER_IP" "ss -tuln | grep -q ':8005'"; then
    success "Metadata service is listening on port 8005"
    ((TESTS_PASSED++))
  else
    error "Metadata service is not listening on port 8005"
    ((TESTS_FAILED++))
  fi
}

#######################################
# Test: BeeGFS storage services on compute nodes
#######################################
test_storage_services() {
  info "Testing BeeGFS storage services..."

  if [[ -z "$COMPUTE_IPS" ]]; then
    skip "Compute IPs not provided, skipping storage service tests"
    ((TESTS_SKIPPED++))
    return
  fi

  IFS=',' read -ra NODES <<< "$COMPUTE_IPS"

  for node_ip in "${NODES[@]}"; do
    info "Testing storage service on $node_ip..."

    # Check if service is running
    if check_service_running "$node_ip" "beegfs-storage"; then
      success "Storage service is running on $node_ip"
      ((TESTS_PASSED++))
    else
      error "Storage service is not running on $node_ip"
      ((TESTS_FAILED++))
      continue
    fi

    # Check if service is enabled
    if check_service_enabled "$node_ip" "beegfs-storage"; then
      success "Storage service is enabled on $node_ip"
      ((TESTS_PASSED++))
    else
      warning "Storage service is not enabled on $node_ip"
      ((TESTS_FAILED++))
    fi

    # Check if storage service port is listening
    if exec_on_node "$node_ip" "ss -tuln | grep -q ':8003'"; then
      success "Storage service is listening on port 8003 on $node_ip"
      ((TESTS_PASSED++))
    else
      error "Storage service is not listening on port 8003 on $node_ip"
      ((TESTS_FAILED++))
    fi
  done
}

#######################################
# Test: BeeGFS client services on all nodes
#######################################
test_client_services() {
  info "Testing BeeGFS client services..."

  local all_nodes=()
  [[ -n "$CONTROLLER_IP" ]] && all_nodes+=("$CONTROLLER_IP")
  [[ -n "$COMPUTE_IPS" ]] && IFS=',' read -ra compute_nodes <<< "$COMPUTE_IPS" && all_nodes+=("${compute_nodes[@]}")

  if [[ ${#all_nodes[@]} -eq 0 ]]; then
    skip "No nodes provided, skipping client service tests"
    ((TESTS_SKIPPED++))
    return
  fi

  for node_ip in "${all_nodes[@]}"; do
    info "Testing client service on $node_ip..."

    # Check if helperd service is running
    if check_service_running "$node_ip" "beegfs-helperd"; then
      success "Helperd service is running on $node_ip"
      ((TESTS_PASSED++))
    else
      error "Helperd service is not running on $node_ip"
      ((TESTS_FAILED++))
    fi

    # Check if helperd service is enabled
    if check_service_enabled "$node_ip" "beegfs-helperd"; then
      success "Helperd service is enabled on $node_ip"
      ((TESTS_PASSED++))
    else
      warning "Helperd service is not enabled on $node_ip"
      ((TESTS_FAILED++))
    fi

    # Check if BeeGFS client kernel module is loaded
    if exec_on_node "$node_ip" "lsmod | grep -q beegfs"; then
      success "BeeGFS client kernel module is loaded on $node_ip"
      ((TESTS_PASSED++))
    else
      error "BeeGFS client kernel module is not loaded on $node_ip"
      ((TESTS_FAILED++))
    fi
  done
}

#######################################
# Test: BeeGFS cluster connectivity
#######################################
test_cluster_connectivity() {
  info "Testing BeeGFS cluster connectivity..."

  if [[ -z "$CONTROLLER_IP" ]]; then
    skip "Controller IP not provided, skipping cluster connectivity test"
    ((TESTS_SKIPPED++))
    return
  fi

  # List all nodes in cluster
  local node_output
  local node_exit_code
  node_output=$(exec_on_node "$CONTROLLER_IP" "beegfs-ctl --listnodes --nodetype=all 2>&1")
  node_exit_code=$?
  if [[ $node_exit_code -eq 0 ]]; then
    success "Successfully queried BeeGFS cluster nodes"
    ((TESTS_PASSED++))

    if [[ "$VERBOSE" == "true" ]]; then
      info "Cluster nodes:"
      while IFS= read -r line; do echo "  $line"; done <<< "$node_output"
    fi
  else
    error "Failed to query BeeGFS cluster nodes"
    if [[ "$VERBOSE" == "true" ]]; then
      warning "beegfs-ctl error output:"
      while IFS= read -r line; do echo "  $line"; done <<< "$node_output"
    fi
    ((TESTS_FAILED++))
  fi

  # List storage targets
  local target_output
  local target_exit_code
  target_output=$(exec_on_node "$CONTROLLER_IP" "beegfs-ctl --listtargets --nodetype=storage --state 2>&1")
  target_exit_code=$?
  if [[ $target_exit_code -eq 0 ]]; then
    success "Successfully queried BeeGFS storage targets"
    ((TESTS_PASSED++))

    if [[ "$VERBOSE" == "true" ]]; then
      info "Storage targets:"
      while IFS= read -r line; do echo "  $line"; done <<< "$target_output"
    fi
  else
    error "Failed to query BeeGFS storage targets"
    ((TESTS_FAILED++))
  fi
}

#######################################
# Print test summary
#######################################
print_summary() {
  echo ""
  print_color "$BLUE" "========================================"
  print_color "$BLUE" "BeeGFS Service Validation Test Summary"
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
  print_color "$BLUE" "BeeGFS Service Validation Tests"
  print_color "$BLUE" "========================================"
  echo ""
  info "Controller: ${CONTROLLER_IP:-not set}"
  info "Compute Nodes: ${COMPUTE_IPS:-not set}"
  echo ""

  # Run tests
  test_mgmt_service
  test_meta_service
  test_storage_services
  test_client_services
  test_cluster_connectivity

  # Print summary
  print_summary
}

# Execute main function
main "$@"
