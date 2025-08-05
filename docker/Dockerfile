# Dockerfile for the development environment

# Use Debian 12 "Bookworm" as the base image
FROM debian:12

# Set environment variables to non-interactive to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system packages, development tools, and Python
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ansible=7.7.0+dfsg-3+deb12u1 \
    build-essential=12.9 \
    cmake=3.25.1-1 \
    curl \
    git \
    gnupg \
    libvirt-clients=9.0.0-4+deb12u2 \
    lsb-release \
    ninja-build=1.11.1-2~deb12u1 \
    python3-pip=23.0.1+dfsg-1 \
    python3-venv=3.11.2-1+b1 \
    qemu-system-x86=1:7.2+dfsg-7+deb12u13 \
    qemu-utils=1:7.2+dfsg-7+deb12u13 \
    screen=4.9.0-4 \
    software-properties-common \
    sudo=1.9.13p3-1+deb12u1 \
    tmux=3.3a-3 \
    xorriso \
  && rm -rf /var/lib/apt/lists/*

# Set shell to fail on pipe errors for all subsequent RUN commands
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install HashiCorp tools (Terraform and Packer)
# Add HashiCorp GPG key
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add the HashiCorp repository
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# Install Terraform and Packer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    packer=1.14.0-1 \
    terraform=1.9.2-1 && \
    rm -rf /var/lib/apt/lists/*

# Unset the custom shell to avoid affecting other commands if not needed
SHELL ["/bin/sh", "-c"]

# Set up a virtual environment for Python in a common location
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Set a temporary working directory to copy and install requirements
WORKDIR /tmp

# Copy Python requirements and install them
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Set the final working directory for the project
WORKDIR /workspace
