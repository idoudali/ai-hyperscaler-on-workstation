# HPC Controller Image CMake Configuration
cmake_minimum_required(VERSION 3.18)

# Define Packer variables
set(IMAGE_NAME "hpc-controller")
set(VM_NAME "hpc-controller.qcow2")
set(DISK_SIZE "20G")
set(MEMORY "2048")
set(CPUS "2")

# SSH username to be used by Packer communicator and Ansible (must match cloud-init user)
set(SSH_USERNAME "admin" CACHE STRING "SSH username for image provisioning")


# Set output directory for the image
set(HPC_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/hpc-controller")

# Use shared SSH keys directory (managed by parent CMakeLists.txt)
set(SSH_KEYS_DIR "${CMAKE_BINARY_DIR}/shared/ssh-keys")

# Set up cloud-init build directory
set(CLOUD_INIT_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/cloud-init")
file(MAKE_DIRECTORY ${CLOUD_INIT_BUILD_DIR})

# Common scripts directory
set(COMMON_SCRIPTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../common/scripts")


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
)



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
    DEPENDS ${CLOUD_INIT_BUILD_DIR}/user-data ${CLOUD_INIT_BUILD_DIR}/meta-data
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-controller.sh
)

# Initialize Packer plugins
add_custom_target(init-hpc-controller-packer
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer init --force hpc-controller.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS generate-shared-ssh-keys generate-packer-vars-hpc-controller
    COMMENT "Initializing HPC Controller Packer plugins..."
)

# Validate Packer template
add_custom_target(validate-hpc-controller-packer
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer validate -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-controller.pkrvars.hcl ${PACKER_VARS} hpc-controller.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS init-hpc-controller-packer generate-packer-vars-hpc-controller
    COMMENT "Validating HPC Controller Packer template..."
)

# Format Packer template
add_custom_target(format-hpc-controller-packer
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer fmt hpc-controller.pkr.hcl
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Formatting HPC Controller Packer template..."
)

# Packer build arguments (simplified)
set(PACKER_BUILD_ARGS -force)

# Build HPC controller image
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
    USES_TERMINAL
    VERBATIM
)

# Target to build the image
add_custom_target(build-hpc-controller-image
    DEPENDS ${HPC_OUTPUT_DIR}/${VM_NAME}
)
