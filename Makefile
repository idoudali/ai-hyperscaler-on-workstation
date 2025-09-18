# Makefile for managing the development environment and build process

# Set default shell to bash
SHELL := /bin/bash

# Docker image settings
IMAGE_NAME := pharos-dev
IMAGE_TAG  := latest
FULL_IMAGE_NAME := $(IMAGE_NAME):$(IMAGE_TAG)

# Helper script for running commands in development container
DEV_CONTAINER_SCRIPT := ./scripts/run-in-dev-container.sh

# Build system variables
BUILD_DIR := build

#==============================================================================
# Build Configuration Helper
#==============================================================================
.PHONY: config

# Configure the project with CMake
config:
	@echo "Configuring the project with CMake and Ninja..."
	@$(DEV_CONTAINER_SCRIPT) cmake -G Ninja -S . -B $(BUILD_DIR)

#==============================================================================
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
	@$(DEV_CONTAINER_SCRIPT)

# Run a command in the development container
# Usage: make run-docker COMMAND="cmake --build build --target deploy"
run-docker:
	@echo "Running command in Docker container: $(COMMAND)"
	@$(DEV_CONTAINER_SCRIPT) $(COMMAND)

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
# Python Virtual Environment Management (uv)
#==============================================================================
.PHONY: venv-create pre-commit-install pre-commit-run pre-commit-run-all

# Create Python virtual environment and install all dependencies
venv-create:
	@echo "Creating Python virtual environment using uv..."
	@uv venv --clear $(VENV_NAME)
	@echo "Virtual environment created at $(VENV_PATH)"
	@echo "Installing workspace packages in editable mode..."
	@uv pip install --reinstall -e $(PYTHON_DIR)/ai_how
	@echo "Installing Ansible and dependencies..."
	@uv pip install -r ansible/requirements.txt
	@echo "Installing Ansible collections..."
	@uv run ansible-galaxy collection install -r ansible/collections/requirements.yml
	@echo "Installing MkDocs and plugins..."
	@uv pip install mkdocs mkdocs-material mkdocs-awesome-pages-plugin mkdocs-include-markdown-plugin "mkdocstrings[python]"
	@echo "Virtual environment setup complete"



# Run pre-commit hooks using nox-based configuration
# Install pre-commit hooks
pre-commit-install:
	@echo "Installing pre-commit hooks..."
	@uv run pre-commit install

pre-commit-run:
	@echo "Running pre-commit hooks with nox-based configuration..."
	@uv run pre-commit run

pre-commit-run-all:
	@echo "Running pre-commit hooks with nox-based configuration..."
	@uv run pre-commit run --all-files

#==============================================================================
# MkDocs Documentation Management
#==============================================================================
.PHONY: docs-build docs-serve docs-clean

# Build the documentation site
docs-build: venv-create
	@echo "Building documentation with MkDocs..."
	@uv run mkdocs build

# Serve the documentation locally for development
docs-serve: venv-create
	@echo "Serving documentation locally at http://localhost:8000..."
	@uv run mkdocs serve

# Clean the documentation build artifacts
docs-clean:
	@echo "Cleaning documentation build artifacts..."
	@rm -rf site/

#==============================================================================
# AI-HOW Python Package Management (Nox)
#==============================================================================
.PHONY: test-ai-how lint-ai-how format-ai-how docs-ai-how clean-ai-how

# Run tests for the ai-how package using Nox
test-ai-how: venv-create
	@echo "Running tests for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s test

# Run linting for the ai-how package using Nox
lint-ai-how: venv-create
	@echo "Running linting for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s lint

# Format the code for the ai-how package using Nox
format-ai-how: venv-create
	@echo "Formatting code for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s format

# Build the documentation for the ai-how package using Nox
docs-ai-how: venv-create
	@echo "Building documentation for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s docs

# Clean the ai-how package build artifacts using Nox
clean-ai-how: venv-create
	@echo "Cleaning ai-how package build artifacts..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s clean


#==============================================================================
# Help
#==============================================================================
.PHONY: help
help:
	@echo "Development Environment & Build System Makefile"
	@echo "-----------------------------------------------"
	@echo "Note: All build commands now run inside the development container"
	@echo "for consistent environment and dependency management."
	@echo ""
	@echo "Docker Environment Commands:"
	@echo "  make build-docker   - Build the development Docker image."
	@echo "  make shell-docker   - Start an interactive shell in the container."
	@echo "  make run-docker     - Run a command in the container (use COMMAND=\"...\")."
	@echo "  make clean-docker   - Remove the Docker image and old containers."
	@echo "  make push-docker    - (Optional) Push image to a registry."
	@echo ""
	@echo "Build Configuration:"
	@echo "  make config         - Configure the CMake project."
	@echo ""
	@echo "Python Virtual Environment Commands (uv):"
	@echo "  make venv-create    - Create virtual environment and install all dependencies."
	@echo ""
	@echo "Pre-commit Hooks Commands (pre-commit):"
	@echo "  make pre-commit-install - Install pre-commit hooks."
	@echo "  make pre-commit-run - Run pre-commit hooks on staged files."
	@echo "  make pre-commit-run-all - Run pre-commit hooks on all files."
	@echo ""
	@echo "Documentation Commands (MkDocs):"
	@echo "  make docs-build     - Build the documentation site."
	@echo "  make docs-serve     - Serve documentation locally at http://localhost:8000."
	@echo "  make docs-clean     - Clean documentation build artifacts."
	@echo ""
	@echo "AI-HOW Python Package Commands (Nox):"
	@echo "  make test-ai-how    - Run tests for the ai-how package."
	@echo "  make lint-ai-how    - Run linting for the ai-how package."
	@echo "  make format-ai-how  - Format the code for the ai-how package."
	@echo "  make docs-ai-how    - Build the documentation for the ai-how package."
	@echo "  make clean-ai-how   - Clean the ai-how package build artifacts."
	@echo ""
	@echo "  make help           - Display this help message."
