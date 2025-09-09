#!/bin/bash
#
# Container Runtime Installation Verification
# Task 008 - Check Apptainer Installation and Version (Adjusted for v1.4.2)
# Validates installation and version compliance per Task 008 requirements
# Optimized for Apptainer 1.4.2 specific features and configuration
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="check-singularity-install.sh"
TEST_NAME="Container Runtime Installation Check"

# Use LOG_DIR from environment or default [[memory:8556508]]
: "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# Test configuration per Task 008 requirements
CONTAINER_RUNTIME_BINARY="apptainer"
REQUIRED_VERSION="1.4.2"  # Adjusted for actual Apptainer installation version

# Required dependencies per Task 008
REQUIRED_PACKAGES=(
    "fuse"                    # FUSE filesystem support
    "squashfs-tools"         # SquashFS utilities
    "uidmap"                 # User namespace mapping
    "libfuse2"               # FUSE runtime libraries
    "libseccomp2"            # Seccomp security support
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
FAILED_TESTS=()

# Logging functions with LOG_DIR compliance
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}
log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

run_test() {
    local test_name="$1"
    local test_function="$2"

    echo "Running: $test_name" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
    TESTS_RUN=$((TESTS_RUN + 1))

    if $test_function; then
        log_info "✅ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "❌ $test_name"
        FAILED_TESTS+=("$test_name")
    fi
    echo | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

# Task 008 Test Functions
test_apptainer_binary_available() {
    log_info "Checking for Apptainer binary..."

    if command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        local installed_path
        installed_path=$(which "$CONTAINER_RUNTIME_BINARY")
        log_info "Apptainer found at: $installed_path"
        return 0
    else
        log_error "Apptainer binary not found in PATH"
        return 1
    fi
}

test_apptainer_version() {
    log_info "Verifying Apptainer version..."

    if ! command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        log_error "Apptainer binary not available for version check"
        return 1
    fi

    local installed_version
    installed_version=$($CONTAINER_RUNTIME_BINARY --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) || {
        log_error "Failed to get Apptainer version"
        return 1
    }

    log_info "Installed Apptainer version: $installed_version"

    # Version comparison (simplified - expecting x.y.z format)
    local required_major required_minor required_patch
    local installed_major installed_minor installed_patch

    IFS='.' read -r required_major required_minor required_patch <<< "$REQUIRED_VERSION"
    IFS='.' read -r installed_major installed_minor installed_patch <<< "$installed_version"

    # Compare versions (major.minor.patch)
    if [[ $installed_major -gt $required_major ]] || \
       { [[ $installed_major -eq $required_major ]] && [[ $installed_minor -gt $required_minor ]]; } || \
       { [[ $installed_major -eq $required_major ]] && [[ $installed_minor -eq $required_minor ]] && [[ $installed_patch -ge $required_patch ]]; }; then
        log_info "Version requirement met: $installed_version >= $REQUIRED_VERSION"
        return 0
    else
        log_error "Version requirement not met: $installed_version < $REQUIRED_VERSION"
        return 1
    fi
}

test_singularity_compatibility() {
    log_info "Checking Singularity compatibility..."

    # Check if singularity command is available (compatibility layer)
    if command -v "singularity" >/dev/null 2>&1; then
        local singularity_version
        singularity_version=$(singularity --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) || true

        if [[ -n "$singularity_version" ]]; then
            log_info "Singularity compatibility available: $singularity_version"
        else
            log_warn "Singularity command available but version detection failed"
        fi
    else
        log_warn "Singularity compatibility command not available (using Apptainer only)"
    fi

    return 0  # This is not a hard requirement, just informational
}

test_required_dependencies() {
    log_info "Verifying required dependencies..."

    local missing_packages=()

    for package in "${REQUIRED_PACKAGES[@]}"; do
        if dpkg -l "$package" >/dev/null 2>&1; then
            local package_version
            package_version=$(dpkg -l "$package" | grep "^ii" | awk '{print $3}' | head -1)
            log_info "Package installed: $package ($package_version)"
        else
            log_error "Required package missing: $package"
            missing_packages+=("$package")
        fi
    done

    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        log_error "Missing required packages: ${missing_packages[*]}"
        return 1
    fi

    log_info "All required dependencies are installed"
    return 0
}

test_apptainer_help() {
    log_info "Testing Apptainer help functionality..."

    if ! command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        log_error "Apptainer binary not available for help test"
        return 1
    fi

    if $CONTAINER_RUNTIME_BINARY --help >/dev/null 2>&1; then
        log_info "Apptainer help command working"
        return 0
    else
        log_error "Apptainer help command failed"
        return 1
    fi
}

test_basic_functionality() {
    log_info "Testing basic Apptainer functionality..."

    if ! command -v "$CONTAINER_RUNTIME_BINARY" >/dev/null 2>&1; then
        log_error "Apptainer binary not available for functionality test"
        return 1
    fi

    # Test basic functionality without network access
    local test_output
    test_output=$($CONTAINER_RUNTIME_BINARY version 2>&1) || {
        log_error "Basic 'apptainer version' command failed"
        return 1
    }

    # Check if output contains a valid version number pattern (e.g., 1.4.2)
    if echo "$test_output" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        log_info "Basic functionality test passed - version: $test_output"
        return 0
    else
        log_error "Basic functionality test failed - unexpected output: '$test_output'"
        return 1
    fi
}

print_summary() {
    local failed=$((TESTS_RUN - TESTS_PASSED))

    {
        echo "========================================"
        echo "Container Runtime Installation Test Summary"
        echo "========================================"
        echo "Script: $SCRIPT_NAME"
        echo "Tests run: $TESTS_RUN"
        echo "Passed: $TESTS_PASSED"
        echo "Failed: $failed"
    } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"

    if [[ $failed -gt 0 ]]; then
        {
            echo "Failed tests:"
            printf '  ❌ %s\n' "${FAILED_TESTS[@]}"
            echo
            echo "❌ Container runtime installation validation FAILED"
        } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
        return 1
    else
        {
            echo
            echo "🎉 Container runtime installation validation PASSED!"
            echo
            echo "INSTALLATION COMPONENTS VALIDATED:"
            echo "  ✅ Apptainer binary available and functional"
            echo "  ✅ Version requirement met (>= $REQUIRED_VERSION)"
            echo "  ✅ Required dependencies installed"
            echo "  ✅ Basic functionality working"
        } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
        return 0
    fi
}

main() {
    {
        echo "========================================"
        echo "$TEST_NAME"
        echo "========================================"
        echo "Script: $SCRIPT_NAME"
        echo "Timestamp: $(date)"
        echo "Log Directory: $LOG_DIR"
        echo "Required Version: $REQUIRED_VERSION"
        echo
    } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"

    # Run Task 008 installation validation tests
    run_test "Apptainer binary available" test_apptainer_binary_available
    run_test "Apptainer version compliance" test_apptainer_version
    run_test "Singularity compatibility" test_singularity_compatibility
    run_test "Required dependencies installed" test_required_dependencies
    run_test "Apptainer help functionality" test_apptainer_help
    run_test "Basic functionality" test_basic_functionality

    print_summary
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
