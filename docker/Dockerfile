
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
    ca-certificates \
    cmake=3.25.1-1 \
    curl \
    git \
    gnupg \
    gosu \
    libvirt-clients=9.0.0-4+deb12u2 \
    libvirt-dev \
    lsb-release \
    ninja-build=1.11.1-2~deb12u1 \
    pkg-config \
    python3-dev \
    python3-pip=23.0.1+dfsg-1 \
    python3-venv=3.11.2-1+b1 \
    qemu-system-x86 \
    qemu-utils \
    screen=4.9.0-4 \
    software-properties-common \
    squashfs-tools \
    sudo \
    tmux=3.3a-3 \
    uidmap \
    xorriso \
  && rm -rf /var/lib/apt/lists/*

# Set shell to fail on pipe errors for all subsequent RUN commands
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install Apptainer/Singularity from GitHub releases
# Reference: https://github.com/apptainer/apptainer/releases
RUN APPTAINER_VERSION=1.3.6 && \
    ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer_${APPTAINER_VERSION}_${ARCH}.deb" \
      -o /tmp/apptainer.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends /tmp/apptainer.deb && \
    rm -rf /tmp/apptainer.deb /var/lib/apt/lists/*

# Install Docker Engine following official documentation
# Reference: https://docs.docker.com/engine/install/ubuntu/
# Add Docker's official GPG key
RUN curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository to Apt sources
# hadolint ignore=SC1091
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine, CLI, containerd, and Docker Compose
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

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

# Install uv - the new package manager and virtual environment tool
# Install to /usr/local/bin for system-wide access
# hadolint ignore=DL4006
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" INSTALLER_NO_MODIFY_PATH=1 sh

# Set up a virtual environment for Python in a common location
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Set a temporary working directory to copy and install requirements
WORKDIR /tmp

# Copy Python requirements and install them
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Working directory will be set dynamically by the container script

# Set bash as the default shell for better command support
SHELL ["/bin/bash", "-c"]

# Copy and set up the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
