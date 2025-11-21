#!/usr/bin/env bash
#
# Container Test Helper Functions
#

# Skip test if Apptainer is not available
skip_if_no_apptainer() {
    if ! command -v apptainer >/dev/null 2>&1; then
        skip "Apptainer binary not available"
    fi
}

# Skip test if no GPU available
skip_if_no_gpu() {
    if ! srun --nodes=1 --gres=gpu:1 true 2>/dev/null; then
        skip "No GPU resources available"
    fi
}

# Skip test if cluster has only single node
skip_if_single_node() {
    local node_count
    node_count=$(sinfo -N | grep -c compute || echo "1")
    if [ "$node_count" -lt 2 ]; then
        skip "Multi-node test requires at least 2 nodes"
    fi
}

# Test container command execution
# Usage: test_container_exec "container.sif" "command"
# Note: This function is reserved for future use in test suites
test_container_exec() {
    local container="$1"
    local command="$2"

    apptainer exec "$container" "$command"
}
