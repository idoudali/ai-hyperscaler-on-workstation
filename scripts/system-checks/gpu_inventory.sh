#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# gpu_inventory.sh
# Reports the current GPU configuration and prints a YAML snippet suitable for
# the project's cluster configuration. Supports MIG-capable and non-MIG GPUs.
#
# Output:
# - Human-readable summary to stdout
# - YAML snippet for global GPU inventory (copy-paste into config/cluster.yaml)
# - YAML snippets for VM PCIe passthrough configurations
# - Also writes all output to ./output/gpu_inventory.yaml
#
# Requirements:
# - nvidia-smi (from NVIDIA driver), version 450.80.02 or newer (for MIG support and reliable output)
# - lspci (for PCI vendor/device ID detection)
# - bash, coreutils, awk, sed, grep

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${REPO_ROOT}/output"
OUT_YAML="${OUT_DIR}/gpu_inventory.yaml"

log_info() { printf "[INFO] %s\n" "$*"; }
log_warn() { printf "[WARN] %s\n" "$*" 1>&2; }
log_err()  { printf "[ERROR] %s\n" "$*" 1>&2; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_err "Required command not found: $1";
    return 1
  fi
}

# Get PCI vendor and device IDs for a given PCI address
get_pci_ids() {
  local pci_addr="$1"
  # Convert from nvidia-smi format (00000000:01:00.0) to lspci format (01:00.0)
  local short_addr
  short_addr="${pci_addr#*:}"

  local pci_info
  pci_info=$(lspci -n -s "${short_addr}" 2>/dev/null | head -n1 || true)
  if [[ -n "${pci_info}" ]]; then
    # Extract vendor:device from format like "01:00.0 0300: 10de:2684 (rev a1)"
    local ids
    ids=$(echo "${pci_info}" | grep -Eo '[0-9a-f]{4}:[0-9a-f]{4}' | head -n1)
    if [[ -n "${ids}" ]]; then
      echo "${ids}" | tr ':' ' '
    else
      echo "unknown unknown"
    fi
  else
    echo "unknown unknown"
  fi
}

# Get IOMMU group for a given PCI address
get_iommu_group() {
  local pci_addr="$1"
  # nvidia-smi returns format like 00000000:01:00.0, but sysfs uses 0000:01:00.0
  # Convert from nvidia-smi format to sysfs format
  local normalized_addr
  if [[ "${pci_addr}" =~ ^[0-9]+: ]]; then
    # Remove leading domain (00000000: -> "")
    normalized_addr="${pci_addr#*:}"
    # Ensure we have the 4-digit domain prefix (add 0000: if missing)
    if [[ ! "${normalized_addr}" =~ ^[0-9a-f]{4}: ]]; then
      normalized_addr="0000:${normalized_addr}"
    fi
  else
    normalized_addr="${pci_addr}"
  fi

  local iommu_path="/sys/bus/pci/devices/${normalized_addr}/iommu_group"
  if [[ -L "${iommu_path}" ]]; then
    basename "$(readlink "${iommu_path}")" 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

# Get NVIDIA driver version
get_nvidia_driver_version() {
  nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ' ' || echo "unknown"
}

cleanup() { :; }
trap cleanup EXIT

main() {
  require_cmd nvidia-smi || {
    log_err "nvidia-smi not found. Please install NVIDIA drivers and ensure nvidia-smi is available."
    exit 1
  }

  require_cmd lspci || {
    log_err "lspci not found. Please install pciutils package."
    exit 1
  }

  mkdir -p "${OUT_DIR}"

  # Basic GPU enumeration
  local -a gpu_rows
  # Fields: index,uuid,name,pci.bus_id,memory.total (in MiB)
  mapfile -t gpu_rows < <(nvidia-smi \
    --query-gpu=index,uuid,name,pci.bus_id,memory.total \
    --format=csv,noheader,nounits 2>/dev/null || true)

  if [[ ${#gpu_rows[@]} -eq 0 ]]; then
    log_warn "No NVIDIA GPUs detected."
    echo "global:" >"${OUT_YAML}"
    echo "  gpu_inventory:" >>"${OUT_YAML}"
    echo "    devices: []" >>"${OUT_YAML}"
    cat "${OUT_YAML}"
    exit 0
  fi

  log_info "Detected ${#gpu_rows[@]} NVIDIA GPU(s). Gathering detailed information..."

  # Get driver version once
  local driver_version
  driver_version="$(get_nvidia_driver_version)"

  # Generate timestamp
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  # Print human-readable report
  echo ""
  echo "=== GPU Inventory Report ==="
  echo "Generated: ${timestamp}"
  echo ""

  # Collect detailed GPU information for both human report and YAML
  local -a gpu_data=()
  local mig_capable_count=0
  local available_count=0

  for row in "${gpu_rows[@]}"; do
    # Parse CSV row
    local gpu_index gpu_uuid gpu_name gpu_bus gpu_mem_mib
    gpu_index=$(echo "${row}" | awk -F',' '{gsub(/^ +| +$/,"",$1); print $1}')
    gpu_uuid=$(echo "${row}"  | awk -F',' '{gsub(/^ +| +$/,"",$2); print $2}')
    gpu_name=$(echo "${row}"  | awk -F',' '{gsub(/^ +| +$/,"",$3); print $3}')
    gpu_bus=$(echo "${row}"   | awk -F',' '{gsub(/^ +| +$/,"",$4); print $4}')
    gpu_mem_mib=$(echo "${row}"| awk -F',' '{gsub(/^ +| +$/,"",$5); print $5}')

    # Get PCI vendor and device IDs
    local pci_ids vendor_id device_id
    pci_ids="$(get_pci_ids "${gpu_bus}")"
    vendor_id="${pci_ids%% *}"  # First part before space
    device_id="${pci_ids##* }"  # Last part after space

    # Get IOMMU group
    local iommu_group
    iommu_group="$(get_iommu_group "${gpu_bus}")"

    # Determine MIG capability and mode
    local mig_capable="false" mig_mode="disabled"
    local q
    q=$(nvidia-smi -i "${gpu_index}" -q 2>/dev/null || true)
    if echo "${q}" | grep -q "MIG Mode"; then
      local current_line
      current_line=$(echo "${q}" \
        | awk '/MIG Mode/{flag=1;next}/^\S/{flag=0}flag' \
        | awk -F':' '/Current/{gsub(/ /,"",$2); print tolower($2)}' \
        | head -n1)
      if [[ -n "${current_line}" ]]; then
        mig_mode="${current_line}"
        if [[ "${mig_mode}" != "n/a" ]]; then
          mig_capable="true"
          mig_capable_count=$((mig_capable_count + 1))
        fi
      fi
    fi

    # Status - assume available if nvidia-smi can query it
    local status="Available"
    available_count=$((available_count + 1))

    # Store data for later use
    gpu_data+=("${gpu_index}|${gpu_uuid}|${gpu_name}|${gpu_bus}|${gpu_mem_mib}|${vendor_id}|${device_id}|${iommu_group}|${mig_capable}|${mig_mode}|${status}")

    # Print human-readable summary for this GPU
    echo "GPU ${gpu_index}:"
    echo "  Model: ${gpu_name}"
    echo "  PCI Address: ${gpu_bus}"
    echo "  Vendor ID: ${vendor_id}"
    echo "  Device ID: ${device_id}"
    echo "  IOMMU Group: ${iommu_group}"
    echo "  MIG Capable: $(if [[ "${mig_capable}" == "true" ]]; then echo "Yes"; else echo "No"; fi)"
    echo "  Driver: nvidia (version ${driver_version})"
    echo "  Status: ${status}"
    echo ""
  done

  # Print summary statistics
  echo "=== Summary ==="
  echo "Total GPUs: ${#gpu_rows[@]}"
  echo "MIG Capable: ${mig_capable_count}"
  echo "Available for Passthrough: ${available_count}"
  echo ""

  # Generate YAML sections
  local global_yaml vm_yaml_sections
  global_yaml="$(generate_global_yaml "${gpu_data[@]}")"
  vm_yaml_sections="$(generate_vm_yaml_sections "${gpu_data[@]}")"

  # Combine all output
  local full_output
  full_output="${global_yaml}"
  full_output+=$'\n\n'
  full_output+="${vm_yaml_sections}"

  # Write to file
  printf "%s\n" "${full_output}" >"${OUT_YAML}"
  log_info "Wrote YAML to ${OUT_YAML}"
  echo ""

  # Print YAML sections
  echo "==== GLOBAL GPU INVENTORY YAML (copy into config/cluster.yaml under global.gpu_inventory) ===="
  printf "%s\n" "${global_yaml}"
  echo ""
  echo "==== VM PCIE PASSTHROUGH CONFIGURATIONS ===="
  printf "%s\n" "${vm_yaml_sections}"
}

# Generate global GPU inventory YAML section
generate_global_yaml() {
  local gpu_data=("$@")
  local yaml="global:"
  yaml+=$'\n  gpu_inventory:'
  yaml+=$'\n    # Host GPU inventory for reference and conflict detection'
  yaml+=$'\n    devices:'

  for data in "${gpu_data[@]}"; do
    IFS='|' read -r gpu_index gpu_uuid gpu_name gpu_bus gpu_mem_mib vendor_id device_id iommu_group mig_capable mig_mode status <<< "${data}"

    yaml+=$'\n      - id: "GPU-'"${gpu_index}"'"'
    yaml+=$'\n        pci_address: "'"${gpu_bus}"'"'
    yaml+=$'\n        model: "'"${gpu_name}"'"'
    yaml+=$'\n        vendor_id: "'"${vendor_id}"'"'
    yaml+=$'\n        device_id: "'"${device_id}"'"'
    yaml+=$'\n        iommu_group: '"${iommu_group}"
    yaml+=$'\n        mig_capable: '"${mig_capable}"
  done

  printf "%s" "${yaml}"
}

# Generate VM PCIe passthrough configuration sections
generate_vm_yaml_sections() {
  local gpu_data=("$@")
  local sections=""

  sections+="# Copy the following sections to compute nodes in your cluster configuration"
  sections+=$'\n# Each GPU should be assigned to only one VM to avoid conflicts\n'

  for data in "${gpu_data[@]}"; do
    IFS='|' read -r gpu_index gpu_uuid gpu_name gpu_bus gpu_mem_mib vendor_id device_id iommu_group mig_capable mig_mode status <<< "${data}"

    sections+=$'\n# Configuration for GPU '"${gpu_index}"' ('"${gpu_name}"')'
    sections+=$'\npcie_passthrough:'
    sections+=$'\n  enabled: true'
    sections+=$'\n  devices:'
    sections+=$'\n    - pci_address: "'"${gpu_bus}"'"'
    sections+=$'\n      device_type: "gpu"'
    sections+=$'\n      vendor_id: "'"${vendor_id}"'"'
    sections+=$'\n      device_id: "'"${device_id}"'"'
    sections+=$'\n      iommu_group: '"${iommu_group}"
    sections+=$'\n'
  done

  printf "%s" "${sections}"
}

main "$@"
