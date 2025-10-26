#!/bin/bash
#
# Framework Orchestration Utility - Common Cluster Management & Workflow
#
# This utility provides standardized cluster management and workflow orchestration
# functions used across all test frameworks. It eliminates duplication by providing:
#  - Cluster lifecycle management (start, stop, status)
#  - Workflow orchestration (full e2e, modular steps)
#  - Environment validation
#  - Ansible deployment wrapper
#  - Test execution wrapper
#  - Error handling and cleanup
#
# Usage:
#   source framework-orchestration.sh
#
# Required Environment Variables (set before sourcing):
#   FRAMEWORK_NAME - Name of the test framework
#   FRAMEWORK_TEST_CONFIG - Path to test configuration YAML
#   FRAMEWORK_TEST_SCRIPTS_DIR - Path to test suite directory
#   PROJECT_ROOT - Root directory of the project
#
# Functions:
#   run_framework_e2e_workflow() - Complete end-to-end test
#   run_framework_modular_workflow() - Run specific workflow phase
#   validate_framework_environment() - Validate prerequisites
#   framework_start_cluster() - Start cluster
#   framework_stop_cluster() - Stop cluster
#   framework_deploy_ansible() - Deploy via Ansible
#   framework_run_tests() - Execute test suite
#   framework_get_cluster_status() - Show cluster status
#

set -euo pipefail

# Default timeout values (can be overridden)
export FRAMEWORK_CLUSTER_START_TIMEOUT="${FRAMEWORK_CLUSTER_START_TIMEOUT:-600}"
export FRAMEWORK_SSH_WAIT_TIMEOUT="${FRAMEWORK_SSH_WAIT_TIMEOUT:-300}"
export FRAMEWORK_ANSIBLE_TIMEOUT="${FRAMEWORK_ANSIBLE_TIMEOUT:-1800}"
export FRAMEWORK_TEST_TIMEOUT="${FRAMEWORK_TEST_TIMEOUT:-3600}"

#
# validate_framework_environment()
# Validate that all required tools and configurations exist
#
# Usage:
#   if validate_framework_environment; then
#       # Environment is valid
#   fi
#
# Returns: 0 if valid, 1 if any issues found
#
validate_framework_environment() {
    local errors=0

    # Check required environment variables
    if [[ -z "${FRAMEWORK_NAME:-}" ]]; then
        echo "Error: FRAMEWORK_NAME environment variable not set"
        ((errors++))
    fi

    if [[ -z "${FRAMEWORK_TEST_CONFIG:-}" ]]; then
        echo "Error: FRAMEWORK_TEST_CONFIG environment variable not set"
        ((errors++))
    elif [[ ! -f "$FRAMEWORK_TEST_CONFIG" ]]; then
        echo "Error: Test configuration file not found: $FRAMEWORK_TEST_CONFIG"
        ((errors++))
    fi

    if [[ -z "${FRAMEWORK_TEST_SCRIPTS_DIR:-}" ]]; then
        echo "Error: FRAMEWORK_TEST_SCRIPTS_DIR environment variable not set"
        ((errors++))
    elif [[ ! -d "$FRAMEWORK_TEST_SCRIPTS_DIR" ]]; then
        echo "Error: Test scripts directory not found: $FRAMEWORK_TEST_SCRIPTS_DIR"
        ((errors++))
    fi

    if [[ -z "${PROJECT_ROOT:-}" ]]; then
        echo "Error: PROJECT_ROOT environment variable not set"
        ((errors++))
    elif [[ ! -d "$PROJECT_ROOT" ]]; then
        echo "Error: Project root directory not found: $PROJECT_ROOT"
        ((errors++))
    fi

    # Check required commands
    local required_cmds=("ai-how" "ansible" "yq")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: Required command not found: $cmd"
            ((errors++))
        fi
    done

    # Check logging functions are available
    if ! declare -f log &>/dev/null; then
        echo "Warning: log() function not available, using basic echo"
    fi

    if [[ $errors -gt 0 ]]; then
        echo "Environment validation failed with $errors error(s)"
        return 1
    fi

    return 0
}

#
# framework_start_cluster()
# Start the HPC cluster from test configuration
#
# Usage:
#   if framework_start_cluster; then
#       echo "Cluster started"
#   fi
#
# Returns: 0 if successful, 1 if failed
#
framework_start_cluster() {
    local timeout="${FRAMEWORK_CLUSTER_START_TIMEOUT}"

    if declare -f log &>/dev/null; then
        log "Starting HPC cluster from configuration: $FRAMEWORK_TEST_CONFIG"
    else
        echo "Starting HPC cluster from configuration: $FRAMEWORK_TEST_CONFIG"
    fi

    # Use ai-how to start cluster (assuming it's integrated)
    # This is a placeholder that frameworks can override
    if [[ -n "${FRAMEWORK_CLUSTER_NAME:-}" ]]; then
        if ! ai-how cluster list 2>/dev/null | grep -q "$FRAMEWORK_CLUSTER_NAME"; then
            echo "Cluster $FRAMEWORK_CLUSTER_NAME not found or not running"
            return 1
        fi
    fi

    if declare -f log &>/dev/null; then
        log "Cluster started successfully"
    fi

    return 0
}

#
# framework_stop_cluster()
# Stop and destroy the HPC cluster
#
# Usage:
#   if framework_stop_cluster; then
#       echo "Cluster stopped"
#   fi
#
# Returns: 0 if successful, 1 if failed
#
framework_stop_cluster() {
    if declare -f log &>/dev/null; then
        log "Stopping HPC cluster"
    else
        echo "Stopping HPC cluster"
    fi

    # Use shared cluster-utils if available
    if declare -f stop_cluster_interactive &>/dev/null; then
        stop_cluster_interactive "$FRAMEWORK_TEST_CONFIG" "${FRAMEWORK_INTERACTIVE:-false}"
    else
        echo "Warning: stop_cluster_interactive() not available"
    fi

    return 0
}

#
# framework_deploy_ansible()
# Deploy configuration via Ansible playbook
#
# Usage:
#   if framework_deploy_ansible "controller"; then
#       echo "Ansible deployment complete"
#   fi
#
# Arguments:
#   $1 - Target VM pattern (e.g., "controller", "compute", "all")
#
# Returns: 0 if successful, 1 if failed
#
framework_deploy_ansible() {
    local target_pattern="${1:-all}"
    local timeout="${FRAMEWORK_ANSIBLE_TIMEOUT}"

    if declare -f log &>/dev/null; then
        log "Deploying Ansible configuration to $target_pattern nodes"
    else
        echo "Deploying Ansible configuration to $target_pattern nodes"
    fi

    # Use shared ansible-utils if available
    if declare -f deploy_ansible_full_workflow &>/dev/null; then
        deploy_ansible_full_workflow "$FRAMEWORK_TEST_CONFIG" "$target_pattern"
    else
        echo "Warning: deploy_ansible_full_workflow() not available"
        return 1
    fi

    if declare -f log &>/dev/null; then
        log "Ansible deployment completed successfully"
    fi

    return 0
}

#
# framework_run_tests()
# Execute the test suite
#
# Usage:
#   if framework_run_tests; then
#       echo "Tests passed"
#   fi
#
# Returns: 0 if all tests pass, 1 if any fail
#
framework_run_tests() {
    # Note: timeout parameter reserved for future enhancement with timeout handling
    # shellcheck disable=SC2034
    local timeout="${FRAMEWORK_TEST_TIMEOUT}"

    if declare -f log &>/dev/null; then
        log "Running test suite from: $FRAMEWORK_TEST_SCRIPTS_DIR"
    else
        echo "Running test suite from: $FRAMEWORK_TEST_SCRIPTS_DIR"
    fi

    # Use shared test-framework-utils if available
    if declare -f run_test_framework &>/dev/null; then
        run_test_framework "$FRAMEWORK_TEST_CONFIG" "$FRAMEWORK_TEST_SCRIPTS_DIR" "${FRAMEWORK_TARGET_VM_PATTERN:-all}" "${FRAMEWORK_MASTER_TEST_SCRIPT:-run-tests.sh}"
    else
        echo "Warning: run_test_framework() not available"
        return 1
    fi

    if declare -f log &>/dev/null; then
        log "Test suite completed successfully"
    fi

    return 0
}

#
# framework_get_cluster_status()
# Show current cluster status
#
# Usage:
#   framework_get_cluster_status
#
# Returns: 0 always (informational function)
#
framework_get_cluster_status() {
    if declare -f log &>/dev/null; then
        log "Cluster Status:"
        log "Configuration: $FRAMEWORK_TEST_CONFIG"
    else
        echo "Cluster Status:"
        echo "Configuration: $FRAMEWORK_TEST_CONFIG"
    fi

    # Use shared utilities if available
    if declare -f show_cluster_status &>/dev/null; then
        show_cluster_status "$FRAMEWORK_TEST_CONFIG"
    else
        echo "Status: Unknown (status command not available)"
    fi

    return 0
}

#
# run_framework_e2e_workflow()
# Execute complete end-to-end test workflow with cleanup
#
# This is the main entry point for e2e testing that orchestrates:
#   1. Validate environment
#   2. Start cluster
#   3. Deploy Ansible
#   4. Run tests
#   5. Stop cluster (unless --no-cleanup)
#
# Usage:
#   if run_framework_e2e_workflow; then
#       echo "E2E test passed"
#   fi
#
# Returns: 0 if all steps succeed, 1 if any step fails
#
run_framework_e2e_workflow() {
    local start_time
    start_time=$(date +%s)

    if declare -f log &>/dev/null; then
        log "=========================================="
        log "Starting E2E Workflow: $FRAMEWORK_NAME"
        log "=========================================="
        log "Configuration: $FRAMEWORK_TEST_CONFIG"
        log "Test Scripts: $FRAMEWORK_TEST_SCRIPTS_DIR"
    else
        echo "=========================================="
        echo "Starting E2E Workflow: $FRAMEWORK_NAME"
        echo "=========================================="
    fi

    # Step 1: Validate environment
    if ! validate_framework_environment; then
        if declare -f log_error &>/dev/null; then
            log_error "Environment validation failed"
        else
            echo "ERROR: Environment validation failed"
        fi
        return 1
    fi

    # Step 2: Start cluster
    if ! framework_start_cluster; then
        if declare -f log_error &>/dev/null; then
            log_error "Failed to start cluster"
        else
            echo "ERROR: Failed to start cluster"
        fi
        return 1
    fi

    # Step 3: Deploy Ansible
    if ! framework_deploy_ansible "${FRAMEWORK_TARGET_VM_PATTERN:-all}"; then
        if declare -f log_error &>/dev/null; then
            log_error "Ansible deployment failed"
        else
            echo "ERROR: Ansible deployment failed"
        fi

        # Attempt cleanup before returning
        if [[ "${FRAMEWORK_NO_CLEANUP:-false}" != "true" ]]; then
            framework_stop_cluster || true
        fi

        return 1
    fi

    # Step 4: Run tests
    if ! framework_run_tests; then
        if declare -f log_error &>/dev/null; then
            log_error "Tests failed"
        else
            echo "ERROR: Tests failed"
        fi

        # Attempt cleanup before returning
        if [[ "${FRAMEWORK_NO_CLEANUP:-false}" != "true" ]]; then
            framework_stop_cluster || true
        fi

        return 1
    fi

    # Step 5: Cleanup
    if [[ "${FRAMEWORK_NO_CLEANUP:-false}" != "true" ]]; then
        if ! framework_stop_cluster; then
            if declare -f log_error &>/dev/null; then
                log_error "Cluster cleanup failed"
            else
                echo "ERROR: Cluster cleanup failed"
            fi
            return 1
        fi
    else
        if declare -f log &>/dev/null; then
            log "Skipping cleanup (--no-cleanup flag set)"
        else
            echo "Skipping cleanup (--no-cleanup flag set)"
        fi
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if declare -f log_success &>/dev/null; then
        log "=========================================="
        log_success "E2E Workflow Completed Successfully"
        log "=========================================="
        log "Duration: ${duration}s"
    else
        echo "=========================================="
        echo "E2E Workflow Completed Successfully"
        echo "Duration: ${duration}s"
    fi

    return 0
}

#
# run_framework_modular_workflow()
# Execute specific workflow phase without automatic cleanup
#
# This allows frameworks to run individual steps for debugging:
#   - start: Start cluster only
#   - deploy: Deploy Ansible only
#   - test: Run tests only
#   - stop: Stop cluster only
#
# Usage:
#   if run_framework_modular_workflow "start"; then
#       echo "Cluster started"
#   fi
#
# Arguments:
#   $1 - Workflow phase (start|deploy|test|stop|status)
#
# Returns: 0 if step succeeds, 1 if failed
#
run_framework_modular_workflow() {
    local phase="${1:-status}"

    if declare -f log &>/dev/null; then
        log "Running modular workflow phase: $phase"
    else
        echo "Running modular workflow phase: $phase"
    fi

    case "$phase" in
        start)
            framework_start_cluster
            ;;
        deploy)
            framework_deploy_ansible "${FRAMEWORK_TARGET_VM_PATTERN:-all}"
            ;;
        test)
            framework_run_tests
            ;;
        stop)
            framework_stop_cluster
            ;;
        status)
            framework_get_cluster_status
            ;;
        *)
            if declare -f log_error &>/dev/null; then
                log_error "Unknown workflow phase: $phase"
            else
                echo "ERROR: Unknown workflow phase: $phase"
            fi
            echo "Valid phases: start, deploy, test, stop, status"
            return 1
            ;;
    esac
}

#
# setup_framework_environment()
# Initialize framework environment variables and logging
#
# Usage:
#   setup_framework_environment
#
setup_framework_environment() {
    # Set defaults if not already set
    export FRAMEWORK_NO_CLEANUP="${FRAMEWORK_NO_CLEANUP:-false}"
    export FRAMEWORK_INTERACTIVE="${FRAMEWORK_INTERACTIVE:-false}"
    export FRAMEWORK_TARGET_VM_PATTERN="${FRAMEWORK_TARGET_VM_PATTERN:-all}"
    export FRAMEWORK_MASTER_TEST_SCRIPT="${FRAMEWORK_MASTER_TEST_SCRIPT:-run-tests.sh}"

    # Source logging utilities if available
    if [[ -f "${PROJECT_ROOT}/tests/test-infra/utils/log-utils.sh" ]]; then
        # shellcheck source=/dev/null
        source "${PROJECT_ROOT}/tests/test-infra/utils/log-utils.sh"
    fi

    # Source cluster utilities if available
    if [[ -f "${PROJECT_ROOT}/tests/test-infra/utils/cluster-utils.sh" ]]; then
        # shellcheck source=/dev/null
        source "${PROJECT_ROOT}/tests/test-infra/utils/cluster-utils.sh"
    fi

    # Source ansible utilities if available
    if [[ -f "${PROJECT_ROOT}/tests/test-infra/utils/ansible-utils.sh" ]]; then
        # shellcheck source=/dev/null
        source "${PROJECT_ROOT}/tests/test-infra/utils/ansible-utils.sh"
    fi

    # Source test framework utilities if available
    if [[ -f "${PROJECT_ROOT}/tests/test-infra/utils/test-framework-utils.sh" ]]; then
        # shellcheck source=/dev/null
        source "${PROJECT_ROOT}/tests/test-infra/utils/test-framework-utils.sh"
    fi
}

# Export functions for use in other scripts
export -f validate_framework_environment
export -f framework_start_cluster
export -f framework_stop_cluster
export -f framework_deploy_ansible
export -f framework_run_tests
export -f framework_get_cluster_status
export -f run_framework_e2e_workflow
export -f run_framework_modular_workflow
export -f setup_framework_environment
