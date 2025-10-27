"""Configuration parsing utilities for cluster managers."""

from typing import Any


class ClusterConfigParser:
    """Parses and extracts cluster-specific configuration."""

    @staticmethod
    def extract_cluster_config(
        config: dict[str, Any], cluster_type: str
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        """Extract cluster-specific and global configuration.

        Handles both full configuration structure with nested clusters
        and direct cluster-specific configuration.

        Args:
            config: Full configuration dictionary
            cluster_type: Type of cluster ('hpc' or 'cloud')

        Returns:
            Tuple of (cluster_config, global_config)

        Examples:
            >>> # Full config structure
            >>> config = {
            ...     "clusters": {
            ...         "hpc": {"name": "my-hpc", ...},
            ...         "cloud": {"name": "my-cloud", ...}
            ...     },
            ...     "global": {"setting": "value"}
            ... }
            >>> hpc_config, global_config = ClusterConfigParser.extract_cluster_config(
            ...     config, "hpc"
            ... )

            >>> # Direct cluster config
            >>> config = {"name": "my-hpc", ...}
            >>> hpc_config, global_config = ClusterConfigParser.extract_cluster_config(
            ...     config, "hpc"
            ... )
        """
        if "clusters" in config and cluster_type in config["clusters"]:
            # Full config structure with nested clusters
            return (config["clusters"][cluster_type], config.get("global", {}))
        else:
            # Assume config is already cluster-specific
            return config, {}
