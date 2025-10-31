"""libvirt client wrapper with error handling and connection management."""

import logging
import os
import threading
import time
from collections.abc import Generator
from contextlib import contextmanager
from typing import Any

import libvirt

from ai_how.utils.logging import (
    log_function_entry,
    log_function_exit,
    log_operation_start,
    log_operation_success,
)
from ai_how.vm_management.xml_tracer import XMLTracer

# Type aliases for libvirt objects (since libvirt-python doesn't provide proper typing)
LibvirtDomain = Any  # libvirt.virDomain
LibvirtNetwork = Any  # libvirt.virNetwork

logger = logging.getLogger(__name__)


class LibvirtConnectionError(Exception):
    """Raised when libvirt connection operations fail."""

    pass


class LibvirtClient:
    """Thread-safe libvirt connection wrapper with error handling and XML tracing."""

    def __init__(self, uri: str | None = None, xml_tracer: XMLTracer | None = None):
        """Initialize libvirt client.

        Args:
            uri: libvirt connection URI (optional). If not provided, it will be
                 read from the LIBVIRT_DEFAULT_URI environment variable,
                 defaulting to "qemu:///system".
            xml_tracer: Optional XML tracer for logging libvirt operations

        Raises:
            LibvirtConnectionError: If libvirt-python is not available
        """
        log_function_entry(logger, "__init__", uri=uri, tracer=xml_tracer is not None)

        # Determine URI from argument, environment variable, or default
        if uri:
            self.uri = uri
        else:
            self.uri = os.environ.get("LIBVIRT_DEFAULT_URI", "qemu:///system")

        self._connection: libvirt.virConnect | None = None
        self._lock = threading.Lock()
        self.xml_tracer = xml_tracer

        logger.debug(f"LibvirtClient initialized with URI: {self.uri}")

        # Log libvirt version info if available
        try:
            version = libvirt.getVersion()
            logger.debug(f"libvirt library version: {version}")
        except Exception as e:
            logger.debug(f"Could not get libvirt version: {e}")

        log_function_exit(logger, "__init__")

    def connect(self) -> Any:
        """Get or create a libvirt connection with retry logic.

        Returns:
            libvirt connection object

        Raises:
            LibvirtConnectionError: If connection fails after retries
        """
        log_function_entry(logger, "connect")

        with self._lock:
            logger.debug("Acquired connection lock")

            if self._connection is None:
                logger.debug("No existing connection, creating new one")
                log_operation_start(logger, "libvirt connection", uri=self.uri)
            elif not self._is_connection_alive():
                logger.debug("Existing connection is dead, reconnecting")
                log_operation_start(logger, "libvirt reconnection", uri=self.uri)
            else:
                logger.debug("Reusing existing alive connection")
                log_function_exit(logger, "connect", result="reused_connection")
                return self._connection

            # Retry connection with exponential backoff
            max_retries = 3
            base_delay = 1.0

            for attempt in range(max_retries):
                try:
                    logger.debug(f"Connection attempt {attempt + 1}/{max_retries}")
                    logger.debug(f"Opening libvirt connection to: {self.uri}")
                    self._connection = libvirt.open(self.uri)

                    if self._connection is None:
                        logger.error(f"libvirt.open() returned None for URI: {self.uri}")
                        raise LibvirtConnectionError(f"Failed to connect to libvirt at {self.uri}")

                    # Test the connection by getting version
                    try:
                        hypervisor_version = self._connection.getVersion()
                        logger.debug(f"Connected to hypervisor version: {hypervisor_version}")
                    except Exception as e:
                        logger.warning(f"Could not get hypervisor version: {e}")

                    # Get hypervisor type
                    try:
                        hypervisor_type = self._connection.getType()
                        logger.debug(f"Hypervisor type: {hypervisor_type}")
                    except Exception as e:
                        logger.warning(f"Could not get hypervisor type: {e}")

                    log_operation_success(logger, "libvirt connection", uri=self.uri)
                    logger.info(f"Successfully connected to libvirt at {self.uri}")
                    break

                except libvirt.libvirtError as e:
                    logger.warning(f"Connection attempt {attempt + 1} failed: {e}")
                    self._connection = None

                    if attempt < max_retries - 1:
                        delay = base_delay * (2**attempt)
                        logger.info(f"Retrying in {delay:.1f} seconds...")
                        time.sleep(delay)
                    else:
                        logger.error(f"All connection attempts failed after {max_retries} retries")
                        raise LibvirtConnectionError(
                            f"libvirt connection failed after {max_retries} attempts: {e}"
                        ) from e

                except Exception as e:
                    logger.error(f"Unexpected error during libvirt connection: {e}")
                    self._connection = None
                    raise LibvirtConnectionError(f"Unexpected connection error: {e}") from e

        log_function_exit(logger, "connect", result="new_connection")
        return self._connection

    def _is_connection_alive(self) -> bool:
        """Check if the current connection is still alive."""
        if self._connection is None:
            logger.debug("Connection is None, not alive")
            return False

        try:
            # Try a simple operation to test connection
            version = self._connection.getVersion()
            logger.debug(f"Connection alive check successful, version: {version}")
            return True
        except libvirt.libvirtError as e:
            logger.debug(f"Connection alive check failed: {e}")
            return False
        except Exception as e:
            logger.debug(f"Unexpected error in connection alive check: {e}")
            return False

    def _is_libvirt_not_found_error(
        self, error: libvirt.libvirtError, expected_error_code: int, fallback_patterns: list[str]
    ) -> bool:
        """Check if a libvirt error represents a "not found" condition.

        Args:
            error: The libvirt error to check
            expected_error_code: The expected libvirt error code for "not found"
            fallback_patterns: List of string patterns to check if error code doesn't match

        Returns:
            True if the error represents a "not found" condition, False otherwise
        """
        try:
            # First try to check the error code
            if hasattr(error, "get_error_code"):
                error_code = error.get_error_code()
                if error_code == expected_error_code:
                    return True
        except (AttributeError, TypeError):
            pass

        # Fallback to string checking for backward compatibility
        error_str = str(error).lower()
        return any(pattern.lower() in error_str for pattern in fallback_patterns)

    @contextmanager
    def get_connection(self) -> Generator[Any, None, None]:
        """Context manager for getting libvirt connection.

        Yields:
            libvirt connection object

        Raises:
            LibvirtConnectionError: If connection fails
        """
        conn = self.connect()
        try:
            yield conn
        finally:
            # Connection is kept alive for reuse
            pass

    def list_domains(self) -> list[str]:
        """List all domains with error handling.

        Returns:
            List of domain names

        Raises:
            LibvirtConnectionError: If operation fails
        """
        log_function_entry(logger, "list_domains")

        try:
            with self.get_connection() as conn:
                log_operation_start(logger, "domain listing")

                # Get all domains (active and inactive)
                logger.debug("Getting list of active domain IDs")
                domain_ids = conn.listDomainsID()
                logger.debug(f"Found {len(domain_ids)} active domains")

                domain_names = []

                # Get active domain names
                for domain_id in domain_ids:
                    try:
                        domain = conn.lookupByID(domain_id)
                        domain_name = domain.name()
                        domain_names.append(domain_name)
                        logger.debug(f"Active domain: {domain_name} (ID: {domain_id})")
                    except libvirt.libvirtError as e:
                        logger.warning(f"Failed to get domain name for ID {domain_id}: {e}")

                # Get inactive domain names
                try:
                    logger.debug("Getting list of inactive domains")
                    inactive_domains = conn.listDefinedDomains()
                    logger.debug(f"Found {len(inactive_domains)} inactive domains")

                    for domain_name in inactive_domains:
                        logger.debug(f"Inactive domain: {domain_name}")

                    domain_names.extend(inactive_domains)
                except libvirt.libvirtError as e:
                    logger.warning(f"Failed to list inactive domains: {e}")

                # Remove duplicates and sort
                unique_domains = sorted(set(domain_names))
                logger.debug(f"Total unique domains found: {len(unique_domains)}")

                log_operation_success(logger, "domain listing", count=len(unique_domains))
                log_function_exit(logger, "list_domains", result=f"{len(unique_domains)} domains")
                return unique_domains

        except libvirt.libvirtError as e:
            logger.error(f"Failed to list domains: {e}")
            raise LibvirtConnectionError(f"Failed to list domains: {e}") from e

    def domain_exists(self, name: str) -> bool:
        """Check if domain exists.

        Args:
            name: Domain name

        Returns:
            True if domain exists, False otherwise
        """
        log_function_entry(logger, "domain_exists", name=name)

        try:
            with self.get_connection() as conn:
                logger.debug(f"Checking if domain exists: {name}")
                conn.lookupByName(name)
                logger.debug(f"Domain exists: {name}")
                log_function_exit(logger, "domain_exists", result=True)
                return True
        except libvirt.libvirtError as e:
            logger.debug(f"Domain does not exist: {name} (error: {e})")
            log_function_exit(logger, "domain_exists", result=False)
            return False

    def get_domain(self, name: str) -> LibvirtDomain:
        """Get domain by name with error handling.

        Args:
            name: Domain name

        Returns:
            libvirt domain object

        Raises:
            LibvirtConnectionError: If domain not found or operation fails
        """
        try:
            with self.get_connection() as conn:
                return conn.lookupByName(name)
        except libvirt.libvirtError as e:
            raise LibvirtConnectionError(f"Failed to get domain '{name}': {e}") from e

    def define_domain(self, xml_config: str) -> LibvirtDomain:
        """Define a new domain from XML configuration.

        Args:
            xml_config: libvirt XML domain configuration

        Returns:
            libvirt domain object

        Raises:
            LibvirtConnectionError: If domain definition fails
        """
        log_function_entry(logger, "define_domain")

        try:
            with self.get_connection() as conn:
                log_operation_start(logger, "domain definition")

                # Log XML config length for debugging (but not full content for security)
                logger.debug(f"Defining domain from XML config ({len(xml_config)} characters)")

                # Extract domain name from XML for logging with robust error handling
                domain_name = "unknown"
                try:
                    import xml.etree.ElementTree as ET
                    from xml.etree.ElementTree import ParseError

                    # Parse XML with better error handling
                    try:
                        root = ET.fromstring(xml_config)
                    except ParseError as parse_error:
                        logger.warning(f"XML parsing failed: {parse_error}")
                        raise LibvirtConnectionError(
                            f"Invalid XML configuration: {parse_error}"
                        ) from parse_error

                    name_elem = root.find("name")
                    if name_elem is not None and name_elem.text:
                        domain_name = name_elem.text.strip()
                        # Validate domain name contains only valid characters using regex
                        import re

                        if not domain_name or not re.match(r"^[a-zA-Z0-9._-]+$", domain_name):
                            logger.warning(
                                f"Domain name contains invalid characters: {domain_name}"
                            )
                            domain_name = "invalid_name"
                        else:
                            logger.debug(f"Domain name from XML: {domain_name}")
                    else:
                        logger.warning("No valid domain name found in XML configuration")

                except ImportError as e:
                    logger.warning(f"XML parsing library not available: {e}")
                except Exception as e:
                    logger.warning(f"Unexpected error extracting domain name from XML: {e}")

                logger.debug("Calling libvirt defineXML")

                try:
                    domain = conn.defineXML(xml_config)

                    if domain is None:
                        logger.error("libvirt defineXML returned None")
                        if self.xml_tracer:
                            self.xml_tracer.log_xml(
                                "domain",
                                xml_config,
                                "define",
                                domain_name,
                                False,
                                "defineXML returned None",
                            )
                        raise LibvirtConnectionError("Failed to define domain from XML")

                    actual_domain_name = domain.name()
                    domain_uuid = domain.UUIDString()

                    # Log successful XML operation
                    if self.xml_tracer:
                        self.xml_tracer.log_xml(
                            "domain", xml_config, "define", actual_domain_name, True
                        )

                    logger.debug(
                        f"Domain defined successfully: name={actual_domain_name},"
                        f" uuid={domain_uuid}"
                    )

                    log_operation_success(
                        logger, "domain definition", name=actual_domain_name, uuid=domain_uuid
                    )
                    logger.info(f"Defined domain: {actual_domain_name}")

                    log_function_exit(logger, "define_domain", result=actual_domain_name)
                    return domain

                except libvirt.libvirtError as e:
                    # Log failed XML operation
                    if self.xml_tracer:
                        self.xml_tracer.log_xml(
                            "domain", xml_config, "define", domain_name, False, str(e)
                        )
                    raise

        except libvirt.libvirtError as e:
            logger.error(f"Failed to define domain: {e}")
            raise LibvirtConnectionError(f"Failed to define domain: {e}") from e

    def get_domain_state(self, name: str) -> tuple[int, int]:
        """Get domain state.

        Args:
            name: Domain name

        Returns:
            Tuple of (state, reason) as defined by libvirt

        Raises:
            LibvirtConnectionError: If operation fails
        """
        try:
            domain = self.get_domain(name)
            state, reason = domain.state()
            return state, reason
        except libvirt.libvirtError as e:
            raise LibvirtConnectionError(f"Failed to get domain state for '{name}': {e}") from e

    def list_networks(self) -> list[str]:
        """List all virtual networks with error handling.

        Returns:
            List of network names

        Raises:
            LibvirtConnectionError: If operation fails
        """
        log_function_entry(logger, "list_networks")

        try:
            with self.get_connection() as conn:
                log_operation_start(logger, "network listing")

                network_names = []

                # Get active networks
                logger.debug("Getting list of active networks")
                try:
                    active_networks = conn.listNetworks()
                    logger.debug(f"Found {len(active_networks)} active networks")
                    network_names.extend(active_networks)

                    for network_name in active_networks:
                        logger.debug(f"Active network: {network_name}")
                except libvirt.libvirtError as e:
                    logger.warning(f"Failed to list active networks: {e}")

                # Get inactive networks
                logger.debug("Getting list of inactive networks")
                try:
                    inactive_networks = conn.listDefinedNetworks()
                    logger.debug(f"Found {len(inactive_networks)} inactive networks")
                    network_names.extend(inactive_networks)

                    for network_name in inactive_networks:
                        logger.debug(f"Inactive network: {network_name}")
                except libvirt.libvirtError as e:
                    logger.warning(f"Failed to list inactive networks: {e}")

                # Remove duplicates and sort
                unique_networks = sorted(set(network_names))
                logger.debug(f"Total unique networks found: {len(unique_networks)}")

                log_operation_success(logger, "network listing", count=len(unique_networks))
                log_function_exit(
                    logger, "list_networks", result=f"{len(unique_networks)} networks"
                )
                return unique_networks

        except libvirt.libvirtError as e:
            logger.error(f"Failed to list networks: {e}")
            raise LibvirtConnectionError(f"Failed to list networks: {e}") from e

    def network_exists(self, name: str) -> bool:
        """Check if virtual network exists.

        Args:
            name: Network name

        Returns:
            True if network exists, False otherwise
        """
        log_function_entry(logger, "network_exists", name=name)

        try:
            with self.get_connection() as conn:
                logger.debug(f"Checking if network exists: {name}")
                conn.networkLookupByName(name)
                logger.debug(f"Network exists: {name}")
                log_function_exit(logger, "network_exists", result=True)
                return True
        except libvirt.libvirtError as e:
            logger.debug(f"Network does not exist: {name} (error: {e})")
            log_function_exit(logger, "network_exists", result=False)
            return False

    def get_network(self, name: str) -> LibvirtNetwork:
        """Get virtual network by name with error handling.

        Args:
            name: Network name

        Returns:
            libvirt network object

        Raises:
            LibvirtConnectionError: If network not found or operation fails
        """
        try:
            with self.get_connection() as conn:
                return conn.networkLookupByName(name)
        except libvirt.libvirtError as e:
            raise LibvirtConnectionError(f"Failed to get network '{name}': {e}") from e

    def create_network(self, xml: str) -> LibvirtNetwork:
        """Create virtual network from XML definition.

        Args:
            xml: libvirt XML network configuration

        Returns:
            libvirt network object

        Raises:
            LibvirtConnectionError: If network creation fails
        """
        log_function_entry(logger, "create_network")

        try:
            with self.get_connection() as conn:
                log_operation_start(logger, "network creation")

                # Log XML config length for debugging
                logger.debug(f"Creating network from XML config ({len(xml)} characters)")

                # Extract network name from XML for logging
                network_name = "unknown"
                try:
                    import xml.etree.ElementTree as ET
                    from xml.etree.ElementTree import ParseError

                    try:
                        root = ET.fromstring(xml)
                    except ParseError as parse_error:
                        logger.warning(f"XML parsing failed: {parse_error}")
                        raise LibvirtConnectionError(
                            f"Invalid XML configuration: {parse_error}"
                        ) from parse_error

                    name_elem = root.find("name")
                    if name_elem is not None and name_elem.text:
                        network_name = name_elem.text.strip()
                        logger.debug(f"Network name from XML: {network_name}")
                    else:
                        logger.warning("No valid network name found in XML configuration")

                except Exception as e:
                    logger.warning(f"Error extracting network name from XML: {e}")

                logger.debug("Calling libvirt networkDefineXML")

                try:
                    network = conn.networkDefineXML(xml)

                    if network is None:
                        logger.error("libvirt networkDefineXML returned None")
                        if self.xml_tracer:
                            self.xml_tracer.log_xml(
                                "network",
                                xml,
                                "define",
                                network_name,
                                False,
                                "networkDefineXML returned None",
                            )
                        raise LibvirtConnectionError("Failed to create network from XML")

                    actual_network_name = network.name()
                    network_uuid = network.UUIDString()

                    # Log successful XML operation
                    if self.xml_tracer:
                        self.xml_tracer.log_xml("network", xml, "define", actual_network_name, True)

                    logger.debug(
                        f"Network created successfully: name={actual_network_name},"
                        f" uuid={network_uuid}"
                    )

                    log_operation_success(
                        logger, "network creation", name=actual_network_name, uuid=network_uuid
                    )
                    logger.info(f"Created network: {actual_network_name}")

                    log_function_exit(logger, "create_network", result=actual_network_name)
                    return network

                except libvirt.libvirtError as e:
                    # Log failed XML operation
                    if self.xml_tracer:
                        self.xml_tracer.log_xml(
                            "network", xml, "define", network_name, False, str(e)
                        )
                    raise

        except libvirt.libvirtError as e:
            logger.error(f"Failed to create network: {e}")
            raise LibvirtConnectionError(f"Failed to create network: {e}") from e

    def destroy_network(self, name: str) -> bool:
        """Destroy virtual network and clean up.

        Args:
            name: Network name

        Returns:
            True if network destroyed successfully

        Raises:
            LibvirtConnectionError: If network destruction fails
        """
        log_function_entry(logger, "destroy_network", name=name)

        try:
            with self.get_connection() as conn:
                log_operation_start(logger, "network destruction", name=name)

                try:
                    network = conn.networkLookupByName(name)

                    # Stop network if active
                    if network.isActive():
                        logger.debug(f"Stopping active network: {name}")
                        network.destroy()

                    # Undefine network
                    logger.debug(f"Undefining network: {name}")
                    network.undefine()

                    log_operation_success(logger, "network destruction", name=name)
                    logger.info(f"Destroyed network: {name}")

                except libvirt.libvirtError as e:
                    # Use helper to check for 'not found' error
                    if self._is_libvirt_not_found_error(
                        e,
                        libvirt.VIR_ERR_NO_NETWORK,  # type: ignore[attr-defined]
                        ["not found"],
                    ):
                        logger.debug(f"Network {name} does not exist")
                        log_function_exit(logger, "destroy_network", result=True)
                        return True
                    else:
                        raise

                log_function_exit(logger, "destroy_network", result=True)
                return True

        except libvirt.libvirtError as e:
            logger.error(f"Failed to destroy network '{name}': {e}")
            raise LibvirtConnectionError(f"Failed to destroy network '{name}': {e}") from e

    def define_storage_pool(self, xml: str, pool_name: str = "") -> Any:
        """Define storage pool from XML definition with tracing.

        Args:
            xml: libvirt XML storage pool configuration
            pool_name: Pool name for tracing (optional)

        Returns:
            libvirt storage pool object

        Raises:
            LibvirtConnectionError: If pool definition fails
        """
        log_function_entry(logger, "define_storage_pool")

        try:
            with self.get_connection() as conn:
                log_operation_start(logger, "storage pool definition")

                # Extract pool name from XML if not provided
                if not pool_name:
                    try:
                        import xml.etree.ElementTree as ET

                        root = ET.fromstring(xml)
                        name_elem = root.find("name")
                        if name_elem is not None and name_elem.text:
                            pool_name = name_elem.text.strip()
                    except Exception as e:
                        logger.warning(f"Could not extract pool name from XML: {e}")
                        pool_name = "unknown"

                try:
                    pool = conn.storagePoolDefineXML(xml, 0)

                    if pool is None:
                        logger.error("libvirt storagePoolDefineXML returned None")
                        if self.xml_tracer:
                            self.xml_tracer.log_xml(
                                "pool",
                                xml,
                                "define",
                                pool_name,
                                False,
                                "storagePoolDefineXML returned None",
                            )
                        raise LibvirtConnectionError("Failed to define storage pool from XML")

                    actual_pool_name = pool.name()
                    pool_uuid = pool.UUIDString()

                    # Log successful XML operation
                    if self.xml_tracer:
                        self.xml_tracer.log_xml("pool", xml, "define", actual_pool_name, True)

                    log_operation_success(
                        logger, "storage pool definition", name=actual_pool_name, uuid=pool_uuid
                    )
                    logger.info(f"Defined storage pool: {actual_pool_name}")

                    log_function_exit(logger, "define_storage_pool", result=actual_pool_name)
                    return pool

                except libvirt.libvirtError as e:
                    # Log failed XML operation
                    if self.xml_tracer:
                        self.xml_tracer.log_xml("pool", xml, "define", pool_name, False, str(e))
                    raise

        except libvirt.libvirtError as e:
            logger.error(f"Failed to define storage pool: {e}")
            raise LibvirtConnectionError(f"Failed to define storage pool: {e}") from e

    def create_volume(self, pool: Any, xml: str, volume_name: str = "") -> Any:
        """Create volume from XML definition with tracing.

        Args:
            pool: libvirt storage pool object
            xml: libvirt XML volume configuration
            volume_name: Volume name for tracing (optional)

        Returns:
            libvirt storage volume object

        Raises:
            LibvirtConnectionError: If volume creation fails
        """
        log_function_entry(logger, "create_volume")

        # Extract volume name from XML if not provided
        if not volume_name:
            try:
                import xml.etree.ElementTree as ET

                root = ET.fromstring(xml)
                name_elem = root.find("name")
                if name_elem is not None and name_elem.text:
                    volume_name = name_elem.text.strip()
            except Exception as e:
                logger.warning(f"Could not extract volume name from XML: {e}")
                volume_name = "unknown"

        try:
            log_operation_start(logger, "volume creation")

            try:
                volume = pool.createXML(xml, 0)

                if volume is None:
                    logger.error("libvirt pool.createXML returned None")
                    if self.xml_tracer:
                        self.xml_tracer.log_xml(
                            "volume",
                            xml,
                            "create",
                            volume_name,
                            False,
                            "pool.createXML returned None",
                        )
                    raise LibvirtConnectionError("Failed to create volume from XML")

                actual_volume_name = volume.name()

                # Log successful XML operation
                if self.xml_tracer:
                    self.xml_tracer.log_xml("volume", xml, "create", actual_volume_name, True)

                log_operation_success(logger, "volume creation", name=actual_volume_name)
                logger.info(f"Created volume: {actual_volume_name}")

                log_function_exit(logger, "create_volume", result=actual_volume_name)
                return volume

            except libvirt.libvirtError as e:
                # Log failed XML operation
                if self.xml_tracer:
                    self.xml_tracer.log_xml("volume", xml, "create", volume_name, False, str(e))
                raise

        except libvirt.libvirtError as e:
            logger.error(f"Failed to create volume: {e}")
            raise LibvirtConnectionError(f"Failed to create volume: {e}") from e

    def close(self) -> None:
        """Close libvirt connection."""
        with self._lock:
            if self._connection is not None:
                try:
                    self._connection.close()
                    logger.info("Closed libvirt connection")
                except libvirt.libvirtError as e:
                    logger.warning(f"Error closing libvirt connection: {e}")
                finally:
                    self._connection = None
