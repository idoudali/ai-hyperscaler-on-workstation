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

        # Step 1: Check if GPU and audio devices are bound to any drivers
        if not self._check_device_driver_binding(pci_address):
            self.logger.error(f"Failed to check driver binding for device {pci_address}")
            return False

        # Step 2: Check if device is in an IOMMU group and get group info
        iommu_group_info = self._get_iommu_group_info(pci_address)
        if not iommu_group_info:
            self.logger.error(f"Could not determine IOMMU group for device {pci_address}")
            return False

        # Step 3: Check if all devices in the same IOMMU group need to be unbound
        if not self._validate_iommu_group_devices(pci_address, iommu_group_info):
            self.logger.error(f"IOMMU group validation failed for device {pci_address}")
            return False

        # Step 4: Check if device is bound to VFIO driver
        if not self._is_device_bound_to_vfio(pci_address):
            self.logger.error(f"PCIe device {pci_address} is not bound to VFIO driver")
            # Use the comprehensive VFIO binding instruction method
            self.bind_device_to_vfio_manual_steps(pci_address)
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

    def _check_device_driver_binding(self, pci_address: str) -> bool:
        """Check if GPU and audio devices are bound to any drivers.

        Args:
            pci_address: PCI address of the device

        Returns:
            True if check completed successfully, False otherwise
        """
        self.logger.info(f"Checking driver binding for device: {pci_address}")

        # Get device class to identify if it's a GPU or audio device
        device_class = self._get_device_class(pci_address)

        if device_class in ["0300", "0400"]:  # Display controller or multimedia controller
            self.logger.info(f"Device {pci_address} is a GPU/audio device (class: {device_class})")

            # Check current driver binding
            driver_path = Path(f"/sys/bus/pci/devices/{pci_address}/driver")
            if driver_path.exists():
                try:
                    driver_name = driver_path.resolve().name
                    self.logger.info(f"Device {pci_address} is bound to driver: {driver_name}")

                    # Check if it's a conflicting driver
                    if self._is_conflicting_driver(driver_name):
                        self.logger.warning(
                            f"Device {pci_address} is bound to conflicting driver: {driver_name}"
                        )
                        self.logger.info("This device will need to be unbound before VFIO binding")
                    else:
                        self.logger.info(
                            f"Device {pci_address} is bound to non-conflicting driver: "
                            f"{driver_name}"
                        )

                except (OSError, RuntimeError) as e:
                    self.logger.error(f"Could not determine driver for device {pci_address}: {e}")
                    return False
            else:
                self.logger.info(f"Device {pci_address} is not bound to any driver")

        return True

    def _get_device_class(self, pci_address: str) -> str:
        """Get the device class for a PCIe device.

        Args:
            pci_address: PCI address of the device

        Returns:
            Device class string (e.g., "0300" for display controller)
        """
        class_path = Path(f"/sys/bus/pci/devices/{pci_address}/class")
        if class_path.exists():
            try:
                with open(class_path) as f:
                    class_content = f.read().strip()
                    # Class format: 0x030000 (display controller)
                    if class_content.startswith("0x"):
                        return class_content[2:6]  # Extract first 4 hex digits
            except OSError:
                pass
        return "unknown"

    def _is_conflicting_driver(self, driver_name: str) -> bool:
        """Check if a driver is conflicting for VFIO binding.

        Args:
            driver_name: Name of the driver

        Returns:
            True if driver is conflicting, False otherwise
        """
        conflicting_drivers = [
            "nvidia",
            "nouveau",
            "radeon",
            "amdgpu",
            "snd_hda_intel",
            "snd_hda_codec",
        ]

        return any(conflicting in driver_name for conflicting in conflicting_drivers)

    def _get_iommu_group_info(self, pci_address: str) -> dict:
        """Get IOMMU group information for a device.

        Args:
            pci_address: PCI address of the device

        Returns:
            Dictionary with IOMMU group information
        """
        iommu_group_path = Path(f"/sys/bus/pci/devices/{pci_address}/iommu_group")

        if not iommu_group_path.exists():
            self.logger.warning(f"Device {pci_address} is not in an IOMMU group")
            return {"group_number": None, "devices": []}

        try:
            group_link = iommu_group_path.resolve()
            group_number = group_link.name

            # Get all devices in this IOMMU group
            group_devices_path = Path(f"/sys/kernel/iommu_groups/{group_number}/devices")
            devices = []

            if group_devices_path.exists():
                for device_path in group_devices_path.iterdir():
                    device_name = device_path.name
                    driver_path = device_path / "driver"

                    device_info = {
                        "pci_address": device_name,
                        "driver": None,
                        "is_conflicting": False,
                    }

                    if driver_path.exists():
                        try:
                            driver_name = driver_path.resolve().name
                            device_info["driver"] = driver_name
                            device_info["is_conflicting"] = self._is_conflicting_driver(driver_name)
                        except (OSError, RuntimeError):
                            pass

                    devices.append(device_info)

            return {"group_number": group_number, "devices": devices}

        except (OSError, RuntimeError) as e:
            self.logger.error(f"Error reading IOMMU group for device {pci_address}: {e}")
            return {"group_number": None, "devices": []}

    def _validate_iommu_group_devices(self, pci_address: str, iommu_group_info: dict) -> bool:
        """Validate that all devices in the same IOMMU group can be properly managed.

        Args:
            pci_address: PCI address of the target device
            iommu_group_info: IOMMU group information

        Returns:
            True if validation passes, False otherwise
        """
        if not iommu_group_info["group_number"]:
            self.logger.info(
                f"Device {pci_address} is not in an IOMMU group - skipping group validation"
            )
            return True

        group_number = iommu_group_info["group_number"]
        devices = iommu_group_info["devices"]

        self.logger.info(f"Validating IOMMU group {group_number} with {len(devices)} devices")

        # Check if there are multiple devices in the group
        if len(devices) > 1:
            self.logger.info(f"IOMMU group {group_number} contains multiple devices:")

            conflicting_devices = []
            for device in devices:
                device_addr = device["pci_address"]
                driver = device["driver"]
                is_conflicting = device["is_conflicting"]

                self.logger.info(f"  {device_addr}: driver={driver}, conflicting={is_conflicting}")

                if is_conflicting:
                    conflicting_devices.append(device)

            if conflicting_devices:
                self.logger.warning(
                    f"Found {len(conflicting_devices)} devices with conflicting drivers in "
                    f"IOMMU group {group_number}"
                )
                self.logger.info(
                    "All devices in this IOMMU group must be unbound before VFIO binding"
                )

                # Provide instructions for unbinding all devices in the group
                self._log_iommu_group_unbinding_instructions(pci_address, iommu_group_info)

                return False
            else:
                self.logger.info(
                    f"All devices in IOMMU group {group_number} are properly configured"
                )
        else:
            self.logger.info(f"IOMMU group {group_number} contains only one device")

        return True

    def _log_iommu_group_unbinding_instructions(
        self, pci_address: str, iommu_group_info: dict
    ) -> None:
        """Log instructions for unbinding all devices in an IOMMU group.

        Args:
            pci_address: PCI address of the target device
            iommu_group_info: IOMMU group information
        """
        group_number = iommu_group_info["group_number"]
        devices = iommu_group_info["devices"]

        instructions = []
        instructions.append("=" * 80)
        instructions.append(f"IOMMU GROUP {group_number} UNBINDING REQUIRED")
        instructions.append("=" * 80)
        instructions.append("")
        instructions.append(
            f"Device {pci_address} is in IOMMU group {group_number} with other devices."
        )
        instructions.append("All devices in this group must be unbound before VFIO binding.")
        instructions.append("")

        instructions.append("DEVICES IN IOMMU GROUP:")
        for device in devices:
            device_addr = device["pci_address"]
            driver = device["driver"] or "no driver"
            is_conflicting = device["is_conflicting"]

            status = "CONFLICTING" if is_conflicting else "OK"
            instructions.append(f"  {device_addr}: {driver} [{status}]")

        instructions.append("")
        instructions.append("UNBINDING INSTRUCTIONS:")
        instructions.append("1. Unbind all devices in the IOMMU group:")
        instructions.append("")

        for device in devices:
            device_addr = device["pci_address"]
            driver = device["driver"]

            if driver:
                instructions.append(f"   # Unbind {device_addr} from {driver}")
                instructions.append(
                    f"   echo {device_addr} | sudo tee /sys/bus/pci/drivers/{driver}/unbind"
                )
            else:
                instructions.append(
                    f"   # {device_addr} is not bound to any driver (no action needed)"
                )

        instructions.append("")
        instructions.append("2. Then bind your target device to VFIO:")
        instructions.append(f"   echo {pci_address} | sudo tee /sys/bus/pci/drivers/vfio-pci/bind")
        instructions.append("")
        instructions.append("3. Verify binding:")
        instructions.append(f"   ls -l /sys/bus/pci/devices/{pci_address}/driver")
        instructions.append("   # Should show: /sys/bus/pci/drivers/vfio-pci")
        instructions.append("")
        instructions.append("=" * 80)
        instructions.append("END OF IOMMU GROUP UNBINDING INSTRUCTIONS")
        instructions.append("=" * 80)

        self.logger.error("\n".join(instructions))

    def _is_device_bound_to_vfio(self, pci_address: str) -> bool:
        """Check if a PCI device is bound to the VFIO driver."""
        driver_path = Path(f"/sys/bus/pci/devices/{pci_address}/driver")

        self.logger.info(f"Driver path: {driver_path}")

        if not driver_path.exists():
            self.logger.warning(
                f"No driver path found for device {pci_address}, "
                "that means that the device is not bound to any driver"
            )
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

    def bind_device_to_vfio_manual_steps(self, pci_address: str) -> bool:
        """Check VFIO binding status and provide manual binding instructions.

        This method analyzes the current VFIO binding status and provides
        detailed error messages with suggested actions for manual binding.

        Args:
            pci_address: PCI address of the device (format: 0000:xx:xx.x)

        Returns:
            True if device is already properly bound to VFIO, False otherwise

        Raises:
            ValueError: If device is not found or validation fails
        """
        self.logger.info(f"Checking VFIO binding status for device: {pci_address}")

        # Validate PCI address format
        if not self._is_valid_pci_address(pci_address):
            raise ValueError(f"Invalid PCI address format: {pci_address}")

        # Check if device exists
        if not self._pci_device_exists(pci_address):
            raise ValueError(f"PCIe device {pci_address} not found on system")

        # Get current device status
        status = self.get_pcie_device_status(pci_address)
        self.logger.info(f"Current device status: {status}")

        # If already bound to VFIO, no action needed
        if status["is_vfio"]:
            self.logger.info(f"Device {pci_address} is already bound to VFIO")
            return True

        # Get detailed instructions and log them as a single block
        instructions = self._get_vfio_binding_instructions(pci_address, status)
        self.logger.error(instructions)
        return False

    def _get_vfio_binding_instructions(self, pci_address: str, status: dict) -> str:
        """Get detailed VFIO binding instructions based on current device status.

        Args:
            pci_address: PCI address of the device
            status: Current device status dictionary

        Returns:
            Formatted instructions string
        """
        instructions = []
        instructions.append("=" * 80)
        instructions.append(f"VFIO BINDING REQUIRED FOR DEVICE: {pci_address}")
        instructions.append("=" * 80)
        instructions.append("")

        # Check prerequisites first
        instructions.append(self._get_prerequisites_check(pci_address))

        # Get specific binding instructions based on current status
        if status["driver"] == "unknown" or not status["driver"]:
            instructions.append(self._get_unbound_device_instructions(pci_address))
        elif status["is_conflicting"]:
            instructions.append(
                self._get_conflicting_driver_instructions(pci_address, status["driver"])
            )
        else:
            instructions.append(
                self._get_general_binding_instructions(pci_address, status["driver"])
            )

        # Get verification steps
        instructions.append(self._get_verification_instructions(pci_address))

        instructions.append("=" * 80)
        instructions.append("END OF VFIO BINDING INSTRUCTIONS")
        instructions.append("=" * 80)

        return "\n".join(instructions)

    def _get_prerequisites_check(self, pci_address: str) -> str:
        """Get prerequisite checks for VFIO binding.

        Args:
            pci_address: PCI address of the device

        Returns:
            Formatted prerequisites string
        """
        instructions = []
        instructions.append("PREREQUISITES CHECK:")
        instructions.append("1. Ensure IOMMU is enabled in BIOS/UEFI and kernel:")
        instructions.append("   cat /proc/cmdline | grep -i iommu")
        instructions.append("   Should contain: intel_iommu=on (Intel) or amd_iommu=on (AMD)")
        instructions.append("")

        # Check if VFIO modules are loaded
        try:
            with open("/proc/modules") as f:
                loaded_modules = f.read()

            required_modules = ["vfio", "vfio_iommu_type1", "vfio_pci"]
            missing_modules = [
                module for module in required_modules if module not in loaded_modules
            ]

            if missing_modules:
                instructions.append("2. Load required VFIO modules:")
                for module in missing_modules:
                    instructions.append(f"   sudo modprobe {module}")
                instructions.append("")
            else:
                instructions.append("2. VFIO modules are loaded ✓")
                instructions.append("")

        except (FileNotFoundError, PermissionError):
            instructions.append("2. Load required VFIO modules:")
            instructions.append("   sudo modprobe vfio")
            instructions.append("   sudo modprobe vfio_iommu_type1")
            instructions.append("   sudo modprobe vfio_pci")
            instructions.append("")

        # Check if VFIO-PCI driver exists
        vfio_pci_path = Path("/sys/bus/pci/drivers/vfio-pci")
        if not vfio_pci_path.exists():
            instructions.append("3. VFIO-PCI driver is not available!")
            instructions.append("   This usually means the vfio_pci module is not loaded.")
            instructions.append("   Load it manually:")
            instructions.append("   sudo modprobe vfio_pci")
            instructions.append("")
            instructions.append("   If that fails, check if your kernel supports VFIO:")
            instructions.append("   ls /sys/bus/pci/drivers/ | grep vfio")
            instructions.append("")
            instructions.append(
                "   If no VFIO drivers are listed, your kernel may not support VFIO."
            )
            instructions.append("   Check kernel configuration:")
            instructions.append("   zcat /proc/config.gz | grep -i vfio")
            instructions.append("")
        else:
            instructions.append("3. VFIO-PCI driver is available ✓")
            instructions.append("")

        # Check IOMMU groups
        instructions.append("4. Check IOMMU groups:")
        instructions.append("   find /sys/kernel/iommu_groups/ -type l | grep " + pci_address)
        instructions.append("   # This shows which IOMMU group the device belongs to")
        instructions.append("")
        instructions.append("   If no IOMMU groups are found, IOMMU may not be enabled.")
        instructions.append("")

        # Add troubleshooting section for common root-level issues
        instructions.append("5. TROUBLESHOOTING COMMON ROOT-LEVEL ISSUES:")
        instructions.append("")
        instructions.append("   A. IOMMU Group Conflicts:")
        instructions.append("      All devices in the same IOMMU group must be bound together.")
        instructions.append("      Check other devices in the same group:")
        instructions.append("      ls /sys/kernel/iommu_groups/*/devices/")
        instructions.append("")
        instructions.append("   B. Device Grouping Issues:")
        instructions.append("      If other devices in the group are bound to different drivers,")
        instructions.append("      you must unbind ALL devices in the group first:")
        instructions.append("      # Find all devices in the same IOMMU group")
        instructions.append(
            "      GROUP=$(readlink /sys/bus/pci/devices/" + pci_address + "/iommu_group)"
        )
        instructions.append("      ls $GROUP/devices/")
        instructions.append("")
        instructions.append("   C. Kernel Module Parameters:")
        instructions.append("      If IOMMU is not available, try unsafe mode (use with caution):")
        instructions.append("      sudo modprobe vfio enable_unsafe_noiommu_mode=1")
        instructions.append("      # Or if already loaded:")
        instructions.append(
            "      echo 1 | sudo tee /sys/module/vfio/parameters/enable_unsafe_noiommu_mode"
        )
        instructions.append("")
        instructions.append("   D. Security Module Conflicts:")
        instructions.append("      Check if SELinux or AppArmor is blocking access:")
        instructions.append("      # For SELinux:")
        instructions.append("      sudo ausearch -m avc -ts recent")
        instructions.append("      # For AppArmor:")
        instructions.append("      sudo dmesg | grep -i apparmor")
        instructions.append("")
        instructions.append("   E. Device State Issues:")
        instructions.append("      Ensure the device is not in use by any process:")
        instructions.append("      lsof +D /sys/bus/pci/devices/" + pci_address)
        instructions.append("      # Kill any processes using the device")
        instructions.append("")

        return "\n".join(instructions)

    def _get_unbound_device_instructions(self, pci_address: str) -> str:
        """Get instructions for unbound devices.

        Args:
            pci_address: PCI address of the device

        Returns:
            Formatted instructions string
        """
        instructions = []
        instructions.append("DEVICE STATUS: Device is not bound to any driver")
        instructions.append("")
        instructions.append("VFIO BINDING STEPS:")
        instructions.append("1. Load VFIO modules (if not loaded):")
        instructions.append("   sudo modprobe vfio vfio_iommu_type1 vfio_pci")
        instructions.append("")
        instructions.append("2. Get device vendor/device IDs:")
        instructions.append(f"   lspci -n -s {pci_address} | awk '{{print $3}}' | sed 's/:/ /'")
        instructions.append("")
        instructions.append("3. Add device to VFIO-PCI:")
        instructions.append("   # Copy the output from step 2 and run:")
        instructions.append(
            "   echo 'VENDOR_ID DEVICE_ID' | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id"
        )
        instructions.append("")
        instructions.append("4. Verify binding:")
        instructions.append(f"   ls -l /sys/bus/pci/devices/{pci_address}/driver")
        instructions.append("   # Should show: /sys/bus/pci/drivers/vfio-pci")
        instructions.append("")
        instructions.append("DEBUGGING HINTS:")
        instructions.append(
            "• If 'No such device' error: Check IOMMU group - all devices in group must be unbound"
        )
        instructions.append("• If device in use: Stop processes or use force unbind")
        instructions.append("• If still failing: Run 'dmesg | grep -i vfio' for kernel errors")
        instructions.append("• For NVIDIA GPUs: Stop nvidia-persistenced service first")

        return "\n".join(instructions)

    def _get_conflicting_driver_instructions(
        self,
        pci_address: str,
        driver: str,
    ) -> str:
        """Get instructions for devices bound to conflicting drivers.

        Args:
            pci_address: PCI address of the device
            driver: Current driver name

        Returns:
            Formatted instructions string
        """
        instructions = []
        instructions.append(f"DEVICE STATUS: Device is bound to conflicting driver: {driver}")
        instructions.append("")
        instructions.append("VFIO BINDING STEPS:")
        instructions.append("1. Unbind from current driver:")
        instructions.append(
            f"   echo {pci_address} | sudo tee /sys/bus/pci/drivers/{driver}/unbind"
        )
        instructions.append("")
        instructions.append("2. Load VFIO modules (if not loaded):")
        instructions.append("   sudo modprobe vfio vfio_iommu_type1 vfio_pci")
        instructions.append("")
        instructions.append("3. Get device vendor/device IDs:")
        instructions.append(f"   lspci -n -s {pci_address} | awk '{{print $3}}' | sed 's/:/ /'")
        instructions.append("")
        instructions.append("4. Add device to VFIO-PCI:")
        instructions.append("   # Copy the output from step 3 and run:")
        instructions.append(
            "   echo 'VENDOR_ID DEVICE_ID' | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id"
        )
        instructions.append("")
        instructions.append("5. Verify binding:")
        instructions.append(f"   ls -l /sys/bus/pci/devices/{pci_address}/driver")
        instructions.append("   # Should show: /sys/bus/pci/drivers/vfio-pci")
        instructions.append("")
        instructions.append("DEBUGGING HINTS:")
        instructions.append(
            "• If 'No such device' error: Check IOMMU group - all devices in group must be unbound"
        )
        instructions.append("• If device in use: Stop processes or use force unbind")
        instructions.append("• If still failing: Run 'dmesg | grep -i vfio' for kernel errors")
        instructions.append("• For NVIDIA GPUs: Stop nvidia-persistenced service first")

        return "\n".join(instructions)

    def _get_general_binding_instructions(self, pci_address: str, driver: str) -> str:
        """Get general binding instructions for devices with non-conflicting drivers.

        Args:
            pci_address: PCI address of the device
            driver: Current driver name

        Returns:
            Formatted instructions string
        """
        instructions = []
        instructions.append(f"DEVICE STATUS: Device is bound to driver: {driver}")
        instructions.append("")
        instructions.append("VFIO BINDING STEPS:")
        instructions.append("1. Unbind from current driver:")
        instructions.append(
            f"   echo {pci_address} | sudo tee /sys/bus/pci/drivers/{driver}/unbind"
        )
        instructions.append("")
        instructions.append("2. Load VFIO modules (if not loaded):")
        instructions.append("   sudo modprobe vfio vfio_iommu_type1 vfio_pci")
        instructions.append("")
        instructions.append("3. Get device vendor/device IDs:")
        instructions.append(f"   lspci -n -s {pci_address} | awk '{{print $3}}' | sed 's/:/ /'")
        instructions.append("")
        instructions.append("4. Add device to VFIO-PCI:")
        instructions.append("   # Copy the output from step 3 and run:")
        instructions.append(
            "   echo 'VENDOR_ID DEVICE_ID' | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id"
        )
        instructions.append("")
        instructions.append("5. Verify binding:")
        instructions.append(f"   ls -l /sys/bus/pci/devices/{pci_address}/driver")
        instructions.append("   # Should show: /sys/bus/pci/drivers/vfio-pci")
        instructions.append("")
        instructions.append("DEBUGGING HINTS:")
        instructions.append(
            "• If 'No such device' error: Check IOMMU group - all devices in group must be unbound"
        )
        instructions.append("• If device in use: Stop processes or use force unbind")
        instructions.append("• If still failing: Run 'dmesg | grep -i vfio' for kernel errors")
        instructions.append("• For NVIDIA GPUs: Stop nvidia-persistenced service first")

        return "\n".join(instructions)

    def _get_verification_instructions(self, pci_address: str) -> str:
        """Get verification instructions for VFIO binding.

        Args:
            pci_address: PCI address of the device

        Returns:
            Formatted instructions string
        """
        instructions = []
        instructions.append("VERIFICATION:")
        instructions.append("1. Check driver binding:")
        instructions.append(f"   ls -l /sys/bus/pci/devices/{pci_address}/driver")
        instructions.append("   Should show: /sys/bus/pci/drivers/vfio-pci")
        instructions.append("")
        instructions.append("2. Check IOMMU group:")
        instructions.append(f"   ls -l /sys/bus/pci/devices/{pci_address}/iommu_group")
        instructions.append("")
        instructions.append("3. List all VFIO devices:")
        instructions.append("   ls /sys/bus/pci/drivers/vfio-pci/")
        instructions.append("")
        instructions.append("4. Check device status:")
        instructions.append(f"   lspci -n -s {pci_address}")
        instructions.append("")

        return "\n".join(instructions)

    def get_kernel_debug_instructions(self, pci_address: str) -> str:
        """Get comprehensive kernel debugging instructions for VFIO binding failures.

        Args:
            pci_address: PCI address of the device

        Returns:
            Formatted kernel debugging instructions
        """
        instructions = []
        instructions.append("=" * 80)
        instructions.append(f"KERNEL DEBUGGING INSTRUCTIONS FOR DEVICE: {pci_address}")
        instructions.append("=" * 80)
        instructions.append("")
        instructions.append("When VFIO binding fails with 'No such device', follow these steps:")
        instructions.append("")

        instructions.append("1. IMMEDIATE KERNEL LOG CHECK:")
        instructions.append("   # Check for VFIO-related errors:")
        instructions.append("   dmesg | grep -i vfio | tail -20")
        instructions.append("")
        instructions.append("   # Check for IOMMU-related errors:")
        instructions.append("   dmesg | grep -i iommu | tail -20")
        instructions.append("")
        instructions.append("   # Check for device-specific errors:")
        instructions.append(f"   dmesg | grep -i {pci_address} | tail -20")
        instructions.append("")

        instructions.append("2. REAL-TIME MONITORING:")
        instructions.append("   # In Terminal 1 - Monitor kernel messages:")
        instructions.append("   sudo dmesg -w")
        instructions.append("")
        instructions.append("   # In Terminal 2 - Attempt binding:")
        instructions.append(f"   echo {pci_address} | sudo tee /sys/bus/pci/drivers/vfio-pci/bind")
        instructions.append("")
        instructions.append("   # Watch Terminal 1 for immediate error messages")
        instructions.append("")

        instructions.append("3. SPECIFIC ERROR PATTERNS:")
        instructions.append("   # Look for these specific error messages:")
        instructions.append("   dmesg | grep -i 'no such device'")
        instructions.append("   dmesg | grep -i 'device not found'")
        instructions.append("   dmesg | grep -i 'invalid device'")
        instructions.append("   dmesg | grep -i 'permission denied'")
        instructions.append("   dmesg | grep -i 'access denied'")
        instructions.append("")

        instructions.append("4. VFIO MODULE ANALYSIS:")
        instructions.append("   # Check if VFIO modules are loaded:")
        instructions.append("   lsmod | grep vfio")
        instructions.append("")
        instructions.append("   # Check VFIO module parameters:")
        instructions.append("   cat /sys/module/vfio/parameters/enable_unsafe_noiommu_mode")
        instructions.append("   cat /sys/module/vfio_pci/parameters/*")
        instructions.append("")
        instructions.append("   # Check VFIO module loading errors:")
        instructions.append("   dmesg | grep -i 'vfio.*error'")
        instructions.append("   dmesg | grep -i 'vfio.*fail'")
        instructions.append("")

        instructions.append("5. DEVICE STATE VERIFICATION:")
        instructions.append("   # Check device power state:")
        instructions.append(f"   cat /sys/bus/pci/devices/{pci_address}/power_state")
        instructions.append("")
        instructions.append("   # Check if device is enabled:")
        instructions.append(f"   cat /sys/bus/pci/devices/{pci_address}/enable")
        instructions.append("")
        instructions.append("   # Check device configuration:")
        instructions.append(f"   cat /sys/bus/pci/devices/{pci_address}/config")
        instructions.append("")

        instructions.append("6. IOMMU SPECIFIC DEBUGGING:")
        instructions.append("   # Check IOMMU group status:")
        instructions.append(f"   ls -l /sys/bus/pci/devices/{pci_address}/iommu_group")
        instructions.append("")
        instructions.append("   # Check IOMMU group devices:")
        instructions.append(
            "   GROUP=$(readlink /sys/bus/pci/devices/" + pci_address + "/iommu_group)"
        )
        instructions.append("   ls $GROUP/devices/")
        instructions.append("")
        instructions.append("   # Check IOMMU errors:")
        instructions.append("   dmesg | grep -i 'iommu.*error'")
        instructions.append("   dmesg | grep -i 'iommu.*fail'")
        instructions.append("")

        instructions.append("7. PCI SUBSYSTEM DEBUGGING:")
        instructions.append("   # Check PCI-related errors:")
        instructions.append("   dmesg | grep -i 'pci.*error'")
        instructions.append("   dmesg | grep -i 'pci.*fail'")
        instructions.append("")
        instructions.append("   # Check PCI device enumeration:")
        instructions.append("   dmesg | grep -i 'pci.*enumerate'")
        instructions.append("   dmesg | grep -i 'pci.*probe'")
        instructions.append("")

        instructions.append("8. SYSTEM CALL AND PERMISSION DEBUGGING:")
        instructions.append("   # Check for sysfs access errors:")
        instructions.append("   dmesg | grep -i 'sysfs.*error'")
        instructions.append("   dmesg | grep -i 'sysfs.*fail'")
        instructions.append("")
        instructions.append("   # Check for permission issues:")
        instructions.append("   dmesg | grep -i 'permission.*denied'")
        instructions.append("   dmesg | grep -i 'access.*denied'")
        instructions.append("")

        instructions.append("9. COMMON SOLUTIONS BASED ON KERNEL MESSAGES:")
        instructions.append("")
        instructions.append("   A. If you see 'IOMMU not enabled' errors:")
        instructions.append("      - Add intel_iommu=on or amd_iommu=on to kernel parameters")
        instructions.append("      - Reboot the system")
        instructions.append("")
        instructions.append("   B. If you see 'VFIO module not loaded' errors:")
        instructions.append(
            "      - Load VFIO modules: sudo modprobe vfio vfio_iommu_type1 vfio_pci"
        )
        instructions.append("")
        instructions.append("   C. If you see 'Device not in D0 power state' errors:")
        instructions.append(
            f"      - Enable device: echo 1 | sudo tee /sys/bus/pci/devices/{pci_address}/enable"
        )
        instructions.append("")
        instructions.append("   D. If you see 'Permission denied' errors:")
        instructions.append("      - Check SELinux/AppArmor: sudo ausearch -m avc -ts recent")
        instructions.append(
            "      - Check file permissions: ls -l /sys/bus/pci/drivers/vfio-pci/bind"
        )
        instructions.append("")
        instructions.append("   E. If you see 'IOMMU group conflict' errors:")
        instructions.append("      - Unbind all devices in the same IOMMU group first")
        instructions.append("      - Then bind your target device")
        instructions.append("")
        instructions.append("   F. If you see 'No IOMMU support' errors:")
        instructions.append(
            "      - Try unsafe mode: sudo modprobe vfio enable_unsafe_noiommu_mode=1"
        )
        instructions.append("      - Note: This is less secure but may work")
        instructions.append("")

        instructions.append("10. ADVANCED DEBUGGING:")
        instructions.append("    # Enable more verbose kernel messages:")
        instructions.append("    echo 8 | sudo tee /proc/sys/kernel/printk")
        instructions.append("")
        instructions.append("    # Check kernel ring buffer:")
        instructions.append("    sudo cat /proc/kmsg | grep -i vfio")
        instructions.append("")
        instructions.append("    # Check system logs:")
        instructions.append("    sudo journalctl -f | grep -i vfio")
        instructions.append("")

        instructions.append("=" * 80)
        instructions.append("END OF KERNEL DEBUGGING INSTRUCTIONS")
        instructions.append("=" * 80)

        return "\n".join(instructions)

    def get_detailed_debug_info(self, pci_address: str) -> str:
        """Get detailed debugging information for a specific PCIe device.

        Args:
            pci_address: PCI address of the device

        Returns:
            Formatted debug information string
        """
        debug_info = []
        debug_info.append("=" * 80)
        debug_info.append(f"DETAILED DEBUG INFO FOR DEVICE: {pci_address}")
        debug_info.append("=" * 80)
        debug_info.append("")

        # Basic device info
        debug_info.append("1. BASIC DEVICE INFORMATION:")
        debug_info.append(f"   PCI Address: {pci_address}")
        debug_info.append("   Device Details:")
        debug_info.append(f"   lspci -n -s {pci_address}")
        debug_info.append("")

        # IOMMU group info
        debug_info.append("2. IOMMU GROUP INFORMATION:")
        iommu_group_path = Path(f"/sys/bus/pci/devices/{pci_address}/iommu_group")
        if iommu_group_path.exists():
            try:
                group_link = iommu_group_path.resolve()
                group_number = group_link.name
                debug_info.append(f"   IOMMU Group: {group_number}")
                debug_info.append("   All devices in this group:")
                debug_info.append(f"   ls /sys/kernel/iommu_groups/{group_number}/devices/")
                debug_info.append("")

                # Check driver bindings for all devices in the group
                debug_info.append("   Current driver bindings in this group:")
                group_devices_path = Path(f"/sys/kernel/iommu_groups/{group_number}/devices")
                if group_devices_path.exists():
                    for device_path in group_devices_path.iterdir():
                        device_name = device_path.name
                        driver_path = device_path / "driver"
                        if driver_path.exists():
                            try:
                                driver_name = driver_path.resolve().name
                                debug_info.append(f"     {device_name}: {driver_name}")
                            except (OSError, RuntimeError):
                                debug_info.append(f"     {device_name}: unknown driver")
                        else:
                            debug_info.append(f"     {device_name}: no driver")
                debug_info.append("")
            except (OSError, RuntimeError) as e:
                debug_info.append(f"   Error reading IOMMU group: {e}")
                debug_info.append("")
        else:
            debug_info.append("   No IOMMU group found - IOMMU may not be enabled")
            debug_info.append("")

        # Current driver binding
        debug_info.append("3. CURRENT DRIVER BINDING:")
        driver_path = Path(f"/sys/bus/pci/devices/{pci_address}/driver")
        if driver_path.exists():
            try:
                driver_name = driver_path.resolve().name
                debug_info.append(f"   Current driver: {driver_name}")
                debug_info.append(f"   Driver path: {driver_path}")
                debug_info.append("")
            except (OSError, RuntimeError) as e:
                debug_info.append(f"   Error reading driver: {e}")
                debug_info.append("")
        else:
            debug_info.append("   Device is not bound to any driver")
            debug_info.append("")

        # VFIO driver availability
        debug_info.append("4. VFIO DRIVER AVAILABILITY:")
        vfio_pci_path = Path("/sys/bus/pci/drivers/vfio-pci")
        if vfio_pci_path.exists():
            debug_info.append("   VFIO-PCI driver is available")
            bind_path = vfio_pci_path / "bind"
            if bind_path.exists():
                debug_info.append("   VFIO-PCI bind file exists")
                debug_info.append(f"   Bind file permissions: {oct(bind_path.stat().st_mode)[-3:]}")
            else:
                debug_info.append("   VFIO-PCI bind file does not exist")
        else:
            debug_info.append("   VFIO-PCI driver is not available")
        debug_info.append("")

        # Device state
        debug_info.append("5. DEVICE STATE:")
        device_path = Path(f"/sys/bus/pci/devices/{pci_address}")

        # Power state
        power_state_path = device_path / "power_state"
        if power_state_path.exists():
            try:
                with open(power_state_path) as f:
                    power_state = f.read().strip()
                debug_info.append(f"   Power state: {power_state}")
            except OSError:
                debug_info.append("   Power state: unknown")
        else:
            debug_info.append("   Power state: not available")

        # Enable state
        enable_path = device_path / "enable"
        if enable_path.exists():
            try:
                with open(enable_path) as f:
                    enable_state = f.read().strip()
                debug_info.append(f"   Enable state: {enable_state}")
            except OSError:
                debug_info.append("   Enable state: unknown")
        else:
            debug_info.append("   Enable state: not available")
        debug_info.append("")

        # Process usage
        debug_info.append("6. PROCESS USAGE:")
        debug_info.append("   Check if device is in use by any process:")
        debug_info.append(f"   lsof +D /sys/bus/pci/devices/{pci_address}")
        debug_info.append("")

        # NVIDIA specific checks
        debug_info.append("7. NVIDIA-SPECIFIC CHECKS:")
        debug_info.append("   Check for NVIDIA processes:")
        debug_info.append("   ps aux | grep nvidia")
        debug_info.append("")
        debug_info.append("   Check nvidia-persistenced service:")
        debug_info.append("   systemctl status nvidia-persistenced")
        debug_info.append("")

        # Kernel messages
        debug_info.append("8. KERNEL MESSAGES:")
        debug_info.append("   Recent VFIO-related messages:")
        debug_info.append("   dmesg | grep -i vfio | tail -10")
        debug_info.append("")
        debug_info.append("   Recent messages for this device:")
        debug_info.append(f"   dmesg | grep -i {pci_address} | tail -10")
        debug_info.append("")

        # Recommended actions
        debug_info.append("9. RECOMMENDED ACTIONS:")
        debug_info.append("   Based on the above information, try these steps:")
        debug_info.append("")
        debug_info.append("   A. If device is in an IOMMU group with other devices:")
        debug_info.append("      - Unbind ALL devices in the group first")
        debug_info.append("      - Then bind your device to VFIO")
        debug_info.append("")
        debug_info.append("   B. If NVIDIA processes are running:")
        debug_info.append(
            "      - Stop nvidia-persistenced: sudo systemctl stop nvidia-persistenced"
        )
        debug_info.append("      - Kill any remaining NVIDIA processes")
        debug_info.append("")
        debug_info.append("   C. If device is in use by other processes:")
        debug_info.append("      - Stop those processes before binding")
        debug_info.append("")
        debug_info.append("   D. If all else fails:")
        debug_info.append(
            "      - Try unsafe mode: sudo modprobe vfio enable_unsafe_noiommu_mode=1"
        )
        debug_info.append("")

        debug_info.append("=" * 80)
        debug_info.append("END OF DEBUG INFO")
        debug_info.append("=" * 80)

        return "\n".join(debug_info)

    def get_vfio_binding_instructions(self, pci_address: str) -> str:
        """Get detailed manual instructions for binding a device to VFIO.

        Args:
            pci_address: PCI address of the device

        Returns:
            Formatted instructions string
        """
        instructions = f"""# VFIO Binding Instructions for Device {pci_address}

## Quick Steps

1. **Load VFIO modules**:
   ```bash
   sudo modprobe vfio vfio_iommu_type1 vfio_pci
   ```

2. **Get device vendor/device IDs**:
   ```bash
   lspci -n -s {pci_address} | awk '{{print $3}}' | sed 's/:/ /'
   ```

3. **Add device to VFIO-PCI**:
   ```bash
   # Copy output from step 2 and run:
   echo 'VENDOR_ID DEVICE_ID' | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id
   ```

4. **Verify binding**:
   ```bash
   ls -l /sys/bus/pci/devices/{pci_address}/driver
   # Should show: /sys/bus/pci/drivers/vfio-pci
   ```

## If Device is Already Bound to Another Driver

1. **Unbind from current driver**:
   ```bash
   echo {pci_address} | sudo tee /sys/bus/pci/drivers/CURRENT_DRIVER/unbind
   ```

2. **Then follow steps 1-4 above**

## Troubleshooting

- **"No such device" error**: Check IOMMU group - all devices in group must be unbound
- **Device in use**: Stop processes or use force unbind
- **Still failing**: Run `dmesg | grep -i vfio` for kernel errors
- **NVIDIA GPUs**: Stop nvidia-persistenced service first

## Prerequisites

- IOMMU enabled in BIOS/UEFI and kernel (`intel_iommu=on` or `amd_iommu=on`)
- Root privileges required
- Device not in use by other processes
"""
        return instructions
