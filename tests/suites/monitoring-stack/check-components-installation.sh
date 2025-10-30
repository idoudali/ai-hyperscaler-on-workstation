#!/bin/bash
# Monitoring stack components installation validation test script
# Consolidated tests for Prometheus and Node Exporter installation
# Part of Task 015: Install Prometheus Monitoring Stack

source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-logging.sh"
set -euo pipefail

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="check-components-installation.sh"
# shellcheck disable=SC2034
TEST_NAME="Monitoring Stack Components Installation Validation"

# =============================================================================
# PROMETHEUS INSTALLATION TESTS
# =============================================================================

test_prometheus_packages() {
    log_info "Testing Prometheus packages installation..."

    local packages=("prometheus" "prometheus-node-exporter" "prometheus-alertmanager")
    local missing_packages=()

    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii\s*$package\s"; then
            log_success "Package $package is installed"
        else
            missing_packages+=("$package")
            log_warning "Package $package is not installed"
        fi
    done

    if [ ${#missing_packages[@]} -eq 0 ]; then
        log_success "All Prometheus packages are installed"
        return 0
    else
        log_error "Missing packages: ${missing_packages[*]}"
        return 1
    fi
}

test_prometheus_user() {
    log_info "Testing Prometheus user and group setup..."

    if id prometheus >/dev/null 2>&1; then
        log_success "Prometheus user exists"

        # Check if user is system user
        local user_id
        user_id=$(id -u prometheus)
        if [ "$user_id" -lt 1000 ]; then
            log_success "Prometheus user is a system user (UID: $user_id)"
        else
            log_warning "Prometheus user is not a system user (UID: $user_id)"
        fi

        # Check group membership
        if groups prometheus | grep -q prometheus; then
            log_success "Prometheus user is in prometheus group"
        else
            log_error "Prometheus user is not in prometheus group"
            return 1
        fi

        return 0
    else
        log_error "Prometheus user does not exist"
        return 1
    fi
}

test_prometheus_directories() {
    log_info "Testing Prometheus directory structure..."

    local directories=(
        "/etc/prometheus"
        "/var/lib/prometheus"
    )

    local failed=0

    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            log_success "Directory $dir exists"

            # Check ownership
            local owner
            owner=$(stat -c "%U:%G" "$dir")
            if [ "$owner" = "prometheus:prometheus" ]; then
                log_success "Directory $dir has correct ownership ($owner)"
            else
                log_warning "Directory $dir has incorrect ownership ($owner), expected prometheus:prometheus"
                failed=1
            fi

            # Check permissions
            local perms
            perms=$(stat -c "%a" "$dir")
            if [ "$perms" = "755" ]; then
                log_success "Directory $dir has correct permissions ($perms)"
            else
                log_warning "Directory $dir has incorrect permissions ($perms), expected 755"
                failed=1
            fi
        else
            log_error "Directory $dir does not exist"
            failed=1
        fi
    done

    return $failed
}

test_prometheus_configuration() {
    log_info "Testing Prometheus configuration..."

    local config_file="/etc/prometheus/prometheus.yml"

    if [ -f "$config_file" ]; then
        log_success "Prometheus configuration file exists"

        # Check file ownership and permissions
        local owner
        owner=$(stat -c "%U:%G" "$config_file")
        local perms
        perms=$(stat -c "%a" "$config_file")

        if [ "$owner" = "prometheus:prometheus" ]; then
            log_success "Configuration file has correct ownership ($owner)"
        else
            log_warning "Configuration file has incorrect ownership ($owner)"
        fi

        if [ "$perms" = "644" ]; then
            log_success "Configuration file has correct permissions ($perms)"
        else
            log_warning "Configuration file has incorrect permissions ($perms)"
        fi

        # Test configuration syntax (if promtool is installed)
        if command -v promtool >/dev/null 2>&1; then
            log_info "Validating Prometheus configuration syntax..."
            if promtool check config "$config_file" >/dev/null 2>&1; then
                log_success "Prometheus configuration syntax is valid"
                return 0
            else
                log_error "Prometheus configuration syntax is invalid"
                return 1
            fi
        else
            log_warning "promtool not found, cannot validate configuration syntax"
            return 0
        fi
    else
        log_error "Prometheus configuration file does not exist"
        return 1
    fi
}

test_prometheus_service() {
    log_info "Testing Prometheus service status..."

    if systemctl is-enabled prometheus >/dev/null 2>&1; then
        log_success "Prometheus service is enabled"
    else
        log_warning "Prometheus service is not enabled"
    fi

    if systemctl is-active prometheus >/dev/null 2>&1; then
        log_success "Prometheus service is active (running)"

        # Get service status details
        local status
        status=$(systemctl status prometheus --no-pager -l 2>/dev/null | head -20)
        log_info "Prometheus service status details:"
        echo "$status" | tee -a "$LOG_FILE"

        return 0
    else
        log_warning "Prometheus service is not active"
        local status
        status=$(systemctl status prometheus --no-pager -l 2>/dev/null | head -20)
        log_info "Prometheus service status details:"
        echo "$status" | tee -a "$LOG_FILE"
        return 1
    fi
}

test_prometheus_connectivity() {
    log_info "Testing Prometheus web interface connectivity..."

    # Wait a moment for service to be fully ready
    sleep 5

    # Test readiness endpoint
    if curl -sf http://localhost:9090/-/ready >/dev/null 2>&1; then
        log_success "Prometheus readiness endpoint is accessible"
    else
        log_error "Prometheus readiness endpoint is not accessible"
        return 1
    fi

    # Test metrics endpoint
    if curl -sf http://localhost:9090/metrics >/dev/null 2>&1; then
        log_success "Prometheus metrics endpoint is accessible"
    else
        log_error "Prometheus metrics endpoint is not accessible"
        return 1
    fi

    # Test query API
    if curl -sf "http://localhost:9090/api/v1/query?query=up" >/dev/null 2>&1; then
        log_success "Prometheus query API is accessible"

        # Get actual up targets count
        local up_targets
        up_targets=$(curl -s "http://localhost:9090/api/v1/query?query=up" | jq -r '.data.result | length' 2>/dev/null || echo "0")
        log_info "Found $up_targets active targets"

        return 0
    else
        log_error "Prometheus query API is not accessible"
        return 1
    fi
}

# =============================================================================
# NODE EXPORTER INSTALLATION TESTS
# =============================================================================

test_node_exporter_package() {
    log_info "Testing Node Exporter package installation..."

    if dpkg -l | grep -q "^ii\s*prometheus-node-exporter\s"; then
        log_success "prometheus-node-exporter package is installed"

        # Get version info
        local version
        version=$(dpkg -l prometheus-node-exporter | grep "^ii" | awk '{print $3}')
        log_info "Installed version: $version"

        return 0
    else
        log_error "prometheus-node-exporter package is not installed"
        return 1
    fi
}

test_node_exporter_service() {
    log_info "Testing Node Exporter service status..."

    if systemctl is-enabled prometheus-node-exporter >/dev/null 2>&1; then
        log_success "Node Exporter service is enabled"
    else
        log_warning "Node Exporter service is not enabled"
    fi

    if systemctl is-active prometheus-node-exporter >/dev/null 2>&1; then
        log_success "Node Exporter service is active (running)"

        # Get service status details
        local status
        status=$(systemctl status prometheus-node-exporter --no-pager -l 2>/dev/null | head -20)
        log_info "Node Exporter service status details:"
        echo "$status" | tee -a "$LOG_FILE"

        return 0
    else
        log_error "Node Exporter service is not active"
        local status
        status=$(systemctl status prometheus-node-exporter --no-pager -l 2>/dev/null | head -20)
        log_info "Node Exporter service status details:"
        echo "$status" | tee -a "$LOG_FILE"
        return 1
    fi
}

test_node_exporter_port() {
    log_info "Testing Node Exporter port availability..."

    local port=9100

    # Check if port is listening
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        log_success "Node Exporter is listening on port $port"
        return 0
    else
        log_error "Node Exporter is not listening on port $port"
        return 1
    fi
}

test_node_exporter_metrics_endpoint() {
    log_info "Testing Node Exporter metrics endpoint..."

    local endpoint="http://localhost:9100/metrics"

    # Wait a moment for service to be ready
    sleep 3

    if curl -sf "$endpoint" >/dev/null 2>&1; then
        log_success "Node Exporter metrics endpoint is accessible"

        # Get metrics content for validation
        local metrics_content
        metrics_content=$(curl -s "$endpoint" 2>/dev/null)

        if [ -n "$metrics_content" ]; then
            log_success "Node Exporter is returning metrics data"

            # Count metrics
            local metrics_count
            metrics_count=$(echo "$metrics_content" | grep -c "^[a-zA-Z]" || true)
            log_info "Collecting $metrics_count metrics families"

            return 0
        else
            log_error "Node Exporter metrics endpoint returned empty content"
            return 1
        fi
    else
        log_error "Node Exporter metrics endpoint is not accessible"
        return 1
    fi
}

test_key_metrics_collection() {
    log_info "Testing collection of key system metrics..."

    local endpoint="http://localhost:9100/metrics"
    local required_metrics=(
        "node_cpu_seconds_total"
        "node_memory_MemTotal_bytes"
        "node_filesystem_size_bytes"
        "node_load1"
        "node_load5"
        "node_load15"
        "node_network_receive_bytes_total"
        "node_network_transmit_bytes_total"
        "node_disk_read_bytes_total"
        "node_disk_written_bytes_total"
    )

    local missing_metrics=()

    # Get metrics content
    local metrics_content
    metrics_content=$(curl -s "$endpoint" 2>/dev/null || echo "")

    if [ -z "$metrics_content" ]; then
        log_error "Could not retrieve metrics content"
        return 1
    fi

    # Check each required metric
    for metric in "${required_metrics[@]}"; do
        if echo "$metrics_content" | grep -q "^${metric}[{ ]"; then
            log_success "Metric $metric is available"
        else
            missing_metrics+=("$metric")
            log_warning "Metric $metric is missing"
        fi
    done

    if [ ${#missing_metrics[@]} -eq 0 ]; then
        log_success "All key system metrics are being collected"
        return 0
    else
        log_error "Missing key metrics: ${missing_metrics[*]}"
        return 1
    fi
}

test_collector_configuration() {
    log_info "Testing Node Exporter collector configuration..."

    # Check if configuration files exist
    local config_locations=(
        "/etc/default/prometheus-node-exporter"
        "/etc/systemd/system/prometheus-node-exporter.service.d/override.conf"
    )

    local config_found=false

    for config_file in "${config_locations[@]}"; do
        if [ -f "$config_file" ]; then
            log_success "Configuration file found: $config_file"
            config_found=true

            # Show configuration content
            log_info "Configuration content:"
            tee -a "$LOG_FILE" < "$config_file"
        fi
    done

    if [ "$config_found" = false ]; then
        log_warning "No custom configuration files found - using defaults"
    fi

    # Check enabled collectors by looking at process arguments
    local process_args
    process_args=$(pgrep -f "prometheus-node-exporter" | head -1 || true)
    if [ -n "$process_args" ]; then
        log_info "Node Exporter process arguments:"
        echo "$process_args" | tee -a "$LOG_FILE"

        # Check for key collectors
        if echo "$process_args" | grep -q "collector.systemd"; then
            log_success "systemd collector is enabled"
        else
            log_info "systemd collector status unknown from process args"
        fi
    else
        log_warning "Could not retrieve Node Exporter process arguments"
    fi

    return 0
}

test_systemd_integration() {
    log_info "Testing systemd integration..."

    # Check if systemd collector is working by looking for systemd metrics
    local endpoint="http://localhost:9100/metrics"
    local systemd_metrics
    systemd_metrics=$(curl -s "$endpoint" 2>/dev/null | grep -c "^node_systemd_" || echo "0")

    if [ "$systemd_metrics" -gt 0 ]; then
        log_success "systemd integration working ($systemd_metrics systemd metrics found)"
        return 0
    else
        log_warning "systemd integration may not be working (no systemd metrics found)"
        return 1
    fi
}

# =============================================================================
# MAIN TEST EXECUTION
# =============================================================================

# Main test execution
main() {
    log_info "=== Starting Monitoring Components Installation Tests ==="
    log_info "Log file: $LOG_FILE"

    local failed_tests=()

    # Prometheus tests
    log_info ""
    log_info "=== PROMETHEUS INSTALLATION TESTS ==="
    test_prometheus_packages || failed_tests+=("prometheus_packages")
    test_prometheus_user || failed_tests+=("prometheus_user")
    test_prometheus_directories || failed_tests+=("prometheus_directories")
    test_prometheus_configuration || failed_tests+=("prometheus_configuration")
    test_prometheus_service || failed_tests+=("prometheus_service")
    test_prometheus_connectivity || failed_tests+=("prometheus_connectivity")

    # Node Exporter tests
    log_info ""
    log_info "=== NODE EXPORTER INSTALLATION TESTS ==="
    test_node_exporter_package || failed_tests+=("node_exporter_package")
    test_node_exporter_service || failed_tests+=("node_exporter_service")
    test_node_exporter_port || failed_tests+=("node_exporter_port")
    test_node_exporter_metrics_endpoint || failed_tests+=("node_exporter_metrics_endpoint")
    test_key_metrics_collection || failed_tests+=("key_metrics_collection")
    test_collector_configuration || failed_tests+=("collector_configuration")
    test_systemd_integration || failed_tests+=("systemd_integration")

    # Summary
    log_info ""
    log_info "=== COMPONENTS INSTALLATION TEST SUMMARY ==="
    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_success "All monitoring components installation tests passed!"
        log_info "Both Prometheus server and Node Exporter are properly installed and configured"
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
