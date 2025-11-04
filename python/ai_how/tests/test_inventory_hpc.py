"""Unit tests for HPC inventory generator."""

from unittest.mock import patch

import pytest

from ai_how.inventory.hpc import HPCInventoryGenerator


@pytest.fixture
def hpc_config(tmp_path):
    """Create HPC cluster configuration."""
    # Create a mock project root with .git marker
    (tmp_path / ".git").mkdir()

    config_file = tmp_path / "cluster.yaml"
    config_content = """
clusters:
  hpc:
    name: test-hpc-cluster
    network:
      subnet: 192.168.100.0/24
      bridge: virbr100
    controller:
      cpu_cores: 4
      memory_gb: 8
      disk_gb: 100
      ip_address: 192.168.100.10
      base_image_path: /path/to/controller.qcow2
      virtio_fs_mounts:
        - tag: project-repo
          host_path: /home/user/project
          mount_point: /mnt/project
          owner: admin
          group: admin
    compute_nodes:
      - cpu_cores: 8
        memory_gb: 16
        disk_gb: 200
        ip: 192.168.100.11
      - cpu_cores: 8
        memory_gb: 16
        disk_gb: 200
        ip: 192.168.100.12
        pcie_passthrough:
          enabled: true
          devices:
            - pci_address: "0000:01:00.0"
              device_type: gpu
              vendor_id: "10de"
              device_id: "2805"
    slurm_config:
      partitions: ["compute", "gpu"]
      default_partition: compute
    storage:
      beegfs:
        enabled: true
        mount_point: /mnt/beegfs
"""
    config_file.write_text(config_content)
    return config_file


class TestHPCInventoryGenerator:
    """Test HPC inventory generator functionality."""

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_generate_basic_inventory(self, mock_get_ip, mock_get_state, hpc_config):
        """Test generating basic HPC inventory."""
        # Mock all VMs as running with their configured IPs
        mock_get_state.return_value = "running"
        mock_get_ip.side_effect = lambda domain: {
            "hpc-cluster-controller": "192.168.100.10",
            "hpc-cluster-compute01": "192.168.100.11",
            "hpc-cluster-compute02": "192.168.100.12",
        }.get(domain)

        generator = HPCInventoryGenerator(hpc_config, "hpc")
        inventory = generator.generate()

        # Check basic structure
        assert "groups" in inventory
        assert "hpc_controllers" in inventory["groups"]
        assert "hpc_compute_nodes" in inventory["groups"]
        assert "hpc_gpu_nodes" in inventory["groups"]
        assert "hpc" in inventory["groups"]

        # Check parent group
        hpc_group = inventory["groups"]["hpc"]
        assert "children" in hpc_group
        assert "hpc_controllers" in hpc_group["children"]

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_controller_extraction(self, mock_get_ip, mock_get_state, hpc_config):
        """Test controller node extraction."""
        mock_get_state.return_value = "running"
        mock_get_ip.return_value = "192.168.100.10"

        generator = HPCInventoryGenerator(hpc_config, "hpc")
        inventory = generator.generate()

        controllers = inventory["groups"]["hpc_controllers"]["hosts"]
        assert "hpc-controller" in controllers

        controller = controllers["hpc-controller"]
        assert controller["ansible_host"] == "192.168.100.10"
        assert controller["slurm_node_name"] == "controller"
        assert controller["cpu_cores"] == 4
        assert controller["memory_gb"] == 8
        assert controller["node_role"] == "controller"

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_compute_nodes_separation(self, mock_get_ip, mock_get_state, hpc_config):
        """Test CPU and GPU compute nodes are separated correctly."""
        mock_get_state.return_value = "running"
        mock_get_ip.side_effect = ["192.168.100.10", "192.168.100.11", "192.168.100.12"]

        generator = HPCInventoryGenerator(hpc_config, "hpc")
        inventory = generator.generate()

        # Check CPU nodes
        cpu_nodes = inventory["groups"]["hpc_compute_nodes"]["hosts"]
        assert "hpc-compute01" in cpu_nodes
        assert cpu_nodes["hpc-compute01"]["has_gpu"] is False

        # Check GPU nodes
        gpu_nodes = inventory["groups"]["hpc_gpu_nodes"]["hosts"]
        assert "hpc-compute02" in gpu_nodes
        assert gpu_nodes["hpc-compute02"]["has_gpu"] is True
        assert gpu_nodes["hpc-compute02"]["gpu_count"] == 1

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_slurm_gres_generation(self, mock_get_ip, mock_get_state, hpc_config):
        """Test SLURM GRES configuration is generated for GPU nodes."""
        mock_get_state.return_value = "running"
        mock_get_ip.side_effect = ["192.168.100.10", "192.168.100.11", "192.168.100.12"]

        generator = HPCInventoryGenerator(hpc_config, "hpc")
        inventory = generator.generate()

        # Check GRES configuration exists
        hpc_vars = inventory["groups"]["hpc"]["vars"]
        assert "slurm_gres_conf" in hpc_vars

        gres_conf = hpc_vars["slurm_gres_conf"]
        assert len(gres_conf) == 1
        assert "NodeName=compute-02" in gres_conf[0]
        assert "Name=gpu" in gres_conf[0]
        assert "Type=nvidia_2805" in gres_conf[0]

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_virtio_fs_extraction(self, mock_get_ip, mock_get_state, hpc_config):
        """Test VirtIO-FS mounts are extracted."""
        mock_get_state.return_value = "running"
        mock_get_ip.return_value = "192.168.100.10"

        generator = HPCInventoryGenerator(hpc_config, "hpc")
        inventory = generator.generate()

        hpc_vars = inventory["groups"]["hpc"]["vars"]
        assert "virtio_fs_mounts" in hpc_vars

        # Should be JSON encoded
        import json

        mounts = json.loads(hpc_vars["virtio_fs_mounts"])
        assert len(mounts) == 1
        assert mounts[0]["tag"] == "project-repo"

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_beegfs_extraction(self, mock_get_ip, mock_get_state, hpc_config):
        """Test BeeGFS configuration is extracted."""
        mock_get_state.return_value = "running"
        mock_get_ip.return_value = "192.168.100.10"

        generator = HPCInventoryGenerator(hpc_config, "hpc")
        inventory = generator.generate()

        hpc_vars = inventory["groups"]["hpc"]["vars"]
        assert "beegfs_enabled" in hpc_vars
        assert hpc_vars["beegfs_enabled"] == "true"
        assert "beegfs_config" in hpc_vars

        # Should be JSON encoded
        import json

        beegfs_config = json.loads(hpc_vars["beegfs_config"])
        assert beegfs_config["enabled"] is True
        assert beegfs_config["mount_point"] == "/mnt/beegfs"

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_shut_off_vms_excluded(self, mock_get_ip, mock_get_state, hpc_config):
        """Test shut off VMs are excluded from inventory."""
        mock_get_state.side_effect = ["running", "shut off", "running"]
        mock_get_ip.side_effect = ["192.168.100.10", "192.168.100.12"]

        generator = HPCInventoryGenerator(hpc_config, "hpc")
        inventory = generator.generate()

        # Controller should be present
        assert "hpc-controller" in inventory["groups"]["hpc_controllers"]["hosts"]

        # Second compute node should be excluded
        all_hosts = []
        for group in ["hpc_controllers", "hpc_compute_nodes", "hpc_gpu_nodes"]:
            if group in inventory["groups"]:
                all_hosts.extend(inventory["groups"][group]["hosts"].keys())

        assert "hpc-compute01" not in all_hosts  # This one was shut off
        assert "hpc-compute02" in all_hosts  # This one was running

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_empty_groups_removed(self, mock_get_ip, mock_get_state, hpc_config):
        """Test empty groups are removed from inventory."""
        # Only controller running
        mock_get_state.side_effect = ["running", "shut off", "shut off"]
        mock_get_ip.return_value = "192.168.100.10"

        generator = HPCInventoryGenerator(hpc_config, "hpc")
        inventory = generator.generate()

        # Empty groups should be removed
        assert "hpc_controllers" in inventory["groups"]
        assert "hpc_compute_nodes" not in inventory["groups"]
        assert "hpc_gpu_nodes" not in inventory["groups"]

        # Parent group should not reference empty groups
        hpc_children = inventory["groups"]["hpc"]["children"]
        assert "hpc_compute_nodes" not in hpc_children
        assert "hpc_gpu_nodes" not in hpc_children
