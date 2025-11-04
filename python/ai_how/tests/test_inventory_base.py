"""Unit tests for base inventory generator."""

from unittest.mock import patch

import pytest

from ai_how.inventory.base import BaseInventoryGenerator


@pytest.fixture
def minimal_config(tmp_path):
    """Create minimal cluster configuration."""
    # Create a mock project root with .git marker
    (tmp_path / ".git").mkdir()

    config_file = tmp_path / "cluster.yaml"
    config_content = """
clusters:
  hpc:
    name: test-hpc
    network:
      subnet: 192.168.100.0/24
    controller:
      cpu_cores: 4
      memory_gb: 8
      ip_address: 192.168.100.10
"""
    config_file.write_text(config_content)
    return config_file


@pytest.fixture
def ssh_key_path(tmp_path):
    """Create mock SSH key."""
    ssh_key = tmp_path / "id_rsa"
    ssh_key.write_text("mock_ssh_key")
    return ssh_key


class TestBaseInventoryGenerator:
    """Test BaseInventoryGenerator functionality."""

    def test_init_with_valid_config(self, minimal_config):
        """Test initialization with valid configuration."""
        generator = BaseInventoryGenerator(minimal_config, "hpc")

        assert generator.cluster_name == "hpc"
        assert generator.ssh_username == "admin"
        assert "hpc" in generator.config["clusters"]

    def test_init_with_missing_cluster(self, minimal_config):
        """Test initialization with non-existent cluster."""
        with pytest.raises(ValueError, match="Cluster 'nonexistent' not found"):
            BaseInventoryGenerator(minimal_config, "nonexistent")

    def test_init_with_custom_ssh_settings(self, minimal_config, ssh_key_path):
        """Test initialization with custom SSH settings."""
        generator = BaseInventoryGenerator(
            minimal_config, "hpc", ssh_key_path=ssh_key_path, ssh_username="testuser"
        )

        assert generator.ssh_username == "testuser"
        assert generator.ssh_key_path == ssh_key_path

    def test_get_ssh_args_basic(self, minimal_config):
        """Test SSH args generation without become."""
        generator = BaseInventoryGenerator(minimal_config, "hpc")

        ssh_args = generator.get_ssh_args(include_become=False)

        assert "ansible_ssh_private_key_file=" in ssh_args
        assert "StrictHostKeyChecking=no" in ssh_args
        assert "ansible_become=true" not in ssh_args

    def test_get_ssh_args_with_become(self, minimal_config):
        """Test SSH args generation with become."""
        generator = BaseInventoryGenerator(minimal_config, "hpc")

        ssh_args = generator.get_ssh_args(include_become=True)

        assert "ansible_ssh_private_key_file=" in ssh_args
        assert "ansible_become=true" in ssh_args

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_query_live_ip_running_domain(self, mock_get_ip, mock_get_state, minimal_config):
        """Test querying live IP for running domain."""
        mock_get_state.return_value = "running"
        mock_get_ip.return_value = "192.168.100.20"

        generator = BaseInventoryGenerator(minimal_config, "hpc")
        live_ip, changed = generator.query_live_ip("test-node", "192.168.100.10", "test-domain")

        assert live_ip == "192.168.100.20"
        assert changed is True  # IP changed from configured

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_query_live_ip_shut_off_domain(self, mock_get_ip, mock_get_state, minimal_config):
        """Test querying live IP for shut off domain."""
        mock_get_state.return_value = "shut off"

        generator = BaseInventoryGenerator(minimal_config, "hpc")
        live_ip, changed = generator.query_live_ip("test-node", "192.168.100.10", "test-domain")

        assert live_ip is None
        assert changed is False
        mock_get_ip.assert_not_called()

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_query_live_ip_no_change(self, mock_get_ip, mock_get_state, minimal_config):
        """Test querying live IP when it matches configured IP."""
        mock_get_state.return_value = "running"
        mock_get_ip.return_value = "192.168.100.10"

        generator = BaseInventoryGenerator(minimal_config, "hpc")
        live_ip, changed = generator.query_live_ip("test-node", "192.168.100.10", "test-domain")

        assert live_ip == "192.168.100.10"
        assert changed is False

    def test_detect_gpu_devices_with_gpu(self, minimal_config):
        """Test GPU device detection with GPU passthrough."""
        node_config = {
            "pcie_passthrough": {
                "enabled": True,
                "devices": [
                    {
                        "pci_address": "0000:01:00.0",
                        "device_type": "gpu",
                        "vendor_id": "10de",
                        "device_id": "2805",
                    },
                    {
                        "pci_address": "0000:01:00.1",
                        "device_type": "audio",
                        "vendor_id": "10de",
                        "device_id": "22bd",
                    },
                ],
            }
        }

        generator = BaseInventoryGenerator(minimal_config, "hpc")
        gpu_devices = generator.detect_gpu_devices(node_config)

        assert len(gpu_devices) == 1
        assert gpu_devices[0]["pci_address"] == "0000:01:00.0"
        assert gpu_devices[0]["device_type"] == "gpu"
        assert gpu_devices[0]["vendor_id"] == "10de"

    def test_detect_gpu_devices_without_gpu(self, minimal_config):
        """Test GPU device detection without GPU passthrough."""
        node_config = {"cpu_cores": 8, "memory_gb": 16}

        generator = BaseInventoryGenerator(minimal_config, "hpc")
        gpu_devices = generator.detect_gpu_devices(node_config)

        assert len(gpu_devices) == 0

    def test_generate_slurm_gres(self, minimal_config):
        """Test SLURM GRES configuration generation."""
        gpu_devices = [
            {
                "pci_address": "0000:01:00.0",
                "vendor_id": "10de",
                "device_id": "2805",
            },
            {
                "pci_address": "0000:07:00.0",
                "vendor_id": "10de",
                "device_id": "2504",
            },
        ]

        generator = BaseInventoryGenerator(minimal_config, "hpc")
        gres_lines = generator.generate_slurm_gres(gpu_devices, "compute-01")

        assert len(gres_lines) == 2
        assert "NodeName=compute-01" in gres_lines[0]
        assert "Name=gpu" in gres_lines[0]
        assert "Type=nvidia_2805" in gres_lines[0]
        assert "File=/dev/nvidia0" in gres_lines[0]

        assert "Type=nvidia_2504" in gres_lines[1]
        assert "File=/dev/nvidia1" in gres_lines[1]

    def test_generate_not_implemented(self, minimal_config):
        """Test that generate() must be implemented by subclass."""
        generator = BaseInventoryGenerator(minimal_config, "hpc")

        with pytest.raises(NotImplementedError):
            generator.generate()
