"""GPU resource utilities."""

import re


class GPUAddressParser:
    """Parses GPU PCI addresses from various formats."""

    # PCI address pattern: domain:bus:device.function
    # Format: xxxx:xx:xx.x where x is hexadecimal and function is 0-7
    PCI_ADDRESS_PATTERN = re.compile(r"([0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7])")

    @classmethod
    def extract_pci_address(cls, gpu_string: str) -> str | None:
        """Extract PCI address from GPU assignment string.

        Handles multiple formats including:
        - "0000:01:00.0 (10de:2204)" - Full PCI with device ID
        - "NVIDIA RTX A6000 at 0000:01:00.0" - GPU name with PCI
        - "0000:01:00.0" - Plain PCI address
        - "GPU 0000:01:00.0" - Prefixed format

        Args:
            gpu_string: String containing GPU information

        Returns:
            PCI address if found, None otherwise

        Examples:
            >>> GPUAddressParser.extract_pci_address("0000:01:00.0 (10de:2204)")
            '0000:01:00.0'
            >>> GPUAddressParser.extract_pci_address("NVIDIA RTX A6000")
            None
        """
        if not gpu_string:
            return None

        match = cls.PCI_ADDRESS_PATTERN.search(gpu_string)
        return match.group(1) if match else None

    @classmethod
    def is_valid_pci_address(cls, address: str) -> bool:
        """Check if string is a valid PCI address.

        Args:
            address: String to validate

        Returns:
            True if valid PCI address format, False otherwise

        Examples:
            >>> GPUAddressParser.is_valid_pci_address("0000:01:00.0")
            True
            >>> GPUAddressParser.is_valid_pci_address("invalid")
            False
        """
        if not address:
            return False
        return bool(cls.PCI_ADDRESS_PATTERN.fullmatch(address))

    @classmethod
    def format_pci_address(cls, domain: int, bus: int, device: int, function: int) -> str:
        """Format PCI address from components.

        Args:
            domain: PCI domain (0-65535)
            bus: PCI bus (0-255)
            device: PCI device (0-31)
            function: PCI function (0-7)

        Returns:
            Formatted PCI address string

        Raises:
            ValueError: If components are out of valid range

        Examples:
            >>> GPUAddressParser.format_pci_address(0, 1, 0, 0)
            '0000:01:00.0'
        """
        if not (0 <= domain <= 0xFFFF):
            raise ValueError(f"Invalid domain: {domain} (must be 0-65535)")
        if not (0 <= bus <= 0xFF):
            raise ValueError(f"Invalid bus: {bus} (must be 0-255)")
        if not (0 <= device <= 0x1F):
            raise ValueError(f"Invalid device: {device} (must be 0-31)")
        if not (0 <= function <= 7):
            raise ValueError(f"Invalid function: {function} (must be 0-7)")

        return f"{domain:04x}:{bus:02x}:{device:02x}.{function}"
