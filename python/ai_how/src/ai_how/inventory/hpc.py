"""HPC/SLURM inventory generator."""

import json
import sys
from typing import Any

from ai_how.inventory.base import BaseInventoryGenerator


class HPCInventoryGenerator(BaseInventoryGenerator):
    """Generate Ansible inventory for HPC/SLURM clusters.

    Generates inventory with the following groups:
    - hpc_controllers: SLURM controller/head node
    - hpc_compute_nodes: Regular CPU compute nodes
    - hpc_gpu_nodes: GPU-enabled compute nodes
    - hpc: Parent group containing all HPC nodes

    Extracts HPC-specific configuration:
    - SLURM node names and configuration
    - GPU GRES configuration for SLURM
    - BeeGFS storage configuration
    - VirtIO-FS mount points
    """

    def generate(self) -> dict[str, Any]:
        """Generate HPC cluster inventory.

        Returns:
            Dictionary with inventory structure:
            {
                'groups': {
                    'hpc_controllers': {...},
                    'hpc_compute_nodes': {...},
                    'hpc_gpu_nodes': {...},
                    'hpc': {...}
                }
            }
        """
        inventory: dict[str, Any] = {"groups": {}}

        # Initialize group structures
        inventory["groups"]["hpc_controllers"] = {"hosts": {}, "vars": {}}
        inventory["groups"]["hpc_compute_nodes"] = {"hosts": {}, "vars": {}}
        inventory["groups"]["hpc_gpu_nodes"] = {"hosts": {}, "vars": {}}
        inventory["groups"]["hpc"] = {
            "hosts": {},
            "children": ["hpc_controllers", "hpc_compute_nodes", "hpc_gpu_nodes"],
            "vars": {},
        }

        # Extract controller node
        self._extract_controller(inventory)

        # Extract compute nodes
        self._extract_compute_nodes(inventory)

        # Extract cluster-level variables
        self._extract_cluster_vars(inventory)

        # Remove empty groups
        self._cleanup_empty_groups(inventory)

        return inventory

    def _extract_controller(self, inventory: dict[str, Any]) -> None:
        """Extract HPC controller node information.

        Args:
            inventory: Inventory structure to populate
        """
        if "controller" not in self.cluster_config:
            return

        controller = self.cluster_config["controller"]
        hostname = f"{self.cluster_name}-controller"
        slurm_name = "controller"

        # Get IP address
        ip = controller.get("ip_address", "192.168.100.10")
        domain_name = f"{self.cluster_name}-cluster-controller"
        live_ip, _ = self.query_live_ip(hostname, ip, domain_name)

        if live_ip is None:
            # Domain is shut off, skip
            print(f"ℹ️  Skipping shut-off domain: {domain_name}", file=sys.stderr)
            return

        # Build host variables
        host_vars = {
            "ansible_host": live_ip,
            "ansible_user": self.ssh_username,
            "ansible_ssh_private_key_file": str(self.ssh_key_path),
            "slurm_node_name": slurm_name,
            "cpu_cores": controller.get("cpu_cores", 4),
            "memory_gb": controller.get("memory_gb", 8),
            "disk_gb": controller.get("disk_gb", 100),
            "base_image_path": controller.get("base_image_path", ""),
            "node_role": "controller",
        }

        inventory["groups"]["hpc_controllers"]["hosts"][hostname] = host_vars

    def _extract_compute_nodes(self, inventory: dict[str, Any]) -> None:
        """Extract HPC compute nodes information.

        Args:
            inventory: Inventory structure to populate
        """
        if "compute_nodes" not in self.cluster_config:
            return

        compute_nodes = self.cluster_config["compute_nodes"]
        all_gres_lines = []

        for idx, node in enumerate(compute_nodes, start=1):
            hostname = f"{self.cluster_name}-compute{idx:02d}"
            slurm_name = f"compute-{idx:02d}"

            # Get IP address
            ip = node.get("ip", f"192.168.100.{10 + idx}")
            domain_name = f"{self.cluster_name}-cluster-compute{idx:02d}"
            live_ip, _ = self.query_live_ip(hostname, ip, domain_name)

            if live_ip is None:
                # Domain is shut off, skip
                print(f"ℹ️  Skipping shut-off domain: {domain_name}", file=sys.stderr)
                continue

            # Build host variables
            host_vars = {
                "ansible_host": live_ip,
                "ansible_user": self.ssh_username,
                "ansible_ssh_private_key_file": str(self.ssh_key_path),
                "slurm_node_name": slurm_name,
                "cpu_cores": node.get("cpu_cores", 8),
                "memory_gb": node.get("memory_gb", 16),
                "disk_gb": node.get("disk_gb", 200),
                "base_image_path": node.get("base_image_path", ""),
                "node_role": "compute",
                "has_gpu": False,
            }

            # Detect GPU devices
            gpu_devices = self.detect_gpu_devices(node)

            if gpu_devices:
                # This is a GPU node
                host_vars["has_gpu"] = True
                host_vars["node_role"] = "gpu_compute"
                host_vars["gpu_count"] = len(gpu_devices)

                # Generate SLURM GRES configuration
                gres_lines = self.generate_slurm_gres(gpu_devices, slurm_name)
                all_gres_lines.extend(gres_lines)

                inventory["groups"]["hpc_gpu_nodes"]["hosts"][hostname] = host_vars
            else:
                # Regular compute node
                inventory["groups"]["hpc_compute_nodes"]["hosts"][hostname] = host_vars

        # Store global GRES configuration
        if all_gres_lines:
            inventory["groups"]["hpc"]["vars"]["slurm_gres_conf"] = all_gres_lines

    def _extract_cluster_vars(self, inventory: dict[str, Any]) -> None:
        """Extract cluster-level variables.

        Args:
            inventory: Inventory structure to populate
        """
        hpc_vars = inventory["groups"]["hpc"]["vars"]

        # Cluster name
        hpc_vars["cluster_name"] = self.cluster_config.get("name", self.cluster_name)

        # Python interpreter
        hpc_vars["ansible_python_interpreter"] = "/usr/bin/python3"

        # SLURM configuration
        slurm_config = self.cluster_config.get("slurm_config", {})
        if slurm_config:
            partitions = slurm_config.get("partitions", [])
            if partitions:
                hpc_vars["slurm_config"] = slurm_config

        # Network configuration
        network = self.cluster_config.get("network", {})
        if network:
            hpc_vars["network"] = network

        # VirtIO-FS mounts (from controller config)
        if "controller" in self.cluster_config:
            controller = self.cluster_config["controller"]
            virtio_fs_mounts = controller.get("virtio_fs_mounts", [])
            if virtio_fs_mounts:
                # Convert to JSON string for Ansible variable
                virtio_fs_json = json.dumps(virtio_fs_mounts, separators=(",", ":"))
                hpc_vars["virtio_fs_mounts"] = virtio_fs_json
                print(
                    f"✅ Found {len(virtio_fs_mounts)} VirtIO-FS mount(s) "
                    "in controller configuration",
                    file=sys.stderr,
                )
            else:
                print(
                    "ℹ️  No VirtIO-FS mounts found in controller configuration",
                    file=sys.stderr,
                )

        # BeeGFS configuration
        if "storage" in self.cluster_config:
            storage = self.cluster_config["storage"]
            beegfs_config = storage.get("beegfs", {})
            if beegfs_config.get("enabled", False):
                # Convert to JSON string for Ansible variable
                beegfs_json = json.dumps(beegfs_config, separators=(",", ":"))
                hpc_vars["beegfs_config"] = beegfs_json
                hpc_vars["beegfs_enabled"] = "true"
                mount_point = beegfs_config.get("mount_point", "/mnt/beegfs")
                print(
                    f"✅ BeeGFS enabled with mount point: {mount_point}",
                    file=sys.stderr,
                )
            else:
                hpc_vars["beegfs_enabled"] = "false"
                print("ℹ️  BeeGFS disabled in cluster configuration", file=sys.stderr)
        else:
            hpc_vars["beegfs_enabled"] = "false"
            print("ℹ️  No BeeGFS configuration found in cluster", file=sys.stderr)

    def _cleanup_empty_groups(self, inventory: dict[str, Any]) -> None:
        """Remove groups with no hosts.

        Args:
            inventory: Inventory structure to clean up
        """
        groups_to_remove = []

        for group_name, group_data in inventory["groups"].items():
            # Don't remove parent groups
            if group_name == "hpc":
                continue

            hosts = group_data.get("hosts", {})
            if not hosts:
                groups_to_remove.append(group_name)

        # Remove empty groups
        for group_name in groups_to_remove:
            del inventory["groups"][group_name]

            # Remove from parent group children
            hpc_children = inventory["groups"]["hpc"]["children"]
            if group_name in hpc_children:
                hpc_children.remove(group_name)
