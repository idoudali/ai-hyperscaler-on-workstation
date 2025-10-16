#!/bin/bash
# Convert a single Docker image to Apptainer format
# Usage: ./convert-single.sh <docker-image-name> [output-path]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HPC_CLI="${PROJECT_ROOT}/build/containers/venv/bin/hpc-container-manager"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Usage information
usage() {
    cat << EOF
Usage: $0 <docker-image-name> [output-path]

Convert a Docker image to Apptainer SIF format.

Arguments:
  docker-image-name   Docker image name (e.g., pytorch-cuda12.1-mpi4.1:latest)
  output-path         Optional output path for .sif file
                      Default: build/containers/apptainer/<name>.sif

Examples:
  # Convert with default output path
  $0 pytorch-cuda12.1-mpi4.1:latest

  # Convert with custom output path
  $0 pytorch-cuda12.1-mpi4.1:latest /tmp/my-image.sif

  # Convert specific version
  $0 pytorch-cuda12.1-mpi4.1:v2.4.0 build/containers/apptainer/pytorch-v2.4.0.sif

Environment:
  HPC_CLI       Path to hpc-container-manager CLI (default: build/containers/venv/bin/hpc-container-manager)
  APPTAINER_CACHE  Apptainer cache directory (default: \$HOME/.apptainer/cache)

EOF
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if HPC CLI exists
    if [[ ! -f "${HPC_CLI}" ]]; then
        log_error "HPC container manager CLI not found at: ${HPC_CLI}"
        log_error "Please run: cmake --build build --target setup-hpc-cli"
        exit 1
    fi

    # Check if Apptainer is available
    if ! command -v apptainer &> /dev/null; then
        log_error "Apptainer not found in PATH"
        log_error "Please install Apptainer: https://apptainer.org/docs/admin/latest/installation.html"
        exit 1
    fi

    # Check if Docker daemon is accessible
    if ! docker info &> /dev/null; then
        log_error "Docker daemon not accessible"
        log_error "Please ensure Docker is running and you have permissions"
        exit 1
    fi

    log_success "All prerequisites met"
}

# Main conversion function
convert_image() {
    local docker_image="$1"
    local output_path="${2:-}"

    log_info "Starting conversion of Docker image: ${docker_image}"

    # Extract image name and tag
    local image_name
    local image_tag
    if [[ "${docker_image}" == *":"* ]]; then
        image_name="${docker_image%%:*}"
        image_tag="${docker_image##*:}"
    else
        image_name="${docker_image}"
        image_tag="latest"
        docker_image="${docker_image}:${image_tag}"
    fi

    # Determine output path
    if [[ -z "${output_path}" ]]; then
        output_path="${PROJECT_ROOT}/build/containers/apptainer/${image_name}.sif"
    fi

    # Create output directory if it doesn't exist
    local output_dir
    output_dir="$(dirname "${output_path}")"
    mkdir -p "${output_dir}"

    log_info "Output path: ${output_path}"

    # Check if Docker image exists
    if ! docker image inspect "${docker_image}" &> /dev/null; then
        log_error "Docker image not found: ${docker_image}"
        log_error "Please build the Docker image first"
        exit 1
    fi

    # Perform conversion using HPC CLI
    log_info "Converting to Apptainer format..."
    if "${HPC_CLI}" convert to-apptainer "${docker_image}" "${output_path}"; then
        log_success "Conversion completed successfully"
    else
        log_error "Conversion failed"
        exit 1
    fi

    # Verify output file
    if [[ -f "${output_path}" ]]; then
        local size
        size=$(du -h "${output_path}" | cut -f1)
        log_success "Created Apptainer image: ${output_path} (${size})"
    else
        log_error "Output file not created: ${output_path}"
        exit 1
    fi

    # Display image information
    log_info "Image information:"
    apptainer inspect "${output_path}" || log_warning "Could not inspect image"

    return 0
}

# Main script
main() {
    # Check for help flag first (before prerequisites)
    if [[ $# -gt 0 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
    fi

    # Check arguments
    if [[ $# -lt 1 ]]; then
        log_error "Missing required argument: docker-image-name"
        usage
    fi

    local docker_image="$1"
    local output_path="${2:-}"

    check_prerequisites
    convert_image "${docker_image}" "${output_path}"

    log_success "Docker to Apptainer conversion completed successfully"
    log_info "You can test the image with:"
    log_info "  apptainer exec ${output_path} python3 --version"
    log_info "  apptainer exec ${output_path} python3 -c 'import torch; print(torch.__version__)'"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
