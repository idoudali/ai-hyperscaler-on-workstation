#!/usr/bin/env bash
# Unified Apptainer deployment helper
# Provides single-image, batch, and BeeGFS deployment flows
#
# Expected to run inside the project development container.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DEFAULT_CLUSTER_CONFIG="${CLUSTER_CONFIG:-${PROJECT_ROOT}/config/example-multi-gpu-clusters.yaml}"
DEFAULT_REGISTRY_PATH="${REGISTRY_PATH:-/opt/containers/ml-frameworks}"
DEFAULT_APPTAINER_DIR="${APPTAINER_DIR:-${PROJECT_ROOT}/build/containers/apptainer}"

CLI_CMD=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  single <SIF_IMAGE>      Deploy a single Apptainer image to the cluster
  batch                   Deploy all Apptainer images from a directory
  beegfs                  Deploy Apptainer images to a BeeGFS-backed controller
  help                    Show this help message

Run "$(basename "$0") <command> --help" for command-specific options.
EOF
}

usage_single() {
  cat <<EOF
Usage: $(basename "$0") single [OPTIONS] <SIF_IMAGE>

Deploy a single Apptainer image to the cluster.

Options:
  -c, --config PATH           Cluster configuration file (default: ${DEFAULT_CLUSTER_CONFIG})
  -r, --registry-path PATH    Registry path on cluster (default: ${DEFAULT_REGISTRY_PATH})
  -s, --sync-nodes            Sync image to all compute nodes
  -v, --verify                Verify deployment on all nodes
      --key PATH              SSH key for cluster access (default: \$SSH_KEY if set)
      --verbose               Enable verbose CLI output
  -h, --help                  Show this help message

Environment Variables:
  CLUSTER_CONFIG   Override default cluster config path
  REGISTRY_PATH    Override default registry path
  SSH_KEY          SSH key for cluster access
EOF
}

usage_batch() {
  cat <<EOF
Usage: $(basename "$0") batch [OPTIONS]

Deploy all Apptainer images from a directory to the cluster.

Options:
  -c, --config PATH           Cluster configuration file (default: ${DEFAULT_CLUSTER_CONFIG})
  -r, --registry-path PATH    Registry path on cluster (default: ${DEFAULT_REGISTRY_PATH})
  -d, --apptainer-dir PATH    Directory with .sif images (default: ${DEFAULT_APPTAINER_DIR})
  -s, --sync-nodes            Sync images to all compute nodes
  -v, --verify                Verify deployment on all nodes
      --key PATH              SSH key for cluster access (default: \$SSH_KEY if set)
      --verbose               Enable verbose CLI output
  -n, --dry-run               Show what would be deployed without deploying
  -p, --parallel              Deploy images in parallel (experimental)
  -h, --help                  Show this help message
EOF
}

usage_beegfs() {
  cat <<EOF
Usage: $(basename "$0") beegfs [OPTIONS]

Deploy Apptainer images to a BeeGFS-backed controller so they are available cluster-wide.

Options:
      --controller-ip ADDR    BeeGFS controller IP (default: \${BEEGFS_CONTROLLER_IP:-192.168.100.10})
      --controller-user USER  BeeGFS controller SSH user (default: \${BEEGFS_CONTROLLER_USER:-admin})
      --target-base PATH      BeeGFS target directory (default: \${BEEGFS_TARGET_BASE:-/mnt/beegfs/containers})
      --sif-root PATH         Directory containing .sif images (default: \${BEEGFS_SIF_ROOT:-${PROJECT_ROOT}/build/containers})
      --key PATH              SSH key for controller access (default: \${BEEGFS_SSH_KEY:-${PROJECT_ROOT}/build/shared/ssh-keys/id_rsa})
      --sync-nodes            Sync images to compute nodes after deployment
      --no-sync               Do not sync images to compute nodes
      --verify                Verify deployment on all nodes (default)
      --no-verify             Skip verification
      --verbose               Enable verbose CLI output
  -h, --help                  Show this help message

Environment Variables (used as defaults if set):
  BEEGFS_CONTROLLER_IP, BEEGFS_CONTROLLER_USER, BEEGFS_TARGET_BASE,
  BEEGFS_SSH_KEY, BEEGFS_SYNC_NODES, BEEGFS_VERIFY, BEEGFS_SIF_ROOT
EOF
}

error() {
  printf "%bERROR:%b %s\n" "${RED}" "${NC}" "$*" >&2
}

warn() {
  printf "%bWARNING:%b %s\n" "${YELLOW}" "${NC}" "$*" >&2
}

info() {
  printf "%bINFO:%b %s\n" "${BLUE}" "${NC}" "$*"
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    error "Required file not found: $path"
    return 1
  fi
}

require_directory() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    error "Required directory not found: $path"
    return 1
  fi
}

activate_cli_env() {
  local activate_path="${PROJECT_ROOT}/build/containers/venv/bin/activate"
  if [[ -f "$activate_path" ]]; then
    # shellcheck disable=SC1090
    source "$activate_path"
  fi

  local tools_path="${PROJECT_ROOT}/containers/tools"
  if [[ -d "$tools_path" ]]; then
    if [[ -n "${PYTHONPATH:-}" ]]; then
      case ":$PYTHONPATH:" in
        *":$tools_path:"*) ;;
        *) export PYTHONPATH="${tools_path}:${PYTHONPATH}";;
      esac
    else
      export PYTHONPATH="$tools_path"
    fi
  fi
}

find_cli() {
  if [[ -n "$CLI_CMD" ]]; then
    echo "$CLI_CMD"
    return 0
  fi

  local candidate="${PROJECT_ROOT}/build/containers/venv/bin/hpc-container-manager"
  if [[ -x "$candidate" ]]; then
    CLI_CMD="$candidate"
    echo "$CLI_CMD"
    return 0
  fi

  warn "CLI not found at ${candidate}"
  warn "Looking for hpc-container-manager in PATH..."
  if CLI_CMD="$(command -v hpc-container-manager 2>/dev/null)"; then
    echo "$CLI_CMD"
    return 0
  fi

  error "hpc-container-manager CLI not found. Build the project first:"
  printf "  cd %s\n" "${PROJECT_ROOT}" >&2
  printf "  make config\n" >&2
  printf "  make run-docker COMMAND='cmake --build build --target hpc-container-manager'\n" >&2
  exit 1
}

deploy_image() {
  local sif="$1"
  local target="$2"
  shift 2
  activate_cli_env
  local cli
  cli="$(find_cli)"
  local cmd=("$cli" deploy to-cluster "$sif" "$target")
  if [[ $# -gt 0 ]]; then
    cmd+=("$@")
  fi
  "${cmd[@]}"
}

perform_single_deploy() {
  local sif_image="$1"
  local cluster_config="$2"
  local registry_path="$3"
  local sync_nodes="$4"
  local verify="$5"
  local verbose="$6"
  local key="$7"

  local image_name
  image_name="$(basename "$sif_image")"
  local registry="${registry_path%/}"
  if [[ -z "$registry" ]]; then
    registry="/"
  fi
  local target="${registry}/${image_name}"

  local extra_cli=(--cluster-config "$cluster_config")
  if [[ "$sync_nodes" == "true" ]]; then
    extra_cli+=(--sync-nodes)
  fi
  if [[ "$verify" == "true" ]]; then
    extra_cli+=(--verify)
  fi
  if [[ "$verbose" == "true" ]]; then
    extra_cli+=(--verbose)
  fi
  if [[ -n "$key" ]]; then
    extra_cli+=(--key "$key")
  fi

  printf "%b═══════════════════════════════════════════════════════════%b\n" "${GREEN}" "${NC}"
  printf "%b  Deploying Container Image%b\n" "${GREEN}" "${NC}"
  printf "%b═══════════════════════════════════════════════════════════%b\n" "${GREEN}" "${NC}"
  printf "Image:          %s\n" "$sif_image"
  printf "Image Name:     %s\n" "$image_name"
  printf "Cluster Config: %s\n" "$cluster_config"
  printf "Registry Path:  %s\n" "$registry"
  printf "Target Path:    %s\n" "$target"
  printf "Sync to Nodes:  %s\n" "$sync_nodes"
  printf "Verify:         %s\n" "$verify"
  if [[ -n "$key" ]]; then
    printf "SSH Key:        %s\n" "$key"
  fi
  printf "\n"

  activate_cli_env
  local cli
  cli="$(find_cli)"
  local cmd=("$cli" deploy to-cluster "$sif_image" "$target" "${extra_cli[@]}")
  printf "%bExecuting:%b %s\n\n" "${YELLOW}" "${NC}" "${cmd[*]}"

  if deploy_image "$sif_image" "$target" "${extra_cli[@]}"; then
    printf "%b═══════════════════════════════════════════════════════════%b\n" "${GREEN}" "${NC}"
    printf "%b  ✓ Deployment Successful%b\n" "${GREEN}" "${NC}"
    printf "%b═══════════════════════════════════════════════════════════%b\n" "${GREEN}" "${NC}"
    printf "\n"
    printf "Image deployed to: %s\n" "$target"
    printf "\n"
    printf "Test with SLURM:\n"
    printf "  srun --container=%s python3 --version\n" "$target"
    printf "\n"
    printf "Or directly with Apptainer:\n"
    printf "  apptainer exec %s python3 --version\n" "$target"
    printf "\n"
    return 0
  fi

  printf "%b═══════════════════════════════════════════════════════════%b\n" "${RED}" "${NC}"
  printf "%b  ✗ Deployment Failed%b\n" "${RED}" "${NC}"
  printf "%b═══════════════════════════════════════════════════════════%b\n" "${RED}" "${NC}"
  printf "\n"
  return 1
}

cmd_single() {
  local cluster_config="$DEFAULT_CLUSTER_CONFIG"
  local registry_path="$DEFAULT_REGISTRY_PATH"
  local sync_nodes=false
  local verify=false
  local verbose=false
  local key="${SSH_KEY:-}"
  local sif_image=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      -c|--config)
        cluster_config="$2"
        shift 2
        ;;
      -r|--registry-path)
        registry_path="$2"
        shift 2
        ;;
      -s|--sync-nodes)
        sync_nodes=true
        shift
        ;;
      -v|--verify)
        verify=true
        shift
        ;;
      --key)
        key="$2"
        shift 2
        ;;
      --verbose)
        verbose=true
        shift
        ;;
      -h|--help)
        usage_single
        exit 0
        ;;
      -*)
        error "Unknown option for single: $1"
        usage_single
        exit 1
        ;;
      *)
        if [[ -z "$sif_image" ]]; then
          sif_image="$1"
          shift
        else
          error "Unexpected argument: $1"
          usage_single
          exit 1
        fi
        ;;
    esac
  done

  if [[ -z "$sif_image" ]]; then
    error "SIF image path is required"
    usage_single
    exit 1
  fi

  if [[ ! -f "$sif_image" ]]; then
    error "Image file not found: $sif_image"
    exit 1
  fi

  require_file "$cluster_config"

  if perform_single_deploy "$sif_image" "$cluster_config" "$registry_path" "$sync_nodes" "$verify" "$verbose" "$key"; then
    return 0
  fi

  exit 1
}

cmd_batch_sequential() {
  local -n _sif_files_ref=$1
  local cluster_config="$2"
  local registry_path="$3"
  local sync_nodes="$4"
  local verify="$5"
  local verbose="$6"
  local key="$7"

  local total=${#_sif_files_ref[@]}
  local success=0
  local failed=0
  local failed_images=()

  local index=0
  for sif in "${_sif_files_ref[@]}"; do
    index=$((index + 1))
    printf "%b───────────────────────────────────────────────────────────%b\n" "${BLUE}" "${NC}"
    printf "%bDeploying: %s (%d/%d)%b\n" "${BLUE}" "$(basename "$sif")" "$index" "$total" "${NC}"
    printf "%b───────────────────────────────────────────────────────────%b\n" "${BLUE}" "${NC}"

    if perform_single_deploy "$sif" "$cluster_config" "$registry_path" "$sync_nodes" "$verify" "$verbose" "$key"; then
      printf "%b✓ Successfully deployed:%b %s\n\n" "${GREEN}" "${NC}" "$(basename "$sif")"
      success=$((success + 1))
    else
      printf "%b✗ Failed to deploy:%b %s\n\n" "${RED}" "${NC}" "$(basename "$sif")"
      failed=$((failed + 1))
      failed_images+=("$(basename "$sif")")
    fi
  done

  printf "%b═══════════════════════════════════════════════════════════%b\n" "${BLUE}" "${NC}"
  printf "%b  Deployment Summary%b\n" "${BLUE}" "${NC}"
  printf "%b═══════════════════════════════════════════════════════════%b\n" "${BLUE}" "${NC}"
  printf "Total Images:      %d\n" "$total"
  printf "%bSuccessful:        %d%b\n" "${GREEN}" "$success" "${NC}"
  if [[ $failed -gt 0 ]]; then
    printf "%bFailed:            %d%b\n" "${RED}" "$failed" "${NC}"
    printf "\n"
    printf "%bFailed images:%b\n" "${RED}" "${NC}"
    for img in "${failed_images[@]}"; do
      printf "%b  ✗ %s%b\n" "${RED}" "$img" "${NC}"
    done
  fi
  printf "\n"

  if [[ $failed -eq 0 ]]; then
    printf "%b✓ All deployments successful%b\n" "${GREEN}" "${NC}"
    return 0
  fi

  printf "%b✗ Some deployments failed%b\n" "${RED}" "${NC}"
  return 1
}

cmd_batch_parallel() {
  local -n _sif_files_ref=$1
  local cluster_config="$2"
  local registry_path="$3"
  local sync_nodes="$4"
  local verify="$5"
  local verbose="$6"
  local key="$7"

  warn "Parallel deployment mode is experimental"

  for sif in "${_sif_files_ref[@]}"; do
    (
      printf "%b[Parallel]%b Deploying %s\n" "${BLUE}" "${NC}" "$(basename "$sif")"
      if perform_single_deploy "$sif" "$cluster_config" "$registry_path" "$sync_nodes" "$verify" "$verbose" "$key"; then
        printf "%b[Parallel]%b ✓ %s\n" "${GREEN}" "${NC}" "$(basename "$sif")"
      else
        printf "%b[Parallel]%b ✗ %s\n" "${RED}" "${NC}" "$(basename "$sif")"
      fi
    ) &
  done

  wait
  warn "Parallel deployment complete (check output for errors)"
}

cmd_batch() {
  local cluster_config="$DEFAULT_CLUSTER_CONFIG"
  local registry_path="$DEFAULT_REGISTRY_PATH"
  local apptainer_dir="$DEFAULT_APPTAINER_DIR"
  local sync_nodes=false
  local verify=false
  local verbose=false
  local dry_run=false
  local parallel=false
  local key="${SSH_KEY:-}"

  while [[ $# -gt 0 ]]; do
    case $1 in
      -c|--config)
        cluster_config="$2"
        shift 2
        ;;
      -r|--registry-path)
        registry_path="$2"
        shift 2
        ;;
      -d|--apptainer-dir)
        apptainer_dir="$2"
        shift 2
        ;;
      -s|--sync-nodes)
        sync_nodes=true
        shift
        ;;
      -v|--verify)
        verify=true
        shift
        ;;
      --key)
        key="$2"
        shift 2
        ;;
      --verbose)
        verbose=true
        shift
        ;;
      -n|--dry-run)
        dry_run=true
        shift
        ;;
      -p|--parallel)
        parallel=true
        shift
        ;;
      -h|--help)
        usage_batch
        exit 0
        ;;
      *)
        error "Unknown option for batch: $1"
        usage_batch
        exit 1
        ;;
    esac
  done

  require_directory "$apptainer_dir"
  require_file "$cluster_config"

  mapfile -t sif_files < <(find "$apptainer_dir" -type f -name '*.sif' | sort)

  if [[ ${#sif_files[@]} -eq 0 ]]; then
    warn "No .sif images found in $apptainer_dir"
    exit 0
  fi

  printf "%b═══════════════════════════════════════════════════════════%b\n" "${BLUE}" "${NC}"
  printf "%b  Batch Deployment of Apptainer Images%b\n" "${BLUE}" "${NC}"
  printf "%b═══════════════════════════════════════════════════════════%b\n" "${BLUE}" "${NC}"
  printf "Cluster Config:    %s\n" "$cluster_config"
  printf "Registry Path:     %s\n" "$registry_path"
  printf "Apptainer Dir:     %s\n" "$apptainer_dir"
  printf "Sync to Nodes:     %s\n" "$sync_nodes"
  printf "Verify:            %s\n" "$verify"
  printf "Parallel:          %s\n" "$parallel"
  printf "Dry Run:           %s\n" "$dry_run"
  if [[ -n "$key" ]]; then
    printf "SSH Key:           %s\n" "$key"
  fi
  printf "\n"
  printf "%bFound %d image(s) to deploy:%b\n" "${GREEN}" "${#sif_files[@]}" "${NC}"
  for sif in "${sif_files[@]}"; do
    printf "  • %s\n" "$(basename "$sif")"
  done
  printf "\n"

  if [[ "$dry_run" == "true" ]]; then
    warn "DRY RUN MODE - No actual deployment will occur"
    printf "\n"
    for sif in "${sif_files[@]}"; do
      printf "%bWould deploy:%b %s → %s/%s\n" "${BLUE}" "${NC}" "$(basename "$sif")" "${registry_path%/}" "$(basename "$sif")"
    done
    printf "\n"
    printf "%b✓ Dry run complete%b\n" "${GREEN}" "${NC}"
    exit 0
  fi

  read -p "Proceed with deployment? (yes/no): " -r reply
  printf "\n"
  if [[ ! "$reply" =~ ^[Yy](es)?$ ]]; then
    info "Deployment cancelled"
    exit 0
  fi

  if [[ "$parallel" == "true" ]]; then
    cmd_batch_parallel sif_files "$cluster_config" "$registry_path" "$sync_nodes" "$verify" "$verbose" "$key"
  else
    if ! cmd_batch_sequential sif_files "$cluster_config" "$registry_path" "$sync_nodes" "$verify" "$verbose" "$key"; then
      exit 1
    fi
  fi
}

cmd_beegfs() {
  local controller_ip="${BEEGFS_CONTROLLER_IP:-192.168.100.10}"
  local controller_user="${BEEGFS_CONTROLLER_USER:-admin}"
  local target_base="${BEEGFS_TARGET_BASE:-/mnt/beegfs/containers}"
  local ssh_key_default="${BEEGFS_SSH_KEY:-${PROJECT_ROOT}/build/shared/ssh-keys/id_rsa}"
  local ssh_key="$ssh_key_default"
  local sync_nodes="${BEEGFS_SYNC_NODES:-false}"
  local verify="${BEEGFS_VERIFY:-true}"
  local sif_root="${BEEGFS_SIF_ROOT:-${PROJECT_ROOT}/build/containers}"
  local verbose=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --controller-ip)
        controller_ip="$2"
        shift 2
        ;;
      --controller-user)
        controller_user="$2"
        shift 2
        ;;
      --target-base)
        target_base="$2"
        shift 2
        ;;
      --sif-root)
        sif_root="$2"
        shift 2
        ;;
      --key)
        ssh_key="$2"
        shift 2
        ;;
      --sync-nodes)
        sync_nodes=true
        shift
        ;;
      --no-sync)
        sync_nodes=false
        shift
        ;;
      --verify)
        verify=true
        shift
        ;;
      --no-verify)
        verify=false
        shift
        ;;
      --verbose)
        verbose=true
        shift
        ;;
      -h|--help)
        usage_beegfs
        exit 0
        ;;
      *)
        error "Unknown option for beegfs: $1"
        usage_beegfs
        exit 1
        ;;
    esac
  done

  if [[ -z "$controller_ip" ]]; then
    error "Controller IP must be provided (set BEEGFS_CONTROLLER_IP or use --controller-ip)"
    exit 1
  fi

  require_directory "$sif_root"
  find_cli >/dev/null

  if [[ -n "$ssh_key" && ! -r "$ssh_key" ]]; then
    warn "SSH key $ssh_key not present or unreadable; continuing without explicit key"
    ssh_key=""
  fi

  mapfile -t sif_images < <(find "$sif_root" -type f -name '*.sif' | sort)

  if [[ ${#sif_images[@]} -eq 0 ]]; then
    error "No Apptainer images (*.sif) found under $sif_root. Build containers first."
    exit 1
  fi

  info "Deploying Apptainer images to BeeGFS on ${controller_user}@${controller_ip}"

  if ! command -v ssh >/dev/null 2>&1; then
    error "Required command 'ssh' not found in PATH"
    exit 1
  fi

  local ssh_opts=(-o BatchMode=yes -o StrictHostKeyChecking=no)
  local deploy_key_args=()
  if [[ -n "$ssh_key" ]]; then
    ssh_opts+=(-i "$ssh_key")
    deploy_key_args+=(--key "$ssh_key")
  fi

  local remote="${controller_user}@${controller_ip}"
  info "Ensuring BeeGFS base directory exists: ${target_base}"
  ssh "${ssh_opts[@]}" "${remote}" -- mkdir -p "$target_base"

  for sif_path in "${sif_images[@]}"; do
    local rel_path="${sif_path#"${sif_root}/"}"
    local rel_dir
    rel_dir="$(dirname "$rel_path")"
    if [[ "$rel_dir" == "." ]]; then
      rel_dir=""
    fi

    local remote_dir="$target_base"
    if [[ -n "$rel_dir" ]]; then
      remote_dir="${target_base}/${rel_dir}"
    fi
    local image_name
    image_name="$(basename "$sif_path")"
    local remote_path="${remote_dir}/${image_name}"

    info "Preparing remote directory ${remote_dir}"
    ssh "${ssh_opts[@]}" "${remote}" -- mkdir -p "$remote_dir"

    info "Deploying ${rel_path} -> ${remote_path}"

    local extra_cli=(--controller "$controller_ip" --user "$controller_user")
    if [[ "$sync_nodes" == "true" || "$sync_nodes" == "1" ]]; then
      extra_cli+=(--sync-nodes)
    fi
    if [[ "$verify" == "true" || "$verify" == "1" ]]; then
      extra_cli+=(--verify)
    fi
    if [[ "${#deploy_key_args[@]}" -gt 0 ]]; then
      extra_cli+=("${deploy_key_args[@]}")
    fi
    if [[ "$verbose" == "true" ]]; then
      extra_cli+=(--verbose)
    fi

    deploy_image "$sif_path" "$remote_path" "${extra_cli[@]}"
  done

  info "Container deployment completed successfully."
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local command="$1"
  shift

  case "$command" in
    help|-h|--help)
      usage
      ;;
    single)
      cmd_single "$@"
      ;;
    batch|all)
      cmd_batch "$@"
      ;;
    beegfs)
      cmd_beegfs "$@"
      ;;
    *)
      error "Unknown command: $command"
      usage
      exit 1
      ;;
  esac
}

main "$@"
