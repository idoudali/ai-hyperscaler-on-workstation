#!/bin/bash
# Virtio-FS mount functionality validation test script
# Part of Task 027: Implement Virtio-FS Host Directory Sharing

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-check-helpers.sh"

TEST_NAME="Virtio-FS Mount Functionality"
LOG_FILE="${LOG_DIR:-/tmp}/virtio-fs-mount-test.log"

# =============================================================================
# VIRTIO-FS MOUNT FUNCTIONALITY TESTS
# =============================================================================

test_mounted_filesystems() {
    log_info "Testing for mounted virtiofs filesystems..."

    log_info "Executing: mount | grep -c \"type virtiofs\""
    local virtiofs_mounts
    local mount_output
    mount_output=$(mount 2>&1)
    virtiofs_mounts=$(echo "$mount_output" | grep -c "type virtiofs" || echo "0")

    log_info "Found $virtiofs_mounts virtiofs mount(s)"

    if [ "$virtiofs_mounts" -gt 0 ]; then
        log_pass "Found $virtiofs_mounts mounted virtiofs filesystems"
        log_info "Mounted filesystems:"
        echo "$mount_output" | grep "type virtiofs" | tee -a "$LOG_FILE"
        return 0
    else
        log_warn "No virtiofs filesystems are currently mounted"
        log_info "All mounted filesystems:"
        echo "$mount_output" | head -20 | tee -a "$LOG_FILE"
        log_error "Expected virtiofs mounts but none found. Check if virtio-fs is configured and mounted."
        return 1
    fi
}

test_mount_point_accessibility() {
    log_info "Testing mount point accessibility..."

    log_info "Executing: mount | grep \"type virtiofs\" | awk '{print \$3}'"
    local mount_points
    mapfile -t mount_points < <(mount | grep "type virtiofs" | awk '{print $3}')

    if [ ${#mount_points[@]} -eq 0 ]; then
        log_warn "No virtiofs mount points found to test"
        log_error "Command 'mount | grep type virtiofs' returned no results"
        return 1
    fi

    log_info "Found ${#mount_points[@]} mount point(s) to test: ${mount_points[*]}"
    local failed=0

    for mount_point in "${mount_points[@]}"; do
        log_info "Testing mount point: $mount_point"

        log_info "Executing: test -d \"$mount_point\""
        if [ -d "$mount_point" ]; then
            log_pass "Mount point $mount_point is accessible (directory exists)"

            log_info "Executing: ls -la \"$mount_point\""
            local ls_output
            if ls_output=$(ls -la "$mount_point" 2>&1); then
                log_pass "Can list directory contents of $mount_point"
                log_info "Directory listing (first 5 lines):"
                echo "$ls_output" | head -5 | while read -r line; do log_info "  $line"; done
            else
                log_fail "Cannot list directory contents of $mount_point"
                log_error "Command 'ls -la $mount_point' failed with output: $ls_output"
                failed=1
            fi

            log_info "Executing: mountpoint -q \"$mount_point\""
            if mountpoint -q "$mount_point" 2>&1; then
                log_pass "$mount_point is properly mounted"
            else
                local mountpoint_output
                mountpoint_output=$(mountpoint "$mount_point" 2>&1 || echo "mountpoint command failed")
                log_fail "$mount_point is not properly mounted"
                log_error "Command 'mountpoint $mount_point' output: $mountpoint_output"
                failed=1
            fi
        else
            log_fail "Mount point $mount_point is not accessible (directory does not exist)"
            log_error "Command 'test -d $mount_point' failed"
            failed=1
        fi
    done

    return $failed
}

test_read_operations() {
    log_info "Testing read operations on mounted filesystems..."

    log_info "Executing: mount | grep \"type virtiofs\" | awk '{print \$3}'"
    local mount_points
    mapfile -t mount_points < <(mount | grep "type virtiofs" | awk '{print $3}')

    if [ ${#mount_points[@]} -eq 0 ]; then
        log_warn "No virtiofs mount points found to test"
        log_error "Command 'mount | grep type virtiofs' returned no results"
        return 1
    fi

    log_info "Found ${#mount_points[@]} mount point(s) to test: ${mount_points[*]}"
    local failed=0

    for mount_point in "${mount_points[@]}"; do
        log_info "Testing read operations on $mount_point..."

        log_info "Executing: ls -la \"$mount_point\""
        local ls_output
        if ls_output=$(ls -la "$mount_point" 2>&1); then
            log_info "Executing: find \"$mount_point\" -mindepth 1 -maxdepth 1 | wc -l"
            local file_count
            file_count=$(find "$mount_point" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
            log_pass "Successfully read directory contents ($file_count items)"

            local first_file
            first_file=$(find "$mount_point" -type f -readable 2>/dev/null | head -1)
            if [ -n "$first_file" ]; then
                if cat "$first_file" >/dev/null 2>&1; then
                    log_pass "Successfully read file: $first_file"
                else
                    log_warn "Could not read file: $first_file"
                fi
            else
                log_info "No readable files found in $mount_point"
            fi
        else
            log_fail "Failed to read directory contents of $mount_point"
            failed=1
        fi
    done

    return $failed
}

test_write_operations() {
    log_info "Testing write operations on mounted filesystems..."

    local mount_points
    mapfile -t mount_points < <(mount | grep "type virtiofs" | awk '{print $3}')

    if [ ${#mount_points[@]} -eq 0 ]; then
        log_warn "No virtiofs mount points found to test"
        return 1
    fi

    local failed=0

    for mount_point in "${mount_points[@]}"; do
        if mount | grep "$mount_point" | grep -q "ro,"; then
            log_info "$mount_point is mounted read-only, skipping write tests"
            continue
        fi

        log_info "Testing write operations on $mount_point..."

        local test_file="$mount_point/.virtio-fs-write-test-$$"

        if echo "test" > "$test_file" 2>/dev/null; then
            log_pass "Successfully created test file: $test_file"

            if [ -f "$test_file" ] && [ "$(cat "$test_file")" = "test" ]; then
                log_pass "Successfully read back test file contents"
            else
                log_fail "Failed to read back test file contents"
                failed=1
            fi

            if rm "$test_file" 2>/dev/null; then
                log_pass "Successfully deleted test file"
            else
                log_fail "Failed to delete test file"
                failed=1
            fi
        else
            log_warn "Cannot write to $mount_point (may be read-only or permission denied)"
        fi
    done

    return $failed
}

test_mount_options() {
    log_info "Testing mount options..."

    local mount_info
    mount_info=$(mount | grep "type virtiofs")

    if [ -z "$mount_info" ]; then
        log_warn "No virtiofs mounts found to test"
        return 1
    fi

    log_info "Current virtiofs mount options:"
    echo "$mount_info" | while IFS= read -r line; do
        log_info "  $line"
    done | tee -a "$LOG_FILE"

    local has_relatime
    has_relatime=$(echo "$mount_info" | grep -c "relatime" || echo "0")

    if [ "$has_relatime" -gt 0 ]; then
        log_pass "relatime option is enabled (good for performance)"
    else
        log_info "relatime option not found in mount options"
    fi

    return 0
}

test_filesystem_stats() {
    log_info "Testing filesystem statistics..."

    local mount_points
    mapfile -t mount_points < <(mount | grep "type virtiofs" | awk '{print $3}')

    if [ ${#mount_points[@]} -eq 0 ]; then
        log_warn "No virtiofs mount points found to test"
        return 1
    fi

    local failed=0

    for mount_point in "${mount_points[@]}"; do
        log_info "Getting statistics for $mount_point..."

        if df -h "$mount_point" >/dev/null 2>&1; then
            log_pass "df command successful for $mount_point"
            df -h "$mount_point" | tee -a "$LOG_FILE"
        else
            log_warn "df command failed for $mount_point"
            failed=1
        fi

        if stat "$mount_point" >/dev/null 2>&1; then
            log_pass "stat command successful for $mount_point"
        else
            log_warn "stat command failed for $mount_point"
            failed=1
        fi
    done

    return $failed
}

test_permissions_and_ownership() {
    log_info "Testing permissions and ownership..."

    local mount_points
    mapfile -t mount_points < <(mount | grep "type virtiofs" | awk '{print $3}')

    if [ ${#mount_points[@]} -eq 0 ]; then
        log_warn "No virtiofs mount points found to test"
        return 1
    fi

    for mount_point in "${mount_points[@]}"; do
        log_info "Checking permissions for $mount_point..."

        local owner perms
        owner=$(stat -c "%U:%G" "$mount_point" 2>/dev/null || echo "unknown")
        perms=$(stat -c "%a" "$mount_point" 2>/dev/null || echo "unknown")

        log_info "  Owner: $owner"
        log_info "  Permissions: $perms"

        if [ -r "$mount_point" ]; then
            log_pass "Current user has read access to $mount_point"
        else
            log_warn "Current user does not have read access to $mount_point"
        fi

        if [ -w "$mount_point" ]; then
            log_pass "Current user has write access to $mount_point"
        elif mount | grep "$mount_point" | grep -q "ro,"; then
            log_info "Mount is read-only, write access not expected"
        else
            log_warn "Current user does not have write access to $mount_point"
        fi
    done

    return 0
}

test_mount_persistence() {
    log_info "Testing mount persistence configuration..."

    if grep -q "virtiofs" /etc/fstab 2>/dev/null; then
        log_pass "virtiofs entries found in /etc/fstab (mounts will persist)"
        log_info "fstab entries:"
        grep "virtiofs" /etc/fstab | tee -a "$LOG_FILE"
    else
        log_warn "No virtiofs entries in /etc/fstab (mounts will not persist across reboots)"
    fi

    return 0
}

# =============================================================================
# MAIN TEST EXECUTION
# =============================================================================

main() {
    init_suite_logging "$TEST_NAME"

    log_info "Log file: $LOG_FILE"

    local failed_tests=()

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

    log_info ""
    log_info "=== MOUNT FUNCTIONALITY TEST SUMMARY ==="
    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_pass "All virtio-fs mount functionality tests passed!"
        log_info "Mounts are working correctly with proper permissions"
        exit 0
    else
        log_fail "Failed tests: ${failed_tests[*]}"
        log_fail "Check the log file for details: $LOG_FILE"
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
