#!/bin/bash
# Virtio-FS mount functionality validation test script
# Part of Task 027: Implement Virtio-FS Host Directory Sharing

set -euo pipefail

# Initialize logging and colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

LOG_FILE="${LOG_DIR:-/tmp}/virtio-fs-mount-test.log"

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
# VIRTIO-FS MOUNT FUNCTIONALITY TESTS
# =============================================================================

test_mounted_filesystems() {
    log_info "Testing for mounted virtiofs filesystems..."

    # Check mount output
    local virtiofs_mounts
    virtiofs_mounts=$(mount | grep -c "type virtiofs" || echo "0")

    if [ "$virtiofs_mounts" -gt 0 ]; then
        log_success "Found $virtiofs_mounts mounted virtiofs filesystems"
        log_info "Mounted filesystems:"
        mount | grep "type virtiofs" | tee -a "$LOG_FILE"
        return 0
    else
        log_warning "No virtiofs filesystems are currently mounted"
        return 1
    fi
}

test_mount_point_accessibility() {
    log_info "Testing mount point accessibility..."

    # Get list of virtiofs mounts
    local mount_points
    mapfile -t mount_points < <(mount | grep "type virtiofs" | awk '{print $3}')

    if [ ${#mount_points[@]} -eq 0 ]; then
        log_warning "No virtiofs mount points found to test"
        return 1
    fi

    local failed=0

    for mount_point in "${mount_points[@]}"; do
        if [ -d "$mount_point" ]; then
            log_success "Mount point $mount_point is accessible"

            # Check if we can list directory contents
            if ls -la "$mount_point" >/dev/null 2>&1; then
                log_success "Can list directory contents of $mount_point"
            else
                log_error "Cannot list directory contents of $mount_point"
                failed=1
            fi

            # Check mount point status
            if mountpoint -q "$mount_point"; then
                log_success "$mount_point is properly mounted"
            else
                log_error "$mount_point is not properly mounted"
                failed=1
            fi
        else
            log_error "Mount point $mount_point is not accessible"
            failed=1
        fi
    done

    return $failed
}

test_read_operations() {
    log_info "Testing read operations on mounted filesystems..."

    # Get list of virtiofs mounts
    local mount_points
    mapfile -t mount_points < <(mount | grep "type virtiofs" | awk '{print $3}')

    if [ ${#mount_points[@]} -eq 0 ]; then
        log_warning "No virtiofs mount points found to test"
        return 1
    fi

    local failed=0

    for mount_point in "${mount_points[@]}"; do
        log_info "Testing read operations on $mount_point..."

        # Try to read directory contents
        if ls -la "$mount_point" >/dev/null 2>&1; then
            local file_count
            file_count=$(find "$mount_point" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
            log_success "Successfully read directory contents ($file_count items)"

            # If there are files, try to read one
            local first_file
            first_file=$(find "$mount_point" -type f -readable 2>/dev/null | head -1)
            if [ -n "$first_file" ]; then
                if cat "$first_file" >/dev/null 2>&1; then
                    log_success "Successfully read file: $first_file"
                else
                    log_warning "Could not read file: $first_file"
                fi
            else
                log_info "No readable files found in $mount_point"
            fi
        else
            log_error "Failed to read directory contents of $mount_point"
            failed=1
        fi
    done

    return $failed
}

test_write_operations() {
    log_info "Testing write operations on mounted filesystems..."

    # Get list of virtiofs mounts
    local mount_points
    mapfile -t mount_points < <(mount | grep "type virtiofs" | awk '{print $3}')

    if [ ${#mount_points[@]} -eq 0 ]; then
        log_warning "No virtiofs mount points found to test"
        return 1
    fi

    local failed=0

    for mount_point in "${mount_points[@]}"; do
        # Check if mount is read-only
        if mount | grep "$mount_point" | grep -q "ro,"; then
            log_info "$mount_point is mounted read-only, skipping write tests"
            continue
        fi

        log_info "Testing write operations on $mount_point..."

        # Create test file
        local test_file="$mount_point/.virtio-fs-write-test-$$"

        # Try to create a file
        if echo "test" > "$test_file" 2>/dev/null; then
            log_success "Successfully created test file: $test_file"

            # Try to read it back
            if [ -f "$test_file" ] && [ "$(cat "$test_file")" = "test" ]; then
                log_success "Successfully read back test file contents"
            else
                log_error "Failed to read back test file contents"
                failed=1
            fi

            # Try to delete it
            if rm "$test_file" 2>/dev/null; then
                log_success "Successfully deleted test file"
            else
                log_error "Failed to delete test file"
                failed=1
            fi
        else
            log_warning "Cannot write to $mount_point (may be read-only or permission denied)"
        fi
    done

    return $failed
}

test_mount_options() {
    log_info "Testing mount options..."

    # Get list of virtiofs mounts
    local mount_info
    mount_info=$(mount | grep "type virtiofs")

    if [ -z "$mount_info" ]; then
        log_warning "No virtiofs mounts found to test"
        return 1
    fi

    log_info "Current virtiofs mount options:"
    echo "$mount_info" | while IFS= read -r line; do
        log_info "  $line"
    done | tee -a "$LOG_FILE"

    # Check for recommended options
    local has_relatime
    has_relatime=$(echo "$mount_info" | grep -c "relatime" || echo "0")

    if [ "$has_relatime" -gt 0 ]; then
        log_success "relatime option is enabled (good for performance)"
    else
        log_info "relatime option not found in mount options"
    fi

    return 0
}

test_filesystem_stats() {
    log_info "Testing filesystem statistics..."

    # Get list of virtiofs mounts
    local mount_points
    mapfile -t mount_points < <(mount | grep "type virtiofs" | awk '{print $3}')

    if [ ${#mount_points[@]} -eq 0 ]; then
        log_warning "No virtiofs mount points found to test"
        return 1
    fi

    local failed=0

    for mount_point in "${mount_points[@]}"; do
        log_info "Getting statistics for $mount_point..."

        # Run df command
        if df -h "$mount_point" >/dev/null 2>&1; then
            log_success "df command successful for $mount_point"
            df -h "$mount_point" | tee -a "$LOG_FILE"
        else
            log_warning "df command failed for $mount_point"
            failed=1
        fi

        # Run stat command
        if stat "$mount_point" >/dev/null 2>&1; then
            log_success "stat command successful for $mount_point"
        else
            log_warning "stat command failed for $mount_point"
            failed=1
        fi
    done

    return $failed
}

test_permissions_and_ownership() {
    log_info "Testing permissions and ownership..."

    # Get list of virtiofs mounts
    local mount_points
    mapfile -t mount_points < <(mount | grep "type virtiofs" | awk '{print $3}')

    if [ ${#mount_points[@]} -eq 0 ]; then
        log_warning "No virtiofs mount points found to test"
        return 1
    fi

    for mount_point in "${mount_points[@]}"; do
        log_info "Checking permissions for $mount_point..."

        local owner perms
        owner=$(stat -c "%U:%G" "$mount_point" 2>/dev/null || echo "unknown")
        perms=$(stat -c "%a" "$mount_point" 2>/dev/null || echo "unknown")

        log_info "  Owner: $owner"
        log_info "  Permissions: $perms"

        # Check if current user can access
        if [ -r "$mount_point" ]; then
            log_success "Current user has read access to $mount_point"
        else
            log_warning "Current user does not have read access to $mount_point"
        fi

        if [ -w "$mount_point" ]; then
            log_success "Current user has write access to $mount_point"
        elif mount | grep "$mount_point" | grep -q "ro,"; then
            log_info "Mount is read-only, write access not expected"
        else
            log_warning "Current user does not have write access to $mount_point"
        fi
    done

    return 0
}

test_mount_persistence() {
    log_info "Testing mount persistence configuration..."

    # Check if fstab has virtiofs entries
    if grep -q "virtiofs" /etc/fstab 2>/dev/null; then
        log_success "virtiofs entries found in /etc/fstab (mounts will persist)"
        log_info "fstab entries:"
        grep "virtiofs" /etc/fstab | tee -a "$LOG_FILE"
    else
        log_warning "No virtiofs entries in /etc/fstab (mounts will not persist across reboots)"
    fi

    return 0
}

# =============================================================================
# MAIN TEST EXECUTION
# =============================================================================

main() {
    log_info "=== Starting Virtio-FS Mount Functionality Tests ==="
    log_info "Log file: $LOG_FILE"

    local failed_tests=()

    # Mount functionality tests
    log_info ""
    log_info "=== MOUNT FUNCTIONALITY TESTS ==="
    test_mounted_filesystems || failed_tests+=("mounted_filesystems")
    test_mount_point_accessibility || failed_tests+=("mount_point_accessibility")
    test_read_operations || failed_tests+=("read_operations")
    test_write_operations || failed_tests+=("write_operations")
    test_mount_options || failed_tests+=("mount_options")
    test_filesystem_stats || failed_tests+=("filesystem_stats")
    test_permissions_and_ownership || failed_tests+=("permissions_ownership")
    test_mount_persistence || failed_tests+=("mount_persistence")

    # Summary
    log_info ""
    log_info "=== MOUNT FUNCTIONALITY TEST SUMMARY ==="
    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_success "All virtio-fs mount functionality tests passed!"
        log_info "Mounts are working correctly with proper permissions"
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
