#!/bin/bash
#
# Test script to verify ai-how API integration with test framework utilities
# This script tests the new API functions without requiring a running cluster
#

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the utility functions
# shellcheck source=./test-infra/utils/log-utils.sh
source "$SCRIPT_DIR/test-infra/utils/log-utils.sh"
# shellcheck source=./test-infra/utils/cluster-utils.sh
source "$SCRIPT_DIR/test-infra/utils/cluster-utils.sh"

# Initialize logging
init_logging "$(date '+%Y-%m-%d_%H-%M-%S')" "logs" "ai-how-api-test"

log "Testing ai-how API integration with test framework utilities"
log "Project Root: $PROJECT_ROOT"

# Test configuration file (use a sample if available)
TEST_CONFIG="${1:-$PROJECT_ROOT/tests/test-infra/configs/test-minimal.yaml}"

if [[ ! -f "$TEST_CONFIG" ]]; then
    log_error "Test configuration file not found: $TEST_CONFIG"
    log_error "Usage: $0 [config-file]"
    log_error "Please provide a valid cluster configuration file"
    exit 1
fi

log "Using test configuration: $TEST_CONFIG"

# Test 1: Check if ai-how command is available
log "Test 1: Checking ai-how command availability"
if ! command -v uv >/dev/null 2>&1; then
    log_error "uv command not found. Please install uv to run ai-how commands."
    exit 1
fi

if ! uv run ai-how --help >/dev/null 2>&1; then
    log_error "ai-how command not available through uv"
    exit 1
fi

log_success "ai-how command is available"

# Test 2: Check if jq is available
log "Test 2: Checking jq command availability"
if ! command -v jq >/dev/null 2>&1; then
    log_error "jq command not found. Please install jq to parse JSON output."
    exit 1
fi

log_success "jq command is available"

# Test 3: Test cluster plan data retrieval
log "Test 3: Testing cluster plan data retrieval"
if ! cluster_data=$(get_cluster_plan_data "$TEST_CONFIG" "hpc"); then
    log_error "Failed to get cluster plan data"
    exit 1
fi

log_success "Cluster plan data retrieved successfully"
log "Cluster data preview:"
echo "$cluster_data" | jq -r '.name, .type, (.vms | length)' 2>/dev/null || true

# Test 4: Test cluster name parsing
log "Test 4: Testing cluster name parsing"
if ! cluster_name=$(parse_cluster_name "$TEST_CONFIG" "hpc"); then
    log_error "Failed to parse cluster name"
    exit 1
fi

log_success "Cluster name parsed: $cluster_name"

# Test 5: Test expected VMs parsing
log "Test 5: Testing expected VMs parsing"
if ! expected_vms=$(parse_expected_vms "$TEST_CONFIG" "hpc"); then
    log_error "Failed to parse expected VMs"
    exit 1
fi

log_success "Expected VMs parsed: $(echo "$expected_vms" | tr '\n' ' ')"

# Test 6: Test VM specifications retrieval
log "Test 6: Testing VM specifications retrieval"
if ! vm_specs=$(get_vm_specifications "$TEST_CONFIG" "hpc"); then
    log_error "Failed to get VM specifications"
    exit 1
fi

log_success "VM specifications retrieved successfully"
log "VM specifications preview:"
echo "$vm_specs" | jq -r '.name, .type, .cpu_cores, .memory_gb' 2>/dev/null || true

# Test 7: Test direct ai-how plan clusters command
log "Test 7: Testing direct ai-how plan clusters command"
if ! plan_output=$(uv run ai-how plan clusters "$TEST_CONFIG" --format json 2>/dev/null); then
    log_error "Failed to run ai-how plan clusters command"
    exit 1
fi

log_success "ai-how plan clusters command executed successfully"
log "Plan output preview:"
echo "$plan_output" | jq -r '.metadata.name, .clusters | keys' 2>/dev/null || true

# Test 8: Test JSON parsing of plan output
log "Test 8: Testing JSON parsing of plan output"
if ! echo "$plan_output" | jq -e '.clusters.hpc' >/dev/null 2>&1; then
    log_error "Failed to parse HPC cluster from plan output"
    exit 1
fi

if ! echo "$plan_output" | jq -e '.clusters.hpc.vms' >/dev/null 2>&1; then
    log_error "Failed to parse VMs from plan output"
    exit 1
fi

log_success "JSON parsing of plan output successful"

# Test 9: Test VM type filtering
log "Test 9: Testing VM type filtering"
compute_vms=""
compute_vms=$(echo "$plan_output" | jq -r '.clusters.hpc.vms[] | select(.type == "compute") | .name' 2>/dev/null || true)

if [[ -n "$compute_vms" ]]; then
    log_success "Found compute VMs: $(echo "$compute_vms" | tr '\n' ' ')"
else
    log_warning "No compute VMs found in configuration"
fi

# Test 10: Test error handling with invalid config
log "Test 10: Testing error handling with invalid config"
if get_cluster_plan_data "/nonexistent/config.yaml" "hpc" >/dev/null 2>&1; then
    log_error "Error handling test failed - should have failed with invalid config"
    exit 1
fi

log_success "Error handling test passed"

# Summary
echo
log "=================================================="
log_success "All ai-how API integration tests passed!"
log_success "The test framework utilities are ready to use the new API"
log "=================================================="

# Display configuration summary
log "Configuration Summary:"
log "  Cluster Name: $cluster_name"
log "  Expected VMs: $(echo "$expected_vms" | wc -w) VM(s)"
log "  VM Types: $(echo "$vm_specs" | jq -r '.type' | sort -u | tr '\n' ' ')"
log "  Total CPU Cores: $(echo "$vm_specs" | jq -r '.cpu_cores' | awk '{sum+=$1} END {print sum}')"
log "  Total Memory: $(echo "$vm_specs" | jq -r '.memory_gb' | awk '{sum+=$1} END {print sum}') GB"

log "Test completed successfully!"
