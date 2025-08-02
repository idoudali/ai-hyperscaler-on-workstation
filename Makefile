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

# Build system variables
BUILD_DIR := build

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
		-v "$(PWD)":/workspace \
		-u $(USER_ID):$(GROUP_ID) \
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
.PHONY: config build-project deploy test clean-build cleanup build-image

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

# Build the golden image artifact
build-image: config
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
	@echo "  make deploy         - Deploy the full infrastructure."
	@echo "  make test           - Run integration tests on deployed infrastructure."
	@echo "  make build-image    - Build the golden VM image."
	@echo "  make clean-build    - Remove the CMake build directory."
	@echo "  make cleanup        - Destroy all deployed infrastructure."
	@echo ""
	@echo "  make help           - Display this help message."
