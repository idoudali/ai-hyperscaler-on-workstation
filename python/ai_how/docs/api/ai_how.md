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
