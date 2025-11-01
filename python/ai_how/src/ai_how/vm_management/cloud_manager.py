"""Cloud cluster management using libvirt."""

import logging
import subprocess
import uuid
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader, TemplateNotFound

from ai_how.resource_management.gpu_allocator import GPUResourceAllocator
from ai_how.state.cluster_state import ClusterState, ClusterStateManager, VMState
from ai_how.state.models import NetworkConfig, VMInfo
from ai_how.utils.config_parser import ClusterConfigParser
from ai_how.utils.gpu_utils import GPUAddressParser
from ai_how.utils.logging import log_function_entry, log_function_exit, run_subprocess_with_logging
from ai_how.utils.vm_config_utils import AutoStartResolver
from ai_how.vm_management.hpc_manager import HPCClusterManager, HPCManagerError
from ai_how.vm_management.libvirt_client import LibvirtClient
from ai_how.vm_management.network_manager import NetworkManager, NetworkManagerError
from ai_how.vm_management.vm_lifecycle import VMLifecycleError, VMLifecycleManager
from ai_how.vm_management.volume_manager import VolumeManager, VolumeManagerError

logger = logging.getLogger(__name__)


class CloudManagerError(HPCManagerError):
    """Raised when Cloud cluster management operations fail."""

    pass


class CloudClusterManager(HPCClusterManager):
    """Manages Cloud cluster lifecycle operations.

    Inherits common infrastructure and VM management from HPCClusterManager,
    customizing for cloud cluster specific requirements (control plane, worker nodes).
    """

    def __init__(self, config: dict[str, Any], state_file: Path, operation: str = "cluster"):
        """Initialize Cloud cluster manager.

        Args:
            config: Cluster configuration dictionary
            state_file: Path to the state file
            operation: Type of operation
        """
        log_function_entry(logger, "__init__", state_file=state_file, operation=operation)

        self.config = config
        # Use ClusterConfigParser to extract cloud-specific config
        self.cloud_config, self.global_config = ClusterConfigParser.extract_cluster_config(
            config, "cloud"
        )

        # Override hpc_config with cloud_config for parent class
        self.hpc_config = self.cloud_config

        # Only log if required fields are present (for validation tests)
        if "name" in self.cloud_config:
            logger.debug(f"Cloud cluster name: {self.cloud_config['name']}")
        if "base_image_path" in self.cloud_config:
            logger.debug(f"Base image path: {self.cloud_config['base_image_path']}")

        cluster_name = self.cloud_config.get("name", "unknown")
        self.cluster_name = cluster_name

        # Initialize parent class components (without XML tracing for cloud)
        self._init_cloud_components(state_file)

        # Initialize Jinja2 environment (reuse parent's template_env setup)
        template_dir = Path(__file__).parent / "templates"

        self.template_env = Environment(
            loader=FileSystemLoader(template_dir), trim_blocks=True, lstrip_blocks=True
        )

        # Cloud manager doesn't use rollback manager or XML tracing
        self.xml_tracer = None
        self.rollback_manager = None

        log_function_exit(logger, "__init__")

    def _init_cloud_components(self, state_file: Path) -> None:
        """Initialize cloud cluster components without XML tracing."""

        self.libvirt_client = LibvirtClient()
        self.gpu_allocator = GPUResourceAllocator(state_file.parent / "global-state.json")
        self.vm_lifecycle = VMLifecycleManager(
            self.libvirt_client, gpu_allocator=self.gpu_allocator
        )
        self.volume_manager = VolumeManager(self.libvirt_client)
        self.network_manager = NetworkManager(self.libvirt_client)
        self.state_manager = ClusterStateManager(state_file)

    @staticmethod
    def _get_project_root(config_file: Path) -> Path:
        """Find the project root by searching for marker files.

        This method searches upward from the config file location for project markers
        like .git directory or pyproject.toml to reliably identify the project root.

        Args:
            config_file: Path to a configuration file within the project

        Returns:
            Path to the project root directory

        Raises:
            CloudManagerError: If project root cannot be determined
        """
        markers = [".git", "pyproject.toml", "CMakeLists.txt"]
        current = config_file.resolve().parent

        # Search up to 10 levels to find a marker
        for _ in range(10):
            for marker in markers:
                if (current / marker).exists():
                    return current
            if current.parent == current:
                # Reached filesystem root
                break
            current = current.parent

        # Fallback: if no marker found, use the traditional .parent.parent.parent
        # This maintains backward compatibility but logs a warning
        logger.warning(
            f"Could not find project root markers near {config_file}. "
            f"Using fallback path traversal."
        )
        return config_file.resolve().parent.parent.parent

    def start_cluster(self) -> bool:
        """Start the complete Cloud cluster.

        Returns:
            True if cluster started successfully

        Raises:
            CloudManagerError: If cluster start fails
        """
        log_function_entry(logger, "start_cluster")

        try:
            return self._execute_cluster_start()
        except Exception as e:
            logger.error(f"Failed to start cloud cluster: {e}")
            raise CloudManagerError(f"Failed to start cloud cluster: {e}") from e

    def _execute_cluster_start(self) -> bool:
        """Execute cluster start operation."""
        try:
            logger.info("Starting Cloud cluster")

            # 1. Validate configuration
            self._validate_cluster_config()

            # 2. Check prerequisites
            self._check_prerequisites()

            # 3. Create cluster infrastructure (network, storage pool)
            self._create_cluster_infrastructure()

            # 4. Ensure cluster state exists
            cluster_state = self.state_manager.ensure_state(
                cluster_name=self.cloud_config["name"], cluster_type="cloud"
            )

            # 5. Set up networking
            self._setup_cluster_networking(cluster_state)

            # 6. Create and start VMs
            self._create_and_start_vms(cluster_state)

            # 7. Save final state
            self.state_manager.save_state(cluster_state)

            logger.info("Cloud cluster started successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to start cloud cluster: {e}")
            raise

    def _validate_cluster_config(self) -> None:
        """Validate cloud cluster configuration."""
        # Basic validation
        required_fields = ["name", "base_image_path", "network"]
        for field in required_fields:
            if field not in self.cloud_config:
                raise CloudManagerError(f"Missing required field in cloud config: {field}")

    def _check_prerequisites(self) -> None:
        """Check system prerequisites for cloud cluster."""
        logger.debug("Checking system prerequisites for cloud cluster")

        # Test libvirt connection
        try:
            with self.libvirt_client.get_connection() as conn:
                hostname = conn.getHostname()
                logger.debug(f"Connected to libvirt host: {hostname}")
            logger.debug("libvirt connection test successful")
        except Exception as e:
            logger.error(f"libvirt connection failed: {e}")
            raise CloudManagerError(f"libvirt connection failed: {e}") from e

        # Check storage pool space requirements
        logger.debug("Checking storage pool space requirements")
        total_disk_needed = self.cloud_config["control_plane"]["disk_gb"]

        # Add worker nodes disk requirements
        worker_nodes_config = self.cloud_config.get("worker_nodes", [])
        if isinstance(worker_nodes_config, list):
            for worker_config in worker_nodes_config:
                total_disk_needed += worker_config["disk_gb"]

        logger.debug(f"Total disk requirement: {total_disk_needed}GB")

        try:
            import shutil

            storage_path = Path("/var/lib/libvirt/images")
            if storage_path.exists():
                stat = shutil.disk_usage(storage_path)
                available_gb = stat.free / (1024**3)
                logger.debug(f"Available space in {storage_path}: {available_gb:.2f}GB")

                if available_gb < total_disk_needed:
                    logger.error(
                        f"Insufficient storage space: need {total_disk_needed}GB, "
                        f"available {available_gb:.2f}GB"
                    )
                    raise CloudManagerError("Insufficient storage space for cluster")
                logger.debug("Storage space check passed")
        except Exception as e:
            if isinstance(e, CloudManagerError):
                raise
            logger.warning(f"Could not verify storage space: {e}")

    def _create_cluster_infrastructure(self) -> None:
        """Create cluster network and storage pool (no rollback manager for cloud)."""
        logger.debug("Creating cluster infrastructure")

        cluster_name = self.cloud_config["name"]
        base_image = Path(self.cloud_config["base_image_path"])
        pool_path = Path("/var/lib/libvirt/images")
        network_config = self.cloud_config["network"].copy()

        logger.debug(f"Creating infrastructure for cluster: {cluster_name}")
        logger.debug(f"Base image: {base_image}")
        logger.debug(f"Pool path: {pool_path}")

        # Prepare static DHCP reservations from VM configurations (using parent class method)
        static_leases, vm_macs = self._prepare_static_dhcp_leases(cluster_name, self.cloud_config)

        # Add static leases to network configuration
        if static_leases:
            network_config["static_leases"] = static_leases
            network_config["vm_macs"] = vm_macs

        try:
            # Create cluster virtual network
            logger.debug("Creating cluster virtual network")
            network_name = self.network_manager.create_cluster_network(cluster_name, network_config)
            logger.debug(f"Created and started network: {network_name}")
            self.network_manager.start_network(cluster_name)

            # Create cluster storage pool
            logger.debug("Creating cluster storage pool")
            pool_name = self.volume_manager.create_cluster_pool(cluster_name, pool_path, base_image)
            logger.debug(f"Created storage pool: {pool_name}")

        except Exception as e:
            logger.error(f"Failed to create cluster infrastructure: {e}")
            raise CloudManagerError(f"Failed to create cluster infrastructure: {e}") from e

    def _setup_cluster_networking(self, cluster_state: ClusterState) -> None:
        """Set up network configuration."""
        network_config = NetworkConfig(
            subnet=self.cloud_config["network"]["subnet"],
            bridge=self.cloud_config["network"]["bridge"],
        )
        cluster_state.network_config = network_config

    def _create_and_start_vms(self, cluster_state: ClusterState) -> None:
        """Create and start all VMs for the cluster."""
        # Create control plane VM
        if "control_plane" in self.cloud_config:
            self._create_control_plane_vm(cluster_state)
            control_plane_vm = cluster_state.controller
            if control_plane_vm:
                self._start_vm_if_needed(control_plane_vm)

        # Create worker nodes
        if "worker_nodes" in self.cloud_config:
            self._create_worker_nodes(cluster_state)

            # Get config for determining which workers to auto-start
            worker_nodes_config = self.cloud_config.get("worker_nodes", [])

            # Separate workers by type for auto-start resolution
            cpu_workers_configs = []
            gpu_workers_configs = []

            if isinstance(worker_nodes_config, list):
                for worker_config in worker_nodes_config:
                    if self._has_gpu(worker_config):
                        gpu_workers_configs.append(worker_config)
                    else:
                        cpu_workers_configs.append(worker_config)

            # Use AutoStartResolver to get indices of workers that should not auto-start
            cpu_no_start_indices = AutoStartResolver.get_no_start_indices(cpu_workers_configs)
            gpu_no_start_indices = AutoStartResolver.get_no_start_indices(gpu_workers_configs)

            # Track worker counters for matching
            cpu_counter = 0
            gpu_counter = 0

            for worker_vm in cluster_state.worker_nodes:
                if worker_vm.vm_type == "cpu":
                    if cpu_counter in cpu_no_start_indices:
                        logger.info(
                            f"Skipping auto-start for CPU worker: {worker_vm.name} "
                            "(auto_start: false)"
                        )
                        cpu_counter += 1
                        continue
                    cpu_counter += 1
                elif worker_vm.vm_type == "gpu":
                    if gpu_counter in gpu_no_start_indices:
                        logger.info(
                            f"Skipping auto-start for GPU worker: {worker_vm.name} "
                            "(auto_start: false)"
                        )
                        gpu_counter += 1
                        continue
                    gpu_counter += 1

                # Start all workers that should be auto-started
                self._start_vm_if_needed(worker_vm)

    def _should_auto_start_vm(self, vm_info: VMInfo) -> bool:  # noqa: ARG002
        """Check if a VM should be auto-started based on configuration.

        Args:
            vm_info: VM information (unused, kept for backward compatibility)

        Returns:
            True if VM should be auto-started, False otherwise
        """
        # This method is deprecated - auto-start is now handled by AutoStartResolver
        # in _create_and_start_vms(). Kept for backward compatibility.
        return True

    def _create_control_plane_vm(self, cluster_state: ClusterState) -> None:
        """Create control plane VM."""
        control_plane_config = self.cloud_config["control_plane"]
        vm_name = f"{self.cluster_name}-control-plane"
        cluster_name = self.cluster_name

        # Skip if VM already exists in state
        if cluster_state.controller:
            logger.info(f"Control plane VM {vm_name} already exists, skipping")
            return

        # Create volume
        try:
            volume_path = self.volume_manager.create_vm_volume(
                cluster_name=cluster_name,
                vm_name=vm_name,
                size_gb=control_plane_config["disk_gb"],
                vm_type="controller",
            )
        except VolumeManagerError as e:
            raise CloudManagerError(f"Failed to create control plane volume: {e}") from e

        # Use static IP address from configuration
        static_ip = control_plane_config.get("ip_address")
        if static_ip:
            allocated_ip = static_ip
            logger.debug(f"Using static IP {allocated_ip} for control plane {vm_name}")
        else:
            # Fallback to dynamic allocation if no static IP configured
            try:
                allocated_ip = self.network_manager.allocate_ip_address(cluster_name, vm_name)
                logger.debug(f"Allocated dynamic IP {allocated_ip} for control plane {vm_name}")
            except NetworkManagerError as e:
                raise CloudManagerError(f"Failed to allocate IP for control plane: {e}") from e

        # Generate VM XML (uses inherited method)
        xml_config = self._generate_vm_xml(
            vm_name=vm_name,
            template_name="controller.xml.j2",
            cpu_cores=control_plane_config["cpu_cores"],
            memory_gb=control_plane_config["memory_gb"],
            volume_path=Path(volume_path),
            ip_address=allocated_ip,
            pcie_passthrough=control_plane_config.get("pcie_passthrough"),
        )

        # Create VM
        try:
            domain_uuid = self.vm_lifecycle.create_vm(vm_name, xml_config)
        except VMLifecycleError as e:
            raise CloudManagerError(f"Failed to create control plane VM: {e}") from e

        # Create VM info and add to state
        vm_info = VMInfo(
            name=vm_name,
            domain_uuid=domain_uuid,
            state=VMState.SHUTOFF,
            cpu_cores=control_plane_config["cpu_cores"],
            memory_gb=control_plane_config["memory_gb"],
            volume_path=Path(volume_path),
            vm_type="controller",
            ip_address=allocated_ip,
        )

        cluster_state.controller = vm_info
        logger.info(f"Created control plane VM: {vm_name}")

    @staticmethod
    def _has_gpu(worker_config: dict[str, Any]) -> bool:
        """Check if worker configuration has GPU passthrough enabled.

        Args:
            worker_config: Worker node configuration dictionary

        Returns:
            True if worker has GPU devices configured, False otherwise
        """
        pcie_config = worker_config.get("pcie_passthrough", {})
        if not pcie_config.get("enabled", False):
            return False

        devices = pcie_config.get("devices", [])
        return any(dev.get("device_type") == "gpu" for dev in devices)

    def _create_worker_nodes(self, cluster_state: ClusterState) -> None:
        """Create worker nodes (both CPU and GPU types).

        Worker type is determined by presence of GPU in pcie_passthrough configuration.
        """
        cluster_name = self.cluster_name
        worker_nodes_config = self.cloud_config.get("worker_nodes", [])

        # Ensure worker_nodes is a list
        if not isinstance(worker_nodes_config, list):
            logger.warning(
                f"worker_nodes expected to be a list, got {type(worker_nodes_config).__name__}"
            )
            return

        # Track separate counters for CPU and GPU workers
        cpu_counter = 0
        gpu_counter = 0

        for worker_config in worker_nodes_config:
            # Determine worker type based on GPU presence
            has_gpu = self._has_gpu(worker_config)
            worker_type = "gpu" if has_gpu else "cpu"

            # Increment appropriate counter
            if worker_type == "gpu":
                gpu_counter += 1
                vm_name = f"{cluster_name}-gpu-worker-{gpu_counter:02d}"
            else:
                cpu_counter += 1
                vm_name = f"{cluster_name}-cpu-worker-{cpu_counter:02d}"

            self._create_worker_vm(cluster_name, vm_name, worker_config, cluster_state, worker_type)

    def _create_worker_vm(
        self,
        cluster_name: str,
        vm_name: str,
        worker_config: dict,
        cluster_state: ClusterState,
        worker_type: str,
    ) -> None:
        """Create a single worker VM."""
        # Skip if VM already exists in state
        if cluster_state.get_vm_by_name(vm_name):
            logger.info(f"Worker VM {vm_name} already exists, skipping")
            return

        # Create volume
        try:
            volume_path = self.volume_manager.create_vm_volume(
                cluster_name=cluster_name,
                vm_name=vm_name,
                size_gb=worker_config["disk_gb"],
                vm_type="worker",
            )
        except VolumeManagerError as e:
            raise CloudManagerError(f"Failed to create worker volume for {vm_name}: {e}") from e

        # Use static IP address from configuration
        static_ip = worker_config.get("ip")
        if static_ip:
            allocated_ip = static_ip
            logger.debug(f"Using static IP {allocated_ip} for worker {vm_name}")
        else:
            # Fallback to dynamic allocation if no static IP configured
            try:
                allocated_ip = self.network_manager.allocate_ip_address(cluster_name, vm_name)
                logger.debug(f"Allocated dynamic IP {allocated_ip} for worker {vm_name}")
            except NetworkManagerError as e:
                raise CloudManagerError(f"Failed to allocate IP for {vm_name}: {e}") from e

        # Generate VM XML - use worker template if available, otherwise compute
        template_name = (
            "worker.xml.j2" if self._template_exists("worker.xml.j2") else "compute_node.xml.j2"
        )
        xml_config = self._generate_vm_xml(
            vm_name=vm_name,
            template_name=template_name,
            cpu_cores=worker_config["cpu_cores"],
            memory_gb=worker_config["memory_gb"],
            volume_path=Path(volume_path),
            ip_address=allocated_ip,
            pcie_passthrough=worker_config.get("pcie_passthrough"),
        )

        # Create VM
        try:
            domain_uuid = self.vm_lifecycle.create_vm(vm_name, xml_config)
        except VMLifecycleError as e:
            raise CloudManagerError(f"Failed to create worker VM {vm_name}: {e}") from e

        # Create VM info and add to state
        vm_info = VMInfo(
            name=vm_name,
            domain_uuid=domain_uuid,
            state=VMState.SHUTOFF,
            cpu_cores=worker_config["cpu_cores"],
            memory_gb=worker_config["memory_gb"],
            volume_path=Path(volume_path),
            vm_type=worker_type,
            ip_address=allocated_ip,
        )

        cluster_state.add_vm(vm_info)
        logger.info(f"Created worker VM: {vm_name} (type={worker_type})")

    def _start_vm_if_needed(self, vm_info: VMInfo) -> None:
        """Start VM if it's not already running."""
        try:
            current_state = self.vm_lifecycle.get_vm_state(vm_info.name)
            if current_state != VMState.RUNNING:
                self.vm_lifecycle.start_vm(vm_info.name)
                vm_info.update_state(VMState.RUNNING)
                logger.info(f"Started VM: {vm_info.name}")
            else:
                logger.info(f"VM {vm_info.name} is already running")
        except VMLifecycleError as e:
            logger.error(f"Failed to start VM {vm_info.name}: {e}")
            raise CloudManagerError(f"Failed to start VM {vm_info.name}: {e}") from e

    def _generate_vm_xml(
        self,
        vm_name: str,
        template_name: str,
        cpu_cores: int,
        memory_gb: int,
        volume_path: Path,
        ip_address: str | None = None,
        pcie_passthrough: dict | None = None,
    ) -> str:
        """Generate VM XML configuration from template."""
        try:
            template = self.template_env.get_template(template_name)

            # Get hardware configuration from cluster config
            hardware_config = self.cloud_config.get("hardware", {})

            template_vars = {
                # Basic VM configuration
                "vm_name": vm_name,
                "vm_uuid": str(uuid.uuid4()),
                "cpu_cores": cpu_cores,
                "memory_gb": memory_gb,
                "disk_path": str(volume_path),
                "cluster_name": self.cluster_name,
                "ip_address": ip_address,
                # Hardware acceleration configuration
                "hardware": hardware_config,
                # PCIe passthrough configuration (per-VM)
                "pcie_passthrough": pcie_passthrough or {},
                # MAC address generation for network
                "mac_address": self._generate_mac_address(vm_name),
            }

            xml_config = template.render(**template_vars)
            return xml_config

        except TemplateNotFound as e:
            raise CloudManagerError(f"Template not found: {e}") from e
        except Exception as e:
            raise CloudManagerError(f"Failed to generate VM XML: {e}") from e

    def _generate_mac_address(self, vm_name: str) -> str:
        """Generate consistent MAC address for VM based on name."""
        import hashlib

        # Create deterministic MAC address based on VM name
        hash_object = hashlib.md5(vm_name.encode())
        hex_dig = hash_object.hexdigest()

        # Use first 6 bytes and ensure it's a valid MAC
        mac_bytes = [hex_dig[i : i + 2] for i in range(0, 12, 2)]

        # Ensure first byte is even (unicast) and has local admin bit set
        mac_bytes[0] = f"{(int(mac_bytes[0], 16) & 0xFE) | 0x02:02x}"

        return ":".join(mac_bytes)

    def _template_exists(self, template_name: str) -> bool:
        """Check if a template exists."""
        try:
            self.template_env.get_template(template_name)
            return True
        except TemplateNotFound:
            return False

    def stop_cluster(self) -> bool:
        """Stop the Cloud cluster.

        Returns:
            True if cluster stopped successfully

        Raises:
            CloudManagerError: If cluster stop fails
        """
        try:
            logger.info("Stopping Cloud cluster")

            cluster_state = self.state_manager.get_state()
            if not cluster_state:
                logger.info("No cluster state found, nothing to stop")
                return True

            # Stop all VMs (inherited from parent)
            all_vms = cluster_state.get_all_vms()
            for vm in all_vms:
                try:
                    if self.vm_lifecycle.get_vm_state(vm.name) == VMState.RUNNING:
                        self.vm_lifecycle.stop_vm(vm.name, force=False)
                        vm.update_state(VMState.SHUTOFF)
                except VMLifecycleError as e:
                    logger.warning(f"Failed to stop VM {vm.name}: {e}")

            # Release GPUs (inherited from parent)
            self._release_cluster_gpus()

            self.state_manager.save_state(cluster_state)
            logger.info("Cloud cluster stopped successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to stop cloud cluster: {e}")
            raise CloudManagerError(f"Failed to stop cloud cluster: {e}") from e

    def _release_cluster_gpus(self) -> None:
        """Release GPU resources allocated to this cluster."""
        cluster_state = self.state_manager.get_state()
        if not cluster_state:
            return

        all_vms = cluster_state.get_all_vms()
        for vm in all_vms:
            if vm.gpu_assigned:
                # Use GPUAddressParser to extract PCI address
                pci_address = GPUAddressParser.extract_pci_address(vm.gpu_assigned)
                if pci_address:
                    self.gpu_allocator.release_gpu(pci_address)

    def status(self) -> dict[str, Any]:
        """Get cluster status.

        Returns:
            Status dictionary
        """
        cluster_state = self.state_manager.get_state()
        if not cluster_state:
            return {"status": "not_created"}

        return cluster_state.get_cluster_status()

    def destroy_cluster(self, force: bool = True) -> bool:  # noqa: ARG002
        """Destroy the Cloud cluster.

        Args:
            force: Force destruction even if VMs are running (default: True)
                   Currently unused, reserved for future use.

        Returns:
            True if cluster destroyed successfully
        """
        try:
            logger.info("Destroying Cloud cluster")

            cluster_state = self.state_manager.get_state()
            cluster_name = self.cloud_config["name"]

            if not cluster_state:
                logger.info("No cluster state found, discovering VMs by name pattern")
                # Discover VMs by name pattern when no state is available
                vm_names = self._discover_cluster_vms(cluster_name)
                if vm_names:
                    # Destroy discovered VMs
                    for vm_name in vm_names:
                        try:
                            if self.vm_lifecycle.vm_exists(vm_name):
                                logger.info(f"Destroying VM: {vm_name}")
                                self.vm_lifecycle.destroy_vm(vm_name, remove_storage=False)

                            # Clean up volume
                            try:
                                self.volume_manager.destroy_vm_volume(cluster_name, vm_name)
                            except Exception as e:
                                logger.warning(f"Failed to destroy volume for VM {vm_name}: {e}")

                        except VMLifecycleError as e:
                            logger.warning(f"Failed to destroy VM {vm_name}: {e}")
                else:
                    logger.info("No cluster VMs found")
            else:
                # Stop all VMs first
                self.stop_cluster()

                # Destroy all VMs from state
                all_vms = cluster_state.get_all_vms()
                for vm in all_vms:
                    try:
                        if self.vm_lifecycle.vm_exists(vm.name):
                            logger.info(f"Destroying VM: {vm.name}")
                            self.vm_lifecycle.destroy_vm(vm.name, remove_storage=False)

                        # Clean up volume
                        try:
                            self.volume_manager.destroy_vm_volume(cluster_name, vm.name)
                        except Exception as e:
                            logger.warning(f"Failed to destroy volume for VM {vm.name}: {e}")

                    except VMLifecycleError as e:
                        logger.warning(f"Failed to destroy VM {vm.name}: {e}")

            # Destroy cluster storage pool
            try:
                logger.info(f"Destroying storage pool for cluster: {cluster_name}")
                self.volume_manager.destroy_cluster_pool(cluster_name, force=True)
            except Exception as e:
                logger.warning(f"Failed to destroy cluster storage pool: {e}")

            # Destroy cluster virtual network
            try:
                logger.info(f"Destroying network for cluster: {cluster_name}")
                self.network_manager.destroy_cluster_network(cluster_name, force=True)
            except Exception as e:
                logger.warning(f"Failed to destroy cluster network: {e}")

            # Clear state file
            self.state_manager.state_file.unlink(missing_ok=True)

            logger.info("Cloud cluster destroyed successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to destroy cloud cluster: {e}")
            raise CloudManagerError(f"Failed to destroy cloud cluster: {e}") from e

    def _discover_cluster_vms(self, cluster_name: str) -> list[str]:
        """Discover VMs that belong to this cluster by name pattern.

        Used when state file is missing to find orphaned VMs.

        Args:
            cluster_name: Name of the cluster

        Returns:
            List of VM names that match the cluster pattern
        """
        try:
            logger.info(f"Discovering VMs for cluster: {cluster_name}")

            # Get all VMs from libvirt
            all_vms = self.vm_lifecycle.list_vms()
            logger.debug(f"Found {len(all_vms)} total VMs in libvirt")

            # Filter VMs that match the cluster name pattern
            cluster_vms = []
            for vm_name in all_vms:
                if vm_name.startswith(f"{cluster_name}-"):
                    cluster_vms.append(vm_name)
                    logger.debug(f"Found cluster VM: {vm_name}")

            logger.info(f"Discovered {len(cluster_vms)} VMs for cluster {cluster_name}")
            return cluster_vms

        except VMLifecycleError as e:
            logger.warning(f"Failed to discover cluster VMs: {e}")
            return []
        except Exception as e:
            logger.error(f"Unexpected error discovering cluster VMs: {e}")
            return []

    def generate_kubespray_inventory(
        self, config_file: Path, output_path: Path | None = None
    ) -> Path:
        """Generate Kubespray inventory for the cloud cluster.

        Args:
            config_file: Path to cluster configuration file
            output_path: Optional path for inventory output (defaults to standard location)

        Returns:
            Path to generated inventory file

        Raises:
            CloudManagerError: If inventory generation fails
        """
        log_function_entry(logger, "generate_kubespray_inventory", config_file=config_file)

        try:
            # Determine project root and inventory output path
            project_root = self._get_project_root(config_file)
            if output_path is None:
                inventory_dir = project_root / "ansible" / "inventories" / "cloud-cluster"
                inventory_dir.mkdir(parents=True, exist_ok=True)
                output_path = inventory_dir / "inventory.ini"

            logger.info(f"Generating Kubespray inventory: {output_path}")

            # Get cluster name
            cluster_name = self.cloud_config.get("name", "cloud")

            # Generate inventory using Python script
            script_path = project_root / "scripts" / "generate-kubespray-inventory.py"
            if not script_path.exists():
                raise CloudManagerError(f"Inventory generation script not found: {script_path}")

            cmd = [
                "python3",
                str(script_path),
                str(config_file),
                cluster_name,
                str(output_path),
            ]

            result = run_subprocess_with_logging(
                cmd,
                logger,
                cwd=project_root,
                check=True,
                operation_description="Generate Kubespray inventory",
            )

            logger.debug(f"Kubespray inventory result: {result}")

            if not output_path.exists():
                raise CloudManagerError(f"Inventory file was not created: {output_path}")

            logger.info(f"✅ Kubespray inventory generated: {output_path}")
            log_function_exit(logger, "generate_kubespray_inventory", output_path)
            return output_path

        except subprocess.CalledProcessError as e:
            logger.error(f"Inventory generation failed: {e}")
            raise CloudManagerError(f"Failed to generate Kubespray inventory: {e}") from e
        except Exception as e:
            logger.error(f"Unexpected error generating inventory: {e}")
            raise CloudManagerError(f"Failed to generate Kubespray inventory: {e}") from e

    def deploy_kubernetes(
        self,
        config_file: Path,
        inventory_path: Path | None = None,
        wait_for_ssh: bool = True,
        ssh_timeout: int = 300,
    ) -> bool:
        """Deploy Kubernetes cluster using Kubespray.

        Args:
            config_file: Path to cluster configuration file
            inventory_path: Optional path to inventory file (generated if not provided)
            wait_for_ssh: Whether to wait for VMs to be SSH-accessible before deploying
            ssh_timeout: Timeout in seconds for SSH readiness

        Returns:
            True if deployment succeeded

        Raises:
            CloudManagerError: If deployment fails
        """
        log_function_entry(
            logger,
            "deploy_kubernetes",
            config_file=config_file,
            inventory_path=inventory_path,
        )

        try:
            # Generate inventory if not provided
            if inventory_path is None:
                logger.info("Generating Kubespray inventory...")
                inventory_path = self.generate_kubespray_inventory(config_file)

            # Wait for VMs to be SSH-accessible if requested
            if wait_for_ssh:
                logger.info("Waiting for VMs to be SSH-accessible...")
                self._wait_for_vms_ssh_ready(ssh_timeout)

            # Verify Kubespray is installed
            project_root = self._get_project_root(config_file)
            kubespray_dir = project_root / "build" / "3rd-party" / "kubespray" / "kubespray-src"
            cluster_yml = kubespray_dir / "cluster.yml"

            if not cluster_yml.exists():
                raise CloudManagerError(
                    f"Kubespray not installed. Expected: {cluster_yml}\n"
                    f"Install with: cmake --build build --target install-kubespray"
                )

            # Run Ansible playbook to deploy Kubernetes
            logger.info("Deploying Kubernetes cluster with Kubespray...")

            playbook_path = project_root / "ansible" / "playbooks" / "deploy-cloud-cluster.yml"

            if not playbook_path.exists():
                raise CloudManagerError(f"Deployment playbook not found: {playbook_path}")

            # Change to ansible directory for Ansible execution
            ansible_dir = project_root / "ansible"

            cmd = [
                "ansible-playbook",
                "-i",
                str(inventory_path.relative_to(ansible_dir)),
                str(playbook_path.relative_to(ansible_dir)),
            ]

            result = run_subprocess_with_logging(
                cmd,
                logger,
                cwd=ansible_dir,
                check=True,
                timeout=3600,  # 1 hour timeout for Kubernetes deployment
                operation_description="Deploy Kubernetes cluster with Kubespray",
            )

            if not result.success:
                raise CloudManagerError(
                    f"Kubernetes deployment failed with exit code {result.returncode}"
                )

            logger.info("✅ Kubernetes cluster deployed successfully")
            log_function_exit(logger, "deploy_kubernetes", True)
            return True

        except subprocess.CalledProcessError as e:
            logger.error(f"Kubernetes deployment failed: {e}")
            raise CloudManagerError(f"Failed to deploy Kubernetes cluster: {e}") from e
        except Exception as e:
            logger.error(f"Unexpected error during Kubernetes deployment: {e}")
            raise CloudManagerError(f"Failed to deploy Kubernetes cluster: {e}") from e

    def _wait_for_vms_ssh_ready(self, timeout: int = 300) -> None:
        """Wait for all cluster VMs to be SSH-accessible.

        Args:
            timeout: Maximum time to wait in seconds

        Raises:
            CloudManagerError: If timeout is reached
        """
        import time

        logger.info(f"Waiting for VMs to be SSH-accessible (timeout: {timeout}s)...")

        cluster_state = self.state_manager.get_state()
        if not cluster_state:
            raise CloudManagerError("Cannot wait for SSH: cluster state not found")

        all_vms = cluster_state.get_all_vms()
        if not all_vms:
            logger.warning("No VMs found in cluster state")
            return

        start_time = time.time()
        check_interval = 10  # Check every 10 seconds

        # Get SSH key and username from environment or defaults
        ssh_key_path = Path.home() / ".ssh" / "id_rsa"
        if not ssh_key_path.exists():
            # Use state manager's state file to find project root
            project_root = self._get_project_root(self.state_manager.state_file)
            ssh_key_path = project_root / "build" / "shared" / "ssh-keys" / "id_rsa"

        ssh_username = "admin"  # Default from Packer build

        while time.time() - start_time < timeout:
            ready_count = 0
            for vm in all_vms:
                if not vm.ip_address:
                    continue

                # Test SSH connectivity
                try:
                    cmd = [
                        "ssh",
                        "-i",
                        str(ssh_key_path),
                        "-o",
                        "StrictHostKeyChecking=no",
                        "-o",
                        "ConnectTimeout=5",
                        "-o",
                        "UserKnownHostsFile=/dev/null",
                        f"{ssh_username}@{vm.ip_address}",
                        "echo 'SSH ready'",
                    ]

                    result = subprocess.run(cmd, capture_output=True, timeout=5, check=False)

                    if result.returncode == 0:
                        ready_count += 1
                        logger.debug(f"VM {vm.name} ({vm.ip_address}) is SSH-ready")
                    else:
                        logger.debug(f"VM {vm.name} ({vm.ip_address}) not yet ready")

                except (subprocess.TimeoutExpired, FileNotFoundError):
                    logger.debug(f"SSH test failed for {vm.name}")

            if ready_count == len([v for v in all_vms if v.ip_address]):
                logger.info(f"✅ All {ready_count} VMs are SSH-accessible")
                return

            elapsed = int(time.time() - start_time)
            logger.debug(
                f"SSH readiness: {ready_count}/{len([v for v in all_vms if v.ip_address])} "
                f"VMs ready (elapsed: {elapsed}s/{timeout}s)"
            )
            time.sleep(check_interval)

        raise CloudManagerError(f"Timeout waiting for VMs to be SSH-accessible ({timeout}s)")
