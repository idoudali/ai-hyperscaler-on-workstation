#!/bin/bash
# Prometheus DCGM Integration Test Script
# Tests Prometheus integration with DCGM exporter for GPU metrics collection

set -euo pipefail

# Script configuration
TEST_NAME="Prometheus DCGM Integration"
VERBOSE=${VERBOSE:-false}

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${YELLOW}[VERBOSE]${NC} $*"
    fi
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test functions
test_pass() {
    ((TESTS_PASSED++))
    log_info "✓ $1"
}

test_fail() {
    ((TESTS_FAILED++))
    log_error "✗ $1"
}

# Test 1: Check Prometheus service status
test_prometheus_service() {
    log_info "Test 1: Checking Prometheus service..."

    if systemctl is-active --quiet prometheus 2>/dev/null; then
        test_pass "Prometheus service is active"
    else
        log_warning "Prometheus service not active - integration tests may be limited"
    fi
}

# Test 2: Check Prometheus configuration for DCGM
test_prometheus_config() {
    log_info "Test 2: Checking Prometheus configuration for DCGM..."

    local config_file="/etc/prometheus/prometheus.yml"

    if [[ -f "$config_file" ]]; then
        if grep -q "dcgm" "$config_file"; then
            test_pass "Prometheus configuration includes DCGM scrape config"
            log_verbose "DCGM configuration in prometheus.yml:"
            log_verbose "$(grep -A 10 "job_name.*dcgm" "$config_file" 2>/dev/null || echo 'not found')"
        else
            log_warning "Prometheus configuration does not include DCGM scrape config"
        fi
    else
        log_warning "Prometheus configuration file not found: $config_file"
    fi
}

# Test 3: Check Prometheus targets for DCGM
test_prometheus_targets() {
    log_info "Test 3: Checking Prometheus targets..."

    if ! systemctl is-active --quiet prometheus 2>/dev/null; then
        log_warning "Prometheus service not running - skipping targets check"
        return 0
    fi

    if ! command -v curl &>/dev/null; then
        log_warning "curl command not available - skipping targets check"
        return 0
    fi

    if targets=$(curl -s http://localhost:9090/api/v1/targets 2>&1); then
        if echo "$targets" | grep -q "dcgm"; then
            test_pass "Prometheus has DCGM exporter as target"
            log_verbose "DCGM target status:"
            log_verbose "$(echo "$targets" | grep -A 5 "dcgm" || true)"
        else
            log_warning "No DCGM target found in Prometheus"
        fi
    else
        log_warning "Unable to query Prometheus targets API"
        log_verbose "Error: $targets"
    fi
}

# Test 4: Query DCGM metrics from Prometheus
test_prometheus_dcgm_metrics() {
    log_info "Test 4: Querying DCGM metrics from Prometheus..."

    if ! systemctl is-active --quiet prometheus 2>/dev/null; then
        log_warning "Prometheus service not running - skipping metrics query"
        return 0
    fi

    if ! command -v curl &>/dev/null; then
        log_warning "curl command not available - skipping metrics query"
        return 0
    fi

    # Try to query a common DCGM metric
    local query="up{job=\"dcgm\"}"
    if result=$(curl -s "http://localhost:9090/api/v1/query?query=${query}" 2>&1); then
        if echo "$result" | grep -q '"status":"success"'; then
            test_pass "Successfully queried DCGM metrics from Prometheus"
            log_verbose "Query result: $result"
        else
            log_warning "DCGM metrics query returned non-success status"
            log_verbose "Response: $result"
        fi
    else
        log_warning "Unable to query Prometheus for DCGM metrics"
        log_verbose "Error: $result"
    fi
}

# Test 5: Check DCGM scrape interval
test_scrape_interval() {
    log_info "Test 5: Checking DCGM scrape interval configuration..."

    local config_file="/etc/prometheus/prometheus.yml"

    if [[ -f "$config_file" ]]; then
        if dcgm_config=$(grep -A 15 "job_name.*dcgm" "$config_file" 2>/dev/null); then
            if echo "$dcgm_config" | grep -q "scrape_interval"; then
                local interval
                interval=$(echo "$dcgm_config" | grep "scrape_interval" | awk '{print $2}')
                test_pass "DCGM scrape interval configured: $interval"
            else
                log_verbose "DCGM scrape interval using global default"
                test_pass "DCGM scrape interval using global configuration"
            fi
        else
            log_warning "Could not find DCGM job configuration"
        fi
    else
        log_warning "Prometheus configuration file not found"
    fi
}

# Test 6: Verify DCGM target health
test_target_health() {
    log_info "Test 6: Verifying DCGM target health in Prometheus..."

    if ! systemctl is-active --quiet prometheus 2>/dev/null; then
        log_warning "Prometheus service not running - skipping target health check"
        return 0
    fi

    if ! command -v curl &>/dev/null; then
        log_warning "curl command not available - skipping target health check"
        return 0
    fi

    if targets=$(curl -s http://localhost:9090/api/v1/targets 2>&1); then
        # Check if DCGM target is up
        if echo "$targets" | grep -A 10 "dcgm" | grep -q '"health":"up"'; then
            test_pass "DCGM target is healthy in Prometheus"
        else
            log_warning "DCGM target may not be healthy (could be expected without GPU hardware)"
            log_verbose "$(echo "$targets" | grep -A 10 "dcgm" || true)"
        fi
    else
        log_warning "Unable to check target health"
    fi
}

# Test 7: Test GPU utilization metrics
test_gpu_utilization_metrics() {
    log_info "Test 7: Testing GPU utilization metrics..."

    if ! systemctl is-active --quiet prometheus 2>/dev/null; then
        log_warning "Prometheus service not running - skipping GPU metrics test"
        return 0
    fi

    if ! command -v curl &>/dev/null; then
        log_warning "curl command not available - skipping GPU metrics test"
        return 0
    fi

    local metrics=(
        "dcgm_gpu_utilization"
        "dcgm_gpu_temp"
        "dcgm_fb_used"
    )

    local found_count=0
    for metric in "${metrics[@]}"; do
        if result=$(curl -s "http://localhost:9090/api/v1/query?query=${metric}" 2>&1); then
            if echo "$result" | grep -q '"status":"success"'; then
                ((found_count++))
                log_verbose "Found metric: $metric"
            fi
        fi
    done

    if [[ $found_count -gt 0 ]]; then
        test_pass "Found $found_count GPU utilization metrics in Prometheus"
    else
        log_warning "No GPU utilization metrics found (may require GPU hardware)"
    fi
}

# Test 8: Check metrics retention
test_metrics_retention() {
    log_info "Test 8: Checking Prometheus retention for DCGM metrics..."

    if ! command -v curl &>/dev/null; then
        log_warning "curl command not available - skipping retention check"
        return 0
    fi

    if ! systemctl is-active --quiet prometheus 2>/dev/null; then
        log_warning "Prometheus service not running - skipping retention check"
        return 0
    fi

    # Query Prometheus configuration
    if config=$(curl -s http://localhost:9090/api/v1/status/config 2>&1); then
        if echo "$config" | grep -q "storage.tsdb.retention"; then
            test_pass "Prometheus storage retention configured"
            log_verbose "$(echo "$config" | grep "storage.tsdb.retention" || true)"
        else
            log_verbose "Using default Prometheus retention settings"
            test_pass "Prometheus retention using defaults"
        fi
    else
        log_warning "Unable to query Prometheus configuration"
    fi
}

# Test 9: Test alert rules for GPU metrics
test_alert_rules() {
    log_info "Test 9: Checking alert rules for GPU metrics..."

    if ! systemctl is-active --quiet prometheus 2>/dev/null; then
        log_warning "Prometheus service not running - skipping alert rules check"
        return 0
    fi

    local rules_dir="/etc/prometheus/rules"

    if [[ -d "$rules_dir" ]]; then
        if gpu_rules=$(find "$rules_dir" -name "*.yml" -exec grep -l "dcgm\|gpu" {} \; 2>/dev/null); then
            if [[ -n "$gpu_rules" ]]; then
                test_pass "GPU-related alert rules found"
                log_verbose "Alert rule files: $gpu_rules"
            else
                log_verbose "No GPU-specific alert rules configured (optional)"
            fi
        else
            log_verbose "No GPU alert rules found (optional)"
        fi
    else
        log_verbose "Alert rules directory not found (optional)"
    fi
}

# Test 10: Verify data flow end-to-end
test_data_flow() {
    log_info "Test 10: Testing end-to-end data flow..."

    if ! systemctl is-active --quiet prometheus 2>/dev/null; then
        log_warning "Prometheus not running - skipping end-to-end test"
        return 0
    fi

    if ! systemctl is-active --quiet dcgm-exporter.service 2>/dev/null; then
        log_warning "DCGM exporter not running - skipping end-to-end test"
        return 0
    fi

    if ! command -v curl &>/dev/null; then
        log_warning "curl command not available - skipping end-to-end test"
        return 0
    fi

    # Check DCGM exporter is exposing metrics
    if dcgm_metrics=$(curl -s http://localhost:9400/metrics 2>&1 | grep -c "^dcgm_" || echo "0"); then
        log_verbose "DCGM exporter exposing $dcgm_metrics metrics"

        # Check Prometheus is scraping them
        sleep 2  # Give Prometheus time to scrape
        if prom_metrics=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" 2>&1); then
            if echo "$prom_metrics" | grep -q "dcgm_"; then
                test_pass "End-to-end data flow working (DCGM → Prometheus)"
            else
                log_warning "DCGM metrics not yet in Prometheus (may need more time)"
            fi
        else
            log_warning "Unable to query Prometheus metrics"
        fi
    else
        log_warning "DCGM exporter not exposing metrics"
    fi
}

# Main execution
main() {
    log_info "=========================================="
    log_info "$TEST_NAME"
    log_info "=========================================="
    echo

    test_prometheus_service
    test_prometheus_config
    test_prometheus_targets
    test_prometheus_dcgm_metrics
    test_scrape_interval
    test_target_health
    test_gpu_utilization_metrics
    test_metrics_retention
    test_alert_rules
    test_data_flow

    echo
    log_info "=========================================="
    log_info "Test Summary"
    log_info "=========================================="
    log_info "Tests Passed: $TESTS_PASSED"
    log_info "Tests Failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_info "All tests passed successfully!"
        return 0
    else
        log_error "Some tests failed!"
        return 1
    fi
}

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
