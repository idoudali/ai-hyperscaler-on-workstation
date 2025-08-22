"""Network management using libvirt virtual networks for HPC clusters."""

import ipaddress
import logging
import os
from pathlib import Path
from typing import Any

import libvirt
from jinja2 import Environment, FileSystemLoader

from ai_how.utils.logging import (
    log_function_entry,
    log_function_exit,
    log_operation_start,
    log_operation_success,
    run_subprocess_with_logging,
)
from ai_how.vm_management.libvirt_client import LibvirtClient

logger = logging.getLogger(__name__)


class NetworkManagerError(Exception):
    """Raised when network management operations fail."""

    pass


class NetworkManager:
    """Manages libvirt virtual networks for HPC clusters."""

    def __init__(self, libvirt_client: LibvirtClient):
        """Initialize network manager.

        Args:
            libvirt_client: LibvirtClient instance for connections
        """
        log_function_entry(logger, "__init__")

        self.client = libvirt_client
        self.logger = logger

        # Initialize Jinja2 environment for templates
        template_dir = Path(__file__).parent / "templates"
        self.template_env = Environment(
            loader=FileSystemLoader(template_dir), trim_blocks=True, lstrip_blocks=True
        )

        logger.debug("NetworkManager initialized with libvirt client")
        log_function_exit(logger, "__init__")

    def create_cluster_network(self, cluster_name: str, network_config: dict[str, Any]) -> str:
        """Create an isolated virtual network for the cluster.

        Args:
            cluster_name: Name of the cluster
            network_config: Network configuration dictionary

        Returns:
            Network name

        Raises:
            NetworkManagerError: If network creation fails
        """
        log_function_entry(
            logger, "create_cluster_network", cluster_name=cluster_name, config=network_config
        )

        try:
            network_name = f"{cluster_name}-network"

            log_operation_start(logger, "cluster network creation", network_name=network_name)

            # Check if network already exists
            if self._network_exists(network_name):
                logger.debug(f"Virtual network {network_name} already exists")
                log_function_exit(logger, "create_cluster_network", result=network_name)
                return network_name

            # Configure DNS mode and get DNS configuration
            dns_config = self.configure_dns_mode(cluster_name, network_config)

            # Parse and validate network configuration
            # Support both 'subnet' (from template config) and 'network_range' (legacy)
            network_range = network_config.get("subnet") or network_config.get(
                "network_range", "192.168.100.0/24"
            )
            bridge_name = network_config.get("bridge") or network_config.get(
                "bridge_name", f"br-{cluster_name}"
            )

            # Parse network configuration using ipaddress module
            network = ipaddress.IPv4Network(network_range, strict=False)
            gateway_ip = network_config.get("gateway_ip", str(network.network_address + 1))
            netmask = str(network.netmask)

            # Calculate DHCP range
            dhcp_start = network_config.get("dhcp_start", str(network.network_address + 10))
            dhcp_end = network_config.get("dhcp_end", str(network.broadcast_address - 1))

            # Get static leases and MAC addresses
            static_leases = network_config.get("static_leases", {})
            vm_macs = network_config.get("vm_macs", {})

            # Prepare template variables
            template_vars = {
                "cluster_name": cluster_name,
                "bridge_name": bridge_name,
                "gateway_ip": gateway_ip,
                "netmask": netmask,
                "dhcp_start": dhcp_start,
                "dhcp_end": dhcp_end,
                "dns_servers": dns_config["dns_servers"],
                "static_leases": static_leases,
                "vm_macs": vm_macs,
            }

            # Generate network XML
            network_xml = self._render_network_template(template_vars)
            logger.debug(f"Generated XML for network {network_name}")

            # Create network
            try:
                with self.client.get_connection() as conn:
                    logger.debug("Defining virtual network")
                    network_obj = conn.networkDefineXML(network_xml)

                    logger.debug("Starting virtual network")
                    network_obj.create()

                    logger.debug("Setting network to autostart")
                    network_obj.setAutostart(1)

                    network_uuid = network_obj.UUIDString()
                    logger.debug(f"Virtual network created with UUID: {network_uuid}")

            except libvirt.libvirtError as e:
                logger.error(f"Failed to create virtual network {network_name}: {e}")
                raise NetworkManagerError(
                    f"Failed to create virtual network {network_name}: {e}"
                ) from e

            log_operation_success(logger, "cluster network creation", network_name=network_name)

            log_function_exit(logger, "create_cluster_network", result=network_name)
            return network_name

        except Exception as e:
            logger.error(f"Failed to create cluster network for {cluster_name}: {e}")
            if isinstance(e, NetworkManagerError):
                raise
            else:
                raise NetworkManagerError(f"Unexpected error creating cluster network: {e}") from e

    def destroy_cluster_network(self, cluster_name: str, force: bool = False) -> bool:
        """Destroy cluster virtual network.

        Args:
            cluster_name: Name of the cluster
            force: Whether to force destruction

        Returns:
            True if network destroyed successfully

        Raises:
            NetworkManagerError: If network destruction fails
        """
        log_function_entry(
            logger, "destroy_cluster_network", cluster_name=cluster_name, force=force
        )

        try:
            network_name = f"{cluster_name}-network"

            if not self._network_exists(network_name):
                logger.debug(f"Virtual network {network_name} does not exist")
                # Still try to clean up DNS integration if it exists
                self.remove_host_dns_integration(cluster_name)
                log_function_exit(logger, "destroy_cluster_network", result=True)
                return True

            log_operation_start(logger, "cluster network destruction", network_name=network_name)

            with self.client.get_connection() as conn:
                network = conn.networkLookupByName(network_name)

                # Stop network if active
                if network.isActive():
                    logger.debug("Stopping virtual network")
                    network.destroy()

                # Undefine network
                logger.debug("Undefining virtual network")
                network.undefine()

            # Clean up DNS integration (for shared_dns mode)
            logger.debug("Cleaning up DNS integration")
            self.remove_host_dns_integration(cluster_name)

            log_operation_success(logger, "cluster network destruction", network_name=network_name)
            log_function_exit(logger, "destroy_cluster_network", result=True)
            return True

        except libvirt.libvirtError as e:
            logger.error(f"Failed to destroy cluster network {cluster_name}: {e}")
            raise NetworkManagerError(
                f"Failed to destroy cluster network {cluster_name}: {e}"
            ) from e
        except Exception as e:
            logger.error(f"Unexpected error destroying cluster network {cluster_name}: {e}")
            raise NetworkManagerError(
                f"Unexpected error destroying cluster network {cluster_name}: {e}"
            ) from e

    def start_network(self, cluster_name: str) -> bool:
        """Start cluster virtual network.

        Args:
            cluster_name: Name of the cluster

        Returns:
            True if network started successfully

        Raises:
            NetworkManagerError: If network start fails
        """
        log_function_entry(logger, "start_network", cluster_name=cluster_name)

        try:
            network_name = f"{cluster_name}-network"

            if not self._network_exists(network_name):
                raise NetworkManagerError(f"Virtual network {network_name} does not exist")

            with self.client.get_connection() as conn:
                network = conn.networkLookupByName(network_name)

                if network.isActive():
                    logger.debug(f"Virtual network {network_name} is already active")
                    log_function_exit(logger, "start_network", result=True)
                    return True

                network.create()
                logger.info(f"Started virtual network: {network_name}")

            log_function_exit(logger, "start_network", result=True)
            return True

        except libvirt.libvirtError as e:
            logger.error(f"Failed to start network {cluster_name}: {e}")
            raise NetworkManagerError(f"Failed to start network {cluster_name}: {e}") from e

    def stop_network(self, cluster_name: str) -> bool:
        """Stop cluster virtual network.

        Args:
            cluster_name: Name of the cluster

        Returns:
            True if network stopped successfully

        Raises:
            NetworkManagerError: If network stop fails
        """
        log_function_entry(logger, "stop_network", cluster_name=cluster_name)

        try:
            network_name = f"{cluster_name}-network"

            if not self._network_exists(network_name):
                logger.debug(f"Virtual network {network_name} does not exist")
                log_function_exit(logger, "stop_network", result=True)
                return True

            with self.client.get_connection() as conn:
                network = conn.networkLookupByName(network_name)

                if not network.isActive():
                    logger.debug(f"Virtual network {network_name} is already inactive")
                    log_function_exit(logger, "stop_network", result=True)
                    return True

                network.destroy()
                logger.info(f"Stopped virtual network: {network_name}")

            log_function_exit(logger, "stop_network", result=True)
            return True

        except libvirt.libvirtError as e:
            logger.error(f"Failed to stop network {cluster_name}: {e}")
            raise NetworkManagerError(f"Failed to stop network {cluster_name}: {e}") from e

    def get_network_info(self, cluster_name: str) -> dict[str, Any]:
        """Get network information and statistics.

        Args:
            cluster_name: Name of the cluster

        Returns:
            Dictionary with network information

        Raises:
            NetworkManagerError: If operation fails
        """
        log_function_entry(logger, "get_network_info", cluster_name=cluster_name)

        try:
            network_name = f"{cluster_name}-network"

            if not self._network_exists(network_name):
                raise NetworkManagerError(f"Virtual network {network_name} does not exist")

            with self.client.get_connection() as conn:
                network = conn.networkLookupByName(network_name)

                # Get basic network info
                is_active = network.isActive()
                network_xml = network.XMLDesc(0)

                # Parse network XML to extract configuration
                import xml.etree.ElementTree as ET

                root = ET.fromstring(network_xml)

                # Extract network details
                bridge_elem = root.find("bridge")
                bridge_name = bridge_elem.get("name") if bridge_elem is not None else "unknown"

                ip_elem = root.find("ip")
                gateway_ip = ip_elem.get("address") if ip_elem is not None else "unknown"
                netmask = ip_elem.get("netmask") if ip_elem is not None else "unknown"

                # Calculate network range from gateway and netmask
                network_range = "unknown"
                if gateway_ip != "unknown" and netmask != "unknown":
                    try:
                        network_addr = ipaddress.IPv4Interface(f"{gateway_ip}/{netmask}").network
                        network_range = str(network_addr)
                    except Exception as e:
                        logger.warning(f"Could not calculate network range: {e}")

                # Extract DHCP range
                dhcp_elem = ip_elem.find("dhcp/range") if ip_elem is not None else None
                dhcp_start = dhcp_elem.get("start") if dhcp_elem is not None else "unknown"
                dhcp_end = dhcp_elem.get("end") if dhcp_elem is not None else "unknown"

                # Extract DNS servers
                dns_servers = []
                for forwarder in root.findall("dns/forwarder"):
                    addr = forwarder.get("addr")
                    if addr:
                        dns_servers.append(addr)

                # Get DHCP leases for allocated IPs
                allocated_ips = {}
                try:
                    leases = self.get_dhcp_leases(cluster_name)
                    for lease in leases:
                        if "hostname" in lease and "ip" in lease:
                            allocated_ips[lease["hostname"]] = lease["ip"]
                except Exception as e:
                    logger.warning(f"Could not get DHCP leases: {e}")

                info = {
                    "name": network_name,
                    "bridge_name": bridge_name,
                    "network_range": network_range,
                    "gateway_ip": gateway_ip,
                    "dhcp_start": dhcp_start,
                    "dhcp_end": dhcp_end,
                    "dns_servers": dns_servers,
                    "is_active": is_active,
                    "allocated_ips": allocated_ips,
                    "uuid": network.UUIDString(),
                }

                log_function_exit(
                    logger, "get_network_info", result=f"network info with {len(allocated_ips)} IPs"
                )
                return info

        except libvirt.libvirtError as e:
            logger.error(f"Failed to get network info for {cluster_name}: {e}")
            raise NetworkManagerError(f"Failed to get network info for {cluster_name}: {e}") from e
        except Exception as e:
            logger.error(f"Unexpected error getting network info for {cluster_name}: {e}")
            raise NetworkManagerError(f"Unexpected error getting network info: {e}") from e

    def allocate_ip_address(self, cluster_name: str, vm_name: str) -> str:
        """Allocate IP address for VM in cluster network.

        Args:
            cluster_name: Name of the cluster
            vm_name: Name of the VM

        Returns:
            Allocated IP address

        Raises:
            NetworkManagerError: If IP allocation fails
        """
        log_function_entry(
            logger, "allocate_ip_address", cluster_name=cluster_name, vm_name=vm_name
        )

        try:
            # Get network info to find available IP
            network_info = self.get_network_info(cluster_name)
            allocated_ips = set(network_info["allocated_ips"].values())

            # Parse network range
            network_range = network_info["network_range"]
            network = ipaddress.IPv4Network(network_range, strict=False)

            # Find next available IP (skip gateway and broadcast)
            gateway_ip = network_info["gateway_ip"]
            for ip in network.hosts():
                ip_str = str(ip)
                if ip_str not in allocated_ips and ip_str != gateway_ip:
                    logger.info(f"Allocated IP {ip_str} for VM {vm_name}")
                    log_function_exit(logger, "allocate_ip_address", result=ip_str)
                    return ip_str

            raise NetworkManagerError(
                f"No available IP addresses in network {cluster_name}-network"
            )

        except Exception as e:
            logger.error(f"Failed to allocate IP for {vm_name}: {e}")
            if isinstance(e, NetworkManagerError):
                raise
            else:
                raise NetworkManagerError(f"Unexpected error allocating IP: {e}") from e

    def release_ip_address(self, cluster_name: str, vm_name: str) -> bool:
        """Release VM IP address from cluster network.

        Args:
            cluster_name: Name of the cluster
            vm_name: Name of the VM

        Returns:
            True if IP released successfully
        """
        log_function_entry(logger, "release_ip_address", cluster_name=cluster_name, vm_name=vm_name)

        # Note: In libvirt, DHCP leases are automatically managed
        # This method is mainly for state tracking purposes
        logger.info(f"Released IP allocation tracking for VM {vm_name}")
        log_function_exit(logger, "release_ip_address", result=True)
        return True

    def list_cluster_ips(self, cluster_name: str) -> dict[str, str]:
        """List all allocated IPs in cluster network.

        Args:
            cluster_name: Name of the cluster

        Returns:
            Dictionary mapping VM names to IP addresses

        Raises:
            NetworkManagerError: If operation fails
        """
        try:
            network_info = self.get_network_info(cluster_name)
            return network_info["allocated_ips"]
        except Exception as e:
            logger.error(f"Failed to list cluster IPs for {cluster_name}: {e}")
            raise NetworkManagerError(f"Failed to list cluster IPs: {e}") from e

    def validate_network_config(self, network_config: dict[str, Any]) -> bool:
        """Validate network configuration parameters.

        Args:
            network_config: Network configuration dictionary

        Returns:
            True if configuration is valid

        Raises:
            NetworkManagerError: If configuration is invalid
        """
        log_function_entry(logger, "validate_network_config", config=network_config)

        try:
            # Validate network range
            network_range = network_config.get("network_range", "192.168.100.0/24")
            try:
                network = ipaddress.IPv4Network(network_range, strict=False)
                logger.debug(f"Network range validation passed: {network}")
            except ValueError as e:
                raise NetworkManagerError(f"Invalid network range '{network_range}': {e}") from e

            # Validate bridge name using regex for clearer intent
            import re

            bridge_name = network_config.get("bridge_name", "")
            if bridge_name and not re.match(r"^[a-zA-Z0-9._-]+$", bridge_name):
                raise NetworkManagerError(
                    f"Invalid bridge name '{bridge_name}': must be alphanumeric with "
                    "dashes/underscores"
                )

            # Validate IP addresses if provided
            for ip_field in ["gateway_ip", "dhcp_start", "dhcp_end"]:
                ip_value = network_config.get(ip_field)
                if ip_value:
                    try:
                        ipaddress.IPv4Address(ip_value)
                        logger.debug(f"{ip_field} validation passed: {ip_value}")
                    except ValueError as e:
                        raise NetworkManagerError(f"Invalid {ip_field} '{ip_value}': {e}") from e

            logger.debug("Network configuration validation passed")
            log_function_exit(logger, "validate_network_config", result=True)
            return True

        except Exception as e:
            logger.error(f"Network configuration validation failed: {e}")
            if isinstance(e, NetworkManagerError):
                raise
            else:
                raise NetworkManagerError(f"Unexpected error validating network config: {e}") from e

    def get_dhcp_leases(self, cluster_name: str) -> list[dict[str, Any]]:
        """Get DHCP lease information for cluster network.

        Args:
            cluster_name: Name of the cluster

        Returns:
            List of DHCP lease dictionaries

        Raises:
            NetworkManagerError: If operation fails
        """
        log_function_entry(logger, "get_dhcp_leases", cluster_name=cluster_name)

        try:
            network_name = f"{cluster_name}-network"

            if not self._network_exists(network_name):
                raise NetworkManagerError(f"Virtual network {network_name} does not exist")

            with self.client.get_connection() as conn:
                network = conn.networkLookupByName(network_name)

                try:
                    # Get DHCP leases (available in libvirt 1.2.6+)
                    leases = network.DHCPLeases()

                    parsed_leases = []
                    for lease in leases:
                        parsed_leases.append(
                            {
                                "ip": lease.get("ipaddr"),
                                "mac": lease.get("mac"),
                                "hostname": lease.get("hostname"),
                                "client_id": lease.get("clientid"),
                                "expiry_time": lease.get("expirytime"),
                            }
                        )

                    logger.debug(f"Found {len(parsed_leases)} DHCP leases")
                    log_function_exit(
                        logger, "get_dhcp_leases", result=f"{len(parsed_leases)} leases"
                    )
                    return parsed_leases

                except AttributeError:
                    # DHCPLeases method not available in older libvirt versions
                    logger.warning("DHCP lease information not available in this libvirt version")
                    log_function_exit(logger, "get_dhcp_leases", result="empty list")
                    return []

        except libvirt.libvirtError as e:
            logger.error(f"Failed to get DHCP leases for {cluster_name}: {e}")
            raise NetworkManagerError(f"Failed to get DHCP leases: {e}") from e

    def configure_dns_mode(
        self, cluster_name: str, network_config: dict[str, Any]
    ) -> dict[str, Any]:
        """Configure DNS based on the specified mode.

        Args:
            cluster_name: Name of the cluster
            network_config: Network configuration dictionary

        Returns:
            DNS configuration dictionary
        """
        log_function_entry(logger, "configure_dns_mode", cluster_name=cluster_name)

        dns_mode = network_config.get("dns_mode", "isolated")
        dns_config = {"dns_servers": network_config.get("dns_servers", ["8.8.8.8", "1.1.1.1"])}

        logger.debug(f"Configuring DNS mode: {dns_mode}")

        if dns_mode == "isolated":
            # Default isolated mode - no changes needed
            logger.debug("Using isolated DNS mode")

        elif dns_mode == "shared_dns":
            # Use host system DNS for cross-cluster resolution
            dns_config["dns_servers"] = ["192.168.122.1"]  # libvirt default bridge
            self._configure_host_dns_integration(cluster_name, network_config)

        elif dns_mode == "routed":
            # Enable routing between cluster networks
            dns_config["dns_servers"] = ["192.168.122.1"]
            self._enable_cluster_routing(cluster_name, network_config)

        elif dns_mode == "service_discovery":
            # Configure external service discovery
            service_config = network_config.get("service_discovery", {})
            consul_ip = service_config.get("address", "192.168.122.1:8600").split(":")[0]
            dns_config["dns_servers"] = [consul_ip]
            self._configure_service_discovery(cluster_name, service_config)

        logger.debug(f"DNS configuration: {dns_config}")
        log_function_exit(logger, "configure_dns_mode", result=dns_mode)
        return dns_config

    def _network_exists(self, network_name: str) -> bool:
        """Check if virtual network exists.

        Args:
            network_name: Name of the virtual network

        Returns:
            True if network exists, False otherwise
        """
        try:
            with self.client.get_connection() as conn:
                conn.networkLookupByName(network_name)
                return True
        except libvirt.libvirtError:
            return False

    def _render_network_template(self, template_vars: dict[str, Any]) -> str:
        """Render network XML template with variables.

        Args:
            template_vars: Template variables dictionary

        Returns:
            Rendered XML string

        Raises:
            NetworkManagerError: If template rendering fails
        """
        try:
            template = self.template_env.get_template("cluster_network.xml.j2")
            return template.render(**template_vars)
        except Exception as e:
            logger.error(f"Failed to render network template: {e}")
            raise NetworkManagerError(f"Failed to render network template: {e}") from e

    def _configure_host_dns_integration(
        self, cluster_name: str, network_config: dict[str, Any]
    ) -> None:
        """Configure host system to resolve cluster domains.

        Args:
            cluster_name: Name of the cluster
            network_config: Network configuration dictionary

        Raises:
            NetworkManagerError: If DNS integration configuration fails or insufficient privileges
        """
        log_function_entry(logger, "_configure_host_dns_integration", cluster_name=cluster_name)

        # Check for root privileges before attempting system modifications
        if os.geteuid() != 0:
            error_msg = (
                "Root privileges required for host DNS integration. "
                "Please run with sudo or as root user."
            )
            logger.error(error_msg)
            raise NetworkManagerError(error_msg)

        try:
            # Generate cluster domain and network details
            domain = f"{cluster_name}.local"
            gateway_ip = network_config.get("gateway_ip", "192.168.100.1")
            network_range = network_config.get("network_range", "192.168.100.0/24")

            logger.debug(f"Configuring host DNS integration for cluster: {cluster_name}")
            logger.debug(f"Domain: {domain}, Gateway: {gateway_ip}, Network: {network_range}")

            # Generate dnsmasq configuration
            dnsmasq_config = self._generate_dnsmasq_config(cluster_name, domain, gateway_ip)

            # Write configuration file
            config_file = f"/etc/dnsmasq.d/{cluster_name}.conf"
            backup_file = f"{config_file}.backup"

            try:
                # Create backup if file exists
                if Path(config_file).exists():
                    logger.debug(f"Creating backup of existing config: {backup_file}")
                    self._backup_file(config_file, backup_file)

                # Write new configuration
                logger.debug(f"Writing dnsmasq configuration to: {config_file}")
                self._write_dns_config_file(config_file, dnsmasq_config)

                # Restart dnsmasq service to apply changes
                logger.debug("Restarting dnsmasq service")
                self._restart_dnsmasq_service()

                logger.info(
                    f"Successfully configured host DNS integration for cluster {cluster_name}"
                )

            except Exception as e:
                # Rollback on failure
                logger.error(f"DNS configuration failed, attempting rollback: {e}")
                self._rollback_dns_configuration(config_file, backup_file)
                raise NetworkManagerError(f"Failed to configure host DNS integration: {e}") from e

        except Exception as e:
            logger.error(f"Host DNS integration failed for {cluster_name}: {e}")
            if isinstance(e, NetworkManagerError):
                raise
            else:
                raise NetworkManagerError(f"Unexpected error in DNS integration: {e}") from e

        log_function_exit(logger, "_configure_host_dns_integration")

    def _generate_dnsmasq_config(self, cluster_name: str, domain: str, gateway_ip: str) -> str:
        """Generate dnsmasq configuration content for cluster DNS integration.

        Args:
            cluster_name: Name of the cluster
            domain: Cluster domain (e.g., "cluster-1.local")
            gateway_ip: Gateway IP address of the cluster network

        Returns:
            Configuration content as string
        """
        config = f"""# AI-HOW DNS configuration for cluster: {cluster_name}
# Generated automatically - do not edit manually
# Domain: {domain}
# Gateway: {gateway_ip}

# Forward DNS queries for cluster domain to cluster gateway
server=/{domain}/{gateway_ip}

# Add cluster domain to local search domains
domain={domain}

# Cache DNS responses for better performance
cache-size=1000

# Prevent upstream queries for local domains
local=/{domain}/
"""
        return config

    def _write_dns_config_file(self, config_file: str, content: str) -> None:
        """Write DNS configuration file with proper permissions.

        Args:
            config_file: Path to configuration file
            content: Configuration content

        Raises:
            NetworkManagerError: If file writing fails
        """
        try:
            # Ensure directory exists
            config_dir = Path(config_file).parent
            if not config_dir.exists():
                logger.debug(f"Creating configuration directory: {config_dir}")
                config_dir.mkdir(parents=True, exist_ok=True)

            # Write configuration file
            with open(config_file, "w") as f:
                f.write(content)

            # Set proper permissions (readable by all, writable by root)
            import os
            import stat

            os.chmod(config_file, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)

            logger.debug(f"Successfully wrote DNS configuration to {config_file}")

        except PermissionError as e:
            raise NetworkManagerError(
                f"Permission denied writing DNS config to {config_file}. "
                f"This operation requires root privileges: {e}"
            ) from e
        except Exception as e:
            raise NetworkManagerError(f"Failed to write DNS configuration file: {e}") from e

    def _backup_file(self, source_file: str, backup_file: str) -> None:
        """Create backup of existing file.

        Args:
            source_file: Source file path
            backup_file: Backup file path
        """
        try:
            import shutil

            shutil.copy2(source_file, backup_file)
            logger.debug(f"Created backup: {source_file} -> {backup_file}")
        except Exception as e:
            logger.warning(f"Failed to create backup of {source_file}: {e}")

    def _restart_dnsmasq_service(self) -> None:
        """Restart dnsmasq service to apply configuration changes.

        Raises:
            NetworkManagerError: If service restart fails or insufficient privileges
        """
        # Check for root privileges before attempting service restart
        if os.geteuid() != 0:
            error_msg = (
                "Root privileges required to restart dnsmasq service. "
                "Please run with sudo or as root user."
            )
            logger.error(error_msg)
            raise NetworkManagerError(error_msg)

        try:
            # Try systemd first (most common) - no sudo needed when running as root
            restart_commands = [
                ["systemctl", "restart", "dnsmasq"],
                ["service", "dnsmasq", "restart"],
            ]

            success = False
            last_error = None

            for cmd in restart_commands:
                try:
                    logger.debug(f"Attempting to restart dnsmasq with: {' '.join(cmd)}")
                    result = run_subprocess_with_logging(
                        cmd, logger, check=True, operation_description="Restarting dnsmasq service"
                    )

                    if result.success:
                        logger.debug("Successfully restarted dnsmasq service")
                        success = True
                        break

                except Exception as e:
                    last_error = e
                    logger.debug(f"Command failed: {' '.join(cmd)}: {e}")
                    continue

            if not success:
                raise NetworkManagerError(
                    f"Failed to restart dnsmasq service. Last error: {last_error}. "
                    f"Please restart dnsmasq manually or ensure proper privileges."
                )

        except Exception as e:
            if isinstance(e, NetworkManagerError):
                raise
            else:
                raise NetworkManagerError(f"Unexpected error restarting dnsmasq: {e}") from e

    def _rollback_dns_configuration(self, config_file: str, backup_file: str) -> None:
        """Rollback DNS configuration changes.

        Args:
            config_file: Configuration file path
            backup_file: Backup file path
        """
        try:
            if Path(backup_file).exists():
                logger.debug(f"Restoring backup: {backup_file} -> {config_file}")
                import shutil

                shutil.copy2(backup_file, config_file)

                # Remove backup file
                Path(backup_file).unlink()
                logger.debug(f"Removed backup file: {backup_file}")
            else:
                # Remove the new config file if no backup exists
                if Path(config_file).exists():
                    logger.debug(f"Removing failed configuration file: {config_file}")
                    Path(config_file).unlink()

            # Attempt to restart dnsmasq to apply rollback
            try:
                self._restart_dnsmasq_service()
                logger.debug("Successfully restarted dnsmasq after rollback")
            except Exception as e:
                logger.warning(f"Failed to restart dnsmasq after rollback: {e}")

        except Exception as e:
            logger.error(f"DNS configuration rollback failed: {e}")

    def remove_host_dns_integration(self, cluster_name: str) -> bool:
        """Remove host DNS integration for a cluster.

        Args:
            cluster_name: Name of the cluster

        Returns:
            True if removal was successful

        Raises:
            NetworkManagerError: If removal fails or insufficient privileges
        """
        log_function_entry(logger, "remove_host_dns_integration", cluster_name=cluster_name)

        # Check for root privileges before attempting system modifications
        if os.geteuid() != 0:
            error_msg = (
                "Root privileges required to remove host DNS integration. "
                "Please run with sudo or as root user."
            )
            logger.error(error_msg)
            raise NetworkManagerError(error_msg)

        try:
            config_file = f"/etc/dnsmasq.d/{cluster_name}.conf"

            if Path(config_file).exists():
                logger.debug(f"Removing DNS configuration file: {config_file}")
                Path(config_file).unlink()

                # Restart dnsmasq to apply changes
                try:
                    self._restart_dnsmasq_service()
                    logger.debug("Successfully restarted dnsmasq after DNS integration removal")
                except Exception as e:
                    logger.warning(f"Failed to restart dnsmasq after DNS integration removal: {e}")

                logger.info(f"Successfully removed host DNS integration for cluster {cluster_name}")
                log_function_exit(logger, "remove_host_dns_integration", result=True)
                return True
            else:
                logger.debug(f"DNS configuration file not found: {config_file}")
                log_function_exit(logger, "remove_host_dns_integration", result=True)
                return True

        except Exception as e:
            logger.error(f"Failed to remove host DNS integration for {cluster_name}: {e}")
            if isinstance(e, NetworkManagerError):
                raise
            else:
                raise NetworkManagerError(f"Unexpected error removing DNS integration: {e}") from e

    def _enable_cluster_routing(self, cluster_name: str, network_config: dict[str, Any]) -> None:
        """Enable IP forwarding and routing between cluster networks.

        Args:
            cluster_name: Name of the cluster
            network_config: Network configuration dictionary
        """
        logger.debug(f"Configuring cluster routing for {cluster_name}")

        bridge_name = network_config.get("bridge_name", f"br-{cluster_name}")

        # Commands that would be executed with proper privileges
        routing_commands = [
            "sysctl -w net.ipv4.ip_forward=1",
            f"iptables -I FORWARD -i {bridge_name} -j ACCEPT",
            f"iptables -I FORWARD -o {bridge_name} -j ACCEPT",
        ]

        logger.info(f"Cluster routing would execute: {routing_commands}")
        # Note: Actual execution would require root privileges

    def _configure_service_discovery(
        self, cluster_name: str, service_config: dict[str, Any]
    ) -> None:
        """Configure external service discovery integration.

        Args:
            cluster_name: Name of the cluster
            service_config: Service discovery configuration
        """
        logger.debug(f"Configuring service discovery for {cluster_name}")

        service_type = service_config.get("type", "consul")
        service_address = service_config.get("address", "192.168.122.1:8600")

        logger.info(f"Service discovery integration: {service_type} at {service_address}")
        # Note: Actual service discovery integration would be implemented here
