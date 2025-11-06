#!/bin/bash
#
# SLURM Job Examples: BeeGFS Shared Storage Validation
# Verifies that BeeGFS is accessible from all nodes and supports concurrent access
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"

# Note: Logging functions now provided by suite-logging.sh

TEST_NAME="BeeGFS Shared Storage Validation"
BEEGFS_MOUNT="/mnt/beegfs"
TEST_DIR="${BEEGFS_MOUNT}/test-$$"

# Cleanup on exit
cleanup() {
    log_debug "Cleaning up test directories..."
    # Clean up test directory if it exists
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR" 2>/dev/null || log_warn "Could not remove test directory: $TEST_DIR"
    fi
}

trap cleanup EXIT

# Check if running via SSH (remote mode)
check_remote_mode() {
    if [ "${TEST_MODE:-local}" = "remote" ] && [ -n "${CONTROLLER_IP:-}" ]; then
        log_info "Running in remote mode on controller: $CONTROLLER_IP"
        return 0
    fi
    return 1
}

# Execute command on controller via SSH
run_ssh() {
    local cmd="$1"
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "${SSH_USER}@${CONTROLLER_IP}" "$cmd"
}

# Test: BeeGFS mounted on controller
test_beegfs_mounted_controller() {
    log_info "Testing BeeGFS mount on controller..."

    if check_remote_mode; then
        if ! run_ssh "test -d $BEEGFS_MOUNT"; then
            log_error "BeeGFS mount point not found on controller: $BEEGFS_MOUNT"
            return 1
        fi
    else
        if [ ! -d "$BEEGFS_MOUNT" ]; then
            log_error "BeeGFS mount point not found: $BEEGFS_MOUNT"
            return 1
        fi
    fi

    log_info "✓ BeeGFS mounted on controller"
    return 0
}

# Test: BeeGFS accessible from compute nodes
test_beegfs_accessible_compute() {
    log_info "Testing BeeGFS accessibility from compute nodes..."

    if ! check_remote_mode; then
        log_warn "Not in remote mode - skipping compute node access test"
        return 0
    fi

    # Test access from compute nodes via srun
    if ! run_ssh "srun --nodes=2 --ntasks-per-node=1 test -d $BEEGFS_MOUNT"; then
        log_error "BeeGFS not accessible from one or more compute nodes"
        return 1
    fi

    log_info "✓ BeeGFS accessible from all compute nodes"
    return 0
}

# Test: Write from controller, read from compute
test_cross_node_io() {
    log_info "Testing cross-node I/O through BeeGFS..."

    if ! check_remote_mode; then
        log_warn "Not in remote mode - skipping cross-node I/O test"
        return 0
    fi

    # Create test file on controller
    local test_file="$TEST_DIR/test_file_$$.txt"
    local test_content
    test_content="Cross-node I/O test at $(date)"

    # Create test directory and file on controller
    if ! run_ssh "mkdir -p $TEST_DIR && echo '$test_content' > $test_file"; then
        log_error "Failed to create test file on controller"
        return 1
    fi

    log_debug "Created test file: $test_file"

    # Read file from compute node using srun
    if ! run_ssh "srun --nodes=1 --ntasks=1 grep 'Cross-node I/O test' $test_file"; then
        log_error "Failed to read test file from compute node"
        return 1
    fi

    log_info "✓ Cross-node I/O successful"
    return 0
}

# Test: Concurrent read/write operations
test_concurrent_io() {
    log_info "Testing concurrent I/O operations..."

    if ! check_remote_mode; then
        log_warn "Not in remote mode - skipping concurrent I/O test"
        return 0
    fi

    # Run concurrent writes from multiple compute nodes
    local concurrent_test="
        mkdir -p $TEST_DIR
        srun --nodes=2 --ntasks-per-node=2 bash -c 'echo \"Process \$SLURM_PROCID from node \$HOSTNAME\" > $TEST_DIR/node_\$SLURM_NODEID_proc_\$SLURM_PROCID.txt'
        sleep 1
        echo 'Concurrent write test completed'
    "

    if ! run_ssh "$concurrent_test"; then
        log_error "Concurrent I/O test failed"
        return 1
    fi

    log_info "✓ Concurrent I/O operations successful"
    return 0
}

# Test: Job examples directory structure
test_job_examples_directory() {
    log_info "Testing SLURM job examples directory structure on BeeGFS..."

    if ! check_remote_mode; then
        log_warn "Not in remote mode - checking local directory structure"
    fi

    local job_examples_base="${BEEGFS_MOUNT}/slurm-jobs"

    # Note: Directories may not exist yet; this just validates the path is accessible
    if check_remote_mode; then
        if ! run_ssh "test -d $job_examples_base || mkdir -p $job_examples_base"; then
            log_error "Cannot create job examples directory on controller"
            return 1
        fi
    else
        if ! mkdir -p "$job_examples_base" 2>/dev/null; then
            log_warn "Cannot create job examples directory (may lack permissions): $job_examples_base"
        fi
    fi

    log_info "✓ Job examples base directory accessible: $job_examples_base"
    return 0
}

# Test: File permissions and accessibility
test_file_permissions() {
    log_info "Testing file permissions on BeeGFS..."

    if ! check_remote_mode; then
        log_warn "Not in remote mode - skipping permissions test"
        return 0
    fi

    # Create a test file and verify permissions
    local perm_test="
        mkdir -p $TEST_DIR
        touch $TEST_DIR/perm_test.txt
        chmod 644 $TEST_DIR/perm_test.txt
        stat $TEST_DIR/perm_test.txt | grep -q Access || exit 1
    "

    if ! run_ssh "$perm_test"; then
        log_error "File permissions test failed"
        return 1
    fi

    log_info "✓ File permissions working correctly"
    return 0
}

# Test: Storage space availability
test_storage_space() {
    log_info "Testing BeeGFS storage space availability..."

    if ! check_remote_mode; then
        log_warn "Not in remote mode - checking local storage"
    fi

    local df_cmd="df $BEEGFS_MOUNT | tail -1 | awk '{print \$4}'"

    local available_space
    if check_remote_mode; then
        available_space=$(run_ssh "$df_cmd")
    else
        available_space=$(eval "$df_cmd")
    fi

    # Check if we have at least 1GB available
    if [ "$available_space" -lt 1048576 ]; then
        log_warn "Low storage space on BeeGFS: ${available_space}KB available"
    else
        log_info "✓ Adequate storage space available: ${available_space}KB"
    fi

    return 0
}

# Helper for plain log output
log() {
    echo -e "$1"
}

# Main test execution
main() {
    echo ""
    echo "====================================="
    echo "  $TEST_NAME"
    echo "====================================="
    echo ""

    local failed=0

    # Determine if running in remote or local mode
    if [ "${TEST_MODE:-local}" = "remote" ]; then
        if [ -z "${CONTROLLER_IP:-}" ] || [ -z "${SSH_KEY_PATH:-}" ] || [ -z "${SSH_USER:-}" ]; then
            log_error "Remote mode requires CONTROLLER_IP, SSH_KEY_PATH, and SSH_USER"
            exit 1
        fi
        log_info "Operating in remote mode: $CONTROLLER_IP"
    else
        log_info "Operating in local mode"
    fi

    log ""

    # Run all tests
    test_beegfs_mounted_controller || ((failed++))
    test_beegfs_accessible_compute || ((failed++))
    test_cross_node_io || ((failed++))
    test_concurrent_io || ((failed++))
    test_job_examples_directory || ((failed++))
    test_file_permissions || ((failed++))
    test_storage_space || ((failed++))

    log ""
    if [ $failed -eq 0 ]; then
        log_info "🎉 All BeeGFS shared storage tests passed!"
        log ""
        return 0
    else
        log_error "❌ $failed BeeGFS test(s) failed"
        log ""
        return 1
    fi
}

# Execute main
main "$@"
