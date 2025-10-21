#!/bin/bash

# Extract IP Addresses from Cluster Configuration
# Parses cluster YAML configuration and outputs IP addresses
#
# Usage:
#   ./extract-cluster-ips.sh <config-file> [cluster-type]
#
# Arguments:
#   config-file    Path to cluster YAML configuration
#   cluster-type   Type of cluster (default: hpc)
#
# Output:
#   Space-separated list of IP addresses to stdout
#
# Examples:
#   ./extract-cluster-ips.sh config/example-multi-gpu-clusters.yaml
#   ./extract-cluster-ips.sh config/test-beegfs.yaml hpc

set -euo pipefail

# Parse arguments
CONFIG_FILE="${1:-}"
CLUSTER_TYPE="${2:-hpc}"

if [[ -z "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file required" >&2
    echo "Usage: $0 <config-file> [cluster-type]" >&2
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi

# Check for yq (YAML parser)
if command -v yq >/dev/null 2>&1; then
    # Use yq if available (preferred)
    {
        yq eval ".clusters.${CLUSTER_TYPE}.controller.ip_address" "$CONFIG_FILE" 2>/dev/null || true
        yq eval ".clusters.${CLUSTER_TYPE}.compute_nodes[].ip_address" "$CONFIG_FILE" 2>/dev/null || true
        yq eval ".clusters.${CLUSTER_TYPE}.compute_nodes[].ip" "$CONFIG_FILE" 2>/dev/null || true
    } | grep -v "^null$" | tr '\n' ' '
    exit 0
fi

# Fallback to grep/awk parsing (works without yq)
# Extract IPs from both "ip_address:" and "ip:" fields
grep -E "^\s+(ip_address|ip):" "$CONFIG_FILE" | \
    awk '{print $2}' | \
    tr -d '"' | \
    grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$" | \
    sort -u | \
    tr '\n' ' '
