#!/bin/bash
#
# Test Suite Configuration Utilities
# Common configuration and environment setup for test suite scripts
# Provides standardized configuration loading and environment management
#

set -euo pipefail

# Source existing utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Derive PROJECT_ROOT with fallback for remote VMs
# When running locally: SCRIPT_DIR is tests/suites/common, go up 3 levels to project root
# When running on remote VM via SCP: PROJECT_ROOT may need to be passed via environment
PROJECT_ROOT="${PROJECT_ROOT:-}"
if [[ -z "$PROJECT_ROOT" ]]; then
    # Try to derive from SCRIPT_DIR (works when script is in original location)
    PROJECT_ROOT_DERIVED="$(cd "$SCRIPT_DIR/../../.." && pwd)"
    if [[ -d "$PROJECT_ROOT_DERIVED/tests/test-infra/utils" ]]; then
        PROJECT_ROOT="$PROJECT_ROOT_DERIVED"
    fi
fi

TEST_INFRA_UTILS_DIR="$PROJECT_ROOT/tests/test-infra/utils"
LOG_UTILS_FILE="$TEST_INFRA_UTILS_DIR/log-utils.sh"

# Diagnostic output when DEBUG mode enabled
if [[ "${DEBUG_SUITE_PATHS:-0}" == "1" ]]; then
    echo "[DEBUG] Running in: $(pwd)" >&2
    echo "[DEBUG] SCRIPT_DIR: $SCRIPT_DIR" >&2
    echo "[DEBUG] PROJECT_ROOT: $PROJECT_ROOT" >&2
    echo "[DEBUG] TEST_INFRA_UTILS_DIR: $TEST_INFRA_UTILS_DIR" >&2
fi

# Verify test-infra utilities are available - fail immediately if not found
if [[ ! -d "$TEST_INFRA_UTILS_DIR" ]]; then
    echo "FATAL: Test infrastructure utilities directory not found: $TEST_INFRA_UTILS_DIR" >&2
    echo "FATAL: Running from directory: $(pwd)" >&2
    echo "FATAL: SCRIPT_DIR: $SCRIPT_DIR" >&2
    echo "FATAL: PROJECT_ROOT: $PROJECT_ROOT" >&2
    echo "FATAL: Suite configuration requires shared utilities from tests/test-infra/utils/" >&2
    echo "FATAL: Set PROJECT_ROOT environment variable to correct location on remote systems" >&2
    exit 1
fi

if [[ ! -f "$LOG_UTILS_FILE" ]]; then
    echo "FATAL: Required log utilities not found: $LOG_UTILS_FILE" >&2
    echo "FATAL: Expected shared logging functions from tests/test-infra/utils/log-utils.sh" >&2
    exit 1
fi

# Source log utilities - required for suite operation
# shellcheck source=/dev/null
source "$LOG_UTILS_FILE"

# Default configuration values
DEFAULT_SSH_USER="admin"
DEFAULT_SSH_KEY_PATH="$PROJECT_ROOT/build/shared/ssh-keys/id_rsa"
DEFAULT_SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
DEFAULT_COMMAND_TIMEOUT=30
DEFAULT_TEST_TIMEOUT=300
DEFAULT_RETRY_COUNT=3
DEFAULT_RETRY_DELAY=2

# Environment setup

# Setup suite environment
setup_suite_environment() {
    local suite_name="$1"

    # Set script name if not already set
    : "${SCRIPT_NAME:=$suite_name}"

    # Set up log directory
    : "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
    mkdir -p "$LOG_DIR"

    # Set up project root
    : "${PROJECT_ROOT:=$PROJECT_ROOT}"

    # Set up test suite directory - derived from SCRIPT_DIR if not already set
    : "${TEST_SUITE_DIR:=$(dirname "$SCRIPT_DIR")}"
    export TEST_SUITE_DIR

    # Initialize logging if available
    if command -v log_info >/dev/null 2>&1; then
        log_info "Suite environment initialized: $suite_name"
        log_info "Log directory: $LOG_DIR"
        log_info "Project root: $PROJECT_ROOT"
        log_info "Test suite directory: $TEST_SUITE_DIR"
    fi
}

# Load suite-specific configuration
load_suite_config() {
    local suite_name="$1"
    local config_file="${2:-$SCRIPT_DIR/../$suite_name/suite-config.sh}"

    if [[ -f "$config_file" ]]; then
        # shellcheck disable=SC1090
        source "$config_file"
        if command -v log_info >/dev/null 2>&1; then
            log_info "Loaded suite configuration from: $config_file"
        fi
    else
        if command -v log_warn >/dev/null 2>&1; then
            log_warn "No suite configuration file found: $config_file"
        fi
    fi
}

# Validate suite prerequisites
validate_suite_prerequisites() {
    local suite_name="$1"
    local missing_deps=()

    # Check for required commands
    local required_commands=("bash" "ssh" "scp")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    # Check for SSH key
    if [[ ! -f "${SSH_KEY_PATH:-$DEFAULT_SSH_KEY_PATH}" ]]; then
        missing_deps+=("SSH key: ${SSH_KEY_PATH:-$DEFAULT_SSH_KEY_PATH}")
    fi

    # Check for log directory
    if [[ ! -d "$LOG_DIR" ]]; then
        missing_deps+=("Log directory: $LOG_DIR")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        if command -v log_error >/dev/null 2>&1; then
            log_error "Missing prerequisites for suite '$suite_name':"
            for dep in "${missing_deps[@]}"; do
                log_error "  - $dep"
            done
        fi
        return 1
    fi

    if command -v log_success >/dev/null 2>&1; then
        log_success "All prerequisites validated for suite '$suite_name'"
    fi
    return 0
}

# Configuration getters

# Get SSH configuration
get_ssh_config() {
    local ssh_key_path="${SSH_KEY_PATH:-$DEFAULT_SSH_KEY_PATH}"
    local ssh_user="${SSH_USER:-$DEFAULT_SSH_USER}"
    local ssh_opts="${SSH_OPTS:-$DEFAULT_SSH_OPTS}"

    echo "-i $ssh_key_path $ssh_opts"
}

# Get SSH user
get_ssh_user() {
    echo "${SSH_USER:-$DEFAULT_SSH_USER}"
}

# Get SSH key path
get_ssh_key_path() {
    echo "${SSH_KEY_PATH:-$DEFAULT_SSH_KEY_PATH}"
}

# Get SSH options
get_ssh_opts() {
    echo "${SSH_OPTS:-$DEFAULT_SSH_OPTS}"
}

# Get timeout configurations
get_test_timeouts() {
    local command_timeout="${COMMAND_TIMEOUT:-$DEFAULT_COMMAND_TIMEOUT}"
    local test_timeout="${TEST_TIMEOUT:-$DEFAULT_TEST_TIMEOUT}"

    echo "COMMAND_TIMEOUT=$command_timeout"
    echo "TEST_TIMEOUT=$test_timeout"
}

# Get retry configurations
get_retry_config() {
    local retry_count="${RETRY_COUNT:-$DEFAULT_RETRY_COUNT}"
    local retry_delay="${RETRY_DELAY:-$DEFAULT_RETRY_DELAY}"

    echo "RETRY_COUNT=$retry_count"
    echo "RETRY_DELAY=$retry_delay"
}

# Get test directory paths
get_test_directories() {
    local suite_dir="${SUITE_DIR:-$SCRIPT_DIR/..}"
    local logs_dir="${LOG_DIR:-$(pwd)/logs}"
    local project_root="${PROJECT_ROOT:-$PROJECT_ROOT}"

    echo "SUITE_DIR=$suite_dir"
    echo "LOG_DIR=$logs_dir"
    echo "PROJECT_ROOT=$project_root"
}

# Environment variable management

# Set environment variable with default
set_env_with_default() {
    local var_name="$1"
    local default_value="$2"
    local current_value="${!var_name:-}"

    if [[ -z "$current_value" ]]; then
        export "$var_name"="$default_value"
    fi
}

# Load environment from file
load_env_file() {
    local env_file="$1"

    if [[ -f "$env_file" ]]; then
        set -a  # automatically export all variables
        # shellcheck disable=SC1090
        source "$env_file"
        set +a  # disable automatic export

        if command -v log_info >/dev/null 2>&1; then
            log_info "Loaded environment from: $env_file"
        fi
    else
        if command -v log_warn >/dev/null 2>&1; then
            log_warn "Environment file not found: $env_file"
        fi
    fi
}

# Save environment to file
save_env_file() {
    local env_file="$1"
    local variables=("${@:2}")

    {
        echo "# Environment configuration"
        echo "# Generated on $(date)"
        echo

        for var in "${variables[@]}"; do
            if [[ -n "${!var:-}" ]]; then
                echo "export $var=\"${!var}\""
            fi
        done
    } > "$env_file"

    if command -v log_info >/dev/null 2>&1; then
        log_info "Environment saved to: $env_file"
    fi
}

# Configuration validation

# Validate SSH configuration
validate_ssh_config() {
    local ssh_key_path="${SSH_KEY_PATH:-$DEFAULT_SSH_KEY_PATH}"
    local ssh_user="${SSH_USER:-$DEFAULT_SSH_USER}"

    local errors=()

    # Check SSH key exists and is readable
    if [[ ! -f "$ssh_key_path" ]]; then
        errors+=("SSH key not found: $ssh_key_path")
    elif [[ ! -r "$ssh_key_path" ]]; then
        errors+=("SSH key not readable: $ssh_key_path")
    fi

    # Check SSH user is not empty
    if [[ -z "$ssh_user" ]]; then
        errors+=("SSH user is empty")
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        if command -v log_error >/dev/null 2>&1; then
            log_error "SSH configuration validation failed:"
            for error in "${errors[@]}"; do
                log_error "  - $error"
            done
        fi
        return 1
    fi

    if command -v log_success >/dev/null 2>&1; then
        log_success "SSH configuration validated successfully"
    fi
    return 0
}

# Validate timeout configuration
validate_timeout_config() {
    local command_timeout="${COMMAND_TIMEOUT:-$DEFAULT_COMMAND_TIMEOUT}"
    local test_timeout="${TEST_TIMEOUT:-$DEFAULT_TEST_TIMEOUT}"

    local errors=()

    # Check timeouts are positive integers
    if ! [[ "$command_timeout" =~ ^[0-9]+$ ]] || [[ $command_timeout -le 0 ]]; then
        errors+=("Invalid command timeout: $command_timeout (must be positive integer)")
    fi

    if ! [[ "$test_timeout" =~ ^[0-9]+$ ]] || [[ $test_timeout -le 0 ]]; then
        errors+=("Invalid test timeout: $test_timeout (must be positive integer)")
    fi

    # Check test timeout is greater than command timeout
    if [[ $test_timeout -lt $command_timeout ]]; then
        errors+=("Test timeout ($test_timeout) must be >= command timeout ($command_timeout)")
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        if command -v log_error >/dev/null 2>&1; then
            log_error "Timeout configuration validation failed:"
            for error in "${errors[@]}"; do
                log_error "  - $error"
            done
        fi
        return 1
    fi

    if command -v log_success >/dev/null 2>&1; then
        log_success "Timeout configuration validated successfully"
    fi
    return 0
}

# Configuration templates

# Create default suite configuration file
create_default_suite_config() {
    local suite_name="$1"
    local config_file="$2"

    {
        echo "#!/bin/bash"
        echo "# Default configuration for $suite_name test suite"
        echo "# Generated on $(date)"
        echo
        echo "# SSH Configuration"
        echo "SSH_USER=\"${DEFAULT_SSH_USER}\""
        echo "SSH_KEY_PATH=\"${DEFAULT_SSH_KEY_PATH}\""
        echo "SSH_OPTS=\"${DEFAULT_SSH_OPTS}\""
        echo
        echo "# Timeout Configuration"
        echo "COMMAND_TIMEOUT=${DEFAULT_COMMAND_TIMEOUT}"
        echo "TEST_TIMEOUT=${DEFAULT_TEST_TIMEOUT}"
        echo
        echo "# Retry Configuration"
        echo "RETRY_COUNT=${DEFAULT_RETRY_COUNT}"
        echo "RETRY_DELAY=${DEFAULT_RETRY_DELAY}"
        echo
        echo "# Suite-specific configuration"
        echo "# Add your suite-specific variables here"
    } > "$config_file"

    chmod +x "$config_file"

    if command -v log_info >/dev/null 2>&1; then
        log_info "Created default configuration file: $config_file"
    fi
}

# Configuration helpers

# Get configuration summary
get_config_summary() {
    local suite_name="${1:-Unknown Suite}"

    echo "Configuration Summary for $suite_name"
    echo "====================================="
    echo "SSH User: ${SSH_USER:-$DEFAULT_SSH_USER}"
    echo "SSH Key: ${SSH_KEY_PATH:-$DEFAULT_SSH_KEY_PATH}"
    echo "SSH Options: ${SSH_OPTS:-$DEFAULT_SSH_OPTS}"
    echo "Command Timeout: ${COMMAND_TIMEOUT:-$DEFAULT_COMMAND_TIMEOUT}s"
    echo "Test Timeout: ${TEST_TIMEOUT:-$DEFAULT_TEST_TIMEOUT}s"
    echo "Retry Count: ${RETRY_COUNT:-$DEFAULT_RETRY_COUNT}"
    echo "Retry Delay: ${RETRY_DELAY:-$DEFAULT_RETRY_DELAY}s"
    echo "Log Directory: ${LOG_DIR:-Not set}"
    echo "Project Root: ${PROJECT_ROOT:-Not set}"
}

# Export functions for use by other scripts
export -f setup_suite_environment
export -f load_suite_config
export -f validate_suite_prerequisites
export -f get_ssh_config
export -f get_ssh_user
export -f get_ssh_key_path
export -f get_ssh_opts
export -f get_test_timeouts
export -f get_retry_config
export -f get_test_directories
export -f set_env_with_default
export -f load_env_file
export -f save_env_file
export -f validate_ssh_config
export -f validate_timeout_config
export -f create_default_suite_config
export -f get_config_summary

# Export default configuration values
export DEFAULT_SSH_USER DEFAULT_SSH_KEY_PATH DEFAULT_SSH_OPTS
export DEFAULT_COMMAND_TIMEOUT DEFAULT_TEST_TIMEOUT DEFAULT_RETRY_COUNT DEFAULT_RETRY_DELAY
export SCRIPT_DIR PROJECT_ROOT TEST_SUITE_DIR

# Log that configuration utilities loaded successfully
log_info "Test suite configuration utilities loaded from: $LOG_UTILS_FILE"
