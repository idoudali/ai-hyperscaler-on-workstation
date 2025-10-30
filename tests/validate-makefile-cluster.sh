#!/bin/bash
# Validate SLURM Deployment on Makefile-Created Clusters
#
# This script validates SLURM clusters deployed via:
#   make hpc-cluster-start && make hpc-cluster-deploy
#
# It leverages existing test suites but adapts them to use Makefile-generated
# inventory and configuration files instead of creating its own test cluster.
#
# Usage:
#   ./validate-makefile-cluster.sh [MODE]
#
# Modes:
#   slurm-only      - Validate SLURM controller and compute (default)
#   controller-only - Validate controller services only
#   compute-only    - Validate compute nodes only
#   run-examples    - Run MPI example jobs
#   quick           - Quick validation (no examples)
#   help            - Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration paths (from Makefile deployment)
CLUSTER_CONFIG="${CLUSTER_CONFIG:-$PROJECT_ROOT/config/example-multi-gpu-clusters.yaml}"
RENDERED_CONFIG="${RENDERED_CONFIG:-$PROJECT_ROOT/output/cluster-state/rendered-config.yaml}"
INVENTORY_FILE="${INVENTORY_FILE:-$PROJECT_ROOT/output/cluster-state/inventory.yml}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
SSH_USER="${SSH_USER:-admin}"

# Test suite locations
CONTROLLER_SUITE="$SCRIPT_DIR/suites/slurm-controller"
COMPUTE_SUITE="$SCRIPT_DIR/suites/slurm-compute"
EXAMPLES_DIR="$PROJECT_ROOT/examples/slurm-jobs"

# Logging
LOG_DIR="$SCRIPT_DIR/logs/validation"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/validate-${TIMESTAMP}.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize logging
init_logging() {
    mkdir -p "$LOG_DIR"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1
}

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ✗${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $*"
}

# Show help
show_help() {
    cat << EOF
SLURM Validation for Makefile-Deployed Clusters

Usage:
    $0 [MODE]

Modes:
    slurm-only      - Validate SLURM controller and compute (default)
    controller-only - Validate controller services only
    compute-only    - Validate compute nodes only
    run-examples    - Run MPI example jobs on cluster
    quick           - Quick validation (controller + compute, no examples)
    help            - Show this help message

Prerequisites:
    1. Cluster deployed via: make hpc-cluster-start && make hpc-cluster-deploy
    2. Inventory file exists: $INVENTORY_FILE
    3. SSH key accessible: $SSH_KEY_PATH

Environment Variables:
    CLUSTER_CONFIG    - Cluster configuration file (default: config/example-multi-gpu-clusters.yaml)
    RENDERED_CONFIG   - Rendered configuration (default: output/cluster-state/rendered-config.yaml)
    INVENTORY_FILE    - Ansible inventory (default: output/cluster-state/inventory.yml)
    SSH_KEY_PATH      - SSH private key (default: build/shared/ssh-keys/id_rsa)
    SSH_USER          - SSH username (default: admin)

Examples:
    # Validate complete SLURM setup
    $0 slurm-only

    # Validate controller only
    $0 controller-only

    # Run example jobs
    $0 run-examples

EOF
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    local errors=0

    # Check inventory file
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        log_error "Inventory file not found: $INVENTORY_FILE"
        log "       Run: make hpc-cluster-inventory"
        ((errors++))
    else
        log_success "Inventory file found: $INVENTORY_FILE"
    fi

    # Check SSH key
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        log_error "SSH key not found: $SSH_KEY_PATH"
        log "       Run: make hpc-cluster-start (generates keys)"
        ((errors++))
    else
        log_success "SSH key found: $SSH_KEY_PATH"
    fi

    # Check cluster config
    if [[ ! -f "$CLUSTER_CONFIG" ]]; then
        log_warning "Cluster config not found: $CLUSTER_CONFIG"
        log "         Using rendered config if available"
    else
        log_success "Cluster config found: $CLUSTER_CONFIG"
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Prerequisites check failed with $errors error(s)"
        return 1
    fi

    log_success "All prerequisites met"
    return 0
}

# Extract controller IP from inventory
get_controller_ip() {
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        log_error "Cannot extract controller IP: inventory file not found"
        return 1
    fi

    # Parse YAML inventory for controller IP
    # Look for ansible_host under hpc_controller group
    local controller_ip
    controller_ip=$(grep -A 5 'hpc_controller:' "$INVENTORY_FILE" | grep 'ansible_host:' | head -1 | awk '{print $2}' | tr -d '"')

    if [[ -z "$controller_ip" ]]; then
        log_error "Could not extract controller IP from inventory"
        return 1
    fi

    echo "$controller_ip"
}

# Extract compute node IPs from inventory
get_compute_ips() {
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        log_error "Cannot extract compute IPs: inventory file not found"
        return 1
    fi

    # Parse YAML inventory for compute node IPs
    # Look for ansible_host under hpc_compute group
    local compute_ips
    compute_ips=$(grep -A 20 'hpc_compute:' "$INVENTORY_FILE" | grep 'ansible_host:' | awk '{print $2}' | tr -d '"')

    if [[ -z "$compute_ips" ]]; then
        log_warning "No compute nodes found in inventory"
        return 0
    fi

    echo "$compute_ips"
}

# Test SSH connectivity
test_ssh_connectivity() {
    local host="$1"
    local name="$2"

    log "Testing SSH connectivity to $name ($host)..."

    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "${SSH_USER}@${host}" "echo 'SSH OK'" &>/dev/null; then
        log_success "SSH connectivity OK: $name"
        return 0
    else
        log_error "SSH connectivity failed: $name"
        return 1
    fi
}

# Validate controller
validate_controller() {
    log ""
    log "=========================================="
    log "Validating SLURM Controller"
    log "=========================================="

    local controller_ip
    controller_ip=$(get_controller_ip) || return 1

    log "Controller IP: $controller_ip"

    # Test SSH connectivity
    test_ssh_connectivity "$controller_ip" "controller" || return 1

    # Run controller test suite
    if [[ -d "$CONTROLLER_SUITE" ]] && [[ -f "$CONTROLLER_SUITE/run-slurm-controller-tests.sh" ]]; then
        log "Running controller test suite..."

        # Export variables for test suite
        export CONTROLLER_IP="$controller_ip"
        export SSH_KEY_PATH SSH_USER
        export MAKEFILE_CLUSTER_MODE="true"

        if "$CONTROLLER_SUITE/run-slurm-controller-tests.sh"; then
            log_success "Controller validation passed"
            return 0
        else
            log_error "Controller validation failed"
            return 1
        fi
    else
        log_warning "Controller test suite not found at: $CONTROLLER_SUITE"
        log "         Running basic validation..."

        # Basic validation: check slurmctld service
        if ssh -i "$SSH_KEY_PATH" "${SSH_USER}@${controller_ip}" \
            "systemctl is-active slurmctld" &>/dev/null; then
            log_success "slurmctld service is active"
        else
            log_error "slurmctld service is not active"
            return 1
        fi

        # Check slurmdbd service
        if ssh -i "$SSH_KEY_PATH" "${SSH_USER}@${controller_ip}" \
            "systemctl is-active slurmdbd" &>/dev/null; then
            log_success "slurmdbd service is active"
        else
            log_warning "slurmdbd service is not active (may be optional)"
        fi

        log_success "Basic controller validation passed"
    fi

    return 0
}

# Validate compute nodes
validate_compute() {
    log ""
    log "=========================================="
    log "Validating SLURM Compute Nodes"
    log "=========================================="

    local compute_ips
    compute_ips=$(get_compute_ips)

    if [[ -z "$compute_ips" ]]; then
        log_warning "No compute nodes to validate"
        return 0
    fi

    local compute_count
    compute_count=$(echo "$compute_ips" | wc -l)
    log "Found $compute_count compute node(s)"

    # Test SSH connectivity to all nodes
    local ssh_ok=0
    while IFS= read -r compute_ip; do
        if test_ssh_connectivity "$compute_ip" "compute-node"; then
            ((ssh_ok++))
        fi
    done <<< "$compute_ips"

    if [[ $ssh_ok -eq 0 ]]; then
        log_error "No compute nodes accessible via SSH"
        return 1
    fi

    log_success "$ssh_ok/$compute_count compute nodes accessible"

    # Run compute test suite
    if [[ -d "$COMPUTE_SUITE" ]] && [[ -f "$COMPUTE_SUITE/run-slurm-compute-tests.sh" ]]; then
        log "Running compute test suite..."

        # Export variables for test suite
        export COMPUTE_IPS="$compute_ips"
        export SSH_KEY_PATH SSH_USER
        export MAKEFILE_CLUSTER_MODE="true"

        if "$COMPUTE_SUITE/run-slurm-compute-tests.sh"; then
            log_success "Compute validation passed"
            return 0
        else
            log_error "Compute validation failed"
            return 1
        fi
    else
        log_warning "Compute test suite not found at: $COMPUTE_SUITE"
        log "         Running basic validation..."

        # Basic validation: check slurmd service on first node
        local first_compute
        first_compute=$(echo "$compute_ips" | head -1)

        if ssh -i "$SSH_KEY_PATH" "${SSH_USER}@${first_compute}" \
            "systemctl is-active slurmd" &>/dev/null; then
            log_success "slurmd service is active on compute node"
        else
            log_error "slurmd service is not active on compute node"
            return 1
        fi

        log_success "Basic compute validation passed"
    fi

    return 0
}

# Run example MPI jobs
run_examples() {
    log ""
    log "=========================================="
    log "Running MPI Example Jobs"
    log "=========================================="

    if [[ ! -d "$EXAMPLES_DIR" ]]; then
        log_error "Examples directory not found: $EXAMPLES_DIR"
        log "       Run Task 3 to create MPI examples"
        return 1
    fi

    local controller_ip
    controller_ip=$(get_controller_ip) || return 1

    log "Controller IP: $controller_ip"
    log "Examples directory: $EXAMPLES_DIR"

    # Check if examples exist
    if [[ ! -d "$EXAMPLES_DIR/hello-world" ]]; then
        log_warning "Hello-world example not found"
        log "         Run Task 3 to create MPI examples"
        return 0
    fi

    log "Copying examples to controller..."
    if ! scp -i "$SSH_KEY_PATH" -r "$EXAMPLES_DIR" \
        "${SSH_USER}@${controller_ip}:/tmp/"; then
        log_error "Failed to copy examples to controller"
        return 1
    fi

    log_success "Examples copied to controller:/tmp/slurm-jobs"

    # Run hello-world example
    log "Running hello-world example..."
    if ssh -i "$SSH_KEY_PATH" "${SSH_USER}@${controller_ip}" \
        "cd /tmp/slurm-jobs/hello-world && bash compile.sh && sbatch hello.sbatch"; then
        log_success "Hello-world job submitted"
    else
        log_error "Failed to submit hello-world job"
        return 1
    fi

    log "Monitor job status with: ssh ${SSH_USER}@${controller_ip} squeue"

    return 0
}

# Main execution
main() {
    local mode="${1:-slurm-only}"

    init_logging

    log "=========================================="
    log "SLURM Validation for Makefile Clusters"
    log "=========================================="
    log "Mode: $mode"
    log "Timestamp: $TIMESTAMP"
    log "Log file: $LOG_FILE"
    log ""

    case "$mode" in
        help|--help|-h)
            show_help
            exit 0
            ;;
        slurm-only)
            check_prerequisites || exit 1
            validate_controller || exit 1
            validate_compute || exit 1
            log ""
            log_success "=========================================="
            log_success "SLURM Validation Complete"
            log_success "=========================================="
            ;;
        controller-only)
            check_prerequisites || exit 1
            validate_controller || exit 1
            log ""
            log_success "Controller validation complete"
            ;;
        compute-only)
            check_prerequisites || exit 1
            validate_compute || exit 1
            log ""
            log_success "Compute validation complete"
            ;;
        run-examples)
            check_prerequisites || exit 1
            run_examples || exit 1
            log ""
            log_success "Example jobs submitted"
            ;;
        quick)
            check_prerequisites || exit 1
            validate_controller || exit 1
            validate_compute || exit 1
            log ""
            log_success "Quick validation complete"
            ;;
        *)
            log_error "Unknown mode: $mode"
            show_help
            exit 1
            ;;
    esac

    log ""
    log "Log saved to: $LOG_FILE"
}

# Execute main
main "$@"
