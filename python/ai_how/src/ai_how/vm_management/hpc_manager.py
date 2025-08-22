"""HPC cluster management using libvirt."""

import logging
import uuid
from collections.abc import Callable
from functools import lru_cache
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader, TemplateNotFound

from ai_how.state.cluster_state import ClusterState, ClusterStateManager, VMInfo, VMState
from ai_how.state.models import NetworkConfig
from ai_how.utils.logging import (
    log_function_entry,
    log_function_exit,
    log_operation_start,
    log_operation_success,
)
from ai_how.vm_management.libvirt_client import LibvirtClient, LibvirtConnectionError
from ai_how.vm_management.network_manager import NetworkManager, NetworkManagerError
from ai_how.vm_management.vm_lifecycle import VMLifecycleError, VMLifecycleManager
from ai_how.vm_management.volume_manager import VolumeManager, VolumeManagerError
from ai_how.vm_management.xml_tracer import XMLTracer

logger = logging.getLogger(__name__)


class RollbackManager:
    """Manages rollback operations for failed cluster operations.

    Includes volume and network cleanup functionality.
    """

    def __init__(self, volume_manager: VolumeManager, network_manager: NetworkManager) -> None:
        self.rollback_stack: list[tuple] = []
        self.volume_manager = volume_manager
        self.network_manager = network_manager

    def add_vm_volume_rollback(self, cluster_name: str, vm_name: str) -> None:
        """Add VM volume destruction to rollback stack."""
        self.add_rollback_action(self.volume_manager.destroy_vm_volume, cluster_name, vm_name)

    def add_pool_rollback(self, cluster_name: str) -> None:
        """Add storage pool destruction to rollback stack."""
        self.add_rollback_action(self.volume_manager.destroy_cluster_pool, cluster_name, force=True)

    def add_network_rollback(self, cluster_name: str) -> None:
        """Add network destruction to rollback stack."""
        self.add_rollback_action(
            self.network_manager.destroy_cluster_network, cluster_name, force=True
        )

    def add_dns_cleanup_rollback(self, cluster_name: str) -> None:
        """Add DNS cleanup to rollback stack."""
        self.add_rollback_action(self.network_manager.remove_host_dns_integration, cluster_name)

    def add_ip_release_rollback(self, cluster_name: str, vm_name: str) -> None:
        """Add IP address release to rollback stack."""
        self.add_rollback_action(self.network_manager.release_ip_address, cluster_name, vm_name)

    def add_rollback_action(self, action: Callable, *args, **kwargs) -> None:
        """Add action to rollback stack."""
        self.rollback_stack.append((action, args, kwargs))

    def execute_rollback(self) -> None:
        """Execute all rollback actions in reverse order."""
        logger.info(f"Executing rollback with {len(self.rollback_stack)} actions")

        while self.rollback_stack:
            action, args, kwargs = self.rollback_stack.pop()
            try:
                action(*args, **kwargs)
                logger.debug(f"Executed rollback action: {action.__name__}")
            except Exception as e:
                logger.warning(f"Rollback action failed: {action.__name__}: {e}")


@lru_cache(maxsize=32)
def _get_cached_template(template_env: Environment, template_name: str):
    """Cache rendered templates to avoid repeated I/O.

    Args:
        template_env: Jinja2 environment
        template_name: Name of the template file

    Returns:
        Jinja2 template object
    """
    return template_env.get_template(template_name)


class HPCManagerError(Exception):
    """Raised when HPC cluster management operations fail."""

    pass


class HPCClusterManager:
    """Manages HPC cluster lifecycle operations."""

    def __init__(self, config: dict[str, Any], state_file: Path, operation: str = "cluster"):
        """Initialize HPC cluster manager.

        Args:
            config: Cluster configuration dictionary
            state_file: Path to the state file
            operation: Type of operation for XML tracing (start, stop, destroy, etc.)
        """
        log_function_entry(logger, "__init__", state_file=state_file, operation=operation)

        self.config = config
        self.hpc_config = config["clusters"]["hpc"]
        self.global_config = config.get("global", {})

        logger.debug(f"HPC cluster name: {self.hpc_config['name']}")
        logger.debug(f"Base image path: {self.hpc_config['base_image_path']}")
        logger.debug(f"Network config: {self.hpc_config['network']}")
        logger.debug(f"Controller config: {self.hpc_config['controller']}")
        logger.debug(f"Compute nodes count: {len(self.hpc_config['compute_nodes'])}")

        # Initialize XML tracer for this operation
        cluster_name = self.hpc_config["name"]
        self.cluster_name = cluster_name  # Store as instance variable for template access
        logger.debug(
            f"Initializing XML tracer for cluster '{cluster_name}' operation '{operation}'"
        )
        self.xml_tracer = XMLTracer(cluster_name, operation)

        # Initialize components with XML tracing
        logger.debug("Initializing libvirt client with XML tracing")
        self.libvirt_client = LibvirtClient(xml_tracer=self.xml_tracer)

        logger.debug("Initializing VM lifecycle manager")
        self.vm_lifecycle = VMLifecycleManager(self.libvirt_client)

        logger.debug("Initializing volume manager")
        self.volume_manager = VolumeManager(self.libvirt_client)

        logger.debug("Initializing network manager")
        self.network_manager = NetworkManager(self.libvirt_client)

        logger.debug(f"Initializing state manager with file: {state_file}")
        self.state_manager = ClusterStateManager(state_file)

        # Initialize Jinja2 environment
        template_dir = Path(__file__).parent / "templates"
        logger.debug(f"Initializing Jinja2 environment with template directory: {template_dir}")
        self.template_env = Environment(
            loader=FileSystemLoader(template_dir), trim_blocks=True, lstrip_blocks=True
        )

        # Rollback manager
        logger.debug("Initializing rollback manager")
        self.rollback_manager = RollbackManager(self.volume_manager, self.network_manager)

        log_function_exit(logger, "__init__")

    def start_cluster(self) -> bool:
        """Start the complete HPC cluster with XML tracing.

        Returns:
            True if cluster started successfully

        Raises:
            HPCManagerError: If cluster start fails
        """
        log_function_entry(logger, "start_cluster")

        try:
            return self._execute_cluster_start()
        finally:
            # Always save XML trace regardless of success/failure
            trace_folder = self.save_xml_trace()
            logger.info(f"XML trace saved to folder: {trace_folder}")

    def _execute_cluster_start(self) -> bool:
        """Execute cluster start operation with full error handling."""
        try:
            log_operation_start(logger, "HPC cluster startup", cluster_name=self.hpc_config["name"])

            # 1. Validate configuration and prerequisites
            logger.debug("Step 1: Validating configuration and prerequisites")
            self._validate_cluster_config()
            self._check_prerequisites()
            logger.debug("Configuration and prerequisites validation complete")

            # 2. Create cluster infrastructure (network and storage)
            logger.debug("Step 2: Creating cluster infrastructure")
            self._create_cluster_infrastructure()
            logger.debug("Cluster infrastructure created")

            # 3. Ensure cluster state exists
            logger.debug("Step 3: Ensuring cluster state exists")
            cluster_state = self.state_manager.ensure_state(
                cluster_name=self.hpc_config["name"], cluster_type="hpc"
            )
            logger.debug(f"Cluster state initialized: {cluster_state.cluster_name}")

            # 4. Set network configuration
            logger.debug("Step 4: Setting network configuration")
            self._setup_cluster_networking(cluster_state)
            logger.debug("Network configuration set")

            # 5. Create and start controller VM
            logger.debug("Step 5: Creating and starting controller VM")
            self._create_and_start_controller_vm(cluster_state)
            logger.debug("Controller VM is ready")

            # 6. Create and start compute nodes
            logger.debug("Step 6: Creating and starting compute nodes")
            self._create_and_start_compute_nodes(cluster_state)
            logger.debug("All compute nodes are ready")

            # 7. Save final state
            logger.debug("Step 7: Saving final cluster state")
            self.state_manager.save_state(cluster_state)
            logger.debug("Cluster state saved successfully")

            log_operation_success(
                logger,
                "HPC cluster startup",
                cluster_name=self.hpc_config["name"],
                total_vms=len(cluster_state.get_all_vms()),
            )

            log_function_exit(logger, "start_cluster", result=True)
            return True

        except Exception as e:
            logger.error(f"Failed to start HPC cluster: {e}")
            logger.debug("Executing rollback due to startup failure")
            self.rollback_manager.execute_rollback()
            raise HPCManagerError(f"Failed to start HPC cluster: {e}") from e

    def _setup_cluster_networking(self, cluster_state) -> None:
        """Set up network configuration for the cluster.

        Args:
            cluster_state: The cluster state object to configure
        """
        network_config = NetworkConfig(
            subnet=self.hpc_config["network"]["subnet"],
            bridge=self.hpc_config["network"]["bridge"],
        )
        cluster_state.network_config = network_config
        logger.debug(
            f"Network config set: subnet={network_config.subnet}, bridge={network_config.bridge}"
        )

    def _create_and_start_controller_vm(self, cluster_state) -> None:
        """Create and start the controller VM if needed.

        Args:
            cluster_state: The cluster state object
        """
        if not cluster_state.controller:
            logger.debug("Controller VM not found in state, creating new one")
            self._create_controller_vm(cluster_state)
        else:
            logger.debug("Controller VM found in state, reusing")

        if cluster_state.controller:
            self._start_vm_if_needed(cluster_state.controller)

    def _create_and_start_compute_nodes(self, cluster_state) -> None:
        """Create and start all compute nodes.

        Args:
            cluster_state: The cluster state object
        """
        self._create_compute_nodes(cluster_state)
        logger.debug(f"Processing {len(cluster_state.compute_nodes)} compute nodes")

        for i, compute_node in enumerate(cluster_state.compute_nodes):
            logger.debug(
                f"Starting compute node {i + 1}/{len(cluster_state.compute_nodes)}: "
                f"{compute_node.name}"
            )
            self._start_vm_if_needed(compute_node)

    def stop_cluster(self) -> bool:
        """Stop the HPC cluster gracefully with XML tracing.

        Returns:
            True if cluster stopped successfully

        Raises:
            HPCManagerError: If cluster stop fails
        """
        try:
            return self._execute_cluster_stop()
        finally:
            # Always save XML trace regardless of success/failure
            trace_folder = self.save_xml_trace()
            logger.info(f"XML trace saved to folder: {trace_folder}")

    def _execute_cluster_stop(self) -> bool:
        """Execute cluster stop operation."""
        try:
            logger.info("Stopping HPC cluster")

            cluster_state = self.state_manager.get_state()
            if not cluster_state:
                logger.info("No cluster state found, nothing to stop")
                return True

            # Stop all VMs
            all_vms = cluster_state.get_all_vms()
            for vm in all_vms:
                try:
                    if self.vm_lifecycle.get_vm_state(vm.name) == VMState.RUNNING:
                        self.vm_lifecycle.stop_vm(vm.name, force=False)
                        vm.update_state(VMState.SHUTOFF)
                except VMLifecycleError as e:
                    logger.warning(f"Failed to stop VM {vm.name}: {e}")

            # Update state
            self.state_manager.save_state(cluster_state)

            logger.info("HPC cluster stopped successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to stop HPC cluster: {e}")
            raise HPCManagerError(f"Failed to stop HPC cluster: {e}") from e

    def destroy_cluster(self) -> bool:
        """Destroy the HPC cluster and clean up resources with XML tracing.

        Returns:
            True if cluster destroyed successfully

        Raises:
            HPCManagerError: If cluster destruction fails
        """
        try:
            return self._execute_cluster_destroy()
        finally:
            # Always save XML trace regardless of success/failure
            trace_folder = self.save_xml_trace()
            logger.info(f"XML trace saved to folder: {trace_folder}")

    def _execute_cluster_destroy(self) -> bool:
        """Execute cluster destroy operation."""
        try:
            logger.info("Destroying HPC cluster")

            cluster_state = self.state_manager.get_state()
            if not cluster_state:
                logger.info("No cluster state found, nothing to destroy")
                return True

            # Destroy all VMs
            all_vms = cluster_state.get_all_vms()
            for vm in all_vms:
                try:
                    if self.vm_lifecycle.vm_exists(vm.name):
                        self.vm_lifecycle.destroy_vm(vm.name, remove_storage=False)

                    # Clean up volume
                    try:
                        self.volume_manager.destroy_vm_volume(cluster_state.cluster_name, vm.name)
                    except VolumeManagerError as e:
                        logger.warning(f"Failed to destroy volume for VM {vm.name}: {e}")

                except (VMLifecycleError, VolumeManagerError) as e:
                    logger.warning(f"Failed to destroy VM {vm.name}: {e}")

            # Destroy cluster storage pool
            try:
                self.volume_manager.destroy_cluster_pool(cluster_state.cluster_name, force=True)
            except VolumeManagerError as e:
                logger.warning(f"Failed to destroy cluster storage pool: {e}")

            # Destroy cluster virtual network
            try:
                self.network_manager.destroy_cluster_network(cluster_state.cluster_name, force=True)
            except NetworkManagerError as e:
                logger.warning(f"Failed to destroy cluster network: {e}")

            # Clear cluster state
            self.state_manager.clear_state()

            logger.info("HPC cluster destroyed successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to destroy HPC cluster: {e}")
            raise HPCManagerError(f"Failed to destroy HPC cluster: {e}") from e

    def status_cluster(self) -> dict[str, Any]:
        """Get cluster status information.

        Returns:
            Dictionary with cluster status details
        """
        try:
            cluster_state = self.state_manager.get_state()
            if not cluster_state:
                return {"status": "not_configured", "message": "Cluster not configured"}

            # Get basic cluster info
            status = cluster_state.get_cluster_status()

            # Add detailed VM status
            vm_statuses = []
            for vm in cluster_state.get_all_vms():
                try:
                    current_state = self.vm_lifecycle.get_vm_state(vm.name)
                    vm_statuses.append(
                        {
                            "name": vm.name,
                            "state": current_state.value,
                            "cpu_cores": vm.cpu_cores,
                            "memory_gb": vm.memory_gb,
                            "ip_address": vm.ip_address,
                            "gpu_assigned": vm.gpu_assigned,
                        }
                    )
                except VMLifecycleError:
                    vm_statuses.append(
                        {"name": vm.name, "state": "undefined", "error": "Failed to get VM state"}
                    )

            status["vms"] = vm_statuses
            return status

        except Exception as e:
            logger.error(f"Failed to get cluster status: {e}")
            return {"status": "error", "message": f"Failed to get cluster status: {e}"}

    def _validate_cluster_config(self) -> None:
        """Validate cluster configuration."""
        log_function_entry(logger, "_validate_cluster_config")

        logger.debug("Validating HPC cluster configuration")

        required_fields = ["name", "base_image_path", "network", "controller", "compute_nodes"]
        logger.debug(f"Checking required fields: {required_fields}")

        for field in required_fields:
            if field not in self.hpc_config:
                logger.error(f"Missing required field in HPC config: {field}")
                raise HPCManagerError(f"Missing required field in HPC config: {field}")
            logger.debug(f"Required field present: {field}")

        # Validate base image exists
        base_image = Path(self.hpc_config["base_image_path"])
        logger.debug(f"Validating base image exists: {base_image}")

        if not base_image.exists():
            logger.error(f"Base image not found: {base_image}")
            raise HPCManagerError(f"Base image not found: {base_image}")

        logger.debug(f"Base image exists: {base_image}")

        # Get base image info for debugging
        try:
            stat = base_image.stat()
            logger.debug(
                f"Base image size: {stat.st_size} bytes ({stat.st_size / (1024**3):.2f} GB)"
            )
        except OSError as e:
            logger.warning(f"Could not get base image stats: {e}")

        # Validate base image format using qemu-img
        try:
            logger.debug("Validating base image format")
            from ai_how.utils.logging import run_subprocess_with_logging

            cmd = ["qemu-img", "info", "--output=json", str(base_image)]
            result = run_subprocess_with_logging(
                cmd,
                logger,
                check=True,
                operation_description="Validating base image format",
            )

            import json

            info = json.loads(result.stdout)
            image_format = info.get("format", "unknown")

            if image_format != "qcow2":
                raise HPCManagerError(
                    f"Base image validation failed: expected qcow2 format but found "
                    f"'{image_format}' at '{base_image}'. Please use a valid qcow2 image file."
                )

            logger.debug("Base image format validation successful")

        except Exception as e:
            if isinstance(e, HPCManagerError):
                raise
            logger.error(f"Invalid base image format: {e}")
            raise HPCManagerError(f"Failed to validate base image: {e}") from e

        # Validate network configuration
        network_config = self.hpc_config["network"]
        logger.debug(f"Network configuration: {network_config}")

        if "subnet" not in network_config or "bridge" not in network_config:
            logger.error("Network configuration missing subnet or bridge")
            raise HPCManagerError("Network configuration must include subnet and bridge")

        # Enhanced network validation using NetworkManager
        try:
            logger.debug("Validating network configuration parameters")
            self.network_manager.validate_network_config(network_config)
            logger.debug("Network configuration validation passed")
        except NetworkManagerError as e:
            logger.error(f"Network configuration validation failed: {e}")
            raise HPCManagerError(f"Invalid network configuration: {e}") from e

        # Validate controller configuration
        controller_config = self.hpc_config["controller"]
        logger.debug(f"Controller configuration: {controller_config}")

        required_controller_fields = ["cpu_cores", "memory_gb", "disk_gb"]
        for field in required_controller_fields:
            if field not in controller_config:
                logger.error(f"Missing required controller field: {field}")
                raise HPCManagerError(f"Missing required controller field: {field}")

        # Validate compute nodes
        compute_nodes = self.hpc_config["compute_nodes"]
        logger.debug(f"Found {len(compute_nodes)} compute nodes to validate")

        for i, node in enumerate(compute_nodes):
            logger.debug(f"Validating compute node {i + 1}: {node}")
            required_node_fields = ["cpu_cores", "memory_gb", "disk_gb"]
            for field in required_node_fields:
                if field not in node:
                    logger.error(f"Missing required field in compute node {i + 1}: {field}")
                    raise HPCManagerError(
                        f"Missing required field in compute node {i + 1}: {field}"
                    )

        logger.debug("All configuration validation checks passed")
        log_function_exit(logger, "_validate_cluster_config")

    def _check_prerequisites(self) -> None:
        """Check system prerequisites."""
        log_function_entry(logger, "_check_prerequisites")

        logger.debug("Checking system prerequisites")

        # Test libvirt connection
        logger.debug("Testing libvirt connection")
        try:
            with self.libvirt_client.get_connection() as conn:
                # Get some basic system info for debugging
                try:
                    hostname = conn.getHostname()
                    logger.debug(f"Connected to libvirt host: {hostname}")
                except Exception as e:
                    logger.debug(f"Could not get hostname: {e}")

                try:
                    uri = conn.getURI()
                    logger.debug(f"libvirt URI: {uri}")
                except Exception as e:
                    logger.debug(f"Could not get URI: {e}")

            logger.debug("libvirt connection test successful")
        except LibvirtConnectionError as e:
            logger.error(f"libvirt connection failed: {e}")
            raise HPCManagerError(f"libvirt connection failed: {e}") from e

        # Check storage pool space requirements
        logger.debug("Checking storage pool space requirements")

        controller_disk = self.hpc_config["controller"]["disk_gb"]
        compute_disk_total = sum(node["disk_gb"] for node in self.hpc_config["compute_nodes"])
        total_disk_needed = controller_disk + compute_disk_total

        logger.debug(f"Controller disk requirement: {controller_disk}GB")
        logger.debug(f"Compute nodes disk requirement: {compute_disk_total}GB")
        logger.debug(f"Total disk requirement: {total_disk_needed}GB")

        try:
            # Check available space in default storage location
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
                    raise HPCManagerError("Insufficient storage space for cluster")

                logger.debug("Storage space check passed")
            else:
                logger.warning(f"Storage path {storage_path} does not exist, skipping space check")
        except Exception as e:
            logger.warning(f"Could not verify storage space: {e}")

        # Check for existing VMs with same names to avoid conflicts
        logger.debug("Checking for name conflicts with existing VMs")
        try:
            existing_domains = self.libvirt_client.list_domains()
            logger.debug(f"Found {len(existing_domains)} existing domains")

            cluster_name = self.hpc_config["name"]
            controller_name = f"{cluster_name}-controller"

            if controller_name in existing_domains:
                logger.warning(f"Controller VM name conflict detected: {controller_name}")

            for i in range(len(self.hpc_config["compute_nodes"])):
                compute_name = f"{cluster_name}-compute-{i + 1:02d}"
                if compute_name in existing_domains:
                    logger.warning(f"Compute node name conflict detected: {compute_name}")

        except Exception as e:
            logger.warning(f"Could not check for VM name conflicts: {e}")

        logger.debug("All prerequisite checks completed")
        log_function_exit(logger, "_check_prerequisites")

    def _create_cluster_infrastructure(self) -> None:
        """Create cluster network, storage pool and base infrastructure."""
        log_function_entry(logger, "_create_cluster_infrastructure")

        cluster_name = self.hpc_config["name"]
        base_image = Path(self.hpc_config["base_image_path"])
        pool_path = Path("/var/lib/libvirt/images")
        network_config = self.hpc_config["network"].copy()

        logger.debug(f"Creating infrastructure for cluster: {cluster_name}")
        logger.debug(f"Base image: {base_image}")
        logger.debug(f"Pool path: {pool_path}")
        logger.debug(f"Network config: {network_config}")

        # Prepare static DHCP reservations from VM configurations
        static_leases = {}
        vm_macs = {}

        # Add controller static lease if IP is configured
        controller_config = self.hpc_config["controller"]
        if "ip_address" in controller_config:
            controller_name = f"{cluster_name}-controller"
            static_leases[controller_name] = controller_config["ip_address"]
            vm_macs[controller_name] = self._generate_mac_address(controller_name)
            logger.debug(
                f"Added static lease for controller: {controller_name} -> "
                f"{controller_config['ip_address']}"
            )

        # Add compute node static leases if IPs are configured
        for i, node_config in enumerate(self.hpc_config["compute_nodes"]):
            if "ip" in node_config:
                compute_name = f"{cluster_name}-compute-{i + 1:02d}"
                static_leases[compute_name] = node_config["ip"]
                vm_macs[compute_name] = self._generate_mac_address(compute_name)
                logger.debug(
                    f"Added static lease for compute node: {compute_name} -> {node_config['ip']}"
                )

        # Add static leases to network configuration
        if static_leases:
            network_config["static_leases"] = static_leases
            network_config["vm_macs"] = vm_macs
            logger.debug(f"Configured {len(static_leases)} static DHCP reservations")

        try:
            # Create cluster virtual network
            logger.debug("Creating cluster virtual network")
            network_name = self.network_manager.create_cluster_network(cluster_name, network_config)

            # Add rollback for network destruction
            self.rollback_manager.add_network_rollback(cluster_name)

            # Start the network
            self.network_manager.start_network(cluster_name)

            logger.debug(f"Created and started network: {network_name}")

            # Create cluster storage pool
            logger.debug("Creating cluster storage pool")
            pool_name = self.volume_manager.create_cluster_pool(cluster_name, pool_path, base_image)

            # Add rollback for pool destruction
            self.rollback_manager.add_pool_rollback(cluster_name)

            logger.debug(f"Created storage pool: {pool_name}")

        except (VolumeManagerError, NetworkManagerError) as e:
            logger.error(f"Failed to create cluster infrastructure: {e}")
            raise HPCManagerError(f"Failed to create cluster infrastructure: {e}") from e

        log_function_exit(logger, "_create_cluster_infrastructure")

    def _create_controller_vm(self, cluster_state: ClusterState) -> None:
        """Create the HPC controller VM."""
        controller_config = self.hpc_config["controller"]
        vm_name = f"{self.hpc_config['name']}-controller"
        cluster_name = self.hpc_config["name"]

        # Create volume
        try:
            volume_path = self.volume_manager.create_vm_volume(
                cluster_name=cluster_name,
                vm_name=vm_name,
                size_gb=controller_config["disk_gb"],
                vm_type="controller",
            )
            self.rollback_manager.add_vm_volume_rollback(cluster_name, vm_name)
        except VolumeManagerError as e:
            raise HPCManagerError(f"Failed to create controller volume: {e}") from e

        # Use static IP address from configuration instead of dynamic allocation
        static_ip = controller_config.get("ip_address")
        if static_ip:
            allocated_ip = static_ip
            logger.debug(f"Using static IP {allocated_ip} for controller {vm_name}")
        else:
            # Fallback to dynamic allocation if no static IP configured
            try:
                allocated_ip = self.network_manager.allocate_ip_address(cluster_name, vm_name)
                self.rollback_manager.add_ip_release_rollback(cluster_name, vm_name)
                logger.debug(f"Allocated dynamic IP {allocated_ip} for controller {vm_name}")
            except NetworkManagerError as e:
                raise HPCManagerError(f"Failed to allocate IP for controller: {e}") from e

        # Generate VM XML
        xml_config = self._generate_vm_xml(
            vm_name=vm_name,
            template_name="controller.xml.j2",
            cpu_cores=controller_config["cpu_cores"],
            memory_gb=controller_config["memory_gb"],
            volume_path=Path(volume_path),
            ip_address=allocated_ip,
            pcie_passthrough=controller_config.get(
                "pcie_passthrough"
            ),  # Controllers typically don't have PCIe passthrough
        )

        # Create VM
        try:
            domain_uuid = self.vm_lifecycle.create_vm(vm_name, xml_config)
            self.rollback_manager.add_rollback_action(self.vm_lifecycle.destroy_vm, vm_name)
        except VMLifecycleError as e:
            raise HPCManagerError(f"Failed to create controller VM: {e}") from e

        # Create VM info and add to state
        vm_info = VMInfo(
            name=vm_name,
            domain_uuid=domain_uuid,
            state=VMState.SHUTOFF,
            cpu_cores=controller_config["cpu_cores"],
            memory_gb=controller_config["memory_gb"],
            volume_path=Path(volume_path),
            vm_type="controller",
            ip_address=allocated_ip,
        )

        cluster_state.controller = vm_info
        logger.info(f"Created controller VM: {vm_name}")

    def _create_compute_nodes(self, cluster_state: ClusterState) -> None:
        """Create HPC compute nodes."""
        cluster_name = self.hpc_config["name"]

        for i, node_config in enumerate(self.hpc_config["compute_nodes"]):
            vm_name = f"{self.hpc_config['name']}-compute-{i + 1:02d}"

            # Skip if VM already exists in state
            if cluster_state.get_vm_by_name(vm_name):
                logger.info(f"Compute node {vm_name} already exists, skipping")
                continue

            # Create volume
            try:
                volume_path = self.volume_manager.create_vm_volume(
                    cluster_name=cluster_name,
                    vm_name=vm_name,
                    size_gb=node_config["disk_gb"],
                    vm_type="compute",
                )
                self.rollback_manager.add_vm_volume_rollback(cluster_name, vm_name)
            except VolumeManagerError as e:
                raise HPCManagerError(f"Failed to create volume for {vm_name}: {e}") from e

            # Use static IP address from configuration instead of dynamic allocation
            static_ip = node_config.get("ip")
            if static_ip:
                allocated_ip = static_ip
                logger.debug(f"Using static IP {allocated_ip} for compute node {vm_name}")
            else:
                # Fallback to dynamic allocation if no static IP configured
                try:
                    allocated_ip = self.network_manager.allocate_ip_address(cluster_name, vm_name)
                    self.rollback_manager.add_ip_release_rollback(cluster_name, vm_name)
                    logger.debug(f"Allocated dynamic IP {allocated_ip} for compute node {vm_name}")
                except NetworkManagerError as e:
                    raise HPCManagerError(f"Failed to allocate IP for {vm_name}: {e}") from e

            # Generate VM XML
            xml_config = self._generate_vm_xml(
                vm_name=vm_name,
                template_name="compute_node.xml.j2",
                cpu_cores=node_config["cpu_cores"],
                memory_gb=node_config["memory_gb"],
                volume_path=Path(volume_path),
                ip_address=allocated_ip,
                gpu_mdev_uuid=None,  # TODO: Implement GPU allocation
                pcie_passthrough=node_config.get("pcie_passthrough"),
            )

            # Create VM
            try:
                domain_uuid = self.vm_lifecycle.create_vm(vm_name, xml_config)
                self.rollback_manager.add_rollback_action(self.vm_lifecycle.destroy_vm, vm_name)
            except VMLifecycleError as e:
                raise HPCManagerError(f"Failed to create compute node {vm_name}: {e}") from e

            # Create VM info and add to state
            vm_info = VMInfo(
                name=vm_name,
                domain_uuid=domain_uuid,
                state=VMState.SHUTOFF,
                cpu_cores=node_config["cpu_cores"],
                memory_gb=node_config["memory_gb"],
                volume_path=Path(volume_path),
                vm_type="compute",
                ip_address=allocated_ip,
                gpu_assigned=node_config.get("gpu_assigned"),
            )

            cluster_state.add_vm(vm_info)
            logger.info(f"Created compute node: {vm_name}")

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
            raise HPCManagerError(f"Failed to start VM {vm_info.name}: {e}") from e

    def _generate_vm_xml(
        self,
        vm_name: str,
        template_name: str,
        cpu_cores: int,
        memory_gb: int,
        volume_path: Path,
        ip_address: str | None = None,
        gpu_mdev_uuid: str | None = None,
        pcie_passthrough: dict | None = None,
    ) -> str:
        """Generate VM XML configuration from template with hardware acceleration support."""
        try:
            template = _get_cached_template(self.template_env, template_name)

            # Get hardware configuration from cluster config
            hardware_config = self.hpc_config.get("hardware", {})

            template_vars = {
                # Basic VM configuration
                "vm_name": vm_name,
                "vm_uuid": str(uuid.uuid4()),
                "cpu_cores": cpu_cores,
                "memory_gb": memory_gb,
                "disk_path": str(volume_path),  # Template still uses disk_path variable name
                "cluster_name": self.cluster_name,
                "ip_address": ip_address,
                "gpu_mdev_uuid": gpu_mdev_uuid,
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
            raise HPCManagerError(f"Template not found: {e}") from e
        except Exception as e:
            raise HPCManagerError(f"Failed to generate VM XML: {e}") from e

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

    def get_xml_trace_summary(self) -> dict:
        """Get summary of XML operations for this cluster operation.

        Returns:
            Dictionary containing trace summary information
        """
        return self.xml_tracer.get_summary()

    def save_xml_trace(self) -> Path:
        """Save XML trace data to disk.

        Returns:
            Path to the trace folder
        """
        return self.xml_tracer.save_trace()
