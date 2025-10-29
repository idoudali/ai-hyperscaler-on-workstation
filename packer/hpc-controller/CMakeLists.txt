# HPC Controller Image CMake Configuration
# =======================================
#
# This CMakeLists.txt configures the build for the HPC Controller VM image.
# The HPC Controller serves as the head node for the HPC cluster, running SLURM
# controller services, BeeGFS metadata and management servers, and orchestration
# tools.
#
# Build Process:
# - Downloads Debian cloud image
# - Generates cloud-init configuration
# - Prepares Packer variables and dependencies
# - Builds QEMU-based VM image using Packer
#
# Usage:
#   cmake --build build --target build-hpc-controller-image
#   cmake --build build --target build-force-hpc-controller-image  # Force rebuild
#
# Available Targets:
#   - build-hpc-controller-image: Build the HPC controller image
#   - build-force-hpc-controller-image: Force rebuild the image
#   - init-hpc-controller-packer: Initialize Packer plugins
#   - validate-hpc-controller-packer: Validate Packer template
#   - format-hpc-controller-packer: Format Packer template
#   - clean-hpc-controller-image: Remove generated image files
#
# Dependencies:
#   - BeeGFS packages (build-beegfs-packages)
#   - SLURM packages (build-slurm-packages)
#   - Shared SSH keys (generate-shared-ssh-keys)

cmake_minimum_required(VERSION 3.18)

# --- Image Configuration ---
# Define Packer variables
set(IMAGE_NAME "hpc-controller")
set(VM_NAME "hpc-controller.qcow2")
set(DISK_SIZE "40G")
set(MEMORY "2048")
set(CPUS "2")

# SSH username to be used by Packer communicator and Ansible (must match cloud-init user)
set(SSH_USERNAME "admin" CACHE STRING "SSH username for image provisioning")

# --- Directory Setup ---
# Set output directory for the image
set(HPC_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/hpc-controller")

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
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/hpc-controller.pkrvars.hcl
    COMMAND sh -c "echo 'debian_cloud_image_checksum = \"'$(cat ${DEBIAN_CLOUD_IMAGE_CHECKSUM_FILE})'\"' > ${CMAKE_CURRENT_BINARY_DIR}/hpc-controller.pkrvars.hcl"
    DEPENDS prepare-debian-checksum
    COMMENT "Generating Packer variables file for hpc-controller..."
    VERBATIM
)

add_custom_target(generate-packer-vars-hpc-controller
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/hpc-controller.pkrvars.hcl
)

# --- Packer Configuration ---
# Packer variable arguments
set(PACKER_VARS
    -var "source_directory=${CMAKE_CURRENT_SOURCE_DIR}"
    -var "repo_tot_dir=${CMAKE_CURRENT_SOURCE_DIR}/../.."
    -var "build_directory=${HPC_OUTPUT_DIR}"
    -var "image_name=${IMAGE_NAME}"
    -var "vm_name=${VM_NAME}"
    -var "disk_size=${DISK_SIZE}"
    -var "memory=${MEMORY}"
    -var "cpus=${CPUS}"
    -var "debian_cloud_image_url=${DEBIAN_CLOUD_IMAGE_URL}"
    -var "cloud_init_dir=${CLOUD_INIT_BUILD_DIR}"
    -var "ssh_keys_dir=${SSH_KEYS_DIR}"
    -var "ssh_username=${SSH_USERNAME}"
    -var "beegfs_packages_dir=${BEEGFS_PACKAGES_SOURCE_DIR}"
    -var "slurm_packages_dir=${SLURM_PACKAGES_SOURCE_DIR}"
)

# --- Cloud-Init Configuration ---
# Prepare cloud-init configuration for hpc-controller

add_custom_command(
    OUTPUT ${CLOUD_INIT_BUILD_DIR}/user-data ${CLOUD_INIT_BUILD_DIR}/meta-data
    COMMAND ${COMMON_SCRIPTS_DIR}/prepare-cloud-init.sh ${SSH_KEYS_DIR} ${CLOUD_INIT_BUILD_DIR} hpc-controller
    COMMENT "Preparing cloud-init configuration for hpc-controller..."
    DEPENDS generate-shared-ssh-keys
        ${COMMON_SCRIPTS_DIR}/prepare-cloud-init.sh
        ${CMAKE_CURRENT_SOURCE_DIR}/../common/cloud-init/hpc-controller-user-data.yml
        ${CMAKE_CURRENT_SOURCE_DIR}/../common/cloud-init/hpc-controller-meta-data.yml
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-controller.sh
    VERBATIM
)

# Target to prepare cloud-init files
add_custom_target(prepare-cloud-init-hpc-controller
    DEPENDS ${CLOUD_INIT_BUILD_DIR}/user-data #
     ${CLOUD_INIT_BUILD_DIR}/meta-data #
     ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-controller.sh
)

# --- Packer Operations ---
# Initialize Packer plugins
set(INIT_PACKER_TOKEN ${CMAKE_CURRENT_BINARY_DIR}/hpc-controller-init-packer.token)

add_custom_command(
    OUTPUT ${INIT_PACKER_TOKEN}
    COMMAND flock ${PACKER_INIT_LOCK_FILE} -c "packer init --force hpc-controller.pkr.hcl"
    COMMAND date > ${INIT_PACKER_TOKEN}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS generate-shared-ssh-keys generate-packer-vars-hpc-controller
    COMMENT "Initializing HPC Controller Packer plugins..."
)

add_custom_target(init-hpc-controller-packer
    DEPENDS ${INIT_PACKER_TOKEN}
)

# Validate Packer template (using temporary output directory to avoid conflicts)
add_custom_target(validate-hpc-controller-packer
    COMMAND flock ${PACKER_INIT_LOCK_FILE} -c "packer init --force hpc-controller.pkr.hcl"
    COMMAND packer validate
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-controller.pkrvars.hcl
            ${PACKER_VARS}
            -var "build_directory=${CMAKE_CURRENT_BINARY_DIR}/validate-tmp"
            hpc-controller.pkr.hcl
    COMMAND rm -rf ${CMAKE_CURRENT_BINARY_DIR}/validate-tmp
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS generate-packer-vars-hpc-controller prepare-cloud-init-hpc-controller build-beegfs-packages build-slurm-packages
    COMMENT "Initializing plugins and validating HPC Controller Packer template..."
)

# Format Packer template
add_custom_target(format-hpc-controller-packer
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer fmt hpc-controller.pkr.hcl
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Formatting HPC Controller Packer template..."
)

# --- Image Build Targets ---
# Packer build arguments (conditional - only force if explicitly requested)
set(PACKER_BUILD_ARGS "")

# Build HPC controller image (only if output doesn't exist)
add_custom_command(
    OUTPUT ${HPC_OUTPUT_DIR}/${VM_NAME}
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer validate
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-controller.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/hpc-controller.pkr.hcl
    COMMAND packer build ${PACKER_BUILD_ARGS}
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-controller.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/hpc-controller.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Building HPC controller image..."
    DEPENDS prepare-cloud-init-hpc-controller
        ${CMAKE_CURRENT_SOURCE_DIR}/hpc-controller.pkr.hcl
        init-hpc-controller-packer
        generate-packer-vars-hpc-controller
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-controller.sh
        build-beegfs-packages
        build-slurm-packages
    USES_TERMINAL
    VERBATIM
)

# Target to build the image
add_custom_target(build-hpc-controller-image
    DEPENDS ${HPC_OUTPUT_DIR}/${VM_NAME}
)

# Force rebuild target (always rebuilds)
add_custom_target(build-force-hpc-controller-image
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer validate
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-controller.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/hpc-controller.pkr.hcl
    COMMAND packer build -force
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-controller.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/hpc-controller.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Force rebuilding HPC controller image..."
    DEPENDS prepare-cloud-init-hpc-controller
        ${CMAKE_CURRENT_SOURCE_DIR}/hpc-controller.pkr.hcl
        init-hpc-controller-packer
        generate-packer-vars-hpc-controller
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-controller.sh
        build-beegfs-packages
        build-slurm-packages
    USES_TERMINAL
    VERBATIM
)

# --- Cleanup Targets ---
# Clean target (removes generated image)
add_custom_target(clean-hpc-controller-image
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMENT "Cleaning HPC controller image..."
    VERBATIM
)
