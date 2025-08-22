"""Cluster state management and persistence."""

import json
import logging
from pathlib import Path
from typing import Union

from ai_how.state.models import ClusterState, NetworkConfig, VMInfo, VMState

logger = logging.getLogger(__name__)


class ClusterStateError(Exception):
    """Raised when cluster state operations fail."""

    pass


class ClusterStateManager:
    """Manages cluster state persistence and tracking."""

    def __init__(self, state_file: Path):
        """Initialize cluster state manager.

        Args:
            state_file: Path to the state file
        """
        self.state_file = Path(state_file)
        self.state: Union[ClusterState, None] = None

        # Create state directory if it doesn't exist
        self.state_file.parent.mkdir(parents=True, exist_ok=True)

    def load_state(self) -> Union[ClusterState, None]:
        """Load cluster state from JSON file.

        Returns:
            ClusterState object if file exists and is valid, None otherwise

        Raises:
            ClusterStateError: If state file is corrupted
        """
        if not self.state_file.exists():
            logger.info(f"State file does not exist: {self.state_file}")
            return None

        try:
            with open(self.state_file, encoding="utf-8") as f:
                data = json.load(f)

            self.state = ClusterState.from_dict(data)
            logger.info(f"Loaded cluster state from {self.state_file}")
            return self.state

        except json.JSONDecodeError as e:
            raise ClusterStateError(f"State file is corrupted: {e}") from e
        except KeyError as e:
            raise ClusterStateError(f"State file is missing required field: {e}") from e
        except Exception as e:
            raise ClusterStateError(f"Failed to load state file: {e}") from e

    def save_state(self, state: ClusterState) -> bool:
        """Save cluster state to JSON file.

        Args:
            state: ClusterState object to save

        Returns:
            True if saved successfully

        Raises:
            ClusterStateError: If save operation fails
        """
        try:
            # Create a backup of existing state file
            if self.state_file.exists():
                backup_path = self.state_file.with_suffix(".json.backup")
                self.state_file.rename(backup_path)
                logger.debug(f"Created backup: {backup_path}")

                # Rotate old backups to prevent accumulation
                self._rotate_backups()

            # Write new state
            with open(self.state_file, "w", encoding="utf-8") as f:
                json.dump(state.to_dict(), f, indent=2, ensure_ascii=False)

            self.state = state
            logger.info(f"Saved cluster state to {self.state_file}")
            return True

        except OSError as e:
            raise ClusterStateError(f"Failed to write state file: {e}") from e
        except Exception as e:
            raise ClusterStateError(f"Unexpected error saving state: {e}") from e

    def _rotate_backups(self, max_backups: int = 5) -> None:
        """Remove old backup files keeping only the most recent ones.

        Args:
            max_backups: Maximum number of backup files to keep
        """
        try:
            backup_pattern = f"{self.state_file.name}.backup"
            backup_files = list(self.state_file.parent.glob(backup_pattern))

            if len(backup_files) > max_backups:
                # Sort by modification time (oldest first)
                backup_files.sort(key=lambda f: f.stat().st_mtime)

                # Remove oldest backups
                for old_backup in backup_files[:-max_backups]:
                    try:
                        old_backup.unlink()
                        logger.debug(f"Removed old backup: {old_backup}")
                    except OSError as e:
                        logger.warning(f"Failed to remove old backup {old_backup}: {e}")

        except Exception as e:
            logger.warning(f"Failed to rotate backups: {e}")
            # Don't fail the main operation if backup rotation fails

    def get_state(self) -> ClusterState | None:
        """Get current cluster state.

        Returns:
            Current ClusterState object or None if not loaded
        """
        if self.state is None:
            self.state = self.load_state()
        return self.state

    def ensure_state(self, cluster_name: str, cluster_type: str) -> ClusterState:
        """Ensure state exists, create if necessary.

        Args:
            cluster_name: Name of the cluster
            cluster_type: Type of cluster ("hpc" or "cloud")

        Returns:
            ClusterState object
        """
        state = self.get_state()
        if state is None:
            state = ClusterState(cluster_name=cluster_name, cluster_type=cluster_type)
            self.save_state(state)
        return state

    def update_vm_state(self, vm_name: str, new_state: VMState) -> bool:
        """Update individual VM state.

        Args:
            vm_name: Name of the VM
            new_state: New VM state

        Returns:
            True if updated successfully

        Raises:
            ClusterStateError: If VM not found or update fails
        """
        state = self.get_state()
        if state is None:
            raise ClusterStateError("No cluster state available")

        if not state.update_vm_state(vm_name, new_state):
            raise ClusterStateError(f"VM '{vm_name}' not found in state")

        self.save_state(state)
        return True

    def add_vm(self, vm_info: VMInfo) -> bool:
        """Add new VM to state tracking.

        Args:
            vm_info: VM information to add

        Returns:
            True if added successfully

        Raises:
            ClusterStateError: If VM already exists or operation fails
        """
        state = self.get_state()
        if state is None:
            raise ClusterStateError("No cluster state available")

        if not state.add_vm(vm_info):
            raise ClusterStateError(f"VM '{vm_info.name}' already exists")

        self.save_state(state)
        return True

    def remove_vm(self, vm_name: str) -> bool:
        """Remove VM from state tracking.

        Args:
            vm_name: Name of the VM to remove

        Returns:
            True if removed successfully

        Raises:
            ClusterStateError: If VM not found or operation fails
        """
        state = self.get_state()
        if state is None:
            raise ClusterStateError("No cluster state available")

        if not state.remove_vm(vm_name):
            raise ClusterStateError(f"VM '{vm_name}' not found in state")

        self.save_state(state)
        return True

    def get_vm_info(self, vm_name: str) -> VMInfo | None:
        """Get VM information by name.

        Args:
            vm_name: Name of the VM

        Returns:
            VMInfo object if found, None otherwise
        """
        state = self.get_state()
        if state is None:
            return None

        return state.get_vm_by_name(vm_name)

    def list_vms(self) -> list[VMInfo]:
        """List all VMs in the cluster state.

        Returns:
            List of VMInfo objects
        """
        state = self.get_state()
        if state is None:
            return []

        return state.get_all_vms()

    def get_cluster_status(self) -> dict:
        """Get cluster status summary.

        Returns:
            Dictionary with cluster status information
        """
        state = self.get_state()
        if state is None:
            return {"status": "no_state", "message": "No cluster state available"}

        return state.get_cluster_status()

    def set_network_config(self, network_config: NetworkConfig) -> bool:
        """Set network configuration for the cluster.

        Args:
            network_config: Network configuration to set

        Returns:
            True if set successfully

        Raises:
            ClusterStateError: If operation fails
        """
        state = self.get_state()
        if state is None:
            raise ClusterStateError("No cluster state available")

        state.network_config = network_config
        self.save_state(state)
        return True

    def clear_state(self) -> bool:
        """Clear all cluster state.

        Returns:
            True if cleared successfully
        """
        try:
            if self.state_file.exists():
                # Create backup before clearing
                backup_path = self.state_file.with_suffix(".json.cleared")
                self.state_file.rename(backup_path)
                logger.info(f"State cleared, backup created: {backup_path}")

            self.state = None
            return True

        except OSError as e:
            raise ClusterStateError(f"Failed to clear state file: {e}") from e

    def backup_state(self, backup_path: Union[Path, None] = None) -> Path:
        """Create a backup of the current state.

        Args:
            backup_path: Optional custom backup path

        Returns:
            Path to the backup file

        Raises:
            ClusterStateError: If backup fails
        """
        if not self.state_file.exists():
            raise ClusterStateError("No state file to backup")

        if backup_path is None:
            from datetime import datetime

            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_path = self.state_file.with_suffix(f".json.backup_{timestamp}")

        try:
            import shutil

            shutil.copy2(self.state_file, backup_path)
            logger.info(f"Created state backup: {backup_path}")
            return backup_path

        except OSError as e:
            raise ClusterStateError(f"Failed to create backup: {e}") from e

    def restore_state(self, backup_path: Path) -> bool:
        """Restore state from a backup file.

        Args:
            backup_path: Path to the backup file

        Returns:
            True if restored successfully

        Raises:
            ClusterStateError: If restore fails
        """
        if not backup_path.exists():
            raise ClusterStateError(f"Backup file not found: {backup_path}")

        try:
            import shutil

            # Create backup of current state if it exists
            if self.state_file.exists():
                current_backup = self.state_file.with_suffix(".json.pre_restore")
                shutil.copy2(self.state_file, current_backup)
                logger.info(f"Created pre-restore backup: {current_backup}")

            # Restore from backup
            shutil.copy2(backup_path, self.state_file)

            # Verify the restored state is valid
            self.state = None
            restored_state = self.load_state()
            if restored_state is None:
                raise ClusterStateError("Restored state is invalid")

            logger.info(f"Restored state from backup: {backup_path}")
            return True

        except OSError as e:
            raise ClusterStateError(f"Failed to restore from backup: {e}") from e
