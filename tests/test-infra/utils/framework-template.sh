#!/bin/bash
#
# TEST FRAMEWORK TEMPLATE
#
# This is a standardized template for creating new test frameworks.
# It provides the complete structure and pattern for implementing
# a consistent test framework that integrates with the HPC test infrastructure.
#
# TO USE THIS TEMPLATE:
# 1. Copy this file to tests/test-YOUR-FRAMEWORK-framework.sh
# 2. Replace all PLACEHOLDER values (marked with REPLACEME_*)
# 3. Implement framework-specific functions in the "Framework-Specific Functions" section
# 4. Test with: ./test-YOUR-FRAMEWORK-framework.sh --help
#
# The template provides:
#  - Standardized CLI parsing (via framework-cli.sh)
#  - Cluster lifecycle management (via framework-orchestration.sh)
#  - Consistent help output and command handling
#  - Proper error handling and logging
#  - Support for modular workflow (start/deploy/test/stop)
#  - Full e2e automation with cleanup
#

set -euo pipefail

# ==============================================================================
# CONFIGURATION SECTION - REPLACE THESE VALUES FOR YOUR FRAMEWORK
# ==============================================================================

# Framework identification
# shellcheck disable=SC2089,SC2090
FRAMEWORK_NAME="REPLACEME_Framework Name (e.g., 'My Component Test Framework')"
FRAMEWORK_DESCRIPTION="REPLACEME_Description of what this framework tests"
FRAMEWORK_TASK="REPLACEME_TASK-NNN"

# Paths and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$PROJECT_ROOT/tests"
UTILS_DIR="$TESTS_DIR/test-infra/utils"

# Framework-specific configuration
FRAMEWORK_TEST_CONFIG="$TESTS_DIR/test-infra/configs/REPLACEME_test-config.yaml"
FRAMEWORK_TEST_SCRIPTS_DIR="$TESTS_DIR/suites/REPLACEME_test-suite-dir"
FRAMEWORK_TARGET_VM_PATTERN="REPLACEME_controller"  # e.g., "controller", "compute", "all"
FRAMEWORK_MASTER_TEST_SCRIPT="REPLACEME_run-tests.sh"  # Master test runner in suite dir

# SSH Configuration
SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
SSH_USER="admin"

# Timeout values (in seconds)
# shellcheck disable=SC2034
FRAMEWORK_CLUSTER_START_TIMEOUT=600
# shellcheck disable=SC2034
FRAMEWORK_SSH_WAIT_TIMEOUT=300
# shellcheck disable=SC2034
FRAMEWORK_ANSIBLE_TIMEOUT=1800
# shellcheck disable=SC2034
FRAMEWORK_TEST_TIMEOUT=3600

# Export for shared utilities
# shellcheck disable=SC2090
export PROJECT_ROOT TESTS_DIR SSH_KEY_PATH SSH_USER
# shellcheck disable=SC2090
export FRAMEWORK_NAME FRAMEWORK_DESCRIPTION FRAMEWORK_TEST_CONFIG
export FRAMEWORK_TEST_SCRIPTS_DIR FRAMEWORK_TARGET_VM_PATTERN
export FRAMEWORK_MASTER_TEST_SCRIPT FRAMEWORK_CLUSTER_START_TIMEOUT

# ==============================================================================
# UTILITY SOURCING - Sources shared utilities for CLI, orchestration, logging
# ==============================================================================

# Validate PROJECT_ROOT
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "Error: Invalid PROJECT_ROOT: $PROJECT_ROOT"
    exit 1
fi

# Source shared utilities in dependency order
for util in log-utils.sh cluster-utils.sh vm-utils.sh ansible-utils.sh test-framework-utils.sh framework-cli.sh framework-orchestration.sh; do
    if [[ ! -f "$UTILS_DIR/$util" ]]; then
        echo "Error: Shared utility not found: $UTILS_DIR/$util"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$UTILS_DIR/$util"
done

# Initialize framework environment (sources additional utilities)
setup_framework_environment

# ==============================================================================
# DEBUG AND HELP SETUP
# ==============================================================================

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Customize help output for this framework
# REPLACEME_FRAMEWORKS_EXTRA_COMMANDS: Additional commands specific to this framework
# REPLACEME_FRAMEWORKS_EXTRA_OPTIONS: Additional options specific to this framework
# REPLACEME_FRAMEWORKS_EXTRA_EXAMPLES: Additional usage examples
show_framework_help() {
    cat << EOF
${BLUE}${FRAMEWORK_NAME}${NC}
${FRAMEWORK_DESCRIPTION}
Task: ${FRAMEWORK_TASK}

USAGE:
    \$0 [OPTIONS] [COMMAND]

STANDARD COMMANDS:
    e2e, end-to-end   Run complete end-to-end test with cleanup (default)
    start-cluster     Start the cluster independently
    stop-cluster      Stop and destroy the cluster
    deploy-ansible    Deploy configuration via Ansible (assumes cluster running)
    run-tests         Run test suite on deployed cluster
    list-tests        List all available individual tests
    run-test NAME     Run a specific individual test by name
    status            Show cluster status
    help              Show this help message

REPLACEME_UNCOMMENT_AND_CUSTOMIZE_IF_NEEDED:
# ADDITIONAL COMMANDS (if your framework has special commands):
#    custom-cmd        Description of custom command

STANDARD OPTIONS:
    -h, --help        Show this help message
    -v, --verbose     Enable verbose output
    -q, --quiet       Minimal output
    --log-level LVL   Set logging level: quiet, normal, verbose, debug
    --no-cleanup      Skip cleanup after test completion
    --interactive     Enable interactive cleanup prompts

REPLACEME_UNCOMMENT_AND_CUSTOMIZE_IF_NEEDED:
# ADDITIONAL OPTIONS (if your framework needs special options):
#    --custom-opt VAL  Description of custom option

LOGGING LEVELS:
    quiet             Only show errors and critical messages
    normal            Standard output (default)
    verbose           Detailed output including all operations
    debug             Maximum verbosity for troubleshooting

EXAMPLES:
    # Run complete end-to-end test with cleanup (recommended for CI/CD)
    \$0
    \$0 e2e
    \$0 end-to-end

    # Modular workflow for debugging (keeps cluster running)
    \$0 start-cluster          # Start cluster
    \$0 deploy-ansible         # Deploy configuration
    \$0 run-tests              # Run tests (can repeat)
    \$0 list-tests             # Show available tests
    \$0 run-test check-foo.sh  # Run specific test
    \$0 status                 # Check status
    \$0 stop-cluster           # Clean up

    # With options
    \$0 --verbose e2e          # Verbose e2e test
    \$0 -v run-tests           # Verbose test run
    \$0 --quiet start-cluster  # Quiet mode cluster start
    \$0 --no-cleanup e2e       # E2E without cleanup

REPLACEME_UNCOMMENT_AND_CUSTOMIZE_IF_NEEDED:
# ADDITIONAL EXAMPLES (framework-specific examples):
#    \$0 custom-cmd             # Run custom command

CONFIGURATION:
    Framework: ${FRAMEWORK_NAME}
    Task: ${FRAMEWORK_TASK}
    Test Config: ${FRAMEWORK_TEST_CONFIG}
    Test Scripts: ${FRAMEWORK_TEST_SCRIPTS_DIR}
    Target VMs: ${FRAMEWORK_TARGET_VM_PATTERN}

NOTES:
    - All commands default to e2e if not specified
    - Use --help to see this message
    - Use --verbose for detailed output during debugging
    - Use --no-cleanup to keep cluster running for manual inspection

REFERENCES:
    - Test Infrastructure: docs/TESTING-GUIDE.md
    - Cluster Deployment: docs/CLUSTER-DEPLOYMENT-WORKFLOW.md
    - This Framework: docs/TESTING-${FRAMEWORK_TASK}.md

EOF
}

# ==============================================================================
# FRAMEWORK-SPECIFIC FUNCTIONS - REPLACE/EXTEND THESE FOR YOUR FRAMEWORK
# ==============================================================================

#
# Framework-specific initialization (optional)
#
# REPLACEME: Implement any framework-specific setup needed
# This function is called at startup if needed
#
init_framework() {
    log "Initializing ${FRAMEWORK_NAME}..."

    # REPLACEME: Add framework-specific setup here
    # Example: Check for required commands, set up environment, etc.

    log "Framework initialization complete"
}

#
# Run framework-specific tests (optional override)
#
# REPLACEME: If you need custom test logic beyond the standard run_framework_tests()
# Override this function. Otherwise, the standard flow will be used.
#
run_framework_specific_tests() {
    log "Running ${FRAMEWORK_NAME} tests..."

    # Standard test execution (use this or implement your own)
    if ! run_test_framework "$FRAMEWORK_TEST_CONFIG" "$FRAMEWORK_TEST_SCRIPTS_DIR" "$FRAMEWORK_TARGET_VM_PATTERN" "$FRAMEWORK_MASTER_TEST_SCRIPT"; then
        log_error "Tests failed"
        return 1
    fi

    log "Tests completed successfully"
    return 0
}

#
# Custom command handler (optional)
#
# REPLACEME: If your framework has custom commands, implement them here
# This is called for any command not in the standard list
#
handle_custom_command() {
    local cmd="$1"

    case "$cmd" in
        # REPLACEME: Add custom commands here
        # "custom-cmd")
        #     log "Executing custom command..."
        #     ;;
        *)
            log_error "Unknown custom command: $cmd"
            return 1
            ;;
    esac
}

# ==============================================================================
# MAIN ENTRY POINT - Handles CLI parsing and command execution
# ==============================================================================

main() {
    # Parse command line arguments using framework-cli
    parse_framework_cli "$@"

    # Get the parsed command
    local command
    command=$(get_framework_command)

    # Display banner
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  ${FRAMEWORK_NAME}${NC}"
    echo -e "${BLUE}  Task: ${FRAMEWORK_TASK}${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""

    # Initialize timestamp for logging
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')

    # Initialize logging using log-utils
    if declare -f init_logging &>/dev/null; then
        export LOG_DIR
        init_logging "$timestamp" "logs" "$(basename "$0" .sh)"
    fi

    log "Starting ${FRAMEWORK_NAME}"
    log "Command: $command"
    log "Test Configuration: $FRAMEWORK_TEST_CONFIG"
    log "Test Scripts Directory: $FRAMEWORK_TEST_SCRIPTS_DIR"
    log "Target VM Pattern: $FRAMEWORK_TARGET_VM_PATTERN"
    echo ""

    # Handle different commands
    case "$command" in
        "help")
            show_framework_help
            exit 0
            ;;

        "status")
            framework_get_cluster_status
            exit $?
            ;;

        "e2e"|"end-to-end")
            log "Starting End-to-End Test"
            if run_framework_e2e_workflow; then
                log_success "End-to-End Test Completed Successfully"
                exit 0
            else
                log_error "End-to-End Test Failed"
                exit 1
            fi
            ;;

        "start-cluster")
            log "Starting cluster..."
            if framework_start_cluster; then
                log_success "Cluster started successfully"
                log "Next steps:"
                log "  1. Deploy Ansible:  \$0 deploy-ansible"
                log "  2. Run tests:       \$0 run-tests"
                log "  3. Stop cluster:    \$0 stop-cluster"
                exit 0
            else
                log_error "Failed to start cluster"
                exit 1
            fi
            ;;

        "stop-cluster")
            log "Stopping cluster..."
            if framework_stop_cluster; then
                log_success "Cluster stopped successfully"
                exit 0
            else
                log_error "Failed to stop cluster"
                exit 1
            fi
            ;;

        "deploy-ansible")
            log "Deploying Ansible..."
            if framework_deploy_ansible "$FRAMEWORK_TARGET_VM_PATTERN"; then
                log_success "Ansible deployment completed"
                log "Next step: \$0 run-tests"
                exit 0
            else
                log_error "Ansible deployment failed"
                exit 1
            fi
            ;;

        "run-tests")
            log "Running tests..."
            if run_framework_specific_tests; then
                log_success "All tests passed"
                exit 0
            else
                log_error "Tests failed"
                exit 1
            fi
            ;;

        "list-tests")
            log "Listing available tests in: $FRAMEWORK_TEST_SCRIPTS_DIR"
            if [[ -d "$FRAMEWORK_TEST_SCRIPTS_DIR" ]]; then
                find "$FRAMEWORK_TEST_SCRIPTS_DIR" -name "*.sh" -type f | sort
                exit 0
            else
                log_error "Test scripts directory not found: $FRAMEWORK_TEST_SCRIPTS_DIR"
                exit 1
            fi
            ;;

        "run-test")
            local test_name="$FRAMEWORK_TEST_TO_RUN"
            if [[ -z "$test_name" ]]; then
                log_error "run-test requires a test name"
                echo "Usage: \$0 run-test <test-name>"
                echo "Use: \$0 list-tests to see available tests"
                exit 1
            fi

            log "Running test: $test_name"
            local test_path="$FRAMEWORK_TEST_SCRIPTS_DIR/$test_name"

            if [[ ! -f "$test_path" ]]; then
                log_error "Test not found: $test_path"
                echo "Use: \$0 list-tests to see available tests"
                exit 1
            fi

            if bash "$test_path"; then
                log_success "Test passed: $test_name"
                exit 0
            else
                log_error "Test failed: $test_name"
                exit 1
            fi
            ;;

        *)
            # Try custom command handler
            if declare -f handle_custom_command &>/dev/null; then
                if handle_custom_command "$command"; then
                    exit 0
                fi
            fi

            log_error "Unknown command: $command"
            echo "Use: \$0 --help for usage information"
            exit 1
            ;;
    esac
}

# ==============================================================================
# EXECUTION - Run main function with all arguments
# ==============================================================================

# Ensure we exit with proper code
main "$@"
exit $?
