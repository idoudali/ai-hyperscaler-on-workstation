# PyTorch + CUDA 12.8 + MPI 4.1 Container for HPC Workloads
# Base image with CUDA 12.8 development tools and Ubuntu 24.04
FROM nvidia/cuda:12.8.0-devel-ubuntu24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHON_VERSION=3.10
ENV PYTORCH_VERSION=2.4.0
ENV MPI_VERSION=4.1.4

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python${PYTHON_VERSION} \
    python3-pip \
    python3-dev \
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
    libopenmpi-dev \
    && rm -rf /var/lib/apt/lists/*

# Install latest CMake from Kitware repository
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null && \
    apt-add-repository "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" && \
    apt-get update && \
    apt-get install -y cmake && \
    rm -rf /var/lib/apt/lists/* && \
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

# Install PyTorch with CUDA 12.1 support (closest available to CUDA 12.8)
RUN pip3 install --no-cache-dir --break-system-packages \
    torch==${PYTORCH_VERSION}+cu121 \
    torchvision \
    torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# Install MPI4Py (after OpenMPI is installed)
RUN pip3 install --no-cache-dir --break-system-packages mpi4py

# Install distributed training libraries
# RUN pip3 install --no-cache-dir --break-system-packages \
#     horovod[pytorch] \
#     deepspeed \
#     accelerate \
#     transformers

# Install monitoring and profiling tools
RUN pip3 install --no-cache-dir --break-system-packages \
    tensorboard \
    wandb \
    nvitop \
    py-spy \
    memory-profiler \
    psutil

# Install development and debugging tools
RUN pip3 install --no-cache-dir --break-system-packages \
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
LABEL maintainer="Pharos AI Hyperscaler Team"
LABEL description="PyTorch + CUDA 12.8 + MPI 4.1 for HPC distributed training"
LABEL pytorch.version="${PYTORCH_VERSION}"
LABEL cuda.version="12.8.0"
LABEL mpi.version="${MPI_VERSION}"
