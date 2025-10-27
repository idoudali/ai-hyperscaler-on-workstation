# Packer Images CMake Configuration
cmake_minimum_required(VERSION 3.18)

# BeeGFS packages directory (from 3rd-party build)
set(BEEGFS_PACKAGES_SOURCE_DIR "${PROJECT_BINARY_DIR}/packages/beegfs")

# SLURM packages directory (from 3rd-party build)
set(SLURM_PACKAGES_SOURCE_DIR "${PROJECT_BINARY_DIR}/packages/slurm")

# Set up shared SSH keys directory (shared between all Packer images)
set(SHARED_SSH_KEYS_DIR "${CMAKE_BINARY_DIR}/shared/ssh-keys")
file(MAKE_DIRECTORY ${SHARED_SSH_KEYS_DIR})

# Common scripts directory
set(COMMON_SCRIPTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/common/scripts")

# Define shared SSH key files
set(SHARED_SSH_KEY_PRIVATE ${SHARED_SSH_KEYS_DIR}/id_rsa)
set(SHARED_SSH_KEY_PUBLIC ${SHARED_SSH_KEYS_DIR}/id_rsa.pub)

# Command to generate shared SSH key pair
add_custom_command(
    OUTPUT ${SHARED_SSH_KEY_PRIVATE} ${SHARED_SSH_KEY_PUBLIC}
    COMMAND ${COMMON_SCRIPTS_DIR}/generate-ssh-keys-only.sh ${SHARED_SSH_KEYS_DIR}
    COMMENT "Generating shared SSH key pair for all Packer images..."
    DEPENDS ${COMMON_SCRIPTS_DIR}/generate-ssh-keys-only.sh
    VERBATIM
)

# Target to trigger the command
add_custom_target(generate-shared-ssh-keys
    DEPENDS ${SHARED_SSH_KEY_PRIVATE} ${SHARED_SSH_KEY_PUBLIC}
)

set(DEBIAN_CLOUD_IMAGE_URL_PREFIX "https://cloud.debian.org/images/cloud/trixie" CACHE INTERNAL "Debian cloud image URL prefix")
set(DEBIAN_RELEASE_VERSION "20250806-2196" CACHE INTERNAL "Debian release version")
set(DEBIAN_IMAGE_NAME "debian-13-genericcloud-amd64-${DEBIAN_RELEASE_VERSION}.qcow2" CACHE INTERNAL "Debian image name")
set(DEBIAN_CLOUD_IMAGE_URL "${DEBIAN_CLOUD_IMAGE_URL_PREFIX}/${DEBIAN_RELEASE_VERSION}/${DEBIAN_IMAGE_NAME}" CACHE INTERNAL "Debian cloud image URL")
set(DEBIAN_CLOUD_IMAGE_CHECKSUM_URL "${DEBIAN_CLOUD_IMAGE_URL_PREFIX}/${DEBIAN_RELEASE_VERSION}/SHA512SUMS" CACHE INTERNAL "Debian cloud image checksum URL")
set(DEBIAN_CLOUD_IMAGE_CHECKSUM_FILE "${CMAKE_CURRENT_BINARY_DIR}/debian-checksum.txt" CACHE INTERNAL "Debian cloud image checksum file")

# Target to download and extract SHA512 checksum
add_custom_command(
    OUTPUT ${DEBIAN_CLOUD_IMAGE_CHECKSUM_FILE}
    COMMAND curl -sL "${DEBIAN_CLOUD_IMAGE_CHECKSUM_URL}" | grep "${DEBIAN_IMAGE_NAME}" | cut -d " " -f1 > ${DEBIAN_CLOUD_IMAGE_CHECKSUM_FILE}
    COMMENT "Downloading and extracting SHA512 checksum for Debian cloud image..."
    VERBATIM
)

# Target to prepare the checksum
add_custom_target(prepare-debian-checksum
    DEPENDS ${DEBIAN_CLOUD_IMAGE_CHECKSUM_FILE}
)

# Add subdirectories for each image type
add_subdirectory(hpc-controller)
add_subdirectory(hpc-compute)
add_subdirectory(cloud-base)
add_subdirectory(cloud-gpu-worker)

# Create aggregate targets that depend on subdirectory targets

# Initialize all Packer plugins
add_custom_target(init-packer
    DEPENDS init-hpc-controller-packer init-hpc-compute-packer init-cloud-base-packer init-cloud-gpu-worker-packer
    COMMENT "Initializing all Packer plugins..."
)

# Initialize HPC Packer plugins (both controller and compute)
add_custom_target(init-hpc-packer
    DEPENDS init-hpc-controller-packer init-hpc-compute-packer
    COMMENT "Initializing HPC Packer plugins..."
)

# Initialize Cloud Packer plugins (base and GPU worker)
add_custom_target(init-cloud-packer
    DEPENDS init-cloud-base-packer init-cloud-gpu-worker-packer
    COMMENT "Initializing Cloud Packer plugins..."
)

# Validate all Packer templates
add_custom_target(validate-packer
    DEPENDS validate-hpc-controller-packer validate-hpc-compute-packer validate-cloud-base-packer validate-cloud-gpu-worker-packer
    COMMENT "Validating all Packer templates..."
)

# Validate HPC Packer templates (both controller and compute)
add_custom_target(validate-hpc-packer
    DEPENDS validate-hpc-controller-packer validate-hpc-compute-packer
    COMMENT "Validating HPC Packer templates..."
)

# Validate Cloud Packer templates (base and GPU worker)
add_custom_target(validate-cloud-packer
    DEPENDS validate-cloud-base-packer validate-cloud-gpu-worker-packer
    COMMENT "Validating Cloud Packer templates..."
)

# Format all Packer templates
add_custom_target(format-packer
    DEPENDS format-hpc-controller-packer format-hpc-compute-packer format-cloud-base-packer format-cloud-gpu-worker-packer
    COMMENT "Formatting all Packer templates..."
)

# Format HPC Packer templates (both controller and compute)
add_custom_target(format-hpc-packer
    DEPENDS format-hpc-controller-packer format-hpc-compute-packer
    COMMENT "Formatting HPC Packer templates..."
)

# Format Cloud Packer templates (base and GPU worker)
add_custom_target(format-cloud-packer
    DEPENDS format-cloud-base-packer format-cloud-gpu-worker-packer
    COMMENT "Formatting Cloud Packer templates..."
)

# Build all base images
add_custom_target(build-packer-images
    DEPENDS build-hpc-controller-image build-hpc-compute-image build-cloud-base-image build-cloud-gpu-worker-image
    COMMENT "Building all base images..."
)

# Build HPC images (both controller and compute)
add_custom_target(build-hpc-images
    DEPENDS build-hpc-controller-image build-hpc-compute-image
    COMMENT "Building HPC images..."
)

# Build Cloud images (base and GPU worker)
add_custom_target(build-cloud-images
    DEPENDS build-cloud-base-image build-cloud-gpu-worker-image
    COMMENT "Building Cloud images..."
)
