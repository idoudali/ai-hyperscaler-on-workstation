#!/bin/bash
# Virtio-FS performance validation test script
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

TEST_NAME="Virtio-FS Performance Validation"
LOG_FILE="${LOG_DIR:-/tmp}/virtio-fs-performance-test.log"

# Performance thresholds (in MB/s)
MIN_READ_SPEED=100
MIN_WRITE_SPEED=100

# Override log functions to also write to test-specific log
log_perf() {
    echo -e "${BLUE}[PERF]${NC} $*" | tee -a "$LOG_FILE"
}

# =============================================================================
# VIRTIO-FS PERFORMANCE TESTS
# =============================================================================

test_sequential_read_performance() {
    local mount_point="$1"

    log_info "Testing sequential read performance on $mount_point..."

    # Check if mount is read-only
    if mount | grep "$mount_point" | grep -q "ro,"; then
        log_info "$mount_point is read-only, skipping write-based read test"
        return 0
    fi

    # Create a test file (100MB)
    local test_file="$mount_point/.virtio-fs-perf-test-$$"
    local test_size_mb=100

    log_info "Creating $test_size_mb MB test file..."
    if ! dd if=/dev/zero of="$test_file" bs=1M count=$test_size_mb conv=fsync >/dev/null 2>&1; then
        log_warn "Failed to create test file, skipping read performance test"
        return 1
    fi

    # Clear cache to get accurate read results
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true

    # Measure read performance
    log_info "Measuring sequential read performance..."
    local start_time end_time elapsed read_speed
    start_time=$(date +%s.%N)

    if dd if="$test_file" of=/dev/null bs=1M >/dev/null 2>&1; then
        end_time=$(date +%s.%N)
        elapsed=$(echo "$end_time - $start_time" | bc)
        read_speed=$(echo "scale=2; $test_size_mb / $elapsed" | bc)

        log_perf "Sequential read: ${read_speed} MB/s"

        if (( $(echo "$read_speed >= $MIN_READ_SPEED" | bc -l) )); then
            log_pass "Read performance meets threshold (>= ${MIN_READ_SPEED} MB/s)"
        else
            log_warn "Read performance below threshold (${MIN_READ_SPEED} MB/s)"
        fi
    else
        log_error "Failed to measure read performance"
        rm -f "$test_file"
        return 1
    fi

    # Cleanup
    rm -f "$test_file"
    return 0
}

test_sequential_write_performance() {
    local mount_point="$1"

    log_info "Testing sequential write performance on $mount_point..."

    # Check if mount is read-only
    if mount | grep "$mount_point" | grep -q "ro,"; then
        log_info "$mount_point is read-only, skipping write performance test"
        return 0
    fi

    # Check write permission
    if [ ! -w "$mount_point" ]; then
        log_warn "$mount_point is not writable, skipping write performance test"
        return 0
    fi

    local test_file="$mount_point/.virtio-fs-perf-write-test-$$"
    local test_size_mb=100

    # Measure write performance
    log_info "Measuring sequential write performance..."
    local start_time end_time elapsed write_speed
    start_time=$(date +%s.%N)

    if dd if=/dev/zero of="$test_file" bs=1M count=$test_size_mb conv=fsync >/dev/null 2>&1; then
        end_time=$(date +%s.%N)
        elapsed=$(echo "$end_time - $start_time" | bc)
        write_speed=$(echo "scale=2; $test_size_mb / $elapsed" | bc)

        log_perf "Sequential write: ${write_speed} MB/s"

        if (( $(echo "$write_speed >= $MIN_WRITE_SPEED" | bc -l) )); then
            log_pass "Write performance meets threshold (>= ${MIN_WRITE_SPEED} MB/s)"
        else
            log_warn "Write performance below threshold (${MIN_WRITE_SPEED} MB/s)"
        fi
    else
        log_error "Failed to measure write performance"
        rm -f "$test_file"
        return 1
    fi

    # Cleanup
    rm -f "$test_file"
    return 0
}

test_random_io_performance() {
    local mount_point="$1"

    log_info "Testing random I/O performance on $mount_point..."

    # Check if mount is read-only
    if mount | grep "$mount_point" | grep -q "ro,"; then
        log_info "$mount_point is read-only, skipping random I/O test"
        return 0
    fi

    # Check if fio is available
    if ! command -v fio >/dev/null 2>&1; then
        log_warn "fio not available, skipping random I/O test"
        return 0
    fi

    local test_file="$mount_point/.virtio-fs-fio-test-$$"

    log_info "Running fio random read/write test..."
    local fio_output
    fio_output=$(fio --name=randtest \
        --filename="$test_file" \
        --size=50M \
        --rw=randrw \
        --bs=4k \
        --direct=1 \
        --ioengine=libaio \
        --iodepth=16 \
        --runtime=10 \
        --time_based \
        --group_reporting \
        --output-format=json 2>/dev/null || echo "")

    if [ -n "$fio_output" ]; then
        log_pass "fio test completed"
        # Parse and display key metrics if jq is available
        if command -v jq >/dev/null 2>&1; then
            local read_iops write_iops
            read_iops=$(echo "$fio_output" | jq -r '.jobs[0].read.iops' 2>/dev/null || echo "N/A")
            write_iops=$(echo "$fio_output" | jq -r '.jobs[0].write.iops' 2>/dev/null || echo "N/A")
            log_perf "Random read IOPS: $read_iops"
            log_perf "Random write IOPS: $write_iops"
        fi
    else
        log_warn "fio test failed or produced no output"
    fi

    # Cleanup
    rm -f "$test_file"
    return 0
}

test_metadata_performance() {
    local mount_point="$1"

    log_info "Testing metadata operations performance on $mount_point..."

    # Check if mount is read-only
    if mount | grep "$mount_point" | grep -q "ro,"; then
        log_info "$mount_point is read-only, skipping metadata test"
        return 0
    fi

    local test_dir="$mount_point/.virtio-fs-metadata-test-$$"
    local num_files=1000

    # Create test directory
    if ! mkdir -p "$test_dir" 2>/dev/null; then
        log_warn "Cannot create test directory, skipping metadata test"
        return 0
    fi

    # Test file creation performance
    log_info "Testing file creation (creating $num_files files)..."
    local start_time end_time elapsed ops_per_sec
    start_time=$(date +%s.%N)

    for i in $(seq 1 $num_files); do
        touch "$test_dir/file_$i" 2>/dev/null || break
    done

    end_time=$(date +%s.%N)
    elapsed=$(echo "$end_time - $start_time" | bc)
    ops_per_sec=$(echo "scale=2; $num_files / $elapsed" | bc)

    log_perf "File creation: ${ops_per_sec} ops/sec"

    # Test file stat performance
    log_info "Testing file stat (stat $num_files files)..."
    start_time=$(date +%s.%N)

    for i in $(seq 1 $num_files); do
        stat "$test_dir/file_$i" >/dev/null 2>&1 || break
    done

    end_time=$(date +%s.%N)
    elapsed=$(echo "$end_time - $start_time" | bc)
    ops_per_sec=$(echo "scale=2; $num_files / $elapsed" | bc)

    log_perf "File stat: ${ops_per_sec} ops/sec"

    # Test file deletion performance
    log_info "Testing file deletion (deleting $num_files files)..."
    start_time=$(date +%s.%N)

    rm -rf "$test_dir"

    end_time=$(date +%s.%N)
    elapsed=$(echo "$end_time - $start_time" | bc)
    ops_per_sec=$(echo "scale=2; $num_files / $elapsed" | bc)

    log_perf "File deletion: ${ops_per_sec} ops/sec"

    log_pass "Metadata operations test completed"
    return 0
}

test_small_file_performance() {
    local mount_point="$1"

    log_info "Testing small file I/O performance on $mount_point..."

    # Check if mount is read-only
    if mount | grep "$mount_point" | grep -q "ro,"; then
        log_info "$mount_point is read-only, skipping small file test"
        return 0
    fi

    local test_dir="$mount_point/.virtio-fs-small-file-test-$$"
    local num_files=100
    local file_size_kb=4

    # Create test directory
    if ! mkdir -p "$test_dir" 2>/dev/null; then
        log_warn "Cannot create test directory, skipping small file test"
        return 0
    fi

    # Test writing small files
    log_info "Writing $num_files small files (${file_size_kb}KB each)..."
    local start_time end_time elapsed throughput
    start_time=$(date +%s.%N)

    for i in $(seq 1 $num_files); do
        dd if=/dev/zero of="$test_dir/small_$i" bs=1K count=$file_size_kb 2>/dev/null || break
    done

    end_time=$(date +%s.%N)
    elapsed=$(echo "$end_time - $start_time" | bc)
    local total_mb
    total_mb=$(echo "scale=2; $num_files * $file_size_kb / 1024" | bc)
    throughput=$(echo "scale=2; $total_mb / $elapsed" | bc)

    log_perf "Small file write: ${throughput} MB/s"

    # Test reading small files
    log_info "Reading $num_files small files..."
    start_time=$(date +%s.%N)

    for i in $(seq 1 $num_files); do
        cat "$test_dir/small_$i" >/dev/null 2>&1 || break
    done

    end_time=$(date +%s.%N)
    elapsed=$(echo "$end_time - $start_time" | bc)
    throughput=$(echo "scale=2; $total_mb / $elapsed" | bc)

    log_perf "Small file read: ${throughput} MB/s"

    # Cleanup
    rm -rf "$test_dir"
    log_pass "Small file I/O test completed"
    return 0
}

test_latency() {
    local mount_point="$1"

    log_info "Testing I/O latency on $mount_point..."

    # Check if mount is read-only
    if mount | grep "$mount_point" | grep -q "ro,"; then
        log_info "$mount_point is read-only, skipping latency test"
        return 0
    fi

    local test_file="$mount_point/.virtio-fs-latency-test-$$"
    local iterations=100

    # Test write latency
    log_info "Measuring write latency ($iterations iterations)..."
    local total_time=0

    for i in $(seq 1 $iterations); do
        local start end elapsed
        start=$(date +%s.%N)
        echo "test" > "$test_file" 2>/dev/null || break
        end=$(date +%s.%N)
        elapsed=$(echo "$end - $start" | bc)
        total_time=$(echo "$total_time + $elapsed" | bc)
    done

    local avg_latency_ms
    avg_latency_ms=$(echo "scale=3; ($total_time / $iterations) * 1000" | bc)
    log_perf "Average write latency: ${avg_latency_ms} ms"

    # Test read latency
    log_info "Measuring read latency ($iterations iterations)..."
    total_time=0

    for i in $(seq 1 $iterations); do
        local start end elapsed
        start=$(date +%s.%N)
        cat "$test_file" >/dev/null 2>&1 || break
        end=$(date +%s.%N)
        elapsed=$(echo "$end - $start" | bc)
        total_time=$(echo "$total_time + $elapsed" | bc)
    done

    avg_latency_ms=$(echo "scale=3; ($total_time / $iterations) * 1000" | bc)
    log_perf "Average read latency: ${avg_latency_ms} ms"

    # Cleanup
    rm -f "$test_file"
    log_pass "Latency test completed"
    return 0
}

# =============================================================================
# MAIN TEST EXECUTION
# =============================================================================

main() {
    init_suite_logging "$TEST_NAME"

    log_info "Log file: $LOG_FILE"

    # Check for required tools
    if ! command -v bc >/dev/null 2>&1; then
        log_error "bc command not found - required for performance calculations"
        exit 1
    fi

    # Get list of virtiofs mounts
    local mount_points
    mapfile -t mount_points < <(mount | grep "type virtiofs" | awk '{print $3}')

    if [ ${#mount_points[@]} -eq 0 ]; then
        log_error "No virtiofs mount points found to test"
        exit 1
    fi

    log_info "Found ${#mount_points[@]} virtiofs mount(s) to test"

    local failed_tests=()

    # Run performance tests on each mount point
    for mount_point in "${mount_points[@]}"; do
        log_info ""
        log_info "=== TESTING MOUNT: $mount_point ==="

        test_sequential_read_performance "$mount_point" || failed_tests+=("sequential_read_${mount_point}")
        test_sequential_write_performance "$mount_point" || failed_tests+=("sequential_write_${mount_point}")
        test_random_io_performance "$mount_point" || failed_tests+=("random_io_${mount_point}")
        test_metadata_performance "$mount_point" || failed_tests+=("metadata_${mount_point}")
        test_small_file_performance "$mount_point" || failed_tests+=("small_file_${mount_point}")
        test_latency "$mount_point" || failed_tests+=("latency_${mount_point}")
    done

    # Summary
    log_info ""
    log_info "=== PERFORMANCE TEST SUMMARY ==="
    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_pass "All virtio-fs performance tests completed!"
        log_info "Review performance metrics above to assess I/O performance"
        exit 0
    else
        log_warn "Some tests failed: ${failed_tests[*]}"
        log_warn "Check the log file for details: $LOG_FILE"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
