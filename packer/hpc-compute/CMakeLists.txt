# HPC Compute Image CMake Configuration
# =====================================
#
# This CMakeLists.txt configures the build for the HPC Compute VM image.
# The HPC Compute nodes serve as worker nodes in the HPC cluster, running SLURM
# compute daemons, BeeGFS storage/object servers, and workload execution services.
#
# Build Process:
# - Downloads Debian cloud image
# - Generates cloud-init configuration
# - Prepares Packer variables and dependencies
# - Builds QEMU-based VM image using Packer
#
# Usage:
#   cmake --build build --target build-hpc-compute-image
#   cmake --build build --target build-force-hpc-compute-image  # Force rebuild
#
# Available Targets:
#   - build-hpc-compute-image: Build the HPC compute image
#   - build-force-hpc-compute-image: Force rebuild the image
#   - init-hpc-compute-packer: Initialize Packer plugins
#   - validate-hpc-compute-packer: Validate Packer template
#   - format-hpc-compute-packer: Format Packer template
#   - clean-hpc-compute-image: Remove generated image files
#
# Dependencies:
#   - BeeGFS packages (build-beegfs-packages)
#   - SLURM packages (build-slurm-packages)
#   - Shared SSH keys (generate-shared-ssh-keys)

cmake_minimum_required(VERSION 3.18)

# --- Image Configuration ---
# Define Packer variables
set(IMAGE_NAME "hpc-compute")
set(VM_NAME "hpc-compute.qcow2")
set(DISK_SIZE "40G")
set(MEMORY "2048")
set(CPUS "2")

# SSH username to be used by Packer communicator and Ansible (must match cloud-init user)
set(SSH_USERNAME "admin" CACHE STRING "SSH username for image provisioning")

# --- Directory Setup ---
# Set output directory for the image
set(HPC_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/hpc-compute")

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
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/hpc-compute.pkrvars.hcl
    COMMAND sh -c "echo 'debian_cloud_image_checksum = \"'$(cat ${DEBIAN_CLOUD_IMAGE_CHECKSUM_FILE})'\"' > ${CMAKE_CURRENT_BINARY_DIR}/hpc-compute.pkrvars.hcl"
    DEPENDS prepare-debian-checksum
    COMMENT "Generating Packer variables file for hpc-compute..."
    VERBATIM
)

add_custom_target(generate-packer-vars-hpc-compute
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/hpc-compute.pkrvars.hcl
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
# Prepare cloud-init configuration for hpc-compute

add_custom_command(
    OUTPUT ${CLOUD_INIT_BUILD_DIR}/user-data ${CLOUD_INIT_BUILD_DIR}/meta-data
    COMMAND ${COMMON_SCRIPTS_DIR}/prepare-cloud-init.sh ${SSH_KEYS_DIR} ${CLOUD_INIT_BUILD_DIR} hpc-compute
    COMMENT "Preparing cloud-init configuration for hpc-compute..."
    DEPENDS generate-shared-ssh-keys
        ${COMMON_SCRIPTS_DIR}/prepare-cloud-init.sh
        ${CMAKE_CURRENT_SOURCE_DIR}/../common/cloud-init/hpc-compute-user-data.yml
        ${CMAKE_CURRENT_SOURCE_DIR}/../common/cloud-init/hpc-compute-meta-data.yml
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-compute.sh
    VERBATIM
)

# Target to prepare cloud-init files
add_custom_target(prepare-cloud-init-hpc-compute
    DEPENDS ${CLOUD_INIT_BUILD_DIR}/user-data #
     ${CLOUD_INIT_BUILD_DIR}/meta-data #
     ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-compute.sh
)

# --- Packer Operations ---
# Initialize Packer plugins
set(INIT_PACKER_TOKEN ${CMAKE_CURRENT_BINARY_DIR}/hpc-compute-init-packer.token)

add_custom_command(
    OUTPUT ${INIT_PACKER_TOKEN}
    COMMAND flock ${PACKER_INIT_LOCK_FILE} -c "packer init --force hpc-compute.pkr.hcl"
    COMMAND date > ${INIT_PACKER_TOKEN}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS generate-shared-ssh-keys generate-packer-vars-hpc-compute
    COMMENT "Initializing HPC Compute Packer plugins..."
)

add_custom_target(init-hpc-compute-packer
    DEPENDS ${INIT_PACKER_TOKEN}
)

# Validate Packer template (using temporary output directory to avoid conflicts)
add_custom_target(validate-hpc-compute-packer
    COMMAND flock ${PACKER_INIT_LOCK_FILE} -c "packer init --force hpc-compute.pkr.hcl"
    COMMAND packer validate
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-compute.pkrvars.hcl
            ${PACKER_VARS}
            -var "build_directory=${CMAKE_CURRENT_BINARY_DIR}/validate-tmp"
            hpc-compute.pkr.hcl
    COMMAND rm -rf ${CMAKE_CURRENT_BINARY_DIR}/validate-tmp
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS generate-packer-vars-hpc-compute prepare-cloud-init-hpc-compute build-beegfs-packages build-slurm-packages
    COMMENT "Initializing plugins and validating HPC Compute Packer template..."
)

# Format Packer template
add_custom_target(format-hpc-compute-packer
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer fmt hpc-compute.pkr.hcl
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Formatting HPC Compute Packer template..."
)

# --- Image Build Targets ---
# Packer build arguments (conditional - only force if explicitly requested)
set(PACKER_BUILD_ARGS "")

# Build HPC compute image (only if output doesn't exist)
add_custom_command(
    OUTPUT ${HPC_OUTPUT_DIR}/${VM_NAME}
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer validate
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-compute.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/hpc-compute.pkr.hcl
    COMMAND packer build ${PACKER_BUILD_ARGS}
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-compute.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/hpc-compute.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Building HPC compute image..."
    DEPENDS prepare-cloud-init-hpc-compute
        ${CMAKE_CURRENT_SOURCE_DIR}/hpc-compute.pkr.hcl
        init-hpc-compute-packer
        generate-packer-vars-hpc-compute
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-compute.sh
        build-beegfs-packages
        build-slurm-packages
    USES_TERMINAL
    VERBATIM
)

# Target to build the image
add_custom_target(build-hpc-compute-image
    DEPENDS ${HPC_OUTPUT_DIR}/${VM_NAME}
)

# Force rebuild target (always rebuilds)
add_custom_target(build-force-hpc-compute-image
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer validate
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-compute.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/hpc-compute.pkr.hcl
    COMMAND packer build -force
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-compute.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/hpc-compute.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Force rebuilding HPC compute image..."
    DEPENDS prepare-cloud-init-hpc-compute
        ${CMAKE_CURRENT_SOURCE_DIR}/hpc-compute.pkr.hcl
        init-hpc-compute-packer
        generate-packer-vars-hpc-compute
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-compute.sh
        build-beegfs-packages
        build-slurm-packages
    USES_TERMINAL
    VERBATIM
)

# --- Cleanup Targets ---
# Clean target (removes generated image)
add_custom_target(clean-hpc-compute-image
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMENT "Cleaning HPC compute image..."
    VERBATIM
)
