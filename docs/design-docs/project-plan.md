# Project Plan: Hyperscaler on a Workstation

**Objective:** To implement the automated, dual-stack AI infrastructure as
described in the `hyperscaler-on-workstation.md` design document. This plan
outlines the concrete steps for an AI agent to execute, transforming the
architectural blueprint into a robust, production-ready, emulated environment
with comprehensive error handling, security, and monitoring.

**Project Status:** Phase 0 Foundation - Complete (95% Complete), Phase 1 - Complete (100% Complete) **Last
Updated:** 2025-01-27 **Latest Enhancement:** Complete Python CLI orchestrator
implementation with full HPC VM management and PCIe GPU passthrough validation

## Current Status Summary

### 📊 Implementation Metrics

- **Total Python Code**: 8,628+ lines in ai_how CLI package
- **VM Management Code**: 4,308+ lines of comprehensive VM lifecycle management  
- **System Validation Scripts**: 2,166+ lines of shell scripts for host validation
- **Built Golden Images**: 1 HPC base image (hpc-base.qcow2) ready for deployment
- **Configuration Schema**: Comprehensive JSON schema with 265+ lines of validation rules
- **Real PCIe Examples**: Template configuration with actual hardware specifications

### 🎯 Major Achievements

- **Complete HPC VM Lifecycle Management**: Full start/stop/status/destroy operations with rollback
- **Advanced PCIe GPU Passthrough**: Multi-function device support with validation
- **Comprehensive Configuration System**: Schema validation, templates, and real-world examples  
- **Production-Ready Infrastructure**: Docker environment, CI/CD, and quality tooling
- **Extensive Host Validation**: GPU inventory, VFIO debugging, and prerequisite checking

## Implementation Status

### ✅ Completed Components

- **Development Environment**: Docker-based development environment with pinned
  versions of tools (Terraform, Packer, Ansible, CMake, Ninja)
- **Build System Core**: CMake-based build system with Ninja generator support
  and custom targets for building minimal base images.
- **Development Workflow**: Makefile automation, pre-commit hooks, conventional
  commits, and basic CI/CD, with all relative imports migrated to absolute imports.
- **Documentation**: Comprehensive design documents and implementation plans.
- **Python CLI Orchestrator (8,628+ lines of code)**: **FULLY COMPLETE**
  - Complete CLI framework with Typer, robust configuration validation, comprehensive logging
  - Full command structure for HPC and Cloud cluster management (`ai_how` package, provides `ai-how` command)
  - Advanced PCIe passthrough validation and GPU assignment display
  - State management and persistence with JSON tracking
  - Comprehensive error handling and rollback capabilities
- **HPC VM Management (4,308+ lines of code)**: **FULLY COMPLETE**
  - Complete system for provisioning, managing, and destroying HPC VMs
  - LibVirt Client, VM Lifecycle Manager, Volume Manager, Network Manager
  - XML templating system with Jinja2 for dynamic VM configuration
  - State Models, Cluster State Manager, GPU Mapper integration
  - Full CLI Integration with start/stop/status/destroy operations
  - PCIe passthrough device management and validation
- **Cluster Configuration Management**: **FULLY COMPLETE**
  - Comprehensive `cluster.yaml` schema design with hardware acceleration support
  - JSON schema validation with PCIe passthrough and multi-function device validation
  - Configuration validator implementation with detailed error reporting
  - Template cluster configuration with real PCIe device examples
- **Host Preparation and Validation (2,166+ lines of shell scripts)**: **FULLY COMPLETE**
  - Complete system prerequisite checker (`check_prereqs.sh` - 1,224 lines)
  - Detailed validation for CPU virtualization, IOMMU, KVM, GPU drivers, and system resources
  - GPU discovery and inventory script (`gpu_inventory.sh` - 654 lines) for host GPU enumeration
  - VFIO debugging and PCIe passthrough validation scripts
  - Comprehensive hardware compatibility checking
- **Golden Image Creation**: **FULLY COMPLETE**
  - Packer templates for both HPC and Cloud base images
  - Built HPC base image (hpc-base.qcow2) with cloud-init integration
  - Shared SSH key management and automated provisioning
  - CMake integration with dependency management
  - Ansible integration for package installation during image builds

### 🚧 Minimal/Skeleton Implementations

- **Ansible Infrastructure**: Basic directory structure and minimal roles implemented
  - Only 2 role task files with basic package installations (tmux, htop, vim, curl, wget)
  - HPC and Cloud base package roles exist but need comprehensive HPC/K8s software packages
  - Cluster setup roles are placeholder implementations
  - Inventory generation script exists but needs full implementation
- **Cloud Cluster Management**: Stub implementation in CLI
  - Cloud cluster commands exist but return "Not implemented" errors
  - Cloud VM provisioning logic not implemented (HPC VM management is complete)
- **CI/CD Pipeline**: Basic linting workflow implemented; multi-stage quality
  gates and deployment automation are pending.

### 📋 Next Milestones

- **Complete Ansible Role Implementation** (Phase 0.8):
  - Implement comprehensive package installation in HPC and Cloud base package roles
  - Add SLURM, MPI, and HPC-specific software to HPC base packages role
  - Add containerd, Kubernetes, and cloud-native software to Cloud base packages role
  - Implement cluster setup roles for post-deployment configuration
- **Implement Cloud Cluster Management** (Phase 0.7 completion):
  - Complete Cloud VM provisioning using existing VM management infrastructure
  - Implement cloud cluster start/stop/status/destroy operations
  - Add Kubernetes cluster configuration and deployment automation
- **Complete Ansible Inventory Generation**:
  - Finish dynamic inventory generation from cluster.yaml
  - Integrate with CLI for automated playbook execution
- **Implement GPU Resource Management** (Phase 3.1):
  - MIG management and vGPU provisioning scripts
  - GPU resource allocation and scheduling
- **Add MLOps Stack Deployment** (Phase 6): Deploy MLOps services on Kubernetes cluster

### 🎯 Immediate Action Items (Priority Order)

1.  **Complete Ansible Role Content** (Phase 0.8 - Highest Priority):
    - Implement comprehensive HPC base packages role with SLURM, MPI, and development tools
    - Implement comprehensive Cloud base packages role with containerd, Kubernetes, and cloud-native tools
    - Create functional cluster setup roles for post-deployment SLURM and Kubernetes configuration
    - Develop complete main execution playbooks for both cluster types

2.  **Complete Cloud Cluster Management** (Phase 0.7 completion):
    - Extend existing VM management infrastructure to support Cloud cluster provisioning
    - Implement cloud cluster start/stop/status/destroy operations using existing patterns
    - Add Kubernetes-specific configuration and networking support

3.  **Finish Ansible Integration** (Phase 0.8):
    - Complete dynamic inventory generation from `cluster.yaml`
    - Integrate Ansible playbook execution with CLI commands
    - Add comprehensive error handling and rollback for Ansible operations

4.  **Implement GPU Resource Management** (Phase 3.1):
    - Create MIG management script (`manage_mig.py`) for dynamic GPU partitioning
    - Implement smart vGPU provisioner (`create_vgpus.py`) with `cluster.yaml` integration
    - Add GPU resource validation and conflict detection
    - Create resource cleanup manager for safe GPU resource destruction
    - **Note**: PCIe passthrough management is already implemented in the CLI

5.  **Add MLOps Stack Deployment** (Phase 6):
    - Deploy MLOps services (MLflow, MinIO, PostgreSQL) on Kubernetes cluster
    - Implement model serving and experiment tracking integration

6.  **Enhancement and Optimization**:
    - Add monitoring and observability stack
    - Implement performance optimization and resource management
    - Enhance CI/CD pipeline with multi-stage quality gates

---

## Phase 0: Foundation - Development Environment, Risk Assessment, and Architecture Selection

This foundational phase establishes the development environment, assesses risks,
and allows for architectural decisions based on project requirements and
constraints.

- [x] **0.1. Create Development Docker Image:**
  - [x] Write a `Dockerfile` for the development environment.
  - [x] The image should be based on Debian 12 to match the host and guest OS.
  - [x] Install all necessary tools with pinned versions: `packer`, `terraform`,
    `ansible`, `cmake`, `ninja-build`, `git`, `python3`, `jsonschema`, `jinja2`,
    etc.
  - [x] Create comprehensive dependency manifest (`requirements.txt`, `Pipfile`,
    etc.) with exact versions.
  - [x] Build the Docker image and tag it (e.g., `hyperscaler-dev:latest`).
  - [ ] Push the image to a container registry (e.g., GitHub Docker Registry)
    for CI usage.
  - [ ] Add security scanning for the container image.

- [ ] **0.2. Implement Enhanced Build System:**
  - [x] Create a root `CMakeLists.txt` file with dependency validation.
  - [x] Configure the project to use the Ninja generator.
  - [x] Add custom CMake targets with error handling and rollback capabilities.
  - [x] Implement version compatibility checks for all tools.
  - [ ] Add automated testing targets for each build artifact.
  - [ ] Create multi-stage CI/CD pipeline with quality gates.

- [ ] **0.3. Risk Assessment and Mitigation Planning:**
  - [ ] Create comprehensive risk matrix identifying potential failure points:
    - [ ] Hardware incompatibility (CPU virtualization, IOMMU support)
    - [ ] NVIDIA driver conflicts and installation failures
    - [ ] Resource exhaustion scenarios
    - [ ] Network configuration conflicts
    - [ ] Security vulnerabilities
  - [ ] Implement pre-flight system validation scripts.
  - [ ] Create automated rollback procedures for each critical operation.
  - [ ] Design system state snapshot strategy before major changes.
  - [ ] Document recovery procedures and escalation paths.

- [ ] **0.4. Architecture Selection Framework:**
  - [ ] Create decision matrix for implementation approaches:
    - [ ] Custom implementation (current plan)
    - [ ] NVIDIA DeepOps adoption
    - [ ] Modular composable approach
    - [ ] Cloud-native consolidation (Volcano on Kubernetes)
  - [ ] Implement modular design allowing component substitution.
  - [ ] Create migration paths between different architectural approaches.
  - [ ] Document trade-offs and selection criteria.

- [x] **0.5. Cluster Configuration Management:**
  - [x] **Cluster Definition Framework:**
    - [x] Create comprehensive cluster configuration YAML schema design.
    - [x] Design HPC cluster specification structure (nodes, resources, SLURM
      config).
    - [x] Design Cloud cluster specification structure (K8s nodes, resources,
      networking).
    - [x] Define global infrastructure settings (networks, GPU allocation,
      security).
  - [x] **Configuration Validation System:**
    - [x] Implement JSON Schema for `config/cluster.yaml` validation.
    - [x] Create configuration validator script with detailed error reporting.
    - [x] Add resource constraint and feasibility validation.
    - [x] Implement cross-cluster dependency validation.
  - [x] **Default Configuration Templates:**
    - [x] Create minimal development cluster template.
    - [ ] Create production-like cluster template.
    - [ ] Create example configurations for different use cases.
    - [x] Add configuration documentation and usage guides.

- [ ] **0.6. Test Infrastructure Setup:**
  - [x] Create automated test suites for each component.
  - [x] Implement comprehensive test framework with nox and pytest.
  - [ ] Set up performance benchmarking infrastructure.
  - [ ] Create test data generators for MLOps workflows.
  - [ ] Add load testing capabilities for GPU resource allocation.

---

## 0.7. Python CLI Orchestrator for Cluster Management

This phase introduces a Python-based CLI that acts as the orchestration layer
across configuration, provisioning, GPU resource management, and cluster
lifecycle. It prioritizes HPC first, then extends to the cloud cluster, and
enforces resource guardrails to handle limited host capacity.

- [x] **0.7.1. Configuration Schema and Validation Flow:**
  - [x] Author `schemas/cluster.schema.json` for structural validation of
    `config/cluster.yaml`.
  - [x] Implement validation module using `jsonschema` for structural
    validation.
  - [x] Add semantic validators (Python) for cross-field checks:
    - [x] GPU feasibility (MIG profiles on MIG-capable devices, no
      oversubscription).
    - [x] Network IP range overlaps and subnet correctness.
    - [x] Cross-dependencies (GPU-enabled nodes require GPU allocation).
  - [x] Integrate validation into CLI `validate` command with readable error
    reporting.

- [x] **0.7.2. CLI Skeleton and Command Contracts:**
  - [x] Create CLI (`ai_how/cli.py`) with Typer framework and subcommands:
    - [x] `validate` (wired to schema + semantic checks).
    - [x] `hpc [start|stop|status|destroy]` (stubs with explicit "Not
    implemented" errors). - [x] `cloud [start|stop|status|destroy]` (stubs with
    explicit "Not implemented" errors).
    - [x] `plan show` (produce summarized actions/drift; initially a stub).
    - [x] `inventory gpu` (host GPU discovery and inventory; initially a stub).
  - [x] Add standardized exit codes and structured stderr for unimplemented
    features.
  - [x] Provide `--config` flag to point to `config/cluster.yaml` and `--state`
    for `output/state.json`.

- [x] **0.7.3. HPC-First Implementation:**
  - [x] Implement `hpc start` to provision HPC VMs per `cluster.yaml` (libvirt
    XML templates, qcow2 disks).
  - [x] Implement `hpc stop` to gracefully shutdown HPC VMs.
  - [x] Implement `hpc status` to report VM and service health.
  - [x] Implement `hpc destroy` with safe teardown and rollback checks.
  - [x] **COMPLETE**: Full HPC cluster lifecycle management implemented (4,308+ lines)

- [ ] **0.7.4. Cloud Cluster Enablement:**
  - [ ] Implement `cloud start` to provision control plane and worker nodes per
    `cluster.yaml`.
  - [ ] Implement `cloud stop`, `cloud status`, and `cloud destroy` with parity
    to HPC behavior.
  - [ ] Generate Ansible inventory for K8s and invoke `ansible/playbooks/playbook-cloud.yml`.

- [ ] **0.7.5. Independent Lifecycle Control:**
  - [ ] Ensure HPC and Cloud subcommands operate independently (separate
    inventories, domains, and state entries).
  - [ ] Implement locks and idempotence to avoid cross-cluster interference.

- [ ] **0.7.6. Limited Resource Guardrails:**
  - [ ] Add capacity checks during `start` to evaluate CPU/RAM/GPU constraints.
  - [ ] Block concurrent start of both clusters when capacity is insufficient;
    print actionable guidance.
  - [ ] Provide `--force` override flag with explicit warnings and confirmation
    prompt (non-interactive mode fails).
  - [ ] Record decisions and capacity snapshots in `output/state.json` for drift
    analysis.

- [ ] **0.7.7. Ansible Integration and Role Execution:** **PARTIALLY IMPLEMENTED**
  - [ ] **Dynamic Inventory Generation:** **SKELETON IMPLEMENTED**
    - [x] Basic `ansible/inventories/generate_inventory.py` script structure created
    - [ ] Complete implementation to create inventories from `cluster.yaml`
    - [ ] Generate separate inventories for HPC and cloud clusters
    - [ ] Include proper variable assignments and group definitions
  - [ ] **Role-Based Configuration:** **MINIMAL IMPLEMENTATION**
    - [x] Basic `ansible/roles/hpc-cluster-setup/` and `cloud-cluster-setup/` directory structure
    - [x] Ansible playbook integration with Packer for image building
    - [ ] Complete HPC cluster configuration role implementation
    - [ ] Complete Kubernetes cluster configuration role implementation  
    - [ ] Role dependency management and execution order
    - [ ] Comprehensive error handling and rollback for role failures
  - [x] **State Management Integration:** **FULLY IMPLEMENTED**
    - [x] Comprehensive state tracking in `output/state.json` via ClusterStateManager
    - [x] VM lifecycle state recording and persistence
    - [x] State-based rollback for failed VM operations
    - [x] Deployment status reporting and validation

---

## Phase 0.8: Ansible Infrastructure and Roles

This phase establishes the Ansible automation framework with roles for both pre-installation
(Packer) and post-deployment cluster configuration. The structure supports both HPC and
cloud cluster automation with clear separation of concerns.

### Proposed Ansible Directory Structure

```bash
ansible/
├── ansible.cfg                    # Ansible configuration for local deployment
├── requirements.txt               # Python dependencies for Ansible
├── collections/
│   └── requirements.yml          # Required Ansible collections
├── inventories/
│   ├── generate_inventory.py     # Dynamic inventory generator from cluster.yaml
│   ├── hpc/                     # HPC cluster inventory templates
│   └── cloud/                   # Cloud cluster inventory templates
├── group_vars/
│   ├── all.yml                  # Global variables for all clusters
│   ├── hpc_cluster.yml          # HPC-specific variables
│   └── cloud_cluster.yml        # Cloud-specific variables
├── host_vars/                   # Host-specific variables (if needed)
├── roles/
│   ├── hpc-base-packages/       # Package installation for HPC base images
│   │   ├── tasks/
│   │   ├── defaults/
│   │   ├── vars/
│   │   └── meta/
│   ├── cloud-base-packages/     # Package installation for cloud base images
│   │   ├── tasks/
│   │   ├── defaults/
│   │   ├── vars/
│   │   └── meta/
│   ├── hpc-cluster-setup/       # Post-deployment HPC cluster configuration
│   │   ├── tasks/
│   │   ├── handlers/
│   │   ├── templates/
│   │   ├── defaults/
│   │   ├── vars/
│   │   └── meta/
│   └── cloud-cluster-setup/     # Post-deployment Kubernetes cluster configuration
│       ├── tasks/
│       ├── handlers/
│       ├── templates/
│       ├── defaults/
│       ├── vars/
│       └── meta/
├── playbooks/
│   ├── playbook-hpc.yml         # Main HPC cluster deployment playbook
│   ├── playbook-cloud.yml       # Main Kubernetes cluster deployment playbook
│   └── playbook-mlops.yml       # MLOps stack deployment playbook
└── vault/                       # Encrypted sensitive data
    └── secrets.yml
```

- [ ] **0.8.1. Basic Ansible Structure and Dependencies:**
  - [ ] **Create Ansible Directory Structure:**
    - [ ] Create `ansible/` root directory with proper organization
    - [ ] Set up `ansible/roles/` for modular role definitions
    - [ ] Create `ansible/playbooks/` for main execution playbooks
    - [ ] Set up `ansible/inventories/` for dynamic inventory generation
    - [ ] Create `ansible/group_vars/` and `ansible/host_vars/` for configuration
    - [ ] Set up `ansible/collections/requirements.yml` for external dependencies
  - [ ] **Ansible Configuration and Dependencies:**
    - [ ] Create `ansible/ansible.cfg` with optimized settings for local deployment
    - [ ] Define `ansible/requirements.txt` for Python dependencies
    - [ ] Set up `ansible/collections/requirements.yml` for required collections
    - [ ] Configure SSH connection settings and key management
    - [ ] Set up Ansible vault for sensitive configuration data

- [ ] **0.8.2. Package Installation Roles for Packer (Pre-installation):**
  - [ ] **HPC Base Image Role (`ansible/roles/hpc-base-packages/`):**
    - [ ] Define package lists for HPC workloads:
      - [ ] Core system packages: `build-essential`, `git`, `wget`, `curl`
      - [ ] HPC tools: `slurm-wlm`, `munge`, `openmpi-bin`, `libopenmpi-dev`
      - [ ] Development tools: `cmake`, `ninja-build`, `gcc`, `g++`
      - [ ] Monitoring: `htop`, `iotop`, `nethogs`, `sysstat`
      - [ ] Security: `fail2ban`, `unattended-upgrades`, `auditd`
    - [ ] Configure system optimizations for HPC workloads
    - [ ] Set up user accounts and SSH key management
    - [ ] Implement security hardening configurations
  - [ ] **Cloud Base Image Role (`ansible/roles/cloud-base-packages/`):**
    - [ ] Define package lists for cloud-native workloads:
      - [ ] Container runtime: `containerd`, `runc`, `docker.io`
      - [ ] Kubernetes tools: `kubeadm`, `kubelet`, `kubectl`
      - [ ] Network tools: `calico-ctl`, `flannel`, `cilium-cli`
      - [ ] Storage tools: `ceph-common`, `glusterfs-client`
      - [ ] Monitoring: `prometheus-node-exporter`, `grafana-agent`
    - [ ] Configure container runtime optimizations
    - [ ] Set up Kubernetes prerequisites and dependencies
    - [ ] Implement cloud-native security configurations

- [ ] **0.8.3. Cluster Setup Roles (Post-deployment):**
  - [ ] **HPC Cluster Setup Role (`ansible/roles/hpc-cluster-setup/`):**
    - [ ] **SLURM Controller Configuration:**
      - [ ] Install and configure SLURM controller daemon (`slurmctld`)
      - [ ] Set up SLURM database and accounting
      - [ ] Configure SLURM partitions and QoS settings
      - [ ] Set up MUNGE authentication service
      - [ ] Configure SLURM spool and log directories
    - [ ] **SLURM Compute Node Configuration:**
      - [ ] Install and configure SLURM compute daemon (`slurmd`)
      - [ ] Set up GPU resource management (GRES) configuration
      - [ ] Configure cgroup isolation for job resource management
      - [ ] Set up node health monitoring and reporting
      - [ ] Configure SLURM prolog and epilog scripts
    - [ ] **HPC Cluster Integration:**
      - [ ] Configure shared filesystem mounts (NFS/CephFS)
      - [ ] Set up user account synchronization
      - [ ] Configure job submission and scheduling policies
      - [ ] Set up cluster monitoring and alerting
  - [ ] **Cloud Cluster Setup Role (`ansible/roles/cloud-cluster-setup/`):**
    - [ ] **Kubernetes Control Plane:**
      - [ ] Bootstrap Kubernetes cluster with `kubeadm`
      - [ ] Configure high-availability control plane
      - [ ] Set up cluster networking (CNI) and DNS
      - [ ] Configure RBAC and security policies
      - [ ] Set up cluster monitoring and logging
    - [ ] **Kubernetes Worker Nodes:**
      - [ ] Join worker nodes to the cluster
      - [ ] Configure node labels and taints
      - [ ] Set up GPU operator and device plugins
      - [ ] Configure storage classes and persistent volumes
      - [ ] Set up node monitoring and health checks
    - [ ] **Cloud Infrastructure Services:**
      - [ ] Deploy ingress controller and load balancer
      - [ ] Set up storage provisioner and CSI drivers
      - [ ] Configure network policies and security groups
      - [ ] Deploy monitoring stack (Prometheus, Grafana)

- [ ] **0.8.4. Main Execution Playbooks:**
  - [ ] **HPC Cluster Playbook (`ansible/playbooks/playbook-hpc.yml`):**
    - [ ] Orchestrate complete HPC cluster deployment
    - [ ] Include role dependencies and execution order
    - [ ] Handle configuration validation and error handling
    - [ ] Implement rollback procedures for failed deployments
    - [ ] Generate cluster status reports and validation
  - [ ] **Cloud Cluster Playbook (`ansible/playbooks/playbook-cloud.yml`):**
    - [ ] Orchestrate complete Kubernetes cluster deployment
    - [ ] Handle multi-node cluster bootstrapping
    - [ ] Implement progressive deployment with validation
    - [ ] Configure post-deployment services and monitoring
    - [ ] Generate cluster health reports and access information

- [ ] **0.8.5. Dynamic Inventory and Configuration Management:**
  - [ ] **Dynamic Inventory Generation:**
    - [ ] Create `ansible/inventories/generate_inventory.py` script
    - [ ] Parse `config/cluster.yaml` to generate Ansible inventory
    - [ ] Support both HPC and cloud cluster inventory formats
    - [ ] Generate host and group variables automatically
    - [ ] Support for different deployment environments
  - [ ] **Configuration Templating:**
    - [ ] Create Jinja2 templates for all configuration files
    - [ ] Support variable substitution from `cluster.yaml`
    - [ ] Implement configuration validation and testing
    - [ ] Support configuration versioning and migration

---

## Cluster Configuration Structure

The `config/cluster.yaml` file serves as the single source of truth for defining
both HPC and Cloud cluster specifications. This configuration drives all
provisioning, GPU allocation, and deployment automation.

### YAML Configuration Structure

```yaml
# Example cluster.yaml structure with PCIe passthrough for 2 discrete NVIDIA GPUs
version: "1.0"
metadata:
  name: "hyperscaler-emulation"
  description: "Dual-stack AI infrastructure emulation"
  
global: {}

clusters:
  hpc:
    network:
      subnet: "192.168.100.0/24"
      bridge: "virbr100"
    controller:
      cpu_cores: 4
      memory_gb: 8
      disk_gb: 100
      ip_address: "192.168.100.10"
    
    compute_nodes:
      - cpu_cores: 8
        memory_gb: 16
        disk_gb: 200
        ip: "192.168.100.11"
        pcie_passthrough:
          enabled: true
          devices:
            - pci_address: "0000:65:00.0"
              device_type: "gpu"
              vendor_id: "10de"
              device_id: "2684"
              iommu_group: 1
      - cpu_cores: 8
        memory_gb: 16
        disk_gb: 200
        ip: "192.168.100.12"
        pcie_passthrough:
          enabled: true
          devices:
            - pci_address: "0000:65:00.1"
              device_type: "gpu"
              vendor_id: "10de"
              device_id: "2684"
              iommu_group: 2
    
    slurm_config:
      partitions: ["gpu", "debug"]
      default_partition: "gpu"
      max_job_time: "24:00:00"

  cloud:
    network:
      subnet: "192.168.200.0/24"
      bridge: "virbr200"
    control_plane:
      cpu_cores: 4
      memory_gb: 8
      disk_gb: 100
      ip_address: "192.168.200.10"
    
    worker_nodes:
      cpu_workers:
        count: 1
        cpu_cores: 4
        memory_gb: 8
        disk_gb: 100
        ip_range: "192.168.200.11"
      
      gpu_workers:
        - cpu_cores: 8
          memory_gb: 16
          disk_gb: 200
          ip: "192.168.200.12"
          pcie_passthrough:
            enabled: true
            devices:
              - pci_address: "0000:65:00.2"
                device_type: "gpu"
                vendor_id: "10de"
                device_id: "2684"
                iommu_group: 3
        - cpu_cores: 8
          memory_gb: 16
          disk_gb: 200
          ip: "192.168.200.13"
          pcie_passthrough:
            enabled: true
            devices:
              - pci_address: "0000:ca:00.0"
                device_type: "gpu"
                vendor_id: "10de"
                device_id: "1e36"
                iommu_group: 4
    
    kubernetes_config:
      cni: "calico"
      ingress: "nginx"
      storage_class: "local-path"
```

### JSON Schema Validation Points

The `schemas/cluster.schema.json` will validate:

- **Resource Constraints**: Ensure CPU, memory, and disk allocations are within
  reasonable bounds
- **Network Validation**: Verify IP ranges don't overlap and are properly
  formatted
- **PCIe/GPU Passthrough Validation**:
  - Validate PCIe address format (0000:xx:xx.x pattern)
  - Ensure vendor_id and device_id are valid 4-digit hex values
  - Validate IOMMU group assignments are non-negative integers
  - Prevent duplicate PCIe address assignments across all VMs
  - Validate device_type enum values (gpu, network, storage, other)
- **GPU Inventory Validation**:
  - Ensure GPU inventory devices have unique IDs and PCI addresses
  - Validate MIG capability flags match known device capabilities
  - Cross-reference VM PCIe assignments against inventory devices
- **Cross-Dependencies**: Validate that VMs with pcie_passthrough enabled have
  valid device assignments
- **Configuration Consistency**: Ensure cluster sizing and GPU assignments are
  feasible for the target hardware

---

## Implementation Infrastructure - ✅ COMPLETE

The following development infrastructure has been successfully implemented to
support the project:

### ✅ Development Environment Infrastructure - COMPLETE

- **Docker Environment**: Complete containerized development environment with KVM/libvirt support
- **Build Automation**: Comprehensive Makefile with Docker workflow automation and virtual environment management
- **Dependency Management**: Pinned tool versions and comprehensive dependency manifest
- **Build System**: CMake-based project with Ninja generator support and automated Packer integration
- **Python Environment**: Full virtual environment setup with uv package management

### ✅ Code Quality and Standards - COMPLETE

- **Pre-commit Hooks**: Comprehensive linting and validation pipeline covering all languages
- **Conventional Commits**: Commitizen configuration for standardized commit messages
- **Markdown Standards**: Linting configuration with project-specific rules for documentation
- **Shell Script Quality**: ShellCheck integration for comprehensive script validation
- **Python Quality**: Full linting with ruff, mypy type checking, and pytest testing framework

### ✅ CI/CD Foundation - COMPLETE

- **GitHub Actions**: Multi-stage linting and validation workflow
- **Multi-language Linting**: Support for Python, shell scripts, YAML, markdown, and Dockerfile
- **Git Hooks**: Local validation before commits and pushes
- **Automated Testing**: Comprehensive test framework with nox and pytest

### ✅ Documentation Framework - COMPLETE

- **Design Documents**: Complete architectural documentation with detailed implementation plans
- **API Documentation**: Python package documentation with mkdocs
- **Configuration Documentation**: Comprehensive cluster configuration examples and validation
- **Troubleshooting Guides**: Extensive validation and debugging script documentation

---

## Phase 1: Host Preparation and Validation - ✅ COMPLETE

This phase prepares the physical host machine with comprehensive validation and
error handling. Enhanced security and recovery procedures ensure a stable
foundation for the virtualized environment.

**Status: 100% Complete - 2,166+ lines of comprehensive validation scripts implemented**

- [x] **1.1. Enhanced Prerequisite Validation:**
  - [x] **Script 1: Comprehensive System Checker (`check_prereqs.sh`)**
    - [x] Validate CPU virtualization (Intel VT-x / AMD-V) with detailed error
      messages.
    - [x] Validate IOMMU (Intel VT-d / AMD-Vi) with specific troubleshooting
      guidance.
    - [x] Check KVM acceleration availability and performance.
    - [x] Verify `nouveau` driver blacklist status.
    - [x] Validate virtualization packages installation and versions.
    - [x] Check user group memberships (`libvirt`, `kvm`).
    - [x] Test NVIDIA GPU visibility and basic functionality.
    - [x] Validate system resources (RAM, disk space, CPU cores).
    - [x] Check for conflicting services and processes.
  - [x] **Script 2: GPU Inventory (`gpu_inventory.sh`)**
    - [x] Enumerate available GPUs and their capabilities.
    - [x] Detect MIG support and current configuration.
    - [x] Report GPU memory and utilization status.

- [x] **1.1.1. PCIe GPU Passthrough Prerequisites:**
  - [x] **PCIe Passthrough Validation (`debug_vfio.sh`, `improved_vfio_steps.sh`)**: **COMPLETE**
    - [x] Validate IOMMU configuration and enabled status (`intel_iommu=on` or `amd_iommu=on`).
    - [x] Check IOMMU groups for GPU isolation and validate group membership.
    - [x] Verify VFIO driver availability and kernel module loading.
    - [x] Validate that target GPUs are not bound to host drivers (`nvidia`, `nouveau`).
    - [x] Check for PCIe ACS (Access Control Services) support and configuration.
    - [x] Report potential conflicts with existing GPU utilization.
    - [x] Generate PCIe device inventory with IOMMU group mappings.
  
  - [x] **PCIe Passthrough Management (Integrated in Python CLI)**: **COMPLETE**
    - [x] PCIe passthrough validation integrated in ai-how CLI with comprehensive validation
    - [x] Multi-function device support (GPU + Audio) with proper ordering
    - [x] Real-world PCIe device configuration examples in template-cluster.yaml
    - [x] VFIO driver binding validation and conflict detection
    - [x] IOMMU group assignment validation and device isolation checks

- [x] **1.2. Host Configuration (Manual/User-Managed):**
  - [x] **Validation and Detection**: Comprehensive prerequisite validation implemented in `check_prereqs.sh`
  - [x] **Nouveau driver validation**: Automated checking for blacklisted nouveau drivers
  - [x] **User group validation**: Automated validation of libvirt and kvm group memberships
  - [x] **Service configuration validation**: Automated checking of KVM and virtualization services
  - [x] **Note**: Host configuration is user-managed with comprehensive validation and guidance

- [x] **1.3. Network Infrastructure (VM-Managed):**
  - [x] **Network Management**: Integrated into VM management system (NetworkManager class)
  - [x] **Dynamic Network Creation**: Libvirt network creation with subnet validation
  - [x] **Configuration Validation**: Network subnet conflict detection in cluster configuration
  - [x] **Bridge Management**: Automated bridge creation and management for VM clusters
  - [x] **Note**: Network infrastructure is created dynamically by VM management system

- [x] **1.4. Security Hardening (Integrated):**
  - [x] **SSH Key Management**: Automated SSH key generation and distribution for VMs
  - [x] **VM Isolation**: Network segmentation through libvirt bridge isolation
  - [x] **Access Controls**: Packer-based VM configuration with proper user permissions
  - [x] **Cloud-init Security**: Secure user configuration and access control setup

---

## Phase 2: Automated Golden Image Creation - ✅ COMPLETE (Core Implementation)

This phase uses Packer to build standardized, secure Debian 13 base images for
the VMs with comprehensive testing and validation. Images are built with
cloud-init integration and Ansible provisioning.

**Status: 95% Complete - Core Packer system implemented, images built successfully**

- [x] **2.1. Enhanced Packer Configurations:** **COMPLETE**
  - [x] Write a Packer template (`hpc-base.pkr.hcl`) for the HPC cluster base image.
    - [x] Cloud-init configuration with secure user setup and SSH key management
    - [x] Ansible integration for package installation during build
    - [x] Network configuration for libvirt environment
    - [x] System optimization and cleanup procedures
  - [x] Write a Packer template (`cloud-base.pkr.hcl`) for the cloud cluster base image.
    - [x] Cloud-init configuration optimized for Kubernetes workloads
    - [x] Container runtime preparation
    - [x] Optimized build process with comprehensive cleanup
  - [x] Configure both templates with error handling and retry logic.
  - [x] **Built Images**: HPC base image (hpc-base.qcow2) successfully created
  - [x] CMake integration with dependency management and shared SSH keys
  - [ ] **Enhancement Needed**: Add comprehensive security vulnerability scanning

- [x] **2.2. Cloud-Init Configuration (Implemented):**
  - [x] **HPC Base Cloud-Init (`hpc-base-user-data.yml`)**: **COMPLETE**
    - [x] Secure admin user setup with SSH key authentication
    - [x] Basic system packages and HPC preparation
    - [x] Network configuration for libvirt environment
    - [x] Security hardening with proper limits and configurations
  - [x] **Cloud Base Cloud-Init (`cloud-base-user-data.yml`)**: **COMPLETE**
    - [x] Debian user setup for Kubernetes workloads
    - [x] System growth and container runtime preparation
    - [x] Cloud-native optimizations and security configurations
  - [x] **Common Security Baseline**: Implemented across both image types
  - [x] **Automated SSH Key Management**: Shared SSH keys across all images

- [x] **2.2.1. Ansible-Enhanced Package Installation:** **IMPLEMENTED**
  - [x] **Integrated Ansible Roles with Packer:** **COMPLETE**
    - [x] `ansible/roles/hpc-base-packages/` integrated with HPC Packer template
    - [x] Ansible playbook execution during Packer image build process
    - [x] Comprehensive error handling and build validation
  - [x] **Package Installation Workflow:** **IMPLEMENTED**
    - [x] Cloud-init handles basic OS configuration (no preseed needed)
    - [x] Ansible roles handle package installation and system configuration
    - [x] Package installation validation through Packer provisioners
    - [ ] **Enhancement Needed**: Expand package lists in Ansible roles (currently minimal)

- [x] **2.3. Build and Validation Pipeline:** **LARGELY COMPLETE**
  - [x] Execute CMake targets with comprehensive error handling.
  - [x] **Build Artifacts Management**:
    - [x] Create image artifacts with build metadata and timestamps
    - [x] Generate build logs and validation output
    - [x] Automatic cleanup and rebuild capabilities
  - [x] **Basic Validation**:
    - [x] Packer template validation before build
    - [x] Cloud-init configuration validation
    - [x] SSH connectivity testing during build
    - [x] Package installation verification
  - [ ] **Advanced Testing** (Enhancement needed):
    - [ ] Automated boot validation tests
    - [ ] Security compliance checks
    - [ ] Performance benchmarking
    - [ ] Comprehensive package integrity verification

---

## Phase 3: Infrastructure Provisioning and Resource Management - ⚠️ PARTIAL IMPLEMENTATION

This phase implements intelligent resource management with dynamic GPU
partitioning, capacity planning, and comprehensive validation of the
infrastructure provisioning process.

**Status: 60% Complete - PCIe passthrough fully implemented, MIG/vGPU management pending**

- [x] **3.1. Enhanced GPU Resource Management:** **PARTIALLY COMPLETE**
  - [ ] **Script 1: Intelligent MIG Manager (`manage_mig.py`)** - **NOT IMPLEMENTED**
    - [ ] Implement capacity planning calculator for GPU resources.
    - [ ] Add dynamic MIG reconfiguration based on workload demands.
    - [ ] Create performance benchmarking for different MIG configurations.
    - [ ] Implement resource utilization monitoring and optimization.
    - [ ] Add conflict detection and resolution for GPU resource allocation.
  
  - [ ] **Script 2: Smart vGPU Provisioner (`create_vgpus.py`)** - **NOT IMPLEMENTED**
    - [ ] Read and validate `config/cluster.yaml` with schema validation.
    - [ ] Parse GPU allocation requirements from both HPC and Cloud cluster specifications.
    - [ ] Calculate optimal MIG slicing strategy with performance considerations.
    - [ ] Validate total GPU resource demands against available hardware.
    - [ ] Implement resource constraint validation and error handling.
    - [ ] Create GPU Instances with comprehensive error checking.
    - [ ] Generate vGPU mediated devices (mdevs) with UUID tracking.
    - [ ] Save detailed mapping to `output/mdev_map.json` with metadata.
    - [ ] Implement rollback procedures for failed GPU allocations.
  
  - [ ] **Script 3: Resource Cleanup Manager (`cleanup_resources.py`)** - **NOT IMPLEMENTED**
    - [ ] Safe cleanup of GPU resources with validation.
    - [ ] Implement staged cleanup with confirmation prompts.
    - [ ] Add resource usage validation before cleanup.
    - [ ] Create backup of resource configurations before destruction.

  - [x] **PCIe Passthrough Resource Management** - **FULLY COMPLETE**
    - [x] **Integrated in Python CLI**: Complete PCIe passthrough validation and management
    - [x] Read and validate `config/cluster.yaml` for PCIe passthrough device assignments.
    - [x] Parse discrete GPU allocation requirements for HPC and Cloud compute nodes.
    - [x] Validate PCIe device availability and IOMMU group compatibility.
    - [x] Implement conflict detection between different GPU allocation modes.
    - [x] Generate libvirt XML hostdev configurations for PCIe passthrough.
    - [x] Create device mapping and assignment validation system.
    - [x] Multi-function device support (GPU + Audio) with proper ordering.
    - [x] Comprehensive PCIe passthrough validation integrated in `ai-how validate` command.

- [x] **3.2. Dynamic Cluster Configuration:** **FULLY COMPLETE**
  - [x] **Cluster Definition YAML Structure (`config/template-cluster.yaml`):** **COMPLETE**
    - [x] **HPC cluster specification**:
      - [x] Controller node: CPU cores, memory, disk size, network configuration
      - [x] Compute nodes: CPU cores per node, memory per node, PCIe passthrough GPU assignment
      - [x] PCIe passthrough device specifications with real-world PCI addresses
      - [x] Hardware acceleration configuration (KVM, CPU model, topology)
      - [x] SLURM-specific settings (partitions, QoS, accounting)
    - [x] **Cloud cluster specification**:
      - [x] Control plane node: CPU cores, memory, disk size, HA configuration
      - [x] CPU and GPU worker nodes with resource specifications
      - [x] GPU worker nodes with PCIe passthrough device assignment
      - [x] Kubernetes-specific settings (CNI, ingress, storage classes)
    - [x] **Global infrastructure settings**:
      - [x] Network topology and IP address ranges with conflict detection
      - [x] Base image path management with relative/absolute path support
      - [x] Hardware acceleration and performance optimization settings
  
  - [x] **JSON Schema Validation (`schemas/cluster.schema.json`):** **COMPREHENSIVE**
    - [x] Define comprehensive schema structure with required/optional fields
    - [x] **Implemented field validation rules**:
      - [x] Resource constraints (CPU, memory, disk validation with ranges)
      - [x] Network IP range validation and subnet conflict detection
      - [x] PCIe passthrough validation (address format, vendor/device IDs)
      - [x] Hardware acceleration validation (CPU models, features, topology)
      - [x] Cross-dependencies validation (PCIe devices require proper configuration)
    - [x] Descriptive error messages for all validation failures
    - [x] Schema versioning support (version 1.0 implemented)
  
  - [x] **Configuration Management Tools:** **FULLY IMPLEMENTED**
    - [x] **Configuration validator integrated in Python CLI** (`ai-how validate`) with detailed error reporting
    - [x] **Default configuration template**: Comprehensive template with real PCIe device examples
    - [x] **Base image path validation**: Support for relative and absolute paths
    - [x] **Configuration testing and validation**: Integrated in CLI with comprehensive checks
    - [x] **Real-world examples**: Template includes actual PCI addresses and hardware specifications

---

## Phase 4: Security Hardening and Access Control

This phase implements comprehensive security measures, authentication systems,
and access controls throughout the infrastructure to ensure a production-ready
security posture.

- [ ] **4.1. Authentication and Authorization:**
  - [ ] **SSH Key Management:**
    - [ ] Generate and distribute SSH keys for all VMs.
    - [ ] Implement key rotation procedures.
    - [ ] Configure SSH hardening (disable password auth, limit users).
    - [ ] Set up SSH certificate authority for centralized key management.
  
  - [ ] **RBAC Configuration:**
    - [ ] Configure role-based access control for SLURM.
    - [ ] Set up Kubernetes RBAC policies and service accounts.
    - [ ] Implement fine-grained permissions for different user roles.
    - [ ] Create security policies for resource access.

- [ ] **4.2. Network Security:**
  - [ ] **Firewall and Network Policies:**
    - [ ] Implement network segmentation with iptables/nftables.
    - [ ] Configure Kubernetes Network Policies.
    - [ ] Set up intrusion detection and monitoring.
    - [ ] Create secure communication channels between clusters.
  
  - [ ] **Certificate Management:**
    - [ ] Set up internal Certificate Authority.
    - [ ] Generate and distribute TLS certificates for all services.
    - [ ] Implement certificate rotation and monitoring.
    - [ ] Configure mutual TLS where applicable.

- [ ] **4.3. Secrets and Configuration Management:**
  - [ ] **Secrets Management:**
    - [ ] Implement secure storage for sensitive configurations.
    - [ ] Set up Kubernetes secrets management.
    - [ ] Configure encrypted storage for passwords and keys.
    - [ ] Implement secrets rotation procedures.
  
  - [ ] **Security Monitoring:**
    - [ ] Set up security event logging and monitoring.
    - [ ] Configure alerting for security incidents.
    - [ ] Implement audit trails for all administrative actions.
    - [ ] Create security compliance reporting.

---

## Phase 5: Parallel Cluster Deployment (HPC and Cloud)

This phase deploys both clusters in parallel with enhanced provisioning,
comprehensive testing, and integration validation. Both HPC and Kubernetes
clusters are deployed simultaneously for efficiency.

- [ ] **5.1. Enhanced Infrastructure Provisioning:**
  - [ ] **Dynamic VM Provisioning Script (`scripts/provision.py`):**
    - [ ] Read and validate `config/cluster.yaml` with schema checking.
    - [ ] Parse HPC cluster VM specifications (controller + compute nodes).
    - [ ] Parse Cloud cluster VM specifications (control plane + worker nodes).
    - [ ] Calculate total resource requirements with feasibility validation.
    - [ ] Validate resource allocation against available host capacity.
    - [ ] Generate templated libvirt XML configurations with error handling.
    - [ ] Create copy-on-write qcow2 disks with integrity checks.
    - [ ] Deploy VMs with comprehensive error handling and rollback.
    - [ ] Generate Ansible inventories with proper variable assignment.
    - [ ] Implement parallel provisioning for both clusters.

- [ ] **5.2. HPC Cluster Configuration:**
  - [ ] **Enhanced SLURM Deployment (`ansible/playbooks/playbook-hpc.yml`):**
    - [ ] Use `ansible/roles/hpc-cluster-setup/` for comprehensive SLURM configuration
    - [ ] Install and configure MUNGE with security hardening.
    - [ ] Deploy SLURM controller with high availability considerations.
    - [ ] Configure compute nodes with GPU resource management.
    - [ ] Attach vGPU mdevs with validation and error handling.
    - [ ] Configure PCIe passthrough devices for discrete GPU access:
      - [ ] Generate libvirt XML with hostdev PCIe passthrough configuration.
      - [ ] Validate IOMMU group isolation and device assignment.
      - [ ] Configure VM CPU affinity and NUMA topology for optimal performance.
      - [ ] Implement PCIe device hotplug support for maintenance scenarios.
    - [ ] Install NVIDIA guest drivers with version compatibility.
    - [ ] Validate PCIe passthrough GPU functionality in guest VMs:
      - [ ] Test NVIDIA driver installation and GPU detection.
      - [ ] Verify CUDA runtime and libraries functionality.
      - [ ] Validate GPU memory allocation and compute capabilities.
      - [ ] Test direct GPU access without virtualization overhead.
    - [ ] Set up monitoring and logging for SLURM services.
    - [ ] Configure backup and recovery procedures.
  
  - [ ] **HPC Testing and Validation:**
    - [ ] Comprehensive cluster health checks.
    - [ ] GPU allocation and scheduling tests (both MIG/vGPU and PCIe passthrough).
    - [ ] PCIe passthrough specific validation:
      - [ ] Test exclusive GPU access without hypervisor overhead.
      - [ ] Validate GPU memory bandwidth and compute performance.
      - [ ] Test GPU-to-GPU communication for multi-GPU workloads.
      - [ ] Verify SLURM gres (generic resource) configuration for discrete GPUs.
    - [ ] Performance benchmarking with standard HPC workloads.
    - [ ] Security compliance validation.

- [ ] **5.3. Kubernetes Cluster Configuration:**
  - [ ] **Enhanced Kubernetes Deployment (`ansible/playbooks/playbook-cloud.yml`):**
    - [ ] Use `ansible/roles/cloud-cluster-setup/` for comprehensive Kubernetes configuration
    - [ ] Install container runtime with security configurations.
    - [ ] Bootstrap Kubernetes with kubeadm and security hardening.
    - [ ] Configure networking with CNI and network policies.
    - [ ] Deploy NVIDIA GPU Operator with MIG support.
    - [ ] Set up monitoring and logging infrastructure.
    - [ ] Configure backup and disaster recovery.
  
  - [ ] **Kubernetes Testing and Validation:**
    - [ ] Cluster readiness and health checks.
    - [ ] GPU resource discovery and allocation tests.
    - [ ] Network policy and security validation.
    - [ ] Performance and load testing.

---

## Phase 6: MLOps Stack Deployment

This phase deploys the comprehensive MLOps and storage services onto the
Kubernetes cluster with enhanced security, monitoring, and high availability
configurations.

- [ ] **6.1. MLOps Infrastructure Preparation:**
  - [ ] **Node Configuration and Labeling:**
    - [ ] Label CPU worker nodes for MLOps services: `compute=cpu`.
    - [ ] Label GPU worker nodes for inference workloads: `compute=gpu`.
    - [ ] Configure node affinity and anti-affinity rules.
    - [ ] Set up resource quotas and limits for different workload types.

- [ ] **6.2. Core MLOps Services Deployment:**
  - [ ] **Enhanced Storage Layer (`playbook-mlops.yml`):**
    - [ ] Deploy MinIO with high availability and security configurations.
    - [ ] Set up PostgreSQL with backup and replication.
    - [ ] Configure persistent storage with proper access controls.
    - [ ] Implement data encryption at rest and in transit.
  
  - [ ] **MLOps Platform Services:**
    - [ ] Deploy MLflow with authentication and authorization.
    - [ ] Install Kubeflow with security hardening.
    - [ ] Configure DVC integration with MinIO backend.
    - [ ] Set up model registry and experiment tracking.
    - [ ] Deploy KServe for model serving infrastructure.

- [ ] **6.3. Integration and Security Configuration:**
  - [ ] **Service Integration:**
    - [ ] Configure secure communication between services.
    - [ ] Set up single sign-on (SSO) integration.
    - [ ] Implement API gateway and rate limiting.
    - [ ] Configure service mesh for advanced traffic management.
  
  - [ ] **Data and Model Security:**
    - [ ] Implement data governance and access controls.
    - [ ] Set up model versioning and provenance tracking.
    - [ ] Configure audit logging for all MLOps operations.
    - [ ] Implement compliance reporting and monitoring.

---

## Phase 7: Monitoring and Observability

This phase implements comprehensive monitoring, logging, and observability
across the entire infrastructure to ensure operational excellence and proactive
issue detection.

- [ ] **7.1. Infrastructure Monitoring:**
  - [ ] **Metrics Collection and Visualization:**
    - [ ] Deploy Prometheus for metrics collection with retention policies.
    - [ ] Set up Grafana with custom dashboards for HPC and cloud clusters.
    - [ ] Configure GPU utilization monitoring and alerting.
    - [ ] Implement node-level resource monitoring (CPU, memory, disk, network).
    - [ ] Set up cluster-level health and performance metrics.
  
  - [ ] **Specialized GPU Monitoring:**
    - [ ] Deploy NVIDIA DCGM for detailed GPU metrics.
    - [ ] Configure MIG instance monitoring and utilization tracking.
    - [ ] Set up GPU temperature, power, and error monitoring.
    - [ ] Implement GPU workload analytics and optimization recommendations.

- [ ] **7.2. Logging and Audit Infrastructure:**
  - [ ] **Centralized Logging:**
    - [ ] Deploy ELK stack (Elasticsearch, Logstash, Kibana) for log
      aggregation.
    - [ ] Configure log shipping from all VMs and containers.
    - [ ] Implement log parsing and structured logging.
    - [ ] Set up log retention and archival policies.
  
  - [ ] **Security and Audit Logging:**
    - [ ] Configure security event monitoring and correlation.
    - [ ] Set up audit trails for all administrative actions.
    - [ ] Implement compliance logging and reporting.
    - [ ] Configure real-time security alerting.

- [ ] **7.3. Distributed Tracing and Performance:**
  - [ ] **MLOps Workflow Tracing:**
    - [ ] Implement distributed tracing for MLOps workflows.
    - [ ] Set up performance profiling for training and inference jobs.
    - [ ] Configure end-to-end workflow monitoring.
    - [ ] Implement bottleneck detection and optimization recommendations.
  
  - [ ] **Alerting and Notification:**
    - [ ] Configure multi-channel alerting (email, Slack, PagerDuty).
    - [ ] Set up alert escalation and on-call procedures.
    - [ ] Implement intelligent alert correlation and noise reduction.
    - [ ] Create runbooks for common alert scenarios.

---

## Phase 8: End-to-End Validation and Testing

This phase implements comprehensive testing and validation of the entire system
through automated test suites, performance benchmarking, and complete MLOps
workflow validation.

- [ ] **8.1. Infrastructure Integration Testing:**
  - [ ] **Automated Test Suite Execution:**
    - [ ] Run comprehensive infrastructure health checks.
    - [ ] Execute integration tests between all clusters and services.
    - [ ] Validate network connectivity and security policies.
    - [ ] Test resource allocation and GPU scheduling across both clusters.
    - [ ] Verify backup and recovery procedures.
  
  - [ ] **Performance Benchmarking:**
    - [ ] Execute standardized HPC benchmarks on SLURM cluster.
    - [ ] Run Kubernetes performance and scalability tests.
    - [ ] Benchmark GPU performance and MIG efficiency.
    - [ ] Test PCIe passthrough GPU performance benchmarks:
      - [ ] Compare native vs. virtualized GPU performance.
      - [ ] Benchmark memory bandwidth and compute throughput.
      - [ ] Test multi-GPU workload scaling and inter-GPU communication.
      - [ ] Validate latency and overhead measurements for discrete GPU access.
    - [ ] Test MLOps workflow performance and throughput.

- [ ] **8.2. Oumi Orchestration Setup and Configuration:**
  - [ ] **Enhanced Oumi Configuration:**
    - [ ] Install and configure Oumi client with security credentials.
    - [ ] Create and validate launcher profiles for both clusters.
    - [ ] Set up secure authentication for all integrations.
    - [ ] Configure monitoring and logging for Oumi operations.
    - [ ] Create comprehensive workflow templates and recipes.

- [ ] **8.3. Complete MLOps Workflow Validation:**
  - [ ] **Training Workflow Validation:**
    - [ ] Create comprehensive training recipes with error handling.
    - [ ] Execute parallel training jobs to test resource allocation.
    - [ ] Test PCIe passthrough GPU training workflows:
      - [ ] Validate exclusive GPU access for high-performance training.
      - [ ] Test multi-GPU distributed training with discrete GPU access.
      - [ ] Verify CUDA and cuDNN functionality in PCIe passthrough mode.
      - [ ] Benchmark training performance vs. vGPU alternatives.
    - [ ] Validate model artifacts, metadata, and experiment tracking.
    - [ ] Test failure scenarios and recovery procedures.
  
  - [ ] **Model Deployment and Inference Testing:**
    - [ ] Test model promotion and registry workflows.
    - [ ] Deploy multiple inference services with different resource
      requirements.
    - [ ] Validate autoscaling and load balancing.
    - [ ] Test model versioning and rollback procedures.
  
  - [ ] **End-to-End Workflow Integration:**
    - [ ] Execute complete CI/CD pipeline for model development.
    - [ ] Test cross-cluster data movement and synchronization.
    - [ ] Validate monitoring and alerting throughout the workflow.
    - [ ] Perform chaos engineering tests for resilience validation.

- [ ] **8.4. Security and Compliance Validation:**
  - [ ] **Security Testing:**
    - [ ] Execute penetration testing and vulnerability assessments.
    - [ ] Validate access controls and authentication mechanisms.
    - [ ] Test data encryption and secure communication channels.
    - [ ] Verify audit logging and compliance reporting.
  
  - [ ] **Operational Readiness Testing:**
    - [ ] Test disaster recovery and business continuity procedures.
    - [ ] Validate backup and restore operations.
    - [ ] Execute load testing and capacity planning validation.
    - [ ] Test operational runbooks and troubleshooting procedures.

---

## Phase 9: Backup and Disaster Recovery

This phase implements comprehensive backup strategies, disaster recovery
procedures, and business continuity planning to ensure data protection and
system resilience.

- [ ] **9.1. Infrastructure Backup Strategy:**
  - [ ] **VM and Configuration Backup:**
    - [ ] Implement automated VM snapshot scheduling before major changes.
    - [ ] Create incremental backup procedures for VM disks.
    - [ ] Set up configuration backup for all infrastructure components.
    - [ ] Implement version control for all configuration files.
    - [ ] Create automated backup verification and integrity checking.
  
  - [ ] **GPU and Resource Configuration Backup:**
    - [ ] Backup MIG configurations and resource allocations.
    - [ ] Create procedures for recreating vGPU mappings.
    - [ ] Document and backup network configurations.
    - [ ] Implement cluster state backup and restoration.

- [ ] **9.2. Data and Application Backup:**
  - [ ] **MLOps Data Protection:**
    - [ ] Implement automated backup for MLflow metadata and models.
    - [ ] Set up MinIO data replication and backup strategies.
    - [ ] Configure PostgreSQL backup with point-in-time recovery.
    - [ ] Implement experiment data and artifact backup procedures.
  
  - [ ] **Kubernetes and Application Backup:**
    - [ ] Deploy Velero for Kubernetes backup and restore.
    - [ ] Configure persistent volume backup and replication.
    - [ ] Implement application configuration backup.
    - [ ] Set up secrets and certificate backup procedures.

- [ ] **9.3. Disaster Recovery Planning:**
  - [ ] **Recovery Procedures and Documentation:**
    - [ ] Create comprehensive disaster recovery runbooks.
    - [ ] Define Recovery Time Objectives (RTO) and Recovery Point Objectives
      (RPO).
    - [ ] Implement automated disaster recovery testing.
    - [ ] Create escalation procedures and communication plans.
  
  - [ ] **Business Continuity Planning:**
    - [ ] Implement high availability configurations where possible.
    - [ ] Create service dependency mapping and failure impact analysis.
    - [ ] Set up monitoring and alerting for backup system health.
    - [ ] Implement automated failover procedures where applicable.

---

## Phase 10: Documentation and Knowledge Management

This phase creates comprehensive documentation, troubleshooting guides, and
knowledge transfer materials to ensure long-term maintainability and operational
excellence.

- [ ] **10.1. Technical Documentation:**
  - [ ] **Architecture and Design Documentation:**
    - [ ] Create detailed architecture diagrams and network topology.
    - [ ] Document system dependencies and integration points.
    - [ ] Create component interaction diagrams and data flow maps.
    - [ ] Document security architecture and threat models.
  
  - [ ] **Operational Documentation:**
    - [ ] Create comprehensive deployment and configuration guides.
    - [ ] Document all automation scripts and their usage.
    - [ ] Create system administration and maintenance procedures.
    - [ ] Document upgrade and migration procedures.

- [ ] **10.2. Troubleshooting and Support:**
  - [ ] **Comprehensive Troubleshooting Guide:**
    - [ ] Document common failure scenarios and their solutions.
    - [ ] Create PCIe passthrough specific troubleshooting procedures:
      - [ ] IOMMU configuration and validation issues.
      - [ ] VFIO driver binding and device isolation problems.
      - [ ] GPU passthrough performance optimization guide.
      - [ ] Host and guest driver conflict resolution.
    - [ ] Create diagnostic procedures and debugging workflows.
    - [ ] Document performance tuning and optimization procedures.
    - [ ] Create escalation procedures and support contacts.
  
  - [ ] **Knowledge Base and Training:**
    - [ ] Create training materials for different user roles.
    - [ ] Document best practices and lessons learned.
    - [ ] Create FAQ and known issues documentation.
    - [ ] Implement knowledge sharing and documentation update procedures.

- [ ] **10.3. Compliance and Audit Documentation:**
  - [ ] **Compliance Documentation:**
    - [ ] Document security compliance and certification procedures.
    - [ ] Create audit trails and reporting documentation.
    - [ ] Document data governance and privacy procedures.
    - [ ] Create change management and approval procedures.

---

## Phase 11: Resource Optimization and Cost Management

This phase implements advanced resource management, cost optimization, and
performance tuning to maximize efficiency and minimize operational overhead.

- [ ] **11.1. Resource Management and Optimization:**
  - [ ] **Dynamic Resource Allocation:**
    - [ ] Implement auto-scaling policies for Kubernetes workloads.
    - [ ] Create dynamic GPU resource allocation based on demand.
    - [ ] Implement workload scheduling optimization.
    - [ ] Set up resource quotas and limits management.
  
  - [ ] **Performance Optimization:**
    - [ ] Implement performance monitoring and tuning procedures.
    - [ ] Create workload optimization recommendations.
    - [ ] Implement capacity planning and forecasting.
    - [ ] Set up performance alerting and optimization automation.

- [ ] **11.2. Cost Tracking and Management:**
  - [ ] **Resource Cost Analytics:**
    - [ ] Implement resource usage tracking and reporting.
    - [ ] Create cost attribution for different workload types.
    - [ ] Set up budget monitoring and alerting.
    - [ ] Implement cost optimization recommendations.
  
  - [ ] **Operational Efficiency:**
    - [ ] Implement idle resource detection and management.
    - [ ] Create resource rightsizing recommendations.
    - [ ] Set up automated resource cleanup procedures.
    - [ ] Implement sustainability and energy efficiency monitoring.

- [ ] **11.3. Continuous Improvement:**
  - [ ] **Performance and Optimization Analytics:**
    - [ ] Implement continuous performance monitoring and analysis.
    - [ ] Create optimization opportunity identification and prioritization.
    - [ ] Set up A/B testing for infrastructure improvements.
    - [ ] Implement feedback loops for continuous optimization.
  
  - [ ] **Innovation and Future Planning:**
    - [ ] Document lessons learned and improvement opportunities.
    - [ ] Create roadmap for future enhancements and upgrades.
    - [ ] Implement technology evaluation and adoption procedures.
    - [ ] Set up innovation experimentation and testing framework.
