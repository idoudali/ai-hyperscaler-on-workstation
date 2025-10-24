# CMake Build System Implementation Reference

**Status:** Production
**Created:** 2025-10-24
**Last Updated:** 2025-10-24

**Location:** Root CMakeLists.txt and subdirectories (packer/, containers/, 3rd-party/)

## Quick Links

- **User Documentation:** See [Build System Architecture](../architecture/build-system.md)
- **Implementation Overview:** See [Components README](README.md)

**Note:** For build container requirements and detailed setup instructions, refer to
`.ai/rules/build-container.md` in the project root

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [CMakeLists.txt Reference](#cmakeliststxt-reference)
3. [Build Layers](#build-layers)
4. [Workflow](#workflow)
5. [Adding Components](#adding-components)
6. [Troubleshooting](#troubleshooting)

## Architecture Overview

### Build System Layers

The CMake build system operates across three primary layers:

```text
Root CMakeLists.txt (Orchestrator)
│
├── packer/ (Image Building)
│   ├── hpc-controller/
│   ├── hpc-compute/
│   └── cloud-base/
│
├── containers/ (Application Containers)
│   ├── Docker build
│   └── Apptainer conversion
│
└── 3rd-party/ (External Dependencies)
    ├── beegfs/
    └── slurm/
```

### Build Flow Diagram

```text
cmake -G Ninja -S . -B build
              ↓
        CMake Configuration
              ↓
    Version Checks (Packer, Docker, Apptainer)
              ↓
    Setup Build Directories
              ↓
    Ninja Build System Ready
              ↓
cmake --build build --target <target>
              ↓
    Execute Target (Packer, Docker, or Dependency)
```

## CMakeLists.txt Reference

### Root CMakeLists.txt

**Location:** `/CMakeLists.txt`

#### Key Features

1. **Ninja Requirement Check** (lines 35-45)
   - Verifies Ninja is installed when `-G Ninja` is specified
   - Provides clear error message if Ninja is missing

2. **Version Compatibility Checks** (lines 48-72)
   - Validates Packer version ≥ 1.9.0
   - Parses Packer version output
   - Warns if version cannot be determined

3. **Subdirectory Integration** (lines 74-86)
   - Adds packer subdirectory
   - Adds containers subdirectory
   - Adds 3rd-party subdirectory
   - Each manages its own targets and dependencies

4. **Custom Top-Level Targets** (lines 88-117)
   - `deploy`: Placeholder for infrastructure deployment
   - `test`: Runs integration test suite
   - `clean-shared-packer`: Cleans SSH keys used by all images
   - `cleanup`: Destroys all provisioned infrastructure

#### Configuration Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `CMAKE_GENERATOR` | Build system to use | `Ninja` |
| `CMAKE_BINARY_DIR` | Build output directory | `./build/` |
| `CMAKE_CURRENT_SOURCE_DIR` | Source code root | `./` |
| `PROJECT_BINARY_DIR` | Project build root | `./build/` |

## Build Layers

### Packer Images Layer (`packer/CMakeLists.txt`)

**Location:** `/packer/CMakeLists.txt`

#### Purpose

Orchestrates building virtual machine images for HPC infrastructure using Packer templates and Ansible provisioning.

#### Key Components

##### 1. Debian Base Image Setup (lines 35-53)

```cmake
set(DEBIAN_CLOUD_IMAGE_URL_PREFIX "https://cloud.debian.org/...")
set(DEBIAN_RELEASE_VERSION "20250806-2196")
set(DEBIAN_IMAGE_NAME "debian-13-genericcloud-amd64-...")
set(DEBIAN_CLOUD_IMAGE_CHECKSUM_URL "...")
```

**Purpose:** Defines which Debian cloud image to use as the base for all Packer builds.

**Update Procedure:**

- Update `DEBIAN_RELEASE_VERSION` when new Debian releases become available
- `prepare-debian-checksum` target downloads and verifies checksums
- All Packer images depend on this checksum validation

##### 2. Shared SSH Keys (lines 10-33)

```cmake
set(SHARED_SSH_KEYS_DIR "${CMAKE_BINARY_DIR}/shared/ssh-keys")
add_custom_command(
    OUTPUT ${SHARED_SSH_KEY_PRIVATE} ${SHARED_SSH_KEY_PUBLIC}
    COMMAND generate-ssh-keys-only.sh
    ...
)
add_custom_target(generate-shared-ssh-keys
    DEPENDS ${SHARED_SSH_KEY_PRIVATE} ${SHARED_SSH_KEY_PUBLIC}
)
```

**Purpose:** Generates SSH key pair used by all Packer provisioning operations.

**Key Points:**

- SSH keys are stored in `build/shared/ssh-keys/`
- Shared across all image types (HPC controller, compute, cloud-base)
- Regenerated only if keys don't exist
- Cleaned by `clean-shared-packer` target

##### 3. Image Subdirectories (lines 55-58)

```cmake
add_subdirectory(hpc-controller)
add_subdirectory(hpc-compute)
add_subdirectory(cloud-base)
```

Each subdirectory handles its own:

- Packer template configuration
- Ansible role selection
- Image-specific variables
- Build-to-output mappings

##### 4. Aggregate Targets (lines 60-108)

**Initialization Targets:**

- `init-packer`: Initialize all Packer plugins
- `init-hpc-packer`: Initialize HPC-specific plugins only

**Validation Targets:**

- `validate-packer`: Validate all Packer templates
- `validate-hpc-packer`: Validate HPC templates only

**Formatting Targets:**

- `format-packer`: Format all Packer templates
- `format-hpc-packer`: Format HPC templates only

**Build Targets:**

- `build-packer-images`: Build all images (HPC controller, HPC compute, cloud-base)
- `build-hpc-images`: Build HPC images only

#### Target Dependency Graph

```text
build-packer-images
├── build-hpc-controller-image
│   └── validate-hpc-controller-packer
│       └── init-hpc-controller-packer
│           └── generate-shared-ssh-keys
│               └── prepare-debian-checksum
├── build-hpc-compute-image
│   └── validate-hpc-compute-packer
│       └── init-hpc-compute-packer
│           └── generate-shared-ssh-keys
└── build-cloud-image
    └── validate-cloud-packer
        └── init-cloud-packer
            └── generate-shared-ssh-keys
```

#### Image-Specific Subdirectories

Each image type has its own `CMakeLists.txt`:

**`packer/hpc-controller/CMakeLists.txt`**

- Builds SLURM controller node image
- Includes Ansible provisioning for SLURM controller setup
- Configures database for accounting

**`packer/hpc-compute/CMakeLists.txt`**

- Builds HPC compute node image
- Includes GPU driver provisioning
- Configures cgroup settings for SLURM

**`packer/cloud-base/CMakeLists.txt`**

- Builds general-purpose cloud image
- Minimal provisioning for generic deployments

### Container Images Layer (`containers/CMakeLists.txt`)

**Location:** `/containers/CMakeLists.txt`

#### Purpose

Builds Docker images and converts them to Apptainer (formerly Singularity) format for HPC environments.

#### Key Features

##### 1. Tool Verification (lines 4-23)

```cmake
find_program(DOCKER_EXECUTABLE docker)
if(NOT DOCKER_EXECUTABLE)
    message(WARNING "Docker not found...")
endif()

find_program(UV_EXECUTABLE uv)
if(NOT UV_EXECUTABLE)
    message(FATAL_ERROR "uv not found...")
endif()
```

Checks for required tools:

- **Docker**: Required for building container images
- **Apptainer**: Required for SIF conversion
- **uv**: Python package manager (required - will fail if missing)

##### 2. Build Directory Setup (lines 25-36)

```cmake
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/containers)
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/containers/docker)
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/containers/apptainer)
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/containers/venv)
```

Creates organized build output structure:

- `build/containers/docker/`: Docker images (stamps)
- `build/containers/apptainer/`: Apptainer .sif files
- `build/containers/venv/`: Python virtual environment for tools

##### 3. Container Discovery (lines 82-96)

```cmake
file(GLOB CONTAINER_EXTENSION_DIRS
     LIST_DIRECTORIES true
     ${CONTAINERS_SOURCE_DIR}/images/*/Docker
)
```

**How it works:**

- Scans `containers/images/*/Docker` directories
- Extracts container names automatically
- Makes adding new containers as simple as creating new `Docker/` directory

**Adding New Containers:**

1. Create `containers/images/my-container/Docker/` directory
2. Add `Dockerfile` in that directory
3. Re-run CMake configuration
4. New container targets are automatically generated

##### 4. Docker Build Targets (lines 98-144)

For each discovered container, creates:

- `build-docker-<name>`: Build Docker image
- `test-docker-<name>`: Quick test of Docker image
- `build-all-docker-images`: Aggregate target for all containers

**Docker Build Process:**

```cmake
add_custom_command(
    OUTPUT ${DOCKER_BUILD_DIR}/${CONTAINER_NAME}.stamp
    COMMAND docker build -t ${CONTAINER_NAME}:latest ...
    COMMAND touch ${CONTAINER_NAME}.stamp  # Mark completion
    DEPENDS ${CONTAINER_DOCKER_INPUT_FILES}
    COMMENT "Building Docker image: ${CONTAINER_NAME}"
    USES_TERMINAL  # Show build output
)
```

**Key Design Decisions:**

- Uses stamp files to track build completion
- Depends on all Docker input files (rebuilds if any change)
- `USES_TERMINAL` shows real-time output
- Image tagged as `<name>:latest`

##### 5. Apptainer Conversion (lines 146-189)

For each Docker image, creates conversion targets:

- `convert-to-apptainer-<name>`: Convert Docker → SIF
- `test-apptainer-<name>`: Test Apptainer image
- `convert-all-to-apptainer`: Convert all images

**Conversion Process:**

```cmake
add_custom_command(
    OUTPUT ${APPTAINER_BUILD_DIR}/${CONTAINER_NAME}.sif
    COMMAND bash -c "source ${VENV_DIR}/bin/activate && \
        PYTHONPATH=... hpc-container-manager convert to-apptainer ..."
    DEPENDS ${VENV_DIR}/bin/hpc-container-manager
            ${DOCKER_BUILD_DIR}/${CONTAINER_NAME}.stamp
    COMMENT "Converting ${CONTAINER_NAME} to Apptainer..."
)
```

**Key Points:**

- Depends on Docker image being built first (stamp file dependency)
- Uses Python virtual environment with container tools
- Sets `PYTHONPATH` to find HPC container manager
- Outputs `.sif` file for cluster deployment

##### 6. Complete Container Workflow (lines 191-209)

```cmake
add_custom_target(build-container-${CONTAINER_NAME}
    DEPENDS build-docker-${CONTAINER_NAME}
            convert-to-apptainer-${CONTAINER_NAME}
    COMMENT "Complete container workflow"
)
```

Single target combines:

1. Docker image build
2. Apptainer conversion
3. Verification steps

##### 7. Task 020: Conversion Workflow Testing (lines 233-280)

Specialized targets for Docker → Apptainer conversion validation:

- `test-convert-single-script`: Validates `convert-single.sh` (7 tests)
- `test-apptainer-local-script`: Validates `test-apptainer-local.sh` (10 tests)
- `test-conversion-scripts`: Runs all script validation
- `help-task-020`: Displays Task 020 help

**Test Execution:**

```bash
cmake --build build --target test-conversion-scripts
```

##### 8. Apptainer Test Suite (lines 282-304)

Comprehensive tests for converted images:

- `test-converted-images`: Verify .sif format and basic functionality
- `test-cuda-apptainer`: Test CUDA support in images
- `test-mpi-apptainer`: Test MPI support in images
- `test-apptainer-all`: Run all test suites

##### 9. Cleanup Targets (lines 211-231)

- `clean-docker-images`: Remove Docker images and stamps
- `clean-apptainer-images`: Remove .sif files
- `clean-container-venv`: Remove Python virtual environment
- `clean-all-containers`: Clean everything

#### Container Targets Flowchart

```text
build-all-containers
├── build-container-pytorch-cuda12.1-mpi4.1
│   ├── build-docker-pytorch-cuda12.1-mpi4.1
│   │   └── setup-container-tools
│   │       └── setup-hpc-cli
│   └── convert-to-apptainer-pytorch-cuda12.1-mpi4.1
│       └── [Docker image built first]
└── [Additional containers]

Cleanup:
clean-all-containers
├── clean-docker-images
├── clean-apptainer-images
└── clean-container-venv
```

### Third-Party Dependencies Layer (`3rd-party/CMakeLists.txt`)

**Location:** `/3rd-party/CMakeLists.txt`

#### Purpose

Builds external dependencies from source:

- BeeGFS distributed filesystem
- SLURM job scheduler

#### Structure

```cmake
add_subdirectory(beegfs)
add_subdirectory(slurm)
```

Each subdirectory manages:

- Source code checkout/download
- Build configuration
- Package creation
- Installation procedures

#### BeeGFS Build (`3rd-party/beegfs/CMakeLists.txt`)

**Key Targets:**

- `build-beegfs-packages`: Build BeeGFS packages from source
- `clean-beegfs`: Clean BeeGFS build artifacts

#### SLURM Build (`3rd-party/slurm/CMakeLists.txt`)

**Key Targets:**

- `build-slurm-packages`: Build SLURM packages from source
- `clean-slurm`: Clean SLURM build artifacts

## Workflow

### Basic Build Commands

#### 1. Initial Configuration

```bash
# Configure CMake with Ninja generator
cmake -G Ninja -S . -B build

# Output:
# -- Found Ninja: /usr/bin/ninja
# -- Found Packer version: 1.10.2
# -- Found Docker: /usr/bin/docker
# ...
# -- Build system configured. Run 'cmake --build build --target ...'
```

**Important:** Always run inside Docker development container for consistent build environment

#### 2. List Available Targets

```bash
# Show all available targets
cmake --build build --target help-containers
cmake --build build --target help-task-020

# Or query CMake directly
cmake --build build -- -t targets
```

#### 3. Build Packer Images

```bash
# Build all images
cmake --build build --target build-packer-images

# Build specific image
cmake --build build --target build-hpc-controller-image

# Validate templates without building
cmake --build build --target validate-packer

# Format templates
cmake --build build --target format-packer
```

#### 4. Build Docker Containers

```bash
# Build all containers
cmake --build build --target build-all-containers

# Build specific container
cmake --build build --target build-docker-pytorch-cuda12.1-mpi4.1

# Test container
cmake --build build --target test-docker-pytorch-cuda12.1-mpi4.1
```

#### 5. Convert to Apptainer

```bash
# Convert all to SIF
cmake --build build --target convert-all-to-apptainer

# Convert specific
cmake --build build --target convert-to-apptainer-pytorch-cuda12.1-mpi4.1

# Test conversion scripts
cmake --build build --target test-conversion-scripts

# Test converted images
cmake --build build --target test-apptainer-all
```

#### 6. Build Dependencies

```bash
# Build BeeGFS packages
cmake --build build --target build-beegfs-packages

# Build SLURM packages
cmake --build build --target build-slurm-packages
```

#### 7. Cleanup

```bash
# Clean specific component
cmake --build build --target clean-beegfs
cmake --build build --target clean-docker-images

# Full cleanup
cmake --build build --target cleanup

# Clean shared resources
cmake --build build --target clean-shared-packer
```

### Typical Development Workflow

```bash
# 1. Configure build system
make config

# 2. Validate templates (quick check)
make run-docker COMMAND="cmake --build build --target validate-packer"

# 3. Build what you need
make run-docker COMMAND="cmake --build build --target build-hpc-controller-image"

# 4. Debug/iterate on template or Ansible
# Make changes to packer/hpc-controller/ or ansible/roles/

# 5. Rebuild (CMake detects changes, rebuilds only what's needed)
make run-docker COMMAND="cmake --build build --target build-hpc-controller-image"

# 6. Clean when starting over
make run-docker COMMAND="cmake --build build --target cleanup"
```

## Adding Components

### Adding a New Packer Image Type

1. **Create directory structure:**

   ```bash
   mkdir -p packer/my-image
   ```

2. **Create `packer/my-image/CMakeLists.txt`:**

   ```cmake
   # Minimal example
   add_custom_target(build-my-image-image
       COMMAND packer build packer.json
       COMMENT "Building my-image..."
   )
   ```

3. **Create Packer template** (`packer/my-image/packer.json`)

4. **Update parent** (`packer/CMakeLists.txt`):

   ```cmake
   add_subdirectory(my-image)

   # Add to aggregate targets
   list(APPEND MY_IMAGE_TARGETS build-my-image-image)
   ```

5. **Verify targets exist:**

   ```bash
   cmake --build build --target build-my-image-image
   ```

### Adding a New Container

1. **Create directory structure:**

   ```bash
   mkdir -p containers/images/my-container/Docker
   ```

2. **Create `containers/images/my-container/Docker/Dockerfile`**

3. **Re-run CMake:**

   ```bash
   make config
   ```

4. **New targets automatically created:**

   ```bash
   cmake --build build --target build-docker-my-container
   cmake --build build --target convert-to-apptainer-my-container
   ```

## Troubleshooting

### Issue: "Ninja executable not found"

**Cause:** Ninja generator requested but not installed

**Solution:**

```bash
# Inside Docker container
apt-get install ninja-build

# Or specify different generator
cmake -G Unix\ Makefiles -S . -B build
```

### Issue: "Packer executable not found"

**Cause:** Packer not in PATH

**Solution:**

```bash
# Inside Docker container
apt-get install packer

# Or add to PATH
export PATH=$PATH:/path/to/packer
```

### Issue: "Docker not found" warning

**Cause:** Docker not installed or not accessible

**Solution:** This should not occur when running inside development container.

### Issue: Rebuild takes too long

**Cause:** CMake rebuilding everything

**Solution:**

1. Check timestamps on input files (images changed but not detected)
2. Use `cmake --build build -j N` to parallelize (N = number of cores)
3. Only build what you need: `cmake --build build --target specific-target`

### Issue: "uv executable not found"

**Cause:** uv package manager not installed

**Solution:**

```bash
# Inside Docker container
pip install uv

# Or via system package manager
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Performance Optimization

### Parallel Builds

```bash
# Build with maximum parallelism (N = CPU cores)
cmake --build build -j 8

# Or set default
export CMAKE_BUILD_PARALLEL_LEVEL=8
cmake --build build
```

### Incremental Builds

CMake only rebuilds targets with changed dependencies:

```bash
# First build takes longer
cmake --build build --target build-packer-images  # ~30 min

# Subsequent builds are fast if unchanged
cmake --build build --target build-packer-images  # ~5 sec
```

### Dependency Caching

Some build artifacts are cached:

- Debian cloud image checksums: `build/debian-checksum.txt`
- SSH keys: `build/shared/ssh-keys/`
- Python venv: `build/containers/venv/`

Remove caches to force full rebuild:

```bash
rm -rf build/
make config
```

## Integration Points

### CMake ↔ Makefile

The main `Makefile` provides convenience targets that wrap CMake:

```makefile
config:        # Runs: cmake -G Ninja -S . -B build
build-docker:  # Wrapper for cmake --build build --target build-all-containers
clean-docker:  # Wrapper for cmake --build build --target clean-docker-images
```

See the project root `Makefile` for a complete list of convenience targets.

### CMake ↔ GitHub Actions

CI/CD workflows in `.github/workflows/` use CMake:

```yaml
- name: Build containers
  run: cmake --build build --target build-all-containers
```

### CMake ↔ AI-HOW CLI

The Python CLI (`python/ai_how/`) consumes:

- Packer images built by CMake
- Converted Apptainer images
- Configuration schemas defined in CMakeLists.txt

## CMake Functions Reference

| Function | Purpose |
|----------|---------|
| `find_program()` | Locate external tools (packer, docker, apptainer) |
| `add_subdirectory()` | Include child CMakeLists.txt |
| `add_custom_command()` | Define build step (actual shell command) |
| `add_custom_target()` | Create target that depends on commands |
| `file(MAKE_DIRECTORY ...)` | Create directories |
| `file(GLOB ...)` | Find files matching pattern |
| `message()` | Print configuration messages |
| `execute_process()` | Run command and capture output |

## CMake Variables Reference

| Variable | Set By | Used For |
|----------|--------|----------|
| `CMAKE_GENERATOR` | `-G` flag | Select build system (Ninja/Unix Makefiles) |
| `CMAKE_BINARY_DIR` | `-B` flag | Output directory for build artifacts |
| `CMAKE_CURRENT_SOURCE_DIR` | CMake | Current CMakeLists.txt location |
| `PROJECT_BINARY_DIR` | project() | Project root build directory |
| `CMAKE_EXECUTABLE` | find_program() | Path to executable |

## Further Reading

- [Official CMake Documentation](https://cmake.org/cmake/help/latest/)
- [Ninja Build System](https://ninja-build.org/)
- [Packer Documentation](https://www.packer.io/docs)
- [Docker Documentation](https://docs.docker.com/)
- [Apptainer Documentation](https://apptainer.org/docs/)
