"""Validation for shared GPU configurations between clusters."""

import logging
from typing import Any

logger = logging.getLogger(__name__)


class SharedGPUValidator:
    """Validates GPU sharing configuration between clusters."""

    def detect_shared_gpus(self, config_data: dict[str, Any]) -> dict[str, list[str]]:
        """Detect GPUs that are shared between clusters.

        Args:
            config_data: Complete cluster configuration dictionary

        Returns:
            Dictionary mapping PCI addresses to list of cluster names using them
            Example: {"0000:01:00.0": ["hpc", "cloud"]}
        """
        gpu_usage: dict[str, list[str]] = {}

        # Scan HPC cluster
        if "hpc" in config_data.get("clusters", {}):
            hpc_config = config_data["clusters"]["hpc"]
            gpus = self._extract_gpu_addresses(hpc_config)
            for gpu_addr in gpus:
                gpu_usage.setdefault(gpu_addr, []).append("hpc")

        # Scan Cloud cluster
        if "cloud" in config_data.get("clusters", {}):
            cloud_config = config_data["clusters"]["cloud"]
            gpus = self._extract_gpu_addresses(cloud_config)
            for gpu_addr in gpus:
                gpu_usage.setdefault(gpu_addr, []).append("cloud")

        # Return only shared GPUs (used by multiple clusters)
        shared = {addr: clusters for addr, clusters in gpu_usage.items() if len(clusters) > 1}
        if shared:
            logger.info(f"Detected shared GPUs: {shared}")
        return shared

    def _extract_gpu_addresses(self, cluster_config: dict[str, Any]) -> list[str]:
        """Extract all GPU PCI addresses from cluster configuration.

        Args:
            cluster_config: Cluster configuration dictionary

        Returns:
            List of GPU PCI addresses in this cluster
        """
        gpu_addresses = []

        # Check controller
        if "controller" in cluster_config:
            pcie = cluster_config["controller"].get("pcie_passthrough", {})
            gpu_addresses.extend(self._get_gpu_devices(pcie))

        # Check compute nodes
        for node in cluster_config.get("compute_nodes", []):
            pcie = node.get("pcie_passthrough", {})
            gpu_addresses.extend(self._get_gpu_devices(pcie))

        # Check worker nodes (for cloud)
        for _worker_type, nodes in cluster_config.get("worker_nodes", {}).items():
            for node in nodes:
                pcie = node.get("pcie_passthrough", {})
                gpu_addresses.extend(self._get_gpu_devices(pcie))

        return gpu_addresses

    def _get_gpu_devices(self, pcie_config: dict[str, Any]) -> list[str]:
        """Extract GPU device addresses from PCIe configuration.

        Args:
            pcie_config: PCIe passthrough configuration

        Returns:
            List of GPU PCI addresses
        """
        if not pcie_config.get("enabled", False):
            return []

        return [
            device["pci_address"]
            for device in pcie_config.get("devices", [])
            if device.get("device_type") == "gpu"
        ]
