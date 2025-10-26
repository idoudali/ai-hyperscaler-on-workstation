#!/bin/bash
#
# Framework CLI Utility - Common Command-Line Interface for Test Frameworks
#
# This utility provides standardized CLI parsing and command handling for all test frameworks.
# It eliminates duplication across the 15+ test frameworks by providing:
#  - Consistent command parsing (parse_framework_cli)
#  - Standard help output generation (show_framework_help)
#  - Option parsing (parse_framework_options)
#  - Command validation
#
# Usage:
#   source framework-cli.sh
#   parse_framework_cli "$@"
#
# Exported Variables:
#   FRAMEWORK_COMMAND - The main command to execute (e2e, start-cluster, etc)
#   FRAMEWORK_TEST_TO_RUN - Specific test name if run-test command
#   FRAMEWORK_OPTIONS - Hash of options (-v, --no-cleanup, etc)
#
# Functions:
#   show_framework_help() - Display help message
#   parse_framework_cli() - Parse command line arguments
#   parse_framework_options() - Parse specific options
#   validate_framework_command() - Validate command is supported
#   get_framework_command() - Get parsed command
#   is_framework_option_set() - Check if option was provided
#

set -euo pipefail

# Color codes for output
# shellcheck disable=SC2034
readonly RED='\033[0;31m'
# shellcheck disable=SC2034
readonly GREEN='\033[0;32m'
# shellcheck disable=SC2034
readonly YELLOW='\033[1;33m'
# shellcheck disable=SC2034
readonly BLUE='\033[0;34m'
# shellcheck disable=SC2034
readonly NC='\033[0m' # No Color

# Standard framework commands across all test frameworks
declare -a FRAMEWORK_STANDARD_COMMANDS=(
    "e2e"
    "end-to-end"
    "start-cluster"
    "stop-cluster"
    "deploy-ansible"
    "run-tests"
    "list-tests"
    "run-test"
    "status"
    "help"
)

# Standard framework options
declare -a FRAMEWORK_STANDARD_OPTIONS=(
    "-h"
    "--help"
    "-v"
    "--verbose"
    "-q"
    "--quiet"
    "--no-cleanup"
    "--interactive"
    "--log-level"
    "--phase"
    "--controller"
    "--test-image"
)

# Global variables set by CLI parser
export FRAMEWORK_COMMAND="${FRAMEWORK_COMMAND:-e2e}"
export FRAMEWORK_TEST_TO_RUN="${FRAMEWORK_TEST_TO_RUN:-}"
export FRAMEWORK_VERBOSE="${FRAMEWORK_VERBOSE:-false}"
export FRAMEWORK_QUIET="${FRAMEWORK_QUIET:-false}"
export FRAMEWORK_NO_CLEANUP="${FRAMEWORK_NO_CLEANUP:-false}"
export FRAMEWORK_INTERACTIVE="${FRAMEWORK_INTERACTIVE:-false}"
export FRAMEWORK_LOG_LEVEL="${FRAMEWORK_LOG_LEVEL:-normal}"
export FRAMEWORK_PHASE="${FRAMEWORK_PHASE:-}"
export FRAMEWORK_CONTROLLER="${FRAMEWORK_CONTROLLER:-}"
export FRAMEWORK_TEST_IMAGE="${FRAMEWORK_TEST_IMAGE:-}"

# Helper: Check if value is a standard framework command
_is_standard_command() {
    local cmd="$1"
    for standard_cmd in "${FRAMEWORK_STANDARD_COMMANDS[@]}"; do
        [[ "$cmd" == "$standard_cmd" ]] && return 0
    done
    return 1
}

# Helper: Check if value is a standard framework option
_is_standard_option() {
    local opt="$1"
    for standard_opt in "${FRAMEWORK_STANDARD_OPTIONS[@]}"; do
        [[ "$opt" == "$standard_opt" ]] && return 0
    done
    return 1
}

#
# show_framework_help()
# Generates standardized help output for frameworks
#
# Usage:
#   FRAMEWORK_NAME="My Test Framework" \
#   FRAMEWORK_DESCRIPTION="Test my component" \
#   FRAMEWORK_TASK="TASK-001" \
#   FRAMEWORK_TEST_CONFIG="/path/to/config.yaml" \
#   FRAMEWORK_TEST_SCRIPTS_DIR="/path/to/tests" \
#   show_framework_help
#
show_framework_help() {
    local framework_name="${FRAMEWORK_NAME:-Test Framework}"
    local framework_description="${FRAMEWORK_DESCRIPTION:-Framework for testing}"
    local task="${FRAMEWORK_TASK:-}"
    local test_config="${FRAMEWORK_TEST_CONFIG:-config.yaml}"
    local test_scripts_dir="${FRAMEWORK_TEST_SCRIPTS_DIR:-tests/suites/default}"
    local extra_commands="${FRAMEWORK_EXTRA_COMMANDS:-}"
    local extra_options="${FRAMEWORK_EXTRA_OPTIONS:-}"
    local extra_examples="${FRAMEWORK_EXTRA_EXAMPLES:-}"

    cat << EOF
${BLUE}${framework_name}${NC}
${framework_description}
${task:+Task: $task}

USAGE:
    \$0 [OPTIONS] [COMMAND]

STANDARD COMMANDS:
    e2e, end-to-end   Run complete end-to-end test with cleanup (default)
    start-cluster     Start the cluster independently
    stop-cluster      Stop and destroy the cluster
    deploy-ansible    Deploy configuration via Ansible (assumes cluster running)
    run-tests         Run test suite on deployed cluster
    list-tests        List all available individual tests
    run-test NAME     Run a specific individual test by name
    status            Show cluster status
    help              Show this help message
${extra_commands:+
ADDITIONAL COMMANDS:
${extra_commands}
}
STANDARD OPTIONS:
    -h, --help        Show this help message
    -v, --verbose     Enable verbose output
    -q, --quiet       Minimal output (equivalent to --log-level quiet)
    --log-level LVL   Set logging level: quiet, normal, verbose, debug (default: normal)
    --no-cleanup      Skip cleanup after test completion
    --interactive     Enable interactive cleanup prompts
${extra_options:+
ADDITIONAL OPTIONS:
${extra_options}
}
LOGGING LEVELS:
    quiet             Only show errors and critical messages
    normal            Standard output (default)
    verbose           Detailed output including all operations
    debug             Maximum verbosity for troubleshooting

EXAMPLES:
    # Run complete end-to-end test with cleanup (recommended for CI/CD)
    \$0
    \$0 e2e
    \$0 end-to-end

    # Modular workflow for debugging (keeps cluster running)
    \$0 start-cluster          # Start cluster
    \$0 deploy-ansible         # Deploy configuration
    \$0 run-tests              # Run tests (can repeat)
    \$0 list-tests             # Show available tests
    \$0 run-test NAME          # Run specific test
    \$0 status                 # Check status
    \$0 stop-cluster           # Clean up
${extra_examples:+
ADDITIONAL EXAMPLES:
${extra_examples}
}
CONFIGURATION:
    Test Config: ${test_config}
    Test Scripts: ${test_scripts_dir}

EOF
}

#
# parse_framework_options()
# Parse and validate framework options
#
# Usage:
#   parse_framework_options "$@"
#
# Sets:
#   FRAMEWORK_VERBOSE, FRAMEWORK_QUIET, FRAMEWORK_NO_CLEANUP,
#   FRAMEWORK_INTERACTIVE, FRAMEWORK_LOG_LEVEL, etc
#
parse_framework_options() {
    local remaining_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_framework_help
                exit 0
                ;;
            -v|--verbose)
                export FRAMEWORK_VERBOSE=true
                export FRAMEWORK_LOG_LEVEL="verbose"
                shift
                ;;
            -q|--quiet)
                export FRAMEWORK_QUIET=true
                export FRAMEWORK_LOG_LEVEL="quiet"
                shift
                ;;
            --log-level)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --log-level requires an argument (quiet|normal|verbose|debug)"
                    exit 1
                fi
                export FRAMEWORK_LOG_LEVEL="$2"
                case "$FRAMEWORK_LOG_LEVEL" in
                    quiet|normal|verbose|debug) ;;
                    *)
                        echo "Error: Invalid log level: $FRAMEWORK_LOG_LEVEL"
                        echo "Valid values: quiet, normal, verbose, debug"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            --no-cleanup)
                export FRAMEWORK_NO_CLEANUP=true
                shift
                ;;
            --interactive)
                export FRAMEWORK_INTERACTIVE=true
                shift
                ;;
            --phase)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --phase requires an argument"
                    exit 1
                fi
                export FRAMEWORK_PHASE="$2"
                shift 2
                ;;
            --controller)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --controller requires an argument"
                    exit 1
                fi
                export FRAMEWORK_CONTROLLER="$2"
                shift 2
                ;;
            --test-image)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --test-image requires an argument"
                    exit 1
                fi
                export FRAMEWORK_TEST_IMAGE="$2"
                shift 2
                ;;
            *)
                # Not an option, keep for command parsing
                remaining_args+=("$1")
                shift
                ;;
        esac
    done

    # Return remaining arguments as positional parameters
    set -- "${remaining_args[@]}"
}

#
# parse_framework_cli()
# Main CLI parser for frameworks
#
# Usage:
#   parse_framework_cli "$@"
#
# Sets:
#   FRAMEWORK_COMMAND - Main command (e2e, start-cluster, etc)
#   FRAMEWORK_TEST_TO_RUN - Test name if using run-test command
#   All FRAMEWORK_* option variables
#
parse_framework_cli() {
    local remaining_args=()

    # Process all arguments
    while [[ $# -gt 0 ]]; do
        local arg="$1"

        case "$arg" in
            -h|--help)
                show_framework_help
                exit 0
                ;;
            -v|--verbose)
                export FRAMEWORK_VERBOSE=true
                export FRAMEWORK_LOG_LEVEL="verbose"
                shift
                ;;
            -q|--quiet)
                export FRAMEWORK_QUIET=true
                export FRAMEWORK_LOG_LEVEL="quiet"
                shift
                ;;
            --log-level)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --log-level requires an argument (quiet|normal|verbose|debug)"
                    exit 1
                fi
                export FRAMEWORK_LOG_LEVEL="$2"
                case "$FRAMEWORK_LOG_LEVEL" in
                    quiet|normal|verbose|debug) ;;
                    *)
                        echo "Error: Invalid log level: $FRAMEWORK_LOG_LEVEL"
                        echo "Valid values: quiet, normal, verbose, debug"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            --no-cleanup)
                export FRAMEWORK_NO_CLEANUP=true
                shift
                ;;
            --interactive)
                export FRAMEWORK_INTERACTIVE=true
                shift
                ;;
            --phase)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --phase requires an argument"
                    exit 1
                fi
                export FRAMEWORK_PHASE="$2"
                shift 2
                ;;
            --controller)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --controller requires an argument"
                    exit 1
                fi
                export FRAMEWORK_CONTROLLER="$2"
                shift 2
                ;;
            --test-image)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --test-image requires an argument"
                    exit 1
                fi
                export FRAMEWORK_TEST_IMAGE="$2"
                shift 2
                ;;
            *)
                # Not an option, collect for command parsing
                remaining_args+=("$arg")
                shift
                ;;
        esac
    done

    # Parse remaining positional arguments for command
    if [[ ${#remaining_args[@]} -gt 0 ]]; then
        local first_arg="${remaining_args[0]}"

        if _is_standard_command "$first_arg"; then
            export FRAMEWORK_COMMAND="$first_arg"

            # Special handling for run-test command
            if [[ "$first_arg" == "run-test" && ${#remaining_args[@]} -gt 1 ]]; then
                export FRAMEWORK_TEST_TO_RUN="${remaining_args[1]}"
            fi
        else
            echo "Error: Unknown command: $first_arg"
            echo "Use: \$0 --help for usage information"
            exit 1
        fi
    else
        # No command specified, default to e2e
        export FRAMEWORK_COMMAND="e2e"
    fi
}

#
# validate_framework_command()
# Validate that a command is supported by the framework
#
# Usage:
#   if validate_framework_command "$cmd"; then
#       # Command is valid
#   fi
#
validate_framework_command() {
    local cmd="$1"
    _is_standard_command "$cmd"
}

#
# get_framework_command()
# Get the currently parsed framework command
#
# Usage:
#   cmd=$(get_framework_command)
#
get_framework_command() {
    echo "$FRAMEWORK_COMMAND"
}

#
# is_framework_option_set()
# Check if a specific option was set during parsing
#
# Usage:
#   if is_framework_option_set "verbose"; then
#       # Verbose mode is on
#   fi
#
is_framework_option_set() {
    local opt="$1"
    local var_name
    var_name="FRAMEWORK_$(echo "$opt" | tr '[:lower:]' '[:upper:]')"

    local value
    value="${!var_name:-false}"
    [[ "$value" == "true" ]]
}

#
# get_framework_option()
# Get the value of a framework option
#
# Usage:
#   level=$(get_framework_option "log_level")
#
get_framework_option() {
    local opt="$1"
    local var_name
    var_name="FRAMEWORK_$(echo "$opt" | tr '[:lower:]' '[:upper:]')"

    echo "${!var_name:-}"
}

# Export functions for use in other scripts
export -f show_framework_help
export -f parse_framework_options
export -f parse_framework_cli
export -f validate_framework_command
export -f get_framework_command
export -f is_framework_option_set
export -f get_framework_option
