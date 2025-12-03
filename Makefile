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

# Include shared variables
include Makefile.vars

# Docker image settings
IMAGE_NAME := ai-how-dev
IMAGE_TAG  := latest
FULL_IMAGE_NAME := $(IMAGE_NAME):$(IMAGE_TAG)

# Helper script for running commands in development container
DEV_CONTAINER_SCRIPT := ./scripts/run-in-dev-container.sh

# Docker-in-Docker support
# Disabled by default for security. Enable only if you need to build or run containers inside the dev container.
# Set DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 to explicitly opt-in.
# WARNING: Mounting Docker socket grants full control of host Docker daemon and can lead to privilege escalation.
# DO NOT enable unless you understand the risks.
DEV_CONTAINER_ENABLE_DOCKER_SOCKET ?= 0

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

# Build the Docker image
.PHONY: build-docker
build-docker:
	@echo "Building Docker image: $(FULL_IMAGE_NAME)..."
	@docker build -t $(FULL_IMAGE_NAME) ./docker

# Run an interactive shell in the development container
.PHONY: shell-docker
shell-docker:
	@echo "Starting interactive shell in Docker container..."
	@DEV_CONTAINER_ENABLE_DOCKER_SOCKET=$(DEV_CONTAINER_ENABLE_DOCKER_SOCKET) $(DEV_CONTAINER_SCRIPT)

# Run a command in the development container
# Usage: make run-docker COMMAND="cmake --build build --target deploy"
# Docker-in-Docker is disabled by default (=0). Set DEV_CONTAINER_ENABLE_DOCKER_SOCKET=1 to enable.
.PHONY: run-docker
run-docker:
	@echo "Running command in Docker container: $(COMMAND)"
	@DEV_CONTAINER_ENABLE_DOCKER_SOCKET=$(DEV_CONTAINER_ENABLE_DOCKER_SOCKET) $(DEV_CONTAINER_SCRIPT) $(COMMAND)

# Push the Docker image to a registry (uncomment and configure)
# REGISTRY_URL := your-registry-url
# .PHONY: push-docker
# push-docker: build-docker
# 	@echo "Pushing Docker image to $(REGISTRY_URL)..."
# 	@docker tag $(FULL_IMAGE_NAME) $(REGISTRY_URL)/$(FULL_IMAGE_NAME)
# 	@docker push $(REGISTRY_URL)/$(FULL_IMAGE_NAME)

# Clean up Docker artifacts
.PHONY: clean-docker
clean-docker:
	@echo "Cleaning up Docker images and containers..."
	@docker rmi $(FULL_IMAGE_NAME) || true
	@docker container prune -f || true

# Lint the Dockerfile
.PHONY: lint-docker
lint-docker:
	@echo "Linting Dockerfile..."
	@echo "--> No linter configured. Please add one (e.g., hadolint)."


#==============================================================================
# Python Virtual Environment Management (uv)
#==============================================================================

# Create Python virtual environment and install MkDocs dependencies
.PHONY: venv-mkdocs
venv-mkdocs:
	@echo "Creating Python virtual environment using uv..."
	@uv venv --clear $(VENV_NAME)
	@echo "Virtual environment created at $(VENV_PATH)"
	@echo "Installing MkDocs and plugins..."
	@uv pip install mkdocs mkdocs-material mkdocs-awesome-pages-plugin mkdocs-include-markdown-plugin mkdocs-simple-plugin mkdocs-monorepo-plugin mkdocs-htmlproofer-plugin "mkdocstrings[python]"
	@echo "MkDocs virtual environment setup complete"

# Create Python virtual environment and install all dependencies
.PHONY: venv-create
venv-create: venv-mkdocs
	@echo "Installing workspace packages in editable mode..."
	@uv pip install --reinstall -e $(PYTHON_DIR)/ai_how
	@echo "Installing containers dependencies..."
	@uv pip install --reinstall -r containers/requirements.txt
	@echo "Installing Ansible and dependencies..."
	@uv pip install -r ansible/requirements.txt
	@echo "Installing Ansible collections..."
	@uv run ansible-galaxy collection install -r ansible/collections/requirements.yml
	@echo "Virtual environment setup complete"



# Run pre-commit hooks using nox-based configuration
# Install pre-commit hooks
.PHONY: pre-commit-install
pre-commit-install:
	@echo "Installing pre-commit hooks..."
	@uv run pre-commit install

.PHONY: pre-commit-run
pre-commit-run:
	@echo "Running pre-commit hooks with nox-based configuration..."
	@uv run pre-commit run

.PHONY: pre-commit-run-all
pre-commit-run-all:
	@echo "Running pre-commit hooks with nox-based configuration..."
	@uv run pre-commit run --all-files

#==============================================================================
# MkDocs Documentation Management
#==============================================================================

# Build the documentation site
.PHONY: docs-build
docs-build: venv-mkdocs
	@echo "Building documentation with MkDocs..."
	# Add ai_how package source to PYTHONPATH so mkdocstrings can find the module
	# without requiring installation of the package and its dependencies
	@PYTHONPATH=$(PYTHON_DIR)/ai_how/src:$$PYTHONPATH uv run mkdocs build

# Serve the documentation locally for development
.PHONY: docs-serve
docs-serve: venv-mkdocs
	@echo "Serving documentation locally at http://localhost:8000..."
	# Add ai_how package source to PYTHONPATH so mkdocstrings can find the module
	# without requiring installation of the package and its dependencies
	@PYTHONPATH=$(PYTHON_DIR)/ai_how/src:$$PYTHONPATH uv run mkdocs serve

# Clean the documentation build artifacts
.PHONY: docs-clean
docs-clean:
	@echo "Cleaning documentation build artifacts..."
	@rm -rf site/

#==============================================================================
# AI-HOW Python Package Management (Nox)
#==============================================================================

# Run tests for the ai-how package using Nox
.PHONY: test-ai-how
test-ai-how: venv-create
	@echo "Running tests for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s test

# Run linting for the ai-how package using Nox
.PHONY: lint-ai-how
lint-ai-how: venv-create
	@echo "Running linting for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && unset FORCE_COLOR NO_COLOR && UV_VENV_CLEAR=0 uv run nox -s lint

# Format the code for the ai-how package using Nox
.PHONY: format-ai-how
format-ai-how: venv-create
	@echo "Formatting code for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && unset FORCE_COLOR NO_COLOR && UV_VENV_CLEAR=0 uv run nox -s format

# Build the documentation for the ai-how package using Nox
.PHONY: docs-ai-how
docs-ai-how: venv-create
	@echo "Building documentation for ai-how package..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s docs

# Clean the ai-how package build artifacts using Nox
.PHONY: clean-ai-how
clean-ai-how: venv-create
	@echo "Cleaning ai-how package build artifacts..."
	@cd $(PYTHON_DIR)/ai_how && UV_VENV_CLEAR=0 uv run nox -s clean


#==============================================================================
# Configuration Template Rendering
#==============================================================================

# Rendered configuration file (default)
CLUSTER_RENDERED ?= output/cluster-state/rendered-config.yaml

# Render configuration with variable expansion
.PHONY: config-render
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
.PHONY: config-validate
config-validate: venv-create
	@echo "=========================================="
	@echo "Validating Cluster Configuration"
	@echo "=========================================="
	@echo "Source: $(CLUSTER_CONFIG)"
	@echo ""
	@if [ ! -f "$(CLUSTER_CONFIG)" ]; then \
		echo "❌ Error: Configuration not found: $(CLUSTER_CONFIG)"; \
		exit 1; \
	fi
	@echo "🔍 Validating configuration syntax and variables..."
	@uv run ai-how render $(CLUSTER_CONFIG) --validate-only --show-variables
	@echo ""
	@echo "✅ Configuration validation successful!"


#==============================================================================
# Container Build and Deployment
#==============================================================================
.PHONY: containers-deploy-beegfs
containers-deploy-beegfs: venv-create
	@echo "=========================================="
	@echo "Building containers and deploying to BeeGFS"
	@echo "=========================================="
	@source .venv/bin/activate && \
	CONTROLLER_IP=$$(ai-how --log-level error system status $(CLUSTER_CONFIG) --format json | \
			jq -r '.hpc_cluster.vms[] | select(.name | test("controller")) | .ip_address') && \
	echo "Detected controller IP: $$CONTROLLER_IP" && \
	if [ -z "$$CONTROLLER_IP" ]; then \
		echo "❌ Unable to determine controller IP from cluster configuration; ensure ai-how reports it" >&2; \
		exit 1; \
	fi && \
	$(MAKE) run-docker COMMAND="cmake --build build --target build-all-containers" && \
	$(MAKE) run-docker COMMAND="bash -lc 'set -euo pipefail; \
		echo \"Deploying with controller IP: $$CONTROLLER_IP\"; \
		export BEEGFS_CONTROLLER_IP=\"$$CONTROLLER_IP\"; \
		export BEEGFS_CONTROLLER_USER=\"$(CONTAINER_DEPLOY_USER)\"; \
		export BEEGFS_TARGET_BASE=\"$(CONTAINER_DEPLOY_TARGET)\"; \
		export BEEGFS_SSH_KEY=\"$(CONTAINER_DEPLOY_SSH_KEY)\"; \
		export BEEGFS_SYNC_NODES=\"$(CONTAINER_DEPLOY_SYNC_NODES)\"; \
		export BEEGFS_VERIFY=\"$(CONTAINER_DEPLOY_VERIFY)\"; \
		./containers/scripts/deploy-containers.sh beegfs'"
	@echo "=========================================="
	@echo "Containers deployed to BeeGFS successfully"
	@echo "=========================================="


#==============================================================================
# Cluster Lifecycle Management
#==============================================================================

#==============================================================================
# HPC Cluster Lifecycle Management
#==============================================================================

# Generate Ansible inventory for HPC cluster
.PHONY: hpc-cluster-inventory
hpc-cluster-inventory: config-render
	@echo "Generating Ansible inventory for HPC cluster..."
	@echo "Configuration: $(CLUSTER_RENDERED)"
	@echo "Cluster: $(CLUSTER_NAME)"
	@echo "Output: $(HPC_INVENTORY_OUTPUT)"
	@echo ""
	@echo "Checking for SSH keys from Packer build system..."
	@if [ ! -f "$(SSH_PRIVATE_KEY)" ]; then \
		echo "❌ Error: SSH private key not found: $(SSH_PRIVATE_KEY)"; \
		echo "Please build the base images first to generate SSH keys."; \
		exit 1; \
	fi
	@echo "✅ SSH keys found: $(SSH_PRIVATE_KEY)"
	@echo ""
	@mkdir -p $(dir $(HPC_INVENTORY_OUTPUT))
	@uv run ai-how inventory generate-hpc $(CLUSTER_RENDERED) $(CLUSTER_NAME) --output $(HPC_INVENTORY_OUTPUT)
	@echo ""
	@echo "✅ Inventory generated successfully"
	@echo "   File: $(HPC_INVENTORY_OUTPUT)"

# Start HPC cluster VMs
.PHONY: hpc-cluster-start
hpc-cluster-start: venv-create clean-ssh-keys
	@echo "Starting HPC cluster VMs..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how hpc start $(CLUSTER_CONFIG)
	@echo "✅ HPC cluster VMs started successfully"

# Stop HPC cluster VMs (graceful shutdown)
.PHONY: hpc-cluster-stop
hpc-cluster-stop: venv-create
	@echo "Stopping HPC cluster VMs (graceful shutdown)..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how hpc stop $(CLUSTER_CONFIG)
	@echo "✅ HPC cluster VMs stopped successfully"

# Deploy runtime configuration to HPC cluster
.PHONY: hpc-cluster-deploy
hpc-cluster-deploy: hpc-cluster-inventory
	@echo "=========================================="
	@echo "Deploying Runtime Configuration to HPC Cluster"
	@echo "=========================================="
	@echo "Inventory: $(HPC_INVENTORY_OUTPUT)"
	@echo "Cluster Config: $(CLUSTER_CONFIG)"
	@echo "Cluster Name: $(CLUSTER_NAME)"
	@echo ""
	@echo "Starting Ansible deployment..."
	@echo "Using uv run for Ansible execution"
	@echo "SSH Key: $(SSH_PRIVATE_KEY)"
	@echo ""
	@ANSIBLE_CONFIG=ansible/ansible.cfg uv run ansible-playbook \
		-v \
		-i $(HPC_INVENTORY_OUTPUT) \
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
	@echo "  - SSH to controller: ssh -i $(SSH_PRIVATE_KEY) admin@192.168.100.10"
	@echo "  - Verify services: systemctl status slurmctld slurmdbd slurmd"
	@echo "  - Test cluster: sinfo && srun hostname"

# Destroy HPC cluster VMs
.PHONY: hpc-cluster-destroy
hpc-cluster-destroy: venv-create
	@echo "Destroying HPC cluster VMs and cleaning up resources..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how hpc destroy $(CLUSTER_CONFIG)
	@echo "✅ HPC cluster destroyed successfully"

# Check HPC cluster status
.PHONY: hpc-cluster-status
hpc-cluster-status: venv-create
	@echo "Checking HPC cluster status..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how hpc status $(CLUSTER_CONFIG)




#==============================================================================
# Cloud Cluster Lifecycle Management
#==============================================================================

# Generate Ansible inventory for Cloud cluster
.PHONY: cloud-cluster-inventory
cloud-cluster-inventory: config-render
	@echo "Generating Ansible inventory for Cloud cluster..."
	@echo "Configuration: $(CLUSTER_RENDERED)"
	@echo "Cluster key: $(CLOUD_CLUSTER_NAME)"
	@echo "Output: $(CLOUD_INVENTORY_OUTPUT)"
	@mkdir -p $(dir $(CLOUD_INVENTORY_OUTPUT))
	@uv run ai-how inventory generate-k8s $(CLUSTER_RENDERED) $(CLOUD_CLUSTER_NAME) --output $(CLOUD_INVENTORY_OUTPUT)
	@echo "✅ Cloud cluster inventory generated"
	@echo "   File: $(CLOUD_INVENTORY_OUTPUT)"
	@echo "⚠️  Note: If IPs are incorrect, check that the cluster name in config matches libvirt VM domain names"

# Start Cloud cluster VMs
.PHONY: cloud-cluster-start
cloud-cluster-start: venv-create clean-ssh-keys
	@echo "Starting Cloud cluster VMs..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how cloud start $(CLUSTER_CONFIG)
	@echo "✅ Cloud cluster VMs started successfully"

# Stop Cloud cluster VMs
.PHONY: cloud-cluster-stop
cloud-cluster-stop: venv-create
	@echo "Stopping Cloud cluster VMs..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how cloud stop $(CLUSTER_CONFIG)
	@echo "✅ Cloud cluster VMs stopped successfully"

# Deploy Kubernetes to Cloud cluster (single consolidated playbook)
.PHONY: cloud-cluster-deploy
cloud-cluster-deploy: cloud-cluster-inventory
	@echo "=========================================="
	@echo "Deploying Kubernetes Cluster via Kubespray"
	@echo "=========================================="
	@echo "Inventory: $(CLOUD_INVENTORY_OUTPUT)"
	@echo "Cluster Config: $(CLUSTER_CONFIG)"
	@echo ""
	@echo "Deploying complete Kubernetes cluster..."
	@ANSIBLE_CONFIG=ansible/ansible.cfg \
	ANSIBLE_COLLECTIONS_PATH=ansible/collections \
	uv run ansible-playbook \
		-v \
		-i $(CLOUD_INVENTORY_OUTPUT) \
		-e "cluster_config=$(CLUSTER_CONFIG)" \
		-e "inventory_file=$(CLOUD_INVENTORY_OUTPUT)" \
		ansible/playbooks/playbook-cloud-runtime.yml
	@echo ""
	@echo "✅ Kubernetes cluster deployment completed"

# Destroy Cloud cluster VMs
.PHONY: cloud-cluster-destroy
cloud-cluster-destroy: venv-create
	@echo "Destroying Cloud cluster VMs..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how cloud destroy $(CLUSTER_CONFIG)
	@echo "✅ Cloud cluster destroyed successfully"

# Check Cloud cluster status
.PHONY: cloud-cluster-status
cloud-cluster-status: venv-create
	@echo "Checking Cloud cluster status..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@uv run ai-how cloud status $(CLUSTER_CONFIG)

#==============================================================================
# GitOps and Kubernetes Manifest Deployment (Wrapper Targets)
#==============================================================================
# These targets call the k8s-manifests/Makefile for actual implementation

# GitOps deployment targets (delegate to k8s-manifests/Makefile)
.PHONY: gitops-deploy-mlops-stack
gitops-deploy-mlops-stack:
	@$(MAKE) -C k8s-manifests gitops-deploy-mlops-stack

.PHONY: gitops-deploy-minio
gitops-deploy-minio:
	@$(MAKE) -C k8s-manifests gitops-deploy-minio

.PHONY: gitops-deploy-postgresql
gitops-deploy-postgresql:
	@$(MAKE) -C k8s-manifests gitops-deploy-postgresql

.PHONY: gitops-deploy-apps
gitops-deploy-apps:
	@$(MAKE) -C k8s-manifests gitops-deploy-apps

.PHONY: gitops-validate
gitops-validate:
	@$(MAKE) -C k8s-manifests gitops-validate

.PHONY: gitops-status
gitops-status:
	@$(MAKE) -C k8s-manifests gitops-status

.PHONY: gitops-update-repo-url
gitops-update-repo-url:
	@$(MAKE) -C k8s-manifests gitops-update-repo-url GIT_REPO_URL=$(GIT_REPO_URL)

# Manual k8s deployment targets (delegate to k8s-manifests/Makefile)
.PHONY: k8s-deploy-manual
k8s-deploy-manual:
	@$(MAKE) -C k8s-manifests k8s-deploy-manual

.PHONY: k8s-deploy-minio-manual
k8s-deploy-minio-manual:
	@$(MAKE) -C k8s-manifests k8s-deploy-minio-manual

.PHONY: k8s-deploy-postgresql-manual
k8s-deploy-postgresql-manual:
	@$(MAKE) -C k8s-manifests k8s-deploy-postgresql-manual

.PHONY: k8s-validate-manifests
k8s-validate-manifests:
	@$(MAKE) -C k8s-manifests k8s-validate-manifests

#==============================================================================
# System-wide Cluster Management (Both HPC and Cloud)
#==============================================================================

# Start complete ML system (both HPC and Cloud clusters)
.PHONY: system-start
system-start: venv-create clean-ssh-keys
	@echo "=========================================="
	@echo "Starting Complete ML Platform"
	@echo "=========================================="
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@echo ""
	@uv run ai-how system start $(CLUSTER_CONFIG)

# Stop complete ML system (both HPC and Cloud clusters)
.PHONY: system-stop
system-stop: venv-create
	@echo "=========================================="
	@echo "Stopping Complete ML Platform"
	@echo "=========================================="
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@echo ""
	@uv run ai-how system stop $(CLUSTER_CONFIG)

# Deploy complete ML system (both HPC and Cloud clusters)
.PHONY: system-deploy
system-deploy: hpc-cluster-deploy cloud-cluster-deploy
	@echo "=========================================="
	@echo "✅ Complete ML Platform Deployed"
	@echo "=========================================="
	@echo ""
	@echo "Both HPC and Cloud clusters have been deployed successfully."
	@echo ""
	@echo "Next Steps:"
	@echo "  - HPC Cluster: ssh -i $(SSH_PRIVATE_KEY) admin@192.168.100.10"
	@echo "  - Cloud Cluster: Check kubeconfig in output/cluster-state/kubeconfigs/"
	@echo "  - Verify services: make system-status"

# Show status of complete ML system
.PHONY: system-status
system-status: venv-create
	@echo "=========================================="
	@echo "Complete ML Platform Status"
	@echo "=========================================="
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@echo ""
	@uv run ai-how system status $(CLUSTER_CONFIG)

# Destroy complete ML system (both HPC and Cloud clusters)
.PHONY: system-destroy
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
.PHONY: cluster-start
cluster-start: system-start

.PHONY: cluster-stop
cluster-stop: system-stop

.PHONY: cluster-status
cluster-status: system-status

.PHONY: cluster-destroy
cluster-destroy: system-destroy

.PHONY: cluster-inventory
cluster-inventory: hpc-cluster-inventory

.PHONY: cluster-deploy
cluster-deploy: hpc-cluster-deploy

#==============================================================================
# SSH Key Management
#==============================================================================
# Remove SSH host keys for cluster VMs to avoid "host key verification failed" errors
# after rebuilding VMs. Uses vm-utils functions to discover running VMs and their IPs.

# Remove SSH host keys for cluster IPs defined in configuration
# This is called BEFORE cluster-start to proactively clean old keys
.PHONY: clean-ssh-keys
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

# Full cluster validation: inventory -> start -> deploy -> tests -> stop
.PHONY: validate-cluster-full
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
.PHONY: validate-cluster-runtime
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
	@echo "                        (Docker-in-Docker enabled by default, set DEV_CONTAINER_ENABLE_DOCKER_SOCKET=0 to disable)"
	@echo "  make run-docker     - Run a command in the container (use COMMAND=\"...\")."
	@echo "                        (Docker-in-Docker enabled by default, set DEV_CONTAINER_ENABLE_DOCKER_SOCKET=0 to disable)"
	@echo "  make containers-deploy-beegfs - Build all containers and deploy them to BeeGFS via hpc-container-manager."
	@echo "      (Controller IP auto-detected via \"ai-how system status\" unless CONTAINER_DEPLOY_CONTROLLER is set.)"
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
	@echo "  make system-deploy     - Deploy both HPC (SLURM) and Cloud (K8s) clusters."
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
	@echo "GitOps Application Deployment (implemented in k8s-manifests/Makefile):"
	@echo "  make gitops-deploy-mlops-stack - Deploy all MLOps apps via GitOps (App of Apps)."
	@echo "  make gitops-deploy-minio       - Deploy MinIO individually via GitOps."
	@echo "  make gitops-deploy-postgresql  - Deploy PostgreSQL individually via GitOps."
	@echo "  make gitops-deploy-apps        - Deploy all apps individually (not App of Apps)."
	@echo "  make gitops-validate           - Validate GitOps configuration (repo URLs, etc)."
	@echo "  make gitops-status             - Check ArgoCD application status."
	@echo "  make gitops-update-repo-url    - Update Git repo URL (use GIT_REPO_URL=...)."
	@echo ""
	@echo "Manual Kubernetes Deployment (implemented in k8s-manifests/Makefile):"
	@echo "  make k8s-deploy-manual         - Deploy all apps directly with kubectl."
	@echo "  make k8s-deploy-minio-manual   - Deploy MinIO directly (no ArgoCD)."
	@echo "  make k8s-deploy-postgresql-manual - Deploy PostgreSQL directly (no ArgoCD)."
	@echo "  make k8s-validate-manifests    - Validate manifests with kustomize build."
	@echo ""
	@echo "  Note: For detailed k8s/GitOps help, run: make -C k8s-manifests help"
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
	@echo "Configuration Variables (defined in Makefile.vars):"
	@echo "  CLUSTER_STATE_DIR           - Cluster state directory (default: output/cluster-state)"
	@echo "  CLUSTER_RENDERED            - Path to rendered config (default: \$${CLUSTER_STATE_DIR}/rendered-config.yaml)"
	@echo "  CLUSTER_CONFIG              - Path to cluster config (default: config/example-multi-gpu-clusters.yaml)"
	@echo "  CLUSTER_NAME                - HPC cluster name for inventory (default: hpc)"
	@echo "  CLOUD_CLUSTER_NAME          - Cloud cluster name for inventory (default: cloud)"
	@echo "  CLOUD_CLUSTER_KUBECONFIG    - Path to kubeconfig (default: \$${CLUSTER_STATE_DIR}/kubeconfigs/cloud-cluster.kubeconfig)"
	@echo "  HPC_INVENTORY_OUTPUT        - HPC inventory output path (default: \$${CLUSTER_STATE_DIR}/hpc-inventory.ini)"
	@echo "  CLOUD_INVENTORY_OUTPUT      - Cloud inventory output path (default: \$${CLUSTER_STATE_DIR}/cloud-inventory.ini)"
	@echo "  INVENTORY_OUTPUT            - Generic inventory path (default: \$${HPC_INVENTORY_OUTPUT})"
	@echo "  SSH_KEYS_DIR                - SSH keys directory (default: build/shared/ssh-keys)"
	@echo "  SSH_PRIVATE_KEY             - SSH private key path (default: \$${SSH_KEYS_DIR}/id_rsa)"
	@echo "  DEV_CONTAINER_ENABLE_DOCKER_SOCKET - Enable Docker-in-Docker (default: 1, set to 0 to disable)"
	@echo ""
	@echo "Notes:"
	@echo "  - Shared variables are defined in Makefile.vars (included by both main and k8s-manifests Makefiles)"
	@echo "  - system-* targets use unified ai-how system commands for both clusters"
	@echo "  - Use hpc-cluster-* or cloud-cluster-* for individual cluster control"
	@echo "  - cluster-* targets now point to system-* for backward compatibility"
	@echo "  - Shared GPU scenarios: use hpc-cluster-* and cloud-cluster-* separately"
	@echo "  - GitOps/k8s targets are implemented in k8s-manifests/Makefile (wrapper targets provided here)"
