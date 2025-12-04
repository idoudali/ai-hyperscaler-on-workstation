# Phase 7: MIG (Multi-Instance GPU) Support

**Status**: 🔵 **Planned**
**Priority**: HIGH
**Dependencies**: Phase 6 Validation
**Estimated Duration**: 2 weeks

## Overview

This phase adds support for NVIDIA Multi-Instance GPU (MIG) technology, allowing a single physical
GPU to be partitioned into multiple smaller GPU instances (slices). This enables better resource
utilization for smaller workloads and allows multiple VMs to share a single powerful GPU with hardware isolation.

## Objectives

1.  Enable manual MIG slicing on the host.
2.  Update Python wrapper (`ai_how`) to support MIG configuration in cluster definitions.
3.  Implement assignment of specific GPU slices to different VMs.
4.  Enable MIG support in the local simulator environment.

## Tasks

### Task 065: Host MIG Configuration Tools

- **ID**: TASK-065
- **Phase**: 7 - MIG Support
- **Description**: Create tools and documentation for manually partitioning GPUs on the host.
- **Deliverables**:
  - `scripts/gpu/enable-mig.sh`: Script to enable MIG mode on supported GPUs.
  - `scripts/gpu/create-mig-slices.sh`: Script to create specific MIG instances (e.g., 1g.5gb, 2g.10gb).
  - `docs/guides/gpu-partitioning.md`: Documentation on how to slice GPUs manually.

### Task 066: Python Wrapper MIG Support

- **ID**: TASK-066
- **Phase**: 7 - MIG Support
- **Description**: Update the `ai_how` Python package to support MIG configuration.
- **Deliverables**:
  - Update `VMSpec` in `vm_factory.py` to accept MIG configuration (UUID or profile).
  - Update `ClusterConfigParser` to validate MIG settings.
  - Update Jinja2 templates for libvirt XML to support `<hostdev mode='subsystem' type='mdev'>` for MIG vGPUs.
  - Update `PCIePassthroughValidator` to validate MIG capability and availability.

### Task 067: Update GPU Allocator

- **ID**: TASK-067
- **Phase**: 7 - MIG Support
- **Description**: Update the resource allocator to manage MIG slices.
- **Deliverables**:
  - Update `GPUResourceAllocator` to track MIG UUIDs in addition to physical PCI addresses.
  - Implement logic to detect available MIG slices on the host.
  - Prevent double-allocation of MIG slices.

### Task 068: Simulator MIG Integration

- **ID**: TASK-068
- **Phase**: 7 - MIG Support
- **Description**: Enable MIG support in the local simulator (libvirt/qemu environment).
- **Deliverables**:
  - Create a new configuration `config/example-mig-cluster.yaml` demonstrating split-GPU setup.
  - Validate end-to-end VM creation with assigned MIG slices.
  - Test isolation between VMs sharing the same physical GPU.

## Configuration Example

```yaml
clusters:
  hpc:
    compute_nodes:
      - ip: "192.168.100.11"
        gpu_config:
          mode: "mig"
          # Specific MIG slice UUID or profile
          mig_uuid: "uuid-of-mig-slice-1"
          # OR profile definition (if auto-creation is supported later)
          mig_profile: "1g.5gb"
```
