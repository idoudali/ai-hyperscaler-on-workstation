"""Tests for optional HPC and Cloud cluster definitions.

This module tests the schema validation for configurations that include:
- Only HPC cluster (Cloud omitted)
- Only Cloud cluster (HPC omitted)
- Both HPC and Cloud clusters (complete configuration)
- Neither cluster (should fail validation)
"""

import json
from pathlib import Path

import pytest
from jsonschema import ValidationError, validate


def load_schema():
    """Load the cluster schema."""
    schema_path = (
        Path(__file__).parent.parent / "src" / "ai_how" / "schemas" / "cluster.schema.json"
    )
    with open(schema_path) as f:
        return json.load(f)


class TestOptionalClusters:
    """Test suite for optional HPC and Cloud cluster definitions."""

    def test_cloud_only_configuration_valid(self):
        """Test that a configuration with only Cloud cluster is valid."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "cloud-only-cluster",
                "description": "Cloud-only configuration for testing",
            },
            "clusters": {
                "cloud": {
                    "name": "test-cloud",
                    "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
                    "control_plane": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 100,
                        "ip_address": "192.168.200.10",
                    },
                    "worker_nodes": {
                        "cpu": [
                            {
                                "worker_type": "cpu",
                                "cpu_cores": 4,
                                "memory_gb": 8,
                                "disk_gb": 100,
                                "ip": "192.168.200.11",
                            }
                        ]
                    },
                    "kubernetes_config": {
                        "cni": "calico",
                        "ingress": "nginx",
                        "storage_class": "local-path",
                    },
                }
            },
        }

        # Should not raise ValidationError
        validate(instance=config, schema=schema)

    def test_hpc_only_configuration_valid(self):
        """Test that a configuration with only HPC cluster is valid."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "hpc-only-cluster",
                "description": "HPC-only configuration for testing",
            },
            "clusters": {
                "hpc": {
                    "name": "test-hpc",
                    "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                    "controller": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 50,
                        "ip_address": "192.168.100.10",
                    },
                    "compute_nodes": [
                        {
                            "cpu_cores": 4,
                            "memory_gb": 8,
                            "disk_gb": 50,
                            "ip": "192.168.100.11",
                        }
                    ],
                    "slurm_config": {
                        "partitions": ["debug", "compute"],
                        "default_partition": "debug",
                    },
                }
            },
        }

        # Should not raise ValidationError
        validate(instance=config, schema=schema)

    def test_both_clusters_configuration_valid(self):
        """Test that a configuration with both HPC and Cloud clusters is valid."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "dual-cluster",
                "description": "Configuration with both HPC and Cloud clusters",
            },
            "clusters": {
                "hpc": {
                    "name": "test-hpc",
                    "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                    "controller": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 50,
                        "ip_address": "192.168.100.10",
                    },
                    "compute_nodes": [
                        {
                            "cpu_cores": 4,
                            "memory_gb": 8,
                            "disk_gb": 50,
                            "ip": "192.168.100.11",
                        }
                    ],
                    "slurm_config": {
                        "partitions": ["debug"],
                        "default_partition": "debug",
                    },
                },
                "cloud": {
                    "name": "test-cloud",
                    "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
                    "control_plane": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 100,
                        "ip_address": "192.168.200.10",
                    },
                    "worker_nodes": {
                        "cpu": [
                            {
                                "worker_type": "cpu",
                                "cpu_cores": 4,
                                "memory_gb": 8,
                                "disk_gb": 100,
                                "ip": "192.168.200.11",
                            }
                        ]
                    },
                    "kubernetes_config": {
                        "cni": "calico",
                        "ingress": "nginx",
                        "storage_class": "local-path",
                    },
                },
            },
        }

        # Should not raise ValidationError
        validate(instance=config, schema=schema)

    def test_empty_clusters_configuration_invalid(self):
        """Test that a configuration with no clusters fails validation."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "empty-cluster",
                "description": "Invalid configuration with no clusters",
            },
            "clusters": {},  # Empty clusters object
        }

        # Should raise ValidationError due to minProperties: 1
        with pytest.raises(ValidationError) as exc_info:
            validate(instance=config, schema=schema)

        # Verify the error message mentions the minProperties constraint
        assert (
            "should be non-empty" in str(exc_info.value).lower()
            or "minproperties" in str(exc_info.value).lower()
        )

    def test_cloud_only_with_base_image_path(self):
        """Test Cloud-only configuration with cluster-level base_image_path."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "cloud-with-image",
                "description": "Cloud-only with base image path",
            },
            "clusters": {
                "cloud": {
                    "name": "test-cloud",
                    "base_image_path": "build/packer/cloud-base/cloud-base.qcow2",
                    "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
                    "control_plane": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 100,
                        "ip_address": "192.168.200.10",
                    },
                    "worker_nodes": {
                        "cpu": [
                            {
                                "worker_type": "cpu",
                                "cpu_cores": 4,
                                "memory_gb": 8,
                                "disk_gb": 100,
                                "ip": "192.168.200.11",
                            }
                        ]
                    },
                    "kubernetes_config": {
                        "cni": "calico",
                        "ingress": "nginx",
                        "storage_class": "local-path",
                    },
                }
            },
        }

        # Should not raise ValidationError
        validate(instance=config, schema=schema)

    def test_hpc_only_with_base_image_path(self):
        """Test HPC-only configuration with cluster-level base_image_path."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "hpc-with-image",
                "description": "HPC-only with base image path",
            },
            "clusters": {
                "hpc": {
                    "name": "test-hpc",
                    "base_image_path": "build/packer/hpc-base/hpc-base.qcow2",
                    "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                    "controller": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 50,
                        "ip_address": "192.168.100.10",
                    },
                    "compute_nodes": [
                        {
                            "cpu_cores": 4,
                            "memory_gb": 8,
                            "disk_gb": 50,
                            "ip": "192.168.100.11",
                        }
                    ],
                    "slurm_config": {
                        "partitions": ["debug"],
                        "default_partition": "debug",
                    },
                }
            },
        }

        # Should not raise ValidationError
        validate(instance=config, schema=schema)

    def test_cloud_only_with_gpu_workers(self):
        """Test Cloud-only configuration with GPU worker nodes."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "cloud-gpu-cluster",
                "description": "Cloud cluster with GPU workers",
            },
            "clusters": {
                "cloud": {
                    "name": "test-cloud-gpu",
                    "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
                    "control_plane": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 100,
                        "ip_address": "192.168.200.10",
                    },
                    "worker_nodes": {
                        "gpu": [
                            {
                                "worker_type": "gpu",
                                "cpu_cores": 8,
                                "memory_gb": 32,
                                "disk_gb": 200,
                                "ip": "192.168.200.20",
                                "pcie_passthrough": {
                                    "enabled": True,
                                    "devices": [
                                        {
                                            "pci_address": "0000:01:00.0",
                                            "device_type": "gpu",
                                        }
                                    ],
                                },
                            }
                        ]
                    },
                    "kubernetes_config": {
                        "cni": "calico",
                        "ingress": "nginx",
                        "storage_class": "local-path",
                    },
                }
            },
        }

        # Should not raise ValidationError
        validate(instance=config, schema=schema)

    def test_hpc_only_with_gpu_compute_nodes(self):
        """Test HPC-only configuration with GPU compute nodes."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "hpc-gpu-cluster",
                "description": "HPC cluster with GPU compute nodes",
            },
            "clusters": {
                "hpc": {
                    "name": "test-hpc-gpu",
                    "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                    "controller": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 50,
                        "ip_address": "192.168.100.10",
                    },
                    "compute_nodes": [
                        {
                            "cpu_cores": 8,
                            "memory_gb": 32,
                            "disk_gb": 100,
                            "ip": "192.168.100.20",
                            "pcie_passthrough": {
                                "enabled": True,
                                "devices": [
                                    {
                                        "pci_address": "0000:01:00.0",
                                        "device_type": "gpu",
                                    }
                                ],
                            },
                        }
                    ],
                    "slurm_config": {
                        "partitions": ["gpu"],
                        "default_partition": "gpu",
                    },
                }
            },
        }

        # Should not raise ValidationError
        validate(instance=config, schema=schema)

    def test_invalid_cluster_property_name(self):
        """Test that invalid cluster property names are rejected."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "invalid-cluster",
                "description": "Configuration with invalid cluster type",
            },
            "clusters": {
                "invalid_type": {  # Not 'hpc' or 'cloud'
                    "name": "test-invalid",
                }
            },
        }

        # Should raise ValidationError due to additionalProperties: false
        with pytest.raises(ValidationError) as exc_info:
            validate(instance=config, schema=schema)

        assert "additional properties" in str(exc_info.value).lower()

    def test_cloud_only_missing_required_fields(self):
        """Test that Cloud-only configuration with missing required fields fails."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "incomplete-cloud",
                "description": "Cloud configuration missing required fields",
            },
            "clusters": {
                "cloud": {
                    "name": "test-cloud",
                    "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
                    # Missing control_plane, worker_nodes, and kubernetes_config
                }
            },
        }

        # Should raise ValidationError due to missing required properties
        with pytest.raises(ValidationError):
            validate(instance=config, schema=schema)

    def test_hpc_only_missing_required_fields(self):
        """Test that HPC-only configuration with missing required fields fails."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "incomplete-hpc",
                "description": "HPC configuration missing required fields",
            },
            "clusters": {
                "hpc": {
                    "name": "test-hpc",
                    "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                    # Missing controller, compute_nodes, and slurm_config
                }
            },
        }

        # Should raise ValidationError due to missing required properties
        with pytest.raises(ValidationError):
            validate(instance=config, schema=schema)

    def test_cloud_only_with_global_config(self):
        """Test Cloud-only configuration with global settings."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "cloud-with-global",
                "description": "Cloud cluster with global configuration",
            },
            "global": {
                "environment": "production",
                "owner": "platform-team",
                "region": "us-west-2",
            },
            "clusters": {
                "cloud": {
                    "name": "test-cloud",
                    "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
                    "control_plane": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 100,
                        "ip_address": "192.168.200.10",
                    },
                    "worker_nodes": {
                        "cpu": [
                            {
                                "worker_type": "cpu",
                                "cpu_cores": 4,
                                "memory_gb": 8,
                                "disk_gb": 100,
                                "ip": "192.168.200.11",
                            }
                        ]
                    },
                    "kubernetes_config": {
                        "cni": "calico",
                        "ingress": "nginx",
                        "storage_class": "local-path",
                    },
                }
            },
        }

        # Should not raise ValidationError
        validate(instance=config, schema=schema)

    def test_hpc_only_with_global_config(self):
        """Test HPC-only configuration with global settings."""
        schema = load_schema()

        config = {
            "version": "1.0",
            "metadata": {
                "name": "hpc-with-global",
                "description": "HPC cluster with global configuration",
            },
            "global": {
                "environment": "development",
                "owner": "research-team",
                "billing_code": "R-1234",
            },
            "clusters": {
                "hpc": {
                    "name": "test-hpc",
                    "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                    "controller": {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 50,
                        "ip_address": "192.168.100.10",
                    },
                    "compute_nodes": [
                        {
                            "cpu_cores": 4,
                            "memory_gb": 8,
                            "disk_gb": 50,
                            "ip": "192.168.100.11",
                        }
                    ],
                    "slurm_config": {
                        "partitions": ["debug"],
                        "default_partition": "debug",
                    },
                }
            },
        }

        # Should not raise ValidationError
        validate(instance=config, schema=schema)
