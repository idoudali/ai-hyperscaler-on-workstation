#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# gpu_inventory.sh
# Reports the current GPU configuration and prints a YAML snippet suitable for
# the project's cluster configuration. Supports MIG-capable and non-MIG GPUs.
#
# Output:
# - Human-readable summary to stdout
# - YAML snippet to stdout (copy-paste into config/cluster.yaml)
# - Also writes YAML to ./output/gpu_inventory.yaml
#
# Requirements:
# - nvidia-smi (from NVIDIA driver), version 450.80.02 or newer (for MIG support and reliable output)
#   - NVIDIA driver version 450.80.02 or newer
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

cleanup() { :; }
trap cleanup EXIT

main() {
  require_cmd nvidia-smi || {
    log_err "nvidia-smi not found. Please install NVIDIA drivers and ensure nvidia-smi is available."
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
    print_yaml_header >"${OUT_YAML}"
    cat "${OUT_YAML}"
    exit 0
  fi

  log_info "Detected ${#gpu_rows[@]} NVIDIA GPU(s). Gathering MIG capability and profiles..."

  # Collect per-GPU data
  local yaml
  yaml="$(print_yaml_header)"
  yaml+=$'\n    devices:'

  local idx=0
  for row in "${gpu_rows[@]}"; do
    # Example row: 0, GPU-xxxx, NVIDIA A100 80GB PCIe, 0000:65:00.0, 81251
    # CSV without quoting
    local gpu_index gpu_uuid gpu_name gpu_bus gpu_mem_mib
    gpu_index=$(echo "${row}" | awk -F',' '{gsub(/^ +| +$/,"",$1); print $1}')
    gpu_uuid=$(echo "${row}"  | awk -F',' '{gsub(/^ +| +$/,"",$2); print $2}')
    gpu_name=$(echo "${row}"  | awk -F',' '{gsub(/^ +| +$/,"",$3); print $3}')
    gpu_bus=$(echo "${row}"   | awk -F',' '{gsub(/^ +| +$/,"",$4); print $4}')
    gpu_mem_mib=$(echo "${row}"| awk -F',' '{gsub(/^ +| +$/,"",$5); print $5}')

    # Determine MIG capability and mode
    local mig_capable="false" mig_mode="disabled"
    local q
    q=$(nvidia-smi -i "${gpu_index}" -q 2>/dev/null || true)
    if echo "${q}" | grep -q "MIG Mode"; then
      # Try to parse the current MIG mode line value
      local current_line
      current_line=$(echo "${q}" \
        | awk '/MIG Mode/{flag=1;next}/^\S/{flag=0}flag' \
        | awk -F':' '/Current/{gsub(/ /,"",$2); print tolower($2)}' \
        | head -n1)
      if [[ -n "${current_line}" ]]; then
        mig_mode="${current_line}"
        # Consider device MIG-capable only if mode is not n/a
        if [[ "${mig_mode}" != "n/a" ]]; then
          mig_capable="true"
        fi
      fi
    fi

    # If MIG-capable, attempt to list allowed GPU instance profiles
    local -a profiles=()
    if [[ "${mig_capable}" == "true" ]]; then
      # nvidia-smi mig profile listing can vary by version. Try multiple options.
      local prof_output=""
      if prof_output=$(nvidia-smi mig -i "${gpu_index}" -lgip 2>/dev/null || true); then
        :
      elif prof_output=$(nvidia-smi mig -i "${gpu_index}" -lgci 2>/dev/null || true); then
        :
      else
        prof_output=""
      fi

      if [[ -n "${prof_output}" ]]; then
        # Extract tokens like 1g.5gb, 2g.10gb, etc.
        mapfile -t profiles < <(echo "${prof_output}" | grep -Eo "[0-9]+g\.[0-9]+gb" | sort -u)
      else
        # Fallback common profiles for A100-family if unknown
        profiles=("1g.5gb" "2g.10gb" "3g.20gb" "7g.80gb")
      fi
    fi

    # Current MIG instances (if any)
    local -a active_profiles=()
    if [[ "${mig_capable}" == "true" && "${mig_mode}" == "enabled" ]]; then
      local l
      l=$(nvidia-smi -i "${gpu_index}" -L 2>/dev/null || true)
      # Lines like: MIG 1g.5gb Device 0: (UUID: ...)
      mapfile -t active_profiles < <(echo "${l}" | grep -Eo "MIG [0-9]+g\.[0-9]+gb" | awk '{print $2}' | sort | uniq -c | awk '{print $2":"$1}')
    fi

    # Append device YAML
    yaml+=$(printf "\n      - id: \"GPU-%s\"\n" "${gpu_index}")
    yaml+=$(printf "        pci_address: \"%s\"\n" "${gpu_bus}")
    yaml+=$(printf "        model: \"%s\"\n" "${gpu_name}")
    yaml+=$(printf "        uuid: \"%s\"\n" "${gpu_uuid}")
    yaml+=$(printf "        memory_mib: %s\n" "${gpu_mem_mib}")
    yaml+=$(printf "        mig_capable: %s\n" "${mig_capable}")
    if [[ "${mig_capable}" == "true" ]]; then
      yaml+=$(printf "        mig_mode: \"%s\"\n" "${mig_mode}")
      if [[ ${#profiles[@]} -gt 0 ]]; then
        yaml+=$(printf "        allowed_mig_profiles: [%s]\n" "$(printf '%s,' "${profiles[@]}" | sed 's/,$//')")
      else
        yaml+=$(printf "        allowed_mig_profiles: []\n")
      fi
      if [[ ${#active_profiles[@]} -gt 0 ]]; then
        yaml+=$(printf "        current_mig_slices:\n")
        local ap
        for ap in "${active_profiles[@]}"; do
          # ap like 1g.5gb:2
          local prof cnt
          prof="${ap%%:*}"; cnt="${ap##*:}"
          yaml+=$(printf "          - profile: \"%s\"\n            count: %s\n" "${prof}" "${cnt}")
        done
      fi
    fi

    idx=$((idx+1))
  done

  # Strategy guidance
  yaml+=$'\n    strategy: "hybrid"  # one of: mig | whole | hybrid'
  yaml+=$'\n    # Optional pool sizing examples (edit as needed)\n    mig_slices:\n      hpc: 0\n      cloud: 0\n    whole_gpus:\n      hpc: 0\n      cloud: 0\n'

  # Print summary
  echo ""
  echo "==== GPU INVENTORY (SUMMARY) ===="
  printf "%s\n" "${gpu_rows[@]}" | nl -w2 -s': '
  echo ""

  # Write YAML
  printf "%s\n" "${yaml}" >"${OUT_YAML}"
  log_info "Wrote YAML to ${OUT_YAML}"
  echo ""
  echo "==== YAML SNIPPET (copy into config/cluster.yaml under global.gpu_allocation) ===="
  printf "%s\n" "${yaml}"
}

print_yaml_header() {
  cat <<'YAML'
global:
  gpu_allocation:
YAML
}

main "$@"
