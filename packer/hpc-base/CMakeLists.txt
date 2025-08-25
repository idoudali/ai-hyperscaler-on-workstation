# HPC Base Image CMake Configuration
cmake_minimum_required(VERSION 3.18)

# Define Packer variables
set(IMAGE_NAME "hpc-base")
set(VM_NAME "hpc-base.qcow2")
set(DISK_SIZE "20G")
set(MEMORY "2048")
set(CPUS "2")


# Set output directory for the image
set(HPC_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/hpc-base")

# Use shared SSH keys directory (managed by parent CMakeLists.txt)
set(SSH_KEYS_DIR "${CMAKE_BINARY_DIR}/shared/ssh-keys")

# Set up cloud-init build directory
set(CLOUD_INIT_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/cloud-init")
file(MAKE_DIRECTORY ${CLOUD_INIT_BUILD_DIR})

# Common scripts directory
set(COMMON_SCRIPTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../common/scripts")


# Read the checksum from file to pass to Packer
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/hpc-base.pkrvars.hcl
    COMMAND sh -c "echo 'debian_cloud_image_checksum = \"'$(cat ${DEBIAN_CLOUD_IMAGE_CHECKSUM_FILE})'\"' > ${CMAKE_CURRENT_BINARY_DIR}/hpc-base.pkrvars.hcl"
    DEPENDS prepare-debian-checksum
    COMMENT "Generating Packer variables file for hpc-base..."
    VERBATIM
)

add_custom_target(generate-packer-vars-hpc-base
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/hpc-base.pkrvars.hcl
)

# Packer variable arguments
set(PACKER_VARS
    -var "source_directory=${CMAKE_CURRENT_SOURCE_DIR}"
    -var "build_directory=${HPC_OUTPUT_DIR}"
    -var "image_name=${IMAGE_NAME}"
    -var "vm_name=${VM_NAME}"
    -var "disk_size=${DISK_SIZE}"
    -var "memory=${MEMORY}"
    -var "cpus=${CPUS}"
    -var "debian_cloud_image_url=${DEBIAN_CLOUD_IMAGE_URL}"
    -var "cloud_init_dir=${CLOUD_INIT_BUILD_DIR}"
    -var "ssh_keys_dir=${SSH_KEYS_DIR}"
)



# Prepare cloud-init configuration for hpc-base
add_custom_command(
    OUTPUT ${CLOUD_INIT_BUILD_DIR}/user-data ${CLOUD_INIT_BUILD_DIR}/meta-data
    COMMAND ${COMMON_SCRIPTS_DIR}/prepare-cloud-init.sh ${SSH_KEYS_DIR} ${CLOUD_INIT_BUILD_DIR} hpc-base
    COMMENT "Preparing cloud-init configuration for hpc-base..."
    DEPENDS generate-shared-ssh-keys
        ${COMMON_SCRIPTS_DIR}/prepare-cloud-init.sh
        ${CMAKE_CURRENT_SOURCE_DIR}/../common/cloud-init/hpc-base-user-data.yml
        ${CMAKE_CURRENT_SOURCE_DIR}/../common/cloud-init/hpc-base-meta-data.yml
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-base.sh
    VERBATIM
)

# Target to prepare cloud-init files
add_custom_target(prepare-cloud-init-hpc-base
    DEPENDS ${CLOUD_INIT_BUILD_DIR}/user-data ${CLOUD_INIT_BUILD_DIR}/meta-data
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-base.sh
)

# Initialize Packer plugins
add_custom_target(init-hpc-packer
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer init hpc-base.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS generate-shared-ssh-keys generate-packer-vars-hpc-base
    COMMENT "Initializing HPC Packer plugins..."
)

# Validate Packer template
add_custom_target(validate-hpc-packer
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer validate -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-base.pkrvars.hcl ${PACKER_VARS} hpc-base.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS init-hpc-packer generate-packer-vars-hpc-base
    COMMENT "Validating HPC Packer template..."
)

# Format Packer template
add_custom_target(format-hpc-packer
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer fmt hpc-base.pkr.hcl
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Formatting HPC Packer template..."
)

# Build HPC base image
add_custom_command(
    OUTPUT ${HPC_OUTPUT_DIR}/${VM_NAME}
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer validate -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-base.pkrvars.hcl ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/hpc-base.pkr.hcl
    COMMAND PACKER_LOG=1 packer build -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-base.pkrvars.hcl ${PACKER_VARS} ${CMAKE_CURRENT_SOURCE_DIR}/hpc-base.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Building HPC base image..."
    DEPENDS prepare-cloud-init-hpc-base
        ${CMAKE_CURRENT_SOURCE_DIR}/hpc-base.pkr.hcl
        init-hpc-packer
        generate-packer-vars-hpc-base
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-base.sh
    USES_TERMINAL
    VERBATIM
)

# Target to build the image
add_custom_target(build-hpc-image
    DEPENDS ${HPC_OUTPUT_DIR}/${VM_NAME}
)
