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

# Enhanced error reporting function
# ------------------------------------------------------------------------------

# Global array to track executed commands
declare -a EXECUTED_COMMANDS=()

# Function to log and execute commands with tracking
execute_and_log() {
    local description="$1"
    local command="$2"
    local show_output="${3:-false}"

    EXECUTED_COMMANDS+=("${description}: ${command}")
    log "Executing: ${command}"

    if [[ "${show_output}" == "true" ]]; then
        eval "${command}"
    else
        eval "${command}" 2>/dev/null
    fi
}

# Enhanced failure reporting with comprehensive information
report_failure() {
    local check_name="$1"
    local failure_type="$2"  # "CRITICAL" or "WARNING"
    local primary_command="$3"
    local failure_reason="$4"
    local impact="$5"
    local resolution="$6"
    local additional_commands="${7:-}"

    if [[ "${failure_type}" == "CRITICAL" ]]; then
        fail "${check_name} check failed (CRITICAL)"
    else
        warn "${check_name} check failed (${failure_type})"
    fi

    echo "  ┌─ Failure Details:"
    echo "  │ Primary Command: ${primary_command}"
    if [[ -n "${additional_commands}" ]]; then
        echo "  │ Additional Commands: ${additional_commands}"
    fi
    echo "  │ Reason: ${failure_reason}"
    echo "  │ Impact: ${impact}"
    echo "  └─ Resolution: ${resolution}"
    echo

    # Show recent command history for this check
    if [[ ${#EXECUTED_COMMANDS[@]} -gt 0 ]]; then
        echo "  ┌─ Commands executed in this check:"
        local max_recent=5
        local start_idx=$((${#EXECUTED_COMMANDS[@]} - max_recent))
        [[ ${start_idx} -lt 0 ]] && start_idx=0

        for ((i=start_idx; i<${#EXECUTED_COMMANDS[@]}; i++)); do
            echo "  │ $((i+1)). ${EXECUTED_COMMANDS[i]}"
        done
        echo "  └─"
        echo
    fi
}

# Function to report successful checks with command info
report_success() {
    local check_name="$1"
    local primary_command="$2"
    local details="$3"

    success "${check_name}"
    if [[ -n "${primary_command}" ]]; then
        log "Primary command: ${primary_command}"
    fi
    if [[ -n "${details}" ]]; then
        log "${details}"
    fi
}

# Clear command history for new check
clear_command_history() {
    EXECUTED_COMMANDS=()
}

# ==============================================================================
# Prerequisite Check Functions
# ==============================================================================

# Stage 1: CPU Virtualization Check
# ------------------------------------------------------------------------------
check_cpu_virtualization() {
    log "Running CPU virtualization check..."
    clear_command_history

    # Check if /proc/cpuinfo exists and is readable
    execute_and_log "Check /proc/cpuinfo accessibility" "test -r /proc/cpuinfo"
    if [[ ! -r /proc/cpuinfo ]]; then
        report_failure \
            "CPU virtualization" \
            "CRITICAL" \
            "test -r /proc/cpuinfo" \
            "Cannot read /proc/cpuinfo - file does not exist or is not readable" \
            "CPU virtualization support cannot be determined, system prerequisite validation impossible" \
            "Check file permissions and ensure /proc filesystem is mounted:
   ls -la /proc/cpuinfo
   mount | grep proc" \
            "ls -la /proc/; mount | grep proc"
        return 1
    fi

    # Check for virtualization flags
    local vmx_count svm_count cpu_model
    execute_and_log "Count Intel VT-x flags" "grep -c vmx /proc/cpuinfo"
    vmx_count=$(grep -c "vmx" /proc/cpuinfo 2>/dev/null || echo "0")

    execute_and_log "Count AMD-V flags" "grep -c svm /proc/cpuinfo"
    svm_count=$(grep -c "svm" /proc/cpuinfo 2>/dev/null || echo "0")

    execute_and_log "Get CPU model" "grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs"
    cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs 2>/dev/null || echo "Unknown")

    if [[ ${vmx_count} -gt 0 ]]; then
        report_success \
            "CPU virtualization is enabled (Intel VT-x detected)" \
            "grep -c vmx /proc/cpuinfo" \
            "VT-x flags found in ${vmx_count} CPU core(s). CPU model: ${cpu_model}"
    elif [[ ${svm_count} -gt 0 ]]; then
        report_success \
            "CPU virtualization is enabled (AMD-V detected)" \
            "grep -c svm /proc/cpuinfo" \
            "AMD-V flags found in ${svm_count} CPU core(s). CPU model: ${cpu_model}"
    else
        # Additional diagnostic information
        local cpu_flags total_cores
        execute_and_log "Get CPU flags sample" "grep flags /proc/cpuinfo | head -1"
        cpu_flags=$(grep "flags" /proc/cpuinfo | head -1 | cut -d: -f2 | head -c 100 2>/dev/null || echo "unknown")

        execute_and_log "Count total CPU cores" "grep -c processor /proc/cpuinfo"
        total_cores=$(grep -c "processor" /proc/cpuinfo 2>/dev/null || echo "unknown")

        report_failure \
            "CPU virtualization" \
            "CRITICAL" \
            "grep -E '(vmx|svm)' /proc/cpuinfo" \
            "No virtualization flags (vmx/svm) found in /proc/cpuinfo for ${total_cores} CPU cores" \
            "Virtual machines will not be able to run with hardware acceleration, severely limiting performance" \
            "Enable hardware virtualization in BIOS/UEFI:
   1. Reboot and enter BIOS/UEFI setup (usually F2, F12, DEL during boot)
   2. Look for 'Virtualization Technology', 'VT-x', 'AMD-V', or 'SVM'
   3. Enable the setting
   4. Save and reboot

   CPU: ${cpu_model}
   Note: If option is not available, your CPU may not support virtualization" \
            "grep 'flags.*vmx\|flags.*svm' /proc/cpuinfo; dmesg | grep -i virtualization"

        log "CPU diagnostic information:"
        log "  ├─ CPU Model: ${cpu_model}"
        log "  ├─ Total cores: ${total_cores}"
        log "  └─ Sample flags: ${cpu_flags}..."

        return 1
    fi
}

# Stage 2: IOMMU Check
# ------------------------------------------------------------------------------
check_iommu() {
    log "Running IOMMU check..."

    # Check if /sys/kernel/iommu_groups exists
    if [[ ! -d /sys/kernel/iommu_groups ]]; then
        report_failure \
            "IOMMU" \
            "CRITICAL" \
            "check /sys/kernel/iommu_groups directory" \
            "IOMMU groups directory does not exist in sysfs" \
            "GPU passthrough and device isolation will not work" \
            "Enable IOMMU in kernel boot parameters with 'intel_iommu=on' or 'amd_iommu=on' and reboot" \
            "ls -la /sys/kernel/; dmesg | grep -i iommu"
        return 1
    fi

    # Count IOMMU groups
    local iommu_groups
    if ! iommu_groups=$(find /sys/kernel/iommu_groups -maxdepth 1 -type d -name '[0-9]*' 2>/dev/null | wc -l); then
        report_failure \
            "IOMMU" \
            "CRITICAL" \
            "find /sys/kernel/iommu_groups -maxdepth 1 -type d -name '[0-9]*' | wc -l" \
            "Failed to enumerate IOMMU groups" \
            "Cannot determine if IOMMU is properly configured" \
            "Check file permissions and ensure IOMMU is enabled in BIOS and kernel" \
            "ls -la /sys/kernel/iommu_groups/; find /sys/kernel/iommu_groups -maxdepth 1 -type d -name '[0-9]*'"
        return 1
    fi

    if [[ ${iommu_groups} -gt 0 ]]; then
        success "IOMMU is enabled and active (found ${iommu_groups} IOMMU groups)."
        log "Command used: find /sys/kernel/iommu_groups -maxdepth 1 -type d -name '[0-9]*' | wc -l"

        # Show example groups for verification
        log "Example IOMMU groups found:"
        local count=0
        for group in /sys/kernel/iommu_groups/*/; do
            if [[ ${count} -lt 3 && -d "${group}" ]]; then
                local group_num
                group_num=$(basename "${group}")
                local device_count
                if ! device_count=$(find "${group}devices" -type l 2>/dev/null | wc -l); then
                    device_count="unknown"
                fi
                log "  Group ${group_num}: ${device_count} device(s)"
                ((count++))
            fi
        done
        [[ ${iommu_groups} -gt 3 ]] && log "  ... and $((iommu_groups - 3)) more groups"

        return 0
    fi

    # Fallback check: Look in dmesg for IOMMU initialization messages
    log "IOMMU groups not found in sysfs, checking kernel logs as fallback..."
    local dmesg_output
    if ! dmesg_output=$(dmesg | grep -e "DMAR: IOMMU enabled" -e "AMD-Vi: Enabled" -e "IOMMU enabled" 2>/dev/null | head -3); then
        report_failure \
            "IOMMU" \
            "CRITICAL" \
            "dmesg | grep -e 'DMAR: IOMMU enabled' -e 'AMD-Vi: Enabled' -e 'IOMMU enabled'" \
            "No IOMMU initialization messages found in kernel logs" \
            "IOMMU is not enabled or not functioning properly" \
            "Enable IOMMU in BIOS/UEFI settings and add 'intel_iommu=on' or 'amd_iommu=on' to kernel boot parameters, then reboot" \
            "dmesg | grep -i iommu; dmesg | grep -i dmar; dmesg | grep -i amd-vi"
        return 1
    fi

    if [[ -n "${dmesg_output}" ]]; then
        warn "IOMMU appears to be enabled in kernel logs, but no IOMMU groups found."
        warn "This might indicate IOMMU is enabled but not functioning properly."
        log "IOMMU messages found in dmesg:"
        echo "${dmesg_output}" | while read -r line; do
            log "  ${line}"
        done
        return 1
    fi

    # No IOMMU detected
    report_failure \
        "IOMMU" \
        "CRITICAL" \
        "multiple IOMMU detection methods" \
        "IOMMU not found in sysfs, kernel logs, or dmesg output" \
        "GPU passthrough and device isolation will not work" \
        "Enable VT-d/AMD-Vi in BIOS/UEFI settings and add 'intel_iommu=on' or 'amd_iommu=on' to kernel boot parameters, then reboot" \
        "ls -la /sys/kernel/; dmesg | grep -i iommu; cat /proc/cmdline"
    return 1
}

# Stage 3: KVM Acceleration Check
# ------------------------------------------------------------------------------
check_kvm_acceleration() {
    log "Running KVM acceleration check..."

    # Check if /dev/kvm exists
    if [[ ! -e /dev/kvm ]]; then
        report_failure \
            "KVM acceleration" \
            "CRITICAL" \
            "check /dev/kvm device" \
            "The /dev/kvm device does not exist" \
            "Virtual machines will not be able to use hardware acceleration" \
            "Load KVM kernel modules with 'sudo modprobe kvm kvm_intel' (Intel) or 'sudo modprobe kvm kvm_amd' (AMD)" \
            "ls -la /dev/kvm; lsmod | grep kvm"
        return 1
    fi

    # Check if /dev/kvm is readable and writable by the user
    if [[ ! -r /dev/kvm ]] || [[ ! -w /dev/kvm ]]; then
        report_failure \
            "KVM acceleration" \
            "CRITICAL" \
            "check /dev/kvm permissions" \
            "The /dev/kvm device exists but is not readable/writable by current user" \
            "Virtual machines will not be able to use KVM acceleration" \
            "Add user to kvm group with 'sudo usermod -aG kvm $(whoami)' and ensure /dev/kvm has correct permissions (0666)" \
            "ls -la /dev/kvm; groups $(whoami); getent group kvm"
        return 1
    fi

    # Check if KVM kernel module is loaded
    local kvm_module_count
    if ! kvm_module_count=$(lsmod | grep -c "^kvm" 2>/dev/null); then
        report_failure \
            "KVM acceleration" \
            "CRITICAL" \
            "lsmod | grep -c '^kvm'" \
            "Failed to check KVM kernel modules" \
            "Cannot determine if KVM modules are loaded" \
            "Check if lsmod command is available and try loading KVM modules manually" \
            "which lsmod; lsmod | head -5"
        return 1
    fi

    if [[ ${kvm_module_count} -eq 0 ]]; then
        report_failure \
            "KVM acceleration" \
            "CRITICAL" \
            "lsmod | grep '^kvm'" \
            "No KVM kernel modules are loaded" \
            "Virtual machines will not be able to use hardware acceleration" \
            "Load KVM modules with 'sudo modprobe kvm kvm_intel' (Intel) or 'sudo modprobe kvm kvm_amd' (AMD)" \
            "lsmod | grep kvm; modprobe -l | grep kvm"
        return 1
    fi

    # Check for specific KVM vendor module
    local vendor_module
    if grep -q "vmx" /proc/cpuinfo 2>/dev/null; then
        vendor_module="kvm_intel"
    elif grep -q "svm" /proc/cpuinfo 2>/dev/null; then
        vendor_module="kvm_amd"
    else
        vendor_module="unknown"
    fi

    if [[ "${vendor_module}" != "unknown" ]] && ! lsmod | grep -q "^${vendor_module}"; then
        warn "KVM base module is loaded, but vendor-specific module (${vendor_module}) is not loaded."
        warn "Command used: lsmod | grep '^${vendor_module}'"
        warn "This may cause performance issues or prevent KVM from working properly."
        warn "Load the vendor module with: sudo modprobe ${vendor_module}"
    fi

    success "KVM acceleration is enabled and available."
    log "Command used: lsmod | grep '^kvm'"
    log "KVM modules found: $(lsmod | grep '^kvm' | awk '{print $1}' | tr '\n' ' ')"
}

# Stage 4: GPU and Driver Check
# ------------------------------------------------------------------------------
check_gpu_drivers() {
    log "Running GPU and driver check..."
    clear_command_history
    local return_code=0
    local critical_failure=false
    local warning_issues=false

    # Step 1: Check if nouveau driver is properly blacklisted
    log "Step 1/4: Checking nouveau driver blacklist status..."
    local nouveau_blacklist_files
    execute_and_log "Check nouveau blacklist" "grep -l 'blacklist nouveau' /etc/modprobe.d/* 2>/dev/null || true"
    nouveau_blacklist_files=$(grep -l "blacklist nouveau" /etc/modprobe.d/* 2>/dev/null || true)

    # Also check for nouveau options
    local nouveau_options_files
    execute_and_log "Check nouveau options" "grep -l 'options nouveau modeset=0' /etc/modprobe.d/* 2>/dev/null || true"
    nouveau_options_files=$(grep -l "options nouveau modeset=0" /etc/modprobe.d/* 2>/dev/null || true)

    if [[ -n "${nouveau_blacklist_files}" && -n "${nouveau_options_files}" ]]; then
        report_success "Nouveau driver properly blacklisted" "grep -l 'blacklist nouveau' /etc/modprobe.d/*" "Found in: ${nouveau_blacklist_files}"
    elif [[ -n "${nouveau_blacklist_files}" ]]; then
        warn "Nouveau driver is blacklisted but 'options nouveau modeset=0' not found."
        warn "This may still cause conflicts. Consider adding 'options nouveau modeset=0' to ${nouveau_blacklist_files}"
        warning_issues=true
    else
        report_failure \
            "Nouveau driver blacklist" \
            "WARNING" \
            "grep -l 'blacklist nouveau' /etc/modprobe.d/*" \
            "Nouveau driver is not blacklisted, which may cause conflicts with NVIDIA proprietary drivers" \
            "This can prevent NVIDIA drivers from loading properly or cause system instability" \
            "Create /etc/modprobe.d/blacklist-nouveau.conf with contents:
     blacklist nouveau
     options nouveau modeset=0
   Then run: sudo update-initramfs -u && sudo reboot" \
            "grep -l 'options nouveau modeset=0' /etc/modprobe.d/*"
        warning_issues=true
    fi

    # Step 2: Check if NVIDIA driver packages are installed
    log "Step 2/4: Checking NVIDIA driver installation..."
    local nvidia_packages
    execute_and_log "Check NVIDIA packages" "dpkg -l | grep -E 'nvidia-driver|nvidia-kernel-source' || true"
    nvidia_packages=$(dpkg -l | grep -E 'nvidia-driver|nvidia-kernel-source' || true)

    if [[ -n "${nvidia_packages}" ]]; then
        log "NVIDIA driver packages found:"
        echo "${nvidia_packages}" | while read -r line; do
            log "  ${line}"
        done
    else
        report_failure \
            "NVIDIA driver packages" \
            "CRITICAL" \
            "dpkg -l | grep -E 'nvidia-driver|nvidia-kernel-source'" \
            "No NVIDIA driver packages are installed on the system" \
            "GPU acceleration and compute workloads will not function" \
            "Install NVIDIA drivers:
   # For automatic driver selection:
   sudo ubuntu-drivers autoinstall

   # Or manually install specific version:
   sudo apt update
   sudo apt install nvidia-driver-550

   # Then reboot:
   sudo reboot"
        critical_failure=true
        return_code=1
    fi

    # Step 3: Check for nvidia-smi command availability
    log "Step 3/4: Checking nvidia-smi command availability..."
    local nvidia_smi_path
    execute_and_log "Check nvidia-smi availability" "command -v nvidia-smi"
    if ! nvidia_smi_path=$(command -v nvidia-smi 2>/dev/null); then
        report_failure \
            "nvidia-smi command" \
            "CRITICAL" \
            "command -v nvidia-smi" \
            "nvidia-smi command not found in PATH" \
            "Cannot verify NVIDIA driver status or manage GPU resources" \
            "Ensure NVIDIA drivers are properly installed:
   # Check if drivers are installed:
   dpkg -l | grep nvidia-driver

   # If installed but nvidia-smi missing, reinstall:
   sudo apt remove --purge nvidia-*
   sudo apt autoremove
   sudo ubuntu-drivers autoinstall
   sudo reboot" \
            "which nvidia-smi; echo \$PATH"
        critical_failure=true
        return_code=1
        return ${return_code}
    else
        report_success "nvidia-smi command found" "command -v nvidia-smi" "Located at: ${nvidia_smi_path}"
    fi

    # Step 4: Test nvidia-smi execution and GPU detection
    log "Step 4/4: Testing nvidia-smi execution and GPU detection..."
    local nvidia_smi_output nvidia_smi_exit_code
    execute_and_log "Execute nvidia-smi" "nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader,nounits"

    if nvidia_smi_output=$(nvidia-smi 2>&1); then
        nvidia_smi_exit_code=0
    else
        nvidia_smi_exit_code=$?
        nvidia_smi_output=$(nvidia-smi 2>&1 || true)
    fi

    if [[ ${nvidia_smi_exit_code} -eq 0 ]]; then
        report_success "NVIDIA GPU detection and driver test" "nvidia-smi" "GPU is accessible and driver is functional"

        # Extract and display key information
        local gpu_count driver_version
        execute_and_log "Count GPUs" "nvidia-smi --list-gpus | wc -l"
        gpu_count=$(nvidia-smi --list-gpus 2>/dev/null | wc -l || echo "unknown")

        execute_and_log "Get driver version" "nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1"
        driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "unknown")

        log "GPU Details:"
        log "  ├─ GPUs detected: ${gpu_count}"
        log "  ├─ Driver version: ${driver_version}"
        log "  └─ nvidia-smi output preview:"
        echo "${nvidia_smi_output}" | head -3 | while read -r line; do
            log "     ${line}"
        done

    else
        # Analyze common nvidia-smi failure scenarios
        local failure_analysis=""
        local suggested_fix=""

        if echo "${nvidia_smi_output}" | grep -q "NVIDIA-SMI has failed"; then
            failure_analysis="nvidia-smi failed to communicate with NVIDIA driver"
            suggested_fix="Driver may not be loaded. Try:
   # Check if driver is loaded:
   lsmod | grep nvidia

   # If no output, try loading manually:
   sudo modprobe nvidia

   # If that fails, reinstall drivers:
   sudo ubuntu-drivers autoinstall
   sudo reboot"
        elif echo "${nvidia_smi_output}" | grep -q "No devices were found"; then
            failure_analysis="No NVIDIA GPUs detected by the driver"
            suggested_fix="Check hardware and BIOS settings:
   # Verify GPU is detected by system:
   lspci | grep -i nvidia

   # Check if GPU is disabled in BIOS
   # Enable 'Discrete Graphics' in BIOS

   # Check if nouveau is conflicting:
   lsmod | grep nouveau"
        elif echo "${nvidia_smi_output}" | grep -q "command not found"; then
            failure_analysis="nvidia-smi command not found despite being in PATH"
            suggested_fix="Reinstall NVIDIA drivers completely:
   sudo apt remove --purge nvidia-*
   sudo apt autoremove
   sudo ubuntu-drivers autoinstall
   sudo reboot"
        else
            failure_analysis="nvidia-smi execution failed with unexpected error"
            suggested_fix="General troubleshooting steps:
   # Check system logs:
   dmesg | grep -i nvidia
   journalctl -u nvidia-persistenced

   # Verify driver integrity:
   nvidia-modprobe -v

   # Last resort - complete reinstall:
   sudo ubuntu-drivers autoinstall"
        fi

        report_failure \
            "nvidia-smi execution" \
            "CRITICAL" \
            "nvidia-smi" \
            "${failure_analysis}. Exit code: ${nvidia_smi_exit_code}" \
            "GPU compute workloads and virtualization will not function" \
            "${suggested_fix}" \
            "lsmod | grep nvidia; dmesg | tail -20 | grep -i nvidia"

        log "Full nvidia-smi error output:"
        echo "${nvidia_smi_output}" | while read -r line; do
            log "  ${line}"
        done

        critical_failure=true
        return_code=1
    fi

    # Summary based on failure type
    if [[ ${critical_failure} == true ]]; then
        fail "GPU drivers check completed with CRITICAL failures that must be resolved."
        return 1
    elif [[ ${warning_issues} == true ]]; then
        warn "GPU drivers check completed with warnings. System may work but with reduced reliability."
        return 2  # Use exit code 2 for warnings to distinguish from critical failures
    else
        success "GPU drivers check completed successfully. All components are functional."
        return 0
    fi
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
        # Python development dependencies
        python3-dev
        python3-pip
        python3-venv
        # libvirt development libraries needed by libvirt-python
        libvirt-dev
        pkg-config
        # Additional build dependencies for Python packages
        build-essential
        python3-setuptools
        python3-wheel
    )
    local missing_packages=()
    local package_check_errors=()

    for pkg in "${required_packages[@]}"; do
        local package_status
        if ! package_status=$(dpkg -s "${pkg}" 2>&1); then
            if echo "${package_status}" | grep -q "is not installed"; then
                missing_packages+=("${pkg}")
            else
                package_check_errors+=("${pkg}: ${package_status}")
            fi
        fi
    done

    if [[ ${#missing_packages[@]} -eq 0 && ${#package_check_errors[@]} -eq 0 ]]; then
        success "All required packages are installed."
        log "Command used: dpkg -s <package_name> for each package"
    else
        if [[ ${#missing_packages[@]} -gt 0 ]]; then
            fail "The following required packages are missing: ${missing_packages[*]}"
            echo "  Command used: dpkg -s <package_name>"
            echo "  Resolution: Install missing packages with:"
            echo "    sudo apt-get update && sudo apt-get install -y ${missing_packages[*]}"
        fi

        if [[ ${#package_check_errors[@]} -gt 0 ]]; then
            fail "The following package checks failed:"
            for error in "${package_check_errors[@]}"; do
                echo "  ${error}"
            done
            echo "  Command used: dpkg -s <package_name>"
            echo "  Resolution: Check package database integrity with 'sudo dpkg --configure -a'"
        fi

        return 1
    fi
}

# Stage 5.5: Python Library Dependencies Check
# ------------------------------------------------------------------------------
check_python_dependencies() {
    log "Running Python library dependencies check..."
    local return_code=0
    local critical_failure=false

    # Check if Python 3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        report_failure \
            "Python 3" \
            "CRITICAL" \
            "command -v python3" \
            "Python 3 is not installed or not in PATH" \
            "Python-based tools and libraries cannot function" \
            "Install Python 3 with: sudo apt-get install python3 python3-pip python3-venv" \
            "which python3; python3 --version"
        critical_failure=true
        return_code=1
    else
        local python_version
        python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        success "Python 3 is available (version: ${python_version})"
        log "Command used: python3 --version"
    fi

    # Check if pip is available
    if ! command -v pip3 >/dev/null 2>&1; then
        report_failure \
            "pip3" \
            "CRITICAL" \
            "command -v pip3" \
            "pip3 is not installed or not in PATH" \
            "Cannot install Python packages" \
            "Install pip3 with: sudo apt-get install python3-pip" \
            "which pip3; pip3 --version"
        critical_failure=true
        return_code=1
    else
        local pip_version
        pip_version=$(pip3 --version 2>&1 | cut -d' ' -f2)
        success "pip3 is available (version: ${pip_version})"
        log "Command used: pip3 --version"
    fi

    # Check if virtual environment can be created
    if ! python3 -m venv --help >/dev/null 2>&1; then
        report_failure \
            "Python venv module" \
            "CRITICAL" \
            "python3 -m venv --help" \
            "Python venv module is not available" \
            "Cannot create isolated Python environments" \
            "Install python3-venv with: sudo apt-get install python3-venv" \
            "python3 -m venv --help; dpkg -l | grep python3-venv"
        critical_failure=true
        return_code=1
    else
        success "Python venv module is available"
        log "Command used: python3 -m venv --help"
    fi

    # Check if build tools are available
    if ! command -v gcc >/dev/null 2>&1; then
        report_failure \
            "GCC compiler" \
            "CRITICAL" \
            "command -v gcc" \
            "GCC compiler is not available" \
            "Cannot compile Python packages with C extensions" \
            "Install build tools with: sudo apt-get install build-essential" \
            "which gcc; gcc --version"
        critical_failure=true
        return_code=1
    else
        local gcc_version
        gcc_version=$(gcc --version 2>&1 | head -1 | cut -d' ' -f3)
        success "GCC compiler is available (version: ${gcc_version})"
        log "Command used: gcc --version"
    fi

    # Check if setuptools and wheel are available
    if ! python3 -c "import setuptools" 2>/dev/null; then
        report_failure \
            "Python setuptools" \
            "CRITICAL" \
            "python3 -c 'import setuptools'" \
            "Python setuptools is not available" \
            "Cannot build or install Python packages" \
            "Install setuptools with: sudo apt-get install python3-setuptools" \
            "python3 -c 'import setuptools'; dpkg -l | grep python3-setuptools"
        critical_failure=true
        return_code=1
    else
        success "Python setuptools is available"
        log "Command used: python3 -c 'import setuptools'"
    fi

    # Check if libvirt development libraries are properly installed
    log "Checking libvirt development libraries for Python bindings..."

    # Check if pkg-config can find libvirt
    if ! pkg-config --exists libvirt; then
        report_failure \
            "libvirt pkg-config" \
            "CRITICAL" \
            "pkg-config --exists libvirt" \
            "pkg-config cannot find libvirt development files" \
            "Python libvirt-python package cannot be installed or compiled" \
            "Install libvirt development package: sudo apt-get install libvirt-dev" \
            "pkg-config --libs-only-L libvirt; dpkg -l | grep libvirt-dev"
        critical_failure=true
        return_code=1
    else
        success "libvirt pkg-config configuration is available"
        log "Command used: pkg-config --exists libvirt"

        # Show libvirt configuration details
        local libvirt_cflags libvirt_libs
        libvirt_cflags=$(pkg-config --cflags libvirt 2>/dev/null || echo "unknown")
        libvirt_libs=$(pkg-config --libs libvirt 2>/dev/null || echo "unknown")

        log "libvirt configuration details:"
        log "  ├─ CFLAGS: ${libvirt_cflags}"
        log "  └─ LIBS: ${libvirt_libs}"
    fi

    # Check if libvirt headers are available
    if [[ ! -f /usr/include/libvirt/libvirt.h ]]; then
        report_failure \
            "libvirt headers" \
            "CRITICAL" \
            "check /usr/include/libvirt/libvirt.h" \
            "libvirt header files are not installed" \
            "Python libvirt-python package cannot be compiled" \
            "Install libvirt development package: sudo apt-get install libvirt-dev" \
            "ls -la /usr/include/libvirt/; dpkg -l | grep libvirt-dev"
        critical_failure=true
        return_code=1
    else
        success "libvirt header files are available"
        log "Command used: check /usr/include/libvirt/libvirt.h"
    fi

    # Test if libvirt-python can be imported (if already installed)
    if python3 -c "import libvirt" 2>/dev/null; then
        success "libvirt-python is already installed and importable"
        log "Command used: python3 -c 'import libvirt'"

        # Get version information
        local libvirt_version
        if libvirt_version=$(python3 -c "import libvirt; print(libvirt.__version__)" 2>/dev/null); then
            log "libvirt-python version: ${libvirt_version}"
        fi
    else
        log "libvirt-python is not yet installed (this is expected for fresh systems)"
        log "Command used: python3 -c 'import libvirt'"
        log "Note: This will be installed when setting up the Python environment"
    fi

    # Summary
    if [[ ${critical_failure} == true ]]; then
        fail "Python dependencies check completed with CRITICAL failures that must be resolved."
        return 1
    else
        success "Python dependencies check completed successfully. All components are functional."
        return 0
    fi
}

# Stage 6: System Resources Check
# ------------------------------------------------------------------------------
check_system_resources() {
    log "Running system resources check..."
    local return_code=0

    # Check RAM
    local total_ram_kb
    if ! total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}' 2>/dev/null); then
        report_failure \
            "System RAM" \
            "CRITICAL" \
            "grep MemTotal /proc/meminfo | awk '{print \$2}'" \
            "Failed to read total RAM from /proc/meminfo" \
            "Cannot determine if system has sufficient memory" \
            "Check if /proc/meminfo is readable and contains MemTotal line" \
            "ls -la /proc/meminfo; head -5 /proc/meminfo"
        return_code=1
    else
        local total_ram_gb=$((total_ram_kb / 1024 / 1024))
        if (( total_ram_gb < MIN_RAM_GB )); then
            fail "Insufficient RAM. Found ${total_ram_gb}GB, require ${MIN_RAM_GB}GB."
            echo "  Command used: grep MemTotal /proc/meminfo | awk '{print \$2}'"
            echo "  Impact: Virtual machines may not have enough memory to run properly"
            echo "  Resolution: Upgrade system RAM to at least ${MIN_RAM_GB}GB"
            return_code=1
        else
            success "Sufficient RAM available (${total_ram_gb}GB)."
            log "Command used: grep MemTotal /proc/meminfo | awk '{print \$2}'"
        fi
    fi

    # Check Disk Space
    local available_disk_gb
    if ! available_disk_gb=$(df -BG / | tail -n 1 | awk '{print $4}' | sed 's/G//' 2>/dev/null); then
        report_failure \
            "Disk space" \
            "CRITICAL" \
            "df -BG / | tail -n 1 | awk '{print \$4}' | sed 's/G//'" \
            "Failed to determine available disk space" \
            "Cannot determine if system has sufficient storage" \
            "Check if df command is available and root filesystem is accessible" \
            "which df; df -h /"
        return_code=1
    else
        if (( available_disk_gb < MIN_DISK_GB )); then
            fail "Insufficient disk space. Found ${available_disk_gb}GB, require ${MIN_DISK_GB}GB."
            echo "  Command used: df -BG / | tail -n 1 | awk '{print \$4}' | sed 's/G//'"
            echo "  Impact: Virtual machine images and data may not fit on disk"
            echo "  Resolution: Free up disk space or expand storage to at least ${MIN_DISK_GB}GB"
            return_code=1
        else
            success "Sufficient disk space available (${available_disk_gb}GB)."
            log "Command used: df -BG / | tail -n 1 | awk '{print \$4}' | sed 's/G//'"
        fi
    fi

    # Check CPU Cores
    local cpu_cores
    if ! cpu_cores=$(nproc 2>/dev/null); then
        report_failure \
            "CPU cores" \
            "CRITICAL" \
            "nproc" \
            "Failed to determine number of CPU cores" \
            "Cannot determine if system has sufficient processing power" \
            "Check if nproc command is available or use 'grep -c processor /proc/cpuinfo' as alternative" \
            "which nproc; grep -c processor /proc/cpuinfo"
        return_code=1
    else
        if (( cpu_cores < MIN_CPU_CORES )); then
            fail "Insufficient CPU cores. Found ${cpu_cores}, require ${MIN_CPU_CORES}."
            echo "  Command used: nproc"
            echo "  Impact: Virtual machines may not have enough CPU resources to run efficiently"
            echo "  Resolution: Use a system with at least ${MIN_CPU_CORES} CPU cores"
            return_code=1
        else
            success "Sufficient CPU cores available (${cpu_cores})."
            log "Command used: nproc"
        fi
    fi

    return ${return_code}
}

# Stage 7: Conflicting Services Check
# ------------------------------------------------------------------------------
check_conflicting_services() {
    log "Running conflicting services check..."

    # Check for running VirtualBox processes
    local virtualbox_processes
    if virtualbox_processes=$(pgrep -f "VBoxHeadless\|VBoxSVC\|VirtualBox" 2>/dev/null | tr '\n' ' '); then
        if [[ -n "${virtualbox_processes}" ]]; then
            warn "VirtualBox processes detected: ${virtualbox_processes}"
            warn "Command used: pgrep -f 'VBoxHeadless\|VBoxSVC\|VirtualBox'"
            warn "VirtualBox may conflict with KVM. Consider stopping VirtualBox services before running KVM VMs."
            warn "Resolution: Stop VirtualBox with 'sudo systemctl stop virtualbox' or kill processes manually"
        fi
    else
        log "No VirtualBox processes detected."
        log "Command used: pgrep -f 'VBoxHeadless\|VBoxSVC\|VirtualBox'"
    fi

    # Check for Docker daemon (may use different virtualization)
    if systemctl is-active --quiet docker 2>/dev/null; then
        log "Docker daemon is running."
        log "Command used: systemctl is-active docker"
        log "Note: Docker may use different virtualization technology but should not conflict with KVM."
    fi

    success "Conflicting services check completed."
}

# Stage 8: User Group Membership Check
# ------------------------------------------------------------------------------
check_user_groups() {
    log "Running user group membership check..."
    local return_code=0
    local required_groups=("libvirt" "kvm")
    local current_user
    current_user=$(whoami)

    for group in "${required_groups[@]}"; do
        local group_members
        if ! group_members=$(getent group "${group}" 2>/dev/null); then
            report_failure \
                "User group membership" \
                "getent group ${group}" \
                "Failed to check group '${group}' - group may not exist" \
                "Cannot determine if user is member of required group" \
                "Create the group with 'sudo groupadd ${group}' if it doesn't exist"
            return_code=1
            continue
        fi

        if echo "${group_members}" | grep -q "\b${current_user}\b"; then
            success "User ${current_user} is a member of the '${group}' group."
            log "Command used: getent group ${group}"
        else
            fail "User ${current_user} is NOT a member of the '${group}' group."
            echo "  Command used: getent group ${group}"
            echo "  Group members: ${group_members}"
            echo "  Impact: User may not have permission to manage virtual machines or access KVM devices"
            echo "  Resolution: Add user to group with 'sudo usermod -aG ${group} ${current_user}'"
            echo "  Note: You will need to log out and log back in for the changes to take effect"
            return_code=1
        fi
    done

    return ${return_code}
}

# ==============================================================================
# Main Execution Logic
# ==============================================================================

usage() {
    echo "Usage: $0 {all|cpu|iommu|kvm|gpu|packages|python-deps|resources|conflicts|groups}"
    echo "  all: Run all prerequisite checks."
    echo "  cpu: Check for CPU virtualization support."
    echo "  iommu: Check for IOMMU support."
    echo "  kvm: Check for KVM acceleration."
    echo "  gpu: Check for NVIDIA GPU and driver status."
    echo "  packages: Check for required software packages."
    echo "  python-deps: Check for Python library dependencies."
    echo "  resources: Check for sufficient system resources (RAM, disk, CPU)."
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
    local warning_stages=()
    local success_stages=()
    local critical_failures=()
    local all_stages=(
        "check_cpu_virtualization"
        "check_iommu"
        "check_kvm_acceleration"
        "check_gpu_drivers"
        "check_packages"
        "check_python_dependencies"
        "check_system_resources"
        "check_conflicting_services"
        "check_user_groups"
    )

    # Map function names to human-readable names
    declare -A stage_names=(
        ["check_cpu_virtualization"]="CPU Virtualization"
        ["check_iommu"]="IOMMU Support"
        ["check_kvm_acceleration"]="KVM Acceleration"
        ["check_gpu_drivers"]="GPU Drivers"
        ["check_packages"]="Required Packages"
        ["check_python_dependencies"]="Python Dependencies"
        ["check_system_resources"]="System Resources"
        ["check_conflicting_services"]="Conflicting Services"
        ["check_user_groups"]="User Group Membership"
    )

    run_stage() {
        local func_name=$1
        local stage_short_name="${func_name#check_}"
        local stage_display_name="${stage_names[$func_name]}"

        echo "════════════════════════════════════════════════════════════════════════════════"
        log "Starting ${stage_display_name} Check"
        echo "════════════════════════════════════════════════════════════════════════════════"

        # Capture both return code and any output
        set +e  # Temporarily disable errexit to capture return codes properly
        "${func_name}"
        local stage_result=$?
        set -e  # Re-enable errexit

        # Categorize the result based on exit code
        if [[ ${stage_result} -eq 0 ]]; then
            success_stages+=("${stage_short_name}")
        elif [[ ${stage_result} -eq 1 ]]; then
            # Critical failure (exit code 1)
            critical_failures+=("${stage_short_name}")
            failed_stages+=("${stage_short_name}")
        elif [[ ${stage_result} -eq 2 ]]; then
            # Warning (exit code 2)
            warning_stages+=("${stage_short_name}")
            failed_stages+=("${stage_short_name}")
        else
            # Any other non-zero exit code is treated as critical
            critical_failures+=("${stage_short_name}")
            failed_stages+=("${stage_short_name}")
        fi

        echo # Add spacing between checks
    }

    # Execute the appropriate checks
    case "${stage}" in
        all)
            log "Starting comprehensive prerequisite validation for Hyperscaler on Workstation..."
            log "This will check all system requirements for virtualization, GPU support, and dependencies."
            echo

            for func in "${all_stages[@]}"; do
                run_stage "${func}"
            done
            ;;
        cpu) run_stage "check_cpu_virtualization" ;;
        iommu) run_stage "check_iommu" ;;
        kvm) run_stage "check_kvm_acceleration" ;;
        gpu) run_stage "check_gpu_drivers" ;;
        packages) run_stage "check_packages" ;;
        python-deps) run_stage "check_python_dependencies" ;;
        resources) run_stage "check_system_resources" ;;
        conflicts) run_stage "check_conflicting_services" ;;
        groups) run_stage "check_user_groups" ;;
        *) usage ;;
    esac

    # Comprehensive final summary
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "                                  FINAL SUMMARY"
    echo "════════════════════════════════════════════════════════════════════════════════"

    # Show overall status
    local total_checks=$((${#success_stages[@]} + ${#failed_stages[@]}))
    echo
    log "Check Results Overview:"
    echo "  ├─ Total checks performed: ${total_checks}"
    echo "  ├─ Successful checks: ${#success_stages[@]}"
    echo "  ├─ Failed checks: ${#failed_stages[@]}"
    echo "  │  ├─ Critical failures: ${#critical_failures[@]}"
    echo "  │  └─ Warnings: ${#warning_stages[@]}"
    echo "  └─ Success rate: $(( ${#success_stages[@]} * 100 / total_checks ))%"
    echo

    # List successful checks
    if [[ ${#success_stages[@]} -gt 0 ]]; then
        success "Successful checks:"
        for stage_name in "${success_stages[@]}"; do
            echo "  ✓ ${stage_name}"
        done
        echo
    fi

    # Handle failures with detailed breakdown
    if [[ ${#failed_stages[@]} -gt 0 ]]; then
        if [[ ${#critical_failures[@]} -gt 0 ]]; then
            fail "CRITICAL failures detected - system will not function properly:"
            for stage_name in "${critical_failures[@]}"; do
                echo "  ✗ ${stage_name} (CRITICAL)"
            done
            echo
            echo "  Impact: These failures prevent core functionality and must be resolved."
            echo "  Action Required: Address critical failures before proceeding with deployment."
        fi

        if [[ ${#warning_stages[@]} -gt 0 ]]; then
            warn "Warnings detected - system may work with reduced functionality:"
            for stage_name in "${warning_stages[@]}"; do
                echo "  ⚠ ${stage_name} (WARNING)"
            done
            echo
            echo "  Impact: System may function but with degraded performance or reliability."
            echo "  Recommendation: Address warnings for optimal operation."
        fi

        echo
        echo "Troubleshooting Information:"
        echo "┌─ For detailed failure analysis, run individual checks:"
        for stage_name in "${failed_stages[@]}"; do
            echo "│   $0 ${stage_name}"
        done
        echo "└─ Each command will provide specific diagnostics and resolution steps."
        echo

        # Show total commands executed if available
        if [[ ${#EXECUTED_COMMANDS[@]} -gt 0 ]]; then
            log "Total diagnostic commands executed: ${#EXECUTED_COMMANDS[@]}"
            echo "Most recent commands:"
            local max_show=10
            local start_idx=$((${#EXECUTED_COMMANDS[@]} - max_show))
            [[ ${start_idx} -lt 0 ]] && start_idx=0

            for ((i=start_idx; i<${#EXECUTED_COMMANDS[@]}; i++)); do
                echo "  $((i+1)). ${EXECUTED_COMMANDS[i]}"
            done
        fi

        if [[ ${#critical_failures[@]} -gt 0 ]]; then
            echo
            fail "System prerequisite validation FAILED with critical issues."
            echo "Cannot proceed with Hyperscaler deployment until critical failures are resolved."
            exit 1
        else
            echo
            warn "System prerequisite validation completed with WARNINGS."
            echo "System may work but addressing warnings is recommended for optimal performance."
            exit 2
        fi
    else
        echo
        success "All prerequisite checks passed successfully!"
        echo
        echo "✓ System Requirements Summary:"
        echo "  ├─ CPU virtualization: Enabled and functional"
        echo "  ├─ IOMMU support: Available for GPU passthrough"
        echo "  ├─ KVM acceleration: Ready for high-performance VMs"
        echo "  ├─ GPU drivers: Installed and operational"
        echo "  ├─ Required packages: All dependencies satisfied"
        echo "  ├─ Python dependencies: All libraries and tools available"
        echo "  ├─ System resources: Sufficient for workloads"
        echo "  ├─ Service conflicts: None detected"
        echo "  └─ User permissions: Properly configured"
        echo
        success "System is ready for Hyperscaler on Workstation deployment!"

        if [[ ${#EXECUTED_COMMANDS[@]} -gt 0 ]]; then
            log "Validation completed using ${#EXECUTED_COMMANDS[@]} diagnostic commands."
        fi
    fi
}

# Run the main function with all provided arguments
main "$@"
