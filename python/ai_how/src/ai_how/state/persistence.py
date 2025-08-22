"""State persistence and serialization utilities."""

import contextlib
import json
import logging
import os
from pathlib import Path
from typing import Any

from ai_how.state.models import ClusterState

logger = logging.getLogger(__name__)


class StatePersistenceError(Exception):
    """Raised when state persistence operations fail."""

    pass


class StateSerializer:
    """Handles serialization and deserialization of cluster state."""

    @staticmethod
    def serialize_state(state: ClusterState) -> dict[str, Any]:
        """Serialize cluster state to dictionary.

        Args:
            state: ClusterState object to serialize

        Returns:
            Dictionary representation of the state
        """
        try:
            return state.to_dict()
        except Exception as e:
            logger.error(f"Failed to serialize cluster state: {e}")
            raise StatePersistenceError(f"Serialization failed: {e}") from e

    @staticmethod
    def deserialize_state(data: dict[str, Any]) -> ClusterState:
        """Deserialize dictionary to cluster state.

        Args:
            data: Dictionary representation of cluster state

        Returns:
            ClusterState object

        Raises:
            StatePersistenceError: If deserialization fails
        """
        try:
            return ClusterState.from_dict(data)
        except Exception as e:
            logger.error(f"Failed to deserialize cluster state: {e}")
            raise StatePersistenceError(f"Deserialization failed: {e}") from e


class StateFileManager:
    """Manages cluster state file operations."""

    def __init__(self, state_file: Path):
        """Initialize state file manager.

        Args:
            state_file: Path to the state file
        """
        self.state_file = Path(state_file)
        self.serializer = StateSerializer()

        # Create state directory if it doesn't exist
        self.state_file.parent.mkdir(parents=True, exist_ok=True)

    def exists(self) -> bool:
        """Check if state file exists.

        Returns:
            True if state file exists
        """
        return self.state_file.exists()

    def load(self) -> ClusterState | None:
        """Load cluster state from file.

        Returns:
            ClusterState object if file exists and is valid, None otherwise

        Raises:
            StatePersistenceError: If state file is corrupted
        """
        if not self.exists():
            logger.debug(f"State file does not exist: {self.state_file}")
            return None

        try:
            logger.debug(f"Loading cluster state from: {self.state_file}")
            with open(self.state_file, encoding="utf-8") as f:
                data = json.load(f)

            state = self.serializer.deserialize_state(data)
            logger.debug(f"Successfully loaded cluster state: {state.cluster_name}")
            return state

        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in state file {self.state_file}: {e}")
            raise StatePersistenceError(f"Corrupted state file: {e}") from e
        except Exception as e:
            logger.error(f"Failed to load cluster state from {self.state_file}: {e}")
            raise StatePersistenceError(f"Failed to load state: {e}") from e

    def save(self, state: ClusterState) -> None:
        """Save cluster state to file.

        Args:
            state: ClusterState object to save

        Raises:
            StatePersistenceError: If save operation fails
        """
        try:
            logger.debug(f"Saving cluster state to: {self.state_file}")

            # Serialize state to dictionary
            data = self.serializer.serialize_state(state)

            # Write to temporary file first for atomic operation
            temp_file = self.state_file.with_suffix(".tmp")
            with open(temp_file, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

            # Atomic rename
            temp_file.replace(self.state_file)

            logger.debug(f"Successfully saved cluster state: {state.cluster_name}")

        except Exception as e:
            logger.error(f"Failed to save cluster state to {self.state_file}: {e}")
            # Clean up temporary file if it exists
            temp_file = self.state_file.with_suffix(".tmp")
            if temp_file.exists():
                with contextlib.suppress(Exception):
                    temp_file.unlink()
            raise StatePersistenceError(f"Failed to save state: {e}") from e

    def backup(self, backup_suffix: str = ".backup") -> Path:
        """Create a backup of the current state file.

        Args:
            backup_suffix: Suffix to append to backup file name

        Returns:
            Path to the backup file

        Raises:
            StatePersistenceError: If backup creation fails
        """
        if not self.exists():
            raise StatePersistenceError("Cannot backup non-existent state file")

        backup_path = self.state_file.with_suffix(f"{self.state_file.suffix}{backup_suffix}")

        try:
            import shutil

            shutil.copy2(self.state_file, backup_path)
            logger.debug(f"Created state backup: {backup_path}")
            return backup_path
        except Exception as e:
            logger.error(f"Failed to create state backup: {e}")
            raise StatePersistenceError(f"Backup creation failed: {e}") from e

    def remove(self) -> None:
        """Remove the state file.

        Raises:
            StatePersistenceError: If removal fails
        """
        try:
            if self.exists():
                self.state_file.unlink()
                logger.debug(f"Removed state file: {self.state_file}")
            else:
                logger.debug(f"State file does not exist, nothing to remove: {self.state_file}")
        except Exception as e:
            logger.error(f"Failed to remove state file {self.state_file}: {e}")
            raise StatePersistenceError(f"Failed to remove state file: {e}") from e

    def get_file_info(self) -> dict[str, Any]:
        """Get information about the state file.

        Returns:
            Dictionary with file information
        """
        if not self.exists():
            return {"exists": False, "path": str(self.state_file)}

        try:
            stat = self.state_file.stat()
            return {
                "exists": True,
                "path": str(self.state_file),
                "size": stat.st_size,
                "modified": stat.st_mtime,
                "readable": os.access(self.state_file, os.R_OK),
                "writable": os.access(self.state_file, os.W_OK),
            }
        except Exception as e:
            logger.warning(f"Failed to get state file info: {e}")
            return {"exists": True, "path": str(self.state_file), "error": str(e)}
