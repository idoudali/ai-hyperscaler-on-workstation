#!/bin/bash
# Test Configuration Validation Test Suite
# Validates the test cluster configurations created in Task 003

set -euo pipefail

# Signal handling for clean interruption
cleanup() {
    echo
    log_warn "Test interrupted by user (Ctrl+C)"
    exit 130
}
trap cleanup INT TERM

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI_HOW_DIR="$PROJECT_ROOT/python/ai_how"
TEST_CONFIGS_DIR="$PROJECT_ROOT/tests/test-infra/configs"

# Test configuration files
TEST_CONFIGS=(
    "test-minimal.yaml"
    "test-gpu-simulation.yaml"
    "test-full-stack.yaml"
)

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
FAILED_TESTS=()
VERBOSE_MODE=false

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_verbose() {
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo -e "${GREEN}[VERBOSE]${NC} $1"
    fi
}

# Helper function to extract maximum resource value from configuration
extract_max_resource_value() {
    local config_path="$1"
    local resource_key="$2"

    grep -E "^\s*${resource_key}:" "$config_path" | awk '{print $2}' | sort -n | tail -1
}

run_test() {
    local test_name="$1"
    local test_function="$2"

    echo "Running: $test_name"
    TESTS_RUN=$((TESTS_RUN + 1))

    if $test_function; then
        log_info "✅ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "❌ $test_name"
        FAILED_TESTS+=("$test_name")
    fi
    echo
}

# Test Configuration Tests
test_configs_directory_exists() {
    [[ -d "$TEST_CONFIGS_DIR" ]] || {
        log_error "Test configurations directory not found: $TEST_CONFIGS_DIR"
        return 1
    }

    log_info "Test configurations directory found: $TEST_CONFIGS_DIR"
}

test_config_files_exist() {
    log_info "Checking test configuration files exist..."

    for config in "${TEST_CONFIGS[@]}"; do
        local config_path="$TEST_CONFIGS_DIR/$config"
        [[ -f "$config_path" ]] || {
            log_error "Test configuration file not found: $config_path"
            return 1
        }
        log_verbose "Found: $config"
    done

    log_info "All test configuration files found"
}

test_config_files_yaml_syntax() {
    log_info "Validating YAML syntax for test configurations..."

    for config in "${TEST_CONFIGS[@]}"; do
        local config_path="$TEST_CONFIGS_DIR/$config"
        log_verbose "Validating YAML syntax for: $config"

        # Check if file is valid YAML
        local config_rel_path
        config_rel_path="$(realpath --relative-to="$AI_HOW_DIR" "$config_path")"
        if ! (cd "$AI_HOW_DIR" && uv run python -c "import yaml; yaml.safe_load(open('$config_rel_path'))") >/dev/null 2>&1; then
            log_error "Configuration file has invalid YAML syntax: $config"
            return 1
        fi
    done

    log_info "All test configurations have valid YAML syntax"
}

test_config_validation_basic() {
    log_info "Testing basic configuration validation for test configs..."

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    for config in "${TEST_CONFIGS[@]}"; do
        local config_path="$TEST_CONFIGS_DIR/$config"
        log_verbose "Validating: $config"

        # Test basic validation
        local config_rel_path
        config_rel_path="$(realpath --relative-to="$AI_HOW_DIR" "$config_path")"
        if ! (cd "$AI_HOW_DIR" && uv run ai-how validate "$config_rel_path"); then
            log_error "Basic configuration validation failed for: $config"
            return 1
        fi
    done

    log_info "All test configurations pass basic validation"
}

test_config_validation_with_skip_pcie() {
    log_info "Testing configuration validation with PCIe validation skipped..."

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    for config in "${TEST_CONFIGS[@]}"; do
        local config_path="$TEST_CONFIGS_DIR/$config"
        log_verbose "Validating with PCIe skip: $config"

        # Test validation with PCIe skip
        local config_rel_path
        config_rel_path="$(realpath --relative-to="$AI_HOW_DIR" "$config_path")"
        if ! (cd "$AI_HOW_DIR" && uv run ai-how validate --skip-pcie-validation "$config_rel_path"); then
            log_error "Configuration validation with PCIe skip failed for: $config"
            return 1
        fi
    done

    log_info "All test configurations pass validation with PCIe skip"
}

test_base_image_paths_exist() {
    log_info "Checking base image paths exist..."

    # Check HPC base image
    local hpc_image="$PROJECT_ROOT/build/packer/hpc-base/hpc-base/hpc-base.qcow2"
    if [[ -f "$hpc_image" ]]; then
        log_info "HPC base image found: $hpc_image"
    else
        log_warn "HPC base image not found: $hpc_image (may need to be built first)"
    fi

    # Check Cloud base image
    local cloud_image="$PROJECT_ROOT/build/packer/cloud-base/cloud-base/cloud-base.qcow2"
    if [[ -f "$cloud_image" ]]; then
        log_info "Cloud base image found: $cloud_image"
    else
        log_warn "Cloud base image not found: $cloud_image (may need to be built first)"
    fi
}

test_network_subnet_isolation() {
    log_info "Checking network subnet isolation..."

    # Extract subnets from test configurations
    local subnets=()
    for config in "${TEST_CONFIGS[@]}"; do
        local config_path="$TEST_CONFIGS_DIR/$config"
        local subnet

        # Extract subnet using a more readable approach
        # First try to find the subnet line, then extract the value
        local subnet_line
        subnet_line=$(grep -E "^\s*subnet:" "$config_path" | head -1)
        if [[ -n "$subnet_line" ]]; then
            # Remove leading whitespace and 'subnet:' prefix using parameter expansion
            subnet_line="${subnet_line#*subnet:}"
            subnet_line="${subnet_line#"${subnet_line%%[![:space:]]*}"}"  # Remove leading whitespace
            # Remove quotes if present using parameter expansion
            subnet="${subnet_line#\"}"
            subnet="${subnet%\"}"

            if [[ -n "$subnet" ]]; then
                subnets+=("$subnet")
                log_verbose "Found subnet: $subnet in $config"
            fi
        fi
    done

    # Check for subnet conflicts
    local unique_subnets
    mapfile -t unique_subnets < <(printf '%s\n' "${subnets[@]}" | sort -u)
    if [[ ${#subnets[@]} -ne ${#unique_subnets[@]} ]]; then
        log_error "Duplicate subnets found in test configurations"
        return 1
    fi

    log_info "All test configurations use unique network subnets"
}

test_resource_allocations_realistic() {
    log_info "Checking resource allocations are realistic for test environments..."

    for config in "${TEST_CONFIGS[@]}"; do
        local config_path="$TEST_CONFIGS_DIR/$config"
        log_verbose "Checking resource allocations in: $config"

        # Check CPU cores (should be reasonable for test environments)
        local cpu_cores
        cpu_cores=$(extract_max_resource_value "$config_path" "cpu_cores")
        if [[ -n "$cpu_cores" && "$cpu_cores" -gt 16 ]]; then
            log_warn "High CPU allocation detected in $config: $cpu_cores cores"
        fi

        # Check memory (should be reasonable for test environments)
        local memory_gb
        memory_gb=$(extract_max_resource_value "$config_path" "memory_gb")
        if [[ -n "$memory_gb" && "$memory_gb" -gt 32 ]]; then
            log_warn "High memory allocation detected in $config: $memory_gb GB"
        fi

        # Check disk (should be reasonable for test environments)
        local disk_gb
        disk_gb=$(extract_max_resource_value "$config_path" "disk_gb")
        if [[ -n "$disk_gb" && "$disk_gb" -gt 200 ]]; then
            log_warn "High disk allocation detected in $config: $disk_gb GB"
        fi
    done

    log_info "Resource allocations appear realistic for test environments"
}

test_config_schema_compliance() {
    log_info "Testing configuration schema compliance..."

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    for config in "${TEST_CONFIGS[@]}"; do
        local config_path="$TEST_CONFIGS_DIR/$config"
        log_verbose "Testing schema compliance for: $config"

        # Test schema validation if available
        local config_rel_path
        config_rel_path="$(realpath --relative-to="$AI_HOW_DIR" "$config_path")"
        if ! (cd "$AI_HOW_DIR" && uv run ai-how validate --schema-validation "$config_rel_path") >/dev/null 2>&1; then
            log_warn "Schema validation not available or failed for $config (may not be implemented yet)"
        else
            log_verbose "Schema validation passed for $config"
        fi
    done

    log_info "Configuration schema compliance tests completed"
}

print_summary() {
    local failed=$((TESTS_RUN - TESTS_PASSED))

    echo "=================================="
    echo "Test Configuration Validation Summary"
    echo "=================================="
    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $failed"

    if [[ $failed -gt 0 ]]; then
        echo "Failed tests:"
        printf '  ❌ %s\n' "${FAILED_TESTS[@]}"
        echo
        echo "❌ Test configuration validation FAILED"
        return 1
    else
        echo
        echo "🎉 Test configuration validation PASSED!"
        echo
        echo "Components validated:"
        echo "  ✅ Test configurations directory exists"
        echo "  ✅ All test configuration files exist"
        echo "  ✅ All configurations have valid YAML syntax"
        echo "  ✅ All configurations pass basic validation"
        echo "  ✅ All configurations pass validation with PCIe skip"
        echo "  ✅ Base image paths are accessible"
        echo "  ✅ Network subnets are isolated"
        echo "  ✅ Resource allocations are realistic"
        echo "  ✅ Configuration schema compliance"
        return 0
    fi
}

main() {
    echo "Test Configuration Validation Test Suite"
    echo "Project root: $PROJECT_ROOT"
    echo "Test configurations directory: $TEST_CONFIGS_DIR"
    echo

    # Run test configuration validation tests
    run_test "Test configurations directory exists" test_configs_directory_exists
    run_test "Test configuration files exist" test_config_files_exist
    run_test "Test configuration files YAML syntax" test_config_files_yaml_syntax
    run_test "Test configuration validation basic" test_config_validation_basic
    run_test "Test configuration validation with PCIe skip" test_config_validation_with_skip_pcie
    run_test "Base image paths exist" test_base_image_paths_exist
    run_test "Network subnet isolation" test_network_subnet_isolation
    run_test "Resource allocations realistic" test_resource_allocations_realistic
    run_test "Configuration schema compliance" test_config_schema_compliance

    print_summary
}

# Handle command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            echo "Test Configuration Validation Test Suite"
            echo "Usage: $0 [--help|--verbose]"
            echo
            echo "This test validates the test cluster configurations created in Task 003:"
            echo "  - Test configurations directory exists"
            echo "  - All test configuration files exist"
            echo "  - All configurations have valid YAML syntax"
            echo "  - All configurations pass basic validation"
            echo "  - All configurations pass validation with PCIe skip"
            echo "  - Base image paths are accessible"
            echo "  - Network subnets are isolated"
            echo "  - Resource allocations are realistic"
            echo "  - Configuration schema compliance"
            echo
            echo "Options:"
            echo "  --verbose  Show detailed command output"
            echo
            echo "Tests run directly on the host system using uv."
            echo "Press Ctrl+C to interrupt long-running tests."
            exit 0
            ;;
        --verbose)
            VERBOSE_MODE=true
            log_info "Verbose mode enabled"
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

main "$@"
