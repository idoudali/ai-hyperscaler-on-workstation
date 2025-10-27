"""VM creation factory for standardized VM provisioning."""

import logging
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from ai_how.state.cluster_state import ClusterState, VMState
from ai_how.state.models import VMInfo
from ai_how.vm_management.network_manager import NetworkManager, NetworkManagerError
from ai_how.vm_management.vm_lifecycle import VMLifecycleError, VMLifecycleManager
from ai_how.vm_management.volume_manager import VolumeManager, VolumeManagerError

logger = logging.getLogger(__name__)


class VMFactoryError(Exception):
    """VM factory operation error."""

    pass


@dataclass
class VMSpec:
    """Specification for VM creation.

    Attributes:
        vm_name: Name of the VM to create
        cluster_name: Name of the cluster this VM belongs to
        vm_type: Type of VM ('controller', 'compute', 'worker', 'cpu', 'gpu')
        cpu_cores: Number of CPU cores to allocate
        memory_gb: Amount of memory in GB to allocate
        disk_gb: Disk size in GB
        template_name: Name of the XML template to use
        static_ip: Optional static IP address (if None, will be allocated)
        pcie_passthrough: Optional PCIe passthrough configuration
    """

    vm_name: str
    cluster_name: str
    vm_type: str
    cpu_cores: int
    memory_gb: int
    disk_gb: int
    template_name: str
    static_ip: str | None = None
    pcie_passthrough: dict | None = None


class VMFactory:
    """Factory for creating VMs with standardized workflow.

    This factory encapsulates the common VM creation pattern:
    1. Check if VM already exists
    2. Create storage volume
    3. Allocate or use static IP address
    4. Generate VM XML configuration
    5. Create VM domain in libvirt
    6. Create VMInfo object

    Example:
        >>> factory = VMFactory(
        ...     volume_manager=volume_mgr,
        ...     network_manager=network_mgr,
        ...     vm_lifecycle=vm_lifecycle,
        ...     xml_generator=generate_xml_func
        ... )
        >>> spec = VMSpec(
        ...     vm_name="test-vm",
        ...     cluster_name="test-cluster",
        ...     vm_type="compute",
        ...     cpu_cores=4,
        ...     memory_gb=8,
        ...     disk_gb=100,
        ...     template_name="compute_node.xml.j2"
        ... )
        >>> vm_info = factory.create_vm(spec, cluster_state)
    """

    def __init__(
        self,
        volume_manager: VolumeManager,
        network_manager: NetworkManager,
        vm_lifecycle: VMLifecycleManager,
        xml_generator: Callable[..., str],
    ):
        """Initialize VM factory.

        Args:
            volume_manager: Manager for storage volumes
            network_manager: Manager for network resources
            vm_lifecycle: Manager for VM lifecycle operations
            xml_generator: Function to generate VM XML configuration.
                          Should accept: vm_name, template_name, cpu_cores,
                          memory_gb, volume_path, ip_address, pcie_passthrough
        """
        self.volume_manager = volume_manager
        self.network_manager = network_manager
        self.vm_lifecycle = vm_lifecycle
        self.xml_generator = xml_generator

    def create_vm(self, spec: VMSpec, cluster_state: ClusterState) -> VMInfo:
        """Create VM following standardized workflow.

        Args:
            spec: VM specification with all required parameters
            cluster_state: Cluster state to check for existing VMs

        Returns:
            Created VMInfo object with all VM details

        Raises:
            VMFactoryError: If VM creation fails at any step
        """
        logger.debug(f"Creating VM: {spec.vm_name} (type={spec.vm_type})")

        # Step 1: Check if VM already exists
        if cluster_state.get_vm_by_name(spec.vm_name):
            raise VMFactoryError(f"VM {spec.vm_name} already exists in cluster state")

        try:
            # Step 2: Create storage volume
            logger.debug(f"Creating volume for VM {spec.vm_name}")
            volume_path = self._create_volume(spec)

            # Step 3: Allocate or use static IP address
            logger.debug(f"Allocating IP address for VM {spec.vm_name}")
            allocated_ip = self._allocate_ip(spec)

            # Step 4: Generate VM XML configuration
            logger.debug(f"Generating XML configuration for VM {spec.vm_name}")
            xml_config = self._generate_xml(spec, volume_path, allocated_ip)

            # Step 5: Create VM domain
            logger.debug(f"Creating VM domain for {spec.vm_name}")
            domain_uuid = self._create_vm_domain(spec.vm_name, xml_config)

            # Step 6: Create VM info object
            vm_info = self._create_vm_info(spec, volume_path, allocated_ip, domain_uuid)

            logger.info(f"Successfully created VM: {spec.vm_name}")
            return vm_info

        except (VolumeManagerError, NetworkManagerError, VMLifecycleError) as e:
            logger.error(f"Failed to create VM {spec.vm_name}: {e}")
            raise VMFactoryError(f"Failed to create VM {spec.vm_name}: {e}") from e
        except Exception as e:
            logger.error(f"Unexpected error creating VM {spec.vm_name}: {e}")
            raise VMFactoryError(f"Unexpected error creating VM {spec.vm_name}: {e}") from e

    def _create_volume(self, spec: VMSpec) -> str:
        """Create storage volume for VM.

        Args:
            spec: VM specification

        Returns:
            Path to created volume

        Raises:
            VolumeManagerError: If volume creation fails
        """
        return self.volume_manager.create_vm_volume(
            cluster_name=spec.cluster_name,
            vm_name=spec.vm_name,
            size_gb=spec.disk_gb,
            vm_type=spec.vm_type,
        )

    def _allocate_ip(self, spec: VMSpec) -> str:
        """Allocate or use static IP address for VM.

        Args:
            spec: VM specification

        Returns:
            IP address (static or allocated)

        Raises:
            NetworkManagerError: If IP allocation fails
        """
        if spec.static_ip:
            logger.debug(f"Using static IP {spec.static_ip} for {spec.vm_name}")
            return spec.static_ip
        else:
            allocated_ip = self.network_manager.allocate_ip_address(spec.cluster_name, spec.vm_name)
            logger.debug(f"Allocated dynamic IP {allocated_ip} for {spec.vm_name}")
            return allocated_ip

    def _generate_xml(self, spec: VMSpec, volume_path: str, ip_address: str) -> str:
        """Generate VM XML configuration.

        Args:
            spec: VM specification
            volume_path: Path to storage volume
            ip_address: Allocated IP address

        Returns:
            XML configuration string

        Raises:
            Exception: If XML generation fails
        """
        return self.xml_generator(
            vm_name=spec.vm_name,
            template_name=spec.template_name,
            cpu_cores=spec.cpu_cores,
            memory_gb=spec.memory_gb,
            volume_path=Path(volume_path),
            ip_address=ip_address,
            pcie_passthrough=spec.pcie_passthrough,
        )

    def _create_vm_domain(self, vm_name: str, xml_config: str) -> str:
        """Create VM domain in libvirt.

        Args:
            vm_name: Name of the VM
            xml_config: XML configuration

        Returns:
            Domain UUID

        Raises:
            VMLifecycleError: If VM domain creation fails
        """
        return self.vm_lifecycle.create_vm(vm_name, xml_config)

    def _create_vm_info(
        self, spec: VMSpec, volume_path: str, ip_address: str, domain_uuid: str
    ) -> VMInfo:
        """Create VMInfo object with VM details.

        Args:
            spec: VM specification
            volume_path: Path to storage volume
            ip_address: Allocated IP address
            domain_uuid: Domain UUID from libvirt

        Returns:
            VMInfo object
        """
        return VMInfo(
            name=spec.vm_name,
            domain_uuid=domain_uuid,
            state=VMState.SHUTOFF,
            cpu_cores=spec.cpu_cores,
            memory_gb=spec.memory_gb,
            volume_path=Path(volume_path),
            vm_type=spec.vm_type,
            ip_address=ip_address,
        )
