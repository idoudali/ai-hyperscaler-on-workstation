#!/bin/bash
# Helper script to run commands in the development Docker container
# Usage: ./scripts/run-in-dev-container.sh [command] [args...]

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Docker image settings (match Makefile)
IMAGE_NAME="pharos-dev"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# Get user/group IDs
USER_ID="$(id -u)"
GROUP_ID="$(id -g)"

# Get KVM and libvirt group IDs for hardware acceleration
KVM_GID=""
LIBVIRT_GID=""
DOCKER_EXTRA_ARGS=""

if command -v getent >/dev/null 2>&1; then
    KVM_GID="$(getent group kvm 2>/dev/null | cut -d: -f3 || echo "")"
    LIBVIRT_GID="$(getent group libvirt 2>/dev/null | cut -d: -f3 || echo "")"

    if [[ -n "$KVM_GID" && -c "/dev/kvm" ]]; then
        DOCKER_EXTRA_ARGS="$DOCKER_EXTRA_ARGS --device /dev/kvm --group-add $KVM_GID"
    fi

    if [[ -n "$LIBVIRT_GID" ]]; then
        DOCKER_EXTRA_ARGS="$DOCKER_EXTRA_ARGS --group-add $LIBVIRT_GID"
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
    COMMAND="/bin/bash"
    log_info "No command provided, starting interactive shell"
elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [command] [args...]"
    echo ""
    echo "Run commands in the pharos development Docker container."
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
    echo ""
    exit 0
else
    COMMAND="$*"
    log_info "Running command in container: $COMMAND"
fi

# Run the container with the same setup as the Makefile
# shellcheck disable=SC2086
if [[ $# -eq 0 ]]; then
    # For interactive shell, don't use /bin/bash -c
    exec docker run -it --rm \
        -v /etc/passwd:/etc/passwd:ro \
        -v /etc/group:/etc/group:ro \
        -v /etc/shadow:/etc/shadow:ro \
        -v /etc/sudoers:/etc/sudoers:ro \
        -v /etc/sudoers.d:/etc/sudoers.d:ro \
        -v "$PROJECT_ROOT":/workspace \
        -v "$HOME":"$HOME" \
        -e HOME="$HOME" \
        -e USER="$USER" \
        -e DISPLAY="${DISPLAY:-}" \
        -w /workspace \
        -u "$USER_ID:$GROUP_ID" \
        $DOCKER_EXTRA_ARGS \
        "$FULL_IMAGE_NAME" \
        /bin/bash
else
    # For commands, use /bin/bash -c to handle compound commands
    exec docker run -it --rm \
        -v /etc/passwd:/etc/passwd:ro \
        -v /etc/group:/etc/group:ro \
        -v /etc/shadow:/etc/shadow:ro \
        -v /etc/sudoers:/etc/sudoers:ro \
        -v /etc/sudoers.d:/etc/sudoers.d:ro \
        -v "$PROJECT_ROOT":/workspace \
        -v "$HOME":"$HOME" \
        -e HOME="$HOME" \
        -e USER="$USER" \
        -e DISPLAY="${DISPLAY:-}" \
        -w /workspace \
        -u "$USER_ID:$GROUP_ID" \
        $DOCKER_EXTRA_ARGS \
        "$FULL_IMAGE_NAME" \
        /bin/bash -c "${COMMAND}"
fi
