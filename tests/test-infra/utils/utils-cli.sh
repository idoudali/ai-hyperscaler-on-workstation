#!/bin/bash
#
# Test Framework Utilities CLI
# Command-line interface for testing and debugging utility functions
#

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source all utility modules
source "$SCRIPT_DIR/log-utils.sh"
source "$SCRIPT_DIR/cluster-utils.sh"
source "$SCRIPT_DIR/vm-utils.sh"
source "$SCRIPT_DIR/test-framework-utils.sh"

# Set up environment variables
export PROJECT_ROOT
export TESTS_DIR="$PROJECT_ROOT/tests"
export SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
export SSH_USER="admin"
export CLEANUP_REQUIRED=false
export INTERACTIVE_CLEANUP=false
export TEST_NAME="utils-cli-test"

# Initialize logging
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
init_logging "$TIMESTAMP" "logs" "utils-cli"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help message
show_help() {
    cat << EOF
Test Framework Utilities CLI

USAGE:
    $0 [OPTIONS] [COMMAND] [ARGS...]

COMMANDS:
    vm-ip <vm-name>                    Get IP address for a VM
    vm-ips <config> [cluster-type]     Get IP addresses for cluster VMs
    vm-ssh <vm-ip> <vm-name>           Test SSH connectivity to VM
    vm-upload <vm-ip> <vm-name> <dir>  Upload scripts to VM
    vm-execute <vm-ip> <vm-name> <script>  Execute script on VM

    cluster-start <config>             Start cluster
    cluster-stop <config>              Stop cluster
    cluster-status <config>            Check cluster status
    cluster-plan <config>              Generate cluster plan
    cluster-vms <config>               List cluster VMs

    test-prereqs <config> <scripts-dir>  Check test prerequisites

    log-test <message>                 Test logging functions
    log-verbose-test <message>         Test verbose logging

    list-functions                     List all available functions
    list-vms                          List all running VMs
    list-networks                     List all virtual networks

    interactive                       Start interactive mode

OPTIONS:
    -h, --help        Show this help message
    -v, --verbose     Enable verbose output
    --no-color        Disable colored output

EXAMPLES:
    # Get VM IP
    $0 vm-ip test-hpc-monitoring-controller

    # Get cluster IPs
    $0 vm-ips tests/test-infra/configs/test-monitoring-stack.yaml

    # Test SSH connectivity
    $0 vm-ssh 192.168.200.10 test-hpc-monitoring-controller

    # Start cluster
    $0 cluster-start tests/test-infra/configs/test-monitoring-stack.yaml

    # Check cluster status
    $0 cluster-status tests/test-infra/configs/test-monitoring-stack.yaml

    # Interactive mode
    $0 interactive

EOF
}

# List all available functions
list_functions() {
    echo -e "${BLUE}Available Functions:${NC}"
    echo ""

    echo -e "${GREEN}VM Utilities:${NC}"
    echo "  get_vm_ip <vm_name>"
    echo "  get_vm_ips_for_cluster <config_file> [cluster_type] [target_vm_name]"
    echo "  get_vm_ips_for_cluster_legacy <cluster_pattern> [target_vm_name]"
    echo "  wait_for_vm_ssh <vm_ip> <vm_name> [timeout]"
    echo "  upload_scripts_to_vm <vm_ip> <vm_name> <scripts_dir> [remote_dir]"
    echo "  execute_script_on_vm <vm_ip> <vm_name> <script_name> [remote_dir] [extra_args]"
    echo "  save_vm_connection_info <cluster_name>"
    echo ""

    echo -e "${GREEN}Cluster Utilities:${NC}"
    echo "  resolve_test_config_path <test_config>"
    echo "  start_cluster <test_config> [cluster_name]"
    echo "  destroy_cluster <test_config> [cluster_name]"
    echo "  verify_cluster_cleanup <test_config> [cluster_name]"
    echo "  check_cluster_not_running <target_vm_pattern>"
    echo "  show_cleanup_instructions <test_config> [cluster_name]"
    echo "  wait_for_cluster_vms <test_config> <cluster_type> [timeout]"
    echo "  get_cluster_plan_data <config_file> <log_directory> [cluster_type]"
    echo "  parse_cluster_name <config_file> <log_directory> <cluster_type>"
    echo "  parse_expected_vms <config_file> <log_directory> <cluster_type>"
    echo "  get_vm_specifications <config_file> <log_directory> <cluster_type> [vm_name]"
    echo "  cleanup_cluster_on_exit <test_config> [cluster_name]"
    echo "  ask_manual_cleanup <test_config>"
    echo "  manual_cluster_cleanup <test_config>"
    echo ""

    echo -e "${GREEN}Test Framework Utilities:${NC}"
    echo "  provision_monitoring_stack_on_vms <cluster_pattern>"
    echo "  run_test_framework <test_config> <test_scripts_dir> <target_vm_pattern> <master_test_script>"
    echo "  check_test_prerequisites <test_config> <test_scripts_dir>"
    echo "  cleanup_test_framework <test_config> <test_scripts_dir> <target_vm_pattern> <master_test_script>"
    echo ""

    echo -e "${GREEN}Logging Utilities:${NC}"
    echo "  log <message>"
    echo "  log_success <message>"
    echo "  log_warning <message>"
    echo "  log_error <message>"
    echo "  log_info <message>"
    echo "  log_warn <message>"
    echo "  log_verbose <message>"
    echo "  init_logging <timestamp> <log_type> <test_name>"
    echo "  log_command <command> [description]"
    echo "  log_test_result <test_name> <result> [details]"
    echo "  create_log_summary"
    echo ""
}

# List all running VMs
list_vms() {
    echo -e "${BLUE}Running VMs:${NC}"
    virsh list --state-running --name | while read -r vm; do
        if [[ -n "$vm" ]]; then
            echo "  - $vm"
        fi
    done
    echo ""
}

# List all virtual networks
list_networks() {
    echo -e "${BLUE}Virtual Networks:${NC}"
    virsh net-list --all | while read -r line; do
        if [[ "$line" =~ ^[[:space:]]*[a-zA-Z] ]]; then
            echo "  $line"
        fi
    done
    echo ""
}

# Interactive mode
interactive_mode() {
    echo -e "${BLUE}Interactive Mode${NC}"
    echo "Type 'help' for available commands, 'exit' to quit"
    echo ""

    while true; do
        read -p "utils-cli> " -r input
        case $input in
            help|h)
                show_help
                ;;
            exit|quit|q)
                echo "Goodbye!"
                break
                ;;
            list-vms)
                list_vms
                ;;
            list-networks)
                list_networks
                ;;
            list-functions)
                list_functions
                ;;
            vm-ip)
                vm_name=$(echo "$input" | cut -d' ' -f2)
                if [[ -n "$vm_name" ]]; then
                    echo "Getting IP for VM: $vm_name"
                    if ip=$(get_vm_ip "$vm_name"); then
                        echo -e "${GREEN}IP: $ip${NC}"
                    else
                        echo -e "${RED}Failed to get IP${NC}"
                    fi
                else
                    echo -e "${RED}Usage: vm-ip <vm-name>${NC}"
                fi
                ;;
            vm-ips)
                config=$(echo "$input" | cut -d' ' -f2)
                cluster_type=$(echo "$input" | cut -d' ' -f3)
                if [[ -n "$config" ]]; then
                    echo "Getting IPs for cluster: $config"
                    if get_vm_ips_for_cluster "$config" "${cluster_type:-hpc}"; then
                        echo -e "${GREEN}Found ${#VM_IPS[@]} VMs${NC}"
                        for i in "${!VM_IPS[@]}"; do
                            echo "  ${VM_NAMES[$i]}: ${VM_IPS[$i]}"
                        done
                    else
                        echo -e "${RED}Failed to get cluster IPs${NC}"
                    fi
                else
                    echo -e "${RED}Usage: vm-ips <config> [cluster-type]${NC}"
                fi
                ;;
            cluster-status*)
                config=$(echo "$input" | cut -d' ' -f2)
                if [[ -n "$config" ]]; then
                    echo "Checking cluster status: $config"
                    if check_cluster_status >/dev/null 2>&1; then
                        echo -e "${GREEN}Cluster is running${NC}"
                    else
                        echo -e "${RED}Cluster is not running${NC}"
                    fi
                else
                    echo -e "${RED}Usage: cluster-status <config>${NC}"
                fi
                ;;
            *)
                if [[ -n "$input" ]]; then
                    echo -e "${RED}Unknown command: $input${NC}"
                    echo "Type 'help' for available commands"
                fi
                ;;
        esac
    done
}

# Main command processing
process_command() {
    local command="$1"
    shift || true

    case "$command" in
        "help"|"-h"|"--help")
            show_help
            ;;
        "vm-ip")
            local vm_name="$1"
            [[ -z "$vm_name" ]] && { echo -e "${RED}Error: VM name required${NC}"; exit 1; }
            echo "Getting IP for VM: $vm_name"
            if ip=$(get_vm_ip "$vm_name"); then
                echo -e "${GREEN}IP: $ip${NC}"
            else
                echo -e "${RED}Failed to get IP${NC}"
                exit 1
            fi
            ;;
        "vm-ips")
            local config="$1"
            local cluster_type="${2:-hpc}"
            [[ -z "$config" ]] && { echo -e "${RED}Error: Config file required${NC}"; exit 1; }
            echo "Getting IPs for cluster: $config"
            if get_vm_ips_for_cluster "$config" "$cluster_type"; then
                echo -e "${GREEN}Found ${#VM_IPS[@]} VMs${NC}"
                for i in "${!VM_IPS[@]}"; do
                    echo "  ${VM_NAMES[$i]}: ${VM_IPS[$i]}"
                done
            else
                echo -e "${RED}Failed to get cluster IPs${NC}"
                exit 1
            fi
            ;;
        "vm-ssh")
            local vm_ip="$1"
            local vm_name="$2"
            [[ -z "$vm_ip" || -z "$vm_name" ]] && { echo -e "${RED}Error: VM IP and name required${NC}"; exit 1; }
            echo "Testing SSH connectivity to $vm_name ($vm_ip)"
            if wait_for_vm_ssh "$vm_ip" "$vm_name"; then
                echo -e "${GREEN}SSH connectivity successful${NC}"
            else
                echo -e "${RED}SSH connectivity failed${NC}"
                exit 1
            fi
            ;;
        "vm-upload")
            local vm_ip="$1"
            local vm_name="$2"
            local scripts_dir="$3"
            [[ -z "$vm_ip" || -z "$vm_name" || -z "$scripts_dir" ]] && { echo -e "${RED}Error: VM IP, name, and scripts directory required${NC}"; exit 1; }
            echo "Uploading scripts to $vm_name ($vm_ip)"
            if upload_scripts_to_vm "$vm_ip" "$vm_name" "$scripts_dir"; then
                echo -e "${GREEN}Scripts uploaded successfully${NC}"
            else
                echo -e "${RED}Script upload failed${NC}"
                exit 1
            fi
            ;;
        "vm-execute")
            local vm_ip="$1"
            local vm_name="$2"
            local script_name="$3"
            [[ -z "$vm_ip" || -z "$vm_name" || -z "$script_name" ]] && { echo -e "${RED}Error: VM IP, name, and script name required${NC}"; exit 1; }
            echo "Executing script on $vm_name ($vm_ip): $script_name"
            if execute_script_on_vm "$vm_ip" "$vm_name" "$script_name"; then
                echo -e "${GREEN}Script executed successfully${NC}"
            else
                echo -e "${RED}Script execution failed${NC}"
                exit 1
            fi
            ;;
        "cluster-start")
            local config="$1"
            [[ -z "$config" ]] && { echo -e "${RED}Error: Config file required${NC}"; exit 1; }
            echo "Starting cluster: $config"
            if start_cluster "$config"; then
                echo -e "${GREEN}Cluster started successfully${NC}"
            else
                echo -e "${RED}Cluster start failed${NC}"
                exit 1
            fi
            ;;
        "cluster-stop")
            local config="$1"
            [[ -z "$config" ]] && { echo -e "${RED}Error: Config file required${NC}"; exit 1; }
            echo "Stopping cluster: $config"
            if destroy_cluster "$config"; then
                echo -e "${GREEN}Cluster stopped successfully${NC}"
            else
                echo -e "${RED}Cluster stop failed${NC}"
                exit 1
            fi
            ;;
        "cluster-status")
            local config="$1"
            [[ -z "$config" ]] && { echo -e "${RED}Error: Config file required${NC}"; exit 1; }
            echo "Checking cluster status: $config"
            if check_cluster_status >/dev/null 2>&1; then
                echo -e "${GREEN}Cluster is running${NC}"
            else
                echo -e "${RED}Cluster is not running${NC}"
                exit 1
            fi
            ;;
        "cluster-plan")
            local config="$1"
            [[ -z "$config" ]] && { echo -e "${RED}Error: Config file required${NC}"; exit 1; }
            echo "Generating cluster plan: $config"
            if plan_file=$(get_cluster_plan_data "$config" "$LOG_DIR" "hpc"); then
                echo -e "${GREEN}Cluster plan generated: $plan_file${NC}"
                cat "$plan_file"
            else
                echo -e "${RED}Cluster plan generation failed${NC}"
                exit 1
            fi
            ;;
        "cluster-vms")
            local config="$1"
            [[ -z "$config" ]] && { echo -e "${RED}Error: Config file required${NC}"; exit 1; }
            echo "Listing cluster VMs: $config"
            if vms=$(parse_expected_vms "$config" "$LOG_DIR" "hpc"); then
                echo -e "${GREEN}Expected VMs: $vms${NC}"
            else
                echo -e "${RED}Failed to get expected VMs${NC}"
                exit 1
            fi
            ;;
        "test-prereqs")
            local config="$1"
            local scripts_dir="$2"
            [[ -z "$config" || -z "$scripts_dir" ]] && { echo -e "${RED}Error: Config file and scripts directory required${NC}"; exit 1; }
            echo "Checking test prerequisites: $config"
            if check_test_prerequisites "$config" "$scripts_dir"; then
                echo -e "${GREEN}Prerequisites check passed${NC}"
            else
                echo -e "${RED}Prerequisites check failed${NC}"
                exit 1
            fi
            ;;
        "log-test")
            local message="$1"
            [[ -z "$message" ]] && { echo -e "${RED}Error: Message required${NC}"; exit 1; }
            echo "Testing logging functions:"
            log "Log: $message"
            log_success "Success: $message"
            log_warning "Warning: $message"
            log_error "Error: $message"
            log_info "Info: $message"
            log_warn "Warn: $message"
            log_verbose "Verbose: $message"
            ;;
        "log-verbose-test")
            local message="$1"
            [[ -z "$message" ]] && { echo -e "${RED}Error: Message required${NC}"; exit 1; }
            echo "Testing verbose logging:"
            log_verbose "Verbose message: $message"
            ;;
        "list-functions")
            list_functions
            ;;
        "list-vms")
            list_vms
            ;;
        "list-networks")
            list_networks
            ;;
        "interactive")
            interactive_mode
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Parse command line arguments
NO_COLOR=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            # VERBOSE flag is handled by the calling script
            shift
            ;;
        --no-color)
            NO_COLOR=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Disable colors if requested
if [[ "$NO_COLOR" == "true" ]]; then
    RED=""
    GREEN=""
    BLUE=""
    NC=""
fi

# Process the command
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

process_command "$@"
