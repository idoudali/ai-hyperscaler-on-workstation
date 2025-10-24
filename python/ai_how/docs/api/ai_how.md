# AI-HOW API Reference

This page provides the complete API reference for the AI-HOW package.

## Core Modules

### CLI Module

::: ai_how.cli
    handler: python
    selection:
      members:
        - app
        - main
        - validate
        - hpc
        - cloud
        - plan_app
        - inventory

### Validation Module

::: ai_how.validation
    handler: python
    selection:
      members:
        - validate_config
        - get_console
        - set_console
        - find_project_root

### Schemas Module

::: ai_how.schemas
    handler: python
    selection:
      members:
        - get_schema_version
        - get_schema_title
        - get_schema_description
        - get_required_fields

## Storage Configuration

### Storage Backend Support

AI-HOW now supports flexible storage backend configuration for clusters, including:

- **BeeGFS Parallel Filesystem**: High-performance distributed storage for HPC workloads
- **VirtIO-FS Host Directory Sharing**: Efficient host-to-VM directory sharing for datasets and development

### Storage Configuration Schema

The storage configuration is defined within the cluster definition:

```yaml
clusters:
  hpc:
    - name: "my-cluster"
      # ... other cluster configurations ...
      storage:
        # BeeGFS parallel filesystem configuration
        beegfs:
          enabled: true
          mount_point: "/mnt/beegfs"
          management_node: "controller"
          metadata_nodes:
            - "controller"
          storage_nodes:
            - "compute-01"
            - "compute-02"
          client_config:
            mount_options: "defaults,_netdev"
            auto_mount: true

        # VirtIO-FS host directory sharing configuration
        virtio_fs:
          enabled: true
```

### Storage Configuration Fields

#### BeeGFS Configuration

- `enabled` (boolean): Enable/disable BeeGFS deployment
- `mount_point` (string): Filesystem mount point on client nodes
- `management_node` (string): BeeGFS Management Service node
- `metadata_nodes` (array): BeeGFS Metadata Service nodes
- `storage_nodes` (array): BeeGFS Storage Service nodes
- `client_config` (object): Advanced client configuration
  - `mount_options` (string): Mount options for BeeGFS client
  - `auto_mount` (boolean): Auto-mount filesystem at boot

#### VirtIO-FS Configuration

- `enabled` (boolean): Enable/disable VirtIO-FS functionality

### Node-Specific Storage Mounts

For node-specific VirtIO-FS mounts, configure within individual VM definitions:

```yaml
controller:
  # ... controller configuration ...
  virtio_fs_mounts:
    - tag: "project-repo"
      host_path: "/home/user/Projects/pharos.ai-hyperscaler"
      mount_point: "/mnt/host-repo"
      readonly: false
      owner: "admin"
      group: "admin"
      mode: "0755"
      options: "rw,relatime"
```

### Storage Configuration Validation

Storage configurations are validated as part of the standard configuration validation process:

```bash
ai-how validate config.yaml
```

This validates:

- Storage backend configuration syntax
- Mount point accessibility
- Node assignment consistency
- Permission and ownership settings

### Storage Deployment Integration

Storage backends are deployed through the unified `playbook-hpc-runtime.yml` playbook, which consolidates:

- **BeeGFS Runtime Configuration**: Previously handled by `playbook-beegfs-runtime-config.yml` (now deleted)
- **VirtIO-FS Runtime Configuration**: Previously handled by `playbook-virtio-fs-runtime-config.yml` (now deleted)
- **HPC Runtime Configuration**: Core HPC infrastructure deployment

This consolidation simplifies the deployment workflow by reducing the number of playbooks users need to run from 7 to 5.

### BeeGFS Service Management

BeeGFS services are managed through systemd with the following components:

- **beegfs-mgmt**: Management service (handles cluster coordination)
- **beegfs-meta**: Metadata service (handles file metadata)
- **beegfs-storage**: Storage service (handles data storage)
- **beegfs-client**: Client service (handles filesystem mounting)

**Note**: The `beegfs-helperd` service has been deprecated in BeeGFS 8.1.0+ and is no longer used.

### Phase 4 Validation Framework

The AI-HOW validation framework has been updated to reflect the consolidated storage configuration approach:

**Updated Validation Steps:**

- **Step 04**: Runtime Deployment (previously Step 03)
- **Step 06**: Functional Tests (previously Step 04)
- **Step 07**: Regression Tests (previously Step 05)

**Validation Script Updates:**

- `step-05-regression-tests.sh` → `step-07-regression-tests.sh`
- All validation steps now reflect the consolidated playbook approach

## State Management

### State Models

::: ai_how.state.models
    handler: python
    selection:
      members:
        - VMState
        - VolumeInfo
        - StoragePoolInfo
        - NetworkInfo
        - NetworkConfig
        - VMInfo
        - ClusterState

### State Manager

::: ai_how.state.manager
    handler: python
    selection:
      members:
        - ClusterStateManager

### State Persistence

::: ai_how.state.persistence
    handler: python
    selection:
      members:
        - StateSerializer
        - StateFileManager

## VM Management

### HPC Manager

::: ai_how.vm_management.hpc_manager
    handler: python
    selection:
      members:
        - HPCClusterManager
        - HPCManagerError
        - RollbackManager

### Libvirt Client

::: ai_how.vm_management.libvirt_client
    handler: python
    selection:
      members:
        - LibvirtClient
        - LibvirtConnectionError

### Network Manager

::: ai_how.vm_management.network_manager
    handler: python
    selection:
      members:
        - NetworkManager
        - NetworkManagerError

### Volume Manager

::: ai_how.vm_management.volume_manager
    handler: python
    selection:
      members:
        - VolumeManager
        - VolumeManagerError

### VM Lifecycle

::: ai_how.vm_management.vm_lifecycle
    handler: python
    selection:
      members:
        - VMLifecycleManager
        - VMLifecycleError

### GPU Mapper

::: ai_how.vm_management.gpu_mapper
    handler: python
    selection:
      members:
        - GPUMapper
        - get_gpu_mapper

### XML Tracer

::: ai_how.vm_management.xml_tracer
    handler: python
    selection:
      members:
        - XMLTracer

## PCIe Validation

### PCIe Passthrough

::: ai_how.pcie_validation.pcie_passthrough
    handler: python
    selection:
      members:
        - PCIePassthroughValidator

## Utilities

### Logging Utilities

::: ai_how.utils.logging
    handler: python
    selection:
      members:
        - configure_logging
        - get_logger_for_module
        - run_subprocess_with_logging
        - SubprocessResult
        - ColoredFormatter

### Path Utilities

::: ai_how.utils.path_utils
    handler: python
    selection:
      members:
        - resolve_path
        - validate_qcow2_file
        - resolve_and_validate_image_path
