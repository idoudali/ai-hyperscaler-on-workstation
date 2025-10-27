"""Tests for SharedGPUValidator."""

import pytest

from ai_how.validators.shared_gpu_validator import SharedGPUValidator


@pytest.fixture
def validator():
    """Create a SharedGPUValidator instance."""
    return SharedGPUValidator()


@pytest.fixture
def config_with_shared_gpu():
    """Configuration with one GPU shared between HPC and Cloud clusters."""
    return {
        "clusters": {
            "hpc": {
                "controller": {
                    "cpu_cores": 4,
                    "memory_gb": 8,
                },
                "compute_nodes": [
                    {
                        "cpu_cores": 8,
                        "memory_gb": 16,
                        "pcie_passthrough": {
                            "enabled": True,
                            "devices": [
                                {
                                    "pci_address": "0000:01:00.0",
                                    "device_type": "gpu",
                                    "vendor_id": "10de",
                                    "device_id": "2805",
                                }
                            ],
                        },
                    }
                ],
            },
            "cloud": {
                "control_plane": {
                    "cpu_cores": 4,
                    "memory_gb": 8,
                },
                "worker_nodes": {
                    "cpu": [],
                    "gpu": [
                        {
                            "cpu_cores": 8,
                            "memory_gb": 16,
                            "auto_start": False,
                            "pcie_passthrough": {
                                "enabled": True,
                                "devices": [
                                    {
                                        "pci_address": "0000:01:00.0",  # Same GPU as HPC
                                        "device_type": "gpu",
                                        "vendor_id": "10de",
                                        "device_id": "2805",
                                    }
                                ],
                            },
                        }
                    ],
                },
            },
        }
    }


@pytest.fixture
def config_with_exclusive_gpus():
    """Configuration with different GPUs for each cluster (no sharing)."""
    return {
        "clusters": {
            "hpc": {
                "controller": {},
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
                ],
            },
            "cloud": {
                "control_plane": {},
                "worker_nodes": {
                    "gpu": [
                        {
                            "pcie_passthrough": {
                                "enabled": True,
                                "devices": [
                                    {
                                        "pci_address": "0000:02:00.0",  # Different GPU
                                        "device_type": "gpu",
                                    }
                                ],
                            }
                        }
                    ],
                },
            },
        }
    }


@pytest.fixture
def config_no_gpus():
    """Configuration with no GPUs."""
    return {
        "clusters": {
            "hpc": {
                "controller": {},
                "compute_nodes": [{"cpu_cores": 4, "memory_gb": 8}],
            },
            "cloud": {
                "control_plane": {},
                "worker_nodes": {"cpu": [{"cpu_cores": 4}]},
            },
        }
    }


class TestSharedGPUValidator:
    """Tests for SharedGPUValidator class."""

    def test_detect_shared_gpu_between_clusters(self, validator, config_with_shared_gpu):
        """Test detection of GPU shared between HPC and Cloud clusters."""
        shared_gpus = validator.detect_shared_gpus(config_with_shared_gpu)

        assert len(shared_gpus) == 1
        assert "0000:01:00.0" in shared_gpus
        assert set(shared_gpus["0000:01:00.0"]) == {"hpc", "cloud"}

    def test_no_shared_gpus_with_exclusive_allocation(self, validator, config_with_exclusive_gpus):
        """Test that exclusive GPUs are not reported as shared."""
        shared_gpus = validator.detect_shared_gpus(config_with_exclusive_gpus)

        # Should be empty since each cluster has different GPUs
        assert len(shared_gpus) == 0

    def test_no_gpus_configured(self, validator, config_no_gpus):
        """Test with configuration that has no GPUs."""
        shared_gpus = validator.detect_shared_gpus(config_no_gpus)

        assert len(shared_gpus) == 0

    def test_empty_configuration(self, validator):
        """Test with empty configuration."""
        shared_gpus = validator.detect_shared_gpus({})

        assert len(shared_gpus) == 0

    def test_hpc_only_configuration(self, validator):
        """Test with only HPC cluster (no Cloud cluster)."""
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
                }
            }
        }

        shared_gpus = validator.detect_shared_gpus(config)

        # Single cluster, so no sharing
        assert len(shared_gpus) == 0

    def test_multiple_shared_gpus(self, validator):
        """Test detection of multiple GPUs shared between clusters."""
        config = {
            "clusters": {
                "hpc": {
                    "compute_nodes": [
                        {
                            "pcie_passthrough": {
                                "enabled": True,
                                "devices": [
                                    {"pci_address": "0000:01:00.0", "device_type": "gpu"},
                                    {"pci_address": "0000:02:00.0", "device_type": "gpu"},
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
                                        {"pci_address": "0000:01:00.0", "device_type": "gpu"},
                                        {"pci_address": "0000:02:00.0", "device_type": "gpu"},
                                    ],
                                }
                            }
                        ]
                    },
                },
            }
        }

        shared_gpus = validator.detect_shared_gpus(config)

        assert len(shared_gpus) == 2
        assert "0000:01:00.0" in shared_gpus
        assert "0000:02:00.0" in shared_gpus
        assert set(shared_gpus["0000:01:00.0"]) == {"hpc", "cloud"}
        assert set(shared_gpus["0000:02:00.0"]) == {"hpc", "cloud"}

    def test_gpu_summary_with_shared_gpus(self, validator, config_with_shared_gpu):
        """Test GPU summary with shared GPU configuration."""
        summary = validator.get_gpu_summary(config_with_shared_gpu)

        assert summary["total_gpus"] == 1
        assert summary["shared_gpu_count"] == 1
        assert summary["exclusive_gpu_count"] == 0
        assert "0000:01:00.0" in summary["shared_gpus"]
        assert set(summary["all_gpus"]["0000:01:00.0"]) == {"hpc", "cloud"}

    def test_gpu_summary_with_exclusive_gpus(self, validator, config_with_exclusive_gpus):
        """Test GPU summary with exclusive GPU allocation."""
        summary = validator.get_gpu_summary(config_with_exclusive_gpus)

        assert summary["total_gpus"] == 2
        assert summary["shared_gpu_count"] == 0
        assert summary["exclusive_gpu_count"] == 2
        assert "0000:01:00.0" in summary["exclusive_gpus"]
        assert "0000:02:00.0" in summary["exclusive_gpus"]

    def test_gpu_summary_no_gpus(self, validator, config_no_gpus):
        """Test GPU summary with no GPUs configured."""
        summary = validator.get_gpu_summary(config_no_gpus)

        assert summary["total_gpus"] == 0
        assert summary["shared_gpu_count"] == 0
        assert summary["exclusive_gpu_count"] == 0

    def test_disabled_pcie_passthrough_not_counted(self, validator):
        """Test that disabled PCIe passthrough is not counted."""
        config = {
            "clusters": {
                "hpc": {
                    "compute_nodes": [
                        {
                            "pcie_passthrough": {
                                "enabled": False,  # Disabled
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
            }
        }

        shared_gpus = validator.detect_shared_gpus(config)
        assert len(shared_gpus) == 0

        summary = validator.get_gpu_summary(config)
        assert summary["total_gpus"] == 0

    def test_non_gpu_devices_not_counted(self, validator):
        """Test that non-GPU PCIe devices are not counted."""
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
                                        "device_type": "nvme",  # Not a GPU
                                    },
                                    {
                                        "pci_address": "0000:02:00.0",
                                        "device_type": "nic",  # Not a GPU
                                    },
                                ],
                            }
                        }
                    ]
                }
            }
        }

        shared_gpus = validator.detect_shared_gpus(config)
        assert len(shared_gpus) == 0

        summary = validator.get_gpu_summary(config)
        assert summary["total_gpus"] == 0

    def test_controller_with_gpu(self, validator):
        """Test GPU detection in HPC controller."""
        config = {
            "clusters": {
                "hpc": {
                    "controller": {
                        "pcie_passthrough": {
                            "enabled": True,
                            "devices": [
                                {
                                    "pci_address": "0000:01:00.0",
                                    "device_type": "gpu",
                                }
                            ],
                        }
                    },
                    "compute_nodes": [],
                }
            }
        }

        summary = validator.get_gpu_summary(config)
        assert summary["total_gpus"] == 1
        assert "0000:01:00.0" in summary["all_gpus"]

    def test_control_plane_with_gpu(self, validator):
        """Test GPU detection in Cloud control plane."""
        config = {
            "clusters": {
                "cloud": {
                    "control_plane": {
                        "pcie_passthrough": {
                            "enabled": True,
                            "devices": [
                                {
                                    "pci_address": "0000:01:00.0",
                                    "device_type": "gpu",
                                }
                            ],
                        }
                    },
                    "worker_nodes": {"cpu": [], "gpu": []},
                }
            }
        }

        summary = validator.get_gpu_summary(config)
        assert summary["total_gpus"] == 1
        assert "0000:01:00.0" in summary["all_gpus"]
