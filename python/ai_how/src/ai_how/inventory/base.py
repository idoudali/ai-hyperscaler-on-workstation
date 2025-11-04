"""Base inventory generator with shared functionality."""

import sys
from pathlib import Path
from typing import Any

import yaml

from ai_how.utils.virsh_utils import get_domain_ip, get_domain_state
from ai_how.utils.vm_utils import has_gpu_passthrough


class BaseInventoryGenerator:
    """Base class for inventory generators with shared functionality.

    Provides common logic for:
    - Loading cluster configuration
    - Extracting node information
    - Querying live IPs from libvirt
    - SSH configuration handling
    - GPU passthrough detection
    """

    def __init__(
        self,
        config_path: str | Path,
        cluster_name: str,
        ssh_key_path: str | Path | None = None,
        ssh_username: str = "admin",
    ):
        """Initialize base inventory generator.

        Args:
            config_path: Path to cluster configuration YAML file
            cluster_name: Name of cluster to generate inventory for
            ssh_key_path: Path to SSH private key (default: build/shared/ssh-keys/id_rsa)
            ssh_username: SSH username (default: admin, matching Packer build)
        """
        self.config_path = Path(config_path)
        self.cluster_name = cluster_name
        self.ssh_username = ssh_username

        # Load configuration
        with open(self.config_path) as f:
            self.config = yaml.safe_load(f)

        if "clusters" not in self.config:
            raise ValueError("No clusters found in configuration")

        if cluster_name not in self.config["clusters"]:
            raise ValueError(f"Cluster '{cluster_name}' not found in configuration")

        self.cluster_config = self.config["clusters"][cluster_name]

        # Set up SSH key path
        if ssh_key_path is None:
            # Default to Packer build SSH keys
            project_root = self._find_project_root()
            self.ssh_key_path = project_root / "build" / "shared" / "ssh-keys" / "id_rsa"
        else:
            self.ssh_key_path = Path(ssh_key_path)

        # Verify SSH key exists
        if not self.ssh_key_path.exists():
            print(
                f"⚠️  WARNING: SSH private key not found at: {self.ssh_key_path}",
                file=sys.stderr,
            )
            print(
                "   Run 'make config' or build Packer images to generate SSH keys",
                file=sys.stderr,
            )

    def _find_project_root(self) -> Path:
        """Find project root by searching for marker files.

        Returns:
            Path to project root directory

        Raises:
            FileNotFoundError: If project root cannot be determined
        """
        markers = [".git", "pyproject.toml", "CMakeLists.txt"]
        current = self.config_path.resolve().parent

        # Search up to 10 levels
        for _ in range(10):
            for marker in markers:
                if (current / marker).exists():
                    return current
            if current.parent == current:
                # Reached filesystem root
                break
            current = current.parent

        raise FileNotFoundError(
            "Could not find project root markers (.git, pyproject.toml, CMakeLists.txt)"
        )

    def get_ssh_args(self, include_become: bool = False) -> str:
        """Get SSH connection arguments for Ansible.

        Args:
            include_become: Whether to include ansible_become=true

        Returns:
            String with Ansible SSH connection arguments
        """
        args = [
            f"ansible_ssh_private_key_file={self.ssh_key_path}",
            "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'",
        ]

        if include_become:
            args.append("ansible_become=true")

        return " ".join(args)

    def query_live_ip(
        self, node_name: str, configured_ip: str, domain_name: str
    ) -> tuple[str | None, bool]:
        """Query live IP from libvirt domain.

        Args:
            node_name: Name of the node (for logging)
            configured_ip: IP address from cluster configuration
            domain_name: Libvirt domain name

        Returns:
            Tuple of (ip_address, ip_changed) where ip_changed indicates if live IP differs
        """
        # Check domain state
        state = get_domain_state(domain_name)
        if state and state.lower() != "running":
            # Domain is not running, skip
            return None, False

        # Query live IP
        live_ip = get_domain_ip(domain_name)
        if live_ip:
            if live_ip != configured_ip:
                print(
                    f"⚠️  WARNING: IP mismatch for {node_name}: "
                    f"config={configured_ip} live={live_ip}",
                    file=sys.stderr,
                )
                return live_ip, True
            return live_ip, False

        # No live IP found, use configured
        return configured_ip, False

    def detect_gpu_devices(self, node_config: dict[str, Any]) -> list[dict[str, Any]]:
        """Detect GPU devices from PCIe passthrough configuration.

        Args:
            node_config: Node configuration dictionary

        Returns:
            List of GPU device information dictionaries
        """
        gpu_devices = []

        if not has_gpu_passthrough(node_config):
            return gpu_devices

        pcie_config = node_config.get("pcie_passthrough", {})
        devices = pcie_config.get("devices", [])

        for device in devices:
            if device.get("device_type") == "gpu":
                gpu_info = {
                    "pci_address": device.get("pci_address", "unknown"),
                    "vendor_id": device.get("vendor_id", "10de"),
                    "device_id": device.get("device_id", "unknown"),
                    "device_type": "gpu",
                }
                gpu_devices.append(gpu_info)

        return gpu_devices

    def generate_slurm_gres(self, gpu_devices: list[dict[str, Any]], node_name: str) -> list[str]:
        """Generate SLURM GRES configuration for GPU devices.

        Args:
            gpu_devices: List of GPU device dictionaries
            node_name: SLURM node name

        Returns:
            List of GRES configuration strings
        """
        gres_lines = []

        for idx, gpu in enumerate(gpu_devices):
            vendor_id = gpu.get("vendor_id", "10de")
            device_id = gpu.get("device_id", "unknown")

            # Map vendor ID to name
            vendor_map = {"10de": "nvidia", "1002": "amd", "8086": "intel"}
            vendor = vendor_map.get(vendor_id.lower(), "unknown")

            # Create GPU type identifier
            gpu_type = f"{vendor}_{device_id}"

            # GRES format: NodeName=node01 Name=gpu Type=nvidia_2080ti File=/dev/nvidia0
            gres_line = f"NodeName={node_name} Name=gpu Type={gpu_type} File=/dev/nvidia{idx}"
            gres_lines.append(gres_line)

        return gres_lines

    def generate(self) -> dict[str, Any]:
        """Generate inventory structure.

        This method should be implemented by subclasses to generate
        cluster-specific inventory structures.

        Returns:
            Inventory data structure

        Raises:
            NotImplementedError: Must be implemented by subclass
        """
        raise NotImplementedError("Subclasses must implement generate()")
