"""VM lifecycle management operations."""

import logging
import time
import xml.etree.ElementTree as ET

import libvirt

from ai_how.state.models import VMState
from ai_how.vm_management.libvirt_client import LibvirtClient, LibvirtConnectionError

logger = logging.getLogger(__name__)


class VMLifecycleError(Exception):
    """Raised when VM lifecycle operations fail."""

    pass


class VMLifecycleManager:
    """Manages VM creation, start, stop, destroy operations."""

    def __init__(self, libvirt_client: LibvirtClient | None = None):
        """Initialize VM lifecycle manager.

        Args:
            libvirt_client: libvirt client instance, creates new if None
        """
        self.client = libvirt_client or LibvirtClient()

    def create_vm(self, vm_name: str, xml_config: str) -> str:
        """Create VM from XML configuration.

        Args:
            vm_name: Name of the VM to create
            xml_config: libvirt XML domain configuration

        Returns:
            Domain UUID of the created VM

        Raises:
            VMLifecycleError: If VM creation fails
        """
        try:
            # Check if VM already exists
            if self.client.domain_exists(vm_name):
                raise VMLifecycleError(f"VM '{vm_name}' already exists")

            # Define the domain
            domain = self.client.define_domain(xml_config)
            domain_uuid = domain.UUIDString()

            logger.info(f"Created VM '{vm_name}' with UUID {domain_uuid}")
            return domain_uuid

        except LibvirtConnectionError as e:
            raise VMLifecycleError(f"Failed to create VM '{vm_name}': {e}") from e

    def start_vm(self, vm_name: str, wait_for_boot: bool = False, boot_timeout: int = 60) -> bool:
        """Start VM with error handling.

        Args:
            vm_name: Name of the VM to start
            wait_for_boot: Whether to wait for the VM to fully boot
            boot_timeout: Maximum time to wait for boot (seconds)

        Returns:
            True if VM started successfully

        Raises:
            VMLifecycleError: If VM start fails
        """
        try:
            domain = self.client.get_domain(vm_name)

            # Check if already running
            state, _ = self.client.get_domain_state(vm_name)
            if state == 1:  # VIR_DOMAIN_RUNNING
                logger.info(f"VM '{vm_name}' is already running")
                return True

            # Start the domain
            if libvirt is not None:
                domain.create()

            logger.info(f"Started VM '{vm_name}'")

            # Wait for boot if requested
            if wait_for_boot:
                return self._wait_for_vm_boot(vm_name, boot_timeout)

            return True

        except LibvirtConnectionError as e:
            raise VMLifecycleError(f"Failed to start VM '{vm_name}': {e}") from e
        except Exception as e:
            if isinstance(e, libvirt.libvirtError):
                raise VMLifecycleError(f"libvirt error starting VM '{vm_name}': {e}") from e
            raise VMLifecycleError(f"Unexpected error starting VM '{vm_name}': {e}") from e

    def stop_vm(self, vm_name: str, force: bool = False, shutdown_timeout: int = 30) -> bool:
        """Stop VM gracefully or forcefully.

        Args:
            vm_name: Name of the VM to stop
            force: Whether to force stop (destroy) instead of graceful shutdown
            shutdown_timeout: Maximum time to wait for graceful shutdown (seconds)

        Returns:
            True if VM stopped successfully

        Raises:
            VMLifecycleError: If VM stop fails
        """
        try:
            domain = self.client.get_domain(vm_name)

            # Check if already stopped
            state, _ = self.client.get_domain_state(vm_name)
            if state in [4, 5]:  # VIR_DOMAIN_SHUTDOWN or VIR_DOMAIN_SHUTOFF
                logger.info(f"VM '{vm_name}' is already stopped")
                return True

            if force:
                # Force destroy the domain
                if libvirt is not None:
                    domain.destroy()
                logger.info(f"Force stopped VM '{vm_name}'")
            else:
                # Attempt graceful shutdown
                if libvirt is not None:
                    domain.shutdown()
                logger.info(f"Initiated graceful shutdown for VM '{vm_name}'")

                # Wait for graceful shutdown
                if not self._wait_for_vm_shutdown(vm_name, shutdown_timeout):
                    logger.warning(f"Graceful shutdown timed out for VM '{vm_name}', forcing stop")
                    if libvirt is not None:
                        domain.destroy()

            return True

        except LibvirtConnectionError as e:
            raise VMLifecycleError(f"Failed to stop VM '{vm_name}': {e}") from e
        except Exception as e:
            if isinstance(e, libvirt.libvirtError):
                raise VMLifecycleError(f"libvirt error stopping VM '{vm_name}': {e}") from e
            raise VMLifecycleError(f"Unexpected error stopping VM '{vm_name}': {e}") from e

    def destroy_vm(self, vm_name: str, remove_storage: bool = False) -> bool:
        """Destroy VM and optionally remove storage.

        Args:
            vm_name: Name of the VM to destroy
            remove_storage: Whether to remove VM storage files

        Returns:
            True if VM destroyed successfully

        Raises:
            VMLifecycleError: If VM destruction fails
        """
        try:
            domain = self.client.get_domain(vm_name)

            # Stop the VM if running
            state, _ = self.client.get_domain_state(vm_name)
            if state == 1:  # VIR_DOMAIN_RUNNING
                self.stop_vm(vm_name, force=True)

            # Get storage info before undefining if we need to remove storage
            storage_paths = []
            if remove_storage:
                storage_paths = self._get_domain_storage_paths(domain)

            # Undefine the domain
            if libvirt is not None:
                domain.undefine()

            logger.info(f"Destroyed VM '{vm_name}'")

            # Remove storage if requested
            if remove_storage and storage_paths:
                self._remove_storage_files(storage_paths)

            return True

        except LibvirtConnectionError as e:
            raise VMLifecycleError(f"Failed to destroy VM '{vm_name}': {e}") from e
        except Exception as e:
            if isinstance(e, libvirt.libvirtError):
                raise VMLifecycleError(f"libvirt error destroying VM '{vm_name}': {e}") from e
            raise VMLifecycleError(f"Unexpected error destroying VM '{vm_name}': {e}") from e

    def get_vm_state(self, vm_name: str) -> VMState:
        """Get current VM state.

        Args:
            vm_name: Name of the VM

        Returns:
            Current VM state

        Raises:
            VMLifecycleError: If operation fails
        """
        try:
            if not self.client.domain_exists(vm_name):
                return VMState.UNDEFINED

            state, _ = self.client.get_domain_state(vm_name)
            return VMState.from_libvirt_state(state)

        except LibvirtConnectionError as e:
            raise VMLifecycleError(f"Failed to get state for VM '{vm_name}': {e}") from e

    def vm_exists(self, vm_name: str) -> bool:
        """Check if VM exists.

        Args:
            vm_name: Name of the VM

        Returns:
            True if VM exists, False otherwise
        """
        return self.client.domain_exists(vm_name)

    def list_vms(self) -> list[str]:
        """List all VMs managed by libvirt.

        Returns:
            List of VM names

        Raises:
            VMLifecycleError: If operation fails
        """
        try:
            return self.client.list_domains()
        except LibvirtConnectionError as e:
            raise VMLifecycleError(f"Failed to list VMs: {e}") from e

    def _wait_for_vm_boot(self, vm_name: str, timeout: int) -> bool:
        """Wait for VM to fully boot.

        Args:
            vm_name: Name of the VM
            timeout: Maximum time to wait (seconds)

        Returns:
            True if VM booted successfully within timeout
        """
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                state, _ = self.client.get_domain_state(vm_name)
                if state == 1:  # VIR_DOMAIN_RUNNING
                    return True
            except LibvirtConnectionError:
                pass

            time.sleep(2)

        logger.warning(f"VM '{vm_name}' did not boot within {timeout} seconds")
        return False

    def _wait_for_vm_shutdown(self, vm_name: str, timeout: int) -> bool:
        """Wait for VM to shutdown gracefully.

        Args:
            vm_name: Name of the VM
            timeout: Maximum time to wait (seconds)

        Returns:
            True if VM shutdown within timeout
        """
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                state, _ = self.client.get_domain_state(vm_name)
                if state in [4, 5]:  # VIR_DOMAIN_SHUTDOWN or VIR_DOMAIN_SHUTOFF
                    return True
            except LibvirtConnectionError:
                # Domain might have been undefined
                return True

            time.sleep(2)

        return False

    def _get_domain_storage_paths(self, domain) -> list[str]:
        """Get storage file paths for a domain.

        Args:
            domain: libvirt domain object

        Returns:
            List of storage file paths
        """
        storage_paths: list[str] = []

        try:
            # Get domain XML to parse storage information
            xml_desc = domain.XMLDesc(0)

            # Parse XML using ElementTree for reliable extraction
            try:
                root = ET.fromstring(xml_desc)

                # Find all disk devices and get their source files
                for disk in root.findall("./devices/disk"):
                    if disk.get("type") == "file":
                        source = disk.find("source")
                        if source is not None and source.get("file"):
                            file_path = source.get("file")
                            if file_path is not None:
                                storage_paths.append(file_path)

            except ET.ParseError as xml_error:
                logger.warning(f"Failed to parse domain XML: {xml_error}")
                # Fallback to simple regex parsing if XML parsing fails
                import re

                matches = re.findall(r"<source file='([^']+)'", xml_desc)
                storage_paths.extend(matches)

        except Exception as e:
            logger.warning(f"Failed to get storage paths for domain: {e}")

        return storage_paths

    def _remove_storage_files(self, storage_paths: list[str]) -> None:
        """Remove storage files.

        Args:
            storage_paths: List of storage file paths to remove
        """
        import os

        for path in storage_paths:
            try:
                if os.path.exists(path):
                    os.remove(path)
                    logger.info(f"Removed storage file: {path}")
            except OSError as e:
                logger.warning(f"Failed to remove storage file {path}: {e}")
