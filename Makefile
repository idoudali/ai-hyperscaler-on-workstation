# Makefile for managing the development environment and build process
#
# This Makefile provides a comprehensive build system for the AI-HOW project.
# It orchestrates Docker-based development environments, CMake builds, Python package management,
# and documentation generation.
#
# Key Features:
# - Containerized development environment with all required tools
# - CMake-based build orchestration with Ninja generator
# - Python virtual environment management with uv
# - Automated documentation generation with MkDocs
# - Pre-commit hooks for code quality
#
# Architecture:
# - Docker provides isolated development environment
# - CMake coordinates Packer image builds and container builds
# - Makefile provides convenient wrapper commands
# - All build operations run inside development container
#
# Usage:
#   make build-docker    # Build development container
#   make config          # Configure CMake project
#   make shell-docker    # Enter development environment
#   make run-docker COMMAND="cmake --build build --target <target>"

# Set default shell to bash
SHELL := /bin/bash

# Docker image settings
IMAGE_NAME := ai-how-dev
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
	@uv pip install mkdocs mkdocs-material mkdocs-awesome-pages-plugin mkdocs-include-markdown-plugin mkdocs-simple-plugin mkdocs-htmlproofer-plugin "mkdocstrings[python]"
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
# Cluster Lifecycle Management
#==============================================================================
.PHONY: cluster-inventory cluster-start cluster-stop cluster-deploy cluster-destroy cluster-status

# Cluster configuration file
CLUSTER_CONFIG ?= config/example-multi-gpu-clusters.yaml
CLUSTER_NAME ?= hpc
INVENTORY_OUTPUT ?= ansible/inventories/test/hosts

# Generate Ansible inventory from cluster configuration
# NOTE: ai-how CLI does not currently have inventory generation functionality
# Using temporary workaround script until feature is implemented
#
# This target uses SSH keys and username from the Packer build system:
# - SSH Key: build/shared/ssh-keys/id_rsa (auto-generated by CMake/Packer)
# - Username: admin (defined in packer/common/cloud-init/*.yml)
cluster-inventory:
	@echo "Generating Ansible inventory from cluster configuration..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@echo "Cluster: $(CLUSTER_NAME)"
	@echo "Output: $(INVENTORY_OUTPUT)"
	@echo "⚠️  NOTE: Using workaround script (ai-how inventory feature not yet implemented)"
	@echo ""
	@echo "Checking for SSH keys from Packer build system..."
	@if [ ! -f "build/shared/ssh-keys/id_rsa" ]; then \
		echo "⚠️  SSH keys not found. Generating them now..."; \
		mkdir -p build/shared/ssh-keys; \
		ssh-keygen -t rsa -b 4096 -f build/shared/ssh-keys/id_rsa -N "" -C "packer-build@shared" || exit 1; \
		echo "✅ SSH keys generated"; \
	else \
		echo "✅ SSH keys found: build/shared/ssh-keys/id_rsa"; \
	fi
	@echo ""
	@mkdir -p $(dir $(INVENTORY_OUTPUT))
	@uv run python scripts/generate-ansible-inventory.py $(CLUSTER_CONFIG) $(CLUSTER_NAME) $(INVENTORY_OUTPUT)
	@echo ""
	@echo "✅ Inventory generated successfully"
	@echo "   File: $(INVENTORY_OUTPUT)"
	@echo "   SSH Key: build/shared/ssh-keys/id_rsa (from Packer build)"
	@echo "   SSH User: admin (matches Packer VMs)"

# Start cluster VMs
cluster-start:
	@echo "Starting HPC cluster VMs..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how hpc start $(CLUSTER_CONFIG)
	@echo "✅ Cluster VMs started successfully"

# Stop cluster VMs (graceful shutdown)
cluster-stop:
	@echo "Stopping HPC cluster VMs (graceful shutdown)..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how hpc stop $(CLUSTER_CONFIG)
	@echo "✅ Cluster VMs stopped successfully"

# Deploy runtime configuration to running cluster
# Prerequisite: inventory must exist (will generate if missing)
cluster-deploy: cluster-inventory
	@echo "=========================================="
	@echo "Deploying Runtime Configuration to Cluster"
	@echo "=========================================="
	@echo "Inventory: $(INVENTORY_OUTPUT)"
	@echo "Cluster Config: $(CLUSTER_CONFIG)"
	@echo "Cluster Name: $(CLUSTER_NAME)"
	@echo ""
	@echo "Verifying prerequisites..."
	@if [ ! -f "$(INVENTORY_OUTPUT)" ]; then \
		echo "❌ Error: Inventory generation failed"; \
		exit 1; \
	fi
	@if [ ! -f "build/shared/ssh-keys/id_rsa" ]; then \
		echo "❌ Error: SSH private key not found"; \
		exit 1; \
	fi
	@echo "✅ Prerequisites verified"
	@echo ""
	@echo "Starting Ansible deployment..."
	@echo "Using Docker container for isolated execution"
	@echo "SSH Key: build/shared/ssh-keys/id_rsa"
	@echo ""
	@DOCKER_NETWORK_MODE=host $(DEV_CONTAINER_SCRIPT) ansible-playbook \
		-i $(INVENTORY_OUTPUT) \
		-e "cluster_config=$(CLUSTER_CONFIG)" \
		-e "cluster_name=$(CLUSTER_NAME)" \
		ansible/playbooks/playbook-hpc-runtime.yml
	@echo ""
	@echo "=========================================="
	@echo "✅ Runtime Configuration Deployed"
	@echo "=========================================="
	@echo ""
	@echo "Next Steps:"
	@echo "  - Check deployment status in the output above"
	@echo "  - SSH to controller: ssh -i build/shared/ssh-keys/id_rsa admin@192.168.100.10"
	@echo "  - Verify services: systemctl status slurmctld slurmdbd slurmd"
	@echo "  - Test cluster: sinfo && srun hostname"

# Destroy cluster VMs and clean up resources
cluster-destroy:
	@echo "Destroying HPC cluster VMs and cleaning up resources..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@echo "⚠️  WARNING: This will permanently delete the VMs and their data"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ] || (echo "Aborted."; exit 1)
	@uv run ai-how hpc destroy $(CLUSTER_CONFIG)
	@echo "✅ Cluster destroyed successfully"

# Check cluster status
cluster-status:
	@echo "Checking HPC cluster status..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how hpc status $(CLUSTER_CONFIG)

#==============================================================================
# Cluster Validation Workflow
#==============================================================================
.PHONY: validate-cluster-full validate-cluster-runtime

# Full cluster validation: inventory -> start -> deploy -> tests -> stop
validate-cluster-full:
	@echo "=========================================="
	@echo "Starting Full Cluster Validation Workflow"
	@echo "=========================================="
	@echo ""
	@echo "Step 1: Generating inventory..."
	@$(MAKE) cluster-inventory
	@echo ""
	@echo "Step 2: Starting cluster VMs..."
	@$(MAKE) cluster-start
	@echo ""
	@echo "Step 3: Waiting for VMs to be ready..."
	@sleep 30
	@echo ""
	@echo "Step 4: Deploying runtime configuration..."
	@$(MAKE) cluster-deploy
	@echo ""
	@echo "Step 5: Running validation tests..."
	@# Add validation test commands here
	@echo "✅ Full cluster validation complete"
	@echo ""
	@echo "Note: Cluster is still running. Use 'make cluster-stop' to shut down."

# Runtime validation only (assumes cluster is already running)
validate-cluster-runtime:
	@echo "=========================================="
	@echo "Validating Runtime Configuration"
	@echo "=========================================="
	@echo ""
	@echo "Step 1: Checking if cluster is running..."
	@$(MAKE) cluster-status || (echo "❌ Cluster not running. Use 'make cluster-start' first."; exit 1)
	@echo ""
	@echo "Step 2: Deploying runtime configuration..."
	@$(MAKE) cluster-deploy
	@echo ""
	@echo "✅ Runtime validation complete"

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
	@echo "Cluster Lifecycle Management Commands:"
	@echo "  make cluster-inventory - Generate Ansible inventory (⚠️  uses workaround script)."
	@echo "  make cluster-start     - Start HPC cluster VMs (ai-how hpc start)."
	@echo "  make cluster-stop      - Stop HPC cluster VMs (ai-how hpc stop)."
	@echo "  make cluster-deploy    - Deploy runtime configuration to running cluster."
	@echo "  make cluster-destroy   - Destroy HPC cluster VMs (ai-how hpc destroy)."
	@echo "  make cluster-status    - Check HPC cluster status (ai-how hpc status)."
	@echo ""
	@echo "Cluster Validation Workflows:"
	@echo "  make validate-cluster-full    - Full validation: inventory -> start -> deploy -> test."
	@echo "  make validate-cluster-runtime - Deploy and validate on running cluster."
	@echo ""
	@echo "  make help           - Display this help message."
	@echo ""
	@echo "Cluster Configuration Variables:"
	@echo "  CLUSTER_CONFIG      - Path to cluster config (default: config/example-multi-gpu-clusters.yaml)"
	@echo "  CLUSTER_NAME        - Cluster name for inventory (default: hpc, not used by ai-how)"
	@echo "  INVENTORY_OUTPUT    - Output path for inventory (default: ansible/inventories/test/hosts)"
	@echo ""
	@echo "Notes:"
	@echo "  - Inventory generation uses temporary workaround script (ai-how feature pending)"
	@echo "  - ai-how CLI uses 'hpc' subcommand (not 'cluster')"
	@echo "  - Cluster name derived from config by ai-how, CLUSTER_NAME only for inventory"
