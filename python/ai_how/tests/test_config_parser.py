"""Tests for configuration parser utilities."""

from ai_how.utils.config_parser import ClusterConfigParser


class TestClusterConfigParser:
    """Test ClusterConfigParser functionality."""

    def test_extract_cluster_config_full_structure(self):
        """Test extracting config from full nested structure."""
        config = {
            "clusters": {
                "hpc": {"name": "test-hpc", "base_image_path": "/path/to/hpc.qcow2"},
                "cloud": {"name": "test-cloud", "base_image_path": "/path/to/cloud.qcow2"},
            },
            "global": {"log_level": "INFO", "timeout": 300},
        }

        hpc_config, global_config = ClusterConfigParser.extract_cluster_config(config, "hpc")

        assert hpc_config == {"name": "test-hpc", "base_image_path": "/path/to/hpc.qcow2"}
        assert global_config == {"log_level": "INFO", "timeout": 300}

    def test_extract_cluster_config_cloud(self):
        """Test extracting cloud cluster config."""
        config = {
            "clusters": {
                "cloud": {"name": "test-cloud", "network": {"subnet": "10.0.0.0/24"}},
            },
            "global": {"region": "us-east-1"},
        }

        cloud_config, global_config = ClusterConfigParser.extract_cluster_config(config, "cloud")

        assert cloud_config == {"name": "test-cloud", "network": {"subnet": "10.0.0.0/24"}}
        assert global_config == {"region": "us-east-1"}

    def test_extract_cluster_config_direct(self):
        """Test extracting from direct cluster config (no nested structure)."""
        config = {
            "name": "direct-hpc",
            "base_image_path": "/path/to/image.qcow2",
            "cpu_cores": 8,
        }

        hpc_config, global_config = ClusterConfigParser.extract_cluster_config(config, "hpc")

        assert hpc_config == config
        assert global_config == {}

    def test_extract_cluster_config_no_global(self):
        """Test extraction when global config is missing."""
        config = {
            "clusters": {
                "hpc": {"name": "test-hpc"},
            }
        }

        hpc_config, global_config = ClusterConfigParser.extract_cluster_config(config, "hpc")

        assert hpc_config == {"name": "test-hpc"}
        assert global_config == {}

    def test_extract_cluster_config_empty_global(self):
        """Test extraction with explicitly empty global config."""
        config = {
            "clusters": {"hpc": {"name": "test-hpc"}},
            "global": {},
        }

        hpc_config, global_config = ClusterConfigParser.extract_cluster_config(config, "hpc")

        assert hpc_config == {"name": "test-hpc"}
        assert global_config == {}
