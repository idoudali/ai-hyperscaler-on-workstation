#!/bin/bash
# Helper script to run commands in the development Docker container
# Usage: ./scripts/run-in-dev-container.sh [command] [args...]

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Docker image settings (match Makefile)
IMAGE_NAME="ai-how-dev"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# Get user/group IDs
USER_ID="$(id -u)"
GROUP_ID="$(id -g)"

# Get KVM, libvirt, sudo, and docker group IDs for hardware acceleration, sudo access, and Docker socket access
KVM_GID=""
LIBVIRT_GID=""
SUDO_GID=""
DOCKER_GID=""
DOCKER_EXTRA_ARGS=""
NETWORK_MODE=""

# Check for network mode environment variable
if [[ -n "${DOCKER_NETWORK_MODE:-}" ]]; then
    NETWORK_MODE="--network ${DOCKER_NETWORK_MODE}"
fi

# Get group IDs for docker, kvm, and libvirt
# These will be passed as environment variables to the container
# The entrypoint will create the groups and add the user to them
if command -v getent >/dev/null 2>&1; then
    KVM_GID="$(getent group kvm 2>/dev/null | cut -d: -f3 || echo "")"
    LIBVIRT_GID="$(getent group libvirt 2>/dev/null | cut -d: -f3 || echo "")"
    SUDO_GID="$(getent group sudo 2>/dev/null | cut -d: -f3 || echo "")"
    DOCKER_GID="$(getent group docker 2>/dev/null | cut -d: -f3 || echo "")"

    # Add groups via --group-add for immediate access
    # The entrypoint will also create named groups for better compatibility
    if [[ -n "$KVM_GID" && -c "/dev/kvm" ]]; then
        DOCKER_EXTRA_ARGS="$DOCKER_EXTRA_ARGS --device /dev/kvm --group-add $KVM_GID"
    fi

    if [[ -n "$LIBVIRT_GID" ]]; then
        DOCKER_EXTRA_ARGS="$DOCKER_EXTRA_ARGS --group-add $LIBVIRT_GID"
    fi

    if [[ -n "$SUDO_GID" ]]; then
        DOCKER_EXTRA_ARGS="$DOCKER_EXTRA_ARGS --group-add $SUDO_GID"
    fi

    # Add docker group if it exists (for Docker-in-Docker functionality)
    if [[ -n "$DOCKER_GID" ]]; then
        DOCKER_EXTRA_ARGS="$DOCKER_EXTRA_ARGS --group-add $DOCKER_GID"
    fi
fi

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[CONTAINER]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[CONTAINER]${NC} $1"; }
log_error() { echo -e "${RED}[CONTAINER]${NC} $1"; }

# Helper function to build environment variable arguments for docker run
# This makes the docker run commands more readable and maintainable
build_env_args() {
    local env_args=""

    # Add optional group IDs if they exist
    if [[ -n "${DOCKER_GID:-}" ]]; then
        env_args="$env_args -e DOCKER_GID=$DOCKER_GID"
    fi

    if [[ -n "${KVM_GID:-}" ]]; then
        env_args="$env_args -e KVM_GID=$KVM_GID"
    fi

    if [[ -n "${LIBVIRT_GID:-}" ]]; then
        env_args="$env_args -e LIBVIRT_GID=$LIBVIRT_GID"
    fi

    echo "$env_args"
}

# Mount Docker socket for Docker-in-Docker functionality, gated by explicit opt-in
# Set DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 to enable mounting the Docker socket
# WARNING: Mounting the Docker socket grants full control of the host Docker daemon
if [[ "${DEV_CONTAINER_ENABLE_DOCKER_SOCKET:-}" == "1" || "${DEV_CONTAINER_ENABLE_DOCKER_SOCKET:-}" == "true" ]]; then
    # Require explicit confirmation unless DEV_CONTAINER_DOCKER_SOCKET_CONFIRM=1
    docker_socket_mounted="no"
    if [[ "${DEV_CONTAINER_DOCKER_SOCKET_CONFIRM:-}" == "1" ]]; then
        docker_socket_mounted="yes"
    else
        log_warn "You are about to mount the Docker socket into the container, which grants full control of the host Docker daemon and can be a severe security risk."
        read -r -p "Are you sure you want to continue? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            docker_socket_mounted="yes"
        else
            log_info "Docker socket will NOT be mounted. Confirmation not given."
        fi
    fi

    if [[ "$docker_socket_mounted" == "yes" ]]; then
        if [[ -S "/var/run/docker.sock" ]]; then
            DOCKER_EXTRA_ARGS="$DOCKER_EXTRA_ARGS -v /var/run/docker.sock:/var/run/docker.sock"
            log_info "Docker socket will be mounted for Docker-in-Docker functionality (explicit opt-in and confirmation enabled)"
        elif [[ -f "/var/run/docker.sock" ]]; then
            # Socket might exist but not be a socket file (e.g., symlink)
            DOCKER_EXTRA_ARGS="$DOCKER_EXTRA_ARGS -v /var/run/docker.sock:/var/run/docker.sock"
            log_info "Docker socket will be mounted for Docker-in-Docker functionality (explicit opt-in and confirmation enabled)"
        else
            log_warn "Docker socket not found at /var/run/docker.sock, Docker-in-Docker will not be available"
        fi
    fi
else
    log_info "Docker socket will NOT be mounted (disabled by default for security). Set DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 to enable Docker-in-Docker functionality."
fi

# Function to check if a path is on an NFS filesystem
# Returns 0 if path is on NFS, 1 otherwise
is_nfs_path() {
    local path="$1"
    local fs_type=""

    # Resolve the path to its real location
    local real_path
    real_path="$(readlink -f "$path" 2>/dev/null || echo "$path")"

    # Method 1: Use findmnt (preferred, most reliable)
    if command -v findmnt >/dev/null 2>&1; then
        fs_type="$(findmnt -n -o FSTYPE "$real_path" 2>/dev/null || echo "")"
        if [[ -n "$fs_type" ]]; then
            # Check for NFS variants (nfs, nfs4, nfs3)
            if [[ "$fs_type" =~ ^nfs ]]; then
                return 0
            fi
            return 1
        fi
    fi

    # Method 2: Use df -T as fallback
    if command -v df >/dev/null 2>&1; then
        fs_type="$(df -T "$real_path" 2>/dev/null | awk 'NR==2 {print $2}' || echo "")"
        if [[ -n "$fs_type" ]]; then
            if [[ "$fs_type" =~ ^nfs ]]; then
                return 0
            fi
            return 1
        fi
    fi

    # Method 3: Check /proc/mounts as last resort
    if [[ -f /proc/mounts ]]; then
        # Find the most specific (longest) mount point that contains this path
        local best_match=""
        local best_match_fs=""

        # Use read with proper field separation to handle mount points with spaces
        # Note: device is intentionally unused, we only need mount_point and mount_fs
        while read -r _device mount_point mount_fs rest; do
            # Check if path starts with this mount point
            # Use longest match to find the most specific mount point
            if [[ "$real_path" == "$mount_point"* ]] && [[ ${#mount_point} -gt ${#best_match} ]]; then
                best_match="$mount_point"
                best_match_fs="$mount_fs"
            fi
        done < /proc/mounts

        # Check if the best match is NFS
        if [[ -n "$best_match" ]] && [[ "$best_match_fs" =~ ^nfs ]]; then
            return 0
        fi
    fi

    # If we can't determine, assume it's not NFS (safer for Docker)
    return 1
}

# Function to build list of directories to mount, filtering out NFS directories
build_mount_list() {
    # Initialize arrays for mount arguments and skipped directories
    DOCKER_VOLUME_MOUNTS=()
    SKIPPED_NFS_PATHS=()

    # Define all potential mount points with their descriptions
    # Format: "description:host_path:container_path"
    local mount_candidates=(
        "PROJECT_ROOT:$PROJECT_ROOT:$PROJECT_ROOT"
        "HOME/.cache:$HOME/.cache:$HOME/.cache"
        "HOME/.config:$HOME/.config:$HOME/.config"
    )

    log_info "Checking mount paths for NFS filesystems..."

    # Process each mount candidate
    for candidate in "${mount_candidates[@]}"; do
        IFS=':' read -r description host_path container_path <<< "$candidate"

        # Skip if host path doesn't exist
        if [[ ! -e "$host_path" ]]; then
            log_warn "Skipping $description ($host_path): path does not exist"
            continue
        fi

        # Check if path is on NFS
        if is_nfs_path "$host_path"; then
            log_warn "Skipping $description ($host_path): on NFS filesystem (not supported by Docker)"
            SKIPPED_NFS_PATHS+=("$description: $host_path")
        else
            # Add to mount list
            DOCKER_VOLUME_MOUNTS+=("-v" "$host_path:$container_path")
            log_info "Will mount $description: $host_path -> $container_path"
        fi
    done

    # Report summary
    if [[ ${#SKIPPED_NFS_PATHS[@]} -gt 0 ]]; then
        log_warn ""
        log_warn "The following paths are on NFS and will not be mounted:"
        for path_info in "${SKIPPED_NFS_PATHS[@]}"; do
            log_warn "  - $path_info"
        done
        log_warn ""
        log_warn "Note: Docker does not support mounting NFS filesystems directly."
        log_warn "The container will run without these mounts."
        log_warn ""
    fi

    # Always set HOME environment variable, even if we can't mount it
    # This is needed for the entrypoint script
    if is_nfs_path "$HOME"; then
        log_warn "HOME directory is on NFS, using container's home directory instead"
        # Use a default home in the container
        DOCKER_HOME_ENV="/home/$USER"
    else
        DOCKER_HOME_ENV="$HOME"
    fi

    # Set working directory
    # If PROJECT_ROOT is on NFS and not mounted, use a default directory
    if is_nfs_path "$PROJECT_ROOT"; then
        log_warn ""
        log_warn "WARNING: PROJECT_ROOT ($PROJECT_ROOT) is on an NFS filesystem!"
        log_warn "The project directory will not be accessible inside the container."
        log_warn "Using /tmp as working directory instead."
        log_warn "Consider moving the project to a local filesystem or using a different approach."
        log_warn ""
        DOCKER_WORKING_DIR="/tmp"
    else
        DOCKER_WORKING_DIR="$PROJECT_ROOT"
    fi
}

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker daemon is not running or not accessible"
    exit 1
fi

# Build list of directories to mount (filtering out NFS directories)
build_mount_list

# Validate that we have at least one mount (PROJECT_ROOT is critical)
if [[ ${#DOCKER_VOLUME_MOUNTS[@]} -eq 0 ]]; then
    log_error "No directories could be mounted (all paths may be on NFS)"
    log_error "Cannot continue without mounting at least PROJECT_ROOT"
    exit 1
fi

# Check if image exists
if ! docker image inspect "$FULL_IMAGE_NAME" >/dev/null 2>&1; then
    log_warn "Docker image '$FULL_IMAGE_NAME' not found"
    log_info "Building Docker image..."

    if [[ -f "$PROJECT_ROOT/Makefile" ]]; then
        cd "$PROJECT_ROOT"
        if ! make build-docker; then
            log_error "Failed to build Docker image"
            exit 1
        fi
    else
        log_error "Cannot build image: Makefile not found in $PROJECT_ROOT"
        exit 1
    fi
fi

# Handle help and default command
if [[ $# -eq 0 ]]; then
    # No command provided, will start interactive shell
    log_info "No command provided, starting interactive shell"
elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [command] [args...]"
    echo ""
    echo "Run commands in the AI-HOW development Docker container."
    echo ""
    echo "Examples:"
    echo "  $0                                                    # Start interactive shell"
    echo "  $0 cmake --build build --target build-hpc-image      # Build HPC base image"
    echo "  $0 cmake --build build --target build-cloud-image    # Build cloud base image"
    echo "  $0 python3 --version                                 # Run python in container"
    echo ""
    echo "The container provides:"
    echo "  - Isolated build environment"
    echo "  - KVM and libvirt access for virtualization"
    echo "  - All development tools and dependencies"
    echo "  - Automatic user and home directory setup"
    echo "  - Proper file permissions and ownership"
    echo ""
    exit 0
else
    # Store original arguments for proper passing to docker
    # Don't concatenate into COMMAND to preserve argument boundaries
    log_info "Running command in container: $*"
fi

# Build environment arguments
ENV_ARGS=$(build_env_args)

# Enable debug output to show the Docker command being executed
set -x

# Run the container with the same setup as the Makefile
# shellcheck disable=SC2086
if [[ $# -eq 0 ]]; then
    # For interactive shell, pass user info via environment variables
    # Note: We don't mount /etc/passwd, /etc/group, etc. because the entrypoint creates users/groups
    exec docker run -it --rm \
        "${DOCKER_VOLUME_MOUNTS[@]}" \
        -e HOME="$DOCKER_HOME_ENV" \
        -e USER="$USER" \
        -e USER_ID="$USER_ID" \
        -e GROUP_ID="$GROUP_ID" \
        $ENV_ARGS \
        -e DISPLAY="${DISPLAY:-}" \
        -w "$DOCKER_WORKING_DIR" \
        $NETWORK_MODE \
        $DOCKER_EXTRA_ARGS \
        "$FULL_IMAGE_NAME" \
        /bin/bash
else
    # For commands, pass user info via environment variables
    # Note: We don't mount /etc/passwd, /etc/group, etc. because the entrypoint creates users/groups
    # Use "$@" to preserve argument boundaries and quoting
    exec docker run --rm \
        "${DOCKER_VOLUME_MOUNTS[@]}" \
        -e HOME="$DOCKER_HOME_ENV" \
        -e USER="$USER" \
        -e USER_ID="$USER_ID" \
        -e GROUP_ID="$GROUP_ID" \
        $ENV_ARGS \
        -e DISPLAY="${DISPLAY:-}" \
        -w "$DOCKER_WORKING_DIR" \
        $NETWORK_MODE \
        $DOCKER_EXTRA_ARGS \
        "$FULL_IMAGE_NAME" \
        "$@"
fi
