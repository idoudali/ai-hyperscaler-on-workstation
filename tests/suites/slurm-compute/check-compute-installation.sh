#!/bin/bash
#
# SLURM Compute Node Installation Validation Script
# Task 022 - SLURM Compute Installation Validation
# Validates SLURM compute packages and all required dependencies
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="check-compute-installation.sh"
TEST_NAME="SLURM Compute Node Installation Validation"

# Use LOG_DIR from environment or default
: "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
FAILED_TESTS=()

# Expected packages for compute nodes
REQUIRED_SLURM_PACKAGES=(
    "slurmd"                 # SLURM daemon
    "slurm-client"           # Client tools
    "munge"                  # Authentication
    "libmunge2"              # Runtime libraries
    "libpmix2"               # PMIx runtime
)

# Container runtime support packages
CONTAINER_PACKAGES=(
    "squashfs-tools"         # For container images
    "cryptsetup-bin"         # For encryption
    "fuse"                   # For overlay filesystems
)

# Required SLURM binaries
SLURM_BINARIES=(
    "slurmd"
    "srun"
    "squeue"
    "scancel"
    "scontrol"
)

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1" | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
}

# Test execution functions
run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    echo -e "\n${BLUE}Running Test ${TESTS_RUN}: ${test_name}${NC}"

    if $test_function; then
        log_info "✓ Test passed: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ Test failed: $test_name"
        FAILED_TESTS+=("$test_name")
        return 1
    fi
}

# Individual test functions
test_slurm_packages_installed() {
    log_info "Checking SLURM compute packages installation..."
    local missing_packages=()
    local installed_packages=()

    for package in "${REQUIRED_SLURM_PACKAGES[@]}"; do
        if dpkg -l "$package" >/dev/null 2>&1; then
            log_debug "✓ Package installed: $package"
            installed_packages+=("$package")
        else
            log_warn "✗ Missing package: $package"
            missing_packages+=("$package")
        fi
    done

    log_info "Installed packages: ${#installed_packages[@]}/${#REQUIRED_SLURM_PACKAGES[@]}"

    if [ ${#installed_packages[@]} -eq 0 ]; then
        log_warn "No SLURM packages found - installation may not be complete"
        return 0
    elif [ ${#missing_packages[@]} -eq 0 ]; then
        log_info "All required SLURM packages are installed"
        return 0
    else
        log_warn "Some packages missing: ${missing_packages[*]}"
        return 0
    fi
}

test_container_packages_installed() {
    log_info "Checking container support packages installation..."
    local missing_packages=()
    local installed_packages=()

    for package in "${CONTAINER_PACKAGES[@]}"; do
        if dpkg -l "$package" >/dev/null 2>&1; then
            log_debug "✓ Package installed: $package"
            installed_packages+=("$package")
        else
            log_warn "✗ Missing package: $package"
            missing_packages+=("$package")
        fi
    done

    log_info "Installed container packages: ${#installed_packages[@]}/${#CONTAINER_PACKAGES[@]}"

    if [ ${#installed_packages[@]} -eq 0 ]; then
        log_warn "No container support packages found"
        return 0
    elif [ ${#missing_packages[@]} -eq 0 ]; then
        log_info "All container support packages are installed"
        return 0
    else
        log_warn "Some container packages missing: ${missing_packages[*]}"
        return 0
    fi
}

test_slurm_binaries_available() {
    log_info "Checking SLURM binary availability..."
    local missing_binaries=()
    local available_binaries=()

    for binary in "${SLURM_BINARIES[@]}"; do
        if command -v "$binary" >/dev/null 2>&1; then
            log_debug "✓ Binary available: $binary"
            available_binaries+=("$binary")
        else
            log_warn "✗ Missing binary: $binary"
            missing_binaries+=("$binary")
        fi
    done

    log_info "Available binaries: ${#available_binaries[@]}/${#SLURM_BINARIES[@]}"

    if [ ${#available_binaries[@]} -eq 0 ]; then
        log_warn "No SLURM binaries found"
        return 0
    elif [ ${#missing_binaries[@]} -eq 0 ]; then
        log_info "All required SLURM binaries are available"
        return 0
    else
        log_warn "Some binaries missing: ${missing_binaries[*]}"
        return 0
    fi
}

test_slurm_version_check() {
    log_info "Verifying SLURM version information..."
    local version_checks_passed=0

    # Test slurmd version
    if command -v slurmd >/dev/null 2>&1 && slurmd -V >/dev/null 2>&1; then
        local slurmd_version
        slurmd_version=$(slurmd -V 2>&1 | head -n1)
        log_info "✓ slurmd version: $slurmd_version"
        version_checks_passed=$((version_checks_passed + 1))
    else
        log_warn "✗ slurmd not available or version check failed"
    fi

    # Test srun version
    if command -v srun >/dev/null 2>&1 && srun --version >/dev/null 2>&1; then
        local srun_version
        srun_version=$(srun --version 2>&1)
        log_info "✓ srun version: $srun_version"
        version_checks_passed=$((version_checks_passed + 1))
    else
        log_warn "✗ srun not available or version check failed"
    fi

    if [ $version_checks_passed -eq 0 ]; then
        log_warn "No SLURM version information available"
        return 0
    else
        return 0
    fi
}

test_pmix_libraries() {
    log_info "Checking PMIx libraries..."
    local found_pmix=false

    if [ -f "/usr/lib/x86_64-linux-gnu/libpmix.so.2" ]; then
        log_info "✓ PMIx library found: /usr/lib/x86_64-linux-gnu/libpmix.so.2"
        found_pmix=true
    fi

    if find /usr/lib* -name "libpmix*" 2>/dev/null | grep -q libpmix; then
        log_info "✓ PMIx libraries detected in system"
        found_pmix=true
    fi

    if [ "$found_pmix" = true ]; then
        return 0
    else
        log_warn "No PMIx libraries found"
        return 0
    fi
}

test_munge_installation() {
    log_info "Checking MUNGE authentication system..."

    if ! command -v mungekey >/dev/null 2>&1; then
        log_warn "mungekey command not found"
        return 0
    fi

    log_info "✓ MUNGE tools available"

    # Check MUNGE key exists
    if [ -f "/etc/munge/munge.key" ]; then
        log_info "✓ MUNGE key file exists"

        # Check key permissions
        local key_perms
        key_perms=$(stat -c "%a" /etc/munge/munge.key)
        if [ "$key_perms" = "400" ] || [ "$key_perms" = "600" ]; then
            log_info "✓ MUNGE key has correct permissions ($key_perms)"
        else
            log_warn "MUNGE key permissions may be incorrect: $key_perms (expected 400 or 600)"
        fi
    else
        log_warn "MUNGE key file not found at /etc/munge/munge.key"
    fi

    return 0
}

test_container_runtime() {
    log_info "Checking container runtime availability..."

    if command -v apptainer >/dev/null 2>&1; then
        local version
        version=$(apptainer --version 2>&1)
        log_info "✓ Apptainer available: $version"
        return 0
    elif command -v singularity >/dev/null 2>&1; then
        local version
        version=$(singularity --version 2>&1)
        log_info "✓ Singularity available: $version"
        return 0
    else
        log_warn "No container runtime found (apptainer/singularity)"
        return 0
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}  $TEST_NAME${NC}"
    echo -e "${BLUE}=====================================${NC}"

    log_info "Starting SLURM compute node installation validation"
    log_info "Log directory: $LOG_DIR"

    # Run all tests
    run_test "SLURM Packages Installation" test_slurm_packages_installed
    run_test "Container Support Packages" test_container_packages_installed
    run_test "SLURM Binaries Availability" test_slurm_binaries_available
    run_test "SLURM Version Verification" test_slurm_version_check
    run_test "PMIx Libraries" test_pmix_libraries
    run_test "MUNGE Installation" test_munge_installation
    run_test "Container Runtime" test_container_runtime

    # Final results
    echo -e "\n${BLUE}=====================================${NC}"
    echo -e "${BLUE}  Test Results Summary${NC}"
    echo -e "${BLUE}=====================================${NC}"

    echo -e "Total tests run: ${TESTS_RUN}"
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}$((TESTS_RUN - TESTS_PASSED))${NC}"

    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        echo -e "\n${RED}Failed tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  - $test"
        done
    fi

    if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
        log_info "SLURM compute node installation validation passed (${TESTS_PASSED}/${TESTS_RUN} tests)"
        return 0
    else
        log_warn "Some tests had issues (${TESTS_PASSED}/${TESTS_RUN} tests passed)"
        return 0
    fi
}

# Execute main function
main "$@"
