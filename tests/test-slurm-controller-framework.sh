#!/bin/bash
#
# SLURM Controller Test Framework
# Task 010 - SLURM Controller Installation and Functionality Validation
# Test framework for validating SLURM controller installation in HPC controller images
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Framework configuration
FRAMEWORK_NAME="SLURM Controller Test Framework"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source shared utilities
UTILS_DIR="$PROJECT_ROOT/tests/test-infra/utils"
if [[ ! -f "$UTILS_DIR/test-framework-utils.sh" ]]; then
    echo "Error: Shared utilities not found at $UTILS_DIR/test-framework-utils.sh"
    exit 1
fi

# shellcheck source=./test-infra/utils/test-framework-utils.sh
source "$UTILS_DIR/test-framework-utils.sh"

# Test configuration
TEST_CONFIG="test-infra/configs/test-slurm-controller.yaml"
TEST_SCRIPTS_DIR="$PROJECT_ROOT/tests/suites/slurm-controller"
TARGET_VM_PATTERN="controller"
MASTER_TEST_SCRIPT="run-slurm-controller-tests.sh"

# Initialize logging
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "slurm-controller"

# Set up environment variables for shared utilities
export PROJECT_ROOT
export TESTS_DIR="$PROJECT_ROOT/tests"
export SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
export SSH_USER="admin"
export CLEANUP_REQUIRED=false
export INTERACTIVE_CLEANUP=false
export TEST_NAME="slurm-controller"

# Main execution function
main() {
    local start_time
    start_time=$(date +%s)

    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  $FRAMEWORK_NAME${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""

    log "Logging initialized: $LOG_DIR"
    log "$FRAMEWORK_NAME Starting"
    log "Working directory: $PROJECT_ROOT"
    echo ""

    log "Starting SLURM Controller Test Framework (Task 010 Validation)"
    log "Configuration: $TEST_CONFIG"
    log "Target VM Pattern: $TARGET_VM_PATTERN"
    log "Test Scripts Directory: $TEST_SCRIPTS_DIR"
    log "Log directory: $LOG_DIR"
    echo ""

    # Validate configuration files exist
    if [[ ! -f "$TEST_CONFIG" ]]; then
        log_error "Test configuration file not found: $TEST_CONFIG"
        exit 1
    fi

    if [[ ! -d "$TEST_SCRIPTS_DIR" ]]; then
        log_error "Test scripts directory not found: $TEST_SCRIPTS_DIR"
        exit 1
    fi

    # Check if controller image exists (optional warning)
    local controller_image_path="$PROJECT_ROOT/build/packer/hpc-controller/hpc-controller/hpc-controller.qcow2"
    if [[ ! -f "$controller_image_path" ]]; then
        log_warning "HPC controller image not found at: $controller_image_path"
        log_warning "You may need to build the controller image first: make build-hpc-controller-image"
    fi

    # Run the complete test framework using shared utilities
    log "Executing test framework using shared utilities..."

    if run_test_framework "$TEST_CONFIG" "$TEST_SCRIPTS_DIR" "$TARGET_VM_PATTERN" "$MASTER_TEST_SCRIPT"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        echo ""
        log "=========================================="
        log_success "Test Framework: ALL TESTS PASSED"
        log_success "SLURM Controller Test Framework: ALL TESTS PASSED"
        log_success "Task 010 validation completed successfully"
        echo ""
        echo "=========================================="
        echo "$FRAMEWORK_NAME completed at: $(date)"
        echo "Exit code: 0"
        echo "Total duration: ${duration}s"
        echo "All logs saved to: $LOG_DIR"
        echo "=========================================="

        exit 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        echo ""
        log "=========================================="
        log_error "Test Framework: SOME TESTS FAILED"
        log_error "Check individual test logs in $LOG_DIR"
        echo ""
        echo "=========================================="
        echo "$FRAMEWORK_NAME completed at: $(date)"
        echo "Exit code: 1"
        echo "Total duration: ${duration}s"
        echo "All logs saved to: $LOG_DIR"
        echo "=========================================="

        exit 1
    fi
}

# Execute main function
main "$@"
