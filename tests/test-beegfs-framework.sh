#!/bin/bash
#
# BeeGFS Test Framework
# Task 028 - Deploy BeeGFS Parallel Filesystem
# Test framework for validating BeeGFS deployment across HPC cluster

set -euo pipefail

# Help message
show_help() {
    cat << EOF
BeeGFS Test Framework - Task 028 Validation

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    e2e, end-to-end   Run complete end-to-end test with cleanup (default behavior)
    start-cluster     Start the HPC cluster independently
    stop-cluster      Stop and destroy the HPC cluster
    deploy-ansible    Deploy BeeGFS configuration via Ansible (assumes cluster is running)
    run-tests         Run BeeGFS tests on running cluster
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
    $0 deploy-ansible         # Deploy BeeGFS configuration
    $0 run-tests              # Run tests (can repeat)
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
    Log Directory: logs/beegfs-test-run-*
    VM Pattern: HPC cluster with controller + compute nodes

EOF
}

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Framework configuration
FRAMEWORK_NAME="BeeGFS Test Framework"

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

# Set up environment variables for shared utilities AFTER validation
export PROJECT_ROOT
export TESTS_DIR="$PROJECT_ROOT/tests"
export SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
export SSH_USER="admin"
export CLEANUP_REQUIRED=false
export INTERACTIVE_CLEANUP=false
export TEST_NAME="beegfs"

# shellcheck source=./test-infra/utils/test-framework-utils.sh
source "$UTILS_DIR/test-framework-utils.sh"

# Test configuration
TEST_CONFIG="$PROJECT_ROOT/tests/test-infra/configs/test-beegfs.yaml"
TEST_SCRIPTS_DIR="$PROJECT_ROOT/tests/suites/beegfs"
MASTER_TEST_SCRIPT="run-beegfs-tests.sh"

# Global variables for command line options
INTERACTIVE=false
COMMAND="e2e"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                # VERBOSE flag is handled by the calling script
                shift
                ;;
            --no-cleanup)
                # NO_CLEANUP flag is handled by the calling script
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            e2e|end-to-end|start-cluster|stop-cluster|deploy-ansible|run-tests|status|help)
                COMMAND="$1"
                shift
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
init_logging "$TIMESTAMP" "logs" "beegfs"

# Start HPC cluster using shared utility
start_cluster_beegfs() {
    log "Starting HPC cluster for BeeGFS testing..."

    if [[ ! -f "$TEST_CONFIG" ]]; then
        log_error "Test configuration not found: $TEST_CONFIG"
        return 1
    fi

    log "Using test configuration: $TEST_CONFIG"

    # Use shared utility function from cluster-utils.sh
    # This properly calls: uv run ai-how hpc start
    if ! start_cluster "$TEST_CONFIG"; then
        log_error "Failed to create HPC cluster"
        return 1
    fi

    log "HPC cluster started successfully"
    CLEANUP_REQUIRED=true

    # Wait for cluster VMs to be ready using shared utility
    if ! wait_for_cluster_vms "$TEST_CONFIG" "hpc" 300; then
        log_error "VMs failed to start properly"
        return 1
    fi

    return 0
}

# Stop HPC cluster using shared utility
stop_cluster_beegfs() {
    log "Stopping HPC cluster..."

    if [[ ! -f "$TEST_CONFIG" ]]; then
        log_warn "Test configuration not found: $TEST_CONFIG"
        return 0
    fi

    # Use shared utility function from cluster-utils.sh
    # This properly calls: uv run ai-how hpc destroy
    if ! destroy_cluster "$TEST_CONFIG"; then
        log_error "Failed to destroy HPC cluster"
        return 1
    fi

    log "HPC cluster stopped successfully"
    CLEANUP_REQUIRED=false

    return 0
}

# Deploy BeeGFS via Ansible
deploy_ansible() {
    log "Deploying BeeGFS configuration via Ansible..."

    # Get cluster name from config
    local cluster_name
    if ! cluster_name=$(parse_cluster_name "$TEST_CONFIG" "${LOG_DIR}" "hpc"); then
        log_error "Failed to get cluster name from configuration"
        return 1
    fi

    log "Cluster name: $cluster_name"

    # Generate Ansible inventory using shared utility
    local inventory="$PROJECT_ROOT/build/test-inventory-beegfs.yml"
    if ! generate_ansible_inventory "$inventory" "$cluster_name"; then
        log_error "Failed to generate Ansible inventory"
        return 1
    fi

    # Wait for SSH connectivity on all nodes
    if ! wait_for_inventory_nodes_ssh "$inventory" "all"; then
        log_error "SSH connectivity check failed"
        return 1
    fi

    local playbook="$PROJECT_ROOT/ansible/playbooks/playbook-beegfs-runtime-config.yml"

    if [[ ! -f "$playbook" ]]; then
        log_error "BeeGFS playbook not found: $playbook"
        return 1
    fi

    log "Running BeeGFS deployment playbook..."
    log "Inventory: $inventory"
    log "Playbook: $playbook"

    # Change to ansible directory and run playbook using uv
    cd "$PROJECT_ROOT/ansible" || {
        log_error "Failed to change to ansible directory"
        return 1
    }

    # Run Ansible playbook using uv (consistent with project pattern)
    if ! uv run ansible-playbook -i "$inventory" "$playbook" -v; then
        log_error "Ansible playbook execution failed"
        cd "$PROJECT_ROOT/tests" || true
        return 1
    fi

    cd "$PROJECT_ROOT/tests" || true

    log "BeeGFS deployment completed successfully"

    # Wait for services to stabilize
    log "Waiting for BeeGFS services to stabilize..."
    sleep 20

    return 0
}

# Run BeeGFS tests
run_tests() {
    log "Running BeeGFS test suite..."

    # Get cluster node IPs using shared utility
    log "Retrieving cluster node information using ai-how API..."

    # Use shared utility to get VM IPs from the cluster
    if ! get_vm_ips_for_cluster "$TEST_CONFIG" "hpc"; then
        log_error "Failed to get VM IPs from cluster"
        return 1
    fi

    # VM_IPS and VM_NAMES arrays are now populated by get_vm_ips_for_cluster
    if [[ ${#VM_IPS[@]} -eq 0 ]]; then
        log_error "No VMs found in cluster"
        return 1
    fi

    log "Found ${#VM_IPS[@]} VM(s) in cluster"

    # Separate controller and compute node IPs
    local controller_ip=""
    local compute_ips=()

    for i in "${!VM_IPS[@]}"; do
        local vm_name="${VM_NAMES[$i]}"
        local vm_ip="${VM_IPS[$i]}"

        if [[ "$vm_name" == *"controller"* ]]; then
            controller_ip="$vm_ip"
            log "Controller: $vm_name ($vm_ip)"
        elif [[ "$vm_name" == *"compute"* ]]; then
            compute_ips+=("$vm_ip")
            log "Compute node: $vm_name ($vm_ip)"
        fi
    done

    if [[ -z "$controller_ip" ]]; then
        log_error "No controller VM found in cluster"
        return 1
    fi

    # Run master test script
    local master_test="$TEST_SCRIPTS_DIR/$MASTER_TEST_SCRIPT"

    if [[ ! -f "$master_test" ]]; then
        log_error "Master test script not found: $master_test"
        return 1
    fi

    # Make executable if needed
    if [[ ! -x "$master_test" ]]; then
        chmod +x "$master_test" || {
            log_error "Failed to make test script executable: $master_test"
            return 1
        }
    fi

    log "Executing BeeGFS tests..."

    # Build test arguments
    local test_args=(
        --controller "$controller_ip"
    )

    # Add compute nodes if any
    if [[ ${#compute_ips[@]} -gt 0 ]]; then
        local compute_csv
        compute_csv=$(IFS=,; echo "${compute_ips[*]}")
        test_args+=(--compute "$compute_csv")
        log "Compute nodes: $compute_csv"
    else
        log_warn "No compute nodes found in cluster"
    fi

    # Add verbose flag if enabled
    [[ "${VERBOSE:-false}" == "true" ]] && test_args+=(--verbose)

    # Execute test suite
    if ! "$master_test" "${test_args[@]}"; then
        log_error "BeeGFS tests failed"
        return 1
    fi

    log_success "BeeGFS tests completed successfully"
    return 0
}

# Show cluster status
show_status() {
    log "Checking cluster status..."

    if [[ ! -f "$TEST_CONFIG" ]]; then
        log_error "Test configuration not found: $TEST_CONFIG"
        return 1
    fi

    # Use shared utility function from cluster-utils.sh
    # This properly calls: uv run ai-how hpc status
    if ! show_cluster_status "$TEST_CONFIG"; then
        log_error "Failed to get cluster status"
        return 1
    fi

    return 0
}

# Run end-to-end test
run_end_to_end() {
    log "Starting end-to-end BeeGFS test..."

    local test_failed=false

    # Start cluster
    if ! start_cluster_beegfs; then
        log_error "Failed to start cluster"
        return 1
    fi

    # Deploy BeeGFS
    if ! deploy_ansible; then
        log_error "Failed to deploy BeeGFS"
        test_failed=true
    fi

    # Run tests
    if [[ "$test_failed" == "false" ]]; then
        if ! run_tests; then
            log_error "Tests failed"
            test_failed=true
        fi
    fi

    # Cleanup
    if [[ "${NO_CLEANUP:-false}" == "false" ]]; then
        log "Cleaning up cluster..."
        if ! stop_cluster_beegfs; then
            log_warn "Failed to stop cluster cleanly"
        fi
    else
        log "Skipping cleanup (--no-cleanup specified)"
    fi

    if [[ "$test_failed" == "true" ]]; then
        log_error "End-to-end test failed"
        return 1
    fi

    log "End-to-end test completed successfully"
    return 0
}

# Main function
main() {
    local start_time
    start_time=$(date +%s)

    # Parse arguments
    parse_arguments "$@"

    echo ""
    echo "========================================"
    echo "  $FRAMEWORK_NAME"
    echo "========================================"
    echo ""

    log "Logging initialized: $LOG_DIR"
    log "$FRAMEWORK_NAME Starting"
    log "Working directory: $PROJECT_ROOT"
    log "Task 028 - Deploy BeeGFS Parallel Filesystem"

    # Handle interactive cleanup
    if [[ "$INTERACTIVE" == "true" ]]; then
        INTERACTIVE_CLEANUP=true
    fi

    # Execute command
    case "$COMMAND" in
        e2e|end-to-end)
            local test_result=0
            if ! run_end_to_end; then
                test_result=1
            fi

            local end_time
            end_time=$(date +%s)
            local duration=$((end_time - start_time))

            echo ""
            if [[ $test_result -eq 0 ]]; then
                log_success "End-to-End Test: ALL TESTS PASSED"
                log_success "BeeGFS Test Framework: ALL TESTS PASSED"
                log_success "Task 028 validation completed successfully"
            else
                log_error "End-to-End Test: SOME TESTS FAILED"
                log_error "Check individual test logs in $LOG_DIR"
            fi
            echo ""
            echo "=========================================="
            echo "$FRAMEWORK_NAME completed at: $(date)"
            echo "Exit code: $test_result"
            echo "Total duration: ${duration}s"
            echo "All logs saved to: $LOG_DIR"
            echo "=========================================="

            exit $test_result
            ;;
        start-cluster)
            if start_cluster_beegfs; then
                log_success "Cluster started successfully"
                exit 0
            else
                log_error "Failed to start cluster"
                exit 1
            fi
            ;;
        stop-cluster)
            if stop_cluster_beegfs; then
                log_success "Cluster stopped successfully"
                exit 0
            else
                log_error "Failed to stop cluster"
                exit 1
            fi
            ;;
        deploy-ansible)
            if deploy_ansible; then
                log_success "Ansible deployment completed successfully"
                exit 0
            else
                log_error "Ansible deployment failed"
                exit 1
            fi
            ;;
        run-tests)
            if run_tests; then
                log_success "Tests completed successfully"
                exit 0
            else
                log_error "Tests failed"
                exit 1
            fi
            ;;
        status)
            if show_status; then
                exit 0
            else
                exit 1
            fi
            ;;
        help)
            show_help
            exit 0
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
