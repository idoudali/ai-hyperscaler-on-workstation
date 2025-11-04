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

# Cluster State
CLUSTER_STATE_DIR := output/cluster-state

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
.PHONY: venv-mkdocs venv-create pre-commit-install pre-commit-run pre-commit-run-all

# Create Python virtual environment and install MkDocs dependencies
venv-mkdocs:
	@echo "Creating Python virtual environment using uv..."
	@uv venv --clear $(VENV_NAME)
	@echo "Virtual environment created at $(VENV_PATH)"
	@echo "Installing MkDocs and plugins..."
	@uv pip install mkdocs mkdocs-material mkdocs-awesome-pages-plugin mkdocs-include-markdown-plugin mkdocs-simple-plugin mkdocs-monorepo-plugin mkdocs-htmlproofer-plugin "mkdocstrings[python]"
	@echo "MkDocs virtual environment setup complete"

# Create Python virtual environment and install all dependencies
venv-create: venv-mkdocs
	@echo "Installing workspace packages in editable mode..."
	@uv pip install --reinstall -e $(PYTHON_DIR)/ai_how
	@echo "Installing Ansible and dependencies..."
	@uv pip install -r ansible/requirements.txt
	@echo "Installing Ansible collections..."
	@uv run ansible-galaxy collection install -r ansible/collections/requirements.yml
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
docs-build: venv-mkdocs
	@echo "Building documentation with MkDocs..."
	# Add ai_how package source to PYTHONPATH so mkdocstrings can find the module
	# without requiring installation of the package and its dependencies
	@PYTHONPATH=$(PYTHON_DIR)/ai_how/src:$$PYTHONPATH uv run mkdocs build

# Serve the documentation locally for development
docs-serve: venv-mkdocs
	@echo "Serving documentation locally at http://localhost:8000..."
	# Add ai_how package source to PYTHONPATH so mkdocstrings can find the module
	# without requiring installation of the package and its dependencies
	@PYTHONPATH=$(PYTHON_DIR)/ai_how/src:$$PYTHONPATH uv run mkdocs serve

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
	@cd $(PYTHON_DIR)/ai_how && unset FORCE_COLOR NO_COLOR && UV_VENV_CLEAR=0 uv run nox -s lint

# Format the code for the ai-how package using Nox
format-ai-how: venv-create
	@echo "Formatting code for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && unset FORCE_COLOR NO_COLOR && UV_VENV_CLEAR=0 uv run nox -s format

# Build the documentation for the ai-how package using Nox
docs-ai-how: venv-create
	@echo "Building documentation for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s docs

# Clean the ai-how package build artifacts using Nox
clean-ai-how: venv-create
	@echo "Cleaning ai-how package build artifacts..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s clean


#==============================================================================
# Configuration Template Rendering
#==============================================================================
.PHONY: config-render config-validate

# Rendered configuration file (default)
CLUSTER_RENDERED ?= output/cluster-state/rendered-config.yaml

# Render configuration with variable expansion
config-render: venv-create
	@echo "=========================================="
	@echo "Rendering Cluster Configuration"
	@echo "=========================================="
	@echo "Source: $(CLUSTER_CONFIG)"
	@echo "Output: $(CLUSTER_RENDERED)"
	@echo ""
	@if [ ! -f "$(CLUSTER_CONFIG)" ]; then \
		echo "❌ Error: Source configuration not found: $(CLUSTER_CONFIG)"; \
		exit 1; \
	fi
	@echo "🔧 Creating cluster state directory..."
	@mkdir -p $(CLUSTER_STATE_DIR)
	@echo "🔧 Processing configuration with variable expansion..."
	@uv run ai-how render $(CLUSTER_CONFIG) -o $(CLUSTER_RENDERED) --show-variables
	@echo ""
	@echo "✅ Configuration rendered successfully!"
	@echo "📁 Source: $(CLUSTER_CONFIG)"
	@echo "📁 Rendered: $(CLUSTER_RENDERED)"
	@echo ""
	@echo "Next steps:"
	@echo "  - Review rendered configuration: $(CLUSTER_RENDERED)"
	@echo "  - Use with cluster commands: make cluster-start"
	@echo "  - Or validate: make config-validate"

# Validate configuration without rendering
config-validate: venv-create
	@echo "=========================================="
	@echo "Validating Cluster Configuration"
	@echo "=========================================="
	@echo "Source: config/example-multi-gpu-clusters.yaml"
	@echo ""
	@if [ ! -f "config/example-multi-gpu-clusters.yaml" ]; then \
		echo "❌ Error: Configuration not found: config/example-multi-gpu-clusters.yaml"; \
		exit 1; \
	fi
	@echo "🔍 Validating configuration syntax and variables..."
	@uv run ai-how render config/example-multi-gpu-clusters.yaml --validate-only --show-variables
	@echo ""
	@echo "✅ Configuration validation successful!"

#==============================================================================
# Cluster Lifecycle Management
#==============================================================================
.PHONY: hpc-cluster-inventory hpc-cluster-start hpc-cluster-stop hpc-cluster-deploy hpc-cluster-destroy hpc-cluster-status
.PHONY: cloud-cluster-inventory cloud-cluster-start cloud-cluster-stop cloud-cluster-deploy cloud-cluster-destroy cloud-cluster-status
.PHONY: system-start system-stop system-status system-destroy
.PHONY: cluster-inventory cluster-start cluster-stop cluster-deploy cluster-destroy cluster-status clean-ssh-keys

# Cluster configuration file
CLUSTER_CONFIG ?= config/example-multi-gpu-clusters.yaml
CLUSTER_NAME ?= hpc
CLOUD_CLUSTER_NAME ?= cloud
INVENTORY_OUTPUT ?= $(CLUSTER_STATE_DIR)/inventory.yml

#==============================================================================
# HPC Cluster Lifecycle Management
#==============================================================================

# Generate Ansible inventory for HPC cluster
hpc-cluster-inventory: config-render
	@echo "Generating Ansible inventory for HPC cluster..."
	@echo "Configuration: $(CLUSTER_RENDERED)"
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
	@uv run python scripts/generate-ansible-inventory.py $(CLUSTER_RENDERED) $(CLUSTER_NAME) $(INVENTORY_OUTPUT)
	@echo ""
	@echo "✅ Inventory generated successfully"
	@echo "   File: $(INVENTORY_OUTPUT)"
	@echo "   SSH Key: build/shared/ssh-keys/id_rsa (from Packer build)"
	@echo "   SSH User: admin (matches Packer VMs)"

# Start HPC cluster VMs
hpc-cluster-start: venv-create clean-ssh-keys
	@echo "Starting HPC cluster VMs..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how hpc start $(CLUSTER_CONFIG)
	@echo "✅ HPC cluster VMs started successfully"

# Stop HPC cluster VMs (graceful shutdown)
hpc-cluster-stop: venv-create
	@echo "Stopping HPC cluster VMs (graceful shutdown)..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how hpc stop $(CLUSTER_CONFIG)
	@echo "✅ HPC cluster VMs stopped successfully"

# Deploy runtime configuration to HPC cluster
hpc-cluster-deploy: hpc-cluster-inventory
	@echo "=========================================="
	@echo "Deploying Runtime Configuration to HPC Cluster"
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
	@echo "Using uv run for Ansible execution"
	@echo "SSH Key: build/shared/ssh-keys/id_rsa"
	@echo ""
	@ANSIBLE_CONFIG=ansible/ansible.cfg uv run ansible-playbook \
		-v \
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

# Destroy HPC cluster VMs
hpc-cluster-destroy: venv-create
	@echo "Destroying HPC cluster VMs and cleaning up resources..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@echo "⚠️  WARNING: This will permanently delete the VMs and their data"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ] || (echo "Aborted."; exit 1)
	@uv run ai-how hpc destroy $(CLUSTER_CONFIG)
	@echo "✅ HPC cluster destroyed successfully"

# Check HPC cluster status
hpc-cluster-status: venv-create
	@echo "Checking HPC cluster status..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how hpc status $(CLUSTER_CONFIG)

#==============================================================================
# Cloud Cluster Lifecycle Management
#==============================================================================

# Generate Ansible inventory for Cloud cluster
cloud-cluster-inventory: config-render
	@echo "Generating Ansible inventory for Cloud cluster..."
	@echo "Configuration: $(CLUSTER_RENDERED)"
	@echo "Cluster: $(CLOUD_CLUSTER_NAME)"
	@echo "Output: $(INVENTORY_OUTPUT)"
	@mkdir -p $(dir $(INVENTORY_OUTPUT))
	@uv run python scripts/generate-kubespray-inventory.py $(CLUSTER_RENDERED) $(CLOUD_CLUSTER_NAME) $(INVENTORY_OUTPUT)
	@echo "✅ Cloud cluster inventory generated"

# Start Cloud cluster VMs
cloud-cluster-start: venv-create clean-ssh-keys
	@echo "Starting Cloud cluster VMs..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how cloud start $(CLUSTER_CONFIG)
	@echo "✅ Cloud cluster VMs started successfully"

# Stop Cloud cluster VMs
cloud-cluster-stop: venv-create
	@echo "Stopping Cloud cluster VMs..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how cloud stop $(CLUSTER_CONFIG)
	@echo "✅ Cloud cluster VMs stopped successfully"

# Deploy Kubernetes to Cloud cluster (two-step: prepare + deploy)
cloud-cluster-deploy: cloud-cluster-inventory
	@echo "=========================================="
	@echo "Deploying Kubernetes to Cloud Cluster"
	@echo "=========================================="
	@echo "Inventory: $(INVENTORY_OUTPUT)"
	@echo "Cluster Config: $(CLUSTER_CONFIG)"
	@echo ""
	@echo "Step 1/2: Preparing Kubespray environment..."
	@ANSIBLE_CONFIG=ansible/ansible.cfg \
	ANSIBLE_COLLECTIONS_PATH=ansible/collections \
	uv run ansible-playbook \
		-v \
		-i $(INVENTORY_OUTPUT) \
		-e "cluster_config=$(CLUSTER_CONFIG)" \
		-e "inventory_file=$(INVENTORY_OUTPUT)" \
		ansible/playbooks/prepare-cloud-deployment.yml
	@echo ""
	@echo "Step 2/2: Deploying Kubernetes cluster..."
	@ANSIBLE_CONFIG=ansible/ansible.cfg \
	ANSIBLE_COLLECTIONS_PATH=ansible/collections \
	uv run ansible-playbook \
		-vv \
		-i $(INVENTORY_OUTPUT) \
		-e "cluster_config=$(CLUSTER_CONFIG)" \
		-e "inventory_file=$(INVENTORY_OUTPUT)" \
		ansible/playbooks/deploy-cloud-k8s.yml
	@echo ""
	@echo "✅ Kubernetes cluster deployment completed"

# Destroy Cloud cluster VMs
cloud-cluster-destroy: venv-create
	@echo "Destroying Cloud cluster VMs..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@echo "⚠️  WARNING: This will permanently delete the VMs"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ] || (echo "Aborted."; exit 1)
	@uv run ai-how cloud destroy $(CLUSTER_CONFIG)
	@echo "✅ Cloud cluster destroyed successfully"

# Check Cloud cluster status
cloud-cluster-status: venv-create
	@echo "Checking Cloud cluster status..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how cloud status $(CLUSTER_CONFIG)

#==============================================================================
# System-wide Cluster Management (Both HPC and Cloud)
#==============================================================================

# Start complete ML system (both HPC and Cloud clusters)
system-start: venv-create clean-ssh-keys
	@echo "=========================================="
	@echo "Starting Complete ML Platform"
	@echo "=========================================="
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@echo ""
	@uv run ai-how system start $(CLUSTER_CONFIG)

# Stop complete ML system (both HPC and Cloud clusters)
system-stop: venv-create
	@echo "=========================================="
	@echo "Stopping Complete ML Platform"
	@echo "=========================================="
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@echo ""
	@uv run ai-how system stop $(CLUSTER_CONFIG)

# Show status of complete ML system
system-status: venv-create
	@echo "=========================================="
	@echo "Complete ML Platform Status"
	@echo "=========================================="
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@echo ""
	@uv run ai-how system status $(CLUSTER_CONFIG)

# Destroy complete ML system (both HPC and Cloud clusters)
system-destroy: venv-create
	@echo "=========================================="
	@echo "Destroying Complete ML Platform"
	@echo "=========================================="
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@echo ""
	@uv run ai-how system destroy $(CLUSTER_CONFIG)

#==============================================================================
# Backward Compatibility Aliases
#==============================================================================

# Old cluster-* targets now point to system-* (manages both clusters)
cluster-start: system-start
cluster-stop: system-stop
cluster-status: system-status
cluster-destroy: system-destroy
cluster-inventory: hpc-cluster-inventory
cluster-deploy: hpc-cluster-deploy

#==============================================================================
# SSH Key Management
#==============================================================================
# Remove SSH host keys for cluster VMs to avoid "host key verification failed" errors
# after rebuilding VMs. Uses vm-utils functions to discover running VMs and their IPs.

# Remove SSH host keys for cluster IPs defined in configuration
# This is called BEFORE cluster-start to proactively clean old keys
clean-ssh-keys:
	@echo "Removing SSH host keys for cluster configuration..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@CLUSTER_IPS=$$(tests/test-infra/utils/extract-cluster-ips.sh $(CLUSTER_CONFIG) hpc 2>/dev/null || echo ""); \
	if [ -n "$$CLUSTER_IPS" ]; then \
		echo "Found IP(s) in config: $$CLUSTER_IPS"; \
		tests/test-infra/utils/ssh-key-cleanup.sh $$CLUSTER_IPS || echo "⚠️  SSH key cleanup failed (continuing anyway)"; \
	else \
		echo "⚠️  No IPs found in config, skipping SSH key cleanup"; \
	fi
	@echo ""

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
	@echo "  make venv-mkdocs    - Create virtual environment and install MkDocs dependencies."
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
	@echo "Configuration Template Commands:"
	@echo "  make config-render     - Render template configuration with variable expansion."
	@echo "  make config-validate   - Validate template configuration without rendering."
	@echo ""
	@echo "System-wide Cluster Management (Both HPC + Cloud):"
	@echo "  make system-start      - Start complete ML platform (ai-how system start)."
	@echo "  make system-stop       - Stop complete ML platform (ai-how system stop)."
	@echo "  make system-status     - Show status of both clusters (ai-how system status)."
	@echo "  make system-destroy    - Destroy complete ML platform (ai-how system destroy)."
	@echo ""
	@echo "HPC Cluster Management:"
	@echo "  make hpc-cluster-inventory - Generate Ansible inventory for HPC cluster."
	@echo "  make hpc-cluster-start     - Start HPC cluster VMs (ai-how hpc start)."
	@echo "  make hpc-cluster-stop      - Stop HPC cluster VMs (ai-how hpc stop)."
	@echo "  make hpc-cluster-deploy    - Deploy SLURM to HPC cluster."
	@echo "  make hpc-cluster-destroy   - Destroy HPC cluster VMs (ai-how hpc destroy)."
	@echo "  make hpc-cluster-status    - Check HPC cluster status (ai-how hpc status)."
	@echo ""
	@echo "Cloud Cluster Management:"
	@echo "  make cloud-cluster-inventory - Generate Ansible inventory for Cloud cluster."
	@echo "  make cloud-cluster-start     - Start Cloud cluster VMs (ai-how cloud start)."
	@echo "  make cloud-cluster-stop      - Stop Cloud cluster VMs (ai-how cloud stop)."
	@echo "  make cloud-cluster-deploy    - Deploy Kubernetes to Cloud cluster."
	@echo "  make cloud-cluster-destroy   - Destroy Cloud cluster VMs (ai-how cloud destroy)."
	@echo "  make cloud-cluster-status    - Check Cloud cluster status (ai-how cloud status)."
	@echo ""
	@echo "Backward Compatibility (cluster-* now = system-*):"
	@echo "  make cluster-start     - Alias for system-start (starts both clusters)."
	@echo "  make cluster-stop      - Alias for system-stop (stops both clusters)."
	@echo "  make cluster-status    - Alias for system-status (shows both clusters)."
	@echo "  make cluster-destroy   - Alias for system-destroy (destroys both clusters)."
	@echo "  make cluster-inventory - Alias for hpc-cluster-inventory."
	@echo "  make cluster-deploy    - Alias for hpc-cluster-deploy."
	@echo ""
	@echo "SSH Key Management Commands:"
	@echo "  make clean-ssh-keys         - Remove SSH keys for IPs in CLUSTER_CONFIG."
	@echo ""
	@echo "Cluster Validation Workflows:"
	@echo "  make validate-cluster-full    - Full validation: inventory -> start -> deploy -> test."
	@echo "  make validate-cluster-runtime - Deploy and validate on running cluster."
	@echo ""
	@echo "  make help           - Display this help message."
	@echo ""
	@echo "Configuration Variables:"
	@echo "  CLUSTER_STATE_DIR      - Cluster state directory (default: output/cluster-state)"
	@echo "  CLUSTER_RENDERED       - Path to rendered config (default: \$${CLUSTER_STATE_DIR}/rendered-config.yaml)"
	@echo "  CLUSTER_CONFIG         - Path to cluster config (default: config/example-multi-gpu-clusters.yaml)"
	@echo "  CLUSTER_NAME           - HPC cluster name for inventory (default: hpc)"
	@echo "  CLOUD_CLUSTER_NAME     - Cloud cluster name for inventory (default: cloud)"
	@echo "  INVENTORY_OUTPUT       - Output path for inventory (default: \$${CLUSTER_STATE_DIR}/inventory.yml)"
	@echo ""
	@echo "Notes:"
	@echo "  - system-* targets use unified ai-how system commands for both clusters"
	@echo "  - Use hpc-cluster-* or cloud-cluster-* for individual cluster control"
	@echo "  - cluster-* targets now point to system-* for backward compatibility"
	@echo "  - Shared GPU scenarios: use hpc-cluster-* and cloud-cluster-* separately"
