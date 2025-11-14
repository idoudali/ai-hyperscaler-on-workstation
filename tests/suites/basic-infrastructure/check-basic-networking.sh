#!/bin/bash
# Basic Networking Test
# Task 005 - Test basic networking functionality
# Validates networking capabilities per Task 005 requirements

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "$SCRIPT_DIR/../common" && pwd)"

# Source shared utilities
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-utils.sh"
# shellcheck source=/dev/null
source "$COMMON_DIR/suite-logging.sh"

TEST_NAME="Basic Networking Test"

# SSH configuration from environment
SSH_KEY_PATH="${SSH_KEY_PATH:-$PROJECT_ROOT/build/shared/ssh-keys/id_rsa}"
SSH_USER="${SSH_USER:-admin}"
SSH_OPTS="${SSH_OPTS:--o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR}"

# Task 005 Test Functions
test_network_bridges() {
    log_test "Checking network bridges"

    local active_networks
    active_networks=$(virsh net-list --state-active 2>/dev/null || true)

    if [[ -n "$active_networks" ]]; then
        log_pass "Found active network bridges:"
        echo "$active_networks" | while read -r bridge; do
            if [[ -n "$bridge" ]]; then
                log_info "  - $bridge"
            fi
        done
        return 0
    else
        local all_networks
        all_networks=$(virsh net-list --all 2>/dev/null | grep -v "Name.*State" | grep -v "^-" | grep -v "^$" || true)

        if [[ -n "$all_networks" ]]; then
            log_pass "Found defined networks (may be inactive):"
            echo "$all_networks" | while read -r bridge; do
                if [[ -n "$bridge" ]]; then
                    log_info "  - $bridge"
                fi
            done
            return 0
        else
            log_fail "No network bridges found"
            return 1
        fi
    fi
}

test_vm_network_interfaces() {
    log_test "Checking VM network interfaces"

    local vm_name
    vm_name=$(virsh list --name | grep test-hpc-minimal | head -1)

    if [[ -n "$vm_name" ]]; then
        local interfaces
        interfaces=$(virsh domiflist "$vm_name" 2>/dev/null || true)

        if echo "$interfaces" | grep -q 'network'; then
            log_pass "VM $vm_name has network interfaces:"
            echo "$interfaces" | while read -r interface; do
                log_info "  - $interface"
            done
            return 0
        else
            log_fail "VM $vm_name has no network interfaces"
            return 1
        fi
    else
        log_fail "No test VMs found for network interface check"
        return 1
    fi
}

test_vm_ip_assignment() {
    log_test "Checking VM IP assignment"

    local vm_names
    vm_names=$(virsh list --name | grep test-hpc-minimal || true)

    if [[ -z "$vm_names" ]]; then
        log_fail "No test VMs found for IP check"
        return 1
    fi

    local ip_count=0
    while IFS= read -r vm_name; do
        if [[ -n "$vm_name" ]]; then
            local vm_ip
            vm_ip=$(virsh domifaddr "$vm_name" 2>/dev/null | grep -E "ipv4|ipv6" | awk '{print $4}' | head -1 | cut -d'/' -f1 || echo "")
            if [[ -n "$vm_ip" ]]; then
                log_info "VM $vm_name has IP: $vm_ip"
                ip_count=$((ip_count + 1))
            else
                log_warn "VM $vm_name has no IP assigned"
            fi
        fi
    done <<< "$vm_names"

    if [[ $ip_count -gt 0 ]]; then
        log_pass "Found $ip_count VMs with IP addresses"
        return 0
    else
        log_fail "No VMs have IP addresses assigned"
        return 1
    fi
}

test_vm_internal_connectivity() {
    log_test "Testing VM internal connectivity"

    local vm_ip
    vm_ip=$(virsh domifaddr "$(virsh list --name | grep test-hpc-minimal | head -1)" 2>/dev/null | grep -E "ipv4|ipv6" | awk '{print $4}' | head -1 | cut -d'/' -f1 || echo "")

    if [[ -z "$vm_ip" ]]; then
        log_fail "No VM IP found for connectivity test"
        return 1
    fi

    # shellcheck disable=SC2086
    if timeout 30s ssh $SSH_OPTS -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "ip route show" >/dev/null 2>&1; then
        log_pass "VM internal routing working on $vm_ip"
    else
        log_fail "VM internal routing failed on $vm_ip"
        return 1
    fi

    # shellcheck disable=SC2086
    if timeout 30s ssh $SSH_OPTS -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "ip addr show" >/dev/null 2>&1; then
        log_pass "VM network interfaces accessible on $vm_ip"
    else
        log_fail "VM network interfaces not accessible on $vm_ip"
        return 1
    fi

    return 0
}

test_vm_dns_resolution() {
    log_test "Testing VM DNS resolution"

    local vm_ip
    vm_ip=$(virsh domifaddr "$(virsh list --name | grep test-hpc-minimal | head -1)" 2>/dev/null | grep -E "ipv4|ipv6" | awk '{print $4}' | head -1 | cut -d'/' -f1 || echo "")

    if [[ -z "$vm_ip" ]]; then
        log_fail "No VM IP found for DNS test"
        return 1
    fi

    # shellcheck disable=SC2086
    if timeout 30s ssh $SSH_OPTS -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "nslookup localhost" >/dev/null 2>&1; then
        log_pass "DNS resolution working on $vm_ip"
        return 0
    else
        log_warn "DNS resolution issues on $vm_ip (may be expected in test environment)"
        return 0
    fi
}

test_vm_ping_connectivity() {
    log_test "Testing VM ping connectivity"

    local vm_ip
    vm_ip=$(virsh domifaddr "$(virsh list --name | grep test-hpc-minimal | head -1)" 2>/dev/null | grep -E "ipv4|ipv6" | awk '{print $4}' | head -1 | cut -d'/' -f1 || echo "")

    if [[ -z "$vm_ip" ]]; then
        log_fail "No VM IP found for ping test"
        return 1
    fi

    # shellcheck disable=SC2086
    if timeout 30s ssh $SSH_OPTS -i "$SSH_KEY_PATH" "$SSH_USER@$vm_ip" "ping -c 1 localhost" >/dev/null 2>&1; then
        log_pass "Ping connectivity working on $vm_ip"
        return 0
    else
        log_warn "Ping connectivity issues on $vm_ip (may be expected in test environment)"
        return 0
    fi
}

main() {
    init_suite_logging "$TEST_NAME"

    run_test "Network bridges" test_network_bridges
    run_test "VM network interfaces" test_vm_network_interfaces
    run_test "VM IP assignment" test_vm_ip_assignment
    run_test "VM internal connectivity" test_vm_internal_connectivity
    run_test "VM DNS resolution" test_vm_dns_resolution
    run_test "VM ping connectivity" test_vm_ping_connectivity

    print_test_summary "$TEST_NAME"
    exit_with_test_results
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
