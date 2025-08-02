#!/bin/bash
# Setup script for commitizen and conventional commits

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Check for dependencies
if ! command -v python3 &> /dev/null || ! command -v pip3 &> /dev/null; then
    log_error "Python 3 and pip3 are required. Please install them first."
    exit 1
fi

# 2. Install Python packages
log_info "Installing commitizen and pre-commit..."
pip3 install --user commitizen pre-commit

# 3. Add ~/.local/bin to PATH if not already present
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    log_info "Adding ~/.local/bin to PATH for this session."
    export PATH="$HOME/.local/bin:$PATH"
    echo -e "${YELLOW}NOTE:${NC} To make this change permanent, add the following line to your ~/.bashrc or ~/.zshrc:"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# 4. Verify installation
if ! command -v cz &> /dev/null || ! command -v pre-commit &> /dev/null; then
    log_error "Installation failed. Could not find 'cz' or 'pre-commit' in PATH."
    exit 1
fi

# 5. Install pre-commit hooks
log_info "Installing pre-commit hooks..."
pre-commit install --hook-type pre-commit --hook-type commit-msg

log_info "Setup complete!"
log_info "You can now use 'cz commit' for interactive commits."
