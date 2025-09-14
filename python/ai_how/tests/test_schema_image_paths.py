"""Tests for the updated schema with base_image_path support at multiple levels."""

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


def test_schema_loads_successfully():
    """Test that the updated schema loads without errors."""
    schema = load_schema()
    assert schema is not None
    assert "definitions" in schema
    assert "baseImagePath" in schema["definitions"]


def test_cluster_level_image_path_optional():
    """Test that base_image_path is now optional at cluster level."""
    schema = load_schema()

    # Minimal HPC cluster without cluster-level base_image_path should be valid
    config = {
        "version": "1.0",
        "metadata": {"name": "test-cluster", "description": "Test cluster"},
        "clusters": {
            "hpc": {
                "name": "test-hpc",
                "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                "controller": {
                    "cpu_cores": 2,
                    "memory_gb": 4,
                    "disk_gb": 20,
                    "ip_address": "192.168.100.10",
                    "base_image_path": "build/packer/hpc-controller/hpc-controller.qcow2",
                },
                "compute_nodes": [
                    {
                        "cpu_cores": 2,
                        "memory_gb": 4,
                        "disk_gb": 20,
                        "ip": "192.168.100.11",
                        "base_image_path": "build/packer/hpc-compute/hpc-compute.qcow2",
                    }
                ],
                "slurm_config": {"partitions": ["debug"], "default_partition": "debug"},
            },
            "cloud": {
                "name": "test-cloud",
                "base_image_path": "build/packer/cloud-base/cloud-base.qcow2",
                "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
                "control_plane": {
                    "cpu_cores": 2,
                    "memory_gb": 4,
                    "disk_gb": 20,
                    "ip_address": "192.168.200.10",
                },
                "worker_nodes": {
                    "cpu": [
                        {
                            "worker_type": "cpu",
                            "cpu_cores": 2,
                            "memory_gb": 4,
                            "disk_gb": 20,
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

    # Should validate successfully
    validate(instance=config, schema=schema)


def test_controller_node_image_path_override():
    """Test that controller nodes can specify their own base_image_path."""
    schema = load_schema()

    config = {
        "version": "1.0",
        "metadata": {"name": "test-cluster", "description": "Test cluster"},
        "clusters": {
            "hpc": {
                "name": "test-hpc",
                "base_image_path": "build/packer/hpc-base/hpc-base.qcow2",  # Default
                "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                "controller": {
                    "cpu_cores": 4,
                    "memory_gb": 8,
                    "disk_gb": 50,
                    "ip_address": "192.168.100.10",
                    # Controller override
                    "base_image_path": "build/packer/hpc-controller/hpc-controller.qcow2",
                },
                "compute_nodes": [
                    {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 30,
                        "ip": "192.168.100.11",
                        # Uses cluster default
                    }
                ],
                "slurm_config": {"partitions": ["debug"], "default_partition": "debug"},
            },
            "cloud": {
                "name": "test-cloud",
                "base_image_path": "build/packer/cloud-base/cloud-base.qcow2",
                "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
                "control_plane": {
                    "cpu_cores": 2,
                    "memory_gb": 4,
                    "disk_gb": 20,
                    "ip_address": "192.168.200.10",
                },
                "worker_nodes": {
                    "cpu": [
                        {
                            "worker_type": "cpu",
                            "cpu_cores": 2,
                            "memory_gb": 4,
                            "disk_gb": 20,
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

    # Should validate successfully
    validate(instance=config, schema=schema)


def test_compute_node_image_path_override():
    """Test that compute nodes can specify their own base_image_path."""
    schema = load_schema()

    config = {
        "version": "1.0",
        "metadata": {"name": "test-cluster", "description": "Test cluster"},
        "clusters": {
            "hpc": {
                "name": "test-hpc",
                "base_image_path": "build/packer/hpc-base/hpc-base.qcow2",  # Default
                "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                "controller": {
                    "cpu_cores": 4,
                    "memory_gb": 8,
                    "disk_gb": 50,
                    "ip_address": "192.168.100.10",
                    # Uses cluster default
                },
                "compute_nodes": [
                    {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 30,
                        "ip": "192.168.100.11",
                        "base_image_path": "build/packer/hpc-compute/hpc-compute.qcow2",  # Override
                    },
                    {
                        "cpu_cores": 8,
                        "memory_gb": 16,
                        "disk_gb": 50,
                        "ip": "192.168.100.12",
                        # Uses cluster default
                    },
                ],
                "slurm_config": {"partitions": ["debug"], "default_partition": "debug"},
            },
            "cloud": {
                "name": "test-cloud",
                "base_image_path": "build/packer/cloud-base/cloud-base.qcow2",
                "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
                "control_plane": {
                    "cpu_cores": 2,
                    "memory_gb": 4,
                    "disk_gb": 20,
                    "ip_address": "192.168.200.10",
                },
                "worker_nodes": {
                    "cpu": [
                        {
                            "worker_type": "cpu",
                            "cpu_cores": 2,
                            "memory_gb": 4,
                            "disk_gb": 20,
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

    # Should validate successfully
    validate(instance=config, schema=schema)


def test_cloud_worker_node_image_path_override():
    """Test that cloud worker nodes can specify their own base_image_path."""
    schema = load_schema()

    config = {
        "version": "1.0",
        "metadata": {"name": "test-cluster", "description": "Test cluster"},
        "clusters": {
            "hpc": {
                "name": "test-hpc",
                "base_image_path": "build/packer/hpc-base/hpc-base.qcow2",
                "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                "controller": {
                    "cpu_cores": 2,
                    "memory_gb": 4,
                    "disk_gb": 20,
                    "ip_address": "192.168.100.10",
                },
                "compute_nodes": [
                    {"cpu_cores": 2, "memory_gb": 4, "disk_gb": 20, "ip": "192.168.100.11"}
                ],
                "slurm_config": {"partitions": ["debug"], "default_partition": "debug"},
            },
            "cloud": {
                "name": "test-cloud",
                "base_image_path": "build/packer/cloud-base/cloud-base.qcow2",  # Default
                "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
                "control_plane": {
                    "cpu_cores": 2,
                    "memory_gb": 4,
                    "disk_gb": 20,
                    "ip_address": "192.168.200.10",
                    # override
                    "base_image_path": "build/packer/cloud-controller/cloud-controller.qcow2",
                },
                "worker_nodes": {
                    "cpu": [
                        {
                            "worker_type": "cpu",
                            "cpu_cores": 2,
                            "memory_gb": 4,
                            "disk_gb": 20,
                            "ip": "192.168.200.11",
                            # Override
                            "base_image_path": "build/packer/cloud-worker/cloud-worker.qcow2",
                        }
                    ],
                    "gpu": [
                        {
                            "worker_type": "gpu",
                            "cpu_cores": 4,
                            "memory_gb": 8,
                            "disk_gb": 50,
                            "ip": "192.168.200.12",
                            # Uses cluster default
                        }
                    ],
                },
                "kubernetes_config": {
                    "cni": "calico",
                    "ingress": "nginx",
                    "storage_class": "local-path",
                },
            },
        },
    }

    # Should validate successfully
    validate(instance=config, schema=schema)


def test_invalid_base_image_path_pattern():
    """Test that invalid base_image_path patterns are rejected."""
    schema = load_schema()

    config = {
        "version": "1.0",
        "metadata": {"name": "test-cluster", "description": "Test cluster"},
        "clusters": {
            "hpc": {
                "name": "test-hpc",
                "base_image_path": "invalid-image.txt",  # Invalid extension
                "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                "controller": {
                    "cpu_cores": 2,
                    "memory_gb": 4,
                    "disk_gb": 20,
                    "ip_address": "192.168.100.10",
                },
                "compute_nodes": [
                    {"cpu_cores": 2, "memory_gb": 4, "disk_gb": 20, "ip": "192.168.100.11"}
                ],
                "slurm_config": {"partitions": ["debug"], "default_partition": "debug"},
            },
            "cloud": {
                "name": "test-cloud",
                "base_image_path": "build/packer/cloud-base/cloud-base.qcow2",
                "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
                "control_plane": {
                    "cpu_cores": 2,
                    "memory_gb": 4,
                    "disk_gb": 20,
                    "ip_address": "192.168.200.10",
                },
                "worker_nodes": {
                    "cpu": [
                        {
                            "worker_type": "cpu",
                            "cpu_cores": 2,
                            "memory_gb": 4,
                            "disk_gb": 20,
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

    # Should raise ValidationError
    with pytest.raises(ValidationError):
        validate(instance=config, schema=schema)


def test_mixed_image_specification_levels():
    """Test complex scenario with image paths specified at different levels."""
    schema = load_schema()

    config = {
        "version": "1.0",
        "metadata": {
            "name": "mixed-image-cluster",
            "description": "Cluster demonstrating image specification at multiple levels",
        },
        "clusters": {
            "hpc": {
                "name": "mixed-hpc",
                "base_image_path": "build/packer/hpc-base/hpc-base.qcow2",  # Cluster default
                "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
                "controller": {
                    "cpu_cores": 4,
                    "memory_gb": 8,
                    "disk_gb": 50,
                    "ip_address": "192.168.100.10",
                    # Controller override
                    "base_image_path": "build/packer/hpc-controller/hpc-controller.qcow2",
                },
                "compute_nodes": [
                    {
                        "cpu_cores": 4,
                        "memory_gb": 8,
                        "disk_gb": 30,
                        "ip": "192.168.100.11",
                        # Compute override
                        "base_image_path": "build/packer/hpc-compute/hpc-compute.qcow2",
                    },
                    {
                        "cpu_cores": 8,
                        "memory_gb": 16,
                        "disk_gb": 50,
                        "ip": "192.168.100.12",
                        # Uses cluster default
                    },
                ],
                "slurm_config": {"partitions": ["gpu", "debug"], "default_partition": "gpu"},
            },
            "cloud": {
                "name": "mixed-cloud",
                # No cluster-level image (nodes must specify their own)
                "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
                "control_plane": {
                    "cpu_cores": 2,
                    "memory_gb": 4,
                    "disk_gb": 20,
                    "ip_address": "192.168.200.10",
                    # Must specify
                    "base_image_path": "build/packer/cloud-controller/cloud-controller.qcow2",
                },
                "worker_nodes": {
                    "cpu": [
                        {
                            "worker_type": "cpu",
                            "cpu_cores": 2,
                            "memory_gb": 4,
                            "disk_gb": 20,
                            "ip": "192.168.200.11",
                            # Must specify
                            "base_image_path": (
                                "build/packer/cloud-cpu-worker/cloud-cpu-worker.qcow2"
                            ),
                        }
                    ],
                    "gpu": [
                        {
                            "worker_type": "gpu",
                            "cpu_cores": 4,
                            "memory_gb": 8,
                            "disk_gb": 50,
                            "ip": "192.168.200.12",
                            # Must specify
                            "base_image_path": (
                                "build/packer/cloud-gpu-worker/cloud-gpu-worker.qcow2"
                            ),
                        }
                    ],
                },
                "kubernetes_config": {
                    "cni": "calico",
                    "ingress": "nginx",
                    "storage_class": "local-path",
                },
            },
        },
    }

    # Should validate successfully
    validate(instance=config, schema=schema)


if __name__ == "__main__":
    # Run tests when executed directly
    pytest.main([__file__, "-v"])
