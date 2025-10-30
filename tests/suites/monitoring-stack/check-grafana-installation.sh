#!/bin/bash
# Grafana Installation Validation Script
# Validates Grafana installation, configuration, and basic functionality
# Part of the Task 016 Grafana implementation

source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
set -euo pipefail

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="check-grafana-installation.sh"
# shellcheck disable=SC2034
TEST_NAME="Grafana Installation Validation"
# Define test suite name for logging/reporting consistency
TEST_SUITE_NAME="Grafana Installation Validation"

# Grafana installation validation tests
test_grafana_package_installation() {
    log_info "Testing Grafana package installation..."

    # Check if Grafana package is installed
    if dpkg -l | grep -q "^ii.*grafana"; then
        log_success "Grafana package is installed"
        return 0
    else
        log_error "Grafana package is not installed"
        return 1
    fi
}

test_grafana_user_group() {
    log_info "Testing Grafana user and group creation..."

    # Check if grafana user exists
    if id -u grafana >/dev/null 2>&1; then
        log_success "Grafana user exists"
    else
        log_error "Grafana user does not exist"
        return 1
    fi

    # Check if grafana group exists
    if getent group grafana >/dev/null 2>&1; then
        log_success "Grafana group exists"
    else
        log_error "Grafana group does not exist"
        return 1
    fi

    # Check user group membership
    if groups grafana | grep -q grafana; then
        log_success "Grafana user belongs to grafana group"
    else
        log_error "Grafana user does not belong to grafana group"
        return 1
    fi
}

test_grafana_directories() {
    log_info "Testing Grafana directory structure..."

    local required_dirs=(
        "/etc/grafana"
        "/var/lib/grafana"
        "/var/log/grafana"
        "/var/lib/grafana/plugins"
        "/etc/grafana/provisioning"
        "/etc/grafana/provisioning/datasources"
        "/etc/grafana/provisioning/dashboards"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "Directory exists: $dir"
        else
            log_error "Directory missing: $dir"
            return 1
        fi

        # Check ownership
        if [[ "$(stat -c '%U:%G' "$dir")" == "grafana:grafana" ]]; then
            log_success "Correct ownership for $dir: grafana:grafana"
        else
            log_error "Incorrect ownership for $dir: $(stat -c '%U:%G' "$dir")"
            return 1
        fi

        # Check permissions (should be 0750)
        if [[ "$(stat -c '%a' "$dir")" == "750" ]]; then
            log_success "Correct permissions for $dir: 750"
        else
            log_error "Incorrect permissions for $dir: $(stat -c '%a' "$dir")"
            return 1
        fi
    done
}

test_grafana_configuration() {
    log_info "Testing Grafana configuration..."

    # Check if main configuration file exists
    if [[ -f "/etc/grafana/grafana.ini" ]]; then
        log_success "Grafana configuration file exists"
    else
        log_error "Grafana configuration file missing"
        return 1
    fi

    # Check configuration file ownership
    if [[ "$(stat -c '%U:%G' /etc/grafana/grafana.ini)" == "grafana:grafana" ]]; then
        log_success "Grafana configuration file has correct ownership"
    else
        log_error "Grafana configuration file has incorrect ownership"
        return 1
    fi

    # Check configuration file permissions
    if [[ "$(stat -c '%a' /etc/grafana/grafana.ini)" == "640" ]]; then
        log_success "Grafana configuration file has correct permissions"
    else
        log_error "Grafana configuration file has incorrect permissions"
        return 1
    fi

    # Check for required configuration sections
    local required_sections=(
        "server"
        "database"
        "session"
        "security"
        "paths"
    )

    for section in "${required_sections[@]}"; do
        if grep -q "^\[$section\]" /etc/grafana/grafana.ini; then
            log_success "Configuration section found: [$section]"
        else
            log_error "Configuration section missing: [$section]"
            return 1
        fi
    done
}

test_grafana_provisioning() {
    log_info "Testing Grafana provisioning configuration..."

    # Check if Prometheus data source provisioning exists
    if [[ -f "/etc/grafana/provisioning/datasources/prometheus.yml" ]]; then
        log_success "Prometheus data source provisioning exists"
    else
        log_error "Prometheus data source provisioning missing"
        return 1
    fi

    # Check if dashboard provisioning exists
    if [[ -f "/etc/grafana/provisioning/dashboards/system-overview.yml" ]]; then
        log_success "Dashboard provisioning exists"
    else
        log_error "Dashboard provisioning missing"
        return 1
    fi

    # Check if dashboard JSON file exists
    if [[ -f "/etc/grafana/provisioning/dashboards/system-overview.json" ]]; then
        log_success "Dashboard JSON file exists"
    else
        log_error "Dashboard JSON file missing"
        return 1
    fi
}

test_grafana_service() {
    log_info "Testing Grafana service configuration..."

    # Check if service file exists
    if systemctl list-unit-files | grep -q grafana-server; then
        log_success "Grafana service file exists"
    else
        log_error "Grafana service file missing"
        return 1
    fi

    # Check service status (should be active if enabled)
    if systemctl is-active --quiet grafana-server; then
        log_success "Grafana service is active"
    else
        log_warning "Grafana service is not active (may be expected in build environment)"
    fi

    # Check if service is enabled
    if systemctl is-enabled --quiet grafana-server; then
        log_success "Grafana service is enabled"
    else
        log_warning "Grafana service is not enabled (may be expected in build environment)"
    fi
}

test_grafana_service_override() {
    log_info "Testing Grafana systemd service override..."

    # Check if service override exists
    if [[ -f "/etc/systemd/system/grafana-server.service.d/override.conf" ]]; then
        log_success "Grafana service override exists"
    else
        log_error "Grafana service override missing"
        return 1
    fi

    # Check override content
    if grep -q "User=grafana" /etc/systemd/system/grafana-server.service.d/override.conf; then
        log_success "Service override has correct user configuration"
    else
        log_error "Service override missing user configuration"
        return 1
    fi

    if grep -q "Group=grafana" /etc/systemd/system/grafana-server.service.d/override.conf; then
        log_success "Service override has correct group configuration"
    else
        log_error "Service override missing group configuration"
        return 1
    fi
}

# Main test execution
main() {
    init_suite_logging "$TEST_SUITE_NAME"

    log_info "=== $TEST_SUITE_NAME ==="

    run_test "Package Installation" test_grafana_package_installation
    run_test "User and Group" test_grafana_user_group
    run_test "Directory Structure" test_grafana_directories
    run_test "Configuration" test_grafana_configuration
    run_test "Provisioning" test_grafana_provisioning
    run_test "Service Configuration" test_grafana_service
    run_test "Service Override" test_grafana_service_override

    # Collect and report results using common utilities
    collect_test_results
    generate_test_report
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
