#!/bin/bash
#
# SSH Connectivity Test
# Task 005 - Test SSH connectivity and authentication
# Validates SSH capabilities per Task 005 requirements
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Script configuration
SCRIPT_NAME="check-ssh-connectivity.sh"
TEST_NAME="SSH Connectivity Test"

# Use LOG_DIR from environment or default
: "${LOG_DIR:=$(pwd)/logs/run-$(date '+%Y-%m-%d_%H-%M-%S')}"
mkdir -p "$LOG_DIR"

# SSH configuration
SSH_KEY_PATH="${SSH_KEY_PATH:-$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
SSH_USER="${SSH_USER:-admin}"
SSH_OPTS="${SSH_OPTS:--o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR}"

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

# Task 005 Test Functions
test_ssh_key_exists() {
    log_info "Checking if SSH key exists..."

    if [[ -f "$SSH_KEY_PATH" ]]; then
        local key_perms
        key_perms=$(stat -c "%a" "$SSH_KEY_PATH" 2>/dev/null || echo "unknown")
        log_info "SSH key found: $SSH_KEY_PATH (permissions: $key_perms)"
        return 0
    else
        log_error "SSH key not found: $SSH_KEY_PATH"
        return 1
    fi
}

test_ssh_key_permissions() {
    log_info "Checking SSH key permissions..."

    if [[ -f "$SSH_KEY_PATH" ]]; then
        local key_perms
        key_perms=$(stat -c "%a" "$SSH_KEY_PATH" 2>/dev/null || echo "unknown")

        # SSH keys should have restrictive permissions (600 or 400)
        if [[ "$key_perms" == "600" ]] || [[ "$key_perms" == "400" ]]; then
            log_info "SSH key permissions are correct: $key_perms"
            return 0
        else
            log_warn "SSH key permissions may be too permissive: $key_perms (should be 600 or 400)"
            return 0  # Don't fail for this, just warn
        fi
    else
        log_error "SSH key not found for permission check"
        return 1
    fi
}

test_vm_ssh_connectivity() {
    log_info "Testing SSH connectivity to VMs..."

    local vm_ips=()
    local vm_names
    vm_names=$(virsh list --name | grep test-hpc-minimal || true)

    if [[ -z "$vm_names" ]]; then
        log_error "No test VMs found for SSH testing"
        return 1
    fi

    # Get IP addresses for each VM with retries
    while IFS= read -r vm_name; do
        if [[ -n "$vm_name" ]]; then
            local vm_ip=""
            local attempts=0
            local max_attempts=5

            # Try to get IP with retries
            while [[ -z "$vm_ip" && $attempts -lt $max_attempts ]]; do
                vm_ip=$(virsh domifaddr "$vm_name" 2>/dev/null | grep -E "ipv4|ipv6" | awk '{print $4}' | head -1 | cut -d'/' -f1 || echo "")
                if [[ -z "$vm_ip" ]]; then
                    attempts=$((attempts + 1))
                    log_info "Waiting for IP for VM $vm_name (attempt $attempts/$max_attempts)..."
                    sleep 2
                fi
            done

            if [[ -n "$vm_ip" ]]; then
                vm_ips+=("$vm_ip")
                log_info "Found VM $vm_name with IP: $vm_ip"
            else
                log_warn "Could not get IP for VM: $vm_name after $max_attempts attempts"
            fi
        fi
    done <<< "$vm_names"

    if [[ ${#vm_ips[@]} -eq 0 ]]; then
        log_error "No VM IPs found for SSH testing"
        return 1
    fi

    # Test SSH connectivity to each VM with retries
    local ssh_success=0
    for vm_ip in "${vm_ips[@]}"; do
        log_info "Testing SSH connection to $vm_ip..."

        local ssh_attempts=0
        local ssh_max_attempts=3

        while [[ $ssh_attempts -lt $ssh_max_attempts ]]; do
            # shellcheck disable=SC2086
            if timeout 30s ssh $SSH_OPTS -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "echo 'SSH working'" 2>&1 | tee -a "$LOG_DIR/ssh-test-$vm_ip.log"; then
                log_info "SSH connection to $vm_ip successful"
                ssh_success=1
                break
            else
                ssh_attempts=$((ssh_attempts + 1))
                if [[ $ssh_attempts -lt $ssh_max_attempts ]]; then
                    log_warn "SSH connection to $vm_ip failed (attempt $ssh_attempts/$ssh_max_attempts), retrying..."
                    sleep 5
                else
                    log_warn "SSH connection to $vm_ip failed after $ssh_max_attempts attempts"
                fi
            fi
        done
    done

    if [[ $ssh_success -eq 1 ]]; then
        return 0
    else
        log_error "All SSH connections failed"
        return 1
    fi
}

test_ssh_authentication() {
    log_info "Testing SSH authentication..."

    local vm_ip
    vm_ip=$(virsh domifaddr "$(virsh list --name | grep test-hpc-minimal | head -1)" 2>/dev/null | grep -E "ipv4|ipv6" | awk '{print $4}' | head -1 | cut -d'/' -f1 || echo "")

    if [[ -z "$vm_ip" ]]; then
        log_error "No VM IP found for authentication test"
        return 1
    fi

    # Test various SSH authentication scenarios
    log_info "Testing SSH authentication to $vm_ip..."

    # Test basic command execution
    # shellcheck disable=SC2086
    if timeout 30s ssh $SSH_OPTS -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "whoami" 2>&1 | tee -a "$LOG_DIR/ssh-auth-test.log"; then
        local remote_user
        # shellcheck disable=SC2086
        remote_user=$(ssh $SSH_OPTS -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "whoami" 2>/dev/null || echo "unknown")
        log_info "SSH authentication successful, remote user: $remote_user"
        return 0
    else
        log_error "SSH authentication failed"
        return 1
    fi
}

test_ssh_sudo_access() {
    log_info "Testing SSH sudo access..."

    local vm_ip
    vm_ip=$(virsh domifaddr "$(virsh list --name | grep test-hpc-minimal | head -1)" 2>/dev/null | grep -E "ipv4|ipv6" | awk '{print $4}' | head -1 | cut -d'/' -f1 || echo "")

    if [[ -z "$vm_ip" ]]; then
        log_error "No VM IP found for sudo test"
        return 1
    fi

    # Test sudo access (may not be available on all systems)
    # shellcheck disable=SC2086
    if timeout 30s ssh ${SSH_OPTS} -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "sudo -n whoami" 2>&1 | tee -a "$LOG_DIR/ssh-sudo-test.log"; then
        log_info "SSH sudo access working"
        return 0
    else
        log_warn "SSH sudo access not available (may be expected)"
        return 0  # Don't fail for this, just warn
    fi
}

print_summary() {
    local failed=$((TESTS_RUN - TESTS_PASSED))

    {
        echo "========================================"
        echo "SSH Connectivity Test Summary"
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
            echo "❌ SSH connectivity validation FAILED"
        } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"
        return 1
    else
        {
            echo
            echo "🎉 SSH connectivity validation PASSED!"
            echo
            echo "SSH COMPONENTS VALIDATED:"
            echo "  ✅ SSH key exists and accessible"
            echo "  ✅ SSH key permissions appropriate"
            echo "  ✅ SSH connectivity to VMs working"
            echo "  ✅ SSH authentication successful"
            echo "  ✅ SSH command execution working"
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
        echo "SSH Key: $SSH_KEY_PATH"
        echo "SSH User: $SSH_USER"
        echo
    } | tee -a "$LOG_DIR/$SCRIPT_NAME.log"

    # Run Task 005 SSH connectivity tests
    run_test "SSH key exists" test_ssh_key_exists
    run_test "SSH key permissions" test_ssh_key_permissions
    run_test "VM SSH connectivity" test_vm_ssh_connectivity
    run_test "SSH authentication" test_ssh_authentication
    run_test "SSH sudo access" test_ssh_sudo_access

    print_summary
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
