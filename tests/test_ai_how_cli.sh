#!/bin/bash
# AI-HOW CLI Installation and Configuration Test Suite
# Validates AI-HOW CLI installation, configuration validation, and PCIe functionality

set -euo pipefail

# File: tests/test_ai_how_cli.sh, Line: 6
PS4='+ [test_ai_how_cli.sh:L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

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
CONFIG_FILE="$PROJECT_ROOT/config/template-cluster.yaml"

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
SKIP_INSTALL=false

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

# Task 002 Validation Criteria Tests
test_uv_available() {
    command -v uv >/dev/null 2>&1 || {
        log_error "uv command not found. Please install uv first."
        return 1
    }
}

test_ai_how_directory_exists() {
    [[ -d "$AI_HOW_DIR" ]] || {
        log_error "AI-HOW directory not found: $AI_HOW_DIR"
        return 1
    }

    [[ -f "$AI_HOW_DIR/pyproject.toml" ]] || {
        log_error "AI-HOW pyproject.toml not found"
        return 1
    }
}

test_ai_how_installation() {
    log_info "Installing AI-HOW CLI in development mode..."

    if [[ "$SKIP_INSTALL" == "true" ]]; then
        log_info "Skipping installation (--skip-install specified)"
        return 0
    fi

    # Change to AI-HOW directory and install
    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    # Install using uv
    log_verbose "Running: uv sync --dev"
    if ! (cd "$AI_HOW_DIR" && uv sync --dev); then
        log_error "AI-HOW installation failed"
        return 1
    fi

    # Verify installation by checking if ai-how command is available
    if ! (cd "$AI_HOW_DIR" && uv run ai-how --help) >/dev/null 2>&1; then
        log_error "AI-HOW CLI not accessible after installation"
        return 1
    fi

    log_info "AI-HOW CLI installed successfully"
}

test_ai_how_help_commands() {
    log_info "Testing AI-HOW CLI help commands..."

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    # Test main help command
    if ! (cd "$AI_HOW_DIR" && uv run ai-how --help) >/dev/null 2>&1; then
        log_error "Main help command failed"
        return 1
    fi

    # Test validate subcommand help
    if ! (cd "$AI_HOW_DIR" && uv run ai-how validate --help) >/dev/null 2>&1; then
        log_error "Validate subcommand help failed"
        return 1
    fi

    # Test hpc subcommand help (if available)
    if ! (cd "$AI_HOW_DIR" && uv run ai-how hpc --help) >/dev/null 2>&1; then
        log_warn "HPC subcommand help not available (may not be implemented yet)"
    fi

    log_info "All help commands working correctly"
}

test_configuration_validation() {
    log_info "Testing configuration validation..."

    [[ -f "$CONFIG_FILE" ]] || {
        log_error "Configuration file not found: $CONFIG_FILE"
        return 1
    }

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    # Test configuration validation
    log_verbose "Running: uv run ai-how validate $CONFIG_FILE"
    if ! (cd "$AI_HOW_DIR" && uv run ai-how validate "$CONFIG_FILE"); then
        log_error "Configuration validation failed"
        return 1
    fi

    log_info "Configuration validation passed"
}

test_pcie_validation() {
    log_info "Testing PCIe validation functionality..."

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    # Test PCIe inventory command (should work even if no GPUs present)
    if ! (cd "$AI_HOW_DIR" && uv run ai-how inventory pcie) >/dev/null 2>&1; then
        log_error "PCIe inventory command failed"
        return 1
    fi

    # Test configuration validation with PCIe validation skipped
    log_verbose "Running: uv run ai-how validate --skip-pcie-validation $CONFIG_FILE"
    if ! (cd "$AI_HOW_DIR" && uv run ai-how validate --skip-pcie-validation "$CONFIG_FILE"); then
        log_error "Configuration validation with PCIe skip failed"
        return 1
    fi

    log_info "PCIe validation functionality working"
}

test_logging_configuration() {
    log_info "Testing logging configuration..."

    cd "$AI_HOW_DIR" || {
        log_error "Failed to change to AI-HOW directory"
        return 1
    }

    # Test with different log levels
    for log_level in "DEBUG" "INFO" "WARNING" "ERROR"; do
        log_verbose "Testing log level: $log_level"
        if ! (cd "$AI_HOW_DIR" && uv run ai-how --log-level "$log_level" --help) >/dev/null 2>&1; then
            log_error "Log level $log_level not supported"
            return 1
        fi
    done

    log_info "Logging configuration functional"
}


print_summary() {
    local failed=$((TESTS_RUN - TESTS_PASSED))

    echo "=================================="
    echo "AI-HOW CLI Test Summary"
    echo "=================================="
    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $failed"

    if [[ $failed -gt 0 ]]; then
        echo "Failed tests:"
        printf '  ❌ %s\n' "${FAILED_TESTS[@]}"
        echo
        echo "❌ AI-HOW CLI validation FAILED"
        return 1
    else
        echo
        echo "🎉 AI-HOW CLI validation PASSED!"
        echo
        echo "Components validated:"
        echo "  ✅ AI-HOW CLI installation"
        echo "  ✅ Help commands display correctly"
        echo "  ✅ Configuration validation works"
        echo "  ✅ PCIe validation functionality"
        echo "  ✅ Logging configuration functional"
        return 0
    fi
}

main() {
    echo "AI-HOW CLI Installation and Configuration Test Suite"
    echo "Project root: $PROJECT_ROOT"
    echo "AI-HOW directory: $AI_HOW_DIR"
    echo

    # Run AI-HOW CLI validation tests
    run_test "uv available" test_uv_available
    run_test "AI-HOW directory exists" test_ai_how_directory_exists
    run_test "Install AI-HOW CLI" test_ai_how_installation
    run_test "CLI help commands" test_ai_how_help_commands
    run_test "Configuration validation" test_configuration_validation
    run_test "PCIe validation functionality" test_pcie_validation
    run_test "Logging configuration" test_logging_configuration

    print_summary
}

# Handle command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            echo "AI-HOW CLI Installation and Configuration Test Suite"
            echo "Usage: $0 [--help|--skip-install|--verbose]"
            echo
            echo "This test validates AI-HOW CLI installation and functionality:"
            echo "  - AI-HOW CLI installation in development mode"
            echo "  - Help commands display correctly"
            echo "  - Configuration validation works on template-cluster.yaml"
            echo "  - PCIe validation functionality"
            echo "  - Logging configuration functional"
            echo
            echo "Options:"
            echo "  --skip-install  Skip installation and test existing installation"
            echo "  --verbose       Show detailed command output"
            echo
            echo "Tests run directly on the host system using uv."
            echo "Press Ctrl+C to interrupt long-running tests."
            exit 0
            ;;
        --verbose)
            VERBOSE_MODE=true
            log_info "Verbose mode enabled"
            ;;
        --skip-install)
            SKIP_INSTALL=true
            log_info "Skip install mode enabled - will test existing installation"
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
