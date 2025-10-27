"""Shared GPU validation for detecting GPU sharing between clusters."""

from __future__ import annotations

from typing import Any


class SharedGPUValidator:
    """Validates GPU sharing configuration between clusters.

    This validator detects when the same physical GPU (by PCI address) is configured
    for use by multiple clusters. While this is allowed in the configuration (to enable
    GPU time-sharing between clusters), it's important to identify these shared GPUs
    for proper resource management and conflict detection at runtime.
    """

    def detect_shared_gpus(self, config_data: dict[str, Any]) -> dict[str, list[str]]:
        """Detect GPUs that are shared between clusters.

        Analyzes the configuration and identifies any GPUs (by PCI address) that are
        configured for use by multiple clusters. This is useful for:
        - Warning users about potential conflicts
        - Enforcing runtime mutual exclusivity
        - Planning cluster startup order

        Args:
            config_data: Full configuration dictionary containing cluster definitions

        Returns:
            Dictionary mapping PCI addresses to list of cluster names using them.
            Only returns GPUs that are shared (used by 2+ clusters).

        Example:
            >>> config = {
            ...     "clusters": {
            ...         "hpc": {
            ...             "compute_nodes": [{
            ...                 "pcie_passthrough": {
            ...                     "enabled": True,
            ...                     "devices": [
            ...                         {"pci_address": "0000:01:00.0", "device_type": "gpu"}
            ...                     ]
            ...                 }
            ...             }]
            ...         },
            ...         "cloud": {
            ...             "worker_nodes": {
            ...                 "gpu": [{
            ...                     "pcie_passthrough": {
            ...                         "enabled": True,
            ...                         "devices": [
            ...                             {"pci_address": "0000:01:00.0", "device_type": "gpu"}
            ...                         ]
            ...                     }
            ...                 }]
            ...             }
            ...         }
            ...     }
            ... }
            >>> validator = SharedGPUValidator()
            >>> validator.detect_shared_gpus(config)
            {"0000:01:00.0": ["hpc", "cloud"]}
        """
        gpu_usage: dict[str, list[str]] = {}

        clusters = config_data.get("clusters", {})

        # Scan HPC cluster
        if "hpc" in clusters:
            hpc_config = clusters["hpc"]
            gpus = self._extract_gpu_addresses(hpc_config, cluster_type="hpc")
            for gpu_addr in gpus:
                gpu_usage.setdefault(gpu_addr, []).append("hpc")

        # Scan Cloud cluster
        if "cloud" in clusters:
            cloud_config = clusters["cloud"]
            gpus = self._extract_gpu_addresses(cloud_config, cluster_type="cloud")
            for gpu_addr in gpus:
                gpu_usage.setdefault(gpu_addr, []).append("cloud")

        # Return only shared GPUs (used by multiple clusters)
        return {
            addr: clusters_list
            for addr, clusters_list in gpu_usage.items()
            if len(clusters_list) > 1
        }

    def _extract_gpu_addresses(
        self,
        cluster_config: dict[str, Any],
        cluster_type: str,
    ) -> list[str]:
        """Extract all GPU PCI addresses from cluster configuration.

        Args:
            cluster_config: Configuration for a single cluster
            cluster_type: Type of cluster ('hpc' or 'cloud')

        Returns:
            List of GPU PCI addresses found in the cluster configuration
        """
        gpu_addresses: list[str] = []

        if cluster_type == "hpc":
            # Check HPC controller
            if "controller" in cluster_config:
                pcie = cluster_config["controller"].get("pcie_passthrough", {})
                gpu_addresses.extend(self._get_gpu_devices(pcie))

            # Check HPC compute nodes
            for node in cluster_config.get("compute_nodes", []):
                pcie = node.get("pcie_passthrough", {})
                gpu_addresses.extend(self._get_gpu_devices(pcie))

        elif cluster_type == "cloud":
            # Check Cloud control plane
            if "control_plane" in cluster_config:
                pcie = cluster_config["control_plane"].get("pcie_passthrough", {})
                gpu_addresses.extend(self._get_gpu_devices(pcie))

            # Check Cloud worker nodes
            worker_nodes = cluster_config.get("worker_nodes", {})

            # CPU workers
            for node in worker_nodes.get("cpu", []):
                pcie = node.get("pcie_passthrough", {})
                gpu_addresses.extend(self._get_gpu_devices(pcie))

            # GPU workers
            for node in worker_nodes.get("gpu", []):
                pcie = node.get("pcie_passthrough", {})
                gpu_addresses.extend(self._get_gpu_devices(pcie))

        return gpu_addresses

    def _get_gpu_devices(self, pcie_config: dict[str, Any]) -> list[str]:
        """Extract GPU device addresses from PCIe passthrough configuration.

        Args:
            pcie_config: PCIe passthrough configuration dictionary

        Returns:
            List of PCI addresses for GPU devices
        """
        if not pcie_config.get("enabled", False):
            return []

        return [
            device["pci_address"]
            for device in pcie_config.get("devices", [])
            if device.get("device_type") == "gpu"
        ]

    def get_gpu_summary(self, config_data: dict[str, Any]) -> dict[str, Any]:
        """Get a summary of GPU usage across all clusters.

        Provides a comprehensive view of GPU allocation including:
        - Total GPUs configured
        - Shared GPUs (used by multiple clusters)
        - Exclusive GPUs (used by single cluster)
        - Clusters using each GPU

        Args:
            config_data: Full configuration dictionary

        Returns:
            Dictionary with GPU usage summary information
        """
        shared_gpus = self.detect_shared_gpus(config_data)

        # Get all GPUs from all clusters
        all_gpus: dict[str, list[str]] = {}
        clusters = config_data.get("clusters", {})

        for cluster_name, cluster_config in clusters.items():
            gpus = self._extract_gpu_addresses(cluster_config, cluster_type=cluster_name)
            for gpu_addr in gpus:
                all_gpus.setdefault(gpu_addr, []).append(cluster_name)

        # Categorize GPUs
        exclusive_gpus = {
            addr: clusters_list
            for addr, clusters_list in all_gpus.items()
            if len(clusters_list) == 1
        }

        return {
            "total_gpus": len(all_gpus),
            "shared_gpus": shared_gpus,
            "shared_gpu_count": len(shared_gpus),
            "exclusive_gpus": exclusive_gpus,
            "exclusive_gpu_count": len(exclusive_gpus),
            "all_gpus": all_gpus,
        }
