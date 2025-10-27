"""Comprehensive unit tests for AI-HOW CLI commands."""

from __future__ import annotations

from typing import TYPE_CHECKING, Any
from unittest.mock import MagicMock, Mock, patch

import pytest
from typer.testing import CliRunner

from ai_how.cli import (
    _display_cluster_status,
    _display_system_status,
    _display_topology,
    app,
    load_and_render_config,
)
from ai_how.state.cluster_state import ClusterStateManager, VMState
from ai_how.system_manager import SystemClusterManager

if TYPE_CHECKING:
    from pathlib import Path

runner = CliRunner()


class TestLoadAndRenderConfig:
    """Tests for load_and_render_config function."""

    def test_load_yaml_without_variables(self, tmp_path: Path) -> None:
        """Test loading YAML configuration file without variables."""
        config_file = tmp_path / "config.yaml"
        config_file.write_text(
            """
metadata:
  name: test-cluster
clusters:
  hpc:
    name: test-hpc
"""
        )

        result = load_and_render_config(config_file)

        assert result is not None
        assert result["metadata"]["name"] == "test-cluster"
        assert result["clusters"]["hpc"]["name"] == "test-hpc"

    def test_load_nonexistent_file(self, tmp_path: Path) -> None:
        """Test loading nonexistent configuration file raises error."""
        nonexistent_file = tmp_path / "nonexistent.yaml"

        with pytest.raises(FileNotFoundError):
            load_and_render_config(nonexistent_file)

    def test_load_invalid_yaml(self, tmp_path: Path) -> None:
        """Test loading invalid YAML file raises error."""
        config_file = tmp_path / "invalid.yaml"
        config_file.write_text(": invalid yaml content [}")

        import yaml

        with pytest.raises(yaml.YAMLError):
            load_and_render_config(config_file)


class TestVMCommands:
    """Tests for individual VM management commands."""

    @patch("ai_how.cli.LibvirtClient")
    @patch("ai_how.cli.ClusterStateManager")
    @patch("ai_how.cli.GPUResourceAllocator")
    @patch("ai_how.cli.VMLifecycleManager")
    def test_vm_stop_success(
        self,
        mock_lifecycle: Mock,
        _mock_gpu_allocator: Mock,
        mock_state_manager: Mock,
        _mock_libvirt: Mock,
    ) -> None:
        """Test successfully stopping a VM."""
        # Setup mocks
        mock_cluster_state = MagicMock()
        mock_vm_info = MagicMock()
        mock_vm_info.domain_uuid = "test-uuid"
        mock_vm_info.vm_type = "compute"
        mock_vm_info.cpu_cores = 8
        mock_vm_info.memory_gb = 16

        mock_cluster_state.get_vm_by_name.return_value = mock_vm_info
        mock_state_manager_instance = MagicMock()
        mock_state_manager_instance.get_state.return_value = mock_cluster_state
        mock_state_manager.return_value = mock_state_manager_instance

        mock_lifecycle_instance = MagicMock()
        mock_lifecycle_instance.stop_vm_with_gpu_release.return_value = True
        mock_lifecycle.return_value = mock_lifecycle_instance

        # Run command
        result = runner.invoke(app, ["vm", "stop", "test-vm"])

        # Assertions
        assert result.exit_code == 0
        assert "stopped successfully" in result.stdout.lower()

    @patch("ai_how.cli.LibvirtClient")
    @patch("ai_how.cli.ClusterStateManager")
    @patch("ai_how.cli.GPUResourceAllocator")
    @patch("ai_how.cli.VMLifecycleManager")
    def test_vm_stop_vm_not_found(
        self,
        _mock_lifecycle: Mock,
        _mock_gpu_allocator: Mock,
        mock_state_manager: Mock,
        _mock_libvirt: Mock,
    ) -> None:
        """Test stopping a VM that does not exist."""
        # Setup mocks
        mock_cluster_state = MagicMock()
        mock_cluster_state.get_vm_by_name.return_value = None
        mock_state_manager_instance = MagicMock()
        mock_state_manager_instance.get_state.return_value = mock_cluster_state
        mock_state_manager.return_value = mock_state_manager_instance

        # Run command
        result = runner.invoke(app, ["vm", "stop", "nonexistent-vm"])

        # Assertions
        assert result.exit_code == 1
        assert "not found" in result.stdout.lower()

    @patch("ai_how.cli.LibvirtClient")
    @patch("ai_how.cli.ClusterStateManager")
    @patch("ai_how.cli.GPUResourceAllocator")
    @patch("ai_how.cli.VMLifecycleManager")
    def test_vm_start_success(
        self,
        mock_lifecycle: Mock,
        _mock_gpu_allocator: Mock,
        mock_state_manager: Mock,
        _mock_libvirt: Mock,
    ) -> None:
        """Test successfully starting a VM."""
        # Setup mocks
        mock_cluster_state = MagicMock()
        mock_vm_info = MagicMock()
        mock_vm_info.domain_uuid = "test-uuid"
        mock_cluster_state.get_vm_by_name.return_value = mock_vm_info
        mock_state_manager_instance = MagicMock()
        mock_state_manager_instance.get_state.return_value = mock_cluster_state
        mock_state_manager.return_value = mock_state_manager_instance

        mock_lifecycle_instance = MagicMock()
        mock_lifecycle_instance.start_vm_with_gpu_allocation.return_value = True
        mock_lifecycle.return_value = mock_lifecycle_instance

        # Run command
        result = runner.invoke(app, ["vm", "start", "test-vm"])

        # Assertions
        assert result.exit_code == 0
        assert "started successfully" in result.stdout.lower()

    @patch("ai_how.cli.LibvirtClient")
    @patch("ai_how.cli.ClusterStateManager")
    @patch("ai_how.cli.GPUResourceAllocator")
    @patch("ai_how.cli.VMLifecycleManager")
    def test_vm_restart_success(
        self,
        mock_lifecycle: Mock,
        _mock_gpu_allocator: Mock,
        mock_state_manager: Mock,
        _mock_libvirt: Mock,
    ) -> None:
        """Test successfully restarting a VM."""
        # Setup mocks
        mock_cluster_state = MagicMock()
        mock_vm_info = MagicMock()
        mock_cluster_state.get_vm_by_name.return_value = mock_vm_info
        mock_state_manager_instance = MagicMock()
        mock_state_manager_instance.get_state.return_value = mock_cluster_state
        mock_state_manager.return_value = mock_state_manager_instance

        mock_lifecycle_instance = MagicMock()
        mock_lifecycle_instance.restart_vm.return_value = True
        mock_lifecycle.return_value = mock_lifecycle_instance

        # Run command
        result = runner.invoke(app, ["vm", "restart", "test-vm"])

        # Assertions
        assert result.exit_code == 0
        assert "restarted successfully" in result.stdout.lower()

    @patch("ai_how.cli.LibvirtClient")
    @patch("ai_how.cli.ClusterStateManager")
    @patch("ai_how.cli.VMLifecycleManager")
    def test_vm_status_success(
        self,
        mock_lifecycle: Mock,
        mock_state_manager: Mock,
        _mock_libvirt: Mock,
    ) -> None:
        """Test getting VM status."""
        # Setup mocks
        mock_cluster_state = MagicMock()
        mock_vm_info = MagicMock()
        mock_vm_info.domain_uuid = "test-uuid"
        mock_vm_info.vm_type = "compute"
        mock_vm_info.cpu_cores = 8
        mock_vm_info.memory_gb = 16
        mock_vm_info.volume_path = "/path/to/volume"
        mock_vm_info.ip_address = "192.168.1.10"
        mock_vm_info.gpu_assigned = "NVIDIA RTX A6000"

        mock_cluster_state.get_vm_by_name.return_value = mock_vm_info
        mock_state_manager_instance = MagicMock()
        mock_state_manager_instance.get_state.return_value = mock_cluster_state
        mock_state_manager.return_value = mock_state_manager_instance

        mock_lifecycle_instance = MagicMock()
        mock_lifecycle_instance.get_vm_state.return_value = VMState.RUNNING
        mock_lifecycle.return_value = mock_lifecycle_instance

        # Run command
        result = runner.invoke(app, ["vm", "status", "test-vm"])

        # Assertions
        assert result.exit_code == 0
        assert "test-uuid" in result.stdout


class TestSystemCommands:
    """Tests for system-level cluster management commands."""

    @patch("ai_how.cli.validate_config")
    @patch("ai_how.cli.load_and_render_config")
    @patch("ai_how.cli.ClusterStateManager")
    @patch("ai_how.cli.SystemClusterManager")
    def test_system_start_success(
        self,
        mock_system_manager_class: Mock,
        mock_state_manager: Mock,
        mock_load_config: Mock,
        mock_validate_config: Mock,
        tmp_path: Path,
    ) -> None:
        """Test successfully starting the complete system."""
        # Create a temporary config file
        config_file = tmp_path / "cluster.yaml"
        config_file.write_text(
            "clusters:\n  hpc:\n    name: hpc-cluster\n  cloud:\n    name: cloud-cluster"
        )

        mock_unified_config = {
            "clusters": {"hpc": {"name": "hpc-cluster"}, "cloud": {"name": "cloud-cluster"}}
        }
        mock_load_config.return_value = mock_unified_config
        mock_validate_config.return_value = True  # Skip validation in tests

        # Mock state_manager with state_file.parent attribute for ClusterOperationExecutor
        mock_state_file = MagicMock()
        mock_state_file.parent = tmp_path
        mock_state_manager_instance = MagicMock()
        mock_state_manager_instance.state_file = mock_state_file
        mock_state_manager.return_value = mock_state_manager_instance

        mock_system_manager = MagicMock()
        mock_system_manager.start_all_clusters.return_value = True
        mock_system_manager.get_system_status.return_value = {
            "system_status": "running",
            "hpc_cluster": {"status": "running"},
            "cloud_cluster": {"status": "running"},
            "shared_resources": {},
            "timestamp": "2024-01-01T00:00:00",
        }
        mock_system_manager_class.return_value = mock_system_manager

        # Run command
        result = runner.invoke(
            app,
            [
                "--state",
                "/tmp/test-state.json",
                "system",
                "start",
                str(config_file),
            ],
        )

        # Assertions
        assert result.exit_code == 0
        assert "started successfully" in result.stdout.lower()

    @patch("ai_how.cli.validate_config")
    @patch("ai_how.cli.load_and_render_config")
    @patch("ai_how.cli.ClusterStateManager")
    @patch("ai_how.cli.SystemClusterManager")
    def test_system_start_failure(
        self,
        mock_system_manager_class: Mock,
        mock_state_manager: Mock,
        mock_load_config: Mock,
        mock_validate_config: Mock,
        tmp_path: Path,
    ) -> None:
        """Test system start failure."""
        # Create a temporary config file
        config_file = tmp_path / "cluster.yaml"
        config_file.write_text(
            "clusters:\n  hpc:\n    name: hpc-cluster\n  cloud:\n    name: cloud-cluster"
        )

        mock_unified_config = {
            "clusters": {"hpc": {"name": "hpc-cluster"}, "cloud": {"name": "cloud-cluster"}}
        }
        mock_load_config.return_value = mock_unified_config
        mock_validate_config.return_value = True

        mock_state_file = MagicMock()
        mock_state_file.parent = tmp_path
        mock_state_manager_instance = MagicMock()
        mock_state_manager_instance.state_file = mock_state_file
        mock_state_manager.return_value = mock_state_manager_instance

        mock_system_manager = MagicMock()
        mock_system_manager.start_all_clusters.return_value = False
        mock_system_manager_class.return_value = mock_system_manager

        # Run command
        result = runner.invoke(
            app,
            [
                "--state",
                "/tmp/test-state.json",
                "system",
                "start",
                str(config_file),
            ],
        )

        # Assertions
        assert result.exit_code == 1
        assert "failed" in result.stdout.lower()

    @patch("ai_how.cli.validate_config")
    @patch("ai_how.cli.load_and_render_config")
    @patch("ai_how.cli.ClusterStateManager")
    @patch("ai_how.cli.SystemClusterManager")
    def test_system_stop_success(
        self,
        mock_system_manager_class: Mock,
        mock_state_manager: Mock,
        mock_load_config: Mock,
        mock_validate_config: Mock,
        tmp_path: Path,
    ) -> None:
        """Test successfully stopping the complete system."""
        # Create a temporary config file
        config_file = tmp_path / "cluster.yaml"
        config_file.write_text(
            "clusters:\n  hpc:\n    name: hpc-cluster\n  cloud:\n    name: cloud-cluster"
        )

        mock_unified_config = {
            "clusters": {"hpc": {"name": "hpc-cluster"}, "cloud": {"name": "cloud-cluster"}}
        }
        mock_load_config.return_value = mock_unified_config
        mock_validate_config.return_value = True

        mock_state_file = MagicMock()
        mock_state_file.parent = tmp_path
        mock_state_manager_instance = MagicMock()
        mock_state_manager_instance.state_file = mock_state_file
        mock_state_manager.return_value = mock_state_manager_instance

        mock_system_manager = MagicMock()
        mock_system_manager.stop_all_clusters.return_value = True
        mock_system_manager_class.return_value = mock_system_manager

        # Run command
        result = runner.invoke(
            app,
            [
                "--state",
                "/tmp/test-state.json",
                "system",
                "stop",
                str(config_file),
            ],
        )

        # Assertions
        assert result.exit_code == 0
        assert "stopped successfully" in result.stdout.lower()

    @patch("ai_how.cli.validate_config")
    @patch("ai_how.cli.load_and_render_config")
    @patch("ai_how.cli.ClusterStateManager")
    @patch("ai_how.cli.SystemClusterManager")
    def test_system_destroy_with_confirmation(
        self,
        mock_system_manager_class: Mock,
        mock_state_manager: Mock,
        mock_load_config: Mock,
        mock_validate_config: Mock,
        tmp_path: Path,
    ) -> None:
        """Test system destroy with user confirmation."""
        # Create a temporary config file
        config_file = tmp_path / "cluster.yaml"
        config_file.write_text(
            "clusters:\n  hpc:\n    name: hpc-cluster\n  cloud:\n    name: cloud-cluster"
        )

        mock_unified_config = {
            "clusters": {"hpc": {"name": "hpc-cluster"}, "cloud": {"name": "cloud-cluster"}}
        }
        mock_load_config.return_value = mock_unified_config
        mock_validate_config.return_value = True

        mock_state_file = MagicMock()
        mock_state_file.parent = tmp_path
        mock_state_manager_instance = MagicMock()
        mock_state_manager_instance.state_file = mock_state_file
        mock_state_manager.return_value = mock_state_manager_instance

        mock_system_manager = MagicMock()
        mock_system_manager.destroy_all_clusters.return_value = True
        mock_system_manager_class.return_value = mock_system_manager

        # Run command with force flag (skip confirmation)
        result = runner.invoke(
            app,
            [
                "--state",
                "/tmp/test-state.json",
                "system",
                "destroy",
                str(config_file),
                "--force",
            ],
        )

        # Assertions
        assert result.exit_code == 0
        assert "destroyed successfully" in result.stdout.lower()

    @patch("ai_how.cli.validate_config")
    @patch("ai_how.cli.load_and_render_config")
    @patch("ai_how.cli.ClusterStateManager")
    @patch("ai_how.cli.SystemClusterManager")
    def test_system_status_success(
        self,
        mock_system_manager_class: Mock,
        mock_state_manager: Mock,
        mock_load_config: Mock,
        mock_validate_config: Mock,
        tmp_path: Path,
    ) -> None:
        """Test getting system status."""
        # Create a temporary config file
        config_file = tmp_path / "cluster.yaml"
        config_file.write_text(
            "clusters:\n  hpc:\n    name: hpc-cluster\n  cloud:\n    name: cloud-cluster"
        )

        mock_unified_config = {
            "clusters": {"hpc": {"name": "hpc-cluster"}, "cloud": {"name": "cloud-cluster"}}
        }
        mock_load_config.return_value = mock_unified_config
        mock_validate_config.return_value = True

        mock_state_file = MagicMock()
        mock_state_file.parent = tmp_path
        mock_state_manager_instance = MagicMock()
        mock_state_manager_instance.state_file = mock_state_file
        mock_state_manager.return_value = mock_state_manager_instance

        mock_system_manager = MagicMock()
        mock_system_manager.get_system_status.return_value = {
            "system_status": "running",
            "hpc_cluster": {"status": "running", "total_vms": 2, "running_vms": 2},
            "cloud_cluster": {"status": "running", "total_vms": 3, "running_vms": 3},
            "shared_resources": {"gpu_allocations": {"0000:01:00.0": "hpc-cluster-compute-01"}},
            "timestamp": "2024-01-01T00:00:00",
        }
        mock_system_manager_class.return_value = mock_system_manager

        # Run command
        result = runner.invoke(
            app,
            [
                "--state",
                "/tmp/test-state.json",
                "system",
                "status",
                str(config_file),
            ],
        )

        # Assertions
        assert result.exit_code == 0
        assert "running" in result.stdout.lower()


class TestTopologyCommand:
    """Tests for topology command."""

    @patch("ai_how.cli.ClusterStateManager")
    def test_topology_success(self, mock_state_manager: Mock) -> None:
        """Test displaying topology successfully."""
        # Setup mocks
        mock_state_manager_instance = MagicMock()
        mock_cluster_state = MagicMock()
        mock_state_manager_instance.get_state.return_value = mock_cluster_state
        mock_state_manager.return_value = mock_state_manager_instance

        # Run command
        result = runner.invoke(app, ["topology"])

        # Assertions
        assert result.exit_code == 0
        assert "topology" in result.stdout.lower()
        assert "hpc" in result.stdout.lower() or "cluster" in result.stdout.lower()

    @patch("ai_how.cli.ClusterStateManager")
    def test_topology_no_state(self, mock_state_manager: Mock) -> None:
        """Test topology when no cluster state exists."""
        # Setup mocks
        mock_state_manager_instance = MagicMock()
        mock_state_manager_instance.get_state.return_value = None
        mock_state_manager.return_value = mock_state_manager_instance

        # Run command
        result = runner.invoke(app, ["topology"])

        # Assertions
        assert result.exit_code == 0
        assert "no cluster state" in result.stdout.lower()


class TestDisplayFunctions:
    """Tests for display helper functions."""

    def test_display_cluster_status(self, capsys: Any) -> None:
        """Test cluster status display."""
        status = {
            "status": "running",
            "cluster_name": "test-cluster",
            "cluster_type": "hpc",
            "total_vms": 2,
            "running_vms": 2,
            "controller_status": "running",
            "compute_nodes": 1,
            "vms": [
                {
                    "name": "controller",
                    "state": "running",
                    "cpu_cores": 4,
                    "memory_gb": 8,
                    "ip_address": "192.168.1.10",
                    "gpu_assigned": None,
                }
            ],
        }

        _display_cluster_status(status)
        captured = capsys.readouterr()

        assert "test-cluster" in captured.out
        assert "running" in captured.out.lower()

    def test_display_system_status(self, capsys: Any) -> None:
        """Test system status display."""
        status = {
            "system_status": "running",
            "hpc_cluster": {"status": "running", "total_vms": 2},
            "cloud_cluster": {"status": "running", "total_vms": 3},
            "shared_resources": {"gpu_allocations": {}},
            "timestamp": "2024-01-01T00:00:00",
        }

        _display_system_status(status)
        captured = capsys.readouterr()

        assert "running" in captured.out.lower()
        assert "hpc" in captured.out.lower()
        assert "cloud" in captured.out.lower()

    def test_display_topology(self, capsys: Any) -> None:
        """Test topology display."""
        _display_topology()
        captured = capsys.readouterr()

        assert "topology" in captured.out.lower()
        assert "cluster" in captured.out.lower()


class TestSystemManagerIntegration:
    """Integration tests for SystemClusterManager."""

    def test_system_manager_initialization(self, tmp_path: Path) -> None:
        """Test SystemClusterManager initialization."""
        state_file = tmp_path / "state.json"
        state_file.write_text("{}")

        state_manager = ClusterStateManager(state_file)
        system_manager = SystemClusterManager(state_manager)

        assert system_manager is not None
        assert system_manager.state_manager == state_manager
        assert system_manager.hpc_manager is None
        assert system_manager.cloud_manager is None

    @patch("ai_how.system_manager.HPCClusterManager")
    @patch("ai_how.system_manager.CloudClusterManager")
    def test_system_manager_start_all_clusters(
        self,
        mock_cloud_manager_class: Mock,
        mock_hpc_manager_class: Mock,
        tmp_path: Path,
    ) -> None:
        """Test starting all clusters through SystemClusterManager."""
        # Setup state
        state_file = tmp_path / "state.json"
        state_file.write_text("{}")
        state_manager = ClusterStateManager(state_file)
        system_manager = SystemClusterManager(state_manager)

        # Setup mock managers
        mock_hpc_manager = MagicMock()
        mock_hpc_manager.start_cluster.return_value = True
        mock_hpc_manager.status_cluster.return_value = {"status": "running"}
        mock_hpc_manager_class.return_value = mock_hpc_manager

        mock_cloud_manager = MagicMock()
        mock_cloud_manager.start_cluster.return_value = True
        mock_cloud_manager.status.return_value = {"status": "running"}
        mock_cloud_manager_class.return_value = mock_cloud_manager

        # Call start_all_clusters
        hpc_config = {"clusters": {"hpc": {}}}
        cloud_config = {"clusters": {"cloud": {}}}

        result = system_manager.start_all_clusters(hpc_config, cloud_config)

        # Assertions
        assert result is True
        mock_hpc_manager.start_cluster.assert_called_once()
        mock_cloud_manager.start_cluster.assert_called_once()

    @patch("ai_how.system_manager.HPCClusterManager")
    @patch("ai_how.system_manager.CloudClusterManager")
    def test_system_manager_stop_all_clusters(
        self,
        mock_cloud_manager_class: Mock,
        mock_hpc_manager_class: Mock,
        tmp_path: Path,
    ) -> None:
        """Test stopping all clusters through SystemClusterManager."""
        # Setup state
        state_file = tmp_path / "state.json"
        state_file.write_text("{}")
        state_manager = ClusterStateManager(state_file)
        system_manager = SystemClusterManager(state_manager)

        # Setup mock managers
        mock_hpc_manager = MagicMock()
        mock_hpc_manager.stop_cluster.return_value = True
        mock_hpc_manager_class.return_value = mock_hpc_manager

        mock_cloud_manager = MagicMock()
        mock_cloud_manager.stop_cluster.return_value = True
        mock_cloud_manager_class.return_value = mock_cloud_manager

        # Call stop_all_clusters
        hpc_config = {"clusters": {"hpc": {}}}
        cloud_config = {"clusters": {"cloud": {}}}

        result = system_manager.stop_all_clusters(hpc_config, cloud_config)

        # Assertions
        assert result is True
        mock_cloud_manager.stop_cluster.assert_called_once()
        mock_hpc_manager.stop_cluster.assert_called_once()

    def test_system_manager_determine_status(self, tmp_path: Path) -> None:
        """Test system status determination logic."""
        state_file = tmp_path / "state.json"
        state_file.write_text("{}")
        state_manager = ClusterStateManager(state_file)
        system_manager = SystemClusterManager(state_manager)

        # Test running status
        status = system_manager._determine_system_status(
            {"status": "running"}, {"status": "running"}
        )
        assert status == "running"

        # Test stopped status
        status = system_manager._determine_system_status(
            {"status": "stopped"}, {"status": "stopped"}
        )
        assert status == "stopped"

        # Test mixed status
        status = system_manager._determine_system_status(
            {"status": "running"}, {"status": "stopped"}
        )
        assert status == "mixed"

        # Test error status
        status = system_manager._determine_system_status({"status": "error"}, {"status": "running"})
        assert status == "error"
