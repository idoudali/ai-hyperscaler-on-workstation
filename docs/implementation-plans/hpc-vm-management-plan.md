# HPC VM Management Implementation Plan

## Overview

This document outlines the implementation plan for enabling HPC cluster VM management
in the AI-HOW CLI. The implementation will provide `hpc start`, `hpc stop`, and
`hpc destroy` commands to manage the virtualized HPC infrastructure using libvirt
storage pools and volumes for enhanced storage management.

## Current State Analysis

### ✅ Existing Components

- **CLI Framework**: Typer-based CLI with command structure in place
- **Configuration Management**: YAML-based cluster configuration with JSON schema
  validation
- **Project Structure**: Well-organized Python package (`ai_how`) with clear
  module separation
- **Base Images**: Packer templates for building HPC base images (needs enhancement)
- **Configuration Schema**: Comprehensive JSON schema for cluster validation

### 🚧 Implementation Requirements

- VM lifecycle management (create, start, stop, destroy)
- libvirt XML template generation from cluster configuration
- **Volume pool and volume management** per cluster with copy-on-write volumes
- State tracking and persistence
- Error handling and rollback capabilities
- Ansible inventory generation

## QEMU Platform Requirements: Q35 vs i440FX

### Critical Platform Selection for Modern HPC Features

**REQUIRED: Q35 Chipset for Modern Virtualization**

This implementation **REQUIRES** the modern QEMU Q35 machine type (`pc-q35-8.0` or later) for
all HPC cluster VMs. The older i440FX chipset (`pc-i440fx-*`) is **NOT SUPPORTED** for the
following reasons:

#### Q35 Chipset Advantages (REQUIRED)

| Feature | Q35 Support | i440FX Support | HPC Impact |
|---------|-------------|----------------|------------|
| **PCIe Passthrough** | ✅ Full Support | ❌ Limited/None | **CRITICAL** for GPU computing |
| **Native PCIe Root Complex** | ✅ Native PCIe | ❌ PCI-to-PCIe Bridge | **REQUIRED** for high-performance devices |
| **Modern IOMMU** | ✅ Advanced IOMMU | ❌ Limited IOMMU | **ESSENTIAL** for device isolation |
| **SR-IOV Support** | ✅ Full Support | ❌ No Support | **NEEDED** for network virtualization |
| **Advanced IRQ Handling** | ✅ MSI/MSI-X | ❌ Legacy IRQ | **CRITICAL** for GPU performance |
| **PCIe Device Hotplug** | ✅ Supported | ❌ Not Supported | **USEFUL** for dynamic allocation |
| **Multiple PCIe Root Ports** | ✅ Native | ❌ Emulated | **REQUIRED** for multiple GPUs |

#### Q35 Architecture Benefits

```text
Q35 Chipset (Modern - REQUIRED)
┌─────────────────────────────────────────┐
│ CPU ←→ PCIe Root Complex (Native)       │
│         ├── PCIe Root Port 1 → GPU 1    │
│         ├── PCIe Root Port 2 → GPU 2    │
│         ├── PCIe Root Port 3 → NVMe     │
│         └── PCIe Root Port 4 → Network  │
└─────────────────────────────────────────┘
✅ Direct PCIe lanes for maximum performance
✅ Native IOMMU integration
✅ Hardware-accelerated virtualization

i440FX Chipset (Legacy - NOT SUPPORTED)
┌─────────────────────────────────────────┐
│ CPU ←→ PCI Bus (Legacy)                 │
│         └── PCI-to-PCIe Bridge         │
│             ├── Emulated PCIe → GPU    │
│             └── Limited IOMMU support  │
└─────────────────────────────────────────┘
❌ Emulated PCIe with performance overhead
❌ Limited IOMMU support for device isolation
❌ No native support for modern GPUs
```

#### Technical Requirements Enforced

```python
# Machine type validation enforces Q35
def _validate_machine_type_requirements(self, hardware_config: dict) -> bool:
    """CRITICAL: Q35 chipset validation for modern features."""
    
    # GPU passthrough REQUIRES Q35
    if has_pcie_devices:
        # Q35 machine type: pc-q35-8.0 or later
        # Provides native PCIe root complex
        # Required for GPU, network, storage passthrough
        self.logger.info("PCIe passthrough detected - Q35 machine type is REQUIRED")
        
    # Advanced features RECOMMEND Q35  
    if uses_advanced_features:
        # Better performance and compatibility
        # Future-proof for emerging features
        self.logger.info("Advanced features detected - Q35 machine type RECOMMENDED")
```

#### GPU Passthrough Requirements

**Q35 Chipset Requirements for GPU Passthrough:**

1. **Native PCIe Root Complex**: Direct CPU-to-GPU communication
2. **Advanced IOMMU**: Complete device isolation and DMA protection
3. **MSI/MSI-X Interrupts**: Modern interrupt handling for GPU performance
4. **PCIe ACS Support**: Advanced PCIe isolation capabilities
5. **SR-IOV Ready**: Support for GPU virtualization features

#### Configuration Enforcement

All VM templates now enforce Q35 machine type:

```xml
<!-- All VMs use Q35 for modern feature support -->
<os>
  <type arch="x86_64" machine="pc-q35-8.0">hvm</type>
  <boot dev="hd"/>
</os>
```

#### Compatibility and Migration

**Migrating from i440FX to Q35:**

- **No automatic migration**: VMs must be recreated with Q35
- **Configuration changes**: PCI device addressing may change
- **Performance improvement**: Significant improvement for GPU workloads
- **Future compatibility**: Q35 is the modern standard for QEMU

**Supported Q35 Versions:**

- `pc-q35-8.0` (Recommended - Latest stable)
- `pc-q35-7.2` (Minimum supported)
- `pc-q35-9.0` (Latest - when available)

## Architecture Design

### Library Selection and Rationale

#### Primary VM Management: `libvirt-python`

```python
# Recommended: libvirt-python (official Python bindings)
import libvirt
```

**Rationale:**

- **Official bindings**: Direct Python bindings for libvirt C API
- **Full feature access**: Complete access to libvirt functionality including storage
- **Performance**: Native C bindings provide optimal performance
- **Error handling**: Comprehensive exception handling and debugging
- **Community support**: Well-maintained and documented

**Alternative Options Considered:**

- `subprocess` + `virsh`: Less reliable, harder error handling
- `virt-manager` components: Too heavyweight for our use case
- `python-terraform` + libvirt provider: Adds unnecessary complexity

#### Configuration and State Management

```python
# Template rendering
from jinja2 import Template, Environment, FileSystemLoader

# State persistence
import json
from pathlib import Path

# Resource validation
import yaml
from ai_how.validation import validate_config
```

#### Storage Management: **libvirt Storage API**

```python
# Native libvirt storage management
import libvirt
from pathlib import Path
```

**Rationale:**

- **Native integration**: Direct libvirt storage pool and volume management
- **Better security**: Proper permissions and access control
- **Enhanced features**: Snapshots, migration, monitoring, multiple storage backends
- **Unified API**: Single interface for all libvirt operations

### Component Architecture

```text
ai_how/
├── cli.py                 # CLI entry points (existing)
├── vm_management/         # New VM management module
│   ├── __init__.py
│   ├── hpc_manager.py     # HPC cluster manager
│   ├── libvirt_client.py  # libvirt connection wrapper
│   ├── vm_lifecycle.py    # VM CRUD operations
│   ├── volume_manager.py  # libvirt storage pool/volume operations
│   ├── network_manager.py # libvirt network management
│   └── templates/         # libvirt XML templates
│       ├── controller.xml.j2
│       ├── compute_node.xml.j2
│       ├── storage_pool.xml.j2
│       ├── cluster_network.xml.j2
│       └── vm_features.xml.j2  # NEW: Hardware features template
├── state/                 # New state management module
│   ├── __init__.py
│   ├── cluster_state.py   # State persistence and tracking
│   └── models.py          # State data models
├── ansible/               # New ansible integration
│   ├── __init__.py
│   └── inventory.py       # Ansible inventory generation
└── validation.py          # Configuration validation (existing)
```

## Implementation Phases

### Phase 1: Core VM Management Infrastructure

#### 1.1 XML Tracing System (**NEW**)

```python
# ai_how/vm_management/xml_tracer.py
import json
import datetime
from pathlib import Path
from typing import Dict, List, Optional

class XMLTracer:
    """Traces and logs all XML definitions passed to libvirt APIs in versioned folders."""
    
    def __init__(self, cluster_name: str, operation: str = "unknown"):
        self.cluster_name = cluster_name
        self.operation = operation
        self.start_time = datetime.datetime.now()
        self.xml_records: List[Dict] = []
        self.operation_counter = 0
        self.trace_folder = self._generate_trace_folder()
        self.metadata_file = self.trace_folder / "trace_metadata.json"
        
        # Create trace folder
        self.trace_folder.mkdir(parents=True, exist_ok=True)
    
    def _generate_trace_folder(self) -> Path:
        """Generate unique versioned trace folder per run."""
        timestamp = self.start_time.strftime("%Y%m%d_%H%M%S_%f")[:-3]  # Include milliseconds
        folder_name = f"run_{self.cluster_name}_{self.operation}_{timestamp}"
        return Path("traces") / folder_name
    
    def log_xml(self, xml_type: str, xml_content: str, operation: str, 
                target_name: str = None, success: bool = True, error: str = None):
        """Log XML content to individual files in versioned trace folder."""
        self.operation_counter += 1
        timestamp = datetime.datetime.now()
        
        # Generate filename for this XML operation
        target_suffix = f"_{target_name}" if target_name else ""
        status_suffix = "_SUCCESS" if success else "_FAILED"
        xml_filename = f"{self.operation_counter:03d}_{xml_type}_{operation}{target_suffix}{status_suffix}.xml"
        xml_file_path = self.trace_folder / xml_filename
        
        # Save XML content to file
        with open(xml_file_path, 'w') as f:
            f.write(xml_content)
        
        # Create metadata record
        record = {
            "sequence": self.operation_counter,
            "timestamp": timestamp.isoformat(),
            "xml_type": xml_type,  # "domain", "network", "pool", "volume"
            "operation": operation,  # "create", "define", "destroy", etc.
            "target_name": target_name,
            "success": success,
            "error": error,
            "xml_file": xml_filename,
            "xml_length": len(xml_content)
        }
        self.xml_records.append(record)
    
    def save_trace(self):
        """Save metadata summary to trace folder."""
        trace_metadata = {
            "cluster_name": self.cluster_name,
            "operation": self.operation,
            "start_time": self.start_time.isoformat(),
            "end_time": datetime.datetime.now().isoformat(),
            "total_xml_operations": len(self.xml_records),
            "trace_folder": str(self.trace_folder),
            "xml_operations": self.xml_records,
            "file_listing": self._get_trace_file_listing()
        }
        
        with open(self.metadata_file, 'w') as f:
            json.dump(trace_metadata, f, indent=2)
        
        return self.trace_folder
    
    def _get_trace_file_listing(self) -> List[str]:
        """Get list of all XML files in trace folder."""
        xml_files = []
        for file_path in sorted(self.trace_folder.glob("*.xml")):
            xml_files.append(file_path.name)
        return xml_files
    
    def get_summary(self) -> Dict:
        """Get summary of XML operations and trace folder location."""
        operations = {}
        xml_types = {}
        success_count = 0
        
        for record in self.xml_records:
            op = record['operation']
            xml_type = record['xml_type']
            
            operations[op] = operations.get(op, 0) + 1
            xml_types[xml_type] = xml_types.get(xml_type, 0) + 1
            
            if record['success']:
                success_count += 1
        
        return {
            "total_operations": len(self.xml_records),
            "successful_operations": success_count,
            "failed_operations": len(self.xml_records) - success_count,
            "operations_by_type": operations,
            "xml_types": xml_types,
            "trace_folder": str(self.trace_folder),
            "metadata_file": str(self.metadata_file)
        }
```

#### 1.2 libvirt Client Wrapper with XML Tracing

```python
# ai_how/vm_management/libvirt_client.py
class LibvirtClient:
    """Thread-safe libvirt connection wrapper with error handling and XML tracing."""
    
    def __init__(self, uri: str = "qemu:///system", xml_tracer: Optional[XMLTracer] = None):
        self.uri = uri
        self._connection = None
        self.xml_tracer = xml_tracer
    
    def connect(self) -> libvirt.virConnect:
        """Establish libvirt connection with proper error handling."""
    
    def list_domains(self) -> list[str]:
        """List all domains with error handling."""
    
    def domain_exists(self, name: str) -> bool:
        """Check if domain exists."""
    
    def get_domain(self, name: str) -> libvirt.virDomain:
        """Get domain by name with error handling."""
    
    def list_storage_pools(self) -> list[str]:
        """List all storage pools."""
    
    def storage_pool_exists(self, name: str) -> bool:
        """Check if storage pool exists."""
    
    def get_storage_pool(self, name: str) -> libvirt.virStoragePool:
        """Get storage pool by name with error handling."""
    
    def list_networks(self) -> list[str]:
        """List all virtual networks."""
    
    def network_exists(self, name: str) -> bool:
        """Check if virtual network exists."""
    
    def get_network(self, name: str) -> libvirt.virNetwork:
        """Get virtual network by name with error handling."""
    
    def create_network(self, xml: str, network_name: str = None) -> libvirt.virNetwork:
        """Create virtual network from XML definition with tracing."""
        try:
            network = self._connection.networkCreateXML(xml)
            if self.xml_tracer:
                self.xml_tracer.log_xml("network", xml, "create", network_name, True)
            return network
        except Exception as e:
            if self.xml_tracer:
                self.xml_tracer.log_xml("network", xml, "create", network_name, False, str(e))
            raise
    
    def define_storage_pool(self, xml: str, pool_name: str = None) -> libvirt.virStoragePool:
        """Define storage pool from XML definition with tracing."""
        try:
            pool = self._connection.storagePoolDefineXML(xml, 0)
            if self.xml_tracer:
                self.xml_tracer.log_xml("pool", xml, "define", pool_name, True)
            return pool
        except Exception as e:
            if self.xml_tracer:
                self.xml_tracer.log_xml("pool", xml, "define", pool_name, False, str(e))
            raise
    
    def create_volume(self, pool: libvirt.virStoragePool, xml: str, volume_name: str = None) -> libvirt.virStorageVol:
        """Create volume from XML definition with tracing."""
        try:
            volume = pool.createXML(xml, 0)
            if self.xml_tracer:
                self.xml_tracer.log_xml("volume", xml, "create", volume_name, True)
            return volume
        except Exception as e:
            if self.xml_tracer:
                self.xml_tracer.log_xml("volume", xml, "create", volume_name, False, str(e))
            raise
    
    def define_domain(self, xml: str, domain_name: str = None) -> libvirt.virDomain:
        """Define domain from XML definition with tracing."""
        try:
            domain = self._connection.defineXML(xml)
            if self.xml_tracer:
                self.xml_tracer.log_xml("domain", xml, "define", domain_name, True)
            return domain
        except Exception as e:
            if self.xml_tracer:
                self.xml_tracer.log_xml("domain", xml, "define", domain_name, False, str(e))
            raise
    
    def destroy_network(self, name: str) -> bool:
        """Destroy virtual network and clean up."""
```

#### 1.2 VM Lifecycle Management

```python
# ai_how/vm_management/vm_lifecycle.py
class VMLifecycleManager:
    """Manages VM creation, start, stop, destroy operations."""
    
    def create_vm(self, vm_config: dict, xml_template: str) -> str:
        """Create VM from configuration and XML template."""
    
    def start_vm(self, domain_name: str) -> bool:
        """Start VM with error handling."""
    
    def stop_vm(self, domain_name: str, force: bool = False) -> bool:
        """Stop VM gracefully or forcefully."""
    
    def destroy_vm(self, domain_name: str) -> bool:
        """Destroy VM and clean up resources."""
```

#### 1.3 Volume Management (**NEW - Libvirt-Native Approach**)

```python
# ai_how/vm_management/volume_manager.py
class VolumeManager:
    """Manages libvirt storage pools and volumes for HPC clusters using native APIs."""
    
    def __init__(self, libvirt_client: LibvirtClient):
        self.client = libvirt_client
    
    def create_cluster_pool(self, cluster_name: str, pool_path: Path, 
                           base_image_path: Path) -> str:
        """Create a storage pool for the cluster with base image using libvirt APIs.
        
        Note: Lets libvirt handle directory creation and permissions automatically
        via pool.build(0) instead of manual directory creation.
        """
        
    def destroy_cluster_pool(self, cluster_name: str, force: bool = False) -> bool:
        """Destroy cluster storage pool and all volumes."""
    
    def create_vm_volume(self, cluster_name: str, vm_name: str, 
                        size_gb: int, vm_type: str = "compute") -> str:
        """Create a COW volume for a VM in the cluster pool."""
    
    def destroy_vm_volume(self, cluster_name: str, vm_name: str) -> bool:
        """Destroy VM volume from cluster pool."""
    
    def resize_vm_volume(self, cluster_name: str, vm_name: str, 
                        new_size_gb: int) -> bool:
        """Resize VM volume."""
    
    def get_volume_info(self, cluster_name: str, vm_name: str) -> dict:
        """Get volume information and statistics."""
    
    def list_cluster_volumes(self, cluster_name: str) -> list[dict]:
        """List all volumes in cluster pool."""
    
    def get_pool_info(self, cluster_name: str) -> dict:
        """Get storage pool information and statistics."""
    
    def validate_pool_space(self, cluster_name: str, 
                           required_space_gb: int) -> bool:
        """Validate available space in pool."""
    
    # New libvirt-native helper methods
    def _volume_exists_in_pool(self, pool_name: str, volume_name: str) -> bool:
        """Check if volume exists in storage pool using libvirt APIs."""
    
    def _create_base_volume_from_image(self, pool_name: str, volume_name: str, 
                                      source_image_path: Path) -> None:
        """Create base volume in pool from existing image using libvirt stream API."""
    
    def _upload_volume_data(self, volume: libvirt.virStorageVol, 
                           source_path: Path) -> None:
        """Upload data to volume using libvirt stream API for secure transfers."""
```

#### 1.4 Network Management (**NEW - Per-Cluster Virtual Networks**)

```python
# ai_how/vm_management/network_manager.py
class NetworkManager:
    """Manages libvirt virtual networks for HPC clusters."""
    
    def __init__(self, libvirt_client: LibvirtClient):
        self.client = libvirt_client
        self.logger = logging.getLogger(__name__)
    
    def create_cluster_network(self, cluster_name: str, network_config: dict) -> str:
        """Create an isolated virtual network for the cluster."""
        
    def destroy_cluster_network(self, cluster_name: str, force: bool = False) -> bool:
        """Destroy cluster virtual network."""
    
    def start_network(self, cluster_name: str) -> bool:
        """Start cluster virtual network."""
    
    def stop_network(self, cluster_name: str) -> bool:
        """Stop cluster virtual network."""
    
    def get_network_info(self, cluster_name: str) -> dict:
        """Get network information and statistics."""
    
    def allocate_ip_address(self, cluster_name: str, vm_name: str) -> str:
        """Allocate IP address for VM in cluster network."""
    
    def release_ip_address(self, cluster_name: str, vm_name: str) -> bool:
        """Release VM IP address from cluster network."""
    
    def list_cluster_ips(self, cluster_name: str) -> dict:
        """List all allocated IPs in cluster network."""
    
    def validate_network_config(self, network_config: dict) -> bool:
        """Validate network configuration parameters."""
    
    def get_dhcp_leases(self, cluster_name: str) -> list[dict]:
        """Get DHCP lease information for cluster network."""
```

### Phase 2: State Management System

#### 2.1 State Data Models

```python
# ai_how/state/models.py
from enum import Enum
from dataclasses import dataclass
from datetime import datetime
from typing import Optional, List

class VMState(Enum):
    """VM lifecycle states."""
    CREATED = "created"
    STARTING = "starting"
    RUNNING = "running"
    STOPPING = "stopping"
    STOPPED = "stopped"
    ERROR = "error"

@dataclass
class VolumeInfo:
    """Volume information and state."""
    name: str
    path: str
    size_gb: int
    allocated_gb: float
    format: str
    created_at: datetime

@dataclass
class StoragePoolInfo:
    """Storage pool information."""
    name: str
    path: str
    type: str
    capacity_gb: float
    allocation_gb: float
    available_gb: float
    volumes: List[VolumeInfo]
    created_at: datetime

@dataclass
class NetworkInfo:
    """Virtual network information."""
    name: str
    bridge_name: str
    network_range: str  # e.g., "192.168.100.0/24"
    gateway_ip: str
    dhcp_start: str
    dhcp_end: str
    dns_servers: List[str]
    is_active: bool
    allocated_ips: dict  # vm_name -> ip_address mapping
    created_at: datetime

@dataclass
class VMInfo:
    """VM information and state."""
    name: str
    state: VMState
    ip_address: Optional[str]
    created_at: datetime
    last_updated: datetime
    volume_path: str  # Changed from disk_path
    memory_mb: int
    cpu_cores: int
    vm_type: str  # controller, compute, etc.

@dataclass
class ClusterState:
    """HPC cluster state information."""
    name: str
    status: str
    vms: List[VMInfo]
    storage_pool: StoragePoolInfo
    network: NetworkInfo
    created_at: datetime
    last_updated: datetime
    config_file: str
```

#### 2.2 State Persistence

```python
# ai_how/state/cluster_state.py
class ClusterStateManager:
    """Manages cluster state persistence and recovery."""
    
    def __init__(self, state_file: Path):
        self.state_file = state_file
        self._state: Optional[ClusterState] = None
    
    def load_state(self) -> ClusterState:
        """Load cluster state from file."""
    
    def save_state(self, state: ClusterState) -> bool:
        """Save cluster state to file with atomic write."""
    
    def update_vm_state(self, vm_name: str, new_state: VMState) -> bool:
        """Update VM state and persist changes."""
    
    def add_vm(self, vm_info: VMInfo) -> bool:
        """Add new VM to cluster state."""
    
    def remove_vm(self, vm_name: str) -> bool:
        """Remove VM from cluster state."""
    
    def update_storage_info(self, pool_info: StoragePoolInfo) -> bool:
        """Update storage pool information."""
    
    def update_network_info(self, network_info: NetworkInfo) -> bool:
        """Update network information."""
    
    def allocate_vm_ip(self, vm_name: str, ip_address: str) -> bool:
        """Allocate IP address to VM and update state."""
    
    def release_vm_ip(self, vm_name: str) -> bool:
        """Release VM IP address and update state."""
```

### Phase 3: HPC Cluster Manager

#### 3.1 Cluster Lifecycle Management

```python
# ai_how/vm_management/hpc_manager.py
class HPCClusterManager:
    """Orchestrates HPC cluster operations with volume management and XML tracing."""
    
    def __init__(self, config: dict, state_manager: ClusterStateManager, operation: str = "cluster"):
        self.config = config
        self.state_manager = state_manager
        
        # Initialize XML tracer for this operation
        cluster_name = config['cluster']['name']
        self.xml_tracer = XMLTracer(cluster_name, operation)
        
        # Initialize managers with XML tracing
        self.libvirt_client = LibvirtClient(xml_tracer=self.xml_tracer)
        self.vm_manager = VMLifecycleManager(self.libvirt_client)
        self.volume_manager = VolumeManager(self.libvirt_client)
        self.network_manager = NetworkManager(self.libvirt_client)
        
        # Initialize host configuration management
        self.host_config = config.get('host_configuration', {})
        self.logger = logging.getLogger(__name__)
    
    def _is_host_changes_enabled(self, feature: str) -> bool:
        """Check if a specific host change feature is enabled.
        
        Args:
            feature: Feature name to check (e.g., 'cross_cluster_routing', 'host_dns_integration')
            
        Returns:
            True if the feature is enabled, False otherwise
        """
        # Default to False for all host changes (production-safe)
        network_config = self.host_config.get('network', {})
        
        if feature == 'cross_cluster_routing':
            return network_config.get('enable_cross_cluster_routing', False)
        elif feature == 'host_dns_integration':
            return network_config.get('enable_host_dns_integration', False)
        elif feature == 'service_discovery':
            return network_config.get('enable_service_discovery', False)
        else:
            # Unknown features are disabled by default
            return False
    
    def _confirm_host_changes(self, description: str) -> bool:
        """Request user confirmation for host system changes.
        
        Args:
            description: Description of the host change being requested
            
        Returns:
            True if confirmed, False if cancelled
        """
        # Check if confirmation is required
        if not self.host_config.get('require_confirmation', True):
            return True
        
        # For non-interactive environments, log and return False
        if not hasattr(self, '_interactive_mode') or not self._interactive_mode:
            self.logger.warning(
                f"Host change '{description}' requires confirmation but running in non-interactive mode. "
                f"Set require_confirmation: false to allow automatic execution."
            )
            return False
        
        # Interactive confirmation (placeholder for CLI integration)
        self.logger.warning(f"CONFIRMATION REQUIRED: {description}")
        self.logger.warning("This will modify the host system configuration.")
        # In actual implementation, this would prompt the user
        return False  # Default to False for safety
    
    def _log_host_change_attempt(self, feature: str, description: str, success: bool, error: str = None):
        """Log host change attempts for audit purposes.
        
        Args:
            feature: Feature name being modified
            description: Description of the change
            success: Whether the change was successful
            error: Error message if the change failed
        """
        if self.host_config.get('enable_audit_logging', True):
            if success:
                self.logger.info(f"Host change successful: {feature} - {description}")
            else:
                self.logger.error(f"Host change failed: {feature} - {description}: {error}")
    
    def start_cluster(self) -> bool:
        """Start complete HPC cluster with network, volume pool creation and XML tracing."""
        try:
            # 1. Create cluster virtual network
            # 2. Create cluster storage pool
            # 3. Create volumes for each VM
            # 4. Create and start VMs with network attachment
            # 5. Update state
            success = self._execute_cluster_start()
            return success
        finally:
            # Always save XML trace regardless of success/failure
            trace_folder = self.xml_tracer.save_trace()
            self.logger.info(f"XML trace saved to folder: {trace_folder}")
    
    def stop_cluster(self) -> bool:
        """Stop all VMs in cluster (preserve volumes and network)."""
        try:
            success = self._execute_cluster_stop()
            return success
        finally:
            trace_folder = self.xml_tracer.save_trace()
            self.logger.info(f"XML trace saved to folder: {trace_folder}")
    
    def destroy_cluster(self) -> bool:
        """Destroy cluster, VMs, storage pool, and virtual network."""
        try:
            success = self._execute_cluster_destroy()
            return success
        finally:
            trace_folder = self.xml_tracer.save_trace()
            self.logger.info(f"XML trace saved to folder: {trace_folder}")
    
    def get_cluster_status(self) -> dict:
        """Get detailed cluster status including storage and network."""
        return self._get_cluster_status_data()
    
    def get_xml_trace_summary(self) -> dict:
        """Get summary of XML operations for this cluster operation."""
        return self.xml_tracer.get_summary()
```

#### 3.2 Enhanced Configuration Integration with Hardware Validation

```python
# ai_how/vm_management/hpc_manager.py
def validate_cluster_config(self, config: dict) -> bool:
    """Validate cluster configuration before operations including hardware support."""
    
    # Check base image exists
    base_image = Path(config['base_image_path'])
    if not base_image.exists():
        raise ValueError(f"Base image not found: {base_image}")
    
    # Check storage pool location
    pool_path = Path(config.get('storage_pool_path', '/var/lib/libvirt/images'))
    if not pool_path.exists():
        raise ValueError(f"Storage pool path not found: {pool_path}")
    
    # Calculate required pool space
    required_space = self._calculate_required_pool_space(config)
    available_space = self._get_available_storage_space(pool_path)
    if available_space < required_space:
        raise ValueError(f"Insufficient storage space: {available_space}GB available, "
                        f"{required_space}GB required")
    
    # Validate network configuration and check for conflicts
    self._validate_network_config(config['network'])
    self._check_network_conflicts(config['network'])
    
    # NEW: Validate hardware configuration
    self._validate_hardware_config(config.get('cluster', {}).get('hardware', {}))
    
    # CRITICAL: Validate Q35 machine type for modern features
    self._validate_machine_type_requirements(config.get('cluster', {}).get('hardware', {}))
    
    return True

def _validate_hardware_config(self, hardware_config: dict) -> bool:
    """Validate hardware acceleration configuration (x86_64 only)."""
    
    acceleration_config = hardware_config.get('acceleration', {})
    
    # Check KVM availability  
    if acceleration_config.get('enable_kvm', True):
        if not self._check_kvm_availability():
            raise ValueError("KVM hardware virtualization is not available. "
                           "Either disable KVM or enable virtualization in BIOS.")
    
    # Check nested virtualization if enabled
    if acceleration_config.get('enable_nested', False):
        if not self._check_nested_virtualization_support():
            self.logger.warning("Nested virtualization requested but may not be supported")
    
    # Validate CPU model (x86_64 specific)
    cpu_model = acceleration_config.get('cpu_model', 'host-passthrough')
    if not self._validate_cpu_model_x86(cpu_model):
        raise ValueError(f"CPU model '{cpu_model}' is not supported for x86_64")
    
    # Check CPU feature compatibility  
    cpu_features = acceleration_config.get('cpu_features', [])
    unsupported_features = self._check_cpu_features_x86(cpu_features)
    if unsupported_features:
        self.logger.warning(f"Some CPU features may not be supported: {', '.join(unsupported_features)}")
    
    # Validate NUMA configuration
    numa_config = acceleration_config.get('numa_topology')
    if numa_config:
        if not self._validate_numa_configuration(numa_config):
            raise ValueError("Invalid NUMA topology configuration")
    
    # Check hugepage availability
    performance_config = acceleration_config.get('performance', {})
    if performance_config.get('enable_hugepages', False):
        hugepage_size = performance_config.get('hugepage_size', '2M')
        if not self._check_hugepage_availability(hugepage_size):
            raise ValueError(f"Hugepages ({hugepage_size}) are not configured on this system")
    
    # NEW: Validate PCIe passthrough configuration
    pcie_config = hardware_config.get('pcie_passthrough', {})
    if pcie_config.get('enabled', False):
        self._validate_pcie_passthrough_config(pcie_config)
    
    return True

def _check_kvm_availability(self) -> bool:
    """Check if KVM hardware virtualization is available (x86_64)."""
    # Check /dev/kvm exists
    if not Path('/dev/kvm').exists():
        return False
    
    # Check if KVM modules are loaded
    try:
        with open('/proc/modules', 'r') as f:
            modules = f.read()
            return 'kvm' in modules
    except (FileNotFoundError, PermissionError):
        return False

def _check_nested_virtualization_support(self) -> bool:
    """Check if nested virtualization is supported and enabled (x86_64)."""
    # Check Intel VT-x
    intel_path = '/sys/module/kvm_intel/parameters/nested'
    # Check AMD-V  
    amd_path = '/sys/module/kvm_amd/parameters/nested'
    
    for path in [intel_path, amd_path]:
        try:
            with open(path, 'r') as f:
                value = f.read().strip()
                if value in ['1', 'Y']:
                    return True
        except (FileNotFoundError, PermissionError):
            continue
    
    return False

def _validate_cpu_model_x86(self, cpu_model: str) -> bool:
    """Validate CPU model for x86_64 architecture."""
    x86_cpu_models = [
        'host', 'host-passthrough', 'host-model', 'qemu64', 
        'Haswell', 'Broadwell', 'Skylake', 'Cascadelake'
    ]
    return cpu_model in x86_cpu_models

def _check_cpu_features_x86(self, cpu_features: list[str]) -> list[str]:
    """Check x86_64 CPU feature compatibility and return unsupported features."""
    unsupported = []
    
    try:
        import subprocess
        result = subprocess.run(['lscpu'], capture_output=True, text=True, check=True)
        cpu_info = result.stdout.lower()
        
        # x86_64 feature mapping
        x86_features = {
            'vmx': 'vmx',
            'svm': 'svm', 
            'sse4.1': 'sse4_1',
            'sse4.2': 'sse4_2',
            'avx': 'avx',
            'avx2': 'avx2',
            'smep': 'smep',
            'smap': 'smap'
        }
        
        for feature in cpu_features:
            feature_name = feature.lstrip('+-')
            if feature_name in x86_features:
                if x86_features[feature_name] not in cpu_info:
                    unsupported.append(feature)
        
    except subprocess.CalledProcessError:
        unsupported = cpu_features
    
    return unsupported

def _validate_machine_type_requirements(self, hardware_config: dict) -> bool:
    """Validate machine type requirements for modern virtualization features.
    
    CRITICAL: Q35 chipset is REQUIRED for:
    - PCIe passthrough (GPU, network cards, storage devices)
    - Modern PCIe features and performance
    - Advanced IOMMU support
    - SR-IOV and virtualization
    
    The older i440FX chipset does NOT support modern PCIe features.
    """
    
    # Check if GPU/PCIe passthrough is enabled
    pcie_config = hardware_config.get('pcie_passthrough', {})
    has_pcie_devices = pcie_config.get('enabled', False) and pcie_config.get('devices', [])
    
    # Check if advanced features are enabled
    acceleration_config = hardware_config.get('acceleration', {})
    uses_advanced_features = any([
        acceleration_config.get('enable_nested', False),
        acceleration_config.get('performance', {}).get('enable_hugepages', False),
        has_pcie_devices
    ])
    
    if has_pcie_devices:
        self.logger.info("PCIe passthrough detected - Q35 machine type is REQUIRED")
        # Q35 is mandatory for PCIe passthrough
        return True
    
    if uses_advanced_features:
        self.logger.info("Advanced virtualization features detected - Q35 machine type RECOMMENDED")
        # Q35 is recommended for advanced features
        return True
    
    # Q35 is recommended for all modern deployments
    self.logger.info("Using Q35 machine type for modern QEMU platform support")
    return True

def _validate_pcie_passthrough_config(self, pcie_config: dict) -> bool:
    """Validate PCIe passthrough configuration and detect conflicts.
    
    REQUIRES: Q35 machine type for PCIe passthrough support.
    """
    
    if not self._check_iommu_support():
        raise ValueError("IOMMU is not enabled. PCIe passthrough requires IOMMU support.")
    
    devices = pcie_config.get('devices', [])
    if not devices:
        return True
    
    # CRITICAL: Ensure Q35 machine type for PCIe passthrough
    self.logger.info("PCIe passthrough requires Q35 machine type - this will be enforced in templates")
    
    # Validate device configuration
    for device in devices:
        pci_address = device['pci_address']
        assigned_to = device['assigned_to']
        
        # Check if device exists
        if not self._pci_device_exists(pci_address):
            raise ValueError(f"PCIe device {pci_address} not found on system")
        
        # Check IOMMU group
        iommu_group = device.get('iommu_group')
        if iommu_group is not None:
            if not self._validate_iommu_group(pci_address, iommu_group):
                self.logger.warning(f"IOMMU group mismatch for device {pci_address}")
    
    # Check for conflicts within cluster
    self._check_intra_cluster_gpu_conflicts(devices)
    
    # Check for conflicts across clusters
    if pcie_config.get('exclusive_mode', True):
        self._check_inter_cluster_gpu_conflicts(devices)
    
    return True

def _check_iommu_support(self) -> bool:
    """Check if IOMMU is enabled on the system."""
    try:
        # Check for Intel VT-d or AMD-Vi
        with open('/proc/cmdline', 'r') as f:
            cmdline = f.read()
            return any(param in cmdline for param in ['intel_iommu=on', 'amd_iommu=on', 'iommu=pt'])
    except (FileNotFoundError, PermissionError):
        return False

def _pci_device_exists(self, pci_address: str) -> bool:
    """Check if PCIe device exists at specified address."""
    device_path = Path(f"/sys/bus/pci/devices/{pci_address}")
    return device_path.exists()

def _validate_iommu_group(self, pci_address: str, expected_group: int) -> bool:
    """Validate IOMMU group for PCIe device."""
    try:
        iommu_link = Path(f"/sys/bus/pci/devices/{pci_address}/iommu_group")
        if iommu_link.exists() and iommu_link.is_symlink():
            actual_group = int(iommu_link.readlink().name)
            return actual_group == expected_group
    except (ValueError, OSError):
        pass
    return False

def _check_intra_cluster_gpu_conflicts(self, devices: list[dict]) -> None:
    """Check for GPU assignment conflicts within the same cluster."""
    pci_addresses = set()
    vm_assignments = {}
    
    for device in devices:
        pci_address = device['pci_address']
        assigned_to = device['assigned_to']
        
        # Check for duplicate PCI addresses
        if pci_address in pci_addresses:
            raise ValueError(f"PCIe device {pci_address} assigned to multiple VMs in cluster")
        pci_addresses.add(pci_address)
        
        # Check for multiple GPU assignments to same VM
        if device['device_type'] == 'gpu':
            if assigned_to in vm_assignments:
                self.logger.warning(f"VM {assigned_to} has multiple GPU assignments")
            vm_assignments[assigned_to] = vm_assignments.get(assigned_to, 0) + 1

def _check_inter_cluster_gpu_conflicts(self, devices: list[dict]) -> None:
    """Check for GPU assignment conflicts across different clusters."""
    from pathlib import Path
    import glob
    import yaml
    
    cluster_name = self.config['cluster']['name']
    
    # Find other cluster configurations
    config_pattern = Path("*.yaml")  # Adjust pattern as needed
    current_devices = {d['pci_address'] for d in devices}
    
    conflicts = []
    
    for config_file in Path('.').glob('*.yaml'):
        if config_file.name.endswith('.yaml'):
            try:
                with open(config_file, 'r') as f:
                    other_config = yaml.safe_load(f)
                
                other_cluster_name = other_config.get('cluster', {}).get('name')
                if other_cluster_name == cluster_name:
                    continue  # Skip self
                
                other_pcie = other_config.get('cluster', {}).get('hardware', {}).get('pcie_passthrough', {})
                other_devices = other_pcie.get('devices', [])
                
                for other_device in other_devices:
                    if other_device['pci_address'] in current_devices:
                        conflicts.append({
                            'pci_address': other_device['pci_address'],
                            'other_cluster': other_cluster_name,
                            'other_vm': other_device['assigned_to']
                        })
            
            except (yaml.YAMLError, KeyError, FileNotFoundError):
                continue
    
    if conflicts:
        conflict_list = [f"{c['pci_address']} (cluster: {c['other_cluster']}, VM: {c['other_vm']})" 
                        for c in conflicts]
        raise ValueError(f"GPU conflicts detected with other clusters: {', '.join(conflict_list)}. "
                        f"Only one cluster can be active when GPU conflicts exist.")

def _validate_numa_configuration(self, numa_config: dict) -> bool:
    """Validate NUMA topology configuration."""
    
    nodes = numa_config.get('nodes', 1)
    if nodes < 1:
        return False
    
    # Check if system has NUMA support
    try:
        numa_info_path = Path('/sys/devices/system/node')
        if not numa_info_path.exists():
            return nodes == 1  # No NUMA, only single node allowed
        
        # Count available NUMA nodes
        numa_nodes = list(numa_info_path.glob('node*'))
        available_nodes = len([n for n in numa_nodes if n.is_dir()])
        
        return nodes <= available_nodes
        
    except Exception:
        return nodes == 1  # Conservative fallback

def _check_hugepage_availability(self, hugepage_size: str) -> bool:
    """Check if hugepages of specified size are available."""
    
    hugepage_paths = {
        '2M': '/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages',
        '1G': '/sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages'
    }
    
    path = hugepage_paths.get(hugepage_size)
    if not path:
        return False
    
    try:
        with open(path, 'r') as f:
            num_hugepages = int(f.read().strip())
            return num_hugepages > 0
    except (FileNotFoundError, PermissionError, ValueError):
        return False

def _create_cluster_infrastructure(self) -> bool:
    """Create cluster network, storage pool and base infrastructure using libvirt APIs."""
    cluster_name = self.config['cluster']['name']
    base_image = Path(self.config['base_image_path'])
    pool_path = Path(self.config.get('storage_pool_path', '/var/lib/libvirt/images'))
    network_config = self.config['network']
    
    # Create cluster virtual network
    network_name = self.network_manager.create_cluster_network(
        cluster_name, network_config
    )
    
    # Start the network
    self.network_manager.start_network(cluster_name)
    
    # Create cluster storage pool using libvirt APIs
    # Note: libvirt handles directory creation and permissions automatically
    pool_name = self.volume_manager.create_cluster_pool(
        cluster_name, pool_path, base_image
    )
    
    # Update state with pool and network information
    pool_info = self.volume_manager.get_pool_info(cluster_name)
    network_info = self.network_manager.get_network_info(cluster_name)
    self.state_manager.update_storage_info(pool_info)
    self.state_manager.update_network_info(network_info)
    
    return True
```

#### 3.3 VM Provisioning with Volumes

```python
def _provision_vm(self, vm_config: dict) -> VMInfo:
    """Provision a single VM with dedicated volume and network."""
    cluster_name = self.config['cluster']['name']
    vm_name = vm_config['name']
    vm_type = vm_config.get('type', 'compute')
    disk_size = vm_config.get('disk_size_gb', 100)
    
    # Create VM volume in cluster pool
    volume_path = self.volume_manager.create_vm_volume(
        cluster_name, vm_name, disk_size, vm_type
    )
    
    # Allocate IP address in cluster network
    ip_address = self.network_manager.allocate_ip_address(cluster_name, vm_name)
    
    # Generate VM XML with volume, network, and hardware references
    xml_template = self._render_vm_template(vm_config, volume_path, cluster_name, ip_address)
    
    # Create VM
    domain_name = self.vm_manager.create_vm(vm_config, xml_template)
    
    # Update state with IP allocation
    self.state_manager.allocate_vm_ip(vm_name, ip_address)
    
    # Create VM info object
    vm_info = VMInfo(
        name=vm_name,
        state=VMState.CREATED,
        ip_address=ip_address,
        created_at=datetime.now(),
        last_updated=datetime.now(),
        volume_path=volume_path,
        memory_mb=vm_config['memory_mb'],
        cpu_cores=vm_config['cpu_cores'],
        vm_type=vm_type
    )
    
    return vm_info

def _render_vm_template(self, vm_config: dict, volume_path: str, 
                       cluster_name: str, ip_address: str) -> str:
    """Render VM XML template with hardware configuration support.
    
    CRITICAL: Always uses Q35 machine type for modern PCIe passthrough support.
    """
    from jinja2 import Environment, FileSystemLoader
    import uuid
    
    # Get hardware configuration
    hardware_config = self.config.get('cluster', {}).get('hardware', {})
    acceleration_config = hardware_config.get('acceleration', {})
    performance_config = acceleration_config.get('performance', {})
    
    # CRITICAL: Enforce Q35 machine type for all VMs
    machine_type = self._get_required_machine_type(hardware_config)
    
    # x86_64 emulator path
    emulator_path = '/usr/bin/qemu-system-x86_64'
    
    # Template variables with hardware configuration
    template_vars = {
        # Basic VM configuration
        'vm_name': vm_config['name'],
        'vm_uuid': str(uuid.uuid4()),
        'memory_mb': vm_config['memory_mb'],
        'cpu_cores': vm_config['cpu_cores'],
        'volume_path': volume_path,
        'cluster_name': cluster_name,
        'ip_address': ip_address,
        
        # Hardware acceleration settings (x86_64 only)
        'enable_kvm': acceleration_config.get('enable_kvm', True),
        'enable_nested': acceleration_config.get('enable_nested', False),
        'cpu_model': acceleration_config.get('cpu_model', 'host-passthrough'),
        'cpu_features': acceleration_config.get('cpu_features', []),
        'emulator_path': emulator_path,
        
        # CPU topology
        'cpu_topology': acceleration_config.get('cpu_topology', {
            'sockets': 1,
            'cores': vm_config['cpu_cores'],
            'threads': 1
        }),
        
        # NUMA configuration
        'numa_topology': acceleration_config.get('numa_topology'),
        
        # Performance settings
        'enable_hugepages': performance_config.get('enable_hugepages', False),
        'hugepage_size': performance_config.get('hugepage_size', '2M'),
        'cpu_pinning': performance_config.get('cpu_pinning', False),
        'memory_backing': performance_config.get('memory_backing', 'default'),
        
        # Machine type (REQUIRED: Q35 for modern features and PCIe passthrough)
        'machine_type': machine_type,
        
        # Network configuration
        'vm_mac_address': self._generate_mac_address(vm_config['name']),
        
        # NEW: PCIe passthrough configuration
        'pcie_devices': self._get_vm_pcie_devices(vm_config['name'], hardware_config.get('pcie_passthrough', {}))
    }
    }
    
    # Load and render template
    template_dir = Path(__file__).parent / "templates"
    env = Environment(loader=FileSystemLoader(template_dir))
    
    # Determine template based on VM type
    vm_type = vm_config.get('type', 'compute')
    template_name = f"{vm_type}_node.xml.j2"
    
    if not (template_dir / template_name).exists():
        template_name = "compute_node.xml.j2"  # Fallback to compute template
    
    template = env.get_template(template_name)
    return template.render(**template_vars)

def _generate_mac_address(self, vm_name: str) -> str:
    """Generate consistent MAC address for VM based on name."""
    import hashlib
    
    # Create deterministic MAC address based on VM name
    hash_object = hashlib.md5(vm_name.encode())
    hex_dig = hash_object.hexdigest()
    
    # Use first 6 bytes and ensure it's a valid MAC
    mac_bytes = [hex_dig[i:i+2] for i in range(0, 12, 2)]
    
    # Ensure first byte is even (unicast) and has local admin bit set
    mac_bytes[0] = f"{(int(mac_bytes[0], 16) & 0xfe) | 0x02:02x}"
    
    return ':'.join(mac_bytes)

def _get_vm_pcie_devices(self, vm_name: str, pcie_config: dict) -> list[dict]:
    """Get PCIe devices assigned to specific VM."""
    if not pcie_config.get('enabled', False):
        return []
    
    vm_devices = []
    for device in pcie_config.get('devices', []):
        if device.get('assigned_to') == vm_name:
            vm_devices.append({
                'pci_address': device['pci_address'],
                'device_type': device['device_type'],
                'vendor_id': device.get('vendor_id'),
                'device_id': device.get('device_id')
            })
    
    return vm_devices

def _get_required_machine_type(self, hardware_config: dict) -> str:
    """Get required machine type based on hardware configuration.
    
    CRITICAL: Always returns Q35 machine type for modern HPC features.
    
    Q35 is REQUIRED for:
    - PCIe passthrough (GPU, network, storage)
    - Modern IOMMU support
    - Advanced virtualization features
    - High-performance computing workloads
    """
    
    # Check for PCIe passthrough requirements
    pcie_config = hardware_config.get('pcie_passthrough', {})
    has_pcie_devices = pcie_config.get('enabled', False) and pcie_config.get('devices', [])
    
    if has_pcie_devices:
        self.logger.info("PCIe passthrough detected - enforcing Q35 machine type")
        # Use latest stable Q35 for PCIe passthrough
        return 'pc-q35-8.0'
    
    # Q35 is recommended for ALL modern HPC deployments
    self.logger.info("Using Q35 machine type for modern QEMU platform support")
    return 'pc-q35-8.0'
```

### Phase 4: Network and Storage Templates

#### 4.1 Cluster Network XML Template

```xml
<!-- ai_how/vm_management/templates/cluster_network.xml.j2 -->
<network>
  <name>{{ cluster_name }}-network</name>
  <bridge name="{{ bridge_name }}" stp="on" delay="0"/>
  <domain name="{{ cluster_name }}.local"/>
  <ip address="{{ gateway_ip }}" netmask="{{ netmask }}">
    <dhcp>
      <range start="{{ dhcp_start }}" end="{{ dhcp_end }}"/>
      {% for vm_name, ip in static_leases.items() %}
      <host mac="{{ vm_macs[vm_name] }}" name="{{ vm_name }}" ip="{{ ip }}"/>
      {% endfor %}
    </dhcp>
  </ip>
  {% if dns_servers %}
  <dns>
    {% for dns in dns_servers %}
    <forwarder addr="{{ dns }}"/>
    {% endfor %}
  </dns>
  {% endif %}
</network>
```

#### 4.2 Storage Pool XML Template

```xml
<!-- ai_how/vm_management/templates/storage_pool.xml.j2 -->
<pool type="dir">
  <name>{{ cluster_name }}-pool</name>
  <source>
  </source>
  <target>
    <path>{{ pool_path }}/{{ cluster_name }}</path>
    <permissions>
      <mode>0755</mode>
      <owner>libvirt-qemu</owner>
      <group>libvirt-qemu</group>
    </permissions>
  </target>
</pool>
```

#### 4.4 Enhanced VM XML Templates with Hardware Acceleration

```xml
<!-- ai_how/vm_management/templates/compute_node.xml.j2 (Simplified x86_64 + GPU Passthrough) -->
<domain type="{{ 'kvm' if enable_kvm else 'qemu' }}">
  <name>{{ vm_name }}</name>
  <uuid>{{ vm_uuid }}</uuid>
  <memory unit="MiB">{{ memory_mb }}</memory>
  <currentMemory unit="MiB">{{ memory_mb }}</currentMemory>
  
  <!-- CPU Configuration (x86_64 only) -->
  <vcpu placement="static">{{ cpu_cores }}</vcpu>
  
  {% if cpu_topology %}
  <cpu mode="{{ cpu_model }}">
    <!-- CPU Features -->
    {% for feature in cpu_features %}
    <feature policy="{{ 'require' if feature.startswith('+') else 'disable' }}" name="{{ feature.lstrip('+-') }}"/>
    {% endfor %}
    
    <!-- CPU Topology -->
    <topology sockets="{{ cpu_topology.sockets }}" 
              cores="{{ cpu_topology.cores }}" 
              threads="{{ cpu_topology.threads }}"/>
    
    <!-- NUMA Topology -->
    {% if numa_topology %}
    <numa>
      {% for node in range(numa_topology.nodes) %}
      <!-- markdownlint-disable-next-line MD013 -->
      <cell id="{{ node }}" cpus="{{ node * (cpu_cores // numa_topology.nodes) }}-{{ ((node + 1) * (cpu_cores // numa_topology.nodes)) - 1 }}" memory="{{ numa_topology.memory_per_node }}" unit="MiB"/>
      {% endfor %}
    </numa>
    {% endif %}
    
    <!-- Nested Virtualization -->
    {% if enable_nested %}
    <feature policy="require" name="vmx"/>  <!-- Intel VT-x -->
    <feature policy="require" name="svm"/>  <!-- AMD-V -->
    {% endif %}
  </cpu>
  {% endif %}
  
  <!-- Memory Backing Configuration -->
  {% if memory_backing != 'default' %}
  <memoryBacking>
    {% if memory_backing == 'hugepages' %}
    <hugepages>
      <page size="{{ hugepage_size }}" unit="M"/>
    </hugepages>
    {% elif memory_backing == 'memfd' %}
    <source type="memfd"/>
    {% endif %}
  </memoryBacking>
  {% endif %}
  
  <!-- OS and Boot Configuration (x86_64) -->
  <!-- CRITICAL: Q35 machine type REQUIRED for PCIe passthrough and modern features -->
  <os>
    <type arch="x86_64" machine="{{ machine_type }}">hvm</type>
    <boot dev="hd"/>
  </os>
  
  <!-- Features Configuration (x86_64 KVM) -->
  <features>
    {% if enable_kvm %}
    <acpi/>
    <apic/>
    <pae/>
    
    <!-- Performance Features -->
    <hyperv>
      <relaxed state="on"/>
      <vapic state="on"/>
      <spinlocks state="on" retries="8191"/>
      <vpindex state="on"/>
      <runtime state="on"/>
      <synic state="on"/>
      <stimer state="on"/>
      <reset state="on"/>
      <vendor_id state="on" value="KVMHyperV"/>
      <frequencies state="on"/>
      <reenlightenment state="on"/>
      <tlbflush state="on"/>
      <ipi state="on"/>
      <evmcs state="on"/>
    </hyperv>
    
    <kvm>
      <hidden state="{{ 'on' if enable_nested else 'off' }}"/>
      <hint-dedicated state="on"/>
    </kvm>
    
    <vmport state="off"/>
    {% endif %}
  </features>
  
  <!-- Clock Configuration (x86_64) -->
  <clock offset="utc">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
    {% if enable_kvm %}
    <timer name="hypervclock" present="yes"/>
    {% endif %}
  </clock>
  
  <!-- Power Management -->
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  
  <!-- Device Configuration -->
  <devices>
    <emulator>{{ emulator_path }}</emulator>
    
    <!-- Storage -->
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2" cache="writeback" io="threads"/>
      <source file="{{ volume_path }}"/>
      <target dev="vda" bus="virtio"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x04" function="0x0"/>
    </disk>
    
    <!-- Network -->
    <interface type="network">
      <source network="{{ cluster_name }}-network"/>
      {% if vm_mac_address %}
      <mac address="{{ vm_mac_address }}"/>
      {% endif %}
      <model type="virtio"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x0"/>
    </interface>
    
    <!-- NEW: PCIe Passthrough Devices -->
    {% for device in pcie_devices %}
    {% if device.device_type == 'gpu' %}
    <!-- GPU Passthrough -->
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x{{ device.pci_address.split(':')[0] }}" 
                 bus="0x{{ device.pci_address.split(':')[1] }}" 
                 slot="0x{{ device.pci_address.split(':')[2].split('.')[0] }}" 
                 function="0x{{ device.pci_address.split(':')[2].split('.')[1] }}"/>
      </source>
      {% if device.vendor_id and device.device_id %}
      <vendor id="0x{{ device.vendor_id }}"/>
      <product id="0x{{ device.device_id }}"/>
      {% endif %}
    </hostdev>
    {% else %}
    <!-- Other PCIe Device Passthrough -->
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x{{ device.pci_address.split(':')[0] }}" 
                 bus="0x{{ device.pci_address.split(':')[1] }}" 
                 slot="0x{{ device.pci_address.split(':')[2].split('.')[0] }}" 
                 function="0x{{ device.pci_address.split(':')[2].split('.')[1] }}"/>
      </source>
    </hostdev>
    {% endif %}
    {% endfor %}
    
    <!-- Graphics and Console -->
    <serial type="pty">
      <target type="isa-serial" port="0">
        <model name="isa-serial"/>
      </target>
    </serial>
    <console type="pty">
      <target type="serial" port="0"/>
    </console>
    
    {% if not pcie_devices or not (pcie_devices | selectattr('device_type', 'equalto', 'gpu') | list) %}
    <!-- VNC Graphics (only if no GPU passthrough) -->
    <graphics type="vnc" port="-1" autoport="yes" listen="0.0.0.0">
      <listen type="address" address="0.0.0.0"/>
    </graphics>
    
    <!-- Video (only if no GPU passthrough) -->
    <video>
      <model type="cirrus" vram="16384" heads="1" primary="yes"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x0"/>
    </video>
    {% endif %}
    
    <!-- Input devices -->
    <input type="mouse" bus="ps2"/>
    <input type="keyboard" bus="ps2"/>
    
    <!-- Memory Balloon -->
    <memballoon model="virtio">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x05" function="0x0"/>
    </memballoon>
    
    <!-- RNG Device for entropy -->
    <rng model="virtio">
      <backend model="random">/dev/urandom</backend>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x06" function="0x0"/>
    </rng>
  </devices>
</domain>
```

#### 4.5 Simplified Hardware Features Template

```xml
<!-- ai_how/vm_management/templates/vm_features.xml.j2 (Simplified x86_64 only) -->
<!-- Reusable hardware features template for inclusion in VM definitions -->

<!-- CPU Configuration (x86_64 only) -->
{% macro render_cpu_configuration(cpu_config) %}
<cpu mode="{{ cpu_config.model }}">
  <!-- CPU Features -->
  {% for feature in cpu_config.features %}
  <feature policy="{{ 'require' if feature.startswith('+') else 'disable' }}" 
           name="{{ feature.lstrip('+-') }}"/>
  {% endfor %}
  
  <!-- CPU Topology -->
  {% if cpu_config.topology %}
  <topology sockets="{{ cpu_config.topology.sockets }}" 
            cores="{{ cpu_config.topology.cores }}" 
            threads="{{ cpu_config.topology.threads }}"/>
  {% endif %}
  
  <!-- NUMA Configuration -->
  {% if cpu_config.numa %}
  <numa>
    {% for node in range(cpu_config.numa.nodes) %}
    <cell id="{{ node }}" 
          <!-- markdownlint-disable-next-line MD013 -->
          cpus="{{ node * (cpu_config.total_cores // cpu_config.numa.nodes) }}-{{ ((node + 1) * (cpu_config.total_cores // cpu_config.numa.nodes)) - 1 }}" 
          memory="{{ cpu_config.numa.memory_per_node }}" 
          unit="MiB"/>
    {% endfor %}
  </numa>
  {% endif %}
</cpu>
{% endmacro %}

<!-- OS Configuration (x86_64 only) -->
<!-- CRITICAL: Q35 machine type REQUIRED for modern features and PCIe passthrough -->
{% macro render_os_configuration(os_config) %}
<os>
  <type arch="x86_64" machine="{{ os_config.machine_type | default('pc-q35-8.0') }}">hvm</type>
  <boot dev="hd"/>
</os>
{% endmacro %}

<!-- Performance Features (x86_64 KVM) -->
{% macro render_features(features_config) %}
<features>
  {% if features_config.enable_kvm %}
  <!-- Standard virtualization features -->
  <acpi/>
  <apic/>
  <pae/>
  
  <!-- Hyper-V enlightenments for better performance -->
  <hyperv>
    <relaxed state="on"/>
    <vapic state="on"/>
    <spinlocks state="on" retries="8191"/>
    <vpindex state="on"/>
    <runtime state="on"/>
    <synic state="on"/>
    <stimer state="on"/>
    <reset state="on"/>
    <vendor_id state="on" value="KVMHyperV"/>
    <frequencies state="on"/>
    <reenlightenment state="on"/>
    <tlbflush state="on"/>
    <ipi state="on"/>
    <evmcs state="on"/>
  </hyperv>
  
  <!-- KVM-specific features -->
  <kvm>
    <hidden state="{{ 'on' if features_config.enable_nested else 'off' }}"/>
    <hint-dedicated state="on"/>
  </kvm>
  
  <vmport state="off"/>
  {% endif %}
</features>
{% endmacro %}

<!-- Memory backing configuration -->
{% macro render_memory_backing(memory_config) %}
{% if memory_config.backing != 'default' %}
<memoryBacking>
  {% if memory_config.backing == 'hugepages' %}
  <hugepages>
    <page size="{{ memory_config.hugepage_size | default('2M') }}" unit="M"/>
  </hugepages>
  {% elif memory_config.backing == 'memfd' %}
  <source type="memfd"/>
  {% endif %}
</memoryBacking>
{% endif %}
{% endmacro %}

<!-- PCIe Passthrough Devices -->
{% macro render_pcie_devices(pcie_devices) %}
{% for device in pcie_devices %}
<hostdev mode="subsystem" type="pci" managed="yes">
  <source>
    <address domain="0x{{ device.pci_address.split(':')[0] }}" 
             bus="0x{{ device.pci_address.split(':')[1] }}" 
             slot="0x{{ device.pci_address.split(':')[2].split('.')[0] }}" 
             function="0x{{ device.pci_address.split(':')[2].split('.')[1] }}"/>
  </source>
  {% if device.vendor_id and device.device_id %}
  <vendor id="0x{{ device.vendor_id }}"/>
  <product id="0x{{ device.device_id }}"/>
  {% endif %}
</hostdev>
{% endfor %}
{% endmacro %}
```

#### 4.3 Network Implementation Details

```python
# ai_how/vm_management/network_manager.py
def create_cluster_network(self, cluster_name: str, network_config: dict) -> str:
    """Create an isolated virtual network for the cluster."""
    
    network_name = f"{cluster_name}-network"
    bridge_name = network_config.get('bridge_name', f"br-{cluster_name}")
    network_range = network_config.get('network_range', "192.168.100.0/24")
    
    # Parse network configuration
    import ipaddress
    network = ipaddress.IPv4Network(network_range, strict=False)
    gateway_ip = str(network.network_address + 1)
    netmask = str(network.netmask)
    
    # Calculate DHCP range
    dhcp_start = network_config.get('dhcp_start', str(network.network_address + 10))
    dhcp_end = network_config.get('dhcp_end', str(network.broadcast_address - 1))
    
    # DNS servers
    dns_servers = network_config.get('dns_servers', ['8.8.8.8', '1.1.1.1'])
    
    # Generate MAC addresses for static leases (optional)
    static_leases = network_config.get('static_leases', {})
    vm_macs = network_config.get('vm_macs', {})
    
    # Render network XML template
    template_vars = {
        'cluster_name': cluster_name,
        'bridge_name': bridge_name,
        'gateway_ip': gateway_ip,
        'netmask': netmask,
        'dhcp_start': dhcp_start,
        'dhcp_end': dhcp_end,
        'dns_servers': dns_servers,
        'static_leases': static_leases,
        'vm_macs': vm_macs
    }
    
    network_xml = self._render_network_template(template_vars)
    
    # Create network
    network = self.client.create_network(network_xml)
    
    self.logger.info(f"Created network for {cluster_name}: {network_name}")
    return network_name

def _render_network_template(self, template_vars: dict) -> str:
    """Render network XML template with variables."""
    from jinja2 import Template
    
    template_path = Path(__file__).parent / "templates" / "cluster_network.xml.j2"
    with open(template_path, 'r') as f:
        template = Template(f.read())
    
    return template.render(**template_vars)

def allocate_ip_address(self, cluster_name: str, vm_name: str) -> str:
    """Allocate IP address for VM in cluster network."""
    network_name = f"{cluster_name}-network"
    
    # Get network info to find available IP
    network_info = self.get_network_info(cluster_name)
    allocated_ips = set(network_info['allocated_ips'].values())
    
    # Parse network range
    import ipaddress
    network = ipaddress.IPv4Network(network_info['network_range'], strict=False)
    
    # Find next available IP (skip gateway and broadcast)
    for ip in network.hosts():
        if str(ip) not in allocated_ips and str(ip) != network_info['gateway_ip']:
            return str(ip)
    
    raise ValueError(f"No available IP addresses in network {network_name}")

def configure_dns_mode(self, cluster_name: str, network_config: dict) -> dict:
    """Configure DNS based on the specified mode.
    
    WARNING: Non-isolated DNS modes require host system changes and are disabled by default.
    """
    dns_mode = network_config.get('dns_mode', 'isolated')
    dns_config = {'dns_servers': network_config.get('dns_servers', ['8.8.8.8', '1.1.1.1'])}
    
    if dns_mode == 'isolated':
        # Default isolated mode - no changes needed
        self.logger.info(f"Using isolated DNS mode for {cluster_name} (no host changes required)")
        return dns_config
    
    elif dns_mode == 'shared_dns':
        # Use host system DNS for cross-cluster resolution
        self.logger.info(f"Shared DNS mode requested for {cluster_name}")
        dns_config['dns_servers'] = ['192.168.122.1']  # libvirt default bridge
        
        # Attempt host DNS integration (may fail if disabled)
        if self._configure_host_dns_integration(cluster_name, network_config):
            self.logger.info(f"Host DNS integration successful for {cluster_name}")
        else:
            self.logger.warning(f"Host DNS integration failed for {cluster_name}, falling back to isolated mode")
            dns_config['dns_servers'] = network_config.get('dns_servers', ['8.8.8.8', '1.1.1.1'])
        
    elif dns_mode == 'routed':
        # Enable routing between cluster networks
        self.logger.info(f"Routed DNS mode requested for {cluster_name}")
        dns_config['dns_servers'] = ['192.168.122.1']
        
        # Attempt to enable cross-cluster routing (may fail if disabled)
        if self._enable_cluster_routing(cluster_name, network_config):
            self.logger.info(f"Cross-cluster routing enabled for {cluster_name}")
        else:
            self.logger.warning(f"Cross-cluster routing failed for {cluster_name}, falling back to isolated mode")
            dns_config['dns_servers'] = network_config.get('dns_servers', ['8.8.8.8', '1.1.1.1'])
        
    elif dns_mode == 'service_discovery':
        # Configure external service discovery
        self.logger.info(f"Service discovery mode requested for {cluster_name}")
        service_config = network_config.get('service_discovery', {})
        consul_ip = service_config.get('address', '192.168.122.1:8600').split(':')[0]
        dns_config['dns_servers'] = [consul_ip]
        
        # Attempt to configure service discovery (may fail if disabled)
        if self._configure_service_discovery(cluster_name, service_config):
            self.logger.info(f"Service discovery configured for {cluster_name}")
        else:
            self.logger.warning(f"Service discovery configuration failed for {cluster_name}, falling back to isolated mode")
            dns_config['dns_servers'] = network_config.get('dns_servers', ['8.8.8.8', '1.1.1.1'])
    
    return dns_config

def _configure_service_discovery(self, cluster_name: str, service_config: dict) -> bool:
    """Configure external service discovery for the cluster.
    
    WARNING: This method modifies host system configuration and is disabled by default.
    To enable, set host_configuration.network.enable_service_discovery: true
    """
    # Check if host changes are enabled
    if not self._is_host_changes_enabled('service_discovery'):
        self.logger.warning(
            f"Service discovery requested for {cluster_name} but host changes are disabled. "
            f"To enable service discovery, add to your configuration:\n"
            f"host_configuration:\n"
            f"  network:\n"
            f"    enable_service_discovery: true\n"
            f"    require_confirmation: true\n\n"
            f"Manual steps required:\n"
            f"1. Install and configure Consul/etcd service discovery\n"
            f"2. Configure cluster to register with service discovery\n"
            f"3. Update DNS to point to service discovery service"
        )
        return False
    
    # Require confirmation if enabled
    if not self._confirm_host_changes(f"Configure service discovery for {cluster_name}"):
        self.logger.info(f"Service discovery configuration cancelled for {cluster_name}")
        return False
    
    try:
        # This is a placeholder for service discovery configuration
        # In a real implementation, this would configure Consul/etcd integration
        service_type = service_config.get('type', 'consul')
        service_address = service_config.get('address', '192.168.122.1:8600')
        
        self.logger.info(f"Configuring {service_type} service discovery for {cluster_name} at {service_address}")
        
        # Placeholder for actual service discovery configuration
        # This would typically involve:
        # 1. Installing service discovery client
        # 2. Configuring service registration
        # 3. Setting up health checks
        # 4. Configuring DNS integration
        
        self.logger.info(f"Service discovery configured for {cluster_name}")
        return True
        
    except Exception as e:
        self.logger.error(f"Failed to configure service discovery: {e}")
        return False

def _configure_host_dns_integration(self, cluster_name: str, network_config: dict):
    """Configure host system to resolve cluster domains.
    
    WARNING: This method modifies host system configuration and is disabled by default.
    To enable, set host_configuration.network.enable_host_dns_integration: true
    """
    # Check if host changes are enabled
    if not self._is_host_changes_enabled('host_dns_integration'):
        self.logger.warning(
            f"Host DNS integration requested for {cluster_name} but host changes are disabled. "
            f"To enable host DNS integration, add to your configuration:\n"
            f"host_configuration:\n"
            f"  network:\n"
            f"    enable_host_dns_integration: true\n"
            f"    dnsmasq_config_path: \"/etc/dnsmasq.d\"\n"
            f"    require_confirmation: true\n\n"
            f"Manual steps required:\n"
            f"1. Create dnsmasq config: /etc/dnsmasq.d/{cluster_name}.conf\n"
            f"2. Add cluster domain resolution rules\n"
            f"3. Restart dnsmasq service: sudo systemctl restart dnsmasq"
        )
        return False
    
    # Require confirmation if enabled
    if not self._confirm_host_changes(f"Configure host DNS integration for {cluster_name}"):
        self.logger.info(f"Host DNS integration cancelled for {cluster_name}")
        return False
    
    try:
        # Add dnsmasq configuration for cluster domain
        domain = f"{cluster_name}.local"
        network_range = network_config['network_range']
        
        dnsmasq_config = f"""
# Added by ai-how for cluster {cluster_name}
server=/{domain}/192.168.100.1
address=/{domain}/{network_config['gateway_ip']}
"""
        
        config_file = f"/etc/dnsmasq.d/{cluster_name}.conf"
        self.logger.info(f"Configure host DNS for {cluster_name} at {config_file}")
        
        # Write configuration and restart dnsmasq
        with open(config_file, 'w') as f:
            f.write(dnsmasq_config)
        
        # Restart dnsmasq service
        import subprocess
        subprocess.run(['systemctl', 'restart', 'dnsmasq'], check=True)
        
        self.logger.info(f"Host DNS integration configured for {cluster_name}")
        return True
        
    except Exception as e:
        self.logger.error(f"Failed to configure host DNS integration: {e}")
        return False

def _enable_cluster_routing(self, cluster_name: str, network_config: dict):
    """Enable IP forwarding and routing between cluster networks.
    
    WARNING: This method modifies host system configuration and is disabled by default.
    To enable, set host_configuration.network.enable_cross_cluster_routing: true
    """
    # Check if host changes are enabled
    if not self._is_host_changes_enabled('cross_cluster_routing'):
        self.logger.warning(
            f"Cross-cluster routing requested for {cluster_name} but host changes are disabled. "
            f"To enable routing between clusters, add to your configuration:\n"
            f"host_configuration:\n"
            f"  network:\n"
            f"    enable_cross_cluster_routing: true\n"
            f"    require_confirmation: true\n\n"
            f"Manual steps required:\n"
            f"1. Enable IP forwarding: sudo sysctl -w net.ipv4.ip_forward=1\n"
            f"2. Add iptables rules for bridge {network_config.get('bridge_name', f'br-{cluster_name}')}\n"
            f"3. Make IP forwarding permanent: echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf"
        )
        return False
    
    # Require confirmation if enabled
    if not self._confirm_host_changes(f"Enable cross-cluster routing for {cluster_name}"):
        self.logger.info(f"Cross-cluster routing cancelled for {cluster_name}")
        return False
    
    try:
        import subprocess
        
        network_range = network_config['network_range']
        bridge_name = network_config.get('bridge_name', f"br-{cluster_name}")
        
        # Enable IP forwarding
        subprocess.run(['sysctl', '-w', 'net.ipv4.ip_forward=1'], check=True)
        
        # Add iptables rules for cross-cluster communication
        iptables_rules = [
            f"iptables -I FORWARD -i {bridge_name} -j ACCEPT",
            f"iptables -I FORWARD -o {bridge_name} -j ACCEPT",
        ]
        
        for rule in iptables_rules:
            subprocess.run(rule.split(), check=True)
            
        self.logger.info(f"Enabled routing for cluster {cluster_name}")
        return True
        
    except Exception as e:
        self.logger.error(f"Failed to enable cross-cluster routing: {e}")
        return False
```

#### 4.4 Volume Creation and Management (**Libvirt-Native Implementation**)

```python
# ai_how/vm_management/volume_manager.py
def create_cluster_pool(self, cluster_name: str, pool_path: Path, base_image_path: Path) -> str:
    """Create storage pool using libvirt APIs - no manual directory creation."""
    pool_name = f"{cluster_name}-pool"
    cluster_pool_path = pool_path / cluster_name
    
    # Generate pool XML (libvirt will create the directory)
    pool_xml = self._generate_pool_xml(pool_name, cluster_pool_path)
    
    # Create storage pool using libvirt APIs
    with self.client.get_connection() as conn:
        pool = conn.storagePoolDefineXML(pool_xml, 0)
        pool.build(0)  # Creates directory with proper permissions automatically
        pool.create(0)
        pool.setAutostart(1)
    
    # Create base image volume in pool using libvirt stream API
    base_volume_name = f"{cluster_name}-base.qcow2"
    if not self._volume_exists_in_pool(pool_name, base_volume_name):
        self._create_base_volume_from_image(pool_name, base_volume_name, base_image_path)
    
    return pool_name

def _create_base_volume_from_image(self, pool_name: str, volume_name: str, 
                                  source_image_path: Path) -> None:
    """Create base volume from image using libvirt stream API."""
    with self.client.get_connection() as conn:
        pool = conn.storagePoolLookupByName(pool_name)
        
        # Get source image info using qemu-img
        cmd = ["qemu-img", "info", "--output=json", str(source_image_path)]
        result = run_subprocess_with_logging(cmd, self.logger, check=True)
        image_info = json.loads(result.stdout)
        
        # Create volume with proper XML
        volume_xml = f"""
<volume type="file">
  <name>{volume_name}</name>
  <capacity unit="bytes">{image_info['virtual-size']}</capacity>
  <target>
    <format type="{image_info['format']}"/>
  </target>
</volume>"""
        
        volume = pool.createXML(volume_xml, 0)
        
        # Upload data using libvirt stream API (secure, no direct file access)
        self._upload_volume_data(volume, source_image_path)

def _upload_volume_data(self, volume: libvirt.virStorageVol, source_path: Path) -> None:
    """Upload data to volume using libvirt stream API for secure transfers."""
    conn = volume.connect()
    stream = conn.newStream(0)
    
    volume_info = volume.info()
    capacity = volume_info[1]
    
    volume.upload(stream, 0, capacity, 0)
    
    # Upload in chunks
    with open(source_path, 'rb') as f:
        chunk_size = 1024 * 1024  # 1MB chunks
        while True:
            data = f.read(chunk_size)
            if not data:
                break
            stream.send(data)
    
    stream.finish()

def create_vm_volume(self, cluster_name: str, vm_name: str, 
                    size_gb: int, vm_type: str = "compute") -> str:
    """Create a COW volume for a VM in the cluster pool."""
    
    pool_name = f"{cluster_name}-pool"
    volume_name = f"{vm_name}.qcow2"
    base_volume_name = f"{cluster_name}-base.qcow2"
    
    with self.client.get_connection() as conn:
        pool = conn.storagePoolLookupByName(pool_name)
        pool_path = self._get_pool_path(pool)
        base_volume_path = pool_path / base_volume_name
        
        # Generate volume XML for copy-on-write with backing store
        volume_xml = self._generate_volume_xml(volume_name, size_gb, base_volume_path)
        
        # Create volume using libvirt API
        volume = pool.createXML(volume_xml, 0)
        volume_path = volume.path()
        
        self.logger.info(f"Created COW volume for {vm_name}: {volume_path}")
        return volume_path
```

### Phase 5: CLI Integration

#### 5.1 Enhanced CLI Commands

```python
# ai_how/cli.py
@app.command()
def hpc(
    ctx: typer.Context,
    action: str = typer.Argument(..., help="Action: start, stop, status, destroy"),
    config_file: Optional[Path] = typer.Option(None, "--config", "-c", 
                                               help="Cluster configuration file"),
    force: bool = typer.Option(False, "--force", "-f", 
                               help="Force operation without confirmation")
):
    """Manage HPC cluster operations with volume management."""
    
    # Load configuration
    config = load_cluster_config(config_file or Path("cluster.yaml"))
    
    # Initialize managers
    state_manager = ClusterStateManager(Path("cluster_state.json"))
    hpc_manager = HPCClusterManager(config, state_manager)
    
    # Execute action with enhanced storage management and XML tracing
    if action == "start":
        success = hpc_manager.start_cluster()
        
        # Display XML trace summary
        trace_summary = hpc_manager.get_xml_trace_summary()
        console.print(f"[blue]XML trace folder: {trace_summary['trace_folder']}[/blue]")
        console.print(f"[blue]Total XML operations: {trace_summary['total_operations']} (
          {trace_summary['successful_operations']} successful, {trace_summary['failed_operations']} failed)[/blue]")
        
        if success:
            console.print("[green]Cluster started successfully![/green]")
            status = hpc_manager.get_cluster_status()
            display_cluster_status(status)
        else:
            console.print("[red]Failed to start cluster[/red]")
            console.print(f"[yellow]Check XML traces for debugging: {trace_summary['trace_folder']}[/yellow]")
            console.print(f"[yellow]Metadata file: {trace_summary['metadata_file']}[/yellow]")
            raise typer.Exit(1)
```

#### 5.2 Enhanced Status Display

```python
# ai_how/cli.py
def display_cluster_status(status: dict):
    """Display cluster status with storage information."""
    
    console.print(f"\n[bold]Cluster: {status['name']}[/bold]")
    console.print(f"Status: {status['status']}")
    console.print(f"Created: {status['created_at']}")
    console.print(f"Last Updated: {status['last_updated']}")
    
    # Network Information
    if status['network']:
        network = status['network']
        console.print(f"\n[bold]Virtual Network: {network['name']}[/bold]")
        console.print(f"Bridge: {network['bridge_name']}")
        console.print(f"Network Range: {network['network_range']}")
        console.print(f"Gateway: {network['gateway_ip']}")
        console.print(f"Status: {'Active' if network['is_active'] else 'Inactive'}")
        
        # Show allocated IPs
        if network['allocated_ips']:
            console.print(f"Allocated IPs: {len(network['allocated_ips'])}")
            for vm_name, ip in network['allocated_ips'].items():
                console.print(f"  {vm_name}: {ip}")
    
    # Storage Pool Information
    if status['storage_pool']:
        pool = status['storage_pool']
        console.print(f"\n[bold]Storage Pool: {pool['name']}[/bold]")
        console.print(f"Path: {pool['path']}")
        console.print(f"Capacity: {pool['capacity_gb']:.1f}GB")
        console.print(f"Allocated: {pool['allocation_gb']:.1f}GB")
        console.print(f"Available: {pool['available_gb']:.1f}GB")
    
    # VM Information
    if status['vms']:
        table = Table(title="Virtual Machines")
        table.add_column("Name", style="cyan")
        table.add_column("Type", style="blue")
        table.add_column("State", style="green")
        table.add_column("IP Address", style="yellow")
        table.add_column("CPU", style="blue")
        table.add_column("Memory", style="magenta")
        table.add_column("Volume", style="cyan")
        
        for vm in status['vms']:
            table.add_row(
                vm['name'],
                vm['vm_type'],
                vm['state'].value,
                vm['ip_address'] or "N/A",
                str(vm['cpu_cores']),
                f"{vm['memory_mb']}MB",
                Path(vm['volume_path']).name
            )
        
        console.print(table)
    else:
        console.print("[yellow]No VMs found in cluster[/yellow]")
```

### Phase 6: Error Handling and Rollback

#### 6.1 Enhanced Rollback System

```python
# ai_how/vm_management/hpc_manager.py
class RollbackManager:
    """Manages rollback operations including volume and network cleanup."""
    
    def __init__(self, volume_manager: VolumeManager, network_manager: NetworkManager):
        self.rollback_stack = []
        self.volume_manager = volume_manager
        self.network_manager = network_manager
    
    def add_vm_volume_rollback(self, cluster_name: str, vm_name: str):
        """Add VM volume destruction to rollback stack."""
        self.add_rollback_action(
            self.volume_manager.destroy_vm_volume,
            cluster_name, vm_name
        )
    
    def add_pool_rollback(self, cluster_name: str):
        """Add storage pool destruction to rollback stack."""
        self.add_rollback_action(
            self.volume_manager.destroy_cluster_pool,
            cluster_name, force=True
        )
    
    def add_network_rollback(self, cluster_name: str):
        """Add network destruction to rollback stack."""
        self.add_rollback_action(
            self.network_manager.destroy_cluster_network,
            cluster_name, force=True
        )
    
    def add_ip_release_rollback(self, cluster_name: str, vm_name: str):
        """Add IP address release to rollback stack."""
        self.add_rollback_action(
            self.network_manager.release_ip_address,
            cluster_name, vm_name
        )
    
    def add_rollback_action(self, action: callable, *args, **kwargs):
        """Add rollback action to stack."""
        self.rollback_stack.append((action, args, kwargs))
    
    def execute_rollback(self):
        """Execute all rollback actions in reverse order."""
        while self.rollback_stack:
            action, args, kwargs = self.rollback_stack.pop()
            try:
                action(*args, **kwargs)
            except Exception as e:
                console.print(f"[yellow]Warning: Rollback action failed: {e}[/yellow]")
```

## Key Benefits of Libvirt-Native Volume and Network Management Approach

### 1. **Eliminates Permission Issues**

**Problem Solved**: Direct file operations cause permission denied errors like:

```text
[Errno 13] Permission denied: '/var/lib/libvirt/images/hpc-cluster'
```

**Solution**: Libvirt-native approach eliminates these issues by:

- **No Manual Directory Creation**: `pool.build(0)` creates directories with proper permissions
- **Automatic Permission Management**: libvirt sets correct ownership (libvirt-qemu:libvirt-qemu)
- **SELinux Context Handling**: libvirt automatically applies correct SELinux contexts
- **Stream-based Transfers**: Uses `libvirt.virStream` API for secure data uploads
- **No Direct File Access**: All operations go through libvirt APIs with proper access control

### 2. **Native libvirt Integration**

- Uses libvirt's native storage pool, volume, and network APIs exclusively
- Better integration with libvirt security and permissions framework
- Supports multiple storage backends (dir, LVM, ZFS, etc.) and network types
- Enhanced monitoring and statistics for both storage and networking
- Consistent with libvirt security model and access controls

### 3. **Improved Resource Management**

- **Pool-level Management**: One storage pool per cluster for organized storage
- **Volume-level Isolation**: Each VM gets its own volume within the cluster pool
- **Network-level Isolation**: Isolated virtual network per cluster with dedicated bridge
- **Copy-on-Write Efficiency**: COW volumes minimize storage overhead
- **Centralized Monitoring**: Pool-level space and network monitoring and management
- **IP Address Management**: Automatic IP allocation and DHCP management per cluster

### 4. **Enhanced Features**

- **Snapshots**: Native snapshot support for VMs
- **Migration**: Volume migration between hosts
- **Network Isolation**: Complete network isolation between clusters
- **DHCP Management**: Automatic IP allocation and DNS resolution
- **Monitoring**: Detailed volume, pool, and network statistics
- **Security**: Proper SELinux contexts, permissions, and network filtering

### 5. **Better Cluster Organization**

```text
Storage Layout:
/var/lib/libvirt/images/
├── hpc-cluster-1-pool/
│   ├── hpc-cluster-1-base.qcow2     # Base image in pool
│   ├── controller-01.qcow2          # COW volume for controller
│   ├── compute-01.qcow2             # COW volume for compute node
│   ├── compute-02.qcow2             # COW volume for compute node
│   └── ...
└── hpc-cluster-2-pool/
    ├── hpc-cluster-2-base.qcow2
    ├── controller-01.qcow2
    └── ...

Network Layout:
Virtual Networks:
├── hpc-cluster-1-network (192.168.100.0/24)
│   ├── Bridge: br-hpc-cluster-1
│   ├── Gateway: 192.168.100.1
│   ├── DHCP Range: 192.168.100.10 - 192.168.100.254
│   └── VMs: controller-01 (192.168.100.10), compute-01 (192.168.100.11), ...
└── hpc-cluster-2-network (192.168.101.0/24)
    ├── Bridge: br-hpc-cluster-2
    ├── Gateway: 192.168.101.1
    ├── DHCP Range: 192.168.101.10 - 192.168.101.254
    └── VMs: controller-01 (192.168.101.10), compute-01 (192.168.101.11), ...
```

### 6. **Advanced Storage Operations**

- **Volume Resize**: Dynamic volume resizing
- **Volume Cloning**: Fast volume cloning for rapid provisioning
- **Storage Migration**: Move volumes between storage backends
- **Backup Integration**: Native backup and restore capabilities
- **Stream-based Operations**: Secure data transfers using libvirt stream API

### 7. **Advanced Network Operations**

- **Network Isolation**: Complete layer 2 isolation between clusters
- **DHCP Reservations**: Static IP assignments for specific VMs
- **DNS Integration**: Local DNS resolution within cluster networks
- **Network Monitoring**: Traffic statistics and connection tracking
- **Network Migration**: Move networks between hosts
- **VLAN Support**: Optional VLAN tagging for additional isolation

## DNS Architecture Options

### Option 1: Complete Isolation (Current Design)

**Use Case**: Maximum security, no cross-cluster communication needed

```text
Cluster 1 Network (192.168.100.0/24)
├── Internal DNS: *.hpc-cluster-1.local
├── External DNS: 8.8.8.8, 1.1.1.1
└── No cross-cluster resolution

Cluster 2 Network (192.168.101.0/24)  
├── Internal DNS: *.hpc-cluster-2.local
├── External DNS: 8.8.8.8, 1.1.1.1
└── No cross-cluster resolution
```

**Pros**: Maximum security, simple configuration
**Cons**: No inter-cluster communication

### Option 2: Shared DNS Server with Host Bridge

**Use Case**: Controlled cross-cluster communication

```text
Host System (DNS Server: dnsmasq on 192.168.122.1)
├── Cluster 1: Routes to 192.168.122.1 for external DNS
├── Cluster 2: Routes to 192.168.122.1 for external DNS
└── Host DNS knows about all cluster domains

Enhanced Network Template:
<network>
  <name>{{ cluster_name }}-network</name>
  <bridge name="{{ bridge_name }}" stp="on" delay="0"/>
  <domain name="{{ cluster_name }}.local"/>
  <ip address="{{ gateway_ip }}" netmask="{{ netmask }}">
    <dhcp>
      <range start="{{ dhcp_start }}" end="{{ dhcp_end }}"/>
    </dhcp>
  </ip>
  <dns>
    <!-- Point to host system DNS that knows all clusters -->
    <forwarder addr="192.168.122.1"/>
    <host ip="{{ gateway_ip }}">
      <hostname>{{ cluster_name }}-gateway</hostname>
    </host>
  </dns>
</network>
```

### Option 3: Cross-Cluster Network with Routing

**Use Case**: Full inter-cluster communication

```text
Host System with IP Forwarding
├── Cluster 1: 192.168.100.0/24 → Bridge br-cluster-1
├── Cluster 2: 192.168.101.0/24 → Bridge br-cluster-2  
└── Routing rules: Allow 192.168.100.0/24 ↔ 192.168.101.0/24

Enhanced Network Manager:
def enable_cross_cluster_routing(self, cluster_names: list[str]) -> bool:
    """Enable routing between specified clusters."""
    # Add iptables FORWARD rules
    # Configure bridge routing
    # Update DNS to resolve cross-cluster names
```

### Option 4: Federated DNS with Consul/etcd

**Use Case**: Service discovery across clusters

```text
External Service Discovery (Consul/etcd)
├── Cluster 1 registers: controller-01.cluster-1.service.consul
├── Cluster 2 registers: controller-01.cluster-2.service.consul
└── All clusters query: consul for cross-cluster services

Network Configuration:
dns_servers:
  - "192.168.122.1"  # Host running Consul DNS
  - "8.8.8.8"        # Fallback
```

## DNS Architecture Comparison

| DNS Mode | Cross-Cluster Resolution | Security Level | Complexity | Use Case |
|----------|-------------------------|----------------|------------|----------|
| **Isolated** | ❌ None | 🟢 Maximum | 🟢 Simple | Production clusters with no inter-cluster communication |
| **Shared DNS** | ✅ Via host DNS | 🟡 High | 🟡 Medium | Controlled cross-cluster name resolution |
| **Routed** | ✅ Full network access | 🟡 Medium | 🔴 Complex | Development environments, federated clusters |
| **Service Discovery** | ✅ Service-based | 🟢 High | 🔴 Complex | Microservices, dynamic service discovery |

### Implementation Decision Matrix

**For Most HPC Use Cases → Recommend: `isolated` (default)**

- HPC clusters typically don't need cross-cluster communication
- Maximum security and resource isolation
- Simple configuration and management

**For Development/Testing → Consider: `shared_dns`**  

- Allows name resolution for debugging across clusters
- Moderate security with controlled access
- Easier troubleshooting and monitoring

**For Federated Computing → Consider: `routed`**

- Full communication between clusters
- Useful for distributed computing workflows
- Requires careful firewall management

## Configuration Integration

### Enhanced Cluster Configuration

```yaml
# cluster.yaml (Simplified Configuration with Per-VM GPU Assignment)
global: {}

cluster:
  name: "hpc-cluster"
  storage:
    pool_path: "/var/lib/libvirt/images"
    pool_type: "dir"  # dir, lvm, zfs, etc.
    base_image: "/var/lib/libvirt/images/hpc-base.qcow2"
  
      # Hardware acceleration configuration (x86_64 only)
  hardware:
    acceleration:
      enable_kvm: true           # Enable KVM hardware virtualization
      enable_nested: false      # Enable nested virtualization
      cpu_model: "host-passthrough"  # host, host-passthrough, host-model, qemu64
      cpu_features:              # Additional CPU features
        - "+vmx"                 # Intel VT-x virtualization
        - "+svm"                 # AMD-V virtualization
        - "+sse4.1"              # SSE 4.1 instructions
        - "+sse4.2"              # SSE 4.2 instructions
        - "+avx"                 # AVX instructions (if supported)
        - "+avx2"                # AVX2 instructions (if supported)
      numa_topology: null       # NUMA topology (auto-detect if null)
      cpu_topology:             # CPU topology settings
        sockets: 1
        cores: 4
        threads: 1
      performance:
        enable_hugepages: false  # Use hugepages for better memory performance  
        hugepage_size: "2M"      # 2M or 1G hugepages
        cpu_pinning: false       # Pin vCPUs to physical CPUs
        memory_backing: "default" # default, hugepages, memfd
  
network:
  network_range: "192.168.100.0/24"  # Cluster network range
  bridge_name: "br-hpc-cluster"      # Bridge name (auto-generated if not specified)
  gateway_ip: "192.168.100.1"        # Gateway IP (auto-calculated if not specified)
  dhcp_start: "192.168.100.10"       # DHCP range start
  dhcp_end: "192.168.100.254"        # DHCP range end
  dns_mode: "isolated"               # DNS architecture mode
  dns_servers:                       # DNS forwarders
    - "8.8.8.8"
    - "1.1.1.1"
  static_leases:                     # Optional static IP assignments
    controller-01: "192.168.100.10"
    compute-01: "192.168.100.11"
    compute-02: "192.168.100.12"

# DNS Architecture Configuration Options
# dns_mode: "isolated"      - Complete isolation (default)
# dns_mode: "shared_dns"    - Use host system DNS for cross-cluster
# dns_mode: "routed"        - Enable routing between clusters  
# dns_mode: "service_discovery" - Use external service discovery

# For shared_dns mode:
# dns_servers: ["192.168.122.1"]  # Host system DNS

# For service_discovery mode:
# service_discovery:
#   type: "consul"
#   address: "192.168.122.1:8600"
#   domain: "service.consul"

# Host Configuration (NEW - Controls Host System Modifications)
# WARNING: These settings control whether the system can modify the host machine
# Default: All host changes are DISABLED for production safety
host_configuration:
  # Global host change settings
  require_confirmation: true        # Require user confirmation for host changes
  enable_audit_logging: true       # Log all host change attempts
  rollback_on_failure: true        # Attempt rollback if host changes fail
  
  # Network-related host changes
  network:
    enable_host_dns_integration: false      # Default: false (no dnsmasq configs)
    enable_cross_cluster_routing: false     # Default: false (no iptables/sysctl changes)
    enable_service_discovery: false         # Default: false (no external service config)
    dnsmasq_config_path: "/etc/dnsmasq.d"  # Path for dnsmasq configs (if enabled)
    
    # Advanced network options (if enabled)
    cross_cluster_routing:
      enable_ip_forwarding: true           # Modify net.ipv4.ip_forward
      add_iptables_rules: true            # Add FORWARD rules for bridges
      permanent_changes: false            # Make changes persistent across reboots
    
    # Service discovery configuration (if enabled)
    service_discovery:
      consul_path: "/usr/local/bin/consul"  # Path to Consul binary
      etcd_path: "/usr/local/bin/etcd"      # Path to etcd binary
      config_dir: "/etc/consul.d"           # Configuration directory
  
  # System-related host changes
  system:
    enable_hugepage_config: false          # Default: false (no hugepage setup)
    enable_numa_config: false              # Default: false (no NUMA tuning)
    enable_kernel_module_config: false     # Default: false (no module loading)
    
    # Performance tuning (if enabled)
    performance:
      hugepage_size: "2M"                  # Hugepage size to configure
      numa_memory_policy: "interleave"     # NUMA memory allocation policy
      cpu_governor: "performance"          # CPU frequency governor
  
  # Security and compliance
  security:
    require_root_access: true              # Require root for host changes
    validate_changes: true                 # Validate changes before applying
    backup_configs: true                   # Backup configs before modification
    max_rollback_attempts: 3              # Maximum rollback attempts
  
  # Development/testing overrides
  development_mode: false                  # Enable all features for development
  skip_confirmation: false                 # Skip confirmation prompts
  allow_destructive_changes: false         # Allow potentially destructive changes
  
controller:
  count: 1
  memory_mb: 4096
  cpu_cores: 2
  disk_size_gb: 50

compute_nodes:
  - name: "compute-01"
    memory_mb: 8192
    cpu_cores: 4
    disk_size_gb: 100
    # Per-VM PCIe passthrough configuration
    pcie_passthrough:
      enabled: true
      devices:
        - pci_address: "0000:65:00.0"  # A100 GPU
          device_type: "gpu"
          vendor_id: "10de"           # NVIDIA vendor ID
          device_id: "2684"           # A100 device ID
          iommu_group: 1
  - name: "compute-02"
    memory_mb: 8192
    cpu_cores: 4
    disk_size_gb: 100
    # Each VM gets its own GPU assignment
    pcie_passthrough:
      enabled: true
      devices:
        - pci_address: "0000:ca:00.0"  # RTX 6000 GPU
          device_type: "gpu"
          vendor_id: "10de"           # NVIDIA vendor ID
          device_id: "1e36"           # RTX 6000 device ID
          iommu_group: 4
```

### Host Configuration Management (NEW - Production Safety Feature)

The HPC VM Management system now includes comprehensive host configuration management
that **DISABLES all host system modifications by default** for production safety.
This addresses the security concerns identified in the Host Machine Reconfiguration Analysis.

#### **Key Safety Features**

1. **Default Disabled**: All host modification features are disabled by default
2. **Explicit Enablement**: Users must explicitly enable each feature they need
3. **Confirmation Required**: User confirmation required for all host changes
4. **Audit Logging**: Complete audit trail of all host change attempts
5. **Graceful Fallback**: System falls back to isolated mode if host changes fail
6. **Clear Warnings**: Detailed warning messages with manual instructions

#### **Host Configuration Options**

```yaml
# Example: Enable cross-cluster routing (requires host changes)
host_configuration:
  network:
    enable_cross_cluster_routing: true
    require_confirmation: true
  
# Example: Enable host DNS integration (requires dnsmasq changes)
host_configuration:
  network:
    enable_host_dns_integration: true
    dnsmasq_config_path: "/etc/dnsmasq.d"
    require_confirmation: true

# Example: Development mode (enables all features - DANGEROUS for production)
host_configuration:
  development_mode: true
  skip_confirmation: true
  allow_destructive_changes: true
```

#### **What Happens When Host Changes Are Disabled**

1. **Cross-Cluster Routing**: System prints warning with manual iptables/sysctl instructions
2. **Host DNS Integration**: System prints warning with manual dnsmasq configuration steps
3. **Service Discovery**: System prints warning with manual service discovery setup steps
4. **Fallback Behavior**: All features fall back to isolated mode (no cross-cluster communication)

#### **Manual Configuration Instructions**

When host changes are disabled, the system provides detailed manual instructions:

```bash
# Example warning message for cross-cluster routing:
WARNING: Cross-cluster routing requested for hpc-cluster but host changes are disabled.
To enable routing between clusters, add to your configuration:
host_configuration:
  network:
    enable_cross_cluster_routing: true
    require_confirmation: true

Manual steps required:
1. Enable IP forwarding: sudo sysctl -w net.ipv4.ip_forward=1
2. Add iptables rules for bridge br-hpc-cluster
3. Make IP forwarding permanent: echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
```

#### **Production vs Development Modes**

| Mode | Host Changes | Confirmation | Use Case |
|------|--------------|--------------|----------|
| **Production (Default)** | ❌ Disabled | ✅ Required | Secure production deployments |
| **Development** | ✅ Enabled | ⚠️ Optional | Development and testing environments |
| **Custom** | ⚠️ Selective | ✅ Required | Production with specific features enabled |

#### **Security Benefits**

- **No Surprise Changes**: System cannot modify host without explicit permission
- **Audit Trail**: All change attempts are logged for compliance
- **Graceful Degradation**: Features fail safely without breaking the cluster
- **User Control**: Users decide exactly what host changes are allowed
- **Production Safe**: Default configuration is safe for production environments

## Configuration Schema (Future Versioning Provision)

### Current Schema (Development Version)

The current schema is in development and may change. Once stabilized, we will implement formal versioning and migration support.

```python
# ai_how/schemas/future_versioning.py (Placeholder for future implementation)
"""
Future versioning system will include:
- Schema version tracking
- Backward compatibility support  
- Automatic migration utilities
- Configuration validation and upgrade tools

Implementation planned for v1.0 stable release.
"""
```

### Simplified JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "HPC Cluster Configuration Schema (Development)",
  "type": "object",
  "required": ["cluster"],
  "properties": {
    "cluster": {
      "type": "object",
      "required": ["name"],
      "properties": {
        "name": {
          "type": "string",
          "pattern": "^[a-zA-Z0-9-]+$"
        },
        "storage": {
          "type": "object",
          "properties": {
            "pool_path": {"type": "string"},
            "pool_type": {
              "type": "string", 
              "enum": ["dir", "lvm", "zfs", "nfs", "iscsi"]
            },
            "base_image": {"type": "string"}
          }
        },
        "hardware": {
          "type": "object",
          "properties": {
            "acceleration": {
              "type": "object",
              "properties": {
                "enable_kvm": {"type": "boolean", "default": true},
                "enable_nested": {"type": "boolean", "default": false},
                "cpu_model": {
                  "type": "string",
                  "enum": ["host", "host-passthrough", "host-model", "qemu64"],
                  "default": "host-passthrough"
                },
                "cpu_features": {
                  "type": "array",
                  "items": {"type": "string"},
                  "description": "Additional CPU features to enable/disable"
                },
                "numa_topology": {
                  "oneOf": [
                    {"type": "null"},
                    {
                      "type": "object",
                      "properties": {
                        "nodes": {"type": "integer", "minimum": 1},
                        "memory_per_node": {"type": "string"}
                      }
                    }
                  ]
                },
                "cpu_topology": {
                  "type": "object",
                  "properties": {
                    "sockets": {"type": "integer", "minimum": 1, "default": 1},
                    "cores": {"type": "integer", "minimum": 1, "default": 4},
                    "threads": {"type": "integer", "minimum": 1, "default": 1}
                  }
                },
                "performance": {
                  "type": "object",
                  "properties": {
                    "enable_hugepages": {"type": "boolean", "default": false},
                    "hugepage_size": {
                      "type": "string", 
                      "enum": ["2M", "1G"],
                      "default": "2M"
                    },
                    "cpu_pinning": {"type": "boolean", "default": false},
                    "memory_backing": {
                      "type": "string",
                      "enum": ["default", "hugepages", "memfd"],
                      "default": "default"
                    }
                  }
                }
              }
            },
            "pcie_passthrough": {
              "type": "object",
              "properties": {
                "enabled": {"type": "boolean", "default": false},
                "exclusive_mode": {"type": "boolean", "default": true},
                "devices": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "pci_address": {"type": "string", "pattern": "^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\\.[0-9a-fA-F]$"},
                      "device_type": {"type": "string", "enum": ["gpu", "network", "storage", "other"]},
                      "vendor_id": {"type": "string", "pattern": "^[0-9a-fA-F]{4}$"},
                      "device_id": {"type": "string", "pattern": "^[0-9a-fA-F]{4}$"},
                      "assigned_to": {"type": "string", "description": "VM name to assign this device"},
                      "iommu_group": {"type": "integer", "minimum": 0}
                    },
                    "required": ["pci_address", "device_type", "assigned_to"]
                  }
                }
              }
            }
          }
        }
      }
    },
    "host_configuration": {
      "type": "object",
      "description": "Controls whether the system can modify the host machine. Default: all disabled for production safety.",
      "properties": {
        "require_confirmation": {
          "type": "boolean",
          "default": true,
          "description": "Require user confirmation for host changes"
        },
        "enable_audit_logging": {
          "type": "boolean",
          "default": true,
          "description": "Log all host change attempts"
        },
        "rollback_on_failure": {
          "type": "boolean",
          "default": true,
          "description": "Attempt rollback if host changes fail"
        },
        "network": {
          "type": "object",
          "properties": {
            "enable_host_dns_integration": {
              "type": "boolean",
              "default": false,
              "description": "Allow modification of host DNS configuration (dnsmasq)"
            },
            "enable_cross_cluster_routing": {
              "type": "boolean",
              "default": false,
              "description": "Allow modification of host routing (iptables, sysctl)"
            },
            "enable_service_discovery": {
              "type": "boolean",
              "default": false,
              "description": "Allow configuration of external service discovery"
            },
            "dnsmasq_config_path": {
              "type": "string",
              "default": "/etc/dnsmasq.d",
              "description": "Path for dnsmasq configuration files"
            }
          }
        },
        "system": {
          "type": "object",
          "properties": {
            "enable_hugepage_config": {
              "type": "boolean",
              "default": false,
              "description": "Allow modification of hugepage configuration"
            },
            "enable_numa_config": {
              "type": "boolean",
              "default": false,
              "description": "Allow modification of NUMA configuration"
            },
            "enable_kernel_module_config": {
              "type": "boolean",
              "default": false,
              "description": "Allow loading/unloading of kernel modules"
            }
          }
        },
        "development_mode": {
          "type": "boolean",
          "default": false,
          "description": "Enable all features for development (DANGEROUS for production)"
        }
      }
    }
  }
}
```

## Dependencies

### Python Dependencies (Updated)

```toml
[dependencies]
libvirt-python = "^9.0.0"
jinja2 = "^3.1.0"
```

### System Dependencies

**QEMU/KVM Requirements:**

- **qemu-system-x86-64** (version 7.2+ for Q35 support)
- **libvirt-daemon-system** (version 8.0+)
- **bridge-utils** (for network management)
- **python3-libvirt** (system package)

**Q35 Platform Requirements:**

- **Modern QEMU**: Version 7.2 or later with Q35 chipset support
- **Q35 Machine Types**: pc-q35-7.2, pc-q35-8.0, or pc-q35-9.0
- **PCIe Support**: Native PCIe root complex for passthrough
- **IOMMU Support**: Intel VT-d or AMD-Vi for device isolation

**Hardware Requirements for GPU Passthrough:**

- **IOMMU Enabled**: `intel_iommu=on` or `amd_iommu=on` in kernel parameters
- **VT-x/AMD-V**: Hardware virtualization support
- **PCIe Devices**: Modern GPUs with IOMMU group isolation
- **UEFI BIOS**: VT-d/AMD-Vi enabled in firmware settings

**Validation Commands:**

```bash
# Check QEMU version and Q35 support
qemu-system-x86_64 -machine help | grep q35

# Verify IOMMU support
dmesg | grep -i iommu

# Check available machine types
qemu-system-x86_64 -machine \? | grep q35
```

## Security Considerations

### Enhanced Security with Volume and Network Management

- **Proper Permissions**: libvirt manages volume permissions automatically
- **SELinux Context**: Correct SELinux contexts for volumes and network bridges
- **Resource Isolation**: Pool-level quotas and limits, network-level isolation
- **Access Control**: libvirt's native access control mechanisms
- **Network Security**: Complete Layer 2 isolation between cluster networks
- **Firewall Integration**: iptables rules managed by libvirt for network filtering
- **MAC Address Management**: Controlled MAC address assignment for security

## Performance Optimizations

### Volume-Specific Optimizations

- **Parallel Volume Creation**: Create multiple VM volumes concurrently
- **Pool Pre-allocation**: Pre-allocate storage pools for better performance
- **Volume Caching**: Cache volume information for faster operations
- **Efficient COW**: Copy-on-write volumes minimize storage I/O

### Network-Specific Optimizations

- **Parallel Network Operations**: Create networks and allocate IPs concurrently
- **Bridge Pre-creation**: Pre-create network bridges for faster VM startup
- **DHCP Caching**: Cache DHCP lease information for quicker IP management
- **Network Statistics Caching**: Cache network statistics for performance monitoring

## Conclusion

The updated implementation plan with Q35 platform support, network and volume management provides significant advantages:

1. **Modern Platform**: Q35 chipset enables PCIe passthrough and advanced virtualization
2. **GPU Computing**: Native PCIe support for high-performance GPU workloads
3. **Better Integration**: Native libvirt storage and network management
4. **Enhanced Features**: Snapshots, migration, monitoring, network isolation
5. **Improved Organization**: Pool-per-cluster storage and network-per-cluster layout
6. **Advanced Operations**: Volume resize, cloning, backup, IP management, DHCP
7. **Better Security**: Proper permissions, SELinux contexts, and network isolation
8. **Complete Isolation**: Full network and storage isolation between clusters
9. **Future-Proof**: Q35 platform ready for emerging technologies

This approach aligns with libvirt best practices and provides a more robust,
scalable, and maintainable infrastructure solution for HPC cluster management.

The addition of network management alongside volume management creates completely
isolated cluster environments, each with their own dedicated virtual network,
storage pool, and resource management. This is ideal for production HPC cluster
deployments where security, isolation, and resource management are critical.

## Recent Updates Summary

### ✅ **Completed Updates**

#### **1. Q35 Platform Requirement (CRITICAL UPDATE)**

- **REQUIRED**: Q35 chipset (`pc-q35-8.0`) for all HPC VMs
- **REPLACED**: Older i440FX chipset (`pc-i440fx-2.9`) completely removed
- **ENFORCED**: Validation logic ensures Q35 for PCIe passthrough
- **BENEFITS**:
  - Native PCIe support for GPU passthrough
  - Advanced IOMMU support for device isolation
  - Modern interrupt handling (MSI/MSI-X)
  - SR-IOV support for network virtualization
  - Future-proof platform for emerging features

#### **2. Simplified Security Configuration**

- **Removed**: All security feature configuration options (`enable_smep`, `enable_smap`, `secure_boot`)
- **Simplified**: Hardware configuration now focuses only on performance optimizations
- **Updated**: XML templates no longer include security-related conditionals
- **Streamlined**: JSON schema simplified to remove security configuration sections

#### **2. XML Tracing System Integration**

- **Added**: Comprehensive XML tracing system (`XMLTracer` class)
- **Features**:
  - Unique trace file per operation with timestamp: `libvirt_trace_{cluster}_{operation}_{timestamp}.json`
  - Complete audit trail of all libvirt XML operations
  - Success/failure tracking with error messages
  - Performance analysis capabilities
- **Integration**: XML tracing integrated into all libvirt client operations
- **CLI Enhancement**: Trace file location displayed in CLI output for debugging

#### **3. Enhanced Debugging and Audit Capabilities**

- **Benefit**: Complete visibility into all XML definitions passed to libvirt
- **Debugging**: Failed operations now have detailed XML traces for troubleshooting
- **Reproducibility**: XML traces enable reproducible cluster deployments
- **Validation**: Generated XML can be validated against expectations

### **Key Configuration Changes**

**Before (Legacy i440FX - NOT SUPPORTED):**

```yaml
cluster:
  hardware:
    acceleration:
      performance: {...}
      security:
        enable_smep: true
        enable_smap: true  
        secure_boot: false
    # Machine type was pc-i440fx-2.9 (legacy)
```

**After (Modern Q35 - REQUIRED):**

```yaml
cluster:
  hardware:
    acceleration:
      performance:
        enable_hugepages: false
        hugepage_size: "2M"
        cpu_pinning: false
        memory_backing: "default"
    # Machine type is now pc-q35-8.0 (modern, required)
    # Q35 enables PCIe passthrough and modern features
```

**Machine Type Evolution:**

```xml
<!-- OLD: Legacy i440FX (NOT SUPPORTED) -->
<os>
  <type arch="x86_64" machine="pc-i440fx-2.9">hvm</type>
</os>

<!-- NEW: Modern Q35 (REQUIRED) -->
<os>
  <type arch="x86_64" machine="pc-q35-8.0">hvm</type>
</os>
```

### **XML Tracing Output Example**

Every cluster operation now generates a versioned trace folder:

```text
traces/
├── run_hpc-cluster_start_20241217_143052_123/
│   ├── 001_network_create_hpc-cluster-network_SUCCESS.xml
│   ├── 002_pool_define_hpc-cluster-pool_SUCCESS.xml
│   ├── 003_volume_create_controller-01_SUCCESS.xml
│   ├── 004_domain_define_controller-01_SUCCESS.xml
│   └── trace_metadata.json
├── run_hpc-cluster_stop_20241217_144501_456/
│   ├── 001_domain_destroy_controller-01_SUCCESS.xml
│   ├── 002_domain_destroy_compute-01_SUCCESS.xml
│   └── trace_metadata.json
└── run_gpu-cluster_destroy_20241217_145023_789/
    ├── 001_domain_destroy_gpu-compute-01_SUCCESS.xml
    ├── 002_volume_delete_gpu-compute-01_SUCCESS.xml
    ├── 003_pool_destroy_gpu-cluster-pool_SUCCESS.xml
    ├── 004_network_destroy_gpu-cluster-network_SUCCESS.xml
    └── trace_metadata.json
```

### **Benefits Achieved**

1. **🏗️ Modern Platform**: Q35 chipset enables PCIe passthrough and advanced features
2. **🎮 GPU Passthrough**: Native PCIe support for high-performance GPU computing
3. **🔧 Simplified Configuration**: Removed complexity around security features
4. **🐛 Enhanced Debugging**: Complete XML operation audit trail with individual files
5. **📊 Better Monitoring**: Detailed operation tracking and performance metrics
6. **🔍 Troubleshooting**: Easy identification of failed XML operations with specific error files
7. **📁 Organized Traces**: Versioned folders with chronological numbering prevent conflicts
8. **⚡ Performance Focus**: Configuration now optimized for performance tuning only
9. **🗂️ Structured Storage**: Each operation gets its own folder with numbered XML files
10. **🔗 Cross-Reference**: Metadata file links operation sequence to specific XML files
11. **🚀 Reproducibility**: Individual XML files can be replayed for testing and validation
12. **🏷️ Clear Naming**: File names indicate operation type, target, and success/failure status
13. **🔮 Future-Proof**: Q35 platform ready for emerging virtualization technologies

## Management Changes Summary (**Simplified Implementation - x86_64 + GPU Passthrough**)

### **Changes Overview**

<!-- markdownlint-disable-next-line MD013 -->
The updated implementation extends the HPC VM Management system with KVM acceleration and GPU passthrough support for x86_64 systems:

#### **1. Schema Changes (Simplified)**

- **Hardware Configuration Block**: New `cluster.hardware` section with:
  - KVM acceleration settings (`acceleration.enable_kvm`)
  - Nested virtualization support (`acceleration.enable_nested`)
  - CPU model and feature control (`cpu_model`, `cpu_features`)
  - NUMA topology configuration (`numa_topology`)
  - Performance optimizations (`performance.enable_hugepages`, `cpu_pinning`)
  - **NEW: GPU/PCIe passthrough configuration** (`pcie_passthrough`)
- **NEW: XML Tracing System**: Comprehensive logging of all libvirt XML operations

#### **2. XML Tracing System (**NEW**)**

The XML tracing system provides comprehensive logging and debugging capabilities:

```python
# XML Tracing Features:
class XMLTracer:
    """Benefits of XML Tracing:
    - Complete audit trail of all libvirt XML operations
    - Debugging support for failed cluster operations  
    - Performance analysis of XML creation and submission
    - Reproducible cluster deployments from trace files
    - Validation of generated XML against expectations
    """
    
    def generate_trace_folder(self) -> str:
        """Unique versioned trace folders per run:
        Format: run_{cluster_name}_{operation}_{timestamp}/
        Examples:
        - run_hpc-cluster_start_20241217_143052_123/
        - run_gpu-cluster_destroy_20241217_143156_456/
        """
    
    def log_xml(self, xml_type, xml_content, operation, target_name, success, error):
        """Saves individual XML files and tracks metadata:
        - Each XML operation saved to separate numbered file
        - Network creation: 001_network_create_cluster-network_SUCCESS.xml
        - Storage pool: 002_pool_define_cluster-pool_SUCCESS.xml
        - Volume creation: 003_volume_create_vm-name_SUCCESS.xml
        - Domain definition: 004_domain_define_vm-name_SUCCESS.xml
        - Failed operations: 005_domain_define_vm-name_FAILED.xml
        - Comprehensive metadata in trace_metadata.json
        """
```

**XML Trace Folder Structure:**

```text
traces/
└── run_hpc-cluster_start_20241217_143052_123/
    ├── 001_network_create_hpc-cluster-network_SUCCESS.xml
    ├── 002_pool_define_hpc-cluster-pool_SUCCESS.xml
    ├── 003_volume_create_hpc-cluster-base_SUCCESS.xml
    ├── 004_volume_create_controller-01_SUCCESS.xml
    ├── 005_volume_create_compute-01_SUCCESS.xml
    ├── 006_domain_define_controller-01_SUCCESS.xml
    ├── 007_domain_define_compute-01_SUCCESS.xml
    ├── 008_domain_define_compute-02_FAILED.xml
    └── trace_metadata.json
```

**trace_metadata.json Structure:**

```json
{
  "cluster_name": "hpc-cluster",
  "operation": "start",
  "start_time": "2024-12-17T14:30:52.123456",
  "end_time": "2024-12-17T14:31:15.987654",
  "total_xml_operations": 8,
  "trace_folder": "traces/run_hpc-cluster_start_20241217_143052_123",
  "xml_operations": [
    {
      "sequence": 1,
      "timestamp": "2024-12-17T14:30:53.234567",
      "xml_type": "network",
      "operation": "create",
      "target_name": "hpc-cluster-network",
      "success": true,
      "error": null,
      "xml_file": "001_network_create_hpc-cluster-network_SUCCESS.xml",
      "xml_length": 1234
    },
    {
      "sequence": 8,
      "timestamp": "2024-12-17T14:31:14.345678",
      "xml_type": "domain",
      "operation": "define", 
      "target_name": "compute-02",
      "success": false,
      "error": "CPU feature 'avx3' not supported",
      "xml_file": "008_domain_define_compute-02_FAILED.xml",
      "xml_length": 4567
    }
  ],
  "file_listing": [
    "001_network_create_hpc-cluster-network_SUCCESS.xml",
    "002_pool_define_hpc-cluster-pool_SUCCESS.xml",
    "003_volume_create_hpc-cluster-base_SUCCESS.xml",
    "004_volume_create_controller-01_SUCCESS.xml",
    "005_volume_create_compute-01_SUCCESS.xml", 
    "006_domain_define_controller-01_SUCCESS.xml",
    "007_domain_define_compute-01_SUCCESS.xml",
    "008_domain_define_compute-02_FAILED.xml"
  ]
}
```

#### **3. GPU/PCIe Passthrough Features**

```python
# NEW: GPU conflict detection and validation
class HPCClusterManager:
    def _validate_pcie_passthrough_config(self, pcie_config: dict) -> bool:
        """NEW: PCIe/GPU passthrough validation including:
        - IOMMU support verification
        - PCIe device existence check
        - Intra-cluster GPU conflict detection (same device to multiple VMs)
        - Inter-cluster GPU conflict detection (same device across clusters)
        - Automatic exclusive mode enforcement
        """
    
    def _check_inter_cluster_gpu_conflicts(self, devices: list[dict]) -> None:
        """NEW: Cross-cluster conflict detection:
        - Scans all cluster configurations for GPU conflicts
        - Enforces exclusive mode (only one cluster active for conflicting GPUs)
        - Provides detailed conflict reporting
        """
```

#### **3. Simplified Template System**

- **x86_64 Only**: Removed multi-architecture complexity for simplicity
- **GPU Passthrough Integration**: Templates automatically handle GPU assignment
- **Conditional Graphics**: Disable VNC/video when GPU is passed through
- **Hardware Feature Integration**: KVM, nested virtualization, CPU features
- **Performance Optimizations**: Hugepages, CPU pinning, memory backing options

#### **4. GPU Conflict Management**

- **Intra-Cluster Validation**: Prevent same GPU assigned to multiple VMs in cluster
- **Inter-Cluster Detection**: Scan all cluster configurations for GPU conflicts
- **Exclusive Mode**: Only one cluster can be active when GPU conflicts exist
- **Detailed Error Reporting**: Clear messages about conflicting assignments

#### **5. Future Versioning Provision**

```python
# ai_how/schemas/future_versioning.py (Placeholder)
"""
Future versioning system will include:
- Schema version tracking
- Backward compatibility support  
- Automatic migration utilities
- Configuration validation and upgrade tools

Implementation planned for v1.0 stable release.
"""
```

#### **6. System Requirements**

```python
# System requirements for GPU passthrough:
SYSTEM_REQUIREMENTS = {
    'iommu_support': 'Intel VT-d or AMD-Vi enabled (intel_iommu=on/amd_iommu=on)',
    'kvm_support': '/dev/kvm device and KVM kernel modules',
    'nested_virt': 'Intel VT-x or AMD-V with nested virtualization (optional)',
    'hugepages': 'Kernel hugepage support for performance (optional)',
    'emulator': 'qemu-system-x86_64',
    'gpu_drivers': 'Host GPU drivers for device identification'
}
```

#### **7. Impact Assessment**

| Component | Change Type | Impact Level | Description |
|-----------|-------------|--------------|-------------|
| **Schema** | Major | High | New hardware and GPU passthrough configuration |
| **Templates** | Major | High | GPU passthrough support, simplified x86_64 only |
| **Validation** | New | High | GPU conflict detection across clusters |
| **Configuration** | Enhanced | Medium | Extended with GPU assignment options |
| **Cluster Management** | Enhanced | High | Cross-cluster conflict enforcement |
| **Documentation** | Major | Low | GPU passthrough configuration examples |

#### **8. Per-VM GPU Configuration Example**

```yaml
global: {}

cluster:
  name: "gpu-cluster"
  compute_nodes:
    - name: "compute-01"
      cpu_cores: 8
      memory_mb: 16384
      # Per-VM GPU passthrough configuration
      pcie_passthrough:
        enabled: true
        devices:
          - pci_address: "0000:65:00.0"  # A100 GPU
            device_type: "gpu"
            vendor_id: "10de"
            device_id: "2684"
            iommu_group: 1
    - name: "compute-02"
      cpu_cores: 8  
      memory_mb: 16384
      pcie_passthrough:
        enabled: true
        devices:
          - pci_address: "0000:ca:00.0"  # RTX 6000 GPU
            device_type: "gpu"
            vendor_id: "10de"
            device_id: "1e36"
            iommu_group: 4
```

#### **9. Testing Implications**

- **GPU Passthrough Testing**: Verify GPU assignment and isolation
- **Conflict Detection Testing**: Test intra and inter-cluster conflict detection
- **Exclusive Mode Testing**: Validate only one cluster active with conflicting GPUs
- **IOMMU Testing**: Test with/without IOMMU support
- **Performance Testing**: Validate GPU performance in VMs

#### **10. Deployment Considerations**

- **IOMMU Requirement**: Must enable Intel VT-d or AMD-Vi in BIOS and kernel
- **GPU Driver Management**: Host drivers needed for device identification
- **Cluster Exclusivity**: Only one cluster active when GPU conflicts exist  
- **IOMMU Group Planning**: Plan GPU assignments based on IOMMU groups
- **Performance Optimization**: Configure hugepages for GPU workloads

#### **11. Future Extensibility**

The simplified architecture provides foundation for:

- **ARM Architecture Support**: Easy addition when needed (single architecture toggle)
- **Multiple GPU Types**: Support for different GPU vendors and models
- **Advanced GPU Features**: SR-IOV, GPU virtualization, MIG support
- **Network Accelerators**: Similar passthrough for network devices
- **Storage Accelerators**: NVMe and storage device passthrough

## Summary of Key Changes (**Updated Implementation**)

### **Problem**: Permission Denied Errors

The original implementation attempted to create directories and copy files directly:

```python
# PROBLEMATIC: Direct file operations
cluster_pool_path.mkdir(parents=True, exist_ok=True)  # Permission denied!
os.chmod(cluster_pool_path, ...)  # Manual permission setting
```

### **Solution**: Libvirt-Native API Usage

#### **1. Storage Pool Creation**

```python
# OLD: Manual directory creation + permission setting
cluster_pool_path.mkdir(parents=True, exist_ok=True)
os.chmod(cluster_pool_path, stat.S_IRWXU | stat.S_IRGRP | ...)

# NEW: Let libvirt handle everything
pool = conn.storagePoolDefineXML(pool_xml, 0)
pool.build(0)  # Creates directory with proper permissions automatically
pool.create(0)
```

#### **2. Base Image Handling**

```python
# OLD: Direct file copying
cmd = ["cp", str(source_path), str(dest_path)]  # Permission issues

# NEW: Libvirt stream API
volume = pool.createXML(volume_xml, 0)
stream = conn.newStream(0)
volume.upload(stream, 0, capacity, 0)
# Upload data through libvirt's secure stream API
```

#### **3. Volume Operations**

```python
# All volume operations now use libvirt APIs exclusively:
- pool.createXML() for volume creation
- volume.upload() for data transfers
- volume.info() for statistics
- pool.listVolumes() for listing
```

### **Benefits Achieved**

- ✅ **No More Permission Errors**: libvirt handles all directory/file permissions
- ✅ **Better Security**: Operations go through libvirt's security framework
- ✅ **SELinux Compliance**: Automatic SELinux context management
- ✅ **Cleaner Code**: No manual permission management or direct file operations
- ✅ **Better Error Handling**: libvirt provides detailed error information
- ✅ **Future-Proof**: Compatible with different storage backends (LVM, ZFS, etc.)

## Latest Update Summary: Versioned XML Tracing Folders

### ✅ **Updated XML Tracing Architecture**

#### **Key Changes Made:**

1. **📁 Versioned Folder Structure**:
   - **Before**: Single JSON trace file per operation
   - **After**: Versioned folder per run with individual XML files

2. **🏗️ Folder Organization**:

   ```text
   traces/
   └── run_{cluster_name}_{operation}_{timestamp}/
       ├── 001_network_create_{target}_SUCCESS.xml
       ├── 002_pool_define_{target}_SUCCESS.xml
       ├── 003_volume_create_{target}_FAILED.xml
       └── trace_metadata.json
   ```

3. **📝 Individual XML Files**: Each libvirt operation saves to a separate numbered XML file
4. **📊 Comprehensive Metadata**: `trace_metadata.json` contains operation sequence, timing, and cross-references
5. **🏷️ Clear File Naming**: Format indicates sequence, type, operation, target, and success/failure
6. **🔗 Cross-Referencing**: Metadata links each operation to its corresponding XML file

#### **Enhanced Features:**

- **🐛 Better Debugging**: Individual XML files can be inspected and replayed
- **📈 Success/Failure Tracking**: Clear visual indication in filenames and metadata
- **🔢 Sequential Numbering**: Operations numbered chronologically for easy tracking
- **📂 Organized Storage**: No more single large JSON files, each XML is separate
- **🚀 Reproducibility**: Individual XML files can be used to reproduce operations
- **🗂️ Better Organization**: Each cluster operation gets its own isolated folder

#### **CLI Integration Enhanced:**

```bash
$ ai-how hpc start
XML trace folder: traces/run_hpc-cluster_start_20241217_143052_123
Total XML operations: 8 (7 successful, 1 failed)
Check XML traces for debugging: traces/run_hpc-cluster_start_20241217_143052_123
Metadata file: traces/run_hpc-cluster_start_20241217_143052_123/trace_metadata.json
```

This versioned folder approach provides superior organization, debugging capabilities,
and maintainability for HPC cluster management operations.

## Host Configuration Management Update Summary

### ✅ **Applied Host Changes Recommendations**

The HPC VM Management Implementation Plan has been updated to address the security
concerns identified in the Host Machine Reconfiguration Analysis. All direct
host system modifications are now **DISABLED BY DEFAULT** and require
explicit user permission.

#### **Key Changes Made:**

1. **🔒 Host Changes Disabled by Default**:
   - Cross-cluster routing (iptables/sysctl changes) - DISABLED
   - Host DNS integration (dnsmasq configuration) - DISABLED
   - Service discovery configuration - DISABLED
   - All features fall back to isolated mode when disabled

2. **⚠️ Warning Messages with Manual Instructions**:
   - System prints detailed warnings when host changes are requested
   - Provides step-by-step manual configuration instructions
   - Shows exact configuration needed to enable features
   - Explains security implications of each change

3. **⚙️ Configuration-Driven Control**:
   - New `host_configuration` section in cluster configuration
   - Granular control over each type of host modification
   - User confirmation required for all changes
   - Audit logging enabled by default

4. **🛡️ Production Safety Features**:
   - Default configuration is production-safe
   - No surprise host modifications
   - Graceful degradation when features are disabled
   - Clear separation between development and production modes

#### **Configuration Examples:**

```yaml
# Production-safe (default) - no host changes
host_configuration:
  network:
    enable_cross_cluster_routing: false    # No iptables/sysctl changes
    enable_host_dns_integration: false     # No dnsmasq changes
    enable_service_discovery: false        # No external service config

# Development mode - all features enabled (DANGEROUS for production)
host_configuration:
  development_mode: true
  skip_confirmation: true
  allow_destructive_changes: true

# Custom mode - selective features enabled
host_configuration:
  network:
    enable_cross_cluster_routing: true     # Enable routing only
    require_confirmation: true            # Require confirmation
  system:
    enable_hugepage_config: false         # Keep hugepages disabled
```

#### **What Users See When Host Changes Are Disabled:**

```bash
WARNING: Cross-cluster routing requested for hpc-cluster but host changes are disabled.
To enable routing between clusters, add to your configuration:
host_configuration:
  network:
    enable_cross_cluster_routing: true
    require_confirmation: true

Manual steps required:
1. Enable IP forwarding: sudo sysctl -w net.ipv4.ip_forward=1
2. Add iptables rules for bridge br-hpc-cluster
3. Make IP forwarding permanent: echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
```

#### **Security Benefits Achieved:**

- ✅ **No Surprise Changes**: System cannot modify host without explicit permission
- ✅ **Audit Trail**: All change attempts are logged for compliance
- ✅ **Graceful Degradation**: Features fail safely without breaking the cluster
- ✅ **User Control**: Users decide exactly what host changes are allowed
- ✅ **Production Safe**: Default configuration is safe for production environments
- ✅ **Clear Documentation**: Users understand exactly what each feature does
- ✅ **Manual Override**: Users can still enable features when needed

#### **Impact on Existing Features:**

| Feature | Before | After | Impact |
|---------|--------|-------|---------|
| **Cross-Cluster Routing** | Always enabled | Disabled by default | Users must explicitly enable |
| **Host DNS Integration** | Always enabled | Disabled by default | Users must explicitly enable |
| **Service Discovery** | Always enabled | Disabled by default | Users must explicitly enable |
| **Fallback Behavior** | Error on failure | Graceful fallback to isolated mode | Better user experience |
| **Security** | Host modifications without warning | Explicit permission required | Much safer |

This update ensures that the HPC VM Management system is production-ready while maintaining all
functionality for users who explicitly enable host modifications. The system now provides a secure,
auditable, and user-controlled approach to cluster management that addresses the security concerns
raised in the Host Machine Reconfiguration Analysis.
