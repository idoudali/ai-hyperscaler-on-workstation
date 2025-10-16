#!/bin/bash

# setup-host-dependencies.sh
# Ubuntu/Debian host dependencies setup script for Pharos AI Hyperscaler on Workstation
#
# This script installs all required system dependencies for the development environment
# including Docker CE (official repository), build tools, and modern Python tooling.
#
# Usage: ./setup-host-dependencies.sh [OPTIONS]
# Run with --help for more information.

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display help message
show_help() {
    cat << EOF
setup-host-dependencies.sh - Ubuntu/Debian Host Dependencies Setup

DESCRIPTION:
    This script installs system dependencies for the Pharos AI Hyperscaler on Workstation
    development environment. You can install all dependencies at once or select specific
    components to install.

USAGE:
    ./setup-host-dependencies.sh [OPTIONS]

OPTIONS:
    --help, -h          Show this help message and exit
    --all               Install all dependencies (default if no options specified)
    --packages          Install only system packages (build tools, Python, virtualization)
    --docker            Install only Docker CE
    --uv                Install only uv (Python package manager)
    --dry-run           Show what would be installed without making changes
    --check             Check current installation status

EXAMPLES:
    ./setup-host-dependencies.sh                    # Install everything
    ./setup-host-dependencies.sh --all              # Install everything
    ./setup-host-dependencies.sh --packages         # Install only system packages
    ./setup-host-dependencies.sh --docker           # Install only Docker CE
    ./setup-host-dependencies.sh --uv               # Install only uv
    ./setup-host-dependencies.sh --dry-run          # Preview what would be installed
    ./setup-host-dependencies.sh --check            # Check installation status

SYSTEM REQUIREMENTS:
    - Ubuntu 18.04+ or Debian 10+
    - sudo privileges
    - Internet connection

COMPONENTS INSTALLED:
    System Packages:
    - Build tools: build-essential, make, cmake, ninja-build
    - Version control: git
    - Python: python3, python3-dev, python3-pip, python3-venv
    - Virtualization: libvirt-dev, qemu-system-x86, qemu-utils
    - Network tools: curl, wget, ca-certificates

    Docker CE:
    - Official Docker Community Edition
    - Docker Compose plugin
    - Docker Buildx plugin
    - User added to docker group

    Python Tools:
    - uv: Modern Python package manager

EOF
}

# Function to check if running on Ubuntu/Debian
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS. This script is designed for Ubuntu/Debian systems."
        exit 1
    fi

    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log_error "This script is designed for Ubuntu/Debian. Detected: $ID"
        exit 1
    fi

    log_info "Detected OS: $PRETTY_NAME"
}

# Function to install necessary Debian packages
install_debian_packages() {
    log_info "Installing required system packages..."

    # Update package list
    log_info "Updating package list..."
    sudo apt-get update

    # Install essential packages
    log_info "Installing essential build and development tools..."
    sudo apt-get install -y \
        apt-transport-https \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        git \
        gnupg \
        libvirt-dev \
        lsb-release \
        make \
        ninja-build \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
        qemu-system-x86 \
        qemu-utils \
        software-properties-common \
        virtiofsd \
        wget

    log_info "System packages installed successfully."
}

# Function to install Docker CE on Ubuntu/Debian
install_docker() {
    log_info "Installing Docker CE (Community Edition)..."

    # Remove old versions if they exist
    log_info "Removing any existing Docker installations..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Set up Docker's official GPG key
    log_info "Setting up Docker repository..."
    sudo mkdir -p /etc/apt/keyrings

    # Detect OS ID for Docker repo (ubuntu or debian)
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DOCKER_OS_ID="$ID"
    else
        log_error "/etc/os-release not found. Cannot determine OS."
        return 1
    fi

    curl -fsSL "https://download.docker.com/linux/${DOCKER_OS_ID}/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DOCKER_OS_ID} \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    log_info "Installing Docker Engine..."
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker service
    log_info "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker

    # Add current user to docker group
    log_info "Adding user '${USER}' to docker group..."
    sudo usermod -aG docker "${USER}"

    # Verify Docker installation
    log_info "Verifying Docker installation..."
    if sudo docker run --rm hello-world > /dev/null 2>&1; then
        log_info "Docker installed and verified successfully."
    else
        log_error "Docker installation verification failed."
        return 1
    fi

    log_warn "You need to log out and back in (or restart) for docker group changes to take effect."
}

# Function to install uv (modern Python package manager)
install_uv() {
    log_info "Installing uv (modern Python package manager)..."

    # Check if uv is already installed
    if command -v uv &> /dev/null; then
        log_info "uv is already installed. Version: $(uv --version)"
        return 0
    fi

    # Install uv using the official installer
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Add uv to PATH for current session
    export PATH="$HOME/.cargo/bin:$PATH"

    # Verify installation
    if command -v uv &> /dev/null; then
        log_info "uv installed successfully. Version: $(uv --version)"
        log_info "uv has been installed to ~/.cargo/bin/uv"
        log_info "Make sure to add ~/.cargo/bin to your PATH or restart your shell."
    else
        log_error "uv installation failed or not found in PATH."
        return 1
    fi
}

# Function to check current installation status
check_installation() {
    log_info "Checking current installation status..."
    echo

    # Check system packages
    log_info "System Packages:"
    local packages=("make" "git" "cmake" "python3" "docker" "qemu-system-x86")
    for pkg in "${packages[@]}"; do
        if command -v "$pkg" &> /dev/null; then
            echo "  ✓ $pkg: $(command -v "$pkg")"
        else
            echo "  ✗ $pkg: Not installed"
        fi
    done

    # Check Python packages and tools
    echo
    log_info "Python Tools:"
    if command -v uv &> /dev/null; then
        echo "  ✓ uv: $(uv --version)"
    else
        echo "  ✗ uv: Not installed"
    fi

    # Check Docker status
    echo
    log_info "Docker Status:"
    if command -v docker &> /dev/null; then
        echo "  ✓ Docker: $(docker --version)"
        if docker ps &> /dev/null; then
            echo "  ✓ Docker daemon: Running"
            echo "  ✓ Docker permissions: User can access Docker"
        else
            echo "  ✗ Docker daemon: Not accessible (may need to restart or add user to docker group)"
        fi
    else
        echo "  ✗ Docker: Not installed"
    fi

    # Check virtualization tools
    echo
    log_info "Virtualization Tools:"
    if dpkg -l | grep -q libvirt-dev; then
        echo "  ✓ libvirt-dev: Installed"
    else
        echo "  ✗ libvirt-dev: Not installed"
    fi

    if command -v qemu-system-x86_64 &> /dev/null; then
        echo "  ✓ qemu-system-x86: Installed"
    else
        echo "  ✗ qemu-system-x86: Not installed"
    fi
}

# Function to show what would be installed (dry run)
show_dry_run() {
    log_info "Dry run - showing what would be installed..."
    echo

    log_info "System packages that would be installed:"
    echo "  - apt-transport-https"
    echo "  - build-essential"
    echo "  - ca-certificates"
    echo "  - cmake"
    echo "  - curl"
    echo "  - git"
    echo "  - gnupg"
    echo "  - libvirt-dev"
    echo "  - lsb-release"
    echo "  - make"
    echo "  - ninja-build"
    echo "  - python3"
    echo "  - python3-dev"
    echo "  - python3-pip"
    echo "  - python3-venv"
    echo "  - qemu-system-x86"
    echo "  - qemu-utils"
    echo "  - software-properties-common"
    echo "  - wget"
    echo

    log_info "Docker CE components that would be installed:"
    echo "  - Docker CE (Community Edition)"
    echo "  - Docker CLI"
    echo "  - containerd.io"
    echo "  - Docker Buildx plugin"
    echo "  - Docker Compose plugin"
    echo "  - User '${USER}' would be added to docker group"
    echo

    log_info "Python tools that would be installed:"
    echo "  - uv (modern Python package manager)"
    echo "  - Installed to ~/.cargo/bin/"
    echo

    log_info "Services that would be configured:"
    echo "  - Docker service would be started and enabled"
    echo

    log_warn "Note: This is a dry run. No actual changes would be made."
}

# Function to display post-installation instructions
show_post_install_info() {
    log_info "Installation completed successfully!"
    echo
    log_info "Next steps:"
    echo "  1. Log out and back in (or restart) to apply docker group changes"
    echo "  2. Ensure ~/.cargo/bin is in your PATH for uv:"
    echo "     echo 'export PATH=\"\$HOME/.cargo/bin:\$PATH\"' >> ~/.bashrc"
    echo "     source ~/.bashrc"
    echo "  3. Navigate to your project directory and run:"
    echo "     make build-docker    # Build development container"
    echo "     make venv-create     # Create Python virtual environment"
    echo
    log_info "Installed versions:"
    echo "  - Docker: $(docker --version 2>/dev/null || echo 'Docker not accessible (restart required)')"
    echo "  - Git: $(git --version)"
    echo "  - Make: $(make --version | head -1)"
    echo "  - CMake: $(cmake --version | head -1)"
    echo "  - Python: $(python3 --version)"
    echo "  - uv: $(uv --version 2>/dev/null || echo 'Not in current PATH')"
}

# Parse command line arguments
parse_args() {
    INSTALL_PACKAGES=false
    INSTALL_DOCKER=false
    INSTALL_UV=false
    DRY_RUN=false
    CHECK_ONLY=false

    # Default to installing everything if no specific options given
    if [[ $# -eq 0 ]]; then
        INSTALL_PACKAGES=true
        INSTALL_DOCKER=true
        INSTALL_UV=true
        return
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --all)
                INSTALL_PACKAGES=true
                INSTALL_DOCKER=true
                INSTALL_UV=true
                shift
                ;;
            --packages)
                INSTALL_PACKAGES=true
                shift
                ;;
            --docker)
                INSTALL_DOCKER=true
                shift
                ;;
            --uv)
                INSTALL_UV=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --check)
                CHECK_ONLY=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done
}

# Main execution function
main() {
    # Parse command line arguments
    parse_args "$@"

    # Handle special modes first
    if [[ "$CHECK_ONLY" == true ]]; then
        check_installation
        exit 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        show_dry_run
        exit 0
    fi

    # Normal installation flow
    log_info "Starting Ubuntu/Debian host dependencies setup..."
    echo

    # Check if running on supported OS
    check_os

    # Install components based on user selection
    if [[ "$INSTALL_PACKAGES" == true ]]; then
        install_debian_packages
        echo
    fi

    if [[ "$INSTALL_DOCKER" == true ]]; then
        install_docker
        echo
    fi

    if [[ "$INSTALL_UV" == true ]]; then
        install_uv
        echo
    fi

    # Show post-installation information if anything was installed
    if [[ "$INSTALL_PACKAGES" == true || "$INSTALL_DOCKER" == true || "$INSTALL_UV" == true ]]; then
        show_post_install_info
    else
        log_warn "No installation options selected. Use --help for usage information."
    fi
}

# Check if script is being sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
