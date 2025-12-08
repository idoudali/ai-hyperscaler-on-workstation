# syntax=docker/dockerfile:1
# PyTorch + CUDA 12.8 + MPI 4.1 Container for HPC Workloads
# Multi-stage build with base PyTorch layer and Oumi framework layer
# Uses BuildKit cache mounts for faster pip package installation

################################################################################
# Stage 1: Base PyTorch + CUDA + MPI (target: pytorch-cuda12.1-mpi4.1)
################################################################################
FROM nvidia/cuda:12.8.0-devel-ubuntu24.04 AS pytorch-cuda12.1-mpi4.1

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTORCH_VERSION=2.4.0
ENV MPI_VERSION=4.1.4
ENV VIRTUAL_ENV=/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Install system dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    python-is-python3 \
    build-essential \
    wget \
    curl \
    git \
    vim \
    openssh-client \
    openssh-server \
    software-properties-common \
    lsb-release \
    gnupg \
    pkg-config \
    libopenmpi-dev

# Install latest CMake from Kitware repository
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null && \
    apt-add-repository "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" && \
    apt-get update && \
    apt-get install -y cmake && \
    cmake --version

# Install Open MPI with CUDA and PMIx support
RUN wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-${MPI_VERSION}.tar.gz && \
    tar -xzf openmpi-${MPI_VERSION}.tar.gz && \
    cd openmpi-${MPI_VERSION} && \
    ./configure --prefix=/usr/local \
                --with-cuda=/usr/local/cuda \
                --with-pmix \
                --enable-mpi-cxx && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cd .. && \
    rm -rf openmpi-${MPI_VERSION}*

# Create Python virtual environment
RUN python -m venv $VIRTUAL_ENV

# Install PyTorch with CUDA 12.1 support (closest available to CUDA 12.8)
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
    torch==${PYTORCH_VERSION}+cu121 \
    torchvision \
    torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# Install MPI4Py (after OpenMPI is installed)
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install mpi4py

# Install distributed training libraries
# RUN --mount=type=cache,target=/root/.cache/pip \
#     pip install \
#     horovod[pytorch] \
#     deepspeed \
#     accelerate \
#     transformers

# Install monitoring and profiling tools
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
    tensorboard \
    wandb \
    nvitop \
    py-spy \
    memory-profiler \
    psutil

# Install development and debugging tools
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
    ipython \
    jupyter \
    matplotlib \
    pandas \
    scikit-learn \
    pytest \
    black \
    flake8

# Set up SSH for MPI
RUN mkdir -p /var/run/sshd && \
    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
    echo "UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config

# Create workspace directory
WORKDIR /workspace

# Set up entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Default command
CMD ["/bin/bash"]

# Labels for metadata
LABEL maintainer="AI-HOW Team"
LABEL description="PyTorch + CUDA 12.8 + MPI 4.1 for HPC distributed training"
LABEL pytorch.version="${PYTORCH_VERSION}"
LABEL cuda.version="12.8.0"
LABEL mpi.version="${MPI_VERSION}"

################################################################################
# Stage 2: Oumi Framework Layer (target: pytorch-cuda12.1-mpi4.1-oumi)
################################################################################
FROM pytorch-cuda12.1-mpi4.1 AS pytorch-cuda12.1-mpi4.1-oumi

# Install Oumi framework and dependencies
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
    oumi

# Install additional ML/AI libraries for Oumi
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
    transformers \
    datasets \
    accelerate \
    peft \
    bitsandbytes \
    safetensors

# Install additional monitoring tools
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
    aim \
    mlflow

# Install pyyaml for configuration file handling
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
    pyyaml

# Entrypoint is inherited from base stage and already handles Oumi detection

# Labels for metadata
LABEL maintainer="AI-HOW Team"
LABEL description="Oumi Framework + PyTorch + CUDA 12.8 + MPI 4.1 for HPC distributed LLM training"
LABEL oumi.framework="enabled"
LABEL base.image="pytorch-cuda12.1-mpi4.1"
