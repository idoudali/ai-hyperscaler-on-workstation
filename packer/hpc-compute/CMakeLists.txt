# HPC Compute Image CMake Configuration
cmake_minimum_required(VERSION 3.18)

# Define Packer variables
set(IMAGE_NAME "hpc-compute")
set(VM_NAME "hpc-compute.qcow2")
set(DISK_SIZE "40G")
set(MEMORY "2048")
set(CPUS "2")

# SSH username to be used by Packer communicator and Ansible (must match cloud-init user)
set(SSH_USERNAME "admin" CACHE STRING "SSH username for image provisioning")


# Set output directory for the image
set(HPC_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/hpc-compute")

# Use shared SSH keys directory (managed by parent CMakeLists.txt)
set(SSH_KEYS_DIR "${CMAKE_BINARY_DIR}/shared/ssh-keys")

# Set up cloud-init build directory
set(CLOUD_INIT_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/cloud-init")
file(MAKE_DIRECTORY ${CLOUD_INIT_BUILD_DIR})

# Common scripts directory
set(COMMON_SCRIPTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../common/scripts")


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
    DEPENDS ${CLOUD_INIT_BUILD_DIR}/user-data ${CLOUD_INIT_BUILD_DIR}/meta-data
        ${CMAKE_CURRENT_SOURCE_DIR}/setup-hpc-compute.sh
)

# Initialize Packer plugins
add_custom_target(init-hpc-compute-packer
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer init --force hpc-compute.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS generate-shared-ssh-keys generate-packer-vars-hpc-compute
    COMMENT "Initializing HPC Compute Packer plugins..."
)

# Validate Packer template
add_custom_target(validate-hpc-compute-packer
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer validate -var-file=${CMAKE_CURRENT_BINARY_DIR}/hpc-compute.pkrvars.hcl ${PACKER_VARS} hpc-compute.pkr.hcl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS init-hpc-compute-packer generate-packer-vars-hpc-compute prepare-cloud-init-hpc-compute build-beegfs-packages build-slurm-packages
    COMMENT "Validating HPC Compute Packer template..."
)

# Format Packer template
add_custom_target(format-hpc-compute-packer
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    COMMAND packer fmt hpc-compute.pkr.hcl
    COMMAND rm -rf ${HPC_OUTPUT_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Formatting HPC Compute Packer template..."
)

# Packer build arguments (simplified)
set(PACKER_BUILD_ARGS -force)

# Build HPC compute image
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
