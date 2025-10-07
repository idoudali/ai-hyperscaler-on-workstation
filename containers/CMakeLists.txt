# Container Images CMake Configuration
cmake_minimum_required(VERSION 3.18)

# --- Check for required tools ---
find_program(DOCKER_EXECUTABLE docker)
if(NOT DOCKER_EXECUTABLE)
    message(WARNING "Docker executable not found. Docker build targets will fail if executed.")
else()
    message(STATUS "Found Docker: ${DOCKER_EXECUTABLE}")
endif()

find_program(APPTAINER_EXECUTABLE apptainer)
if(NOT APPTAINER_EXECUTABLE)
    message(WARNING "Apptainer executable not found. Apptainer conversion targets will fail if executed.")
else()
    message(STATUS "Found Apptainer: ${APPTAINER_EXECUTABLE}")
endif()

find_program(UV_EXECUTABLE uv)
if(NOT UV_EXECUTABLE)
    message(FATAL_ERROR "uv executable not found. Please install uv: https://docs.astral.sh/uv/")
endif()
message(STATUS "Found uv: ${UV_EXECUTABLE}")

# --- Create build output directories ---
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/containers)
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/containers/docker)
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/containers/apptainer)
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/containers/venv)

# --- Set up paths ---
set(CONTAINERS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
set(CONTAINERS_BUILD_DIR "${CMAKE_BINARY_DIR}/containers")
set(DOCKER_BUILD_DIR "${CONTAINERS_BUILD_DIR}/docker")
set(APPTAINER_BUILD_DIR "${CONTAINERS_BUILD_DIR}/apptainer")
set(VENV_DIR "${CONTAINERS_BUILD_DIR}/venv")

# --- Python Virtual Environment Setup ---
# Create virtual environment and install container tools
add_custom_command(
    OUTPUT ${VENV_DIR}/bin/activate
    COMMAND python3 -m venv ${VENV_DIR}
    COMMENT "Creating Python virtual environment for container tools..."
    VERBATIM
)

# Install container tools dependencies in the virtual environment using uv
add_custom_command(
    OUTPUT ${VENV_DIR}/.container-tools-installed
    COMMAND ${UV_EXECUTABLE} pip install --python ${VENV_DIR}/bin/python -r ${CONTAINERS_SOURCE_DIR}/requirements.txt
    COMMAND ${CMAKE_COMMAND} -E touch ${VENV_DIR}/.container-tools-installed
    DEPENDS ${VENV_DIR}/bin/activate #
    ${CONTAINERS_SOURCE_DIR}/requirements.txt
    COMMENT "Installing container tools in virtual environment (using uv)..."
    VERBATIM
)

# Target to set up container tools environment
add_custom_target(setup-container-tools
    DEPENDS ${VENV_DIR}/.container-tools-installed
)

# --- HPC Container Manager CLI Setup ---
# Create symlink to CLI tool
add_custom_command(
    OUTPUT ${VENV_DIR}/bin/hpc-container-manager
    COMMAND ${CMAKE_COMMAND} -E create_symlink
            ${CONTAINERS_SOURCE_DIR}/tools/cli/hpc-container-manager
            ${VENV_DIR}/bin/hpc-container-manager
    COMMAND chmod +x ${VENV_DIR}/bin/hpc-container-manager
    DEPENDS setup-container-tools
    COMMENT "Creating HPC container manager CLI symlink..."
    VERBATIM
)

add_custom_target(setup-hpc-cli
    DEPENDS ${VENV_DIR}/bin/hpc-container-manager
    setup-container-tools
)

# --- Container Extension Discovery ---
# Find all container extensions in images/
file(GLOB CONTAINER_EXTENSION_DIRS
     LIST_DIRECTORIES true
     ${CONTAINERS_SOURCE_DIR}/images/*/Docker
)

# Extract container names from paths
set(CONTAINER_NAMES "")
foreach(DOCKER_DIR ${CONTAINER_EXTENSION_DIRS})
    get_filename_component(CONTAINER_NAME ${DOCKER_DIR} DIRECTORY)
    get_filename_component(CONTAINER_NAME ${CONTAINER_NAME} NAME)
    list(APPEND CONTAINER_NAMES ${CONTAINER_NAME})
endforeach()

message(STATUS "Found container extensions: ${CONTAINER_NAMES}")

# --- Docker Image Build Targets ---
foreach(CONTAINER_NAME ${CONTAINER_NAMES})
    # Gather all input files for the Docker image (Dockerfile and context)
    file(GLOB_RECURSE CONTAINER_DOCKER_INPUT_FILES
         ${CONTAINERS_SOURCE_DIR}/images/${CONTAINER_NAME}/Docker/*)

    # Build Docker image command (creates a stamp file to track builds)
    add_custom_command(
        OUTPUT ${DOCKER_BUILD_DIR}/${CONTAINER_NAME}.stamp
        COMMAND ${DOCKER_EXECUTABLE} build
                -t ${CONTAINER_NAME}:latest
                ${CONTAINERS_SOURCE_DIR}/images/${CONTAINER_NAME}/Docker/
        COMMAND ${CMAKE_COMMAND} -E touch ${DOCKER_BUILD_DIR}/${CONTAINER_NAME}.stamp
        DEPENDS ${VENV_DIR}/.container-tools-installed
                ${CONTAINER_DOCKER_INPUT_FILES}
        WORKING_DIRECTORY ${CONTAINERS_SOURCE_DIR}
        COMMENT "Building Docker image: ${CONTAINER_NAME}"
        USES_TERMINAL
        VERBATIM
    )

    # Target for the Docker build (depends on the stamp file)
    add_custom_target(build-docker-${CONTAINER_NAME}
        DEPENDS ${DOCKER_BUILD_DIR}/${CONTAINER_NAME}.stamp
        COMMENT "Ensuring Docker image ${CONTAINER_NAME} is built"
    )

    # Test Docker image target
    add_custom_target(test-docker-${CONTAINER_NAME}
        COMMAND ${DOCKER_EXECUTABLE} run --rm ${CONTAINER_NAME}:latest python3 --version
        DEPENDS build-docker-${CONTAINER_NAME}
        WORKING_DIRECTORY ${CONTAINERS_SOURCE_DIR}
        COMMENT "Testing Docker image: ${CONTAINER_NAME}"
        VERBATIM
    )
endforeach()

# Aggregate target to build all Docker images
set(ALL_DOCKER_TARGETS "")
foreach(CONTAINER_NAME ${CONTAINER_NAMES})
    list(APPEND ALL_DOCKER_TARGETS build-docker-${CONTAINER_NAME})
endforeach()

add_custom_target(build-all-docker-images
    DEPENDS ${ALL_DOCKER_TARGETS}
    COMMENT "Building all Docker images..."
)

# --- Apptainer Conversion Targets ---
foreach(CONTAINER_NAME ${CONTAINER_NAMES})
    # Convert Docker to Apptainer command (outputs .sif file)
    # Depends on the Docker stamp file to ensure Docker image is built first
    add_custom_command(
        OUTPUT ${APPTAINER_BUILD_DIR}/${CONTAINER_NAME}.sif
        COMMAND bash -c "source ${VENV_DIR}/bin/activate && \
            PYTHONPATH=${CONTAINERS_SOURCE_DIR}/tools:${PYTHONPATH} \
            ${VENV_DIR}/bin/hpc-container-manager convert to-apptainer --force \
            ${CONTAINER_NAME}:latest ${APPTAINER_BUILD_DIR}/${CONTAINER_NAME}.sif"
        DEPENDS ${VENV_DIR}/bin/hpc-container-manager
                ${DOCKER_BUILD_DIR}/${CONTAINER_NAME}.stamp
        WORKING_DIRECTORY ${CONTAINERS_SOURCE_DIR}
        COMMENT "Converting ${CONTAINER_NAME} to Apptainer..."
        VERBATIM
    )

    # Target for the conversion (depends on the .sif file)
    add_custom_target(convert-to-apptainer-${CONTAINER_NAME}
        DEPENDS ${APPTAINER_BUILD_DIR}/${CONTAINER_NAME}.sif
        COMMENT "Ensuring ${CONTAINER_NAME} is converted to Apptainer"
    )

    # Test Apptainer image target
    add_custom_target(test-apptainer-${CONTAINER_NAME}
        COMMAND ${VENV_DIR}/bin/hpc-container-manager
                test ${APPTAINER_BUILD_DIR}/${CONTAINER_NAME}.sif
        DEPENDS convert-to-apptainer-${CONTAINER_NAME} setup-hpc-cli
        WORKING_DIRECTORY ${CONTAINERS_SOURCE_DIR}
        COMMENT "Testing Apptainer image: ${CONTAINER_NAME}"
        VERBATIM
    )
endforeach()

# Aggregate target to convert all images
set(ALL_APPTAINER_TARGETS "")
foreach(CONTAINER_NAME ${CONTAINER_NAMES})
    list(APPEND ALL_APPTAINER_TARGETS convert-to-apptainer-${CONTAINER_NAME})
endforeach()

add_custom_target(convert-all-to-apptainer
    DEPENDS ${ALL_APPTAINER_TARGETS}
    COMMENT "Converting all Docker images to Apptainer..."
)

# --- Complete Container Workflow Targets ---
foreach(CONTAINER_NAME ${CONTAINER_NAMES})
    # Complete workflow: Build Docker + Convert to Apptainer
    add_custom_target(build-container-${CONTAINER_NAME}
        DEPENDS build-docker-${CONTAINER_NAME} convert-to-apptainer-${CONTAINER_NAME}
        COMMENT "Complete container workflow for ${CONTAINER_NAME}"
    )
endforeach()

# Build all containers (complete workflow)
set(ALL_CONTAINER_WORKFLOW_TARGETS "")
foreach(CONTAINER_NAME ${CONTAINER_NAMES})
    list(APPEND ALL_CONTAINER_WORKFLOW_TARGETS build-container-${CONTAINER_NAME})
endforeach()

add_custom_target(build-all-containers
    DEPENDS ${ALL_CONTAINER_WORKFLOW_TARGETS}
    COMMENT "Building all containers (Docker + Apptainer)..."
)

# --- Cleanup Targets ---
add_custom_target(clean-docker-images
    COMMAND ${DOCKER_EXECUTABLE} image prune -f
    COMMAND rm -rf ${DOCKER_BUILD_DIR}/*
    COMMENT "Cleaning Docker images and build directory..."
)

add_custom_target(clean-apptainer-images
    COMMAND rm -rf ${APPTAINER_BUILD_DIR}/*
    COMMENT "Cleaning Apptainer images..."
)

add_custom_target(clean-container-venv
    COMMAND rm -rf ${VENV_DIR}
    COMMENT "Cleaning container virtual environment..."
)

add_custom_target(clean-all-containers
    DEPENDS clean-docker-images clean-apptainer-images clean-container-venv
    COMMENT "Cleaning all container artifacts..."
)

# --- Task 020: Conversion Workflow Scripts ---
# Test convert-single.sh script correctness
add_custom_target(test-convert-single-script
    COMMAND ${CMAKE_SOURCE_DIR}/containers/scripts/test-convert-single-correctness.sh
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Testing convert-single.sh script correctness and functionality..."
    USES_TERMINAL
)

add_custom_target(test-apptainer-local-script
    COMMAND ${CMAKE_SOURCE_DIR}/containers/scripts/test-apptainer-local-correctness.sh
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Testing test-apptainer-local.sh script correctness and functionality..."
    USES_TERMINAL
)

# Combined Task 020 script validation
add_custom_target(test-conversion-scripts
    DEPENDS test-convert-single-script test-apptainer-local-script
    COMMENT "Testing all Task 020 conversion workflow scripts..."
)

# Task 020 help target
add_custom_target(help-task-020
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "=== Task 020: Docker to Apptainer Conversion Workflow ==="
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Script Validation - No images required:"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-convert-single-script    - Validate convert-single.sh - 7 tests"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-apptainer-local-script   - Validate test-apptainer-local.sh - 10 tests"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-conversion-scripts       - Run all script validation tests"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Image Testing - Requires converted images:"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-converted-images         - Format and functionality validation"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-cuda-apptainer           - CUDA functionality validation"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-mpi-apptainer            - MPI functionality validation"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-apptainer-all            - Run all image test suites"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Conversion Workflow:"
    COMMAND ${CMAKE_COMMAND} -E echo "  1. Build Docker:    cmake --build build --target build-docker-name"
    COMMAND ${CMAKE_COMMAND} -E echo "  2. Convert:         cmake --build build --target convert-to-apptainer-name"
    COMMAND ${CMAKE_COMMAND} -E echo "  3. Test scripts:    cmake --build build --target test-conversion-scripts"
    COMMAND ${CMAKE_COMMAND} -E echo "  4. Test images:     cmake --build build --target test-apptainer-all"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Documentation: docs/APPTAINER-CONVERSION-WORKFLOW.md"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMENT "Displaying Task 020 help information"
)

# --- Task 020: Comprehensive Apptainer Test Suite ---
add_custom_target(test-converted-images
    COMMAND ${CMAKE_SOURCE_DIR}/containers/tests/apptainer/test-converted-images.sh
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Testing converted Apptainer images..."
)

add_custom_target(test-cuda-apptainer
    COMMAND ${CMAKE_SOURCE_DIR}/containers/tests/apptainer/test-cuda-apptainer.sh
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Testing CUDA functionality in Apptainer images..."
)

add_custom_target(test-mpi-apptainer
    COMMAND ${CMAKE_SOURCE_DIR}/containers/tests/apptainer/test-mpi-apptainer.sh
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Testing MPI functionality in Apptainer images..."
)

add_custom_target(test-apptainer-all
    DEPENDS test-converted-images test-cuda-apptainer test-mpi-apptainer
    COMMENT "Running all Apptainer test suites..."
)

# --- Help Target ---
# Build list of container names for help output (one per line)
set(CONTAINER_HELP_LINES "")
foreach(CONTAINER_NAME ${CONTAINER_NAMES})
    list(APPEND CONTAINER_HELP_LINES COMMAND ${CMAKE_COMMAND} -E echo "    ${CONTAINER_NAME}")
endforeach()

add_custom_target(help-containers
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "=== Container Build System ==="
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Setup targets:"
    COMMAND ${CMAKE_COMMAND} -E echo "  setup-container-tools         - Install container tools and dependencies"
    COMMAND ${CMAKE_COMMAND} -E echo "  setup-hpc-cli                 - Set up HPC container manager CLI"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Docker image targets:"
    COMMAND ${CMAKE_COMMAND} -E echo "  build-docker-<name>           - Build specific Docker image"
    COMMAND ${CMAKE_COMMAND} -E echo "  build-all-docker-images       - Build all Docker images"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-docker-<name>            - Test specific Docker image"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Apptainer conversion targets:"
    COMMAND ${CMAKE_COMMAND} -E echo "  convert-to-apptainer-<name>   - Convert specific Docker image"
    COMMAND ${CMAKE_COMMAND} -E echo "  convert-all-to-apptainer      - Convert all Docker images"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-apptainer-<name>         - Test specific Apptainer image"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Task 020: Conversion workflow script validation:"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-convert-single-script    - Test convert-single.sh script correctness"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-apptainer-local-script   - Test test-apptainer-local.sh script correctness"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-conversion-scripts       - Test all conversion workflow scripts"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Task 020: Comprehensive Apptainer test suite:"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-converted-images         - Test converted image format and functionality"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-cuda-apptainer           - Test CUDA functionality in images"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-mpi-apptainer            - Test MPI functionality in images"
    COMMAND ${CMAKE_COMMAND} -E echo "  test-apptainer-all            - Run all Apptainer test suites"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Complete workflow targets:"
    COMMAND ${CMAKE_COMMAND} -E echo "  build-container-<name>        - Build Docker + convert to Apptainer"
    COMMAND ${CMAKE_COMMAND} -E echo "  build-all-containers          - Build all containers (complete workflow)"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Cleanup targets:"
    COMMAND ${CMAKE_COMMAND} -E echo "  clean-docker-images           - Clean Docker images"
    COMMAND ${CMAKE_COMMAND} -E echo "  clean-apptainer-images        - Clean Apptainer images"
    COMMAND ${CMAKE_COMMAND} -E echo "  clean-container-venv          - Clean virtual environment"
    COMMAND ${CMAKE_COMMAND} -E echo "  clean-all-containers          - Clean all container artifacts"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Available containers:"
    ${CONTAINER_HELP_LINES}
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMENT "Displaying container build system help"
)

message(STATUS "Container build system configured")
message(STATUS "  Container extensions found: ${CONTAINER_NAMES}")
message(STATUS "  Run 'cmake --build build --target help-containers' for available targets")
