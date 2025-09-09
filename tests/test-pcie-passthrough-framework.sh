#!/bin/bash
#
# PCIe Passthrough Test Framework
# Automated testing framework for GPU passthrough using ai-how tooling
#

set -euo pipefail

# PS4 customizes the debug output format for Bash's 'set -x' (execution tracing).
# To use this format, enable debug mode by running: 'set -x' before executing the script,
# or set the environment variable 'BASH_ENV' to source this script with 'set -x'.
PS4='+ [${BASH_SOURCE[0]}:L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/..")"
TESTS_DIR="$PROJECT_ROOT/tests"
TEST_CONFIG="test-infra/configs/test-pcie-passthrough-minimal.yaml"
TEST_SCRIPTS_DIR="$(realpath "$SCRIPT_DIR/scripts/gpu-validation")"
# Create unique log directory per run
RUN_TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_DIR="$(realpath "$SCRIPT_DIR")/logs/test-pcie-passthrough-run-$RUN_TIMESTAMP"
SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
SSH_USER="admin"  # Adjust based on your base image
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# Target VM configuration - only test the GPU-enabled compute node
TARGET_VM_NAME="test-hpc-pcie-minimal-compute-01"

# Timeouts (in seconds)
VM_STARTUP_TIMEOUT=300
SSH_READY_TIMEOUT=180

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Utility Functions
# =============================================================================

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $*"
}

cleanup_on_exit() {
    local exit_code=$?
    log "Cleaning up on exit (code: $exit_code)..."

    if [ "${CLEANUP_REQUIRED:-false}" = "true" ]; then
        log "Attempting to tear down test cluster..."
        if ! tear_down_cluster; then
            log_warning "Automated cleanup failed. You may need to manually clean up VMs."
            if [ "${INTERACTIVE_CLEANUP:-false}" = "true" ]; then
                ask_manual_cleanup
            fi
        fi
    fi

    exit $exit_code
}

ask_manual_cleanup() {
    echo
    log_warning "Test cluster may still be running. Manual cleanup options:"
    echo "  1. List running VMs: virsh list --all"
    echo "  2. Stop specific VM: virsh destroy <vm-name>"
    echo "  3. Remove VM: virsh undefine <vm-name>"
    echo "  4. Clean up using ai-how: cd $PROJECT_ROOT && uv run ai-how destroy $TEST_CONFIG"
    echo

    if [ -t 0 ]; then  # Check if running interactively
        read -p "Would you like to attempt manual cleanup now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            manual_cleanup
        fi
    fi
}

manual_cleanup() {
    log "Attempting manual cleanup..."

    # Try to destroy cluster using ai-how
    cd "$PROJECT_ROOT"
    if uv run ai-how destroy "$TEST_CONFIG" --force 2>/dev/null; then
        log_success "Manual cleanup completed"
    else
        log_warning "Manual cleanup with ai-how failed"

        # List VMs for manual intervention
        log "Current VM status:"
        virsh list --all || true
    fi
}

# =============================================================================
# Core Functions
# =============================================================================

check_prerequisites() {
    log "Checking prerequisites..."

    # Check if we're in the right directory
    if [ ! -f "$TESTS_DIR/$TEST_CONFIG" ]; then
        log_error "Test configuration not found: $TESTS_DIR/$TEST_CONFIG"
        return 1
    fi

    # Check for required commands
    local missing_commands=()
    for cmd in uv virsh ssh; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi

    # Check SSH key
    if [ ! -f "$SSH_KEY_PATH" ]; then
        log_warning "SSH key not found at $SSH_KEY_PATH"
        log_warning "You may need to generate an SSH key pair or adjust SSH_KEY_PATH"
    fi

    # Create log directory
    mkdir -p "$LOG_DIR"

    log_success "Prerequisites check passed"
    return 0
}

check_vm_not_running() {
    log "Checking if target VM ($TARGET_VM_NAME) is already running..."

    # Check if the target VM exists and is running
    if virsh list --name --state-running 2>/dev/null | grep -q "^${TARGET_VM_NAME}$"; then
        log_error "Target VM ($TARGET_VM_NAME) is already running!"
        log_error "The test framework requires a clean environment to start."
        echo ""
        log_error "CLUSTER CLEANUP REQUIRED:"
        echo ""
        echo "To properly clean up the existing cluster, use the ai-how tool:"
        echo ""
        echo "  cd $PROJECT_ROOT"
        echo "  uv run ai-how destroy $TEST_CONFIG"
        echo ""
        echo "Alternative cleanup methods:"
        echo ""
        echo "1. Force destroy with ai-how:"
        echo "   uv run ai-how destroy $TEST_CONFIG --force"
        echo ""
        echo "2. Manual VM cleanup using virsh:"
        echo "   # Stop the VM"
        echo "   virsh destroy $TARGET_VM_NAME"
        echo "   # Remove VM definition"
        echo "   virsh undefine $TARGET_VM_NAME"
        echo "   # Check for any remaining VMs"
        echo "   virsh list --all"
        echo ""
        echo "3. Check for related VMs that might need cleanup:"
        echo "   virsh list --all | grep -E '(hpc|cluster|test)'"
        echo ""
        echo "After cleanup, verify no VMs are running:"
        echo "   virsh list --state-running"
        echo ""
        echo "Then re-run this test framework."
        echo ""
        return 1
    fi

    # Also check if VM exists but is not running (might be in failed state)
    if virsh list --all 2>/dev/null | grep -q "^.*${TARGET_VM_NAME}"; then
        local vm_state
        vm_state=$(virsh list --all | grep "${TARGET_VM_NAME}" | awk '{print $3}')
        log_warning "Target VM ($TARGET_VM_NAME) exists in state: $vm_state"
        log_warning "This may indicate a previous test run didn't clean up properly."
        echo ""
        echo "To clean up the existing VM definition:"
        echo "  virsh undefine $TARGET_VM_NAME"
        echo ""
        echo "Or use ai-how to destroy the entire cluster:"
        echo "  cd $PROJECT_ROOT && uv run ai-how destroy $TEST_CONFIG"
        echo ""
        return 1
    fi

    log_success "Target VM ($TARGET_VM_NAME) is not running - ready to start"
    return 0
}

start_cluster() {
    log "Starting test cluster with configuration: $TEST_CONFIG"

    cd "$PROJECT_ROOT"

    local start_log="$LOG_DIR/cluster-start.log"

    # Start the cluster
    log "Executing: uv run ai-how hpc start $TESTS_DIR/$TEST_CONFIG"
    uv run ai-how hpc start "$TESTS_DIR/$TEST_CONFIG" 2>&1 | tee "$start_log"
    local exit_code=${PIPESTATUS[0]}

    if [ "$exit_code" -eq 0 ]; then
        log_success "Cluster start command completed successfully (exit code: $exit_code)"
        return 0
    else
        log_error "Failed to start cluster (exit code: $exit_code)"
        log "Check the log file: $start_log"
        return 1
    fi
}

wait_for_vms() {
    log "Waiting for target GPU VM ($TARGET_VM_NAME) to be created and running..."

    local timeout=$VM_STARTUP_TIMEOUT
    local elapsed=0
    local check_interval=10

    while [ $elapsed -lt $timeout ]; do
        # Check if the specific target VM is running
        if virsh list --name --state-running 2>/dev/null | grep -q "^${TARGET_VM_NAME}$"; then
            log_success "Target GPU VM ($TARGET_VM_NAME) is running"
            return 0
        fi

        log "Target VM not ready yet... waiting (${elapsed}s/${timeout}s)"
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    log_error "Timeout waiting for target VM ($TARGET_VM_NAME) to start"
    return 1
}

save_vm_connection_info() {
    log "Saving VM connection information to LOG_DIR..."

    # Create VM info subdirectory
    local vm_info_dir="$LOG_DIR/vm-connection-info"
    mkdir -p "$vm_info_dir"

    # Save structured VM information (JSON-like format)
    log "Creating VM connection info files..."

    # VM List (human readable)
    {
        echo "# VM Connection Information"
        echo "# Generated at: $(date)"
        echo "# Test Configuration: $TEST_CONFIG"
        echo "# Log Directory: $LOG_DIR"
        echo ""
        echo "VM Count: ${#VM_IPS[@]}"
        echo ""
        echo "VM Details:"
        for i in "${!VM_IPS[@]}"; do
            echo "  VM $((i+1)):"
            echo "    Name: ${VM_NAMES[$i]}"
            echo "    IP: ${VM_IPS[$i]}"
            echo ""
        done
    } > "$vm_info_dir/vm-list.txt"

    # SSH Connection Commands (ready to use)
    {
        echo "#!/bin/bash"
        echo "# SSH Connection Commands for Test VMs"
        echo "# Generated at: $(date)"
        echo ""
        echo "# SSH Configuration:"
        echo "SSH_KEY_PATH=\"$SSH_KEY_PATH\""
        echo "SSH_USER=\"$SSH_USER\""
        echo "SSH_OPTS=\"$SSH_OPTS\""
        echo ""
        echo "# Individual VM Connection Commands:"
        for i in "${!VM_IPS[@]}"; do
            echo ""
            echo "# Connect to ${VM_NAMES[$i]} (${VM_IPS[$i]})"
            echo "ssh $SSH_OPTS -i \"$SSH_KEY_PATH\" \"$SSH_USER@${VM_IPS[$i]}\""
            echo "# Copy files to ${VM_NAMES[$i]}:"
            echo "# scp $SSH_OPTS -i \"$SSH_KEY_PATH\" <local-file> \"$SSH_USER@${VM_IPS[$i]}:~/\""
            echo "# Copy files from ${VM_NAMES[$i]}:"
            echo "# scp $SSH_OPTS -i \"$SSH_KEY_PATH\" \"$SSH_USER@${VM_IPS[$i]}:~/remote-file\" ."
        done
        echo ""
        echo "# Connect to all VMs in sequence:"
        echo "connect_all_vms() {"
        for i in "${!VM_IPS[@]}"; do
            echo "    echo \"Connecting to ${VM_NAMES[$i]} (${VM_IPS[$i]})...\""
            echo "    ssh $SSH_OPTS -i \"$SSH_KEY_PATH\" \"$SSH_USER@${VM_IPS[$i]}\" \"\$@\""
        done
        echo "}"
    } > "$vm_info_dir/ssh-commands.sh"
    chmod +x "$vm_info_dir/ssh-commands.sh"

    # CSV format for easy parsing
    {
        echo "vm_name,vm_ip,ssh_command,scp_upload_command,scp_download_command"
        for i in "${!VM_IPS[@]}"; do
            local vm_name="${VM_NAMES[$i]}"
            local vm_ip="${VM_IPS[$i]}"
            local ssh_cmd="ssh $SSH_OPTS -i \"$SSH_KEY_PATH\" \"$SSH_USER@$vm_ip\""
            local scp_up="scp $SSH_OPTS -i \"$SSH_KEY_PATH\" <local-file> \"$SSH_USER@$vm_ip:~/\""
            local scp_down="scp $SSH_OPTS -i \"$SSH_KEY_PATH\" \"$SSH_USER@$vm_ip:~/remote-file\" ."
            echo "$vm_name,$vm_ip,\"$ssh_cmd\",\"$scp_up\",\"$scp_down\""
        done
    } > "$vm_info_dir/vm-info.csv"

    # Save VM status information
    {
        echo "# VM Status Information"
        echo "# Generated at: $(date)"
        echo ""
        echo "=== Running VMs ==="
        virsh list --name --state-running | grep "^${TARGET_VM_NAME}$" || echo "Target GPU VM ($TARGET_VM_NAME) not found"
        echo ""
        echo "=== Target GPU VM Status ==="
        virsh list --all | grep "^${TARGET_VM_NAME}" || echo "Target GPU VM ($TARGET_VM_NAME) not found"
        echo ""
        echo "=== VM Network Information ==="
        for i in "${!VM_IPS[@]}"; do
            echo "--- ${VM_NAMES[$i]} ---"
            virsh domifaddr "${VM_NAMES[$i]}" 2>/dev/null || echo "Network info not available"
            echo ""
        done
    } > "$vm_info_dir/vm-status.txt"

    # Create a debugging helper script
    {
        echo "#!/bin/bash"
        echo "# VM Debugging Helper Script"
        echo "# Generated at: $(date)"
        echo ""
        echo "VM_INFO_DIR=\"\$(dirname \"\$0\")\""
        echo "LOG_DIR=\"$LOG_DIR\""
        echo ""
        echo "show_help() {"
        echo "    echo \"VM Debugging Helper\""
        echo "    echo \"Usage: \$0 [COMMAND] [VM_NAME_OR_NUMBER]\""
        echo "    echo \"\""
        echo "    echo \"Commands:\""
        echo "    echo \"  list          - List all VMs\""
        echo "    echo \"  connect <vm>  - Connect to specific VM\""
        echo "    echo \"  logs <vm>     - Show test logs for VM\""
        echo "    echo \"  status        - Show VM status\""
        echo "    echo \"  commands      - Show all SSH commands\""
        echo "    echo \"\""
        echo "    echo \"Examples:\""
        echo "    echo \"  \$0 list\""
        echo "    echo \"  \$0 connect 1    # Connect to first VM\""
        echo "    echo \"  \$0 connect vm1  # Connect to VM named 'vm1'\""
        echo "}"
        echo ""
        echo "case \"\$1\" in"
        echo "    list)"
        echo "        echo \"Available VMs:\""
        for i in "${!VM_IPS[@]}"; do
            echo "        echo \"  $((i+1)): ${VM_NAMES[$i]} (${VM_IPS[$i]})\""
        done
        echo "        ;;"
        echo "    connect)"
        echo "        if [[ \"\$2\" =~ ^[0-9]+\$ ]] && [ \"\$2\" -le \"${#VM_IPS[@]}\" ] && [ \"\$2\" -gt 0 ]; then"
        echo "            # Connect by number"
        echo "            vm_index=\$((\$2 - 1))"
        for i in "${!VM_IPS[@]}"; do
            echo "            [ \"\$vm_index\" -eq \"$i\" ] && ssh $SSH_OPTS -i \"$SSH_KEY_PATH\" \"$SSH_USER@${VM_IPS[$i]}\""
        done
        echo "        else"
        echo "            # Connect by name"
        for i in "${!VM_IPS[@]}"; do
            echo "            [ \"\$2\" = \"${VM_NAMES[$i]}\" ] && ssh $SSH_OPTS -i \"$SSH_KEY_PATH\" \"$SSH_USER@${VM_IPS[$i]}\""
        done
        echo "        fi"
        echo "        ;;"
        echo "    logs)"
        echo "        echo \"Test logs directory: \$LOG_DIR\""
        echo "        ls -la \"\$LOG_DIR/\"*\$2* 2>/dev/null || echo \"No logs found for VM '\$2'\""
        echo "        ;;"
        echo "    status)"
        echo "        cat \"\$VM_INFO_DIR/vm-status.txt\""
        echo "        ;;"
        echo "    commands)"
        echo "        cat \"\$VM_INFO_DIR/ssh-commands.sh\""
        echo "        ;;"
        echo "    *)"
        echo "        show_help"
        echo "        ;;"
        echo "esac"
    } > "$vm_info_dir/debug-helper.sh"
    chmod +x "$vm_info_dir/debug-helper.sh"

    log_success "VM connection info saved to: $vm_info_dir"
    log "  - vm-list.txt: Human-readable VM information"
    log "  - ssh-commands.sh: Ready-to-use SSH commands"
    log "  - vm-info.csv: Machine-readable VM data"
    log "  - vm-status.txt: Current VM status information"
    log "  - debug-helper.sh: Interactive debugging helper"
}

get_vm_ips() {
    log "Getting IP address for target GPU VM ($TARGET_VM_NAME)..."

    # Check if the target VM is running
    if ! virsh list --name --state-running 2>/dev/null | grep -q "^${TARGET_VM_NAME}$"; then
        log_error "Target GPU VM ($TARGET_VM_NAME) is not running"
        return 1
    fi

    VM_IPS=()
    VM_NAMES=()

    log "Getting IP for target VM: $TARGET_VM_NAME"

    # Try to get IP using virsh domifaddr for the specific target VM
    local vm_ip=""
    local attempts=0
    local max_attempts=10

    while [ $attempts -lt $max_attempts ] && [ -z "$vm_ip" ]; do
        if vm_ip=$(virsh domifaddr "$TARGET_VM_NAME" | grep -oE "192\.168\.[0-9]+\.[0-9]+" | head -1); then
            break
        fi

        attempts=$((attempts + 1))
        log "IP not available yet for $TARGET_VM_NAME, attempt $attempts/$max_attempts"
        sleep 5
    done

    if [ -n "$vm_ip" ]; then
        log_success "Target GPU VM $TARGET_VM_NAME IP: $vm_ip"
        VM_IPS+=("$vm_ip")
        VM_NAMES+=("$TARGET_VM_NAME")
    else
        log_error "Failed to get IP for target VM: $TARGET_VM_NAME"
        return 1
    fi

    log_success "Retrieved IP address for target GPU VM: $TARGET_VM_NAME ($vm_ip)"

    # Save VM connection information for debugging
    save_vm_connection_info

    return 0
}

wait_for_ssh() {
    local vm_ip="$1"
    local vm_name="$2"

    log "Waiting for SSH connectivity to $vm_name ($vm_ip)..."

    local timeout=$SSH_READY_TIMEOUT
    local elapsed=0
    local check_interval=10

    while [ $elapsed -lt $timeout ]; do
        # shellcheck disable=SC2086
        if ssh ${SSH_OPTS} -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "echo 'SSH ready'" >/dev/null 2>&1; then
            log_success "SSH ready for $vm_name ($vm_ip)"
            return 0
        fi

        log "SSH not ready for $vm_name... waiting (${elapsed}s/${timeout}s)"
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    log_error "Timeout waiting for SSH connectivity to $vm_name"
    return 1
}

upload_test_scripts() {
    local vm_ip="$1"
    local vm_name="$2"

    log "Uploading test scripts to $vm_name ($vm_ip)..."

    # Create remote test and log directories using user home directory
    # shellcheck disable=SC2088
    local remote_base_dir="~/gpu-tests"
    local remote_log_dir="$remote_base_dir/logs/run-$RUN_TIMESTAMP"
    # shellcheck disable=SC2086
    if ! ssh ${SSH_OPTS} -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "mkdir -p $remote_base_dir $remote_log_dir"; then
        log_error "Failed to create remote test and log directories"
        return 1
    fi

    # Upload all test scripts
    # shellcheck disable=SC2086
    if ! scp ${SSH_OPTS} -i "$SSH_KEY_PATH" "$TEST_SCRIPTS_DIR"/*.sh "$SSH_USER@$vm_ip:$remote_base_dir/"; then
        log_error "Failed to upload test scripts"
        return 1
    fi

    # Make scripts executable
    # shellcheck disable=SC2086
    if ! ssh ${SSH_OPTS} -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "chmod +x $remote_base_dir/*.sh"; then
        log_error "Failed to make test scripts executable"
        return 1
    fi

    log_success "Test scripts uploaded successfully"
    return 0
}

run_tests_on_vm() {
    local vm_ip="$1"
    local vm_name="$2"

    log "Running GPU validation tests on $vm_name ($vm_ip)..."

    local test_log="$LOG_DIR/test-results-${vm_name}.log"
    # shellcheck disable=SC2088
    local remote_base_dir="~/gpu-tests"
    local remote_log_dir="$remote_base_dir/logs/run-$RUN_TIMESTAMP"

    # Run the test suite on the remote VM with custom log directory
    # shellcheck disable=SC2086
    if ssh ${SSH_OPTS} -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "LOG_DIR='$remote_log_dir' $remote_base_dir/run-all-tests.sh" 2>&1 | tee "$test_log"; then
        local test_exit_code=${PIPESTATUS[0]}

        # Copy remote logs back to local system
        log "Copying remote test logs from $vm_name..."
        # shellcheck disable=SC2086
        if scp ${SSH_OPTS} -i "$SSH_KEY_PATH" -r "$SSH_USER@$vm_ip:$remote_log_dir/" "$LOG_DIR/remote-logs-${vm_name}/" 2>/dev/null; then
            log_success "Remote logs copied to $LOG_DIR/remote-logs-${vm_name}/"
        else
            log_warning "Failed to copy remote logs (tests may have failed early)"
        fi

        if [ "$test_exit_code" -eq 0 ]; then
            log_success "All tests passed on $vm_name"
            return 0
        else
            log_warning "Some tests failed on $vm_name (exit code: $test_exit_code)"
            return "$test_exit_code"
        fi
    else
        log_error "Failed to execute tests on $vm_name"
        return 1
    fi
}

tear_down_cluster() {
    log "Tearing down test cluster..."

    cd "$PROJECT_ROOT"

    local destroy_log="$LOG_DIR/cluster-destroy.log"

    # Try graceful shutdown first
    log "Executing: uv run ai-how hpc destroy $TESTS_DIR/$TEST_CONFIG"
    uv run ai-how hpc destroy "$TESTS_DIR/$TEST_CONFIG" 2>&1 | tee "$destroy_log"
    local exit_code=${PIPESTATUS[0]}

    if [ "$exit_code" -eq 0 ]; then
        log_success "Cluster destroyed successfully (exit code: $exit_code)"

        # Wait a moment and verify cleanup
        sleep 5
        if verify_cleanup; then
            log_success "Cleanup verification passed"
            return 0
        else
            log_warning "Cleanup verification found remaining VMs"
            return 1
        fi
    else
        log_error "Failed to destroy cluster gracefully (exit code: $exit_code)"
        log "Check the log file: $destroy_log"
        return 1
    fi
}

verify_cleanup() {
    log "Verifying cleanup (checking for remaining VMs)..."

    local remaining_vms
    if remaining_vms=$(virsh list --all | grep "^${TARGET_VM_NAME}" || true); then
        if [ -n "$remaining_vms" ]; then
            log_warning "Found remaining VMs:"
            echo "$remaining_vms"
            return 1
        fi
    fi

    log_success "No remaining VMs found"
    return 0
}

# =============================================================================
# Main Test Execution
# =============================================================================

run_full_test() {
    log "Starting PCIe Passthrough Test Framework"
    log "Configuration: $TEST_CONFIG"
    log "Target GPU VM: $TARGET_VM_NAME"
    log "Log directory: $LOG_DIR"
    echo

    # Setup cleanup handler
    trap cleanup_on_exit EXIT INT TERM

    # Step 1: Prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        return 1
    fi

    # Step 2: Check VM not running
    if ! check_vm_not_running; then
        log_error "Environment check failed - VM already exists"
        return 1
    fi

    # Step 3: Start cluster
    if ! start_cluster; then
        log_error "Failed to start cluster"
        return 1
    fi

    CLEANUP_REQUIRED=true

    # Step 4: Wait for target GPU VM
    if ! wait_for_vms; then
        log_error "Target GPU VM failed to start properly"
        return 1
    fi

    # Step 5: Get target VM IP
    if ! get_vm_ips; then
        log_error "Failed to get target VM IP address"
        return 1
    fi

    # Step 6: Test target GPU VM
    local overall_success=true
    for i in "${!VM_IPS[@]}"; do
        local vm_ip="${VM_IPS[$i]}"
        local vm_name="${VM_NAMES[$i]}"

        log "Testing VM: $vm_name ($vm_ip)"

        # Wait for SSH
        if ! wait_for_ssh "$vm_ip" "$vm_name"; then
            log_error "SSH connectivity failed for $vm_name"
            overall_success=false
            continue
        fi

        # Upload test scripts
        if ! upload_test_scripts "$vm_ip" "$vm_name"; then
            log_error "Failed to upload test scripts to $vm_name"
            overall_success=false
            continue
        fi

        # Run tests
        if ! run_tests_on_vm "$vm_ip" "$vm_name"; then
            log_warning "Tests failed on $vm_name"
            overall_success=false
        fi
    done

    # Step 7: Cleanup
    if ! tear_down_cluster; then
        log_error "Failed to tear down cluster cleanly"
        INTERACTIVE_CLEANUP=true
        return 1
    fi

    CLEANUP_REQUIRED=false

    # Final results
    echo
    log "=================================================="
    if [ "$overall_success" = "true" ]; then
        log_success "PCIe Passthrough Test Framework: ALL TESTS PASSED"
        log_success "GPU passthrough is working correctly on target VM ($TARGET_VM_NAME)"
        return 0
    else
        log_warning "PCIe Passthrough Test Framework: TESTS FAILED"
        log_warning "GPU passthrough failed on target VM ($TARGET_VM_NAME)"
        log_warning "Check test logs in $LOG_DIR"
        return 1
    fi
}

# =============================================================================
# CLI Interface
# =============================================================================

show_usage() {
    cat << EOF
PCIe Passthrough Test Framework

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --help, -h          Show this help message
    --config CONFIG     Use specific test configuration (default: $TEST_CONFIG)
    --ssh-user USER     SSH username (default: $SSH_USER)
    --ssh-key KEY       SSH key path (default: $SSH_KEY_PATH)
    --target-vm NAME    Target VM name to test (default: $TARGET_VM_NAME)
    --no-cleanup        Don't cleanup on failure (for debugging)
    --verbose, -v       Enable verbose output

EXAMPLES:
    # Run with default configuration
    $0

    # Run with custom configuration
    $0 --config test-infra/configs/test-full-stack.yaml

    # Run with custom SSH settings
    $0 --ssh-user root --ssh-key ~/.ssh/test_key

    # Run with different target VM
    $0 --target-vm my-custom-compute-node

    # Run without cleanup on failure (for debugging)
    $0 --no-cleanup

PREREQUISITES:
    - ai-how tool installed and working
    - virsh command available
    - SSH key pair configured
    - Base VM images built (Packer)

IMPORTANT:
    The framework requires a clean environment and will check that the target VM
    is not already running before starting tests. If a VM exists, you will get
    detailed cleanup instructions including:

    - Using ai-how to destroy the cluster: 'uv run ai-how destroy <config>'
    - Manual VM cleanup using virsh commands
    - Verification commands to ensure clean environment

    Always ensure previous test runs are properly cleaned up before starting.

LOG FILES:
    Test logs are saved to: tests/logs/run-YYYY-MM-DD_HH-MM-SS/
    Each test run creates a unique timestamped directory with:
    - cluster-start.log, cluster-destroy.log: Framework operation logs
    - test-results-<vm-name>.log: Individual VM test results
    - remote-logs-<vm-name>/: Remote VM test execution logs
    - vm-connection-info/: VM IP addresses and SSH connection commands
      * vm-list.txt: Human-readable VM information
      * ssh-commands.sh: Ready-to-use SSH connection commands
      * debug-helper.sh: Interactive debugging helper script

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_usage
            exit 0
            ;;
        --config)
            TEST_CONFIG="$2"
            shift 2
            ;;
        --ssh-user)
            SSH_USER="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        --target-vm)
            TARGET_VM_NAME="$2"
            shift 2
            ;;
        --no-cleanup)
            trap - EXIT INT TERM
            shift
            ;;
        --verbose|-v)
            set -x
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# =============================================================================
# Main Execution
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_full_test
fi
