# Cloud GPU Worker Image CMake Configuration
cmake_minimum_required(VERSION 3.18)

# Define Packer variables
set(IMAGE_NAME "cloud-gpu-worker")
set(VM_NAME "cloud-gpu-worker.qcow2")
set(DISK_SIZE "30G")
set(MEMORY "4096")
set(CPUS "4")

# SSH username to be used by Packer communicator and Ansible (must match cloud-init user)
set(SSH_USERNAME "admin" CACHE STRING "SSH username for image provisioning")


# Set output directory for the image
set(CLOUD_GPU_WORKER_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/cloud-gpu-worker")

# Use shared SSH keys directory (managed by parent CMakeLists.txt)
set(SSH_KEYS_DIR "${CMAKE_BINARY_DIR}/shared/ssh-keys")

# Set up cloud-init build directory
set(CLOUD_INIT_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/cloud-init")
file(MAKE_DIRECTORY ${CLOUD_INIT_BUILD_DIR})

# Common scripts directory
set(COMMON_SCRIPTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../common/scripts")

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
    DEPENDS ${CLOUD_INIT_BUILD_DIR}/user-data ${CLOUD_INIT_BUILD_DIR}/meta-data
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-gpu-worker.sh
)

# Initialize Packer plugins
add_custom_target(init-cloud-gpu-worker-packer
    COMMAND rm -rf ${CLOUD_GPU_WORKER_OUTPUT_DIR}
    COMMAND packer init --force cloud-gpu-worker.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS generate-shared-ssh-keys generate-packer-vars-cloud-gpu-worker
    COMMENT "Initializing Cloud GPU Worker Packer plugins..."
)

# Validate Packer template
add_custom_target(validate-cloud-gpu-worker-packer
    COMMAND rm -rf ${CLOUD_GPU_WORKER_OUTPUT_DIR}
    COMMAND packer validate -var-file=${CMAKE_CURRENT_BINARY_DIR}/cloud-gpu-worker.pkrvars.hcl ${PACKER_VARS} cloud-gpu-worker.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS init-cloud-gpu-worker-packer generate-packer-vars-cloud-gpu-worker prepare-cloud-init-cloud-gpu-worker
    COMMENT "Validating Cloud GPU Worker Packer template..."
)

# Format Packer template
add_custom_target(format-cloud-gpu-worker-packer
    COMMAND rm -rf ${CLOUD_GPU_WORKER_OUTPUT_DIR}
    COMMAND packer fmt cloud-gpu-worker.pkr.hcl
    COMMAND rm -rf ${CLOUD_GPU_WORKER_OUTPUT_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Formatting Cloud GPU Worker Packer template..."
)

# Packer build arguments (simplified)
set(PACKER_BUILD_ARGS -force)

# Build cloud GPU worker image
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
