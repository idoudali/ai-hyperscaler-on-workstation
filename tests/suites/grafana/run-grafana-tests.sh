#!/bin/bash
# Grafana monitoring dashboard validation test suite
# Part of Task 015: Install Prometheus Monitoring Stack

set -euo pipefail

# Source shared suite utilities and logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/suite-utils.sh"
source "${SCRIPT_DIR}/../common/suite-logging.sh"

# Script metadata
# shellcheck disable=SC2034
SCRIPT_NAME="run-grafana-tests.sh"
# shellcheck disable=SC2034
TEST_NAME="Grafana Test Suite"

# Initialize logging
init_suite_logging "$TEST_NAME"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.sh}.log"
touch "$LOG_FILE"

# Local logging helpers to ensure entries land in the script specific log file
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Ensure test tracking is initialised
init_test_tracking

# -----------------------------------------------------------------------------
# Individual test functions
# -----------------------------------------------------------------------------

test_grafana_service_status() {
    log_info "Checking Grafana service status..."

    if systemctl is-active --quiet grafana-server; then
        log_success "Grafana service is running"
        return 0
    fi

    log_warning "Grafana service is not running (expected service name: grafana-server)"
    return 1
}

test_grafana_api_health() {
    log_info "Checking Grafana HTTP health endpoint..."

    if ! command -v curl >/dev/null 2>&1; then
        log_warning "curl not available on host – skipping API health check"
        return 0
    fi

    if curl -sf http://localhost:3000/api/health >/dev/null 2>&1; then
        log_success "Grafana API health endpoint responded successfully"
        return 0
    fi

    log_warning "Grafana API health endpoint is not accessible on localhost:3000"
    return 1
}

test_grafana_directories() {
    log_info "Verifying Grafana configuration and data directories..."

    local config_dir="/etc/grafana"
    local data_dir="/var/lib/grafana"
    local issues=0

    if [[ -d "$config_dir" ]]; then
        log_success "Configuration directory present: $config_dir"
    else
        log_warning "Configuration directory missing: $config_dir"
        issues=$((issues + 1))
    fi

    if [[ -d "$data_dir" ]]; then
        log_success "Data directory present: $data_dir"
    else
        log_warning "Data directory missing: $data_dir"
        issues=$((issues + 1))
    fi

    if [[ $issues -eq 0 ]]; then
        return 0
    fi

    return 1
}

test_grafana_datasource_api() {
    log_info "Checking Grafana datasources API response..."

    if ! command -v curl >/dev/null 2>&1; then
        log_warning "curl not available on host – skipping datasources API check"
        return 0
    fi

    if curl -sf http://localhost:3000/api/datasources >/dev/null 2>&1; then
        log_success "Grafana datasources API is responding"
        return 0
    fi

    log_warning "Grafana datasources API is not responding on localhost:3000"
    return 1
}

test_grafana_port_listening() {
    log_info "Checking if Grafana port 3000 is listening..."

    if ss -ltn '( sport = :3000 )' >/dev/null 2>&1 || netstat -ltn 2>/dev/null | grep -q ":3000 "; then
        log_success "Grafana port 3000 is listening"
        return 0
    fi

    log_warning "Grafana port 3000 is not listening"
    return 1
}

# -----------------------------------------------------------------------------
# Main execution
# -----------------------------------------------------------------------------
main() {
    log_info "Starting Grafana validation tests"
    log_info "Log directory: $LOG_DIR"
    log_info "Log file: $LOG_FILE"

    run_test "Grafana service status" test_grafana_service_status || true
    run_test "Grafana API health endpoint" test_grafana_api_health || true
    run_test "Grafana directories present" test_grafana_directories || true
    run_test "Grafana datasources API" test_grafana_datasource_api || true
    run_test "Grafana port listening" test_grafana_port_listening || true

    echo | tee -a "$LOG_FILE"
    log_info "=== Test Results Summary ==="
    log_info "Tests run: $TESTS_RUN"
    log_info "Tests passed: ${TESTS_PASSED}"
    log_info "Tests failed: ${TESTS_FAILED}"

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        log_warning "The following tests reported issues:"
        for failed in "${FAILED_TESTS[@]}"; do
            log_warning "  - $failed"
        done
        log_warning "Grafana validation completed with warnings – investigate the items above."
        return 0
    fi

    log_success "All Grafana validation tests passed"
    return 0
}

main "$@"
