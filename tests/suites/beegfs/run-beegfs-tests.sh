#!/usr/bin/env bash
# BeeGFS Master Test Runner
#
# This script orchestrates all BeeGFS test suites:
# - Service validation tests
# - Filesystem operations tests
# - Performance and scaling tests
#
# Usage:
#   ./run-beegfs-tests.sh [OPTIONS]
#
# Options:
#   --controller <ip>        Controller node IP address
#   --compute <ip1,ip2,...>  Compute node IP addresses (comma-separated)
#   --mount-point <path>     BeeGFS mount point (default: /mnt/beegfs)
#   --test-size <size>       Performance test file size in MB (default: 1024)
#   --suite <name>          Run specific test suite (services|filesystem|performance|all)
#   --verbose               Enable verbose output
#   --help                  Show this help message

source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
set -euo pipefail

# Script configuration
# shellcheck disable=SC2034  # Used as metadata for logging/reporting
SCRIPT_NAME="run-beegfs-tests.sh"
# shellcheck disable=SC2034  # Used as metadata for logging/reporting
TEST_NAME="BeeGFS Master Test Runner"

# Default configuration
CONTROLLER_IP="${CONTROLLER_IP:-}"
COMPUTE_IPS="${COMPUTE_IPS:-}"
BEEGFS_MOUNT_POINT="${BEEGFS_MOUNT_POINT:-/mnt/beegfs}"
TEST_SIZE_MB="${TEST_SIZE_MB:-1024}"
TEST_SUITE="${TEST_SUITE:-all}"
VERBOSE="${VERBOSE:-false}"

# Test suite results
declare -A SUITE_RESULTS

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
section() { print_color "$CYAN" "==== $* ===="; }

#######################################
# Print usage information
#######################################
usage() {
  cat << EOF
Usage: $0 [OPTIONS]

BeeGFS Master Test Runner

Options:
  --controller <ip>        Controller node IP address
  --compute <ip1,ip2,...>  Compute node IP addresses (comma-separated)
  --mount-point <path>     BeeGFS mount point (default: /mnt/beegfs)
  --test-size <size>       Performance test file size in MB (default: 1024)
  --suite <name>          Run specific test suite (services|filesystem|performance|all)
  --verbose               Enable verbose output
  --help                  Show this help message

Test Suites:
  services      - BeeGFS service validation
  filesystem    - Filesystem operations validation
  performance   - Performance and scaling benchmarks
  all           - Run all test suites (default)

Environment Variables:
  CONTROLLER_IP           Controller node IP address
  COMPUTE_IPS             Compute node IP addresses (comma-separated)
  BEEGFS_MOUNT_POINT      BeeGFS mount point
  TEST_SIZE_MB            Performance test file size in MB

Examples:
  # Run all tests
  $0 --controller 192.168.122.10 --compute 192.168.122.11,192.168.122.12

  # Run only service tests
  $0 --controller 192.168.122.10 --suite services

  # Run with custom mount point and test size
  $0 --controller 192.168.122.10 --compute 192.168.122.11 \\
     --mount-point /beegfs --test-size 2048

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
      --suite) TEST_SUITE="$2"; shift 2 ;;
      --verbose) VERBOSE=true; shift ;;
      --help) usage; exit 0 ;;
      *) error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done
}

#######################################
# Validate configuration
#######################################
validate_config() {
  local errors=0

  if [[ -z "$CONTROLLER_IP" ]]; then
    error "Controller IP is required (use --controller or set CONTROLLER_IP)"
    ((errors++))
  fi

  if [[ "$TEST_SUITE" == "performance" ]] || [[ "$TEST_SUITE" == "all" ]]; then
    if [[ -z "$COMPUTE_IPS" ]]; then
      warning "Compute IPs not set - parallel performance tests will be skipped"
    fi
  fi

  case "$TEST_SUITE" in
    services|filesystem|performance|all) ;;
    *)
      error "Invalid test suite: $TEST_SUITE (must be services|filesystem|performance|all)"
      ((errors++))
      ;;
  esac

  if [[ $errors -gt 0 ]]; then
    return 1
  fi

  return 0
}

#######################################
# Run test suite
# Arguments:
#   $1 - Test suite name
#   $2 - Test script path
#######################################
run_test_suite() {
  local suite_name=$1
  local test_script=$2

  section "Running $suite_name test suite"
  echo ""

  if [[ ! -x "$test_script" ]]; then
    error "Test script not found or not executable: $test_script"
    SUITE_RESULTS["$suite_name"]="NOT_FOUND"
    return 1
  fi

  local args=(
    --controller "$CONTROLLER_IP"
  )

  [[ -n "$COMPUTE_IPS" ]] && args+=(--compute "$COMPUTE_IPS")

  # Only pass --mount-point to scripts that support it (not Service Validation)
  if [[ "$suite_name" != "Service Validation" ]] && [[ -n "$BEEGFS_MOUNT_POINT" ]]; then
    args+=(--mount-point "$BEEGFS_MOUNT_POINT")
  fi

  [[ "$suite_name" == "Performance" ]] && args+=(--test-size "$TEST_SIZE_MB")
  [[ "$VERBOSE" == "true" ]] && args+=(--verbose)

  if "$test_script" "${args[@]}"; then
    success "$suite_name tests passed"
    SUITE_RESULTS["$suite_name"]="PASS"
    echo ""
    return 0
  else
    error "$suite_name tests failed"
    SUITE_RESULTS["$suite_name"]="FAIL"
    echo ""
    return 1
  fi
}

#######################################
# Run all test suites
#######################################
run_all_tests() {
  local overall_result=0

  # Service validation tests
  if [[ "$TEST_SUITE" == "all" ]] || [[ "$TEST_SUITE" == "services" ]]; then
    if ! run_test_suite "Service Validation" "$SCRIPT_DIR/check-beegfs-services.sh"; then
      overall_result=1
    fi
  fi

  # Filesystem operations tests
  if [[ "$TEST_SUITE" == "all" ]] || [[ "$TEST_SUITE" == "filesystem" ]]; then
    if ! run_test_suite "Filesystem Operations" "$SCRIPT_DIR/check-filesystem-operations.sh"; then
      overall_result=1
    fi
  fi

  # Performance and scaling tests
  if [[ "$TEST_SUITE" == "all" ]] || [[ "$TEST_SUITE" == "performance" ]]; then
    if ! run_test_suite "Performance" "$SCRIPT_DIR/check-performance-scaling.sh"; then
      overall_result=1
    fi
  fi

  return $overall_result
}

#######################################
# Print test summary
#######################################
print_summary() {
  echo ""
  print_color "$BLUE" "========================================"
  print_color "$BLUE" "BeeGFS Test Suite Summary"
  print_color "$BLUE" "========================================"
  echo ""

  if [[ ${#SUITE_RESULTS[@]} -eq 0 ]]; then
    warning "No test suites were run"
    return 1
  fi

  local passed=0
  local failed=0

  for suite in "${!SUITE_RESULTS[@]}"; do
    local result="${SUITE_RESULTS[$suite]}"
    printf "  %-30s: " "$suite"

    case "$result" in
      PASS)
        print_color "$GREEN" "✓ PASSED"
        ((passed++))
        ;;
      FAIL)
        print_color "$RED" "✗ FAILED"
        ((failed++))
        ;;
      NOT_FOUND)
        print_color "$YELLOW" "⚠ NOT FOUND"
        ((failed++))
        ;;
      *)
        print_color "$YELLOW" "? UNKNOWN"
        ((failed++))
        ;;
    esac
  done

  echo ""
  print_color "$BLUE" "Summary:"
  print_color "$GREEN" "  Test Suites Passed: $passed"
  print_color "$RED" "  Test Suites Failed: $failed"
  echo ""

  if [[ $failed -eq 0 ]]; then
    print_color "$GREEN" "✓ All test suites passed successfully!"
    return 0
  else
    print_color "$RED" "✗ Some test suites failed. Please review the output above."
    return 1
  fi
}

#######################################
# Print banner
#######################################
print_banner() {
  print_color "$CYAN" "========================================"
  print_color "$CYAN" "    BeeGFS Parallel Filesystem Tests"
  print_color "$CYAN" "========================================"
  echo ""
  info "Test Suite: $TEST_SUITE"
  info "Controller: ${CONTROLLER_IP:-not set}"
  info "Compute Nodes: ${COMPUTE_IPS:-not set}"
  info "Mount Point: $BEEGFS_MOUNT_POINT"
  [[ "$TEST_SUITE" == "performance" ]] || [[ "$TEST_SUITE" == "all" ]] && \
    info "Test Size: ${TEST_SIZE_MB}MB"
  echo ""
}

#######################################
# Main function
#######################################
main() {
  parse_args "$@"

  print_banner

  # Validate configuration
  if ! validate_config; then
    error "Configuration validation failed"
    exit 1
  fi

  # Run tests
  local test_result=0
  if ! run_all_tests; then
    test_result=1
  fi

  # Print summary
  if ! print_summary; then
    test_result=1
  fi

  exit $test_result
}

# Execute main function
main "$@"
