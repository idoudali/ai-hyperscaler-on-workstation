# Dockerfile for the development environment

# Use Debian 12 "Bookworm" as the base image
FROM debian:12

# Set environment variables to non-interactive to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system packages, development tools, and Python
RUN apt-get update && \
    apt-get install -y \
    git \
    build-essential \
    python3-pip \
    python3-venv \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    ansible \
    cmake \
    ninja-build && \
    rm -rf /var/lib/apt/lists/*

# Install HashiCorp tools (Terraform and Packer)
# Add HashiCorp GPG key
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add the HashiCorp repository
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# Install Terraform and Packer
RUN apt-get update && \
    apt-get install -y terraform packer

# Create a non-root user for security
RUN useradd -m -s /bin/bash developer
USER developer
WORKDIR /home/developer

# Set up a virtual environment for Python
RUN python3 -m venv /home/developer/venv
ENV PATH="/home/developer/venv/bin:$PATH"

# Copy Python requirements and install them
COPY --chown=developer:developer requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Set the working directory for the project
WORKDIR /workspace
