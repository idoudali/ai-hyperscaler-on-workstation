# AI-HOW Schema Guide

**Status:** Production  
**Version:** 1.0  
**Last Updated:** 2025-10-21

Comprehensive guide to the AI-HOW cluster configuration JSON Schema.

> **Note**: For core concepts and terminology, see [Common Concepts](common-concepts.md).

## Table of Contents

1. [Schema Overview](#schema-overview)
2. [Root Schema](#root-schema)
3. [HPC Cluster Schema](#hpc-cluster-schema)
4. Cloud Cluster Schema
5. Network Configuration
6. PCIe Passthrough Configuration
7. [Hardware Acceleration](#hardware-acceleration)
8. [Base Image Paths](#base-image-paths)
9. [Virtio-FS Mounts](#virtio-fs-mounts)
10. [Validation Examples](#validation-examples)
11. [Common Patterns](#common-patterns)

## Schema Overview

**Schema Location:** `src/ai_how/schemas/cluster.schema.json`  
**Schema Version:** 1.0  
**JSON Schema Draft:** Draft-7  
**Configuration Format:** YAML (parsed to JSON for validation)

The AI-HOW schema defines the structure and constraints for cluster configuration files. It
uses JSON Schema Draft-7 for validation and supports both HPC and Cloud cluster definitions.

For detailed information about configuration validation, see [Common Concepts - Configuration Validation](common-concepts.md#configuration-validation).

### Schema Features

- **Required Fields:** Enforced for critical configuration
- **Type Validation:** All fields have explicit types
- **Format Validation:** PCI addresses, image paths, IP ranges
- **Enum Constraints:** Device types, hardware types
- **Pattern Matching:** Regex validation for IDs and paths
- **Reference Sharing:** Reusable definitions with `$ref`

---

## Root Schema

The root level defines the overall configuration structure.

### Root Properties

#### `version`

Configuration format version.

**Type:** String
**Pattern:** `^1\.0$`
**Required:** Yes
**Default:** None

**Usage:**

```yaml
version: "1.0"
```text

**Notes:**

- Must be "1.0" for current schema
- Allows for future schema versions
- Semantic versioning: major.minor

#### `metadata`

Configuration metadata and identification.

**Type:** Object
**Required:** Yes

**Properties:**

##### `metadata.name`

Cluster name used for identification.

**Type:** String
**Pattern:** `^[a-zA-Z0-9_-]+$`
**Min Length:** 1
**Max Length:** 64

**Usage:**

```yaml
metadata:
  name: "my-cluster"
  name: "prod-hpc-01"
  name: "dev_kubernetes_cluster"
```text

**Constraints:**

- Alphanumeric, hyphens, underscores only
- No spaces or special characters
- Used in resource names, network names, storage pools

##### `metadata.description`

Human-readable cluster description.

**Type:** String
**Max Length:** 512
**Required:** No

**Usage:**

```yaml
metadata:
  name: "prod-cluster"
  description: "Production HPC cluster for AI workloads"
```text

#### `global`

Global configuration options (flexible object).

**Type:** Object
**Required:** No
**Default:** Empty object

**Usage:**

```yaml
global:
  environment: production
  owner: "data-science-team"
  billing_code: "CS-1234"
  custom_tag: "important"
```text

**Notes:**

- No fixed schema for global properties
- Allows custom key-value pairs
- Useful for metadata and tags
- Preserved in state file

#### `clusters`

Cluster definitions (HPC and/or Cloud).

**Type:** Object
**Required:** Yes
**Properties:**

##### `clusters.hpc`

Array of HPC cluster definitions.

**Type:** Array of `hpcCluster` objects
**Min Items:** 0
**Max Items:** No limit
**Required:** No (but at least one of `hpc` or `cloud` required)

**Usage:**

```yaml
clusters:
  hpc:
    - name: "cluster-1"
      ...
    - name: "cluster-2"
      ...
```text

##### `clusters.cloud`

Array of Cloud cluster definitions.

**Type:** Array of `cloudCluster` objects
**Min Items:** 0
**Max Items:** No limit
**Required:** No (but at least one of `hpc` or `cloud` required)

**Usage:**

```yaml
clusters:
  cloud:
    - name: "kubernetes-1"
      ...
```

### Complete Root Example

```yaml
version: "1.0"

metadata:
  name: "production-infrastructure"
  description: "Production HPC and Kubernetes clusters"

global:
  environment: production
  owner: platform-team
  region: us-west-2

clusters:
  hpc:
    - name: "hpc-compute-01"
      # ... HPC configuration
  cloud:
    - name: "kubernetes-prod"
      # ... Cloud configuration
```

---

## HPC Cluster Schema

HPC cluster definition for traditional compute clusters (SLURM, etc.).

### HPC Cluster Structure

```text
hpcCluster
├── name (string)
├── virtualMachines
│   ├── controller
│   │   ├── name
│   │   ├── cpu_cores
│   │   ├── memory_gb
│   │   ├── baseImagePath
│   │   └── pciePassthrough
│   └── computeNodes
│       ├── count
│       └── specification
│           ├── name_prefix
│           ├── cpu_cores
│           ├── memory_gb
│           ├── baseImagePath
│           └── pciePassthrough
├── network
│   ├── subnet
│   └── bridge
├── storage
│   ├── poolPath
│   └── volumeSizeGb
└── hardwareAcceleration
    ├── kvm_enabled
    ├── numa_enabled
    └── cpu_features
```text

### Required Properties

#### `name`

HPC cluster name.

**Type:** String
**Pattern:** `^[a-zA-Z0-9_-]+$`
**Min Length:** 1
**Max Length:** 64
**Required:** Yes

**Usage:**

```yaml
clusters:
  hpc:
    - name: "hpc-prod"
```text

#### `virtualMachines`

VM definitions for controller and compute nodes.

**Type:** Object
**Required:** Yes

**Sub-properties:**

##### `virtualMachines.controller`

Controller node VM specification.

**Type:** `vmSpecification` object
**Required:** Yes

**Properties:**

- `name` (string): Controller VM name
- `cpu_cores` (integer): CPU count (1-128)
- `memory_gb` (integer): Memory in GB (1-2048)
- `baseImagePath` (string): qcow2 image path
- `pciePassthrough` (object, optional): GPU/device passthrough

**Example:**

```yaml
virtualMachines:
  controller:
    name: "hpc-controller"
    cpu_cores: 8
    memory_gb: 32
    baseImagePath: "images/hpc-base.qcow2"
    pciePassthrough:
      enabled: false
```text

##### `virtualMachines.computeNodes`

Compute node specifications.

**Type:** Object
**Required:** Yes

**Properties:**

###### `computeNodes.count`

Number of compute nodes to create.

**Type:** Integer
**Minimum:** 1
**Maximum:** 1000
**Required:** Yes

###### `computeNodes.specification`

Specification template for compute nodes.

**Type:** `vmSpecification` object
**Required:** Yes

**Properties:**

- `name_prefix` (string): VM name prefix
- `cpu_cores` (integer): CPU count (1-128)
- `memory_gb` (integer): Memory in GB (1-2048)
- `baseImagePath` (string): qcow2 image path
- `pciePassthrough` (object, optional): GPU/device passthrough

**Example:**

```yaml
virtualMachines:
  computeNodes:
    count: 4
    specification:
      name_prefix: "compute"
      cpu_cores: 16
      memory_gb: 64
      baseImagePath: "images/hpc-compute.qcow2"
      pciePassthrough:
        enabled: true
        devices:
          - pci_address: "0000:01:00.0"
            device_type: "gpu"
```text

**VM Naming:** Compute nodes are named `{name_prefix}-01`, `{name_prefix}-02`, etc.

#### `network`

Cluster network configuration.

**Type:** Object
**Required:** Yes

See [Network Configuration](#network-configuration) section.

#### `storage`

Storage pool configuration.

**Type:** Object
**Required:** Yes

**Properties:**

##### `storage.poolPath`

Storage pool directory path.

**Type:** String (path)
**Required:** Yes

**Usage:**

```yaml
storage:
  poolPath: "/var/lib/libvirt/images/my-cluster"
```text

**Constraints:**

- Absolute path required
- Directory will be created if doesn't exist
- Sufficient disk space required

##### `storage.volumeSizeGb`

Default volume size for VMs.

**Type:** Integer
**Minimum:** 10
**Maximum:** 10000
**Default:** 100
**Required:** No

**Usage:**

```yaml
storage:
  poolPath: "/var/lib/libvirt/images/my-cluster"
  volumeSizeGb: 500
```text

### Optional Properties

#### `hardwareAcceleration`

Hardware acceleration settings.

**Type:** Object
**Required:** No

See [Hardware Acceleration](#hardware-acceleration) section.

### Complete HPC Example

```yaml
version: "1.0"

metadata:
  name: "production-hpc"
  description: "Production HPC cluster with GPU support"

clusters:
  hpc:
    - name: "hpc-prod-01"
      virtualMachines:
        controller:
          name: "hpc-controller"
          cpu_cores: 8
          memory_gb: 32
          baseImagePath: "images/hpc-base.qcow2"
          pciePassthrough:
            enabled: false
        computeNodes:
          count: 4
          specification:
            name_prefix: "compute"
            cpu_cores: 16
            memory_gb: 64
            baseImagePath: "images/hpc-compute.qcow2"
            pciePassthrough:
              enabled: true
              devices:
                - pci_address: "0000:01:00.0"
                  device_type: "gpu"
                - pci_address: "0000:02:00.0"
                  device_type: "gpu"
      network:
        subnet: "192.168.100.0/24"
        bridge: "virbr100"
      storage:
        poolPath: "/var/lib/libvirt/images/hpc-prod-01"
        volumeSizeGb: 500
      hardwareAcceleration:
        kvm_enabled: true
        numa_enabled: true
        cpu_features:
          - "vmx"
          - "avx2"
```text

---

## Cloud Cluster Schema

Cloud cluster definition for Kubernetes and cloud-native infrastructure.

### Cloud Cluster Structure

```text
cloudCluster
├── name (string)
├── type (enum: kubernetes, docker-swarm, nomad)
├── virtualMachines
│   ├── master_nodes
│   └── worker_nodes
├── network
├── storage
└── hardwareAcceleration
```text

**Status:** Schema defined, implementation not yet completed.

### Example Cloud Schema

```yaml
clusters:
  cloud:
    - name: "kubernetes-prod"
      type: "kubernetes"
      virtualMachines:
        master_nodes:
          count: 3
          specification:
            name_prefix: "master"
            cpu_cores: 4
            memory_gb: 8
            baseImagePath: "images/kubernetes-master.qcow2"
        worker_nodes:
          count: 10
          specification:
            name_prefix: "worker"
            cpu_cores: 8
            memory_gb: 16
            baseImagePath: "images/kubernetes-worker.qcow2"
      network:
        subnet: "192.168.200.0/24"
        bridge: "virbr200"
      storage:
        poolPath: "/var/lib/libvirt/images/kubernetes-prod"
```text

---

## Network Configuration

Network settings for cluster virtual network.

### Network Schema

```text
network
├── subnet (string: CIDR format)
└── bridge (string: network bridge name)
```text

### Properties

#### `network.subnet`

Network subnet in CIDR notation.

**Type:** String
**Format:** CIDR (e.g., "192.168.100.0/24")
**Pattern:** `^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$`
**Required:** Yes

**Usage:**

```yaml
network:
  subnet: "192.168.100.0/24"
  subnet: "10.0.0.0/16"
  subnet: "172.16.0.0/12"
```text

**Constraints:**

- Valid IPv4 address with subnet mask
- Subnet mask: /8 to /30
- Should not overlap with host network
- Should not overlap with other clusters

#### `network.bridge`

Virtual network bridge name.

**Type:** String
**Pattern:** `^[a-z0-9]{1,15}$`
**Required:** Yes

**Usage:**

```yaml
network:
  subnet: "192.168.100.0/24"
  bridge: "virbr100"
```text

**Naming Convention:**

- Prefix: `virbr` (virtual bridge)
- Suffix: Unique identifier (usually subnet last octet)
- Examples: `virbr100`, `virbr200`, `virbr10`

### Complete Network Example

```yaml
network:
  subnet: "192.168.100.0/24"
  bridge: "virbr100"
```text

### Network Details

- **Gateway:** First usable IP (.1)
- **DHCP Range:** Typically .100-.254
- **VM IPs:** Assigned by DHCP from available range
- **Broadcast:** Last IP in subnet (.255)

---

## PCIe Passthrough Configuration

GPU and device passthrough settings for VM access to host PCIe devices.

For detailed PCIe passthrough information, see [Common Concepts - PCIe Passthrough](common-concepts.md#pcie-passthrough).

### PCIe Passthrough Schema

```text
pciePassthrough
├── enabled (boolean)
└── devices (array)
    ├── pci_address (string)
    └── device_type (enum)
```text

### Properties

#### `pciePassthrough.enabled`

Enable or disable PCIe device passthrough.

**Type:** Boolean
**Default:** False
**Required:** No

**Usage:**

```yaml
pciePassthrough:
  enabled: true
  devices: [...]

pciePassthrough:
  enabled: false
```text

#### `pciePassthrough.devices`

Array of devices to pass through to VMs.

**Type:** Array of device objects
**Min Items:** 0
**Max Items:** 16
**Required:** No (must be present if `enabled: true`)

**Each device has:**

##### `device.pci_address`

PCIe device address.

**Type:** String
**Format:** PCI address (0000:01:00.0)
**Pattern:** `^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]$`
**Required:** Yes

**Format Breakdown:**

- Domain: 4 hex digits (usually 0000)
- Bus: 2 hex digits (00-FF)
- Slot: 2 hex digits (00-1F typically)
- Function: 1 digit (0-7)

**Examples:**

```yaml
devices:
  - pci_address: "0000:01:00.0"   # First GPU
  - pci_address: "0000:02:00.0"   # Second GPU
  - pci_address: "0000:0d:00.0"   # Audio device
```text

##### `device.device_type`

Type of PCIe device.

**Type:** String (enum)
**Allowed Values:**

- `gpu` - GPU accelerator (NVIDIA, AMD, Intel)
- `audio` - Audio adapter
- `network` - Network interface
- `storage` - Storage controller
- `other` - Other device type

**Usage:**

```yaml
devices:
  - pci_address: "0000:01:00.0"
    device_type: "gpu"
  - pci_address: "0000:02:00.0"
    device_type: "gpu"
  - pci_address: "0000:0d:00.0"
    device_type: "audio"
```text

### PCIe Device Discovery

**Find Available Devices:**

```bash
# List all PCIe devices
ai-how inventory pcie

# Look for your GPU
lspci | grep -i nvidia
lspci | grep -i amd
```text

**Get Exact PCI Address:**

```bash
lspci -D | grep "NVIDIA\|Audio\|Network"
# Output: 0000:01:00.0 3D controller: NVIDIA Corporation GA100 [A100-PCIE-40GB] (rev a1)
```text

### PCIe Passthrough Validation

Before using PCIe passthrough, ensure system requirements are met. See [Common Concepts - PCIe
Passthrough](common-concepts.md#pcie-passthrough) for detailed requirements.

**Validation Command:**

```bash
ai-how validate config.yaml
```

### Common Passthrough Configurations

#### Single GPU Passthrough

```yaml
pciePassthrough:
  enabled: true
  devices:
    - pci_address: "0000:01:00.0"
      device_type: "gpu"
```text

#### Multiple GPUs

```yaml
pciePassthrough:
  enabled: true
  devices:
    - pci_address: "0000:01:00.0"
      device_type: "gpu"
    - pci_address: "0000:02:00.0"
      device_type: "gpu"
    - pci_address: "0000:03:00.0"
      device_type: "gpu"
```text

#### Mixed Device Types

```yaml
pciePassthrough:
  enabled: true
  devices:
    - pci_address: "0000:01:00.0"
      device_type: "gpu"
    - pci_address: "0000:0d:00.0"
      device_type: "audio"
    - pci_address: "0000:05:00.0"
      device_type: "network"
```text

---

## Hardware Acceleration

Hardware acceleration and CPU feature settings.

### Hardware Acceleration Schema

```text
hardwareAcceleration
├── kvm_enabled (boolean)
├── numa_enabled (boolean)
└── cpu_features (array of strings)
```text

### Properties

#### `hardwareAcceleration.kvm_enabled`

Enable KVM virtualization support.

**Type:** Boolean
**Default:** True
**Required:** No

**Usage:**

```yaml
hardwareAcceleration:
  kvm_enabled: true
```text

**Notes:**

- Requires KVM-capable CPU
- Provides significant performance improvement
- Recommended: Keep enabled

#### `hardwareAcceleration.numa_enabled`

Enable NUMA (Non-Uniform Memory Access) optimization.

**Type:** Boolean
**Default:** False
**Required:** No

**Usage:**

```yaml
hardwareAcceleration:
  numa_enabled: true
```text

**Notes:**

- Only effective on NUMA-capable systems
- Improves performance for multi-socket systems
- Check: `numactl -H` to verify NUMA availability

#### `hardwareAcceleration.cpu_features`

CPU features to expose to VMs.

**Type:** Array of strings
**Allowed Values:** `vmx`, `svm`, `avx`, `avx2`, `sse`, `sse2`, `sse4_1`, `sse4_2`, etc.
**Default:** Empty array (auto-detect)
**Required:** No

**Usage:**

```yaml
hardwareAcceleration:
  cpu_features:
    - "vmx"      # Intel virtualization extension
    - "avx2"     # Advanced Vector Extensions 2
    - "sse4_2"   # Streaming SIMD Extensions 4.2
```text

**Common Combinations:**

- ML/AI workloads: `avx2`, `fma`, `bmi2`
- Virtualization: `vmx` (Intel) or `svm` (AMD)
- Vector processing: `avx`, `avx2`, `avx512`

### Complete Hardware Acceleration Example

```yaml
hardwareAcceleration:
  kvm_enabled: true
  numa_enabled: true
  cpu_features:
    - "vmx"
    - "avx2"
    - "sse4_2"
    - "rdtscp"
```text

---

## Base Image Paths

Paths to qcow2 base images for VM creation.

### Image Path Schema

**Type:** String
**Pattern:** `.*\.qcow2$`
**Required:** Where VM is defined
**Default:** None

### Properties

#### Image Path Format

Paths should reference qcow2 images:

```yaml
baseImagePath: "images/hpc-base.qcow2"
baseImagePath: "/absolute/path/to/image.qcow2"
baseImagePath: "./relative/path/to/image.qcow2"
```text

#### Path Resolution

1. Relative paths: Resolved relative to config file directory
2. Absolute paths: Used as-is
3. Symlinks: Resolved to actual file

#### Validation

Paths are validated to:

- Contain `.qcow2` extension
- Point to existing files
- Be readable by current user
- Contain valid qcow2 image data

### Image Path Examples

```yaml
virtualMachines:
  controller:
    baseImagePath: "images/hpc-base.qcow2"
  computeNodes:
    specification:
      baseImagePath: "images/hpc-compute.qcow2"
```text

**Image Organization:**

```text
project/
├── config/
│   └── cluster.yaml
└── images/
    ├── hpc-base.qcow2
    ├── hpc-compute.qcow2
    └── kubernetes-worker.qcow2
```text

---

## Virtio-FS Mounts

Host directory sharing with VMs using Virtio-FS.

### Virtio-FS Schema

**Type:** Object
**Required:** No
**Default:** Empty (no mounts)

### Properties

Virtio-FS configuration maps host directories to VM mount points:

```yaml
virtioFsMounts:
  - host_path: "/data/shared"
    mount_point: "/mnt/shared"
  - host_path: "/home/user/projects"
    mount_point: "/workspace"
```text

#### `host_path`

Path on host system.

**Type:** String (path)
**Required:** Yes

#### `mount_point`

Path inside VM.

**Type:** String (path)
**Required:** Yes

### Example

```yaml
virtioFsMounts:
  - host_path: "/data/datasets"
    mount_point: "/datasets"
  - host_path: "/home/user/code"
    mount_point: "/code"
```text

---

## Validation Examples

### Example 1 - Basic HPC Configuration

```yaml
version: "1.0"

metadata:
  name: "test-cluster"
  description: "Simple test HPC cluster"

clusters:
  hpc:
    - name: "test"
      virtualMachines:
        controller:
          name: "controller"
          cpu_cores: 4
          memory_gb: 8
          baseImagePath: "images/base.qcow2"
        computeNodes:
          count: 2
          specification:
            name_prefix: "compute"
            cpu_cores: 8
            memory_gb: 16
            baseImagePath: "images/base.qcow2"
      network:
        subnet: "192.168.100.0/24"
        bridge: "virbr100"
      storage:
        poolPath: "/var/lib/libvirt/images/test"
```text

### Example 2 - GPU Cluster

```yaml
version: "1.0"

metadata:
  name: "gpu-cluster"
  description: "HPC cluster with GPU support"

clusters:
  hpc:
    - name: "gpu-prod"
      virtualMachines:
        controller:
          name: "gpu-controller"
          cpu_cores: 8
          memory_gb: 32
          baseImagePath: "images/hpc-base.qcow2"
        computeNodes:
          count: 4
          specification:
            name_prefix: "gpu-compute"
            cpu_cores: 16
            memory_gb: 64
            baseImagePath: "images/hpc-compute.qcow2"
            pciePassthrough:
              enabled: true
              devices:
                - pci_address: "0000:01:00.0"
                  device_type: "gpu"
                - pci_address: "0000:02:00.0"
                  device_type: "gpu"
      network:
        subnet: "192.168.100.0/24"
        bridge: "virbr100"
      storage:
        poolPath: "/var/lib/libvirt/images/gpu-prod"
        volumeSizeGb: 500
      hardwareAcceleration:
        kvm_enabled: true
        numa_enabled: true
        cpu_features:
          - "vmx"
          - "avx2"
```text

### Example 3 - Production Configuration

```yaml
version: "1.0"

metadata:
  name: "production-infrastructure"
  description: "Production HPC cluster"

global:
  environment: production
  owner: platform-engineering
  billing_project: "ai-infrastructure"

clusters:
  hpc:
    - name: "prod-hpc-01"
      virtualMachines:
        controller:
          name: "prod-controller"
          cpu_cores: 16
          memory_gb: 64
          baseImagePath: "images/hpc-base-prod.qcow2"
          pciePassthrough:
            enabled: false
        computeNodes:
          count: 8
          specification:
            name_prefix: "prod-compute"
            cpu_cores: 32
            memory_gb: 128
            baseImagePath: "images/hpc-compute-prod.qcow2"
            pciePassthrough:
              enabled: true
              devices:
                - pci_address: "0000:01:00.0"
                  device_type: "gpu"
                - pci_address: "0000:02:00.0"
                  device_type: "gpu"
      network:
        subnet: "10.100.0.0/16"
        bridge: "virbr100"
      storage:
        poolPath: "/storage/libvirt/prod-hpc-01"
        volumeSizeGb: 1000
      hardwareAcceleration:
        kvm_enabled: true
        numa_enabled: true
        cpu_features:
          - "vmx"
          - "avx2"
          - "fma"
```text

---

## Common Patterns

### Multi-Cluster Configuration

Run multiple independent clusters:

```yaml
version: "1.0"

metadata:
  name: "multi-cluster-setup"

clusters:
  hpc:
    - name: "dev-cluster"
      network:
        subnet: "192.168.101.0/24"
        bridge: "virbr101"
      storage:
        poolPath: "/var/lib/libvirt/images/dev"
      # ... VM definitions

    - name: "staging-cluster"
      network:
        subnet: "192.168.102.0/24"
        bridge: "virbr102"
      storage:
        poolPath: "/var/lib/libvirt/images/staging"
      # ... VM definitions

    - name: "prod-cluster"
      network:
        subnet: "192.168.103.0/24"
        bridge: "virbr103"
      storage:
        poolPath: "/var/lib/libvirt/images/prod"
      # ... VM definitions
```text

### Development vs Production

Use environment-specific configurations:

```bash
# Development: Small cluster, fewer resources
ai-how validate config/dev-cluster.yaml

# Production: Large cluster, GPU support
ai-how validate config/prod-cluster.yaml
```text

### Custom Configuration Inheritance

Store common values and override:

```yaml
# base-cluster.yaml
version: "1.0"
metadata:
  name: "base"
global:
  environment: ${ENV:-dev}
clusters:
  hpc:
    - name: "cluster"
      network:
        bridge: "virbr100"
      storage:
        poolPath: "/var/lib/libvirt/images/cluster"

# Usage: Merge with sed/yq/jq for custom values
```text

---

## See Also

- [CLI Reference](cli-reference.md) - Command-line interface
- [State Management](state-management.md) - Cluster state
- [API Documentation](api/ai_how.md) - Python API
