#!/bin/bash
# Deploy a single Apptainer image to HPC cluster
# This script wraps the Python CLI for easier batch deployment

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default values
CLUSTER_CONFIG="${PROJECT_ROOT}/config/example-multi-gpu-clusters.yaml"
REGISTRY_PATH="/opt/containers/ml-frameworks"
SYNC_NODES=false
VERIFY=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Usage function
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] <SIF_IMAGE>

Deploy a single Apptainer image to HPC cluster.

Arguments:
  SIF_IMAGE         Path to .sif Apptainer image

Options:
  -c, --config PATH           Cluster configuration file (default: config/example-multi-gpu-clusters.yaml)
  -r, --registry-path PATH    Registry path on cluster (default: /opt/containers/ml-frameworks)
  -s, --sync-nodes            Sync image to all compute nodes
  -v, --verify                Verify deployment on all nodes
  --verbose                   Enable verbose output
  -h, --help                  Show this help message

Examples:
  # Deploy single image
  $(basename "$0") build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif

  # Deploy with sync and verification
  $(basename "$0") -s -v build/containers/apptainer/pytorch-cuda12.1-mpi4.1.sif

  # Deploy to custom registry path
  $(basename "$0") -r /opt/containers/custom-images my-custom-image.sif

Environment Variables:
  CLUSTER_CONFIG      Override default cluster config path
  REGISTRY_PATH       Override default registry path
  SSH_KEY             SSH key for cluster access

EOF
  exit 0
}

# Parse arguments
SIF_IMAGE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--config)
      CLUSTER_CONFIG="$2"
      shift 2
      ;;
    -r|--registry-path)
      REGISTRY_PATH="$2"
      shift 2
      ;;
    -s|--sync-nodes)
      SYNC_NODES=true
      shift
      ;;
    -v|--verify)
      VERIFY=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [[ -z "$SIF_IMAGE" ]]; then
        SIF_IMAGE="$1"
      else
        echo -e "${RED}ERROR: Unknown argument: $1${NC}"
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate arguments
if [[ -z "$SIF_IMAGE" ]]; then
  echo -e "${RED}ERROR: SIF image path is required${NC}"
  usage
fi

if [[ ! -f "$SIF_IMAGE" ]]; then
  echo -e "${RED}ERROR: Image file not found: $SIF_IMAGE${NC}"
  exit 1
fi

if [[ ! -f "$CLUSTER_CONFIG" ]]; then
  echo -e "${RED}ERROR: Cluster config not found: $CLUSTER_CONFIG${NC}"
  exit 1
fi

# Extract image filename
IMAGE_NAME=$(basename "$SIF_IMAGE")

# Build CLI command
CLI_CMD="${PROJECT_ROOT}/build/containers/venv/bin/hpc-container-manager"

if [[ ! -x "$CLI_CMD" ]]; then
  echo -e "${YELLOW}WARNING: CLI not found at $CLI_CMD${NC}"
  echo -e "${YELLOW}Looking for CLI in PATH...${NC}"
  CLI_CMD="hpc-container-manager"
  if ! command -v "$CLI_CMD" &> /dev/null; then
    echo -e "${RED}ERROR: hpc-container-manager CLI not found${NC}"
    echo -e "${YELLOW}Please build the project first:${NC}"
    echo -e "  cd ${PROJECT_ROOT}"
    echo -e "  make config"
    echo -e "  make run-docker COMMAND='cmake --build build --target hpc-container-manager'"
    exit 1
  fi
fi

# Display deployment info
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deploying Container Image to HPC Cluster${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Image:          $SIF_IMAGE"
echo "Image Name:     $IMAGE_NAME"
echo "Cluster Config: $CLUSTER_CONFIG"
echo "Registry Path:  $REGISTRY_PATH"
echo "Sync to Nodes:  $SYNC_NODES"
echo "Verify:         $VERIFY"
echo ""

# Build deployment command
DEPLOY_CMD=("$CLI_CMD" deploy to-cluster "$SIF_IMAGE" "${REGISTRY_PATH}/${IMAGE_NAME}")
DEPLOY_CMD+=(--cluster-config "$CLUSTER_CONFIG")

if [[ "$SYNC_NODES" == "true" ]]; then
  DEPLOY_CMD+=(--sync-nodes)
fi

if [[ "$VERIFY" == "true" ]]; then
  DEPLOY_CMD+=(--verify)
fi

if [[ "$VERBOSE" == "true" ]]; then
  DEPLOY_CMD+=(--verbose)
fi

if [[ -n "${SSH_KEY:-}" ]]; then
  DEPLOY_CMD+=(--key "$SSH_KEY")
fi

# Execute deployment
echo -e "${YELLOW}Executing: ${DEPLOY_CMD[*]}${NC}"
echo ""

if "${DEPLOY_CMD[@]}"; then
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✓ Deployment Successful${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "Image deployed to: ${REGISTRY_PATH}/${IMAGE_NAME}"
  echo ""
  echo "Test with SLURM:"
  echo "  srun --container=${REGISTRY_PATH}/${IMAGE_NAME} python3 --version"
  echo ""
  echo "Or directly with Apptainer:"
  echo "  apptainer exec ${REGISTRY_PATH}/${IMAGE_NAME} python3 --version"
  echo ""
  exit 0
else
  echo ""
  echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${RED}  ✗ Deployment Failed${NC}"
  echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
  exit 1
fi
