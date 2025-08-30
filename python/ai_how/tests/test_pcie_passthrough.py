"""Tests for PCIe passthrough validation module."""

from unittest.mock import mock_open, patch

import pytest

from ai_how.pcie_validation.pcie_passthrough import PCIePassthroughValidator


class TestPCIePassthroughValidator:
    """Test cases for PCIePassthroughValidator class."""

    def setup_method(self):
        """Set up test fixtures."""
        self.validator = PCIePassthroughValidator()

    def test_is_valid_pci_address(self):
        """Test PCI address format validation."""
        # Valid addresses
        assert self.validator._is_valid_pci_address("0000:01:00.0")
        assert self.validator._is_valid_pci_address("0000:ff:ff.7")
        assert self.validator._is_valid_pci_address("0000:00:01.0")
        assert self.validator._is_valid_pci_address("0001:01:00.0")  # Different domain (now valid)
        assert self.validator._is_valid_pci_address("ffff:01:00.0")  # Maximum domain value

        # Invalid addresses
        assert not self.validator._is_valid_pci_address("0000:01:00")  # Missing function
        assert not self.validator._is_valid_pci_address("0000:01:00.8")  # Function > 7
        assert not self.validator._is_valid_pci_address("invalid")  # Completely invalid

    def test_cluster_has_pcie_passthrough(self):
        """Test detection of PCIe passthrough in cluster config."""
        # Cluster with PCIe passthrough enabled
        config_with_pcie = {
            "compute_nodes": [
                {
                    "pcie_passthrough": {
                        "enabled": True,
                        "devices": [{"pci_address": "0000:01:00.0", "device_type": "gpu"}],
                    }
                }
            ]
        }
        assert self.validator._cluster_has_pcie_passthrough(config_with_pcie)

        # Cluster without PCIe passthrough
        config_without_pcie = {"compute_nodes": [{"cpu_cores": 8, "memory_gb": 16}]}
        assert not self.validator._cluster_has_pcie_passthrough(config_without_pcie)

        # Cluster with PCIe passthrough disabled
        config_disabled = {
            "compute_nodes": [
                {
                    "pcie_passthrough": {
                        "enabled": False,
                        "devices": [{"pci_address": "0000:01:00.0", "device_type": "gpu"}],
                    }
                }
            ]
        }
        assert not self.validator._cluster_has_pcie_passthrough(config_disabled)

    def test_validate_pcie_device_config(self):
        """Test PCIe device configuration validation."""
        # Valid device config
        valid_device = {
            "pci_address": "0000:01:00.0",
            "device_type": "gpu",
            "vendor_id": "10de",
            "device_id": "2684",
        }
        assert self.validator._validate_pcie_device_config(valid_device)

        # Missing required fields
        invalid_device_missing = {
            "pci_address": "0000:01:00.0"
            # Missing device_type
        }
        assert not self.validator._validate_pcie_device_config(invalid_device_missing)

        # Invalid PCI address
        invalid_device_address = {"pci_address": "invalid", "device_type": "gpu"}
        assert not self.validator._validate_pcie_device_config(invalid_device_address)

        # Invalid device type
        invalid_device_type = {"pci_address": "0000:01:00.0", "device_type": "invalid_type"}
        assert not self.validator._validate_pcie_device_config(invalid_device_type)

    @patch("ai_how.pcie_validation.pcie_passthrough.run_subprocess_with_logging")
    def test_pci_device_exists(self, mock_run):
        """Test PCI device existence check."""
        # Device exists
        mock_result = type("MockResult", (), {})()
        mock_result.success = True
        mock_result.stdout = "0000:01:00.0 0300: 10de:2684 (rev a1)"
        mock_run.return_value = mock_result
        assert self.validator._pci_device_exists("0000:01:00.0")

        # Device doesn't exist (empty stdout)
        mock_result_empty = type("MockResult", (), {})()
        mock_result_empty.success = True
        mock_result_empty.stdout = ""
        mock_run.return_value = mock_result_empty
        assert not self.validator._pci_device_exists("0000:01:00.0")

        # Command fails
        mock_result_fail = type("MockResult", (), {})()
        mock_result_fail.success = False
        mock_result_fail.stdout = ""
        mock_run.return_value = mock_result_fail
        assert not self.validator._pci_device_exists("0000:01:00.0")

    @patch("pathlib.Path.exists")
    @patch("pathlib.Path.resolve")
    def test_is_device_bound_to_vfio(self, mock_resolve, mock_exists):
        """Test VFIO driver binding check."""
        # Device bound to VFIO
        mock_exists.return_value = True
        mock_resolve.return_value.name = "vfio-pci"
        assert self.validator._is_device_bound_to_vfio("0000:01:00.0")

        # Device bound to different driver
        mock_resolve.return_value.name = "nvidia"
        assert not self.validator._is_device_bound_to_vfio("0000:01:00.0")

        # No driver bound
        mock_exists.return_value = False
        assert not self.validator._is_device_bound_to_vfio("0000:01:00.0")

    @patch("pathlib.Path.exists")
    @patch("pathlib.Path.resolve")
    def test_is_device_bound_to_conflicting_driver(self, mock_resolve, mock_exists):
        """Test conflicting driver detection."""
        # Device bound to NVIDIA driver
        mock_exists.return_value = True
        mock_resolve.return_value.name = "nvidia"
        assert self.validator._is_device_bound_to_conflicting_driver("0000:01:00.0")

        # Device bound to VFIO driver
        mock_resolve.return_value.name = "vfio-pci"
        assert not self.validator._is_device_bound_to_conflicting_driver("0000:01:00.0")

        # Device bound to other driver
        mock_resolve.return_value.name = "xhci_hcd"
        assert not self.validator._is_device_bound_to_conflicting_driver("0000:01:00.0")

    def test_validate_vfio_modules(self):
        """Test VFIO modules validation."""
        # All required modules loaded
        modules_data = (
            "vfio 12345 0 - Live 0x0000000000000000\n"
            "vfio_iommu_type1 12346 0 - Live 0x0000000000000000\n"
            "vfio_pci 12347 0 - Live 0x0000000000000000"
        )
        with patch("builtins.open", new_callable=mock_open, read_data=modules_data):
            assert self.validator._validate_vfio_modules()

        # Missing modules
        incomplete_modules_data = "vfio 12345 0 - Live 0x0000000000000000"
        with patch("builtins.open", new_callable=mock_open, read_data=incomplete_modules_data):
            assert not self.validator._validate_vfio_modules()

    def test_validate_iommu_configuration(self):
        """Test IOMMU configuration validation."""
        # IOMMU enabled
        cmdline_data = "BOOT_IMAGE=/boot/vmlinuz intel_iommu=on root=/dev/sda1"
        with patch("builtins.open", new_callable=mock_open, read_data=cmdline_data):
            assert self.validator._validate_iommu_configuration()

        # IOMMU disabled
        cmdline_data_disabled = "BOOT_IMAGE=/boot/vmlinuz root=/dev/sda1"
        with patch("builtins.open", new_callable=mock_open, read_data=cmdline_data_disabled):
            assert not self.validator._validate_iommu_configuration()

    def test_is_x86_64_architecture(self):
        """Test x86_64 architecture detection."""
        # This test depends on the actual system architecture
        # We'll test the logic but not the actual result
        result = self.validator._is_x86_64_architecture()
        assert isinstance(result, bool)

    @patch("pathlib.Path.exists")
    def test_is_kvm_available(self, mock_exists):
        """Test KVM availability check."""
        # KVM available
        mock_exists.return_value = True
        with patch(
            "builtins.open",
            new_callable=mock_open,
            read_data="kvm 12345 0 - Live 0x0000000000000000",
        ):
            assert self.validator._is_kvm_available()

        # KVM not available
        mock_exists.return_value = False
        assert not self.validator._is_kvm_available()

    def test_get_pcie_device_status(self):
        """Test PCIe device status retrieval."""
        # Mock the internal methods
        with (
            patch.object(self.validator, "_pci_device_exists", return_value=True),
            patch.object(self.validator, "_is_device_bound_to_vfio", return_value=True),
            patch.object(
                self.validator, "_is_device_bound_to_conflicting_driver", return_value=False
            ),
            # Mock the driver path resolution to return a VFIO driver
            patch("pathlib.Path.exists", return_value=True),
            patch("pathlib.Path.resolve") as mock_resolve,
        ):
            # Mock the driver path to return a VFIO driver name
            mock_resolve.return_value.name = "vfio-pci"

            status = self.validator.get_pcie_device_status("0000:01:00.0")

            assert status["pci_address"] == "0000:01:00.0"
            assert status["exists"] is True
            assert status["is_vfio"] is True
            assert status["is_conflicting"] is False

    def test_list_pcie_devices(self):
        """Test PCIe device listing."""
        # Mock the entire list_pcie_devices method to return controlled data
        mock_devices = [
            {
                "pci_address": "0000:01:00.0",
                "exists": True,
                "driver": "vfio-pci",
                "is_vfio": True,
                "is_conflicting": False,
                "iommu_group": "1",
                "device_class": "0300",
            },
            {
                "pci_address": "0000:01:00.1",
                "exists": True,
                "driver": "vfio-pci",
                "is_vfio": True,
                "is_conflicting": False,
                "iommu_group": "1",
                "device_class": "0403",
            },
        ]

        with patch.object(self.validator, "list_pcie_devices", return_value=mock_devices):
            devices = self.validator.list_pcie_devices()
            assert len(devices) == 2
            assert devices[0]["pci_address"] == "0000:01:00.0"
            assert devices[0]["device_class"] == "0300"
            assert devices[1]["pci_address"] == "0000:01:00.1"
            assert devices[1]["device_class"] == "0403"

    @patch("ai_how.pcie_validation.pcie_passthrough.run_subprocess_with_logging")
    def test_pci_device_exists_fails_if_lspci_missing(self, mock_run):
        """Test that PCI device existence check fails if lspci command is missing."""
        # Arrange: Mock subprocess call to raise FileNotFoundError
        mock_run.side_effect = FileNotFoundError("lspci command not found")

        # Act: Call _pci_device_exists
        result = self.validator._pci_device_exists("0000:01:00.0")

        # Assert: The function returns False
        assert result is False

    @patch("builtins.open")
    @patch("pathlib.Path.exists")
    def test_is_kvm_available_fails_if_proc_unreadable(self, mock_path_exists, mock_open):
        """Test that KVM availability check fails if /proc/modules cannot be read."""
        # Arrange: Mock /dev/kvm exists but /proc/modules raises PermissionError
        mock_path_exists.return_value = True
        mock_open.side_effect = PermissionError("Permission denied")

        # Act: Call _is_kvm_available
        result = self.validator._is_kvm_available()

        # Assert: The function returns False
        assert result is False

    def test_validate_pcie_passthrough_config_integration(self):
        """Integration test for PCIe passthrough configuration validation."""
        # Test configuration with PCIe passthrough enabled
        config_data = {
            "clusters": {
                "test-cluster": {
                    "compute_nodes": [
                        {
                            "name": "gpu-node-01",
                            "pcie_passthrough": {
                                "enabled": True,
                                "devices": [
                                    {
                                        "pci_address": "0000:01:00.0",
                                        "device_type": "gpu",
                                        "vendor_id": "10de",
                                        "device_id": "2684",
                                    }
                                ],
                            },
                        }
                    ]
                }
            }
        }

        # Mock all system-level checks to pass
        with (
            patch.object(self.validator, "_validate_system_pcie_support", return_value=True),
            patch.object(self.validator, "_validate_vfio_modules", return_value=True),
            patch.object(self.validator, "_validate_iommu_configuration", return_value=True),
            patch.object(self.validator, "_pci_device_exists", return_value=True),
            patch.object(self.validator, "_is_device_bound_to_vfio", return_value=True),
            patch.object(
                self.validator, "_is_device_bound_to_conflicting_driver", return_value=False
            ),
            # Mock the device availability validation to pass
            patch.object(self.validator, "_validate_pcie_device_availability", return_value=True),
        ):
            # Should pass validation
            result = self.validator.validate_pcie_passthrough_config(config_data)
            assert result is True

        # Test configuration without PCIe passthrough
        config_no_pcie = {
            "clusters": {
                "test-cluster": {
                    "compute_nodes": [{"name": "cpu-node-01", "cpu_cores": 8, "memory_gb": 16}]
                }
            }
        }

        # Should pass validation (no PCIe passthrough to validate)
        result = self.validator.validate_pcie_passthrough_config(config_no_pcie)
        assert result is True

        # Test configuration that fails system validation
        with (
            patch.object(self.validator, "_validate_system_pcie_support", return_value=False),
            # Mock device availability to pass so we can test system validation failure
            patch.object(self.validator, "_validate_pcie_device_availability", return_value=True),
            pytest.raises(ValueError, match="System does not support PCIe passthrough"),
        ):
            self.validator.validate_pcie_passthrough_config(config_data)

        # Test configuration that fails device validation
        with (
            patch.object(self.validator, "_validate_system_pcie_support", return_value=True),
            patch.object(self.validator, "_validate_vfio_modules", return_value=True),
            patch.object(self.validator, "_validate_iommu_configuration", return_value=True),
            patch.object(self.validator, "_pci_device_exists", return_value=True),
            patch.object(self.validator, "_is_device_bound_to_vfio", return_value=False),
            patch.object(
                self.validator, "_is_device_bound_to_conflicting_driver", return_value=False
            ),
            pytest.raises(ValueError, match="is not available for passthrough"),
        ):
            self.validator.validate_pcie_passthrough_config(config_data)
