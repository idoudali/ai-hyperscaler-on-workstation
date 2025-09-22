#!/usr/bin/env python3
"""
Validation tests for inventory generation with GPU detection.
This script tests the enhanced inventory generator against various cluster configurations.
"""

import unittest
import tempfile
import yaml
import json
import sys
from pathlib import Path
from unittest.mock import patch

# Add the inventories directory to the Python path for importing
sys.path.insert(0, str(Path(__file__).parent))

from generate_inventory import InventoryGenerator


class TestInventoryGeneration(unittest.TestCase):
    """Test cases for inventory generation with GPU detection."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.temp_path = Path(self.temp_dir)

    def create_test_cluster_config(self, config_data: dict) -> Path:
        """Create a temporary cluster configuration file."""
        config_path = self.temp_path / "test-cluster.yaml"
        with open(config_path, 'w') as f:
            yaml.dump(config_data, f)
        return config_path

    def test_gpu_detection_basic(self):
        """Test basic GPU detection from PCIe passthrough configuration."""
        config_data = {
            'clusters': {
                'hpc': {
                    'name': 'test-hpc-cluster',
                    'controller': {
                        'cpu_cores': 4,
                        'memory_gb': 8,
                        'disk_gb': 100,
                        'ip_address': '192.168.100.10'
                    },
                    'compute_nodes': [
                        {
                            'cpu_cores': 8,
                            'memory_gb': 16,
                            'disk_gb': 200,
                            'ip': '192.168.100.11',
                            'pcie_passthrough': {
                                'enabled': True,
                                'devices': [
                                    {
                                        'pci_address': '0000:01:00.0',
                                        'device_type': 'gpu',
                                        'vendor_id': '10de',
                                        'device_id': '2684',
                                        'iommu_group': 17
                                    }
                                ]
                            }
                        }
                    ],
                    'slurm_config': {
                        'partitions': ['gpu', 'debug'],
                        'default_partition': 'gpu'
                    }
                }
            }
        }

        config_path = self.create_test_cluster_config(config_data)
        generator = InventoryGenerator(str(config_path))

        # Test GPU detection
        node_config = config_data['clusters']['hpc']['compute_nodes'][0]
        gpu_devices = generator.detect_gpu_resources(node_config)

        self.assertEqual(len(gpu_devices), 1)
        self.assertEqual(gpu_devices[0]['device_id'], '2684')
        self.assertEqual(gpu_devices[0]['vendor'], 'nvidia')
        self.assertEqual(gpu_devices[0]['pci_address'], '0000:01:00.0')

    def test_gres_config_generation(self):
        """Test GRES configuration generation for GPU resources."""
        gpu_devices = [
            {
                'device_id': '2684',
                'vendor_id': '10de',
                'vendor': 'nvidia',
                'pci_address': '0000:01:00.0',
                'iommu_group': 17
            }
        ]

        generator = InventoryGenerator()
        gres_config = generator.generate_gres_config(gpu_devices, 'test-node-01')

        self.assertEqual(len(gres_config), 1)
        expected = "NodeName=test-node-01 Name=gpu Type=nvidia_2684 File=/dev/nvidia0"
        self.assertEqual(gres_config[0], expected)

    def test_multiple_gpu_gres_config(self):
        """Test GRES configuration generation for multiple GPUs."""
        gpu_devices = [
            {
                'device_id': '2684',
                'vendor_id': '10de',
                'vendor': 'nvidia',
                'pci_address': '0000:01:00.0'
            },
            {
                'device_id': '1e36',
                'vendor_id': '10de',
                'vendor': 'nvidia',
                'pci_address': '0000:07:00.0'
            }
        ]

        generator = InventoryGenerator()
        gres_config = generator.generate_gres_config(gpu_devices, 'gpu-node-01')

        self.assertEqual(len(gres_config), 2)
        self.assertIn("NodeName=gpu-node-01 Name=gpu Type=nvidia_2684 File=/dev/nvidia0", gres_config)
        self.assertIn("NodeName=gpu-node-01 Name=gpu Type=nvidia_1e36 File=/dev/nvidia1", gres_config)

    def test_hpc_inventory_generation(self):
        """Test complete HPC inventory generation with GPU nodes."""
        config_data = {
            'clusters': {
                'hpc': {
                    'name': 'test-hpc-cluster',
                    'network': {
                        'subnet': '192.168.100.0/24',
                        'bridge': 'virbr100'
                    },
                    'controller': {
                        'cpu_cores': 4,
                        'memory_gb': 8,
                        'disk_gb': 100,
                        'ip_address': '192.168.100.10'
                    },
                    'compute_nodes': [
                        {
                            'cpu_cores': 8,
                            'memory_gb': 16,
                            'disk_gb': 200,
                            'ip': '192.168.100.11',
                            'pcie_passthrough': {
                                'enabled': True,
                                'devices': [
                                    {
                                        'device_type': 'gpu',
                                        'vendor_id': '10de',
                                        'device_id': '2684'
                                    }
                                ]
                            }
                        },
                        {
                            'cpu_cores': 4,
                            'memory_gb': 8,
                            'disk_gb': 100,
                            'ip': '192.168.100.12'
                            # No PCIe passthrough - CPU only node
                        }
                    ],
                    'slurm_config': {
                        'partitions': ['gpu', 'cpu'],
                        'default_partition': 'gpu'
                    }
                }
            }
        }

        config_path = self.create_test_cluster_config(config_data)
        generator = InventoryGenerator(str(config_path))
        generator.load_cluster_config()

        hpc_inventory = generator.generate_hpc_inventory()

        # Test basic structure
        self.assertIn('children', hpc_inventory)
        self.assertIn('hpc_controllers', hpc_inventory['children'])
        self.assertIn('hpc_compute_nodes', hpc_inventory['children'])
        self.assertIn('hpc_gpu_nodes', hpc_inventory['children'])

        # Test controller
        controllers = hpc_inventory['children']['hpc_controllers']['hosts']
        self.assertEqual(len(controllers), 1)
        self.assertIn('hpc-controller', controllers)

        # Test compute nodes (CPU only)
        compute_nodes = hpc_inventory['children']['hpc_compute_nodes']['hosts']
        self.assertEqual(len(compute_nodes), 1)

        # Test GPU nodes
        gpu_nodes = hpc_inventory['children']['hpc_gpu_nodes']['hosts']
        self.assertEqual(len(gpu_nodes), 1)

        gpu_node = list(gpu_nodes.values())[0]
        self.assertTrue(gpu_node['has_gpu'])
        self.assertEqual(gpu_node['gpu_count'], 1)
        self.assertIn('slurm_gres', gpu_node)

        # Test global GRES configuration
        self.assertIn('slurm_gres_conf', hpc_inventory['vars'])
        gres_conf = hpc_inventory['vars']['slurm_gres_conf']
        self.assertEqual(len(gres_conf), 1)

    def test_cloud_inventory_generation(self):
        """Test cloud cluster inventory generation with GPU workers."""
        config_data = {
            'clusters': {
                'cloud': {
                    'name': 'test-cloud-cluster',
                    'network': {
                        'subnet': '192.168.200.0/24',
                        'bridge': 'virbr200'
                    },
                    'control_plane': {
                        'cpu_cores': 4,
                        'memory_gb': 8,
                        'disk_gb': 100,
                        'ip_address': '192.168.200.10'
                    },
                    'worker_nodes': {
                        'cpu': [
                            {
                                'cpu_cores': 4,
                                'memory_gb': 8,
                                'disk_gb': 100,
                                'ip': '192.168.200.11',
                                'worker_type': 'cpu'
                            }
                        ],
                        'gpu': [
                            {
                                'cpu_cores': 8,
                                'memory_gb': 16,
                                'disk_gb': 200,
                                'ip': '192.168.200.12',
                                'worker_type': 'gpu',
                                'pcie_passthrough': {
                                    'enabled': True,
                                    'devices': [
                                        {
                                            'device_type': 'gpu',
                                            'vendor_id': '10de',
                                            'device_id': '1e36'
                                        }
                                    ]
                                }
                            }
                        ]
                    },
                    'kubernetes_config': {
                        'cni': 'calico',
                        'ingress': 'nginx'
                    }
                }
            }
        }

        config_path = self.create_test_cluster_config(config_data)
        generator = InventoryGenerator(str(config_path))
        generator.load_cluster_config()

        cloud_inventory = generator.generate_cloud_inventory()

        # Test basic structure
        self.assertIn('children', cloud_inventory)
        self.assertIn('k8s_control_plane', cloud_inventory['children'])
        self.assertIn('k8s_workers', cloud_inventory['children'])
        self.assertIn('k8s_gpu_workers', cloud_inventory['children'])

        # Test control plane
        control_plane = cloud_inventory['children']['k8s_control_plane']['hosts']
        self.assertEqual(len(control_plane), 1)

        # Test CPU workers
        cpu_workers = cloud_inventory['children']['k8s_workers']['hosts']
        self.assertEqual(len(cpu_workers), 1)

        # Test GPU workers
        gpu_workers = cloud_inventory['children']['k8s_gpu_workers']['hosts']
        self.assertEqual(len(gpu_workers), 1)

        gpu_worker = list(gpu_workers.values())[0]
        self.assertTrue(gpu_worker['has_gpu'])
        self.assertEqual(gpu_worker['gpu_count'], 1)

    def test_vendor_id_mapping(self):
        """Test vendor ID to vendor name mapping."""
        generator = InventoryGenerator()

        self.assertEqual(generator._get_vendor_name('10de'), 'nvidia')
        self.assertEqual(generator._get_vendor_name('1002'), 'amd')
        self.assertEqual(generator._get_vendor_name('8086'), 'intel')
        self.assertEqual(generator._get_vendor_name('unknown'), 'unknown')

    def test_no_gpu_detection(self):
        """Test inventory generation with no GPU devices."""
        config_data = {
            'clusters': {
                'hpc': {
                    'name': 'cpu-only-cluster',
                    'controller': {
                        'cpu_cores': 4,
                        'memory_gb': 8,
                        'ip_address': '192.168.100.10'
                    },
                    'compute_nodes': [
                        {
                            'cpu_cores': 8,
                            'memory_gb': 16,
                            'ip': '192.168.100.11'
                            # No PCIe passthrough
                        }
                    ]
                }
            }
        }

        config_path = self.create_test_cluster_config(config_data)
        generator = InventoryGenerator(str(config_path))
        generator.load_cluster_config()

        hpc_inventory = generator.generate_hpc_inventory()

        # Should have no GPU nodes
        gpu_nodes = hpc_inventory['children']['hpc_gpu_nodes']['hosts']
        self.assertEqual(len(gpu_nodes), 0)

        # Should have regular compute nodes
        compute_nodes = hpc_inventory['children']['hpc_compute_nodes']['hosts']
        self.assertEqual(len(compute_nodes), 1)

        # Should not have GRES configuration
        self.assertNotIn('slurm_gres_conf', hpc_inventory['vars'])

    def test_inventory_validation(self):
        """Test inventory validation functionality."""
        config_data = {
            'clusters': {
                'hpc': {
                    'name': 'validation-test',
                    'controller': {
                        'ip_address': '192.168.100.10'
                    },
                    'compute_nodes': [
                        {
                            'ip': '192.168.100.11',
                            'pcie_passthrough': {
                                'enabled': True,
                                'devices': [
                                    {
                                        'device_type': 'gpu',
                                        'device_id': '2684'
                                    }
                                ]
                            }
                        }
                    ]
                }
            }
        }

        config_path = self.create_test_cluster_config(config_data)
        generator = InventoryGenerator(str(config_path))

        # Generate inventory
        inventory = generator.generate_inventory()

        # Validate inventory
        self.assertTrue(generator.validate_inventory())

    def test_full_inventory_structure(self):
        """Test complete inventory structure with both HPC and Cloud clusters."""
        config_data = {
            'clusters': {
                'hpc': {
                    'name': 'test-hpc',
                    'controller': {'ip_address': '192.168.100.10'},
                    'compute_nodes': [
                        {
                            'ip': '192.168.100.11',
                            'pcie_passthrough': {
                                'enabled': True,
                                'devices': [{'device_type': 'gpu', 'device_id': '2684'}]
                            }
                        }
                    ]
                },
                'cloud': {
                    'name': 'test-cloud',
                    'control_plane': {'ip_address': '192.168.200.10'},
                    'worker_nodes': {
                        'gpu': [
                            {
                                'ip': '192.168.200.11',
                                'pcie_passthrough': {
                                    'enabled': True,
                                    'devices': [{'device_type': 'gpu', 'device_id': '1e36'}]
                                }
                            }
                        ]
                    }
                }
            }
        }

        config_path = self.create_test_cluster_config(config_data)
        generator = InventoryGenerator(str(config_path))

        inventory = generator.generate_inventory()

        # Test top-level structure
        self.assertIn('all', inventory)
        self.assertIn('children', inventory['all'])

        # Test both clusters exist
        children = inventory['all']['children']
        self.assertIn('hpc_cluster', children)
        self.assertIn('cloud_cluster', children)

        # Test HPC cluster has GPU nodes
        hpc_gpu_nodes = children['hpc_cluster']['children']['hpc_gpu_nodes']['hosts']
        self.assertEqual(len(hpc_gpu_nodes), 1)

        # Test Cloud cluster has GPU workers
        cloud_gpu_workers = children['cloud_cluster']['children']['k8s_gpu_workers']['hosts']
        self.assertEqual(len(cloud_gpu_workers), 1)


def run_validation_tests():
    """Run all validation tests for inventory generation."""
    print("🧪 Running inventory generation validation tests...")
    print("="*60)

    # Run the test suite
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestInventoryGeneration)

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    print("\n" + "="*60)
    if result.wasSuccessful():
        print("✅ All validation tests passed!")
        print(f"📊 Ran {result.testsRun} tests successfully")
        return True
    else:
        print("❌ Some validation tests failed!")
        print(f"📊 Ran {result.testsRun} tests, {len(result.failures)} failures, {len(result.errors)} errors")
        return False


if __name__ == "__main__":
    success = run_validation_tests()
    sys.exit(0 if success else 1)
