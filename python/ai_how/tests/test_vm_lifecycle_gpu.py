"""Unit tests for VM lifecycle GPU operations."""

from unittest.mock import Mock, patch

import pytest

from ai_how.resource_management.gpu_allocator import GPUResourceAllocator
from ai_how.state.models import VMInfo, VMState
from ai_how.vm_management.vm_lifecycle import VMLifecycleError, VMLifecycleManager


class TestVMLifecycleManagerGPU:
    """Test VM lifecycle manager GPU operations."""

    @pytest.fixture
    def mock_libvirt_client(self):
        """Create mock libvirt client."""
        return Mock()

    @pytest.fixture
    def mock_state_manager(self):
        """Create mock state manager."""
        state_manager = Mock()
        vm_info = VMInfo(
            name="test-vm",
            domain_uuid="test-uuid",
            state=VMState.RUNNING,
            cpu_cores=4,
            memory_gb=16,
            volume_path="test.qcow2",
            gpu_assigned="0000:01:00.0 (10de:2204) NVIDIA RTX A6000",
        )
        state_manager.get_state.return_value.get_vm_by_name.return_value = vm_info
        return state_manager

    @pytest.fixture
    def mock_gpu_allocator(self, tmp_path):
        """Create mock GPU allocator."""
        return GPUResourceAllocator(tmp_path / "global-state.json")

    def test_extract_pci_address_from_string(self):
        """Test extracting PCI address from GPU string."""
        manager = VMLifecycleManager()
        pci = manager._extract_pci_address("0000:01:00.0 (10de:2204) NVIDIA RTX A6000")
        assert pci == "0000:01:00.0"

    def test_extract_pci_address_with_model_only(self):
        """Test extracting PCI address when only model is given."""
        manager = VMLifecycleManager()
        pci = manager._extract_pci_address("NVIDIA RTX A6000")
        assert pci is None

    def test_extract_pci_address_invalid(self):
        """Test extracting PCI address from invalid string."""
        manager = VMLifecycleManager()
        pci = manager._extract_pci_address("invalid-string")
        assert pci is None

    @patch("ai_how.vm_management.vm_lifecycle.VMLifecycleManager.stop_vm")
    def test_stop_vm_with_gpu_release(
        self, mock_stop, mock_libvirt_client, mock_state_manager, mock_gpu_allocator
    ):
        """Test stopping VM and releasing GPU."""
        mock_stop.return_value = True

        manager = VMLifecycleManager(
            libvirt_client=mock_libvirt_client,
            state_manager=mock_state_manager,
            gpu_allocator=mock_gpu_allocator,
        )

        # Allocate GPU first
        mock_gpu_allocator.allocate_gpu("0000:01:00.0", "test-vm")

        success = manager.stop_vm_with_gpu_release("test-vm", force=False)
        assert success

        # Verify GPU was released
        assert mock_gpu_allocator.get_gpu_owner("0000:01:00.0") is None

    @patch("ai_how.vm_management.vm_lifecycle.VMLifecycleManager.start_vm")
    def test_start_vm_with_gpu_allocation(
        self, mock_start, mock_libvirt_client, mock_state_manager, mock_gpu_allocator
    ):
        """Test starting VM with GPU allocation."""
        mock_start.return_value = True

        manager = VMLifecycleManager(
            libvirt_client=mock_libvirt_client,
            state_manager=mock_state_manager,
            gpu_allocator=mock_gpu_allocator,
        )

        success = manager.start_vm_with_gpu_allocation("test-vm", wait_for_boot=False)
        assert success

        # Verify GPU was allocated
        assert mock_gpu_allocator.get_gpu_owner("0000:01:00.0") == "test-vm"

    @patch("ai_how.vm_management.vm_lifecycle.VMLifecycleManager.start_vm")
    def test_start_vm_with_gpu_conflict(
        self, _mock_start, mock_libvirt_client, mock_state_manager, mock_gpu_allocator
    ):
        """Test starting VM when GPU is already allocated."""
        # Allocate GPU to another owner first
        mock_gpu_allocator.allocate_gpu("0000:01:00.0", "other-vm")

        manager = VMLifecycleManager(
            libvirt_client=mock_libvirt_client,
            state_manager=mock_state_manager,
            gpu_allocator=mock_gpu_allocator,
        )

        with pytest.raises(VMLifecycleError) as exc_info:
            manager.start_vm_with_gpu_allocation("test-vm", wait_for_boot=False)

        assert "currently allocated to other-vm" in str(exc_info.value)

    def test_restart_vm(self, mock_libvirt_client, mock_state_manager, mock_gpu_allocator):
        """Test restarting VM with GPU management."""
        with (
            patch.object(
                VMLifecycleManager, "stop_vm_with_gpu_release", return_value=True
            ) as mock_stop,
            patch.object(
                VMLifecycleManager, "start_vm_with_gpu_allocation", return_value=True
            ) as mock_start,
        ):
            manager = VMLifecycleManager(
                libvirt_client=mock_libvirt_client,
                state_manager=mock_state_manager,
                gpu_allocator=mock_gpu_allocator,
            )

            success = manager.restart_vm("test-vm", wait_for_boot=False)
            assert success
            mock_stop.assert_called_once()
            mock_start.assert_called_once()
