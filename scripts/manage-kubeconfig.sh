#!/usr/bin/env bash
# Manage multiple Kubernetes kubeconfig files
#
# This script helps manage multiple cluster kubeconfigs by:
# - Listing all available cluster configs
# - Switching between clusters
# - Merging configs for multi-cluster access
# - Setting default cluster context
#
# Kubeconfigs are stored in: output/cluster-state/kubeconfigs/
# This location is repo-based and gitignored for security

set -euo pipefail

# Find project root (directory containing .git or scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Use repo-based kubeconfig directory
KUBE_DIR="${PROJECT_ROOT}/output/cluster-state/kubeconfigs"
CONFIG_SUFFIX=".kubeconfig"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Manage multiple Kubernetes kubeconfig files

Usage: manage-kubeconfig.sh <command> [options]

Commands:
  list                    List all available cluster configs
  use <cluster>           Switch to use a specific cluster
  merge [output]          Merge all configs into one (default: ~/.kube/config)
  current                 Show current kubectl context
  show <cluster>           Show details for a specific cluster
  set-default <cluster>   Set a cluster as the default (~/.kube/config)
  help                    Show this help message

Examples:
  # List all clusters
  $0 list

  # Use a specific cluster
  $0 use cloud-cluster

  # Merge all clusters into default config
  $0 merge

  # Set cloud-cluster as default
  $0 set-default cloud-cluster

  # Show current context
  $0 current
EOF
}

list_clusters() {
    echo "Available clusters:"
    echo "Kubeconfig directory: ${KUBE_DIR}"
    echo ""
    if [ ! -d "${KUBE_DIR}" ]; then
        echo "  ${YELLOW}No kubeconfig directory found${NC}"
        echo "  ${YELLOW}Run cluster deployment to generate kubeconfigs${NC}"
        return 0
    fi

    local found=false
    for config in "${KUBE_DIR}"/*"${CONFIG_SUFFIX}"; do
        if [ -f "${config}" ]; then
            found=true
            local filename
            filename=$(basename "${config}")
            local cluster_name="${filename%"${CONFIG_SUFFIX}"}"
            local size
            size=$(du -h "${config}" | cut -f1)

            # Try to get cluster info from kubeconfig
            local context=""
            if command -v kubectl &> /dev/null; then
                context=$(KUBECONFIG="${config}" kubectl config current-context 2>/dev/null || echo "")
            fi

            if [ -n "${context}" ]; then
                echo "  ${GREEN}${cluster_name}${NC} - ${size} - Context: ${context}"
            else
                echo "  ${GREEN}${cluster_name}${NC} - ${size}"
            fi
        fi
    done

    if [ "${found}" = false ]; then
        echo "  ${YELLOW}No cluster configs found${NC}"
        echo "  ${YELLOW}Expected files: ${KUBE_DIR}/*${CONFIG_SUFFIX}${NC}"
    fi
}

use_cluster() {
    local cluster="${1:-}"
    if [ -z "${cluster}" ]; then
        echo -e "${RED}Error: Cluster name required${NC}" >&2
        echo "Usage: $0 use <cluster>" >&2
        return 1
    fi

    local config_path="${KUBE_DIR}/${cluster}${CONFIG_SUFFIX}"
    if [ ! -f "${config_path}" ]; then
        echo -e "${RED}Error: Config not found: ${config_path}${NC}" >&2
        echo "Available clusters:" >&2
        list_clusters >&2
        return 1
    fi

    # Use absolute path
    local abs_path
    abs_path=$(cd "$(dirname "${config_path}")" && pwd)/$(basename "${config_path}")

    export KUBECONFIG="${abs_path}"
    echo -e "${GREEN}Switched to cluster: ${cluster}${NC}"
    echo "KUBECONFIG: ${abs_path}"

    if command -v kubectl &> /dev/null; then
        local context
        context=$(kubectl config current-context 2>/dev/null || echo "unknown")
        echo "Current context: ${context}"

        # Test connection
        if kubectl cluster-info &> /dev/null; then
            echo -e "${GREEN}✓ Cluster is accessible${NC}"
        else
            echo -e "${YELLOW}⚠ Could not verify cluster connectivity${NC}"
        fi
    fi

    cat <<EOF

To make this permanent, add to your shell profile (~/.bashrc or ~/.zshrc):
  export KUBECONFIG="${abs_path}"

Or use relative path from project root:
  export KUBECONFIG="\$(cd ${PROJECT_ROOT} && pwd)/output/cluster-state/kubeconfigs/${cluster}${CONFIG_SUFFIX}"
EOF
}

merge_configs() {
    local output="${1:-${KUBE_DIR}/merged.kubeconfig}"

    if [ ! -d "${KUBE_DIR}" ]; then
        echo -e "${RED}Error: Kubeconfig directory not found: ${KUBE_DIR}${NC}" >&2
        return 1
    fi

    local configs=()
    for config in "${KUBE_DIR}"/*"${CONFIG_SUFFIX}"; do
        if [ -f "${config}" ]; then
            configs+=("${config}")
        fi
    done

    if [ ${#configs[@]} -eq 0 ]; then
        echo -e "${YELLOW}No cluster configs found to merge${NC}" >&2
        return 1
    fi

    echo "Merging ${#configs[@]} cluster config(s) into ${output}..."

    # Use KUBECONFIG environment variable to merge
    local old_kubeconfig="${KUBECONFIG:-}"
    local merged_config
    merged_config=$(IFS=':'; echo "${configs[*]}")
    export KUBECONFIG="${merged_config}"

    # Backup existing config if it exists
    if [ -f "${output}" ] && [ ! -f "${output}.backup" ]; then
        cp "${output}" "${output}.backup"
        echo "Backed up existing config to ${output}.backup"
    fi

    # Merge all configs
    kubectl config view --flatten > "${output}"

    # Restore original KUBECONFIG
    if [ -n "${old_kubeconfig}" ]; then
        export KUBECONFIG="${old_kubeconfig}"
    else
        unset KUBECONFIG
    fi

    local abs_output
    abs_output=$(cd "$(dirname "${output}")" && pwd)/$(basename "${output}")

    echo -e "${GREEN}✓ Merged configs into ${abs_output}${NC}"
    echo ""
    echo "Available contexts:"
    KUBECONFIG="${abs_output}" kubectl config get-contexts

    cat <<EOF

To use the merged config:
  export KUBECONFIG="${abs_output}"

To switch between clusters in merged config:
  KUBECONFIG="${abs_output}" kubectl config use-context <context-name>
EOF
}

show_current() {
    if command -v kubectl &> /dev/null; then
        local current_context
        current_context=$(kubectl config current-context 2>/dev/null || echo "none")

        if [ -n "${KUBECONFIG:-}" ]; then
            echo "KUBECONFIG: ${KUBECONFIG}"
        else
            echo "KUBECONFIG: ~/.kube/config (default)"
        fi

        echo "Current context: ${current_context}"

        if [ "${current_context}" != "none" ]; then
            echo ""
            echo "Cluster info:"
            kubectl cluster-info 2>/dev/null || echo "Could not connect to cluster"
        fi
    else
        echo -e "${RED}kubectl not found${NC}" >&2
        return 1
    fi
}

show_cluster() {
    local cluster="${1:-}"
    if [ -z "${cluster}" ]; then
        echo -e "${RED}Error: Cluster name required${NC}" >&2
        echo "Usage: $0 show <cluster>" >&2
        return 1
    fi

    local config_path="${KUBE_DIR}/${cluster}${CONFIG_SUFFIX}"
    if [ ! -f "${config_path}" ]; then
        echo -e "${RED}Error: Config not found: ${config_path}${NC}" >&2
        return 1
    fi

    local abs_path
    abs_path=$(cd "$(dirname "${config_path}")" && pwd)/$(basename "${config_path}")

    echo "Cluster: ${cluster}"
    echo "Config: ${abs_path}"
    echo "Size: $(du -h "${config_path}" | cut -f1)"
    echo ""

    if command -v kubectl &> /dev/null; then
        local old_kubeconfig="${KUBECONFIG:-}"
        export KUBECONFIG="${abs_path}"

        echo "Contexts:"
        kubectl config get-contexts

        echo ""
        echo "Cluster info:"
        kubectl cluster-info 2>/dev/null || echo "Could not connect to cluster"

        # Restore original KUBECONFIG
        if [ -n "${old_kubeconfig}" ]; then
            export KUBECONFIG="${old_kubeconfig}"
        else
            unset KUBECONFIG
        fi
    fi
}

set_default() {
    local cluster="${1:-}"
    if [ -z "${cluster}" ]; then
        echo -e "${RED}Error: Cluster name required${NC}" >&2
        echo "Usage: $0 set-default <cluster>" >&2
        return 1
    fi

    local config_path="${KUBE_DIR}/${cluster}${CONFIG_SUFFIX}"
    if [ ! -f "${config_path}" ]; then
        echo -e "${RED}Error: Config not found: ${config_path}${NC}" >&2
        return 1
    fi

    local default_config="${HOME}/.kube/config"

    # Ensure ~/.kube directory exists
    mkdir -p "${HOME}/.kube"

    # Backup existing default if it exists
    if [ -f "${default_config}" ] && [ ! -f "${default_config}.backup" ]; then
        cp "${default_config}" "${default_config}.backup"
        echo "Backed up existing default config to ${default_config}.backup"
    fi

    cp "${config_path}" "${default_config}"
    echo -e "${GREEN}✓ Set ${cluster} as default cluster${NC}"
    echo "Default kubeconfig: ${default_config}"

    if command -v kubectl &> /dev/null; then
        local old_kubeconfig="${KUBECONFIG:-}"
        unset KUBECONFIG
        local context
        context=$(kubectl config current-context 2>/dev/null || echo "")
        echo "Current context: ${context}"
        if [ -n "${old_kubeconfig}" ]; then
            export KUBECONFIG="${old_kubeconfig}"
        fi
    fi
}

# Main command dispatcher
main() {
    local command="${1:-help}"

    case "${command}" in
        list)
            list_clusters
            ;;
        use)
            use_cluster "${2:-}"
            ;;
        merge)
            merge_configs "${2:-}"
            ;;
        current)
            show_current
            ;;
        show)
            show_cluster "${2:-}"
            ;;
        set-default)
            set_default "${2:-}"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo -e "${RED}Unknown command: ${command}${NC}" >&2
            echo "" >&2
            usage >&2
            return 1
            ;;
    esac
}

main "$@"
