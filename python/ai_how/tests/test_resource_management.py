"""Unit tests for resource management module."""

from pathlib import Path

import pytest

from ai_how.resource_management.gpu_allocator import GPUResourceAllocator
from ai_how.resource_management.shared_gpu_validator import SharedGPUValidator


class TestSharedGPUValidator:
    """Test SharedGPUValidator class."""

    def test_detect_shared_gpus_no_sharing(self):
        """Test detecting shared GPUs when none are shared."""
        validator = SharedGPUValidator()
        config = {
            "clusters": {
                "hpc": {
                    "compute_nodes": [
                        {
                            "pcie_passthrough": {
                                "enabled": True,
                                "devices": [
                                    {
                                        "pci_address": "0000:01:00.0",
                                        "device_type": "gpu",
                                    }
                                ],
                            }
                        }
                    ]
                },
                "cloud": {
                    "worker_nodes": {
                        "gpu": [
                            {
                                "pcie_passthrough": {
                                    "enabled": True,
                                    "devices": [
                                        {
                                            "pci_address": "0000:02:00.0",
                                            "device_type": "gpu",
                                        }
                                    ],
                                }
                            }
                        ]
                    }
                },
            }
        }

        shared = validator.detect_shared_gpus(config)
        assert shared == {}

    def test_detect_shared_gpus_with_sharing(self):
        """Test detecting shared GPUs when they are shared."""
        validator = SharedGPUValidator()
        config = {
            "clusters": {
                "hpc": {
                    "compute_nodes": [
                        {
                            "pcie_passthrough": {
                                "enabled": True,
                                "devices": [
                                    {
                                        "pci_address": "0000:01:00.0",
                                        "device_type": "gpu",
                                    }
                                ],
                            }
                        }
                    ]
                },
                "cloud": {
                    "worker_nodes": {
                        "gpu": [
                            {
                                "pcie_passthrough": {
                                    "enabled": True,
                                    "devices": [
                                        {
                                            "pci_address": "0000:01:00.0",
                                            "device_type": "gpu",
                                        }
                                    ],
                                }
                            }
                        ]
                    }
                },
            }
        }

        shared = validator.detect_shared_gpus(config)
        assert "0000:01:00.0" in shared
        assert set(shared["0000:01:00.0"]) == {"hpc", "cloud"}

    def test_extract_gpu_addresses_from_compute_nodes(self):
        """Test extracting GPU addresses from compute nodes."""
        validator = SharedGPUValidator()
        config = {
            "compute_nodes": [
                {
                    "pcie_passthrough": {
                        "enabled": True,
                        "devices": [
                            {"pci_address": "0000:01:00.0", "device_type": "gpu"},
                            {"pci_address": "0000:01:00.1", "device_type": "audio"},
                        ],
                    }
                }
            ]
        }

        gpus = validator._extract_gpu_addresses(config)
        assert "0000:01:00.0" in gpus
        assert "0000:01:00.1" not in gpus

    def test_extract_gpu_addresses_from_worker_nodes(self):
        """Test extracting GPU addresses from worker nodes."""
        validator = SharedGPUValidator()
        config = {
            "worker_nodes": {
                "gpu": [
                    {
                        "pcie_passthrough": {
                            "enabled": True,
                            "devices": [{"pci_address": "0000:02:00.0", "device_type": "gpu"}],
                        }
                    }
                ]
            }
        }

        gpus = validator._extract_gpu_addresses(config)
        assert "0000:02:00.0" in gpus


class TestGPUResourceAllocator:
    """Test GPUResourceAllocator class."""

    @pytest.fixture
    def temp_state_file(self, tmp_path: Path) -> Path:
        """Create temporary global state file."""
        return tmp_path / "global-state.json"

    def test_allocate_gpu_success(self, temp_state_file):
        """Test successfully allocating a GPU."""
        allocator = GPUResourceAllocator(temp_state_file)
        assert allocator.allocate_gpu("0000:01:00.0", "test-cluster")

        state = allocator._read_global_state()
        assert state["shared_resources"]["gpu_allocations"]["0000:01:00.0"] == "test-cluster"

    def test_allocate_gpu_twice_to_same_owner(self, temp_state_file):
        """Test allocating GPU twice to the same owner."""
        allocator = GPUResourceAllocator(temp_state_file)
        assert allocator.allocate_gpu("0000:01:00.0", "test-cluster")
        assert allocator.allocate_gpu("0000:01:00.0", "test-cluster")  # Should succeed

    def test_allocate_gpu_conflict(self, temp_state_file):
        """Test allocating GPU to conflicting owner."""
        allocator = GPUResourceAllocator(temp_state_file)
        assert allocator.allocate_gpu("0000:01:00.0", "cluster-1")
        assert not allocator.allocate_gpu("0000:01:00.0", "cluster-2")  # Should fail

    def test_release_gpu_success(self, temp_state_file):
        """Test releasing a GPU."""
        allocator = GPUResourceAllocator(temp_state_file)
        allocator.allocate_gpu("0000:01:00.0", "test-cluster")
        assert allocator.release_gpu("0000:01:00.0")

        state = allocator._read_global_state()
        assert "0000:01:00.0" not in state["shared_resources"]["gpu_allocations"]

    def test_release_gpu_not_allocated(self, temp_state_file):
        """Test releasing a GPU that's not allocated."""
        allocator = GPUResourceAllocator(temp_state_file)
        assert not allocator.release_gpu("0000:01:00.0")

    def test_is_gpu_available(self, temp_state_file):
        """Test checking GPU availability."""
        allocator = GPUResourceAllocator(temp_state_file)
        assert allocator.is_gpu_available("0000:01:00.0", "test-cluster")

        allocator.allocate_gpu("0000:01:00.0", "test-cluster")
        assert allocator.is_gpu_available("0000:01:00.0", "test-cluster")

        assert not allocator.is_gpu_available("0000:01:00.0", "other-cluster")

    def test_get_gpu_owner(self, temp_state_file):
        """Test getting GPU owner."""
        allocator = GPUResourceAllocator(temp_state_file)
        assert allocator.get_gpu_owner("0000:01:00.0") is None

        allocator.allocate_gpu("0000:01:00.0", "test-cluster")
        assert allocator.get_gpu_owner("0000:01:00.0") == "test-cluster"

    def test_validate_gpu_availability_all_available(self, temp_state_file):
        """Test validating GPU availability when all are available."""
        allocator = GPUResourceAllocator(temp_state_file)
        is_available, message = allocator.validate_gpu_availability(
            ["0000:01:00.0", "0000:02:00.0"], "test-cluster"
        )
        assert is_available
        assert message is None

    def test_validate_gpu_availability_with_conflict(self, temp_state_file):
        """Test validating GPU availability with conflicts."""
        allocator = GPUResourceAllocator(temp_state_file)
        allocator.allocate_gpu("0000:01:00.0", "other-cluster")

        is_available, message = allocator.validate_gpu_availability(
            ["0000:01:00.0", "0000:02:00.0"], "test-cluster"
        )
        assert not is_available
        assert "0000:01:00.0" in message
        assert "other-cluster" in message
