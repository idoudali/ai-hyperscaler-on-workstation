#!/bin/bash
# Entrypoint script for the AI-HOW development Docker container
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

    # Check if user already exists by UID
    local existing_user
    existing_user=$(getent passwd "$user_id" 2>/dev/null | cut -d: -f1 || echo "")

    if [[ -n "$existing_user" ]]; then
        log_info "User with UID $user_id already exists: $existing_user"
        username="$existing_user"
        # Update home directory if it was changed
        home_dir=$(getent passwd "$user_id" 2>/dev/null | cut -d: -f6 || echo "$home_dir")
    else
        log_info "Creating user $username with UID $user_id"

        # Create group if it doesn't exist
        # Check by GID first, then by name
        local existing_group
        existing_group=$(getent group "$group_id" 2>/dev/null | cut -d: -f1 || echo "")

        if [[ -z "$existing_group" ]]; then
            # Try to find group by name
            existing_group=$(getent group "$username" 2>/dev/null | cut -d: -f1 || echo "")
        fi

        if [[ -z "$existing_group" ]]; then
            log_info "Creating group $username with GID $group_id"
            if ! groupadd -g "$group_id" "$username" 2>/dev/null; then
                log_warn "Failed to create group with groupadd, trying alternative name"
                # Try with a different name if username conflicts
                if ! groupadd -g "$group_id" "gid${group_id}" 2>/dev/null; then
                    log_error "Failed to create group with GID $group_id"
                    # Continue anyway - useradd will create a group or use existing one
                else
                    existing_group="gid${group_id}"
                    log_info "Created group with alternative name: $existing_group"
                fi
            else
                existing_group="$username"
            fi
        else
            log_info "Group already exists: $existing_group (GID: $group_id)"
        fi

        # Verify group exists by GID before creating user
        # useradd will create the group if it doesn't exist when using -g with GID
        if ! getent group "$group_id" >/dev/null 2>&1; then
            log_warn "Group $group_id does not exist, useradd will create it or use default"
        fi

        # Create user with explicit GID
        log_info "Creating user $username with UID $user_id and GID $group_id"
        if ! useradd -u "$user_id" -g "$group_id" -d "$home_dir" -s /bin/bash -m "$username" 2>/dev/null; then
            log_warn "Failed to create user with useradd, trying alternative approach"
            # Alternative: create user without home directory first, then create home
            if ! useradd -u "$user_id" -g "$group_id" -d "$home_dir" -s /bin/bash -M "$username" 2>/dev/null; then
                log_warn "User creation failed, checking if user exists with different name"
                # Try to get the username by UID in case it was created
                existing_user=$(getent passwd "$user_id" 2>/dev/null | cut -d: -f1 || echo "")
                if [[ -n "$existing_user" ]]; then
                    username="$existing_user"
                    log_info "Found existing user: $username"
                else
                    log_error "Failed to create user $username with UID $user_id"
                    exit 1
                fi
            fi
        fi

        # Verify the user was created with correct GID
        local actual_gid
        actual_gid=$(id -g "$user_id" 2>/dev/null || echo "")
        if [[ -n "$actual_gid" && "$actual_gid" != "$group_id" ]]; then
            log_warn "User GID mismatch: expected $group_id, got $actual_gid. Attempting to fix..."
            # Try to change the primary group
            usermod -g "$group_id" "$username" 2>/dev/null || {
                log_warn "Could not change primary group, but continuing"
            }
        fi
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
    local common_dirs=(".ssh" ".cache" ".cache/cargo" ".local" ".config")
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

# Configure Cargo to use cache directory
export CARGO_HOME="$HOME/.cache/cargo"
export PATH="$CARGO_HOME/bin:/usr/local/cargo/bin:$PATH"

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

# Function to create a group if it doesn't exist or fix its GID
# Returns: 0 on success (outputs group name to stdout), 1 on failure
create_group_if_needed() {
    local group_name="$1"
    local group_gid="$2"
    local effective_group_name="$group_name"

    if [[ -z "$group_gid" ]]; then
        return 1
    fi

    # Check if group exists by name
    local existing_gid
    existing_gid=$(getent group "$group_name" 2>/dev/null | cut -d: -f3 || echo "")

    if [[ -n "$existing_gid" ]]; then
        if [[ "$existing_gid" == "$group_gid" ]]; then
            log_info "Group $group_name already exists with correct GID $group_gid"
            echo "$effective_group_name"
            return 0
        else
            log_warn "Group $group_name exists with GID $existing_gid, but we need GID $group_gid"
            # Check if the target GID is already taken by another group
            if getent group "$group_gid" >/dev/null 2>&1; then
                local conflicting_name
                conflicting_name=$(getent group "$group_gid" | cut -d: -f1)
                log_info "GID $group_gid is already used by group $conflicting_name, will use existing group"
                echo "$conflicting_name"
                return 0
            else
                # Create new group with suffix "_2" and the desired GID
                log_info "Creating group ${group_name}_2 with GID $group_gid"
                effective_group_name="${group_name}_2"
                # At this point, we know target GID is not taken (checked above),
                # so we can proceed directly to creating the group
            fi
        fi
    fi

    # Create the group if it doesn't exist
    if ! getent group "$effective_group_name" >/dev/null 2>&1; then
        log_info "Creating group $effective_group_name with GID $group_gid"
        if groupadd -g "$group_gid" "$effective_group_name" 2>/dev/null; then
            log_info "Successfully created group $effective_group_name (GID: $group_gid)"
        else
            log_warn "Failed to create group $effective_group_name with GID $group_gid"
            return 1
        fi
    fi

    echo "$effective_group_name"
    return 0
}

# Function to handle group additions
setup_groups() {
    local user_id="$1"
    local username="$2"

    # Create groups from environment variables if provided
    # These groups are needed for Docker-in-Docker, KVM, and libvirt access
    if [[ -n "${DOCKER_GID:-}" ]]; then
        if docker_group=$(create_group_if_needed "docker" "$DOCKER_GID") && [[ -n "$docker_group" ]]; then
            log_info "Adding $username to $docker_group group (GID: $DOCKER_GID)"
            usermod -a -G "$docker_group" "$username" 2>/dev/null || log_warn "Could not add $username to $docker_group group"
        fi
    fi

    if [[ -n "${KVM_GID:-}" ]]; then
        if kvm_group=$(create_group_if_needed "kvm" "$KVM_GID") && [[ -n "$kvm_group" ]]; then
            log_info "Adding $username to $kvm_group group (GID: $KVM_GID)"
            usermod -a -G "$kvm_group" "$username" 2>/dev/null || log_warn "Could not add $username to $kvm_group group"
        fi
    fi

    if [[ -n "${LIBVIRT_GID:-}" ]]; then
        if libvirt_group=$(create_group_if_needed "libvirt" "$LIBVIRT_GID") && [[ -n "$libvirt_group" ]]; then
            log_info "Adding $username to $libvirt_group group (GID: $LIBVIRT_GID)"
            usermod -a -G "$libvirt_group" "$username" 2>/dev/null || log_warn "Could not add $username to $libvirt_group group"
        fi
    fi

    # Add user to additional groups if they exist (like sudo)
    local additional_groups=("sudo")
    for group in "${additional_groups[@]}"; do
        if getent group "$group" >/dev/null 2>&1; then
            local group_id
            group_id=$(getent group "$group" | cut -d: -f3)
            log_info "Adding $username to group $group (GID: $group_id)"
            if ! usermod -a -G "$group" "$username" 2>/dev/null; then
                log_warn "Could not add $username to group $group"
            fi
        fi
    done
}

# Main entrypoint logic
main() {
    log_info "Starting AI-HOW development container entrypoint"

    # Get user and group information from environment variables
    local user_id="${USER_ID:-1000}"
    local group_id="${GROUP_ID:-1000}"
    local username="${USER:-user}"
    local home_dir="${HOME:-/home/$username}"

    # Only run user setup if we're not running as root
    if [[ "$user_id" != "0" ]]; then
        setup_user "$user_id" "$group_id" "$username" "$home_dir"
        setup_groups "$user_id" "$username"

        # Get the actual username after setup (in case user already existed with different name)
        # This handles the case where /etc/passwd is mounted and user exists with different name
        # Note: username may be updated here to match the actual username found in the system,
        # which is why we capture it again after setup_user
        local actual_username
        if actual_username=$(getent passwd "$user_id" 2>/dev/null | cut -d: -f1); then
            username="$actual_username"
            log_info "Using existing username: $username"
        fi
    else
        log_warn "Running as root, skipping user setup"
    fi

    # Set up environment variables for the user
    export CARGO_HOME="$home_dir/.cache/cargo"
    export PATH="$CARGO_HOME/bin:/usr/local/cargo/bin:/opt/venv/bin:$PATH"

    # Switch to the user if not already running as them
    # Use UID instead of username for gosu to avoid lookup issues with mounted passwd
    if [[ "$(id -u)" != "$user_id" ]]; then
        log_info "Switching to user $username (UID: $user_id)"
        # gosu supports numeric UID, which is more reliable when passwd is mounted
        exec gosu "$user_id" env CARGO_HOME="$CARGO_HOME" PATH="$PATH" USER="$username" HOME="$home_dir" "$@"
    else
        log_info "Already running as target user, executing command"
        exec "$@"
    fi
}

# Run main function with all arguments
main "$@"
