"""Tests for HPC manager path handling."""

from unittest.mock import patch

import pytest

from ai_how.vm_management.hpc_manager import HPCClusterManager, HPCManagerError


class TestHPCManagerPathHandling:
    """Test HPC manager path resolution and validation."""

    def test_hpc_manager_with_relative_path(self, tmp_path):
        """Test that HPC manager correctly resolves relative base_image_path."""
        # Create a mock qcow2 file
        qcow2_file = tmp_path / "test.qcow2"
        qcow2_file.touch()

        # Create a config with relative path
        config = {
            "clusters": {
                "hpc": {
                    "name": "test-cluster",
                    "base_image_path": "test.qcow2",  # Relative path
                    "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                    "controller": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 100,
                        "ip_address": "192.168.100.10",
                    },
                    "compute_nodes": [
                        {"cpu_cores": 8, "memory_gb": 16, "disk_gb": 200, "ip": "192.168.100.11"}
                    ],
                    "slurm_config": {"partitions": ["gpu"], "default_partition": "gpu"},
                }
            }
        }

        state_file = tmp_path / "state.json"

        with patch("pathlib.Path.cwd") as mock_cwd:
            mock_cwd.return_value = tmp_path

            # This should not raise an exception
            manager = HPCClusterManager(config, state_file)

            # The base_image_path should be resolved to absolute path
            assert manager.hpc_config["base_image_path"] == "test.qcow2"

    def test_hpc_manager_with_absolute_path(self, tmp_path):
        """Test that HPC manager correctly handles absolute base_image_path."""
        # Create a mock qcow2 file
        qcow2_file = tmp_path / "test.qcow2"
        qcow2_file.touch()

        # Create a config with absolute path
        config = {
            "clusters": {
                "hpc": {
                    "name": "test-cluster",
                    "base_image_path": str(qcow2_file),  # Absolute path
                    "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                    "controller": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 100,
                        "ip_address": "192.168.100.10",
                    },
                    "compute_nodes": [
                        {"cpu_cores": 8, "memory_gb": 16, "disk_gb": 200, "ip": "192.168.100.11"}
                    ],
                    "slurm_config": {"partitions": ["gpu"], "default_partition": "gpu"},
                }
            }
        }

        state_file = tmp_path / "state.json"

        # This should not raise an exception
        manager = HPCClusterManager(config, state_file)

        # The base_image_path should remain as absolute path
        assert manager.hpc_config["base_image_path"] == str(qcow2_file)

    def test_hpc_manager_with_nonexistent_file(self, tmp_path):
        """Test that HPC manager raises error for non-existent base_image_path."""
        # Create a config with non-existent file
        config = {
            "clusters": {
                "hpc": {
                    "name": "test-cluster",
                    "base_image_path": "nonexistent.qcow2",
                    "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                    "controller": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 100,
                        "ip_address": "192.168.100.10",
                    },
                    "compute_nodes": [
                        {"cpu_cores": 8, "memory_gb": 16, "disk_gb": 200, "ip": "192.168.100.11"}
                    ],
                    "slurm_config": {"partitions": ["gpu"], "default_partition": "gpu"},
                }
            }
        }

        state_file = tmp_path / "state.json"

        with patch("pathlib.Path.cwd") as mock_cwd:
            mock_cwd.return_value = tmp_path

            manager = HPCClusterManager(config, state_file)

            with pytest.raises(HPCManagerError, match="Base image validation failed"):
                manager._validate_cluster_config()

    def test_hpc_manager_with_wrong_extension(self, tmp_path):
        """Test that HPC manager raises error for wrong file extension."""
        # Create a file with wrong extension
        wrong_file = tmp_path / "test.img"
        wrong_file.touch()

        # Create a config with wrong extension
        config = {
            "clusters": {
                "hpc": {
                    "name": "test-cluster",
                    "base_image_path": "test.img",
                    "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                    "controller": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 100,
                        "ip_address": "192.168.100.10",
                    },
                    "compute_nodes": [
                        {"cpu_cores": 8, "memory_gb": 16, "disk_gb": 200, "ip": "192.168.100.11"}
                    ],
                    "slurm_config": {"partitions": ["gpu"], "default_partition": "gpu"},
                }
            }
        }

        state_file = tmp_path / "state.json"

        with patch("pathlib.Path.cwd") as mock_cwd:
            mock_cwd.return_value = tmp_path

            manager = HPCClusterManager(config, state_file)

            with pytest.raises(HPCManagerError, match="Base image validation failed"):
                manager._validate_cluster_config()
