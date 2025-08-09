#!/bin/bash
#
# check_prereqs.sh - A comprehensive system prerequisite checker for the Hyperscaler on a Workstation project.
#
# This script validates that the host system meets all the necessary requirements
# for running the virtualized HPC and Cloud environments. It checks for CPU
# virtualization, IOMMU, KVM, GPU drivers, and other critical components.
#
# The script is designed to be run in stages, allowing for granular checks of the system.
#
# Usage:
#   ./check_prereqs.sh [all|stage1|stage2|...]
#
# Stages:
#   all: Run all checks.
#   cpu: Check for CPU virtualization support (VT-x/AMD-V).
#   iommu: Check for IOMMU support (VT-d/AMD-Vi).
#   kvm: Check for KVM acceleration.
#   gpu: Check for NVIDIA GPU and driver status.
#   packages: Check for required software packages.
#   resources: Check for sufficient system resources (RAM, disk, CPU).
#

set -o errexit
set -o nounset
set -o pipefail

# ==============================================================================
# Global Variables and Utility Functions
# ==============================================================================

# Minimum resource requirements
readonly MIN_RAM_GB=32
readonly MIN_DISK_GB=500
readonly MIN_CPU_CORES=8

# Enable script tracing if TRACE is set to "1"
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

# Line numbering and error reporting
# ------------------------------------------------------------------------------
err_report() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} on line ${1} of $0"
}
trap 'err_report $LINENO' ERR

# Color codes
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# Logging functions
# ------------------------------------------------------------------------------
log() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

warn() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1"
}

fail() {
    echo -e "${COLOR_RED}[FAILURE]${COLOR_RESET} $1"
}

# ==============================================================================
# Prerequisite Check Functions
# ==============================================================================

# Stage 1: CPU Virtualization Check
# ------------------------------------------------------------------------------
check_cpu_virtualization() {
    log "Running CPU virtualization check..."
    if grep -q -E ' (vmx|svm) ' /proc/cpuinfo; then
        success "CPU virtualization is enabled (VT-x/AMD-V)."
    else
        fail "CPU virtualization is NOT enabled."
        warn "Please enable VT-x (for Intel) or AMD-V (for AMD) in your system's BIOS/UEFI settings."
        return 1
    fi
}

# Stage 2: IOMMU Check
# ------------------------------------------------------------------------------
check_iommu() {
    log "Running IOMMU check..."
    if dmesg | grep -q -e "DMAR: IOMMU enabled" -e "AMD-Vi: Enabled"; then
        success "IOMMU (VT-d/AMD-Vi) is enabled."
    else
        fail "IOMMU (VT-d/AMD-Vi) is NOT enabled or not found in kernel logs."
        warn "Please enable 'intel_iommu=on' or 'amd_iommu=on' in your kernel boot parameters."
        warn "You may also need to enable it in your system's BIOS/UEFI settings."
        return 1
    fi
}

# Stage 3: KVM Acceleration Check
# ------------------------------------------------------------------------------
check_kvm_acceleration() {
    log "Running KVM acceleration check..."
    if [ -e /dev/kvm ] && lsmod | grep -q kvm; then
        success "KVM acceleration is enabled and available."
    else
        fail "KVM acceleration is NOT available."
        warn "The /dev/kvm device does not exist or the kvm kernel module is not loaded."
        warn "Ensure that the 'kvm' and 'kvm_intel' (or 'kvm_amd') modules are loaded."
        return 1
    fi
}

# Stage 4: GPU and Driver Check
# ------------------------------------------------------------------------------
check_gpu_drivers() {
    log "Running GPU and driver check..."
    local return_code=0

    # Check if nouveau is blacklisted
    if grep -q "blacklist nouveau" /etc/modprobe.d/*; then
        success "Nouveau driver is blacklisted."
    else
        warn "Nouveau driver does not appear to be blacklisted. This may cause conflicts with NVIDIA drivers."
        warn "It is recommended to create a file in /etc/modprobe.d/ with 'blacklist nouveau' and 'options nouveau modeset=0'."
        return_code=1
    fi

    # Check for nvidia-smi
    if command -v nvidia-smi &> /dev/null; then
        success "nvidia-smi is found."
        if nvidia-smi &> /dev/null; then
            success "NVIDIA GPU is visible and nvidia-smi command works."
        else
            fail "nvidia-smi command failed to execute. The NVIDIA driver may not be loaded correctly."
            return_code=1
        fi
    else
        fail "nvidia-smi command not found."
        warn "Please ensure the NVIDIA driver is installed correctly and that nvidia-smi is in your PATH."
        return_code=1
    fi

    return ${return_code}
}

# Stage 5: Required Packages Check
# ------------------------------------------------------------------------------
check_packages() {
    log "Running required packages check..."
    local required_packages=(
        qemu-system-x86
        libvirt-daemon-system
        libvirt-clients
        bridge-utils
        virt-manager
        ebtables
        dnsmasq-base
    )
    local missing_packages=()

    for pkg in "${required_packages[@]}"; do
        if ! dpkg -s "${pkg}" &> /dev/null; then
            missing_packages+=("${pkg}")
        fi
    done

    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        success "All required packages are installed."
    else
        fail "The following required packages are missing: ${missing_packages[*]}"
        warn "Please install them by running:"
        echo "  sudo apt-get update && sudo apt-get install -y ${missing_packages[*]}"
        return 1
    fi
}

# Stage 6: System Resources Check
# ------------------------------------------------------------------------------
check_system_resources() {
    log "Running system resources check..."
    local return_code=0

    # Check RAM
    local total_ram_kb
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_gb=$((total_ram_kb / 1024 / 1024))
    if (( total_ram_gb < MIN_RAM_GB )); then
        fail "Insufficient RAM. Found ${total_ram_gb}GB, require ${MIN_RAM_GB}GB."
        return_code=1
    else
        success "Sufficient RAM available (${total_ram_gb}GB)."
    fi

    # Check Disk Space
    local available_disk_gb
    available_disk_gb=$(df -BG / | tail -n 1 | awk '{print $4}' | sed 's/G//')
    if (( available_disk_gb < MIN_DISK_GB )); then
        fail "Insufficient disk space. Found ${available_disk_gb}GB, require ${MIN_DISK_GB}GB."
        return_code=1
    else
        success "Sufficient disk space available (${available_disk_gb}GB)."
    fi

    # Check CPU Cores
    local cpu_cores
    cpu_cores=$(nproc)
    if (( cpu_cores < MIN_CPU_CORES )); then
        fail "Insufficient CPU cores. Found ${cpu_cores}, require ${MIN_CPU_CORES}."
        return_code=1
    else
        success "Sufficient CPU cores available (${cpu_cores})."
    fi

    return ${return_code}
}

# Stage 7: Conflicting Services Check
# ------------------------------------------------------------------------------
check_conflicting_services() {
    log "Running conflicting services check..."
    warn "This check is currently a placeholder. No specific conflicting services are being checked."
    # Future implementation could check for things like other running hypervisors (e.g., VirtualBox)
    # or services that might interfere with networking.
    success "Conflicting services check passed (placeholder)."
}

# Stage 8: User Group Membership Check
# ------------------------------------------------------------------------------
check_user_groups() {
    log "Running user group membership check..."
    local return_code=0
    local required_groups=("libvirt" "kvm")

    for group in "${required_groups[@]}"; do
        if getent group "${group}" | grep -q "\b$(whoami)\b"; then
            success "User $(whoami) is a member of the '${group}' group."
        else
            fail "User $(whoami) is NOT a member of the '${group}' group."
            warn "Please add the user to the group by running: 'sudo usermod -aG ${group} $(whoami)'"
            warn "You will need to log out and log back in for the changes to take effect."
            return_code=1
        fi
    done

    return ${return_code}
}

# ==============================================================================
# Main Execution Logic
# ==============================================================================

usage() {
    echo "Usage: $0 {all|cpu|iommu|kvm|gpu|packages|resources|conflicts|groups}"
    echo "  all: Run all prerequisite checks."
    echo "  cpu: Check for CPU virtualization support."
    echo "  iommu: Check for IOMMU support."
    echo "  kvm: Check for KVM acceleration."
    echo "  gpu: Check for NVIDIA GPU and driver status."
    echo "  packages: Check for required software packages."
    echo "  resources: Check for sufficient system resources."
    echo "  conflicts: Check for conflicting services."
    echo "  groups: Check for user group memberships (libvirt, kvm)."
    exit 1
}

main() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    local stage="$1"
    local failed_stages=()
    local all_stages=(
        "check_cpu_virtualization"
        "check_iommu"
        "check_kvm_acceleration"
        "check_gpu_drivers"
        "check_packages"
        "check_system_resources"
        "check_conflicting_services"
        "check_user_groups"
    )

    run_stage() {
        local func_name=$1
        if ! "${func_name}"; then
            failed_stages+=("${func_name#check_}")
        fi
    }

    case "${stage}" in
        all)
            log "Running all prerequisite checks..."
            for func in "${all_stages[@]}"; do
                run_stage "${func}"
            done
            ;;
        cpu) run_stage "check_cpu_virtualization" ;;
        iommu) run_stage "check_iommu" ;;
        kvm) run_stage "check_kvm_acceleration" ;;
        gpu) run_stage "check_gpu_drivers" ;;
        packages) run_stage "check_packages" ;;
        resources) run_stage "check_system_resources" ;;
        conflicts) run_stage "check_conflicting_services" ;;
        groups) run_stage "check_user_groups" ;;
        *) usage ;;
    esac

    echo # Add a newline for better formatting

    if [[ ${#failed_stages[@]} -gt 0 ]]; then
        fail "One or more prerequisite checks failed."
        log "Summary of failed stages: ${failed_stages[*]}"
        exit 1
    else
        success "All prerequisite checks passed successfully."
    fi
}

# Run the main function with all provided arguments
main "$@"
