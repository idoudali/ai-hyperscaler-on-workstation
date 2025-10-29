# Cloud Base Image CMake Configuration
# ====================================
#
# This CMakeLists.txt configures the build for the Cloud Base VM image.
# The Cloud Base image serves as a minimal base image for cloud deployments,
# providing a clean Debian environment with essential tools and configurations.
#
# Build Process:
# - Downloads Debian cloud image
# - Generates cloud-init configuration
# - Prepares Packer variables and dependencies
# - Builds QEMU-based VM image using Packer
#
# Usage:
#   cmake --build build --target build-cloud-base-image
#   cmake --build build --target build-force-cloud-base-image  # Force rebuild
#
# Available Targets:
#   - build-cloud-base-image: Build the cloud base image
#   - build-force-cloud-base-image: Force rebuild the image
#   - init-cloud-base-packer: Initialize Packer plugins
#   - validate-cloud-base-packer: Validate Packer template
#   - format-cloud-base-packer: Format Packer template
#   - clean-cloud-base-image: Remove generated image files
#
# Dependencies:
#   - Shared SSH keys (generate-shared-ssh-keys)

cmake_minimum_required(VERSION 3.18)

# --- Image Configuration ---
# Define Packer variables
set(IMAGE_NAME "cloud-base")
set(VM_NAME "cloud-base.qcow2")
set(DISK_SIZE "20G")
set(MEMORY "2048")
set(CPUS "2")

# SSH username to be used by Packer communicator and Ansible (must match cloud-init user)
set(SSH_USERNAME "admin" CACHE STRING "SSH username for image provisioning")

# --- Directory Setup ---
# Set output directory for the image
set(CLOUD_BASE_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/cloud-base")

# Use shared SSH keys directory (managed by parent CMakeLists.txt)
set(SSH_KEYS_DIR "${CMAKE_BINARY_DIR}/shared/ssh-keys")

# Set up cloud-init build directory
set(CLOUD_INIT_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/cloud-init")
file(MAKE_DIRECTORY ${CLOUD_INIT_BUILD_DIR})

# Common scripts directory
set(COMMON_SCRIPTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../common/scripts")

# --- Packer Variables Generation ---
# Read the checksum from file to pass to Packer
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/cloud-base.pkrvars.hcl
    COMMAND sh -c "echo 'debian_cloud_image_checksum = \"'$(cat ${DEBIAN_CLOUD_IMAGE_CHECKSUM_FILE})'\"' > ${CMAKE_CURRENT_BINARY_DIR}/cloud-base.pkrvars.hcl"
    DEPENDS prepare-debian-checksum
    COMMENT "Generating Packer variables file for cloud-base..."
    VERBATIM
)

add_custom_target(generate-packer-vars-cloud-base
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/cloud-base.pkrvars.hcl
)

# --- Packer Configuration ---
# Packer variable arguments
set(PACKER_VARS
    -var "source_directory=${CMAKE_CURRENT_SOURCE_DIR}"
    -var "repo_tot_dir=${CMAKE_CURRENT_SOURCE_DIR}/../.."
    -var "build_directory=${CLOUD_BASE_OUTPUT_DIR}"
    -var "image_name=${IMAGE_NAME}"
    -var "vm_name=${VM_NAME}"
    -var "disk_size=${DISK_SIZE}"
    -var "memory=${MEMORY}"
    -var "cpus=${CPUS}"
    -var "debian_cloud_image_url=${DEBIAN_CLOUD_IMAGE_URL}"
    -var "cloud_init_dir=${CLOUD_INIT_BUILD_DIR}"
    -var "ssh_keys_dir=${SSH_KEYS_DIR}"
    -var "ssh_username=${SSH_USERNAME}"
)

# --- Cloud-Init Configuration ---
# Prepare cloud-init configuration for cloud-base

add_custom_command(
    OUTPUT ${CLOUD_INIT_BUILD_DIR}/user-data ${CLOUD_INIT_BUILD_DIR}/meta-data
    COMMAND ${COMMON_SCRIPTS_DIR}/prepare-cloud-init.sh ${SSH_KEYS_DIR} ${CLOUD_INIT_BUILD_DIR} cloud-base
    COMMENT "Preparing cloud-init configuration for cloud-base..."
    DEPENDS generate-shared-ssh-keys
        ${COMMON_SCRIPTS_DIR}/prepare-cloud-init.sh
        ${CMAKE_CURRENT_SOURCE_DIR}/../common/cloud-init/cloud-base-user-data.yml
        ${CMAKE_CURRENT_SOURCE_DIR}/../common/cloud-init/cloud-base-meta-data.yml
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-cloud-base.sh
    VERBATIM
)

# Target to prepare cloud-init files
add_custom_target(prepare-cloud-init-cloud-base
    DEPENDS ${CLOUD_INIT_BUILD_DIR}/user-data #
     ${CLOUD_INIT_BUILD_DIR}/meta-data #
     ${CMAKE_CURRENT_SOURCE_DIR}/setup-cloud-base.sh
)

# --- Packer Operations ---
# Initialize Packer plugins
set(INIT_PACKER_TOKEN ${CMAKE_CURRENT_BINARY_DIR}/cloud-base-init-packer.token)

add_custom_command(
    OUTPUT ${INIT_PACKER_TOKEN}
    COMMAND flock ${PACKER_INIT_LOCK_FILE} -c "packer init --force cloud-base.pkr.hcl"
    COMMAND date > ${INIT_PACKER_TOKEN}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS generate-shared-ssh-keys generate-packer-vars-cloud-base
    COMMENT "Initializing Cloud Base Packer plugins..."
)

add_custom_target(init-cloud-base-packer
    DEPENDS ${INIT_PACKER_TOKEN}
)

# Validate Packer template (using temporary output directory to avoid conflicts)
add_custom_target(validate-cloud-base-packer
    COMMAND flock ${PACKER_INIT_LOCK_FILE} -c "packer init --force cloud-base.pkr.hcl"
    COMMAND packer validate
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/cloud-base.pkrvars.hcl
            ${PACKER_VARS}
            -var "build_directory=${CMAKE_CURRENT_BINARY_DIR}/validate-tmp"
            cloud-base.pkr.hcl
    COMMAND rm -rf ${CMAKE_CURRENT_BINARY_DIR}/validate-tmp
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS generate-packer-vars-cloud-base prepare-cloud-init-cloud-base
    COMMENT "Initializing plugins and validating Cloud Base Packer template..."
)

# Format Packer template
add_custom_target(format-cloud-base-packer
    COMMAND rm -rf ${CLOUD_BASE_OUTPUT_DIR}
    COMMAND packer fmt cloud-base.pkr.hcl
    COMMAND rm -rf ${CLOUD_BASE_OUTPUT_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Formatting Cloud Base Packer template..."
)

# --- Image Build Targets ---
# Packer build arguments (conditional - only force if explicitly requested)
set(PACKER_BUILD_ARGS "")

# Build cloud base image (only if output doesn't exist)
add_custom_command(
    OUTPUT ${CLOUD_BASE_OUTPUT_DIR}/${VM_NAME}
    COMMAND rm -rf ${CLOUD_BASE_OUTPUT_DIR}
    COMMAND packer validate
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/cloud-base.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/cloud-base.pkr.hcl
    COMMAND packer build ${PACKER_BUILD_ARGS}
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/cloud-base.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/cloud-base.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Building cloud base image..."
    DEPENDS prepare-cloud-init-cloud-base
        ${CMAKE_CURRENT_SOURCE_DIR}/cloud-base.pkr.hcl
        init-cloud-base-packer
        generate-packer-vars-cloud-base
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-cloud-base.sh
    USES_TERMINAL
    VERBATIM
)

# Target to build the image
add_custom_target(build-cloud-base-image
    DEPENDS ${CLOUD_BASE_OUTPUT_DIR}/${VM_NAME}
)

# Force rebuild target (always rebuilds)
add_custom_target(build-force-cloud-base-image
    COMMAND rm -rf ${CLOUD_BASE_OUTPUT_DIR}
    COMMAND packer validate
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/cloud-base.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/cloud-base.pkr.hcl
    COMMAND packer build -force
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/cloud-base.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/cloud-base.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Force rebuilding cloud base image..."
    DEPENDS prepare-cloud-init-cloud-base
        ${CMAKE_CURRENT_SOURCE_DIR}/cloud-base.pkr.hcl
        init-cloud-base-packer
        generate-packer-vars-cloud-base
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-cloud-base.sh
    USES_TERMINAL
    VERBATIM
)

# --- Cleanup Targets ---
# Clean target (removes generated image)
add_custom_target(clean-cloud-base-image
    COMMAND rm -rf ${CLOUD_BASE_OUTPUT_DIR}
    COMMENT "Cleaning cloud base image..."
    VERBATIM
)
