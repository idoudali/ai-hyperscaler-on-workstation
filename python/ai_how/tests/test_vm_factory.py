"""Tests for VM factory."""

from pathlib import Path
from unittest.mock import Mock

import pytest

from ai_how.state.cluster_state import ClusterState, VMState
from ai_how.state.models import VMInfo
from ai_how.vm_management.vm_factory import VMFactory, VMFactoryError, VMSpec


class TestVMSpec:
    """Test VMSpec dataclass."""

    def test_vmspec_creation(self):
        """Test creating VMSpec with required fields."""
        spec = VMSpec(
            vm_name="test-vm",
            cluster_name="test-cluster",
            vm_type="compute",
            cpu_cores=4,
            memory_gb=8,
            disk_gb=100,
            template_name="compute.xml.j2",
        )

        assert spec.vm_name == "test-vm"
        assert spec.cluster_name == "test-cluster"
        assert spec.vm_type == "compute"
        assert spec.cpu_cores == 4
        assert spec.memory_gb == 8
        assert spec.disk_gb == 100
        assert spec.template_name == "compute.xml.j2"
        assert spec.static_ip is None
        assert spec.pcie_passthrough is None

    def test_vmspec_with_optional_fields(self):
        """Test creating VMSpec with optional fields."""
        spec = VMSpec(
            vm_name="test-vm",
            cluster_name="test-cluster",
            vm_type="gpu",
            cpu_cores=8,
            memory_gb=16,
            disk_gb=200,
            template_name="gpu.xml.j2",
            static_ip="10.0.0.10",
            pcie_passthrough={"device": "0000:01:00.0"},
        )

        assert spec.static_ip == "10.0.0.10"
        assert spec.pcie_passthrough == {"device": "0000:01:00.0"}


class TestVMFactory:
    """Test VMFactory functionality."""

    @pytest.fixture
    def mock_managers(self):
        """Create mock managers for testing."""
        volume_manager = Mock()
        network_manager = Mock()
        vm_lifecycle = Mock()
        xml_generator = Mock()

        return {
            "volume": volume_manager,
            "network": network_manager,
            "lifecycle": vm_lifecycle,
            "xml_gen": xml_generator,
        }

    @pytest.fixture
    def vm_factory(self, mock_managers):
        """Create VMFactory instance with mocked dependencies."""
        return VMFactory(
            volume_manager=mock_managers["volume"],
            network_manager=mock_managers["network"],
            vm_lifecycle=mock_managers["lifecycle"],
            xml_generator=mock_managers["xml_gen"],
        )

    @pytest.fixture
    def cluster_state(self):
        """Create mock cluster state."""
        state = Mock(spec=ClusterState)
        state.get_vm_by_name = Mock(return_value=None)
        return state

    @pytest.fixture
    def basic_spec(self):
        """Create basic VM spec for testing."""
        return VMSpec(
            vm_name="test-vm",
            cluster_name="test-cluster",
            vm_type="compute",
            cpu_cores=4,
            memory_gb=8,
            disk_gb=100,
            template_name="compute.xml.j2",
        )

    def test_create_vm_success(self, vm_factory, mock_managers, cluster_state, basic_spec):
        """Test successful VM creation."""
        # Setup mocks
        mock_managers["volume"].create_vm_volume.return_value = "/var/lib/libvirt/test-vm.qcow2"
        mock_managers["network"].allocate_ip_address.return_value = "10.0.0.10"
        mock_managers["xml_gen"].return_value = "<domain>...</domain>"
        mock_managers["lifecycle"].create_vm.return_value = "test-uuid-1234"

        # Execute
        vm_info = vm_factory.create_vm(basic_spec, cluster_state)

        # Verify
        assert vm_info.name == "test-vm"
        assert vm_info.domain_uuid == "test-uuid-1234"
        assert vm_info.state == VMState.SHUTOFF
        assert vm_info.cpu_cores == 4
        assert vm_info.memory_gb == 8
        assert vm_info.volume_path == Path("/var/lib/libvirt/test-vm.qcow2")
        assert vm_info.vm_type == "compute"
        assert vm_info.ip_address == "10.0.0.10"

        # Verify method calls
        mock_managers["volume"].create_vm_volume.assert_called_once_with(
            cluster_name="test-cluster",
            vm_name="test-vm",
            size_gb=100,
            vm_type="compute",
        )
        mock_managers["network"].allocate_ip_address.assert_called_once_with(
            "test-cluster", "test-vm"
        )

    def test_create_vm_with_static_ip(self, vm_factory, mock_managers, cluster_state):
        """Test VM creation with static IP."""
        spec = VMSpec(
            vm_name="test-vm",
            cluster_name="test-cluster",
            vm_type="controller",
            cpu_cores=4,
            memory_gb=8,
            disk_gb=100,
            template_name="controller.xml.j2",
            static_ip="10.0.0.5",
        )

        mock_managers["volume"].create_vm_volume.return_value = "/var/lib/libvirt/test-vm.qcow2"
        mock_managers["xml_gen"].return_value = "<domain>...</domain>"
        mock_managers["lifecycle"].create_vm.return_value = "test-uuid"

        vm_info = vm_factory.create_vm(spec, cluster_state)

        # Verify static IP was used (not allocated)
        assert vm_info.ip_address == "10.0.0.5"
        mock_managers["network"].allocate_ip_address.assert_not_called()

    def test_create_vm_already_exists(self, vm_factory, cluster_state, basic_spec):
        """Test VM creation fails if VM already exists."""
        # Mock VM already exists
        existing_vm = Mock(spec=VMInfo)
        cluster_state.get_vm_by_name.return_value = existing_vm

        with pytest.raises(VMFactoryError, match="already exists"):
            vm_factory.create_vm(basic_spec, cluster_state)

    def test_create_vm_volume_creation_fails(
        self, vm_factory, mock_managers, cluster_state, basic_spec
    ):
        """Test VM creation fails when volume creation fails."""
        from ai_how.vm_management.volume_manager import VolumeManagerError

        mock_managers["volume"].create_vm_volume.side_effect = VolumeManagerError(
            "Insufficient space"
        )

        with pytest.raises(VMFactoryError, match="Failed to create VM"):
            vm_factory.create_vm(basic_spec, cluster_state)

    def test_create_vm_ip_allocation_fails(
        self, vm_factory, mock_managers, cluster_state, basic_spec
    ):
        """Test VM creation fails when IP allocation fails."""
        from ai_how.vm_management.network_manager import NetworkManagerError

        mock_managers["volume"].create_vm_volume.return_value = "/var/lib/libvirt/test-vm.qcow2"
        mock_managers["network"].allocate_ip_address.side_effect = NetworkManagerError(
            "No available IPs"
        )

        with pytest.raises(VMFactoryError, match="Failed to create VM"):
            vm_factory.create_vm(basic_spec, cluster_state)

    def test_create_vm_domain_creation_fails(
        self, vm_factory, mock_managers, cluster_state, basic_spec
    ):
        """Test VM creation fails when domain creation fails."""
        from ai_how.vm_management.vm_lifecycle import VMLifecycleError

        mock_managers["volume"].create_vm_volume.return_value = "/var/lib/libvirt/test-vm.qcow2"
        mock_managers["network"].allocate_ip_address.return_value = "10.0.0.10"
        mock_managers["xml_gen"].return_value = "<domain>...</domain>"
        mock_managers["lifecycle"].create_vm.side_effect = VMLifecycleError("libvirt error")

        with pytest.raises(VMFactoryError, match="Failed to create VM"):
            vm_factory.create_vm(basic_spec, cluster_state)

    def test_create_vm_with_pcie_passthrough(self, vm_factory, mock_managers, cluster_state):
        """Test VM creation with PCIe passthrough configuration."""
        spec = VMSpec(
            vm_name="gpu-vm",
            cluster_name="test-cluster",
            vm_type="gpu",
            cpu_cores=8,
            memory_gb=16,
            disk_gb=200,
            template_name="gpu.xml.j2",
            pcie_passthrough={"device": "0000:01:00.0", "type": "gpu"},
        )

        mock_managers["volume"].create_vm_volume.return_value = "/var/lib/libvirt/gpu-vm.qcow2"
        mock_managers["network"].allocate_ip_address.return_value = "10.0.0.20"
        mock_managers["xml_gen"].return_value = "<domain>...</domain>"
        mock_managers["lifecycle"].create_vm.return_value = "gpu-uuid"

        # Create VM and verify it succeeds
        vm_factory.create_vm(spec, cluster_state)

        # Verify XML generator was called with PCIe passthrough config
        mock_managers["xml_gen"].assert_called_once()
        call_kwargs = mock_managers["xml_gen"].call_args[1]
        assert call_kwargs["pcie_passthrough"] == {"device": "0000:01:00.0", "type": "gpu"}
