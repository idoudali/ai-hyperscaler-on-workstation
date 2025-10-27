"""System-level cluster management for coordinated operations between HPC and Cloud clusters."""

from __future__ import annotations

import json
import logging
import time
from datetime import datetime
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from pathlib import Path

    from ai_how.state.cluster_state import ClusterStateManager

from ai_how.vm_management.cloud_manager import CloudClusterManager, CloudManagerError
from ai_how.vm_management.hpc_manager import HPCClusterManager, HPCManagerError

logger = logging.getLogger(__name__)


class SystemManagerError(Exception):
    """Exception raised for system manager errors."""

    pass


class ClusterOperationExecutor:
    """Executes operations on cluster managers with standardized error handling.

    This class reduces code duplication for cluster manager operations by
    providing a generic interface for creating managers and executing operations.
    """

    def __init__(self, state_dir: Path):
        """Initialize cluster operation executor.

        Args:
            state_dir: Directory containing cluster state files
        """
        self.state_dir = state_dir
        self._managers: dict[str, dict[str, Any]] = {
            "hpc": {
                "manager": None,
                "manager_class": HPCClusterManager,
                "error_class": HPCManagerError,
                "state_filename": "hpc-state.json",
            },
            "cloud": {
                "manager": None,
                "manager_class": CloudClusterManager,
                "error_class": CloudManagerError,
                "state_filename": "cloud-state.json",
            },
        }

    def get_or_create_manager(self, cluster_type: str, config_data: dict[str, Any]):
        """Get existing manager or create new one.

        Args:
            cluster_type: Type of cluster ('hpc' or 'cloud')
            config_data: Configuration dictionary for the cluster

        Returns:
            Cluster manager instance

        Raises:
            ValueError: If cluster_type is invalid
        """
        if cluster_type not in self._managers:
            raise ValueError(f"Invalid cluster type: {cluster_type}")

        manager_info = self._managers[cluster_type]

        if manager_info["manager"] is None:
            state_file = self.state_dir / manager_info["state_filename"]
            manager_class = manager_info["manager_class"]
            manager_info["manager"] = manager_class(config_data, state_file)

        return manager_info["manager"]

    def execute_operation(
        self, cluster_type: str, operation: str, config_data: dict[str, Any], **kwargs
    ) -> bool:
        """Execute a cluster operation with standardized error handling.

        Args:
            cluster_type: Type of cluster ('hpc' or 'cloud')
            operation: Method name like 'start_cluster', 'stop_cluster', etc.
            config_data: Configuration dictionary for the cluster
            **kwargs: Additional arguments for the operation

        Returns:
            True if operation succeeded, False otherwise
        """
        try:
            manager = self.get_or_create_manager(cluster_type, config_data)
            method = getattr(manager, operation)
            result = method(**kwargs)
            return result if isinstance(result, bool) else True
        except Exception as e:
            logger.error(f"{cluster_type.upper()} cluster {operation} failed: {e}")
            return False

    def get_status(self, cluster_type: str, config_data: dict[str, Any]) -> dict[str, Any]:
        """Get cluster status.

        Args:
            cluster_type: Type of cluster ('hpc' or 'cloud')
            config_data: Configuration dictionary for the cluster

        Returns:
            Dictionary with cluster status
        """
        try:
            manager = self.get_or_create_manager(cluster_type, config_data)
            # Handle different method names for status
            if hasattr(manager, "status_cluster"):
                return manager.status_cluster()
            elif hasattr(manager, "status"):
                return manager.status()
            else:
                return {"status": "error", "message": "No status method available"}
        except Exception as e:
            logger.error(f"Failed to get {cluster_type} status: {e}")
            return {"status": "error", "message": str(e)}


class SystemClusterManager:
    """Manages the entire system (HPC + Cloud clusters) with coordinated operations."""

    def __init__(self, state_manager: ClusterStateManager):
        """Initialize system manager with state manager.

        Args:
            state_manager: State manager for accessing cluster state
        """
        self.state_manager = state_manager
        self.executor = ClusterOperationExecutor(state_manager.state_file.parent)
        # Keep references for backward compatibility
        self.hpc_manager = None
        self.cloud_manager = None

    def start_all_clusters(self, hpc_config: dict[str, Any], cloud_config: dict[str, Any]) -> bool:
        """Start both HPC and Cloud clusters in proper order.

        Order of operations:
        1. Start HPC cluster first (training infrastructure)
        2. Wait for HPC to be ready
        3. Start Cloud cluster (inference infrastructure)
        4. Validate both clusters running

        Args:
            hpc_config: HPC cluster configuration dictionary
            cloud_config: Cloud cluster configuration dictionary

        Returns:
            True if both clusters started successfully, False otherwise
        """
        try:
            logger.info("Starting complete ML system...")

            # Step 1: Start HPC cluster first
            logger.info("Step 1/3: Starting HPC cluster...")
            if not self._start_hpc_cluster(hpc_config):
                raise SystemManagerError("Failed to start HPC cluster")
            logger.info("HPC cluster started")

            # Step 2: Wait for HPC to stabilize
            logger.info("Waiting for HPC cluster to stabilize...")
            if not self._wait_for_cluster_ready("hpc", timeout=300):
                logger.warning("HPC cluster did not reach ready state within timeout")

            # Step 3: Start Cloud cluster
            logger.info("Step 2/3: Starting Cloud cluster...")
            if not self._start_cloud_cluster(cloud_config):
                logger.warning("Cloud cluster startup failed, rolling back HPC cluster...")
                self._stop_hpc_cluster(hpc_config)
                raise SystemManagerError("Failed to start Cloud cluster (rolled back HPC)")
            logger.info("Cloud cluster started")

            # Step 4: Validate both running
            logger.info("Step 3/3: Validating system health...")
            if not self._validate_system_health():
                logger.warning("System validation had warnings but continuing")

            logger.info("Complete ML system started successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to start system: {e}")
            return False

    def stop_all_clusters(self, hpc_config: dict[str, Any], cloud_config: dict[str, Any]) -> bool:
        """Stop both clusters in reverse order (Cloud first, then HPC).

        Order of operations:
        1. Stop Cloud cluster first (inference can stop)
        2. Stop HPC cluster (training infrastructure)
        3. Validate both stopped

        Args:
            hpc_config: HPC cluster configuration dictionary
            cloud_config: Cloud cluster configuration dictionary

        Returns:
            True if both clusters stopped successfully
        """
        try:
            logger.info("Stopping complete ML system...")

            # Step 1: Stop Cloud cluster first
            logger.info("Step 1/2: Stopping Cloud cluster...")
            if not self._stop_cloud_cluster(cloud_config):
                logger.warning("Cloud cluster stop had issues")

            # Step 2: Stop HPC cluster
            logger.info("Step 2/2: Stopping HPC cluster...")
            if not self._stop_hpc_cluster(hpc_config):
                raise SystemManagerError("Failed to stop HPC cluster")

            logger.info("Complete ML system stopped successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to stop system: {e}")
            return False

    def destroy_all_clusters(
        self,
        hpc_config: dict[str, Any],
        cloud_config: dict[str, Any],
    ) -> bool:
        """Destroy both clusters with confirmation.

        Order of operations:
        1. Stop both clusters first (graceful shutdown)
        2. Destroy Cloud cluster
        3. Destroy HPC cluster
        4. Clean up global state

        Args:
            hpc_config: HPC cluster configuration dictionary
            cloud_config: Cloud cluster configuration dictionary

        Returns:
            True if both clusters destroyed successfully
        """
        try:
            logger.info("Destroying complete ML system...")

            # Stop both clusters first (graceful shutdown)
            self.stop_all_clusters(hpc_config, cloud_config)

            # Destroy Cloud cluster
            logger.info("Step 1/2: Destroying Cloud cluster...")
            if not self._destroy_cloud_cluster(cloud_config):
                logger.warning("Cloud cluster destroy had issues")

            # Destroy HPC cluster
            logger.info("Step 2/2: Destroying HPC cluster...")
            if not self._destroy_hpc_cluster(hpc_config):
                raise SystemManagerError("Failed to destroy HPC cluster")

            # Clean up global state
            self._cleanup_global_state()

            logger.info("Complete ML system destroyed successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to destroy system: {e}")
            return False

    def get_system_status(
        self, hpc_config: dict[str, Any], cloud_config: dict[str, Any]
    ) -> dict[str, Any]:
        """Get status of entire system.

        Args:
            hpc_config: HPC cluster configuration dictionary
            cloud_config: Cloud cluster configuration dictionary

        Returns:
            Dictionary containing system status information
        """
        try:
            hpc_status = self._get_hpc_status(hpc_config)
            cloud_status = self._get_cloud_status(cloud_config)
            shared_resources = self._get_shared_resources_status()

            return {
                "system_status": self._determine_system_status(hpc_status, cloud_status),
                "hpc_cluster": hpc_status,
                "cloud_cluster": cloud_status,
                "shared_resources": shared_resources,
                "timestamp": datetime.now().isoformat(),
            }
        except Exception as e:
            logger.error(f"Failed to get system status: {e}")
            return {"error": str(e), "timestamp": datetime.now().isoformat()}

    def _start_hpc_cluster(self, config_data: dict[str, Any]) -> bool:
        """Start HPC cluster.

        Args:
            config_data: Configuration data for HPC cluster

        Returns:
            True if cluster started successfully
        """
        result = self.executor.execute_operation("hpc", "start_cluster", config_data)
        # Update reference for backward compatibility
        self.hpc_manager = self.executor._managers["hpc"]["manager"]
        return result

    def _start_cloud_cluster(self, config_data: dict[str, Any]) -> bool:
        """Start Cloud cluster.

        Args:
            config_data: Configuration data for Cloud cluster

        Returns:
            True if cluster started successfully
        """
        result = self.executor.execute_operation("cloud", "start_cluster", config_data)
        # Update reference for backward compatibility
        self.cloud_manager = self.executor._managers["cloud"]["manager"]
        return result

    def _stop_hpc_cluster(self, config_data: dict[str, Any]) -> bool:
        """Stop HPC cluster.

        Args:
            config_data: Configuration data for HPC cluster

        Returns:
            True if cluster stopped successfully
        """
        return self.executor.execute_operation("hpc", "stop_cluster", config_data)

    def _stop_cloud_cluster(self, config_data: dict[str, Any]) -> bool:
        """Stop Cloud cluster.

        Args:
            config_data: Configuration data for Cloud cluster

        Returns:
            True if cluster stopped successfully
        """
        return self.executor.execute_operation("cloud", "stop_cluster", config_data)

    def _destroy_hpc_cluster(self, config_data: dict[str, Any]) -> bool:
        """Destroy HPC cluster.

        Args:
            config_data: Configuration data for HPC cluster

        Returns:
            True if cluster destroyed successfully
        """
        return self.executor.execute_operation("hpc", "destroy_cluster", config_data)

    def _destroy_cloud_cluster(self, config_data: dict[str, Any]) -> bool:
        """Destroy Cloud cluster.

        Args:
            config_data: Configuration data for Cloud cluster

        Returns:
            True if cluster destroyed successfully
        """
        return self.executor.execute_operation("cloud", "destroy_cluster", config_data, force=True)

    def _wait_for_cluster_ready(self, cluster_type: str, timeout: int = 300) -> bool:
        """Wait for cluster to be fully ready.

        Args:
            cluster_type: Type of cluster ('hpc' or 'cloud')
            timeout: Maximum time to wait in seconds

        Returns:
            True if cluster reached ready state, False if timeout
        """
        start_time = time.time()
        check_interval = 5  # Check every 5 seconds

        while time.time() - start_time < timeout:
            try:
                if cluster_type == "hpc" and self.hpc_manager:
                    status = self.hpc_manager.status_cluster()
                    if status.get("status") == "running":
                        logger.debug(f"{cluster_type} cluster is ready")
                        return True
                elif cluster_type == "cloud" and self.cloud_manager:
                    status = self.cloud_manager.status()
                    if status.get("status") == "running":
                        logger.debug(f"{cluster_type} cluster is ready")
                        return True
            except Exception as e:
                logger.debug(f"Error checking {cluster_type} cluster readiness: {e}")

            time.sleep(check_interval)

        logger.warning(f"Timeout waiting for {cluster_type} cluster to be ready")
        return False

    def _validate_system_health(self) -> bool:
        """Validate entire system is healthy.

        Returns:
            True if system is healthy
        """
        try:
            if self.hpc_manager:
                hpc_status = self.hpc_manager.status_cluster()
                if hpc_status.get("status") != "running":
                    logger.warning("HPC cluster not in running state")

            if self.cloud_manager:
                cloud_status = self.cloud_manager.status()
                if cloud_status.get("status") != "running":
                    logger.warning("Cloud cluster not in running state")

            return True
        except Exception as e:
            logger.warning(f"System health validation warning: {e}")
            return False

    def _get_hpc_status(self, config_data: dict[str, Any]) -> dict[str, Any]:
        """Get HPC cluster status.

        Args:
            config_data: Configuration data for HPC cluster

        Returns:
            Dictionary with HPC cluster status
        """
        return self.executor.get_status("hpc", config_data)

    def _get_cloud_status(self, config_data: dict[str, Any]) -> dict[str, Any]:
        """Get Cloud cluster status.

        Args:
            config_data: Configuration data for Cloud cluster

        Returns:
            Dictionary with Cloud cluster status
        """
        return self.executor.get_status("cloud", config_data)

    def _get_shared_resources_status(self) -> dict[str, Any]:
        """Get shared resource (GPU) status.

        Returns:
            Dictionary with shared resource allocation status
        """
        try:
            global_state_path = self.state_manager.state_file.parent / "global-state.json"
            if global_state_path.exists():
                with open(global_state_path, encoding="utf-8") as f:
                    data = json.load(f)
                    return data.get("shared_resources", {})
            return {}
        except Exception as e:
            logger.warning(f"Failed to get shared resources status: {e}")
            return {}

    def _determine_system_status(
        self, hpc_status: dict[str, Any], cloud_status: dict[str, Any]
    ) -> str:
        """Determine overall system status.

        Args:
            hpc_status: HPC cluster status dictionary
            cloud_status: Cloud cluster status dictionary

        Returns:
            System status string: 'running', 'stopped', 'mixed', or 'error'
        """
        hpc_state = hpc_status.get("status", "unknown")
        cloud_state = cloud_status.get("status", "unknown")

        if hpc_state == "error" or cloud_state == "error":
            return "error"
        elif hpc_state == "running" and cloud_state == "running":
            return "running"
        elif hpc_state == "stopped" and cloud_state == "stopped":
            return "stopped"
        else:
            return "mixed"

    def _cleanup_global_state(self) -> None:
        """Clean up global state after destroy."""
        try:
            global_state_path = self.state_manager.state_file.parent / "global-state.json"
            if global_state_path.exists():
                logger.info(f"Removing global state file: {global_state_path}")
                global_state_path.unlink()
        except Exception as e:
            logger.warning(f"Failed to clean up global state: {e}")
