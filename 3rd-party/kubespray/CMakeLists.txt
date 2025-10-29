# Kubespray Integration Configuration
cmake_minimum_required(VERSION 3.18)

# Kubespray version configuration
set(KUBESPRAY_VERSION "v2.29.0" CACHE STRING "Kubespray version/tag to checkout")
set(KUBESPRAY_GIT_REPO "https://github.com/kubernetes-sigs/kubespray.git" CACHE STRING "Kubespray Git repository URL")

# Build directories
set(KUBESPRAY_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/kubespray-src")

# Clone Kubespray source repository
add_custom_command(
    OUTPUT ${KUBESPRAY_SOURCE_DIR}/.git/config
    COMMAND rm -rf ${KUBESPRAY_SOURCE_DIR}
    COMMAND git clone ${KUBESPRAY_GIT_REPO} ${KUBESPRAY_SOURCE_DIR}
    COMMAND cd ${KUBESPRAY_SOURCE_DIR} && git checkout ${KUBESPRAY_VERSION}
    COMMENT "Cloning Kubespray source repository (version ${KUBESPRAY_VERSION})..."
    VERBATIM
)

add_custom_target(clone-kubespray-source
    DEPENDS ${KUBESPRAY_SOURCE_DIR}/.git/config
)

# Install Kubespray Python dependencies (optional, for local testing)
# Note: Kubespray requirements are typically handled by Ansible
add_custom_target(install-kubespray
    DEPENDS clone-kubespray-source
    COMMAND ${CMAKE_COMMAND} -E echo "Kubespray installed to: ${KUBESPRAY_SOURCE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E echo "Version: ${KUBESPRAY_VERSION}"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Next steps:"
    COMMAND ${CMAKE_COMMAND} -E echo "  1. Generate inventory: ai-how cloud generate-inventory config.yaml"
    COMMAND ${CMAKE_COMMAND} -E echo "  2. Deploy cluster: ansible-playbook -i inventories/cloud-cluster/inventory.ini build/3rd-party/kubespray/kubespray-src/cluster.yml"
    COMMENT "Installing Kubespray (version ${KUBESPRAY_VERSION})..."
    VERBATIM
)

# List Kubespray information
add_custom_target(list-kubespray-info
    DEPENDS clone-kubespray-source
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
    COMMAND ${CMAKE_COMMAND} -E echo "  Kubespray Integration Information"
    COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Configuration:"
    COMMAND ${CMAKE_COMMAND} -E echo "  Version:          ${KUBESPRAY_VERSION}"
    COMMAND ${CMAKE_COMMAND} -E echo "  Source Dir:       ${KUBESPRAY_SOURCE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E echo "  Repository:       ${KUBESPRAY_GIT_REPO}"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Available files:"
    COMMAND bash -c "ls -lh ${KUBESPRAY_SOURCE_DIR}/*.yml 2>/dev/null | head -5 || echo '  (run install-kubespray first)'"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    VERBATIM
)

# Clean Kubespray
add_custom_target(clean-kubespray
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${KUBESPRAY_SOURCE_DIR}
    COMMENT "Cleaning Kubespray source directory..."
    VERBATIM
)

# Add informational target
add_custom_target(help-kubespray
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
    COMMAND ${CMAKE_COMMAND} -E echo "  Kubespray Integration Targets"
    COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Available targets:"
    COMMAND ${CMAKE_COMMAND} -E echo "  install-kubespray    - Clone and install Kubespray"
    COMMAND ${CMAKE_COMMAND} -E echo "  list-kubespray-info  - Show Kubespray information"
    COMMAND ${CMAKE_COMMAND} -E echo "  clean-kubespray      - Clean Kubespray source directory"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Configuration:"
    COMMAND ${CMAKE_COMMAND} -E echo "  Version:        ${KUBESPRAY_VERSION}"
    COMMAND ${CMAKE_COMMAND} -E echo "  Source Dir:     ${KUBESPRAY_SOURCE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Usage:"
    COMMAND ${CMAKE_COMMAND} -E echo "  cmake --build build --target install-kubespray"
    COMMAND ${CMAKE_COMMAND} -E echo "  make run-docker COMMAND=\"cmake --build build --target install-kubespray\""
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Documentation:"
    COMMAND ${CMAKE_COMMAND} -E echo "  https://kubespray.io/"
    COMMAND ${CMAKE_COMMAND} -E echo "  https://github.com/kubernetes-sigs/kubespray"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    VERBATIM
)
