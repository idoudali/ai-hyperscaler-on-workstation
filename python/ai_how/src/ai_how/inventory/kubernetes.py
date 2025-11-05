"""Kubernetes/Kubespray inventory generator."""

import ipaddress
import sys
from pathlib import Path
from typing import Any

from ai_how.inventory.base import BaseInventoryGenerator
from ai_how.utils.vm_utils import has_gpu_passthrough


class KubernetesInventoryGenerator(BaseInventoryGenerator):
    """Generate Ansible inventory for Kubernetes clusters using Kubespray.

    Generates inventory with the following groups:
    - kube_control_plane: Kubernetes control plane nodes
    - etcd: etcd cluster nodes (typically same as control plane)
    - kube_node: All worker nodes
    - calico_rr: Calico route reflectors (typically empty)
    - k8s_cluster: Parent group containing all nodes

    Kubespray-specific requirements:
    - ansible_become=true must be set (Kubespray needs sudo)
    - Both ansible_host and ip variables required
    - Skips shut-off VMs from inventory
    """

    def __init__(
        self,
        config_path: str | Path,
        cluster_name: str,
        ssh_key_path: str | Path | None = None,
        ssh_username: str = "admin",
    ):
        """Initialize Kubernetes inventory generator.

        Args:
            config_path: Path to cluster configuration YAML file
            cluster_name: Name of cluster to generate inventory for
            ssh_key_path: Path to SSH private key (default: build/shared/ssh-keys/id_rsa)
            ssh_username: SSH username (default: admin, matching Packer build)
        """
        super().__init__(config_path, cluster_name, ssh_key_path, ssh_username)

        # Extract network configuration for IP calculations
        subnet_str = "192.168.200.0/24"  # Default fallback
        if "network" in self.cluster_config and "subnet" in self.cluster_config["network"]:
            subnet_str = self.cluster_config["network"]["subnet"]

        try:
            network = ipaddress.IPv4Network(subnet_str, strict=False)
            self.network_base = str(network.network_address).split(".")[:3]
        except (ValueError, AttributeError) as e:
            raise ValueError(f"Invalid subnet configuration '{subnet_str}': {e}") from e

    def generate(self) -> dict[str, Any]:
        """Generate Kubernetes cluster inventory.

        Returns:
            Dictionary with inventory structure:
            {
                'groups': {
                    'kube_control_plane': {...},
                    'etcd': {...},
                    'kube_node': {...},
                    'calico_rr': {...},
                    'k8s_cluster': {...}
                }
            }
        """
        inventory: dict[str, Any] = {"groups": {}}

        # Initialize group structures
        inventory["groups"]["kube_control_plane"] = {"hosts": {}, "vars": {}}
        inventory["groups"]["etcd"] = {"hosts": {}, "vars": {}}
        inventory["groups"]["kube_node"] = {"hosts": {}, "vars": {}}
        inventory["groups"]["calico_rr"] = {"hosts": {}, "vars": {}}
        inventory["groups"]["k8s_cluster"] = {
            "hosts": {},
            "children": ["kube_control_plane", "kube_node", "calico_rr"],
            "vars": {},
        }

        # Extract nodes
        nodes = self._extract_cloud_cluster_nodes()

        # Add control plane nodes
        self._add_control_plane_nodes(inventory, nodes)

        # Add worker nodes
        self._add_worker_nodes(inventory, nodes)

        return inventory

    def _extract_cloud_cluster_nodes(self) -> dict[str, list[dict[str, Any]]]:
        """Extract cloud cluster node information from configuration.

        Returns:
            Dictionary with node groups: {
                'control_plane': [{'name': '...', 'ip': '...'}, ...],
                'cpu_workers': [{'name': '...', 'ip': '...'}, ...],
                'gpu_workers': [{'name': '...', 'ip': '...'}, ...]
            }
        """
        nodes = {"control_plane": [], "cpu_workers": [], "gpu_workers": []}

        # Extract control plane node
        control_plane_ip_offset = 10  # Default offset
        if "control_plane" in self.cluster_config:
            control_plane = self.cluster_config["control_plane"]
            control_plane_ip = control_plane.get("ip_address") or control_plane.get("ip", None)

            if control_plane_ip:
                # Extract last octet to determine offset
                control_plane_ip_parts = control_plane_ip.split(".")
                if len(control_plane_ip_parts) == 4:
                    control_plane_ip_offset = int(control_plane_ip_parts[3])
            else:
                # Calculate default control plane IP
                control_plane_ip = f"{'.'.join(self.network_base)}.{control_plane_ip_offset}"

            nodes["control_plane"].append(
                {
                    "name": "control-plane",
                    "ip": control_plane_ip,
                    "ansible_host": control_plane_ip,
                }
            )

        # Extract worker nodes
        if "worker_nodes" in self.cluster_config:
            worker_nodes = self.cluster_config["worker_nodes"]

            if not isinstance(worker_nodes, list):
                raise ValueError(
                    f"'worker_nodes' must be a list (got {type(worker_nodes).__name__})"
                )

            cpu_worker_idx = 1
            gpu_worker_idx = 1

            for node in worker_nodes:
                # Determine if this is a GPU worker
                is_gpu_worker = has_gpu_passthrough(node)

                if is_gpu_worker:
                    # GPU worker - start after control plane with buffer
                    gpu_worker_start_offset = control_plane_ip_offset + 10
                    gpu_ip_offset = gpu_worker_start_offset + gpu_worker_idx
                    default_gpu_ip = f"{'.'.join(self.network_base)}.{gpu_ip_offset}"
                    gpu_ip = node.get("ip") or node.get("ip_address", default_gpu_ip)

                    nodes["gpu_workers"].append(
                        {
                            "name": f"gpu-worker-{gpu_worker_idx:02d}",
                            "ip": gpu_ip,
                            "ansible_host": gpu_ip,
                        }
                    )
                    gpu_worker_idx += 1
                else:
                    # CPU worker - start at control_plane + 1
                    cpu_ip_offset = control_plane_ip_offset + cpu_worker_idx
                    default_cpu_ip = f"{'.'.join(self.network_base)}.{cpu_ip_offset}"
                    cpu_ip = node.get("ip") or node.get("ip_address", default_cpu_ip)

                    nodes["cpu_workers"].append(
                        {
                            "name": f"cpu-worker-{cpu_worker_idx:02d}",
                            "ip": cpu_ip,
                            "ansible_host": cpu_ip,
                        }
                    )
                    cpu_worker_idx += 1

        return nodes

    def _add_control_plane_nodes(
        self, inventory: dict[str, Any], nodes: dict[str, list[dict[str, Any]]]
    ) -> None:
        """Add control plane nodes to inventory.

        Args:
            inventory: Inventory structure to populate
            nodes: Extracted node information
        """
        for node in nodes["control_plane"]:
            hostname = node["name"]
            ip = node["ip"]

            # Get cluster name from config (fallback to cluster_name parameter)
            cluster_display_name = self.cluster_config.get("name", self.cluster_name)

            # Query live IP
            domain_name = f"{cluster_display_name}-{hostname}"
            live_ip, _ = self.query_live_ip(hostname, ip, domain_name)

            if live_ip is None:
                # Domain is shut off, skip
                print(f"ℹ️  Skipping shut-off domain: {domain_name}", file=sys.stderr)
                continue

            ansible_host = live_ip

            # Build host variables (Kubespray requires both ansible_host and ip)
            host_vars = {
                "ansible_host": ansible_host,
                "ip": ansible_host,
                "ansible_user": self.ssh_username,
                "ansible_ssh_private_key_file": str(self.ssh_key_path),
                "ansible_ssh_common_args": (
                    "'-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'"
                ),
                "ansible_become": "true",  # Required by Kubespray
            }

            # Add to control plane and etcd groups
            inventory["groups"]["kube_control_plane"]["hosts"][hostname] = host_vars
            inventory["groups"]["etcd"]["hosts"][hostname] = host_vars

    def _add_worker_nodes(
        self, inventory: dict[str, Any], nodes: dict[str, list[dict[str, Any]]]
    ) -> None:
        """Add worker nodes to inventory.

        Args:
            inventory: Inventory structure to populate
            nodes: Extracted node information
        """
        # Combine CPU and GPU workers
        all_workers = nodes["cpu_workers"] + nodes["gpu_workers"]

        for node in all_workers:
            hostname = node["name"]
            ip = node["ip"]

            # Get cluster name from config (fallback to cluster_name parameter)
            cluster_display_name = self.cluster_config.get("name", self.cluster_name)

            # Query live IP
            domain_name = f"{cluster_display_name}-{hostname}"
            live_ip, _ = self.query_live_ip(hostname, ip, domain_name)

            if live_ip is None:
                # Domain is shut off, skip
                print(f"ℹ️  Skipping shut-off domain: {domain_name}", file=sys.stderr)
                continue

            ansible_host = live_ip

            # Build host variables (Kubespray requires both ansible_host and ip)
            host_vars = {
                "ansible_host": ansible_host,
                "ip": ansible_host,
                "ansible_user": self.ssh_username,
                "ansible_ssh_private_key_file": str(self.ssh_key_path),
                "ansible_ssh_common_args": (
                    "'-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'"
                ),
                "ansible_become": "true",  # Required by Kubespray
            }

            # Add to worker nodes group
            inventory["groups"]["kube_node"]["hosts"][hostname] = host_vars
