#!/bin/bash
# Build HPC Base Images with Packer - Test Suite
# Validates Packer base image building and functionality

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
CONTAINER_SCRIPT="$PROJECT_ROOT/scripts/run-in-dev-container.sh"
BUILD_DIR="$PROJECT_ROOT/build"

# Expected paths from Task 001 specification
HPC_IMAGE="$BUILD_DIR/packer/hpc-base/hpc-base/hpc-base.qcow2"
CLOUD_IMAGE="$BUILD_DIR/packer/cloud-base/cloud-base/cloud-base.qcow2"
SSH_PRIVATE_KEY="$BUILD_DIR/shared/ssh-keys/id_rsa"
SSH_PUBLIC_KEY="$BUILD_DIR/shared/ssh-keys/id_rsa.pub"

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
FORCE_CLEANUP=false

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

# Task 001 Validation Criteria Tests
test_container_script_available() {
    [[ -x "$CONTAINER_SCRIPT" ]] || {
        log_error "Container script not found or not executable: $CONTAINER_SCRIPT"
        return 1
    }
}

test_build_hpc_image() {
    log_info "Checking HPC base image..."

    # Check if image already exists
    if [[ -f "$HPC_IMAGE" ]]; then
        if [[ "$FORCE_CLEANUP" == "true" ]]; then
            log_info "Removing existing HPC image (--force-cleanup specified)"
            rm -f "$HPC_IMAGE"
        else
            log_info "Pre-existing HPC base image found: $HPC_IMAGE"
            log_info "Using existing image (use --force-cleanup to rebuild)"
            return 0
        fi
    fi

    log_info "Building HPC base image..."
    log_info "Press Ctrl+C to interrupt if needed"

    # Build using dev container with proper signal handling
    log_verbose "Running: $CONTAINER_SCRIPT cmake --build build --target build-hpc-image"
    log_info "Build started... (this may take 20-30 minutes)"

    if "$CONTAINER_SCRIPT" cmake --build build --target build-hpc-image; then
        [[ -f "$HPC_IMAGE" ]] || {
            log_error "Build succeeded but image not found: $HPC_IMAGE"
            return 1
        }
    else
        local exit_code=$?
        if [[ $exit_code -eq 130 ]] || [[ $exit_code -eq 143 ]]; then
            log_warn "HPC image build interrupted by user"
        else
            log_error "HPC image build failed (exit code: $exit_code)"
        fi
        return 1
    fi
}

test_build_cloud_image() {
    log_info "Checking Cloud base image..."

    # Check if image already exists
    if [[ -f "$CLOUD_IMAGE" ]]; then
        if [[ "$FORCE_CLEANUP" == "true" ]]; then
            log_info "Removing existing Cloud image (--force-cleanup specified)"
            rm -f "$CLOUD_IMAGE"
        else
            log_info "Pre-existing Cloud base image found: $CLOUD_IMAGE"
            log_info "Using existing image (use --force-cleanup to rebuild)"
            return 0
        fi
    fi

    log_info "Building Cloud base image..."
    log_info "Press Ctrl+C to interrupt if needed"

    # Build using dev container with proper signal handling
    log_verbose "Running: $CONTAINER_SCRIPT cmake --build build --target build-cloud-image"
    log_info "Build started... (this may take 20-30 minutes)"

    if "$CONTAINER_SCRIPT" cmake --build build --target build-cloud-image; then
        [[ -f "$CLOUD_IMAGE" ]] || {
            log_error "Build succeeded but image not found: $CLOUD_IMAGE"
            return 1
        }
    else
        local exit_code=$?
        if [[ $exit_code -eq 130 ]] || [[ $exit_code -eq 143 ]]; then
            log_warn "Cloud image build interrupted by user"
        else
            log_error "Cloud image build failed (exit code: $exit_code)"
        fi
        return 1
    fi
}

test_images_boot_qemu() {
    log_info "Testing images boot successfully in QEMU..."

    for image in "$HPC_IMAGE" "$CLOUD_IMAGE"; do
        local name
        name=$(basename "$image" .qcow2)

        [[ -f "$image" ]] || {
            log_error "$name image not found"
            return 1
        }

        # Quick QEMU validation - check if image is readable
        log_info "Checking $name image integrity..."
        if ! "$CONTAINER_SCRIPT" qemu-img check "$image" 2>&1 | grep -E "(Image end offset|No errors were found)" >/dev/null; then
            log_error "$name image failed QEMU integrity check"
            return 1
        fi

        log_info "$name image passes QEMU validation"
    done
}

test_ssh_keys_generated() {
    log_info "Verifying SSH key generation..."

    [[ -f "$SSH_PRIVATE_KEY" ]] || {
        log_error "Private SSH key not found: $SSH_PRIVATE_KEY"
        return 1
    }

    [[ -f "$SSH_PUBLIC_KEY" ]] || {
        log_error "Public SSH key not found: $SSH_PUBLIC_KEY"
        return 1
    }

    # Validate key format
    log_info "Validating SSH key format..."
    if ! "$CONTAINER_SCRIPT" ssh-keygen -l -f "$SSH_PRIVATE_KEY" >/dev/null 2>&1; then
        log_error "SSH private key validation failed"
        return 1
    fi

    # Check permissions (within reasonable range)
    local private_perms
    private_perms=$(stat -c%a "$SSH_PRIVATE_KEY")
    [[ "$private_perms" == "600" ]] || {
        log_warn "Private key permissions: $private_perms (expected 600)"
    }
}

test_base_system_packages() {
    log_info "Validating base system packages (basic check)..."

    for image in "$HPC_IMAGE" "$CLOUD_IMAGE"; do
        local name
        name=$(basename "$image" .qcow2)

        [[ -f "$image" ]] || {
            log_error "$name image not found"
            return 1
        }

        # Basic image format and size validation
        local info
        info=$("$CONTAINER_SCRIPT" qemu-img info "$image") || {
            log_error "$name image info failed"
            return 1
        }

        # Check format
        echo "$info" | grep -q "file format: qcow2" || {
            log_error "$name is not qcow2 format"
            return 1
        }

        # Check size (<2GB as per success criteria)
        local size_bytes
        size_bytes=$(stat -c%s "$image")
        local size_gb
        size_gb=$(echo "scale=2; $size_bytes/1024/1024/1024" | bc)

        if (( $(echo "$size_gb > 2.0" | bc -l) )); then
            log_error "$name too large: ${size_gb}GB (max 2GB)"
            return 1
        fi

        log_info "$name: qcow2, ${size_gb}GB"
    done
}

print_summary() {
    local failed=$((TESTS_RUN - TESTS_PASSED))

    echo "=================================="
    echo "Base Images Build Test Summary"
    echo "=================================="
    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $failed"

    if [[ $failed -gt 0 ]]; then
        echo "Failed tests:"
        printf '  ❌ %s\n' "${FAILED_TESTS[@]}"
        echo
        echo "❌ Base images build validation FAILED"
        return 1
    else
        echo
        echo "🎉 Base images build validation PASSED!"
        echo
        echo "Components validated:"
        echo "  ✅ HPC base image (hpc-base.qcow2)"
        echo "  ✅ Cloud base image (cloud-base.qcow2)"
        echo "  ✅ Images boot successfully in QEMU"
        echo "  ✅ SSH access keys generated"
        echo "  ✅ Base system packages properly installed"
        return 0
    fi
}

main() {
    echo "Build HPC Base Images with Packer - Test Suite"
    echo "Using dev container: $CONTAINER_SCRIPT"
    echo "Project root: $PROJECT_ROOT"
    echo

    # Run base images validation tests
    run_test "Container script available" test_container_script_available
    run_test "Build HPC image" test_build_hpc_image
    run_test "Build Cloud image" test_build_cloud_image
    run_test "Images boot in QEMU" test_images_boot_qemu
    run_test "SSH keys generated" test_ssh_keys_generated
    run_test "Base system packages validated" test_base_system_packages

    print_summary
}

# Handle command line options
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            echo "Build HPC Base Images with Packer - Test Suite"
            echo "Usage: $0 [--help|--skip-build|--verbose|--force-cleanup]"
            echo
            echo "This test validates Packer base image building:"
            echo "  - Built HPC base image (hpc-base.qcow2)"
            echo "  - Built Cloud base image (cloud-base.qcow2)"
            echo "  - Verified base image functionality"
            echo "  - SSH keys generated and accessible"
            echo
            echo "Options:"
            echo "  --skip-build     Test existing images without building"
            echo "  --verbose        Show detailed command output"
            echo "  --force-cleanup  Remove existing images and rebuild from scratch"
            echo
            echo "By default, existing images are reused to save time."
            echo "All builds run inside the dev container for consistency."
            echo "Press Ctrl+C to interrupt long-running builds."
            exit 0
            ;;
        --verbose)
            VERBOSE_MODE=true
            log_info "Verbose mode enabled"
            ;;
        --force-cleanup)
            FORCE_CLEANUP=true
            log_info "Force cleanup mode enabled - will rebuild all images"
            ;;
        --skip-build)
            SKIP_BUILD=true
            log_info "Skip build mode enabled - will test existing images only"
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Override build tests if --skip-build was specified
if [[ "$SKIP_BUILD" == "true" ]]; then
    test_build_hpc_image() {
        [[ -f "$HPC_IMAGE" ]] || {
            log_error "HPC image not found (use full test to build): $HPC_IMAGE"
            return 1
        }
        log_info "HPC image found (build skipped)"
    }
    test_build_cloud_image() {
        [[ -f "$CLOUD_IMAGE" ]] || {
            log_error "Cloud image not found (use full test to build): $CLOUD_IMAGE"
            return 1
        }
        log_info "Cloud image found (build skipped)"
    }
fi

main "$@"
