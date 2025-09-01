"""State data models for cluster and VM tracking."""

from dataclasses import asdict, dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any


class VMState(Enum):
    """VM state enumeration matching libvirt states."""

    UNDEFINED = "undefined"
    RUNNING = "running"
    BLOCKED = "blocked"
    PAUSED = "paused"
    SHUTDOWN = "shutdown"
    SHUTOFF = "shutoff"
    CRASHED = "crashed"
    PMSUSPENDED = "pmsuspended"
    ERROR = "error"

    @classmethod
    def from_libvirt_state(cls, state: int) -> "VMState":
        """Convert libvirt state integer to VMState enum.

        Args:
            state: libvirt state integer

        Returns:
            VMState enum value
        """
        # Map libvirt state constants to our enum
        # libvirt states: VIR_DOMAIN_NOSTATE=0, VIR_DOMAIN_RUNNING=1, etc.
        state_map = {
            0: cls.UNDEFINED,  # VIR_DOMAIN_NOSTATE
            1: cls.RUNNING,  # VIR_DOMAIN_RUNNING
            2: cls.BLOCKED,  # VIR_DOMAIN_BLOCKED
            3: cls.PAUSED,  # VIR_DOMAIN_PAUSED
            4: cls.SHUTDOWN,  # VIR_DOMAIN_SHUTDOWN
            5: cls.SHUTOFF,  # VIR_DOMAIN_SHUTOFF
            6: cls.CRASHED,  # VIR_DOMAIN_CRASHED
            7: cls.PMSUSPENDED,  # VIR_DOMAIN_PMSUSPENDED
        }
        return state_map.get(state, cls.ERROR)


@dataclass
class VolumeInfo:
    """Volume information and state."""

    name: str
    path: str
    size_gb: float
    allocated_gb: float
    format: str
    created_at: datetime
    backing_file: str | None = None

    def __post_init__(self):
        """Set timestamps if not provided."""
        if isinstance(self.created_at, str):
            self.created_at = datetime.fromisoformat(self.created_at)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        data = asdict(self)
        data["created_at"] = self.created_at.isoformat()
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "VolumeInfo":
        """Create VolumeInfo from dictionary."""
        if "created_at" in data and isinstance(data["created_at"], str):
            data["created_at"] = datetime.fromisoformat(data["created_at"])
        return cls(**data)


@dataclass
class StoragePoolInfo:
    """Storage pool information."""

    name: str
    path: str
    type: str
    capacity_gb: float
    allocation_gb: float
    available_gb: float
    volumes: list[VolumeInfo] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.now)
    uuid: str | None = None

    def __post_init__(self):
        """Set timestamps if not provided."""
        if isinstance(self.created_at, str):
            self.created_at = datetime.fromisoformat(self.created_at)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        data = asdict(self)
        data["volumes"] = [vol.to_dict() for vol in self.volumes]
        data["created_at"] = self.created_at.isoformat()
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "StoragePoolInfo":
        """Create StoragePoolInfo from dictionary."""
        if "created_at" in data and isinstance(data["created_at"], str):
            data["created_at"] = datetime.fromisoformat(data["created_at"])
        if "volumes" in data:
            data["volumes"] = [VolumeInfo.from_dict(vol_data) for vol_data in data["volumes"]]
        return cls(**data)


@dataclass
class NetworkInfo:
    """Virtual network information."""

    name: str
    bridge_name: str
    network_range: str  # e.g., "192.168.100.0/24"
    gateway_ip: str
    dhcp_start: str
    dhcp_end: str
    dns_servers: list[str] = field(default_factory=list)
    is_active: bool = False
    allocated_ips: dict[str, str] = field(default_factory=dict)  # vm_name -> ip_address mapping
    created_at: datetime = field(default_factory=datetime.now)
    uuid: str | None = None

    def __post_init__(self):
        """Set timestamps if not provided."""
        if isinstance(self.created_at, str):
            self.created_at = datetime.fromisoformat(self.created_at)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        data = asdict(self)
        data["created_at"] = self.created_at.isoformat()
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "NetworkInfo":
        """Create NetworkInfo from dictionary."""
        if "created_at" in data and isinstance(data["created_at"], str):
            data["created_at"] = datetime.fromisoformat(data["created_at"])
        return cls(**data)


@dataclass
class NetworkConfig:
    """Network configuration for clusters."""

    subnet: str
    bridge: str
    dns_mode: str = "isolated"
    dns_servers: list[str] = field(default_factory=lambda: ["8.8.8.8", "1.1.1.1"])
    static_leases: dict[str, str] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "NetworkConfig":
        """Create NetworkConfig from dictionary."""
        return cls(**data)


@dataclass
class VMInfo:
    """Information about a single VM."""

    name: str
    domain_uuid: str
    state: VMState
    cpu_cores: int
    memory_gb: int
    volume_path: Path  # Changed from disk_path
    vm_type: str = "compute"  # controller, compute, etc.
    ip_address: str | None = None
    gpu_assigned: str | None = None  # Changed from bool to str to store GPU model name
    created_at: datetime | None = None
    last_modified: datetime | None = None

    def __post_init__(self):
        """Set timestamps if not provided."""
        if self.created_at is None:
            self.created_at = datetime.now()
        if self.last_modified is None:
            self.last_modified = datetime.now()

        # Ensure volume_path is a Path object
        if isinstance(self.volume_path, str):
            self.volume_path = Path(self.volume_path)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        data = asdict(self)
        # Convert Path objects to strings
        data["volume_path"] = str(self.volume_path)
        # Convert datetime objects to ISO format strings
        if self.created_at:
            data["created_at"] = self.created_at.isoformat()
        if self.last_modified:
            data["last_modified"] = self.last_modified.isoformat()
        # Convert enum to string
        data["state"] = self.state.value
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "VMInfo":
        """Create VMInfo from dictionary."""
        # Handle backward compatibility for disk_path -> volume_path
        if "disk_path" in data and "volume_path" not in data:
            data["volume_path"] = data.pop("disk_path")

        # Handle backward compatibility for gpu_assigned as boolean
        if "gpu_assigned" in data and isinstance(data["gpu_assigned"], bool):
            data["gpu_assigned"] = "GPU" if data["gpu_assigned"] else None

        # Validate required fields
        required_fields = ["name", "domain_uuid", "state", "cpu_cores", "memory_gb", "volume_path"]
        for field_name in required_fields:
            if field_name not in data:
                raise ValueError(f"Missing required field: {field_name}")

        # Validate field types
        if not isinstance(data["name"], str):
            raise ValueError(f"name must be a string, got {type(data['name'])}")
        if not isinstance(data["domain_uuid"], str):
            raise ValueError(f"domain_uuid must be a string, got {type(data['domain_uuid'])}")
        if not isinstance(data["cpu_cores"], int):
            raise ValueError(f"cpu_cores must be an integer, got {type(data['cpu_cores'])}")
        if not isinstance(data["memory_gb"], int):
            raise ValueError(f"memory_gb must be an integer, got {type(data['memory_gb'])}")

        # Convert string back to Path
        if "volume_path" in data:
            data["volume_path"] = Path(data["volume_path"])

        # Convert ISO format strings back to datetime
        if "created_at" in data and data["created_at"]:
            data["created_at"] = datetime.fromisoformat(data["created_at"])
        if "last_modified" in data and data["last_modified"]:
            data["last_modified"] = datetime.fromisoformat(data["last_modified"])

        # Convert string back to enum
        if "state" in data:
            data["state"] = VMState(data["state"])

        return cls(**data)

    def update_state(self, new_state: VMState) -> None:
        """Update VM state and timestamp."""
        self.state = new_state
        self.last_modified = datetime.now()


@dataclass
class ClusterState:
    """Complete state information for a cluster."""

    cluster_name: str
    cluster_type: str  # "hpc" or "cloud"
    controller: VMInfo | None = None
    compute_nodes: list[VMInfo] = field(default_factory=list)
    worker_nodes: list[VMInfo] = field(default_factory=list)
    network_config: NetworkConfig | None = None
    storage_pool: StoragePoolInfo | None = None  # Storage pool information
    config_file_path: str | None = None
    state_file_version: str = "2.0"  # Updated version for volume management
    created_at: datetime | None = None
    last_modified: datetime | None = None

    def __post_init__(self):
        """Initialize default values."""
        if self.created_at is None:
            self.created_at = datetime.now()
        if self.last_modified is None:
            self.last_modified = datetime.now()

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        data = {
            "cluster_name": self.cluster_name,
            "cluster_type": self.cluster_type,
            "controller": self.controller.to_dict() if self.controller else None,
            "compute_nodes": [vm.to_dict() for vm in self.compute_nodes],
            "worker_nodes": [vm.to_dict() for vm in self.worker_nodes],
            "network_config": self.network_config.to_dict() if self.network_config else None,
            "storage_pool": self.storage_pool.to_dict() if self.storage_pool else None,
            "config_file_path": self.config_file_path,
            "state_file_version": self.state_file_version,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "last_modified": self.last_modified.isoformat() if self.last_modified else None,
        }
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "ClusterState":
        """Create ClusterState from dictionary."""
        # Validate required fields
        required_fields = ["cluster_name", "cluster_type"]
        for field_name in required_fields:
            if field_name not in data:
                raise ValueError(f"Missing required field: {field_name}")

        # Validate field types
        if not isinstance(data["cluster_name"], str):
            raise ValueError(f"cluster_name must be a string, got {type(data['cluster_name'])}")
        if not isinstance(data["cluster_type"], str):
            raise ValueError(f"cluster_type must be a string, got {type(data['cluster_type'])}")

        # Validate cluster_type values
        valid_types = ["hpc", "cloud"]
        if data["cluster_type"] not in valid_types:
            raise ValueError(
                f"cluster_type must be one of {valid_types}, got {data['cluster_type']}"
            )

        # Convert controller
        controller = None
        if data.get("controller"):
            if not isinstance(data["controller"], dict):
                raise ValueError(f"controller must be a dictionary, got {type(data['controller'])}")
            controller = VMInfo.from_dict(data["controller"])

        # Convert compute nodes
        compute_nodes = []
        if data.get("compute_nodes"):
            if not isinstance(data["compute_nodes"], list):
                raise ValueError(f"compute_nodes must be a list, got {type(data['compute_nodes'])}")
            compute_nodes = [VMInfo.from_dict(vm_data) for vm_data in data["compute_nodes"]]

        # Convert worker nodes
        worker_nodes = []
        if data.get("worker_nodes"):
            if not isinstance(data["worker_nodes"], list):
                raise ValueError(f"worker_nodes must be a list, got {type(data['worker_nodes'])}")
            worker_nodes = [VMInfo.from_dict(vm_data) for vm_data in data["worker_nodes"]]

        # Convert network config
        network_config = None
        if data.get("network_config"):
            if not isinstance(data["network_config"], dict):
                raise ValueError(
                    f"network_config must be a dictionary, got {type(data['network_config'])}"
                )
            network_config = NetworkConfig.from_dict(data["network_config"])

        # Convert storage pool
        storage_pool = None
        if data.get("storage_pool"):
            if not isinstance(data["storage_pool"], dict):
                raise ValueError(
                    f"storage_pool must be a dictionary, got {type(data['storage_pool'])}"
                )
            storage_pool = StoragePoolInfo.from_dict(data["storage_pool"])

        # Convert timestamps
        created_at = None
        if data.get("created_at"):
            if not isinstance(data["created_at"], str):
                raise ValueError(f"created_at must be a string, got {type(data['created_at'])}")
            created_at = datetime.fromisoformat(data["created_at"])

        last_modified = None
        if data.get("last_modified"):
            if not isinstance(data["last_modified"], str):
                raise ValueError(
                    f"last_modified must be a string, got {type(data['last_modified'])}"
                )
            last_modified = datetime.fromisoformat(data["last_modified"])

        return cls(
            cluster_name=data["cluster_name"],
            cluster_type=data["cluster_type"],
            controller=controller,
            compute_nodes=compute_nodes,
            worker_nodes=worker_nodes,
            network_config=network_config,
            storage_pool=storage_pool,
            config_file_path=data.get("config_file_path"),
            state_file_version=data.get("state_file_version", "2.0"),
            created_at=created_at,
            last_modified=last_modified,
        )

    def get_all_vms(self) -> list[VMInfo]:
        """Get all VMs in the cluster."""
        vms = []
        if self.controller:
            vms.append(self.controller)
        vms.extend(self.compute_nodes)
        vms.extend(self.worker_nodes)
        return vms

    def get_vm_by_name(self, name: str) -> VMInfo | None:
        """Get VM by name."""
        for vm in self.get_all_vms():
            if vm.name == name:
                return vm
        return None

    def add_vm(self, vm_info: VMInfo) -> bool:
        """Add VM to appropriate list based on naming convention.

        Args:
            vm_info: VM information to add

        Returns:
            True if added successfully, False if VM already exists
        """
        # Check if VM already exists
        if self.get_vm_by_name(vm_info.name):
            return False

        # Add to appropriate list based on name
        if "controller" in vm_info.name.lower():
            self.controller = vm_info
        elif "compute" in vm_info.name.lower():
            self.compute_nodes.append(vm_info)
        elif "worker" in vm_info.name.lower():
            self.worker_nodes.append(vm_info)
        else:
            # Default to compute nodes for HPC, worker nodes for cloud
            if self.cluster_type == "hpc":
                self.compute_nodes.append(vm_info)
            else:
                self.worker_nodes.append(vm_info)

        self.last_modified = datetime.now()
        return True

    def remove_vm(self, name: str) -> bool:
        """Remove VM by name.

        Args:
            name: VM name to remove

        Returns:
            True if removed successfully, False if not found
        """
        # Check controller
        if self.controller and self.controller.name == name:
            self.controller = None
            self.last_modified = datetime.now()
            return True

        # Check compute nodes
        for i, vm in enumerate(self.compute_nodes):
            if vm.name == name:
                del self.compute_nodes[i]
                self.last_modified = datetime.now()
                return True

        # Check worker nodes
        for i, vm in enumerate(self.worker_nodes):
            if vm.name == name:
                del self.worker_nodes[i]
                self.last_modified = datetime.now()
                return True

        return False

    def update_vm_state(self, name: str, new_state: VMState) -> bool:
        """Update VM state by name.

        Args:
            name: VM name
            new_state: New VM state

        Returns:
            True if updated successfully, False if VM not found
        """
        vm = self.get_vm_by_name(name)
        if vm:
            vm.update_state(new_state)
            self.last_modified = datetime.now()
            return True
        return False

    def get_cluster_status(self) -> dict[str, Any]:
        """Get cluster status summary."""
        all_vms = self.get_all_vms()
        running_vms = [vm for vm in all_vms if vm.state == VMState.RUNNING]

        status = {
            "cluster_name": self.cluster_name,
            "cluster_type": self.cluster_type,
            "total_vms": len(all_vms),
            "running_vms": len(running_vms),
            "controller_status": self.controller.state.value if self.controller else "not_created",
            "compute_nodes": len(self.compute_nodes),
            "worker_nodes": len(self.worker_nodes),
            "last_modified": self.last_modified.isoformat() if self.last_modified else None,
        }

        return status
