cmake_minimum_required(VERSION 3.18)
project(HyperscalerOnWorkstation LANGUAGES NONE)

# --- Initial Check for Ninja ---
# This check runs before the generator is fully configured.
if(CMAKE_GENERATOR STREQUAL "Ninja")
  find_program(NINJA_EXECUTABLE ninja)
  if(NOT NINJA_EXECUTABLE)
    message(
      FATAL_ERROR
        "Ninja generator was requested, but the 'ninja' executable was not found. Please install ninja-build."
    )
  endif()
endif()


# --- Version Compatibility Checks ---
# Check for required tools and their versions

# Check for Packer
find_program(PACKER_EXECUTABLE packer)
if(NOT PACKER_EXECUTABLE)
    message(FATAL_ERROR "Packer executable not found. Please install Packer.")
endif()

# Verify Packer version (minimum 1.9.0 required)
execute_process(
    COMMAND ${PACKER_EXECUTABLE} version
    OUTPUT_VARIABLE PACKER_VERSION_OUTPUT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
string(REGEX MATCH "Packer v([0-9]+\\.[0-9]+\\.[0-9]+)" PACKER_VERSION_MATCH "${PACKER_VERSION_OUTPUT}")
if(PACKER_VERSION_MATCH)
    set(PACKER_VERSION ${CMAKE_MATCH_1})
    if(PACKER_VERSION VERSION_LESS "1.9.0")
        message(FATAL_ERROR "Packer version ${PACKER_VERSION} is too old. Minimum required version is 1.9.0.")
    endif()
    message(STATUS "Found Packer version: ${PACKER_VERSION}")
else()
    message(WARNING "Could not determine Packer version. Proceeding with build.")
endif()

# --- Packer Images ---
# Add packer subdirectory
add_subdirectory(packer)

# --- Custom Targets ---
# Note: Packer-related targets are available in the packer/ subdirectory
# Use: cmake --build build --target packer/<target_name>
# Available targets: init-packer, validate-packer, format-packer, build-image, clean-images, install-images

# Provision and configure the entire infrastructure (placeholder)
add_custom_target(deploy
    COMMAND echo "This is a placeholder for the 'deploy' target."
    COMMAND echo "Note: Run 'cmake --build build --target build-image' first to build images"
    COMMENT "Deploying entire infrastructure..."
)

# Run all tests
add_custom_target(
  test
  DEPENDS deploy
  COMMAND scripts/run_all_tests.sh
  COMMENT "Running all integration tests...")

# Cleanup shared Packer resources (SSH keys)
add_custom_target(clean-shared-packer
    COMMAND rm -rf ${CMAKE_BINARY_DIR}/shared
    COMMENT "Cleaning shared Packer resources (SSH keys)..."
)

# Cleanup all resources
add_custom_target(
  cleanup
  COMMAND scripts/cleanup_all.sh
  COMMENT "Destroying all provisioned infrastructure...")

message(
  STATUS
    "Build system configured. Run 'cmake --build build --target <target_name>' to execute a target."
)
