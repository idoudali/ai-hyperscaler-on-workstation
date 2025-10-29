# Cloud GPU Worker Image CMake Configuration
# ==========================================
#
# This CMakeLists.txt configures the build for the Cloud GPU Worker VM image.
# The Cloud GPU Worker image is designed for GPU-accelerated workloads in cloud
# environments, with GPU drivers and runtime libraries pre-installed and configured.
#
# Build Process:
# - Downloads Debian cloud image
# - Generates cloud-init configuration
# - Prepares Packer variables and dependencies
# - Builds QEMU-based VM image using Packer
#
# Usage:
#   cmake --build build --target build-cloud-gpu-worker-image
#   cmake --build build --target build-force-cloud-gpu-worker-image  # Force rebuild
#
# Available Targets:
#   - build-cloud-gpu-worker-image: Build the cloud GPU worker image
#   - build-force-cloud-gpu-worker-image: Force rebuild the image
#   - init-cloud-gpu-worker-packer: Initialize Packer plugins
#   - validate-cloud-gpu-worker-packer: Validate Packer template
#   - format-cloud-gpu-worker-packer: Format Packer template
#   - clean-cloud-gpu-worker-image: Remove generated image files
#
# Dependencies:
#   - Shared SSH keys (generate-shared-ssh-keys)

cmake_minimum_required(VERSION 3.18)

# --- Image Configuration ---
# Define Packer variables
set(IMAGE_NAME "cloud-gpu-worker")
set(VM_NAME "cloud-gpu-worker.qcow2")
set(DISK_SIZE "30G")
set(MEMORY "4096")
set(CPUS "4")

# SSH username to be used by Packer communicator and Ansible (must match cloud-init user)
set(SSH_USERNAME "admin" CACHE STRING "SSH username for image provisioning")

# --- Directory Setup ---
# Set output directory for the image
set(CLOUD_GPU_WORKER_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/cloud-gpu-worker")

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
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/cloud-gpu-worker.pkrvars.hcl
    COMMAND sh -c "echo 'debian_cloud_image_checksum = \"'$(cat ${DEBIAN_CLOUD_IMAGE_CHECKSUM_FILE})'\"' > ${CMAKE_CURRENT_BINARY_DIR}/cloud-gpu-worker.pkrvars.hcl"
    DEPENDS prepare-debian-checksum
    COMMENT "Generating Packer variables file for cloud-gpu-worker..."
    VERBATIM
)

add_custom_target(generate-packer-vars-cloud-gpu-worker
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/cloud-gpu-worker.pkrvars.hcl
)

# --- Packer Configuration ---
# Packer variable arguments
set(PACKER_VARS
    -var "source_directory=${CMAKE_CURRENT_SOURCE_DIR}"
    -var "repo_tot_dir=${CMAKE_CURRENT_SOURCE_DIR}/../.."
    -var "build_directory=${CLOUD_GPU_WORKER_OUTPUT_DIR}"
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
# Prepare cloud-init configuration for cloud-gpu-worker

add_custom_command(
    OUTPUT ${CLOUD_INIT_BUILD_DIR}/user-data ${CLOUD_INIT_BUILD_DIR}/meta-data
    COMMAND ${COMMON_SCRIPTS_DIR}/prepare-cloud-init.sh ${SSH_KEYS_DIR} ${CLOUD_INIT_BUILD_DIR} cloud-gpu-worker
    COMMENT "Preparing cloud-init configuration for cloud-gpu-worker..."
    DEPENDS generate-shared-ssh-keys
        ${COMMON_SCRIPTS_DIR}/prepare-cloud-init.sh
        ${CMAKE_CURRENT_SOURCE_DIR}/../common/cloud-init/cloud-gpu-worker-user-data.yml
        ${CMAKE_CURRENT_SOURCE_DIR}/../common/cloud-init/cloud-gpu-worker-meta-data.yml
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-gpu-worker.sh
    VERBATIM
)

# Target to prepare cloud-init files
add_custom_target(prepare-cloud-init-cloud-gpu-worker
    DEPENDS ${CLOUD_INIT_BUILD_DIR}/user-data #
     ${CLOUD_INIT_BUILD_DIR}/meta-data #
     ${CMAKE_CURRENT_SOURCE_DIR}/setup-gpu-worker.sh
)

# --- Packer Operations ---
# Initialize Packer plugins
set(INIT_PACKER_TOKEN ${CMAKE_CURRENT_BINARY_DIR}/cloud-gpu-worker-init-packer.token)

add_custom_command(
    OUTPUT ${INIT_PACKER_TOKEN}
    COMMAND flock ${PACKER_INIT_LOCK_FILE} -c "packer init --force cloud-gpu-worker.pkr.hcl"
    COMMAND date > ${INIT_PACKER_TOKEN}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS generate-shared-ssh-keys generate-packer-vars-cloud-gpu-worker
    COMMENT "Initializing Cloud GPU Worker Packer plugins..."
)

add_custom_target(init-cloud-gpu-worker-packer
    DEPENDS ${INIT_PACKER_TOKEN}
)

# Validate Packer template (using temporary output directory to avoid conflicts)
add_custom_target(validate-cloud-gpu-worker-packer
    COMMAND flock ${PACKER_INIT_LOCK_FILE} -c "packer init --force cloud-gpu-worker.pkr.hcl"
    COMMAND packer validate
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/cloud-gpu-worker.pkrvars.hcl
            ${PACKER_VARS}
            -var "build_directory=${CMAKE_CURRENT_BINARY_DIR}/validate-tmp"
            cloud-gpu-worker.pkr.hcl
    COMMAND rm -rf ${CMAKE_CURRENT_BINARY_DIR}/validate-tmp
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS generate-packer-vars-cloud-gpu-worker prepare-cloud-init-cloud-gpu-worker
    COMMENT "Initializing plugins and validating Cloud GPU Worker Packer template..."
)

# Format Packer template
add_custom_target(format-cloud-gpu-worker-packer
    COMMAND rm -rf ${CLOUD_GPU_WORKER_OUTPUT_DIR}
    COMMAND packer fmt cloud-gpu-worker.pkr.hcl
    COMMAND rm -rf ${CLOUD_GPU_WORKER_OUTPUT_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Formatting Cloud GPU Worker Packer template..."
)

# --- Image Build Targets ---
# Packer build arguments (conditional - only force if explicitly requested)
set(PACKER_BUILD_ARGS "")

# Build cloud GPU worker image (only if output doesn't exist)
add_custom_command(
    OUTPUT ${CLOUD_GPU_WORKER_OUTPUT_DIR}/${VM_NAME}
    COMMAND rm -rf ${CLOUD_GPU_WORKER_OUTPUT_DIR}
    COMMAND packer validate
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/cloud-gpu-worker.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/cloud-gpu-worker.pkr.hcl
    COMMAND packer build ${PACKER_BUILD_ARGS}
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/cloud-gpu-worker.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/cloud-gpu-worker.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Building cloud GPU worker image..."
    DEPENDS prepare-cloud-init-cloud-gpu-worker
        ${CMAKE_CURRENT_SOURCE_DIR}/cloud-gpu-worker.pkr.hcl
        init-cloud-gpu-worker-packer
        generate-packer-vars-cloud-gpu-worker
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-gpu-worker.sh
    USES_TERMINAL
    VERBATIM
)

# Target to build the image
add_custom_target(build-cloud-gpu-worker-image
    DEPENDS ${CLOUD_GPU_WORKER_OUTPUT_DIR}/${VM_NAME}
)

# Force rebuild target (always rebuilds)
add_custom_target(build-force-cloud-gpu-worker-image
    COMMAND rm -rf ${CLOUD_GPU_WORKER_OUTPUT_DIR}
    COMMAND packer validate
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/cloud-gpu-worker.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/cloud-gpu-worker.pkr.hcl
    COMMAND packer build -force
            -var-file=${CMAKE_CURRENT_BINARY_DIR}/cloud-gpu-worker.pkrvars.hcl
            ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/cloud-gpu-worker.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Force rebuilding cloud GPU worker image..."
    DEPENDS prepare-cloud-init-cloud-gpu-worker
        ${CMAKE_CURRENT_SOURCE_DIR}/cloud-gpu-worker.pkr.hcl
        init-cloud-gpu-worker-packer
        generate-packer-vars-cloud-gpu-worker
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-gpu-worker.sh
    USES_TERMINAL
    VERBATIM
)

# --- Cleanup Targets ---
# Clean target (removes generated image)
add_custom_target(clean-cloud-gpu-worker-image
    COMMAND rm -rf ${CLOUD_GPU_WORKER_OUTPUT_DIR}
    COMMENT "Cleaning cloud GPU worker image..."
    VERBATIM
)
