#!/bin/bash
# Monitoring stack integration test script
# Tests Prometheus and Node Exporter integration
# Part of Task 015: Install Prometheus Monitoring Stack

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"

TEST_NAME="Monitoring Stack Integration"
LOG_FILE="${LOG_DIR:-/tmp}/monitoring-integration-test.log"

# Test functions
test_prometheus_targets() {
    log_test "Testing Prometheus target discovery and scraping"

    sleep 10  # Wait for Prometheus to complete initial scraping

    local targets_response
    targets_response=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null || echo "")

    if [ -z "$targets_response" ]; then
        log_fail "Could not retrieve targets from Prometheus API"
        return 1
    fi

    local active_targets total_targets
    active_targets=$(echo "$targets_response" | grep -c '"health":"up"' || echo "0")
    total_targets=$(echo "$targets_response" | grep -c '"discoveredLabels"' || echo "0")

    log_info "Found $active_targets/$total_targets active targets"

    if [ "$active_targets" -gt 0 ]; then
        log_pass "Prometheus has active targets"
    else
        log_fail "Prometheus has no active targets"
        return 1
    fi

    if echo "$targets_response" | grep -q '"job":"prometheus"'; then
        log_pass "Prometheus self-monitoring target found"
    else
        log_warn "Prometheus self-monitoring target not found"
    fi

    if echo "$targets_response" | grep -q '"job":"node-exporter"'; then
        log_pass "Node Exporter targets found in Prometheus"
    else
        log_warn "Node Exporter targets not found in Prometheus"
    fi

    return 0
}

test_prometheus_node_metrics() {
    log_test "Testing Prometheus collection of Node Exporter metrics"

    local test_queries=(
        "up{job=\"node-exporter\"}"
        "node_cpu_seconds_total"
        "node_memory_MemTotal_bytes"
        "node_filesystem_size_bytes"
        "node_load1"
    )

    local failed_queries=()

    for query in "${test_queries[@]}"; do
        log_info "Testing query: $query"

        local response encoded_query
        encoded_query=$(echo "$query" | sed 's/{/%7B/g; s/}/%7D/g; s/=/%3D/g; s/"/%22/g; s/ /%20/g')
        response=$(curl -s "http://localhost:9090/api/v1/query?query=$encoded_query" 2>/dev/null || echo "")

        if [ -n "$response" ]; then
            if echo "$response" | grep -q '"status":"success"'; then
                local result_count
                result_count=$(echo "$response" | tr -d '\n' | grep -o '"result":\[' | wc -l || echo "0")
                result_count=$((result_count))
                if [ "$result_count" -gt 0 ]; then
                    log_pass "Query '$query' returned results"
                else
                    log_warn "Query '$query' returned no data points"
                    failed_queries+=("$query")
                fi
            else
                log_fail "Query '$query' failed"
                failed_queries+=("$query")
            fi
        else
            log_fail "Could not execute query '$query'"
            failed_queries+=("$query")
        fi
    done

    if [ ${#failed_queries[@]} -eq 0 ]; then
        log_pass "All test queries executed successfully"
        return 0
    else
        log_fail "Failed queries: ${failed_queries[*]}"
        return 1
    fi
}

test_metrics_data_quality() {
    log_test "Testing metrics data quality and consistency"

    # Test CPU metrics
    local cpu_idle_query="node_cpu_seconds_total{mode=\"idle\"}"
    local cpu_response
    cpu_response=$(curl -s "http://localhost:9090/api/v1/query?query=$cpu_idle_query" 2>/dev/null || echo "")

    if [ -n "$cpu_response" ] && echo "$cpu_response" | grep -q '"status":"success"'; then
        local cpu_count
        cpu_count=$(echo "$cpu_response" | grep -c '"value":\[.*,"[0-9.]*"\]' || echo "0")
        log_pass "CPU metrics available for $cpu_count CPU cores"
    else
        log_warn "CPU metrics quality check failed"
    fi

    # Test memory metrics
    local memory_query="node_memory_MemTotal_bytes"
    local memory_response
    memory_response=$(curl -s "http://localhost:9090/api/v1/query?query=$memory_query" 2>/dev/null || echo "")

    if [ -n "$memory_response" ] && echo "$memory_response" | grep -q '"status":"success"'; then
        local memory_bytes
        memory_bytes=$(echo "$memory_response" | grep -o '"value":\[.*,"\([0-9]*\)"\]' | sed 's/.*"\([0-9]*\)".*/\1/' | head -1)
        if [ -n "$memory_bytes" ] && [ "$memory_bytes" -gt 0 ]; then
            local memory_gb
            memory_gb=$((memory_bytes / 1024 / 1024 / 1024))
            log_pass "Memory metrics available (Total: ${memory_gb}GB)"
        else
            log_warn "Memory metrics appear invalid"
        fi
    else
        log_warn "Memory metrics quality check failed"
    fi

    # Test filesystem metrics
    local fs_query="node_filesystem_size_bytes{fstype!=\"tmpfs\"}"
    local fs_response
    fs_response=$(curl -s "http://localhost:9090/api/v1/query?query=$fs_query" 2>/dev/null || echo "")

    if [ -n "$fs_response" ] && echo "$fs_response" | grep -q '"status":"success"'; then
        local fs_count
        fs_count=$(echo "$fs_response" | grep -c '"value":\[.*,"[0-9.]*"\]' || echo "0")
        log_pass "Filesystem metrics available for $fs_count filesystems"
    else
        log_warn "Filesystem metrics quality check failed"
    fi

    return 0
}

test_scrape_intervals() {
    log_test "Testing scrape interval configuration"

    local config_file="/etc/prometheus/prometheus.yml"

    if [ -f "$config_file" ]; then
        log_info "Analyzing Prometheus configuration..."

        local global_interval
        global_interval=$(grep "scrape_interval:" "$config_file" | head -1 | awk '{print $2}' | tr -d '"' || echo "unknown")
        log_info "Global scrape interval: $global_interval"

        if grep -q "job_name.*node.*exporter" "$config_file"; then
            log_pass "Node Exporter job configured in Prometheus"
        else
            log_warn "Node Exporter job not found in Prometheus configuration"
        fi

        return 0
    else
        log_fail "Prometheus configuration file not found"
        return 1
    fi
}

test_alerting_configuration() {
    log_test "Testing alerting configuration"

    local config_file="/etc/prometheus/prometheus.yml"

    if [ -f "$config_file" ]; then
        if grep -q "alertmanagers:" "$config_file"; then
            log_pass "Alertmanager configuration found in Prometheus"

            local am_targets
            am_targets=$(grep -A 5 "alertmanagers:" "$config_file" | grep "targets:" | awk '{print $2}' | tr -d '"[]' || echo "none")
            log_info "Alertmanager targets: $am_targets"
        else
            log_warn "Alertmanager configuration not found in Prometheus"
        fi
    else
        log_fail "Cannot check alerting configuration - Prometheus config missing"
        return 1
    fi

    if systemctl is-active prometheus-alertmanager >/dev/null 2>&1; then
        log_pass "Alertmanager service is running"
    else
        log_info "Alertmanager service is not running (may be intended)"
    fi

    return 0
}

test_web_interface() {
    log_test "Testing Prometheus web interface functionality"

    if curl -sf "http://localhost:9090/" >/dev/null 2>&1; then
        log_pass "Prometheus web interface main page accessible"
    else
        log_fail "Prometheus web interface main page not accessible"
        return 1
    fi

    if curl -sf "http://localhost:9090/graph" >/dev/null 2>&1; then
        log_pass "Prometheus graph interface accessible"
    else
        log_warn "Prometheus graph interface not accessible"
    fi

    if curl -sf "http://localhost:9090/targets" >/dev/null 2>&1; then
        log_pass "Prometheus targets page accessible"
    else
        log_warn "Prometheus targets page not accessible"
    fi

    if curl -sf "http://localhost:9090/config" >/dev/null 2>&1; then
        log_pass "Prometheus configuration page accessible"
    else
        log_warn "Prometheus configuration page not accessible"
    fi

    return 0
}

# Main test execution
main() {
    init_suite_logging "$TEST_NAME"

    log_info "Log file: $LOG_FILE"

    run_test "Prometheus Targets" test_prometheus_targets
    run_test "Prometheus Node Metrics" test_prometheus_node_metrics
    run_test "Metrics Data Quality" test_metrics_data_quality
    run_test "Scrape Intervals" test_scrape_intervals
    run_test "Alerting Configuration" test_alerting_configuration
    run_test "Web Interface" test_web_interface

    print_test_summary "$TEST_NAME"
    exit_with_test_results
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
