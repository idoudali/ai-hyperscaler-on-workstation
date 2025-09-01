#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# gpu_inventory.sh
# Reports the current GPU configuration and prints a YAML snippet suitable for
# the project's cluster configuration. Supports MIG-capable and non-MIG GPUs.
# Also detects GPUs attached to vfio-pci driver for PCIe passthrough scenarios.
#
# Output:
# - Human-readable summary to stdout
# - YAML snippet for global GPU inventory (copy-paste into config/cluster.yaml)
# - YAML snippets for VM PCIe passthrough configurations
# - Also writes all output to ./output/gpu_inventory.yaml
#
# Requirements:
# - nvidia-smi (from NVIDIA driver), version 450.80.02 or newer (for MIG support and reliable output)
# - lspci (for PCI vendor/device ID detection and vfio-pci GPU detection)
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

# Detect sound devices associated with NVIDIA GPUs
detect_nvidia_sound_devices() {
  local gpu_pci_addr="$1"
  local -a sound_devices=()

  # Look for audio devices in the same IOMMU group as the GPU
  local gpu_iommu_group
  gpu_iommu_group="$(get_iommu_group "${gpu_pci_addr}")"

  if [[ "${gpu_iommu_group}" == "unknown" ]]; then
    return 0
  fi

  # Find all PCI devices in the same IOMMU group
  local iommu_group_path="/sys/kernel/iommu_groups/${gpu_iommu_group}/devices"
  if [[ ! -d "${iommu_group_path}" ]]; then
    return 0
  fi

  # Look for audio devices (function 1, 2, etc.) associated with the GPU
  for device_path in "${iommu_group_path}"/*; do
    local device_name
    device_name=$(basename "${device_path}")

    # Convert device name to PCI address format
    local normalized_device_pci_addr
    normalized_device_pci_addr="${device_name}"
    # Skip the GPU device itself
    if [[ "${normalized_device_pci_addr}" == "${gpu_pci_addr}" ]]; then
      continue
    fi

    # Check if this is an audio device associated with the GPU
    # Use normalized_device_pci_addr from above
    local device_pci_addr="${normalized_device_pci_addr}"

    # Get device info
    local device_info
    device_info=$(lspci -nnk -s "${device_pci_addr}" 2>/dev/null || true)

    if [[ -z "${device_info}" ]]; then
      continue
    fi

    # Check if this is an audio device
    if echo "${device_info}" | grep -q "Audio device\|Multimedia audio controller"; then
      # Extract vendor and device IDs
      local vendor_device_ids
      vendor_device_ids=$(echo "${device_info}" | grep -Eo '[0-9a-f]{4}:[0-9a-f]{4}' | head -n1 || true)

      if [[ -n "${vendor_device_ids}" ]]; then
        local vendor_id device_id
        vendor_id="${vendor_device_ids%%:*}"
        device_id="${vendor_device_ids##*:}"

        # Check if this is an NVIDIA audio device (vendor ID 10de)
        if [[ "${vendor_id}" == "10de" ]]; then
          # Get device name
          local audio_name
          audio_name=$(echo "${device_info}" | head -n1 | sed 's/.*Audio device: //' | sed 's/.*Multimedia audio controller: //' || echo "NVIDIA Audio Device")

          # Get kernel driver
          local audio_driver
          audio_driver=$(echo "${device_info}" | grep 'Kernel driver in use' | awk '{print $5}' || echo "none")

          # Store audio device info
          sound_devices+=("${device_pci_addr}|${audio_name}|${vendor_id}|${device_id}|${gpu_iommu_group}|${audio_driver}")
        fi
      fi
    fi
  done

  printf "%s\n" "${sound_devices[@]}"
}

# Get NVIDIA driver version
get_nvidia_driver_version() {
  nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ' ' || echo "unknown"
}

# Detect GPUs using lspci (including those attached to vfio-pci)
detect_gpus_with_lspci() {
  local -a gpu_data=()

  # List all VGA and 3D controllers (GPUs)
  local gpu_pci_addresses
  gpu_pci_addresses=$(lspci -nn | grep -i 'vga\|3d' | awk '{print $1}' || true)

  if [[ -z "${gpu_pci_addresses}" ]]; then
    return 0
  fi

  local gpu_index=0
  while IFS= read -r pci_addr; do
    [[ -z "${pci_addr}" ]] && continue

    # Get detailed information for this GPU
    local pci_info
    pci_info=$(lspci -nnk -s "${pci_addr}" 2>/dev/null || true)

    if [[ -z "${pci_info}" ]]; then
      continue
    fi

    # Extract vendor and device IDs
    local vendor_device_ids
    vendor_device_ids=$(echo "${pci_info}" | grep -Eo '[0-9a-f]{4}:[0-9a-f]{4}' | head -n1 || true)

    if [[ -z "${vendor_device_ids}" ]]; then
      continue
    fi

    local vendor_id device_id
    vendor_id="${vendor_device_ids%%:*}"
    device_id="${vendor_device_ids##*:}"

    # Check if this is an NVIDIA GPU (vendor ID 10de)
    if [[ "${vendor_id}" != "10de" ]]; then
      continue
    fi

    # Get kernel driver in use
    local driver
    driver=$(echo "${pci_info}" | grep 'Kernel driver in use' | awk '{print $5}' || echo "none")

    # Get GPU name/model from lspci output
    local gpu_name
    gpu_name=$(echo "${pci_info}" | head -n1 | sed 's/.*VGA compatible controller: //' | sed 's/.*3D controller: //' || echo "Unknown NVIDIA GPU")

    # Get IOMMU group
    local iommu_group
    iommu_group="$(get_iommu_group "${pci_addr}")"

    # Determine status based on driver
    local status
    if [[ "${driver}" == "vfio-pci" ]]; then
      status="Attached to vfio-pci"
    elif [[ "${driver}" == "nvidia" ]]; then
      status="Attached to NVIDIA driver"
    else
      status="Unknown driver: ${driver}"
    fi

    # For vfio-pci GPUs, we can't get MIG info or memory info
    local mig_capable="false"
    local mig_mode="disabled"
    local gpu_mem_mib="unknown"
    local gpu_uuid="unknown"

    # Store data for later use
    gpu_data+=("${gpu_index}|${gpu_uuid}|${gpu_name}|${pci_addr}|${gpu_mem_mib}|${vendor_id}|${device_id}|${iommu_group}|${mig_capable}|${mig_mode}|${status}|${driver}")

    gpu_index=$((gpu_index + 1))
  done <<< "${gpu_pci_addresses}"

  printf "%s\n" "${gpu_data[@]}"
}

# Detect GPUs using nvidia-smi (only those attached to NVIDIA driver)
detect_gpus_with_nvidia_smi() {
  local -a gpu_data=()

  # Check if nvidia-smi is working properly
  if ! nvidia-smi --query-gpu=index --format=csv,noheader,nounits >/dev/null 2>&1; then
    log_warn "nvidia-smi is not working properly. Skipping NVIDIA driver detection."
    return 0
  fi

  # Fields: index,uuid,name,pci.bus_id,memory.total (in MiB)
  local -a gpu_rows
  mapfile -t gpu_rows < <(nvidia-smi \
    --query-gpu=index,uuid,name,pci.bus_id,memory.total \
    --format=csv,noheader,nounits 2>/dev/null || true)

  if [[ ${#gpu_rows[@]} -eq 0 ]]; then
    return 0
  fi

  # Get driver version once
  local driver_version
  driver_version="$(get_nvidia_driver_version)"

  for row in "${gpu_rows[@]}"; do
    # Parse CSV row
    local gpu_index gpu_uuid gpu_name gpu_bus gpu_mem_mib
    gpu_index=$(echo "${row}" | awk -F',' '{gsub(/^ +| +$/,"",$1); print $1}')
    gpu_uuid=$(echo "${row}"  | awk -F',' '{gsub(/^ +| +$/,"",$2); print $2}')
    gpu_name=$(echo "${row}"  | awk -F',' '{gsub(/^ +| +$/,"",$3); print $3}')
    gpu_bus=$(echo "${row}"   | awk -F',' '{gsub(/^ +| +$/,"",$4); print $4}')
    gpu_mem_mib=$(echo "${row}"| awk -F',' '{gsub(/^ +| +$/,"",$5); print $5}')

    # Skip if any field is empty or invalid
    if [[ -z "${gpu_index}" || -z "${gpu_name}" || -z "${gpu_bus}" ]]; then
      continue
    fi

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
        fi
      fi
    fi

    # Status - available if nvidia-smi can query it
    local status="Available (NVIDIA driver)"
    local driver="nvidia"

    # Store data for later use
    gpu_data+=("${gpu_index}|${gpu_uuid}|${gpu_name}|${gpu_bus}|${gpu_mem_mib}|${vendor_id}|${device_id}|${iommu_group}|${mig_capable}|${mig_mode}|${status}|${driver}")
  done

  printf "%s\n" "${gpu_data[@]}"
}

# Merge and deduplicate GPU data based on PCI address
merge_gpu_data() {
  local -a nvidia_gpus=()
  local -a lspci_gpus=()
  local marker_found=false
  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then
      marker_found=true
      continue
    fi
    if [[ "$marker_found" == false ]]; then
      nvidia_gpus+=("$arg")
    else
      lspci_gpus+=("$arg")
    fi
  done
  local -a merged_gpus=()
  local -a seen_pci_addresses=()

  # First, add NVIDIA GPUs
  for gpu in "${nvidia_gpus[@]}"; do
    [[ -z "${gpu}" ]] && continue

    IFS='|' read -r gpu_index gpu_uuid gpu_name gpu_bus gpu_mem_mib vendor_id device_id iommu_group mig_capable mig_mode status driver <<< "${gpu}"
    seen_pci_addresses+=("${gpu_bus}")
    merged_gpus+=("${gpu}")
  done

  # Then add lspci GPUs that aren't already covered by NVIDIA detection
  for gpu in "${lspci_gpus[@]}"; do
    [[ -z "${gpu}" ]] && continue

    IFS='|' read -r gpu_index gpu_uuid gpu_name gpu_bus gpu_mem_mib vendor_id device_id iommu_group mig_capable mig_mode status driver <<< "${gpu}"

    # Check if this PCI address is already covered
    local already_seen=false
    for seen_addr in "${seen_pci_addresses[@]}"; do
      if [[ "${gpu_bus}" == "${seen_addr}" ]]; then
        already_seen=true
        break
      fi
    done

    if [[ "${already_seen}" == "false" ]]; then
      seen_pci_addresses+=("${gpu_bus}")
      merged_gpus+=("${gpu}")
    fi
  done

  printf "%s\n" "${merged_gpus[@]}"
}

cleanup() { :; }
trap cleanup EXIT

main() {
  require_cmd lspci || {
    log_err "lspci not found. Please install pciutils package."
    exit 1
  }

  mkdir -p "${OUT_DIR}"

  # Detect GPUs using both methods
  local -a nvidia_gpus=()
  local -a lspci_gpus=()

  # Try to detect GPUs with nvidia-smi first
  if command -v nvidia-smi >/dev/null 2>&1; then
    log_info "Detecting GPUs with NVIDIA driver..."
    mapfile -t nvidia_gpus < <(detect_gpus_with_nvidia_smi)
  else
    log_warn "nvidia-smi not found. Will only detect GPUs with lspci."
  fi

  # Always detect GPUs with lspci
  log_info "Detecting GPUs with lspci..."
  mapfile -t lspci_gpus < <(detect_gpus_with_lspci)

  # Merge and deduplicate GPU data
  local -a all_gpus=()
  mapfile -t all_gpus < <(merge_gpu_data "${nvidia_gpus[@]}" "--" "${lspci_gpus[@]}")

  if [[ ${#all_gpus[@]} -eq 0 ]]; then
    log_warn "No NVIDIA GPUs detected with either method."
    echo "global: {}" >"${OUT_YAML}"
    echo ""
    echo "=== GPU Inventory Report ==="
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "No NVIDIA GPUs detected on this system."
    echo "This could mean:"
    echo "  - No NVIDIA GPUs are installed"
    echo "  - GPUs are installed but not detected by lspci"
    echo "  - GPUs are bound to a different driver"
    echo ""
    cat "${OUT_YAML}"
    exit 0
  fi

  log_info "Detected ${#all_gpus[@]} NVIDIA GPU(s). Gathering detailed information..."

  # Get driver version if available
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
  local -a sound_devices=()
  local mig_capable_count=0
  local nvidia_driver_count=0
  local vfio_pci_count=0

  for gpu in "${all_gpus[@]}"; do
    [[ -z "${gpu}" ]] && continue

    # Parse GPU data
    IFS='|' read -r gpu_index gpu_uuid gpu_name gpu_bus gpu_mem_mib vendor_id device_id iommu_group mig_capable mig_mode status driver <<< "${gpu}"

    # Debug: Only process actual GPUs (should have proper GPU data)
    if [[ "${gpu_name}" == "" ]]; then
      continue  # Skip invalid GPU entries
    fi

    # Count by driver type
    if [[ "${driver}" == "nvidia" ]]; then
      nvidia_driver_count=$((nvidia_driver_count + 1))
      if [[ "${mig_capable}" == "true" ]]; then
        mig_capable_count=$((mig_capable_count + 1))
      fi
    elif [[ "${driver}" == "vfio-pci" ]]; then
      vfio_pci_count=$((vfio_pci_count + 1))
    fi

    # Store data for later use
    gpu_data+=("${gpu_index}|${gpu_uuid}|${gpu_name}|${gpu_bus}|${gpu_mem_mib}|${vendor_id}|${device_id}|${iommu_group}|${mig_capable}|${mig_mode}|${status}|${driver}")

    # Detect sound devices associated with this GPU
    local gpu_sound_devices
    mapfile -t gpu_sound_devices < <(detect_nvidia_sound_devices "${gpu_bus}")
    sound_devices+=("${gpu_sound_devices[@]}")

    # Print human-readable summary for this GPU
    echo "GPU ${gpu_index}:"
    echo "  Model: ${gpu_name}"
    echo "  PCI Address: ${gpu_bus}"
    echo "  Vendor ID: ${vendor_id}"
    echo "  Device ID: ${device_id}"
    echo "  IOMMU Group: ${iommu_group}"
    echo "  MIG Capable: $(if [[ "${mig_capable}" == "true" ]]; then echo "Yes"; else echo "No"; fi)"
    if [[ "${driver}" == "nvidia" ]]; then
      echo "  Driver: nvidia (version ${driver_version})"
      echo "  Memory: ${gpu_mem_mib} MiB"
    else
      echo "  Driver: ${driver}"
      echo "  Memory: ${gpu_mem_mib}"
    fi
    echo "  Status: ${status}"

    # Print associated sound devices
    if [[ ${#gpu_sound_devices[@]} -gt 0 ]]; then
      echo "  Associated Sound Devices:"
      for sound_device in "${gpu_sound_devices[@]}"; do
        [[ -z "${sound_device}" ]] && continue
        IFS='|' read -r sound_pci_addr sound_name sound_vendor_id sound_device_id sound_iommu_group sound_driver <<< "${sound_device}"
        echo "    - ${sound_name} (${sound_pci_addr}) - Driver: ${sound_driver}"
      done
    fi
    echo ""
  done

  # Print summary statistics
  echo "=== Summary ==="
  echo "Total GPUs: ${#all_gpus[@]}"
  echo "  - NVIDIA Driver: ${nvidia_driver_count}"
  echo "  - vfio-pci: ${vfio_pci_count}"
  echo "MIG Capable: ${mig_capable_count}"
  echo ""

  # Generate YAML sections
  local global_yaml vm_yaml_sections
  global_yaml="$(generate_global_yaml "${gpu_data[@]}")"
  vm_yaml_sections="$(generate_vm_yaml_sections)"

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
  echo "==== GLOBAL CONFIGURATION SECTION ===="
  printf "%s\n" "${global_yaml}"
  echo ""
  echo "==== UNIFIED PCIE PASSTHROUGH CONFIGURATIONS ===="
  echo "Each configuration block includes the GPU and ALL associated sound devices"
  echo "These MUST be assigned to the same VM for proper PCIe passthrough"
  echo ""
  printf "%s\n" "${vm_yaml_sections}"
}

# Generate global configuration YAML section
generate_global_yaml() {
  local gpu_data=("$@")
  local yaml="global:\n  gpus:"

  for data in "${gpu_data[@]}"; do
    [[ -z "${data}" ]] && continue
    IFS='|' read -r gpu_index gpu_uuid gpu_name gpu_bus gpu_mem_mib vendor_id device_id iommu_group mig_capable mig_mode status driver <<< "${data}"
    yaml+=$'\n    - index: '"${gpu_index}"
    yaml+=$'\n      uuid: '"${gpu_uuid}"
    yaml+=$'\n      name: '"${gpu_name}"
    yaml+=$'\n      bus_address: '"${gpu_bus}"
    yaml+=$'\n      memory_mib: '"${gpu_mem_mib}"
    yaml+=$'\n      vendor_id: '"${vendor_id}"
    yaml+=$'\n      device_id: '"${device_id}"
    yaml+=$'\n      iommu_group: '"${iommu_group}"
    yaml+=$'\n      mig_capable: '"${mig_capable}"
    yaml+=$'\n      mig_mode: '"${mig_mode}"
    yaml+=$'\n      status: '"${status}"
    yaml+=$'\n      driver: '"${driver}"
  done

  printf "%s" "${yaml}"
}

# Generate VM PCIe passthrough configuration sections
generate_vm_yaml_sections() {
  local sections=""

  sections+="# Copy the following sections to compute nodes in your cluster configuration"
  sections+=$'\n# Each GPU should be assigned to only one VM to avoid conflicts\n'
  sections+=$'\n# IMPORTANT: GPUs and their associated sound devices are grouped together\n'
  sections+=$'\n# and MUST be assigned to the same VM for proper PCIe passthrough\n'

  # Process each GPU from the global gpu_data array
  for data in "${gpu_data[@]}"; do
    [[ -z "${data}" ]] && continue

    IFS='|' read -r gpu_index gpu_uuid gpu_name gpu_bus gpu_mem_mib vendor_id device_id iommu_group mig_capable mig_mode status driver <<< "${data}"

    sections+=$'\n# ===== COMPLETE PCIE PASSTHROUGH CONFIGURATION FOR GPU '"${gpu_index}"' ====='
    sections+=$'\n# GPU: '"${gpu_name}"' (Driver: '"${driver}"')'
    sections+=$'\n# This configuration includes the GPU and ALL associated sound devices'
    sections+=$'\n# Copy this entire block to your VM configuration\n'
    sections+=$'\npcie_passthrough:'
    sections+=$'\n  enabled: true'
    sections+=$'\n  devices:'
    sections+=$'\n    # GPU device (primary function) - MUST be listed first for ROM BAR to be enabled correctly'
    sections+=$'\n    - pci_address: "'"${gpu_bus}"'"'
    sections+=$'\n      device_type: "gpu"'
    sections+=$'\n      vendor_id: "'"${vendor_id}"'"'
    sections+=$'\n      device_id: "'"${device_id}"'"'
    sections+=$'\n      iommu_group: '"${iommu_group}"

    # Add associated sound devices for this GPU
    local sound_devices_found=false
    for sound_device in "${sound_devices[@]}"; do
      [[ -z "${sound_device}" ]] && continue
      IFS='|' read -r sound_pci_addr sound_name sound_vendor_id sound_device_id sound_iommu_group sound_driver <<< "${sound_device}"

      # Check if this sound device is in the same IOMMU group as the GPU
      if [[ "${sound_iommu_group}" == "${iommu_group}" ]]; then
        if [[ "${sound_devices_found}" == "false" ]]; then
          sections+=$'\n    # Audio devices (secondary functions) - REQUIRED for same IOMMU group'
          sound_devices_found=true
        fi
        sections+=$'\n    - pci_address: "'"${sound_pci_addr}"'"'
        sections+=$'\n      device_type: "audio"'
        sections+=$'\n      vendor_id: "'"${sound_vendor_id}"'"'
        sections+=$'\n      device_id: "'"${sound_device_id}"'"'
        sections+=$'\n      iommu_group: '"${sound_iommu_group}"
      fi
    done

    if [[ "${sound_devices_found}" == "false" ]]; then
      sections+=$'\n    # No associated sound devices found for this GPU'
    fi

    sections+=$'\n'
    sections+=$'\n# ===== END OF CONFIGURATION FOR GPU '"${gpu_index}"' =====\n'
  done

  printf "%s" "${sections}"
}

# Generate sound device PCIe passthrough configuration sections
generate_sound_device_yaml_sections() {
  local sound_devices=("$@")
  local sections=""

  if [[ ${#sound_devices[@]} -eq 0 ]]; then
    return 0
  fi

  sections+=$'\n# Sound Device PCIe Passthrough Configurations\n'
  sections+=$'\n# These devices are typically in the same IOMMU group as their associated GPUs\n'
  sections+=$'\n# and should be passed together for proper functionality\n'

  for sound_device in "${sound_devices[@]}"; do
    [[ -z "${sound_device}" ]] && continue
    IFS='|' read -r sound_pci_addr sound_name sound_vendor_id sound_device_id sound_iommu_group sound_driver <<< "${sound_device}"

    sections+=$'\n# Configuration for Sound Device '"${sound_pci_addr}"' ('"${sound_name}"') - Driver: '"${sound_driver}"
    sections+=$'\npcie_passthrough:'
    sections+=$'\n  enabled: true'
    sections+=$'\n  devices:'
    sections+=$'\n    - pci_address: "'"${sound_pci_addr}"'"'
    sections+=$'\n      device_type: "audio"'
    sections+=$'\n      vendor_id: "'"${sound_vendor_id}"'"'
    sections+=$'\n      device_id: "'"${sound_device_id}"'"'
    sections+=$'\n      iommu_group: '"${sound_iommu_group}"
    sections+=$'\n'
  done

  printf "%s" "${sections}"
}

main "$@"
