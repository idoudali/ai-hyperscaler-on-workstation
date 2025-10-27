"""Tests for GPU utilities."""

import pytest

from ai_how.utils.gpu_utils import GPUAddressParser


class TestGPUAddressParser:
    """Test GPUAddressParser functionality."""

    def test_extract_pci_address_with_device_id(self):
        """Test extracting PCI address with device ID."""
        gpu_string = "0000:01:00.0 (10de:2204)"
        result = GPUAddressParser.extract_pci_address(gpu_string)
        assert result == "0000:01:00.0"

    def test_extract_pci_address_plain(self):
        """Test extracting plain PCI address."""
        gpu_string = "0000:01:00.0"
        result = GPUAddressParser.extract_pci_address(gpu_string)
        assert result == "0000:01:00.0"

    def test_extract_pci_address_with_text(self):
        """Test extracting PCI address from text with GPU name."""
        gpu_string = "NVIDIA RTX A6000 at 0000:01:00.0"
        result = GPUAddressParser.extract_pci_address(gpu_string)
        assert result == "0000:01:00.0"

    def test_extract_pci_address_prefixed(self):
        """Test extracting PCI address with prefix."""
        gpu_string = "GPU 0000:01:00.0"
        result = GPUAddressParser.extract_pci_address(gpu_string)
        assert result == "0000:01:00.0"

    def test_extract_pci_address_multiple_in_string(self):
        """Test extracting first PCI address when multiple present."""
        gpu_string = "Primary: 0000:01:00.0, Secondary: 0000:02:00.0"
        result = GPUAddressParser.extract_pci_address(gpu_string)
        assert result == "0000:01:00.0"

    def test_extract_pci_address_no_match(self):
        """Test extraction returns None when no PCI address found."""
        gpu_string = "NVIDIA RTX A6000"
        result = GPUAddressParser.extract_pci_address(gpu_string)
        assert result is None

    def test_extract_pci_address_empty_string(self):
        """Test extraction with empty string."""
        result = GPUAddressParser.extract_pci_address("")
        assert result is None

    def test_extract_pci_address_none(self):
        """Test extraction with None."""
        result = GPUAddressParser.extract_pci_address(None)
        assert result is None

    def test_extract_pci_address_different_domains(self):
        """Test extracting addresses from different PCI domains."""
        test_cases = [
            ("0000:01:00.0", "0000:01:00.0"),
            ("0001:0a:00.1", "0001:0a:00.1"),
            ("ffff:ff:1f.7", "ffff:ff:1f.7"),
        ]
        for gpu_string, expected in test_cases:
            result = GPUAddressParser.extract_pci_address(gpu_string)
            assert result == expected

    def test_is_valid_pci_address_valid(self):
        """Test validation of valid PCI addresses."""
        valid_addresses = [
            "0000:01:00.0",
            "0001:0a:00.1",
            "ffff:ff:1f.7",
            "1234:ab:cd.5",
        ]
        for address in valid_addresses:
            assert GPUAddressParser.is_valid_pci_address(address) is True

    def test_is_valid_pci_address_invalid(self):
        """Test validation rejects invalid addresses."""
        invalid_addresses = [
            "invalid",
            "0000:01:00",  # Missing function
            "01:00.0",  # Missing domain
            "0000:01:00.0 (extra)",  # Extra text
            "0000:01:00.8",  # Function > 7
            "",
            None,
        ]
        for address in invalid_addresses:
            assert GPUAddressParser.is_valid_pci_address(address) is False

    def test_format_pci_address_basic(self):
        """Test formatting PCI address from components."""
        result = GPUAddressParser.format_pci_address(0, 1, 0, 0)
        assert result == "0000:01:00.0"

    def test_format_pci_address_complex(self):
        """Test formatting complex PCI address."""
        result = GPUAddressParser.format_pci_address(0xFFFF, 0xAB, 0x1F, 7)
        assert result == "ffff:ab:1f.7"

    def test_format_pci_address_invalid_domain(self):
        """Test formatting rejects invalid domain."""
        with pytest.raises(ValueError, match="Invalid domain"):
            GPUAddressParser.format_pci_address(0x10000, 0, 0, 0)

        with pytest.raises(ValueError, match="Invalid domain"):
            GPUAddressParser.format_pci_address(-1, 0, 0, 0)

    def test_format_pci_address_invalid_bus(self):
        """Test formatting rejects invalid bus."""
        with pytest.raises(ValueError, match="Invalid bus"):
            GPUAddressParser.format_pci_address(0, 0x100, 0, 0)

        with pytest.raises(ValueError, match="Invalid bus"):
            GPUAddressParser.format_pci_address(0, -1, 0, 0)

    def test_format_pci_address_invalid_device(self):
        """Test formatting rejects invalid device."""
        with pytest.raises(ValueError, match="Invalid device"):
            GPUAddressParser.format_pci_address(0, 0, 0x20, 0)

        with pytest.raises(ValueError, match="Invalid device"):
            GPUAddressParser.format_pci_address(0, 0, -1, 0)

    def test_format_pci_address_invalid_function(self):
        """Test formatting rejects invalid function."""
        with pytest.raises(ValueError, match="Invalid function"):
            GPUAddressParser.format_pci_address(0, 0, 0, 8)

        with pytest.raises(ValueError, match="Invalid function"):
            GPUAddressParser.format_pci_address(0, 0, 0, -1)
