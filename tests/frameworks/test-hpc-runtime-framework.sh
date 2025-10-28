#!/bin/bash
# HPC Runtime Test Framework - Consolidates 6 runtime test suites
# Task: TASK-036

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$PROJECT_ROOT/tests"
UTILS_DIR="$TESTS_DIR/test-infra/utils"

export PROJECT_ROOT TESTS_DIR SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa" SSH_USER="admin"

FRAMEWORK_NAME="HPC Runtime Test Framework"
FRAMEWORK_DESCRIPTION="Consolidated runtime validation for SLURM compute nodes and cluster services"
# shellcheck disable=SC2034
FRAMEWORK_TASK="TASK-036"
FRAMEWORK_TEST_CONFIG="$TESTS_DIR/test-infra/configs/test-slurm-compute.yaml"
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

# Run all 6 consolidated test suites
run_framework_specific_tests() {
    log "Running ${FRAMEWORK_NAME}..."
    local failed=0 passed=0
    for suite in "${RUNTIME_TEST_SUITES[@]}"; do
        local suite_dir="$TESTS_DIR/suites/$suite"
        [[ ! -d "$suite_dir" ]] && { log_warning "Suite not found: $suite"; ((failed++)); continue; }
        log ""; log "Running: $suite"
        if run_test_framework "$TESTS_DIR/test-infra/configs/test-${suite}.yaml" "$suite_dir" "$FRAMEWORK_TARGET_VM_PATTERN" "run-${suite}-tests.sh" 2>&1; then
            ((passed++))
        else
            ((failed++))
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
    "run-tests") run_framework_specific_tests ;;
    "status") framework_get_cluster_status ;;
    "list-tests") find "$TESTS_DIR/suites" -name "*.sh" | head -20 ;;
    "help"|"--help") show_framework_help ;;
    *) run_framework_e2e_workflow ;;
esac
