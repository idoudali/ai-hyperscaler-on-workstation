#!/bin/bash
# HPC Runtime Test Framework - Consolidates 6 runtime test suites
# Task: TASK-036

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
UTILS_DIR="$TESTS_DIR/test-infra/utils"

export PROJECT_ROOT TESTS_DIR SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa" SSH_USER="admin"

FRAMEWORK_NAME="HPC Runtime Test Framework"
FRAMEWORK_DESCRIPTION="Consolidated runtime validation for SLURM compute nodes and cluster services"
# shellcheck disable=SC2034
FRAMEWORK_TASK="TASK-036"
FRAMEWORK_TEST_CONFIG="$PROJECT_ROOT/config/example-multi-gpu-clusters.yaml"
FRAMEWORK_TEST_SCRIPTS_DIR="$TESTS_DIR/suites/slurm-compute"
FRAMEWORK_TARGET_VM_PATTERN="compute"
# shellcheck disable=SC2034
FRAMEWORK_MASTER_TEST_SCRIPT="run-slurm-compute-tests.sh"
export FRAMEWORK_NAME FRAMEWORK_DESCRIPTION FRAMEWORK_TEST_CONFIG FRAMEWORK_TEST_SCRIPTS_DIR FRAMEWORK_TARGET_VM_PATTERN

# Additional help documentation for suite selection
FRAMEWORK_EXTRA_COMMANDS="    run-tests [SUITE]  Run specific test suite or all suites if not specified"
FRAMEWORK_EXTRA_EXAMPLES="
    # Run all test suites on deployed cluster
    \$0 run-tests

    # Run specific compute node suite (executes ON compute nodes)
    \$0 run-tests slurm-compute
    \$0 run-tests cgroup-isolation
    \$0 run-tests gpu-gres
    \$0 run-tests container-runtime

    # Run specific controller suite (executes FROM controller via SLURM)
    \$0 run-tests container-integration
    \$0 run-tests container-e2e"
export FRAMEWORK_EXTRA_COMMANDS FRAMEWORK_EXTRA_EXAMPLES

# Consolidated test suites - organized by execution context
# NOTE: Tests disabled temporarily (Nov 10, 2025) - see QUICK_FIX_P0_ISSUES.md for re-enabling:
#   - dcgm-monitoring: VERBOSE variable not initialized (line 31)
#   - job-scripts: Epilog template path resolution issue

# COMPUTE NODE SUITES - Run directly ON compute nodes (local execution)
# These test runtime components installed on compute nodes
declare -a COMPUTE_NODE_SUITES=(
    "slurm-compute"          # SLURM daemon on compute node
    "cgroup-isolation"       # cgroup configuration on compute node
    "gpu-gres"              # GPU resources and MIG configuration on compute node
    "container-runtime"      # Apptainer/Singularity installation on compute node
)

# CONTROLLER SUITES - Run FROM controller node (SLURM job submission)
# These test cluster orchestration and job execution
declare -a CONTROLLER_SUITES=(
    "container-integration"  # SLURM + container + GPU integration (via srun/sbatch)
    "container-e2e"         # End-to-end ML workflow validation (via SLURM jobs)
)

# Combined list for validation and iteration
declare -a RUNTIME_TEST_SUITES=(
    "${COMPUTE_NODE_SUITES[@]}"
    "${CONTROLLER_SUITES[@]}"
)

# Source utilities
# shellcheck disable=SC1090
for util in log-utils.sh cluster-utils.sh test-framework-utils.sh framework-cli.sh framework-orchestration.sh; do
    [[ -f "$UTILS_DIR/$util" ]] && source "$UTILS_DIR/$util"
done

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "hpc-runtime"

# Initialize SSH agent for key forwarding
# This allows remote VMs to SSH to other VMs using the forwarded agent
init_ssh_agent() {
    log "Initializing SSH agent for key forwarding..."

    # Start SSH agent if not already running
    if [[ -z "${SSH_AGENT_PID:-}" ]]; then
        eval "$(ssh-agent -s)" > /dev/null
        log "SSH agent started: PID=$SSH_AGENT_PID"
    fi

    # Add SSH key to agent
    if [[ -f "$SSH_KEY_PATH" ]]; then
        ssh-add "$SSH_KEY_PATH" 2>/dev/null || {
            log_warning "Failed to add SSH key to agent: $SSH_KEY_PATH"
            return 1
        }
        log "SSH key added to agent"
    else
        log_warning "SSH key not found: $SSH_KEY_PATH"
        return 1
    fi

    # Export agent variables for child processes
    export SSH_AUTH_SOCK SSH_AGENT_PID
    return 0
}

# Cleanup SSH agent on exit
cleanup_ssh_agent() {
    if [[ -n "${SSH_AGENT_PID:-}" ]]; then
        log_debug "Killing SSH agent: PID=$SSH_AGENT_PID"
        kill "$SSH_AGENT_PID" 2>/dev/null || true
    fi
}

# Initialize SSH agent at startup
init_ssh_agent || log_warning "SSH agent initialization failed, continuing without agent forwarding"

# Register cleanup handler
trap cleanup_ssh_agent EXIT

# Validate that a test suite exists in RUNTIME_TEST_SUITES
validate_test_suite() {
    local suite="$1"
    for valid in "${RUNTIME_TEST_SUITES[@]}"; do
        [[ "$valid" == "$suite" ]] && return 0
    done
    return 1
}

# Determine if a suite should run on compute nodes (true) or controller (false)
is_compute_node_suite() {
    local suite="$1"
    for compute_suite in "${COMPUTE_NODE_SUITES[@]}"; do
        [[ "$compute_suite" == "$suite" ]] && return 0
    done
    return 1
}

# Get controller IP from cluster configuration
get_controller_ip() {
    local config_file="$1"
    local cluster_name="${2:-hpc}"

    if ! get_vm_ips_for_cluster "$config_file" "$cluster_name" "controller"; then
        log_error "Failed to get controller IP from cluster configuration"
        return 1
    fi

    if [[ ${#VM_IPS[@]} -eq 0 ]]; then
        log_error "No controller found in cluster configuration"
        return 1
    fi

    echo "${VM_IPS[0]}"
    return 0
}

# Run all 6 consolidated test suites (with full cluster lifecycle)
run_framework_specific_tests() {
    log "Running ${FRAMEWORK_NAME}..."
    local failed=0 passed=0
    for suite in "${RUNTIME_TEST_SUITES[@]}"; do
        local suite_dir="$TESTS_DIR/suites/$suite"
        [[ ! -d "$suite_dir" ]] && { log_warning "Suite not found: $suite"; ((failed++)); continue; }
        log ""; log "Running: $suite"
        if run_test_framework "$TESTS_DIR/test-infra/configs/test-${suite}.yaml" "$suite_dir" "$FRAMEWORK_TARGET_VM_PATTERN" "run-${suite}-tests.sh" 2>&1; then
            ((passed+=1))
        else
            ((failed+=1))
        fi
    done
    log ""; log "Summary: $passed passed, $failed failed"
    [[ $failed -eq 0 ]]
}

# Run tests on already-deployed cluster (skip cluster startup)
# Tests are dispatched based on execution context:
#   - COMPUTE NODE SUITES: Run ON each compute node (direct execution)
#   - CONTROLLER SUITES: Run FROM controller (SLURM job submission)
# Optional parameter: specific test suite name
run_tests_on_deployed_cluster() {
    local requested_suite="${1:-}"
    local test_suites=()

    # Filter to specific suite if requested
    if [[ -n "$requested_suite" ]]; then
        if ! validate_test_suite "$requested_suite"; then
            log_error "Invalid test suite: $requested_suite"
            log_error "Valid suites: ${RUNTIME_TEST_SUITES[*]}"
            return 1
        fi
        test_suites=("$requested_suite")
        log "Running specific test suite: $requested_suite"
    else
        test_suites=("${RUNTIME_TEST_SUITES[@]}")
    fi

    log "Running tests on already-deployed cluster..."
    log "Execution strategy:"
    log "  - Compute node suites: Run ON each compute node directly"
    log "  - Controller suites: Run FROM controller via SLURM"
    log ""

    # Ensure containers are deployed before running container suites
    if [[ " ${test_suites[*]} " =~ " container-integration " ]] || \
       [[ " ${test_suites[*]} " =~ " container-e2e " ]] || \
       [[ " ${test_suites[*]} " =~ " container-runtime " ]]; then
        log "Container suites require deployed containers"
        log "Running: make containers-deploy-beegfs"
        if make -C "$PROJECT_ROOT" containers-deploy-beegfs 2>&1; then
            log_success "Container deployment completed"
        else
            log_warning "Container deployment may have issues, attempting to continue..."
        fi
        log ""
    fi

    local failed=0 passed=0

    # Separate suites by execution context
    local -a compute_suites_to_run=()
    local -a controller_suites_to_run=()

    for suite in "${test_suites[@]}"; do
        if is_compute_node_suite "$suite"; then
            compute_suites_to_run+=("$suite")
        else
            controller_suites_to_run+=("$suite")
        fi
    done

    # Run compute node suites ON compute nodes
    if [[ ${#compute_suites_to_run[@]} -gt 0 ]]; then
        log "═══════════════════════════════════════════════════════════"
        log "Running COMPUTE NODE suites (execute ON compute nodes)"
        log "═══════════════════════════════════════════════════════════"
        log ""

        # Get compute node IPs
        if ! get_vm_ips_for_cluster "$FRAMEWORK_TEST_CONFIG" "hpc" "compute"; then
            log_error "Failed to get compute node IPs"
            return 1
        fi

        for suite in "${compute_suites_to_run[@]}"; do
            local suite_dir="$TESTS_DIR/suites/$suite"
            [[ ! -d "$suite_dir" ]] && { log_warning "Suite not found: $suite"; ((failed++)); continue; }

            log "Running: $suite (on compute nodes)"
            local master_script="run-${suite}-tests.sh"
            local suite_failed=0

            # Run on each compute node
            for i in "${!VM_IPS[@]}"; do
                local vm_ip="${VM_IPS[$i]}"
                local vm_name="${VM_NAMES[$i]}"

                log "  Testing on compute node: $vm_name ($vm_ip)"

                if ! wait_for_vm_ssh "$vm_ip" "$vm_name"; then
                    log_error "  SSH connectivity failed"
                    suite_failed=1
                    continue
                fi

                # Calculate intended remote directory (maintain project structure)
                local project_basename
                project_basename="$(basename "$PROJECT_ROOT")"
                local suite_relative
                suite_relative="tests/suites/$suite"
                # shellcheck disable=SC2088
                local intended_remote_dir="~/$project_basename/$suite_relative"

                # Upload test scripts (will fallback to /tmp if permissions fail)
                if ! upload_scripts_to_vm "$vm_ip" "$vm_name" "$TESTS_DIR/suites/$suite" "$intended_remote_dir"; then
                    log_error "  Failed to upload test scripts"
                    suite_failed=1
                    continue
                fi

                # Get actual directory used (might be /tmp fallback)
                local actual_suite_dir="$ACTUAL_REMOTE_DIR"
                log "  Scripts uploaded to: $actual_suite_dir"

                # Run tests - execute script in actual directory
                if ! execute_script_on_vm "$vm_ip" "$vm_name" "$master_script" "$actual_suite_dir"; then
                    log_warning "  Test failed on $vm_name"
                    suite_failed=1
                fi
            done

            if [[ $suite_failed -eq 0 ]]; then
                log_success "Suite passed: $suite"
                ((passed+=1))
            else
                log_warning "Suite failed: $suite"
                ((failed+=1))
            fi
            log ""
        done
    fi

    # Run controller suites FROM controller
    if [[ ${#controller_suites_to_run[@]} -gt 0 ]]; then
        log "═══════════════════════════════════════════════════════════"
        log "Running CONTROLLER suites (execute FROM controller via SLURM)"
        log "═══════════════════════════════════════════════════════════"
        log ""

        # Get controller IP
        local controller_ip
        if ! controller_ip=$(get_controller_ip "$FRAMEWORK_TEST_CONFIG" "hpc"); then
            log_error "Failed to get controller IP"
            return 1
        fi

        log "Controller IP: $controller_ip"
        log ""

        if ! wait_for_vm_ssh "$controller_ip" "controller"; then
            log_error "SSH connectivity failed to controller"
            return 1
        fi

        for suite in "${controller_suites_to_run[@]}"; do
            local suite_dir="$TESTS_DIR/suites/$suite"
            [[ ! -d "$suite_dir" ]] && { log_warning "Suite not found: $suite"; ((failed++)); continue; }

            log "Running: $suite (from controller)"
            local master_script="run-${suite}-tests.sh"

            # Calculate intended remote directory (maintain project structure)
            local project_basename
            project_basename="$(basename "$PROJECT_ROOT")"
            local suite_relative
            suite_relative="tests/suites/$suite"
            # shellcheck disable=SC2088
            local intended_remote_dir="~/$project_basename/$suite_relative"

            # Upload test scripts to controller (will fallback to /tmp if permissions fail)
            if ! upload_scripts_to_vm "$controller_ip" "controller" "$TESTS_DIR/suites/$suite" "$intended_remote_dir"; then
                log_error "  Failed to upload test scripts to controller"
                ((failed+=1))
                continue
            fi

            # Get actual directory used (might be /tmp fallback)
            local actual_suite_dir="$ACTUAL_REMOTE_DIR"
            log "  Scripts uploaded to: $actual_suite_dir"

            # Execute test FROM controller (tests will submit SLURM jobs)
            if execute_script_on_vm "$controller_ip" "controller" "$master_script" "$actual_suite_dir"; then
                log_success "Suite passed: $suite"
                ((passed+=1))
            else
                log_warning "Suite failed: $suite"
                ((failed+=1))
            fi
            log ""
        done
    fi

    log "═══════════════════════════════════════════════════════════"
    log "Test Summary"
    log "═══════════════════════════════════════════════════════════"
    log "Compute node suites: ${#compute_suites_to_run[@]}"
    log "Controller suites: ${#controller_suites_to_run[@]}"
    log "Passed: $passed"
    log "Failed: $failed"
    log ""

    [[ $failed -eq 0 ]]
}

# Extract suite name if provided after "run-tests" command
# This function finds "run-tests" in the original arguments and returns the next non-option argument
get_requested_suite_name() {
    local cmd_found=false
    for arg in "$@"; do
        if [[ "$cmd_found" == "true" ]]; then
            # Skip options (start with -)
            if [[ "$arg" != -* ]]; then
                echo "$arg"
                return 0
            fi
        fi
        if [[ "$arg" == "run-tests" ]]; then
            cmd_found=true
        fi
    done
}

# Main
parse_framework_cli "$@"
COMMAND=$(get_framework_command)

# Get the requested suite name if running "run-tests" command
REQUESTED_SUITE=""
if [[ "$COMMAND" == "run-tests" ]]; then
    REQUESTED_SUITE=$(get_requested_suite_name "$@")
fi

case "$COMMAND" in
    "e2e"|"end-to-end") run_framework_e2e_workflow ;;
    "start-cluster") framework_start_cluster ;;
    "stop-cluster") framework_stop_cluster ;;
    "deploy-ansible") framework_deploy_ansible "$FRAMEWORK_TARGET_VM_PATTERN" ;;
    "run-tests") run_tests_on_deployed_cluster "$REQUESTED_SUITE" ;;
    "run-tests-e2e") run_framework_specific_tests ;;
    "status") framework_get_cluster_status ;;
    "list-tests") find "$TESTS_DIR/suites" -name "*.sh" | head -20 ;;
    "help"|"--help") show_framework_help ;;
    *) run_framework_e2e_workflow ;;
esac
