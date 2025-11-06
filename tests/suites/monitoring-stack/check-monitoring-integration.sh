#!/bin/bash
# Monitoring stack integration test script
# Tests Prometheus and Node Exporter integration
# Part of Task 015: Install Prometheus Monitoring Stack

set -euo pipefail

# Initialize logging and colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

LOG_FILE="${LOG_DIR:-/tmp}/monitoring-integration-test.log"

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

# Test functions
test_prometheus_targets() {
    log_info "Testing Prometheus target discovery and scraping..."

    # Wait for Prometheus to complete initial scraping
    sleep 10

    # Check targets API
    local targets_response
    targets_response=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null || echo "")

    if [ -z "$targets_response" ]; then
        log_error "Could not retrieve targets from Prometheus API"
        return 1
    fi

    # Parse active targets
    local active_targets
    active_targets=$(echo "$targets_response" | grep -c '"health":"up"' || echo "0")
    local total_targets
    total_targets=$(echo "$targets_response" | grep -c '"discoveredLabels"' || echo "0")

    log_info "Found $active_targets/$total_targets active targets"

    if [ "$active_targets" -gt 0 ]; then
        log_success "Prometheus has active targets"
    else
        log_error "Prometheus has no active targets"
        return 1
    fi

    # Check for self-monitoring target (prometheus)
    if echo "$targets_response" | grep -q '"job":"prometheus"'; then
        log_success "Prometheus self-monitoring target found"
    else
        log_warning "Prometheus self-monitoring target not found"
    fi

    # Check for node-exporter targets
    if echo "$targets_response" | grep -q '"job":"node-exporter"'; then
        log_success "Node Exporter targets found in Prometheus"
    else
        log_warning "Node Exporter targets not found in Prometheus"
    fi

    return 0
}

test_prometheus_node_metrics() {
    log_info "Testing Prometheus collection of Node Exporter metrics..."

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

        local response
        local encoded_query
        encoded_query=$(echo "$query" | sed 's/{/%7B/g; s/}/%7D/g; s/=/%3D/g; s/"/%22/g; s/ /%20/g')
        response=$(curl -s "http://localhost:9090/api/v1/query?query=$encoded_query" 2>/dev/null || echo "")

        if [ -n "$response" ]; then
            # Check if query returned data
            if echo "$response" | grep -q '"status":"success"'; then
                local result_count
                # Strip newlines and count results properly
                result_count=$(echo "$response" | tr -d '\n' | grep -o '"result":\[' | wc -l || echo "0")
                result_count=$((result_count))  # Ensure it's a number
                if [ "$result_count" -gt 0 ]; then
                    log_success "Query '$query' returned results"
                else
                    log_warning "Query '$query' returned no data points"
                    failed_queries+=("$query")
                fi
            else
                log_error "Query '$query' failed"
                failed_queries+=("$query")
            fi
        else
            log_error "Could not execute query '$query'"
            failed_queries+=("$query")
        fi
    done

    if [ ${#failed_queries[@]} -eq 0 ]; then
        log_success "All test queries executed successfully"
        return 0
    else
        log_error "Failed queries: ${failed_queries[*]}"
        return 1
    fi
}

test_metrics_data_quality() {
    log_info "Testing metrics data quality and consistency..."

    # Test CPU metrics consistency
    local cpu_idle_query="node_cpu_seconds_total{mode=\"idle\"}"
    local cpu_response
    cpu_response=$(curl -s "http://localhost:9090/api/v1/query?query=$cpu_idle_query" 2>/dev/null || echo "")

    if [ -n "$cpu_response" ] && echo "$cpu_response" | grep -q '"status":"success"'; then
        local cpu_count
        cpu_count=$(echo "$cpu_response" | grep -c '"value":\[.*,"[0-9.]*"\]' || echo "0")
        log_success "CPU metrics available for $cpu_count CPU cores"
    else
        log_warning "CPU metrics quality check failed"
    fi

    # Test memory metrics consistency
    local memory_query="node_memory_MemTotal_bytes"
    local memory_response
    memory_response=$(curl -s "http://localhost:9090/api/v1/query?query=$memory_query" 2>/dev/null || echo "")

    if [ -n "$memory_response" ] && echo "$memory_response" | grep -q '"status":"success"'; then
        # Extract memory value (in bytes)
        local memory_bytes
        memory_bytes=$(echo "$memory_response" | grep -o '"value":\[.*,"\([0-9]*\)"\]' | sed 's/.*"\([0-9]*\)".*/\1/' | head -1)
        if [ -n "$memory_bytes" ] && [ "$memory_bytes" -gt 0 ]; then
            local memory_gb
            memory_gb=$((memory_bytes / 1024 / 1024 / 1024))
            log_success "Memory metrics available (Total: ${memory_gb}GB)"
        else
            log_warning "Memory metrics appear invalid"
        fi
    else
        log_warning "Memory metrics quality check failed"
    fi

    # Test filesystem metrics
    local fs_query="node_filesystem_size_bytes{fstype!=\"tmpfs\"}"
    local fs_response
    fs_response=$(curl -s "http://localhost:9090/api/v1/query?query=$fs_query" 2>/dev/null || echo "")

    if [ -n "$fs_response" ] && echo "$fs_response" | grep -q '"status":"success"'; then
        local fs_count
        fs_count=$(echo "$fs_response" | grep -c '"value":\[.*,"[0-9.]*"\]' || echo "0")
        log_success "Filesystem metrics available for $fs_count filesystems"
    else
        log_warning "Filesystem metrics quality check failed"
    fi

    return 0
}

test_scrape_intervals() {
    log_info "Testing scrape interval configuration..."

    # Check Prometheus configuration for scrape intervals
    local config_file="/etc/prometheus/prometheus.yml"

    if [ -f "$config_file" ]; then
        log_info "Analyzing Prometheus configuration..."

        # Check global scrape interval
        local global_interval
        global_interval=$(grep "scrape_interval:" "$config_file" | head -1 | awk '{print $2}' | tr -d '"' || echo "unknown")
        log_info "Global scrape interval: $global_interval"

        # Check if node-exporter job is configured
        if grep -q "job_name.*node.*exporter" "$config_file"; then
            log_success "Node Exporter job configured in Prometheus"
        else
            log_warning "Node Exporter job not found in Prometheus configuration"
        fi

        return 0
    else
        log_error "Prometheus configuration file not found"
        return 1
    fi
}

test_alerting_configuration() {
    log_info "Testing alerting configuration..."

    # Check if alertmanager is configured in Prometheus
    local config_file="/etc/prometheus/prometheus.yml"

    if [ -f "$config_file" ]; then
        if grep -q "alertmanagers:" "$config_file"; then
            log_success "Alertmanager configuration found in Prometheus"

            # Extract alertmanager targets
            local am_targets
            am_targets=$(grep -A 5 "alertmanagers:" "$config_file" | grep "targets:" | awk '{print $2}' | tr -d '"[]' || echo "none")
            log_info "Alertmanager targets: $am_targets"
        else
            log_warning "Alertmanager configuration not found in Prometheus"
        fi
    else
        log_error "Cannot check alerting configuration - Prometheus config missing"
        return 1
    fi

    # Check if alertmanager service is available
    if systemctl is-active prometheus-alertmanager >/dev/null 2>&1; then
        log_success "Alertmanager service is running"
    else
        log_info "Alertmanager service is not running (may be intended)"
    fi

    return 0
}

test_web_interface() {
    log_info "Testing Prometheus web interface functionality..."

    # Test main page
    if curl -sf "http://localhost:9090/" >/dev/null 2>&1; then
        log_success "Prometheus web interface main page accessible"
    else
        log_error "Prometheus web interface main page not accessible"
        return 1
    fi

    # Test graph page
    if curl -sf "http://localhost:9090/graph" >/dev/null 2>&1; then
        log_success "Prometheus graph interface accessible"
    else
        log_warning "Prometheus graph interface not accessible"
    fi

    # Test targets page
    if curl -sf "http://localhost:9090/targets" >/dev/null 2>&1; then
        log_success "Prometheus targets page accessible"
    else
        log_warning "Prometheus targets page not accessible"
    fi

    # Test config page
    if curl -sf "http://localhost:9090/config" >/dev/null 2>&1; then
        log_success "Prometheus configuration page accessible"
    else
        log_warning "Prometheus configuration page not accessible"
    fi

    return 0
}

# Main test execution
main() {
    log_info "=== Starting Monitoring Stack Integration Tests ==="
    log_info "Log file: $LOG_FILE"

    local failed_tests=()

    # Run all integration tests
    test_prometheus_targets || failed_tests+=("prometheus_targets")
    test_prometheus_node_metrics || failed_tests+=("prometheus_node_metrics")
    test_metrics_data_quality || failed_tests+=("metrics_data_quality")
    test_scrape_intervals || failed_tests+=("scrape_intervals")
    test_alerting_configuration || failed_tests+=("alerting_configuration")
    test_web_interface || failed_tests+=("web_interface")

    # Summary
    log_info "=== Integration Test Summary ==="
    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_success "All monitoring stack integration tests passed!"
        exit 0
    else
        log_error "Failed integration tests: ${failed_tests[*]}"
        log_error "Check the log file for details: $LOG_FILE"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
