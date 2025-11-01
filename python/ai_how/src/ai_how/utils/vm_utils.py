"""VM utility functions for cluster management."""

import hashlib
from pathlib import Path
from typing import Any


def generate_mac_address(vm_name: str) -> str:
    """Generate consistent MAC address for VM based on name.

    Creates a deterministic MAC address from the VM name using MD5 hashing.
    The generated MAC address has the local admin bit set and unicast bit cleared.

    Args:
        vm_name: Name of the VM

    Returns:
        MAC address in format "XX:XX:XX:XX:XX:XX"

    Example:
        >>> mac = generate_mac_address("my-cluster-worker-01")
        >>> print(mac)  # e.g., "02:ab:cd:ef:12:34"
    """
    # Create deterministic MAC address based on VM name
    # MD5 is used here for deterministic, non-cryptographic purposes only (not for security).
    hash_object = hashlib.md5(vm_name.encode())
    hex_dig = hash_object.hexdigest()

    # Use first 6 bytes and ensure it's a valid MAC
    mac_bytes = [hex_dig[i : i + 2] for i in range(0, 12, 2)]

    # Ensure first byte is even (unicast) and has local admin bit set
    mac_bytes[0] = f"{(int(mac_bytes[0], 16) & 0xFE) | 0x02:02x}"

    return ":".join(mac_bytes)


def has_gpu_passthrough(config: dict[str, Any]) -> bool:
    """Check if a node configuration has GPU passthrough enabled.

    A configuration is considered to have GPU passthrough if:
    1. pcie_passthrough.enabled is True, AND
    2. At least one device has device_type == "gpu"

    Args:
        config: Node configuration dictionary (worker/compute node)

    Returns:
        True if node has GPU passthrough configured, False otherwise

    Example:
        >>> config = {
        ...     "pcie_passthrough": {
        ...         "enabled": True,
        ...         "devices": [
        ...             {"pci_address": "0000:01:00.0", "device_type": "gpu"}
        ...         ]
        ...     }
        ... }
        >>> has_gpu_passthrough(config)
        True
    """
    pcie_config = config.get("pcie_passthrough", {})
    if not pcie_config.get("enabled", False):
        return False

    devices = pcie_config.get("devices", [])
    return any(dev.get("device_type") == "gpu" for dev in devices)


def get_project_root(reference_path: Path) -> Path:
    """Find the project root by searching for marker files.

    This function searches upward from the reference path for project markers
    like .git directory, pyproject.toml, or CMakeLists.txt to reliably identify
    the project root.

    Args:
        reference_path: Path to a file or directory within the project
                       (e.g., config file, state file, or module file)

    Returns:
        Path to the project root directory

    Raises:
        FileNotFoundError: If project root cannot be determined after searching
                          up to 10 directory levels
    """
    markers = [".git", "pyproject.toml", "CMakeLists.txt"]
    current = reference_path.resolve()

    # If it's a file, start from its directory
    if current.is_file():
        current = current.parent

    # Search up to 10 levels to find a marker
    for _ in range(10):
        for marker in markers:
            if (current / marker).exists():
                return current
        if current.parent == current:
            # Reached filesystem root
            break
        current = current.parent

    # If no marker found, raise an error
    raise FileNotFoundError(
        f"Could not find project root markers (.git, pyproject.toml, CMakeLists.txt) "
        f"near {reference_path}. Searched up to 10 directory levels."
    )
