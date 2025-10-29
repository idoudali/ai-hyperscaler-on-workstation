"""Utility functions for interacting with virsh/libvirt."""

import ipaddress
import re
import subprocess


def get_domain_ip(domain_name: str) -> str | None:
    """Get the IP address of a libvirt domain via virsh domifaddr.

    This function queries virsh for the network interface addresses of a given
    domain and extracts the first valid IPv4 address found.

    Args:
        domain_name: Name of the libvirt domain

    Returns:
        The IPv4 address as a string if found, None otherwise

    Example:
        >>> ip = get_domain_ip("my-vm-domain")
        >>> if ip:
        ...     print(f"VM IP: {ip}")
    """
    try:
        output = subprocess.check_output(
            ["virsh", "domifaddr", domain_name], text=True, stderr=subprocess.DEVNULL
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None

    # Parse output lines for IPv4 addresses in CIDR format
    for line in output.splitlines():
        line = line.strip()
        # Match IPv4 address in CIDR notation (e.g., "192.168.122.10/24")
        match = re.search(r"\b(\d+\.\d+\.\d+\.\d+)/\d+\b", line)
        if match:
            ip_str = match.group(1)
            try:
                # Validate it's a proper IPv4 address
                ipaddress.IPv4Address(ip_str)
                return ip_str
            except ValueError:
                # Invalid IP, continue searching
                continue

    return None


def get_domain_state(domain_name: str) -> str | None:
    """Get the state of a libvirt domain (running, shut off, etc.).

    Args:
        domain_name: Name of the libvirt domain

    Returns:
        The state as a string (e.g., "running", "shut off"), None if command fails

    Example:
        >>> state = get_domain_state("my-vm-domain")
        >>> if state == "running":
        ...     print("VM is running")
    """
    try:
        output = subprocess.check_output(
            ["virsh", "domstate", domain_name], text=True, stderr=subprocess.DEVNULL
        ).strip()
        return output
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
