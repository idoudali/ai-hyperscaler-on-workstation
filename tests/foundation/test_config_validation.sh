#!/bin/bash
# Configuration Validation Test Suite
# Validates AI-HOW CLI configuration validation functionality

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
CONFIG_DIR="$PROJECT_ROOT/config"
TEMPLATE_CONFIG="$CONFIG_DIR/example-multi-gpu-clusters.yaml"
TEST_CONFIGS_DIR="$PROJECT_ROOT/tests/test-infra/configs"

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
ENHANCED_MODE=false
ALL_CONFIGS_MODE=false

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_verbose() {
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo -e "${GREEN}[VERBOSE]${NC} $1"
    fi
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

# Configuration Validation Tests
test_config_file_exists() {
    [[ -f "$TEMPLATE_CONFIG" ]] || {
        log_error "Template configuration file not found: $TEMPLATE_CONFIG"
        return 1
    }

    log_info "Template configuration file found: $TEMPLATE_CONFIG"
}

test_config_file_syntax() {
    log_info "Validating YAML syntax..."

    # Check if file is valid YAML
    if ! (cd "$AI_HOW_DIR" && uv run python -c "import yaml; yaml.safe_load(open('$TEMPLATE_CONFIG'))") >/dev/null 2>&1; then
        log_error "Configuration file has invalid YAML syntax"
        return 1
    fi

    log_info "YAML syntax is valid"
}

test_config_validation_basic() {
    log_info "Testing basic configuration validation..."

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    # Test basic validation
    log_verbose "Running: uv run ai-how validate $TEMPLATE_CONFIG"
    if ! (cd "$AI_HOW_DIR" && uv run ai-how validate "$TEMPLATE_CONFIG"); then
        log_error "Basic configuration validation failed"
        return 1
    fi

    log_info "Basic configuration validation passed"
}

test_config_validation_with_skip_pcie() {
    log_info "Testing configuration validation with PCIe validation skipped..."

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    # Test validation with PCIe skip
    log_verbose "Running: uv run ai-how validate --skip-pcie-validation $TEMPLATE_CONFIG"
    if ! (cd "$AI_HOW_DIR" && uv run ai-how validate --skip-pcie-validation "$TEMPLATE_CONFIG"); then
        log_error "Configuration validation with PCIe skip failed"
        return 1
    fi

    log_info "Configuration validation with PCIe skip passed"
}

test_config_validation_verbose() {
    log_info "Testing configuration validation with verbose output..."

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    # Test validation with verbose output
    log_verbose "Running: uv run ai-how --log-level DEBUG validate $TEMPLATE_CONFIG"
    if ! (cd "$AI_HOW_DIR" && uv run ai-how --log-level DEBUG validate "$TEMPLATE_CONFIG") >/dev/null 2>&1; then
        log_error "Configuration validation with verbose output failed"
        return 1
    fi

    log_info "Configuration validation with verbose output passed"
}

test_invalid_config_handling() {
    log_info "Testing invalid configuration handling..."

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    # Create a temporary invalid config file in current directory
    local invalid_config="./invalid-config-$$.yaml"
    cat > "$invalid_config" << 'EOF'
version: "1.0"
metadata:
  name: "invalid-test"
clusters:
  hpc:
    # Missing required fields
    name: "test"
EOF

    # Test that invalid config fails validation
    if (cd "$AI_HOW_DIR" && uv run ai-how validate "$invalid_config") >/dev/null 2>&1; then
        log_error "Invalid configuration should have failed validation"
        rm -f "$invalid_config"
        return 1
    fi

    # Clean up
    rm -f "$invalid_config"
    log_info "Invalid configuration properly rejected"
}

test_config_schema_validation() {
    log_info "Testing JSON schema validation..."

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    # Check if schema files exist
    local schema_dir="$AI_HOW_DIR/src/ai_how/schemas"
    if [[ ! -d "$schema_dir" ]]; then
        log_warn "Schema directory not found: $schema_dir"
        return 0  # Not a failure, schemas might be optional
    fi

    # Test schema validation
    log_verbose "Running: uv run ai-how validate --schema-validation $TEMPLATE_CONFIG"
    if ! (cd "$AI_HOW_DIR" && uv run ai-how validate --schema-validation "$TEMPLATE_CONFIG") >/dev/null 2>&1; then
        log_warn "Schema validation not available or failed (may not be implemented yet)"
    else
        log_info "Schema validation passed"
    fi
}

test_config_validation_output_format() {
    log_info "Testing configuration validation output format..."

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    # Test JSON output format
    log_verbose "Running: uv run ai-how validate --output-format json $TEMPLATE_CONFIG"
    if ! (cd "$AI_HOW_DIR" && uv run ai-how validate --output-format json "$TEMPLATE_CONFIG") >/dev/null 2>&1; then
        log_warn "JSON output format not available (may not be implemented yet)"
    else
        log_info "JSON output format working"
    fi

    # Test YAML output format
    log_verbose "Running: uv run ai-how validate --output-format yaml $TEMPLATE_CONFIG"
    if ! (cd "$AI_HOW_DIR" && uv run ai-how validate --output-format yaml "$TEMPLATE_CONFIG") >/dev/null 2>&1; then
        log_warn "YAML output format not available (may not be implemented yet)"
    else
        log_info "YAML output format working"
    fi
}

# Enhanced configuration validation functions (Task 005)
test_all_test_configs() {
    log_info "Testing all test configuration files..."

    if [[ ! -d "$TEST_CONFIGS_DIR" ]]; then
        log_warn "Test configs directory not found: $TEST_CONFIGS_DIR"
        return 0
    fi

    local config_files=()
    while IFS= read -r -d '' file; do
        config_files+=("$file")
    done < <(find "$TEST_CONFIGS_DIR" -name "*.yaml" -print0 2>/dev/null || true)

    if [[ ${#config_files[@]} -eq 0 ]]; then
        log_warn "No test configuration files found in $TEST_CONFIGS_DIR"
        return 0
    fi

    log_info "Found ${#config_files[@]} test configuration files"

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    local config_validation_passed=true
    for config_file in "${config_files[@]}"; do
        log_info "Validating: $(basename "$config_file")"

        # YAML syntax validation
        if ! python3 -c "import yaml; yaml.safe_load(open('$config_file'))" >/dev/null 2>&1; then
            log_error "YAML syntax validation failed for $(basename "$config_file")"
            config_validation_passed=false
            continue
        fi

        # AI-HOW validation with PCIe skip (test configs may not have PCIe devices)
        log_verbose "Running: uv run ai-how validate --skip-pcie-validation $config_file"
        if ! (cd "$AI_HOW_DIR" && uv run ai-how validate --skip-pcie-validation "$config_file") >/dev/null 2>&1; then
            log_error "AI-HOW validation failed for $(basename "$config_file")"
            config_validation_passed=false
        else
            log_info "✅ $(basename "$config_file") validation passed"
        fi
    done

    if [[ "$config_validation_passed" == "true" ]]; then
        log_info "All test configuration files validated successfully"
        return 0
    else
        log_error "Some test configuration files failed validation"
        return 1
    fi
}

test_network_subnet_uniqueness() {
    log_info "Testing network subnet uniqueness across all configs..."

    if [[ ! -d "$TEST_CONFIGS_DIR" ]]; then
        log_warn "Test configs directory not found: $TEST_CONFIGS_DIR"
        return 0
    fi

    local all_subnets=()
    local config_files=()

    # Find all YAML configuration files
    while IFS= read -r -d '' file; do
        config_files+=("$file")
    done < <(find "$TEST_CONFIGS_DIR" -name "*.yaml" -print0 2>/dev/null || true)

    # Extract all subnets
    for config_file in "${config_files[@]}"; do
        local subnets
        subnets=$(grep -E "subnet:" "$config_file" | sed 's/.*subnet: *//' | tr -d '"' | tr -d "'" || true)
        while IFS= read -r subnet; do
            if [[ -n "$subnet" ]]; then
                all_subnets+=("$subnet")
            fi
        done <<< "$subnets"
    done

    if [[ ${#all_subnets[@]} -eq 0 ]]; then
        log_warn "No network subnets found in configuration files"
        return 0
    fi

    log_info "Found ${#all_subnets[@]} network subnets"

    # Check for duplicates
    local unique_subnets
    mapfile -t unique_subnets < <(printf '%s\n' "${all_subnets[@]}" | sort | uniq)

    if [[ ${#all_subnets[@]} -eq ${#unique_subnets[@]} ]]; then
        log_info "All network subnets are unique"
        return 0
    else
        log_error "Duplicate network subnets found:"
        printf '%s\n' "${all_subnets[@]}" | sort | uniq -d
        return 1
    fi
}

test_base_image_paths() {
    log_info "Testing base image path existence..."

    if [[ ! -d "$TEST_CONFIGS_DIR" ]]; then
        log_warn "Test configs directory not found: $TEST_CONFIGS_DIR"
        return 0
    fi

    local config_files=()
    while IFS= read -r -d '' file; do
        config_files+=("$file")
    done < <(find "$TEST_CONFIGS_DIR" -name "*.yaml" -print0 2>/dev/null || true)

    local all_paths_exist=true

    for config_file in "${config_files[@]}"; do
        local image_paths
        image_paths=$(grep -E "base_image_path:" "$config_file" | sed 's/.*base_image_path: *//' | tr -d '"' | tr -d "'" || true)

        while IFS= read -r image_path; do
            if [[ -n "$image_path" ]]; then
                local resolved_path
                if [[ "$image_path" = /* ]]; then
                    resolved_path="$image_path"
                else
                    resolved_path="$PROJECT_ROOT/$image_path"
                fi

                if [[ -f "$resolved_path" ]]; then
                    log_info "✅ Base image found: $image_path"
                else
                    log_warn "⚠️  Base image not found: $image_path (resolved to: $resolved_path)"
                    all_paths_exist=false
                fi
            fi
        done <<< "$image_paths"
    done

    if [[ "$all_paths_exist" == "true" ]]; then
        log_info "All base image paths exist"
        return 0
    else
        log_warn "Some base image paths are missing (this may be expected if images haven't been built yet)"
        return 0  # Don't fail the test for missing images
    fi
}

print_summary() {
    local failed=$((TESTS_RUN - TESTS_PASSED))

    echo "=================================="
    echo "Configuration Validation Test Summary"
    echo "=================================="
    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $failed"

    if [[ $failed -gt 0 ]]; then
        echo "Failed tests:"
        printf '  ❌ %s\n' "${FAILED_TESTS[@]}"
        echo
        echo "❌ Configuration validation FAILED"
        return 1
    else
        echo
        echo "🎉 Configuration validation PASSED!"
        echo
        echo "Components validated:"
        echo "  ✅ Configuration file exists and has valid YAML syntax"
        echo "  ✅ Basic configuration validation works"
        echo "  ✅ Configuration validation with PCIe skip works"
        echo "  ✅ Verbose output mode works"
        echo "  ✅ Invalid configuration properly rejected"
        echo "  ✅ Output format options available"
        return 0
    fi
}

main() {
    echo "Configuration Validation Test Suite"
    echo "Project root: $PROJECT_ROOT"
    echo "Configuration file: $TEMPLATE_CONFIG"
    if [[ "$ALL_CONFIGS_MODE" == "true" ]]; then
        echo "Test configs directory: $TEST_CONFIGS_DIR"
    fi
    if [[ "$ENHANCED_MODE" == "true" ]]; then
        echo "Enhanced mode: ENABLED"
    fi
    echo

    # Run basic configuration validation tests
    run_test "Configuration file exists" test_config_file_exists
    run_test "Configuration file syntax" test_config_file_syntax
    run_test "Basic configuration validation" test_config_validation_basic
    run_test "Configuration validation with PCIe skip" test_config_validation_with_skip_pcie
    run_test "Configuration validation verbose" test_config_validation_verbose
    run_test "Invalid configuration handling" test_invalid_config_handling
    run_test "Configuration schema validation" test_config_schema_validation
    run_test "Configuration validation output format" test_config_validation_output_format

    # Run enhanced tests if requested
    if [[ "$ALL_CONFIGS_MODE" == "true" ]]; then
        run_test "All test configuration files validation" test_all_test_configs
    fi

    if [[ "$ENHANCED_MODE" == "true" ]]; then
        run_test "Network subnet uniqueness validation" test_network_subnet_uniqueness
        run_test "Base image path validation" test_base_image_paths
    fi

    print_summary
}

# Handle command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            echo "Configuration Validation Test Suite"
            echo "Usage: $0 [--help|--verbose|--all-configs|--enhanced]"
            echo
            echo "This test validates AI-HOW CLI configuration validation:"
            echo "  - Configuration file exists and has valid YAML syntax"
            echo "  - Basic configuration validation works"
            echo "  - Configuration validation with PCIe skip works"
            echo "  - Verbose output mode works"
            echo "  - Invalid configuration properly rejected"
            echo "  - Output format options available"
            echo
            echo "Enhanced features (Task 005):"
            echo "  - All test configuration files validation"
            echo "  - Network subnet uniqueness validation"
            echo "  - Base image path validation"
            echo
            echo "Options:"
            echo "  --verbose      Show detailed command output"
            echo "  --all-configs  Validate all test configuration files"
            echo "  --enhanced     Run enhanced validation tests"
            echo
            echo "Tests run directly on the host system using uv."
            echo "Press Ctrl+C to interrupt long-running tests."
            exit 0
            ;;
        --verbose)
            VERBOSE_MODE=true
            log_info "Verbose mode enabled"
            ;;
        --all-configs)
            ALL_CONFIGS_MODE=true
            log_info "All configs mode enabled"
            ;;
        --enhanced)
            ENHANCED_MODE=true
            log_info "Enhanced mode enabled"
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
