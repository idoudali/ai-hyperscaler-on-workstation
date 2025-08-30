"""PCIe passthrough validation module for AI-HOW.

This module provides comprehensive validation for PCIe passthrough configuration,
ensuring that devices are properly bound to VFIO drivers and not conflicting
with host drivers like NVIDIA.
"""

import contextlib
import platform
import re
from pathlib import Path

from ai_how.utils.logging import get_logger_for_module, run_subprocess_with_logging

logger = get_logger_for_module(__name__)


class PCIePassthroughValidator:
    """Validates PCIe passthrough configuration and system readiness."""

    def __init__(self):
        self.logger = get_logger_for_module(__name__)

    def validate_pcie_passthrough_config(self, config_data: dict) -> bool:
        """Validate PCIe passthrough configuration from cluster config.

        Args:
            config_data: Cluster configuration data

        Returns:
            True if validation passes, False otherwise

        Raises:
            ValueError: If validation fails with specific error details
        """
        self.logger.info("Starting PCIe passthrough validation")

        # Check if any clusters have PCIe passthrough enabled
        clusters = config_data.get("clusters", {})
        pcie_enabled = False

        for cluster_name, cluster_config in clusters.items():
            if self._cluster_has_pcie_passthrough(cluster_config):
                pcie_enabled = True
                self.logger.info(f"PCIe passthrough detected in cluster: {cluster_name}")

                # Validate this cluster's PCIe configuration
                if not self._validate_cluster_pcie_config(cluster_config):
                    raise ValueError(
                        f"PCIe passthrough validation failed for cluster: {cluster_name}"
                    )

        if not pcie_enabled:
            self.logger.info("No PCIe passthrough configured - skipping validation")
            return True

        # System-level validation
        if not self._validate_system_pcie_support():
            raise ValueError("System does not support PCIe passthrough")

        if not self._validate_vfio_modules():
            raise ValueError("VFIO modules are not properly loaded")

        if not self._validate_iommu_configuration():
            raise ValueError("IOMMU is not properly configured")

        self.logger.info("PCIe passthrough validation completed successfully")
        return True

    def _cluster_has_pcie_passthrough(self, cluster_config: dict) -> bool:
        """Check if a cluster has PCIe passthrough enabled."""
        compute_nodes = cluster_config.get("compute_nodes", [])

        for node in compute_nodes:
            pcie_config = node.get("pcie_passthrough", {})
            if pcie_config.get("enabled", False):
                return True

        return False

    def _validate_cluster_pcie_config(self, cluster_config: dict) -> bool:
        """Validate PCIe configuration for a specific cluster."""
        compute_nodes = cluster_config.get("compute_nodes", [])

        for i, node in enumerate(compute_nodes):
            pcie_config = node.get("pcie_passthrough", {})
            if not pcie_config.get("enabled", False):
                continue

            self.logger.info(f"Validating PCIe passthrough for compute node {i + 1}")

            devices = pcie_config.get("devices", [])
            if not devices:
                raise ValueError(
                    f"PCIe passthrough enabled but no devices specified for compute node {i + 1}"
                )

            for device in devices:
                if not self._validate_pcie_device_config(device):
                    raise ValueError(f"Invalid PCIe device configuration: {device}")

                # Check if device exists and is available
                pci_address = device.get("pci_address")
                if not self._validate_pcie_device_availability(pci_address):
                    raise ValueError(f"PCIe device {pci_address} is not available for passthrough")

        return True

    def _validate_pcie_device_config(self, device: dict) -> bool:
        """Validate individual PCIe device configuration."""
        required_fields = ["pci_address", "device_type"]

        for field in required_fields:
            if field not in device:
                self.logger.error(f"Missing required field '{field}' in PCIe device config")
                return False

        # Validate PCI address format (0000:xx:xx.x)
        pci_address = device["pci_address"]
        if not self._is_valid_pci_address(pci_address):
            self.logger.error(f"Invalid PCI address format: {pci_address}")
            return False

        # Validate device type
        device_type = device["device_type"]
        valid_types = ["gpu", "network", "storage", "audio", "other"]
        if device_type not in valid_types:
            self.logger.error(f"Invalid device type '{device_type}'. Must be one of: {valid_types}")
            return False

        return True

    def _is_valid_pci_address(self, pci_address: str) -> bool:
        """Validate PCI address format (dddd:xx:xx.x, where d is a hex digit)."""
        pattern = r"^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]$"
        return bool(re.match(pattern, pci_address))

    def _validate_pcie_device_availability(self, pci_address: str) -> bool:
        """Check if a PCIe device is available for passthrough."""
        self.logger.debug(f"Checking availability of PCIe device: {pci_address}")

        # Check if device exists on the system
        if not self._pci_device_exists(pci_address):
            self.logger.error(f"PCIe device {pci_address} not found on system")
            return False

        # Check if device is bound to VFIO driver
        if not self._is_device_bound_to_vfio(pci_address):
            self.logger.error(f"PCIe device {pci_address} is not bound to VFIO driver")
            return False

        # Check if device is not bound to conflicting drivers (e.g., NVIDIA)
        if self._is_device_bound_to_conflicting_driver(pci_address):
            self.logger.error(f"PCIe device {pci_address} is bound to a conflicting driver")
            return False

        return True

    def _pci_device_exists(self, pci_address: str) -> bool:
        """Check if a PCI device exists on the system."""
        try:
            result = run_subprocess_with_logging(
                ["lspci", "-n", "-s", pci_address],
                self.logger,
                operation_description=f"Checking PCI device existence for {pci_address}",
                check=False,
            )
            command_succeeded = result.success
            device_found = result.stdout.strip() != ""
            return command_succeeded and device_found
        except (FileNotFoundError, OSError):
            self.logger.error("lspci command not found. It is required for PCIe validation.")
            # Fail validation if a required tool is missing.
            return False

    def _is_device_bound_to_vfio(self, pci_address: str) -> bool:
        """Check if a PCI device is bound to the VFIO driver."""
        driver_path = Path(f"/sys/bus/pci/devices/{pci_address}/driver")

        if not driver_path.exists():
            self.logger.warning(f"No driver bound to device {pci_address}")
            return False

        try:
            driver_name = driver_path.resolve().name
            is_vfio = driver_name.startswith("vfio")
            self.logger.debug(
                f"Device {pci_address} bound to driver: {driver_name} (VFIO: {is_vfio})"
            )
            return is_vfio
        except (OSError, RuntimeError) as e:
            self.logger.warning(f"Could not determine driver for device {pci_address}: {e}")
            return False

    def _is_device_bound_to_conflicting_driver(self, pci_address: str) -> bool:
        """Check if a PCI device is bound to a conflicting driver.

        Note: The list of conflicting drivers is hardcoded and may need updates
        as new drivers are introduced. Common conflicting drivers include:
        - nvidia: NVIDIA proprietary driver
        - nouveau: NVIDIA open-source driver
        - radeon: AMD legacy driver
        - amdgpu: AMD modern driver

        Consider making this configurable in future versions.
        """
        driver_path = Path(f"/sys/bus/pci/devices/{pci_address}/driver")

        if not driver_path.exists():
            return False

        try:
            driver_name = driver_path.resolve().name
            conflicting_drivers = ["nvidia", "nouveau", "radeon", "amdgpu"]

            for conflicting in conflicting_drivers:
                if conflicting in driver_name:
                    self.logger.error(
                        f"Device {pci_address} is bound to conflicting driver: {driver_name}"
                    )
                    return True

            return False
        except (OSError, RuntimeError) as e:
            self.logger.warning(f"Could not determine driver for device {pci_address}: {e}")
            return False

    def _validate_system_pcie_support(self) -> bool:
        """Validate that the system supports PCIe passthrough."""
        self.logger.info("Validating system PCIe passthrough support")

        # Check if running on x86_64 architecture
        if not self._is_x86_64_architecture():
            self.logger.error("PCIe passthrough is only supported on x86_64 architecture")
            return False

        # Check if KVM is available
        if not self._is_kvm_available():
            self.logger.error("KVM is not available - required for PCIe passthrough")
            return False

        return True

    def _is_x86_64_architecture(self) -> bool:
        """Check if running on x86_64 architecture."""
        return platform.machine() == "x86_64"

    def _is_kvm_available(self) -> bool:
        """Check if KVM is available on the system."""
        kvm_path = Path("/dev/kvm")
        if not kvm_path.exists():
            return False

        # Check if KVM modules are loaded
        try:
            with open("/proc/modules") as f:
                modules = f.read()
                return "kvm" in modules
        except (FileNotFoundError, PermissionError):
            self.logger.error("Could not read /proc/modules to verify KVM status.")
            # Fail validation if checks cannot be performed.
            return False

    def _validate_vfio_modules(self) -> bool:
        """Validate that VFIO modules are properly loaded."""
        self.logger.info("Validating VFIO modules")

        required_modules = ["vfio", "vfio_iommu_type1", "vfio_pci"]

        try:
            with open("/proc/modules") as f:
                loaded_modules = f.read()

            missing_modules = []
            for module in required_modules:
                if module not in loaded_modules:
                    missing_modules.append(module)

            if missing_modules:
                self.logger.error(f"Missing required VFIO modules: {missing_modules}")
                return False

            self.logger.info("All required VFIO modules are loaded")
            return True

        except (FileNotFoundError, PermissionError) as e:
            self.logger.error(f"Could not check loaded modules: {e}")
            return False

    def _validate_iommu_configuration(self) -> bool:
        """Validate IOMMU configuration."""
        self.logger.info("Validating IOMMU configuration")

        # Check kernel command line for IOMMU parameters
        try:
            with open("/proc/cmdline") as f:
                cmdline = f.read()

            # Check for Intel VT-d or AMD IOMMU
            iommu_enabled = any(
                param in cmdline
                for param in ["intel_iommu=on", "amd_iommu=on", "iommu=pt", "iommu=on"]
            )

            if not iommu_enabled:
                self.logger.error(
                    "IOMMU is not enabled. Required kernel parameters: "
                    "intel_iommu=on or amd_iommu=on"
                )
                return False

            self.logger.info("IOMMU is properly configured")
            return True

        except (FileNotFoundError, PermissionError) as e:
            self.logger.error(f"Could not check kernel command line: {e}")
            return False

    def get_pcie_device_status(self, pci_address: str) -> dict[str, str | bool]:
        """Get detailed status of a PCIe device.

        Args:
            pci_address: PCI address of the device

        Returns:
            Dictionary with device status information
        """
        status: dict[str, str | bool] = {
            "pci_address": pci_address,
            "exists": False,
            "driver": "unknown",
            "is_vfio": False,
            "is_conflicting": False,
            "iommu_group": "unknown",
        }

        # Check if device exists
        status["exists"] = self._pci_device_exists(pci_address)
        if not status["exists"]:
            return status

        # Get driver information
        driver_path = Path(f"/sys/bus/pci/devices/{pci_address}/driver")
        if driver_path.exists():
            with contextlib.suppress(OSError, RuntimeError):
                driver_name = driver_path.resolve().name
                status["driver"] = driver_name
                status["is_vfio"] = driver_name.startswith("vfio")
                status["is_conflicting"] = self._is_device_bound_to_conflicting_driver(pci_address)

        # Get IOMMU group
        iommu_group_path = Path(f"/sys/bus/pci/devices/{pci_address}/iommu_group")
        if iommu_group_path.exists():
            with contextlib.suppress(OSError, RuntimeError):
                status["iommu_group"] = iommu_group_path.resolve().name

        return status

    def list_pcie_devices(self) -> list[dict[str, str | bool]]:
        """List all PCIe devices with their current driver binding status.

        Returns:
            List of dictionaries with device information
        """
        devices: list[dict[str, str | bool]] = []

        try:
            # Iterate through /sys/bus/pci/devices/ to get all PCI devices
            pci_devices_path = Path("/sys/bus/pci/devices")
            if not pci_devices_path.exists():
                self.logger.error("PCI devices directory does not exist")
                return devices

            for device_path in pci_devices_path.iterdir():
                if not device_path.is_dir():
                    continue

                pci_address = device_path.name
                if not self._is_valid_pci_address(pci_address):
                    continue

                # Get device class from class file
                device_class = "unknown"
                class_path = device_path / "class"
                if class_path.exists():
                    try:
                        with open(class_path) as f:
                            class_content = f.read().strip()
                            # Class format: 0x030000 (display controller)
                            if class_content.startswith("0x"):
                                device_class = class_content[2:6]  # Extract first 4 hex digits
                    except (OSError, ValueError):
                        pass

                # Get detailed status
                status = self.get_pcie_device_status(pci_address)
                status["device_class"] = device_class

                devices.append(status)

        except (FileNotFoundError, OSError) as e:
            self.logger.error(f"Could not list PCIe devices: {e}")

        return devices
