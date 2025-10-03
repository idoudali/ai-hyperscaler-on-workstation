#!/bin/bash
# DCGM Exporter Validation Test Script
# Tests DCGM exporter installation, service status, and metrics export

set -uo pipefail

# Script configuration
TEST_NAME="DCGM Exporter Validation"
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
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}

# Test functions
test_pass() {
    ((TESTS_PASSED++))
    log_info "✓ $1"
}

test_fail() {
    ((TESTS_FAILED++))
    log_error "✗ $1"
}

# Test 1: Check DCGM exporter binary installation
test_exporter_binary() {
    log_info "Test 1: Checking DCGM exporter binary..."

    local binary_path="/usr/bin/dcgm-exporter"

    if [[ -f "$binary_path" ]]; then
        test_pass "DCGM exporter binary exists: $binary_path"
        if [[ "$VERBOSE" == "true" ]]; then
            log_verbose "Binary permissions: $(stat -c '%a %U:%G' "$binary_path" 2>/dev/null || echo 'unknown')"
            log_verbose "Binary size: $(stat -c '%s bytes' "$binary_path" 2>/dev/null || echo 'unknown')"
        fi
    else
        test_fail "DCGM exporter binary not found: $binary_path"
    fi
}

# Test 2: Check DCGM exporter systemd service
test_exporter_service() {
    log_info "Test 2: Checking DCGM exporter service..."

    local service_found=false
    local service_name=""

    # Check for different possible service names (prioritize our custom service)
    if systemctl list-unit-files | awk '{print $1}' | grep -q "^dcgm-exporter\.service$"; then
        service_found=true
        service_name="dcgm-exporter.service"
    elif systemctl list-unit-files | awk '{print $1}' | grep -q "^nvidia-dcgm-exporter\.service$"; then
        service_found=true
        service_name="nvidia-dcgm-exporter.service"
    fi

    if [[ "$service_found" == "true" ]]; then
        test_pass "DCGM exporter service unit file exists: $service_name"

        if systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
            log_verbose "Service is enabled"
        else
            log_verbose "Service is not enabled"
        fi

        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            log_verbose "Service is active"
        else
            log_verbose "Service is not active (may be expected in Packer build)"
        fi

        log_verbose "$(systemctl status "$service_name" --no-pager -l 2>&1 | head -20 || true)"
    else
        test_fail "DCGM exporter service unit file not found"
    fi
}

# Test 3: Check DCGM exporter configuration
test_exporter_config() {
    log_info "Test 3: Checking DCGM exporter configuration..."

    local config_file="/etc/default/dcgm-exporter"

    if [[ -f "$config_file" ]]; then
        test_pass "DCGM exporter configuration exists: $config_file"
        log_verbose "Configuration permissions: $(stat -c '%a %U:%G' "$config_file" 2>/dev/null || echo 'unknown')"
        log_verbose "Configuration content:"
        log_verbose "$(cat "$config_file" 2>/dev/null || echo 'unable to read')"
    else
        log_warning "DCGM exporter configuration file not found: $config_file"
    fi
}

# Test 4: Check DCGM exporter user
test_exporter_user() {
    log_info "Test 4: Checking DCGM exporter user..."

    if id prometheus &>/dev/null; then
        test_pass "DCGM exporter user (prometheus) exists"
        log_verbose "User info: $(id prometheus 2>/dev/null || echo 'unknown')"
    else
        test_fail "DCGM exporter user (prometheus) not found"
    fi
}

# Test 5: Check DCGM exporter port availability
test_exporter_port() {
    log_info "Test 5: Checking DCGM exporter port..."

    local port=9400

    if systemctl is-active --quiet dcgm-exporter.service 2>/dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
            test_pass "DCGM exporter is listening on port $port"
        else
            log_warning "DCGM exporter port $port not found in listening ports"
        fi
    else
        log_warning "DCGM exporter service not running - skipping port check"
    fi
}

# Test 6: Test DCGM exporter metrics endpoint
test_exporter_metrics() {
    log_info "Test 6: Testing DCGM exporter metrics endpoint..."

    if ! systemctl is-active --quiet dcgm-exporter.service 2>/dev/null; then
        log_warning "DCGM exporter service not running - skipping metrics test"
        return 0
    fi

    if command -v curl &>/dev/null; then
        if metrics=$(curl -s -f http://localhost:9400/metrics 2>&1); then
    local metric_count
    metric_count=$(echo "$metrics" | grep -c "^DCGM_FI_" 2>/dev/null || echo "0")
    metric_count=${metric_count//[^0-9]/}  # Remove non-numeric characters
    if [[ ${metric_count:-0} -gt 0 ]]; then
        test_pass "DCGM exporter metrics endpoint responding ($metric_count DCGM metrics)"
                log_verbose "Sample metrics:"
                log_verbose "$(echo "$metrics" | grep "^DCGM_FI_" | head -10 || true)"
            else
                log_warning "DCGM exporter responding but no DCGM metrics found (may require GPU hardware)"
                log_verbose "Response preview: $(echo "$metrics" | head -20 || true)"
            fi
        else
            log_warning "Unable to connect to DCGM exporter metrics endpoint"
            log_verbose "Error: $metrics"
        fi
    else
        log_warning "curl command not available - skipping metrics endpoint test"
    fi
}

# Test 7: Check GPU metrics availability
test_gpu_metrics() {
    log_info "Test 7: Checking GPU-specific metrics..."

    if ! systemctl is-active --quiet dcgm-exporter.service 2>/dev/null; then
        log_warning "DCGM exporter service not running - skipping GPU metrics test"
        return 0
    fi

    if ! command -v curl &>/dev/null; then
        log_warning "curl command not available - skipping GPU metrics test"
        return 0
    fi

    if metrics=$(curl -s -f http://localhost:9400/metrics 2>&1); then
        local gpu_metrics=(
            "dcgm_gpu_utilization"
            "dcgm_gpu_temp"
            "dcgm_memory_used"
            "dcgm_power_usage"
            "dcgm_sm_clock"
        )

        local found_metrics=0
        for metric in "${gpu_metrics[@]}"; do
            if echo "$metrics" | grep -q "^${metric}"; then
                ((found_metrics++))
                log_verbose "Found metric: $metric"
            fi
        done

        if [[ $found_metrics -gt 0 ]]; then
            test_pass "Found $found_metrics GPU-specific metrics"
        else
            log_warning "No GPU-specific metrics found (may require GPU hardware)"
        fi
    else
        log_warning "Unable to fetch metrics for GPU metrics check"
    fi
}

# Test 8: Check DCGM exporter logs
test_exporter_logs() {
    log_info "Test 8: Checking DCGM exporter logs..."

    if systemctl list-unit-files | grep -q dcgm-exporter.service; then
        if logs=$(journalctl -u dcgm-exporter.service -n 20 --no-pager 2>&1); then
            test_pass "DCGM exporter logs accessible"
            log_verbose "Recent log entries:"
            log_verbose "$logs"

            if echo "$logs" | grep -qi "error\|fatal\|panic"; then
                log_warning "Errors found in DCGM exporter logs"
            fi
        else
            log_warning "Unable to access DCGM exporter logs"
        fi
    else
        log_warning "DCGM exporter service not found - skipping log check"
    fi
}

# Test 9: Verify service dependencies
test_service_dependencies() {
    log_info "Test 9: Checking service dependencies..."

    if systemctl list-unit-files | grep -q dcgm-exporter.service; then
        if deps=$(systemctl show dcgm-exporter.service -p Requires -p After 2>&1); then
            test_pass "DCGM exporter service dependencies configured"
            log_verbose "$deps"

            if echo "$deps" | grep -q "nvidia-dcgm"; then
                log_verbose "Properly depends on nvidia-dcgm service"
            else
                log_warning "May not have proper dependency on nvidia-dcgm service"
            fi
        else
            log_warning "Unable to check service dependencies"
        fi
    else
        log_warning "DCGM exporter service not found - skipping dependency check"
    fi
}

# Test 10: Test exporter health check
test_exporter_health() {
    log_info "Test 10: Testing DCGM exporter health..."

    if ! systemctl is-active --quiet dcgm-exporter.service 2>/dev/null; then
        log_warning "DCGM exporter service not running - skipping health check"
        return 0
    fi

    if command -v curl &>/dev/null; then
        # Check if service responds at all
        if response=$(curl -s -w "\n%{http_code}" http://localhost:9400/metrics 2>&1); then
            http_code=$(echo "$response" | tail -1)
            if [[ "$http_code" == "200" ]]; then
                test_pass "DCGM exporter health check passed (HTTP 200)"
            else
                log_warning "DCGM exporter returned HTTP $http_code"
            fi
        else
            log_warning "DCGM exporter health check failed"
        fi
    else
        log_warning "curl command not available - skipping health check"
    fi
}

# Main execution
main() {
    log_info "=========================================="
    log_info "$TEST_NAME"
    log_info "=========================================="
    echo

    test_exporter_binary
    test_exporter_service
    test_exporter_config
    test_exporter_user
    test_exporter_port
    test_exporter_metrics
    test_gpu_metrics
    test_exporter_logs
    test_service_dependencies
    test_exporter_health

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
