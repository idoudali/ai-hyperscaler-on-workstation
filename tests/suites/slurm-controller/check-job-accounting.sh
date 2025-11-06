#!/bin/bash
# SLURM Job Accounting Validation Test Suite
# Task 017: Configure SLURM Job Accounting
# This script validates SLURM job accounting functionality including
# database connectivity, slurmdbd service, job tracking, and accounting data

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-check-helpers.sh"

set -euo pipefail

# Script configuration
export SCRIPT_NAME="check-job-accounting.sh"
export TEST_NAME="SLURM Job Accounting Validation"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
: "${LOG_DIR:=$(pwd)/logs/run-${TIMESTAMP}}"
LOG_DIR="${LOG_DIR%/}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME%.sh}.log"
touch "$LOG_FILE"
export LOG_DIR LOG_FILE

# Test configuration
TEST_TIMEOUT=300
SLURM_CONF="/etc/slurm/slurm.conf"
SLURMDBD_CONF="/etc/slurm/slurmdbd.conf"
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
MYSQL_DB="slurm_acct_db"
MYSQL_USER="slurm"

# Test counters (using custom ones since this script has special test_passed/test_failed funcs)
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test result functions
test_passed() {
    ((TESTS_PASSED++))
    log_success "✓ $1"
}

test_failed() {
    ((TESTS_FAILED++))
    log_error "✗ $1"
}

test_skipped() {
    ((TESTS_SKIPPED++))
    log_warning "⚠ $1"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment..."
    # Kill any running test jobs
    if command -v squeue >/dev/null 2>&1; then
        squeue -u "$(whoami)" --format="%i" --noheader | xargs -r scancel 2>/dev/null || true
    fi
}

# Set up logging
setup_logging() {
    mkdir -p "$LOG_DIR"
    log_info "Starting $TEST_NAME ($SCRIPT_NAME)"
    log_info "Starting SLURM Job Accounting validation tests"
    log_info "Log file: $LOG_FILE"
    log_info "Test timeout: ${TEST_TIMEOUT}s"
}

# Test 1: Check MariaDB service status
test_mariadb_service() {
    log_info "Test 1: Checking MariaDB service status..."

    if systemctl is-active --quiet mariadb; then
        test_passed "MariaDB service is running"
    else
        test_failed "MariaDB service is not running"
        return 1
    fi

    if systemctl is-enabled --quiet mariadb; then
        test_passed "MariaDB service is enabled"
    else
        test_failed "MariaDB service is not enabled"
    fi
}

# Test 2: Check MariaDB connectivity
test_mariadb_connectivity() {
    log_info "Test 2: Checking MariaDB connectivity..."

    if command -v mysql >/dev/null 2>&1; then
        if mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD:-slurm}" -e "SELECT 1;" "$MYSQL_DB" >/dev/null 2>&1; then
            test_passed "MariaDB connection successful"
        else
            test_failed "MariaDB connection failed"
            return 1
        fi
    else
        test_skipped "mysql client not available"
    fi
}

# Test 3: Check SLURM accounting database exists
test_slurm_database() {
    log_info "Test 3: Checking SLURM accounting database..."

    if command -v mysql >/dev/null 2>&1; then
        if mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD:-slurm}" -e "USE $MYSQL_DB; SHOW TABLES;" >/dev/null 2>&1; then
            test_passed "SLURM accounting database exists and accessible"

            # Check for key accounting tables
            local tables
            tables=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD:-slurm}" -e "USE $MYSQL_DB; SHOW TABLES;" -s 2>/dev/null | tr '\n' ' ')

            if echo "$tables" | grep -q "cluster_table"; then
                test_passed "cluster_table exists"
            else
                test_failed "cluster_table missing"
            fi

            if echo "$tables" | grep -q "job_table"; then
                test_passed "job_table exists"
            else
                test_failed "job_table missing"
            fi

            if echo "$tables" | grep -q "step_table"; then
                test_passed "step_table exists"
            else
                test_failed "step_table missing"
            fi
        else
            test_failed "SLURM accounting database not accessible"
            return 1
        fi
    else
        test_skipped "mysql client not available"
    fi
}

# Test 4: Check slurmdbd service status
test_slurmdbd_service() {
    log_info "Test 4: Checking slurmdbd service status..."

    if systemctl is-active --quiet slurmdbd; then
        test_passed "slurmdbd service is running"
    else
        test_failed "slurmdbd service is not running"
        return 1
    fi

    if systemctl is-enabled --quiet slurmdbd; then
        test_passed "slurmdbd service is enabled"
    else
        test_failed "slurmdbd service is not enabled"
    fi
}

# Test 5: Check slurmdbd configuration
test_slurmdbd_config() {
    log_info "Test 5: Checking slurmdbd configuration..."

    if [[ -f "$SLURMDBD_CONF" ]]; then
        test_passed "slurmdbd configuration file exists"

        # Check key configuration parameters
        if grep -q "StorageType=accounting_storage/mysql" "$SLURMDBD_CONF"; then
            test_passed "StorageType configured for MySQL"
        else
            test_failed "StorageType not configured for MySQL"
        fi

        if grep -q "StorageHost=$MYSQL_HOST" "$SLURMDBD_CONF"; then
            test_passed "StorageHost configured correctly"
        else
            test_failed "StorageHost not configured correctly"
        fi

        if grep -q "StorageLoc=$MYSQL_DB" "$SLURMDBD_CONF"; then
            test_passed "StorageLoc configured correctly"
        else
            test_failed "StorageLoc not configured correctly"
        fi

        if grep -q "DbdPort=6819" "$SLURMDBD_CONF"; then
            test_passed "DbdPort configured correctly"
        else
            test_failed "DbdPort not configured correctly"
        fi
    else
        test_failed "slurmdbd configuration file not found"
        return 1
    fi
}

# Test 6: Check slurmdbd connectivity
test_slurmdbd_connectivity() {
    log_info "Test 6: Checking slurmdbd connectivity..."

    if command -v sacctmgr >/dev/null 2>&1; then
        if timeout 10 sacctmgr show cluster >/dev/null 2>&1; then
            test_passed "slurmdbd connection successful"
        else
            test_failed "slurmdbd connection failed"
            return 1
        fi
    else
        test_skipped "sacctmgr command not available"
    fi
}

# Test 7: Check SLURM configuration for accounting
test_slurm_accounting_config() {
    log_info "Test 7: Checking SLURM configuration for accounting..."

    if [[ -f "$SLURM_CONF" ]]; then
        test_passed "SLURM configuration file exists"

        # Check accounting configuration
        if grep -q "AccountingStorageType=accounting_storage/slurmdbd" "$SLURM_CONF"; then
            test_passed "AccountingStorageType configured for slurmdbd"
        else
            test_failed "AccountingStorageType not configured for slurmdbd"
        fi

        if grep -q "AccountingStorageHost=localhost" "$SLURM_CONF"; then
            test_passed "AccountingStorageHost configured correctly"
        else
            test_failed "AccountingStorageHost not configured correctly"
        fi

        if grep -q "AccountingStoragePort=6819" "$SLURM_CONF"; then
            test_passed "AccountingStoragePort configured correctly"
        else
            test_failed "AccountingStoragePort not configured correctly"
        fi

        if grep -q "JobAcctGatherType=jobacct_gather/linux" "$SLURM_CONF"; then
            test_passed "JobAcctGatherType configured correctly"
        else
            test_failed "JobAcctGatherType not configured correctly"
        fi

        if grep -q "JobAcctGatherParams=UsePss,NoOverMemoryKill" "$SLURM_CONF"; then
            test_passed "JobAcctGatherParams configured correctly"
        else
            test_failed "JobAcctGatherParams not configured correctly"
        fi
    else
        test_failed "SLURM configuration file not found"
        return 1
    fi
}

# Test 8: Check sacct command functionality
test_sacct_command() {
    log_info "Test 8: Checking sacct command functionality..."

    if command -v sacct >/dev/null 2>&1; then
        test_passed "sacct command available"

        # Test basic sacct functionality
        if timeout 10 sacct --format=JobID,JobName,Partition,Account,AllocCPUS,State,ExitCode >/dev/null 2>&1; then
            test_passed "sacct command executes successfully"
        else
            test_failed "sacct command execution failed"
        fi

        # Test sacct with different formats
        if timeout 10 sacct --format=JobID,JobName,State --start=today >/dev/null 2>&1; then
            test_passed "sacct with date filter works"
        else
            test_failed "sacct with date filter failed"
        fi
    else
        test_failed "sacct command not available"
    fi
}

# Test 9: Check sacctmgr command functionality
test_sacctmgr_command() {
    log_info "Test 9: Checking sacctmgr command functionality..."

    if command -v sacctmgr >/dev/null 2>&1; then
        test_passed "sacctmgr command available"

        # Test basic sacctmgr functionality
        if timeout 10 sacctmgr show cluster >/dev/null 2>&1; then
            test_passed "sacctmgr show cluster works"
        else
            test_failed "sacctmgr show cluster failed"
        fi

        if timeout 10 sacctmgr show account >/dev/null 2>&1; then
            test_passed "sacctmgr show account works"
        else
            test_failed "sacctmgr show account failed"
        fi

        if timeout 10 sacctmgr show user >/dev/null 2>&1; then
            test_passed "sacctmgr show user works"
        else
            test_failed "sacctmgr show user failed"
        fi
    else
        test_failed "sacctmgr command not available"
    fi
}

# Test 10: Test job submission and accounting
test_job_accounting() {
    log_info "Test 10: Testing job submission and accounting..."

    if command -v srun >/dev/null 2>&1; then
        test_passed "srun command available"

        # Submit a simple test job
        local job_id
        if job_id=$(timeout 30 srun --job-name=test-accounting --time=1:00 echo "test job" 2>/dev/null | grep -o '[0-9]\+' | head -1); then
            test_passed "Test job submitted successfully (JobID: $job_id)"

            # Wait a moment for job to complete
            sleep 5

            # Check if job appears in accounting
            if timeout 10 sacct --job="$job_id" --format=JobID,JobName,State >/dev/null 2>&1; then
                test_passed "Job appears in accounting records"
            else
                test_failed "Job not found in accounting records"
            fi
        else
            test_failed "Failed to submit test job"
        fi
    else
        test_skipped "srun command not available"
    fi
}

# Test 11: Check accounting data integrity
test_accounting_data_integrity() {
    log_info "Test 11: Checking accounting data integrity..."

    if command -v mysql >/dev/null 2>&1; then
        # Check if there are any jobs in the database
        local job_count
        job_count=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD:-slurm}" -e "USE $MYSQL_DB; SELECT COUNT(*) FROM job_table;" -s 2>/dev/null || echo "0")

        if [[ "$job_count" -gt 0 ]]; then
            test_passed "Accounting database contains $job_count job records"
        else
            test_warning "No job records found in accounting database"
        fi

        # Check for recent job records
        local recent_jobs
        recent_jobs=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD:-slurm}" -e "USE $MYSQL_DB; SELECT COUNT(*) FROM job_table WHERE time_start > DATE_SUB(NOW(), INTERVAL 1 HOUR);" -s 2>/dev/null || echo "0")

        if [[ "$recent_jobs" -gt 0 ]]; then
            test_passed "Found $recent_jobs recent job records"
        else
            test_warning "No recent job records found"
        fi
    else
        test_skipped "mysql client not available"
    fi
}

# Test 12: Check accounting log files
test_accounting_logs() {
    log_info "Test 12: Checking accounting log files..."

    local log_files=(
        "/var/log/slurm/slurmdbd.log"
        "/var/log/slurm/slurmctld.log"
    )

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            test_passed "Log file exists: $log_file"

            if [[ -r "$log_file" ]]; then
                test_passed "Log file is readable: $log_file"

                # Check for recent log entries
                if [[ -s "$log_file" ]]; then
                    test_passed "Log file contains data: $log_file"
                else
                    test_warning "Log file is empty: $log_file"
                fi
            else
                test_failed "Log file is not readable: $log_file"
            fi
        else
            test_failed "Log file not found: $log_file"
        fi
    done
}

# Test 13: Check accounting performance
test_accounting_performance() {
    log_info "Test 13: Checking accounting performance..."

    if command -v sacct >/dev/null 2>&1; then
        # Test sacct performance with a simple query
        local start_time
        start_time=$(date +%s.%N)

        if timeout 10 sacct --format=JobID,JobName,State --start=today >/dev/null 2>&1; then
            local end_time
            end_time=$(date +%s.%N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")

            if (( $(echo "$duration < 5.0" | bc -l 2>/dev/null || echo 0) )); then
                test_passed "sacct query completed in ${duration}s (good performance)"
            else
                test_warning "sacct query took ${duration}s (may be slow)"
            fi
        else
            test_failed "sacct performance test failed"
        fi
    else
        test_skipped "sacct command not available"
    fi
}

# Test 14: Check accounting configuration validation
test_accounting_config_validation() {
    log_info "Test 14: Checking accounting configuration validation..."

    # Check SLURM configuration syntax
    if command -v slurmctld >/dev/null 2>&1; then
        if timeout 10 slurmctld -D -vvv >/dev/null 2>&1; then
            test_passed "SLURM configuration syntax is valid"
        else
            test_failed "SLURM configuration syntax validation failed"
        fi
    else
        test_skipped "slurmctld command not available"
    fi

    # Check slurmdbd configuration syntax
    if command -v slurmdbd >/dev/null 2>&1; then
        if timeout 10 slurmdbd -D -vvv >/dev/null 2>&1; then
            test_passed "slurmdbd configuration syntax is valid"
        else
            test_failed "slurmdbd configuration syntax validation failed"
        fi
    else
        test_skipped "slurmdbd command not available"
    fi
}

# Test 15: Check accounting backup and recovery
test_accounting_backup() {
    log_info "Test 15: Checking accounting backup configuration..."

    # Check if backup directory exists
    local backup_dir="/var/backup/slurm"
    if [[ -d "$backup_dir" ]]; then
        test_passed "Backup directory exists: $backup_dir"

        if [[ -w "$backup_dir" ]]; then
            test_passed "Backup directory is writable"
        else
            test_warning "Backup directory is not writable"
        fi
    else
        test_warning "Backup directory not found: $backup_dir"
    fi

    # Check for existing backups
    if find "$backup_dir" -name "*.sql" -o -name "*.dump" 2>/dev/null | head -1 | grep -q .; then
        test_passed "Backup files found in backup directory"
    else
        test_warning "No backup files found in backup directory"
    fi
}

# Main test execution
run_tests() {
    log_info "Running SLURM Job Accounting validation tests..."

    # Core service tests
    test_mariadb_service
    test_mariadb_connectivity
    test_slurm_database
    test_slurmdbd_service
    test_slurmdbd_config
    test_slurmdbd_connectivity

    # Configuration tests
    test_slurm_accounting_config
    test_accounting_config_validation

    # Command functionality tests
    test_sacct_command
    test_sacctmgr_command

    # Job accounting tests
    test_job_accounting
    test_accounting_data_integrity

    # Logging and performance tests
    test_accounting_logs
    test_accounting_performance

    # Backup and recovery tests
    test_accounting_backup
}

# Print test summary
print_summary() {
    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

    echo
    log_info "=== Test Summary ==="
    log_info "Total tests: $total_tests"
    log_success "Passed: $TESTS_PASSED"
    log_error "Failed: $TESTS_FAILED"
    log_warning "Skipped: $TESTS_SKIPPED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All critical tests passed! SLURM job accounting is working correctly."
        return 0
    else
        log_error "Some tests failed. Please check the configuration and logs."
        return 1
    fi
}

# Main execution
main() {
    # Set up signal handling
    trap cleanup EXIT INT TERM

    # Set up logging
    setup_logging

    # Run tests
    run_tests

    # Print summary
    print_summary
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
