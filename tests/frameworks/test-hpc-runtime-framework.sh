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

# Consolidated test suites (6 total)
declare -a RUNTIME_TEST_SUITES=("slurm-compute" "cgroup-isolation" "gpu-gres" "job-scripts" "dcgm-monitoring" "container-integration")

# Source utilities
# shellcheck disable=SC1090
for util in log-utils.sh cluster-utils.sh test-framework-utils.sh framework-cli.sh framework-orchestration.sh; do
    [[ -f "$UTILS_DIR/$util" ]] && source "$UTILS_DIR/$util"
done

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "hpc-runtime"

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
# Tests are dispatched to remote VMs via SSH using the test framework
run_tests_on_deployed_cluster() {
    log "Running tests on already-deployed cluster..."
    log "Note: Tests are dispatched to remote VMs (controller or compute nodes)"
    log ""

    # Ensure containers are deployed before running integration tests
    # This is a dependency for the container-integration test suite
    if [[ " ${RUNTIME_TEST_SUITES[*]} " =~ " container-integration " ]]; then
        log ""; log "Container Integration tests require deployed containers"
        log "Running: make containers-deploy-beegfs"
        if make -C "$PROJECT_ROOT" containers-deploy-beegfs 2>&1; then
            log_success "Container deployment completed"
        else
            log_warning "Container deployment may have issues, attempting to continue..."
        fi
    fi
    log ""

    # Get VM IPs from cluster configuration (does not start/stop VMs)
    if ! get_vm_ips_for_cluster "$FRAMEWORK_TEST_CONFIG" "hpc" "$FRAMEWORK_TARGET_VM_PATTERN"; then
        log_error "Failed to get VM IP addresses from cluster configuration"
        return 1
    fi

    local failed=0 passed=0
    for suite in "${RUNTIME_TEST_SUITES[@]}"; do
        local suite_dir="$TESTS_DIR/suites/$suite"
        [[ ! -d "$suite_dir" ]] && { log_warning "Suite not found: $suite"; ((failed++)); continue; }
        log ""; log "Running: $suite"

        # Determine master test script name for this suite
        local master_script="run-${suite}-tests.sh"

        # Run tests on each VM matching the pattern
        local suite_failed=0
        for i in "${!VM_IPS[@]}"; do
            local vm_ip="${VM_IPS[$i]}"
            local vm_name="${VM_NAMES[$i]}"

            log "  Testing on $vm_name ($vm_ip)..."

            # Wait for SSH connectivity
            if ! wait_for_vm_ssh "$vm_ip" "$vm_name"; then
                log_error "SSH connectivity failed for $vm_name"
                suite_failed=1
                continue
            fi

            # Check if project directory exists on VM (shared filesystem mount)
            local project_exists=false
            if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" \
                "$SSH_USER@$vm_ip" "test -d '$PROJECT_ROOT'" 2>/dev/null; then
                project_exists=true
                log "  Project directory exists on VM at: $PROJECT_ROOT"
            else
                log "  Project directory not found on VM, will upload scripts"
            fi

            # Execute tests: use shared mount if available, otherwise upload scripts
            if [[ "$project_exists" == "true" ]]; then
                # Execute directly from shared filesystem
                log "  Executing from shared filesystem..."
                if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" \
                    "$SSH_USER@$vm_ip" "cd '$PROJECT_ROOT' && bash tests/suites/$suite/$master_script" 2>&1; then
                    log_warning "Test failed on $vm_name"
                    suite_failed=1
                fi
            else
                # Upload and execute approach
                log "  Using upload and execute approach..."

                # Calculate intended remote directory (maintain project structure)
                local project_basename
                project_basename="$(basename "$PROJECT_ROOT")"
                local suite_relative
                suite_relative="${suite_dir#"$PROJECT_ROOT"/}"
                # shellcheck disable=SC2088
                local intended_remote_dir="~/$project_basename/$suite_relative"

                # Upload test scripts (will fallback to /tmp if permissions fail)
                if ! upload_scripts_to_vm "$vm_ip" "$vm_name" "$suite_dir" "$intended_remote_dir"; then
                    log_error "Failed to upload test scripts to $vm_name"
                    suite_failed=1
                    continue
                fi

                # Get actual directory used (might be /tmp fallback)
                local actual_suite_dir="$ACTUAL_REMOTE_DIR"
                log "  Scripts uploaded to: $actual_suite_dir"

                # Execute test script on VM
                local script_basename
                script_basename=$(basename "$master_script")
                if ! execute_script_on_vm "$vm_ip" "$vm_name" "$script_basename" "$actual_suite_dir"; then
                    log_warning "Test failed on $vm_name"
                    suite_failed=1
                fi
            fi
        done

        if [[ $suite_failed -eq 0 ]]; then
            log_success "Suite passed: $suite"
            ((passed+=1))
        else
            log_warning "Suite failed: $suite"
            ((failed+=1))
        fi
    done
    log ""; log "Summary: $passed passed, $failed failed"
    [[ $failed -eq 0 ]]
}

# Main
parse_framework_cli "$@"
COMMAND=$(get_framework_command)

case "$COMMAND" in
    "e2e"|"end-to-end") run_framework_e2e_workflow ;;
    "start-cluster") framework_start_cluster ;;
    "stop-cluster") framework_stop_cluster ;;
    "deploy-ansible") framework_deploy_ansible "$FRAMEWORK_TARGET_VM_PATTERN" ;;
    "run-tests") run_tests_on_deployed_cluster ;;
    "run-tests-e2e") run_framework_specific_tests ;;
    "status") framework_get_cluster_status ;;
    "list-tests") find "$TESTS_DIR/suites" -name "*.sh" | head -20 ;;
    "help"|"--help") show_framework_help ;;
    *) run_framework_e2e_workflow ;;
esac
