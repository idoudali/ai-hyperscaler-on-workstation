"""State management module for cluster tracking and persistence."""

# New modular state management (recommended)
# Legacy state management (for backward compatibility)
from ai_how.state.cluster_state import ClusterStateManager as LegacyClusterStateManager
from ai_how.state.manager import ClusterStateManager, StateManagerError
from ai_how.state.models import ClusterState, NetworkConfig, NetworkInfo, VMInfo, VMState
from ai_how.state.persistence import StateFileManager, StatePersistenceError, StateSerializer

__all__ = [
    # Core models
    "ClusterState",
    "NetworkConfig",
    "NetworkInfo",
    "VMInfo",
    "VMState",
    # New state management (recommended)
    "ClusterStateManager",
    "StateManagerError",
    "StateFileManager",
    "StateSerializer",
    "StatePersistenceError",
    # Legacy (for backward compatibility)
    "LegacyClusterStateManager",
]
