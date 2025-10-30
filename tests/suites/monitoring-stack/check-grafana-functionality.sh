#!/bin/bash
# Grafana Functionality Validation Script
# Tests Grafana API, data source connectivity, and dashboard functionality
# Part of the Task 016 Grafana implementation

source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
set -euo pipefail

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="check-grafana-functionality.sh"
# shellcheck disable=SC2034
TEST_NAME="Grafana Functionality Validation"

# Grafana configuration (should match Ansible defaults)
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
GRAFANA_URL="http://localhost:${GRAFANA_PORT}"
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"

# Grafana functionality tests
test_grafana_api_health() {
    log_info "Testing Grafana API health endpoint..."

    local response
    local status_code

    # Test health endpoint
    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s -w "%{http_code}" -o /tmp/grafana-health.json "${GRAFANA_URL}/api/health" 2>/dev/null)
        status_code=$(echo "$response" | tail -n1)
        # body=$(echo "$response" | head -n -1)  # Not used, response saved to file

        if [[ "$status_code" == "200" ]]; then
            log_success "Grafana health endpoint returns 200 OK"

            # Check response content
            if grep -q "ok" /tmp/grafana-health.json; then
                log_success "Health check response indicates service is healthy"
            else
                log_warning "Health check response may indicate issues"
            fi
        else
            log_error "Grafana health endpoint returned status $status_code"
            return 1
        fi
    else
        log_error "curl command not available for API testing"
        return 1
    fi
}

test_grafana_prometheus_datasource() {
    log_info "Testing Prometheus data source configuration..."

    local response
    local status_code

    # Test data source endpoint
    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s -w "%{http_code}" -o /tmp/grafana-datasources.json \
            -u "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}" \
            "${GRAFANA_URL}/api/datasources" 2>/dev/null)
        status_code=$(echo "$response" | tail -n1)

        if [[ "$status_code" == "200" ]]; then
            log_success "Grafana data sources endpoint returns 200 OK"

            # Check if Prometheus data source exists
            if grep -q "Prometheus" /tmp/grafana-datasources.json; then
                log_success "Prometheus data source is configured"
            else
                log_error "Prometheus data source not found in Grafana configuration"
                return 1
            fi

            # Check data source URL
            if grep -q "http://localhost:9090" /tmp/grafana-datasources.json; then
                log_success "Prometheus data source URL is correct"
            else
                log_error "Prometheus data source URL is incorrect"
                return 1
            fi
        else
            log_error "Grafana data sources endpoint returned status $status_code"
            return 1
        fi
    else
        log_error "curl command not available for API testing"
        return 1
    fi
}

test_grafana_dashboard_provisioning() {
    log_info "Testing dashboard provisioning..."

    local response
    local status_code

    # Test dashboards endpoint
    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s -w "%{http_code}" -o /tmp/grafana-dashboards.json \
            -u "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}" \
            "${GRAFANA_URL}/api/search?type=dash-db" 2>/dev/null)
        status_code=$(echo "$response" | tail -n1)

        if [[ "$status_code" == "200" ]]; then
            log_success "Grafana dashboards endpoint returns 200 OK"

            # Check if system overview dashboard exists
            if grep -q "System Overview" /tmp/grafana-dashboards.json; then
                log_success "System Overview dashboard is provisioned"
            else
                log_warning "System Overview dashboard not found (may be expected if service not fully started)"
            fi
        else
            log_error "Grafana dashboards endpoint returned status $status_code"
            return 1
        fi
    else
        log_error "curl command not available for API testing"
        return 1
    fi
}

test_grafana_metrics_query() {
    log_info "Testing Grafana metrics query functionality..."

    local response
    local status_code

    # Test query endpoint with a simple Prometheus query
    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s -w "%{http_code}" -o /tmp/grafana-query.json \
            -u "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}" \
            -X POST \
            -H "Content-Type: application/json" \
            -d '{"queries":[{"refId":"A","expr":"up","instant":true}]}' \
            "${GRAFANA_URL}/api/ds/query" 2>/dev/null)
        status_code=$(echo "$response" | tail -n1)

        if [[ "$status_code" == "200" ]]; then
            log_success "Grafana query endpoint returns 200 OK"

            # Check if query returned data (basic validation)
            if grep -q "data" /tmp/grafana-query.json; then
                log_success "Query returned data structure"
            else
                log_warning "Query response may be incomplete"
            fi
        else
            log_error "Grafana query endpoint returned status $status_code"
            return 1
        fi
    else
        log_error "curl command not available for API testing"
        return 1
    fi
}

test_grafana_port_connectivity() {
    log_info "Testing Grafana port connectivity..."

    # Check if port is listening
    if command -v ss >/dev/null 2>&1; then
        if ss -tuln | grep -q ":${GRAFANA_PORT} "; then
            log_success "Grafana port ${GRAFANA_PORT} is listening"
        else
            log_error "Grafana port ${GRAFANA_PORT} is not listening"
            return 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tuln | grep -q ":${GRAFANA_PORT} "; then
            log_success "Grafana port ${GRAFANA_PORT} is listening"
        else
            log_error "Grafana port ${GRAFANA_PORT} is not listening"
            return 1
        fi
    else
        log_warning "Neither ss nor netstat available for port checking"
    fi
}

test_grafana_process() {
    log_info "Testing Grafana process..."

    # Check if grafana-server process is running
    if pgrep -f grafana-server >/dev/null 2>&1; then
        log_success "Grafana server process is running"

        # Check process user
        local grafana_pid
        local process_user
        grafana_pid=$(pgrep -f grafana-server)
        process_user=$(ps -o user= -p "$grafana_pid" | tr -d ' ')

        if [[ "$process_user" == "grafana" ]]; then
            log_success "Grafana process runs as correct user"
        else
            log_error "Grafana process runs as incorrect user: $process_user"
            return 1
        fi
    else
        log_warning "Grafana server process is not running (may be expected in build environment)"
    fi
}

test_grafana_database() {
    log_info "Testing Grafana database..."

    # Check if database file exists (SQLite by default)
    if [[ -f "/var/lib/grafana/grafana.db" ]]; then
        log_success "Grafana database file exists"

        # Check database file ownership
        if [[ "$(stat -c '%U:%G' /var/lib/grafana/grafana.db)" == "grafana:grafana" ]]; then
            log_success "Grafana database has correct ownership"
        else
            log_error "Grafana database has incorrect ownership"
            return 1
        fi

        # Check database file permissions
        if [[ "$(stat -c '%a' /var/lib/grafana/grafana.db)" == "640" ]]; then
            log_success "Grafana database has correct permissions"
        else
            log_error "Grafana database has incorrect permissions"
            return 1
        fi
    else
        log_warning "Grafana database file not found (may be expected if service not started)"
    fi
}

test_grafana_logs() {
    log_info "Testing Grafana logging..."

    # Check if log directory exists
    if [[ -d "/var/log/grafana" ]]; then
        log_success "Grafana log directory exists"
    else
        log_error "Grafana log directory missing"
        return 1
    fi

    # Check log directory ownership
    if [[ "$(stat -c '%U:%G' /var/log/grafana)" == "grafana:grafana" ]]; then
        log_success "Grafana log directory has correct ownership"
    else
        log_error "Grafana log directory has incorrect ownership"
        return 1
    fi

    # Check if log files exist (if service is running)
    if ls /var/log/grafana/*.log >/dev/null 2>&1; then
        log_success "Grafana log files exist"

        # Check if logs contain recent entries
        if find /var/log/grafana -name "*.log" -newermt "1 minute ago" 2>/dev/null | grep -q .; then
            log_success "Grafana logs contain recent entries"
        else
            log_warning "Grafana logs may not contain recent entries"
        fi
    else
        log_warning "No Grafana log files found (may be expected if service not running)"
    fi
}

# Main test execution
main() {
    init_logging "$(date '+%Y-%m-%d_%H-%M-%S')" "tests/logs" "grafana-func"

    log_info "=== $TEST_SUITE_NAME ==="
    log_info "Grafana URL: $GRAFANA_URL"
    log_info "Admin User: $GRAFANA_ADMIN_USER"

    run_test "API Health" test_grafana_api_health
    run_test "Port Connectivity" test_grafana_port_connectivity
    run_test "Process Status" test_grafana_process
    run_test "Database" test_grafana_database
    run_test "Prometheus Data Source" test_grafana_prometheus_datasource
    run_test "Dashboard Provisioning" test_grafana_dashboard_provisioning
    run_test "Metrics Query" test_grafana_metrics_query
    run_test "Logging" test_grafana_logs

    print_test_summary
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
