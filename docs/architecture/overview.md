# Architecture Overview

**Status:** Production  
**Created:** 2025-01-20  
**Last Updated:** 2025-01-20

## Overview

The Hyperscaler on Workstation is a comprehensive high-performance computing (HPC) infrastructure solution
designed to run on workstation hardware. The system provides enterprise-grade HPC capabilities including GPU
acceleration, distributed computing, container orchestration, and parallel storage.

## System Architecture

The system is built using a modern, containerized architecture with the following key components:

### Core Infrastructure

- **SLURM Workload Manager**: Distributed job scheduling and resource management
- **BeeGFS Parallel Filesystem**: High-performance distributed storage
- **GPU Management**: NVIDIA GPU support with MIG (Multi-Instance GPU) partitioning
- **Container Runtime**: Docker and Apptainer for application isolation
- **Network**: High-speed interconnect for distributed computing

### Build System

The project uses a sophisticated build system that orchestrates the creation of all infrastructure components:

- **[Build System Documentation](build-system.md)**: Comprehensive guide to the build architecture
- **Development Container**: Docker-based isolated development environment
- **CMake Orchestration**: Ninja-based parallel build system
- **Packer Images**: Infrastructure VM images for HPC components
- **Container Images**: Application containers with Docker/Apptainer conversion

### Key Features

- **Scalable Architecture**: Designed to scale from single workstations to multi-node clusters
- **GPU Acceleration**: Full NVIDIA GPU support with advanced partitioning
- **Container Integration**: Seamless Docker and Apptainer container support
- **Parallel Storage**: High-performance BeeGFS distributed filesystem
- **Automated Deployment**: Infrastructure as Code with Ansible and Terraform
- **Monitoring**: Comprehensive system monitoring and observability

## Architecture Components

### Infrastructure Layer

- **HPC Controller Node**: SLURM controller with management services
- **HPC Compute Nodes**: SLURM compute nodes with GPU support
- **Storage Nodes**: BeeGFS storage and metadata servers
- **Network Infrastructure**: High-speed interconnect and management networks

### Application Layer

- **Container Runtime**: Docker and Apptainer for application deployment
- **Job Scheduler**: SLURM for distributed job management
- **GPU Management**: NVIDIA drivers and MIG support
- **Monitoring**: System monitoring and alerting

### Development Layer

- **Build System**: CMake-based build orchestration
- **Development Environment**: Containerized development tools
- **CI/CD Pipeline**: Automated testing and deployment
- **Documentation**: Comprehensive system documentation

## Getting Started

To understand the system architecture and begin development:

1. **Read the Build System Documentation**: Start with the [Build System Architecture](build-system.md)
   to understand how components are built and integrated
2. **Review Component Documentation**: Explore individual component documentation in the Components section
3. **Follow the Quickstart Guides**: Use the Getting Started section for hands-on experience
4. **Explore Tutorials**: Work through the tutorials to understand system capabilities

## Related Documentation

- **[Build System Architecture](build-system.md)**: Complete build system documentation
- **[Network Architecture](network.md)**: Network design and configuration
- **[Storage Architecture](storage.md)**: BeeGFS parallel filesystem design
- **[GPU Architecture](gpu.md)**: GPU management and MIG configuration
- **[Container Architecture](containers.md)**: Container runtime and management
- **[SLURM Architecture](slurm.md)**: Workload manager configuration
- **[Monitoring Architecture](monitoring.md)**: System monitoring and observability

## Design Principles

The architecture follows these key principles:

- **Modularity**: Components are designed to be independently deployable and maintainable
- **Scalability**: System can scale from single workstations to large clusters
- **Reliability**: Built-in redundancy and fault tolerance
- **Performance**: Optimized for high-performance computing workloads
- **Security**: Comprehensive security controls and isolation
- **Maintainability**: Clear separation of concerns and comprehensive documentation
