#!/bin/bash
# HPC Packer Unified SLURM Test Framework - Validates SLURM across controller and compute nodes
# Task: TASK-036
# This unified framework tests SLURM deployment using the multi-GPU cluster configuration

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TESTS_DIR="$PROJECT_ROOT/tests"
UTILS_DIR="$TESTS_DIR/test-infra/utils"

export PROJECT_ROOT TESTS_DIR SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa" SSH_USER="admin"

FRAMEWORK_NAME="HPC Packer Unified SLURM Test Framework"
FRAMEWORK_DESCRIPTION="Consolidated SLURM validation across controller and compute nodes with BeeGFS shared storage"
# shellcheck disable=SC2034
FRAMEWORK_TASK="TASK-036"
FRAMEWORK_TEST_CONFIG="$PROJECT_ROOT/config/example-multi-gpu-clusters.yaml"
FRAMEWORK_TEST_SCRIPTS_DIR="$TESTS_DIR/suites"
# Default to full mode (test both controller and compute)
FRAMEWORK_TARGET_VM_PATTERN="${TARGET_VM_PATTERN:-controller|compute}"
# shellcheck disable=SC2034
FRAMEWORK_MASTER_TEST_SCRIPT="run-unified-slurm-tests.sh"
export FRAMEWORK_NAME FRAMEWORK_DESCRIPTION FRAMEWORK_TEST_CONFIG FRAMEWORK_TEST_SCRIPTS_DIR

# Export logging configuration
export FRAMEWORK_LOG_LEVEL="info"  # Will be set from CLI option

# Test suites configuration - organized by component
declare -a CONTROLLER_TEST_SUITES=("slurm-controller" "monitoring-stack" "grafana" "slurm-accounting")
declare -a COMPUTE_TEST_SUITES=("container-runtime")
declare -a JOB_EXAMPLE_TEST_SUITES=("slurm-job-examples")

# Source utilities
# shellcheck disable=SC1090
for util in log-utils.sh cluster-utils.sh test-framework-utils.sh framework-cli.sh framework-orchestration.sh; do
    [[ -f "$UTILS_DIR/$util" ]] && source "$UTILS_DIR/$util"
done

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "hpc-slurm-unified"

# Test mode tracking
TEST_MODE="full"  # controller, compute, examples, or full
LOG_LEVEL="info"  # debug, info, warning, error

# Apply logging level configuration
apply_log_level() {
    local level="$1"
    case "$level" in
        debug)
            export DEBUG_SUITE_PATHS=1
            log_info "Log level set to: DEBUG (all diagnostic messages enabled)"
            ;;
        info)
            export DEBUG_SUITE_PATHS=0
            log_info "Log level set to: INFO (normal output)"
            ;;
        warning)
            export DEBUG_SUITE_PATHS=0
            # INFO level will still show, just not DEBUG
            log_info "Log level set to: WARNING (minimized output, warnings and errors only)"
            ;;
        error)
            export DEBUG_SUITE_PATHS=0
            log_info "Log level set to: ERROR (only error messages)"
            ;;
        *)
            log_error "Unknown log level: $level (valid options: debug, info, warning, error)"
            return 1
            ;;
    esac
    export FRAMEWORK_LOG_LEVEL="$level"
}

# Parse framework options from CLI arguments
parse_slurm_mode() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_framework_help
                exit 0
                ;;
            --mode)
                TEST_MODE="$2"
                shift 2
                ;;
            --log-level)
                LOG_LEVEL="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
}

# Run tests against an existing (already deployed) cluster
# This function assumes the cluster is already running and just dispatches test suites
run_tests_against_existing_cluster() {
    local test_config="$1"
    local test_scripts_dir="$2"
    local target_pattern="$3"
    local master_script="$4"

    log "Running tests against existing cluster (no cluster management)"
    log "Configuration: $test_config"
    log "Test Scripts: $test_scripts_dir"
    log "Target VM Pattern: $target_pattern"

    # Get VM IPs from existing cluster
    if ! get_vm_ips_for_cluster "$test_config" "hpc" "$target_pattern"; then
        log_error "Failed to get VM IP addresses from existing cluster"
        return 1
    fi

    local overall_success=true

    # Run tests on each VM
    for i in "${!VM_IPS[@]}"; do
        local vm_ip="${VM_IPS[$i]}"
        local vm_name="${VM_NAMES[$i]}"

        log "Testing VM: $vm_name ($vm_ip)"

        # Wait for SSH connectivity
        if ! wait_for_vm_ssh "$vm_ip" "$vm_name"; then
            log_error "SSH connectivity failed for $vm_name"
            overall_success=false
            continue
        fi

        # Calculate intended remote directory (maintain project structure)
        local project_basename
        project_basename="$(basename "$PROJECT_ROOT")"
        local suite_relative
        suite_relative="${test_scripts_dir#"$PROJECT_ROOT"/}"
        # shellcheck disable=SC2088
        local intended_remote_dir="~/$project_basename/$suite_relative"

        # Upload test scripts (will fallback to /tmp if permissions fail)
        if ! upload_scripts_to_vm "$vm_ip" "$vm_name" "$test_scripts_dir" "$intended_remote_dir"; then
            log_error "Failed to upload test scripts to $vm_name"
            overall_success=false
            continue
        fi

        # Get actual directory used (might be /tmp fallback)
        local actual_suite_dir="$ACTUAL_REMOTE_DIR"
        log "  Scripts uploaded to: $actual_suite_dir"

        # Run tests - execute script in actual directory
        local script_basename
        script_basename=$(basename "$master_script")
        if ! execute_script_on_vm "$vm_ip" "$vm_name" "$script_basename" "$actual_suite_dir"; then
            log_warning "Tests failed on $vm_name"
            overall_success=false
        fi
    done

    # Return results
    if [[ "$overall_success" == "true" ]]; then
        log_success "All tests passed across ${#VM_IPS[@]} VM(s)"
        return 0
    else
        log_warning "Some tests failed - check logs for details"
        return 1
    fi
}

# Determine target VM pattern for a given test suite
get_target_pattern_for_suite() {
    local suite="$1"

    # Check if suite is in CONTROLLER_TEST_SUITES
    for controller_suite in "${CONTROLLER_TEST_SUITES[@]}"; do
        if [[ "$suite" == "$controller_suite" ]]; then
            echo "controller"
            return 0
        fi
    done

    # Check if suite is in COMPUTE_TEST_SUITES
    for compute_suite in "${COMPUTE_TEST_SUITES[@]}"; do
        if [[ "$suite" == "$compute_suite" ]]; then
            echo "compute"
            return 0
        fi
    done

    # Check if suite is in JOB_EXAMPLE_TEST_SUITES
    for job_suite in "${JOB_EXAMPLE_TEST_SUITES[@]}"; do
        if [[ "$suite" == "$job_suite" ]]; then
            echo "controller"
            return 0
        fi
    done

    # Default to controller if not found
    echo "controller"
    return 0
}

# Build job examples locally before testing
build_job_examples() {
    log "Building SLURM job examples locally..."

    # Check if Docker is available and build examples
    if command -v docker >/dev/null 2>&1; then
        log "Building examples using make run-docker..."

        # Build each example
        for example in hello-world pi-calculation matrix-multiply; do
            log "Building $example example..."
            if make -C "$PROJECT_ROOT" run-docker COMMAND="cmake --build build --target build-$example"; then
                log_success "Successfully built $example example"
            else
                log_warning "Failed to build $example example (may already be built)"
            fi
        done
    else
        log_warning "Docker not available - skipping build (using pre-built binaries if available)"
    fi

    log "Job examples build step completed"
    return 0
}

# Run all test suites based on mode (against existing cluster)
run_framework_specific_tests() {
    log "Running ${FRAMEWORK_NAME}..."
    log "Test mode: $TEST_MODE"
    log "Note: Running against EXISTING CLUSTER (no cluster startup/teardown)"
    log ""

    local failed=0 passed=0
    local test_suites_to_run=()

    # Determine which test suites to run based on mode
    case "$TEST_MODE" in
        controller)
            log "Testing SLURM controller components only..."
            test_suites_to_run=("${CONTROLLER_TEST_SUITES[@]}")
            ;;
        compute)
            log "Testing SLURM compute components only..."
            test_suites_to_run=("${COMPUTE_TEST_SUITES[@]}")
            ;;
        examples)
            log "Running SLURM job examples only..."
            test_suites_to_run=("${JOB_EXAMPLE_TEST_SUITES[@]}")
            ;;
        full)
            log "Running full SLURM test suite (controller + compute + examples)..."
            test_suites_to_run=("${CONTROLLER_TEST_SUITES[@]}" "${COMPUTE_TEST_SUITES[@]}" "${JOB_EXAMPLE_TEST_SUITES[@]}")
            ;;
        *)
            log_error "Invalid test mode: $TEST_MODE (use: controller, compute, examples, or full)"
            return 1
            ;;
    esac

    log ""; log "Test suites to run: ${test_suites_to_run[*]}"
    log ""

    # Build job examples if they're being tested
    local suites_str=" ${test_suites_to_run[*]} "
    if [[ "$suites_str" =~ " slurm-job-examples " ]]; then
        if ! build_job_examples; then
            log_warning "Job examples build had issues, but continuing with test execution"
        fi
        log ""
    fi

    # Run each test suite against existing cluster (continue even on failures)
    for suite in "${test_suites_to_run[@]}"; do
        local suite_dir="$TESTS_DIR/suites/$suite"

        if [[ ! -d "$suite_dir" ]]; then
            log_warning "Suite not found: $suite"
            ((failed++))
            continue
        fi

        log ""; log "Running: $suite"

        # Determine the master test script name
        local master_script="run-${suite}-tests.sh"

        # Use the framework test config for ALL test suites
        # This ensures tests run against the SAME cluster configuration that was specified
        local test_config="$FRAMEWORK_TEST_CONFIG"

        # Track test execution result
        local suite_result=0

        # Determine target VM pattern based on test suite category
        local target_pattern
        target_pattern=$(get_target_pattern_for_suite "$suite")

        # Run tests against EXISTING cluster (no startup/teardown)
        # All test suites use the same pattern: SSH to target VM and execute
        run_tests_against_existing_cluster "$test_config" "$suite_dir" "$target_pattern" "$master_script" 2>&1 || suite_result=$?

        # Record result and continue to next suite regardless of failure
        if [[ $suite_result -eq 0 ]]; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    log ""; log "Summary: $passed passed, $failed failed"
    # Return success only if no tests failed, but don't exit the script
    if [[ $failed -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Show usage help
show_framework_help() {
    echo "Unified SLURM Test Framework - Task TASK-036"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  e2e, end-to-end       Run end-to-end SLURM testing workflow (default)"
    echo "  start-cluster         Start the SLURM cluster (VMs)"
    echo "  stop-cluster          Stop the SLURM cluster"
    echo "  deploy-ansible        Deploy SLURM configuration via Ansible"
    echo "  run-tests             Run configured test suites only"
    echo "  status                Check cluster status"
    echo "  list-tests            List available test suites"
    echo "  help, --help          Show this help message"
    echo ""
    echo "Options:"
    echo "  --mode MODE           Set test mode: controller, compute, examples, or full (default: full)"
    echo "  --log-level LEVEL     Set logging level: debug, info, warning, error (default: info)"
    echo ""
    echo "Logging Levels:"
    echo "  debug                 Show all debug messages (most verbose)"
    echo "  info                  Show info and important messages (default)"
    echo "  warning               Show only warnings and errors"
    echo "  error                 Show only error messages (least verbose)"
    echo ""
    echo "Examples:"
    echo "  # Full SLURM testing with standard logging (default)"
    echo "  $0 run-tests --mode full"
    echo ""
    echo "  # Test only controller with debug logging"
    echo "  $0 run-tests --mode controller --log-level debug"
    echo ""
    echo "  # Test only compute components with minimal logging"
    echo "  $0 run-tests --mode compute --log-level warning"
    echo ""
    echo "  # Run only SLURM job examples"
    echo "  $0 run-tests --mode examples"
    echo ""
    echo "  # End-to-end workflow with debug output"
    echo "  $0 e2e --log-level debug"
}

# Main execution
# Extract command from first argument (before parsing options)
COMMAND="${1:-}"

# If first arg looks like a command (not an option), shift it before parsing options
if [[ -n "$COMMAND" ]] && [[ ! "$COMMAND" =~ ^- ]]; then
    shift || true
fi

# Parse remaining framework-specific options
parse_slurm_mode "$@"

# Apply logging level from CLI (after parsing)
if ! apply_log_level "$LOG_LEVEL"; then
    log_error "Failed to set log level"
    exit 1
fi

# Get the command via framework-cli if not already set
if [[ -z "$COMMAND" ]] || [[ "$COMMAND" =~ ^- ]]; then
    COMMAND=$(get_framework_command)
fi

# Track exit code for test commands that should complete even on failure
exit_code=0

case "$COMMAND" in
    "e2e"|"end-to-end") run_framework_e2e_workflow || exit_code=$? ;;
    "start-cluster") framework_start_cluster ;;
    "stop-cluster") framework_stop_cluster ;;
    "deploy-ansible") framework_deploy_ansible "$FRAMEWORK_TARGET_VM_PATTERN" ;;
    "run-tests") run_framework_specific_tests || exit_code=$? ;;
    "status") framework_get_cluster_status ;;
    "list-tests") find "$TESTS_DIR/suites" -name "run-*.sh" -o -name "check-*.sh" | head -30 ;;
    "help"|"--help") show_framework_help ;;
    *) run_framework_e2e_workflow || exit_code=$? ;;
esac

# Exit with the captured exit code (0 if no failures occurred)
exit $exit_code
