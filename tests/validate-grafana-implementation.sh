#!/bin/bash
# Grafana Implementation Validation Script
# Validates Task 016 Grafana implementation without requiring full infrastructure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    log_info "Running test: $test_name"

    if "$test_function"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "Test passed: $test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "Test failed: $test_name"
    fi
}

# Test 1: Ansible role structure validation
test_ansible_role_structure() {
    log_info "Testing Ansible role structure..."

    # Check if monitoring-stack role exists
    if [[ -d "ansible/roles/monitoring-stack" ]]; then
        log_success "Monitoring stack role exists"
    else
        log_error "Monitoring stack role missing"
        return 1
    fi

    # Check if Grafana task file exists
    if [[ -f "ansible/roles/monitoring-stack/tasks/grafana.yml" ]]; then
        log_success "Grafana task file exists"
    else
        log_error "Grafana task file missing"
        return 1
    fi

    # Check if Grafana templates exist
    local required_templates=(
        "grafana.ini.j2"
        "prometheus-datasource.yml.j2"
        "system-dashboard.yml.j2"
        "grafana-service-override.conf.j2"
    )

    for template in "${required_templates[@]}"; do
        if [[ -f "ansible/roles/monitoring-stack/templates/$template" ]]; then
            log_success "Template exists: $template"
        else
            log_error "Template missing: $template"
            return 1
        fi
    done

    # Check if dashboard JSON exists
    if [[ -f "ansible/roles/monitoring-stack/files/system-overview-dashboard.json" ]]; then
        log_success "Dashboard JSON file exists"
    else
        log_error "Dashboard JSON file missing"
        return 1
    fi
}

# Test 2: Template syntax validation
test_template_syntax() {
    log_info "Testing template syntax..."

    # Check if python3 is available for JSON validation
    if ! command -v python3 >/dev/null 2>&1; then
        log_warning "python3 not available, skipping JSON validation"
        return 0
    fi

    # Validate dashboard JSON syntax
    if python3 -m json.tool "ansible/roles/monitoring-stack/files/system-overview-dashboard.json" >/dev/null 2>&1; then
        log_success "Dashboard JSON syntax is valid"
    else
        log_error "Dashboard JSON syntax is invalid"
        return 1
    fi

    # Check if YAML templates are valid (basic check)
    # Note: yamllint doesn't work well with Jinja2 templates, so we skip this
    log_info "YAML template validation skipped (Jinja2 templates not compatible with yamllint)"
}

# Test 3: Configuration consistency validation
test_configuration_consistency() {
    log_info "Testing configuration consistency..."

    # Check if Grafana variables are defined in defaults
    if grep -q "grafana_version:" "ansible/roles/monitoring-stack/defaults/main.yml"; then
        log_success "Grafana version variable defined"
    else
        log_error "Grafana version variable missing"
        return 1
    fi

    if grep -q "grafana_port:" "ansible/roles/monitoring-stack/defaults/main.yml"; then
        log_success "Grafana port variable defined"
    else
        log_error "Grafana port variable missing"
        return 1
    fi

    # Check if Grafana task is included in main.yml
    if grep -q "grafana.yml" "ansible/roles/monitoring-stack/tasks/main.yml"; then
        log_success "Grafana task included in main tasks"
    else
        log_error "Grafana task not included in main tasks"
        return 1
    fi
}

# Test 4: Playbook integration validation
test_playbook_integration() {
    log_info "Testing playbook integration..."

    # Check if playbook includes monitoring stack role
    if grep -q "monitoring-stack" "ansible/playbooks/playbook-hpc-controller.yml"; then
        log_success "Monitoring stack role included in playbook"
    else
        log_error "Monitoring stack role not included in playbook"
        return 1
    fi

    # Check if monitoring role is set to server
    if grep -q "monitoring_role.*server" "ansible/playbooks/playbook-hpc-controller.yml"; then
        log_success "Monitoring role set to server (includes Grafana)"
    else
        log_error "Monitoring role not set to server"
        return 1
    fi
}

# Test 5: File permissions validation
test_file_permissions() {
    log_info "Testing file permissions..."

    # Check template file permissions (should be readable)
    if [[ -r "ansible/roles/monitoring-stack/templates/grafana.ini.j2" ]]; then
        log_success "Grafana template is readable"
    else
        log_error "Grafana template is not readable"
        return 1
    fi

    # Check if template files are not executable (they shouldn't be)
    if [[ ! -x "ansible/roles/monitoring-stack/templates/grafana.ini.j2" ]]; then
        log_success "Grafana template is not executable (correct)"
    else
        log_error "Grafana template is executable (incorrect)"
        return 1
    fi
}

# Main validation execution
main() {
    log_info "=== Grafana Implementation Validation ==="
    log_info "Task 016: Set Up Grafana Dashboard Platform"

    run_test "Ansible Role Structure" test_ansible_role_structure
    run_test "Template Syntax" test_template_syntax
    run_test "Configuration Consistency" test_configuration_consistency
    run_test "Playbook Integration" test_playbook_integration
    run_test "File Permissions" test_file_permissions

    # Print summary
    echo ""
    log_info "=== Validation Summary ==="
    log_info "Tests Run: $TESTS_RUN"
    log_info "Tests Passed: $TESTS_PASSED"
    log_info "Tests Failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All validation tests passed!"
        log_info "Grafana implementation appears to be correctly configured."
        log_info "Next steps:"
        log_info "1. Install Ansible if needed for full testing"
        log_info "2. Build HPC controller image with Grafana integration"
        log_info "3. Deploy test cluster and run full integration tests"
        return 0
    else
        log_error "$TESTS_FAILED validation test(s) failed"
        return 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
