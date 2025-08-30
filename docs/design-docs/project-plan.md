# Project Plan: Hyperscaler on a Workstation

**Objective:** To implement the automated, dual-stack AI infrastructure as
described in the `hyperscaler-on-workstation.md` design document. This plan
outlines the concrete steps for an AI agent to execute, transforming the
architectural blueprint into a robust, production-ready, emulated environment
with comprehensive error handling, security, and monitoring.

**Project Status:** Phase 0 Foundation - Near Complete (85% Complete) **Last
Updated:** 2025-01-15 **Latest Enhancement:** Added PCIe GPU passthrough support for 2 discrete NVIDIA GPUs

## Current Status Summary

### ✅ Completed Components

- **Development Environment**: Docker-based development environment with pinned
  versions of tools (Terraform, Packer, Ansible, CMake, Ninja)
- **Build System Core**: CMake-based build system with Ninja generator support
  and custom targets for building minimal base images.
- **Development Workflow**: Makefile automation, pre-commit hooks, conventional
  commits, and basic CI/CD, with all relative imports migrated to absolute imports. (Refer to [Absolute Imports Migration](docs/implementation-plans/absolute-imports-migration.md))
- **Documentation**: Comprehensive design documents and implementation plans.
- **Python CLI Orchestrator**: Complete CLI framework with Typer, robust configuration
  validation, comprehensive logging, and command structure for HPC and Cloud cluster management
  (`ai_how` package, provides `ai-how` command). (Refer to [Enhanced Logging Implementation Guide](docs/implementation-plans/enhanced-logging-guide.md)
  and [Subprocess Logging Improvements](docs/implementation-plans/subprocess-logging-improvements.md))
- **HPC VM Management**: Complete system for provisioning, managing, and destroying HPC VMs, including LibVirt Client,
VM Lifecycle Manager, Disk Manager, State Models, Cluster State Manager, XML Templates, HPC Manager, and CLI Integration.
(Refer to [HPC VM Management Implementation - Complete](docs/implementation-plans/hpc-implementation-complete.md))
- **Cluster Configuration Management**: Comprehensive `cluster.yaml` schema
  design, JSON schema validation, and configuration validator implementation.
- **Host Preparation and Validation**: Complete system prerequisite checker
  (`check_prereqs.sh`) with detailed validation for CPU virtualization, IOMMU,
  KVM, GPU drivers, and system resources.
- **GPU Inventory System**: GPU discovery and inventory script
  (`gpu_inventory.sh`) for host GPU enumeration.

### 🚧 In Progress Components

- **Build System Enhancement**: Foundational Packer templates for `hpc-base` and
  `cloud-base` are implemented but lack specific software packages (HPC tools,
  container runtimes). Automated testing targets are placeholders.
- **CI/CD Pipeline**: Basic linting workflow implemented; multi-stage quality
  gates and deployment automation are pending.

### 📋 Next Milestones

- **Implement CLI Provisioning Logic** (Phase 0.7 continuation):
  - Add Ansible inventory generation and playbook execution
  - Complete state management and tracking functionality
- **Complete Phase 0.2 build system enhancements** (add software to images,
  implement tests).
- **Enhance Golden Images** (Phase 2.2): Add HPC-specific packages and container
  runtimes to base images.
- **Implement GPU Resource Management** (Phase 3.1): MIG management, vGPU
  provisioning scripts, and PCIe GPU passthrough for discrete GPU access.
- **Enhance CI/CD pipeline** with build and deployment stages.

### 🎯 Immediate Action Items (Priority Order)

1.  **Complete CLI Provisioning Implementation** (Phase 0.7 continuation):
    - Add Ansible inventory generation and playbook execution integration
    - Complete state management with `output/state.json` tracking

2.  **Implement GPU Resource Management** (Phase 3.1):
    - Create MIG management script (`manage_mig.py`) for dynamic GPU
      partitioning
    - Implement smart vGPU provisioner (`create_vgpus.py`) with `cluster.yaml`
      integration
    - **NEW: Implement PCIe GPU passthrough management**:
      - Add PCIe passthrough validation scripts (`check_pcie_passthrough.sh`)
      - Create PCIe device preparation tools (`prepare_pcie_devices.sh`)
      - Implement PCIe passthrough resource manager (`manage_pcie_passthrough.py`)
      - Add support for 2 discrete NVIDIA GPUs with direct VM access
    - Add GPU resource validation and conflict detection
    - Create resource cleanup manager for safe GPU resource destruction

3.  **Enhance Golden Images** (Phase 2.2):
    - Add HPC-specific packages (Slurm, Munge) to the `hpc-base` image
    - Add container runtime and Kubernetes packages to the `cloud-base` image
    - Implement security hardening and monitoring tools in both images

4.  **Complete Build System Enhancement** (Phase 0.2 remaining items):
    - Replace placeholder test commands with actual integration tests
    - Enhance CI/CD pipeline with multi-stage quality gates

5.  **Finalize Development Environment** (Phase 0.1 remaining items):
    - Configure container registry push workflow
    - Add security scanning for Docker images

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
  - [ ] Generate Ansible inventory for HPC and invoke `playbook-hpc.yml`.

- [ ] **0.7.4. Cloud Cluster Enablement:**
  - [ ] Implement `cloud start` to provision control plane and worker nodes per
    `cluster.yaml`.
  - [ ] Implement `cloud stop`, `cloud status`, and `cloud destroy` with parity
    to HPC behavior.
  - [ ] Generate Ansible inventory for K8s and invoke `playbook-k8s.yml`.

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

## Implementation Infrastructure (Completed)

The following development infrastructure has been successfully implemented to
support the project:

### ✅ Development Environment Infrastructure

- **Docker Environment**: Complete containerized development environment
  (`docker/Dockerfile`)
- **Build Automation**: Comprehensive Makefile with Docker workflow automation
- **Dependency Management**: Pinned tool versions and dependency manifest
- **Build System**: CMake-based project with Ninja generator support

### ✅ Code Quality and Standards

- **Pre-commit Hooks**: Comprehensive linting and validation pipeline
  (`.pre-commit-config.yaml`)
- **Conventional Commits**: Commitizen configuration for standardized commit
  messages (`.cz.toml`)
- **Markdown Standards**: Linting configuration with project-specific rules
  (`.markdownlint.yaml`)
- **Shell Script Quality**: ShellCheck integration for script validation

### ✅ CI/CD Foundation

- **GitHub Actions**: Basic linting and validation workflow
  (`.github/workflows/ci.yml`)
- **Multi-language Linting**: Support for Dockerfile, shell scripts, YAML, and
  markdown, including enforcement of absolute imports. (Refer to [Absolute Imports Migration](docs/implementation-plans/absolute-imports-migration.md))
- **Git Hooks**: Local validation before commits and pushes

### ✅ Documentation Framework

- **Design Documents**: Complete architectural documentation in
  `docs/design-docs/`
- **Implementation Plans**: Detailed task-specific implementation guides
- **Open Source Analysis**: Comprehensive evaluation of alternative solutions

---

## Phase 1: Host Preparation and Validation

This phase prepares the physical host machine with comprehensive validation and
error handling. Enhanced security and recovery procedures ensure a stable
foundation for the virtualized environment.

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

- [ ] **1.1.1. PCIe GPU Passthrough Prerequisites:**
  - [ ] **Script 3: PCIe Passthrough Validator (`check_pcie_passthrough.sh`)**
    - [ ] Validate IOMMU configuration and enabled status (`intel_iommu=on` or `amd_iommu=on`).
    - [ ] Check IOMMU groups for GPU isolation and validate group membership.
    - [ ] Verify VFIO driver availability and kernel module loading.
    - [ ] Validate that target GPUs are not bound to host drivers (`nvidia`, `nouveau`).
    - [ ] Check for PCIe ACS (Access Control Services) support and configuration.
    - [ ] Validate host system compatibility for SR-IOV if applicable.
    - [ ] Report potential conflicts with existing GPU utilization.
    - [ ] Generate PCIe device inventory with IOMMU group mappings.
  
  - [ ] **Script 4: PCIe Device Preparation (`prepare_pcie_devices.sh`)**
    - [ ] Create backup of current GPU driver bindings and configurations.
    - [ ] Unbind target GPUs from host drivers (nvidia, nouveau) safely.
    - [ ] Bind target GPUs to VFIO-PCI driver with validation.
    - [ ] Configure VFIO driver parameters and permissions.
    - [ ] Validate PCIe device isolation and IOMMU group assignment.
    - [ ] Implement rollback procedures for driver binding failures.
    - [ ] Create persistent configuration for PCIe passthrough devices.
    - [ ] Generate device mapping configuration for VM provisioning.

- [ ] **1.2. Automated Host Configuration:**
  - [ ] **Script 2: Safe System Configurator (`configure_host.sh`)**
    - [ ] Create system backup before any changes.
    - [ ] Safely blacklist `nouveau` driver with validation.
    - [ ] Install virtualization packages with version compatibility checks.
    - [ ] Configure user groups with proper permissions.
    - [ ] Set up system service configurations.
    - [ ] Implement rollback capability for all changes.
    - [ ] Provide detailed installation guide for NVIDIA vGPU Manager.

- [ ] **1.3. Network Infrastructure Setup:**
  - [ ] **Script 3: Network Validator (`check_networks.sh`)**
    - [ ] Validate existing network configurations.
    - [ ] Check for IP address conflicts.
    - [ ] Verify bridge and routing configurations.
  - [ ] **Script 4: Secure Network Creator (`create_networks.sh`)**
    - [ ] Create isolated networks with security policies.
    - [ ] Implement firewall rules for network segmentation.
    - [ ] Set up DNS and DHCP with proper scoping.
    - [ ] Configure network monitoring and logging.

- [ ] **1.4. Security Hardening:**
  - [ ] Configure SSH key-based authentication.
  - [ ] Set up basic firewall rules and network policies.
  - [ ] Implement system logging and audit trails.
  - [ ] Configure access controls and user permissions.
  - [ ] Set up certificate management infrastructure.

---

## Phase 2: Automated Golden Image Creation

This phase uses Packer to build standardized, secure Debian 12 base images for
the VMs with comprehensive testing and validation. Images are built with
security hardening and monitoring tools.

- [ ] **2.1. Enhanced Packer Configurations:**
  - [x] Write a Packer template (`hpc-base.pkr.hcl`) for the HPC cluster base
    image.
    - [ ] Include security hardening configurations.
    - [ ] Add monitoring and logging tools.
    - [ ] Implement image validation tests.
  - [x] Write a Packer template (`cloud-base.pkr.hcl`) for the cloud cluster
    base image.
    - [ ] Include container runtime optimizations.
    - [ ] Add Kubernetes-specific security configurations.
    - [ ] Implement cloud-native monitoring tools.
  - [x] Configure both templates with error handling and retry logic.
  - [ ] Add image scanning for security vulnerabilities.

- [ ] **2.2. Secure Unattended Install Configuration:**
  - [ ] Create `http/preseed-hpc.cfg` with:
    - [ ] HPC-specific packages (munge, slurm tools, MPI libraries).
    - [ ] Security configurations and hardening.
    - [ ] Monitoring and logging setup.
  - [ ] Create `http/preseed-cloud.cfg` with:
    - [ ] Container runtime packages (containerd, runc).
    - [ ] Kubernetes prerequisites.
    - [ ] Cloud-native security tools.
  - [ ] Implement common security baseline for both images.
  - [ ] Add automated testing hooks for image validation.

- [ ] **2.3. Build and Validation Pipeline:**
  - [x] Execute CMake targets with comprehensive error handling.
  - [ ] Implement automated image testing:
    - [ ] Boot validation tests.
    - [ ] Security compliance checks.
    - [ ] Performance benchmarking.
    - [ ] Package integrity verification.
  - [ ] Create image artifacts with metadata and checksums.
  - [ ] Implement rollback procedures for failed builds.
  - [ ] Store validated images with version tagging.

---

## Phase 3: Infrastructure Provisioning and Resource Management

This phase implements intelligent resource management with dynamic GPU
partitioning, capacity planning, and comprehensive validation of the
infrastructure provisioning process.

- [ ] **3.1. Enhanced GPU Resource Management:**
  - [ ] **Script 1: Intelligent MIG Manager (`manage_mig.py`)**
    - [ ] Implement capacity planning calculator for GPU resources.
    - [ ] Add dynamic MIG reconfiguration based on workload demands.
    - [ ] Create performance benchmarking for different MIG configurations.
    - [ ] Implement resource utilization monitoring and optimization.
    - [ ] Add conflict detection and resolution for GPU resource allocation.
  
  - [ ] **Script 2: Smart vGPU Provisioner (`create_vgpus.py`)**
    - [ ] Read and validate `config/cluster.yaml` with schema validation.
    - [ ] Parse GPU allocation requirements from both HPC and Cloud cluster
      specifications.
    - [ ] Calculate optimal MIG slicing strategy with performance
      considerations.
    - [ ] Validate total GPU resource demands against available hardware.
    - [ ] Implement resource constraint validation and error handling.
    - [ ] Create GPU Instances with comprehensive error checking.
    - [ ] Generate vGPU mediated devices (mdevs) with UUID tracking.
    - [ ] Save detailed mapping to `output/mdev_map.json` with metadata.
    - [ ] Implement rollback procedures for failed GPU allocations.
  
  - [ ] **Script 3: Resource Cleanup Manager (`cleanup_resources.py`)**
    - [ ] Safe cleanup of GPU resources with validation.
    - [ ] Implement staged cleanup with confirmation prompts.
    - [ ] Add resource usage validation before cleanup.
    - [ ] Create backup of resource configurations before destruction.

  - [ ] **Script 4: PCIe Passthrough Resource Manager (`manage_pcie_passthrough.py`)**
    - [ ] Read and validate `config/cluster.yaml` for PCIe passthrough device assignments.
    - [ ] Parse discrete GPU allocation requirements for HPC compute nodes.
    - [ ] Validate PCIe device availability and IOMMU group compatibility.
    - [ ] Implement conflict detection between MIG/vGPU and PCIe passthrough modes.
    - [ ] Generate libvirt XML hostdev configurations for PCIe passthrough.
    - [ ] Create device mapping and assignment validation system.
    - [ ] Implement PCIe device reservation and release management.
    - [ ] Save PCIe device assignments to `output/pcie_map.json` with metadata.
    - [ ] Implement rollback procedures for failed PCIe device allocations.
    - [ ] Create validation scripts for PCIe passthrough device functionality.

- [ ] **3.2. Dynamic Cluster Configuration:**
  - [ ] **Cluster Definition YAML Structure (`config/cluster.yaml`):**
    - [ ] Define HPC cluster specification:
      - [ ] Controller node: CPU cores, memory, disk size, network configuration
      - [ ] Compute nodes: Number of nodes, CPU cores per node, memory per node,
        GPU assignment (MIG, vGPU, or PCIe passthrough)
      - [ ] PCIe passthrough device specifications with IOMMU group validation
      - [ ] Storage requirements and shared filesystem configuration
      - [ ] SLURM-specific settings (partitions, QoS, accounting)
    - [ ] Define Cloud cluster specification:
      - [ ] Control plane node: CPU cores, memory, disk size, HA configuration
      - [ ] CPU worker nodes: Number and resource specifications
      - [ ] GPU worker nodes: Number, resource specs, GPU device assignment
      - [ ] Storage classes and persistent volume configurations
      - [ ] Kubernetes-specific settings (CNI, ingress, service mesh)
    - [ ] Global infrastructure settings:
      - [ ] Network topology and IP address ranges
      - [ ] GPU partitioning strategy (MIG profiles, device allocation)
      - [ ] Security configurations and access controls
      - [ ] Monitoring and logging preferences
  
  - [ ] **JSON Schema Validation (`schemas/cluster.schema.json`):**
    - [ ] Define comprehensive schema structure with required/optional fields
    - [ ] Implement field validation rules:
      - [ ] Resource constraints (minimum/maximum CPU, memory, disk)
      - [ ] Network IP range validation and conflict detection
      - [ ] GPU allocation validation (total resources vs. cluster demands)
      - [ ] Cross-dependencies validation (e.g., GPU nodes require GPU
        allocation)
    - [ ] Add descriptive error messages for validation failures
    - [ ] Include schema versioning for future compatibility
  
  - [ ] **Configuration Management Tools:**
    - [ ] Implement configuration validator (`scripts/validate_config.py`) with
      detailed error reporting
    - [ ] Create default configuration templates:
      - [ ] Minimal cluster (development/testing)
      - [ ] Production-like cluster (full resource allocation)
      - [ ] Custom templates for specific use cases
    - [ ] Add configuration migration tools for version updates
    - [ ] Implement configuration testing and simulation
    - [ ] Create configuration diff and merge utilities

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
  - [ ] **Enhanced SLURM Deployment (`playbook-hpc.yml`):**
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
  - [ ] **Enhanced Kubernetes Deployment (`playbook-k8s.yml`):**
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
