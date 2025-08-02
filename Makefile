# Makefile for managing the development environment

# Set default shell to bash
SHELL := /bin/bash

# Docker image settings
IMAGE_NAME := pharos-dev
IMAGE_TAG  := latest
FULL_IMAGE_NAME := $(IMAGE_NAME):$(IMAGE_TAG)

# Default target
.PHONY: all
all: help

# Build the Docker image
.PHONY: build-docker
build-docker:
	@echo "Building Docker image: $(FULL_IMAGE_NAME)..."
	docker build -t $(FULL_IMAGE_NAME) ./docker

# Run an interactive shell in the development container
.PHONY: shell-docker
shell-docker:
	@echo "Starting interactive shell in Docker container..."
	docker run -it --rm -v "$(PWD)":/workspace $(FULL_IMAGE_NAME) /bin/bash

# Push the Docker image to a registry (uncomment and configure)
# REGISTRY_URL := your-registry-url
# .PHONY: push-docker
# push-docker: build-docker
# 	@echo "Pushing Docker image to $(REGISTRY_URL)..."
# 	docker tag $(FULL_IMAGE_NAME) $(REGISTRY_URL)/$(FULL_IMAGE_NAME)
# 	docker push $(REGISTRY_URL)/$(FULL_IMAGE_NAME)

# Clean up Docker artifacts
.PHONY: clean-docker
clean-docker:
	@echo "Cleaning up Docker images and containers..."
	docker rmi $(FULL_IMAGE_NAME) || true
	docker container prune -f || true

# Lint the Dockerfile
.PHONY: lint-docker
lint-docker:
	@echo "Linting Dockerfile..."
	# Add your Dockerfile linter command here, e.g., hadolint docker/Dockerfile

# Display help message
.PHONY: help
help:
	@echo "Development Environment Makefile"
	@echo "--------------------------------"
	@echo "Available commands:"
	@echo "  make build-docker   - Build the development Docker image."
	@echo "  make shell-docker   - Start an interactive shell in the container."
	@echo "  make push-docker    - Build and push the image to a registry (needs configuration)."
	@echo "  make clean-docker   - Remove the Docker image and old containers."
	@echo "  make lint-docker    - Lint the Dockerfile."
	@echo "  make help           - Display this help message."
