#!/bin/bash
#
# SLURM Cluster Health Check and Cleanup Script
# Validates cluster health and performs necessary cleanup/resync before running tests
# Ensures all compute nodes are responsive and SLURM services are operational
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Configuration
: "${HEALTH_CHECK_TIMEOUT:=60}"
: "${NODE_RESPONSE_TIMEOUT:=10}"
MAX_RESYNC_RETRIES=3
RESYNC_WAIT_INTERVAL=5

# Helper functions for this script
log() {
    echo -e "$1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_failure() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running via SSH (remote mode)
check_remote_mode() {
    if [ "${TEST_MODE:-local}" = "remote" ] && [ -n "${CONTROLLER_IP:-}" ]; then
        return 0
    fi
    return 1
}

# Execute command on remote controller or locally
execute_command() {
    local cmd="$1"

    if check_remote_mode; then
        ssh -i "$SSH_KEY_PATH" \
            -o StrictHostKeyChecking=no \
            -o ConnectTimeout="$NODE_RESPONSE_TIMEOUT" \
            -o BatchMode=yes \
            "${SSH_USER}@${CONTROLLER_IP}" "$cmd"
    else
        eval "$cmd"
    fi
}

# Check SLURM controller daemon status
check_controller_daemon() {
    log_info "Checking SLURM controller daemon status..."

    if ! execute_command "systemctl is-active slurmctld >/dev/null 2>&1"; then
        log_failure "SLURM controller daemon (slurmctld) is not running"
        return 1
    fi

    log_success "SLURM controller daemon is running"
    return 0
}

# Check SLURM database daemon status
check_database_daemon() {
    log_info "Checking SLURM database daemon status..."

    if ! execute_command "systemctl is-active slurmdbd >/dev/null 2>&1"; then
        log_warn "SLURM database daemon (slurmdbd) is not running (optional)"
        return 0  # Don't fail on this
    fi

    log_success "SLURM database daemon is running"
    return 0
}

# Get list of compute nodes from SLURM configuration
get_compute_nodes() {
    execute_command "sinfo -h -o '%N' -t idle,alloc,down,drained,draining"
}

# Check individual node responsiveness
check_node_responsiveness() {
    local node="$1"
    local node_status

    # Get node status from SLURM
    node_status=$(execute_command "scontrol show node '$node' 2>/dev/null | grep 'State=' | head -1" || echo "")

    if [ -z "$node_status" ]; then
        log_failure "Could not query node status: $node"
        return 1
    fi

    # Check if node is down or not responding
    if echo "$node_status" | grep -qE "State=.*DOWN|State=.*NOT_RESPONDING"; then
        log_failure "Node is DOWN or NOT_RESPONDING: $node ($node_status)"
        return 1
    fi

    log_success "Node is responsive: $node"
    return 0
}

# Check all compute nodes
check_all_nodes() {
    log_info "Checking compute node responsiveness..."

    local nodes
    nodes=$(get_compute_nodes)

    if [ -z "$nodes" ]; then
        log_error "Could not retrieve compute node list from SLURM"
        return 1
    fi

    local failed_nodes=()
    local node_count=0

    for node in $nodes; do
        # Skip controller node
        if [ "$node" = "controller" ]; then
            continue
        fi

        node_count=$((node_count + 1))

        if ! check_node_responsiveness "$node"; then
            failed_nodes+=("$node")
        fi
    done

    if [ $node_count -eq 0 ]; then
        log_error "No compute nodes found in SLURM configuration"
        return 1
    fi

    if [ ${#failed_nodes[@]} -gt 0 ]; then
        log_warn "Found ${#failed_nodes[@]}/$node_count nodes that are not responsive"
        return 1
    fi

    log_success "All $node_count compute nodes are responsive"
    return 0
}

# Check job queue for stuck jobs
check_job_queue() {
    log_info "Checking SLURM job queue..."

    local pending_count
    pending_count=$(execute_command "squeue -h -t PD | wc -l")

    local running_count
    running_count=$(execute_command "squeue -h -t R | wc -l")

    log_info "Job queue status: Running=$running_count, Pending=$pending_count"

    if [ "$pending_count" -gt 50 ]; then
        log_warn "Large number of pending jobs ($pending_count) - may indicate scheduler issues"
        return 1
    fi

    log_success "Job queue appears healthy"
    return 0
}

# Resync down nodes with controller
resync_nodes() {
    log_info "Attempting to resync down nodes with SLURM controller..."

    local nodes
    nodes=$(execute_command "sinfo -h -o '%N' -t down,drained,draining")

    if [ -z "$nodes" ]; then
        log_info "No nodes to resync"
        return 0
    fi

    log_info "Resyncing nodes: $nodes"

    # Attempt to resume down nodes
    if ! execute_command "scontrol update nodename='$nodes' state=resume" 2>/dev/null; then
        log_warn "Failed to issue resync command"
        return 1
    fi

    # Wait for nodes to respond
    sleep "$RESYNC_WAIT_INTERVAL"

    # Verify nodes came back up
    local verify_down
    verify_down=$(execute_command "sinfo -h -o '%N' -t down")

    if [ -n "$verify_down" ]; then
        log_warn "Some nodes still down after resync: $verify_down"
        return 1
    fi

    log_success "Nodes successfully resynced"
    return 0
}

# Clear queued but failed jobs
clear_failed_jobs() {
    log_info "Checking for failed or stuck jobs..."

    local failed_count
    failed_count=$(execute_command "squeue -h -t F,CA,TO,NF 2>/dev/null | wc -l" || echo "0")

    if [ "$failed_count" -eq 0 ]; then
        log_info "No stuck/failed jobs found"
        return 0
    fi

    log_warn "Found $failed_count stuck/failed jobs"

    # Cancel failed jobs (only user jobs, not system jobs)
    execute_command "scancel --state=FAILED --states=CANCELLED,TIMEOUT,NODE_FAIL 2>/dev/null" || true

    log_info "Cleared failed jobs"
    return 0
}

# Restart SLURM daemons if needed
restart_slurm_daemons() {
    log_info "Verifying SLURM daemon health..."

    # Check controller daemon
    if ! execute_command "systemctl is-active slurmctld >/dev/null 2>&1"; then
        log_warn "SLURM controller daemon not running - restarting..."

        if ! execute_command "sudo systemctl restart slurmctld" 2>/dev/null; then
            log_error "Failed to restart slurmctld daemon"
            return 1
        fi

        sleep 5  # Give daemon time to start
        log_info "SLURM controller daemon restarted"
    fi

    return 0
}

# Perform cluster cleanup before tests
cleanup_cluster() {
    log_info "Performing cluster cleanup..."

    # Clear old job logs and temporary files from BeeGFS
    if execute_command "[ -d /mnt/beegfs/slurm-jobs ] 2>/dev/null"; then
        log_info "Cleaning up old job directories from BeeGFS..."
        execute_command "find /mnt/beegfs/slurm-jobs -type d -mtime +1 -exec rm -rf {} + 2>/dev/null" || true
    fi

    # Clear SLURM job cache
    if execute_command "[ -d /var/lib/slurm/slurmd ] 2>/dev/null"; then
        log_info "Clearing SLURM job cache..."
        execute_command "sudo rm -f /var/lib/slurm/slurmd/job_state* 2>/dev/null" || true
    fi

    log_success "Cluster cleanup completed"
    return 0
}

# Wait for all nodes to be ready
wait_for_nodes_ready() {
    local max_wait=$HEALTH_CHECK_TIMEOUT
    local elapsed=0
    local check_interval=5

    log_info "Waiting for all nodes to be ready (timeout: ${max_wait}s)..."

    while [ "$elapsed" -lt "$max_wait" ]; do
        local down_count
        down_count=$(execute_command "sinfo -h -o '%N' -t down | wc -l" || echo "1")

        if [ "$down_count" -eq 0 ]; then
            log_success "All nodes are ready"
            return 0
        fi

        log_debug "Waiting for nodes... ($((max_wait - elapsed))s remaining)"
        sleep "$check_interval"
        elapsed=$((elapsed + check_interval))
    done

    log_error "Nodes did not become ready within timeout"
    return 1
}

# Main health check function
main() {
    local start_time
    start_time=$(date +%s)

    log ""
    log "====================================="
    log "  SLURM Cluster Health Check"
    log "====================================="
    log ""

    # Step 1: Check SLURM daemons
    log_info "Step 1/6: Verifying SLURM daemons..."
    if ! check_controller_daemon; then
        log_error "Controller daemon check failed - attempting restart..."
        if ! restart_slurm_daemons; then
            log_error "Failed to recover SLURM controller daemon"
            return 1
        fi
    fi

    check_database_daemon || true

    # Step 2: Check job queue
    log_info "Step 2/6: Checking job queue..."
    if ! check_job_queue; then
        log_warn "Job queue check failed - will continue"
    fi

    # Step 3: Check node responsiveness
    log_info "Step 3/6: Checking compute node responsiveness..."
    if ! check_all_nodes; then
        log_warn "Some nodes not responding - attempting resync..."

        # Step 4: Resync down nodes
        log_info "Step 4/6: Resyncing down nodes..."
        local retry_count=0
        while [ $retry_count -lt $MAX_RESYNC_RETRIES ]; do
            if resync_nodes; then
                break
            fi
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $MAX_RESYNC_RETRIES ]; then
                log_warn "Resync attempt $((retry_count + 1))/$MAX_RESYNC_RETRIES..."
                sleep $((RESYNC_WAIT_INTERVAL * (retry_count + 1)))
            fi
        done

        if [ $retry_count -ge $MAX_RESYNC_RETRIES ]; then
            log_error "Failed to resync nodes after $MAX_RESYNC_RETRIES attempts"
            return 1
        fi

        # Wait for nodes to be ready
        log_info "Step 5/6: Waiting for nodes to stabilize..."
        if ! wait_for_nodes_ready; then
            log_error "Nodes failed to stabilize"
            return 1
        fi
    else
        # Skip steps 4-5 if nodes already healthy
        log_info "Step 4/6: Skipping resync (nodes are healthy)"
        log_info "Step 5/6: Skipping wait (nodes are stable)"
    fi

    # Step 6: Cleanup and prepare for tests
    log_info "Step 6/6: Cleaning up cluster..."
    clear_failed_jobs || true
    cleanup_cluster || true

    # Final verification
    log_info "Performing final health verification..."
    if ! check_all_nodes; then
        log_error "Final health check failed"
        return 1
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log ""
    log "====================================="
    log_success "✓ Cluster health check PASSED"
    log "====================================="
    log_info "Health check completed in ${duration}s"
    log ""

    return 0
}

# Execute main function
main "$@"
