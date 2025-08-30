# Makefile for managing the development environment and build process

# Set default shell to bash
SHELL := /bin/bash

# Docker image settings
IMAGE_NAME := pharos-dev
IMAGE_TAG  := latest
FULL_IMAGE_NAME := $(IMAGE_NAME):$(IMAGE_TAG)

# Get the current user's UID and GID
USER_ID := $(shell id -u)
GROUP_ID := $(shell id -g)

# Get KVM and libvirt group IDs to pass to Docker for hardware acceleration.
# The user running this Makefile must be in the 'kvm' and 'libvirt' groups on the host.
KVM_GID := $(shell getent group kvm | cut -d: -f3)
LIBVIRT_GID := $(shell getent group libvirt | cut -d: -f3)
DOCKER_EXTRA_ARGS :=
ifneq ($(KVM_GID),)
	DOCKER_EXTRA_ARGS += --device /dev/kvm --group-add $(KVM_GID)
endif
ifneq ($(LIBVIRT_GID),)
	DOCKER_EXTRA_ARGS += --group-add $(LIBVIRT_GID)
endif

# Build system variables
BUILD_DIR := build

# Python virtual environment settings
PYTHON_DIR := python
VENV_NAME := .venv
VENV_PATH := $(VENV_NAME)

# Default target
.PHONY: all
all: help

#==============================================================================
# Docker Environment Management
#==============================================================================
.PHONY: build-docker shell-docker push-docker clean-docker lint-docker

# Build the Docker image
build-docker:
	@echo "Building Docker image: $(FULL_IMAGE_NAME)..."
	@docker build -t $(FULL_IMAGE_NAME) ./docker

# Run an interactive shell in the development container
shell-docker:
	@echo "Starting interactive shell in Docker container..."
	@docker run -it --rm \
		-v /etc/passwd:/etc/passwd:ro \
		-v /etc/group:/etc/group:ro \
		-v /etc/shadow:/etc/shadow:ro \
		-v /etc/sudoers:/etc/sudoers:ro \
		-v /etc/sudoers.d:/etc/sudoers.d:ro \
		-v "$(PWD)":/workspace \
		-v "$(HOME)":"$(HOME)" \
		-e HOME="$(HOME)" \
		-w /workspace \
		-u $(USER_ID):$(GROUP_ID) \
		$(DOCKER_EXTRA_ARGS) \
		$(FULL_IMAGE_NAME) /bin/bash

# Push the Docker image to a registry (uncomment and configure)
# REGISTRY_URL := your-registry-url
# .PHONY: push-docker
# push-docker: build-docker
# 	@echo "Pushing Docker image to $(REGISTRY_URL)..."
# 	@docker tag $(FULL_IMAGE_NAME) $(REGISTRY_URL)/$(FULL_IMAGE_NAME)
# 	@docker push $(REGISTRY_URL)/$(FULL_IMAGE_NAME)

# Clean up Docker artifacts
clean-docker:
	@echo "Cleaning up Docker images and containers..."
	@docker rmi $(FULL_IMAGE_NAME) || true
	@docker container prune -f || true

# Lint the Dockerfile
lint-docker:
	@echo "Linting Dockerfile..."
	@echo "--> No linter configured. Please add one (e.g., hadolint)."

#==============================================================================
# Project Build System (CMake)
#==============================================================================
.PHONY: config build-project deploy test clean-build cleanup build-image init-packer validate-packer clean-packer

# Configure the project with CMake
config:
	@echo "Configuring the project with CMake and Ninja..."
	@cmake -G Ninja -S . -B $(BUILD_DIR)

# Build all targets (alias for deploy)
build-project: deploy

# Deploy the infrastructure
deploy: config
	@echo "Deploying the infrastructure..."
	@cmake --build $(BUILD_DIR) --target deploy

# Run integration tests
test: config
	@echo "Running integration tests..."
	@cmake --build $(BUILD_DIR) --target test

# Initialize Packer plugins
init-packer: config
	@echo "Initializing Packer plugins..."
	@cmake --build $(BUILD_DIR) --target init-packer

# Validate Packer templates
validate-packer: init-packer
	@echo "Validating Packer templates..."
	@rm -rf $(BUILD_DIR)/images/* || true
	@cmake --build $(BUILD_DIR) --target validate-packer

# Clean Packer output directories
clean-packer: config
	@echo "Cleaning Packer output directories..."
	@cmake --build $(BUILD_DIR) --target clean-images

# Build the golden image artifact
build-image: validate-packer
	@echo "Building the golden image..."
	@cmake --build $(BUILD_DIR) --target build-image

# Clean the CMake build directory
clean-build:
	@echo "Cleaning the build directory..."
	@rm -rf $(BUILD_DIR)

# Destroy all provisioned infrastructure
cleanup: config
	@echo "Destroying all provisioned infrastructure..."
	@cmake --build $(BUILD_DIR) --target cleanup

#==============================================================================
# Python Virtual Environment Management (uv)
#==============================================================================
.PHONY: venv-create venv-install venv-activate venv-update venv-clean venv-lint venv-test

# Create a new Python virtual environment using uv
venv-create:
	@echo "Creating Python virtual environment using uv..."
	@uv venv --clear $(VENV_NAME)
	@echo "Virtual environment created at $(VENV_PATH)"

# Force recreation of the virtual environment
venv-recreate:
	@echo "Force recreating Python virtual environment using uv..."
	@rm -rf $(VENV_NAME) && uv venv $(VENV_NAME)
	@echo "Virtual environment recreated at $(VENV_PATH)"

# Quick reset: clean and reinstall everything
venv-reset: venv-clean venv-install
	@echo "Virtual environment reset complete"

# Install all workspace packages from pyproject.toml in editable mode
venv-install: venv-create
	@echo "Installing workspace packages in editable mode..."
	@uv pip install --reinstall -e $(PYTHON_DIR)/ai_how
	@echo "Workspace packages installed successfully"

# Activate the virtual environment (prints activation command)
venv-activate:
	@echo "To activate the virtual environment, run:"
	@echo "  source $(VENV_NAME)/bin/activate"
	@echo "Or use uv directly:"
	@echo "  uv run python"

# Update all workspace packages
venv-update:
	@echo "Updating all workspace packages..."
	@uv pip install --upgrade -e $(PYTHON_DIR)/ai_how

# Clean the virtual environment
venv-clean:
	@echo "Removing Python virtual environment..."
	@rm -rf $(VENV_PATH)
	@echo "Virtual environment removed"

# Run linting tools on Python code
venv-lint:
	@echo "Running linting tools on Python code..."
	@uv run pre-commit run --all-files

# Run pre-commit hooks using nox-based configuration
venv-pre-commit:
	@echo "Running pre-commit hooks with nox-based configuration..."
	@uv run pre-commit run --all-files

# Install pre-commit hooks
venv-install-hooks:
	@echo "Installing pre-commit hooks..."
	@uv run pre-commit install

# Run tests in the virtual environment
venv-test:
	@echo "Running tests in virtual environment..."
	@uv run pytest

#==============================================================================
# AI-HOW Python Package Management (Nox)
#==============================================================================
.PHONY: test-ai-how lint-ai-how format-ai-how docs-ai-how clean-ai-how

# Run tests for the ai-how package using Nox
test-ai-how: venv-install
	@echo "Running tests for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s test

# Run linting for the ai-how package using Nox
lint-ai-how: venv-install
	@echo "Running linting for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s lint

# Format the code for the ai-how package using Nox
format-ai-how: venv-install
	@echo "Formatting code for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s format

# Build the documentation for the ai-how package using Nox
docs-ai-how: venv-install
	@echo "Building documentation for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s docs

# Clean the ai-how package build artifacts using Nox
clean-ai-how: venv-install
	@echo "Cleaning ai-how package build artifacts..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s clean


#==============================================================================
# Help
#==============================================================================
.PHONY: help
help:
	@echo "Development Environment & Build System Makefile"
	@echo "-----------------------------------------------"
	@echo ""
	@echo "Docker Environment Commands:"
	@echo "  make build-docker   - Build the development Docker image."
	@echo "  make shell-docker   - Start an interactive shell in the container."
	@echo "  make clean-docker   - Remove the Docker image and old containers."
	@echo "  make push-docker    - (Optional) Push image to a registry."
	@echo ""
	@echo "Project Build Commands:"
	@echo "  make config         - Configure the CMake project."
	@echo "  make init-packer    - Initialize Packer plugins."
	@echo "  make validate-packer - Validate Packer templates."
	@echo "  make build-image    - Build the golden VM image."
	@echo "  make clean-packer   - Clean Packer output directories."
	@echo "  make deploy         - Deploy the full infrastructure."
	@echo "  make test           - Run integration tests on deployed infrastructure."
	@echo "  make clean-build    - Remove the CMake build directory."
	@echo "  make cleanup        - Destroy all deployed infrastructure."
	@echo ""
	@echo "Python Virtual Environment Commands (uv):"
	@echo "  make venv-create    - Create a new Python virtual environment."
	@echo "  make venv-recreate  - Force recreate the Python virtual environment."
	@echo "  make venv-reset     - Clean and reinstall the virtual environment."
	@echo "  make venv-install   - Install all workspace packages in editable mode."
	@echo "  make venv-activate  - Show how to activate the virtual environment."
	@echo "  make venv-update    - Update all packages in the virtual environment."
	@echo "  make venv-clean     - Remove the virtual environment."
	@echo "  make venv-lint      - Run linting tools on Python code."
	@echo "  make venv-pre-commit - Run pre-commit hooks with nox-based configuration."
	@echo "  make venv-install-hooks - Install pre-commit hooks."
	@echo "  make venv-test      - Run tests in the virtual environment."
	@echo ""
	@echo "AI-HOW Python Package Commands (Nox):"
	@echo "  make test-ai-how    - Run tests for the ai-how package."
	@echo "  make lint-ai-how    - Run linting for the ai-how package."
	@echo "  make format-ai-how  - Format the code for the ai-how package."
	@echo "  make docs-ai-how    - Build the documentation for the ai-how package."
	@echo "  make clean-ai-how   - Clean the ai-how package build artifacts."
	@echo ""
	@echo "  make help           - Display this help message."
