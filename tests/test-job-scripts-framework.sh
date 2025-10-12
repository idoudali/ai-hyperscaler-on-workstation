#!/bin/bash
#
# SLURM Job Scripts Test Framework
# Task 025 - SLURM Job Scripts (Epilog/Prolog) Installation and Functionality Validation
# Test framework for validating SLURM job scripts in HPC compute images
#
# This script uses shared utilities from test-infra/utils/:
#   - cluster-utils.sh: start_cluster, destroy_cluster, resolve_test_config_path
#   - vm-utils.sh: wait_for_vm_ssh, get_vm_ip, get_vm_ips_for_cluster
#   - log-utils.sh: log, log_success, log_error, log_warning, init_logging
#   - test-framework-utils.sh: Orchestration functions (if using run_test_framework)
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Framework configuration
FRAMEWORK_NAME="SLURM Job Scripts Test Framework"

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
if [[ ! -f "$UTILS_DIR/test-framework-utils.sh" ]]; then
    echo "Error: Shared utilities not found at $UTILS_DIR/test-framework-utils.sh"
    exit 1
fi

# Default CLI options (can be overridden by command-line arguments)
VERBOSE=${VERBOSE:-false}
NO_CLEANUP=${NO_CLEANUP:-false}
INTERACTIVE=${INTERACTIVE:-false}

# Set up environment variables for shared utilities AFTER validation
export PROJECT_ROOT
export TESTS_DIR="$PROJECT_ROOT/tests"
export SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
export SSH_USER="admin"
export CLEANUP_REQUIRED=false
export INTERACTIVE_CLEANUP=false
export TEST_NAME="job-scripts"

# shellcheck source=./test-infra/utils/test-framework-utils.sh
source "$UTILS_DIR/test-framework-utils.sh"

# Test configuration
TEST_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/test-job-scripts.yaml"
TEST_SCRIPTS_DIR="$PROJECT_ROOT/tests/suites/job-scripts"
TARGET_VM_PATTERN="compute"
MASTER_TEST_SCRIPT="run-job-scripts-tests.sh"

# Initialize logging
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "job-scripts"

# Individual command functions
# Note: start_cluster, generate_ansible_inventory, deploy_ansible_playbook are provided by utilities

deploy_ansible() {
    log "Deploying SLURM job scripts configuration to cluster: $TEST_NAME"

    local playbook="$PROJECT_ROOT/ansible/playbooks/playbook-job-scripts-runtime-config.yml"

    log "Using runtime playbook: $playbook"
    log ""
    log "Runtime Mode Behavior:"
    log "  - packer_build=false (forced)"
    log "  - Job scripts will be CONFIGURED in SLURM"
    log "  - Services will be RESTARTED"
    log "  - Script execution will be TESTED"
    log ""

    # Use common utility function to deploy Ansible playbook
    # This function:
    # - Gets cluster name from YAML config (not state.json)
    # - Generates inventory using generate_ansible_inventory()
    # - Extracts IPs from inventory (not state.json) for SSH checks
    # - Runs the playbook
    if ! deploy_ansible_playbook "$TEST_CONFIG" "$playbook" "compute" "$LOG_DIR"; then
        log_error "Failed to deploy SLURM job scripts configuration"
        return 1
    fi

    log_success "SLURM job scripts configuration deployed successfully"
    return 0
}

run_tests() {
    local test_scripts_dir="$1"
    local target_pattern="$2"
    local master_script="$3"

    log "Running tests from: $test_scripts_dir"
    log "Target pattern: $target_pattern"
    log "Master script: $master_script"

    # Change to test scripts directory
    cd "$test_scripts_dir" || {
        log_error "Failed to change to test scripts directory: $test_scripts_dir"
        return 1
    }

    # Run master test script
    if [[ -f "$master_script" ]]; then
        log "Executing master test script: $master_script"
        if ./"$master_script"; then
            log_success "Tests completed successfully"
            return 0
        else
            log_error "Tests failed"
            return 1
        fi
    else
        log_error "Master test script not found: $master_script"
        return 1
    fi
}

list_tests() {
    log "Available test scripts in $TEST_SCRIPTS_DIR:"
    echo ""

    if [[ ! -d "$TEST_SCRIPTS_DIR" ]]; then
        log_error "Test scripts directory not found: $TEST_SCRIPTS_DIR"
        return 1
    fi

    # List all executable test scripts (excluding the master script)
    local count=0
    while IFS= read -r test_file; do
        local basename_file
        basename_file=$(basename "$test_file")
        if [[ "$basename_file" != "$MASTER_TEST_SCRIPT" ]]; then
            echo "  - $basename_file"
            ((count++))
        fi
    done < <(find "$TEST_SCRIPTS_DIR" -maxdepth 1 -type f -name "*.sh" -executable | sort)

    # Also show the master script
    if [[ -f "$TEST_SCRIPTS_DIR/$MASTER_TEST_SCRIPT" ]]; then
        echo ""
        echo "Master test script:"
        echo "  - $MASTER_TEST_SCRIPT (runs all tests)"
        ((count++))
    fi

    echo ""
    log "Total: $count test script(s) available"
    echo ""
    echo "Usage: $0 run-test <test-name>"
    echo "Example: $0 run-test check-epilog-prolog.sh"
}

run_single_test() {
    local test_name="$1"

    if [[ -z "$test_name" ]]; then
        log_error "No test name provided"
        echo "Usage: $0 run-test <test-name>"
        echo "Run '$0 list-tests' to see available tests"
        return 1
    fi

    log "Running individual test: $test_name"

    if [[ ! -d "$TEST_SCRIPTS_DIR" ]]; then
        log_error "Test scripts directory not found: $TEST_SCRIPTS_DIR"
        return 1
    fi

    local test_path="$TEST_SCRIPTS_DIR/$test_name"

    if [[ ! -f "$test_path" ]]; then
        log_error "Test script not found: $test_path"
        echo ""
        echo "Available tests:"
        list_tests
        return 1
    fi

    if [[ ! -x "$test_path" ]]; then
        log_error "Test script is not executable: $test_path"
        return 1
    fi

    # Change to test scripts directory and run the test
    cd "$TEST_SCRIPTS_DIR" || {
        log_error "Failed to change to test scripts directory: $TEST_SCRIPTS_DIR"
        return 1
    }

    log "Executing: $test_name"
    if ./"$test_name"; then
        log_success "Test '$test_name' completed successfully"
        return 0
    else
        log_error "Test '$test_name' failed"
        return 1
    fi
}

# Note: destroy_cluster is provided by cluster-utils.sh
# We create a wrapper for backward compatibility
stop_cluster() {
    destroy_cluster "$TEST_CONFIG" "$TEST_NAME"
}

show_cluster_status() {
    log "Checking cluster status: $TEST_NAME"
    log "Configuration: $TEST_CONFIG"

    # Change to project root where state.json is located
    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project root: $PROJECT_ROOT"
        return 1
    }

    # Resolve config path for proper execution
    local resolved_config
    if ! resolved_config=$(resolve_test_config_path "$TEST_CONFIG"); then
        log_error "Failed to resolve config path"
        cd "$TESTS_DIR" || true
        return 1
    fi

    local cmd="uv run ai-how hpc status $resolved_config"
    log "Executing: $cmd"

    $cmd
    local status=$?

    # Return to tests directory
    cd "$TESTS_DIR" || true

    return $status
}

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

    log "Starting SLURM Job Scripts Test Framework (Task 025 Validation)"
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
        echo -e "${GREEN}==========================================${NC}"
        echo -e "${GREEN}  SLURM Job Scripts Tests PASSED${NC}"
        echo -e "${GREEN}==========================================${NC}"
        echo -e "${GREEN}Total execution time: ${duration}s${NC}"
        echo ""

        log "SLURM Job Scripts test framework completed successfully (${duration}s)"
        exit 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        echo ""
        echo -e "${RED}==========================================${NC}"
        echo -e "${RED}  SLURM Job Scripts Tests FAILED${NC}"
        echo -e "${RED}==========================================${NC}"
        echo -e "${RED}Total execution time: ${duration}s${NC}"
        echo ""

        log_error "SLURM Job Scripts test framework failed after ${duration}s"
        exit 1
    fi
}

# Help function
show_help() {
    cat << EOF
$FRAMEWORK_NAME
Task 025 - SLURM Job Scripts (Epilog/Prolog) Installation and Functionality Validation

Usage: $0 [OPTIONS] [COMMAND] [ARGS]

COMMANDS:
    e2e, end-to-end     Run complete end-to-end test workflow (default)
                        Sequence: start-cluster → deploy-ansible → run-tests → stop-cluster

    start-cluster       Start test cluster VMs (keeps cluster running)
    stop-cluster        Stop and destroy test cluster VMs
    deploy-ansible      Deploy SLURM job scripts configuration via Ansible
    run-tests           Run SLURM job scripts test suite on deployed cluster
    list-tests          List all available individual test scripts
    run-test NAME       Run a specific individual test by name
    status              Show current cluster status and configuration
    help, -h, --help    Show this help message

OPTIONS:
    -v, --verbose       Enable verbose output for debugging
    --no-cleanup        Skip cleanup after test completion (for debugging)
    --interactive       Enable interactive prompts for cleanup/confirmation

ENVIRONMENT VARIABLES:
    PROJECT_ROOT        Project root directory
    SSH_KEY_PATH        Path to SSH key for VM access
    SSH_USER            SSH user for VM access (default: admin)
    TEST_CONFIG         Path to test configuration file
    VERBOSE             Enable verbose mode (true/false)
    NO_CLEANUP          Skip cleanup (true/false)
    INTERACTIVE         Enable interactive mode (true/false)

EXAMPLES:
    # Complete end-to-end test with automatic cleanup (recommended for CI/CD)
    $0
    $0 e2e
    $0 end-to-end

    # Modular workflow for debugging (keeps cluster running between steps)
    $0 start-cluster       # Start cluster once
    $0 deploy-ansible      # Deploy configuration
    $0 run-tests          # Run tests (can repeat multiple times)
    $0 stop-cluster       # Clean up when done

    # List and run individual tests for focused debugging
    $0 list-tests                              # Show all available tests
    $0 run-test check-epilog-prolog.sh        # Run specific test

    # Check cluster status
    $0 status

    # Run with verbose output for debugging
    $0 --verbose e2e
    $0 -v run-tests

    # Keep cluster running after tests for manual inspection
    $0 --no-cleanup e2e

WORKFLOW:
    1. CI/CD Mode (automated):
       $0 e2e                 # Complete test with automatic cleanup

    2. Development Mode (manual):
       $0 start-cluster       # Start once
       $0 deploy-ansible      # Deploy changes (can repeat)
       $0 run-tests          # Test (can repeat)
       $0 list-tests         # Find specific tests
       $0 run-test <name>    # Debug specific test
       $0 stop-cluster       # Clean up

TEST CONFIGURATION:
    Config File: $TEST_CONFIG
    Test Scripts: $TEST_SCRIPTS_DIR
    Target VMs: $TARGET_VM_PATTERN
    Master Script: $MASTER_TEST_SCRIPT

NOTES:
    - This framework tests SLURM job scripts (epilog/prolog) functionality
    - Tests include script execution, failure detection, and debug collection
    - Requires HPC compute image with SLURM already configured
    - Job scripts are deployed and configured at runtime (not in Packer build)

EOF
}

# Parse command-line arguments
COMMAND="${1:-e2e}"

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            export VERBOSE
            shift
            ;;
        --no-cleanup)
            NO_CLEANUP=true
            export NO_CLEANUP
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            export INTERACTIVE
            shift
            ;;
        -h|--help|help)
            show_help
            exit 0
            ;;
        e2e|end-to-end)
            COMMAND="e2e"
            shift
            ;;
        start-cluster)
            COMMAND="start-cluster"
            shift
            ;;
        stop-cluster)
            COMMAND="stop-cluster"
            shift
            ;;
        deploy-ansible)
            COMMAND="deploy-ansible"
            shift
            ;;
        run-tests)
            COMMAND="run-tests"
            shift
            ;;
        list-tests)
            COMMAND="list-tests"
            shift
            ;;
        run-test)
            COMMAND="run-test"
            TEST_ARG="${2:-}"
            shift 2 || shift
            ;;
        status)
            COMMAND="status"
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute command
case "$COMMAND" in
    e2e|end-to-end)
        main
        ;;
    start-cluster)
        init_logging "$TIMESTAMP" "logs" "job-scripts"
        log "Starting cluster: $TEST_NAME"
        start_cluster "$TEST_CONFIG" "$TEST_NAME"
        ;;
    stop-cluster)
        init_logging "$TIMESTAMP" "logs" "job-scripts"
        log "Stopping cluster: $TEST_NAME"
        stop_cluster
        ;;
    deploy-ansible)
        init_logging "$TIMESTAMP" "logs" "job-scripts"
        deploy_ansible
        ;;
    run-tests)
        init_logging "$TIMESTAMP" "logs" "job-scripts"
        run_tests "$TEST_SCRIPTS_DIR" "$TARGET_VM_PATTERN" "$MASTER_TEST_SCRIPT"
        ;;
    list-tests)
        list_tests
        ;;
    run-test)
        init_logging "$TIMESTAMP" "logs" "job-scripts"
        run_single_test "$TEST_ARG"
        ;;
    status)
        init_logging "$TIMESTAMP" "logs" "job-scripts"
        show_cluster_status
        ;;
    *)
        echo "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
