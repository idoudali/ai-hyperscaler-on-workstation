#!/usr/bin/env bash
# BeeGFS Performance and Scaling Tests
#
# This script performs performance benchmarks on BeeGFS:
# - Sequential read/write performance
# - Random I/O performance
# - Metadata operation performance
# - Parallel I/O scaling across nodes
#
# Usage:
#   ./check-performance-scaling.sh [OPTIONS]
#
# Options:
#   --controller <ip>        Controller node IP address
#   --compute <ip1,ip2,...>  Compute node IP addresses (comma-separated)
#   --mount-point <path>     BeeGFS mount point (default: /mnt/beegfs)
#   --test-size <size>       Test file size in MB (default: 1024)
#   --verbose               Enable verbose output
#   --help                  Show this help message

source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
set -euo pipefail

# Script configuration
# shellcheck disable=SC2034  # Used as metadata for logging/reporting
SCRIPT_NAME="check-performance-scaling.sh"
# shellcheck disable=SC2034  # Used as metadata for logging/reporting
TEST_NAME="BeeGFS Performance and Scaling Tests"

# Default configuration
CONTROLLER_IP="${CONTROLLER_IP:-}"
COMPUTE_IPS="${COMPUTE_IPS:-}"
BEEGFS_MOUNT_POINT="${BEEGFS_MOUNT_POINT:-/mnt/beegfs}"
TEST_SIZE_MB="${TEST_SIZE_MB:-1024}"
VERBOSE="${VERBOSE:-false}"

# SSH configuration
SSH_USER="${SSH_USER:-admin}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
TEST_DIR="beegfs-perf-test-$(date +%Y%m%d-%H%M%S)"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Performance results
declare -A PERF_RESULTS

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

BeeGFS Performance and Scaling Tests

Options:
  --controller <ip>        Controller node IP address
  --compute <ip1,ip2,...>  Compute node IP addresses (comma-separated)
  --mount-point <path>     BeeGFS mount point (default: /mnt/beegfs)
  --test-size <size>       Test file size in MB (default: 1024)
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
      --test-size) TEST_SIZE_MB="$2"; shift 2 ;;
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
# Format bytes to human-readable
#######################################
format_bytes() {
  local bytes=$1
  local gb=$((bytes / 1024 / 1024 / 1024))
  local mb=$((bytes / 1024 / 1024))

  if [[ $gb -gt 0 ]]; then
    echo "${gb}GB"
  elif [[ $mb -gt 0 ]]; then
    echo "${mb}MB"
  else
    echo "${bytes} bytes"
  fi
}

#######################################
# Test: Sequential write performance
#######################################
test_sequential_write() {
  info "Testing sequential write performance..."

  if [[ -z "$CONTROLLER_IP" ]]; then
    skip "Controller IP not provided, skipping sequential write test"
    ((TESTS_SKIPPED++))
    return
  fi

  local test_file="$BEEGFS_MOUNT_POINT/$TEST_DIR/seq-write-test"
  local dd_output

  # Create test directory
  exec_on_node "$CONTROLLER_IP" "mkdir -p $BEEGFS_MOUNT_POINT/$TEST_DIR" >/dev/null 2>&1 || true

  # Run sequential write test
  info "Writing ${TEST_SIZE_MB}MB test file..."
  if dd_output=$(exec_on_node "$CONTROLLER_IP" \
    "dd if=/dev/zero of=$test_file bs=1M count=$TEST_SIZE_MB conv=fdatasync 2>&1"); then

    # Parse throughput from dd output
    local throughput
    if throughput=$(echo "$dd_output" | grep -oP '\d+(\.\d+)? [MG]B/s' | tail -1); then
      success "Sequential write: $throughput"
      PERF_RESULTS["seq_write"]="$throughput"
      ((TESTS_PASSED++))

      if [[ "$VERBOSE" == "true" ]]; then
        # shellcheck disable=SC2001
        echo "$dd_output" | sed 's/^/  /'
      fi
    else
      warning "Could not parse write throughput from dd output"
      ((TESTS_FAILED++))
    fi
  else
    error "Sequential write test failed"
    ((TESTS_FAILED++))
  fi

  # Clean up
  exec_on_node "$CONTROLLER_IP" "rm -f $test_file" >/dev/null 2>&1 || true
}

#######################################
# Test: Sequential read performance
#######################################
test_sequential_read() {
  info "Testing sequential read performance..."

  if [[ -z "$CONTROLLER_IP" ]]; then
    skip "Controller IP not provided, skipping sequential read test"
    ((TESTS_SKIPPED++))
    return
  fi

  local test_file="$BEEGFS_MOUNT_POINT/$TEST_DIR/seq-read-test"

  # Create test file
  info "Preparing ${TEST_SIZE_MB}MB test file for reading..."
  if ! exec_on_node "$CONTROLLER_IP" \
    "dd if=/dev/zero of=$test_file bs=1M count=$TEST_SIZE_MB conv=fdatasync 2>&1" >/dev/null; then
    error "Failed to create test file for read test"
    ((TESTS_FAILED++))
    return
  fi

  # Clear cache
  exec_on_node "$CONTROLLER_IP" "sync && echo 3 > /proc/sys/vm/drop_caches" >/dev/null 2>&1 || true

  # Run sequential read test
  info "Reading ${TEST_SIZE_MB}MB test file..."
  local dd_output
  if dd_output=$(exec_on_node "$CONTROLLER_IP" \
    "dd if=$test_file of=/dev/null bs=1M 2>&1"); then

    # Parse throughput from dd output
    local throughput
    if throughput=$(echo "$dd_output" | grep -oP '\d+(\.\d+)? [MG]B/s' | tail -1); then
      success "Sequential read: $throughput"
      PERF_RESULTS["seq_read"]="$throughput"
      ((TESTS_PASSED++))

      if [[ "$VERBOSE" == "true" ]]; then
        # shellcheck disable=SC2001
        echo "$dd_output" | sed 's/^/  /'
      fi
    else
      warning "Could not parse read throughput from dd output"
      ((TESTS_FAILED++))
    fi
  else
    error "Sequential read test failed"
    ((TESTS_FAILED++))
  fi

  # Clean up
  exec_on_node "$CONTROLLER_IP" "rm -f $test_file" >/dev/null 2>&1 || true
}

#######################################
# Test: Metadata operations performance
#######################################
test_metadata_operations() {
  info "Testing metadata operations performance..."

  if [[ -z "$CONTROLLER_IP" ]]; then
    skip "Controller IP not provided, skipping metadata test"
    ((TESTS_SKIPPED++))
    return
  fi

  local test_dir="$BEEGFS_MOUNT_POINT/$TEST_DIR/metadata-test"
  local num_files=1000

  # Create test directory
  exec_on_node "$CONTROLLER_IP" "mkdir -p $test_dir" >/dev/null 2>&1 || true

  # Test file creation
  info "Creating $num_files files..."
  # shellcheck disable=SC2155
  local start_time=$(date +%s.%N)
  if exec_on_node "$CONTROLLER_IP" "cd $test_dir && for i in {1..$num_files}; do touch file-\$i; done"; then
    # shellcheck disable=SC2155
    local end_time=$(date +%s.%N)
    # shellcheck disable=SC2155
    local duration=$(echo "$end_time - $start_time" | bc)
    # shellcheck disable=SC2155
    local ops_per_sec=$(echo "$num_files / $duration" | bc)
    success "File creation: ${ops_per_sec} ops/sec"
    PERF_RESULTS["metadata_create"]="${ops_per_sec} ops/sec"
    ((TESTS_PASSED++))
  else
    error "File creation test failed"
    ((TESTS_FAILED++))
    return
  fi

  # Test file stat
  info "Stat'ing $num_files files..."
  # shellcheck disable=SC2155
  start_time=$(date +%s.%N)
  if exec_on_node "$CONTROLLER_IP" "cd $test_dir && for i in {1..$num_files}; do stat file-\$i >/dev/null; done"; then
    # shellcheck disable=SC2155
    end_time=$(date +%s.%N)
    # shellcheck disable=SC2155
    duration=$(echo "$end_time - $start_time" | bc)
    # shellcheck disable=SC2155
    ops_per_sec=$(echo "$num_files / $duration" | bc)
    success "File stat: ${ops_per_sec} ops/sec"
    PERF_RESULTS["metadata_stat"]="${ops_per_sec} ops/sec"
    ((TESTS_PASSED++))
  else
    error "File stat test failed"
    ((TESTS_FAILED++))
  fi

  # Test file deletion
  info "Deleting $num_files files..."
  # shellcheck disable=SC2155
  start_time=$(date +%s.%N)
  if exec_on_node "$CONTROLLER_IP" "cd $test_dir && rm -f file-*"; then
    # shellcheck disable=SC2155
    end_time=$(date +%s.%N)
    # shellcheck disable=SC2155
    duration=$(echo "$end_time - $start_time" | bc)
    # shellcheck disable=SC2155
    ops_per_sec=$(echo "$num_files / $duration" | bc)
    success "File deletion: ${ops_per_sec} ops/sec"
    PERF_RESULTS["metadata_delete"]="${ops_per_sec} ops/sec"
    ((TESTS_PASSED++))
  else
    error "File deletion test failed"
    ((TESTS_FAILED++))
  fi

  # Clean up
  exec_on_node "$CONTROLLER_IP" "rm -rf $test_dir" >/dev/null 2>&1 || true
}

#######################################
# Test: Parallel I/O across nodes
#######################################
test_parallel_io() {
  info "Testing parallel I/O across nodes..."

  if [[ -z "$COMPUTE_IPS" ]]; then
    skip "Compute IPs not provided, skipping parallel I/O test"
    ((TESTS_SKIPPED++))
    return
  fi

  IFS=',' read -ra NODES <<< "$COMPUTE_IPS"
  local num_nodes=${#NODES[@]}

  info "Running parallel writes on $num_nodes compute nodes..."

  local pids=()
  # shellcheck disable=SC2155
  local start_time=$(date +%s.%N)

  # Start parallel writes
  for i in "${!NODES[@]}"; do
    local node_ip="${NODES[$i]}"
    local test_file="$BEEGFS_MOUNT_POINT/$TEST_DIR/parallel-write-node${i}"

    (
      exec_on_node "$node_ip" \
        "dd if=/dev/zero of=$test_file bs=1M count=$TEST_SIZE_MB conv=fdatasync 2>&1" \
        > "${TMPDIR:-/tmp}/beegfs-parallel-write-node${i}.log" 2>&1
    ) &
    pids+=($!)
  done

  # Wait for all writes to complete
  local all_success=true
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      all_success=false
    fi
  done

  # shellcheck disable=SC2155
  local end_time=$(date +%s.%N)
  # shellcheck disable=SC2155
  local duration=$(echo "$end_time - $start_time" | bc)

  if [[ "$all_success" == "true" ]]; then
    local total_mb=$((TEST_SIZE_MB * num_nodes))
    # shellcheck disable=SC2155
    local aggregate_throughput=$(echo "$total_mb / $duration" | bc)
    success "Parallel write (${num_nodes} nodes): ${aggregate_throughput} MB/s aggregate"
    PERF_RESULTS["parallel_write"]="${aggregate_throughput} MB/s"
    ((TESTS_PASSED++))
  else
    error "Some parallel writes failed"
    ((TESTS_FAILED++))
  fi

  # Clean up
  for i in "${!NODES[@]}"; do
    local node_ip="${NODES[$i]}"
    local test_file="$BEEGFS_MOUNT_POINT/$TEST_DIR/parallel-write-node${i}"
    exec_on_node "$node_ip" "rm -f $test_file" >/dev/null 2>&1 || true
  done
}

#######################################
# Test: BeeGFS filesystem statistics
#######################################
test_filesystem_stats() {
  info "Gathering BeeGFS filesystem statistics..."

  if [[ -z "$CONTROLLER_IP" ]]; then
    skip "Controller IP not provided, skipping filesystem stats"
    ((TESTS_SKIPPED++))
    return
  fi

  # Get filesystem usage
  local df_output
  if df_output=$(exec_on_node "$CONTROLLER_IP" "beegfs-df 2>&1"); then
    success "Retrieved BeeGFS filesystem statistics"
    ((TESTS_PASSED++))

    if [[ "$VERBOSE" == "true" ]]; then
      info "BeeGFS filesystem usage:"
      # shellcheck disable=SC2001
      echo "$df_output" | sed 's/^/  /'
    fi
  else
    error "Failed to retrieve filesystem statistics"
    ((TESTS_FAILED++))
  fi

  # Get pool information
  local pool_output
  if pool_output=$(exec_on_node "$CONTROLLER_IP" "beegfs-ctl --getentryinfo $BEEGFS_MOUNT_POINT 2>&1"); then
    success "Retrieved BeeGFS pool information"
    ((TESTS_PASSED++))

    if [[ "$VERBOSE" == "true" ]]; then
      info "BeeGFS pool information:"
      # shellcheck disable=SC2001
      echo "$pool_output" | sed 's/^/  /'
    fi
  else
    warning "Could not retrieve pool information"
    ((TESTS_FAILED++))
  fi
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
# Print performance summary
#######################################
print_performance_summary() {
  if [[ ${#PERF_RESULTS[@]} -gt 0 ]]; then
    echo ""
    print_color "$BLUE" "========================================"
    print_color "$BLUE" "Performance Results"
    print_color "$BLUE" "========================================"

    for key in "${!PERF_RESULTS[@]}"; do
      # shellcheck disable=SC2155
      local label=$(echo "$key" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')
      printf "  %-25s: %s\n" "$label" "${PERF_RESULTS[$key]}"
    done
  fi
}

#######################################
# Print test summary
#######################################
print_summary() {
  echo ""
  print_color "$BLUE" "========================================"
  print_color "$BLUE" "BeeGFS Performance Test Summary"
  print_color "$BLUE" "========================================"
  echo ""
  print_color "$GREEN" "Tests Passed:  $TESTS_PASSED"
  print_color "$RED" "Tests Failed:  $TESTS_FAILED"
  print_color "$YELLOW" "Tests Skipped: $TESTS_SKIPPED"

  print_performance_summary

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

  # Check if bc is available
  if ! command -v bc &> /dev/null; then
    warning "bc command not found. Install with: apt-get install bc"
    warning "Some performance calculations may not work."
  fi

  print_color "$BLUE" "========================================"
  print_color "$BLUE" "BeeGFS Performance and Scaling Tests"
  print_color "$BLUE" "========================================"
  echo ""
  info "Controller: ${CONTROLLER_IP:-not set}"
  info "Compute Nodes: ${COMPUTE_IPS:-not set}"
  info "Mount Point: $BEEGFS_MOUNT_POINT"
  info "Test Size: ${TEST_SIZE_MB}MB"
  echo ""

  # Set up cleanup trap
  trap cleanup EXIT

  # Run tests
  test_sequential_write
  test_sequential_read
  test_metadata_operations
  test_parallel_io
  test_filesystem_stats

  # Print summary
  print_summary
}

# Execute main function
main "$@"
