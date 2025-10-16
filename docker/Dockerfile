
# Dockerfile for the development environment

# Use Debian 13 "Trixie" as the base image
FROM debian:trixie

# Set environment variables to non-interactive to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system packages, development tools, and Python
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ansible \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    debhelper \
    default-jdk \
    devscripts \
    dh-dkms \
    git \
    gnupg \
    gosu \
    kmod \
    libattr1-dev \
    libblkid-dev \
    libcurl4-openssl-dev \
    libibverbs-dev \
    libnl-3-200 \
    libnl-3-dev \
    libnl-genl-3-200 \
    libnl-route-3-200 \
    libnl-route-3-dev \
    librdmacm-dev \
    libssl-dev \
    libtool \
    libvirt-clients \
    libvirt-dev \
    lsb-release \
    ninja-build \
    pkg-config \
    python3-dev \
    python3-pip \
    python3-venv \
    qemu-system-x86 \
    qemu-utils \
    screen \
    squashfs-tools \
    sudo \
    tmux \
    uidmap \
    uuid-dev \
    xfslibs-dev \
    xorriso \
    xz-utils \
    zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

# Set shell to fail on pipe errors for all subsequent RUN commands
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install Apptainer build dependencies
# Reference: https://apptainer.org/docs/admin/main/installation.html
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    cryptsetup \
    fakeroot \
    fuse3 \
    libfuse-dev \
    libseccomp-dev \
    squashfs-tools \
    squashfuse \
    uidmap \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Go (required for building Apptainer)
RUN GO_VERSION=1.23.2 && \
    ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
      amd64) GO_ARCH=amd64 ;; \
      arm64) GO_ARCH=arm64 ;; \
      *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Build and install Apptainer from source
WORKDIR /tmp
RUN APPTAINER_VERSION=1.4.3 && \
    curl -fsSL "https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer-${APPTAINER_VERSION}.tar.gz" -o "apptainer-${APPTAINER_VERSION}.tar.gz" && \
    tar -xzf "apptainer-${APPTAINER_VERSION}.tar.gz"

WORKDIR /tmp/apptainer-1.4.3
RUN ./mconfig --prefix=/usr/local --without-suid && \
    make -C builddir && \
    make -C builddir install && \
    rm -rf /tmp/apptainer-* && \
    apptainer --version

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
