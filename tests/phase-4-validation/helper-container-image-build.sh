#!/bin/bash
# Helper: Container Image Build and Distribution
# Purpose: Build container images and ensure they are properly copied and exist on the cluster

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="${VALIDATION_ROOT:-validation-output/phase-4-validation-$(date +%Y%m%d-%H%M%S)}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
Helper: Container Image Build and Distribution

Purpose: Build container images and ensure they are properly copied and exist on the cluster

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose logging
    --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR)
    --registry-path PATH Override registry path
    --skip-build        Skip container building, only test distribution
    --test-container FILE Use specific test container file

Examples:
    $0                          # Run full helper
    $0 --verbose                # Run with verbose logging
    $0 --skip-build             # Only test distribution (skip building)
    $0 --test-container my.sif  # Use specific container file

EOF
}

# Parse command line arguments
VERBOSE=false
LOG_LEVEL="INFO"
REGISTRY_PATH=""
SKIP_BUILD=false
TEST_CONTAINER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            LOG_LEVEL="DEBUG"
            shift
            ;;
        --log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        --registry-path)
            REGISTRY_PATH="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --test-container)
            TEST_CONTAINER="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Set up logging
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/helper-container-image-build.log"

exec > >(tee -a "$LOG_FILE")
exec 2>&1

log_info "=========================================="
log_info "Helper: Container Image Build & Distribution"
log_info "=========================================="
log_info "Log file: $LOG_FILE"
log_info "Log level: $LOG_LEVEL"
log_info "Verbose: $VERBOSE"
log_info "Skip build: $SKIP_BUILD"

# Change to project root
cd "$PROJECT_ROOT"

# ========================================
# Step 1: Build Container Images
# ========================================

if [ "$SKIP_BUILD" = false ]; then
    log_info "Step 1: Building container images..."

    # Build development container image (if not already built)
    log_info "Building development Docker image..."
    make build-docker

    # Build specific container images for testing
    log_info "Building test container images..."

    # Check if CMake target exists for container building
    if make run-docker COMMAND="cmake --build build --target help" 2>/dev/null | grep -q "build-test-container"; then
        make run-docker COMMAND="cmake --build build --target build-test-container"
    else
        log_warning "No build-test-container target found, creating simple test container..."
    fi

    # Create a simple test container if none exists
    # Use containers from Step 3 if available, otherwise create test container
    if [ -z "$TEST_CONTAINER" ]; then
        # Look for containers built in Step 3
        if [ -f "build/containers/base-images/hello-world.sif" ]; then
            TEST_CONTAINER="build/containers/base-images/hello-world.sif"
            log_info "Using hello-world container from Step 3: $TEST_CONTAINER"
        elif [ -f "build/containers/base-images/python-test.sif" ]; then
            TEST_CONTAINER="build/containers/base-images/python-test.sif"
            log_info "Using python-test container from Step 3: $TEST_CONTAINER"
        elif [ ! -f "test-container.sif" ]; then
            log_info "Creating test container from hello-world..."
            make run-docker COMMAND="apptainer build test-container.sif docker://hello-world"
            TEST_CONTAINER="test-container.sif"
        else
            TEST_CONTAINER="test-container.sif"
            log_info "Using existing test container: $TEST_CONTAINER"
        fi
    elif [ -n "$TEST_CONTAINER" ]; then
        log_info "Using specified test container: $TEST_CONTAINER"
    fi

    # Verify container images were created
    log_info "Checking for container images..."
    if [ -d "build/containers" ]; then
        ls -la build/containers/
    else
        log_warning "No containers in build/containers/"
    fi

    if ls ./*.sif 2>/dev/null; then
        log_success "Found .sif files in current directory"
    else
        log_warning "No .sif files in current directory"
    fi
else
    log_info "Step 1: Skipping container build (--skip-build specified)"
fi

# ========================================
# Step 2: Deploy Container Registry Infrastructure
# ========================================

log_info "Step 2: Deploying container registry infrastructure..."

# Deploy container registry with BeeGFS backend
log_info "Running container registry playbook..."
ansible-playbook -i ansible/inventories/test/hosts ansible/playbooks/playbook-container-registry.yml

# Verify registry infrastructure
log_info "Verifying registry infrastructure..."
ssh admin@192.168.100.10 "ls -la /mnt/beegfs/containers/ || ls -la /opt/containers/"

# ========================================
# Step 3: Copy Container Images to Registry
# ========================================

log_info "Step 3: Copying container images to registry..."

# Determine registry path (BeeGFS or local)
if [ -z "$REGISTRY_PATH" ]; then
    REGISTRY_PATH=$(ssh admin@192.168.100.10 "if [ -d /mnt/beegfs/containers ]; then echo /mnt/beegfs/containers; else echo /opt/containers; fi")
fi
log_info "Using registry path: $REGISTRY_PATH"

# Use test container if specified or found
if [ -z "$TEST_CONTAINER" ]; then
    TEST_CONTAINER=$(find . -maxdepth 1 -name "*.sif" -type f | head -1)
fi

if [ -z "$TEST_CONTAINER" ] || [ ! -f "$TEST_CONTAINER" ]; then
    log_error "No test container found. Please specify with --test-container or ensure .sif files exist."
    exit 1
fi

log_info "Using test container: $TEST_CONTAINER"

# Copy container to registry
log_info "Copying $TEST_CONTAINER to registry..."
scp "$TEST_CONTAINER" "admin@192.168.100.10:$REGISTRY_PATH/ml-frameworks/"

# Verify container was copied
log_info "Verifying container was copied..."
ssh admin@192.168.100.10 "ls -la \"\$REGISTRY_PATH/ml-frameworks/\$TEST_CONTAINER\""

# ========================================
# Step 4: Verify Container Distribution
# ========================================

log_info "Step 4: Verifying container distribution across nodes..."

# Check if container exists on all nodes (BeeGFS should auto-distribute)
log_info "Checking container on all nodes..."
ssh admin@192.168.100.10 "ls -la \"\$REGISTRY_PATH/ml-frameworks/\$TEST_CONTAINER\""
ssh admin@192.168.100.11 "ls -la \"\$REGISTRY_PATH/ml-frameworks/\$TEST_CONTAINER\""
ssh admin@192.168.100.12 "ls -la \"\$REGISTRY_PATH/ml-frameworks/\$TEST_CONTAINER\""

# Test container execution on each node
log_info "Testing container execution..."
ssh admin@192.168.100.10 "apptainer exec \"\$REGISTRY_PATH/ml-frameworks/\$TEST_CONTAINER\" echo 'Hello from controller'"
ssh admin@192.168.100.11 "apptainer exec \"\$REGISTRY_PATH/ml-frameworks/\$TEST_CONTAINER\" echo 'Hello from compute01'"
ssh admin@192.168.100.12 "apptainer exec \"\$REGISTRY_PATH/ml-frameworks/\$TEST_CONTAINER\" echo 'Hello from compute02'"

# ========================================
# Step 5: Test Container Registry Management
# ========================================

log_info "Step 5: Testing container registry management..."

# List all containers in registry
log_info "Listing all containers in registry..."
ssh admin@192.168.100.10 "find \"\$REGISTRY_PATH\" -name '*.sif' -type f"

# Test container metadata
log_info "Testing container metadata..."
ssh admin@192.168.100.10 "apptainer inspect \"\$REGISTRY_PATH/ml-frameworks/\$TEST_CONTAINER\""

# Test container registry sync (if using local storage)
if [ "$REGISTRY_PATH" = "/opt/containers" ]; then
    log_info "Testing container sync to nodes (local storage mode)..."
    ssh admin@192.168.100.10 "/usr/local/bin/registry-sync-to-nodes.sh"
fi

# ========================================
# Summary
# ========================================

log_success "=========================================="
log_success "✅ Container Image Build & Distribution Complete"
log_success "=========================================="
log_info ""
log_info "Summary:"
log_info "- Container images built and copied to registry"
log_info "- Registry path: $REGISTRY_PATH"
log_info "- Container distribution verified across all nodes"
log_info "- Container execution tested on all nodes"
log_info ""
log_info "Next steps:"
log_info "1. Run Step 5: Storage Consolidation validation"
log_info "2. Test container registry with BeeGFS backend"
log_info "3. Verify container distribution and execution"
log_info ""
log_info "Log file: $LOG_FILE"
