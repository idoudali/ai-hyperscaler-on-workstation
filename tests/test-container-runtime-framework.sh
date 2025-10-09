#!/bin/bash
#
# Container Runtime Test Framework
# Task 008/009 - Container Runtime Installation and Security Validation
# Test framework for validating container runtime (Apptainer/Singularity) in HPC compute images
#

set -euo pipefail

# Help message
show_help() {
    cat << EOF
Container Runtime Test Framework - Task 008/009 Validation

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    e2e, end-to-end   Run complete end-to-end test with cleanup (default behavior)
    start-cluster     Start the HPC cluster independently
    stop-cluster      Stop and destroy the HPC cluster
    deploy-ansible    Deploy container runtime via Ansible (assumes cluster is running)
    run-tests         Run container runtime tests on deployed cluster
    list-tests        List all available individual test scripts
    run-test NAME     Run a specific individual test by name
    status            Show cluster status
    help              Show this help message

OPTIONS:
    -h, --help        Show this help message
    -v, --verbose     Enable verbose output
    --no-cleanup      Skip cleanup after test completion
    --interactive     Enable interactive cleanup prompts

EXAMPLES:
    # Run complete end-to-end test with cleanup (default, recommended for CI/CD)
    $0
    $0 e2e
    $0 end-to-end

    # Modular workflow for debugging (keeps cluster running)
    $0 start-cluster          # Start cluster
    $0 deploy-ansible         # Deploy container runtime
    $0 run-tests              # Run tests (can repeat)
    $0 list-tests             # Show all available tests
    $0 run-test check-singularity-install.sh  # Run specific test
    $0 status                 # Check status
    $0 stop-cluster           # Clean up when done

WORKFLOWS:
    End-to-End (Default):
        $0                    # Complete test with cleanup
        $0 e2e                # Explicit

    Manual/Debugging:
        1. Start cluster:     $0 start-cluster
        2. Deploy Ansible:    $0 deploy-ansible
        3. Run tests:         $0 run-tests
        4. Stop cluster:      $0 stop-cluster

CONFIGURATION:
    Test Config: $TEST_CONFIG
    Log Directory: logs/container-runtime-test-run-*
    VM Pattern: $TARGET_VM_PATTERN

VALIDATION:
    Task 008: Container Runtime Installation
      ✓ Apptainer binary installed and functional (>= 1.4.2)
      ✓ All dependencies installed (fuse, squashfs-tools, uidmap, etc.)
      ✓ Container execution capabilities (pull, run, bind mounts)
      ✓ Integration with SLURM scheduling

    Task 009: Container Security Configuration
      ✓ Security configuration properly applied
    ✓ Privilege escalation prevention
    ✓ Host filesystem access restrictions
    ✓ Security policies validation

EOF
}

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Framework configuration
FRAMEWORK_NAME="Container Runtime Test Framework"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Validate PROJECT_ROOT before setting up environment variables
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "Error: Invalid PROJECT_ROOT directory: $PROJECT_ROOT"
    exit 1
fi

# Source shared utilities
UTILS_DIR="$PROJECT_ROOT/tests/test-infra/utils"

# Set up environment variables for shared utilities AFTER validation
export PROJECT_ROOT
export TESTS_DIR="$PROJECT_ROOT/tests"
export SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
export SSH_USER="admin"
export CLEANUP_REQUIRED=false
export INTERACTIVE_CLEANUP=false
export TEST_NAME="container-runtime"

# Source all required utilities
for util in log-utils.sh cluster-utils.sh test-framework-utils.sh ansible-utils.sh; do
    if [[ ! -f "$UTILS_DIR/$util" ]]; then
        echo "Error: Shared utility not found: $UTILS_DIR/$util"
        exit 1
    fi
    # shellcheck source=./test-infra/utils/
    source "$UTILS_DIR/$util"
done

# Test configuration
TEST_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/test-container-runtime.yaml"
TEST_SCRIPTS_DIR="$PROJECT_ROOT/tests/suites/container-runtime"
TARGET_VM_PATTERN="compute"
MASTER_TEST_SCRIPT="run-container-runtime-tests.sh"

# Global variables for command line options
INTERACTIVE=false
COMMAND="e2e"
TEST_TO_RUN=""

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                export VERBOSE=true
                shift
                ;;
            --no-cleanup)
                export CLEANUP_REQUIRED=false
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                export INTERACTIVE_CLEANUP=true
                shift
                ;;
            e2e|end-to-end|start-cluster|stop-cluster|deploy-ansible|run-tests|list-tests|status|help)
                COMMAND="$1"
                shift
                ;;
            run-test)
                COMMAND="run-test"
                if [[ $# -gt 1 ]]; then
                    TEST_TO_RUN="$2"
                    shift 2
                else
                    log_error "run-test requires a test name"
                    echo "Usage: $0 run-test <test-name>"
                    echo "Use: $0 list-tests to see available tests"
                    exit 1
                fi
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Use '$0 --help' for usage information"
                exit 1
                ;;
        esac
    done
}

# Initialize logging
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "container-runtime"




# Run tests on deployed cluster
run_tests() {
    log "Running container runtime tests on deployed cluster..."

    # Validate files exist
    if [[ ! -d "$TEST_SCRIPTS_DIR" ]]; then
        log_error "Test scripts directory not found: $TEST_SCRIPTS_DIR"
        return 1
    fi

    # Run master test script
    log "Executing master test script: $MASTER_TEST_SCRIPT"
    if ! run_master_tests "$TEST_SCRIPTS_DIR" "$MASTER_TEST_SCRIPT"; then
        log_error "Tests failed"
        return 1
    fi

    log_success "All tests passed"
    return 0
}




# Run complete end-to-end test with cleanup
run_full_test() {
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

    log "Starting Container Runtime Test Framework (Task 008/009 Validation)"
    log "Configuration: $TEST_CONFIG"
    log "Target VM Pattern: $TARGET_VM_PATTERN"
    log "Test Scripts Directory: $TEST_SCRIPTS_DIR"
    log "Log directory: $LOG_DIR"
    echo ""

    # Validate configuration files exist
    if [[ ! -f "$TEST_CONFIG" ]]; then
        log_error "Test configuration file not found: $TEST_CONFIG"
        return 1
    fi

    if [[ ! -d "$TEST_SCRIPTS_DIR" ]]; then
        log_error "Test scripts directory not found: $TEST_SCRIPTS_DIR"
        return 1
    fi

    # Check if compute image exists (optional warning)
    local compute_image_path="$PROJECT_ROOT/build/packer/hpc-compute/hpc-compute/hpc-compute.qcow2"
    if [[ ! -f "$compute_image_path" ]]; then
        log_warning "HPC compute image not found at: $compute_image_path"
        log_warning "You may need to build the compute image first: make build-hpc-compute-image"
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
        log_success "Container Runtime Test Framework: ALL TESTS PASSED"
        log_success "Task 008 and Task 009 validation completed successfully"
        echo ""
        echo "=========================================="
        echo "$FRAMEWORK_NAME completed at: $(date)"
        echo "Exit code: 0"
        echo "Total duration: ${duration}s"
        echo "All logs saved to: $LOG_DIR"
        echo "=========================================="

        return 0
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

        return 1
    fi
}

# Main execution
main() {
# Parse command line arguments
    parse_arguments "$@"

    # Handle different commands
    case "$COMMAND" in
        "help")
            show_help
            exit 0
            ;;
        "status")
            show_cluster_status "$TEST_CONFIG"
            exit 0
            ;;
        "e2e"|"end-to-end")
            # End-to-end test with cleanup
            log "Starting End-to-End Test (with automatic cleanup)"
            log "Configuration: $TEST_CONFIG"
            log "Target VM Pattern: $TARGET_VM_PATTERN"
            log "Test Scripts Directory: $TEST_SCRIPTS_DIR"
            log "Log directory: $LOG_DIR"
            echo ""

            if run_full_test; then
                log_success "End-to-end test completed successfully"
                exit 0
            else
                log_error "End-to-end test failed"
                exit 1
            fi
            ;;
        "start-cluster")
            # Start cluster only
            log "Starting cluster independently..."
            if start_cluster_interactive "$TEST_CONFIG" "$INTERACTIVE"; then
                log_success "Cluster started successfully"
                log ""
                log "Next steps:"
                log "  1. Deploy Ansible: $0 deploy-ansible"
                log "  2. Run tests: $0 run-tests"
                log ""
                exit 0
            else
                log_error "Failed to start cluster"
                exit 1
            fi
            ;;
        "stop-cluster")
            # Stop cluster
            log "Stopping cluster..."
            if stop_cluster_interactive "$TEST_CONFIG" "$INTERACTIVE"; then
                log_success "Cluster stopped successfully"
                exit 0
            else
                log_error "Failed to stop cluster"
                exit 1
            fi
            ;;
        "deploy-ansible")
            # Deploy ansible on running cluster
            log "Deploying Ansible on running cluster..."
            if deploy_ansible_full_workflow "$TEST_CONFIG" "$TARGET_VM_PATTERN"; then
                log_success "Ansible deployment completed"
                log ""
                log "Next step:"
                log "  1. Run tests: $0 run-tests"
                log ""
                exit 0
            else
                log_error "Ansible deployment failed"
                exit 1
            fi
            ;;
        "run-tests")
            # Run tests on deployed cluster
            log "Running tests on deployed cluster..."
            if run_tests; then
                log_success "Tests completed successfully"
                exit 0
            else
                log_error "Tests failed"
                exit 1
            fi
            ;;
        "list-tests")
            # List available tests
            list_tests_in_directory "$TEST_SCRIPTS_DIR" "Test Scripts" "$0"
            exit 0
            ;;
        "run-test")
            # Run specific test
            if [[ -z "$TEST_TO_RUN" ]]; then
                log_error "Test name required for run-test command"
                echo "Usage: $0 run-test <test-name>"
                echo "Use: $0 list-tests to see available tests"
                exit 1
            fi
            if execute_single_test_by_name "$TEST_TO_RUN" "$TEST_SCRIPTS_DIR" "$0"; then
                log_success "Test passed: $TEST_TO_RUN"
                exit 0
            else
                log_error "Test failed: $TEST_TO_RUN"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
