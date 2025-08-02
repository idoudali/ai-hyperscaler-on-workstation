# Simplified Implementation Plan for Task 0.2: Enhanced Build System

**Objective:** To meet the minimal requirements of Task 0.2 by creating a functional, automated build system using
CMake and Ninja. This plan focuses on simplicity and delivering the essential capabilities outlined in the project plan.

---

## 1. Core Build System: `CMakeLists.txt`

This section consolidates the setup into a single root `CMakeLists.txt` file for simplicity.

### 1.1. Project Setup and Generator

- In the root `CMakeLists.txt`, define the project and required CMake version.

  ```cmake
  cmake_minimum_required(VERSION 3.18)
  project(HyperscalerOnWorkstation LANGUAGES NONE)
  ```

- To meet the Ninja generator requirement, we will instruct the user to configure the project
  with `cmake -G Ninja -S . -B build`. A `Makefile` wrapper can provide a shortcut for this.

### 1.2. Dependency and Version Validation

- All validation will occur directly within the root `CMakeLists.txt`.
- **Tool Discovery & Version Check:** A single macro can be used to check for required tools.

  ```cmake
  macro(CHECK_TOOL tool_name version_arg version_regex min_version)
      find_program(TOOL_PATH ${tool_name})
      if(NOT TOOL_PATH)
          message(FATAL_ERROR "${tool_name} not found. Please install it.")
      endif()
      execute_process(COMMAND ${TOOL_PATH} ${version_arg} OUTPUT_VARIABLE TOOL_VERSION_OUTPUT)
      string(REGEX MATCH "${version_regex}" TOOL_VERSION "${TOOL_VERSION_OUTPUT}")
      if(TOOL_VERSION VERSION_LESS ${min_version})
          message(FATAL_ERROR "Found ${tool_name} version ${TOOL_VERSION}, but version ${min_version} or greater is required.")
      endif()
  endmacro()

  # Example: CHECK_TOOL(git "--version" "git version ([0-9]+\\.[0-9]+\\.[0-9]+)" "2.39.0")
  # ... other tools can be added here as needed.
  ```

- This approach meets the "dependency validation" and "version compatibility checks" requirements efficiently.

## 2. Minimalist Custom CMake Targets

To meet the requirement for custom targets, we will define a few high-level targets. Error handling will be
based on non-zero exit codes from scripts. A manual `cleanup` target will serve as the "rollback" mechanism.

### 2.1. Primary Targets

- **`build-image`**: Builds the primary build artifact, the golden VM image.
  - `add_custom_target(build-image COMMAND echo "Building image...")`
- **`deploy`**: Provisions and configures the entire infrastructure. This target depends on the image being built.
  - `add_custom_target(deploy DEPENDS build-image)`
  - `add_custom_command(TARGET deploy COMMAND echo "Deploying infrastructure...")`
  - ... and so on for all deployment steps.
- **`cleanup`**: Destroys all resources created by the `deploy` target.
  - `add_custom_target(cleanup COMMAND scripts/cleanup_all.sh)`

## 3. Consolidated Automated Testing Target

To meet the requirement for "automated testing targets for each build artifact," we will create a single, comprehensive
test target.

### 3.1. Single `test` Target

- A single target named `test` will be created.
- It will depend on the `deploy` target to ensure the infrastructure exists before testing.
- It will execute one master validation script. This simplifies the CMake configuration by delegating the orchestration
  of tests to a shell script.

  ```cmake
  add_custom_target(test DEPENDS deploy
      COMMAND scripts/run_all_tests.sh
      COMMENT "Running all integration tests..."
  )
  ```

- The `scripts/run_all_tests.sh` script will be responsible for executing the individual test suites for the
   HPC cluster, Kubernetes cluster, and MLOps services.

## 4. CI/CD Pipeline for Static Analysis

To meet the requirement for a "multi-stage CI/CD pipeline with quality gates," a simple pipeline will be implemented
using GitHub Actions to perform linting and static checks. This pipeline will not require a self-hosted runner.

### 4.1. CI Workflow (`.github/workflows/ci.yml`)

- This pipeline will run on pull requests to `main`, acting as a quality gate.
- It will run entirely on standard GitHub-hosted runners.

### 4.2. CI Job: `lint`

- The pipeline will consist of a single job named `lint`.
- It will run on `ubuntu-latest`.
- **Steps:**
    1. Checkout the code.
    2. Perform static analysis on shell scripts (e.g., using `shellcheck`).
    3. Perform static analysis on other configuration files as needed.
- This job acts as the quality gate to ensure code style and quality before merging.
