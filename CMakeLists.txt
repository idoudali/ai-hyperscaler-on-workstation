cmake_minimum_required(VERSION 3.18)
project(HyperscalerOnWorkstation LANGUAGES NONE)

# --- Initial Check for Ninja ---
# This check runs before the generator is fully configured.
if(CMAKE_GENERATOR STREQUAL "Ninja")
    find_program(NINJA_EXECUTABLE ninja)
    if(NOT NINJA_EXECUTABLE)
        message(FATAL_ERROR "Ninja generator was requested, but the 'ninja' executable was not found. Please install ninja-build.")
    endif()
endif()

# --- Custom Targets ---
# These targets are placeholders. The actual commands will be added as the project progresses.

# Build the golden image (placeholder)
add_custom_target(build-image
    COMMAND echo "This is a placeholder for the 'build-image' target."
    COMMENT "Building golden VM image..."
)

# Provision and configure the entire infrastructure (placeholder)
add_custom_target(deploy
    DEPENDS build-image
    COMMAND echo "This is a placeholder for the 'deploy' target."
    COMMENT "Deploying entire infrastructure..."
)

# Run all tests
add_custom_target(test
    DEPENDS deploy
    COMMAND scripts/run_all_tests.sh
    COMMENT "Running all integration tests..."
)

# Cleanup all resources
add_custom_target(cleanup
    COMMAND scripts/cleanup_all.sh
    COMMENT "Destroying all provisioned infrastructure..."
)

message(STATUS "Build system configured. Run 'cmake --build build --target <target_name>' to execute a target.")
