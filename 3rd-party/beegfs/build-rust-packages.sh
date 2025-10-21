#!/bin/bash
# BeeGFS Rust Debian Package Build Script
#
# This script replicates the Debian packaging logic from the beegfs-rust Makefile,
# building only .deb packages (RPM packaging is excluded).
#
# Original Makefile Reference:
# https://github.com/ThinkParQ/beegfs-rust/blob/main/Makefile
#
# Usage:
#   ./build-rust-packages.sh [PACKAGE_DIR] [VERSION]
#
# Arguments:
#   PACKAGE_DIR - Directory where packages will be output (default: target/package)
#   VERSION     - Version string for packages (default: extracted from git tags)

set -euo pipefail

# Configuration
PACKAGE_DIR="${1:-target/package}"
VERSION="${2:-}"
TARGET_DIR="target/release"
BIN_UTIL_PREFIX="${BIN_UTIL_PREFIX:-}"
VERBOSE="${VERBOSE:-0}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Determine version if not provided
if [[ -z "$VERSION" ]]; then
    if git describe --tags --match 'v*.*.*' &>/dev/null; then
        V=$(git describe --tags --match 'v*.*.*' | sed 's/\-/~/g')
        VERSION="${V#v}"
    else
        log_error "Could not determine version from git tags"
        exit 1
    fi
fi

VERSION_TRIMMED="$VERSION"
log_info "Building BeeGFS Rust Management Service packages (version: $VERSION_TRIMMED)"

# Create target and package directories
mkdir -p "$TARGET_DIR"
mkdir -p "$PACKAGE_DIR"

# Step 1: Build thirdparty license summary
log_info "Generating third-party license summary..."
if ! cargo about generate about.hbs --all-features -o "$TARGET_DIR/thirdparty-licenses.html"; then
    log_error "Failed to generate license summary"
    exit 1
fi

# Step 2: Clean and build the binary
log_info "Cleaning previous mgmtd builds..."
cargo clean --locked --release -p mgmtd

log_info "Building mgmtd in release mode..."
if [[ "$VERBOSE" == "1" ]]; then
    cargo build --locked --release -p mgmtd -p sqlite_check
else
    cargo build --locked --release -p mgmtd -p sqlite_check 2>&1 | grep -E "(Compiling|Finished|error|warning:)"
fi

# Step 3: Post-process binaries (debug symbols and strip)
log_info "Post-processing binaries..."
if ! "${BIN_UTIL_PREFIX}objcopy" --only-keep-debug \
    "$TARGET_DIR/beegfs-mgmtd" "$TARGET_DIR/beegfs-mgmtd.debug"; then
    log_warn "Failed to extract debug symbols, continuing..."
fi

if ! "${BIN_UTIL_PREFIX}strip" -s "$TARGET_DIR/beegfs-mgmtd"; then
    log_error "Failed to strip binary"
    exit 1
fi

# Step 4: Build Debian packages
log_info "Building Debian packages..."

# Build standard package
log_info "Building standard mgmtd package..."
cargo deb --locked --no-build -p mgmtd -o "$PACKAGE_DIR/" \
    --deb-version="20:$VERSION_TRIMMED"

# Build debug package
log_info "Building debug mgmtd package..."
cargo deb --locked --no-build -p mgmtd -o "$PACKAGE_DIR/" --variant=debug \
    --deb-version="20:$VERSION_TRIMMED"

# Step 5: Rename files to remove epoch from filenames
# BeeGFS uses epoch 20 in version but doesn't want it in filenames
log_info "Renaming packages to remove epoch from filenames..."
find "$PACKAGE_DIR" -name "*_20:*.deb" -type f | while read -r file; do
    newname="${file//_20:/_}"
    if [[ "$file" != "$newname" ]]; then
        log_info "Renaming: $(basename "$file") -> $(basename "$newname")"
        mv "$file" "$newname"
    fi
done

# Step 6: Replace tilde in package filename with hyphens
# GitHub release action substitutes tilde (~) with dot (.) when uploaded
log_info "Replacing tildes with hyphens in package filenames..."
find "$PACKAGE_DIR/" -type f -name "*~*.deb" | while read -r file; do
    newname="${file//\~/-}"
    if [[ "$file" != "$newname" ]]; then
        log_info "Renaming: $(basename "$file") -> $(basename "$newname")"
        mv "$file" "$newname"
    fi
done

# Step 7: List built packages
log_info "Successfully built packages:"
find "$PACKAGE_DIR" -name "*.deb" -type f -exec ls -lh {} \; | awk '{print "  - " $9 " (" $5 ")"}'

log_info "Build complete! Packages are in: $PACKAGE_DIR"
