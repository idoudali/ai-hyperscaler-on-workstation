#!/bin/bash
# Virtio-FS configuration validation test script
# Part of Task 027: Implement Virtio-FS Host Directory Sharing

set -euo pipefail

# Initialize logging and colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

LOG_FILE="${LOG_DIR:-/tmp}/virtio-fs-config-test.log"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# =============================================================================
# VIRTIO-FS CONFIGURATION TESTS
# =============================================================================

test_required_packages() {
    log_info "Testing required packages installation..."

    local packages=("fuse3" "util-linux")
    local missing_packages=()

    for package in "${packages[@]}"; do
        if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
            log_success "Package $package is installed"
        else
            missing_packages+=("$package")
            log_warning "Package $package is not installed"
        fi
    done

    if [ ${#missing_packages[@]} -eq 0 ]; then
        log_success "All required packages are installed"
        return 0
    else
        log_error "Missing packages: ${missing_packages[*]}"
        return 1
    fi
}

test_virtiofs_kernel_module() {
    log_info "Testing virtiofs kernel module availability..."

    # Check if virtiofs is registered as a filesystem (built-in or module)
    if grep -q "virtiofs" /proc/filesystems 2>/dev/null; then
        log_success "virtiofs filesystem is available (registered in /proc/filesystems)"

        # Try to get module info if it's a loadable module
        if modinfo virtiofs >/dev/null 2>&1; then
            log_success "virtiofs is available as a loadable kernel module"

            # Get module info
            local module_info
            module_info=$(modinfo virtiofs 2>/dev/null | grep -E "^(filename|version|description):" || echo "No detailed info available")
            log_info "Module info:"
            echo "$module_info" | tee -a "$LOG_FILE"

            # Check if module is loaded
            if lsmod | grep -q "virtiofs"; then
                log_success "virtiofs kernel module is loaded"
            else
                log_info "virtiofs kernel module exists but is not loaded (may be built-in)"
            fi
        else
            log_info "virtiofs is built into the kernel (not a loadable module)"
        fi

        return 0
    else
        log_error "virtiofs filesystem is not available"
        log_error "Ensure kernel version >= 5.4 with virtiofs support"
        return 1
    fi
}

test_fuse_configuration() {
    log_info "Testing FUSE configuration..."

    # Check if /dev/fuse exists
    if [ -c "/dev/fuse" ]; then
        log_success "/dev/fuse character device exists"

        # Check permissions
        local perms
        perms=$(stat -c "%a" /dev/fuse)
        log_info "/dev/fuse permissions: $perms"

        if [ "$perms" = "666" ]; then
            log_success "/dev/fuse has correct permissions"
        else
            log_warning "/dev/fuse permissions may not be optimal"
        fi
    else
        log_error "/dev/fuse device does not exist"
        return 1
    fi

    # Check if fuse module is loaded
    if lsmod | grep -q "^fuse\s"; then
        log_success "fuse kernel module is loaded"
    else
        log_warning "fuse kernel module is not loaded"
    fi

    return 0
}

test_mount_point_directories() {
    log_info "Testing mount point directories..."

    local common_mount_points=(
        "/mnt/host-datasets"
        "/mnt/host-containers"
    )

    local failed=0

    for mount_point in "${common_mount_points[@]}"; do
        if [ -d "$mount_point" ]; then
            log_success "Mount point directory $mount_point exists"

            # Check ownership
            local owner
            owner=$(stat -c "%U:%G" "$mount_point")
            log_info "Directory $mount_point ownership: $owner"

            # Check permissions
            local perms
            perms=$(stat -c "%a" "$mount_point")
            log_info "Directory $mount_point permissions: $perms"
        else
            log_warning "Mount point directory $mount_point does not exist (may be created during mount)"
        fi
    done

    return $failed
}

test_fstab_configuration() {
    log_info "Testing /etc/fstab configuration..."

    if [ -f "/etc/fstab" ]; then
        log_success "/etc/fstab file exists"

        # Check for virtiofs entries
        local virtiofs_entries
        virtiofs_entries=$(grep -c "virtiofs" /etc/fstab 2>/dev/null || echo "0")

        if [ "$virtiofs_entries" -gt 0 ]; then
            log_success "Found $virtiofs_entries virtiofs entries in /etc/fstab"
            log_info "Virtiofs entries:"
            grep "virtiofs" /etc/fstab | tee -a "$LOG_FILE"
        else
            log_warning "No virtiofs entries found in /etc/fstab"
        fi

        return 0
    else
        log_error "/etc/fstab file does not exist"
        return 1
    fi
}

test_virtio_pci_devices() {
    log_info "Testing for virtio PCI devices..."

    # Check for virtio devices in lspci
    local virtio_devices
    virtio_devices=$(lspci | grep -ci "virtio")

    if [ "$virtio_devices" -gt 0 ]; then
        log_success "Found $virtio_devices virtio PCI devices"
        log_info "Virtio devices:"
        lspci | grep -i "virtio" | tee -a "$LOG_FILE"
    else
        log_warning "No virtio PCI devices found (expected if no virtio-fs mounts configured)"
    fi

    return 0
}

test_system_capabilities() {
    log_info "Testing system capabilities for virtio-fs..."

    # Check kernel version
    local kernel_version
    kernel_version=$(uname -r)
    log_info "Kernel version: $kernel_version"

    # Extract major and minor version
    local kernel_major
    local kernel_minor
    kernel_major=$(echo "$kernel_version" | cut -d. -f1)
    kernel_minor=$(echo "$kernel_version" | cut -d. -f2)

    # Virtiofs requires kernel >= 5.4
    if [ "$kernel_major" -gt 5 ] || { [ "$kernel_major" -eq 5 ] && [ "$kernel_minor" -ge 4 ]; }; then
        log_success "Kernel version supports virtiofs (>= 5.4 required)"
    else
        log_error "Kernel version too old for virtiofs support (>= 5.4 required)"
        return 1
    fi

    # Check available filesystem types
    if grep -q "virtiofs" /proc/filesystems 2>/dev/null; then
        log_success "virtiofs filesystem type is registered"
    else
        log_warning "virtiofs filesystem type not found in /proc/filesystems"
    fi

    return 0
}

test_mount_helper_availability() {
    log_info "Testing mount helper availability..."

    # Check if mount.virtiofs exists
    if command -v mount.virtiofs >/dev/null 2>&1; then
        log_success "mount.virtiofs helper is available"

        local mount_helper_path
        mount_helper_path=$(command -v mount.virtiofs)
        log_info "mount.virtiofs location: $mount_helper_path"
    else
        log_info "mount.virtiofs helper not found (not required for basic mounting)"
    fi

    # Check mount command
    if command -v mount >/dev/null 2>&1; then
        log_success "mount command is available"

        local mount_version
        mount_version=$(mount --version 2>&1 | head -1)
        log_info "mount version: $mount_version"
    else
        log_error "mount command is not available"
        return 1
    fi

    return 0
}

# =============================================================================
# MAIN TEST EXECUTION
# =============================================================================

main() {
    log_info "=== Starting Virtio-FS Configuration Tests ==="
    log_info "Log file: $LOG_FILE"

    local failed_tests=()

    # Configuration tests
    log_info ""
    log_info "=== CONFIGURATION VALIDATION TESTS ==="
    test_required_packages || failed_tests+=("required_packages")
    test_virtiofs_kernel_module || failed_tests+=("virtiofs_kernel_module")
    test_fuse_configuration || failed_tests+=("fuse_configuration")
    test_mount_point_directories || failed_tests+=("mount_point_directories")
    test_fstab_configuration || failed_tests+=("fstab_configuration")
    test_virtio_pci_devices || failed_tests+=("virtio_pci_devices")
    test_system_capabilities || failed_tests+=("system_capabilities")
    test_mount_helper_availability || failed_tests+=("mount_helper_availability")

    # Summary
    log_info ""
    log_info "=== CONFIGURATION TEST SUMMARY ==="
    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_success "All virtio-fs configuration tests passed!"
        log_info "System is properly configured for virtio-fs mounts"
        exit 0
    else
        log_error "Failed tests: ${failed_tests[*]}"
        log_error "Check the log file for details: $LOG_FILE"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
