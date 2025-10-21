# Common Concepts

**Status:** Production  
**Version:** 0.1.0  
**Last Updated:** 2025-10-21

This document defines common concepts and terminology used throughout the AI-HOW documentation to avoid duplication
and ensure consistency.

## Core Concepts

### AI-HOW Definition

AI-HOW (AI Hyperscaler on Workstation) is a Python CLI orchestrator for managing hyperscaler
infrastructure running on workstation environments. It provides a unified interface for common
cluster management tasks.

### Key Features

- **CLI Interface**: Simple command-line interface built with Typer
- **Configuration Validation**: JSON Schema-based validation for configuration files
- **Rich Output**: Beautiful terminal output with Rich library
- **YAML Support**: Native support for YAML configuration files
- **Extensible**: Plugin-based architecture for adding new functionality

## Technical Concepts

### Configuration Validation

AI-HOW uses JSON Schema Draft-7 for configuration validation. This provides:

- **Required Fields**: Enforced for critical configuration
- **Type Validation**: All fields have explicit types
- **Format Validation**: PCI addresses, image paths, IP ranges
- **Enum Constraints**: Device types, hardware types
- **Pattern Matching**: Regex validation for IDs and paths
- **Reference Sharing**: Reusable definitions with `$ref`

**Schema Location**: `src/ai_how/schemas/cluster.schema.json`  
**Configuration Format**: YAML (parsed to JSON for validation)

### PCIe Passthrough

PCIe passthrough allows VMs to directly access host PCIe devices (primarily GPUs). This requires:

1. **System Support**:
   - IOMMU enabled (Intel VT-d or AMD IOMMU)
   - VFIO modules loaded (`vfio`, `vfio_iommu_type1`, `vfio_pci`)
   - KVM support available
   - x86_64 architecture only

2. **Device Configuration**:
   - PCI address format: `0000:xx:xx.x`
   - Device types: `gpu`, `audio`, `network`, `storage`, `other`
   - VFIO driver binding (not NVIDIA, Nouveau, or conflicting drivers)

3. **Validation**: Use `ai-how validate config.yaml` to check system readiness

### VM States

AI-HOW tracks VM states using libvirt state mappings:

| State | Description |
|-------|-------------|
| `RUNNING` | VM is running |
| `PAUSED` | VM is paused |
| `SHUTOFF` | VM is shut off |
| `UNDEFINED` | VM is not defined |
| `CRASHED` | VM has crashed |
| `DYING` | VM is shutting down |
| `PMSUSPENDED` | VM is power-managed suspended |

### State Management

AI-HOW maintains cluster state in JSON format for persistence across CLI invocations:

**Default Location**: `output/state.json`  
**Override**: `--state /path/to/state.json`

**State Contains**:

- Cluster metadata (name, type, status)
- VM information (names, states, IPs, resources)
- Network information (subnets, bridges, active IPs)
- Volume information (paths, sizes, formats)
- Timestamps (creation, modification)

### Network Configuration

Standard network configuration uses:

**Default Subnet**: `192.168.100.0/24`  
**Default Bridge**: `virbr100`  
**Gateway**: First usable IP (.1)  
**DHCP Range**: Typically .100-.254  
**VM IPs**: Assigned by DHCP from available range

## Common Commands

### Basic Validation

```bash
ai-how validate config.yaml
```

### HPC Cluster Management

```bash
# Start cluster
ai-how hpc start config.yaml

# Check status
ai-how hpc status

# Stop cluster
ai-how hpc stop config.yaml

# Destroy cluster
ai-how hpc destroy config.yaml --force
```

### PCIe Device Inventory

```bash
ai-how inventory pcie
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AI_HOW_STATE_FILE` | `output/state.json` | State file location |
| `AI_HOW_LOG_LEVEL` | `INFO` | Logging verbosity |
| `LIBVIRT_URI` | `qemu:///system` | libvirt connection URI |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General failure (config error, validation failure) |
| 2 | File not found |
| 3 | Permission denied |
| 4 | Invalid argument |
| 5 | System error (libvirt, VFIO, etc.) |

## See Also

- [CLI Reference](cli-reference.md) - Complete command reference
- [Schema Guide](schema-guide.md) - Configuration schema details
- [API Documentation](api/ai_how.md) - Python API reference
- [State Management](state-management.md) - State persistence details
