#!/bin/bash
# Deploy all built Apptainer images to HPC cluster
# Batch deployment script for multiple images

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default values
CLUSTER_CONFIG="${PROJECT_ROOT}/config/template-cluster.yaml"
REGISTRY_PATH="/opt/containers/ml-frameworks"
APPTAINER_DIR="${PROJECT_ROOT}/build/containers/apptainer"
SYNC_NODES=false
VERIFY=false
VERBOSE=false
DRY_RUN=false
PARALLEL=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Deploy all built Apptainer images to HPC cluster.

Options:
  -c, --config PATH           Cluster configuration file (default: config/template-cluster.yaml)
  -r, --registry-path PATH    Registry path on cluster (default: /opt/containers/ml-frameworks)
  -d, --apptainer-dir PATH    Directory with .sif images (default: build/containers/apptainer)
  -s, --sync-nodes            Sync images to all compute nodes
  -v, --verify                Verify deployment on all nodes
  -p, --parallel              Deploy images in parallel (experimental)
  -n, --dry-run               Show what would be deployed without deploying
  --verbose                   Enable verbose output
  -h, --help                  Show this help message

Examples:
  # Deploy all images
  $(basename "$0")

  # Dry run to see what would be deployed
  $(basename "$0") --dry-run

  # Deploy with sync and verification
  $(basename "$0") --sync-nodes --verify

  # Deploy from custom directory
  $(basename "$0") --apptainer-dir /path/to/images

Environment Variables:
  CLUSTER_CONFIG      Override default cluster config path
  REGISTRY_PATH       Override default registry path
  SSH_KEY             SSH key for cluster access

EOF
  exit 0
}

# Parse arguments
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
    -d|--apptainer-dir)
      APPTAINER_DIR="$2"
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
    -p|--parallel)
      PARALLEL=true
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=true
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
      echo -e "${RED}ERROR: Unknown argument: $1${NC}"
      usage
      ;;
  esac
done

# Validate Apptainer directory
if [[ ! -d "$APPTAINER_DIR" ]]; then
  echo -e "${RED}ERROR: Apptainer directory not found: $APPTAINER_DIR${NC}"
  echo -e "${YELLOW}Build containers first with: make run-docker COMMAND='cmake --build build --target apptainer-images'${NC}"
  exit 1
fi

# Find all .sif files
mapfile -t SIF_FILES < <(find "$APPTAINER_DIR" -name "*.sif" -type f 2>/dev/null)

if [[ ${#SIF_FILES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}WARNING: No .sif images found in $APPTAINER_DIR${NC}"
  exit 0
fi

# Display deployment summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Batch Deployment of Apptainer Images${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Cluster Config:    $CLUSTER_CONFIG"
echo "Registry Path:     $REGISTRY_PATH"
echo "Apptainer Dir:     $APPTAINER_DIR"
echo "Sync to Nodes:     $SYNC_NODES"
echo "Verify:            $VERIFY"
echo "Parallel:          $PARALLEL"
echo "Dry Run:           $DRY_RUN"
echo ""
echo -e "${GREEN}Found ${#SIF_FILES[@]} image(s) to deploy:${NC}"
for sif in "${SIF_FILES[@]}"; do
  echo "  • $(basename "$sif")"
done
echo ""

# Dry run mode
if [[ "$DRY_RUN" == "true" ]]; then
  echo -e "${YELLOW}DRY RUN MODE - No actual deployment will occur${NC}"
  echo ""
  for sif in "${SIF_FILES[@]}"; do
    echo -e "${BLUE}Would deploy:${NC} $(basename "$sif") → ${REGISTRY_PATH}/$(basename "$sif")"
  done
  echo ""
  echo -e "${GREEN}✓ Dry run complete${NC}"
  exit 0
fi

# Confirmation prompt
read -p "Proceed with deployment? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy](es)?$ ]]; then
  echo "Deployment cancelled"
  exit 0
fi

# Deploy images
DEPLOY_SCRIPT="${SCRIPT_DIR}/deploy-single.sh"
if [[ ! -x "$DEPLOY_SCRIPT" ]]; then
  echo -e "${RED}ERROR: deploy-single.sh not found or not executable${NC}"
  exit 1
fi

# Build deployment options
DEPLOY_OPTS=(-c "$CLUSTER_CONFIG" -r "$REGISTRY_PATH")
if [[ "$SYNC_NODES" == "true" ]]; then
  DEPLOY_OPTS+=(-s)
fi
if [[ "$VERIFY" == "true" ]]; then
  DEPLOY_OPTS+=(-v)
fi
if [[ "$VERBOSE" == "true" ]]; then
  DEPLOY_OPTS+=(--verbose)
fi

# Deployment counters
TOTAL=${#SIF_FILES[@]}
SUCCESS=0
FAILED=0
declare -a FAILED_IMAGES=()

# Sequential deployment
deploy_sequential() {
  for sif in "${SIF_FILES[@]}"; do
    echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}Deploying: $(basename "$sif") ($((SUCCESS + FAILED + 1))/${TOTAL})${NC}"
    echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"

    if "$DEPLOY_SCRIPT" "${DEPLOY_OPTS[@]}" "$sif"; then
      ((SUCCESS++)) || true
      echo -e "${GREEN}✓ Successfully deployed: $(basename "$sif")${NC}"
    else
      ((FAILED++)) || true
      FAILED_IMAGES+=("$(basename "$sif")")
      echo -e "${RED}✗ Failed to deploy: $(basename "$sif")${NC}"
    fi
    echo ""
  done
}

# Parallel deployment (experimental)
deploy_parallel() {
  echo -e "${YELLOW}Parallel deployment mode (experimental)${NC}"
  echo ""

  for sif in "${SIF_FILES[@]}"; do
    (
      if "$DEPLOY_SCRIPT" "${DEPLOY_OPTS[@]}" "$sif"; then
        echo -e "${GREEN}✓ Successfully deployed: $(basename "$sif")${NC}"
      else
        echo -e "${RED}✗ Failed to deploy: $(basename "$sif")${NC}"
      fi
    ) &
  done

  wait

  # Note: Parallel mode doesn't track success/failure accurately yet
  echo -e "${YELLOW}Parallel deployment complete (check output for errors)${NC}"
}

# Execute deployment
if [[ "$PARALLEL" == "true" ]]; then
  deploy_parallel
else
  deploy_sequential
fi

# Display final summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Deployment Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Total Images:      $TOTAL"
echo -e "${GREEN}Successful:        $SUCCESS${NC}"
if [[ $FAILED -gt 0 ]]; then
  echo -e "${RED}Failed:            $FAILED${NC}"
  echo ""
  echo -e "${RED}Failed images:${NC}"
  for img in "${FAILED_IMAGES[@]}"; do
    echo -e "${RED}  ✗ $img${NC}"
  done
fi
echo ""

# Exit with appropriate code
if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All deployments successful${NC}"
  exit 0
else
  echo -e "${RED}✗ Some deployments failed${NC}"
  exit 1
fi
