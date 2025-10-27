"""GPU resource allocation and conflict detection for shared GPU management."""

import json
import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


class GPUResourceAllocator:
    """Manages GPU resource allocation and conflict detection between clusters."""

    def __init__(self, global_state_path: Path | None = None):
        """Initialize GPU resource allocator.

        Args:
            global_state_path: Path to global state file (default: output/global-state.json)
        """
        self.global_state_path = global_state_path or Path("output/global-state.json")
        self._ensure_global_state_file()

    def _ensure_global_state_file(self) -> None:
        """Create global state file if it doesn't exist."""
        if not self.global_state_path.exists():
            self.global_state_path.parent.mkdir(parents=True, exist_ok=True)
            self._write_global_state(
                {"shared_resources": {"gpu_allocations": {}, "last_updated": ""}}
            )

    def _read_global_state(self) -> dict[str, Any]:
        """Read global state from file.

        Returns:
            Global state dictionary
        """
        if not self.global_state_path.exists():
            return {"shared_resources": {"gpu_allocations": {}, "last_updated": ""}}

        with open(self.global_state_path) as f:
            return json.load(f)

    def _write_global_state(self, state: dict[str, Any]) -> None:
        """Write global state to file.

        Args:
            state: Global state dictionary
        """
        self.global_state_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.global_state_path, "w") as f:
            json.dump(state, f, indent=2)

    def _update_timestamp(self, state: dict[str, Any]) -> None:
        """Update last_updated timestamp in state.

        Args:
            state: Global state dictionary
        """
        from datetime import datetime

        state["shared_resources"]["last_updated"] = datetime.now().isoformat()

    def allocate_gpu(self, pci_address: str, owner: str) -> bool:
        """Allocate a GPU to a specific owner.

        Args:
            pci_address: PCI address of the GPU
            owner: Owner identifier (cluster name or VM name)

        Returns:
            True if allocation succeeded, False if GPU already allocated
        """
        state = self._read_global_state()
        allocations = state["shared_resources"]["gpu_allocations"]

        if pci_address in allocations and allocations[pci_address] != owner:
            logger.warning(f"GPU {pci_address} already allocated to {allocations[pci_address]}")
            return False

        allocations[pci_address] = owner
        self._update_timestamp(state)
        self._write_global_state(state)
        logger.info(f"Allocated GPU {pci_address} to {owner}")
        return True

    def release_gpu(self, pci_address: str) -> bool:
        """Release a GPU allocation.

        Args:
            pci_address: PCI address of the GPU

        Returns:
            True if release succeeded, False if GPU not allocated
        """
        state = self._read_global_state()
        allocations = state["shared_resources"]["gpu_allocations"]

        if pci_address not in allocations:
            logger.warning(f"GPU {pci_address} not currently allocated")
            return False

        old_owner = allocations.pop(pci_address)
        self._update_timestamp(state)
        self._write_global_state(state)
        logger.info(f"Released GPU {pci_address} from {old_owner}")
        return True

    def is_gpu_available(self, pci_address: str, requesting_owner: str) -> bool:
        """Check if a GPU is available for allocation to a specific owner.

        Args:
            pci_address: PCI address of the GPU
            requesting_owner: Owner requesting the GPU

        Returns:
            True if GPU is available, False if already allocated to different owner
        """
        state = self._read_global_state()
        allocations = state["shared_resources"]["gpu_allocations"]
        current_owner = allocations.get(pci_address)

        if current_owner is None:
            return True
        return current_owner == requesting_owner

    def get_gpu_owner(self, pci_address: str) -> str | None:
        """Get current owner of a GPU.

        Args:
            pci_address: PCI address of the GPU

        Returns:
            Owner name or None if not allocated
        """
        state = self._read_global_state()
        allocations = state["shared_resources"]["gpu_allocations"]
        return allocations.get(pci_address)

    def validate_gpu_availability(
        self, required_gpus: list[str], requesting_owner: str
    ) -> tuple[bool, str | None]:
        """Validate that all required GPUs are available.

        Args:
            required_gpus: List of GPU PCI addresses required
            requesting_owner: Owner requesting the GPUs

        Returns:
            Tuple of (is_available, conflict_message)
            - is_available: True if all GPUs available
            - conflict_message: None if available, error message if conflict
        """
        if not required_gpus:
            return True, None

        state = self._read_global_state()
        allocations = state["shared_resources"]["gpu_allocations"]

        for pci_address in required_gpus:
            current_owner = allocations.get(pci_address)
            if current_owner is not None and current_owner != requesting_owner:
                return False, f"GPU {pci_address} is currently allocated to '{current_owner}'"

        return True, None
