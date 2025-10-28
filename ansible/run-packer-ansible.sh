#!/bin/bash
#
# Packer Ansible Replication Script
# This script replicates the Ansible execution that happens during Packer builds
# for the HPC base image, allowing you to run the same steps on a live VM
#
# Usage:
#   ./run-packer-ansible.sh [target_host]
#   ./run-packer-ansible.sh localhost
#   ./run-packer-ansible.sh 192.168.1.100
#
# =============================================================================
# CONFIGURATION
# =============================================================================

set -euo pipefail

# Default configuration
TARGET_HOST="${1:-localhost}"
ROLE="${2:-all}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="${REPO_DIR}/ansible"
SSH_USERNAME="${SSH_USERNAME:-debian}"
SSH_PORT="${SSH_PORT:-22}"
SSH_KEY="${SSH_KEY:-${REPO_DIR}/build/shared/ssh-keys/id_rsa}"
VERBOSE="${VERBOSE:-true}"
LOGGING_LEVEL="${LOGGING_LEVEL:--vvv}"

# Available roles
AVAILABLE_ROLES=("base-packages" "container-runtime" "nvidia-gpu-drivers" "slurm-controller")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking requirements..."

    # Check if ansible is available
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "ansible-playbook not found. Please install Ansible first:"
        log_error "  pip install ansible"
        exit 1
    fi

    # Check if target host is reachable
    if [[ "$TARGET_HOST" != "localhost" ]]; then
        if ! ping -c 1 -W 5 "$TARGET_HOST" &> /dev/null; then
            log_warning "Cannot ping $TARGET_HOST. Continuing anyway..."
        fi
    fi

    # Check if playbook exists
    if [[ ! -f "${ANSIBLE_DIR}/playbooks/playbook-hpc-runtime.yml" ]]; then
        log_error "HPC runtime playbook not found: ${ANSIBLE_DIR}/playbooks/playbook-hpc-runtime.yml"
        exit 1
    fi

    # Check if SSH key exists
    if [[ ! -f "$SSH_KEY" ]]; then
        log_error "SSH key not found: $SSH_KEY"
        log_error "Please ensure the SSH key exists or set SSH_KEY environment variable"
        exit 1
    fi

    # Check if role is valid
    if [[ "$ROLE" != "all" ]]; then
        local valid_role=false
        for available_role in "${AVAILABLE_ROLES[@]}"; do
            if [[ "$ROLE" == "$available_role" ]]; then
                valid_role=true
                break
            fi
        done

        if [[ "$valid_role" == false ]]; then
            log_error "Invalid role: $ROLE"
            log_error "Available roles: all, ${AVAILABLE_ROLES[*]}"
            exit 1
        fi
    fi

    log_success "Requirements check passed"
}

create_inventory() {
    local inventory_file="${ANSIBLE_DIR}/inventories/temp_packer_inventory"

    cat > "$inventory_file" << EOF
[all]
${TARGET_HOST} ansible_user=${SSH_USERNAME} ansible_port=${SSH_PORT} ansible_ssh_private_key_file=${SSH_KEY} ansible_python_interpreter=/usr/bin/python3

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ansible_become=true
ansible_become_method=sudo
EOF

    echo "$inventory_file"
}

run_ansible_playbook() {
    local inventory_file="$1"

    log_info "Running Ansible playbook with Packer configuration..."
    log_info "Target host: $TARGET_HOST"
    log_info "Role: $ROLE"
    log_info "SSH user: $SSH_USERNAME"
    log_info "SSH port: $SSH_PORT"
    log_info "SSH key: $SSH_KEY"
    log_info "Repository: $REPO_DIR"

    # Set up environment variables (matching Packer configuration)
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_SSH_ARGS='-o ForwardAgent=yes -o ControlMaster=auto -o ControlPersist=60s'
    export ANSIBLE_ROLES_PATH="${ANSIBLE_DIR}/roles"
    export ANSIBLE_BECOME_FLAGS='-H -S -n'
    export ANSIBLE_SCP_IF_SSH=True
    export ANSIBLE_SCP_EXTRA_ARGS='-O'
    export ANSIBLE_REMOTE_TMP=/tmp

    # Build ansible-playbook command
    local ansible_cmd=(
        ansible-playbook
        -i "$inventory_file"
        "${ANSIBLE_DIR}/playbooks/playbook-hpc-runtime.yml"
        -u "$SSH_USERNAME"
        --extra-vars "ansible_python_interpreter=/usr/bin/python3"
        --extra-vars '{"packer_build":true}'
        --extra-vars '{"nvidia_install_cuda":false}'
        --extra-vars "target_hosts=all"
        --become
        --become-user=root
        "${LOGGING_LEVEL}"
    )

    # Add role selection if specific role is requested
    if [[ "$ROLE" != "all" ]]; then
        ansible_cmd+=(--tags "$ROLE")
        log_info "Running only role: $ROLE"
    else
        log_info "Running all roles: ${AVAILABLE_ROLES[*]}"
    fi

    # Execute the playbook
    log_info "Executing: ${ansible_cmd[*]}"
    echo

    if "${ansible_cmd[@]}"; then
        log_success "Ansible playbook completed successfully"
        return 0
    else
        log_error "Ansible playbook failed"
        return 1
    fi
}

cleanup() {
    local inventory_file="$1"

    if [[ -f "$inventory_file" ]]; then
        log_info "Cleaning up temporary inventory file..."
        rm -f "$inventory_file"
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [target_host] [role] [options]

ARGUMENTS:
  target_host    Target host to run Ansible against (default: localhost)
  role           Role to execute (default: all)
                 Available roles: all, base-packages, container-runtime, nvidia-gpu-drivers, slurm-controller

OPTIONS:
  SSH_USERNAME   SSH username to use (default: debian)
  SSH_PORT       SSH port to use (default: 22)
  SSH_KEY        SSH private key file to use (default: REPO_DIR/build/shared/ssh-keys/id_rsa)
  VERBOSE        Enable verbose output (default: true)

EXAMPLES:
  $0                                    # Run all roles on localhost
  $0 localhost                          # Run all roles on localhost explicitly
  $0 localhost base-packages            # Run only base-packages role on localhost
  $0 localhost container-runtime        # Run only container-runtime role on localhost
  $0 localhost nvidia-gpu-drivers       # Run only nvidia-gpu-drivers role on localhost
  $0 localhost slurm-controller         # Run only slurm-controller role on localhost
  $0 192.168.1.100 base-packages       # Run specific role on specific IP
  $0 vm-host slurm-controller           # Run specific role on specific hostname
  SSH_USERNAME=ubuntu $0 localhost base-packages         # Use different SSH user
  SSH_PORT=2222 $0 localhost nvidia-gpu-drivers          # Use custom SSH port
  SSH_KEY=/path/to/key $0 localhost container-runtime    # Use custom SSH key
  SSH_USERNAME=ubuntu SSH_PORT=2222 SSH_KEY=/path/to/key $0 192.168.1.100 base-packages  # Use custom user, port, and key
  VERBOSE=false $0 localhost all        # Disable verbose output

DESCRIPTION:
  This script replicates the Ansible execution that happens during Packer builds
  for the HPC base image. It runs the same playbook with the same configuration
  that Packer uses, allowing you to test or apply the same changes to a live VM.

  The script can run all roles or a specific role:
  - base-packages: Install HPC base packages (tmux, htop, vim, curl, wget)
  - container-runtime: Install Apptainer container runtime
  - nvidia-gpu-drivers: Install NVIDIA GPU drivers (without CUDA)
  - slurm-controller: Install SLURM controller packages (slurm-wlm, slurmdbd, munge, mariadb, pmix)
  - all: Run all roles (default behavior)

  This is useful for:
  - Testing specific role changes before rebuilding Packer images
  - Applying only specific components to existing VMs
  - Debugging individual Ansible role issues
  - Updating VMs with specific packages without running everything
  - Testing role dependencies and interactions

EOF
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Handle help flag
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi

    log_info "Starting Packer Ansible replication script"
    log_info "Repository directory: $REPO_DIR"
    log_info "Ansible directory: $ANSIBLE_DIR"
    log_info "Target: $TARGET_HOST:$SSH_PORT (user: $SSH_USERNAME, key: $SSH_KEY)"
    log_info "Role: $ROLE"

    # Change to ansible directory
    cd "$ANSIBLE_DIR"

    # Check requirements
    check_requirements

    # Create temporary inventory
    log_info "Creating temporary inventory file..."
    local inventory_file
    inventory_file=$(create_inventory)
    log_info "Created temporary inventory file: $inventory_file"

    # Set up cleanup trap
    # shellcheck disable=SC2064
    trap "cleanup ${inventory_file}" EXIT

    # Run the playbook
    if run_ansible_playbook "$inventory_file"; then
        if [[ "$ROLE" == "all" ]]; then
            log_success "Packer Ansible replication completed successfully!"
            log_info "The VM now has the same packages and configuration as a Packer-built image"
            log_info "Installed components: HPC packages, container runtime, NVIDIA drivers, SLURM controller"
            log_info "Run validation tests: cd tests && make test test-slurm-controller"
            log_info "Note: A reboot may be required for NVIDIA drivers to become active"
        else
            log_success "Role '$ROLE' executed successfully!"
            log_info "The VM now has the '$ROLE' role applied with Packer build settings"
            if [[ "$ROLE" == "nvidia-gpu-drivers" ]]; then
                log_info "Note: A reboot may be required for NVIDIA drivers to become active"
            elif [[ "$ROLE" == "slurm-controller" ]]; then
                log_info "SLURM controller packages installed: slurm-wlm, slurmdbd, munge, mariadb, pmix"
                log_info "Run validation tests: cd tests && make test-slurm-controller"
                log_info "Note: Additional configuration (TASK-011, TASK-012, TASK-013) needed for full SLURM setup"
            fi
        fi
    else
        log_error "Packer Ansible replication failed"
        exit 1
    fi
}

# Run main function
main "$@"
