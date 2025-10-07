#!/bin/bash
# Entrypoint script for the pharos development Docker container
# Handles user creation and home directory setup
#
# Environment variables:
#   ENTRYPOINT_VERBOSE - Set to "false" to disable log messages (default: "true")
#   USER_ID - User ID to create/use (default: 1000)
#   GROUP_ID - Group ID to create/use (default: 1000)
#   USER - Username to create/use (default: "user")
#   HOME - Home directory path (default: "/home/$USER")

set -euo pipefail

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Control logging verbosity (set to "false" to disable messages)
ENTRYPOINT_VERBOSE="${ENTRYPOINT_VERBOSE:-false}"

log_info() {
    if [[ "$ENTRYPOINT_VERBOSE" == "true" ]]; then
        echo -e "${GREEN}[ENTRYPOINT]${NC} $1"
    fi
}
log_warn() {
    if [[ "$ENTRYPOINT_VERBOSE" == "true" ]]; then
        echo -e "${YELLOW}[ENTRYPOINT]${NC} $1"
    fi
}
log_error() {
    if [[ "$ENTRYPOINT_VERBOSE" == "true" ]]; then
        echo -e "${RED}[ENTRYPOINT]${NC} $1"
    fi
}

# Function to create user and home directory
setup_user() {
    local user_id="$1"
    local group_id="$2"
    local username="${3:-user}"
    local home_dir="${4:-/home/$username}"

    log_info "Setting up user: $username (UID: $user_id, GID: $group_id)"

    # Check if user already exists
    if ! getent passwd "$user_id" >/dev/null 2>&1; then
        log_info "Creating user $username with UID $user_id"

        # Create group if it doesn't exist
        if ! getent group "$group_id" >/dev/null 2>&1; then
            groupadd -g "$group_id" "$username" 2>/dev/null || true
        fi

        # Create user
        useradd -u "$user_id" -g "$group_id" -d "$home_dir" -s /bin/bash -m "$username" 2>/dev/null || {
            log_warn "Failed to create user with useradd, trying alternative approach"
            # Alternative: create user without home directory first, then create home
            useradd -u "$user_id" -g "$group_id" -d "$home_dir" -s /bin/bash -M "$username" 2>/dev/null || true
        }
    else
        log_info "User with UID $user_id already exists"
        username=$(getent passwd "$user_id" | cut -d: -f1)
    fi

    # Ensure home directory exists and has correct permissions
    if [[ ! -d "$home_dir" ]]; then
        log_info "Creating home directory: $home_dir"
        mkdir -p "$home_dir"
    fi

    # Set ownership of home directory (this must succeed)
    if ! chown -R "$user_id:$group_id" "$home_dir"; then
        log_error "Failed to set ownership of $home_dir"
        exit 1
    fi

    # Set proper permissions
    chmod 755 "$home_dir" 2>/dev/null || true

    # Create common directories in home
    local common_dirs=(".ssh" ".cache" ".local" ".config")
    for dir in "${common_dirs[@]}"; do
        local full_path="$home_dir/$dir"
        if [[ ! -d "$full_path" ]]; then
            mkdir -p "$full_path"
            chown "$user_id:$group_id" "$full_path"
            chmod 700 "$full_path"
        fi
    done

    # Set up basic shell configuration if it doesn't exist
    local bashrc="$home_dir/.bashrc"
    if [[ ! -f "$bashrc" ]]; then
        log_info "Creating basic .bashrc for $username"
        cat > "$bashrc" << 'EOF'
# Basic bash configuration for container user
export PS1='\u@\h:\w\$ '
export PATH="/opt/venv/bin:$PATH"

# Enable color support
if [[ -x /usr/bin/dircolors ]]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Common aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF
        chown "$user_id:$group_id" "$bashrc"
    fi

    log_info "User setup completed for $username"
}

# Function to handle group additions
setup_groups() {
    local user_id="$1"
    local username="$2"

    # Add user to additional groups if they exist
    # Docker group is particularly important for Docker socket access
    local additional_groups=("kvm" "libvirt" "sudo" "docker")

    for group in "${additional_groups[@]}"; do
        if getent group "$group" >/dev/null 2>&1; then
            local group_id
            group_id=$(getent group "$group" | cut -d: -f3)
            log_info "Adding $username to group $group (GID: $group_id)"
            if ! usermod -a -G "$group" "$username" 2>/dev/null; then
                log_warn "Could not add $username to group $group"
            fi
        else
            log_warn "Group $group does not exist in container, skipping"
        fi
    done
}

# Main entrypoint logic
main() {
    log_info "Starting pharos development container entrypoint"

    # Get user and group information from environment variables
    local user_id="${USER_ID:-1000}"
    local group_id="${GROUP_ID:-1000}"
    local username="${USER:-user}"
    local home_dir="${HOME:-/home/$username}"

    # Only run user setup if we're not running as root
    if [[ "$user_id" != "0" ]]; then
        setup_user "$user_id" "$group_id" "$username" "$home_dir"
        setup_groups "$user_id" "$username"
    else
        log_warn "Running as root, skipping user setup"
    fi

    # Switch to the user if not already running as them
    if [[ "$(id -u)" != "$user_id" ]]; then
        log_info "Switching to user $username (UID: $user_id)"
        exec gosu "$username" "$@"
    else
        log_info "Already running as target user, executing command"
        exec "$@"
    fi
}

# Run main function with all arguments
main "$@"
