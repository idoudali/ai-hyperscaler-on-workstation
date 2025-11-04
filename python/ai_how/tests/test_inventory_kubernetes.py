"""Unit tests for Kubernetes inventory generator."""

from unittest.mock import patch

import pytest

from ai_how.inventory.kubernetes import KubernetesInventoryGenerator


@pytest.fixture
def k8s_config(tmp_path):
    """Create Kubernetes cluster configuration."""
    # Create a mock project root with .git marker
    (tmp_path / ".git").mkdir()

    config_file = tmp_path / "cluster.yaml"
    config_content = """
clusters:
  cloud:
    name: test-k8s-cluster
    network:
      subnet: 192.168.200.0/24
      bridge: virbr200
    control_plane:
      cpu_cores: 4
      memory_gb: 8
      disk_gb: 100
      ip_address: 192.168.200.10
    worker_nodes:
      - cpu_cores: 4
        memory_gb: 8
        disk_gb: 100
        ip: 192.168.200.11
      - cpu_cores: 8
        memory_gb: 16
        disk_gb: 200
        ip: 192.168.200.12
        pcie_passthrough:
          enabled: true
          devices:
            - pci_address: "0000:01:00.0"
              device_type: gpu
              vendor_id: "10de"
              device_id: "2805"
"""
    config_file.write_text(config_content)
    return config_file


class TestKubernetesInventoryGenerator:
    """Test Kubernetes inventory generator functionality."""

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_generate_basic_inventory(self, mock_get_ip, mock_get_state, k8s_config):
        """Test generating basic Kubernetes inventory."""
        mock_get_state.return_value = "running"
        mock_get_ip.side_effect = lambda domain: {
            "cloud-cluster-control-plane": "192.168.200.10",
            "cloud-cluster-cpu-worker-01": "192.168.200.11",
            "cloud-cluster-gpu-worker-01": "192.168.200.12",
        }.get(domain)

        generator = KubernetesInventoryGenerator(k8s_config, "cloud")
        inventory = generator.generate()

        # Check basic structure
        assert "groups" in inventory
        assert "kube_control_plane" in inventory["groups"]
        assert "etcd" in inventory["groups"]
        assert "kube_node" in inventory["groups"]
        assert "calico_rr" in inventory["groups"]
        assert "k8s_cluster" in inventory["groups"]

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_control_plane_extraction(self, mock_get_ip, mock_get_state, k8s_config):
        """Test control plane node extraction."""
        mock_get_state.return_value = "running"
        mock_get_ip.return_value = "192.168.200.10"

        generator = KubernetesInventoryGenerator(k8s_config, "cloud")
        inventory = generator.generate()

        # Control plane should be in both kube_control_plane and etcd
        cp_hosts = inventory["groups"]["kube_control_plane"]["hosts"]
        etcd_hosts = inventory["groups"]["etcd"]["hosts"]

        assert "control-plane" in cp_hosts
        assert "control-plane" in etcd_hosts

        cp_node = cp_hosts["control-plane"]
        assert cp_node["ansible_host"] == "192.168.200.10"
        assert cp_node["ip"] == "192.168.200.10"
        assert "ansible_become" in cp_node
        assert cp_node["ansible_become"] == "true"

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_worker_nodes_extraction(self, mock_get_ip, mock_get_state, k8s_config):
        """Test worker nodes extraction."""
        mock_get_state.return_value = "running"
        mock_get_ip.side_effect = ["192.168.200.10", "192.168.200.11", "192.168.200.12"]

        generator = KubernetesInventoryGenerator(k8s_config, "cloud")
        inventory = generator.generate()

        worker_hosts = inventory["groups"]["kube_node"]["hosts"]

        # Should have both CPU and GPU workers
        assert "cpu-worker-01" in worker_hosts
        assert "gpu-worker-01" in worker_hosts

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_gpu_worker_detection(self, mock_get_ip, mock_get_state, k8s_config):
        """Test GPU workers are detected correctly."""
        mock_get_state.return_value = "running"
        mock_get_ip.side_effect = ["192.168.200.10", "192.168.200.11", "192.168.200.12"]

        generator = KubernetesInventoryGenerator(k8s_config, "cloud")
        inventory = generator.generate()

        worker_hosts = inventory["groups"]["kube_node"]["hosts"]

        # GPU worker should have correct naming
        assert "gpu-worker-01" in worker_hosts

        # Both should be in kube_node
        assert len(worker_hosts) == 2

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_kubespray_become_required(self, mock_get_ip, mock_get_state, k8s_config):
        """Test ansible_become=true is set for all hosts (Kubespray requirement)."""
        mock_get_state.return_value = "running"
        # 1 control plane + 2 workers = 3 IPs needed
        mock_get_ip.side_effect = ["192.168.200.10", "192.168.200.11", "192.168.200.12"]

        generator = KubernetesInventoryGenerator(k8s_config, "cloud")
        inventory = generator.generate()

        # Check all hosts have ansible_become=true
        for group_name in ["kube_control_plane", "kube_node"]:
            if group_name in inventory["groups"]:
                hosts = inventory["groups"][group_name]["hosts"]
                for host_vars in hosts.values():
                    # Should have ansible_become in the vars
                    assert "ansible_become" in host_vars
                    assert host_vars["ansible_become"] == "true"

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_ip_and_ansible_host_both_present(self, mock_get_ip, mock_get_state, k8s_config):
        """Test both 'ip' and 'ansible_host' are present (Kubespray requirement)."""
        mock_get_state.return_value = "running"
        mock_get_ip.return_value = "192.168.200.10"

        generator = KubernetesInventoryGenerator(k8s_config, "cloud")
        inventory = generator.generate()

        cp_hosts = inventory["groups"]["kube_control_plane"]["hosts"]
        cp_node = cp_hosts["control-plane"]

        # Both should be present
        assert "ansible_host" in cp_node
        assert "ip" in cp_node
        assert cp_node["ansible_host"] == cp_node["ip"]

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_shut_off_vms_excluded(self, mock_get_ip, mock_get_state, k8s_config):
        """Test shut off VMs are excluded from inventory."""
        mock_get_state.side_effect = ["running", "shut off", "running"]
        mock_get_ip.side_effect = ["192.168.200.10", "192.168.200.12"]

        generator = KubernetesInventoryGenerator(k8s_config, "cloud")
        inventory = generator.generate()

        worker_hosts = inventory["groups"]["kube_node"]["hosts"]

        # Only the running worker should be present
        assert "cpu-worker-01" not in worker_hosts  # This was shut off
        assert "gpu-worker-01" in worker_hosts  # This was running

    @patch("ai_how.inventory.base.get_domain_state")
    @patch("ai_how.inventory.base.get_domain_ip")
    def test_ip_calculation_with_offsets(self, mock_get_ip, mock_get_state, k8s_config):
        """Test IP address calculation respects control plane offset."""
        mock_get_state.return_value = "running"
        # Return None for live IPs to test configured IP calculation
        mock_get_ip.return_value = None

        # Mock domain state to return configured IPs
        def mock_query_live_ip(_node_name, configured_ip, _domain_name):
            # Return configured IP since we're testing calculation
            return configured_ip, False

        generator = KubernetesInventoryGenerator(k8s_config, "cloud")

        with patch.object(generator, "query_live_ip", side_effect=mock_query_live_ip):
            inventory = generator.generate()

        # Control plane should be at .10
        cp_hosts = inventory["groups"]["kube_control_plane"]["hosts"]
        if cp_hosts:
            cp_node = list(cp_hosts.values())[0]
            assert cp_node["ip"] == "192.168.200.10"

    def test_invalid_subnet_raises_error(self, tmp_path):
        """Test invalid subnet configuration raises error."""
        # Create a mock project root with .git marker
        (tmp_path / ".git").mkdir()

        config_file = tmp_path / "cluster.yaml"
        config_content = """
clusters:
  cloud:
    name: test-k8s
    network:
      subnet: invalid_subnet
    control_plane:
      cpu_cores: 4
"""
        config_file.write_text(config_content)

        with pytest.raises(ValueError, match="Invalid subnet configuration"):
            KubernetesInventoryGenerator(config_file, "cloud")

    def test_k8s_cluster_parent_group(self, k8s_config):
        """Test k8s_cluster parent group has correct children."""
        generator = KubernetesInventoryGenerator(k8s_config, "cloud")
        inventory = generator.generate()

        k8s_cluster = inventory["groups"]["k8s_cluster"]
        assert "children" in k8s_cluster
        assert "kube_control_plane" in k8s_cluster["children"]
        assert "kube_node" in k8s_cluster["children"]
        assert "calico_rr" in k8s_cluster["children"]
