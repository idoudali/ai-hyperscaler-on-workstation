"""High-level cluster state management."""

import logging
from datetime import datetime
from pathlib import Path
from typing import Any

from ai_how.state.models import ClusterState, NetworkConfig, NetworkInfo, VMInfo
from ai_how.state.persistence import StateFileManager, StatePersistenceError

logger = logging.getLogger(__name__)


class StateManagerError(Exception):
    """Raised when state management operations fail."""

    pass


class ClusterStateManager:
    """High-level cluster state management with business logic."""

    def __init__(self, state_file: Path):
        """Initialize cluster state manager.

        Args:
            state_file: Path to the state file
        """
        self.file_manager = StateFileManager(state_file)
        self._cached_state: ClusterState | None = None
        self._state_dirty = False

    @property
    def state_file(self) -> Path:
        """Get the state file path."""
        return self.file_manager.state_file

    def get_state(self) -> ClusterState | None:
        """Get the current cluster state.

        Returns:
            Current cluster state or None if no state exists

        Raises:
            StateManagerError: If state loading fails
        """
        try:
            if self._cached_state is None:
                self._cached_state = self.file_manager.load()
            return self._cached_state
        except StatePersistenceError as e:
            raise StateManagerError(f"Failed to get cluster state: {e}") from e

    def save_state(self, state: ClusterState | None = None) -> None:
        """Save cluster state to file.

        Args:
            state: State to save. If None, saves the cached state.

        Raises:
            StateManagerError: If save operation fails
        """
        try:
            if state is not None:
                self._cached_state = state
            elif self._cached_state is None:
                raise StateManagerError("No state to save")

            # Update last modified timestamp
            self._cached_state.last_modified = datetime.now()

            self.file_manager.save(self._cached_state)
            self._state_dirty = False

        except StatePersistenceError as e:
            raise StateManagerError(f"Failed to save cluster state: {e}") from e

    def ensure_state(self, cluster_name: str, cluster_type: str = "hpc") -> ClusterState:
        """Ensure cluster state exists, creating it if necessary.

        Args:
            cluster_name: Name of the cluster
            cluster_type: Type of cluster (hpc, cloud, etc.)

        Returns:
            ClusterState object

        Raises:
            StateManagerError: If state creation fails
        """
        try:
            state = self.get_state()
            if state is None:
                logger.info(f"Creating new cluster state: {cluster_name}")
                state = ClusterState(
                    cluster_name=cluster_name,
                    cluster_type=cluster_type,
                    created_at=datetime.now(),
                    last_modified=datetime.now(),
                    config_file_path=str(self.state_file),
                )
                self._cached_state = state
                self._state_dirty = True

            return state
        except Exception as e:
            raise StateManagerError(f"Failed to ensure cluster state: {e}") from e

    def clear_state(self) -> None:
        """Clear the cluster state and remove the state file.

        Raises:
            StateManagerError: If state clearing fails
        """
        try:
            self.file_manager.remove()
            self._cached_state = None
            self._state_dirty = False
            logger.info("Cluster state cleared")
        except StatePersistenceError as e:
            raise StateManagerError(f"Failed to clear cluster state: {e}") from e

    def backup_state(self, backup_suffix: str | None = None) -> Path:
        """Create a backup of the current state.

        Args:
            backup_suffix: Custom suffix for backup file

        Returns:
            Path to the backup file

        Raises:
            StateManagerError: If backup creation fails
        """
        try:
            if backup_suffix is None:
                backup_suffix = f".backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"

            return self.file_manager.backup(backup_suffix)
        except StatePersistenceError as e:
            raise StateManagerError(f"Failed to backup cluster state: {e}") from e

    # VM Management Methods
    def add_vm(self, vm_info: VMInfo) -> None:
        """Add VM to cluster state.

        Args:
            vm_info: VM information to add

        Raises:
            StateManagerError: If no cluster state exists
        """
        state = self.get_state()
        if state is None:
            raise StateManagerError("No cluster state exists")

        if vm_info.vm_type == "controller":
            state.controller = vm_info
        else:
            # Check for existing VM with same name
            existing_vm = state.get_vm_by_name(vm_info.name)
            if existing_vm:
                # Update existing VM
                for i, vm in enumerate(state.compute_nodes):
                    if vm.name == vm_info.name:
                        state.compute_nodes[i] = vm_info
                        break
                for i, vm in enumerate(state.worker_nodes):
                    if vm.name == vm_info.name:
                        state.worker_nodes[i] = vm_info
                        break
            else:
                # Add new VM
                if vm_info.vm_type == "compute":
                    state.compute_nodes.append(vm_info)
                elif vm_info.vm_type == "worker":
                    state.worker_nodes.append(vm_info)
                else:
                    state.compute_nodes.append(vm_info)  # Default to compute

        self._state_dirty = True
        logger.debug(f"Added VM to state: {vm_info.name}")

    def remove_vm(self, vm_name: str) -> bool:
        """Remove VM from cluster state.

        Args:
            vm_name: Name of VM to remove

        Returns:
            True if VM was removed, False if not found
        """
        state = self.get_state()
        if state is None:
            return False

        # Check controller
        if state.controller and state.controller.name == vm_name:
            state.controller = None
            self._state_dirty = True
            logger.debug(f"Removed controller VM from state: {vm_name}")
            return True

        # Check compute nodes
        for i, vm in enumerate(state.compute_nodes):
            if vm.name == vm_name:
                del state.compute_nodes[i]
                self._state_dirty = True
                logger.debug(f"Removed compute VM from state: {vm_name}")
                return True

        # Check worker nodes
        for i, vm in enumerate(state.worker_nodes):
            if vm.name == vm_name:
                del state.worker_nodes[i]
                self._state_dirty = True
                logger.debug(f"Removed worker VM from state: {vm_name}")
                return True

        return False

    def get_vm(self, vm_name: str) -> VMInfo | None:
        """Get VM information by name.

        Args:
            vm_name: Name of VM to find

        Returns:
            VMInfo if found, None otherwise
        """
        state = self.get_state()
        if state is None:
            return None

        return state.get_vm_by_name(vm_name)

    def update_vm_state(self, vm_name: str, new_state: Any) -> bool:
        """Update VM state.

        Args:
            vm_name: Name of VM to update
            new_state: New VM state

        Returns:
            True if VM was updated, False if not found
        """
        vm = self.get_vm(vm_name)
        if vm is None:
            return False

        vm.update_state(new_state)
        self._state_dirty = True
        logger.debug(f"Updated VM state: {vm_name} -> {new_state}")
        return True

    # Network Management Methods
    def update_network_config(self, network_config: NetworkConfig) -> None:
        """Update network configuration in cluster state.

        Args:
            network_config: Network configuration to set

        Raises:
            StateManagerError: If no cluster state exists
        """
        state = self.get_state()
        if state is None:
            raise StateManagerError("No cluster state exists")

        state.network_config = network_config
        self._state_dirty = True
        logger.debug("Updated network configuration in state")

    def update_network_info(self, network_info: NetworkInfo) -> None:
        """Update network information in cluster state.

        Args:
            network_info: Network information to set

        Raises:
            StateManagerError: If no cluster state exists
        """
        state = self.get_state()
        if state is None:
            raise StateManagerError("No cluster state exists")

        # Note: This method may need to be updated based on the final NetworkInfo integration
        # Currently, ClusterState has network_config but not network_info
        # This is a placeholder for future NetworkInfo integration
        logger.debug(f"Network info update requested: {network_info.name}")
        self._state_dirty = True

    def allocate_vm_ip(self, vm_name: str, ip_address: str) -> None:
        """Record IP address allocation for a VM.

        Args:
            vm_name: Name of the VM
            ip_address: Allocated IP address
        """
        vm = self.get_vm(vm_name)
        if vm:
            vm.ip_address = ip_address
            self._state_dirty = True
            logger.debug(f"Allocated IP {ip_address} to VM {vm_name}")

    def release_vm_ip(self, vm_name: str) -> None:
        """Release IP address allocation for a VM.

        Args:
            vm_name: Name of the VM
        """
        vm = self.get_vm(vm_name)
        if vm:
            old_ip = vm.ip_address
            vm.ip_address = None
            self._state_dirty = True
            logger.debug(f"Released IP {old_ip} from VM {vm_name}")

    # State Information Methods
    def get_cluster_status(self) -> dict[str, Any]:
        """Get cluster status summary.

        Returns:
            Dictionary with cluster status information
        """
        state = self.get_state()
        if state is None:
            return {"status": "not_configured", "message": "No cluster state found"}

        return state.get_cluster_status()

    def is_dirty(self) -> bool:
        """Check if state has unsaved changes.

        Returns:
            True if state has unsaved changes
        """
        return self._state_dirty

    def get_file_info(self) -> dict[str, Any]:
        """Get information about the state file.

        Returns:
            Dictionary with file information
        """
        return self.file_manager.get_file_info()

    def auto_save_if_dirty(self) -> bool:
        """Save state if there are unsaved changes.

        Returns:
            True if state was saved, False if no changes to save

        Raises:
            StateManagerError: If save operation fails
        """
        if self._state_dirty and self._cached_state is not None:
            self.save_state()
            return True
        return False
